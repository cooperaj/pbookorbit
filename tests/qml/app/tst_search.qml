import QtQuick
import "../helpers"

// Searching from the header's search button. The library has Dune and Dune Messiah, by
// Frank Herbert in the Dune series, and Hyperion, by Dan Simmons. Online the server
// searches, from three characters; offline the downloaded books are searched. Searches are
// saved as recent searches when typing ends, but not when going back.
AppTestCase {
    name: "Search"

    readonly property var dune: ({id: 1, title: "Dune", authors: ["Frank Herbert"], seriesName: "Dune",
                                  formats: ["epub"]})
    readonly property var duneMessiah: ({id: 6, title: "Dune Messiah", authors: ["Frank Herbert"],
                                         seriesName: "Dune", formats: ["epub"]})
    readonly property var hyperion: ({id: 2, title: "Hyperion", authors: ["Dan Simmons"], formats: ["epub"]})

    function onDevice(book, file) {
        return Object.assign({}, book, {file: file})
    }

    function openSearchLibrary(settings, options) {
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/search-dune.json", {q: "dune"})
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/search-none.json", {q: "zzz"})
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        serveLibrary("libraries/menu.json", "libraries/menu-jump-buckets.json")
        open(Object.assign({}, savedSession, settings || {}), options)
        bookRow("Dune")
    }

    // Opens the search page, and returns it
    function openSearch() {
        tap("searchButton")
        const page = find("searchPage")
        verify(page.visible, "the search page shows")
        return page
    }

    function searchFor(text) {
        type("searchField", text)
    }

    function searches() {
        return fakeServer.requests.filter(r => r.body && r.body.q !== undefined).map(r => r.body.q)
    }

    // The results' titles, top to bottom
    function results() {
        const list = find("searchResults")
        const titles = []
        for (let i = 0; i < list.count; i++) {
            const row = list.itemAtIndex(i)
            if (row && row.visible && row.book.title)
                titles.push(row.book.title)
        }
        return titles.join(", ")
    }

    function resultRow(title) {
        const list = find("searchResults")
        let found = null
        tryVerify(() => {
            for (let i = 0; i < list.count; i++) {
                const row = list.itemAtIndex(i)
                if (row && row.visible && row.book.title === title)
                    found = row
            }
            return found !== null
        }, 5000, "a result for " + title)
        return found
    }

    // A recent search's row, once the list has made it
    function recent(text) {
        let row = null
        tryVerify(() => (row = findChild(find("recentSearches"), "recent " + text)) !== null, 5000,
                  "a row for " + text + " in " + JSON.stringify(bookOrbit.recentSearches))
        return row
    }

    function test_searchButtonOpensTheSearchPage() {
        openSearchLibrary()

        openSearch()

        verify(find("searchField").activeFocus, "ready to type")
        verify(find("recentSearches").visible, "the recent searches show")
    }

    function test_typingSearchesTheServer() {
        openSearchLibrary()
        openSearch()

        searchFor("dune")

        tryVerify(() => results() === "Dune, Dune Messiah", 5000, "the server's matches")
        compare(searches(), ["dune"], "one search, once typing pauses")
    }

    function test_underThreeCharactersDoesntSearch() {
        openSearchLibrary()
        openSearch()

        searchFor("du")
        wait(600)

        compare(searches(), [], "not searched")
        verify(find("recentSearches").visible, "still the recent searches")
        verify(!find("searchResults").visible)
    }

    function test_noMatchesSaysSo() {
        openSearchLibrary()
        openSearch()

        searchFor("zzz")

        const empty = find("noBooksFound")
        tryVerify(() => empty.visible, 5000, "No books found")
        compare(empty.text, "Try a different title, author or series.")
    }

    function test_clearingReturnsToRecentSearches() {
        openSearchLibrary({recentSearches: '["hyperion"]'})
        openSearch()
        searchFor("dune")
        tryVerify(() => results() !== "", 5000)

        tap("clearButton")

        compare(find("searchField").text, "")
        verify(find("recentSearches").visible, "the recent searches are back")
        verify(recent("hyperion").visible)
    }

    function test_enterSavesTheSearch() {
        openSearchLibrary({recentSearches: '["hyperion"]'})
        openSearch()
        searchFor("dune")

        keyClick(Qt.Key_Return)

        verify(!find("searchField").activeFocus, "typing ends")
        compare(bookOrbit.recentSearches, ["dune", "hyperion"], "newest first")
    }

    function test_goingBackDoesntSaveTheSearch() {
        openSearchLibrary()
        const page = openSearch()
        searchFor("dune")

        tap("backButton", page)

        verify(!page.visible, "back to the library")
        compare(bookOrbit.recentSearches, [])
    }

    // Searched again, it moves to the top rather than being listed twice
    function test_tappingARecentSearchSearchesAgain() {
        openSearchLibrary({recentSearches: '["hyperion", "dune"]'})
        openSearch()

        mouseClick(recent("dune"))

        compare(find("searchField").text, "dune")
        tryVerify(() => results() === "Dune, Dune Messiah", 5000, "its results")
        compare(bookOrbit.recentSearches, ["dune", "hyperion"])
    }

    function test_recentSearchesAreKept() {
        openSearchLibrary()
        openSearch()
        searchFor("dune")
        keyClick(Qt.Key_Return)

        // As though the app were started again
        const saved = {recentSearches: JSON.stringify(bookOrbit.recentSearches)}
        openSearchLibrary(saved)
        openSearch()

        verify(recent("dune").visible)
    }

    // A downloaded book opens; tapping it also saves the search
    function test_tappingADownloadedResultOpensIt() {
        openSearchLibrary({}, {books: [onDevice(duneMessiah, "Dune Messiah.epub")]})
        openSearch()
        searchFor("dune")

        mouseClick(resultRow("Dune Messiah"))

        compare(inkview.openedBooks.length, 1, "one book opened")
        verify(inkview.openedBooks[0].path.endsWith("/Books/Dune Messiah.epub"), "Dune Messiah")
        compare(bookOrbit.recentSearches, ["dune"])
    }

    function test_tappingAResultNotOnTheDeviceOffersToDownloadIt() {
        openSearchLibrary()
        openSearch()
        searchFor("dune")

        mouseClick(resultRow("Dune Messiah"))

        const dialog = find("downloadDialog")
        verify(dialog.visible, "the download dialog shows")
        compare(dialog.book.title, "Dune Messiah")
    }

    function test_holdingAResultOpensItsMenu() {
        openSearchLibrary()
        openSearch()
        searchFor("dune")
        const row = resultRow("Dune Messiah")
        const menu = find("bookMenu")

        mousePress(row)
        tryVerify(() => menu.visible, 3000, "the menu opens")
        mouseRelease(row)

        compare(menu.book.title, "Dune Messiah", "for that book")
    }

    // Offline, every word must be in the title, an author or a series, in any case
    function test_offlineSearchesDownloadedBooks() {
        open(savedSession, {offline: true, books: [onDevice(dune, "Dune.epub"),
                                                   onDevice(duneMessiah, "Dune Messiah.epub"),
                                                   onDevice(hyperion, "Hyperion.epub")]})
        bookRow("Dune")
        openSearch()

        searchFor("HERBERT messiah")

        tryVerify(() => results() === "Dune Messiah", 5000, "author and title words together")
        compare(fakeServer.requests.length, 0, "the server isn't asked")
    }

    function test_offlineSearchMatchesSeries() {
        open(savedSession, {offline: true, books: [onDevice(dune, "Dune.epub"),
                                                   onDevice(hyperion, "Hyperion.epub")]})
        bookRow("Dune")
        openSearch()

        searchFor("dune")

        tryVerify(() => results() === "Dune", 5000)
    }

    function test_offlineNoMatchesSaysOnlyDownloadedBooks() {
        open(savedSession, {offline: true, books: [onDevice(hyperion, "Hyperion.epub")]})
        bookRow("Hyperion")
        openSearch()

        searchFor("dune")

        const empty = find("noBooksFound")
        tryVerify(() => empty.visible, 5000, "No books found")
        compare(empty.text, "You're currently offline, only downloaded books can be searched.")
    }
}
