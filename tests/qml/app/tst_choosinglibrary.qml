import QtQuick
import "../helpers"

// Choosing which library to use when the server has several: Books, Audiobooks and Comics
// (libraries/several.json). Asked once, after signing in, and kept until signing out or
// changed from the menu. Books has Dune, Hyperion and Neuromancer; Audiobooks has Dune and
// Dune Messiah.
AppTestCase {
    name: "ChoosingLibrary"

    readonly property string audiobooks: "/api/v1/libraries/2/books"

    function init() {
        fakeServer.reset()
        fakeServer.respond("POST", "/api/v1/auth/login", 200, "auth/login-success.json")
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        serveLibrary()
        fakeServer.respond("GET", "/api/v1/libraries", 200, "libraries/several.json")
        fakeServer.respond("POST", audiobooks, 200, "libraries/search-dune.json")
        fakeServer.respond("POST", audiobooks + "/jump-buckets", 200, "libraries/jump-buckets.json")
    }

    function signInAsNewUser() {
        signIn(fakeServer.url, "reader", "right")
        tryVerify(() => !find("loginPage").visible, 5000, "signed in")
    }

    function booksAskedFor(path) {
        return fakeServer.requests.filter(r => r.path.startsWith(path)).length
    }

    // The libraries in the dialog, top to bottom, the selected one in brackets:
    // "[Books], Audiobooks, Comics"
    function libraryRows() {
        const list = find("libraryList")
        const rows = []
        for (let i = 0; i < list.count; i++) {
            const row = list.itemAtIndex(i)
            rows.push(row.selected ? "[" + row.modelData.name + "]" : row.modelData.name)
        }
        return rows.join(", ")
    }

    // Signed in with Books chosen, and its books listed
    function openOnBooks() {
        open(Object.assign({libraryId: "1"}, savedSession))
        bookRow("Hyperion")
    }

    function openChangeLibrary() {
        tap("menuButton")
        tap("changeLibrary")
        tryVerify(() => find("libraryDialog").visible, 5000, "the dialog shows")
    }

    function chooseLibrary(name) {
        const dialog = find("libraryDialog")
        tryVerify(() => dialog.visible, 5000, "the dialog shows")
        tap("library " + name, dialog)
        tap("continueButton", dialog)
        verify(!dialog.visible, "the dialog closes")
    }

    function test_severalLibrariesAskWhichToUse() {
        open()

        signInAsNewUser()

        const dialog = find("libraryDialog")
        tryVerify(() => dialog.visible, 5000, "the dialog shows")
        compare(dialog.heading, "Choose your library")
        expectText("Your BookOrbit server has 3 libraries. Choose the one to use on this device.")
        compare(libraryRows(), "[Books], Audiobooks, Comics", "the first is selected to begin with")
        expectText("3 books")
        expectText("1 book")
        compare(booksAskedFor("/api/v1/libraries/"), 0, "no books are asked for yet")
        verify(!bookOrbit.session.busy, "waiting for a choice isn't loading")
    }

    function test_tappingALibrarySelectsIt() {
        open()
        signInAsNewUser()
        tryVerify(() => find("libraryDialog").visible, 5000, "the dialog shows")

        tap("library Comics")

        compare(libraryRows(), "Books, Audiobooks, [Comics]")
    }

    function test_continueUsesTheSelectedLibrary() {
        open()
        signInAsNewUser()

        chooseLibrary("Audiobooks")

        expectText("Dune")
        verify(booksAskedFor(audiobooks) > 0, "Audiobooks' books are asked for")
        compare(booksAskedFor("/api/v1/libraries/1/"), 0, "Books' aren't")
    }

    function test_theChoiceIsKeptWhenTheAppStartsAgain() {
        open()
        signInAsNewUser()
        chooseLibrary("Audiobooks")
        expectText("Dune")

        reopen()

        expectText("Dune")
        verify(!find("libraryDialog").visible, "not asked again")
        verify(booksAskedFor(audiobooks) > 0, "Audiobooks' books are asked for")
    }

    function test_quittingBeforeChoosingAsksAtNextStart() {
        open(savedSession)

        tryVerify(() => find("libraryDialog").visible, 5000, "the dialog shows")
    }

    function test_aLibraryNoLongerThereAsksAgain() {
        open(Object.assign({libraryId: "9"}, savedSession))

        tryVerify(() => find("libraryDialog").visible, 5000, "the dialog shows")
    }

    function test_oneLibraryIsUsedWithoutAsking() {
        fakeServer.respond("GET", "/api/v1/libraries", 200, "libraries/list.json")
        open()

        signInAsNewUser()

        expectText("Dune")
        verify(!find("libraryDialog").visible, "not asked")
    }

    function test_signingOutForgetsTheChoice() {
        open()
        signInAsNewUser()
        chooseLibrary("Audiobooks")
        expectText("Dune")

        tap("menuButton")
        tapText("Sign out")
        signInAsNewUser()

        tryVerify(() => find("libraryDialog").visible, 5000, "asked again")
    }

    // Finding books looks through the chosen library, so it's offered once there is one
    function test_findBooksIsOfferedAfterTheChoice() {
        open({}, {files: ["Dune - Frank Herbert.epub"]})
        signInAsNewUser()
        tryVerify(() => find("libraryDialog").visible, 5000, "the dialog shows")
        verify(!find("findBooksDialog").visible, "not offered yet")

        chooseLibrary("Audiobooks")

        tryVerify(() => find("findBooksDialog").visible, 5000, "offered")
    }

    // Five rows show, and the rest scroll into view
    function test_manyLibrariesScroll() {
        const libraries = [1, 2, 3, 4, 5, 6, 7].map(id => ({id: id, name: "Library " + id, bookCount: id}))
        fakeServer.respondJson("GET", "/api/v1/libraries", 200, libraries)
        open()
        signInAsNewUser()
        tryVerify(() => find("libraryDialog").visible, 5000, "the dialog shows")
        const list = find("libraryList")

        compare(list.height, 5 * list.rowHeight)
        verify(list.contentHeight > list.height, "the list scrolls")
        verify(find("library Library 1").visible)
    }

    function test_changeLibraryIsInTheMenuWithSeveral() {
        openOnBooks()

        tap("menuButton")

        verify(find("changeLibrary").visible)
    }

    function test_noChangeLibraryWithOne() {
        fakeServer.respond("GET", "/api/v1/libraries", 200, "libraries/list.json")
        openOnBooks()

        tap("menuButton")

        verify(!find("changeLibrary").visible)
    }

    function test_changingStartsOnTheLibraryInUse() {
        openOnBooks()

        openChangeLibrary()

        compare(libraryRows(), "[Books], Audiobooks, Comics")
        verify(find("cancelButton").visible, "a change can be cancelled")
    }

    function test_changingLibraryListsItsBooks() {
        openOnBooks()
        openChangeLibrary()

        chooseLibrary("Audiobooks")

        bookRow("Dune Messiah")
        compare(titlesIn(find("bookList")), "Dune, Dune Messiah", "only Audiobooks' books")
    }

    function test_aChangeIsKeptWhenTheAppStartsAgain() {
        openOnBooks()
        openChangeLibrary()
        chooseLibrary("Audiobooks")
        bookRow("Dune Messiah")

        reopen()

        bookRow("Dune Messiah")
        verify(!find("libraryDialog").visible, "not asked")
    }

    function test_cancellingKeepsTheLibrary() {
        openOnBooks()
        openChangeLibrary()
        tap("library Audiobooks")

        tap("cancelButton")

        verify(!find("libraryDialog").visible, "the dialog closes")
        compare(booksAskedFor(audiobooks), 0, "Audiobooks' books aren't asked for")
        bookRow("Hyperion")
    }

    function test_choosingTheSameLibraryLoadsNothing() {
        openOnBooks()
        const asked = booksAskedFor("/api/v1/libraries/1/")
        openChangeLibrary()

        tap("continueButton", find("libraryDialog"))

        verify(!find("libraryDialog").visible, "the dialog closes")
        compare(booksAskedFor("/api/v1/libraries/1/"), asked, "no books asked for again")
    }

    // The series on screen are looked up again in the new library
    function test_changingLibraryReloadsTheSeriesTab() {
        fakeServer.respond("GET", "/api/v1/series", 200, "series/list.json")
        openOnBooks()
        tap("SeriesTab")
        tryVerify(() => fakeServer.requests.some(r => r.path === "/api/v1/series"), 5000, "series asked for")

        openChangeLibrary()
        chooseLibrary("Audiobooks")

        tryVerify(() => fakeServer.requests.some(r => r.path === "/api/v1/series" && r.query.libraryId === "2"),
                  5000, "Audiobooks' series asked for")
    }
}
