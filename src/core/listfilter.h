#pragma once

#include <QObject>

class Database;
class Session;

// The content type and Downloaded only, as chosen in any list's filter menu and shown in
// every list that has them. Kept until the user signs out. Each list has its own library.
// Search has its own, unsaved, copied from the lists' as each search starts.
class ListFilter : public QObject
{
    Q_OBJECT
    // Ebooks and audiobooks shown: one or both, never neither
    Q_PROPERTY(bool ebooks READ ebooks NOTIFY changed)
    Q_PROPERTY(bool audiobooks READ audiobooks NOTIFY changed)
    // Only books on the device, as chosen. Lists are also downloaded only while offline.
    Q_PROPERTY(bool downloadedOnly READ downloadedOnly NOTIFY changed)

public:
    ListFilter(Session *session, Database *database, QObject *parent = nullptr);
    // Not saved
    explicit ListFilter(QObject *parent = nullptr);

    bool ebooks() const { return m_ebooks; }
    bool audiobooks() const { return m_audiobooks; }
    bool downloadedOnly() const { return m_downloadedOnly; }

    // Shows or hides "ebook" or "audiobook" content, unless that would hide both
    Q_INVOKABLE void showContent(const QString &kind, bool on);
    Q_INVOKABLE void setDownloadedOnly(bool on);
    // Takes other's choices
    Q_INVOKABLE void copy(ListFilter *other);

signals:
    void changed();

private:
    void save();

    // None if not saved
    Database *m_database = nullptr;
    bool m_ebooks = true;
    bool m_audiobooks = true;
    bool m_downloadedOnly = false;
};
