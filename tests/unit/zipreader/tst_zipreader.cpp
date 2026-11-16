#include <QFile>
#include <QTest>

#include "core/zipreader.h"

static QByteArray fixture(const QString &name)
{
    QFile file(QStringLiteral(FIXTURES_DIR "/releases/") + name);
    if (!file.open(QIODevice::ReadOnly))
        qFatal("no fixture %s", qPrintable(file.fileName()));
    return file.readAll();
}

static const QString LAUNCHER = QStringLiteral("pbookorbit.app");
static const QString BINARY = QStringLiteral("pbookorbit/pbookorbit");

// Release zips, made by tests/fixtures/releases/make.py
class TestZipReader : public QObject
{
    Q_OBJECT

private slots:
    void readsTheFilesAsked_data()
    {
        QTest::addColumn<QString>("zip");
        QTest::newRow("deflated") << "pbookorbit-0.10.0-B300-6.10.zip";
        QTest::newRow("stored") << "stored.zip";
    }
    void readsTheFilesAsked()
    {
        QFETCH(QString, zip);

        const auto files = zip::read(fixture(zip), {LAUNCHER, BINARY, "missing"});

        QCOMPARE(files.keys().size(), 2);
        QCOMPARE(files.value(LAUNCHER), QByteArray("#!/bin/sh\n# launcher 0.10.0\n"));
        QCOMPARE(files.value(BINARY), QByteArray("binary 0.10.0\n").repeated(200));
    }

    // Its data changed after its CRC was recorded
    void aDamagedFileIsLeftOut()
    {
        const auto files = zip::read(fixture("damaged.zip"), {LAUNCHER, BINARY});

        QVERIFY(files.contains(LAUNCHER));
        QVERIFY(!files.contains(BINARY));
    }

    void anythingElseGivesNothing_data()
    {
        QTest::addColumn<QByteArray>("archive");
        QTest::newRow("empty") << QByteArray();
        QTest::newRow("not a zip") << QByteArray("not a zip file").repeated(10);
        QTest::newRow("first half") << fixture("stored.zip").left(1500);
        QTest::newRow("second half") << fixture("stored.zip").mid(1500);
    }
    void anythingElseGivesNothing()
    {
        QFETCH(QByteArray, archive);

        QVERIFY(zip::read(archive, {LAUNCHER, BINARY}).isEmpty());
    }
};

QTEST_GUILESS_MAIN(TestZipReader)
#include "tst_zipreader.moc"
