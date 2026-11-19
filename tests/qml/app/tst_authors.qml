import QtQuick
import "../helpers"

// The Authors tab. The server has Frank Herbert (four records: Dune, Dune Messiah, and
// Children of Dune as an ebook and a separate audiobook), Dan Simmons (two Hyperion Cantos
// books), James S. A. Corey (four Expanse books, one an audiobook) and Ann Leckie (one book
// in no series). The list comes first, each time the tab opens, then the books of the
// authors in view, which set their formats, book and series counts, a book with an ebook
// and audiobook counting once, saved until looked up again. Unlike collections and series,
// authors have the library's filter, which by format needs every author looked up, and
// tapping one opens their info page. Offline, the authors are the downloaded books'.
//
// The page itself is tested in components/tst_grouplistpage.qml, and what every group list
// shares in tst_series.qml.
AppTestCase {
    name: "Authors"

    readonly property string authors: "/api/v1/authors"
    // Every library's, as Series and Authors list them all to start with
    readonly property string books: "/api/v1/books/query"
    readonly property string allByName: "Ann Leckie (1), Dan Simmons (2), Frank Herbert (3), James S. A. Corey (4)"
    readonly property var dune: ({id: 1, title: "Dune", authors: ["Frank Herbert"], seriesName: "Dune",
                                  seriesIndex: 1, formats: ["epub"], file: "Dune.epub"})
    readonly property var leviathanWakes: ({id: 10, title: "Leviathan Wakes", authors: ["James S. A. Corey"],
                                            seriesName: "The Expanse", seriesIndex: 1, formats: ["m4b"],
                                            file: "Leviathan Wakes.m4b"})

    function serveAuthors() {
        fakeServer.respond("GET", authors, 200, "authors/list.json")
        fakeServer.respond("GET", authors + "/1", 200, "authors/frank-herbert.json")
        // Each author's books, found by author name
        fakeServer.respond("POST", books, 200, "authors/books.json", {filter: {rules: [{field: "author"}]}})
    }

    function openAuthors(options) {
        openLibrary(undefined, undefined, options)
        serveAuthors()
        bookRow("Dune")
        tap("AuthorsTab")
        const page = find("authorsPage")
        verify(page.visible, "the Authors view shows")
        return page
    }

    function rows() {
        return groupRows("authorsPage")
    }

    function row(name) {
        return groupRow("authorsPage", name)
    }

    function authorRequests() {
        return fakeServer.requests.filter(r => r.method === "GET" && r.path === authors).length
    }


    // Sixty authors, more than a screen
    function openManyAuthors() {
        openLibrary()
        fakeServer.respondJson("GET", authors, 200, {total: 60, items: Array.from({length: 60}, (_, i) => ({
            id: 201 + i, name: "Author " + String(i + 1).padStart(2, "0"), bookCount: 2,
            lastAddedAt: "2026-01-01 10:00:00+00", imageUrl: null
        }))})
        fakeServer.respond("POST", books, 200, "authors/books.json", {filter: {rules: [{field: "author"}]}})
        bookRow("Dune")
        tap("AuthorsTab")
        const list = find("authorsPage").list
        tryVerify(() => list.count === 60, 5000, "every author is listed")
        return list
    }

    function filterBy(option) {
        tap("filterButton", find("authorsPage"))
        tap(option, find("filterMenu"))
    }

    function setDownloadedOnly() {
        tap("filterButton", find("authorsPage"))
        tap("downloadedOnly", find("filterMenu"))
        // The menu stays open for the switch
        tap("filterButton", find("authorsPage"))
    }

    // Counts settle once each author's books are in
    function openLoadedAuthors(options) {
        openAuthors(options)
        tryVerify(() => rows() === allByName, 5000, "A-Z, with counts from their books: " + rows())
    }

    function test_listsTheAuthorsByName() {
        openLoadedAuthors()
    }

    // Children of Dune's ebook and audiobook are separate records but one book
    function test_rowShowsItsSeriesAndFormats() {
        openLoadedAuthors()

        const herbert = row("Frank Herbert")
        compare(herbert.group.bookCount, 3)
        compare(herbert.group.seriesCount, 1)
        compare(herbert.group.formats, ["epub", "m4b"])
        compare(row("Ann Leckie").group.seriesCount, 0, "no series")
        compare(row("Dan Simmons").group.formats, ["epub"])
    }

    // Authors alone have sort names, in A-Z sections like names
    function test_sortBySortName() {
        openLoadedAuthors()

        sortBy("authorsPage", "Sort name")

        compare(rows(), "James S. A. Corey (4), Frank Herbert (3), Ann Leckie (1), Dan Simmons (2)",
                "by surname")
        compare(find("jumpRail", find("authorsPage")).sections.map(s => s.label).join(""), "CHLS")
    }

    function test_tappingAnAuthorOpensTheirInfo() {
        openLoadedAuthors()

        mouseClick(row("Frank Herbert"))

        const info = find("authorInfoPage")
        verify(info.visible, "their info page shows")
        compare(info.author.name, "Frank Herbert")
        tryVerify(() => info.details.description === "Author of Dune.", 5000, "with their details")
    }

    function test_backFromAnAuthorReturnsToTheTab() {
        openLoadedAuthors()
        mouseClick(row("Frank Herbert"))
        const info = find("authorInfoPage")
        verify(info.visible)

        tap("backButton", info)

        verify(!info.visible, "the info page closes")
        verify(find("authorsPage").visible, "the Authors view is back")
        compare(rows(), allByName)
    }

    // Each time the tab opens, the list and the books of the authors in view are asked for
    // again
    function test_reloadedEachTimeTheTabOpens() {
        openLoadedAuthors()
        compare(authorRequests(), 1)
        const lookups = lookedUp("author").length

        tap("LibraryTab")
        tap("AuthorsTab")

        tryVerify(() => authorRequests() === 2, 5000, "the list is asked for again")
        tryVerify(() => lookedUp("author").length > lookups, 5000, "and the authors in view looked up again")
        compare(rows(), allByName)
    }

    // Only the authors on screen, and a screen either side, have their books looked up
    // Only the authors in view are looked up (as tst_series tests for every list), until
    // filtering by format, which needs every author's books, looks them all up
    function test_formatFilterLooksUpEveryAuthor() {
        openManyAuthors()
        tryVerify(() => lookedUp("author").includes("Author 01"), 5000, "the first are looked up")
        wait(300)
        verify(!lookedUp("author").includes("Author 60"), "not the last")

        filterBy("Audiobooks")

        tryVerify(() => lookedUp("author").includes("Author 60"), 5000, "every author, without scrolling")
    }

    // Downloaded only uses the downloaded books, so it needn't look every author up
    function test_downloadedOnlyDoesntLookUpEveryAuthor() {
        openManyAuthors()
        tryVerify(() => lookedUp("author").includes("Author 01"), 5000, "the first are looked up")

        setDownloadedOnly()
        wait(500)

        verify(!lookedUp("author").includes("Author 60"), "not the last")
        verify(find("emptyState", find("authorsPage")).visible, "no downloaded books, so no authors")
    }

    // At the next start, what the authors' books showed is there before they're looked up,
    // and stays if they can't be
    function test_startShowsTheSavedDetails() {
        openLoadedAuthors()
        fakeServer.respond("POST", books, 500, "server-error.json", {filter: {rules: [{field: "author"}]}})
        const lookups = lookedUp("author").length

        reopen()
        tap("AuthorsTab")

        tryVerify(() => authorRequests() === 2, 5000, "the list is asked for again")
        tryVerify(() => lookedUp("author").length > lookups, 5000, "the books are asked for, and fail")
        wait(300)
        compare(rows(), allByName, "the saved counts")
        compare(row("Frank Herbert").group.formats, ["epub", "m4b"])
        compare(row("Frank Herbert").group.seriesCount, 1)
    }

    // Only authors with books in the format, counting just those. A counted book shows all
    // its formats: Children of Dune is an audiobook and an ebook.
    function test_audiobooksFilter() {
        openLoadedAuthors()

        filterBy("Audiobooks")

        compare(rows(), "Frank Herbert (1), James S. A. Corey (1)")
        compare(row("Frank Herbert").group.formats, ["epub", "m4b"])
        compare(row("James S. A. Corey").group.formats, ["m4b"])
    }

    function test_ebooksFilter() {
        openLoadedAuthors()

        filterBy("Ebooks")

        compare(rows(), "Ann Leckie (1), Dan Simmons (2), Frank Herbert (3), James S. A. Corey (3)",
                "all but the audiobook-only Leviathan Wakes")
    }

    function test_downloadedOnly() {
        openLoadedAuthors({books: [dune]})

        setDownloadedOnly()

        tryVerify(() => rows() === "Frank Herbert (1)", 5000, "only their downloaded book: " + rows())
    }

    function test_downloadedOnlyWithoutDownloadsSaysSo() {
        openLoadedAuthors()

        setDownloadedOnly()

        const empty = find("emptyState", find("authorsPage"))
        tryVerify(() => empty.visible, 5000, "No authors")
        compare(empty.title, "No authors")
        compare(empty.text, "Turn off Downloaded only to see every author.")
    }

    function test_noAuthorsSaysSo() {
        openLibrary()
        fakeServer.respond("GET", authors, 200, "authors/none.json")
        bookRow("Dune")

        tap("AuthorsTab")

        const empty = find("emptyState", find("authorsPage"))
        tryVerify(() => empty.visible, 5000, "No authors")
        compare(empty.title, "No authors")
        compare(empty.text, "Authors show here once the library has books.")
    }

    // Offline, the downloaded books' authors, counting only those
    function test_offlineListsTheDownloadedBooksAuthors() {
        open(savedSession, {offline: true, books: [dune, leviathanWakes]})
        bookRow("Dune")

        tap("AuthorsTab")

        tryVerify(() => rows() === "Frank Herbert (1), James S. A. Corey (1)", 5000,
                  "only authors of downloaded books: " + rows())
        compare(row("James S. A. Corey").group.formats, ["m4b"])
        compare(fakeServer.requests.length, 0, "the server isn't asked")
    }

    function test_offlineWithoutDownloadsSaysSo() {
        open(savedSession, {offline: true})

        tap("AuthorsTab")

        const empty = find("emptyState", find("authorsPage"))
        tryVerify(() => empty.visible, 5000, "No authors")
        compare(empty.text, "You're currently offline, only authors of downloaded books can be shown.")
    }

    // Back online, the server's authors replace the downloaded books'
    function test_reconnectingShowsTheServersAuthors() {
        open(savedSession, {offline: true, books: [dune]})
        tap("AuthorsTab")
        tryVerify(() => rows() === "Frank Herbert (1)", 5000, "the downloaded book's author")
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        serveLibrary()
        serveAuthors()

        testApp.offline = false
        tap("menuButton")
        tap("reconnect")

        tryVerify(() => rows() === allByName, 5000, "the server's authors: " + rows())
    }

    // The last authors show at the next start while the server answers
    function test_startShowsTheLastAuthors() {
        openLoadedAuthors()
        fakeServer.hold("GET", authors)

        reopen()
        tap("AuthorsTab")

        tryVerify(() => rows() === allByName, 5000, "the saved rows: " + rows())
        verify(!find("spinner", find("authorsPage")).visible, "no spinner over them")
        fakeServer.release("GET", authors)
    }
}
