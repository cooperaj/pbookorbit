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
    // The saved collections with local books, counting only those
    void showLocal() override;
    void lookUp(const QList<int> &ids, int generation) override;
    bool lookUpAlone() const override { return true; }

private:
    // Looks up a collection's books from page onwards, for its covers, authors, formats,
    // count and book ids
    void lookUpCollection(int collectionId, int page, int generation);
};

// The series: {id, name, bookCount, covers (first two books), authors, formats,
// lastAddedAt, readProgress (0 to 1)}. Formats, cover versions and a bookCount that
// counts an ebook/audiobook pair once come from looking up a series' books, a few series to
// a request.
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
    // Its series, those by the author if there is one
    QStringList groupsOf(const QVariantMap &book) const override;

    // The author whose series these are, or empty for all
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

// The authors: {kind: "author", id, name, sortName ("Martin, George R.R."),
// bookCount, photo (imageUrl, or ""), lastAddedAt, formats, seriesCount (-1 until their
// books are looked up), bookSeries}. Formats, counts and series come from looking up an
// author's books, a few authors to a request.
class AuthorList : public GroupList
{
    Q_OBJECT

public:
    AuthorList(Session *session, Database *database, Details *details, GroupDetails *groupDetails,
               QObject *parent = nullptr);

    // The author's unfiltered row, or empty if not listed
    Q_INVOKABLE QVariantMap row(int authorId) const;

protected:
    void loadPage(int page, int generation) override;
    void showLocal() override;
    void lookUp(const QList<int> &ids, int generation) override;
    QStringList groupsOf(const QVariantMap &book) const override;
};
