#pragma once

#include "core/booklistmodel.h"

#include <QHash>
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <functional>
#include <utility>

class Database;
class Details;
class Session;

// A book list loaded a page at a time. The model has a row for every book once the first
// page arrives; other pages load on demand. Lists set to local books only list the books on
// the device instead (see setLocalBooks()), sorted and sectioned as the server would.
class PagedBookList : public QObject
{
    Q_OBJECT
    Q_PROPERTY(BookListModel *model READ model CONSTANT)
    // Number of books, or -1 until known
    Q_PROPERTY(int total READ total NOTIFY changed)
    // Set when a request for the list fails, cleared when it loads again. Empty offline,
    // which the header shows instead.
    Q_PROPERTY(QString error READ error NOTIFY changed)
    // Jump rail sections, e.g. [{label: "A", index: 2}, ...]: letters for the A-Z sorts,
    // series numbers for series order (e.g. [{label: "12", index: 11}, ...]), else empty
    Q_PROPERTY(QVariantList jumpSections READ jumpSections NOTIFY jumpSectionsChanged)

public:
    PagedBookList(Session *session, Database *database, Details *details, QObject *parent = nullptr);

    BookListModel *model() { return &m_model; }
    int total() const { return m_listGeneration == m_queryGeneration ? m_total : -1; }
    QString error() const { return m_error; }
    QVariantList jumpSections() const { return m_jumpSections; }

    // Loads whichever pages cover rows first to last and aren't loaded yet. Called while
    // scrolling for the visible rows plus a screen either side.
    Q_INVOKABLE void load(int first, int last);

    // The books on the device, as Downloads.downloadedBooks() lists them. Relists them if
    // the list shows only those.
    virtual void setLocalBooks(const QVariantList &books);
    // Empties the list when the session ends
    void clear();
    // Stops the list cache's rows being shown, as when they're from another library
    void forgetCache();

signals:
    void changed();
    void jumpSectionsChanged();

protected:
    // How a list is sectioned: not at all, at the rows in sectionStarts (A-Z, or the
    // server's date buckets for last read), by day (date added), or by series number (rows
    // then omit the series name)
    enum class Sections { None, Starts, Days, SeriesNumbers };
    // Books per page
    static constexpr int PAGE_SIZE = 40;
    // Records fetched when looking for a page's other records of the same books
    static constexpr int COMPANIONS_PAGE_SIZE = 4 * PAGE_SIZE;
    // Rows kept in the list cache, a couple of screens' worth
    static constexpr int CACHED_ROWS = 2 * PAGE_SIZE;

    // Sets the sort and filter (see LibraryBooks::setQuery)
    void setSortAndFilter(const QString &sortField, bool descending, const QStringList &formats,
                          bool localOnly);
    // Reloads from page one, or lists the local books
    void refresh();
    // Starts a new query generation, so replies to the old one are ignored
    void restartPages();
    // Clears the rows, for different books
    void clearRows();
    // Calls then once the library is known, or sets the error
    void withLibrary(std::function<void()> then);
    void loadPage(int page);
    // Lists onlyBooks: filtered, sorted and sectioned locally, matching the server's lists
    void showListedBooks();
    // Saves the list's first rows, if it's cached and they've changed
    void saveCache();
    void setError(const QString &error);

    // When the library is known: sets the endpoints and mergePairs for the query
    virtual void setPaths();
    // setPaths() for the books in a library, or in every library for -1
    void setLibraryPaths(int libraryId);
    // The local books in a library (all for -1, or offline), and those whose library isn't
    // known
    QVariantList localBooksIn(int libraryId) const;
    // The local books this list shows when set to local books only
    virtual QVariantList localBooks() const { return m_localBooks; }
    // Whether the list has sections. Search results have none, as from the server.
    virtual bool sectioned() const { return true; }
    // A book's sort key for listing local books, matching the server's
    virtual QString sortKey(const QVariantMap &book, const QString &field) const;
    // Whether an audiobook row may be hidden for an ebook record that is maybe in the list
    // (see hideListedPairs)
    virtual bool checksPairs() const { return false; }
    // Hides the rows in maybeHidden (row, its companions) whose ebook record is in the list,
    // then calls then. merged has the companions merged in; rows doesn't.
    virtual void hideListedPairs(const QVariantList &merged, const QVariantList &rows,
                                 const QList<std::pair<int, QList<QVariantMap>>> &maybeHidden,
                                 const QVariantList &books, std::function<void(const QVariantList &)> then);
    // Called while saving the cache, in its transaction
    virtual void cacheSaved() {}
    // Builds the BookOrbit query for the sort and filter
    QJsonObject bookQuery() const;

    Session *m_session;
    Database *m_database;
    Details *m_details;
    BookListModel m_model;
    // BookOrbit query: sort, filter and search text
    QJsonObject m_query;
    // Endpoint: a library's books, every library's or a collection's. Without a jump path,
    // the server can't section A-Z or last read sorts, and they go unsectioned.
    QString m_path;
    QString m_jumpPath;
    // Where a page's other records of the same books are looked for
    QString m_companionsPath;
    // Sort and filter (see setQuery), plus fixed rules such as booksOf's author or series
    QJsonArray m_rules;
    QString m_sortField = "title";
    bool m_sortDescending = false;
    QStringList m_formats;
    bool m_onlyListed = false;
    QVariantList m_onlyBooks;
    QVariantList m_localBooks;
    // Bumped on reload so stale replies are dropped
    int m_queryGeneration = 0;
    // Generation the rows belong to. The old rows stay until a new query's first page
    // arrives.
    int m_listGeneration = -1;
    int m_total = 0;
    // Hide audiobook records whose ebook is a separate record, so one row covers both.
    // Only safe when the ebook is guaranteed to be in the list.
    bool m_mergePairs = false;
    // Its list cache name ("library", "booksOf:<field>:<values>"), or empty if it isn't
    // cached
    QString m_cacheName;
    // Its first rows have changed since the list cache was saved
    bool m_cacheDirty = false;

private:
    // Loads the A-Z jump buckets for the query, then calls then
    void loadJumpSections(std::function<void()> then);
    // Loads series numbers for a list sorted by them, as its jumpSections, from page onwards
    void loadSeriesSections(int page = 0);
    void clearJumpSections();
    // Finds other records of the same books on a newly loaded page (e.g. a separate
    // audiobook with the same title and first author), merges their formats into the page's
    // rows and calls then with them. If the lookup fails, then gets the rows unmerged.
    void lookUpCompanions(const QVariantList &books, const QVariantList &rows, int generation,
                          std::function<void(const QVariantList &rows)> then);
    // A row for a record, sectioned by day if the list is
    QVariantMap decorateBook(const QVariantMap &book) const;
    // Marks which rows from first to last start a section
    void updateSectionStarts(int first, int last);
    // Shows the cached rows, if they're for this sort and filter
    void restoreCache();
    // Letter sorts and date sorts
    static bool isLetterSort(const QString &field) { return field == "title" || field == "author"; }
    // Sorts sectioned by each book's date. Last read has no date per book (see refresh).
    static bool isDateSort(const QString &field) { return field == "addedAt"; }

    // Pages (from 0) loaded and in flight for the current query
    QSet<int> m_loadedPages;
    QSet<int> m_loadingPages;
    // The rows are from the list cache, for this query: its first page updates them in
    // place, keeping the scroll position
    bool m_cached = false;
    // Saves the cache once a refresh settles, rather than on each page and companion lookup
    QTimer m_cacheTimer;
    // Rows asked for while waiting for the first page, loaded once it's in
    int m_wantedFirst = 0;
    int m_wantedLast = -1;
    Sections m_sections = Sections::None;
    // For Starts, each section's first row and its label
    QHash<int, QString> m_sectionStarts;
    QVariantList m_jumpSections;
    QString m_error;
};
