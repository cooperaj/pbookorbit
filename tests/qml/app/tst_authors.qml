import QtQuick
import "../helpers"

// The Authors tab. The server has Frank Herbert (four records: Dune, Dune Messiah, and
// Children of Dune as an ebook and a separate audiobook), Dan Simmons (two Hyperion Cantos
// books), James S. A. Corey (four Expanse books, one an audiobook) and Ann Leckie (one book
// in no series). The list comes first, then each author's books, which set their formats,
// book and series counts, a book with an ebook and audiobook counting once. Like the
// series, authors load the first time the tab opens only. Unlike collections and series,
// authors have the library's filter, and tapping one opens their info page. Offline, the
// authors are the downloaded books'.
//
// The page itself is tested in components/tst_grouplistpage.qml, and what every group list
// shares in tst_series.qml.
AppTestCase {
    name: "Authors"

    readonly property string authors: "/api/v1/authors"
    readonly property string books: "/api/v1/libraries/1/books"
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

    // The rows top to bottom, "name (books)"
    function rows() {
        const list = find("authorsPage").list
        const shown = []
        for (let i = 0; i < list.count; i++) {
            const row = list.itemAtIndex(i)
            if (row && row.visible)
                shown.push(row.group.name + " (" + row.group.bookCount + ")")
        }
        return shown.join(", ")
    }

    function row(name) {
        const list = find("authorsPage").list
        let found = null
        tryVerify(() => {
            for (let i = 0; i < list.count; i++) {
                const item = list.itemAtIndex(i)
                if (item && item.visible && item.group.name === name)
                    found = item
            }
            return found !== null
        }, 5000, "a row for " + name)
        return found
    }

    function authorRequests() {
        return fakeServer.requests.filter(r => r.method === "GET" && r.path === authors).length
    }

    function sortBy(option) {
        tap("sortButton", find("authorsPage"))
        tap(option, find("sortMenu"))
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

        sortBy("Sort name")

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

    function test_loadedOnlyTheFirstTime() {
        openLoadedAuthors()
        compare(authorRequests(), 1)

        tap("LibraryTab")
        tap("AuthorsTab")
        wait(500)

        compare(authorRequests(), 1, "not asked for again")
        compare(rows(), allByName)
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
