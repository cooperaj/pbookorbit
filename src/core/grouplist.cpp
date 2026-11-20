#include "core/grouplist.h"
#include "core/bookrecords.h"
#include "core/database.h"
#include "core/details.h"
#include "core/diagnostics.h"
#include "core/groupdetails.h"
#include "core/session.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <algorithm>

using namespace bookrecords;

// Maximum values in one filter rule, e.g. series names
static const int MAX_RULE_VALUES = 20;

GroupList::GroupList(Session *session, Database *database, Details *details, GroupDetails *groupDetails,
                     QObject *parent)
    : QObject(parent)
    , m_session(session)
    , m_database(database)
    , m_details(details)
    , m_groupDetails(groupDetails)
{
    // Signing in again, perhaps as someone else, starts with every library
    connect(session, &Session::signedOut, this, [this]() { setLibrary(-1); });
}

void GroupList::load()
{
    if (!m_session->online()) {
        startLoad();
        showLocal();
        return;
    }

    // Once the libraries are known, for whether the one chosen is still there. A later
    // load() replaces this one.
    const int generation = m_generation;
    m_session->loadLibrary([this, generation]() {
        if (generation != m_generation)
            return;
        if (m_libraryId >= 0 && !m_session->hasLibrary(m_libraryId))
            setLibrary(-1);
        const int loading = startLoad();
        restoreCache();
        loadPage(0, loading);
    }, [this, generation](const QString &error) {
        if (generation == m_generation)
            setError(error);
    });
}

void GroupList::setSort(const QString &field, bool descending)
{
    m_sort = field;
    m_descending = descending;
    show();
}

void GroupList::setLibrary(int libraryId)
{
    if (libraryId == m_libraryId)
        return;

    // The names without any library, then with the new one
    const auto scoped = [libraryId](const QString &name) {
        const QString base = name.section(':', 0, 0);
        return base.isEmpty() || libraryId < 0 ? base : QString("%1:%2").arg(base).arg(libraryId);
    };
    m_libraryId = libraryId;
    m_cacheName = scoped(m_cacheName);
    m_detailsKind = scoped(m_detailsKind);
    if (!m_librarySetting.isEmpty()) {
        if (libraryId < 0)
            m_database->remove(m_librarySetting);
        else
            m_database->setText(m_librarySetting, QString::number(libraryId));
    }
    clear();
    emit libraryIdChanged();
}

void GroupList::keepLibrary(const QString &setting)
{
    m_librarySetting = setting;
    bool saved = false;
    const int libraryId = m_database->text(setting).toInt(&saved);
    if (saved)
        setLibrary(libraryId);
}

void GroupList::lookUpRows(int first, int last)
{
    m_wantedFirst = first;
    m_wantedLast = last;
    lookUpWantedRows();
}

void GroupList::setQuery(const QString &sortField, bool descending, const QStringList &formats,
                         bool localOnly)
{
    m_formats = formats;
    m_localOnly = localOnly;
    setSort(sortField, descending);
    lookUpWantedRows();
}

void GroupList::setLocalBooks(const QVariantList &books)
{
    m_localBooks = books;
    if (!m_session->online() && m_local)
        showLocal();
    else if (m_localOnly)
        show();
}

void GroupList::clear()
{
    m_generation++;
    m_rows.clear();
    m_cached.clear();
    m_cacheRead = false;
    m_loaded = false;
    m_lookedUp.clear();
    m_wanted.clear();
    m_model.reset(0);
    m_jumpSections.clear();
    m_error.clear();
    emit changed();
}

void GroupList::forgetLocalRows()
{
    // Rows built offline stay on screen until the server's arrive
    if (m_local)
        m_loaded = false;
    emit changed();
}

int GroupList::startLoad()
{
    m_lookedUp.clear();
    m_wanted.clear();
    setError(QString());
    return ++m_generation;
}

void GroupList::pageLoaded(bool more, std::function<void()> loadNext)
{
    if (more) {
        showLoaded();
        loadNext();
        return;
    }

    m_cached.clear();
    show();
    saveCache();
    forgetGoneDetails();
    lookUpWantedRows();
}

void GroupList::show()
{
    QList<QVariantMap> rows = filtered(shownRows());
    const QString field = m_sort;
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
    if (m_descending)
        std::reverse(rows.begin(), rows.end());

    // By name, in A-Z sections like the library's titles
    QVariantList list;
    m_jumpSections.clear();
    for (QVariantMap row : std::as_const(rows)) {
        QString label;
        if (field == "name" || field == "sortName") {
            const QString letter = letterSection(row.value(field).toString());
            if (m_jumpSections.isEmpty() || m_jumpSections.last().toMap().value("label") != letter) {
                m_jumpSections.append(QVariantMap{{"label", letter}, {"index", list.size()}});
                label = letter;
            }
        }
        row.insert("sectionStart", !label.isEmpty());
        row.insert("sectionLabel", label);
        list.append(row);
    }

    // Updating rows in place keeps the scroll position
    if (m_model.count() != list.size())
        m_model.reset(list.size());
    m_model.setBooks(0, list);
    emit changed();
}

void GroupList::showLoaded()
{
    if (m_cached.isEmpty())
        show();
}

void GroupList::showLocalRows()
{
    m_cached.clear();
    m_local = true;
    m_loaded = true;
    show();
}

void GroupList::saveCache()
{
    if (m_cacheName.isEmpty())
        return;
    QVariantList rows;
    for (const QVariantMap &row : std::as_const(m_rows))
        rows.append(row);
    m_database->saveListCache(m_cacheName, QVariantMap{{"rows", rows}});
}

void GroupList::restoreCache()
{
    if (m_cacheRead || m_cacheName.isEmpty())
        return;
    m_cacheRead = true;
    // With any details looked up since
    for (const QVariant &row : m_database->listCache(m_cacheName).value("rows").toList())
        m_cached.append(withSavedDetails(row.toMap()));
    if (!m_cached.isEmpty())
        show();
}

QList<QVariantMap> GroupList::filtered(const QList<QVariantMap> &rows) const
{
    if (m_formats.isEmpty() && !m_localOnly)
        return rows;

    // With localOnly, the local books in the list's library (all of them offline, where
    // none can be chosen) in the chosen formats, by group
    QHash<QString, QHash<QString, QStringList>> downloaded;         // group -> key -> formats
    QHash<QString, QHash<QString, QStringList>> downloadedSeries;   // group -> key -> series
    if (m_localOnly) {
        const QVariantList books = booksIn(m_localBooks, m_session->online() ? m_libraryId : -1);
        for (const QVariant &value : books) {
            const QVariantMap book = value.toMap();
            bool wanted = m_formats.isEmpty();
            for (const QString &format : book.value("downloadedFormats").toStringList())
                wanted = wanted || m_formats.contains(format);
            if (!wanted)
                continue;
            const QString key = companionKey(book);
            for (const QString &group : groupsOf(book)) {
                // Rows built offline show what's downloaded, as showLocal() does
                addNew(downloaded[group][key], m_local ? book.value("downloadedFormats").toStringList()
                                                       : ownFormats(book));
                addNew(downloadedSeries[group][key], seriesNames(book));
            }
        }
    }

    // Only groups with matching books, counting just those and showing their formats, as
    // the filtered book list does. Groups whose books aren't looked up yet wait.
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
        row.insert("formats", formats);
        // Authors' rows count their series
        if (row.contains("seriesCount"))
            row.insert("seriesCount", seriesCount(wantedSeries));
        shown.append(row);
    }
    return shown;
}

void GroupList::lookUpWantedRows()
{
    // Only once the list has loaded, and not for rows built offline
    if (!m_session->online() || m_local || !m_loaded || !m_cached.isEmpty())
        return;
    QList<int> ids;
    for (int i = qMax(0, m_wantedFirst); i <= m_wantedLast && i < m_model.count(); i++) {
        const int id = m_model.book(i).value("id").toInt();
        if (!m_lookedUp.contains(id))
            ids.append(id);
    }
    if (lookUpAll()) {
        QSet<int> queued(ids.cbegin(), ids.cend());
        for (const QVariantMap &row : std::as_const(m_rows)) {
            const int id = row.value("id").toInt();
            if (!m_lookedUp.contains(id) && !queued.contains(id))
                ids.append(id);
        }
    }
    queueLookUps(ids);
}

void GroupList::queueLookUps(const QList<int> &ids)
{
    m_wanted = ids;
    if (m_lookingUpGeneration != m_generation)
        lookUpNextRows(m_generation);
}

void GroupList::lookUpNextRows(int generation)
{
    m_lookingUpGeneration = -1;
    // As many as fit in one request. That's one row on its own, or up to a page of books
    // between them, at least one row and at most a rule's worth.
    const bool alone = lookUpAlone();
    // Every row may be waiting, so not a search of the rows for each
    QHash<int, const QVariantMap *> rowsById;
    for (const QVariantMap &row : std::as_const(m_rows))
        rowsById.insert(row.value("id").toInt(), &row);
    QList<int> ids;
    int books = 0;
    while (!m_wanted.isEmpty()) {
        const int id = m_wanted.first();
        const QVariantMap *row = rowsById.value(id);
        // An empty collection has nothing to look up
        if (!row || m_lookedUp.contains(id) || (alone && row->value("serverCount").toInt() == 0)) {
            m_wanted.removeFirst();
            continue;
        }
        const int count = row->value("serverCount").toInt();
        if (!ids.isEmpty() && (alone || books + count > LOOKUP_PAGE_SIZE || ids.size() == MAX_RULE_VALUES))
            break;
        ids.append(m_wanted.takeFirst());
        books += count;
    }

    if (ids.isEmpty()) {
        const bool allLookedUp = m_lookedUp.size() >= m_rows.size();
        if (allLookedUp != m_allLookedUp) {
            m_allLookedUp = allLookedUp;
            emit changed();
        }
        return;
    }
    m_lookingUpGeneration = generation;
    lookUp(ids, generation);
}

void GroupList::stopLookingUp()
{
    // Tried again when next wanted
    m_lookingUpGeneration = -1;
    m_wanted.clear();
}

void GroupList::lookUpByName(const QList<int> &ids, bool authors, int page, int generation)
{
    QStringList names;
    for (const int id : ids) {
        if (const QVariantMap *row = rowWithId(id))
            names.append(row->value("name").toString());
    }
    const QJsonObject query{
        {"filter", group("AND", {rule(authors ? "author" : "series", "includesAny", QJsonArray::fromStringList(names))})},
        {"pagination", QJsonObject{{"page", page}, {"size", LOOKUP_PAGE_SIZE}}},
    };

    // Quiet: this only fills in existing rows
    m_session->request("POST", Session::booksPath(m_libraryId), QJsonDocument(query),
        [this, authors, ids, page, generation](const QByteArray &data) {
            if (generation != m_generation)
                return;
            const QJsonObject result = QJsonDocument::fromJson(data).object();
            const QJsonArray items = result.value("items").toArray();
            m_details->updateSavedBooks(items);
            const bool more = morePages(page, LOOKUP_PAGE_SIZE, result);

            // What earlier pages found for each row, by name. A first page replaces what an
            // earlier lookup found.
            QHash<QString, int> idNamed;
            QHash<int, FoundBooks> found;
            for (const int id : ids) {
                if (const QVariantMap *row = rowWithId(id)) {
                    idNamed.insert(row->value("name").toString(), id);
                    found.insert(id, page == 0 ? FoundBooks() : FoundBooks::in(*row));
                }
            }
            QHash<int, QVariant> coverVersions;
            for (const QJsonValue &item : items) {
                const QVariantMap book = item.toObject().toVariantMap();
                coverVersions.insert(book.value("id").toInt(), book.value("coverVersion"));
                // Every series a book is in, or every author it has
                for (const QString &name : authors ? book.value("authors").toStringList() : seriesNames(book)) {
                    if (idNamed.contains(name))
                        found[idNamed.value(name)].add(book, authors);
                }
            }

            QList<const QVariantMap *> complete;
            for (auto it = found.constBegin(); it != found.constEnd(); ++it) {
                QVariantMap *row = rowWithId(it.key());
                it.value().putIn(*row, authors, !more);
                row->insert("covers", withCoverVersions(row->value("covers").toList(), coverVersions));
                if (!more) {
                    m_lookedUp.insert(it.key());
                    complete.append(row);
                }
            }
            m_database->transaction([&]() {
                for (const QVariantMap *row : std::as_const(complete))
                    saveRowDetails(*row);
            });
            showLoaded();
            if (more)
                lookUpByName(ids, authors, page + 1, generation);
            else
                lookUpNextRows(generation);
        },
        [this, generation](int status, const QString &message) {
            diagnostics::log(QString("series or author books: %1 (%2)").arg(message).arg(status));
            if (generation == m_generation)
                stopLookingUp();
        });
}

void GroupList::saveRowDetails(const QVariantMap &row)
{
    if (m_detailsKind.isEmpty())
        return;
    QVariantMap details;
    for (const QString &field : QStringList{"bookCount", "formats", "covers"} + m_detailFields)
        details.insert(field, row.value(field));
    m_groupDetails->save(m_detailsKind, row.value("id").toInt(), details);
}

void GroupList::forgetGoneDetails()
{
    if (m_detailsKind.isEmpty() || m_partial)
        return;
    QList<int> ids;
    for (const QVariantMap &row : std::as_const(m_rows))
        ids.append(row.value("id").toInt());
    m_groupDetails->keepOnly(m_detailsKind, ids);
}

QVariantMap GroupList::withSavedDetails(QVariantMap row)
{
    if (m_detailsKind.isEmpty())
        return row;
    const QVariantMap details = m_groupDetails->of(m_detailsKind).value(row.value("id").toInt());
    // Not for a group with no books now, such as an emptied collection
    if (details.isEmpty() || row.value("serverCount").toInt() == 0)
        return row;
    for (const QString &field : QStringList{"bookCount", "formats"} + m_detailFields) {
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

void GroupList::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    emit changed();
}

QVariantMap *GroupList::rowWithId(int id)
{
    for (QVariantMap &row : m_rows) {
        if (row.value("id").toInt() == id)
            return &row;
    }
    return nullptr;
}

QVariantList GroupList::withCoverVersions(QVariantList covers, const QHash<int, QVariant> &versions)
{
    for (QVariant &cover : covers) {
        QVariantMap map = cover.toMap();
        if (versions.contains(map.value("id").toInt()))
            map.insert("coverVersion", versions.value(map.value("id").toInt()));
        cover = map;
    }
    return covers;
}

int GroupList::seriesCount(const QHash<QString, QStringList> &bookSeries)
{
    QSet<QString> series;
    for (const QStringList &names : bookSeries) {
        for (const QString &name : names)
            series.insert(name);
    }
    return int(series.size());
}

QString GroupList::libraryParameter() const
{
    return m_libraryId < 0 ? QString() : QString("&libraryId=%1").arg(m_libraryId);
}

int GroupList::localId(const QString &name)
{
    return -int(qHash(name) & 0x7fffffff) - 1;
}

GroupList::FoundBooks GroupList::FoundBooks::in(const QVariantMap &row)
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

void GroupList::FoundBooks::add(const QVariantMap &book, bool withSeries)
{
    const QString key = companionKey(book);
    addNew(formatsOf[key], ownFormats(book));
    addNew(formats, ownFormats(book));
    if (withSeries)
        addNew(seriesOf[key], seriesNames(book));
}

void GroupList::FoundBooks::putIn(QVariantMap &row, bool withSeries, bool complete) const
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
