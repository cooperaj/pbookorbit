#include <QTest>

#include "core/formats.h"

// Each test_data() slot fills a table; the slot of the same name then runs once per row,
// with QFETCH reading that row's columns.
class TestFormats : public QObject
{
    Q_OBJECT

private slots:
    // Sorts a book's files into its ebook and its audiobook
    void kindOfEachFormat_data()
    {
        QTest::addColumn<QString>("format");
        QTest::addColumn<QString>("kind");
        QTest::newRow("epub") << "epub" << "ebook";
        QTest::newRow("pdf") << "pdf" << "ebook";
        QTest::newRow("m4b") << "m4b" << "audiobook";
        QTest::newRow("upper-case mp3") << "MP3" << "audiobook";
    }
    void kindOfEachFormat()
    {
        QFETCH(QString, format);
        QFETCH(QString, kind);
        QCOMPARE(::mediaKind(format), kind);
    }

    // Find books only looks at book files, and audiobooks download to their own folder
    void whichFormatsAreBooks_data()
    {
        QTest::addColumn<QString>("format");
        QTest::addColumn<bool>("book");
        QTest::addColumn<bool>("audio");
        QTest::newRow("epub") << "epub" << true << false;
        QTest::newRow("kepub") << "kepub" << true << false;
        QTest::newRow("cbz") << "cbz" << true << false;
        QTest::newRow("flac") << "flac" << true << true;
        QTest::newRow("upper-case opus") << "OPUS" << true << true;
        QTest::newRow("txt") << "txt" << false << false;
        QTest::newRow("empty") << "" << false << false;
    }
    void whichFormatsAreBooks()
    {
        QFETCH(QString, format);
        QFETCH(bool, book);
        QFETCH(bool, audio);
        QCOMPARE(::isBookFormat(format), book);
        QCOMPARE(::isAudioFormat(format), audio);
    }
};

QTEST_GUILESS_MAIN(TestFormats)
#include "tst_formats.moc"
