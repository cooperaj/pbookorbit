#include "core/bookrecords.h"
#include "core/formats.h"

#include <QDateTime>
#include <QRegularExpression>
#include <algorithm>

namespace bookrecords {

void addNew(QStringList &list, const QStringList &values)
{
    for (const QString &value : values) {
        if (!list.contains(value))
            list.append(value);
    }
}

QJsonObject rule(const QString &field, const QString &op, const QJsonValue &value)
{
    return QJsonObject{{"type", "rule"}, {"field", field}, {"operator", op}, {"value", value}};
}

QJsonObject group(const QString &join, const QJsonArray &rules)
{
    return QJsonObject{{"type", "group"}, {"join", join}, {"rules", rules}};
}

QString looseText(const QString &text)
{
    QString loose;
    for (const QChar c : text) {
        if (c.isLetterOrNumber())
            loose.append(c.toLower());
    }
    return loose;
}

QStringList words(const QString &text)
{
    static const QRegularExpression notWord(R"([^\p{L}\p{N}]+)");
    return text.split(notWord, Qt::SkipEmptyParts);
}

QString companionKey(const QVariantMap &book)
{
    const QStringList authors = book.value("authors").toStringList();
    return looseText(book.value("title").toString()) + '\n'
           + (authors.isEmpty() ? QString() : looseText(authors.first()));
}

// Titles containing each word, and an author containing the first author's longest word.
// Punctuation is dropped since records spell it differently ("Carl’s"/"Carl's").
QJsonObject companionsFilter(const QVariantList &books)
{
    QJsonArray matches;
    for (const QVariant &value : books) {
        const QVariantMap book = value.toMap();
        const QString title = book.value("title").toString();
        QJsonArray match;
        for (const QString &word : words(title))
            match.append(rule("title", "contains", word));
        if (match.isEmpty())
            match.append(rule("title", "eq", title));

        QString authorWord;
        for (const QString &word : words(book.value("authors").toStringList().value(0))) {
            if (word.length() > authorWord.length())
                authorWord = word;
        }
        if (!authorWord.isEmpty())
            match.append(rule("author", "includesAny", QJsonArray{authorWord}));
        matches.append(group("AND", match));
    }
    return group("OR", matches);
}

QList<QVariantMap> bookFiles(const QVariantMap &book)
{
    QList<QVariantMap> files;
    for (const QVariant &value : book.value("files").toList()) {
        const QVariantMap file = value.toMap();
        const QString role = file.value("role").toString();
        if (!file.value("format").toString().isEmpty() && (role == "primary" || role == "content"))
            files.append(file);
    }
    std::stable_sort(files.begin(), files.end(), [](const QVariantMap &a, const QVariantMap &b) {
        return a.value("role") == "primary" && b.value("role") != "primary";
    });
    return files;
}

// From the record's first file of each kind
QVariantList ownVariants(const QVariantMap &book)
{
    QVariantList variants;
    QStringList kinds;
    for (const QVariantMap &file : bookFiles(book)) {
        const QString format = file.value("format").toString();
        const QString kind = mediaKind(format);
        if (kinds.contains(kind))
            continue;
        kinds.append(kind);
        variants.append(QVariantMap{
            {"bookId", book.value("id")},
            {"fileId", file.value("id")},
            {"format", format.toLower()},
            {"sizeBytes", file.value("sizeBytes")},
            {"kind", kind},
            {"book", book},
        });
    }
    return variants;
}

QStringList ownFormats(const QVariantMap &book)
{
    QStringList formats;
    for (const QVariantMap &file : bookFiles(book))
        addNew(formats, {file.value("format").toString().toLower()});
    return formats;
}

QVariantList formatFiles(const QVariantMap &book)
{
    QVariantList files;
    QStringList formats;
    for (const QVariantMap &file : bookFiles(book)) {
        const QString format = file.value("format").toString().toLower();
        if (formats.contains(format))
            continue;
        formats.append(format);
        files.append(QVariantMap{
            {"format", format},
            {"sizeBytes", file.value("sizeBytes", 0)},
            {"kind", mediaKind(format)},
        });
    }
    return files;
}

void addCompanions(QVariantMap &row, const QList<QVariantMap> &companions, bool hideAudio)
{
    QVariantList variants = row.value("variants").toList();
    QStringList formats = row.value("formats").toStringList();
    QStringList kinds;
    for (const QVariant &variant : std::as_const(variants))
        kinds.append(variant.toMap().value("kind").toString());
    const QString ownKind = kinds.isEmpty() ? QString() : kinds.first();

    bool ebookElsewhere = false;
    for (const QVariantMap &companion : companions) {
        for (const QVariant &value : ownVariants(companion)) {
            const QString kind = value.toMap().value("kind").toString();
            if (kind == "ebook")
                ebookElsewhere = true;
            if (!kinds.contains(kind)) {
                kinds.append(kind);
                variants.append(value);
            }
        }
        addNew(formats, ownFormats(companion));
    }

    // Ebook versions first: a downloaded ebook opens before its audiobook. The formats
    // follow, so an audiobook's row reads like its ebook's.
    std::stable_sort(variants.begin(), variants.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("kind") == "ebook" && b.toMap().value("kind") != "ebook";
    });
    std::stable_sort(formats.begin(), formats.end(), [](const QString &a, const QString &b) {
        return !isAudioFormat(a) && isAudioFormat(b);
    });
    row.insert("variants", variants);
    row.insert("formats", formats);
    row.insert("hidden", hideAudio && ownKind == "audiobook" && ebookElsewhere);
}

void hideListedPairs(QVariantList &merged, const QVariantList &rows,
                     const QList<std::pair<int, QList<QVariantMap>>> &maybeHidden,
                     const QVariantList &listedIds)
{
    for (const auto &[i, companions] : maybeHidden) {
        QList<QVariantMap> listed;
        for (const QVariantMap &companion : companions) {
            if (listedIds.contains(companion.value("id")))
                listed.append(companion);
        }
        QVariantMap listedRow = rows.at(i).toMap();
        addCompanions(listedRow, listed, true);
        QVariantMap row = merged.at(i).toMap();
        row.insert("hidden", listedRow.value("hidden"));
        merged[i] = row;
    }
}

// Third line, as in the system library: reading status and series, either optional, e.g.
// "19% read | The Rising World - 2", "Completed", "Discworld - 13". Progress (0-100) shows
// whatever the status, as in BookOrbit, since reading doesn't always set one.
static QString statusText(const QVariantMap &book)
{
    const QString status = book.value("readStatus").toMap().value("status").toString();
    const double progress = book.value("readingProgress").toDouble();
    if (isFinished(book))
        return "Completed";
    if (status == "on_hold")
        return "On hold";
    if (status == "abandoned")
        return "Abandoned";
    // Never "0%" or "100%" for a book that is part read
    if (progress > 0)
        return QString("%1% read").arg(qBound(1, qRound(progress), 99));
    if (status == "reading" || status == "rereading")
        return "Reading";
    return {};
}

static QString seriesText(const QVariantMap &book)
{
    QString text = book.value("seriesName").toString();
    if (!text.isEmpty() && !book.value("seriesIndex").isNull())
        text += " - " + book.value("seriesIndex").toString();
    return text;
}

QVariantMap row(const QVariantMap &book, const QString &dayField)
{
    QVariantMap row = book;

    // Labelled like the system library: "2026/10/23" or "Never"
    QString section;
    row.insert("sectionLabel", QString());
    if (!dayField.isEmpty()) {
        const QDateTime when = QDateTime::fromString(book.value(dayField).toString(), Qt::ISODateWithMs);
        if (when.isValid()) {
            const QDate date = when.toLocalTime().date();
            section = date.toString("yyyy-MM-dd");
            row.insert("sectionLabel", date.toString("yyyy/MM/dd"));
        } else {
            section = "never";
            row.insert("sectionLabel", "Never");
        }
    }
    row.insert("section", section);
    row.insert("sectionStart", false);

    row.insert("statusText", statusText(book));
    row.insert("seriesText", seriesText(book));

    // Its own versions and formats. addCompanions() adds other records'.
    row.insert("variants", ownVariants(book));
    row.insert("formats", ownFormats(book));
    row.insert("hidden", false);
    return row;
}

bool isFinished(const QVariantMap &book)
{
    const QString status = book.value("readStatus").toMap().value("status").toString();
    return status == "read" || status == "skimmed" || book.value("readingProgress").toDouble() >= 100;
}

QStringList seriesNames(const QVariantMap &book)
{
    QStringList names;
    for (const QVariant &membership : book.value("seriesMemberships").toList())
        names.append(membership.toMap().value("seriesName").toString());
    if (names.isEmpty() && !book.value("seriesName").toString().isEmpty())
        names.append(book.value("seriesName").toString());
    return names;
}

QString authorSortKey(const QString &name)
{
    const int space = name.trimmed().lastIndexOf(' ');
    return space < 0 ? name.trimmed() : name.mid(space + 1) + ", " + name.left(space);
}

void sortAuthors(QStringList &authors)
{
    std::sort(authors.begin(), authors.end(), [](const QString &a, const QString &b) {
        return QString::localeAwareCompare(authorSortKey(a).toLower(), authorSortKey(b).toLower()) < 0;
    });
}

void sortFormats(QStringList &formats)
{
    static const QStringList order = ebookFormats() + audioFormats();
    std::stable_sort(formats.begin(), formats.end(), [](const QString &a, const QString &b) {
        return uint(order.indexOf(a)) < uint(order.indexOf(b));   // unknown ones last
    });
}

QString letterSection(const QString &key)
{
    const QChar first = key.isEmpty() ? QChar() : key.at(0).toUpper();
    return first >= 'A' && first <= 'Z' ? QString(first) : QString("#");
}

}
