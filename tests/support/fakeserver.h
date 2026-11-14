#pragma once

#include <QHash>
#include <QJsonValue>
#include <QObject>
#include <QPointer>
#include <QSet>
#include <QTcpServer>
#include <QTcpSocket>
#include <QVariantList>

// A stand-in BookOrbit server on 127.0.0.1. A test says what each request gets with
// respond(), points the client at url, and can check what was sent in requests. Anything
// without a response gets 404. With reachable false, connections are refused, as when the
// server or the network is down.
class FakeServer : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString url READ url CONSTANT)
    Q_PROPERTY(QVariantList requests READ requests NOTIFY requestsChanged)
    Q_PROPERTY(bool reachable READ reachable WRITE setReachable NOTIFY reachableChanged)

public:
    explicit FakeServer(QObject *parent = nullptr);

    QString url() const;
    QVariantList requests() const { return m_requests; }
    bool reachable() const { return m_server.isListening(); }
    void setReachable(bool reachable);

    // The reply to method and path (e.g. "POST", "/api/v1/auth/login"): the status, and
    // the body from tests/fixtures/<fixture>, or none if fixture is empty. With match, only
    // for requests whose body has those fields, e.g. {sort: [{field: "author"}]}. Objects
    // and arrays in match need only be part of the body's. The latest that matches wins,
    // and one without match answers the rest.
    Q_INVOKABLE void respond(const QString &method, const QString &path, int status,
                             const QString &fixture = QString(), const QVariant &match = QVariant());
    // A file download for GET path: the bytes of tests/fixtures/<fixture>, named fileName
    // the way BookOrbit names them, in a Content-Disposition header
    Q_INVOKABLE void respondFile(const QString &path, const QString &fixture, const QString &fileName);
    // Keeps requests to method and path waiting, unanswered, until release(), so a test can
    // act while a reply is on its way
    Q_INVOKABLE void hold(const QString &method, const QString &path);
    // Answers the requests held for method and path, and stops holding them
    Q_INVOKABLE void release(const QString &method, const QString &path);
    // Forgets the responses, requests and holds, and is reachable again
    Q_INVOKABLE void reset();

signals:
    void requestsChanged();
    void reachableChanged();

private:
    struct Response {
        int status;
        QByteArray body;
        QJsonValue match;
        QByteArray headers = "Content-Type: application/json\r\n";
    };

    static QByteArray fixtureBytes(const QString &fixture);

    struct Waiting {
        QPointer<QTcpSocket> socket;
        QString key;
        QJsonValue body;
    };

    static bool matches(const QJsonValue &body, const QJsonValue &match);
    void answer(QTcpSocket *socket, const QString &key, const QJsonValue &body);

    void readRequest(QTcpSocket *socket);

    QTcpServer m_server;
    // Kept so the url stays the same while unreachable
    quint16 m_port = 0;
    QHash<QString, QList<Response>> m_responses;
    QSet<QString> m_held;
    QList<Waiting> m_waiting;
    QVariantList m_requests;
};
