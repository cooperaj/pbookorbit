import QtQuick
import "../helpers"

// Checking for a newer release of the app, from the header's menu. GitHub's releases come
// from the fake server, and the app is version 0.9.0 built for an Era Color (B300, firmware
// 6.10; see TestApp in main.cpp).
AppTestCase {
    name: "Updating"

    function checkForUpdates() {
        tap("menuButton")
        tapText("Check for updates")
    }

    function releaseRequests() {
        return fakeServer.requests.filter(r => r.path === "/releases").length
    }

    // Signed out too, in case signing in needs the update
    function test_aUserCanFindAnUpdateAndItsChangelog() {
        fakeServer.respond("GET", "/releases", 200, "releases/newer.json")
        open()

        checkForUpdates()

        expectText("Version 0.10.0 is available")
        expectText("You have version 0.9.0.")
        expectText("Changelog")
        compare(releaseRequests(), 1)
        tapText("Close")
        expectNoText("Version 0.10.0 is available")
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
