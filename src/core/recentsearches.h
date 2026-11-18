#pragma once

#include <QObject>
#include <QStringList>

class Database;
class Session;

// The user's recent searches, newest first, kept until they sign out
class RecentSearches : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList items READ items NOTIFY changed)

public:
    // Shorter searches match too much to be useful
    static constexpr int MIN_LENGTH = 3;

    RecentSearches(Session *session, Database *database, QObject *parent = nullptr);

    QStringList items() const { return m_items; }

    // Adds text to the top (moving it if already there, ignoring case) and saves them
    Q_INVOKABLE void add(const QString &text);

signals:
    void changed();

private:
    Database *m_database;
    QStringList m_items;
};
