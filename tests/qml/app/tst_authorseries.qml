import QtQuick
import "../helpers"

// An author's series, opened from the Series cell of their info page. Dan Simmons has three
// series (Endymion, Hyperion Cantos, Ilium), Frank Herbert two (Dune, Pandora Sequence) and
// Ann Leckie one (Imperial Radch). The server finds series by any author whose name contains
// the one asked for, so Dan Simmons's include Dan Simmonsen's, which aren't shown. Each
// author's series load as they're opened, the last author's never showing meanwhile, and
// they keep the sort chosen for the last author. They aren't saved for the next start.
//
// The page itself is tested in components/tst_groupspage.qml, and what every group list
// shares in tst_series.qml.
AppTestCase {
    name: "AuthorSeries"

    readonly property string series: "/api/v1/series"
    readonly property string books: "/api/v1/libraries/1/books"
    readonly property string danSimmonsSeries: "Endymion (2), Hyperion Cantos (2), Ilium (1)"

    function openAuthors(options) {
        openLibrary(undefined, undefined, options)
        fakeServer.respond("GET", "/api/v1/authors", 200, "authorseries/authors.json")
        fakeServer.respond("GET", "/api/v1/authors/1", 200, "authorseries/frank-herbert.json")
        fakeServer.respond("GET", "/api/v1/authors/2", 200, "authorseries/dan-simmons.json")
        fakeServer.respond("GET", "/api/v1/authors/3", 200, "authorseries/ann-leckie.json")
        // Each author's or series' books
        fakeServer.respond("POST", books, 200, "authorseries/books.json", {filter: {rules: [{field: "author"}]}})
        fakeServer.respond("POST", books, 200, "authorseries/books.json", {filter: {rules: [{field: "series"}]}})
        bookRow("Dune")
        tap("AuthorsTab")
    }

    // Opens the author's info page from the Authors tab, once their series are counted
    function openAuthor(name) {
        const list = find("authorsPage").list
        let row = null
        tryVerify(() => {
            for (let i = 0; i < list.count; i++) {
                const item = list.itemAtIndex(i)
                if (item && item.visible && item.group.name === name && item.group.seriesCount > 0)
                    row = item
            }
            return row !== null
        }, 5000, name + " with their series counted")
        mouseClick(row)
        const info = find("authorInfoPage")
        verify(info.visible, "their info page")
        return info
    }

    // Taps the Series cell of the author's info page
    function openTheirSeries(name, fixture) {
        fakeServer.respond("GET", series, 200, fixture)
        tap("SeriesCell", openAuthor(name))
    }

    // The rows top to bottom, "name (count)"
    function rows() {
        const list = find("authorSeriesPage").list
        const shown = []
        for (let i = 0; i < list.count; i++) {
            const row = list.itemAtIndex(i)
            if (row && row.visible)
                shown.push(row.group.name + " (" + row.group.bookCount + ")")
        }
        return shown.join(", ")
    }

    function row(name) {
        const list = find("authorSeriesPage").list
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

    function seriesAskedFor() {
        return fakeServer.requests.filter(r => r.method === "GET" && r.path === series).map(r => r.query.author)
    }

    function back(under) {
        tap("backButton", under)
    }

    // Only Dan Simmons's: not Dan Simmonsen's, which the server includes
    function test_seriesCellListsTheirSeries() {
        openAuthors()

        openTheirSeries("Dan Simmons", "authorseries/dan-simmons-series.json")

        const view = find("authorSeriesView")
        verify(view.visible, "their series show")
        compare(view.name, "Dan Simmons")
        tryVerify(() => rows() === danSimmonsSeries, 5000, "theirs, A-Z: " + rows())
        compare(seriesAskedFor(), ["Dan Simmons"], "asked for by name")
    }

    function test_oneSeriesGoesStraightToItsBooks() {
        openAuthors()

        tap("SeriesCell", openAuthor("Ann Leckie"))

        const books = find("booksOfPage")
        verify(books.visible, "the series' books")
        compare(books.kind, "Series")
        compare(books.name, "Imperial Radch")
        verify(!find("authorSeriesView").visible, "not the list")
        compare(seriesAskedFor(), [], "nor asked for")
    }

    function test_tappingASeriesListsItsBooks() {
        openAuthors()
        openTheirSeries("Dan Simmons", "authorseries/dan-simmons-series.json")

        mouseClick(row("Ilium"))

        const books = find("booksOfPage")
        verify(books.visible)
        compare(books.kind, "Series")
        compare(books.name, "Ilium")
    }

    function test_backReturnsToTheAuthor() {
        openAuthors()
        openTheirSeries("Dan Simmons", "authorseries/dan-simmons-series.json")
        const view = find("authorSeriesView")
        tryVerify(() => rows() === danSimmonsSeries, 5000)

        back(view)

        verify(!view.visible, "the series close")
        verify(find("authorInfoPage").visible, "back to Dan Simmons")
        compare(find("authorInfoPage").author.name, "Dan Simmons")
    }

    // The next author's series load without the last author's showing meanwhile
    function test_anotherAuthorStartsEmpty() {
        openAuthors()
        openTheirSeries("Dan Simmons", "authorseries/dan-simmons-series.json")
        tryVerify(() => rows() === danSimmonsSeries, 5000)
        back(find("authorSeriesView"))
        back(find("authorInfoPage"))
        fakeServer.hold("GET", series)

        openTheirSeries("Frank Herbert", "authorseries/frank-herbert-series.json")

        compare(rows(), "", "not Dan Simmons's")
        verify(find("spinner", find("authorSeriesPage")).visible, "loading")
        fakeServer.release("GET", series)
        tryVerify(() => rows() === "Dune (2), Pandora Sequence (1)", 5000, "Frank Herbert's: " + rows())
        compare(seriesAskedFor(), ["Dan Simmons", "Frank Herbert"])
    }

    // The sort is kept from one author to the next
    function test_sortKeptBetweenAuthors() {
        openAuthors()
        openTheirSeries("Dan Simmons", "authorseries/dan-simmons-series.json")
        tryVerify(() => rows() === danSimmonsSeries, 5000)
        tap("sortButton", find("authorSeriesPage"))
        tap("Recently added", find("sortMenu"))
        compare(rows(), "Ilium (1), Endymion (2), Hyperion Cantos (2)", "latest first")
        back(find("authorSeriesView"))
        back(find("authorInfoPage"))

        openTheirSeries("Frank Herbert", "authorseries/frank-herbert-series.json")

        tryVerify(() => rows() === "Dune (2), Pandora Sequence (1)", 5000, "still latest first: " + rows())
        compare(find("sortButton", find("authorSeriesPage")).text, "By Recently added")
    }

    function test_noSeriesSaysSo() {
        openAuthors()

        openTheirSeries("Dan Simmons", "authorseries/none.json")

        const empty = find("emptyState", find("authorSeriesPage"))
        tryVerify(() => empty.visible, 5000, "No series")
        compare(empty.title, "No series")
        compare(empty.text, "None of their books are in a series.")
    }

    // Offline, the series of their downloaded books, without asking the server
    function test_offlineListsTheirDownloadedBooksSeries() {
        open(savedSession, {offline: true, books: [
            {id: 2, title: "Hyperion", authors: ["Dan Simmons"], seriesName: "Hyperion Cantos", seriesIndex: 1,
             formats: ["epub"], file: "Hyperion.epub"},
            {id: 7, title: "Ilium", authors: ["Dan Simmons"], seriesName: "Ilium", seriesIndex: 1,
             formats: ["epub"], file: "Ilium.epub"}]})
        tap("AuthorsTab")

        tap("SeriesCell", openAuthor("Dan Simmons"))

        tryVerify(() => rows() === "Hyperion Cantos (1), Ilium (1)", 5000, "their downloaded books': " + rows())
        compare(fakeServer.requests.length, 0, "the server isn't asked")
    }

    // The connection lost while their series load: their downloaded books' series instead.
    // (Reconnecting happens from the header menu, which this page covers.)
    function test_losingTheConnectionShowsTheirDownloadedBooksSeries() {
        openAuthors({books: [{id: 2, title: "Hyperion", authors: ["Dan Simmons"], seriesName: "Hyperion Cantos",
                              seriesIndex: 1, formats: ["epub"], file: "Hyperion.epub"}]})
        const info = openAuthor("Dan Simmons")
        // Their details are in, so asking for their series is what finds the server gone
        tryVerify(() => info.details.name === "Dan Simmons", 5000, "their details")
        fakeServer.reachable = false

        tap("SeriesCell", info)

        tryVerify(() => rows() === "Hyperion Cantos (1)", 5000, "the downloaded book's series: " + rows())
        verify(!bookOrbit.online, "offline")
    }
}
