import QtQuick

// Checks for a newer release of the app (see Updater) and says what it found. Changelog
// opens the release's GitHub page in the browser.
SystemDialog {
    id: dialog
    readonly property string step: updater.state

    function check() {
        visible = true
        updater.check()
    }

    function close() {
        updater.cancel()
        visible = false
    }

    heading: step === "checking" ? "Checking for updates"
             : step === "available" ? "Version " + updater.latestVersion + " is available"
             : step === "noBuild" ? "Version " + updater.latestVersion + " isn't ready for this device"
             : step === "failed" ? "Couldn't check for updates"
             : "PBookOrbit is up to date"

    message: step === "checking" ? "Asking GitHub for the latest release…"
             : step === "available" ? "You have version " + updater.version + "."
             : step === "noBuild" ? "It has no build for this device yet. You have version " + updater.version + "."
             : step === "failed" ? updater.error
             : "You have the latest version, " + updater.version + "."

    icon: step === "failed" ? "icon_error" : "icon_information"
    buttons: {
        if (step === "checking")
            return [["Cancel", "close"]]
        if (step === "failed")
            return [["Try again", "check"], ["Close", "close"]]
        if ((step === "available" || step === "noBuild") && browser.available)
            return [["Changelog", "changelog"], ["Close", "close"]]
        return [["OK", "close"]]
    }

    onPressed: (action) => {
        if (action === "check")
            check()
        else if (action === "changelog")
            browser.open(updater.releaseUrl)
        else
            close()
    }
}
