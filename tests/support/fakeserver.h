#pragma once

#include <QHash>
#include <QJsonValue>
#include <QObject>
#include <QTcpServer>
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
    // Forgets the responses and requests, and is reachable again
    Q_INVOKABLE void reset();

signals:
    void requestsChanged();
    void reachableChanged();

private:
    struct Response {
        int status;
        QByteArray body;
        QJsonValue match;
    };

    static bool matches(const QJsonValue &body, const QJsonValue &match);

    void readRequest(QTcpSocket *socket);

    QTcpServer m_server;
    // Kept so the url stays the same while unreachable
    quint16 m_port = 0;
    QHash<QString, QList<Response>> m_responses;
    QVariantList m_requests;
};
