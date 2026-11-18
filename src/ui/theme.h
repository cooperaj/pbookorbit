#pragma once

#include <QColor>
#include <QObject>
#include <QString>
#include <QVariantMap>

class Database;
class Session;

// The user's BookOrbit accent colour, and what's drawn in it
class Theme : public QObject
{
    Q_OBJECT
    // The accent colour and a readable text colour on top of it. Only available if the user
    // has synced their theme to the server, otherwise teal (BookOrbit's default). Cached for
    // offline use.
    Q_PROPERTY(QColor accentColor READ accentColor NOTIFY accentChanged)
    Q_PROPERTY(QColor accentTextColor READ accentTextColor NOTIFY accentChanged)

public:
    Theme(Session *session, Database *database, QObject *parent = nullptr);

    QColor accentColor() const;
    QColor accentTextColor() const;

    // Placeholder for a missing author photo, as BookOrbit draws it: initials ("AT" for
    // "Adrian Tchaikovsky") on a gradient chosen from the name, near the accent hue.
    // Returns {initials, from, to, color}, saturated for e-ink.
    Q_INVOKABLE QVariantMap authorMonogram(const QString &name) const;

    // Reads the accent colour from the user's synced theme, if any
    void load();

signals:
    void accentChanged();

private:
    Session *m_session;
    Database *m_database;
    QString m_accent;   // BookOrbit accent name, e.g. "teal"; empty for the default
};
