import QtQuick
import "../helpers"

// The Series tab. The server has Dune (four records: Dune, Dune Messiah, and Children of
// Dune as an ebook and a separate audiobook), Hyperion Cantos and The Expanse. The list
// comes first, each time the tab opens, then the books of the series in view, which set
// their formats, count (a book with an ebook and audiobook counting once) and cover
// versions. What the books showed is saved, and shown until they're looked up again.
// Offline, the series are the downloaded books'.
//
// The page itself (spinner, errors, rail) is tested in components/tst_grouplistpage.qml. The
// sorting, sections and errors the client gives every group list are tested here, once.
AppTestCase {
    name: "Series"

    readonly property string series: "/api/v1/series"
    // Every library's, as Series and Authors list them all to start with
    readonly property string books: "/api/v1/books/query"

    function serveSeries() {
        fakeServer.respond("GET", series, 200, "series/list.json")
        // Each series' books, found by series name
        fakeServer.respond("POST", books, 200, "series/books.json", {filter: {rules: [{field: "series"}]}})
        // A series' books in series order, for its books-of page
        fakeServer.respond("POST", books, 200, "series/dune-books.json", {sort: [{field: "seriesIndex"}]})
    }

    function openSeries(options) {
        openLibrary(undefined, undefined, options)
        serveSeries()
        bookRow("Dune")
        tap("SeriesTab")
        const page = find("seriesPage")
        verify(page.visible, "the Series view shows")
        return page
    }

    function rows() {
        return groupRows("seriesPage")
    }

    function row(name) {
        return groupRow("seriesPage", name)
    }

    function seriesRequests() {
        return fakeServer.requests.filter(r => r.method === "GET" && r.path === series).length
    }


    // Counts settle once each series' books are in
    function openLoadedSeries() {
        openSeries()
        tryVerify(() => rows() === "Dune (3), Hyperion Cantos (1), The Expanse (2)", 5000,
                  "A-Z, with counts from their books")
    }

    function test_listsTheSeriesByName() {
        openLoadedSeries()
    }

    // Children of Dune's ebook and audiobook are separate records but one book
    function test_rowShowsItsAuthorsAndFormats() {
        openLoadedSeries()

        const dune = row("Dune")
        compare(dune.group.bookCount, 3)
        compare(dune.group.authors, ["Frank Herbert"])
        compare(dune.group.formats, ["epub", "m4b"])
        compare(row("The Expanse").group.formats, ["epub", "m4b"])
        compare(row("Hyperion Cantos").group.formats, ["epub"])
    }

    function test_sortByBookCount() {
        openLoadedSeries()

        sortBy("seriesPage", "Book count")

        compare(rows(), "Dune (3), The Expanse (2), Hyperion Cantos (1)", "most first")
    }

    function test_sortByRecentlyAdded() {
        openLoadedSeries()

        sortBy("seriesPage", "Recently added")

        compare(rows(), "The Expanse (2), Dune (3), Hyperion Cantos (1)", "latest first")
    }

    // The share read, not how many: all of Hyperion Cantos's one book before two of Dune's
    // four
    function test_sortByReadProgress() {
        openLoadedSeries()

        sortBy("seriesPage", "Read progress")

        compare(rows(), "Hyperion Cantos (1), Dune (3), The Expanse (2)", "most read first")
    }

    // A-Z sections for the name sort only
    function test_jumpRailSectionsByName() {
        openLoadedSeries()
        const rail = find("jumpRail", find("seriesPage"))
        compare(rail.sections.map(s => s.label).join(""), "DHT")

        sortBy("seriesPage", "Book count")

        compare(rail.sections.length, 0, "none by book count")
    }

    function test_tappingASeriesListsItsBooksInOrder() {
        openLoadedSeries()

        mouseClick(row("Dune"))

        const page = find("booksOfPage")
        verify(page.visible, "the series' books show")
        compare(page.kind, "Series")
        compare(page.name, "Dune")
        tryVerify(() => page.list.count > 0 && page.list.itemAtIndex(0)
                        && page.list.itemAtIndex(0).book.title === "Dune", 5000, "Dune first")
        // From the server's only library, which has A-Z sections
        verify(fakeServer.requests.some(r => r.path === "/api/v1/libraries/1/books" && r.body.sort
                                             && r.body.sort[0].field === "seriesIndex"
                                             && JSON.stringify(r.body.filter).indexOf("\"Dune\"") >= 0),
               "asked for in series order")
    }

    // Each time the tab opens, the list and the books of the series in view are asked for
    // again
    function test_reloadedEachTimeTheTabOpens() {
        openLoadedSeries()
        compare(seriesRequests(), 1)
        const lookups = lookedUp("series").length

        tap("LibraryTab")
        tap("SeriesTab")

        tryVerify(() => seriesRequests() === 2, 5000, "the list is asked for again")
        tryVerify(() => lookedUp("series").length > lookups, 5000, "and the series in view looked up again")
        compare(rows(), "Dune (3), Hyperion Cantos (1), The Expanse (2)")
    }

    // The list has no cover versions: they come with the books, so a changed cover is fetched
    function test_coversGetVersionsFromTheirBooks() {
        openLoadedSeries()

        compare(row("Dune").group.covers[0].coverVersion, "v1")
        compare(row("The Expanse").group.covers[0].coverVersion, "v10")
    }

    // Only the series on screen, and a screen either side, have their books looked up. Every
    // group list shares this, so it's tested here; collections, looked up their own way,
    // have a test of their own.
    function test_onlySeriesInViewAreLookedUp() {
        openLibrary()
        fakeServer.respondJson("GET", series, 200, {total: 60, items: Array.from({length: 60}, (_, i) => ({
            id: 101 + i, name: "Series " + String(i + 1).padStart(2, "0"), bookCount: 2, readCount: 0,
            authors: [], coverBookIds: [], lastAddedAt: "2026-01-01 10:00:00+00"
        }))})
        fakeServer.respond("POST", books, 200, "series/books.json", {filter: {rules: [{field: "series"}]}})
        bookRow("Dune")

        tap("SeriesTab")

        const list = find("seriesPage").list
        tryVerify(() => list.count === 60, 5000, "every series is listed")
        tryVerify(() => lookedUp("series").includes("Series 01"), 5000, "the first are looked up")
        wait(300)
        verify(!lookedUp("series").includes("Series 60"), "not the last: " + lookedUp("series"))

        list.positionViewAtEnd()

        tryVerify(() => lookedUp("series").includes("Series 60"), 5000, "the last once scrolled to")
    }

    // At the next start, what the series' books showed is there before they're looked up,
    // and stays if they can't be
    function test_startShowsTheSavedDetails() {
        openLoadedSeries()
        fakeServer.respond("POST", books, 500, "server-error.json", {filter: {rules: [{field: "series"}]}})
        const lookups = lookedUp("series").length

        reopen()
        tap("SeriesTab")

        tryVerify(() => seriesRequests() === 2, 5000, "the list is asked for again")
        tryVerify(() => lookedUp("series").length > lookups, 5000, "the books are asked for, and fail")
        wait(300)
        compare(rows(), "Dune (3), Hyperion Cantos (1), The Expanse (2)", "the saved counts")
        compare(row("Dune").group.formats, ["epub", "m4b"])
        compare(row("Dune").group.covers[0].coverVersion, "v1")
    }

    // Details saved for a series that has gone are deleted, so they can't show if it comes
    // back with its books unknown
    function test_goneSeriesForgetTheirDetails() {
        openLoadedSeries()
        fakeServer.respond("GET", series, 200, "series/none.json")
        tap("LibraryTab")
        tap("SeriesTab")
        tryVerify(() => find("emptyState", find("seriesPage")).visible, 5000, "the series have gone")
        fakeServer.respond("GET", series, 200, "series/list.json")
        fakeServer.respond("POST", books, 500, "server-error.json", {filter: {rules: [{field: "series"}]}})

        tap("LibraryTab")
        tap("SeriesTab")

        tryVerify(() => rows() === "Dune (4), Hyperion Cantos (1), The Expanse (2)", 5000,
                  "the list's counts, not the saved ones: " + rows())
    }

    // Filtered like the authors (see tst_authors.qml): only series with audiobooks,
    // counting just those
    function test_audiobooksFilter() {
        openLoadedSeries()

        showOnly("seriesPage", "Audiobooks")

        tryVerify(() => rows() === "Dune (1), The Expanse (1)", 5000, rows())
        compare(row("The Expanse").group.formats, ["m4b"])
    }

    function test_downloadedOnly() {
        openSeries({books: [{id: 1, title: "Dune", authors: ["Frank Herbert"], seriesName: "Dune",
                             seriesIndex: 1, formats: ["epub"], file: "Dune.epub"}]})
        tryVerify(() => rows() === "Dune (3), Hyperion Cantos (1), The Expanse (2)", 5000)

        setDownloadedOnly("seriesPage")

        tryVerify(() => rows() === "Dune (1)", 5000, "only the downloaded book's: " + rows())
    }

    function test_downloadedOnlyWithoutDownloadsSaysSo() {
        openLoadedSeries()

        setDownloadedOnly("seriesPage")

        const empty = find("emptyState", find("seriesPage"))
        tryVerify(() => empty.visible, 5000, "No series")
        compare(empty.title, "No series")
        compare(empty.text, "Turn off Downloaded only to see every series.")
    }

    function test_noSeriesSaysSo() {
        openLibrary()
        fakeServer.respond("GET", series, 200, "series/none.json")
        bookRow("Dune")

        tap("SeriesTab")

        const empty = find("emptyState", find("seriesPage"))
        tryVerify(() => empty.visible, 5000, "No series")
        compare(empty.title, "No series")
        compare(empty.text, "Series show here once books in the library belong to one.")
    }

    function test_serverErrorSaysSomethingWentWrong() {
        openLibrary()
        fakeServer.respond("GET", series, 500, "server-error.json")
        bookRow("Dune")

        tap("SeriesTab")

        const empty = find("emptyState", find("seriesPage"))
        tryVerify(() => empty.visible, 5000, "an error")
        compare(empty.title, "Something went wrong")
    }

    // Offline, the downloaded books' series, counting only those
    function test_offlineListsTheDownloadedBooksSeries() {
        open(savedSession, {offline: true, books: [
            {id: 1, title: "Dune", authors: ["Frank Herbert"], seriesName: "Dune", seriesIndex: 1,
             formats: ["epub"], file: "Dune.epub"},
            {id: 10, title: "Leviathan Wakes", authors: ["James S. A. Corey"], seriesName: "The Expanse",
             seriesIndex: 1, formats: ["m4b"], file: "Leviathan Wakes.m4b"},
            {id: 2, title: "Hyperion", authors: ["Dan Simmons"], formats: ["epub"], file: "Hyperion.epub"}]})
        bookRow("Dune")

        tap("SeriesTab")

        tryVerify(() => rows() === "Dune (1), The Expanse (1)", 5000, "only series of downloaded books: " + rows())
        compare(row("The Expanse").group.formats, ["m4b"])
        compare(fakeServer.requests.length, 0, "the server isn't asked")
    }

    // Back online, the server's series replace the downloaded books'
    function test_reconnectingShowsTheServersSeries() {
        open(savedSession, {offline: true, books: [
            {id: 1, title: "Dune", authors: ["Frank Herbert"], seriesName: "Dune", seriesIndex: 1,
             formats: ["epub"], file: "Dune.epub"}]})
        tap("SeriesTab")
        tryVerify(() => rows() === "Dune (1)", 5000, "the downloaded book's series")
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        serveLibrary()
        serveSeries()

        testApp.offline = false
        tap("menuButton")
        tap("reconnect")

        tryVerify(() => rows() === "Dune (3), Hyperion Cantos (1), The Expanse (2)", 5000,
                  "the server's series: " + rows())
    }

    function test_offlineWithoutDownloadsSaysSo() {
        open(savedSession, {offline: true})

        tap("SeriesTab")

        const empty = find("emptyState", find("seriesPage"))
        tryVerify(() => empty.visible, 5000, "No series")
        compare(empty.text, "You're currently offline, only series with downloaded books can be shown.")
    }

    // The last series show at the next start while the server answers
    function test_startShowsTheLastSeries() {
        openLoadedSeries()
        fakeServer.hold("GET", series)

        reopen()
        tap("SeriesTab")

        tryVerify(() => rows() === "Dune (3), Hyperion Cantos (1), The Expanse (2)", 5000,
                  "the saved rows: " + rows())
        verify(!find("spinner", find("seriesPage")).visible, "no spinner over them")
        fakeServer.release("GET", series)
    }
}
