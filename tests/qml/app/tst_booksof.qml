import QtQuick
import "../helpers"

// A books-of page: an author's, series' or collection's books, opened here from a book's
// menu. The server has Dune and Dune Messiah, both by Frank Herbert in the Dune series, and
// Hyperion. An author's books are A-Z with letter sections, a series' in series order with
// number sections. Each kind keeps its own sort between uses.
//
// The list itself is tested in components/tst_booklistpage.qml, and a collection's books in
// tst_collections.qml.
AppTestCase {
    name: "BooksOf"

    readonly property string books: "/api/v1/libraries/1/books"
    readonly property var byFrankHerbert: ({filter: {rules: [{field: "author", value: ["Frank Herbert"]}]}})
    readonly property var inDune: ({filter: {rules: [{field: "series", value: ["Dune"]}]}})

    function openMenuLibrary(options) {
        fakeServer.respond("POST", books, 200, "libraries/menu-dune-books.json", byFrankHerbert)
        fakeServer.respond("POST", books + "/jump-buckets", 200, "libraries/menu-dune-jump-buckets.json",
                           byFrankHerbert)
        fakeServer.respond("POST", books, 200, "libraries/menu-dune-books.json", inDune)
        openLibrary("libraries/menu.json", "libraries/menu-jump-buckets.json", options)
    }

    // Opens the books of Dune's author or series ("authorBooks", "seriesBooks") from its
    // menu, and returns the page
    function openBooksOf(item) {
        tap(item, holdBook("Dune"))
        const page = find("booksOfPage")
        verify(page.visible, "the books show")
        return page
    }

    function asked(match) {
        return fakeServer.requests.filter(r => r.path === books && r.body.sort
                                               && (JSON.stringify(r.body.filter) || "").indexOf(match) >= 0)
    }

    function sortText(page) {
        return find("sortButton", page).text
    }

    function back(page) {
        tap("backButton", page)
        verify(!page.visible)
    }

    function test_authorsBooksAToZWithLetterSections() {
        openMenuLibrary()

        const page = openBooksOf("authorBooks")

        compare(page.kind, "Author")
        tryVerify(() => titlesIn(page.list) === "Dune, Dune Messiah", 5000)
        compare(asked("Frank Herbert")[0].body.sort[0].field, "title")
        compare(sortText(page), "By Title")
        const rail = find("jumpRail", page)
        compare(rail.sections.map(s => s.label).join(""), "D")
        verify(rail.alphabetical)
    }

    function test_seriesBooksInSeriesOrderWithNumberSections() {
        openMenuLibrary()

        const page = openBooksOf("seriesBooks")

        compare(page.kind, "Series")
        tryVerify(() => titlesIn(page.list) === "Dune, Dune Messiah", 5000)
        compare(asked("\"Dune\"")[0].body.sort[0].field, "seriesIndex")
        compare(sortText(page), "By Series order")
        const rail = find("jumpRail", page)
        tryVerify(() => rail.sections.map(s => s.label).join(" ") === "1 2", 5000, "numbered sections")
        verify(!rail.alphabetical)
    }

    function test_eachKindKeepsItsSort() {
        openMenuLibrary()
        let page = openBooksOf("authorBooks")
        tap("sortButton", page)
        tap("Author", find("sortMenu"))
        compare(sortText(page), "By Author")
        back(page)

        page = openBooksOf("seriesBooks")
        compare(sortText(page), "By Series order", "the series' own")
        back(page)

        page = openBooksOf("authorBooks")
        compare(sortText(page), "By Author", "the author's kept")
    }

    function test_backReturnsToTheLibrary() {
        openMenuLibrary()
        const page = openBooksOf("authorBooks")

        back(page)

        verify(find("bookList").visible, "the library")
    }

    function test_noBooksSaysSo() {
        openMenuLibrary()
        fakeServer.respond("POST", books, 200, "libraries/search-none.json", byFrankHerbert)

        const page = openBooksOf("authorBooks")

        const empty = find("emptyState", page)
        tryVerify(() => empty.visible, 5000, "No books found")
        compare(empty.title, "No books found")
        compare(empty.text, "")
    }

    function test_downloadedOnlyWithoutDownloadsSaysSo() {
        openMenuLibrary()
        const page = openBooksOf("authorBooks")
        tryVerify(() => titlesIn(page.list) !== "", 5000)

        tap("filterButton", page)
        tap("downloadedOnly", find("filterMenu"))

        const empty = find("emptyState", page)
        tryVerify(() => empty.visible, 5000, "No downloaded books")
        compare(empty.title, "No downloaded books")
        compare(empty.text, "Turn off Downloaded only to see them all.")
    }

    function test_serverErrorSaysSomethingWentWrong() {
        openMenuLibrary()
        fakeServer.respond("POST", books, 500, "server-error.json", byFrankHerbert)

        const page = openBooksOf("authorBooks")

        const empty = find("emptyState", page)
        tryVerify(() => empty.visible, 5000, "an error")
        compare(empty.title, "Something went wrong")
        compare(empty.text, "Internal server error (HTTP 500)")
    }

    // An error over the books already shown, as in the library
    function test_errorOverItsBooks() {
        openMenuLibrary()
        const page = openBooksOf("authorBooks")
        tryVerify(() => titlesIn(page.list) === "Dune, Dune Messiah", 5000)
        fakeServer.respond("POST", books, 500, "server-error.json", {sort: [{field: "author"}]})

        tap("sortButton", page)
        tap("Author", find("sortMenu"))

        const error = find("errorLine", page)
        tryVerify(() => error.visible, 5000, "the error shows")
        compare(error.text, "Internal server error (HTTP 500)")
        compare(titlesIn(page.list), "Dune, Dune Messiah", "over the books")
    }

    // Each list has its own error, cleared when it loads again. Tested here for them all.
    function test_errorGoesWhenItLoadsAgain() {
        openMenuLibrary()
        const page = openBooksOf("authorBooks")
        tryVerify(() => titlesIn(page.list) === "Dune, Dune Messiah", 5000)
        fakeServer.respond("POST", books, 500, "server-error.json", {sort: [{field: "author"}]})
        tap("sortButton", page)
        tap("Author", find("sortMenu"))
        const error = find("errorLine", page)
        tryVerify(() => error.visible, 5000, "the error shows")

        tap("sortButton", page)
        tap("Title", find("sortMenu"))

        tryVerify(() => !error.visible, 5000, "gone once the books load")
    }

    function test_errorStaysOnItsOwnList() {
        fakeServer.respond("GET", "/api/v1/collections", 200, "collections/none.json")
        fakeServer.respond("POST", books, 500, "server-error.json", byFrankHerbert)
        openLibrary("libraries/menu.json", "libraries/menu-jump-buckets.json")
        const page = openBooksOf("authorBooks")
        tryVerify(() => find("emptyState", page).visible, 5000, "the books-of page fails")

        tap("backButton", page)

        verify(!find("errorLine", find("libraryPage")).visible, "not over the library's books")
        tap("CollectionsTab")
        const empty = find("emptyState", find("collectionsPage"))
        tryVerify(() => empty.visible, 5000, "No collections")
        compare(empty.title, "No collections")
    }

    // Offline, the downloaded ones, without asking the server
    function test_offlineListsTheDownloadedBooks() {
        open(savedSession, {offline: true, books: [
            {id: 1, title: "Dune", authors: ["Frank Herbert"], seriesName: "Dune", formats: ["epub"], file: "Dune.epub"}]})

        const page = openBooksOf("authorBooks")

        tryVerify(() => titlesIn(page.list) === "Dune", 5000, "only Dune: " + titlesIn(page.list))
        compare(fakeServer.requests.length, 0)
    }
}
