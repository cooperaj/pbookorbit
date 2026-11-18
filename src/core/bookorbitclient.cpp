#include "core/bookorbitclient.h"
#include "core/bookrecords.h"
#include "core/database.h"
#include "core/diagnostics.h"

#include <QDateTime>
#include <QJsonArray>
#include <QJsonObject>
#include <QTimer>
#include <QUrl>
#include <algorithm>
#include <limits>

// Books per request when looking up the books of collections, series or authors
static const int LOOKUP_PAGE_SIZE = 200;

using bookrecords::addNew;
using bookrecords::authorSortKey;
using bookrecords::companionKey;
using bookrecords::group;
using bookrecords::isFinished;
using bookrecords::letterSection;
using bookrecords::morePages;
using bookrecords::ownFormats;
using bookrecords::rule;
using bookrecords::seriesNames;
using bookrecords::sortAuthors;
using bookrecords::sortFormats;

BookOrbitClient::BookOrbitClient(Database *database, QObject *parent)
    : QObject(parent)
    , m_database(database)
    , m_session(database)
    , m_theme(&m_session, database)
    , m_recentSearches(&m_session, database)
    , m_details(&m_session, database)
    , m_library(&m_session, database, &m_details)
    , m_search(&m_session, database, &m_details)
    , m_booksOf(&m_session, database, &m_details)
{
    // Connected before QML's handlers, so the lists are ready for them
    connect(&m_session, &Session::started, this, &BookOrbitClient::start);
    connect(&m_session, &Session::ended, this, &BookOrbitClient::clearLists);
    connect(&m_session, &Session::onlineChanged, this, [this]() {
        if (m_session.online())
            forgetLocalRows();
    });

    m_collections.lookup = Lookup::Collection;
    m_collections.cacheName = "collections";
    m_collections.detailsKind = "collections";
    m_collections.detailFields = {"authors"};
    m_series.cacheName = "series";
    m_series.detailsKind = "series";
    // Not cached, as they change with each author shown. Their details are the series'.
    m_authorSeries.detailsKind = "series";
    m_authorSeries.partial = true;
    m_authors.lookup = Lookup::Authors;
    m_authors.cacheName = "authors";
    m_authors.detailsKind = "authors";
    // Each book's formats and series, for filtering and the author's page
    m_authors.detailFields = {"seriesCount", "books", "bookSeries"};
}

void BookOrbitClient::start()
{
    // The first request gets an access token from the saved session
    if (m_session.signedIn()) {
        m_library.reload();
        m_theme.load();
    }
}

// How many series a group's books are in, books being key -> series names
static int seriesCount(const QHash<QString, QStringList> &bookSeries)
{
    QSet<QString> series;
    for (const QStringList &names : bookSeries) {
        for (const QString &name : names)
            series.insert(name);
    }
    return int(series.size());
}

// The books a lookup has found for a group row so far: each book's formats by its companion
// key, so a separate ebook and audiobook count once, and for an author the series each is in
struct FoundBooks {
    QHash<QString, QStringList> formatsOf;
    QHash<QString, QStringList> seriesOf;
    QStringList formats;

    // What earlier pages of the same lookup found
    static FoundBooks in(const QVariantMap &row)
    {
        FoundBooks found;
        const QVariantMap books = row.value("books").toMap();
        for (auto it = books.constBegin(); it != books.constEnd(); ++it)
            found.formatsOf.insert(it.key(), it.value().toStringList());
        const QVariantMap bookSeries = row.value("bookSeries").toMap();
        for (auto it = bookSeries.constBegin(); it != bookSeries.constEnd(); ++it)
            found.seriesOf.insert(it.key(), it.value().toStringList());
        found.formats = row.value("formats").toStringList();
        return found;
    }

    void add(const QVariantMap &book, bool withSeries)
    {
        const QString key = companionKey(book);
        addNew(formatsOf[key], ownFormats(book));
        addNew(formats, ownFormats(book));
        if (withSeries)
            addNew(seriesOf[key], seriesNames(book));
    }

    // Sets the row's books, formats and, withSeries, bookSeries. Once complete, its counts
    // too.
    void putIn(QVariantMap &row, bool withSeries, bool complete) const
    {
        QVariantMap books;
        for (auto it = formatsOf.constBegin(); it != formatsOf.constEnd(); ++it)
            books.insert(it.key(), it.value());
        row.insert("books", books);
        QStringList sorted = formats;
        sortFormats(sorted);
        row.insert("formats", sorted);
        if (withSeries) {
            QVariantMap bookSeries;
            for (auto it = seriesOf.constBegin(); it != seriesOf.constEnd(); ++it)
                bookSeries.insert(it.key(), it.value());
            row.insert("bookSeries", bookSeries);
        }
        if (!complete || formatsOf.isEmpty())
            return;
        row.insert("bookCount", int(formatsOf.size()));
        if (withSeries)
            row.insert("seriesCount", seriesCount(seriesOf));
    }
};

// A row's covers, with the versions known for their books
static QVariantList withCoverVersions(QVariantList covers, const QHash<int, QVariant> &versions)
{
    for (QVariant &cover : covers) {
        QVariantMap map = cover.toMap();
        if (versions.contains(map.value("id").toInt()))
            map.insert("coverVersion", versions.value(map.value("id").toInt()));
        cover = map;
    }
    return covers;
}

// The row with this id, or nullptr
static QVariantMap *rowWithId(QList<QVariantMap> &rows, int id)
{
    for (QVariantMap &row : rows) {
        if (row.value("id").toInt() == id)
            return &row;
    }
    return nullptr;
}

void BookOrbitClient::loadCollections()
{
    const int generation = startLoad(m_collections);
    if (!m_session.online()) {
        showLocalCollections();
        return;
    }
    restoreList(m_collections);
    // [{id, name, icon, displayOrder, bookCount, ...}]: the user's collections and others'
    // public ones, in the user's order
    m_session.callJson("GET", "/collections", QJsonDocument(), [this, generation](const QJsonDocument &doc) {
        if (generation != m_collections.generation)
            return;
        m_collections.rows.clear();
        m_collections.local = false;
        QList<QVariantMap> entries;
        for (const QJsonValue &value : doc.array()) {
            QVariantMap row = value.toObject().toVariantMap();
            entries.append(row);
            row.insert("serverCount", row.value("bookCount"));
            row.insert("covers", QVariantList());
            row.insert("authors", QStringList());
            row.insert("formats", QStringList());
            m_collections.rows.append(withSavedDetails(m_collections, row));
        }
        m_database->transaction([this, &entries]() { m_database->saveCollections(entries); });
        m_collections.loaded = true;
        listPageLoaded(m_collections, false, {});
    }, [this, generation](const QString &error) {
        if (generation == m_collections.generation)
            setListError(m_collections, error);
    });
}

void BookOrbitClient::lookUpCollection(int collectionId, int page, int generation)
{
    // Newest first
    const QJsonObject query{
        {"sort", QJsonArray{QJsonObject{{"field", "collectionOrder"}, {"dir", "desc"}}}},
        {"pagination", QJsonObject{{"page", page}, {"size", LOOKUP_PAGE_SIZE}}},
    };
    // Quiet: this only fills in existing rows
    m_session.request("POST", QString("/collections/%1/books/query").arg(collectionId), QJsonDocument(query),
        [this, collectionId, page, generation](const QByteArray &data) {
            if (generation != m_collections.generation)
                return;
            const QJsonObject result = QJsonDocument::fromJson(data).object();
            const QJsonArray items = result.value("items").toArray();
            m_details.updateSavedBooks(items);
            const bool more = morePages(page, LOOKUP_PAGE_SIZE, result);
            QVariantMap *row = rowWithId(m_collections.rows, collectionId);
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
                    m_collections.lookedUp.insert(collectionId);
                    m_database->transaction([this, collectionId, row, &bookIds]() {
                        m_database->saveCollectionBooks(collectionId, bookIds);
                        saveRowDetails(m_collections, *row);
                    });
                }
            }
            showLoadedGroups(m_collections);
            if (more && row)
                lookUpCollection(collectionId, page + 1, generation);
            else
                lookUpNextRows(&m_collections, generation);
        },
        [this, collectionId, generation](int status, const QString &message) {
            diagnostics::log(QString("collection %1 books: %2 (%3)").arg(collectionId).arg(message).arg(status));
            if (generation == m_collections.generation)
                stopLookingUp(m_collections);
        });
}

void BookOrbitClient::setCollectionSort(const QString &field, bool descending)
{
    m_collections.sort = field;
    m_collections.descending = descending;
    showGroups(m_collections);
}

// Series page size (the server's maximum)
static const int SERIES_PAGE_SIZE = 100;
// Maximum values in one filter rule, e.g. series names
static const int MAX_RULE_VALUES = 20;

void BookOrbitClient::loadSeries()
{
    const int generation = startLoad(m_series);
    if (!m_session.online()) {
        showLocalSeries(m_series);
        return;
    }
    restoreList(m_series);
    loadWithLibrary(m_series, generation, [this, generation]() { loadSeriesPage(&m_series, 0, generation); });
}

void BookOrbitClient::lookUpRows(BookListModel *model, int first, int last)
{
    for (Groups *groups : {&m_collections, &m_series, &m_authors, &m_authorSeries}) {
        if (&groups->model == model)
            wantRows(*groups, first, last);
    }
}

void BookOrbitClient::showAuthorSeries(const QString &author)
{
    const int generation = startLoad(m_authorSeries);
    // Don't show the previous author's series while loading
    if (author != m_authorSeriesName) {
        m_authorSeries.rows.clear();
        m_authorSeries.loaded = false;
        showGroups(m_authorSeries);
    }
    m_authorSeriesName = author;
    if (!m_session.online()) {
        showLocalSeries(m_authorSeries);
        return;
    }
    loadWithLibrary(m_authorSeries, generation, [this, generation]() { loadSeriesPage(&m_authorSeries, 0, generation); });
}

void BookOrbitClient::setAuthorSeriesSort(const QString &field, bool descending)
{
    m_authorSeries.sort = field;
    m_authorSeries.descending = descending;
    showGroups(m_authorSeries);
}

QVariantMap BookOrbitClient::authorRow(int authorId) const
{
    for (const QVariantMap &row : shownRows(m_authors)) {
        if (row.value("id").toInt() == authorId)
            return row;
    }
    return QVariantMap();
}

void BookOrbitClient::loadSeriesPage(Groups *groups, int page, int generation)
{
    // {items: [{id, name, bookCount, readCount, authors, coverBookIds (series order),
    // lastAddedAt, ...}], total}. For an author, author= matches any series with an author
    // whose name contains it, ignoring case.
    const bool ofAuthor = groups == &m_authorSeries;
    QString path = QString("/series?libraryId=%1&sort=name&order=asc&page=%2&size=%3")
                       .arg(m_session.libraryId()).arg(page).arg(SERIES_PAGE_SIZE);
    if (ofAuthor)
        path += "&author=" + QString::fromUtf8(QUrl::toPercentEncoding(m_authorSeriesName));
    m_session.callJson("GET", path, QJsonDocument(), [this, groups, ofAuthor, page, generation](const QJsonDocument &doc) {
        if (generation != groups->generation)
            return;
        const QJsonObject result = doc.object();
        const QJsonArray items = result.value("items").toArray();
        // The old rows stay until the first page of new ones
        if (page == 0) {
            groups->rows.clear();
            groups->local = false;
        }
        for (const QJsonValue &value : items) {
            const QJsonObject series = value.toObject();
            QStringList authors = series.value("authors").toVariant().toStringList();
            // Only this author's, not others whose names contain theirs
            if (ofAuthor && !authors.contains(m_authorSeriesName, Qt::CaseInsensitive))
                continue;
            sortAuthors(authors);
            // The list has no cover versions. They come with the series' books.
            QVariantList covers;
            for (const QJsonValue &bookId : series.value("coverBookIds").toArray()) {
                if (covers.size() < 2)
                    covers.append(QVariantMap{{"id", bookId.toInt()}, {"coverVersion", QString()}});
            }
            const int bookCount = series.value("bookCount").toInt();
            groups->rows.append(withSavedDetails(*groups, QVariantMap{
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
        groups->loaded = true;
        listPageLoaded(*groups, morePages(page, SERIES_PAGE_SIZE, result),
                       [this, groups, page, generation]() { loadSeriesPage(groups, page + 1, generation); });
    }, [this, groups, generation](const QString &error) {
        if (generation == groups->generation)
            setListError(*groups, error);
    });
}

void BookOrbitClient::wantRows(Groups &groups, int first, int last)
{
    groups.wantedFirst = first;
    groups.wantedLast = last;
    lookUpWantedRows(groups);
}

void BookOrbitClient::lookUpWantedRows(Groups &groups)
{
    // Only once the list has loaded, and not for rows built offline
    if (!m_session.online() || groups.local || !groups.loaded || !groups.cached.isEmpty())
        return;
    QList<int> ids;
    for (int i = qMax(0, groups.wantedFirst); i <= groups.wantedLast && i < groups.model.count(); i++) {
        const int id = groups.model.book(i).value("id").toInt();
        if (!groups.lookedUp.contains(id))
            ids.append(id);
    }
    // Filtering authors by format needs every author's books, those in view first
    if (filteringByFormat(groups)) {
        QSet<int> queued(ids.cbegin(), ids.cend());
        for (const QVariantMap &row : std::as_const(groups.rows)) {
            const int id = row.value("id").toInt();
            if (!groups.lookedUp.contains(id) && !queued.contains(id))
                ids.append(id);
        }
    }
    queueLookUps(&groups, ids);
}

void BookOrbitClient::queueLookUps(Groups *groups, const QList<int> &ids)
{
    groups->wanted = ids;
    if (groups->lookingUpGeneration != groups->generation)
        lookUpNextRows(groups, groups->generation);
}

void BookOrbitClient::lookUpNextRows(Groups *groups, int generation)
{
    groups->lookingUpGeneration = -1;
    // As many as fit in one request. That's a collection on its own, or series or authors
    // with up to a page of books between them, at least one and at most a rule's worth.
    const bool collections = groups->lookup == Lookup::Collection;
    // Every author may be waiting, so not a search of the rows for each
    QHash<int, const QVariantMap *> rowsById;
    for (const QVariantMap &row : std::as_const(groups->rows))
        rowsById.insert(row.value("id").toInt(), &row);
    QList<int> ids;
    int books = 0;
    while (!groups->wanted.isEmpty()) {
        const int id = groups->wanted.first();
        const QVariantMap *row = rowsById.value(id);
        // An empty collection has nothing to look up
        if (!row || groups->lookedUp.contains(id) || (collections && row->value("serverCount").toInt() == 0)) {
            groups->wanted.removeFirst();
            continue;
        }
        const int count = row->value("serverCount").toInt();
        if (!ids.isEmpty() && (collections || books + count > LOOKUP_PAGE_SIZE || ids.size() == MAX_RULE_VALUES))
            break;
        ids.append(groups->wanted.takeFirst());
        books += count;
    }
    if (ids.isEmpty()) {
        const bool allLookedUp = groups->lookedUp.size() >= groups->rows.size();
        if (allLookedUp != groups->allLookedUp) {
            groups->allLookedUp = allLookedUp;
            emitChanged(*groups);
        }
        return;
    }
    groups->lookingUpGeneration = generation;
    if (collections)
        lookUpCollection(ids.first(), 0, generation);
    else
        lookUpByName(groups, ids, 0, generation);
}

void BookOrbitClient::stopLookingUp(Groups &groups)
{
    // Tried again when next wanted
    groups.lookingUpGeneration = -1;
    groups.wanted.clear();
}

void BookOrbitClient::saveRowDetails(const Groups &groups, const QVariantMap &row)
{
    if (groups.detailsKind.isEmpty())
        return;
    QVariantMap details;
    for (const QString &field : QStringList{"bookCount", "formats", "covers"} + groups.detailFields)
        details.insert(field, row.value(field));
    const int id = row.value("id").toInt();
    savedDetails(groups.detailsKind).insert(id, details);
    m_database->saveGroupDetails(groups.detailsKind, id, details);
}

void BookOrbitClient::lookUpByName(Groups *groups, const QList<int> &ids, int page, int generation)
{
    const bool series = groups->lookup == Lookup::Series;
    QStringList names;
    for (const int id : ids) {
        if (const QVariantMap *row = rowWithId(groups->rows, id))
            names.append(row->value("name").toString());
    }
    const QJsonObject query{
        {"filter", group("AND", {rule(series ? "series" : "author", "includesAny", QJsonArray::fromStringList(names))})},
        {"pagination", QJsonObject{{"page", page}, {"size", LOOKUP_PAGE_SIZE}}},
    };
    // Quiet: this only fills in existing rows
    m_session.request("POST", libraryBooksPath(), QJsonDocument(query),
        [this, groups, series, ids, page, generation](const QByteArray &data) {
            if (generation != groups->generation)
                return;
            const QJsonObject result = QJsonDocument::fromJson(data).object();
            const QJsonArray items = result.value("items").toArray();
            m_details.updateSavedBooks(items);
            const bool more = morePages(page, LOOKUP_PAGE_SIZE, result);
            // What earlier pages found for each row, by name. A first page replaces what an
            // earlier lookup found.
            QHash<QString, int> idNamed;
            QHash<int, FoundBooks> found;
            for (const int id : ids) {
                if (const QVariantMap *row = rowWithId(groups->rows, id)) {
                    idNamed.insert(row->value("name").toString(), id);
                    found.insert(id, page == 0 ? FoundBooks() : FoundBooks::in(*row));
                }
            }
            QHash<int, QVariant> coverVersions;
            for (const QJsonValue &item : items) {
                const QVariantMap book = item.toObject().toVariantMap();
                coverVersions.insert(book.value("id").toInt(), book.value("coverVersion"));
                // Every series a book is in, or every author it has
                for (const QString &name : series ? seriesNames(book) : book.value("authors").toStringList()) {
                    if (idNamed.contains(name))
                        found[idNamed.value(name)].add(book, !series);
                }
            }
            QList<const QVariantMap *> complete;
            for (auto it = found.constBegin(); it != found.constEnd(); ++it) {
                QVariantMap *row = rowWithId(groups->rows, it.key());
                it.value().putIn(*row, !series, !more);
                row->insert("covers", withCoverVersions(row->value("covers").toList(), coverVersions));
                if (!more) {
                    groups->lookedUp.insert(it.key());
                    complete.append(row);
                }
            }
            m_database->transaction([&]() {
                for (const QVariantMap *row : std::as_const(complete))
                    saveRowDetails(*groups, *row);
            });
            showLoadedGroups(*groups);
            if (more)
                lookUpByName(groups, ids, page + 1, generation);
            else
                lookUpNextRows(groups, generation);
        },
        [this, groups, generation](int status, const QString &message) {
            diagnostics::log(QString("series or author books: %1 (%2)").arg(message).arg(status));
            if (generation == groups->generation)
                stopLookingUp(*groups);
        });
}

void BookOrbitClient::forgetGoneDetails(Groups &groups)
{
    if (groups.detailsKind.isEmpty() || groups.partial)
        return;
    QSet<int> ids;
    for (const QVariantMap &row : std::as_const(groups.rows))
        ids.insert(row.value("id").toInt());
    QHash<int, QVariantMap> &saved = savedDetails(groups.detailsKind);
    saved.removeIf([&ids](QHash<int, QVariantMap>::iterator it) { return !ids.contains(it.key()); });
    m_database->keepGroupDetails(groups.detailsKind, saved.keys());
}

QHash<int, QVariantMap> &BookOrbitClient::savedDetails(const QString &kind)
{
    if (!m_savedDetails.contains(kind))
        m_savedDetails.insert(kind, m_database->groupDetails(kind));
    return m_savedDetails[kind];
}

QVariantMap BookOrbitClient::withSavedDetails(const Groups &groups, QVariantMap row)
{
    if (groups.detailsKind.isEmpty())
        return row;
    const QVariantMap details = savedDetails(groups.detailsKind).value(row.value("id").toInt());
    // Not for a group with no books now, such as an emptied collection
    if (details.isEmpty() || row.value("serverCount").toInt() == 0)
        return row;
    for (const QString &field : QStringList{"bookCount", "formats"} + groups.detailFields) {
        if (details.contains(field))
            row.insert(field, details.value(field));
    }
    // The list's covers, with the versions looked up for the same books
    QHash<int, QVariant> versions;
    for (const QVariant &cover : details.value("covers").toList())
        versions.insert(cover.toMap().value("id").toInt(), cover.toMap().value("coverVersion"));
    row.insert("covers", withCoverVersions(row.value("covers").toList(), versions));
    return row;
}

// A stable id for a row built offline, negative so it can't clash with the server's
static int localId(const QString &name)
{
    return -int(qHash(name) & 0x7fffffff) - 1;
}

void BookOrbitClient::setLocalBooks(const QVariantList &books)
{
    m_localBooks = books;
    m_library.setLocalBooks(books);
    m_search.setLocalBooks(books);
    m_booksOf.setLocalBooks(books);
    if (m_authors.localOnly)
        showGroups(m_authors);
    if (m_session.online())
        return;
    if (m_series.local)
        showLocalSeries(m_series);
    if (m_authorSeries.local)
        showLocalSeries(m_authorSeries);
    if (m_authors.local)
        showLocalAuthors();
    if (m_collections.local)
        showLocalCollections();
}

void BookOrbitClient::showLocalSeries(Groups &groups)
{
    const bool ofAuthor = &groups == &m_authorSeries;
    QMap<QString, QList<QVariantMap>> booksOf;   // series name -> books
    for (const QVariant &value : std::as_const(m_localBooks)) {
        const QVariantMap book = value.toMap();
        if (ofAuthor && !book.value("authors").toStringList().contains(m_authorSeriesName, Qt::CaseInsensitive))
            continue;
        for (const QString &name : seriesNames(book))
            booksOf[name].append(book);
    }
    groups.rows.clear();
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
        groups.rows.append(QVariantMap{
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
    groups.cached.clear();
    groups.local = true;
    groups.loaded = true;
    groups.allLookedUp = true;
    showGroups(groups);
}

void BookOrbitClient::showLocalAuthors()
{
    QMap<QString, QList<QVariantMap>> booksOf;   // author -> books
    for (const QVariant &value : std::as_const(m_localBooks)) {
        const QVariantMap book = value.toMap();
        for (const QString &author : book.value("authors").toStringList())
            booksOf[author].append(book);
    }
    // Ids, sort names and photos from when they were last fetched
    const QHash<QString, Database::Author> saved = m_database->authorsNamed(booksOf.keys());
    m_authors.rows.clear();
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
        m_authors.rows.append(QVariantMap{
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
    m_authors.cached.clear();
    m_authors.local = true;
    m_authors.loaded = true;
    m_authors.allLookedUp = true;
    showGroups(m_authors);
}

void BookOrbitClient::showLocalCollections()
{
    QHash<int, QVariantMap> local;   // book id -> book
    for (const QVariant &value : std::as_const(m_localBooks)) {
        const QVariantMap book = value.toMap();
        local.insert(book.value("id").toInt(), book);
    }
    m_collections.rows.clear();
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
        m_collections.rows.append(row);
    }
    m_collections.cached.clear();
    m_collections.local = true;
    m_collections.loaded = true;
    showGroups(m_collections);
}

void BookOrbitClient::setSeriesSort(const QString &field, bool descending)
{
    m_series.sort = field;
    m_series.descending = descending;
    showGroups(m_series);
}

void BookOrbitClient::loadAuthors()
{
    const int generation = startLoad(m_authors);
    if (!m_session.online()) {
        showLocalAuthors();
        return;
    }
    restoreList(m_authors);
    loadWithLibrary(m_authors, generation, [this, generation]() { loadAuthorsPage(0, generation); });
}

void BookOrbitClient::loadAuthorsPage(int page, int generation)
{
    // {items: [{id, name, sortName, bookCount, lastAddedAt, imageUrl (or null), ...}], total}
    const QString path = QString("/authors?libraryId=%1&sort=name&order=asc&page=%2&size=%3")
                             .arg(m_session.libraryId()).arg(page).arg(SERIES_PAGE_SIZE);
    m_session.callJson("GET", path, QJsonDocument(), [this, page, generation](const QJsonDocument &doc) {
        if (generation != m_authors.generation)
            return;
        const QJsonObject result = doc.object();
        const QJsonArray items = result.value("items").toArray();
        // The old rows stay until the first page of new ones
        if (page == 0) {
            m_authors.rows.clear();
            m_authors.allLookedUp = false;
            m_authors.local = false;
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
            m_authors.rows.append(withSavedDetails(m_authors, QVariantMap{
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
        m_authors.loaded = true;
        listPageLoaded(m_authors, morePages(page, SERIES_PAGE_SIZE, result),
                       [this, page, generation]() { loadAuthorsPage(page + 1, generation); });
    }, [this, generation](const QString &error) {
        if (generation == m_authors.generation)
            setListError(m_authors, error);
    });
}

void BookOrbitClient::setAuthorQuery(const QString &sortField, bool descending, const QStringList &formats,
                                     bool localOnly)
{
    m_authors.sort = sortField;
    m_authors.descending = descending;
    m_authors.formats = formats;
    m_authors.localOnly = localOnly;
    showGroups(m_authors);
    lookUpWantedRows(m_authors);
}

bool BookOrbitClient::filteringByFormat(const Groups &groups)
{
    return !groups.formats.isEmpty() && !groups.localOnly;
}

void BookOrbitClient::showGroups(Groups &groups)
{
    QList<QVariantMap> rows;
    if (!groups.formats.isEmpty() || groups.localOnly) {
        // Only authors with books in the chosen formats (or local ones, with localOnly),
        // counting just those books and showing their formats, as the
        // filtered book list does. Authors whose books aren't looked up yet wait.
        QHash<QString, QHash<QString, QStringList>> downloaded;   // author -> key -> formats
        QHash<QString, QHash<QString, QStringList>> downloadedSeries;   // author -> key -> series
        for (const QVariant &value : std::as_const(m_localBooks)) {
            const QVariantMap book = value.toMap();
            bool wanted = groups.formats.isEmpty();
            for (const QString &format : book.value("downloadedFormats").toStringList())
                wanted = wanted || groups.formats.contains(format);
            if (!wanted)
                continue;
            for (const QString &author : book.value("authors").toStringList()) {
                QStringList &formats = downloaded[author][companionKey(book)];
                addNew(formats, ownFormats(book));
                QStringList &series = downloadedSeries[author][companionKey(book)];
                addNew(series, seriesNames(book));
            }
        }
        for (QVariantMap row : shownRows(groups)) {
            // Matching books by key, with their formats and series
            QHash<QString, QStringList> wantedBooks;
            QHash<QString, QStringList> wantedSeries;
            if (groups.localOnly) {
                wantedBooks = downloaded.value(row.value("name").toString());
                wantedSeries = downloadedSeries.value(row.value("name").toString());
            } else {
                const QVariantMap books = row.value("books").toMap();
                const QVariantMap bookSeries = row.value("bookSeries").toMap();
                for (auto it = books.constBegin(); it != books.constEnd(); ++it) {
                    const QStringList formats = it.value().toStringList();
                    bool wanted = false;
                    for (const QString &format : formats)
                        wanted = wanted || groups.formats.contains(format);
                    if (wanted) {
                        wantedBooks.insert(it.key(), formats);
                        wantedSeries.insert(it.key(), bookSeries.value(it.key()).toStringList());
                    }
                }
            }
            if (wantedBooks.isEmpty())
                continue;
            QStringList formats;
            for (const QStringList &bookFormats : std::as_const(wantedBooks)) {
                addNew(formats, bookFormats);
            }
            sortFormats(formats);
            row.insert("bookCount", int(wantedBooks.size()));
            row.insert("seriesCount", seriesCount(wantedSeries));
            row.insert("formats", formats);
            rows.append(row);
        }
    } else {
        rows = shownRows(groups);
    }
    const QString field = groups.sort;
    std::stable_sort(rows.begin(), rows.end(), [field](const QVariantMap &a, const QVariantMap &b) {
        if (field == "bookCount")
            return a.value("bookCount").toInt() < b.value("bookCount").toInt();
        if (field == "readProgress")
            return a.value("readProgress").toDouble() < b.value("readProgress").toDouble();
        if (field == "lastAddedAt")   // "2026-09-17 13:03:35.074338+00": in order as text
            return a.value("lastAddedAt").toString() < b.value("lastAddedAt").toString();
        if (field == "sortName")   // an author's, "Martin, George R.R."
            return QString::localeAwareCompare(a.value("sortName").toString().toLower(), b.value("sortName").toString().toLower()) < 0;
        return QString::localeAwareCompare(a.value("name").toString().toLower(), b.value("name").toString().toLower()) < 0;
    });
    if (groups.descending)
        std::reverse(rows.begin(), rows.end());
    // By name, in A-Z sections like the library's titles
    QVariantList list;
    groups.jumpSections.clear();
    for (QVariantMap row : std::as_const(rows)) {
        QString label;
        if (field == "name" || field == "sortName") {
            const QString letter = letterSection(row.value(field).toString());
            if (groups.jumpSections.isEmpty() || groups.jumpSections.last().toMap().value("label") != letter) {
                groups.jumpSections.append(QVariantMap{{"label", letter}, {"index", list.size()}});
                label = letter;
            }
        }
        row.insert("sectionStart", !label.isEmpty());
        row.insert("sectionLabel", label);
        list.append(row);
    }
    // Updating rows in place keeps the scroll position
    if (groups.model.count() != list.size())
        groups.model.reset(list.size());
    groups.model.setBooks(0, list);
    emitChanged(groups);
}

void BookOrbitClient::showLoadedGroups(Groups &groups)
{
    if (groups.cached.isEmpty())
        showGroups(groups);
}

void BookOrbitClient::finishGroups(Groups &groups, bool complete)
{
    groups.cached.clear();
    showGroups(groups);
    if (complete)
        saveListCache(groups);
}

int BookOrbitClient::startLoad(Groups &groups)
{
    groups.lookedUp.clear();
    groups.wanted.clear();
    setListError(groups, QString());
    return ++groups.generation;
}

void BookOrbitClient::loadWithLibrary(Groups &groups, int generation, std::function<void()> load)
{
    Groups *loading = &groups;
    m_session.loadLibrary([loading, generation, load]() {
        if (generation == loading->generation)
            load();
    }, [this, loading, generation](const QString &error) {
        if (generation == loading->generation)
            setListError(*loading, error);
    });
}

void BookOrbitClient::listPageLoaded(Groups &groups, bool more, std::function<void()> loadNext)
{
    if (more) {
        showLoadedGroups(groups);
        loadNext();
    } else {
        finishGroups(groups, true);
        forgetGoneDetails(groups);
        lookUpWantedRows(groups);
    }
}

void BookOrbitClient::saveListCache(const Groups &groups)
{
    if (groups.cacheName.isEmpty())
        return;
    QVariantList rows;
    for (const QVariantMap &row : groups.rows)
        rows.append(row);
    m_database->saveListCache(groups.cacheName, QVariantMap{{"rows", rows}});
}

void BookOrbitClient::restoreList(Groups &groups)
{
    if (groups.cacheRead || groups.cacheName.isEmpty())
        return;
    groups.cacheRead = true;
    // With any details looked up since
    for (const QVariant &row : m_database->listCache(groups.cacheName).value("rows").toList())
        groups.cached.append(withSavedDetails(groups, row.toMap()));
    if (!groups.cached.isEmpty())
        showGroups(groups);
}

void BookOrbitClient::clearLists()
{
    m_database->clearCaches();
    m_savedDetails.clear();
    for (Groups *groups : {&m_collections, &m_series, &m_authors, &m_authorSeries}) {
        groups->generation++;
        groups->rows.clear();
        groups->cached.clear();
        groups->cacheRead = false;
        groups->loaded = false;
        groups->lookedUp.clear();
        groups->wanted.clear();
        groups->model.reset(0);
        groups->jumpSections.clear();
        groups->error.clear();
    }
    emit collectionsChanged();
    emit seriesListChanged();
    emit authorsChanged();
    emit authorSeriesChanged();

    m_library.clear();
    m_search.clear();
    m_booksOf.clear();
}

void BookOrbitClient::forgetLocalRows()
{
    // Rows built offline stay on screen until the server's arrive
    for (Groups *groups : {&m_collections, &m_series, &m_authors, &m_authorSeries}) {
        if (groups->local)
            groups->loaded = false;
    }
    emit collectionsChanged();
    emit seriesListChanged();
    emit authorsChanged();
    emit authorSeriesChanged();
}

void BookOrbitClient::emitChanged(const Groups &groups)
{
    if (&groups == &m_collections)
        emit collectionsChanged();
    else if (&groups == &m_series)
        emit seriesListChanged();
    else if (&groups == &m_authorSeries)
        emit authorSeriesChanged();
    else
        emit authorsChanged();
}

void BookOrbitClient::setListError(Groups &groups, const QString &error)
{
    if (groups.error == error)
        return;
    groups.error = error;
    emitChanged(groups);
}
