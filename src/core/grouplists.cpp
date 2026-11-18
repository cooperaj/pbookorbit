#include "core/grouplists.h"
#include "core/bookrecords.h"
#include "core/database.h"
#include "core/details.h"
#include "core/diagnostics.h"
#include "core/session.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QUrl>
#include <algorithm>
#include <limits>

using namespace bookrecords;

// Series and authors page size (the server's maximum)
static const int GROUPS_PAGE_SIZE = 100;

CollectionList::CollectionList(Session *session, Database *database, Details *details,
                               GroupDetails *groupDetails, QObject *parent)
    : GroupList(session, database, details, groupDetails, parent)
{
    m_cacheName = "collections";
    m_detailsKind = "collections";
    m_detailFields = {"authors"};
}

void CollectionList::loadPage(int, int generation)
{
    // [{id, name, icon, displayOrder, bookCount, ...}]: the user's collections and others'
    // public ones, in the user's order
    m_session->callJson("GET", "/collections", QJsonDocument(), [this, generation](const QJsonDocument &doc) {
        if (generation != m_generation)
            return;
        m_rows.clear();
        m_local = false;
        QList<QVariantMap> entries;
        for (const QJsonValue &value : doc.array()) {
            QVariantMap row = value.toObject().toVariantMap();
            entries.append(row);
            row.insert("serverCount", row.value("bookCount"));
            row.insert("covers", QVariantList());
            row.insert("authors", QStringList());
            row.insert("formats", QStringList());
            m_rows.append(withSavedDetails(row));
        }
        m_database->transaction([this, &entries]() { m_database->saveCollections(entries); });
        m_loaded = true;
        pageLoaded(false, {});
    }, [this, generation](const QString &error) {
        if (generation == m_generation)
            setError(error);
    });
}

void CollectionList::lookUp(const QList<int> &ids, int generation)
{
    lookUpCollection(ids.first(), 0, generation);
}

void CollectionList::lookUpCollection(int collectionId, int page, int generation)
{
    // Newest first
    const QJsonObject query{
        {"sort", QJsonArray{QJsonObject{{"field", "collectionOrder"}, {"dir", "desc"}}}},
        {"pagination", QJsonObject{{"page", page}, {"size", LOOKUP_PAGE_SIZE}}},
    };

    // Quiet: this only fills in existing rows
    m_session->request("POST", QString("/collections/%1/books/query").arg(collectionId), QJsonDocument(query),
        [this, collectionId, page, generation](const QByteArray &data) {
            if (generation != m_generation)
                return;
            const QJsonObject result = QJsonDocument::fromJson(data).object();
            const QJsonArray items = result.value("items").toArray();
            m_details->updateSavedBooks(items);
            const bool more = morePages(page, LOOKUP_PAGE_SIZE, result);
            QVariantMap *row = rowWithId(collectionId);
            if (row) {
                // What an earlier lookup found is replaced
                FoundBooks found = page == 0 ? FoundBooks() : FoundBooks::in(*row);
                QVariantList covers = page == 0 ? QVariantList() : row->value("covers").toList();
                QStringList authors = page == 0 ? QStringList() : row->value("authors").toStringList();
                QVariantList bookIds = page == 0 ? QVariantList() : row->value("bookIds").toList();
                for (const QJsonValue &item : items) {
                    const QVariantMap book = item.toObject().toVariantMap();
                    found.add(book, false);
                    bookIds.append(book.value("id"));
                    if (covers.size() < 2 && book.value("hasCover").toBool())
                        covers.append(QVariantMap{{"id", book.value("id")}, {"coverVersion", book.value("coverVersion")}});
                    addNew(authors, book.value("authors").toStringList());
                }
                sortAuthors(authors);
                found.putIn(*row, false, !more);
                row->insert("covers", covers);
                row->insert("authors", authors);
                row->insert("bookIds", bookIds);
                if (!more) {
                    m_lookedUp.insert(collectionId);
                    m_database->transaction([this, collectionId, row, &bookIds]() {
                        m_database->saveCollectionBooks(collectionId, bookIds);
                        saveRowDetails(*row);
                    });
                }
            }
            showLoaded();
            if (more && row)
                lookUpCollection(collectionId, page + 1, generation);
            else
                lookUpNextRows(generation);
        },
        [this, collectionId, generation](int status, const QString &message) {
            diagnostics::log(QString("collection %1 books: %2 (%3)").arg(collectionId).arg(message).arg(status));
            if (generation == m_generation)
                stopLookingUp();
        });
}

void CollectionList::showLocal()
{
    QHash<int, QVariantMap> local;   // book id -> book
    for (const QVariant &value : std::as_const(m_localBooks)) {
        const QVariantMap book = value.toMap();
        local.insert(book.value("id").toInt(), book);
    }

    m_rows.clear();
    for (const Database::Collection &collection : m_database->collections()) {
        // As lookUpCollection() fills them in, from the local books only
        QVariantList covers;
        QStringList authors;
        QStringList formats;
        QStringList bookKeys;
        for (const QVariant &bookId : collection.bookIds) {
            const auto found = local.constFind(bookId.toInt());
            if (found == local.constEnd())
                continue;
            const QVariantMap &book = *found;
            const QString key = companionKey(book);
            addNew(bookKeys, {key});
            if (covers.size() < 2 && book.value("hasCover").toBool())
                covers.append(QVariantMap{{"id", book.value("id")}, {"coverVersion", book.value("coverVersion")}});
            addNew(authors, book.value("authors").toStringList());
            addNew(formats, book.value("downloadedFormats").toStringList());
        }
        if (bookKeys.isEmpty())
            continue;
        sortAuthors(authors);
        sortFormats(formats);
        QVariantMap row = collection.entry;
        row.insert("covers", covers);
        row.insert("authors", authors);
        row.insert("formats", formats);
        // All of them, for the collection's order
        row.insert("bookIds", collection.bookIds);
        row.insert("bookCount", int(bookKeys.size()));
        m_rows.append(row);
    }
    showLocalRows();
}

SeriesList::SeriesList(Session *session, Database *database, Details *details, GroupDetails *groupDetails,
                       QObject *parent)
    : GroupList(session, database, details, groupDetails, parent)
{
    m_cacheName = "series";
    m_detailsKind = "series";
}

void SeriesList::loadPage(int page, int generation)
{
    // {items: [{id, name, bookCount, readCount, authors, coverBookIds (series order),
    // lastAddedAt, ...}], total}. For an author, author= matches any series with an author
    // whose name contains it, ignoring case.
    const bool ofAuthor = !m_author.isEmpty();
    QString path = QString("/series?libraryId=%1&sort=name&order=asc&page=%2&size=%3")
                       .arg(m_session->libraryId()).arg(page).arg(GROUPS_PAGE_SIZE);
    if (ofAuthor)
        path += "&author=" + QString::fromUtf8(QUrl::toPercentEncoding(m_author));

    m_session->callJson("GET", path, QJsonDocument(), [this, ofAuthor, page, generation](const QJsonDocument &doc) {
        if (generation != m_generation)
            return;
        const QJsonObject result = doc.object();
        const QJsonArray items = result.value("items").toArray();
        // The old rows stay until the first page of new ones
        if (page == 0) {
            m_rows.clear();
            m_local = false;
        }
        for (const QJsonValue &value : items) {
            const QJsonObject series = value.toObject();
            QStringList authors = series.value("authors").toVariant().toStringList();
            // Only this author's, not others whose names contain theirs
            if (ofAuthor && !authors.contains(m_author, Qt::CaseInsensitive))
                continue;
            sortAuthors(authors);
            // The list has no cover versions. They come with the series' books.
            QVariantList covers;
            for (const QJsonValue &bookId : series.value("coverBookIds").toArray()) {
                if (covers.size() < 2)
                    covers.append(QVariantMap{{"id", bookId.toInt()}, {"coverVersion", QString()}});
            }
            const int bookCount = series.value("bookCount").toInt();
            m_rows.append(withSavedDetails(QVariantMap{
                {"id", series.value("id").toInt()},
                {"name", series.value("name").toString()},
                {"bookCount", bookCount},
                {"serverCount", bookCount},
                {"covers", covers},
                {"authors", authors},
                {"formats", QStringList()},
                {"books", QVariantMap()},
                {"lastAddedAt", series.value("lastAddedAt").toString()},
                {"readProgress", bookCount > 0 ? series.value("readCount").toDouble() / bookCount : 0.0},
            }));
        }
        m_loaded = true;
        pageLoaded(morePages(page, GROUPS_PAGE_SIZE, result),
                   [this, page, generation]() { loadPage(page + 1, generation); });
    }, [this, generation](const QString &error) {
        if (generation == m_generation)
            setError(error);
    });
}

void SeriesList::lookUp(const QList<int> &ids, int generation)
{
    lookUpByName(ids, false, 0, generation);
}

void SeriesList::showLocal()
{
    QMap<QString, QList<QVariantMap>> booksOf;   // series name -> books
    for (const QVariant &value : std::as_const(m_localBooks)) {
        const QVariantMap book = value.toMap();
        if (!m_author.isEmpty() && !book.value("authors").toStringList().contains(m_author, Qt::CaseInsensitive))
            continue;
        for (const QString &name : seriesNames(book))
            booksOf[name].append(book);
    }

    m_rows.clear();
    for (auto it = booksOf.constBegin(); it != booksOf.constEnd(); ++it) {
        QList<QVariantMap> books = it.value();
        // Series order for the covers, books numbered in another series last
        const QString name = it.key();
        const auto index = [name](const QVariantMap &book) {
            return book.value("seriesName").toString() == name && !book.value("seriesIndex").isNull()
                ? book.value("seriesIndex").toDouble() : std::numeric_limits<double>::max();
        };
        std::stable_sort(books.begin(), books.end(), [index](const QVariantMap &a, const QVariantMap &b) {
            return index(a) < index(b);
        });
        QVariantMap keyed;   // companion key -> formats
        QSet<QString> finished;
        QStringList formats;
        QStringList authors;
        QVariantList covers;
        QString lastAddedAt;
        for (const QVariantMap &book : std::as_const(books)) {
            const QString key = companionKey(book);
            QStringList bookFormats = keyed.value(key).toStringList();
            addNew(bookFormats, book.value("downloadedFormats").toStringList());
            addNew(formats, book.value("downloadedFormats").toStringList());
            keyed.insert(key, bookFormats);
            if (isFinished(book))
                finished.insert(key);
            addNew(authors, book.value("authors").toStringList());
            if (covers.size() < 2 && book.value("hasCover").toBool())
                covers.append(QVariantMap{{"id", book.value("id")}, {"coverVersion", book.value("coverVersion")}});
            lastAddedAt = qMax(lastAddedAt, book.value("addedAt").toString());
        }
        sortFormats(formats);
        sortAuthors(authors);
        m_rows.append(QVariantMap{
            {"id", localId(name)},
            {"name", name},
            {"bookCount", int(keyed.size())},
            {"serverCount", int(keyed.size())},
            {"covers", covers},
            {"authors", authors},
            {"formats", formats},
            {"books", keyed},
            {"lastAddedAt", lastAddedAt},
            {"readProgress", double(finished.size()) / keyed.size()},
        });
    }
    m_allLookedUp = true;
    showLocalRows();
}

AuthorSeriesList::AuthorSeriesList(Session *session, Database *database, Details *details,
                                   GroupDetails *groupDetails, QObject *parent)
    : SeriesList(session, database, details, groupDetails, parent)
{
    // Not cached, as they change with each author shown. Their details are the series'.
    m_cacheName.clear();
    m_partial = true;
}

void AuthorSeriesList::show(const QString &author)
{
    // Don't show the previous author's series while loading
    if (author != m_author) {
        m_rows.clear();
        m_loaded = false;
        GroupList::show();
    }
    m_author = author;
    load();
}

AuthorList::AuthorList(Session *session, Database *database, Details *details, GroupDetails *groupDetails,
                       QObject *parent)
    : GroupList(session, database, details, groupDetails, parent)
{
    m_cacheName = "authors";
    m_detailsKind = "authors";
    // Each book's formats and series, for filtering and the author's page
    m_detailFields = {"seriesCount", "books", "bookSeries"};
}

void AuthorList::setQuery(const QString &sortField, bool descending, const QStringList &formats,
                          bool localOnly)
{
    m_formats = formats;
    m_localOnly = localOnly;
    setSort(sortField, descending);
    lookUpWantedRows();
}

QVariantMap AuthorList::row(int authorId) const
{
    for (const QVariantMap &row : shownRows()) {
        if (row.value("id").toInt() == authorId)
            return row;
    }
    return QVariantMap();
}

void AuthorList::setLocalBooks(const QVariantList &books)
{
    m_localBooks = books;
    if (m_localOnly)
        show();
    GroupList::setLocalBooks(books);
}

void AuthorList::loadPage(int page, int generation)
{
    // {items: [{id, name, sortName, bookCount, lastAddedAt, imageUrl (or null), ...}], total}
    const QString path = QString("/authors?libraryId=%1&sort=name&order=asc&page=%2&size=%3")
                             .arg(m_session->libraryId()).arg(page).arg(GROUPS_PAGE_SIZE);
    m_session->callJson("GET", path, QJsonDocument(), [this, page, generation](const QJsonDocument &doc) {
        if (generation != m_generation)
            return;
        const QJsonObject result = doc.object();
        const QJsonArray items = result.value("items").toArray();
        // The old rows stay until the first page of new ones
        if (page == 0) {
            m_rows.clear();
            m_allLookedUp = false;
            m_local = false;
        }
        QList<QVariantMap> entries;
        for (const QJsonValue &value : items)
            entries.append(value.toObject().toVariantMap());
        m_database->transaction([this, &entries]() { m_database->saveAuthors(entries); });

        for (const QJsonValue &value : items) {
            const QJsonObject author = value.toObject();
            const QString name = author.value("name").toString();
            QString sortName = author.value("sortName").toString();
            if (sortName.isEmpty())
                sortName = authorSortKey(name);
            m_rows.append(withSavedDetails(QVariantMap{
                {"kind", "author"},
                {"id", author.value("id").toInt()},
                {"name", name},
                {"sortName", sortName},
                {"bookCount", author.value("bookCount").toInt()},
                {"serverCount", author.value("bookCount").toInt()},
                {"photo", author.value("imageUrl").toString()},
                {"lastAddedAt", author.value("lastAddedAt").toString()},
                {"formats", QStringList()},
                {"books", QVariantMap()},
                {"bookSeries", QVariantMap()},
                {"seriesCount", -1},
            }));
        }
        m_loaded = true;
        pageLoaded(morePages(page, GROUPS_PAGE_SIZE, result),
                   [this, page, generation]() { loadPage(page + 1, generation); });
    }, [this, generation](const QString &error) {
        if (generation == m_generation)
            setError(error);
    });
}

void AuthorList::lookUp(const QList<int> &ids, int generation)
{
    lookUpByName(ids, true, 0, generation);
}

void AuthorList::showLocal()
{
    QMap<QString, QList<QVariantMap>> booksOf;   // author -> books
    for (const QVariant &value : std::as_const(m_localBooks)) {
        const QVariantMap book = value.toMap();
        for (const QString &author : book.value("authors").toStringList())
            booksOf[author].append(book);
    }

    // Ids, sort names and photos from when they were last fetched
    const QHash<QString, Database::Author> saved = m_database->authorsNamed(booksOf.keys());
    m_rows.clear();
    for (auto it = booksOf.constBegin(); it != booksOf.constEnd(); ++it) {
        const auto found = saved.constFind(it.key());
        // The list entry, or failing that the details, which have the same fields
        QVariantMap entry;
        if (found != saved.constEnd())
            entry = found->entry.isEmpty() ? found->details : found->entry;
        QString sortName = entry.value("sortName").toString();
        if (sortName.isEmpty())
            sortName = authorSortKey(it.key());
        QVariantMap keyed;        // companion key -> formats
        QVariantMap bookSeries;   // companion key -> series
        QHash<QString, QStringList> seriesOfBooks;
        QStringList formats;
        QString lastAddedAt;
        for (const QVariantMap &book : it.value()) {
            const QString key = companionKey(book);
            QStringList bookFormats = keyed.value(key).toStringList();
            addNew(bookFormats, book.value("downloadedFormats").toStringList());
            addNew(formats, book.value("downloadedFormats").toStringList());
            keyed.insert(key, bookFormats);
            QStringList &series = seriesOfBooks[key];
            addNew(series, seriesNames(book));
            bookSeries.insert(key, series);
            lastAddedAt = qMax(lastAddedAt, book.value("addedAt").toString());
        }
        sortFormats(formats);
        m_rows.append(QVariantMap{
            {"kind", "author"},
            {"id", found != saved.constEnd() ? found->id : localId(it.key())},
            {"name", it.key()},
            {"sortName", sortName},
            {"bookCount", int(keyed.size())},
            {"serverCount", int(keyed.size())},
            {"photo", entry.value("imageUrl").toString()},
            {"lastAddedAt", lastAddedAt},
            {"formats", formats},
            {"books", keyed},
            {"bookSeries", bookSeries},
            {"seriesCount", seriesCount(seriesOfBooks)},
        });
    }
    m_allLookedUp = true;
    showLocalRows();
}

QList<QVariantMap> AuthorList::filtered(const QList<QVariantMap> &rows) const
{
    if (m_formats.isEmpty() && !m_localOnly)
        return rows;

    // Only authors with books in the chosen formats (or local ones, with localOnly), counting
    // just those books and showing their formats, as the filtered book list does. Authors
    // whose books aren't looked up yet wait.
    QHash<QString, QHash<QString, QStringList>> downloaded;         // author -> key -> formats
    QHash<QString, QHash<QString, QStringList>> downloadedSeries;   // author -> key -> series
    for (const QVariant &value : std::as_const(m_localBooks)) {
        const QVariantMap book = value.toMap();
        bool wanted = m_formats.isEmpty();
        for (const QString &format : book.value("downloadedFormats").toStringList())
            wanted = wanted || m_formats.contains(format);
        if (!wanted)
            continue;
        for (const QString &author : book.value("authors").toStringList()) {
            QStringList &formats = downloaded[author][companionKey(book)];
            addNew(formats, ownFormats(book));
            QStringList &series = downloadedSeries[author][companionKey(book)];
            addNew(series, seriesNames(book));
        }
    }

    QList<QVariantMap> shown;
    for (QVariantMap row : rows) {
        // Matching books by key, with their formats and series
        QHash<QString, QStringList> wantedBooks;
        QHash<QString, QStringList> wantedSeries;
        if (m_localOnly) {
            wantedBooks = downloaded.value(row.value("name").toString());
            wantedSeries = downloadedSeries.value(row.value("name").toString());
        } else {
            const QVariantMap books = row.value("books").toMap();
            const QVariantMap bookSeries = row.value("bookSeries").toMap();
            for (auto it = books.constBegin(); it != books.constEnd(); ++it) {
                const QStringList formats = it.value().toStringList();
                bool wanted = false;
                for (const QString &format : formats)
                    wanted = wanted || m_formats.contains(format);
                if (wanted) {
                    wantedBooks.insert(it.key(), formats);
                    wantedSeries.insert(it.key(), bookSeries.value(it.key()).toStringList());
                }
            }
        }
        if (wantedBooks.isEmpty())
            continue;
        QStringList formats;
        for (const QStringList &bookFormats : std::as_const(wantedBooks))
            addNew(formats, bookFormats);
        sortFormats(formats);
        row.insert("bookCount", int(wantedBooks.size()));
        row.insert("seriesCount", seriesCount(wantedSeries));
        row.insert("formats", formats);
        shown.append(row);
    }
    return shown;
}
