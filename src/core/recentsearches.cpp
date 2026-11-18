#include "core/recentsearches.h"
#include "core/database.h"
#include "core/session.h"

// Recent searches kept
static const int MAX_RECENT_SEARCHES = 10;

RecentSearches::RecentSearches(Session *session, Database *database, QObject *parent)
    : QObject(parent)
    , m_database(database)
{
    m_items = m_database->list("recentSearches");

    // They belong to the signed-out user
    connect(session, &Session::signedOut, this, [this]() {
        m_items.clear();
        m_database->remove("recentSearches");
        emit changed();
    });
}

void RecentSearches::add(const QString &text)
{
    const QString search = text.trimmed();
    if (search.length() < MIN_LENGTH)
        return;

    QStringList searches{search};
    for (const QString &recent : std::as_const(m_items)) {
        if (recent.compare(search, Qt::CaseInsensitive) != 0 && searches.size() < MAX_RECENT_SEARCHES)
            searches.append(recent);
    }
    if (searches == m_items)
        return;

    m_items = searches;
    m_database->setList("recentSearches", m_items);
    emit changed();
}
