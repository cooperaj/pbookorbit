#include "core/details.h"
#include "core/database.h"
#include "core/diagnostics.h"
#include "core/session.h"

#include <QJsonDocument>
#include <QJsonObject>

Details::Details(Session *session, Database *database, QObject *parent)
    : QObject(parent)
    , m_session(session)
    , m_database(database)
{
}

void Details::loadBook(int bookId)
{
    // BookDetail (packages/types/src/book.ts). Quiet: the page already shows the list's
    // details, and offline it just shows less.
    m_session->download(QString("/books/%1").arg(bookId),
        [this, bookId](const QByteArray &data) {
            const QVariantMap details = QJsonDocument::fromJson(data).object().toVariantMap();
            m_database->saveBookDetails(bookId, details);
            emit bookDetails(bookId, details);
        },
        [this, bookId](int status, const QString &message) {
            if (status != 0)
                diagnostics::log(QString("book %1 details: %2").arg(bookId).arg(message));
            emit bookDetails(bookId, m_database->bookDetails(bookId));
        });
}

void Details::loadAuthor(int authorId)
{
    // Quiet: offline, the page shows what was saved
    m_session->download(QString("/authors/%1").arg(authorId),
        [this, authorId](const QByteArray &data) {
            const QVariantMap details = QJsonDocument::fromJson(data).object().toVariantMap();
            m_database->saveAuthorDetails(authorId, details);
            emit authorDetails(authorId, details);
        },
        [this, authorId](int status, const QString &message) {
            if (status != 0)
                diagnostics::log(QString("author %1 details: %2").arg(authorId).arg(message));
            emit authorDetails(authorId, m_database->authorDetails(authorId));
        });
}

void Details::updateSavedBooks(const QJsonArray &items)
{
    QList<QVariantMap> entries;
    for (const QJsonValue &item : items)
        entries.append(item.toObject().toVariantMap());

    int changed = 0;
    m_database->transaction([this, &entries, &changed]() { changed = m_database->updateBooks(entries); });
    if (changed > 0)
        emit savedBooksChanged();
}
