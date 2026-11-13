#include <QDir>
#include <QFile>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickImageProvider>
#include <QTemporaryDir>
#include <QtQuickTest>
#include <inkview.h>
#include <memory>

#include "core/bookfinder.h"
#include "core/bookorbitclient.h"
#include "core/database.h"
#include "core/downloads.h"
#include "fakeserver.h"
#include "ui/covers.h"

// Theme icons come from the device's theme through inkview, which the tests don't start.
// This answers image://theme/<name> with a blank so the components don't warn about it.
class BlankImageProvider : public QQuickImageProvider
{
public:
    BlankImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}
    QImage requestImage(const QString &, QSize *size, const QSize &) override
    {
        QImage image(1, 1, QImage::Format_ARGB32);
        image.fill(Qt::transparent);
        if (size)
            *size = image.size();
        return image;
    }
};

// The app's real objects, made afresh by reset() in a new temporary folder, which is also
// the working directory. On the PC build inkview's paths are relative, so the database,
// downloads, covers and log all stay in there.
class TestApp : public QObject
{
    Q_OBJECT
    // Whether the device has no network, as with make run-offline. Can be changed while
    // the app is open, like turning Wi-Fi off or on.
    Q_PROPERTY(bool offline READ offline WRITE setOffline)

public:
    explicit TestApp(QQmlEngine *engine) : QObject(engine), m_engine(engine) { reset(); }
    ~TestApp() override
    {
        m_objects.reset();
        setOffline(false);
        QDir::setCurrent(QDir::tempPath());
    }

    bool offline() const { return qEnvironmentVariableIsSet("PBOOKORBIT_OFFLINE"); }
    void setOffline(bool offline)
    {
        if (offline)
            qputenv("PBOOKORBIT_OFFLINE", "1");
        else
            qunsetenv("PBOOKORBIT_OFFLINE");
    }

    // New objects on a new database, set as bookOrbit, downloads, covers and bookFinder.
    // settings go in the database first, as though the app had been used before, e.g.
    // {serverUrl: "https://books.example.com", username: "reader"}. A refreshToken as well
    // makes a saved session. options:
    //   offline: start with no network (see the offline property)
    //   books: book entries saved in the database, as BookOrbit lists them. One with a
    //          file, e.g. "dune.epub", is downloaded: the file is made in the Books folder.
    Q_INVOKABLE void reset(const QVariantMap &settings = {}, const QVariantMap &options = {})
    {
        auto objects = std::make_unique<Objects>();
        QDir::setCurrent(objects->dir.path());
        objects->database = std::make_unique<Database>(objects->dir.filePath("pbookorbit.db"));
        for (auto it = settings.begin(); it != settings.end(); ++it)
            objects->database->setText(it.key(), it.value().toString());
        for (const QVariant &value : options.value("books").toList())
            saveBook(objects->database.get(), value.toMap());
        setOffline(options.value("offline").toBool());
        objects->client = std::make_unique<BookOrbitClient>(objects->database.get());
        objects->covers = std::make_unique<Covers>(objects->client.get(), objects->dir.filePath("covers"));
        objects->downloads = std::make_unique<Downloads>(objects->client.get(), objects->database.get());
        objects->bookFinder = std::make_unique<BookFinder>(objects->client.get(), objects->downloads.get(),
                                                           objects->database.get());
        // As in the app's main.cpp
        connect(objects->downloads.get(), &Downloads::downloaded, objects->client.get(),
                &BookOrbitClient::loadBookDetails);
        connect(objects->client.get(), &BookOrbitClient::savedBooksChanged, objects->downloads.get(),
                &Downloads::entriesChanged);

        QQmlContext *context = m_engine->rootContext();
        context->setContextProperty("bookOrbit", objects->client.get());
        context->setContextProperty("covers", objects->covers.get());
        context->setContextProperty("downloads", objects->downloads.get());
        context->setContextProperty("bookFinder", objects->bookFinder.get());
        // Only now nothing refers to the old ones
        m_objects = std::move(objects);
    }

private:
    static void saveBook(Database *database, QVariantMap entry)
    {
        const int id = entry.value("id").toInt();
        const QString file = entry.take("file").toString();
        database->saveBook(id, entry);
        if (file.isEmpty())
            return;
        // Where Downloads puts ebooks; relative on the PC build, so in the temporary folder
        const QString folder = QString::fromUtf8(FLASHDIR "/Books");
        QDir().mkpath(folder);
        QFile book(folder + "/" + file);
        if (!book.open(QIODevice::WriteOnly) || book.write("test book") < 0)
            qFatal("TestApp: can't write %s", qPrintable(book.fileName()));
        database->addBookFile(id, book.fileName());
    }

    // Members are destroyed in reverse order, so each goes before what it uses, and the
    // folder last
    struct Objects {
        QTemporaryDir dir;
        std::unique_ptr<Database> database;
        std::unique_ptr<BookOrbitClient> client;
        std::unique_ptr<Covers> covers;
        std::unique_ptr<Downloads> downloads;
        std::unique_ptr<BookFinder> bookFinder;
    };

    QQmlEngine *m_engine;
    std::unique_ptr<Objects> m_objects;
};

// The app's components read globals that main.cpp puts in the root context. The tests get
// the screen size, the app's real objects (see TestApp), a fake server, and a stand-in from
// stubs/ for each object that drives the device. Add one by writing stubs/<Name>.qml and a
// setStub() line in qmlEngineAvailable().
class Setup : public QObject
{
    Q_OBJECT

public slots:
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->addImageProvider("theme", new BlankImageProvider);
        QQmlContext *context = engine->rootContext();
        context->setContextProperty("dpScale", 1.0);
        context->setContextProperty("screenWidth", 600);
        context->setContextProperty("windowHeight", 800);
        context->setContextProperty("fakeServer", new FakeServer(engine));
        context->setContextProperty("testApp", new TestApp(engine));
        setStub(engine, "eink", "Eink");
        setStub(engine, "diagnostics", "Diagnostics");
        setStub(engine, "browser", "Browser");
        setStub(engine, "launcherTile", "LauncherTile");
    }

private:
    void setStub(QQmlEngine *engine, const char *name, const QString &file)
    {
        QQmlComponent component(engine, QUrl::fromLocalFile(QStringLiteral(QUICK_TEST_SOURCE_DIR "/stubs/") + file + ".qml"));
        QObject *stub = component.create();
        if (!stub)
            qFatal("stubs/%s.qml: %s", qPrintable(file), qPrintable(component.errorString()));
        stub->setParent(engine);
        engine->rootContext()->setContextProperty(QString::fromUtf8(name), stub);
    }
};

QUICK_TEST_MAIN_WITH_SETUP(qml, Setup)
#include "main.moc"
