#include <QDir>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickImageProvider>
#include <QTemporaryDir>
#include <QtQuickTest>
#include <memory>

#include "core/bookorbitclient.h"
#include "core/database.h"
#include "fakeserver.h"

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
// downloads and log all stay in there.
class TestApp : public QObject
{
    Q_OBJECT

public:
    explicit TestApp(QQmlEngine *engine) : QObject(engine), m_engine(engine) { reset(); }
    ~TestApp() override
    {
        m_client.reset();
        m_database.reset();
        QDir::setCurrent(QDir::tempPath());
    }

    // A new client with an empty database, as on first start, and set as bookOrbit
    Q_INVOKABLE void reset()
    {
        auto dir = std::make_unique<QTemporaryDir>();
        QDir::setCurrent(dir->path());
        auto database = std::make_unique<Database>(dir->filePath("pbookorbit.db"));
        auto client = std::make_unique<BookOrbitClient>(database.get());
        m_engine->rootContext()->setContextProperty("bookOrbit", client.get());
        // Only now nothing refers to the old ones
        m_client = std::move(client);
        m_database = std::move(database);
        m_dir = std::move(dir);
    }

private:
    QQmlEngine *m_engine;
    // Destroyed in reverse order: the client before its database, both before the folder
    std::unique_ptr<QTemporaryDir> m_dir;
    std::unique_ptr<Database> m_database;
    std::unique_ptr<BookOrbitClient> m_client;
};

// The app's components read globals that main.cpp puts in the root context. The tests get
// dpScale, the real BookOrbitClient (see TestApp), a fake server, and a stand-in from
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
        context->setContextProperty("fakeServer", new FakeServer(engine));
        context->setContextProperty("testApp", new TestApp(engine));
        setStub(engine, "eink", "Eink");
        setStub(engine, "diagnostics", "Diagnostics");
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
