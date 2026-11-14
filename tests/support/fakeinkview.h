#pragma once

#include <QHash>
#include <QObject>
#include <QVariantList>

// Stand-ins for the inkview calls the app makes that would reach the device or the system:
// opening books and tasks, the library scan, the apps for each format, the theme's icons,
// night mode and the task manager. fakeinkview.cpp defines them, and a test program that
// links it uses them in place of libinkview's; every other inkview call is still the real
// one. One of these, as inkview in QML, says what the app asked for and sets what it's told.
class FakeInkview : public QObject
{
    Q_OBJECT
    // OpenBook() calls: [{path, app}], app being the one SetFileHandler() named for the
    // file, or empty for the reader the system picks
    Q_PROPERTY(QVariantList openedBooks READ openedBooks NOTIFY changed)
    // OpenTask() calls: [{app, args}]
    Q_PROPERTY(QVariantList openedTasks READ openedTasks NOTIFY changed)
    // Library scans asked for with SendEventTo()
    Q_PROPERTY(int libraryScans READ libraryScans NOTIFY changed)

public:
    explicit FakeInkview(QObject *parent = nullptr);
    ~FakeInkview() override;

    // The one in use, which the inkview functions answer from
    static FakeInkview *instance();

    // Forgets what the app asked for, for a newly started app. apps lists the system's
    // apps for each format, {epub: [{app: "koreader.app", name: "KOReader"}]}; nightMode is
    // the system's.
    void reset(const QVariantMap &apps, bool nightMode);

    QVariantList openedBooks() const { return m_openedBooks; }
    QVariantList openedTasks() const { return m_openedTasks; }
    int libraryScans() const { return m_libraryScans; }

    // Used by the inkview functions
    struct FileType {
        QByteArray extension;
        QByteArray programs;   // "koreader.app,eink-reader.app"
    };
    QList<FileType> fileTypes;
    QHash<QByteArray, QByteArray> langTexts;   // "@koreader" -> "KOReader"
    QHash<QByteArray, QString> fileHandlers;   // path -> app, from SetFileHandler()
    bool nightMode = false;
    int appCapabilities = 0;
    void bookOpened(const QString &path, const QString &app);
    void taskOpened(const QString &app, const QStringList &args);
    void libraryScanned();

signals:
    void changed();

private:
    QVariantList m_openedBooks;
    QVariantList m_openedTasks;
    int m_libraryScans = 0;
};
