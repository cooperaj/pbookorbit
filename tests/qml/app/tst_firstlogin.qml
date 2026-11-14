import QtQuick
import "../helpers"

// Signing in for the first time on a device that already has books on it. The server has
// Dune, Hyperion and Neuromancer, and Dune is on the device, copied over some other way.
AppTestCase {
    name: "FirstLogin"

    readonly property var bookOnDevice: ["Dune - Frank Herbert.epub"]

    function init() {
        fakeServer.reset()
        fakeServer.respond("POST", "/api/v1/auth/login", 200, "auth/login-success.json")
        serveLibrary()
        fakeServer.respond("GET", "/api/v1/books/1", 200, "books/1.json")
    }

    function signInAsNewUser() {
        signIn(fakeServer.url, "reader", "right")
        tryVerify(() => !find("loginPage").visible, 5000, "signed in")
    }

    function test_booksOnDeviceOfferToFindThem() {
        open({}, {files: bookOnDevice})

        signInAsNewUser()

        const dialog = find("findBooksDialog")
        verify(dialog.visible, "the offer shows")
        compare(dialog.heading, "Find your books?")
    }

    function test_noBooksOnDeviceMeansNoOffer() {
        open()

        signInAsNewUser()

        verify(!find("findBooksDialog").visible, "no offer")
    }

    // Found books are recorded as downloaded, and marked so in the library among the others
    function test_findingBooksMarksThemDownloaded() {
        open({}, {files: bookOnDevice})
        signInAsNewUser()
        const dialog = find("findBooksDialog")

        tap("searchButton", dialog)

        tryCompare(dialog, "step", "done")
        compare(dialog.message, "Found 1 book from your BookOrbit library, now listed as downloaded.")
        verify(downloads.isOnDevice(1), "Dune is recorded as downloaded")
        verify(!downloads.isOnDevice(2), "Hyperion isn't")
        tryVerify(() => find("onDevicePill", bookRow("Dune")).visible, 5000, "Dune is marked on the device")
        verify(!find("onDevicePill", bookRow("Hyperion")).visible, "Hyperion isn't marked")
        verify(!find("onDevicePill", bookRow("Neuromancer")).visible, "Neuromancer isn't marked")
    }
}
