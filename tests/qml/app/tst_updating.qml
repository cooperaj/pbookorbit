import QtQuick
import QtTest
import "../helpers"

// Checking for a newer release of the app, from the header's menu, and installing it.
// GitHub's releases come from the fake server, and the app is version 0.9.0 built for an
// Era Color (B300, firmware 6.10), started by its launcher, applications/pbookorbit.app
// (see TestApp in main.cpp). Installing leaves the new launcher there and the new binary in
// applications/pbookorbit/update, for the launcher to swap in when the app next starts.
AppTestCase {
    name: "Updating"

    readonly property string zip: "pbookorbit-0.10.0-B300-6.10.zip"

    SignalSpy { id: restarts; signalName: "restartRequested" }

    function checkForUpdates() {
        tap("menuButton")
        tapText("Check for updates")
    }

    // Version 0.10.0 on offer, its B300 zip served as fixture
    function serveRelease(fixture) {
        fakeServer.respond("GET", "/releases", 200, "releases/newer.json")
        fakeServer.respondFile("/download/" + zip, "releases/" + (fixture || zip), zip)
    }

    function releaseRequests() {
        return fakeServer.requests.filter(r => r.path === "/releases").length
    }

    // Signed out too, in case signing in needs the update. Restarting quits, and the
    // launcher starts the new version.
    function test_aUserCanUpdateAndTheAppRestartsWithIt() {
        serveRelease()
        open()
        restarts.target = find("updateDialog")
        restarts.clear()

        checkForUpdates()
        expectText("Version 0.10.0 is available")
        expectText("You have version 0.9.0.")
        expectText("Changelog")
        compare(releaseRequests(), 1)
        tapText("Update")

        expectText("Version 0.10.0 is ready")
        compare(testApp.filesIn("applications/pbookorbit/update"), ["pbookorbit"])
        compare(testApp.filesIn("applications"), ["pbookorbit.app"], "the new launcher")
        compare(testApp.filesIn("applications/pbookorbit"), [], "no restart asked for yet")

        tapText("Restart now")
        expectText("Restarting…")
        tryCompare(restarts, "count", 1)
        compare(testApp.filesIn("applications/pbookorbit"), ["restart"])
    }

    // The update waits in place, without a restart, for the next time the app opens
    function test_updatingLaterLeavesItForTheNextStart() {
        serveRelease()
        open()
        checkForUpdates()
        tapText("Update")
        expectText("Version 0.10.0 is ready")

        tapText("Later")

        expectNoText("Version 0.10.0 is ready")
        compare(testApp.filesIn("applications/pbookorbit/update"), ["pbookorbit"])
        compare(testApp.filesIn("applications/pbookorbit"), [], "no restart asked for")
    }

    // A file that doesn't match GitHub's checksum
    function test_aDamagedDownloadIsntInstalledAndCanBeTriedAgain() {
        serveRelease("stored.zip")
        open()
        checkForUpdates()

        tapText("Update")

        expectText("Couldn't update")
        expectText("The download was damaged. Try again.")
        compare(testApp.filesIn("applications/pbookorbit/update"), [])
        compare(testApp.filesIn("applications"), [])

        serveRelease()
        tapText("Try again")
        expectText("Version 0.10.0 is ready")
    }

    // A build run without its launcher, as in the emulator, can't install
    function test_withoutTheLauncherOnlyTheChangelogIsOffered() {
        serveRelease()
        open({}, {noLauncher: true})

        checkForUpdates()

        expectText("You have version 0.9.0. Get the new one from its GitHub page.")
        expectText("Changelog")
        expectNoText("Update")
    }

    function test_beingUpToDateIsSaid() {
        fakeServer.respond("GET", "/releases", 200, "releases/none-newer.json")
        openLibrary()

        checkForUpdates()

        expectText("PBookOrbit is up to date")
        expectText("You have the latest version, 0.9.0.")
        expectNoText("Changelog")
    }

    // A newer release built only for other devices
    function test_anUpdateWithoutABuildForThisDeviceSaysSo() {
        fakeServer.respond("GET", "/releases", 200, "releases/newer-not-for-b300.json")
        openLibrary()

        checkForUpdates()

        expectText("Version 0.10.0 isn't ready for this device")
    }

    function test_aFailedCheckCanBeTriedAgain() {
        open({}, {offline: true})

        checkForUpdates()

        expectText("Couldn't check for updates")
        expectText("There's no network connection. Connect to Wi-Fi and try again.")
        compare(releaseRequests(), 0)

        testApp.offline = false
        fakeServer.respond("GET", "/releases", 500, "server-error.json")
        tapText("Try again")
        expectText("GitHub couldn't list the releases (HTTP 500).")

        fakeServer.respond("GET", "/releases", 200, "releases/newer.json")
        tapText("Try again")
        expectText("Version 0.10.0 is available")
    }
}
