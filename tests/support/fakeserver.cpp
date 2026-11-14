#include "fakeserver.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJSValue>
#include <QJsonObject>
#include <QTcpSocket>
#include <algorithm>
#include <utility>

FakeServer::FakeServer(QObject *parent) : QObject(parent)
{
    if (!m_server.listen(QHostAddress::LocalHost))
        qFatal("FakeServer: can't listen: %s", qPrintable(m_server.errorString()));
    m_port = m_server.serverPort();
    connect(&m_server, &QTcpServer::newConnection, this, [this] {
        while (QTcpSocket *socket = m_server.nextPendingConnection()) {
            connect(socket, &QTcpSocket::readyRead, this, [this, socket] { readRequest(socket); });
            connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
        }
    });
}

QString FakeServer::url() const
{
    return QString("http://127.0.0.1:%1").arg(m_port);
}

void FakeServer::setReachable(bool reachable)
{
    if (reachable == m_server.isListening())
        return;
    if (!reachable)
        m_server.close();
    else if (!m_server.listen(QHostAddress::LocalHost, m_port))
        qFatal("FakeServer: can't listen again: %s", qPrintable(m_server.errorString()));
    emit reachableChanged();
}

void FakeServer::respond(const QString &method, const QString &path, int status, const QString &fixture,
                         const QVariant &match)
{
    QByteArray body;
    if (!fixture.isEmpty()) {
        QFile file(QStringLiteral(FIXTURES_DIR "/") + fixture);
        if (!file.open(QIODevice::ReadOnly))
            qFatal("FakeServer: no fixture %s", qPrintable(file.fileName()));
        body = file.readAll();
    }
    // A JavaScript object arrives wrapped, and QJsonValue only reads plain maps and lists
    const QVariant plain = match.metaType() == QMetaType::fromType<QJSValue>() ? match.value<QJSValue>().toVariant()
                                                                              : match;
    m_responses[method + ' ' + path].append({status, body, QJsonValue::fromVariant(plain)});
}

// Whether body has everything in match: each of its fields, and each of its array items
// somewhere in the body's array
bool FakeServer::matches(const QJsonValue &body, const QJsonValue &match)
{
    if (match.isObject()) {
        const QJsonObject wanted = match.toObject();
        const QJsonObject have = body.toObject();
        for (auto it = wanted.begin(); it != wanted.end(); ++it) {
            if (!have.contains(it.key()) || !matches(have.value(it.key()), it.value()))
                return false;
        }
        return body.isObject();
    }
    if (match.isArray()) {
        const QJsonArray have = body.toArray();
        for (const QJsonValue &wanted : match.toArray()) {
            if (std::none_of(have.begin(), have.end(), [&](const QJsonValue &v) { return matches(v, wanted); }))
                return false;
        }
        return body.isArray();
    }
    return body == match;
}

void FakeServer::hold(const QString &method, const QString &path)
{
    m_held.insert(method + ' ' + path);
}

void FakeServer::release(const QString &method, const QString &path)
{
    const QString key = method + ' ' + path;
    m_held.remove(key);
    const QList<Waiting> waiting = std::exchange(m_waiting, {});
    for (const Waiting &request : waiting) {
        if (request.key != key)
            m_waiting.append(request);
        else if (request.socket)
            answer(request.socket, request.key, request.body);
    }
}

void FakeServer::reset()
{
    m_responses.clear();
    m_held.clear();
    m_waiting.clear();
    m_requests.clear();
    emit requestsChanged();
    setReachable(true);
}

// Waits for the whole request (headers, then Content-Length bytes of body) before answering.
// Each connection gets one reply and is closed.
void FakeServer::readRequest(QTcpSocket *socket)
{
    const QByteArray data = socket->peek(socket->bytesAvailable());
    const int headerEnd = data.indexOf("\r\n\r\n");
    if (headerEnd < 0)
        return;
    const QList<QByteArray> lines = data.left(headerEnd).split('\n');
    int length = 0;
    for (const QByteArray &line : lines) {
        if (line.toLower().startsWith("content-length:"))
            length = line.mid(15).trimmed().toInt();
    }
    if (data.size() < headerEnd + 4 + length)
        return;
    socket->read(headerEnd + 4 + length);

    const QList<QByteArray> requestLine = lines.first().trimmed().split(' ');
    const QString method = QString::fromLatin1(requestLine.value(0));
    const QString path = QString::fromLatin1(requestLine.value(1)).section('?', 0, 0);
    const QByteArray body = data.mid(headerEnd + 4, length);
    const QJsonDocument json = QJsonDocument::fromJson(body);
    m_requests.append(QVariantMap{
        {"method", method},
        {"path", path},
        {"body", json.toVariant()},
    });
    emit requestsChanged();

    const QJsonValue bodyValue = json.isObject() ? QJsonValue(json.object())
                               : json.isArray() ? QJsonValue(json.array()) : QJsonValue();
    const QString key = method + ' ' + path;
    if (m_held.contains(key))
        m_waiting.append({socket, key, bodyValue});
    else
        answer(socket, key, bodyValue);
}

void FakeServer::answer(QTcpSocket *socket, const QString &key, const QJsonValue &bodyValue)
{
    Response response{404, R"({"statusCode":404,"message":"Not found"})", {}};
    const QList<Response> candidates = m_responses.value(key);
    const auto matched = std::find_if(candidates.rbegin(), candidates.rend(), [&](const Response &r) {
        return !r.match.isUndefined() && !r.match.isNull() && matches(bodyValue, r.match);
    });
    const auto general = std::find_if(candidates.rbegin(), candidates.rend(), [](const Response &r) {
        return r.match.isUndefined() || r.match.isNull();
    });
    if (matched != candidates.rend())
        response = *matched;
    else if (general != candidates.rend())
        response = *general;
    socket->write(QString("HTTP/1.1 %1 Fake\r\nContent-Type: application/json\r\n"
                          "Content-Length: %2\r\nConnection: close\r\n\r\n")
                      .arg(response.status).arg(response.body.size()).toLatin1());
    socket->write(response.body);
    socket->disconnectFromHost();
}
