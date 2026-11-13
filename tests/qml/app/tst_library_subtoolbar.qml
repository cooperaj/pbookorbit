import QtQuick
import "../helpers"

// The library's sub-toolbar: the content type and downloaded-only filter, and the sort.
// The server has Dune and Neuromancer as ebooks and The Martian as an audiobook, and
// answers each query with the books it would list for it.
AppTestCase {
    name: "LibrarySubToolbar"

    function openMixedLibrary(options) {
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/mixed-ebooks.json",
                           {filter: {rules: [{field: "format", value: ["epub"]}]}})
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/mixed-audiobooks.json",
                           {filter: {rules: [{field: "format", value: ["m4b"]}]}})
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/mixed-by-author.json",
                           {sort: [{field: "author"}]})
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/mixed-reversed.json",
                           {sort: [{field: "title", dir: "desc"}]})
        openLibrary("libraries/mixed.json", "libraries/mixed-jump-buckets.json", options)
    }

    // The titles listed, top to bottom
    function titles() {
        const list = find("bookList")
        const shown = []
        for (let i = 0; i < list.count; i++) {
            const row = list.itemAtIndex(i)
            if (row && row.visible)
                shown.push(row.book.title)
        }
        return shown.join(", ")
    }

    function chooseFilter(option) {
        tap("filterButton", find("bookList"))
        tap(option, find("filterMenu"))
    }

    function chooseSort(option) {
        tap("sortButton", find("bookList"))
        tap(option, find("sortMenu"))
    }

    function test_audiobooksFilterListsOnlyAudiobooks() {
        openMixedLibrary()
        tryVerify(() => titles() === "Dune, Neuromancer, The Martian", 5000, "the whole library")

        chooseFilter("Audiobooks")

        tryVerify(() => titles() === "The Martian", 5000, "only The Martian")
        compare(find("filterButton", find("bookList")).text, "Audiobooks")
    }

    function test_ebooksFilterListsOnlyEbooks() {
        openMixedLibrary()
        tryVerify(() => titles() === "Dune, Neuromancer, The Martian", 5000, "the whole library")

        chooseFilter("Ebooks")

        tryVerify(() => titles() === "Dune, Neuromancer", 5000, "only the ebooks")
        compare(find("filterButton", find("bookList")).text, "Ebooks")
    }

    function test_sortByAuthor() {
        openMixedLibrary()
        tryVerify(() => titles() === "Dune, Neuromancer, The Martian", 5000, "by title first")

        chooseSort("Author")

        tryVerify(() => titles() === "Neuromancer, Dune, The Martian", 5000, "Gibson, Herbert, Weir")
        compare(find("sortButton", find("bookList")).text, "By Author")
    }

    // The icon beside the sort flips its direction, and the rail with it
    function test_sortIconReversesTheOrder() {
        openMixedLibrary()
        tryVerify(() => titles() === "Dune, Neuromancer, The Martian", 5000, "A to Z first")

        tap("iconButton", find("sortButton", find("bookList")))

        tryVerify(() => titles() === "The Martian, Neuromancer, Dune", 5000, "Z to A")
        verify(find("libraryRail").descending, "the rail runs Z to A")
    }

    function test_downloadedOnlyListsJustDownloads() {
        openMixedLibrary({books: [{id: 1, title: "Dune", authors: ["Frank Herbert"], formats: ["epub"],
                                   file: "Dune.epub"}]})
        tryVerify(() => titles() === "Dune, Neuromancer, The Martian", 5000, "the whole library")

        tap("filterButton", find("bookList"))
        tap("downloadedOnly", find("filterMenu"))

        tryVerify(() => titles() === "Dune", 5000, "only Dune")
        verify(find("downloadedOnly", find("filterMenu")).checked, "the switch is on")
    }

    function test_noDownloadsSaysSo() {
        openMixedLibrary()
        tryVerify(() => titles() === "Dune, Neuromancer, The Martian", 5000, "the whole library")

        tap("filterButton", find("bookList"))
        tap("downloadedOnly", find("filterMenu"))

        const empty = find("libraryEmptyState")
        tryVerify(() => empty.visible, 5000, "the empty state shows")
        compare(empty.title, "No downloaded books")
        compare(empty.text, "Books you download show here, and can be read offline.")
    }

    // Offline only downloads can show, so the switch is on and can't be turned off. Back
    // online the user's own choice, off, returns.
    function test_offlineForcesDownloadedOnlyUntilOnline() {
        openMixedLibrary({offline: true})
        tap("filterButton", find("bookList"))
        const downloadedOnly = find("downloadedOnly", find("filterMenu"))
        verify(downloadedOnly.checked, "on offline")
        verify(!downloadedOnly.enabled, "and can't be changed")
        tap("filterButton", find("bookList"))

        testApp.offline = false
        tap("menuButton")
        tap("reconnect")

        tryVerify(() => titles() === "Dune, Neuromancer, The Martian", 5000, "the server's books are back")
        verify(!downloadedOnly.checked, "off again")
        verify(downloadedOnly.enabled, "and can be changed")
    }

    function test_serverErrorSaysSomethingWentWrong() {
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        serveLibrary("libraries/mixed.json", "libraries/mixed-jump-buckets.json")
        // After serveLibrary's, so it's the one that answers
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 500, "server-error.json")
        open(savedSession)

        const empty = find("libraryEmptyState")
        tryVerify(() => empty.visible, 5000, "the empty state shows")
        compare(empty.title, "Something went wrong")
        compare(empty.text, "Internal server error (HTTP 500)")
    }
}
