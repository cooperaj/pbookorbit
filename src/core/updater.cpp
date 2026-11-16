#include "core/updater.h"

#include "core/bookorbitclient.h"
#include "core/diagnostics.h"
#include "core/systemlibrary.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QVersionNumber>
#include <optional>

namespace updates {
namespace {

struct Version {
    bool valid = false;
    int numbers[3] = {0, 0, 0};
    QStringList pre;   // pre-release identifiers: "beta.2" is ["beta", "2"]
};

Version parse(QString text)
{
    // git describe's commits since the tag, and uncommitted changes
    static const QRegularExpression describe(R"((-\d+-g[0-9a-f]+)?(-dirty)?$)");
    text.remove(describe);

    static const QRegularExpression semver(R"(^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?$)");
    const QRegularExpressionMatch match = semver.match(text);
    Version version;
    if (!match.hasMatch())
        return version;
    version.valid = true;
    for (int i = 0; i < 3; ++i)
        version.numbers[i] = match.captured(i + 1).toInt();
    if (!match.captured(4).isEmpty())
        version.pre = match.captured(4).split('.');
    return version;
}

int sign(int n)
{
    return (n > 0) - (n < 0);
}

// Semantic versioning's order: a version without a pre-release is newer than one with, and
// identifiers compare one by one, numbers by value and below words
int comparePre(const QStringList &a, const QStringList &b)
{
    if (a.isEmpty() || b.isEmpty())
        return int(a.isEmpty()) - int(b.isEmpty());
    for (qsizetype i = 0; i < qMin(a.size(), b.size()); ++i) {
        bool aNumber = false;
        bool bNumber = false;
        const int x = a[i].toInt(&aNumber);
        const int y = b[i].toInt(&bNumber);
        if (aNumber && bNumber) {
            if (x != y)
                return x < y ? -1 : 1;
        } else if (aNumber != bNumber) {
            return aNumber ? -1 : 1;
        } else if (const int order = a[i].compare(b[i])) {
            return sign(order);
        }
    }
    return sign(int(a.size() - b.size()));
}

// "B300-6.10": the chip, and the firmware release the SDK is for
struct Sdk {
    QString chip;
    QVersionNumber firmware;
};

Sdk sdkOf(const QString &name)
{
    static const QRegularExpression pattern(R"(^([A-Za-z0-9]+)-(\d+\.\d+)$)");
    const QRegularExpressionMatch match = pattern.match(name);
    if (!match.hasMatch())
        return {};
    return {match.captured(1), QVersionNumber::fromString(match.captured(2))};
}

// The release's file for build's chip with the newest firmware up to the device's
std::optional<Asset> assetFor(const QJsonArray &assets, const Sdk &build, const QVersionNumber &device)
{
    static const QRegularExpression pattern(R"(^pbookorbit-.+-([A-Za-z0-9]+-\d+\.\d+)\.zip$)");
    std::optional<Asset> best;
    QVersionNumber bestFirmware;
    for (const QJsonValue &value : assets) {
        const QJsonObject asset = value.toObject();
        const QString name = asset.value("name").toString();
        const Sdk sdk = sdkOf(pattern.match(name).captured(1));
        if (sdk.chip.isEmpty() || sdk.chip != build.chip || sdk.firmware > device)
            continue;
        if (best && sdk.firmware <= bestFirmware)
            continue;
        QString digest = asset.value("digest").toString();
        best = Asset{name, asset.value("browser_download_url").toString(),
                     qint64(asset.value("size").toDouble()),
                     digest.startsWith("sha256:") ? digest.mid(7) : QString()};
        bestFirmware = sdk.firmware;
    }
    return best;
}

}

int compare(const QString &a, const QString &b)
{
    const Version x = parse(a);
    const Version y = parse(b);
    if (!x.valid || !y.valid)
        return int(x.valid) - int(y.valid);
    for (int i = 0; i < 3; ++i) {
        if (x.numbers[i] != y.numbers[i])
            return x.numbers[i] < y.numbers[i] ? -1 : 1;
    }
    return comparePre(x.pre, y.pre);
}

Choice choose(const QJsonArray &releases, const QString &installed, const QString &sdk,
              const QString &firmware)
{
    const Version current = parse(installed);
    // Until 1.0, pre-releases are all there is
    const bool preReleases = !current.valid || current.numbers[0] < 1;
    const Sdk build = sdkOf(sdk);
    const QVersionNumber device = QVersionNumber::fromString(firmware).isNull()
                                      ? build.firmware : QVersionNumber::fromString(firmware);

    Choice available;
    Choice noBuild;
    for (const QJsonValue &value : releases) {
        const QJsonObject release = value.toObject();
        const QString tag = release.value("tag_name").toString();
        if (release.value("draft").toBool() || (release.value("prerelease").toBool() && !preReleases)
                || !parse(tag).valid || compare(tag, installed) <= 0)
            continue;

        const std::optional<Asset> asset = assetFor(release.value("assets").toArray(), build, device);
        Choice &best = asset ? available : noBuild;
        if (!best.version.isEmpty() && compare(tag, best.version) <= 0)
            continue;
        best = {asset ? "available" : "noBuild", tag, release.value("html_url").toString(),
                asset.value_or(Asset{})};
    }
    if (!available.version.isEmpty())
        return available;
    if (!noBuild.version.isEmpty())
        return noBuild;
    return {"upToDate", {}, {}, {}};
}

}

Updater::Updater(const QString &releasesUrl, const QString &version, const QString &sdk, QObject *parent)
    : QObject(parent), m_releasesUrl(releasesUrl), m_version(version), m_sdk(sdk)
{
}

void Updater::check()
{
    if (m_state == "checking")
        return;
    m_choice = {};
    m_state = "checking";
    m_error.clear();
    emit changed();
    if (!BookOrbitClient::ensureNetwork()) {
        finish("failed", "There's no network connection. Connect to Wi-Fi and try again.");
        return;
    }

    if (!m_nam)
        m_nam = new QNetworkAccessManager(this);
    // GitHub lists the newest first
    QNetworkRequest request(QUrl(m_releasesUrl + "?per_page=20"));
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("X-GitHub-Api-Version", "2022-11-28");
    request.setHeader(QNetworkRequest::UserAgentHeader, "PBookOrbit/" + m_version);
    request.setTransferTimeout(30000);
    diagnostics::trace("GET " + request.url().toString());
    QNetworkReply *reply = m_nam->get(request);
    m_reply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply != m_reply)
            return;   // cancelled
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        diagnostics::trace(QString("releases -> %1").arg(status ? QString::number(status) : reply->errorString()));
        if (reply->error() != QNetworkReply::NoError) {
            // GitHub allows 60 unauthenticated requests an hour per address
            finish("failed", status == 403 || status == 429 ? "GitHub is busy. Try again later."
                             : status ? QString("GitHub couldn't list the releases (HTTP %1).").arg(status)
                                      : "Couldn't reach GitHub. Check your connection and try again.");
            return;
        }
        const QJsonDocument releases = QJsonDocument::fromJson(reply->readAll());
        if (!releases.isArray()) {
            finish("failed", "GitHub's list of releases couldn't be read.");
            return;
        }

        const QString firmware = systemlibrary::firmwareRelease();
        m_choice = updates::choose(releases.array(), m_version, m_sdk, firmware);
        diagnostics::log(QString("update check: %1 with the %2 SDK on firmware %3: %4 %5 %6")
                             .arg(m_version, m_sdk, firmware.isEmpty() ? "unknown" : firmware,
                                  m_choice.state, m_choice.version, m_choice.asset.name)
                             .trimmed());
        finish(m_choice.state);
    });
}

void Updater::cancel()
{
    if (m_state != "checking")
        return;
    QNetworkReply *reply = m_reply;
    m_reply = nullptr;
    if (reply)
        reply->abort();
    finish("");
}

void Updater::finish(const QString &state, const QString &error)
{
    m_reply = nullptr;
    m_state = state;
    m_error = error;
    emit changed();
}
