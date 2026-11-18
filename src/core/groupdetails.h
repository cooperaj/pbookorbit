#pragma once

#include <QHash>
#include <QList>
#include <QString>
#include <QVariantMap>

class Database;

// What looking up group rows' books found (formats, counts, cover versions and the like),
// by kind ("collections", "series", "authors") and id, saved for next time. Lists of the
// same kind share it, such as the library's series and an author's.
class GroupDetails
{
public:
    explicit GroupDetails(Database *database);

    // The saved details of a kind, read the first time
    QHash<int, QVariantMap> &of(const QString &kind);
    void save(const QString &kind, int id, const QVariantMap &details);
    // Deletes the kind's details of any other ids
    void keepOnly(const QString &kind, const QList<int> &ids);
    // Forgets them, when the session ends (the database's caches are cleared separately)
    void clear() { m_details.clear(); }

private:
    Database *m_database;
    QHash<QString, QHash<int, QVariantMap>> m_details;
};
