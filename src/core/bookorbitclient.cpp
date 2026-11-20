#include "core/bookorbitclient.h"
#include "core/database.h"

BookOrbitClient::BookOrbitClient(Database *database, QObject *parent)
    : QObject(parent)
    , m_database(database)
    , m_session(database)
    , m_filter(&m_session, database)
    , m_theme(&m_session, database)
    , m_recentSearches(&m_session, database)
    , m_details(&m_session, database)
    , m_groupDetails(database)
    , m_library(&m_session, database, &m_details)
    , m_search(&m_session, database, &m_details)
    , m_booksOf(&m_session, database, &m_details)
    , m_collections(&m_session, database, &m_details, &m_groupDetails)
    , m_series(&m_session, database, &m_details, &m_groupDetails)
    , m_authors(&m_session, database, &m_details, &m_groupDetails)
    , m_authorSeries(&m_session, database, &m_details, &m_groupDetails)
{
    // Series and Authors keep their library; an author's series start with every library
    m_series.keepLibrary("seriesLibraryId");
    m_authors.keepLibrary("authorsLibraryId");
    // Connected before QML's handlers, so the lists are ready for them
    connect(&m_session, &Session::started, this, &BookOrbitClient::start);
    connect(&m_session, &Session::ended, this, &BookOrbitClient::clearLists);
    // The other library's books, without the old one's cached rows meanwhile
    connect(&m_session, &Session::libraryChanged, this, [this]() {
        m_library.forgetCache();
        m_library.clear();
        m_library.reload();
    });
    connect(&m_session, &Session::onlineChanged, this, [this]() {
        if (!m_session.online())
            return;
        for (GroupList *groups : groupLists())
            groups->forgetLocalRows();
    });
}

void BookOrbitClient::start()
{
    // The first request gets an access token from the saved session
    if (m_session.signedIn()) {
        m_library.reload();
        m_theme.load();
    }
}

void BookOrbitClient::setLocalBooks(const QVariantList &books)
{
    for (PagedBookList *list : bookLists())
        list->setLocalBooks(books);
    for (GroupList *groups : groupLists())
        groups->setLocalBooks(books);
}

void BookOrbitClient::clearLists()
{
    m_database->clearCaches();
    m_groupDetails.clear();
    for (GroupList *groups : groupLists())
        groups->clear();
    for (PagedBookList *list : bookLists())
        list->clear();
}
