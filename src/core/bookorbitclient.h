#pragma once

#include "core/booklists.h"
#include "core/bookrecords.h"
#include "core/details.h"
#include "core/groupdetails.h"
#include "core/grouplists.h"
#include "core/listfilter.h"
#include "core/recentsearches.h"
#include "core/session.h"
#include "ui/theme.h"

#include <QObject>
#include <QVariantList>

class Database;

// The app's view of a BookOrbit library, as QML sees it ("bookOrbit"): the session, the
// book lists and group lists fetched through it, and what goes with them. Keeps them in
// step as the session starts and ends, the app goes online and books are downloaded.
class BookOrbitClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(Session *session READ session CONSTANT)
    Q_PROPERTY(ListFilter *filter READ filter CONSTANT)
    Q_PROPERTY(Theme *theme READ theme CONSTANT)
    Q_PROPERTY(RecentSearches *recentSearches READ recentSearches CONSTANT)
    Q_PROPERTY(Details *details READ details CONSTANT)
    Q_PROPERTY(LibraryBooks *library READ library CONSTANT)
    Q_PROPERTY(SearchResults *search READ search CONSTANT)
    Q_PROPERTY(BooksOf *booksOf READ booksOf CONSTANT)
    Q_PROPERTY(CollectionList *collections READ collections CONSTANT)
    Q_PROPERTY(SeriesList *series READ series CONSTANT)
    Q_PROPERTY(AuthorList *authors READ authors CONSTANT)
    Q_PROPERTY(AuthorSeriesList *authorSeries READ authorSeries CONSTANT)

public:
    explicit BookOrbitClient(Database *database, QObject *parent = nullptr);

    Session *session() { return &m_session; }
    ListFilter *filter() { return &m_filter; }
    Theme *theme() { return &m_theme; }
    RecentSearches *recentSearches() { return &m_recentSearches; }
    Details *details() { return &m_details; }
    LibraryBooks *library() { return &m_library; }
    SearchResults *search() { return &m_search; }
    BooksOf *booksOf() { return &m_booksOf; }
    CollectionList *collections() { return &m_collections; }
    SeriesList *series() { return &m_series; }
    AuthorList *authors() { return &m_authors; }
    AuthorSeriesList *authorSeries() { return &m_authorSeries; }

    // Loads the book list if a session was saved
    Q_INVOKABLE void start();
    // The books on the device, as Downloads.downloadedBooks() lists them, for the lists set
    // to local books only. Offline, the series, authors, collections and search are built
    // from these. Updates the lists showing them.
    Q_INVOKABLE void setLocalBooks(const QVariantList &books);
    // A record's book files, one per format, primary first: [{format, sizeBytes, kind}],
    // with the format in lower case and kind "ebook" or "audiobook"
    Q_INVOKABLE QVariantList formatFiles(const QVariantMap &book) const
    {
        return bookrecords::formatFiles(book);
    }

private:
    QList<PagedBookList *> bookLists() { return {&m_library, &m_search, &m_booksOf}; }
    QList<GroupList *> groupLists() { return {&m_collections, &m_series, &m_authors, &m_authorSeries}; }
    // Empties every list when the session ends, and forgets what was cached for it
    void clearLists();

    Database *m_database;
    Session m_session;
    ListFilter m_filter;
    Theme m_theme;
    RecentSearches m_recentSearches;
    Details m_details;
    GroupDetails m_groupDetails;
    LibraryBooks m_library;
    SearchResults m_search;
    BooksOf m_booksOf;
    CollectionList m_collections;
    SeriesList m_series;
    AuthorList m_authors;
    AuthorSeriesList m_authorSeries;
};
