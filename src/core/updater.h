#pragma once

#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QObject>
#include <QPointer>

class QNetworkReply;

// What GitHub's releases mean for this build, kept apart from the request so it can be
// tested on its own
namespace updates {

// Orders versions as semantic versions: -1, 0 or 1. Takes release tags ("0.9.0-beta",
// "v1.2.0") and git describe output for builds between them ("0.9.0-beta-63-g3232675-dirty"
// counts as 0.9.0-beta). Anything else counts as older than every version.
int compare(const QString &a, const QString &b);

// A release's file for a build: pbookorbit-<version>-<sdk>.zip, the SDK the build was made
// with, e.g. pbookorbit-1.2.0-B300-6.10.zip
struct Asset {
    QString name;
    QString url;
    qint64 size = 0;
    QString sha256;   // hex, from GitHub's digest; empty if it gave none
};

struct Choice {
    // "upToDate", "available" (version has a file for this device), or "noBuild" (version
    // is newer but has no file for it)
    QString state;
    QString version;
    QString pageUrl;   // the release on GitHub, for its changelog
    Asset asset;
};

// The newest release worth offering from GitHub's list, for a build of installed made with
// sdk (e.g. "B300-6.10") on firmware (e.g. "6.11"; empty if unknown, taken as the SDK's).
// Drafts are skipped, and so are pre-releases once installed is 1.0 or later. A release's
// file must be for the same chip (B300) and the newest firmware no newer than the
// device's: B288 and B300 devices have 6.11 firmware but only 6.10 SDKs, so they keep
// taking 6.10 builds until a 6.11 one is released.
Choice choose(const QJsonArray &releases, const QString &installed, const QString &sdk,
              const QString &firmware);

}

// Checks GitHub for a newer release of the app, when the user asks, and installs it.
//
// The app runs from applications/pbookorbit/pbookorbit, started by the launcher script
// applications/pbookorbit.app (src/launcher.sh). Installing downloads the release's zip,
// checks it against GitHub's SHA-256, replaces the launcher (which runs from a copy in
// /tmp) and leaves the new binary in pbookorbit/update/. The launcher swaps it in when the
// app next starts: at once after restart(), which asks it to start the app again, or the
// next time the user opens it.
class Updater : public QObject
{
    Q_OBJECT
    // This build's version (git describe), e.g. "0.9.0-beta"
    Q_PROPERTY(QString version READ version CONSTANT)
    // "" until checked, then "checking", "upToDate", "available", "noBuild" or "failed";
    // installing, "downloading", then "ready" or "installFailed"
    Q_PROPERTY(QString state READ state NOTIFY changed)
    // The release found: its version, and its GitHub page, which has the changelog
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY changed)
    Q_PROPERTY(QString releaseUrl READ releaseUrl NOTIFY changed)
    // Why the check or install failed
    Q_PROPERTY(QString error READ error NOTIFY changed)
    // Download progress, 0-100, in whole percent so the screen redraws rarely
    Q_PROPERTY(int percent READ percent NOTIFY changed)
    // Whether the app was started by the launcher, which installing needs
    Q_PROPERTY(bool canInstall READ canInstall CONSTANT)

public:
    static inline const QString GITHUB_RELEASES =
        QStringLiteral("https://api.github.com/repos/cooperaj/pbookorbit/releases");

    // For this build: GITHUB_RELEASES, its version, the SDK it was built with (PB_APP_VERSION
    // and PB_SDK), and the launcher that started it (PBOOKORBIT_LAUNCHER, empty if none).
    // Tests give their own.
    Updater(const QString &releasesUrl, const QString &version, const QString &sdk,
            const QString &launcher, QObject *parent = nullptr);

    QString version() const { return m_version; }
    QString state() const { return m_state; }
    QString latestVersion() const { return m_choice.version; }
    QString releaseUrl() const { return m_choice.pageUrl; }
    QString error() const { return m_error; }
    int percent() const { return m_percent; }
    bool canInstall() const { return !m_launcher.isEmpty(); }

    // Connects Wi-Fi if needed, then asks GitHub for its releases
    Q_INVOKABLE void check();
    // Downloads and installs the available release
    Q_INVOKABLE void install();
    // Stops checking or downloading
    Q_INVOKABLE void cancel();
    // Once ready: asks the launcher to start the app again after it quits. The caller quits.
    Q_INVOKABLE bool restart();

signals:
    void changed();

private:
    void finish(const QString &state, const QString &error = QString());
    // Unpacks the downloaded zip into place; returns why it couldn't
    QString unpack(const QByteArray &archive);
    QNetworkRequest request(const QString &url) const;
    // Sends it, as the current request
    QNetworkReply *get(const QNetworkRequest &request);
    // applications/pbookorbit, beside the launcher
    QString appDir() const;

    QString m_releasesUrl;
    QString m_version;
    QString m_sdk;
    QString m_launcher;
    QString m_state;
    QString m_error;
    int m_percent = 0;
    updates::Choice m_choice;
    // Made on the first check, as most starts never check
    QNetworkAccessManager *m_nam = nullptr;
    QPointer<QNetworkReply> m_reply;
};
