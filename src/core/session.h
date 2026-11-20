#pragma once

#include <QElapsedTimer>
#include <QJsonDocument>
#include <QList>
#include <QNetworkAccessManager>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <functional>
#include <utility>

class Database;
class QNetworkReply;

// A signed-in session with a BookOrbit server, and the requests made in it.
//
// Uses a "native" session: POST /auth/login returns a short-lived access token (sent as a
// Bearer token) and a refresh token. Only the refresh token is saved, and every refresh
// replaces it.
class Session : public QObject
{
    Q_OBJECT
    // Last server signed in to, e.g. "https://books.example.com". Empty until a sign-in
    // succeeds, and kept after signing out.
    Q_PROPERTY(QString serverUrl READ serverUrl NOTIFY serverUrlChanged)
    // Prefill for the server field when none is saved. Set at build time with
    // SUGGESTED_SERVER, otherwise empty.
    Q_PROPERTY(QString suggestedServer READ suggestedServer CONSTANT)
    Q_PROPERTY(QString username READ username NOTIFY usernameChanged)
    Q_PROPERTY(bool signedIn READ signedIn NOTIFY signedInChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    // Whether the server can be reached, as far as the app knows. Starts true; goes false
    // when a request gets no reply or Wi-Fi can't reconnect without asking, and true again
    // on any reply. While false, requests other than goOnline(), sign-in and downloads
    // fail at once with NO_CONNECTION.
    Q_PROPERTY(bool online READ online NOTIFY onlineChanged)
    // Whether the device has a network connection, as the system reports it. Nothing tells
    // the app when that changes, so it's looked at again whenever online changes. Offline
    // with it true means the server didn't reply.
    Q_PROPERTY(bool networkConnected READ networkConnected NOTIFY onlineChanged)
    // Signing in's error, shown on the sign-in page
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    // The user's libraries, [{id, name}] in their order. Empty until withLibrary() has
    // fetched them.
    Q_PROPERTY(QVariantList libraries READ libraries NOTIFY librariesChanged)
    // The book list's library (see withLibrary()), or -1 until known
    Q_PROPERTY(int libraryId READ libraryId NOTIFY libraryIdChanged)

public:
    using DataHandler = std::function<void(const QByteArray &)>;
    using ErrorHandler = std::function<void(int status, const QString &message)>;
    // A failure's message, or an empty one when offline (the header shows that)
    using FailedHandler = std::function<void(const QString &error)>;
    // The error for requests that can't be sent, with status 0
    static inline const QString NO_CONNECTION = QStringLiteral("No connection");
    // The error for requests sent that got no reply, with the network up
    static inline const QString NO_REPLY = QStringLiteral("The server didn't reply");

    explicit Session(Database *database, QObject *parent = nullptr);

    QString serverUrl() const { return m_serverUrl; }
    QString suggestedServer() const;
    QString username() const { return m_username; }
    bool signedIn() const { return m_signedIn; }
    bool busy() const { return m_pending > 0; }
    bool online() const { return m_online; }
    bool networkConnected() const;
    QString error() const { return m_error; }
    QVariantList libraries() const { return m_libraries; }
    int libraryId() const { return m_libraryId; }
    // Endpoint for book queries in a library, or in every library for -1. Only a library's
    // has jump buckets, at the path plus "/jump-buckets".
    static QString booksPath(int libraryId);
    // The library to ask for a list's books or groups: libraryId, or for every library (-1)
    // a server's only one, which has A-Z sections unlike every library's books
    int libraryToQuery(int libraryId) const;
    // Whether libraries has one with this id
    bool hasLibrary(int libraryId) const;
    // The library the book list showed last, as saved, or -1. Known before the libraries
    // are fetched, so it may have gone since.
    int savedLibraryId() const;

    // server is as typed, e.g. "books.example.com". Defaults to https.
    Q_INVOKABLE void signIn(const QString &server, const QString &username, const QString &password);
    // Clears the saved server so another can be used. Only when signed out.
    Q_INVOKABLE void forgetServer();
    Q_INVOKABLE void signOut();
    // Asks the system to connect Wi-Fi (its own dialog), then checks the server is there
    Q_INVOKABLE void goOnline();
    // Uses another of the libraries from now on, and remembers it until signing out
    Q_INVOKABLE void chooseLibrary(int libraryId);

    // Authenticated GET for raw data such as thumbnails. Doesn't set busy.
    void download(const QString &path, DataHandler onSuccess, ErrorHandler onError);
    // Authenticated GET for a large file the caller streams. Refreshes the access token
    // first so it outlasts the download. The caller owns the reply.
    void startStream(const QString &path, std::function<void(QNetworkReply *)> onStarted,
                     ErrorHandler onError);
    // Authenticated background request. Doesn't set busy.
    void request(const QByteArray &method, const QString &path, const QJsonDocument &body,
                 DataHandler onSuccess, ErrorHandler onError);
    // Authenticated request for a list, setting busy while it's in flight
    void callJson(const QByteArray &method, const QString &path, const QJsonDocument &body,
                  std::function<void(const QJsonDocument &)> onSuccess, FailedHandler onFailed);
    // Calls then with the library id, fetching the libraries first if needed: the one
    // used last time if the server still has it, else the first. Calls made while they're
    // fetched wait for the same request, which is quiet if the first call is.
    void withLibrary(std::function<void(int libraryId)> then, ErrorHandler onError, bool quiet = true);
    // withLibrary() for a list, setting busy, with onFailed called as callJson() does
    void loadLibrary(std::function<void()> then, FailedHandler onFailed);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

signals:
    void serverUrlChanged();
    void usernameChanged();
    void signedInChanged();
    void busyChanged();
    void onlineChanged();
    void errorChanged();
    void librariesChanged();
    void libraryIdChanged();
    // chooseLibrary() replaced the library in use
    void libraryChanged();
    // A sign-in succeeded
    void started();
    // The session ended, signed out or expired. Sent before signedInChanged.
    void ended();
    // The user signed out
    void signedOut();

private:
    // Sets the library in use, saved for next time
    void useLibrary(int libraryId);
    // On the device, connects Wi-Fi silently if needed, then calls then(connected). That takes
    // seconds, so it's done on another thread and the app carries on drawing. Calls made
    // meanwhile wait for the same connection.
    void whenNetwork(std::function<void(bool connected)> then);
    // Refreshes the session to see whether the server can be reached
    void checkServer();
    // Fails a request without sending it
    void failOffline(const ErrorHandler &onError);
    void setOnline(bool online);
    // withToken adds the access token (login, refresh and logout don't use it). Quiet
    // requests don't set busy.
    void send(const QByteArray &method, const QString &path, const QJsonDocument &body,
              DataHandler onSuccess, ErrorHandler onError, bool withToken = false,
              bool quiet = false);
    // send() once Wi-Fi is connected
    void sendNow(const QByteArray &method, const QString &path, const QJsonDocument &body,
                 DataHandler onSuccess, ErrorHandler onError, bool withToken, bool quiet);
    // Sends with the access token, refreshing and retrying once on a 401
    void call(const QByteArray &method, const QString &path, const QJsonDocument &body,
              DataHandler onSuccess, ErrorHandler onError, bool quiet = false,
              bool retried = false);
    // Exchanges the refresh token for a new access token, then runs any queued callbacks
    void refreshSession(std::function<void()> then);
    void applyCredentials(const QJsonObject &credentials);
    void clearSession();
    void setSignedIn(bool signedIn);
    void setError(const QString &error);

    Database *m_database;
    QNetworkAccessManager m_nam;
    QString m_serverUrl;
    QString m_username;
    QString m_accessToken;
    QString m_refreshToken;
    bool m_signedIn = false;
    bool m_online = true;
    // Wi-Fi connected at the last look, and when that was (see eventFilter)
    bool m_networkConnected = false;
    QElapsedTimer m_networkLook;
    // Waiting for whenNetwork()'s connection; not empty while it connects
    QList<std::function<void(bool)>> m_afterConnect;
    int m_pending = 0;
    QString m_error;
    QVariantList m_libraries;
    int m_libraryId = -1;
    // Waiting for withLibrary()'s request; not empty while it's in flight
    QList<std::pair<std::function<void(int)>, ErrorHandler>> m_afterLibrary;
    bool m_refreshing = false;
    QList<std::function<void()>> m_afterRefresh;
    // Why the last refresh failed, if the server answered with an error, for the requests
    // that waited for it
    int m_refreshStatus = 0;
    QString m_refreshError;
};
