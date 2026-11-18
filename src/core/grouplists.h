#pragma once

#include "core/grouplist.h"

// The user's collections: {id, name, bookCount, covers (the last two added books with
// covers), authors (by surname), formats}. All but the name come from looking up a
// collection's books, a collection to a request; bookCount then counts a separate ebook and
// audiobook record as one book.
class CollectionList : public GroupList
{
    Q_OBJECT

public:
    CollectionList(Session *session, Database *database, Details *details, GroupDetails *groupDetails,
                   QObject *parent = nullptr);

protected:
    void loadPage(int page, int generation) override;
    bool needsLibrary() const override { return false; }
    // The saved collections with local books, counting only those
    void showLocal() override;
    void lookUp(const QList<int> &ids, int generation) override;
    bool lookUpAlone() const override { return true; }

private:
    // Looks up a collection's books from page onwards, for its covers, authors, formats,
    // count and book ids
    void lookUpCollection(int collectionId, int page, int generation);
};

// The library's series: {id, name, bookCount, covers (first two books), authors, formats,
// lastAddedAt, readProgress (0 to 1)}. Formats, cover versions and a bookCount that counts
// an ebook/audiobook pair once come from looking up a series' books, a few series to a
// request.
class SeriesList : public GroupList
{
    Q_OBJECT

public:
    SeriesList(Session *session, Database *database, Details *details, GroupDetails *groupDetails,
               QObject *parent = nullptr);

protected:
    void loadPage(int page, int generation) override;
    void showLocal() override;
    void lookUp(const QList<int> &ids, int generation) override;

    // The author whose series these are, or empty for the library's
    QString m_author;
};

// One author's series, in rows like SeriesList's
class AuthorSeriesList : public SeriesList
{
    Q_OBJECT

public:
    AuthorSeriesList(Session *session, Database *database, Details *details, GroupDetails *groupDetails,
                     QObject *parent = nullptr);

    // Fills the list with the series containing books by author
    Q_INVOKABLE void show(const QString &author);
};

// The library's authors: {kind: "author", id, name, sortName ("Martin, George R.R."),
// bookCount, photo (imageUrl, or ""), lastAddedAt, formats, seriesCount (-1 until their
// books are looked up), bookSeries}. Formats, counts and series come from looking up an
// author's books, a few authors to a request. With a filter set, counts and formats cover
// only matching books.
class AuthorList : public GroupList
{
    Q_OBJECT
    // Whether every author's books have been looked up this time. Filtering by format needs
    // this.
    Q_PROPERTY(bool allLookedUp READ allLookedUp NOTIFY changed)

public:
    AuthorList(Session *session, Database *database, Details *details, GroupDetails *groupDetails,
               QObject *parent = nullptr);

    bool allLookedUp() const { return m_allLookedUp; }

    // Sorts authors by "name", "sortName", "bookCount" or "lastAddedAt", and keeps only those
    // with books in formats (and, with localOnly, among the local books). Choosing formats,
    // without localOnly, looks up every author's books.
    Q_INVOKABLE void setQuery(const QString &sortField, bool descending, const QStringList &formats,
                              bool localOnly = false);
    // The author's unfiltered row, or empty if not listed
    Q_INVOKABLE QVariantMap row(int authorId) const;

    void setLocalBooks(const QVariantList &books) override;

protected:
    void loadPage(int page, int generation) override;
    void showLocal() override;
    void lookUp(const QList<int> &ids, int generation) override;
    // Filtering by format, not just to the local books
    bool lookUpAll() const override { return !m_formats.isEmpty() && !m_localOnly; }
    QList<QVariantMap> filtered(const QList<QVariantMap> &rows) const override;

private:
    QStringList m_formats;
    bool m_localOnly = false;
};
