#pragma once

#include "core/pagedbooklist.h"

// The library's books
class LibraryBooks : public PagedBookList
{
    Q_OBJECT

public:
    LibraryBooks(Session *session, Database *database, Details *details, QObject *parent = nullptr);

    // Sets the list's sort and filter, and reloads it.
    //   sortField   addedAt, title, author or lastReadAt
    //   descending  Z to A, or newest first
    //   formats     only books in these formats; empty for all
    //   localOnly   list the local books instead of asking the server, so it works offline
    //   reload      reload it now; otherwise the next reload() uses them
    Q_INVOKABLE void setQuery(const QString &sortField, bool descending, const QStringList &formats,
                              bool localOnly = false, bool reload = true);
    // Reloads it from page one
    void reload() { refresh(); }

protected:
    // Those in the session's library
    QVariantList localBooks() const override;
};

// Books matching a search of titles, authors and series, by title, in every library.
// Offline, the local books matching it.
class SearchResults : public PagedBookList
{
    Q_OBJECT

public:
    using PagedBookList::PagedBookList;

    // Searches for text. Text shorter than RecentSearches::MIN_LENGTH clears the results.
    Q_INVOKABLE void find(const QString &text);
    // Kept for the next search offline, leaving the results as they are
    void setLocalBooks(const QVariantList &books) override { m_localBooks = books; }

protected:
    void setPaths() override;
    bool letterSections() const override { return false; }
    bool checksPairs() const override { return true; }
    void hideListedPairs(const QVariantList &merged, const QVariantList &rows,
                         const QList<std::pair<int, QList<QVariantMap>>> &maybeHidden,
                         const QVariantList &books, std::function<void(const QVariantList &)> then) override;

private:
    // The local books matching the text
    void findLocalBooks(const QString &text);
};

// The books of some authors, a series or a collection
class BooksOf : public PagedBookList
{
    Q_OBJECT

public:
    using PagedBookList::PagedBookList;

    // Fills the list with the books of some authors (field "author", values are names), a
    // series ("series", its name) or a collection ("collection", its id). Authors' and
    // series' books are those in libraryId, or in every library for -1; a collection's may
    // be in any. Sorting and filtering work as in LibraryBooks::setQuery(), plus
    // "seriesIndex" (series order, with a section per number) and, for collections,
    // "collectionOrder" (order added). Existing rows stay until the new ones arrive.
    Q_INVOKABLE void show(const QString &field, const QStringList &values, const QString &sortField,
                          bool descending, const QStringList &formats = {}, bool localOnly = false,
                          int libraryId = -1);

protected:
    void setPaths() override;
    QVariantList localBooks() const override;
    QString sortKey(const QVariantMap &book, const QString &field) const override;
    bool checksPairs() const override;
    void hideListedPairs(const QVariantList &merged, const QVariantList &rows,
                         const QList<std::pair<int, QList<QVariantMap>>> &maybeHidden,
                         const QVariantList &books, std::function<void(const QVariantList &)> then) override;
    void cacheSaved() override;

private:
    QString m_field;
    QStringList m_values;
    int m_libraryId = -1;
    // For a collection, its book ids as its lookup saved them, newest first
    QVariantList m_collectionIds;
};
