import QtQuick
import "../helpers"

// A server with several libraries: Books, Audiobooks and Comics (libraries/several.json).
// Each view has its own library. The book list shows one, the first until another is
// chosen. Series and Authors show every library's groups unless set to one, and keep it.
// Those choices are kept until signing out. An author's series, books-of lists and search
// start with every library each time. The content type and Downloaded only are every
// view's.
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
        bookOrbit.series.setLibrary(2)
        bookOrbit.authors.setLibrary(3)
        bookOrbit.filter.showContent("ebook", false)
        bookOrbit.filter.setDownloadedOnly(true)

        bookOrbit.session.signOut()
        fakeServer.respond("POST", "/api/v1/auth/login", 200, "auth/login-success.json")
        signIn(fakeServer.url, "reader", "right")

        bookRow("Hyperion")
        compare(bookOrbit.session.libraryId, 1)
        compare(bookOrbit.series.libraryId, -1, "series of every library")
        compare(bookOrbit.authors.libraryId, -1, "authors too")
        verify(bookOrbit.filter.ebooks && !bookOrbit.filter.downloadedOnly, "the content type too")
        compare(fakeServer.requests.filter(r => r.path === "/api/v1/libraries/1/books" && !r.body.filter
                                               && !r.path.endsWith("jump-buckets")).length > 0, true,
                "asked for unfiltered")
    }

    // The menu's libraries, top to bottom, the chosen one in brackets: "[Books], Audiobooks"
    function libraryOptions() {
        const menu = find("filterMenu")
        return ["All libraries", "Books", "Audiobooks", "Comics"]
            .map(name => present("library " + name, menu))
            .filter(row => row && row.visible)
            .map(row => row.checked ? "[" + row.text + "]" : row.text)
            .join(", ")
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

    function openSeriesTab(settings) {
        open(Object.assign(settings || {}, savedSession))
        bookRow("Hyperion")
        fakeServer.respond("GET", "/api/v1/series", 200, "series/list.json")
        tap("SeriesTab")
        tryVerify(() => asked("/api/v1/series").length > 0, 5000, "the series are asked for")
    }

    function seriesAskedFor(libraryId) {
        return asked("/api/v1/series").filter(r => r.query.libraryId === libraryId).length
    }

    function test_seriesOfEveryLibraryToStartWith() {
        openSeriesTab()

        verify(!("libraryId" in asked("/api/v1/series")[0].query), "for no library in particular")
    }

    function test_seriesOffersEveryLibraryOrOne() {
        openSeriesTab()

        compare(find("filterButton", find("seriesPage")).text, "All libraries")
        openFilterMenu("seriesPage")
        compare(libraryOptions(), "[All libraries], Books, Audiobooks, Comics")
        verify(find("Ebooks", find("filterMenu")).visible, "with content types")
        verify(find("downloadedOnly", find("filterMenu")).visible, "and Downloaded only")
    }

    // One library's series come from the server; the book list keeps its own
    function test_seriesOfOneLibrary() {
        openSeriesTab()
        openFilterMenu("seriesPage")

        tap("library Audiobooks", find("filterMenu"))

        verify(!find("filterMenu").visible, "the menu closes")
        tryVerify(() => seriesAskedFor("2") === 1, 5000, "Audiobooks' series asked for")
        compare(find("filterButton", find("seriesPage")).text, "Audiobooks")
        compare(bookOrbit.session.libraryId, 1, "the book list keeps Books")
    }

    function test_everyLibraryAgain() {
        openSeriesTab()
        openFilterMenu("seriesPage")
        tap("library Audiobooks", find("filterMenu"))
        tryVerify(() => seriesAskedFor("2") === 1, 5000, "Audiobooks' series asked for")
        const before = asked("/api/v1/series").length
        openFilterMenu("seriesPage")

        tap("library All libraries", find("filterMenu"))

        tryVerify(() => asked("/api/v1/series").length > before, 5000, "asked for again")
        verify(!("libraryId" in asked("/api/v1/series")[before].query), "for no library in particular")
        compare(find("filterButton", find("seriesPage")).text, "All libraries")
    }

    // Choosing the book list's library leaves the other views as they were
    function test_theBookListsLibraryIsItsOwn() {
        open(savedSession)
        bookRow("Hyperion")
        openFilterMenu("bookList")

        tap("library Audiobooks", find("filterMenu"))

        fakeServer.respond("GET", "/api/v1/series", 200, "series/list.json")
        tap("SeriesTab")
        tryVerify(() => asked("/api/v1/series").length > 0, 5000, "the series are asked for")
        verify(!("libraryId" in asked("/api/v1/series")[0].query), "for no library in particular")
        compare(find("filterButton", find("seriesPage")).text, "All libraries")
    }

    // Leaving Series and coming back, or starting again, it keeps its library
    function test_seriesLibraryIsKept() {
        openSeriesTab()
        openFilterMenu("seriesPage")
        tap("library Audiobooks", find("filterMenu"))
        tryVerify(() => seriesAskedFor("2") === 1, 5000, "Audiobooks' series asked for")
        tap("LibraryTab")
        tap("SeriesTab")
        tryVerify(() => seriesAskedFor("2") === 2, 5000, "Audiobooks' again")

        reopen()
        bookRow("Hyperion")
        tap("SeriesTab")

        tryVerify(() => seriesAskedFor("2") === 3, 5000, "Audiobooks' after starting again")
        compare(find("filterButton", find("seriesPage")).text, "Audiobooks")
    }

    // A library the server no longer has: every library's
    function test_seriesLibraryThatHasGone() {
        openSeriesTab({seriesLibraryId: "9"})

        verify(!("libraryId" in asked("/api/v1/series")[0].query), "for no library in particular")
        compare(bookOrbit.series.libraryId, -1)
    }

    // Downloaded only counts the library's downloaded books, and any whose library isn't
    // known, as the book list does
    function test_downloadedSeriesOfALibrary() {
        open(Object.assign({seriesLibraryId: "2"}, savedSession), {books: [
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
        tryVerify(() => seriesAskedFor("2") === 1, 5000)

        setDownloadedOnly("seriesPage")

        tryVerify(() => groupRows("seriesPage") === "Dune (1), The Expanse (1)", 5000,
                  "only Audiobooks' and the unknown: " + groupRows("seriesPage"))
    }

    // Authors have a library of their own
    function test_authorsInALibrary() {
        openSeriesTab()
        fakeServer.respond("GET", "/api/v1/authors", 200, "authors/list.json")
        tap("AuthorsTab")
        tryVerify(() => asked("/api/v1/authors").length > 0, 5000, "the authors are asked for")
        openFilterMenu("authorsPage")

        tap("library Comics", find("filterMenu"))

        tryVerify(() => asked("/api/v1/authors").some(r => r.query.libraryId === "3"), 5000,
                  "Comics' authors asked for")
        tap("SeriesTab")
        compare(find("filterButton", find("seriesPage")).text, "All libraries", "Series keeps its own")
    }

    // An author's series start with every library's, whatever they showed last time
    function test_anAuthorsSeriesStartWithEveryLibrary() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("GET", "/api/v1/series", 200, "series/list.json")
        bookOrbit.authorSeries.setLibrary(2)

        root.openAuthorSeries("Frank Herbert")

        compare(bookOrbit.authorSeries.libraryId, -1)
        compare(find("filterButton", find("authorSeriesPage")).text, "All libraries")
    }

    // A books-of list starts with every library's books. Back, the one before shows the
    // library it had.
    function test_booksOfStartWithEveryLibrary() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("POST", everyLibrary, 200, "libraries/menu-dune-books.json")
        root.openBooksOf("author", ["Frank Herbert"], "")
        tryVerify(() => asked(everyLibrary).some(r => r.body.filter.rules[0].field === "author"), 5000,
                  "every library's")
        openFilterMenu("booksOfPage")
        tap("library Audiobooks", find("filterMenu"))
        tryVerify(() => asked(audiobooks).some(r => r.body.filter && r.body.filter.rules[0].field === "author"),
                  5000, "Audiobooks' after choosing it")

        root.openBooksOf("series", ["Dune"], "")

        compare(find("filterButton", find("booksOfPage")).text, "All libraries")
        tryVerify(() => asked(everyLibrary).some(r => r.body.filter.rules[0].field === "series"), 5000,
                  "the series' in every library")
        root.closeBooksOf()
        compare(find("filterButton", find("booksOfPage")).text, "Audiobooks", "back to the author's")
    }

    // The server has A-Z sections only for a library's books
    function test_everyLibrarysBooksHaveNoLetterSections() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("POST", everyLibrary, 200, "libraries/menu-dune-books.json")

        root.openBooksOf("author", ["Frank Herbert"], "")

        const page = find("booksOfPage")
        tryVerify(() => titlesIn(page.list) === "Dune, Dune Messiah", 5000)
        compare(asked(everyLibrary + "/jump-buckets").length, 0)
        compare(bookOrbit.booksOf.jumpSections.length, 0)
    }

    function searches(path) {
        return asked(path).filter(r => r.body.q === "dune").length
    }

    // Searches for Dune, which every library is asked for
    function searchDune() {
        fakeServer.respond("POST", everyLibrary, 200, "libraries/search-dune.json")
        const before = searches(everyLibrary)
        tap("searchButton")
        type("searchField", "dune")
        tryVerify(() => searches(everyLibrary) === before + 1, 5000, "every library searched")
        tryVerify(() => titlesIn(find("searchResults")) !== "", 5000)
    }

    function test_searchSpansEveryLibrary() {
        open(savedSession)
        bookRow("Hyperion")

        searchDune()

        compare(find("filterButton", find("searchPage")).text, "All libraries")
    }

    function test_searchCanBeSetToOneLibrary() {
        open(savedSession)
        bookRow("Hyperion")
        searchDune()

        tap("filterButton", find("searchPage"))
        tap("library Audiobooks", find("filterMenu"))

        tryVerify(() => searches(audiobooks) === 1, 5000, "that library searched")
        compare(find("filterButton", find("searchPage")).text, "Audiobooks")
    }

    function test_searchStartsWithEveryLibraryEachTime() {
        open(savedSession)
        bookRow("Hyperion")
        searchDune()
        tap("filterButton", find("searchPage"))
        tap("library Audiobooks", find("filterMenu"))
        tryVerify(() => searches(audiobooks) === 1, 5000)
        tap("backButton", find("searchPage"))

        searchDune()

        compare(searches(audiobooks), 1, "not the last one's library")
        compare(find("filterButton", find("searchPage")).text, "All libraries")
    }

    // A content type chosen in one view shows in the others, applied to each when it's next
    // shown
    function test_contentTypeIsEveryViews() {
        openSeriesTab()
        const before = asked("/api/v1/libraries/1/books").length

        showOnly("seriesPage", "Audiobooks")
        tap("filterButton", find("seriesPage"))   // closes the menu
        wait(300)
        compare(asked("/api/v1/libraries/1/books").length, before, "the hidden book list waits")
        tap("LibraryTab")

        compare(find("filterButton", find("bookList")).text, "Books")
        tryVerify(() => asked("/api/v1/libraries/1/books").some(r => r.body.filter
                      && JSON.stringify(r.body.filter).indexOf("m4b") >= 0), 5000, "audiobooks asked for")
        openFilterMenu("bookList")
        verify(!find("Ebooks", find("filterMenu")).checked, "Ebooks unticked here too")
    }

    function test_collectionsHaveNoFilter() {
        open(savedSession)
        bookRow("Hyperion")
        fakeServer.respond("GET", "/api/v1/collections", 200, "collections/list.json")

        tap("CollectionsTab")

        verify(!find("filterButton", find("collectionsPage")).visible)
    }
}
