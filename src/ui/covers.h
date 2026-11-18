#pragma once

#include <QList>
#include <QObject>
#include <QSet>
#include <QSize>
#include <QString>
#include <QStringList>

class Session;

// Cover thumbnails for book lists and photos for the authors list. Downloads a book's
// thumbnail (GET /books/:id/thumbnail, about 100 KB) or an author's (GET
// /authors/:id/thumbnail) once per version and keeps it as it came. Each display size is
// made from that: scaled (photos cropped to fill, as BookOrbit does), its colours adjusted
// for the screen (einkcolors.h), and cached as a PNG.
//
// Only one version of each is kept, as downloading a new one deletes the old one's files.
//
// QML calls source() or authorPhoto() (see CoversImage.qml). If the image hasn't been
// downloaded, it returns empty, starts a download and emits ready(id, photo) when done.
// Offline it doesn't download, and emits ready() once back online so QML asks again.
// Meanwhile it uses a download of another version, or rescales a copy cached at another
// size, if any.
class Covers : public QObject
{
    Q_OBJECT

public:
    Covers(Session *session, const QString &cacheDir, QObject *parent = nullptr);

    // File URL of the cached cover, or "" while downloading. version is the book's
    // coverVersion, so changed covers are fetched again. Without one (the series list
    // has none), whichever version was downloaded is used.
    Q_INVOKABLE QString source(int bookId, const QString &version, int width, int height);
    // Same for an author's photo. imageUrl comes from the authors list and includes the
    // path and version, e.g. "/api/v1/authors/7/thumbnail?t=1788298235776"
    Q_INVOKABLE QString authorPhoto(int authorId, const QString &imageUrl, int width, int height);

signals:
    // The book's cover, or the author's photo, can be asked for again
    void ready(int id, bool photo);

private:
    struct Request {
        // A book's id and its cover, or an author's id and their photo
        int id;
        bool photo;
        QString path;
        QSize size;
        QString name;   // see folder()
        // shortHash() of the version, or empty for whichever was downloaded
        QString hash;
    };

    // The folder for a cover or photo's files, one of 256 picked by the name's hash. name is
    // "<bookId>" for a cover or "author-<authorId>" for a photo.
    QString folder(const QString &name) const;
    // A file of the name's in its folder, "<name>-<rest>"
    QString filePath(const QString &name, const QString &rest) const;
    // A size made for the screen, "<name>-<version hash>-<width>x<height>.png"
    QString sizedFile(const Request &request) const;
    // The download, as it came (JPEG or PNG), "<name>-<version hash>-source"
    QString sourceFile(const Request &request) const;
    // The name's files in its folder, newest first, without the "<name>-"
    QStringList files(const QString &name) const;
    // The version hash of the name's download, or "" if there's none
    QString downloadedHash(const QString &name) const;
    // Makes the request's size from a download. Returns the file, or "" if it failed.
    QString sizeFrom(const Request &request, const QString &source);
    // Offline, makes the request's size from a download of another version or rescales the
    // largest copy cached. Returns "" if there's neither.
    QString localCopy(const Request &request);
    // Cached file URL, or "" while downloading
    QString fetch(Request request);
    void startDownloads();
    // Saves a download and deletes the files of any other version, unless it has no version
    // and one with a version is there. Returns whether it can be asked for again.
    bool keepDownload(const Request &request, const QByteArray &data);
    // Notes a cover or photo to ask for again once online
    void missed(const Request &request);

    Session *m_session;
    QString m_cacheDir;
    // Newest requests first, so covers on screen beat ones already scrolled past
    QList<Request> m_queue;
    QSet<QString> m_wanted;
    int m_running = 0;
    // Wanted while offline, as {id, photo}
    QSet<std::pair<int, bool>> m_missed;
    // Versions deleted this session for a newer download, as "<name>/<version hash>". A
    // list loaded before the change still asks for them, and gets the newer one, rather
    // than fetching it again and deleting the newer one in turn.
    QSet<QString> m_replaced;
};
