#include <QJsonArray>
#include <QJsonObject>
#include <QTest>

#include "core/updater.h"

// A GitHub release as its API lists it, with a file per SDK, e.g. {"B300-6.10"}
static QJsonObject release(const QString &tag, const QStringList &sdks, bool prerelease = false,
                           bool draft = false)
{
    QJsonArray assets;
    for (const QString &sdk : sdks) {
        const QString name = QString("pbookorbit-%1-%2.zip").arg(tag, sdk);
        assets.append(QJsonObject{
            {"name", name},
            {"browser_download_url", "https://github.com/cooperaj/pbookorbit/releases/download/" + tag + "/" + name},
            {"size", 836333},
            {"digest", "sha256:b251880b67fe35d155debf74e2fc212e1278ba2abfa4c631d0ace0bbef54b4dc"},
        });
    }
    return {
        {"tag_name", tag},
        {"html_url", "https://github.com/cooperaj/pbookorbit/releases/tag/" + tag},
        {"prerelease", prerelease},
        {"draft", draft},
        {"assets", assets},
    };
}

class TestUpdates : public QObject
{
    Q_OBJECT

private slots:
    // Release tags, and builds between them, in semantic versioning's order
    void versionsAreOrdered_data()
    {
        QTest::addColumn<QString>("older");
        QTest::addColumn<QString>("newer");
        QTest::newRow("patch") << "0.9.0" << "0.9.1";
        QTest::newRow("minor beats patch") << "0.9.9" << "0.10.0";
        QTest::newRow("major") << "0.10.0" << "1.0.0";
        QTest::newRow("pre-release before its release") << "0.9.0-beta" << "0.9.0";
        QTest::newRow("pre-releases by name") << "1.0.0-alpha" << "1.0.0-beta";
        QTest::newRow("pre-release numbers by value") << "1.0.0-beta.2" << "1.0.0-beta.10";
        QTest::newRow("numbers before words") << "1.0.0-1" << "1.0.0-beta";
        QTest::newRow("longer pre-release") << "1.0.0-beta" << "1.0.0-beta.1";
        QTest::newRow("v prefix") << "v0.9.0" << "0.9.1";
        QTest::newRow("a build after a tag, before the next") << "0.9.0-beta-63-g3232675-dirty" << "0.9.0";
        QTest::newRow("no version before any") << "3232675" << "0.0.1";
    }
    void versionsAreOrdered()
    {
        QFETCH(QString, older);
        QFETCH(QString, newer);
        QCOMPARE(updates::compare(older, newer), -1);
        QCOMPARE(updates::compare(newer, older), 1);
    }

    // A build counts as the tag it was made after, so it isn't offered that tag again
    void aBuildAfterATagIsThatTag()
    {
        QCOMPARE(updates::compare("0.9.0-beta-63-g3232675-dirty", "0.9.0-beta"), 0);
        QCOMPARE(updates::compare("0.9.0-dirty", "0.9.0"), 0);
    }

    // Which release is offered, and its file, for a build on a device's firmware
    void theNewestUsableReleaseIsChosen_data()
    {
        QTest::addColumn<QJsonArray>("releases");
        QTest::addColumn<QString>("installed");
        QTest::addColumn<QString>("sdk");
        QTest::addColumn<QString>("firmware");
        QTest::addColumn<QString>("state");
        QTest::addColumn<QString>("version");
        QTest::addColumn<QString>("file");

        const QJsonArray releases{
            release("0.11.0", {"B288-6.10", "B300-6.10", "RK3566-6.11"}),
            release("0.10.0", {"B288-6.10", "B300-6.10"}),
            release("0.9.0-beta", {"B288-6.10", "B300-6.10"}, true),
        };
        QTest::newRow("newest for the chip") << releases << "0.9.0-beta" << "B300-6.10" << "6.10"
                                             << "available" << "0.11.0" << "pbookorbit-0.11.0-B300-6.10.zip";
        QTest::newRow("other chip") << releases << "0.9.0-beta" << "B288-6.10" << "6.10"
                                    << "available" << "0.11.0" << "pbookorbit-0.11.0-B288-6.10.zip";
        QTest::newRow("installed is the newest") << releases << "0.11.0" << "B300-6.10" << "6.10"
                                                 << "upToDate" << "" << "";
        QTest::newRow("a build after the newest") << releases << "0.11.0-4-gabc1234" << "B300-6.10" << "6.10"
                                                  << "upToDate" << "" << "";

        // B288 and B300 devices get 6.11 firmware before there's a 6.11 SDK for them
        const QJsonArray sdk611{
            release("0.12.0", {"B300-6.10", "B300-6.11"}),
        };
        QTest::newRow("6.10 build on 6.11 firmware") << releases << "0.10.0" << "B300-6.10" << "6.11"
                                                     << "available" << "0.11.0" << "pbookorbit-0.11.0-B300-6.10.zip";
        QTest::newRow("moves to a 6.11 build once there is one") << sdk611 << "0.11.0" << "B300-6.10" << "6.11"
                                                                 << "available" << "0.12.0" << "pbookorbit-0.12.0-B300-6.11.zip";
        QTest::newRow("6.10 firmware keeps the 6.10 build") << sdk611 << "0.11.0" << "B300-6.10" << "6.10"
                                                            << "available" << "0.12.0" << "pbookorbit-0.12.0-B300-6.10.zip";
        QTest::newRow("unknown firmware is the SDK's") << sdk611 << "0.11.0" << "B300-6.10" << ""
                                                       << "available" << "0.12.0" << "pbookorbit-0.12.0-B300-6.10.zip";
        QTest::newRow("RK3566 needs 6.11") << releases << "0.9.0-beta" << "RK3566-6.11" << "6.11"
                                           << "available" << "0.11.0" << "pbookorbit-0.11.0-RK3566-6.11.zip";

        QTest::newRow("newer without a file for the chip") << QJsonArray{release("0.10.0", {"B288-6.10"})}
                                                           << "0.9.0" << "B300-6.10" << "6.10"
                                                           << "noBuild" << "0.10.0" << "";
        QTest::newRow("older with a file over newer without") << QJsonArray{release("0.11.0", {"B288-6.10"}),
                                                                            release("0.10.0", {"B300-6.10"})}
                                                              << "0.9.0" << "B300-6.10" << "6.10"
                                                              << "available" << "0.10.0" << "pbookorbit-0.10.0-B300-6.10.zip";
        QTest::newRow("only a newer firmware's file") << QJsonArray{release("0.10.0", {"B300-6.11"})}
                                                      << "0.9.0" << "B300-6.10" << "6.10"
                                                      << "noBuild" << "0.10.0" << "";
        QTest::newRow("files named without firmware are ignored") << QJsonArray{release("0.10.0", {"B300"})}
                                                                  << "0.9.0" << "B300-6.10" << "6.10"
                                                                  << "noBuild" << "0.10.0" << "";

        // Until 1.0, pre-releases count
        const QJsonArray beta{
            release("1.1.0-beta", {"B300-6.10"}, true),
            release("1.0.0", {"B300-6.10"}),
        };
        QTest::newRow("pre-release before 1.0") << beta << "0.9.0" << "B300-6.10" << "6.10"
                                                << "available" << "1.1.0-beta" << "pbookorbit-1.1.0-beta-B300-6.10.zip";
        QTest::newRow("no pre-release from 1.0") << beta << "1.0.0-rc.1" << "B300-6.10" << "6.10"
                                                 << "available" << "1.0.0" << "pbookorbit-1.0.0-B300-6.10.zip";
        QTest::newRow("draft") << QJsonArray{release("0.10.0", {"B300-6.10"}, false, true)}
                               << "0.9.0" << "B300-6.10" << "6.10" << "upToDate" << "" << "";
        QTest::newRow("tag that isn't a version") << QJsonArray{release("nightly", {"B300-6.10"})}
                                                  << "0.9.0" << "B300-6.10" << "6.10" << "upToDate" << "" << "";
    }
    void theNewestUsableReleaseIsChosen()
    {
        QFETCH(QJsonArray, releases);
        QFETCH(QString, installed);
        QFETCH(QString, sdk);
        QFETCH(QString, firmware);
        QFETCH(QString, state);
        QFETCH(QString, version);
        QFETCH(QString, file);

        const updates::Choice choice = updates::choose(releases, installed, sdk, firmware);

        QCOMPARE(choice.state, state);
        QCOMPARE(choice.version, version);
        QCOMPARE(choice.asset.name, file);
    }

    // What the download needs, and the page with the changelog
    void theChoiceHasTheFileAndPage()
    {
        const updates::Choice choice = updates::choose({release("0.10.0", {"B300-6.10"})}, "0.9.0",
                                                       "B300-6.10", "6.10");

        QCOMPARE(choice.pageUrl, QString("https://github.com/cooperaj/pbookorbit/releases/tag/0.10.0"));
        QCOMPARE(choice.asset.url,
                 QString("https://github.com/cooperaj/pbookorbit/releases/download/0.10.0/pbookorbit-0.10.0-B300-6.10.zip"));
        QCOMPARE(choice.asset.size, qint64(836333));
        QCOMPARE(choice.asset.sha256, QString("b251880b67fe35d155debf74e2fc212e1278ba2abfa4c631d0ace0bbef54b4dc"));
    }
};

QTEST_GUILESS_MAIN(TestUpdates)
#include "tst_updates.moc"
