#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QTemporaryDir>
#include <QtQuickTest>
#include <inkview.h>
#include <memory>
#include <sqlite3.h>

#include "core/bookfinder.h"
#include "core/bookorbitclient.h"
#include "core/browser.h"
#include "core/database.h"
#include "core/diagnostics.h"
#include "core/downloads.h"
#include "core/updater.h"
#include "core/formats.h"
#include "fakeinkview.h"
#include "fakekeyboard.h"
#include "fakeserver.h"
#include "ui/covers.h"
#include "ui/eink.h"
#include "ui/invertedimageprovider.h"
#include "ui/launchertile.h"
#include "ui/themeimageprovider.h"

// The app's real objects, made afresh by reset() in a new temporary folder, which is also
// the working directory. On the PC build inkview's paths are relative, so the database,
// downloads, covers and log all stay in there. Where they'd reach the device through
// inkview, they reach FakeInkview instead.
class TestApp : public QObject
{
    Q_OBJECT
    // Whether the device has no network, as with make run-offline. Can be changed while
    // the app is open, like turning Wi-Fi off or on.
    Q_PROPERTY(bool offline READ offline WRITE setOffline)

public:
    TestApp(QQmlEngine *engine, FakeServer *server, FakeInkview *inkview, FakeKeyboard *keyboard)
        : QObject(engine), m_engine(engine), m_server(server), m_inkview(inkview), m_keyboard(keyboard)
    {
        reset();
    }
    ~TestApp() override
    {
        m_objects.reset();
        setOffline(false);
        QDir::setCurrent(QDir::tempPath());
    }

    bool offline() const { return qEnvironmentVariableIsSet("PBOOKORBIT_OFFLINE"); }

    // A setting as the app saved it in its database, e.g. "refreshToken"
    Q_INVOKABLE QString setting(const QString &key) const { return m_objects->database->text(key); }

    // The files in a folder of the device's storage, e.g. "Books", hidden ones too, by name
    Q_INVOKABLE QStringList filesIn(const QString &folder) const
    {
        return QDir(QString::fromUtf8(FLASHDIR "/") + folder).entryList(QDir::Files | QDir::Hidden, QDir::Name);
    }
    void setOffline(bool offline)
    {
        if (offline)
            qputenv("PBOOKORBIT_OFFLINE", "1");
        else
            qunsetenv("PBOOKORBIT_OFFLINE");
    }

    // New objects on a new database, set as the globals main.cpp sets: bookOrbit, downloads
    // and the rest. settings go in the database first, as though the app had been used
    // before, e.g. {serverUrl: "https://books.example.com", username: "reader"}. A
    // refreshToken as well makes a saved session. options:
    //   offline: start with no network (see the offline property)
    //   apps: the system's apps for each format, {epub: [{app: "koreader.app", name:
    //         "KOReader"}]}, for Open with
    //   nightMode: start with the system in night mode
    //   books: book entries saved in the database, as BookOrbit lists them. One with a
    //          file, e.g. "dune.epub", is downloaded: the file is made where downloads go,
    //          Books, or Audio Books for an audiobook. undeletable: true makes a folder
    //          there instead, which deleting the book fails on. details: the book's
    //          details as GET /books/:id gave them, saved for offline.
    //   files: names of book files there that the app hasn't recorded, as though copied
    //          onto the device another way
    //   firmware: the firmware's version, e.g. "U700k3.6.10.2359"; none by default
    //   opened: when the system's reader last opened book files there, or its player last
    //           played audiobook files, by name, e.g. {"dune.epub": "2026-11-14T10:00:00Z"},
    //           in the system's library and audiobook databases. Without it there are none.
    Q_INVOKABLE void reset(const QVariantMap &settings = {}, const QVariantMap &options = {})
    {
        start(std::make_shared<QTemporaryDir>(), settings, options);
    }

    // New objects on the same database and files, as when the app is started again. options
    // as for reset().
    Q_INVOKABLE void restart(const QVariantMap &options = {})
    {
        start(m_objects->dir, {}, options);
    }

private:
    void start(std::shared_ptr<QTemporaryDir> dir, const QVariantMap &settings, const QVariantMap &options)
    {
        auto objects = std::make_unique<Objects>();
        objects->dir = std::move(dir);
        QDir::setCurrent(objects->dir->path());
        objects->database = std::make_unique<Database>(objects->dir->filePath("pbookorbit.db"));
        for (auto it = settings.begin(); it != settings.end(); ++it)
            objects->database->setText(it.key(), it.value().toString());
        for (const QVariant &value : options.value("books").toList())
            saveBook(objects->database.get(), value.toMap());
        for (const QVariant &file : options.value("files").toList())
            makeBookFile(file.toString());
        if (options.contains("opened"))
            makeSystemLibrary(options.value("opened").toMap());
        setOffline(options.value("offline").toBool());
        m_inkview->reset(options.value("apps").toMap(), options.value("nightMode").toBool(),
                         options.value("firmware").toString());
        m_keyboard->reset();
        objects->log = std::make_unique<diagnostics::Log>(objects->database.get());
        objects->client = std::make_unique<BookOrbitClient>(objects->database.get());
        objects->covers = std::make_unique<Covers>(objects->client.get(), objects->dir->filePath("covers"));
        objects->downloads = std::make_unique<Downloads>(objects->client.get(), objects->database.get());
        objects->bookFinder = std::make_unique<BookFinder>(objects->client.get(), objects->downloads.get(),
                                                           objects->database.get());
        // As in the app's main.cpp
        connect(objects->downloads.get(), &Downloads::downloaded, objects->client.get(),
                &BookOrbitClient::loadBookDetails);
        connect(objects->client.get(), &BookOrbitClient::savedBooksChanged, objects->downloads.get(),
                &Downloads::entriesChanged);
        objects->browser = std::make_unique<Browser>();
        // GitHub's releases come from the fake server too, at /releases. The build is
        // 0.9.0 for an Era Color (B300); the firmware option says what it runs.
        objects->updater = std::make_unique<Updater>(m_server->url() + "/releases", "0.9.0", "B300-6.10");
        objects->eink = std::make_unique<Eink>();
        objects->eink->followNightMode();
        objects->launcherTile = std::make_unique<LauncherTile>();

        QQmlContext *context = m_engine->rootContext();
        context->setContextProperty("bookOrbit", objects->client.get());
        context->setContextProperty("covers", objects->covers.get());
        context->setContextProperty("downloads", objects->downloads.get());
        context->setContextProperty("bookFinder", objects->bookFinder.get());
        context->setContextProperty("browser", objects->browser.get());
        context->setContextProperty("updater", objects->updater.get());
        context->setContextProperty("eink", objects->eink.get());
        context->setContextProperty("diagnostics", objects->log.get());
        context->setContextProperty("launcherTile", objects->launcherTile.get());
        // Only now nothing refers to the old ones
        m_objects = std::move(objects);
    }

    static void saveBook(Database *database, QVariantMap entry)
    {
        const int id = entry.value("id").toInt();
        const QString file = entry.take("file").toString();
        const bool undeletable = entry.take("undeletable").toBool();
        const QVariantMap details = entry.take("details").toMap();
        database->saveBook(id, entry);
        if (!details.isEmpty())
            database->saveBookDetails(id, details);
        if (!file.isEmpty())
            database->addBookFile(id, makeBookFile(file, undeletable));
    }

    // The system's library database, explorer-3.db, and the audiobook player's,
    // audiobooks.db, with the tables and columns the app reads, as on firmware 6.10: each
    // named ebook in storage 1 with the default profile's open time, and each audiobook with
    // the time it was last played
    static void makeSystemLibrary(const QVariantMap &opened)
    {
        QStringList books{
            "CREATE TABLE folders(id INTEGER PRIMARY KEY AUTOINCREMENT, storageid INTEGER, name TEXT)",
            "CREATE TABLE files(id INTEGER PRIMARY KEY AUTOINCREMENT, storageid INTEGER, folder_id INTEGER,"
            " book_id INTEGER, filename TEXT)",
            "CREATE TABLE books_settings(bookid INTEGER, profileid INTEGER, opentime INTEGER,"
            " PRIMARY KEY(bookid, profileid))",
        };
        QStringList audiobooks{
            "CREATE TABLE folders(id INTEGER PRIMARY KEY AUTOINCREMENT, storageid INTEGER, name TEXT)",
            "CREATE TABLE files(id INTEGER PRIMARY KEY AUTOINCREMENT, book_id INTEGER, filename TEXT,"
            " folder_id INTEGER)",
            "CREATE TABLE book_state(id INTEGER PRIMARY KEY AUTOINCREMENT, book_id INTEGER,"
            " last_read_ts INTEGER)",
        };

        int id = 0;
        for (auto it = opened.begin(); it != opened.end(); ++it) {
            id++;
            const QString name = QString(it.key()).replace("'", "''");
            const qint64 time = QDateTime::fromString(it.value().toString(), Qt::ISODate).toSecsSinceEpoch();
            if (isAudioFormat(QFileInfo(it.key()).suffix())) {
                audiobooks << QString("INSERT INTO folders VALUES(%1, 1, '%2')").arg(id).arg(AUDIOBOOKS_DEFAULT_PATH)
                           << QString("INSERT INTO files VALUES(%1, %1, '%2', %1)").arg(id).arg(name)
                           << QString("INSERT INTO book_state VALUES(%1, %1, %2)").arg(id).arg(time);
            } else {
                books << QString("INSERT INTO folders VALUES(%1, 1, '%2')").arg(id).arg(FLASHDIR "/Books")
                      << QString("INSERT INTO files VALUES(%1, 1, %1, %1, '%2')").arg(id).arg(name)
                      << QString("INSERT INTO books_settings VALUES(%1, 1, %2)").arg(id).arg(time);
            }
        }

        makeDatabase(QString::fromUtf8(USERDATA "/explorer-3/explorer-3.db"), books);
        makeDatabase(QString::fromUtf8(CONFIGPATH "/audiobooks/audiobooks.db"), audiobooks);
    }

    static void makeDatabase(const QString &file, const QStringList &sql)
    {
        QDir().mkpath(QFileInfo(file).path());
        sqlite3 *db = nullptr;
        if (sqlite3_open(qPrintable(file), &db) != SQLITE_OK)
            qFatal("TestApp: can't make %s", qPrintable(file));
        for (const QString &statement : sql) {
            if (sqlite3_exec(db, qPrintable(statement), nullptr, nullptr, nullptr) != SQLITE_OK)
                qFatal("TestApp: %s", sqlite3_errmsg(db));
        }
        sqlite3_close(db);
    }

    // Makes a book file where Downloads puts it, and returns its path. Relative on the PC
    // build, so in the temporary folder. asFolder makes a folder by that name, which
    // QFile::remove() can't delete.
    static QString makeBookFile(const QString &name, bool asFolder = false)
    {
        const QString folder = QString::fromUtf8(isAudioFormat(QFileInfo(name).suffix()) ? AUDIOBOOKS_DEFAULT_PATH
                                                                                         : FLASHDIR "/Books");
        QDir().mkpath(folder);
        if (asFolder) {
            QDir().mkpath(folder + "/" + name);
            return folder + "/" + name;
        }
        QFile book(folder + "/" + name);
        if (!book.open(QIODevice::WriteOnly) || book.write("test book") < 0)
            qFatal("TestApp: can't write %s", qPrintable(book.fileName()));
        return book.fileName();
    }

    // Members are destroyed in reverse order, so each goes before what it uses, and the
    // folder last, once no restart shares it
    struct Objects {
        std::shared_ptr<QTemporaryDir> dir;
        std::unique_ptr<Database> database;
        std::unique_ptr<diagnostics::Log> log;
        std::unique_ptr<BookOrbitClient> client;
        std::unique_ptr<Covers> covers;
        std::unique_ptr<Downloads> downloads;
        std::unique_ptr<BookFinder> bookFinder;
        std::unique_ptr<Browser> browser;
        std::unique_ptr<Updater> updater;
        std::unique_ptr<Eink> eink;
        std::unique_ptr<LauncherTile> launcherTile;
    };

    QQmlEngine *m_engine;
    FakeServer *m_server;
    FakeInkview *m_inkview;
    FakeKeyboard *m_keyboard;
    std::unique_ptr<Objects> m_objects;
};

// The app's components read globals that main.cpp puts in the root context. The tests get
// the screen size, the image providers and the app's real objects (see TestApp), a fake
// server, inkview, which says what the app asked of the device (see FakeInkview), and
// keyboard, the on-screen keyboard (see FakeKeyboard).
class Setup : public QObject
{
    Q_OBJECT

public slots:
    // The tests load the QML from src/qml, not from the app's compiled resources. Qt's disk
    // cache of it lives in the build folder between runs and isn't refreshed when a
    // component a file uses changes, which can hang a test, so it's off.
    void applicationAvailable()
    {
        qputenv("QML_DISABLE_DISK_CACHE", "1");
    }

    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->addImageProvider("theme", new ThemeImageProvider);
        engine->addImageProvider("inverted", new InvertedImageProvider);
        QQmlContext *context = engine->rootContext();
        context->setContextProperty("dpScale", 1.0);
        context->setContextProperty("screenWidth", 600);
        context->setContextProperty("windowHeight", 800);
        auto *server = new FakeServer(engine);
        context->setContextProperty("fakeServer", server);
        auto *inkview = new FakeInkview(engine);
        context->setContextProperty("inkview", inkview);
        // Not measured from the device: tall enough to cover the sign-in form's password field
        auto *keyboard = new FakeKeyboard(QSizeF(600, 800), 440, engine);
        context->setContextProperty("keyboard", keyboard);
        context->setContextProperty("testApp", new TestApp(engine, server, inkview, keyboard));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(qml, Setup)
#include "main.moc"
