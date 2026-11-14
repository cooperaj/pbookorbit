import QtQuick
import QtTest
import "../helpers"

// The title bar: home, the title, search and the menu
AppTestCase {
    name: "Header"

    SignalSpy { id: homeTaps; signalName: "homeClicked" }

    // main.qml quits on homeClicked, which returns to the device's home screen. Quitting
    // here would end the test run, so this stops at the signal.
    function test_homeAsksToQuit() {
        openLibrary()
        homeTaps.target = find("appHeader")
        homeTaps.clear()

        tap("homeButton")

        compare(homeTaps.count, 1)
    }

    // Home works signed out too, unlike search and the menu
    function test_signedOutHasOnlyHome() {
        open()

        verify(find("homeButton").visible, "home")
        verify(!find("searchButton").visible, "no search")
        verify(!find("menuButton").visible, "no menu")
    }

    function test_titleScrollsBackToTheTop() {
        openLibrary("libraries/books-30.json", "libraries/jump-buckets-30.json")
        const list = find("bookList")
        tryCompare(list, "count", 30)
        list.positionViewAtIndex(25, ListView.Beginning)
        verify(list.contentY > list.originY, "scrolled down")

        tap("appTitle")

        tryCompare(list, "contentY", list.originY)
    }

    function test_searchButtonOpensSearch() {
        openLibrary()

        tap("searchButton")

        verify(find("searchPage").visible, "the search page shows")
    }

    // Finding books needs the server's library
    function test_offlineMenuHasReconnectNotFindBooks() {
        openLibrary(undefined, undefined, {offline: true})

        tap("menuButton")

        verify(find("reconnect").visible, "Reconnect")
        verify(!find("findBooks").visible, "no Find books")
        verify(find("signOut").visible, "Sign out")
    }

    function test_tappingThePageClosesTheMenu() {
        openLibrary()
        tap("menuButton")

        tap("headerMenuFade")

        verify(!find("headerMenu").visible, "the menu closes")
    }

    function test_findBooksStartsLooking() {
        openLibrary(undefined, undefined, {files: ["Dune - Frank Herbert.epub"]})
        fakeServer.respond("GET", "/api/v1/books/1", 200, "books/1.json")
        tap("menuButton")

        tap("findBooks")

        const dialog = find("findBooksDialog")
        verify(dialog.visible, "the dialog shows")
        verify(!find("headerMenu").visible, "the menu closes")
        tryCompare(dialog, "step", "done")
        verify(downloads.isOnDevice(1), "Dune is found")
    }

    // Signing out ends the session on the server and goes back to sign-in, keeping the
    // server and username
    function test_signOutReturnsToSignIn() {
        openLibrary()
        tryCompare(find("bookList"), "count", 3)
        tap("menuButton")

        tap("signOut")

        verify(find("loginPage").visible, "the sign-in page shows")
        verify(!find("headerMenu").visible, "the menu closes")
        tryVerify(() => fakeServer.requests.some(r => r.path === "/api/v1/auth/logout"), 5000,
                  "the session is ended on the server")
        verify(find("serverPill").visible, "the server is kept")
        compare(find("usernameField").text, "reader")
    }
}
