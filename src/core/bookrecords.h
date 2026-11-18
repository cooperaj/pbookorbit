#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <utility>

// BookOrbit's book records as the server lists them, and the rows the lists show for them
namespace bookrecords {

// Adds those of values not already in list, in order
void addNew(QStringList &list, const QStringList &values);

// Whether a paged reply ({items, total}) has pages after this one
bool morePages(int page, int pageSize, const QJsonObject &result);

// Filter parts for BookOrbit's book queries
QJsonObject rule(const QString &field, const QString &op, const QJsonValue &value);
QJsonObject group(const QString &join, const QJsonArray &rules);

// Lower-case letters and digits only, so "Carl’s" matches "Carl's" and "S.A." matches "S. A."
QString looseText(const QString &text);
// The words of some text, without the punctuation around and inside them
QStringList words(const QString &text);

// Identifies records of the same book: loose title plus first author
QString companionKey(const QVariantMap &book);
// A filter for every record that might share one of these books' title and first author.
// companionKey() then picks the real matches.
QJsonObject companionsFilter(const QVariantList &books);

// A record's book files, primary first: those with a format and the role "primary" or
// "content" (the same book in another format). Cover, metadata and supplement files are
// skipped.
QList<QVariantMap> bookFiles(const QVariantMap &book);
// A record's versions of the book, at most one ebook and one audiobook: [{bookId, fileId,
// format, sizeBytes, kind: "ebook" | "audiobook", book}], where book is the record to
// download from
QVariantList ownVariants(const QVariantMap &book);
// Every book format a record has, primary first: "epub", "azw3", ...
QStringList ownFormats(const QVariantMap &book);
// A record's book files, one per format, primary first: [{format, sizeBytes, kind}]
QVariantList formatFiles(const QVariantMap &book);

// Merges other records of the same book into a row's variants and formats. With hideAudio,
// hides an audiobook row whose ebook is also listed.
void addCompanions(QVariantMap &row, const QList<QVariantMap> &companions, bool hideAudio);
// Hides each audiobook row in maybeHidden (row, its companions) whose ebook companion is in
// listedIds, and shows the rest. rows are the unmerged rows.
void hideListedPairs(QVariantList &merged, const QVariantList &rows,
                     const QList<std::pair<int, QList<QVariantMap>>> &maybeHidden,
                     const QVariantList &listedIds);

// A list row for a record: statusText, seriesText, its own variants and formats, hidden
// false, and no section start. With dayField ("addedAt" or "lastOpenedAt") the row's
// section is the day of that date ("yyyy-MM-dd", labelled "yyyy/MM/dd"), or "never".
QVariantMap row(const QVariantMap &book, const QString &dayField = {});

// Read, skimmed or at 100%, which a row shows as "Completed"
bool isFinished(const QVariantMap &book);
// Every series a book is in
QStringList seriesNames(const QVariantMap &book);

// "George R.R. Martin" -> "Martin, George R.R.". Close enough to BookOrbit's author sort
// names, which list entries don't include.
QString authorSortKey(const QString &name);
// By surname
void sortAuthors(QStringList &authors);
// Ebooks before audiobooks, each in BookOrbit's order of formats
void sortFormats(QStringList &formats);
// "A" to "Z" for keys starting with a letter, otherwise "#", matching BookOrbit
QString letterSection(const QString &key);

}
