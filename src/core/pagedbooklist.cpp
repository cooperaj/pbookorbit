#include "core/pagedbooklist.h"
#include "core/bookrecords.h"
#include "core/database.h"
#include "core/details.h"
#include "core/session.h"
#include "core/systemlibrary.h"

#include <QDateTime>
#include <QJsonDocument>
#include <QTimeZone>
#include <algorithm>
#include <optional>

using namespace bookrecords;

// Page size when only reading series numbers (the server's maximum)
static const int SERIES_NUMBERS_PAGE_SIZE = 200;

PagedBookList::PagedBookList(Session *session, Database *database, Details *details, QObject *parent)
    : QObject(parent)
    , m_session(session)
    , m_database(database)
    , m_details(details)
{
    m_cacheTimer.setSingleShot(true);
    m_cacheTimer.setInterval(2000);
    connect(&m_cacheTimer, &QTimer::timeout, this, &PagedBookList::saveCache);
}

void PagedBookList::load(int first, int last)
{
    // Other pages wait for the first, which sets the list's length
    if (m_listGeneration != m_queryGeneration) {
        m_wantedFirst = first;
        m_wantedLast = last;
        return;
    }
    first = qMax(0, first);
    last = qMin(last, m_model.count() - 1);
    for (int page = first / PAGE_SIZE; page <= last / PAGE_SIZE && last >= 0; page++) {
        if (!m_loadedPages.contains(page) && !m_loadingPages.contains(page))
            loadPage(page);
    }
}

void PagedBookList::setLocalBooks(const QVariantList &books)
{
    m_localBooks = books;
    if (m_onlyListed)
        refresh();
}

void PagedBookList::clear()
{
    m_cacheTimer.stop();
    m_cacheDirty = false;
    restartPages();
    m_listGeneration = -1;
    m_total = 0;
    m_model.reset(0);
    clearJumpSections();
    showJumpSections({});
    emit changed();
}

void PagedBookList::setSortAndFilter(const QString &sortField, bool descending, const QStringList &formats,
                                     bool localOnly)
{
    m_sortField = sortField;
    m_sortDescending = descending;
    m_formats = formats;
    m_onlyListed = localOnly;
}

void PagedBookList::refresh()
{
    restartPages();
    if (m_onlyListed) {
        m_onlyBooks = localBooks();
        showListedBooks();

        // Nothing else fetches the libraries while only downloaded books are listed, and
        // the library menu and the books in the chosen library need them. Quiet: the
        // books on the device are already shown.
        if (m_session->online() && m_session->libraryId() < 0) {
            const int generation = m_queryGeneration;
            m_session->withLibrary([this, generation](int) {
                // Unchanged when the saved library was shown, and redrawing would scroll
                // the list back to the top
                QVariantList books = localBooks();
                if (generation != m_queryGeneration || books == m_onlyBooks)
                    return;
                m_onlyBooks = std::move(books);
                showListedBooks();
            }, [](int, const QString &) {});
        }
        return;
    }

    // With nothing shown yet, the cached rows until the first page
    if (m_listGeneration == -1 && m_model.count() == 0)
        restoreCache();
    const int generation = m_queryGeneration;
    withLibrary([this, generation]() {
        if (generation != m_queryGeneration)
            return;
        m_query = bookQuery();
        setPaths();

        // A-Z and last read sorts need their sections first, to know which rows start one.
        // List entries have no last read date, so only its jump buckets can section it.
        if ((isLetterSort(m_sortField) || m_sortField == "lastReadAt") && !m_jumpPath.isEmpty()) {
            m_sections = Sections::Starts;
            loadJumpSections([this]() { loadPage(0); });
        } else if (m_sortField == "seriesIndex") {
            // Each book under its number in the series
            m_sections = Sections::SeriesNumbers;
            clearJumpSections();
            loadPage(0);
            loadSeriesSections();
        } else {
            // No sections for collection order: the server doesn't say when each book was
            // added. None for A-Z or last read across libraries either, as only a library
            // has jump buckets, and its title order can't be matched locally.
            m_sections = isDateSort(m_sortField) ? Sections::Days : Sections::None;
            clearJumpSections();
            jumpSectionsLoaded();
            loadPage(0);
        }
    });
}

void PagedBookList::setPaths()
{
    setLibraryPaths(m_session->libraryId());
}

void PagedBookList::setLibraryPaths(int libraryId)
{
    m_path = Session::booksPath(libraryId);
    m_jumpPath = libraryId < 0 ? QString() : m_path + "/jump-buckets";
    m_companionsPath = m_path;
    // With every type listed, an audiobook's ebook record is in the list too
    m_mergePairs = m_formats.isEmpty();
}

QVariantList PagedBookList::localBooksIn(int libraryId) const
{
    // Offline, where no library can be chosen, all of them
    return booksIn(m_localBooks, m_session->online() ? libraryId : -1);
}

void PagedBookList::withLibrary(std::function<void()> then)
{
    const int generation = m_queryGeneration;
    m_session->loadLibrary(then, [this, generation](const QString &error) {
        if (generation == m_queryGeneration)
            setError(error);
    });
}

void PagedBookList::restartPages()
{
    m_queryGeneration++;
    m_loadedPages.clear();
    m_loadingPages.clear();
    m_cached = false;
    m_wantedLast = -1;
    m_jumpSectionsLoaded = false;
    setError(QString());
}

void PagedBookList::clearRows()
{
    // Saved now, as the timer would find them replaced
    saveCache();
    restartPages();
    m_listGeneration = -1;
    m_total = 0;
    m_model.reset(0);
    clearJumpSections();
    showJumpSections({});
    emit changed();
}

QJsonObject PagedBookList::bookQuery() const
{
    QJsonObject query{
        {"sort", QJsonArray{QJsonObject{{"field", m_sortField}, {"dir", m_sortDescending ? "desc" : "asc"}}}},
    };

    QJsonArray rules = m_rules;
    if (!m_formats.isEmpty())
        rules.append(rule("format", "includesAny", QJsonArray::fromStringList(m_formats)));
    if (!rules.isEmpty())
        query.insert("filter", group("AND", rules));
    return query;
}

QString PagedBookList::sortKey(const QVariantMap &book, const QString &field) const
{
    if (field == "author") {
        const QStringList authors = book.value("authors").toStringList();
        return authors.isEmpty() ? QString() : authorSortKey(authors.first());
    }
    if (field == "seriesIndex") {
        // Numbers in order, and books without one last
        const QVariant index = book.value("seriesIndex");
        return index.isNull() ? QString("~") : QString("%1").arg(index.toDouble(), 12, 'f', 3, QChar('0'));
    }
    return book.value(field).toString();   // title, or an ISO date
}

void PagedBookList::showListedBooks()
{
    // BookOrbit gives no last read date per book, so last read is when the system's reader
    // last opened the book's files, where its library can be read, newest first, then the
    // books never opened by title. Elsewhere it's by title, unsectioned.
    const bool lastRead = m_sortField == "lastReadAt";
    std::optional<QHash<QString, qint64>> openedOrNone;
    if (lastRead) {
        QStringList paths;
        for (const QVariant &value : std::as_const(m_onlyBooks))
            paths += value.toMap().value("devicePaths").toStringList();
        openedOrNone = systemlibrary::lastOpened(paths);
    }
    const bool openTimes = openedOrNone.has_value();
    const QHash<QString, qint64> opened = openedOrNone.value_or(QHash<QString, qint64>());
    m_sections = !sectioned() ? Sections::None
               : isLetterSort(m_sortField) ? Sections::Starts
               : m_sortField == "seriesIndex" ? Sections::SeriesNumbers
               : isDateSort(m_sortField) || openTimes ? Sections::Days : Sections::None;
    const bool byTitle = lastRead;
    const QString field = byTitle ? QString("title") : m_sortField;

    // Records of the same book (an ebook and audiobook stored separately) become one row,
    // the ebook's, with both formats
    QHash<QString, QList<QVariantMap>> byKey;
    QStringList keys;   // in the order first seen
    for (const QVariant &value : std::as_const(m_onlyBooks)) {
        const QVariantMap book = value.toMap();
        const QString key = companionKey(book);
        if (!byKey.contains(key))
            keys.append(key);
        byKey[key].append(book);
    }
    QList<QPair<QString, QVariantMap>> books;   // sort key, row
    for (const QString &key : std::as_const(keys)) {
        QList<QVariantMap> records = byKey.value(key);
        // Shown if any downloaded file is in a chosen format
        bool wanted = m_formats.isEmpty();
        for (const QVariantMap &record : std::as_const(records)) {
            for (const QString &format : record.value("downloadedFormats").toStringList())
                wanted = wanted || m_formats.contains(format);
        }
        if (!wanted)
            continue;
        int shown = 0;
        for (int i = 0; i < records.size(); i++) {
            const QVariantList variants = ownVariants(records.at(i));
            if (!variants.isEmpty() && variants.first().toMap().value("kind") == "ebook") {
                shown = i;
                break;
            }
        }
        QVariantMap book = records.takeAt(shown);
        if (openTimes) {
            // Its latest open, of any of its records' files
            qint64 latest = 0;
            for (const QVariantMap &record : byKey.value(key)) {
                for (const QString &path : record.value("devicePaths").toStringList())
                    latest = qMax(latest, opened.value(path));
            }
            if (latest > 0)
                book.insert("lastOpenedAt", QDateTime::fromSecsSinceEpoch(latest, QTimeZone::UTC).toString(Qt::ISODate));
        }
        QVariantMap row = decorateBook(book);
        addCompanions(row, records, false);
        books.append({sortKey(book, field), row});
    }
    const bool descending = m_sortDescending && !byTitle;
    std::stable_sort(books.begin(), books.end(), [descending](const auto &a, const auto &b) {
        const int order = QString::localeAwareCompare(a.first.toLower(), b.first.toLower());
        return descending ? order > 0 : order < 0;
    });
    // Then by when they were opened, newest first, keeping title order among the rest
    if (openTimes) {
        std::stable_sort(books.begin(), books.end(), [](const auto &a, const auto &b) {
            return a.second.value("lastOpenedAt").toString() > b.second.value("lastOpenedAt").toString();
        });
    }

    QVariantList rows;
    m_sectionStarts.clear();
    m_jumpSections.clear();
    for (const auto &[key, row] : std::as_const(books)) {
        if (m_sections == Sections::Starts) {
            const QString letter = letterSection(key);
            if (m_jumpSections.isEmpty() || m_jumpSections.last().toMap().value("label") != letter) {
                m_sectionStarts.insert(rows.size(), letter);
                m_jumpSections.append(QVariantMap{{"label", letter}, {"index", rows.size()}});
            }
        } else if (m_sections == Sections::SeriesNumbers && !row.value("seriesIndex").isNull()) {
            // Same as loadSeriesSections() does for server lists
            const QString label = row.value("seriesIndex").toString();
            if (m_jumpSections.isEmpty() || m_jumpSections.last().toMap().value("label") != label)
                m_jumpSections.append(QVariantMap{{"label", label}, {"index", rows.size()}});
        }
        rows.append(row);
    }

    // Everything is already loaded
    m_listGeneration = m_queryGeneration;
    m_total = rows.size();
    for (int page = 0; page * PAGE_SIZE < rows.size(); page++)
        m_loadedPages.insert(page);
    m_model.reset(rows.size());
    m_model.setBooks(0, rows);
    updateSectionStarts(0, rows.size() - 1);
    jumpSectionsLoaded();
    emit changed();
}

// A date bucket's section label, like the system library's dates: "2026/10/23" for a day,
// "2026/10" for a month, "2026" or "2020-2029" for years, and "Never" for books not read
static QString dateBucketLabel(const QJsonObject &bucket, const QJsonObject &granularity)
{
    if (bucket.value("isUnknown").toBool())
        return QStringLiteral("Never");
    const QString key = bucket.value("key").toString();
    const int step = granularity.value("step").toInt(1);
    if (granularity.value("unit").toString() == "year" && step > 1)
        return QString("%1-%2").arg(key).arg(key.toInt() + step - 1);
    return QString(key).replace('-', '/');
}

void PagedBookList::loadJumpSections(std::function<void()> then)
{
    // Same request as the web client's jump rail: the list query plus maxBuckets (at most
    // 64). Returns {buckets: [{key, label, index, isUnknown}], total, kind, granularity},
    // where index is the section's first row. Buckets use the server's sort keys, so they
    // always match the list. Letters go on the rail too; dates (kind "temporal") only label
    // the rows.
    QJsonObject query = m_query;
    query.insert("pagination", QJsonObject{{"page", 0}, {"size", PAGE_SIZE}});
    query.insert("maxBuckets", 64);
    const int generation = m_queryGeneration;
    m_session->callJson("POST", m_jumpPath, QJsonDocument(query),
        [this, generation, then](const QJsonDocument &doc) {
            if (generation != m_queryGeneration)
                return;   // stale reply
            const QJsonObject result = doc.object();
            m_sectionStarts.clear();
            m_jumpSections.clear();
            const QString kind = result.value("kind").toString();
            const QJsonObject granularity = result.value("granularity").toObject();
            for (const QJsonValue &bucket : result.value("buckets").toArray()) {
                const int index = bucket["index"].toInt();
                if (kind == "letter") {
                    const QString label = bucket["label"].toString();
                    m_sectionStarts.insert(index, label);
                    m_jumpSections.append(QVariantMap{{"label", label}, {"index", index}});
                } else if (kind == "temporal") {
                    m_sectionStarts.insert(index, dateBucketLabel(bucket.toObject(), granularity));
                }
            }
            jumpSectionsLoaded();
            then();
        },
        [this, generation](const QString &error) {
            if (generation == m_queryGeneration)
                setError(error);
        });
}

void PagedBookList::loadSeriesSections(int page)
{
    // There are no jump buckets for series order, so read every book's number from the list
    // in large pages, while rows load as usual
    QJsonObject query = m_query;
    query.insert("pagination", QJsonObject{{"page", page}, {"size", SERIES_NUMBERS_PAGE_SIZE}});
    const int generation = m_queryGeneration;
    m_session->callJson("POST", m_path, QJsonDocument(query),
        [this, page, generation](const QJsonDocument &doc) {
            if (generation != m_queryGeneration)
                return;
            const QJsonObject result = doc.object();
            const QJsonArray items = result.value("items").toArray();
            for (int i = 0; i < items.size(); i++) {
                // Books without a number get no section. An ebook and its audiobook share
                // one.
                const QVariant index = items.at(i)["seriesIndex"].toVariant();
                if (index.isNull())
                    continue;
                const QString label = index.toString();
                if (m_jumpSections.isEmpty() || m_jumpSections.last().toMap().value("label") != label)
                    m_jumpSections.append(QVariantMap{{"label", label}, {"index", page * SERIES_NUMBERS_PAGE_SIZE + i}});
            }
            if (morePages(page, SERIES_NUMBERS_PAGE_SIZE, result))
                loadSeriesSections(page + 1);
            else
                jumpSectionsLoaded();
        },
        [this, generation](const QString &error) {
            if (generation == m_queryGeneration)
                setError(error);
        });
}

void PagedBookList::clearJumpSections()
{
    m_sectionStarts.clear();
    m_jumpSections.clear();
}

void PagedBookList::jumpSectionsLoaded()
{
    m_jumpSectionsLoaded = true;
    if (m_listGeneration == m_queryGeneration)
        showJumpSections(m_jumpSections);
}

void PagedBookList::showJumpSections(const QVariantList &sections)
{
    if (sections == m_shownJumpSections)
        return;
    m_shownJumpSections = sections;
    emit jumpSectionsChanged();
}

void PagedBookList::loadPage(int page)
{
    // Same query as the web client. Returns {items: [...], total, page, size}. Pages count
    // from 0.
    QJsonObject query = m_query;
    query.insert("pagination", QJsonObject{{"page", page}, {"size", PAGE_SIZE}});

    m_loadingPages.insert(page);
    const int generation = m_queryGeneration;
    m_session->callJson("POST", m_path, QJsonDocument(query),
        [this, page, generation](const QJsonDocument &doc) {
            if (generation != m_queryGeneration)
                return;   // stale reply
            const QJsonObject result = doc.object();
            const int total = result.value("total").toInt();
            m_details->updateSavedBooks(result.value("items").toArray());
            QVariantList books;
            QVariantList records;
            for (const QJsonValue &item : result.value("items").toArray()) {
                records.append(item.toObject().toVariantMap());
                books.append(decorateBook(records.last().toMap()));
            }

            // Shown once merged with their companions, so an ebook and its audiobook don't
            // show as two rows first
            lookUpCompanions(records, books, generation,
                [this, page, generation, total](const QVariantList &rows) {
                    if (generation != m_queryGeneration)
                        return;
                    m_loadingPages.remove(page);
                    m_loadedPages.insert(page);
                    // A new query's first page resets the list to the right length. Cached
                    // rows stay until their pages load, so the list doesn't jump back to the
                    // top.
                    const bool firstPage = m_listGeneration != generation;
                    if (firstPage) {
                        m_listGeneration = generation;
                        m_total = total;
                        if (m_cached)
                            m_model.resize(m_total);
                        else
                            m_model.reset(m_total);
                        m_cached = false;
                    }
                    const int first = page * PAGE_SIZE;
                    m_model.setBooks(first, rows);
                    // Series numbers can still be loading; until then, no rail rather
                    // than the old one
                    if (firstPage)
                        showJumpSections(m_jumpSectionsLoaded ? m_jumpSections : QVariantList());
                    if (!m_cacheName.isEmpty() && first < CACHED_ROWS) {
                        m_cacheDirty = true;
                        m_cacheTimer.start();
                    }
                    if (firstPage && m_wantedLast >= 0)
                        load(m_wantedFirst, m_wantedLast);
                    // Include the next row, whose section start depends on this page's
                    // last. Hidden rows pass their section boxes on to the next row.
                    updateSectionStarts(first, first + int(rows.size()));
                    m_error.clear();
                    emit changed();
                });
        },
        [this, page, generation](const QString &error) {
            if (generation != m_queryGeneration)
                return;
            m_loadingPages.remove(page);   // try again when it is next on screen
            setError(error);
        });
}

void PagedBookList::lookUpCompanions(const QVariantList &books, const QVariantList &rows, int generation,
                                     std::function<void(const QVariantList &rows)> then)
{
    if (books.isEmpty()) {
        then(rows);
        return;
    }

    // Every record of the books on the page, ignoring the list's filter
    const QJsonObject query{
        {"filter", companionsFilter(books)},
        {"pagination", QJsonObject{{"page", 0}, {"size", COMPANIONS_PAGE_SIZE}}},
    };
    m_session->callJson("POST", m_companionsPath, QJsonDocument(query),
        [this, books, rows, generation, then](const QJsonDocument &doc) {
            if (generation != m_queryGeneration)
                return;
            QVariantList merged = rows;
            QHash<QString, QList<QVariantMap>> byKey;
            for (const QJsonValue &item : doc.object().value("items").toArray()) {
                const QVariantMap record = item.toObject().toVariantMap();
                byKey[companionKey(record)].append(record);
            }

            // Rows that would be hidden if their ebook record is listed too, for lists
            // where that isn't certain: (row, companions)
            QList<std::pair<int, QList<QVariantMap>>> maybeHidden;
            for (int i = 0; i < books.size(); i++) {
                const QVariantMap book = books.at(i).toMap();
                QList<QVariantMap> companions;
                for (const QVariantMap &record : byKey.value(companionKey(book))) {
                    if (record.value("id") != book.value("id"))
                        companions.append(record);
                }
                if (companions.isEmpty())
                    continue;
                QVariantMap row = merged.at(i).toMap();
                addCompanions(row, companions, m_mergePairs);
                merged[i] = row;
                if (checksPairs()) {
                    QVariantMap hiddenRow = rows.at(i).toMap();
                    addCompanions(hiddenRow, companions, true);
                    if (hiddenRow.value("hidden").toBool())
                        maybeHidden.append({i, companions});
                }
            }
            if (maybeHidden.isEmpty())
                then(merged);
            else
                hideListedPairs(merged, rows, maybeHidden, books, then);
        },
        // Unmerged, rather than not at all
        [this, rows, generation, then](const QString &) {
            if (generation == m_queryGeneration)
                then(rows);
        });
}

void PagedBookList::hideListedPairs(const QVariantList &merged, const QVariantList &,
                                    const QList<std::pair<int, QList<QVariantMap>>> &,
                                    const QVariantList &, std::function<void(const QVariantList &)> then)
{
    then(merged);
}

QVariantMap PagedBookList::decorateBook(const QVariantMap &book) const
{
    // Date added, and last read on the device (lastOpenedAt, see showListedBooks), are
    // sectioned by day. A-Z and last read from the server use the jump sections instead (see
    // updateSectionStarts).
    QString dayField;
    if (m_sections == Sections::Days)
        dayField = m_sortField == "lastReadAt" ? "lastOpenedAt" : "addedAt";
    return row(book, dayField);
}

void PagedBookList::updateSectionStarts(int first, int last)
{
    if (m_sections == Sections::None)
        return;
    const auto hidden = [this](int row) { return m_model.book(row).value("hidden").toBool(); };
    for (int row = qMax(0, first); row <= last && row < m_model.count(); row++) {
        if (!m_model.isLoaded(row))
            continue;
        if (hidden(row)) {
            m_model.setField(row, "sectionStart", false);
            continue;
        }
        // Previous visible row, skipping hidden ones
        int previous = row - 1;
        while (previous >= 0 && m_model.isLoaded(previous) && hidden(previous))
            previous--;
        if (m_sections == Sections::SeriesNumbers) {
            // Series number, which the box shows in place of seriesText
            const QVariant index = m_model.book(row).value("seriesIndex");
            m_model.setField(row, "sectionStart", !index.isNull());
            m_model.setField(row, "sectionLabel", index.isNull() ? QString() : index.toString());
            m_model.setField(row, "seriesText", QString());
        } else if (m_sections == Sections::Starts) {
            // A section starting here, or on the hidden rows just before
            QString label;
            for (int r = row; r > previous && label.isEmpty(); r--)
                label = m_sectionStarts.value(r);
            m_model.setField(row, "sectionStart", !label.isEmpty());
            m_model.setField(row, "sectionLabel", label);
        } else {
            // A new day, if the previous visible row is loaded and on a different day.
            // Otherwise its page fills this in later.
            const QString section = m_model.book(row).value("section").toString();
            m_model.setField(row, "sectionStart", previous < 0
                || (m_model.isLoaded(previous) && m_model.book(previous).value("section").toString() != section));
        }
    }
}

void PagedBookList::saveCache()
{
    // Only a list from the server whose rows have changed, and not one replaced since
    if (!std::exchange(m_cacheDirty, false) || m_cacheName.isEmpty() || m_onlyListed
            || m_listGeneration != m_queryGeneration)
        return;
    QVariantList rows;
    for (int i = 0; i < qMin(m_model.count(), CACHED_ROWS) && m_model.isLoaded(i); i++)
        rows.append(m_model.book(i));
    if (rows.isEmpty())
        return;
    m_database->transaction([&]() {
        m_database->saveListCache(m_cacheName, QVariantMap{
            {"query", m_query.toVariantMap()},
            {"total", m_total},
            {"jumpSections", m_shownJumpSections},
            {"rows", rows},
            {"savedAt", QDateTime::currentMSecsSinceEpoch()},
        });
        cacheSaved();
    });
}

void PagedBookList::restoreCache()
{
    if (m_cacheName.isEmpty())
        return;
    // Only for the same sort and filter
    const QVariantMap cache = m_database->listCache(m_cacheName);
    const QVariantList rows = cache.value("rows").toList();
    if (rows.isEmpty() || QJsonObject::fromVariantMap(cache.value("query").toMap()) != bookQuery())
        return;
    // listGeneration stays -1, so the first page from the server replaces these, and
    // scrolling past them waits for it
    m_total = cache.value("total").toInt();
    m_jumpSections = cache.value("jumpSections").toList();
    m_cached = true;
    m_model.reset(m_total);
    m_model.setBooks(0, rows);
    showJumpSections(m_jumpSections);
    emit changed();
}

void PagedBookList::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    emit changed();
}
