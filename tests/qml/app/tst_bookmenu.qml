import QtQuick
import "../helpers"

// The menu a book's row opens when held, and finding out about the book from it. The server
// has Dune and Dune Messiah, both by Frank Herbert in the Dune series, and Hyperion, by Dan
// Simmons and in no series. Delete and Open with are tested with deleting, getting and
// reading books.
AppTestCase {
    name: "BookMenu"

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
}
