#pragma once

#include "core/booklistmodel.h"

#include <QHash>
#include <QList>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class Database;
class Details;
class GroupDetails;
class Session;

// Collections, series or authors: one row each, loaded whole and sorted locally. Each row's
// books are looked up as it comes into view, for its formats, counts, cover versions and the
// like, and what's found is saved for next time (see GroupDetails). Offline, the rows are
// built from the local books.
class GroupList : public QObject
{
    Q_OBJECT
    // One row per group (role "book"), sorted, with sectionStart and sectionLabel set on the
    // first row of each letter when sorted by name
    Q_PROPERTY(BookListModel *model READ model CONSTANT)
    // Set when loading the list fails, cleared when it loads again. Empty offline, which the
    // header shows instead.
    Q_PROPERTY(QString error READ error NOTIFY changed)
    // Letter sections when sorted by name, else empty
    Q_PROPERTY(QVariantList jumpSections READ jumpSections NOTIFY changed)
    // Whether the list has loaded since sign-in
    Q_PROPERTY(bool loaded READ loaded NOTIFY changed)

public:
    GroupList(Session *session, Database *database, Details *details, GroupDetails *groupDetails,
              QObject *parent = nullptr);

    BookListModel *model() { return &m_model; }
    QString error() const { return m_error; }
    QVariantList jumpSections() const { return m_jumpSections; }
    bool loaded() const { return m_loaded; }

    // Fetches the list. Existing rows, or the saved ones, stay until the new ones arrive.
    // Offline, builds them from the local books.
    Q_INVOKABLE void load();
    // Sorts by "name", "bookCount", "lastAddedAt", "readProgress" or, for authors,
    // "sortName"
    Q_INVOKABLE void setSort(const QString &field, bool descending);
    // Looks up the books of rows first to last, once each per load. Called while scrolling
    // for the visible rows plus a screen either side. Until the list has loaded, it waits
    // for it. Rows asked for before and not yet looked up are dropped.
    Q_INVOKABLE void lookUpRows(int first, int last);

    // The books on the device, as Downloads.downloadedBooks() lists them. Offline, rows
    // built from them are rebuilt.
    virtual void setLocalBooks(const QVariantList &books);
    // Empties the list when the session ends
    void clear();
    // Back online: rows built offline are to be fetched again
    void forgetLocalRows();

signals:
    void changed();

protected:
    // The books a lookup has found for a row so far: each book's formats by its companion
    // key, so a separate ebook and audiobook count once, and for an author the series each
    // is in
    struct FoundBooks {
        QHash<QString, QStringList> formatsOf;
        QHash<QString, QStringList> seriesOf;
        QStringList formats;

        // What earlier pages of the same lookup found
        static FoundBooks in(const QVariantMap &row);
        void add(const QVariantMap &book, bool withSeries);
        // Sets the row's books, formats and, withSeries, bookSeries. Once complete, its
        // counts too.
        void putIn(QVariantMap &row, bool withSeries, bool complete) const;
    };

    // Books per request when looking up rows' books
    static constexpr int LOOKUP_PAGE_SIZE = 200;

    // Loads page onwards from the server, once the library is known if needsLibrary()
    virtual void loadPage(int page, int generation) = 0;
    virtual bool needsLibrary() const { return true; }
    // Rows for the local books, as though looked up
    virtual void showLocal() = 0;
    // Looks up the books of the rows with these ids, then calls lookUpNextRows()
    virtual void lookUp(const QList<int> &ids, int generation) = 0;
    // Whether each row is looked up on its own, and an empty one not at all (collections).
    // Otherwise rows go a few to a request.
    virtual bool lookUpAlone() const { return false; }
    // Whether every row needs looking up, those in view first, not just those in view
    virtual bool lookUpAll() const { return false; }
    // The rows to show, of those loaded (or cached)
    virtual QList<QVariantMap> filtered(const QList<QVariantMap> &rows) const { return rows; }

    // Starts loading again, with a new generation, nothing looked up and no error. Returns
    // the generation.
    int startLoad();
    // After a page arrives, loads the next with loadNext if there are more, or else
    // finishes the list and looks up the rows in view
    void pageLoaded(bool more, std::function<void()> loadNext);
    // Sorts the rows into the model and builds the A-Z sections
    void show();
    // show() for a load in progress: not while the cached rows are shown
    void showLoaded();
    // Built offline: shows them in place of any cached rows
    void showLocalRows();
    // Looks up the wanted rows, if the list is ready for it
    void lookUpWantedRows();
    // Sends the next request for the waiting rows, as many as fit in one
    void lookUpNextRows(int generation);
    // Stops after a failed lookup, to try again when rows are next wanted
    void stopLookingUp();
    // Looks up the books of the series or authors with these ids, from page onwards
    void lookUpByName(const QList<int> &ids, bool authors, int page, int generation);
    // Saves what a row's lookup found, if the list's are saved
    void saveRowDetails(const QVariantMap &row);
    // A row with any saved details put in
    QVariantMap withSavedDetails(QVariantMap row);
    void setError(const QString &error);
    // The row with this id, or nullptr
    QVariantMap *rowWithId(int id);
    // A row's covers, with the versions known for their books
    static QVariantList withCoverVersions(QVariantList covers, const QHash<int, QVariant> &versions);
    // How many series a row's books are in, books being key -> series names
    static int seriesCount(const QHash<QString, QStringList> &bookSeries);
    // A stable id for a row built offline, negative so it can't clash with the server's
    static int localId(const QString &name);
    // The rows on screen: the cached ones, until loaded
    const QList<QVariantMap> &shownRows() const { return m_cached.isEmpty() ? m_rows : m_cached; }

    Session *m_session;
    Database *m_database;
    Details *m_details;
    GroupDetails *m_groupDetails;
    // Its list cache name, or empty if it isn't cached
    QString m_cacheName;
    // The kind its rows' looked up details are saved as, or empty if they aren't
    QString m_detailsKind;
    // Fields saved with the details besides bookCount, formats and covers
    QStringList m_detailFields;
    // Only some of its kind's rows (an author's series), so its loads don't say which saved
    // details have gone
    bool m_partial = false;
    // In server order; the model is sorted
    QList<QVariantMap> m_rows;
    QVariantList m_localBooks;
    bool m_loaded = false;
    // Bumped on reload so stale replies are dropped
    int m_generation = 0;
    QString m_sort = "name";   // the sort menu's default
    bool m_descending = false;
    // Whether every row's books have been looked up (series and authors only)
    bool m_allLookedUp = false;
    // Rows whose books have been looked up since the list was loaded, by id
    QSet<int> m_lookedUp;
    // Rows built from the local books while offline, to fetch again once online
    bool m_local = false;

private:
    // Calls load once the library id is known, unless the list has been loaded again since
    void withLibrary(int generation, std::function<void()> load);
    // Shows the cached rows, if any, until a load finishes. Only the first time it's
    // called.
    void restoreCache();
    void saveCache();
    // After a whole list has loaded, deletes the saved details of rows no longer in it
    void forgetGoneDetails();
    // Looks up the books of the rows with these ids, replacing any waiting, a request at a
    // time
    void queueLookUps(const QList<int> &ids);

    BookListModel m_model;
    QVariantList m_jumpSections;
    QString m_error;
    // Ids of the rows to look up next, those on screen
    QList<int> m_wanted;
    // Rows of the model last asked for (see lookUpRows), looked up once loaded
    int m_wantedFirst = 0;
    int m_wantedLast = -1;
    // The generation a lookup is in flight for, or -1
    int m_lookingUpGeneration = -1;
    // Rows from the list cache, shown instead of the rows until a load finishes
    QList<QVariantMap> m_cached;
    // Whether the cache has been read. Not until the list is first loaded, as a hidden list
    // with rows still makes delegates, which fetch covers.
    bool m_cacheRead = false;
};
