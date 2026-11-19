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
    // The libraries to choose from, [{id, name, bookCount}] in the user's order, while the
    // server has several and none is chosen. Empty otherwise.
    Q_PROPERTY(QVariantList libraryChoices READ libraryChoices NOTIFY libraryChoicesChanged)
    // The library in use, or -1 until it's known
    Q_PROPERTY(int libraryId READ libraryId NOTIFY libraryIdChanged)
    // How many libraries the server had when last asked, or 0 before then
    Q_PROPERTY(int libraryCount READ libraryCount NOTIFY libraryCountChanged)

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
    QVariantList libraryChoices() const { return m_libraryChoices; }
    int libraryCount() const { return m_libraryCount; }
    // The library's id, or -1 until withLibrary() has fetched it
    int libraryId() const { return m_libraryId; }
    // Endpoint for the library's book queries
    QString libraryBooksPath() const { return QString("/libraries/%1/books").arg(m_libraryId); }

    // server is as typed, e.g. "books.example.com". Defaults to https.
    Q_INVOKABLE void signIn(const QString &server, const QString &username, const QString &password);
    // Clears the saved server so another can be used. Only when signed out.
    Q_INVOKABLE void forgetServer();
    Q_INVOKABLE void signOut();
    // Asks the system to connect Wi-Fi (its own dialog), then checks the server is there
    Q_INVOKABLE void goOnline();
    // Fetches the libraries into libraryChoices, to choose another
    Q_INVOKABLE void changeLibrary();
    // Uses one of libraryChoices from now on, and sends the requests waiting for it
    Q_INVOKABLE void chooseLibrary(int libraryId);
    // Keeps the library in use, if there is one, and clears libraryChoices
    Q_INVOKABLE void cancelLibraryChoice();

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
    // Calls then with the library id, fetching it first if needed. Calls made while it's
    // fetched wait for the same request, which is quiet if the first call is. The library is
    // the one chosen before if the server still has it, or its only one; with several, they
    // wait until one is chosen (see libraryChoices).
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
    void libraryChoicesChanged();
    void libraryIdChanged();
    void libraryCountChanged();
    // The library id is known, so requests for its books can be sent
    void libraryReady();
    // Another library was chosen in place of the one in use, after libraryReady
    void libraryChanged();
    // A sign-in succeeded
    void started();
    // The session ended, signed out or expired. Sent before signedInChanged.
    void ended();
    // The user signed out
    void signedOut();

private:
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
    // Uses and saves the library, and sends the requests waiting for it
    void setLibrary(int libraryId);
    void setLibraryChoices(const QVariantList &choices);
    // The libraries in a /libraries reply, as in libraryChoices. Updates libraryCount.
    QVariantList librariesFrom(const QByteArray &data);
    static bool offers(const QVariantList &choices, int libraryId);

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
    int m_libraryId = -1;
    // Waiting for withLibrary()'s request; not empty while it's in flight
    QList<std::pair<std::function<void(int)>, ErrorHandler>> m_afterLibrary;
    QVariantList m_libraryChoices;
    int m_libraryCount = 0;
    bool m_refreshing = false;
    QList<std::function<void()>> m_afterRefresh;
    // Why the last refresh failed, if the server answered with an error, for the requests
    // that waited for it
    int m_refreshStatus = 0;
    QString m_refreshError;
};
