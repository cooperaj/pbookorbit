#include "core/systemlibrary.h"

#include "core/diagnostics.h"

#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <inkview.h>
#include <memory>
#include <sqlite3.h>

namespace systemlibrary {

// Firmware the schemas below were checked on, as "major.minor"
static const QStringList CHECKED_FIRMWARE{"6.10"};

// The system's library, and the audiobook player's own
static const char *LIBRARY_DB = USERDATA "/explorer-3/explorer-3.db";
static const char *AUDIOBOOKS_DB = CONFIGPATH "/audiobooks/audiobooks.db";

QString firmwareVersion()
{
    const char *version = GetSoftwareVersion();
    return version ? QString::fromUtf8(version) : QString();
}

QString firmwareRelease()
{
    // "U700k3.6.10.2359": model, then major.minor.build
    static const QRegularExpression release(R"((\d+\.\d+)\.\d+$)");
    return release.match(firmwareVersion()).captured(1);
}

bool supported()
{
    return CHECKED_FIRMWARE.contains(firmwareRelease());
}

// Each ebook file on the device's storage (storage 1; cloud copies have no folder), as its
// folder and name, with the time the default profile last opened it, if it has been
static const char *OPENED_BOOKS_SQL =
    "SELECT folders.name || '/' || files.filename, books_settings.opentime"
    " FROM files"
    " JOIN folders ON folders.id = files.folder_id"
    " JOIN books_settings ON books_settings.bookid = files.book_id"
    " WHERE files.storageid = 1 AND books_settings.profileid = 1 AND books_settings.opentime > 0";

// Each audiobook file, with the time it was last played (set when playing starts)
static const char *PLAYED_AUDIOBOOKS_SQL =
    "SELECT folders.name || '/' || files.filename, book_state.last_read_ts"
    " FROM files"
    " JOIN folders ON folders.id = files.folder_id"
    " JOIN book_state ON book_state.book_id = files.book_id"
    " WHERE book_state.last_read_ts > 0";

// Close the database and free the query however the function returns
using Database = std::unique_ptr<sqlite3, decltype(&sqlite3_close)>;
using Query = std::unique_ptr<sqlite3_stmt, decltype(&sqlite3_finalize)>;

// Adds the wanted files' times from one database's query (path, Unix seconds) to times,
// keeping the latest of each. False if it couldn't be read, or only in part.
static bool readTimes(const char *file, const char *sql, const QSet<QString> &wanted,
                      QHash<QString, qint64> &times)
{
    if (!QFileInfo::exists(QString::fromUtf8(file)))
        return false;

    // Read-only: the system writes it (in WAL mode) while we read
    sqlite3 *handle = nullptr;
    const int opened = sqlite3_open_v2(file, &handle, SQLITE_OPEN_READONLY, nullptr);
    Database db(handle, &sqlite3_close);
    if (opened != SQLITE_OK) {
        diagnostics::log(QString("system library: can't open %1 (%2)").arg(file, sqlite3_errmsg(db.get())));
        return false;
    }
    sqlite3_busy_timeout(db.get(), 500);

    sqlite3_stmt *statement = nullptr;
    const int prepared = sqlite3_prepare_v2(db.get(), sql, -1, &statement, nullptr);
    Query query(statement, &sqlite3_finalize);
    if (prepared != SQLITE_OK) {
        diagnostics::log(QString("system library: unexpected schema in %1 (%2)").arg(file, sqlite3_errmsg(db.get())));
        return false;
    }

    // Collected apart, so a read cut short (the system busy writing, say) adds nothing
    QHash<QString, qint64> found;
    int step;
    while ((step = sqlite3_step(query.get())) == SQLITE_ROW) {
        const auto text = reinterpret_cast<const char *>(sqlite3_column_text(query.get(), 0));
        const QString path = QString::fromUtf8(text);
        if (wanted.contains(path))
            found.insert(path, qMax(found.value(path), sqlite3_column_int64(query.get(), 1)));
    }
    if (step != SQLITE_DONE)
        return false;

    for (auto it = found.cbegin(); it != found.cend(); ++it)
        times.insert(it.key(), qMax(times.value(it.key()), it.value()));
    return true;
}

std::optional<QHash<QString, qint64>> lastOpened(const QStringList &paths)
{
    if (!supported())
        return std::nullopt;

    // Ebooks from the library, audiobooks from the player's. Either is enough.
    const QSet<QString> wanted(paths.cbegin(), paths.cend());
    QHash<QString, qint64> times;
    const bool books = readTimes(LIBRARY_DB, OPENED_BOOKS_SQL, wanted, times);
    const bool audiobooks = readTimes(AUDIOBOOKS_DB, PLAYED_AUDIOBOOKS_SQL, wanted, times);
    if (!books && !audiobooks)
        return std::nullopt;
    return times;
}

}
