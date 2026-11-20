import QtQuick
import "../helpers"

// A server with several libraries: Books, Audiobooks and Comics (libraries/several.json).
// The book list and search use one of them, the first until another is chosen in the
// filter menu, and the choice is kept until signing out. Series and Authors list every
// library's groups unless set to one there, and go back to all of them once left. A series
// or author's books come from the library its list shows, or from the only library a
// series is in, or else from every library, which has no A-Z sections.
AppTestCase {
    name: "Libraries"

    readonly property string audiobooks: "/api/v1/libraries/2/books"
    readonly property string everyLibrary: "/api/v1/books/query"

    function init() {
        fakeServer.reset()
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        serveLibrary()
        fakeServer.respond("GET", "/api/v1/libraries", 200, "libraries/several.json")
        fakeServer.respond("POST", audiobooks, 200, "libraries/search-dune.json")
        fakeServer.respond("POST", audiobooks + "/jump-buckets", 200, "libraries/jump-buckets.json")
    }

    function asked(path) {
        return fakeServer.requests.filter(r => r.path === path)
    }

    function openOn(libraryId) {
        open(Object.assign({libraryId: String(libraryId)}, savedSession))
    }

    function test_startsWithTheFirst() {
        open(savedSession)

        bookRow("Hyperion")
        compare(bookOrbit.session.libraries.map(l => l.name).join(", "), "Books, Audiobooks, Comics")
        compare(bookOrbit.session.libraryId, 1)
        compare(asked(audiobooks).length, 0)
    }

    function test_startsWithTheOneChosenBefore() {
        openOn(2)

        bookRow("Dune Messiah")
        compare(bookOrbit.session.libraryId, 2)
        compare(asked("/api/v1/libraries/1/books").length, 0, "the first isn't asked for")
    }

    function test_startsWithTheFirstIfTheChosenOneHasGone() {
        openOn(9)

        bookRow("Hyperion")
        compare(bookOrbit.session.libraryId, 1)
    }

    function test_choosingOneListsItsBooks() {
        open(savedSession)
        bookRow("Hyperion")

        bookOrbit.session.chooseLibrary(2)

        bookRow("Dune Messiah")
        verify(asked(audiobooks).length > 0, "its books are asked for")
    }

    // Next time, its books, and not the other library's saved rows meanwhile
    function test_choiceIsKeptForNextTime() {
        open(savedSession)
        bookRow("Hyperion")
        wait(2500)   // the first library's rows saved once loading settles
        bookOrbit.session.chooseLibrary(2)
        bookRow("Dune Messiah")
        fakeServer.hold("GET", "/api/v1/libraries")

        reopen()

        wait(500)
        compare(titlesIn(find("bookList")), "", "no rows from the first library")
        fakeServer.release("GET", "/api/v1/libraries")
        bookRow("Dune Messiah")
        compare(bookOrbit.session.libraryId, 2)
    }

    function test_signingOutForgetsTheChoice() {
        open(savedSession)
        bookRow("Hyperion")
        bookOrbit.session.chooseLibrary(2)
        bookRow("Dune Messiah")

        bookOrbit.session.signOut()
        fakeServer.respond("POST", "/api/v1/auth/login", 200, "auth/login-success.json")
        signIn(fakeServer.url, "reader", "right")

        bookRow("Hyperion")
        compare(bookOrbit.session.libraryId, 1)
    }

    function test_seriesOfEveryLibraryToStartWith() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("GET", "/api/v1/series", 200, "series/list.json")

        tap("SeriesTab")

        tryVerify(() => asked("/api/v1/series").length > 0, 5000, "the series are asked for")
        verify(!("libraryId" in asked("/api/v1/series")[0].query), "for no library in particular")
    }

    function test_seriesOfOneLibrary() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("GET", "/api/v1/series", 200, "series/list.json")
        fakeServer.respond("POST", audiobooks, 200, "series/books.json", {filter: {rules: [{field: "series"}]}})

        bookOrbit.series.setLibrary(2)
        tap("SeriesTab")

        tryVerify(() => asked("/api/v1/series").length > 0, 5000, "the series are asked for")
        compare(asked("/api/v1/series")[0].query.libraryId, "2")
        tryVerify(() => asked(audiobooks).some(r => r.body.filter && r.body.filter.rules[0].field === "series"),
                  5000, "their books are looked up there")
    }

    function openSeriesInLibraries() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("GET", "/api/v1/series", 200, "series/in-libraries.json")
        fakeServer.respond("POST", everyLibrary, 200, "series/books.json", {filter: {rules: [{field: "series"}]}})
        fakeServer.respond("POST", everyLibrary, 200, "series/dune-books.json", {sort: [{field: "seriesIndex"}]})
        fakeServer.respond("POST", audiobooks, 200, "series/dune-books.json", {sort: [{field: "seriesIndex"}]})
        tap("SeriesTab")
    }

    function seriesBooksAskedAt(path) {
        return asked(path).filter(r => r.body.sort && r.body.sort[0].field === "seriesIndex").length
    }

    function test_seriesInOneLibraryListsItsBooksThere() {
        openSeriesInLibraries()

        mouseClick(groupRow("seriesPage", "Dune"))

        tryVerify(() => seriesBooksAskedAt(audiobooks) > 0, 5000, "asked of Audiobooks")
        compare(seriesBooksAskedAt(everyLibrary), 0)
    }

    function test_seriesInSeveralLibrariesListsTheBooksOfAll() {
        openSeriesInLibraries()

        mouseClick(groupRow("seriesPage", "Hyperion Cantos"))

        tryVerify(() => seriesBooksAskedAt(everyLibrary) > 0, 5000, "asked of every library")
        compare(seriesBooksAskedAt(audiobooks), 0)
    }

    // The server has A-Z sections only for a library's books
    function test_everyLibrarysBooksHaveNoLetterSections() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("POST", everyLibrary, 200, "libraries/menu-dune-books.json")

        root.openBooksOf("author", ["Frank Herbert"], "", -1)

        const page = find("booksOfPage")
        tryVerify(() => titlesIn(page.list) === "Dune, Dune Messiah", 5000)
        compare(asked(everyLibrary + "/jump-buckets").length, 0)
        compare(bookOrbit.booksOf.jumpSections.length, 0)
    }

    // A book's other books are those in its library, even from a list of several libraries'
    function test_aBooksAuthorIsLookedForInItsLibrary() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("POST", audiobooks, 200, "libraries/menu-dune-books.json",
                           {filter: {rules: [{field: "author"}]}})

        root.openBooksOf("author", ["Frank Herbert"], "", root.libraryOf({libraryId: 2}))

        tryVerify(() => asked(audiobooks).some(r => r.body.filter && r.body.filter.rules[0].field === "author"),
                  5000, "asked of Audiobooks")
    }

    // Downloaded only lists the library's downloaded books, and any whose library isn't known
    function test_downloadedOnlyListsTheLibrarysBooks() {
        open(Object.assign({libraryId: "2"}, savedSession), {books: [
            {id: 21, libraryId: 1, title: "Ancillary Justice", authors: ["Ann Leckie"], formats: ["epub"],
             file: "justice.epub"},
            {id: 22, libraryId: 2, title: "Leviathan Wakes", authors: ["James S. A. Corey"], formats: ["m4b"],
             file: "leviathan.m4b"},
            {id: 23, title: "Children of Dune", authors: ["Frank Herbert"], formats: ["epub"], file: "children.epub"},
        ]})
        bookRow("Dune Messiah")

        tap("filterButton", find("bookList"))
        tap("downloadedOnly", find("filterMenu"))

        tryVerify(() => titlesIn(find("bookList")) === "Children of Dune, Leviathan Wakes", 5000,
                  "only Audiobooks' and the unknown: " + titlesIn(find("bookList")))
    }

    // The filter menu's libraries, top to bottom, the chosen one in brackets:
    // "[Books], Audiobooks, Comics"
    function libraryOptions() {
        const menu = find("filterMenu")
        return ["All libraries", "Books", "Audiobooks", "Comics"]
            .map(name => present("library " + name, menu))
            .filter(row => row && row.visible)
            .map(row => row.checked ? "[" + row.text + "]" : row.text)
            .join(", ")
    }

    // The item with this name, if there is one
    function present(name, under) {
        return findChild(under, name) || findVisual(under, name)
    }

    function openFilterMenu(pageName) {
        tap("filterButton", find(pageName))
        verify(find("filterMenu").visible, "the menu opens")
    }

    function test_libraryViewOffersEachLibrary() {
        open(savedSession)
        bookRow("Hyperion")

        compare(find("filterButton", find("bookList")).text, "Books", "the button names it")
        openFilterMenu("bookList")

        compare(libraryOptions(), "[Books], Audiobooks, Comics", "no All libraries")
        verify(find("Ebooks", find("filterMenu")).visible, "the content types too")
    }

    function test_choosingALibraryInTheMenu() {
        open(savedSession)
        bookRow("Hyperion")
        openFilterMenu("bookList")

        tap("library Audiobooks", find("filterMenu"))

        verify(!find("filterMenu").visible, "the menu closes")
        bookRow("Dune Messiah")
        compare(find("filterButton", find("bookList")).text, "Audiobooks")
        compare(bookOrbit.session.libraryId, 2)
    }

    function test_oneLibraryHasNoChoice() {
        openLibrary()
        bookRow("Hyperion")

        compare(find("filterButton", find("bookList")).text, "All titles")
        openFilterMenu("bookList")
        compare(libraryOptions(), "")
        verify(!find("libraries heading", find("filterMenu")).visible, "no heading")
    }

    function openSeriesTab() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("GET", "/api/v1/series", 200, "series/list.json")
        tap("SeriesTab")
        tryVerify(() => asked("/api/v1/series").length > 0, 5000, "the series are asked for")
    }

    function seriesAskedFor(libraryId) {
        return asked("/api/v1/series").filter(r => r.query.libraryId === libraryId).length
    }

    function test_seriesOffersAllLibrariesOrOne() {
        openSeriesTab()

        compare(find("filterButton", find("seriesPage")).text, "All libraries")
        openFilterMenu("seriesPage")

        compare(libraryOptions(), "[All libraries], Books, Audiobooks, Comics")
        verify(find("Ebooks", find("filterMenu")).visible, "with content types")
        verify(find("downloadedOnly", find("filterMenu")).visible, "and Downloaded only")
    }

    // Downloaded only counts the library's downloaded books, and any whose library isn't
    // known, as the book list does
    function test_downloadedSeriesOfALibrary() {
        open(savedSession, {books: [
            {id: 21, libraryId: 1, title: "Hyperion", authors: ["Dan Simmons"], seriesName: "Hyperion Cantos",
             formats: ["epub"], file: "hyperion.epub"},
            {id: 22, libraryId: 2, title: "Leviathan Wakes", authors: ["James S. A. Corey"],
             seriesName: "The Expanse", formats: ["m4b"], file: "leviathan.m4b"},
            {id: 23, title: "Dune", authors: ["Frank Herbert"], seriesName: "Dune", formats: ["epub"],
             file: "dune.epub"},
        ]})
        bookRow("Hyperion")
        fakeServer.respond("GET", "/api/v1/series", 200, "series/list.json")
        tap("SeriesTab")
        openFilterMenu("seriesPage")
        tap("library Audiobooks", find("filterMenu"))
        tryVerify(() => seriesAskedFor("2") === 1, 5000)

        setDownloadedOnly("seriesPage")

        tryVerify(() => groupRows("seriesPage") === "Dune (1), The Expanse (1)", 5000,
                  "only Audiobooks' and the unknown: " + groupRows("seriesPage"))
    }

    function test_choosingASeriesLibrary() {
        openSeriesTab()
        openFilterMenu("seriesPage")

        tap("library Audiobooks", find("filterMenu"))

        tryVerify(() => seriesAskedFor("2") === 1, 5000, "Audiobooks' series asked for")
        compare(find("filterButton", find("seriesPage")).text, "Audiobooks")
        compare(bookOrbit.session.libraryId, 1, "the book list's is unchanged")
    }

    // Back to every library's, without asking for them until shown
    function test_leavingSeriesForgetsItsLibrary() {
        openSeriesTab()
        openFilterMenu("seriesPage")
        tap("library Audiobooks", find("filterMenu"))
        tryVerify(() => seriesAskedFor("2") === 1, 5000)
        const before = asked("/api/v1/series").length

        tap("LibraryTab")
        wait(300)
        compare(asked("/api/v1/series").length, before, "nothing asked while away")
        tap("SeriesTab")

        tryVerify(() => asked("/api/v1/series").length === before + 1, 5000, "asked for again")
        compare(seriesAskedFor(undefined), 2, "for every library")
        compare(find("filterButton", find("seriesPage")).text, "All libraries")
    }

    // An author's books are those in the library Authors shows
    function test_authorsInALibrary() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("GET", "/api/v1/authors", 200, "authors/list.json")
        fakeServer.respond("GET", "/api/v1/authors/1", 200, "authors/frank-herbert.json")
        tap("AuthorsTab")
        openFilterMenu("authorsPage")
        compare(libraryOptions(), "[All libraries], Books, Audiobooks, Comics")
        verify(find("Ebooks", find("filterMenu")).visible, "with content types")

        tap("library Audiobooks", find("filterMenu"))
        tryVerify(() => asked("/api/v1/authors").some(r => r.query.libraryId === "2"), 5000,
                  "Audiobooks' authors asked for")
        mouseClick(groupRow("authorsPage", "Frank Herbert"))
        tap("BooksCell", find("authorInfoPage"))

        // Sorted, unlike the lookups for the list's counts
        tryVerify(() => asked(audiobooks).some(r => r.body.filter && r.body.filter.rules[0].field === "author"
                                                     && r.body.sort),
                  5000, "their books asked of Audiobooks")
    }

    function test_collectionsHaveNoFilter() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("GET", "/api/v1/collections", 200, "collections/list.json")

        tap("CollectionsTab")

        verify(!find("filterButton", find("collectionsPage")).visible)
    }
}
