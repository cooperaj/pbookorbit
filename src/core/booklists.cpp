#include "core/booklists.h"
#include "core/bookrecords.h"
#include "core/database.h"
#include "core/recentsearches.h"
#include "core/session.h"

#include <QJsonDocument>
#include <algorithm>

using namespace bookrecords;

// Books-of lists kept in the list cache, the most recently loaded
static const int CACHED_BOOKS_OF = 20;

LibraryBooks::LibraryBooks(Session *session, Database *database, Details *details, QObject *parent)
    : PagedBookList(session, database, details, parent)
{
    m_cacheName = "library";
}

void LibraryBooks::setQuery(const QString &sortField, bool descending, const QStringList &formats,
                            bool localOnly)
{
    setSortAndFilter(sortField, descending, formats, localOnly);
    refresh();
}

void SearchResults::find(const QString &text)
{
    restartPages();
    const QString q = text.trimmed();
    if (q.length() < RecentSearches::MIN_LENGTH) {
        m_listGeneration = m_queryGeneration;
        m_total = 0;
        m_model.reset(0);
        emit changed();
        return;
    }
    if (!m_session->online()) {
        findLocalBooks(q);
        return;
    }

    m_onlyListed = false;
    emit changed();   // total is -1 until the results arrive
    const int generation = m_queryGeneration;
    withLibrary([this, generation, q]() {
        if (generation != m_queryGeneration)
            return;
        // Same as BookOrbit's web client: the text as q, sorted by title
        m_path = libraryBooksPath();
        m_query = QJsonObject{
            {"q", q},
            {"sort", QJsonArray{QJsonObject{{"field", "title"}, {"dir", "asc"}}}},
        };
        loadPage(0);
    });
}

void SearchResults::findLocalBooks(const QString &text)
{
    // Books with every word of the text in their title, an author or a series, ignoring
    // case and punctuation
    QStringList wanted;
    for (const QString &word : words(text))
        wanted.append(looseText(word));
    m_onlyBooks.clear();
    for (const QVariant &value : std::as_const(m_localBooks)) {
        const QVariantMap book = value.toMap();
        QStringList fields{looseText(book.value("title").toString())};
        for (const QString &author : book.value("authors").toStringList())
            fields.append(looseText(author));
        for (const QString &series : seriesNames(book))
            fields.append(looseText(series));
        const bool matches = std::all_of(wanted.cbegin(), wanted.cend(), [&fields](const QString &word) {
            return std::any_of(fields.cbegin(), fields.cend(), [&word](const QString &field) {
                return field.contains(word);
            });
        });
        if (matches)
            m_onlyBooks.append(book);
    }

    setSortAndFilter("title", false, {}, true);
    showListedBooks();
}

void SearchResults::hideListedPairs(const QVariantList &merged, const QVariantList &rows,
                                    const QList<std::pair<int, QList<QVariantMap>>> &maybeHidden,
                                    const QVariantList &books, std::function<void(const QVariantList &)> then)
{
    // Drop an audiobook row if its ebook record matches the search too. A search can match
    // only the audiobook (by narrator, say), which then stays.
    QVariantList candidates;
    for (const auto &[i, companions] : maybeHidden)
        candidates.append(books.at(i));
    const QJsonObject query{
        {"q", m_query.value("q")},
        {"filter", companionsFilter(candidates)},
        {"pagination", QJsonObject{{"page", 0}, {"size", COMPANIONS_PAGE_SIZE}}},
    };
    const int generation = m_queryGeneration;
    m_session->callJson("POST", libraryBooksPath(), QJsonDocument(query),
        [this, rows, merged, maybeHidden, generation, then](const QJsonDocument &doc) {
            if (generation != m_queryGeneration)
                return;
            QVariantList found;
            for (const QJsonValue &item : doc.object().value("items").toArray())
                found.append(item.toObject().value("id").toVariant());
            QVariantList shown = merged;
            bookrecords::hideListedPairs(shown, rows, maybeHidden, found);
            then(shown);
        },
        // Both rows, rather than none
        [this, merged, generation, then](const QString &) {
            if (generation == m_queryGeneration)
                then(merged);
        });
}

void BooksOf::show(const QString &field, const QStringList &values, const QString &sortField,
                   bool descending, const QStringList &formats, bool localOnly)
{
    // Different books: clear the old rows. A new sort or filter of the same books keeps
    // them until the new rows arrive.
    if (field != m_field || values != m_values)
        clearRows();
    m_field = field;
    m_values = values;
    m_cacheName = "booksOf:" + field + ":" + QJsonDocument(QJsonArray::fromStringList(values)).toJson(QJsonDocument::Compact);

    m_collectionIds.clear();
    if (field == "collection") {
        const int collectionId = values.value(0).toInt();
        // As saved by the last lookup, since a row only has them once looked up
        m_collectionIds = m_database->collectionBookIds(collectionId);
        const QString path = QString("/collections/%1/books").arg(collectionId);
        m_path = path + "/query";
        m_jumpPath = path + "/jump-buckets";
        m_rules = QJsonArray();
        // An audiobook's ebook record may not be in the collection
        m_mergePairs = false;
    } else {
        // The library's books, matching the names exactly. setPaths() sets the path.
        m_rules = QJsonArray{rule(field, "includesAny", QJsonArray::fromStringList(values))};
    }

    setSortAndFilter(sortField, descending, formats, localOnly);
    refresh();
}

void BooksOf::setPaths()
{
    // A collection's are set by show()
    if (m_field != "collection")
        PagedBookList::setPaths();
}

QVariantList BooksOf::localBooks() const
{
    QVariantList books;
    for (const QVariant &value : m_localBooks) {
        const QVariantMap book = value.toMap();
        bool wanted = false;
        if (m_field == "collection") {
            wanted = m_collectionIds.contains(book.value("id"));
        } else if (m_field == "series") {
            wanted = m_values.contains(book.value("seriesName").toString());
        } else {
            for (const QString &author : book.value("authors").toStringList())
                wanted = wanted || m_values.contains(author);
        }
        if (wanted)
            books.append(book);
    }
    return books;
}

QString BooksOf::sortKey(const QVariantMap &book, const QString &field) const
{
    // Position in the collection, oldest first
    if (field == "collectionOrder") {
        const int latest = int(m_collectionIds.indexOf(book.value("id")));
        return QString("%1").arg(m_collectionIds.size() - latest, 8, 10, QChar('0'));
    }
    return PagedBookList::sortKey(book, field);
}

bool BooksOf::checksPairs() const
{
    return m_field == "collection" && m_formats.isEmpty();
}

void BooksOf::hideListedPairs(const QVariantList &merged, const QVariantList &rows,
                              const QList<std::pair<int, QList<QVariantMap>>> &maybeHidden,
                              const QVariantList &, std::function<void(const QVariantList &)> then)
{
    // In a collection with all formats listed, drop the audiobook row if its ebook record is
    // in the collection too, matching the collection counts
    QVariantList shown = merged;
    bookrecords::hideListedPairs(shown, rows, maybeHidden, m_collectionIds);
    then(shown);
}

void BooksOf::cacheSaved()
{
    m_database->keepListCaches("booksOf:", CACHED_BOOKS_OF);
}
