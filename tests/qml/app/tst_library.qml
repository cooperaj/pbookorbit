import QtQuick
import "../helpers"

// The library list. The server has 30 books, five each under A, B, C, F, M and T.
AppTestCase {
    name: "Library"

    function openLibrary30(options) {
        openLibrary("libraries/books-30.json", "libraries/jump-buckets-30.json", options)
        tryCompare(find("bookList"), "count", 30)
    }

    // A-Z, the default sort, has the server's sections on the rail
    function test_titleSortShowsServerSections() {
        openLibrary30()

        const rail = find("libraryRail")
        tryVerify(() => rail.visible, 5000, "the rail shows")
        compare(rail.sections.map(s => s.label + s.index).join(" "), "A0 B5 C10 F15 M20 T25")
    }

    // Dates have no letter sections
    function test_dateSortHidesRail() {
        openLibrary30()
        tryVerify(() => find("libraryRail").visible, 5000, "the rail shows")

        tap("sortButton", find("bookList"))
        tap("Date added", find("sortMenu"))

        tryVerify(() => !find("libraryRail").visible, 5000, "the rail goes")
        const byDate = r => r.path === "/api/v1/libraries/1/books" && r.body.sort && r.body.sort[0].field === "addedAt"
        tryVerify(() => fakeServer.requests.some(byDate), 5000, "the library is asked for by date")
    }

    // The sections' labels and first rows, from the top to row last
    function sectionsTo(last) {
        const list = find("bookList")
        const starts = []
        for (let i = 0; i <= last; i++) {
            list.positionViewAtIndex(i, ListView.Contain)
            const row = list.itemAtIndex(i)
            verify(row, "row " + i)
            if (row.book.sectionStart)
                starts.push(row.book.sectionLabel + " " + i)
        }
        return starts.join(", ")
    }

    function firstLabel() {
        const row = find("bookList").itemAtIndex(0)
        return row ? row.book.sectionLabel : ""
    }

    function sortByRecentlyRead(jumpBuckets) {
        fakeServer.respond("POST", "/api/v1/libraries/1/books/jump-buckets", 200, jumpBuckets,
                           {sort: [{field: "lastReadAt"}]})
        openLibrary30()
        tap("sortButton", find("bookList"))
        tap("Recently read", find("sortMenu"))
        const byLastRead = r => r.path.endsWith("/jump-buckets") && r.body.sort[0].field === "lastReadAt"
        tryVerify(() => fakeServer.requests.some(byLastRead), 5000, "the server's date buckets")
    }

    // List entries have no last read date, so the server's buckets section them. Books
    // never read come last.
    function test_recentlyReadSectionsByDay() {
        sortByRecentlyRead("libraries/jump-buckets-read-days.json")

        tryVerify(() => firstLabel() === "2026/11/14", 5000, "sectioned by last read")
        compare(sectionsTo(8), "2026/11/14 0, 2026/11/02 3, Never 7")
        verify(!find("libraryRail").visible, "no rail for dates")
    }

    // Read over a longer time than 64 days, the server buckets by month
    function test_recentlyReadSectionsByMonth() {
        sortByRecentlyRead("libraries/jump-buckets-read-months.json")

        tryVerify(() => firstLabel() === "2026/11", 5000, "sectioned by last read")
        compare(sectionsTo(3), "2026/11 0, 2025/12 2")
    }

    // Offline, the downloaded books Tide, Acorn, Maple and Birch sorted by Recently read
    function sortDownloadedByRecentlyRead(options) {
        const books = ["Tide", "Acorn", "Maple", "Birch"].map((title, i) => ({
            id: i + 1, title: title, authors: ["A. Writer"], formats: ["epub"], file: title + ".epub"}))
        open(savedSession, Object.assign({offline: true, books: books}, options))
        tryCompare(find("bookList"), "count", 4)
        tap("sortButton", find("bookList"))
        tap("Recently read", find("sortMenu"))
    }

    function titles() {
        const list = find("bookList")
        const shown = []
        for (let i = 0; i < list.count; i++) {
            list.positionViewAtIndex(i, ListView.Contain)
            shown.push(list.itemAtIndex(i).book.title)
        }
        return shown.join(", ")
    }

    // BookOrbit has no last read date per book, so downloaded books go by when the system's
    // reader last opened them, from its library on firmware it was checked on. Books never
    // opened come last, by title.
    function test_recentlyReadDownloadedByLastOpened() {
        sortDownloadedByRecentlyRead({firmware: "U700k3.6.10.2359",
                                      opened: {"Maple.epub": "2026-11-02T12:00:00Z",
                                               "Tide.epub": "2026-11-14T12:00:00Z"}})

        tryVerify(() => titles() === "Tide, Maple, Acorn, Birch", 5000, "newest first: " + titles())
        compare(sectionsTo(3), "2026/11/14 0, 2026/11/02 1, Never 2")
    }

    // Audiobooks go by when the system's player last played them, among the ebooks
    function test_recentlyReadDownloadedAudiobooksByLastPlayed() {
        const books = [{id: 1, title: "Tide", authors: ["A. Writer"], formats: ["epub"], file: "Tide.epub"},
                       {id: 2, title: "Ascension", authors: ["A. Writer"], formats: ["m4b"], file: "Ascension.m4b"},
                       {id: 3, title: "Maple", authors: ["A. Writer"], formats: ["epub"], file: "Maple.epub"}]
        open(savedSession, {offline: true, books: books, firmware: "U700k3.6.10.2359",
                            opened: {"Maple.epub": "2026-11-02T12:00:00Z",
                                     "Ascension.m4b": "2026-11-10T12:00:00Z",
                                     "Tide.epub": "2026-11-14T12:00:00Z"}})
        tryCompare(find("bookList"), "count", 3)
        tap("sortButton", find("bookList"))
        tap("Recently read", find("sortMenu"))

        tryVerify(() => titles() === "Tide, Ascension, Maple", 5000, "newest first: " + titles())
        compare(sectionsTo(2), "2026/11/14 0, 2026/11/10 1, 2026/11/02 2")
    }

    // Without the system's library, or on firmware it wasn't checked on, by title, unsectioned
    function test_recentlyReadDownloadedByTitleWithoutTheSystemLibrary() {
        sortDownloadedByRecentlyRead()

        tryVerify(() => titles() === "Acorn, Birch, Maple, Tide", 5000, "by title: " + titles())
        compare(sectionsTo(3), "", "no sections")
    }

    function test_recentlyReadDownloadedByTitleOnOtherFirmware() {
        sortDownloadedByRecentlyRead({firmware: "U700k3.6.11.100",
                                      opened: {"Tide.epub": "2026-11-14T12:00:00Z"}})

        tryVerify(() => titles() === "Acorn, Birch, Maple, Tide", 5000, "by title: " + titles())
        compare(sectionsTo(3), "", "no sections")
    }

    // Offline the sections come from the downloaded books, not the server
    function test_offlineRailFromDownloadedBooks() {
        const books = []
        const titles = ["Acorn", "Atlas", "Beacon", "Birch", "Bramble", "Maple", "Mirror",
                        "Moth", "Thistle", "Tide", "Torch", "Tundra"]
        for (let i = 0; i < titles.length; i++)
            books.push({id: i + 1, title: titles[i], authors: ["A. Writer"], formats: ["epub"],
                        file: titles[i] + ".epub"})
        open(savedSession, {offline: true, books: books})

        const rail = find("libraryRail")
        tryVerify(() => rail.visible, 5000, "the rail shows")
        compare(rail.sections.map(s => s.label + s.index).join(" "), "A0 B2 M5 T8")
    }

    // An empty library says so, once the server has answered
    function test_noBooksSaysSo() {
        fakeServer.hold("POST", "/api/v1/libraries/1/books")
        openLibrary("libraries/search-none.json", "libraries/jump-buckets.json")
        const empty = find("libraryEmptyState")
        tryVerify(() => fakeServer.requests.some(r => r.path === "/api/v1/libraries/1/books"), 5000)
        verify(!empty.visible, "not while the server answers")

        fakeServer.release("POST", "/api/v1/libraries/1/books")

        tryVerify(() => empty.visible, 5000, "No books")
        compare(empty.title, "No books")
        compare(empty.text, "Books in your BookOrbit library show here.")
    }

    function test_noBooksOfTheTypeSaysSo() {
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/search-none.json",
                           {filter: {rules: [{field: "format"}]}})
        openLibrary30()

        tap("filterButton", find("bookList"))
        tap("Ebooks", find("filterMenu"))

        const empty = find("libraryEmptyState")
        tryVerify(() => empty.visible, 5000, "No ebooks")
        compare(empty.title, "No ebooks")
    }
}
