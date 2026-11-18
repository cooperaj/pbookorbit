#pragma once

#include <QJsonArray>
#include <QObject>
#include <QVariantMap>

class Database;
class Session;

// Books' and authors' full details, saved for offline, and the saved books' list entries
class Details : public QObject
{
    Q_OBJECT

public:
    Details(Session *session, Database *database, QObject *parent = nullptr);

    // Fetches a book's full details and emits bookDetails(), with the saved ones (or none)
    // on failure. Saved for books with saved list entries, i.e. on the device.
    Q_INVOKABLE void loadBook(int bookId);
    // Fetches an author's details and emits authorDetails(), with the saved ones (or none)
    // on failure
    Q_INVOKABLE void loadAuthor(int authorId);

    // Updates the saved entries of any of these books, as a list gave them (see
    // Database::updateBooks)
    void updateSavedBooks(const QJsonArray &items);

signals:
    void bookDetails(int bookId, const QVariantMap &details);
    void authorDetails(int authorId, const QVariantMap &details);
    // Saved books' list entries were updated from the server
    void savedBooksChanged();

private:
    Session *m_session;
    Database *m_database;
};
