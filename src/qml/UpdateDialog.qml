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

    signal restartRequested()

    // What each step shows. Buttons are [label, action]. The download's percent is left out,
    // so the buttons aren't made again each time it changes.
    readonly property var view: {
        const latest = updater.latestVersion
        const installed = updater.version
        const close = [["Close", "close"]]
        const changelog = browser.available ? [["Changelog", "changelog"]] : []
        const views = {
            checking: {heading: "Checking for updates", message: "Asking GitHub for the latest release…",
                       buttons: [["Cancel", "close"]]},
            upToDate: {heading: "PBookOrbit is up to date",
                       message: "You have the latest version, " + installed + ".", buttons: [["OK", "close"]]},
            failed: {heading: "Couldn't check for updates", message: updater.error, error: true,
                     buttons: close.concat([["Try again", "check"]])},
            noBuild: {heading: "Version " + latest + " isn't ready for this device",
                      message: "It has no build for this device yet. You have version " + installed + ".",
                      buttons: close.concat(changelog)},
            // Installing needs the launcher, otherwise it's the GitHub page
            available: {heading: "Version " + latest + " is available",
                        message: "You have version " + installed + "."
                                 + (updater.canInstall ? "" : " Get the new one from its GitHub page."),
                        buttons: close.concat(changelog, updater.canInstall ? [["Update", "install"]] : [])},
            downloading: {heading: "Downloading version " + latest, buttons: [["Cancel", "close"]]},
            installFailed: {heading: "Couldn't update", message: updater.error, error: true,
                            buttons: close.concat([["Try again", "install"]])},
            ready: {heading: "Version " + latest + " is ready",
                    message: "Restart PBookOrbit to finish. Otherwise it updates the next time you open it.",
                    buttons: [["Later", "close"], ["Restart now", "restart"]]},
            restarting: {heading: "Restarting…", message: "PBookOrbit will open again in a moment.", buttons: []},
        }
        // Before the first check, and after one is cancelled, the dialog is hidden
        return views[step] ?? views.checking
    }

    function check() {
        visible = true
        updater.check()
    }

    function close() {
        updater.cancel()
        visible = false
    }

    heading: view.heading
    message: step === "downloading" ? updater.percent + "%" : view.message
    icon: view.error ? "icon_error" : "icon_information"
    percent: step === "downloading" ? updater.percent : -1
    buttons: view.buttons

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
