#include "ui/covers.h"

#include "core/bookorbitclient.h"
#include "core/diagnostics.h"
#include "core/savefile.h"
#include "ui/einkcolors.h"

#include <QBuffer>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QRegularExpression>
#include <QUrl>

// Concurrent downloads: enough to fill a screen quickly without swamping the device
static const int MAX_DOWNLOADS = 3;

Covers::Covers(BookOrbitClient *client, const QString &cacheDir, QObject *parent)
    : QObject(parent)
    , m_client(client)
    , m_cacheDir(cacheDir)
{
    connect(m_client, &BookOrbitClient::onlineChanged, this, [this]() {
        if (!m_client->online())
            return;
        for (const auto &[id, photo] : std::exchange(m_missed, {}))
            emit ready(id, photo);
    });
}

void Covers::missed(const Request &request)
{
    m_missed.insert({request.id, request.photo});
}

static QString shortHash(const QString &text)
{
    return QString::fromLatin1(QCryptographicHash::hash(text.toUtf8(), QCryptographicHash::Sha1).toHex().left(12));
}

QString Covers::folder(const QString &name) const
{
    // 256 folders, so none holds too many files, nor only one or two
    return m_cacheDir + '/' + shortHash(name).left(2);
}

// The hash for a cover asked for without a version
static const QString &noVersionHash()
{
    static const QString hash = shortHash(QString());
    return hash;
}

// A file URL, or "" for no file
static QString fileUrl(const QString &file)
{
    return file.isEmpty() ? QString() : QUrl::fromLocalFile(file).toString();
}

QString Covers::filePath(const QString &name, const QString &rest) const
{
    return QString("%1/%2-%3").arg(folder(name), name, rest);
}

QString Covers::sizedFile(const Request &request) const
{
    // PNG, since JPEG would smear the dithering
    return filePath(request.name, QString("%1-%2x%3.png").arg(request.hash)
                                      .arg(request.size.width()).arg(request.size.height()));
}

QString Covers::sourceFile(const Request &request) const
{
    return filePath(request.name, request.hash + "-source");
}

// What follows "<name>-" in a sized file's name, "<version hash>-<width>x<height>.png", and
// in a download's, "<version hash>-source"
static const QRegularExpression sizedName(R"(^([0-9a-f]{12})-(\d+)x(\d+)\.png$)");
static const QRegularExpression sourceName(R"(^([0-9a-f]{12})-source$)");

QStringList Covers::files(const QString &name) const
{
    QStringList files = QDir(folder(name)).entryList({name + "-*"}, QDir::Files, QDir::Time);
    for (QString &file : files)
        file.remove(0, name.size() + 1);
    return files;
}

QString Covers::downloadedHash(const QString &name) const
{
    // Only one is kept, but the newest wins should a deletion have failed
    for (const QString &file : files(name)) {
        if (const QRegularExpressionMatch match = sourceName.match(file); match.hasMatch())
            return match.captured(1);
    }
    return QString();
}

// Scaled to its display size: photos fill their space like BookOrbit's portraits
// (object-fit: cover; object-position: 50% 26%), cropping the sides equally and the top
// and bottom roughly 1:3, since faces are usually high in a portrait. Covers fit it,
// keeping their aspect ratio.
static QImage fitted(const QImage &image, const QSize &size, bool photo)
{
    if (!photo)
        return image.scaled(size, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    const QImage scaled = image.scaled(size, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
    return scaled.copy((scaled.width() - size.width()) / 2, qRound((scaled.height() - size.height()) * 0.26),
                       size.width(), size.height());
}

QString Covers::source(int bookId, const QString &version, int width, int height)
{
    return fetch({bookId, false, QString("/books/%1/thumbnail").arg(bookId), QSize(width, height),
                  QString::number(bookId), version.isEmpty() ? QString() : shortHash(version)});
}

QString Covers::authorPhoto(int authorId, const QString &imageUrl, int width, int height)
{
    // The path under the API (download() adds the prefix), which must be this author's, so
    // another's photo is never kept as theirs. The query is the version.
    static const QString apiPrefix = "/api/v1";
    if (QUrl(imageUrl).path() != QString("%1/authors/%2/thumbnail").arg(apiPrefix).arg(authorId))
        return QString();
    return fetch({authorId, true, imageUrl.mid(apiPrefix.size()), QSize(width, height),
                  QString("author-%1").arg(authorId), shortHash(QUrl(imageUrl).query())});
}

QString Covers::sizeFrom(const Request &request, const QString &source)
{
    QImage image;
    if (!image.load(source)) {
        // Fetched again next time
        diagnostics::log(source + ": not an image");
        QFile::remove(source);
        return QString();
    }
    image = fitted(image, request.size, request.photo);
    // Adjust for the colour screen, as the system library does for covers
    adjustForEink(image);
    const QString file = sizedFile(request);
    return image.save(file, "PNG") ? file : QString();
}

QString Covers::localCopy(const Request &request)
{
    // A download of another version, named for that version so the current one is still
    // fetched once online
    if (const QString hash = downloadedHash(request.name); !hash.isEmpty()) {
        Request older = request;
        older.hash = hash;
        if (const QString file = sizedFile(older); QFileInfo::exists(file))
            return file;
        if (const QString file = sizeFrom(older, sourceFile(older)); !file.isEmpty())
            return file;
    }
    // Or else the largest size cached, to scale down
    QString largest;
    QString largestHash;
    qint64 largestArea = 0;
    for (const QString &file : files(request.name)) {
        const QRegularExpressionMatch match = sizedName.match(file);
        if (!match.hasMatch())
            continue;
        const qint64 area = match.captured(2).toLongLong() * match.captured(3).toLongLong();
        if (area > largestArea) {
            largest = file;
            largestHash = match.captured(1);
            largestArea = area;
        }
    }
    QImage image;
    if (largest.isEmpty() || !image.load(filePath(request.name, largest)))
        return QString();
    // Already adjusted for the screen. Named for the version it came from, so the current
    // one is still fetched once online.
    Request older = request;
    older.hash = largestHash;
    const QString file = sizedFile(older);
    return fitted(image, request.size, request.photo).save(file, "PNG") ? file : QString();
}

QString Covers::fetch(Request request)
{
    // Not laid out yet: asked again once it has a size
    if (request.size.isEmpty())
        return QString();
    // Without a version, or with one replaced this session, whichever was downloaded
    if (request.hash.isEmpty() || m_replaced.contains(request.name + '/' + request.hash)) {
        const QString downloaded = downloadedHash(request.name);
        if (!downloaded.isEmpty())
            request.hash = downloaded;
        else if (request.hash.isEmpty())
            request.hash = noVersionHash();
    }
    const QString file = sizedFile(request);
    if (QFileInfo::exists(file))
        return fileUrl(file);
    // Downloaded already, for another size
    const QString source = sourceFile(request);
    if (QFileInfo::exists(source))
        return fileUrl(sizeFrom(request, source));
    if (!m_client->online()) {
        missed(request);
        return fileUrl(localCopy(request));
    }
    // One download however many sizes want it
    if (!m_wanted.contains(source)) {
        m_wanted.insert(source);
        m_queue.prepend(request);
        startDownloads();
    }
    return QString();
}

bool Covers::keepDownload(const Request &request, const QByteArray &data)
{
    // Without a version any download will do, so one with a version that arrived meanwhile
    // is kept instead and a list with versions doesn't fetch it again
    if (request.hash == noVersionHash() && !downloadedHash(request.name).isEmpty())
        return true;
    const QString source = sourceFile(request);
    QDir().mkpath(folder(request.name));
    if (const QString error = saveFile(source, data); !error.isEmpty()) {
        diagnostics::log(error);
        return false;
    }
    // Every other version's download and sizes
    for (const QString &file : files(request.name)) {
        if (file.startsWith(request.hash + '-'))
            continue;
        if (const QRegularExpressionMatch match = sourceName.match(file); match.hasMatch())
            m_replaced.insert(request.name + '/' + match.captured(1));
        QFile::remove(filePath(request.name, file));
    }
    return true;
}

void Covers::startDownloads()
{
    while (m_running < MAX_DOWNLOADS && !m_queue.isEmpty()) {
        const Request request = m_queue.takeFirst();
        m_running++;
        m_client->download(request.path,
            [this, request](const QByteArray &data) {
                m_running--;
                m_wanted.remove(sourceFile(request));
                // Kept as it came; QML asks again for its size, which is made from it
                QBuffer buffer;
                buffer.setData(data);
                if (!QImageReader(&buffer).canRead())
                    diagnostics::log(request.path + ": not an image");
                else if (keepDownload(request, data))
                    emit ready(request.id, request.photo);
                startDownloads();
            },
            [this, request](int status, const QString &message) {
                m_running--;
                m_wanted.remove(sourceFile(request));
                if (!m_client->online())
                    missed(request);
                else
                    diagnostics::log(QString("%1: %2 (%3)").arg(request.path, message).arg(status));
                startDownloads();
            });
    }
}
