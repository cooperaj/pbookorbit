#include <QTest>

#include "core/bookrecords.h"

using namespace bookrecords;

// Book records as the server lists them, with only the fields under test
class TestBookRecords : public QObject
{
    Q_OBJECT

    static QVariantMap file(int id, const QString &format, const QString &role)
    {
        return {{"id", id}, {"format", format}, {"role", role}, {"sizeBytes", id * 1000}};
    }

    static QVariantMap record(int id, const QString &title, const QString &author, const QVariantList &files)
    {
        return {{"id", id}, {"title", title}, {"authors", QStringList{author}}, {"files", files}};
    }

    static QStringList kinds(const QVariantList &variants)
    {
        QStringList kinds;
        for (const QVariant &variant : variants)
            kinds.append(variant.toMap().value("kind").toString());
        return kinds;
    }

private slots:
    // Records spell titles and names differently, but are still the same book
    void sameBookDespitePunctuation_data()
    {
        QTest::addColumn<QString>("title");
        QTest::addColumn<QString>("author");
        QTest::addColumn<bool>("same");
        QTest::newRow("curly apostrophe") << "Carl’s Doomsday Scenario" << "Matt Dinniman" << true;
        QTest::newRow("spaced initials") << "Carl's Doomsday Scenario" << "Matt  Dinniman" << true;
        QTest::newRow("other title") << "The Dungeon Anarchist's Cookbook" << "Matt Dinniman" << false;
        QTest::newRow("other author") << "Carl's Doomsday Scenario" << "Someone Else" << false;
    }
    void sameBookDespitePunctuation()
    {
        QFETCH(QString, title);
        QFETCH(QString, author);
        QFETCH(bool, same);
        const QVariantMap book = record(1, "Carl's Doomsday Scenario", "Matt Dinniman", {});
        QCOMPARE(companionKey(record(2, title, author, {})) == companionKey(book), same);
    }

    // The server is asked for every title word and the author's longest name
    void companionsAreSearchedByTitleWordsAndAuthor()
    {
        const QJsonObject filter = companionsFilter({record(1, "Carl’s Doomsday", "S.A. Corey", {})});

        const QJsonObject match = filter.value("rules").toArray().first().toObject();
        QCOMPARE(filter.value("join").toString(), QString("OR"));
        QCOMPARE(match.value("join").toString(), QString("AND"));
        QStringList values;
        for (const QJsonValue &rule : match.value("rules").toArray()) {
            const QJsonValue value = rule.toObject().value("value");
            values.append(value.isArray() ? value.toArray().first().toString() : value.toString());
        }
        QCOMPARE(values, (QStringList{"Carl", "s", "Doomsday", "Corey"}));
    }

    // Only the book's own files count, the main format first
    void bookFilesSkipCoversAndPutThePrimaryFirst()
    {
        const QVariantMap book = record(1, "T", "A", {
            file(1, "jpg", "cover"),
            file(2, "azw3", "content"),
            file(3, "", "content"),
            file(4, "epub", "primary"),
        });

        QCOMPARE(formatFiles(book), (QVariantList{
            QVariantMap{{"format", "epub"}, {"sizeBytes", 4000}, {"kind", "ebook"}},
            QVariantMap{{"format", "azw3"}, {"sizeBytes", 2000}, {"kind", "ebook"}},
        }));
        QCOMPARE(ownFormats(book), (QStringList{"epub", "azw3"}));
    }

    // A record offers at most one ebook and one audiobook to download
    void oneVersionOfEachKind()
    {
        const QVariantMap book = record(7, "T", "A", {
            file(1, "EPUB", "primary"), file(2, "mobi", "content"), file(3, "m4b", "content"),
        });

        const QVariantList variants = ownVariants(book);

        QCOMPARE(kinds(variants), (QStringList{"ebook", "audiobook"}));
        QCOMPARE(variants.first().toMap().value("format").toString(), QString("epub"));
        QCOMPARE(variants.first().toMap().value("bookId").toInt(), 7);
        QCOMPARE(variants.last().toMap().value("fileId").toInt(), 3);
    }

    // An audiobook record merged with its ebook reads like the ebook, and hides when asked
    void audiobookMergedWithItsEbook_data()
    {
        QTest::addColumn<bool>("hideAudio");
        QTest::newRow("shown") << false;
        QTest::newRow("hidden") << true;
    }
    void audiobookMergedWithItsEbook()
    {
        QFETCH(bool, hideAudio);
        QVariantMap audio = row(record(1, "T", "A", {file(1, "m4b", "primary")}));
        const QVariantMap ebook = record(2, "T", "A", {file(2, "epub", "primary")});

        addCompanions(audio, {ebook}, hideAudio);

        QCOMPARE(kinds(audio.value("variants").toList()), (QStringList{"ebook", "audiobook"}));
        QCOMPARE(audio.value("formats").toStringList(), (QStringList{"epub", "m4b"}));
        QCOMPARE(audio.value("hidden").toBool(), hideAudio);
    }

    // An ebook row is never hidden for its audiobook
    void ebookStaysShown()
    {
        QVariantMap ebook = row(record(2, "T", "A", {file(2, "epub", "primary")}));

        addCompanions(ebook, {record(1, "T", "A", {file(1, "m4b", "primary")})}, true);

        QVERIFY(!ebook.value("hidden").toBool());
    }

    // An audiobook hides only when its ebook is among the listed ids
    void pairsHideOnlyWhenTheEbookIsListed()
    {
        const QVariantMap ebook = record(2, "T", "A", {file(2, "epub", "primary")});
        const QVariantList rows{row(record(1, "T", "A", {file(1, "m4b", "primary")}))};
        QVariantList merged = rows;

        hideListedPairs(merged, rows, {{0, {ebook}}}, {3});
        QVERIFY(!merged.first().toMap().value("hidden").toBool());

        hideListedPairs(merged, rows, {{0, {ebook}}}, {2});
        QVERIFY(merged.first().toMap().value("hidden").toBool());
    }

    // The third line of a book's row
    void statusAndSeries_data()
    {
        QTest::addColumn<QString>("status");
        QTest::addColumn<double>("progress");
        QTest::addColumn<QString>("statusText");
        QTest::newRow("unread") << "" << 0.0 << "";
        QTest::newRow("reading, no progress") << "reading" << 0.0 << "Reading";
        QTest::newRow("part read") << "" << 19.4 << "19% read";
        QTest::newRow("barely started") << "reading" << 0.2 << "1% read";
        QTest::newRow("nearly done") << "reading" << 99.8 << "99% read";
        QTest::newRow("at the end") << "reading" << 100.0 << "Completed";
        QTest::newRow("skimmed") << "skimmed" << 0.0 << "Completed";
        QTest::newRow("on hold") << "on_hold" << 40.0 << "On hold";
        QTest::newRow("abandoned") << "abandoned" << 0.0 << "Abandoned";
    }
    void statusAndSeries()
    {
        QFETCH(QString, status);
        QFETCH(double, progress);
        QFETCH(QString, statusText);
        QVariantMap book = record(1, "T", "A", {});
        book.insert("readStatus", QVariantMap{{"status", status}});
        book.insert("readingProgress", progress);
        book.insert("seriesName", "Discworld");
        book.insert("seriesIndex", 13);

        const QVariantMap shown = row(book);

        QCOMPARE(shown.value("statusText").toString(), statusText);
        QCOMPARE(shown.value("seriesText").toString(), QString("Discworld - 13"));
        QCOMPARE(isFinished(book), statusText == "Completed");
    }

    // Lists sorted by date start a section each day, with books never opened last
    void sectionedByDay()
    {
        QVariantMap book = record(1, "T", "A", {});
        book.insert("addedAt", "2026-10-23T12:00:00.000Z");

        const QVariantMap added = row(book, "addedAt");
        const QVariantMap opened = row(book, "lastOpenedAt");
        const QVariantMap unsectioned = row(book);

        QCOMPARE(added.value("section").toString(), QString("2026-10-23"));
        QCOMPARE(added.value("sectionLabel").toString(), QString("2026/10/23"));
        QCOMPARE(opened.value("sectionLabel").toString(), QString("Never"));
        QCOMPARE(unsectioned.value("section").toString(), QString());
    }

    // A book in several series lists them all; older records only name one
    void seriesOfABook()
    {
        QVariantMap book{{"seriesName", "Expanse"}};
        QCOMPARE(seriesNames(book), QStringList{"Expanse"});

        book.insert("seriesMemberships", QVariantList{
            QVariantMap{{"seriesName", "Cosmere"}}, QVariantMap{{"seriesName", "Mistborn"}},
        });
        QCOMPARE(seriesNames(book), (QStringList{"Cosmere", "Mistborn"}));
    }

    // Authors sort by surname, under its letter
    void authorsBySurname()
    {
        QStringList authors{"George R.R. Martin", "Adrian Tchaikovsky", "Iain M. Banks", "Plato"};

        sortAuthors(authors);

        QCOMPARE(authors, (QStringList{"Iain M. Banks", "George R.R. Martin", "Plato", "Adrian Tchaikovsky"}));
        QCOMPARE(authorSortKey("George R.R. Martin"), QString("Martin, George R.R."));
        QCOMPARE(letterSection(authorSortKey("Iain M. Banks")), QString("B"));
        QCOMPARE(letterSection("2001"), QString("#"));
    }

    // Ebooks before audiobooks, unknown formats last
    void formatsInBookOrbitsOrder()
    {
        QStringList formats{"txt", "m4b", "pdf", "epub"};

        sortFormats(formats);

        QCOMPARE(formats, (QStringList{"epub", "pdf", "m4b", "txt"}));
    }
};

QTEST_GUILESS_MAIN(TestBookRecords)
#include "tst_bookrecords.moc"
