#pragma once

#include "core/booklistmodel.h"
#include "core/bookrecords.h"
#include "core/details.h"
#include "core/recentsearches.h"
#include "core/session.h"
#include "ui/theme.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QHash>
#include <QSet>
#include <QList>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <functional>

class Database;

// The app's view of a BookOrbit library: its book lists and groups, fetched through the
// session (see Session), or built from the local books offline
class BookOrbitClient : public QObject
{
    Q_OBJECT
    // Each list's error: set when a request for it fails, cleared when it loads again.
    // Empty offline, which the header shows instead.
    Q_PROPERTY(QString booksError READ booksError NOTIFY booksChanged)
    Q_PROPERTY(QString searchError READ searchError NOTIFY searchChanged)
    Q_PROPERTY(QString booksOfError READ booksOfError NOTIFY booksOfChanged)
    Q_PROPERTY(QString collectionsError READ collectionsError NOTIFY collectionsChanged)
    Q_PROPERTY(QString seriesError READ seriesError NOTIFY seriesListChanged)
    Q_PROPERTY(QString authorsError READ authorsError NOTIFY authorsChanged)
    Q_PROPERTY(QString authorSeriesError READ authorSeriesError NOTIFY authorSeriesChanged)
    Q_PROPERTY(Session *session READ session CONSTANT)
    Q_PROPERTY(Theme *theme READ theme CONSTANT)
    Q_PROPERTY(RecentSearches *recentSearches READ recentSearches CONSTANT)
    Q_PROPERTY(Details *details READ details CONSTANT)
    Q_PROPERTY(BookListModel *books READ books CONSTANT)
    // Number of books, or -1 until known
    Q_PROPERTY(int totalBooks READ totalBooks NOTIFY booksChanged)
    // Jump rail sections for the A-Z sorts, e.g. [{label: "A", index: 2}, ...]. Empty for
    // date sorts.
    Q_PROPERTY(QVariantList jumpSections READ jumpSections NOTIFY jumpSectionsChanged)
    // Search results, by title
    Q_PROPERTY(BookListModel *searchResults READ searchResults CONSTANT)
    // Number of matches, or -1 until known
    Q_PROPERTY(int searchTotal READ searchTotal NOTIFY searchChanged)
    // Books listed by showBooksOf()
    Q_PROPERTY(BookListModel *booksOf READ booksOf CONSTANT)
    // Number of books, or -1 until known
    Q_PROPERTY(int booksOfTotal READ booksOfTotal NOTIFY booksOfChanged)
    // The user's collections, one row each (role "book"): {id, name, bookCount, covers
    // (the last two added books with covers), authors (by surname), formats}. All but the
    // name come from looking up a collection's books (see lookUpRows()), saved
    // from the last time; bookCount then counts a separate ebook and audiobook record as
    // one book.
    Q_PROPERTY(BookListModel *collections READ collections CONSTANT)
    // Letter sections when sorted by name, else empty. The first row of each section has
    // sectionStart and sectionLabel set.
    Q_PROPERTY(QVariantList collectionJumpSections READ collectionJumpSections NOTIFY collectionsChanged)
    // Whether collections have loaded since sign-in
    Q_PROPERTY(bool collectionsLoaded READ collectionsLoaded NOTIFY collectionsChanged)
    // The library's series, in rows like the collections': {id, name, bookCount, covers
    // (first two books), authors, formats, lastAddedAt, readProgress (0 to 1)}. Formats,
    // cover versions and a bookCount that counts an ebook/audiobook pair once come from
    // looking up a series' books (see lookUpRows()), saved from the last time.
    Q_PROPERTY(BookListModel *seriesList READ seriesList CONSTANT)
    Q_PROPERTY(QVariantList seriesJumpSections READ seriesJumpSections NOTIFY seriesListChanged)
    Q_PROPERTY(bool seriesLoaded READ seriesLoaded NOTIFY seriesListChanged)
    // The library's authors: {kind: "author", id, name, sortName ("Martin, George R.R."),
    // bookCount, photo (imageUrl, or ""), lastAddedAt, formats, seriesCount (-1 until their
    // books are looked up), bookSeries}. Formats, counts and series come from looking up
    // an author's books (see lookUpRows()), saved from the last time. With a filter
    // set, counts and formats cover only matching books.
    Q_PROPERTY(BookListModel *authorsList READ authorsList CONSTANT)
    Q_PROPERTY(QVariantList authorJumpSections READ authorJumpSections NOTIFY authorsChanged)
    Q_PROPERTY(bool authorsLoaded READ authorsLoaded NOTIFY authorsChanged)
    // Whether every author's books have been looked up this time. Filtering by format
    // needs this.
    Q_PROPERTY(bool allAuthorsLookedUp READ allAuthorsLookedUp NOTIFY authorsChanged)
    // One author's series (see showAuthorSeries()), in rows like seriesList's
    Q_PROPERTY(BookListModel *authorSeriesList READ authorSeriesList CONSTANT)
    Q_PROPERTY(QVariantList authorSeriesJumpSections READ authorSeriesJumpSections NOTIFY authorSeriesChanged)
    Q_PROPERTY(bool authorSeriesLoaded READ authorSeriesLoaded NOTIFY authorSeriesChanged)
    // Jump sections for booksOf: letters for an author's books, series numbers for a
    // series (e.g. [{label: "12", index: 11}, ...])
    Q_PROPERTY(QVariantList booksOfJumpSections READ booksOfJumpSections NOTIFY jumpSectionsChanged)

public:
    explicit BookOrbitClient(Database *database, QObject *parent = nullptr);

    QString booksError() const { return m_list.error; }
    QString searchError() const { return m_search.error; }
    QString booksOfError() const { return m_booksOf.error; }
    QString collectionsError() const { return m_collections.error; }
    QString seriesError() const { return m_series.error; }
    QString authorsError() const { return m_authors.error; }
    QString authorSeriesError() const { return m_authorSeries.error; }
    Session *session() { return &m_session; }
    Theme *theme() { return &m_theme; }
    RecentSearches *recentSearches() { return &m_recentSearches; }
    Details *details() { return &m_details; }
    BookListModel *books() { return &m_list.model; }
    int totalBooks() const;
    QVariantList jumpSections() const { return m_list.jumpSections; }
    BookListModel *searchResults() { return &m_search.model; }
    int searchTotal() const;
    BookListModel *booksOf() { return &m_booksOf.model; }
    int booksOfTotal() const;
    QVariantList booksOfJumpSections() const { return m_booksOf.jumpSections; }
    BookListModel *collections() { return &m_collections.model; }
    bool collectionsLoaded() const { return m_collections.loaded; }
    QVariantList collectionJumpSections() const { return m_collections.jumpSections; }
    BookListModel *seriesList() { return &m_series.model; }
    bool seriesLoaded() const { return m_series.loaded; }
    QVariantList seriesJumpSections() const { return m_series.jumpSections; }
    BookListModel *authorsList() { return &m_authors.model; }
    bool authorsLoaded() const { return m_authors.loaded; }
    bool allAuthorsLookedUp() const { return m_authors.allLookedUp; }
    QVariantList authorJumpSections() const { return m_authors.jumpSections; }
    BookListModel *authorSeriesList() { return &m_authorSeries.model; }
    bool authorSeriesLoaded() const { return m_authorSeries.loaded; }
    QVariantList authorSeriesJumpSections() const { return m_authorSeries.jumpSections; }

    // Loads the book list if a session was saved
    Q_INVOKABLE void start();
    // Sets the book list's sort and filter, and reloads it.
    //   sortField   addedAt, title, author or lastReadAt
    //   descending  Z to A, or newest first
    //   formats     only books in these formats; empty for all
    //   localOnly   list the local books (see setLocalBooks) instead of asking the server,
    //               so it works offline
    Q_INVOKABLE void setBookQuery(const QString &sortField, bool descending,
                                  const QStringList &formats, bool localOnly = false);
    // Reloads the book list from page one
    Q_INVOKABLE void refreshBooks();
    // Loads whichever pages cover rows first to last and aren't loaded yet. Called while
    // scrolling for the visible rows plus a screen either side.
    Q_INVOKABLE void loadBooks(int first, int last);

    // Searches titles, authors and series. Text shorter than MIN_SEARCH_LENGTH clears the
    // results.
    Q_INVOKABLE void search(const QString &text);
    // loadBooks() for the search results
    Q_INVOKABLE void loadSearchResults(int first, int last);
    // Fills booksOf with the books of some authors (field "author", values are names), a
    // series ("series", its name) or a collection ("collection", its id). Sorting and
    // filtering work as in setBookQuery(), plus "seriesIndex" (series order, with a section
    // per number) and, for collections, "collectionOrder" (order added). Existing rows stay
    // until the new ones arrive.
    Q_INVOKABLE void showBooksOf(const QString &field, const QStringList &values,
                                 const QString &sortField, bool descending,
                                 const QStringList &formats = {}, bool localOnly = false);
    // loadBooks() for booksOf
    Q_INVOKABLE void loadBooksOf(int first, int last);
    // The books on the device, as Downloads.downloadedBooks() lists them, for the lists
    // set to local books only. Offline, the series, authors and search are built from
    // these. Updates the lists showing them.
    Q_INVOKABLE void setLocalBooks(const QVariantList &books);
    // Fetches the user's collections. Existing rows, or the saved ones, stay until the new
    // ones arrive.
    Q_INVOKABLE void loadCollections();
    // Sorts collections by "name" or "bookCount"
    Q_INVOKABLE void setCollectionSort(const QString &field, bool descending);
    // Fetches the library's series. Existing rows, or the saved ones, stay until the new
    // ones arrive.
    Q_INVOKABLE void loadSeries();
    // Sorts series by "name", "bookCount", "lastAddedAt" or "readProgress"
    Q_INVOKABLE void setSeriesSort(const QString &field, bool descending);
    // Fetches the library's authors. Existing rows, or the saved ones, stay until the new
    // ones arrive.
    Q_INVOKABLE void loadAuthors();
    // Sorts authors by "name", "sortName", "bookCount" or "lastAddedAt", and keeps only
    // those with books in formats (and, with localOnly, among the local books). Choosing
    // formats, without localOnly, looks up every author's books.
    Q_INVOKABLE void setAuthorQuery(const QString &sortField, bool descending, const QStringList &formats,
                                    bool localOnly = false);
    // Fills authorSeriesList with the series containing books by author
    Q_INVOKABLE void showAuthorSeries(const QString &author);
    // Looks up the books of rows first to last of a group list (collections, seriesList,
    // authorsList or authorSeriesList), for their formats, counts, cover versions and the
    // like, once each per load. Called while scrolling for the visible rows plus a screen
    // either side. Until the list has loaded, it waits for it. Rows asked for before and
    // not yet looked up are dropped. Series and authors go a few to a request,
    // collections one each. With a format filter on the authors, every author is looked
    // up, those in view first.
    Q_INVOKABLE void lookUpRows(BookListModel *model, int first, int last);
    // Same fields as setSeriesSort()
    Q_INVOKABLE void setAuthorSeriesSort(const QString &field, bool descending);
    // The author's unfiltered row from authorsList, or empty if not listed
    Q_INVOKABLE QVariantMap authorRow(int authorId) const;
    // A record's book files, one per format, primary first: [{format, sizeBytes, kind}],
    // with the format in lower case and kind "ebook" or "audiobook"
    Q_INVOKABLE QVariantList formatFiles(const QVariantMap &book) const
    {
        return bookrecords::formatFiles(book);
    }

signals:
    void booksChanged();
    void jumpSectionsChanged();
    void searchChanged();
    void booksOfChanged();
    void collectionsChanged();
    void seriesListChanged();
    void authorsChanged();
    void authorSeriesChanged();

private:
    // How a list is sectioned: not at all, at the rows in sectionStarts (A-Z, or the
    // server's date buckets for last read), by day (date added), or by series number (rows
    // then omit the series name)
    enum class Sections { None, Starts, Days, SeriesNumbers };

    // A book list loaded a page at a time. The model has a row for every book once the
    // first page arrives; other pages load on demand.
    struct PagedBooks {
        BookListModel model;
        // BookOrbit query: sort, filter and search text
        QJsonObject query;
        // Pages (from 0) loaded and in flight for the current query
        QSet<int> loadedPages;
        QSet<int> loadingPages;
        // Endpoint: the library's books or a collection's
        QString path;
        QString jumpPath;
        // Sort and filter (see setBookQuery), plus fixed rules such as booksOf's author or
        // series
        QJsonArray rules;
        QString sortField = "title";
        bool sortDescending = false;
        QStringList formats;
        bool onlyListed = false;
        QVariantList onlyBooks;
        // Bumped on reload so stale replies are dropped
        int queryGeneration = 0;
        // Generation the rows belong to. The old rows stay until a new query's first page
        // arrives.
        int listGeneration = -1;
        // Its list cache name ("library", "booksOf:<field>:<values>"), or empty if it isn't
        // cached
        QString cacheName;
        // The rows are from the list cache, for this query: its first page updates them in
        // place, keeping the scroll position
        bool cached = false;
        // Its first rows have changed since the list cache was saved
        bool cacheDirty = false;
        // Rows asked for while waiting for the first page, loaded once it's in
        int wantedFirst = 0;
        int wantedLast = -1;
        int total = 0;
        // Hide audiobook records whose ebook is a separate record, so one row covers both.
        // Only safe when the ebook is guaranteed to be in the list.
        bool mergePairs = false;
        Sections sections = Sections::None;
        // See jumpSections. For Starts, sectionStarts maps each section's first row to its
        // letter.
        QVariantList jumpSections;
        QHash<int, QString> sectionStarts;
        // See booksError
        QString error;
    };

    // How a group list's rows have their books looked up. Series and authors go by name, a
    // few to a request, and a collection on its own.
    enum class Lookup { Series, Authors, Collection };

    // Collections, series or authors: one row each, sorted locally
    struct Groups {
        // Set once, in the constructor
        Lookup lookup = Lookup::Series;
        // Its list cache name, or empty if it isn't cached
        QString cacheName;
        // The kind its rows' looked up details are saved as, or empty if they aren't
        QString detailsKind;
        // Fields saved with the details besides bookCount, formats and covers
        QStringList detailFields;
        // Only some of its kind's rows (an author's series), so its loads don't say which
        // saved details have gone
        bool partial = false;
        // rows is in server order, model is sorted
        QList<QVariantMap> rows;
        BookListModel model;
        // Letter sections, when sorted by name
        QVariantList jumpSections;
        bool loaded = false;
        // Bumped on reload so stale replies are dropped
        int generation = 0;
        QString sort = "name";   // the sort menu's default
        bool descending = false;
        // Authors' filter (see setAuthorQuery)
        QStringList formats;
        bool localOnly = false;
        // Whether every row's books have been looked up (series and authors only)
        bool allLookedUp = false;
        // Rows whose books have been looked up since the list was loaded, by id
        QSet<int> lookedUp;
        // Ids of the rows to look up next, those on screen
        QList<int> wanted;
        // Rows of the model last asked for (see lookUpRows), looked up once loaded
        int wantedFirst = 0;
        int wantedLast = -1;
        // The generation a lookup is in flight for, or -1
        int lookingUpGeneration = -1;
        // Rows built from the local books while offline, to fetch again once online
        bool local = false;
        // Rows from the list cache, shown instead of rows until a load finishes
        QList<QVariantMap> cached;
        // Whether the cache has been read. Not until the list is first loaded, as a hidden
        // list with rows still makes delegates, which fetch covers.
        bool cacheRead = false;
        // See collectionsError
        QString error;
    };

    // The rows on screen: the cached ones, until loaded
    static const QList<QVariantMap> &shownRows(const Groups &groups)
    {
        return groups.cached.isEmpty() ? groups.rows : groups.cached;
    }

    // Emits the list's change signal (booksChanged, searchChanged, ...)
    void emitChanged(const PagedBooks &list);
    void emitChanged(const Groups &groups);
    // Sets the list's error, emitting its change signal if that changes it
    void setListError(PagedBooks &list, const QString &error);
    void setListError(Groups &groups, const QString &error);
    // Endpoint for library book queries
    QString libraryBooksPath() const { return QString("/libraries/%1/books").arg(m_session.libraryId()); }
    // Looks up a collection's books from page onwards, for its covers, authors, formats,
    // count and book ids
    void lookUpCollection(int collectionId, int page, int generation);
    // Sorts rows into the model and builds the A-Z sections
    void showGroups(Groups &groups);
    // showGroups() for a load in progress: not while the cached rows are shown
    void showLoadedGroups(Groups &groups);
    // A load has finished: shows its rows in place of any cached ones and, if complete,
    // caches them
    void finishGroups(Groups &groups, bool complete);
    // Starts loading a group list again, with a new generation, nothing looked up and no
    // error. Returns the generation.
    int startLoad(Groups &groups);
    // Calls load once the library id is known, unless the list has been loaded again since
    void loadWithLibrary(Groups &groups, int generation, std::function<void()> load);
    // After a page of a group list arrives, loads the next with loadNext if there are more,
    // or else finishes the list and looks up the rows in view
    void listPageLoaded(Groups &groups, bool more, std::function<void()> loadNext);
    // Caches a group list's rows
    void saveListCache(const Groups &groups);
    // Shows a group list's cached rows, if any, until a load finishes. Only the first time
    // it's called.
    void restoreList(Groups &groups);
    // Caches a book list's first rows, for the same books, sort and filter next time
    void saveListCache(PagedBooks &list);
    // Shows a book list's cached rows, if they're for its sort and filter
    void restoreList(PagedBooks &list);
    // Loads series (the library's or an author's) one page at a time
    void loadSeriesPage(Groups *groups, int page, int generation);
    // Notes rows first to last of the model as wanted, and looks them up once the list has
    // loaded
    void wantRows(Groups &groups, int first, int last);
    void lookUpWantedRows(Groups &groups);
    // Looks up the books of the rows with these ids, replacing any waiting, a request at a
    // time
    void queueLookUps(Groups *groups, const QList<int> &ids);
    // Sends the next request for the waiting rows, as many as fit in one
    void lookUpNextRows(Groups *groups, int generation);
    // Stops after a failed lookup, to try again when rows are next wanted
    void stopLookingUp(Groups &groups);
    // Looks up the books of the series or authors with these ids, from page onwards, for
    // formats, counts and cover versions
    void lookUpByName(Groups *groups, const QList<int> &ids, int page, int generation);
    // Whether the authors are filtered by format, not just to the local books, so every
    // author needs looking up
    static bool filteringByFormat(const Groups &groups);
    // After a whole list has loaded, deletes the saved details of rows no longer in it
    void forgetGoneDetails(Groups &groups);
    // Saves what a row's lookup found, if its list's are saved
    void saveRowDetails(const Groups &groups, const QVariantMap &row);
    // The saved details of a kind, read the first time
    QHash<int, QVariantMap> &savedDetails(const QString &kind);
    // A row with any saved details of its group put in
    QVariantMap withSavedDetails(const Groups &groups, QVariantMap row);
    // Loads authors one page at a time
    void loadAuthorsPage(int page, int generation);
    // Offline: rows for the series (the library's or the author's) or authors of the local
    // books, as though looked up
    void showLocalSeries(Groups &groups);
    void showLocalAuthors();
    // Offline: the saved collections with local books, counting only those
    void showLocalCollections();
    // Offline: the local books matching the search text
    void searchLocalBooks(const QString &text);
    // Calls then once the library id is known (see Session::withLibrary), or onFailed with
    // the error to show
    void loadLibrary(std::function<void()> then, Session::FailedHandler onFailed);
    // Empties every list when the session ends, and forgets what was cached for it
    void clearLists();
    // Back online: rows built offline are to be fetched again
    void forgetLocalRows();
    // Builds the BookOrbit query for a list's sort and filter
    static QJsonObject bookQuery(const PagedBooks &list);
    // Reloads from page one, or lists the local books
    void refreshList(PagedBooks &list);
    // The local books among booksOf's author, series or collection
    QVariantList localBooksOf() const;
    // Filters, sorts and sections onlyBooks locally, matching the server's lists
    void showListedBooks(PagedBooks &list);
    // Loads the A-Z jump buckets for a list's query, then calls then
    void loadJumpSections(PagedBooks &list, std::function<void()> then);
    // Loads series numbers for a list sorted by them, as its jumpSections, from page
    // onwards
    void loadSeriesSections(PagedBooks &list, int page = 0);
    // Clears a list's jump sections
    void clearJumpSections(PagedBooks &list);
    // Starts a new query generation, so replies to the old one are ignored
    void restartPages(PagedBooks &list);
    void loadPages(PagedBooks &list, int first, int last);
    void loadPage(PagedBooks &list, int page);
    // Finds other records of the same books on a newly loaded page (e.g. a separate
    // audiobook with the same title and first author), merges their formats into the page's
    // rows and calls then with them. If the lookup fails, then gets the rows unmerged.
    void lookUpCompanions(PagedBooks *list, const QVariantList &books, const QVariantList &rows,
                          int generation, std::function<void(const QVariantList &rows)> then);
    // A row for a record (see bookrecords::row), sectioned by day if the list is
    static QVariantMap decorateBook(const QVariantMap &book, const PagedBooks &list);
    // Marks which rows from first to last start a section
    void updateSectionStarts(PagedBooks &list, int first, int last);
    // Letter sorts and date sorts
    static bool isLetterSort(const QString &field) { return field == "title" || field == "author"; }
    // Sorts sectioned by each book's date. Last read has no date per book (see refreshList).
    static bool isDateSort(const QString &field) { return field == "addedAt"; }

    Database *m_database;
    Session m_session;
    Theme m_theme;
    RecentSearches m_recentSearches;
    Details m_details;
    // Main library list
    PagedBooks m_list;
    // Saves the book lists' caches once a refresh settles
    QTimer m_listCacheTimer;
    PagedBooks m_search;
    PagedBooks m_booksOf;
    // What booksOf shows (see showBooksOf). For a collection, the book ids
    // loadCollections() found, newest first.
    QString m_booksOfField;
    QStringList m_booksOfValues;
    QVariantList m_booksOfCollectionIds;
    Groups m_collections;
    Groups m_series;
    Groups m_authors;
    Groups m_authorSeries;
    // What looking up rows' books found, by kind and id (see Database::groupDetails)
    QHash<QString, QHash<int, QVariantMap>> m_savedDetails;
    // Author whose series m_authorSeries holds
    QString m_authorSeriesName;
    QVariantList m_localBooks;
};
