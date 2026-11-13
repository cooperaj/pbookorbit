import QtQuick
import "../helpers"

// The library list. The server has 30 books, five each under A, B, C, F, M and T.
AppTestCase {
    name: "Library"

    function openLibrary30(options) {
        openLibrary("libraries/books-30.json", "libraries/jump-buckets-30.json", options)
        tryCompare(find("bookList"), "count", 30)
    }

    function firstTitleShown() {
        const list = find("bookList")
        const row = list.itemAtIndex(list.indexAt(list.width / 2, list.contentY + 1))
        return row ? row.book.title : ""
    }

    // A-Z, the default sort, has the server's sections on the rail
    function test_titleSortShowsServerSections() {
        openLibrary30()

        const rail = find("libraryRail")
        tryVerify(() => rail.visible, 5000, "the rail shows")
        compare(rail.sections.map(s => s.label + s.index).join(" "), "A0 B5 C10 F15 M20 T25")
    }

    function test_railJumpsInTheLibrary() {
        openLibrary30()
        const rail = find("libraryRail")
        tryVerify(() => rail.visible, 5000, "the rail shows")

        const m = rail.entries.findIndex(entry => entry.label === "M")
        mouseClick(rail, rail.width / 2, rail.entriesTop + (m + 0.5) * rail.pitch)

        tryVerify(() => firstTitleShown() === "Maple", 5000, "Maple, the first M, is at the top")
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
}
