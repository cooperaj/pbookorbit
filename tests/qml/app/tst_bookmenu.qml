import QtQuick
import "../helpers"

// The menu a book's row opens when held. The server has Dune and Dune Messiah, both by Frank
// Herbert in the Dune series, and Hyperion, by Dan Simmons and in no series. Each test
// checks what an item does, and the conditional items that they're hidden when they should
// be.
AppTestCase {
    name: "BookMenu"

    // Two apps on the device can open an epub
    readonly property var epubApps: ({epub: [{app: "koreader.app", name: "KOReader"},
                                             {app: "eink-reader.app", name: "PB Reader"}]})
    readonly property var duneOnDevice: [{id: 1, title: "Dune", authors: ["Frank Herbert"],
                                          formats: ["epub"], file: "Dune.epub"}]

    function openMenuLibrary(options) {
        // An author's or series' books are the library's, filtered by that name
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/menu-dune-books.json",
                           {filter: {rules: [{field: "author", value: ["Frank Herbert"]}]}})
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/menu-dune-books.json",
                           {filter: {rules: [{field: "series", value: ["Dune"]}]}})
        openLibrary("libraries/menu.json", "libraries/menu-jump-buckets.json", options)
    }

    function test_holdingABookOpensItsMenu() {
        openMenuLibrary()
        const row = bookRow("Dune")
        const menu = find("bookMenu")

        mousePress(row)
        tryVerify(() => menu.visible, 3000, "the menu opens")
        mouseRelease(row)

        compare(menu.book.title, "Dune", "for that book")
    }

    function test_tappingOutsideClosesTheMenu() {
        openMenuLibrary()
        const menu = holdBook("Dune")

        mouseClick(menu, 20, menu.height - 20)

        verify(!menu.visible, "the menu closes")
    }

    function test_bookInfoOpensTheBooksPage() {
        openMenuLibrary()
        const menu = holdBook("Dune")

        tap("bookInfo", menu)

        verify(!menu.visible, "the menu closes")
        const info = find("bookInfoPage")
        verify(info.visible, "the info page shows")
        compare(info.book.title, "Dune")
    }

    function test_allBooksOfAuthor() {
        openMenuLibrary()
        const menu = holdBook("Dune")

        tap("authorBooks", menu)

        const page = find("booksOfPage")
        verify(page.visible, "the author's books show")
        compare(page.name, "Frank Herbert")
        tryVerify(() => titlesIn(page.list) === "Dune, Dune Messiah", 5000, "Frank Herbert's books")
    }

    function test_allBooksOfSeries() {
        openMenuLibrary()
        const menu = holdBook("Dune")

        tap("seriesBooks", menu)

        const page = find("booksOfPage")
        verify(page.visible, "the series' books show")
        compare(page.name, "Dune")
        tryVerify(() => titlesIn(page.list) === "Dune, Dune Messiah", 5000, "the Dune series")
    }

    function test_noSeriesItemOutsideASeries() {
        openMenuLibrary()

        const menu = holdBook("Hyperion")

        verify(!find("seriesBooks", menu).visible, "no All books of series")
    }

    // What happens next is tested with deleting
    function test_deleteAsksAboutThatBook() {
        openMenuLibrary({books: duneOnDevice})
        const menu = holdBook("Dune")

        tap("deleteBook", menu)

        verify(!menu.visible, "the menu closes")
        const dialog = find("deleteDialog")
        verify(dialog.visible, "the delete dialog shows")
        compare(dialog.book.title, "Dune")
    }

    function test_noDeleteForABookNotOnTheDevice() {
        openMenuLibrary()

        const menu = holdBook("Dune")

        verify(!find("deleteBook", menu).visible, "no Delete")
    }

    // Open with lists the apps for the book's format, and opens it in the one chosen
    function test_openWithADownloadedBook() {
        openMenuLibrary({books: duneOnDevice, apps: epubApps})
        const menu = holdBook("Dune")

        tap("openWith", menu)
        verify(find("KOReader", menu).visible, "the apps are listed")
        // The second, so it's the choice that counts and not the order
        tap("PB Reader", menu)

        verify(!menu.visible, "the menu closes")
        expectOpenedInReader("/Books/Dune.epub", "eink-reader.app")
    }

    // A book not on the device downloads first, then opens in the app chosen
    function test_openWithDownloadsFirst() {
        openMenuLibrary({apps: epubApps})
        fakeServer.respondFile("/api/v1/books/files/11/download", "files/book.epub", "Dune - Frank Herbert.epub")
        const menu = holdBook("Dune")
        tap("openWith", menu)

        tap("KOReader", menu)

        const dialog = find("downloadDialog")
        verify(dialog.visible, "the download dialog shows")
        compare(dialog.message, "Download EPUB, 1.9 MB to the Books folder and open it in KOReader?")
        tapText("Download", dialog)
        tryVerify(() => !dialog.visible, 5000, "downloaded")
        expectOpenedInReader("/Books/Dune - Frank Herbert.epub", "koreader.app")
    }

    function test_noOpenWithWithoutAnAppForTheFormat() {
        openMenuLibrary({books: duneOnDevice, apps: {pdf: [{app: "koreader.app", name: "KOReader"}]}})

        const menu = holdBook("Dune")

        verify(!find("openWith", menu).visible, "no Open with")
    }
}
