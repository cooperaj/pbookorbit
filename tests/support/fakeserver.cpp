#include "fakeserver.h"

#include <QFile>
#include <QJsonDocument>
#include <QTcpSocket>

FakeServer::FakeServer(QObject *parent) : QObject(parent)
{
    if (!m_server.listen(QHostAddress::LocalHost))
        qFatal("FakeServer: can't listen: %s", qPrintable(m_server.errorString()));
    connect(&m_server, &QTcpServer::newConnection, this, [this] {
        while (QTcpSocket *socket = m_server.nextPendingConnection()) {
            connect(socket, &QTcpSocket::readyRead, this, [this, socket] { readRequest(socket); });
            connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
        }
    });
}

QString FakeServer::url() const
{
    return QString("http://127.0.0.1:%1").arg(m_server.serverPort());
}

void FakeServer::respond(const QString &method, const QString &path, int status, const QString &fixture)
{
    QByteArray body;
    if (!fixture.isEmpty()) {
        QFile file(QStringLiteral(FIXTURES_DIR "/") + fixture);
        if (!file.open(QIODevice::ReadOnly))
            qFatal("FakeServer: no fixture %s", qPrintable(file.fileName()));
        body = file.readAll();
    }
    m_responses.insert(method + ' ' + path, {status, body});
}

void FakeServer::reset()
{
    m_responses.clear();
    m_requests.clear();
    emit requestsChanged();
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
    m_requests.append(QVariantMap{
        {"method", method},
        {"path", path},
        {"body", QJsonDocument::fromJson(body).toVariant()},
    });
    emit requestsChanged();

    const Response response = m_responses.value(method + ' ' + path, {404, R"({"statusCode":404,"message":"Not found"})"});
    socket->write(QString("HTTP/1.1 %1 Fake\r\nContent-Type: application/json\r\n"
                          "Content-Length: %2\r\nConnection: close\r\n\r\n")
                      .arg(response.status).arg(response.body.size()).toLatin1());
    socket->write(response.body);
    socket->disconnectFromHost();
}
