#include "core/groupdetails.h"
#include "core/database.h"

#include <QSet>

GroupDetails::GroupDetails(Database *database)
    : m_database(database)
{
}

QHash<int, QVariantMap> &GroupDetails::of(const QString &kind)
{
    if (!m_details.contains(kind))
        m_details.insert(kind, m_database->groupDetails(kind));
    return m_details[kind];
}

void GroupDetails::save(const QString &kind, int id, const QVariantMap &details)
{
    of(kind).insert(id, details);
    m_database->saveGroupDetails(kind, id, details);
}

void GroupDetails::keepOnly(const QString &kind, const QList<int> &ids)
{
    const QSet<int> kept(ids.cbegin(), ids.cend());
    QHash<int, QVariantMap> &saved = of(kind);
    saved.removeIf([&kept](QHash<int, QVariantMap>::iterator it) { return !kept.contains(it.key()); });
    m_database->keepGroupDetails(kind, saved.keys());
}
