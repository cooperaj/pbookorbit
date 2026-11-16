import QtQuick

// Checks for a newer release of the app and installs it (see Updater). Changelog opens the
// release's GitHub page in the browser. Once installed, Restart now asks the launcher to
// start the app again and emits restartRequested() for the app to quit; Later leaves the
// update for the next time the app starts.
SystemDialog {
    id: dialog
    // Set once Restart now is pressed, until the app quits
    property bool restarting: false
    readonly property string step: restarting ? "restarting" : updater.state
    readonly property string latest: updater.latestVersion

    signal restartRequested()

    function check() {
        visible = true
        updater.check()
    }

    function close() {
        updater.cancel()
        visible = false
    }

    heading: step === "checking" ? "Checking for updates"
             : step === "available" ? "Version " + latest + " is available"
             : step === "noBuild" ? "Version " + latest + " isn't ready for this device"
             : step === "failed" ? "Couldn't check for updates"
             : step === "downloading" ? "Downloading version " + latest
             : step === "installFailed" ? "Couldn't update"
             : step === "ready" ? "Version " + latest + " is ready"
             : step === "restarting" ? "Restarting…"
             : "PBookOrbit is up to date"

    message: step === "checking" ? "Asking GitHub for the latest release…"
             : step === "available" ? "You have version " + updater.version + "."
                                      + (updater.canInstall ? "" : " Get the new one from its GitHub page.")
             : step === "noBuild" ? "It has no build for this device yet. You have version " + updater.version + "."
             : step === "failed" || step === "installFailed" ? updater.error
             : step === "downloading" ? updater.percent + "%"
             : step === "ready" ? "Restart PBookOrbit to finish. Otherwise it updates the next time you open it."
             : step === "restarting" ? "PBookOrbit will open again in a moment."
             : "You have the latest version, " + updater.version + "."

    icon: step === "failed" || step === "installFailed" ? "icon_error" : "icon_information"
    percent: step === "downloading" ? updater.percent : -1
    buttons: {
        const changelog = browser.available ? [["Changelog", "changelog"]] : []
        if (step === "checking" || step === "downloading")
            return [["Cancel", "close"]]
        if (step === "failed")
            return [["Try again", "check"], ["Close", "close"]]
        if (step === "installFailed")
            return [["Try again", "install"], ["Close", "close"]]
        if (step === "available")
            return (updater.canInstall ? [["Update", "install"]] : []).concat(changelog, [["Close", "close"]])
        if (step === "noBuild")
            return changelog.concat([["Close", "close"]])
        if (step === "ready")
            return [["Restart now", "restart"], ["Later", "close"]]
        if (step === "restarting")
            return []
        return [["OK", "close"]]
    }

    onPressed: (action) => {
        if (action === "check")
            check()
        else if (action === "install")
            updater.install()
        else if (action === "changelog")
            browser.open(updater.releaseUrl)
        else if (action === "restart") {
            if (updater.restart()) {
                restarting = true
                restartTimer.start()
            }
        } else
            close()
    }

    // Give the screen time to say so first
    Timer {
        id: restartTimer
        interval: 500
        onTriggered: dialog.restartRequested()
    }
}
