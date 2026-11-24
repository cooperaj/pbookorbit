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

    // Only the first sign-in on the device asks; after that it's in the menu
    function test_signingInAgainDoesNotOfferAgain() {
        open({}, {files: bookOnDevice})
        signInAsNewUser()
        tap("closeButton", find("findBooksDialog"))
        tap("menuButton")
        tap("signOut")
        verify(find("loginPage").visible)

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
        expectOnDevice("Dune", "epub")
        expectNotOnDevice("Hyperion")
        expectNotOnDevice("Neuromancer")
    }

    // Every library is searched, not just the one the book list shows
    function test_findingBooksSearchesEveryLibrary() {
        fakeServer.respond("GET", "/api/v1/libraries", 200, "libraries/several.json")
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/search-hail-mary.json")
        fakeServer.respond("POST", everyLibrary, 200, "libraries/books.json")
        open({}, {files: bookOnDevice})
        signInAsNewUser()
        const dialog = find("findBooksDialog")

        tap("searchButton", dialog)

        tryCompare(dialog, "step", "done")
        verify(downloads.isOnDevice(1), "Dune, in another library, is recorded as downloaded")
    }

    // Books not in the library are counted after the found ones
    function test_unmatchedBooksAreCounted() {
        open({}, {files: bookOnDevice.concat(["Unknown One.epub", "Unknown Two.epub"])})
        signInAsNewUser()
        const dialog = find("findBooksDialog")

        tap("searchButton", dialog)

        tryCompare(dialog, "step", "done")
        compare(dialog.message, "Found 1 book from your BookOrbit library, now listed as downloaded."
                                + " 2 others couldn't be matched.")
    }
}
