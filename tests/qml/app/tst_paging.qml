import QtQuick
import "../helpers"

// A long library, loaded a page of 40 at a time as it's scrolled. The server has 100 books,
// "A Book 1" to "Y Book 4", four to a letter. The list is as long as the library from the
// first page, with blank rows until their page loads. The page-turn keys page whichever
// list or info page is in front, like its page buttons.
AppTestCase {
    name: "Paging"

    readonly property string books: "/api/v1/libraries/1/books"

    function openLongLibrary() {
        fakeServer.respond("POST", books, 200, "libraries/books-100-page1.json", {pagination: {page: 1}})
        fakeServer.respond("POST", books, 200, "libraries/books-100-page2.json", {pagination: {page: 2}})
        openLibrary("libraries/books-100-page0.json", "libraries/jump-buckets-100.json")
        bookRow("A Book 1")
    }

    // The library's pages asked for, in order. Not the lookups for each page's other
    // versions (an ebook's audiobook), which filter by title.
    function pagesAsked() {
        return fakeServer.requests.filter(r => r.path === books && r.body.pagination && !r.body.filter)
                                  .map(r => r.body.pagination.page)
    }

    // The titles of the rows on screen, "" for one still loading
    function titlesShown() {
        const list = find("bookList")
        const titles = []
        for (let i = 0; i < list.count; i++) {
            const row = list.itemAtIndex(i)
            if (row && row.visible && row.y + row.height > list.contentY && row.y < list.contentY + list.height)
                titles.push(row.book.loaded ? row.book.title : "")
        }
        return titles
    }

    function firstTitleShown() {
        return titlesShown()[0]
    }

    function test_firstPageShowsTheWholeLength() {
        openLongLibrary()

        const list = find("bookList")
        compare(list.count, 100, "a row for every book")
        wait(500)
        compare(pagesAsked(), [0], "only the first page")
    }

    function test_pagingDownLoadsTheNextPage() {
        openLongLibrary()
        const list = find("bookList")

        // Until the rows of the second page come near
        for (let i = 0; i < 10 && pagesAsked().indexOf(1) < 0; i++) {
            tap("pageDown", list.parent)
            wait(300)
        }

        tryCompare(pagesAsked(), "length", 2)
        compare(pagesAsked(), [0, 1], "the second page")
        // Into the second page's rows, K to T
        for (let i = 0; i < 3; i++)
            tap("pageDown", list.parent)
        tryVerify(() => titlesShown().length > 0 && titlesShown().every(t => /^[K-T] /.test(t)), 5000,
                  "its rows fill in: " + JSON.stringify(titlesShown()))
    }

    // A jump far down loads the page there, not the ones in between
    function test_jumpingLoadsJustThatPage() {
        openLongLibrary()
        const rail = find("libraryRail")
        tryVerify(() => rail.visible, 5000, "the rail shows")

        const y = rail.entries.findIndex(entry => entry.label === "Y")
        mouseClick(rail, rail.width / 2, rail.entriesTop + (y + 0.5) * rail.pitch)

        tryVerify(() => firstTitleShown() === "Y Book 1" || titlesShown().indexOf("Y Book 1") >= 0, 5000,
                  "the Ys show")
        verify(pagesAsked().indexOf(2) >= 0, "the last page")
        verify(pagesAsked().indexOf(1) < 0, "not the one before it")
    }

    function test_pageKeysPageTheLibrary() {
        openLongLibrary()
        const list = find("bookList")
        const top = list.contentY

        keyClick(Qt.Key_PageDown)
        verify(list.contentY > top, "down a page")
        const first = firstTitleShown()

        keyClick(Qt.Key_PageDown)
        verify(firstTitleShown() !== first, "and another")

        keyClick(Qt.Key_PageUp)
        compare(firstTitleShown(), first, "back up")
    }

    // With a menu open a key would page the list behind it
    function test_pageKeysWaitForAMenuToClose() {
        openLongLibrary()
        const list = find("bookList")
        const menu = find("bookMenu")
        menu.open(bookRow("A Book 2"))
        menu.show()
        const top = list.contentY

        keyClick(Qt.Key_PageDown)

        compare(list.contentY, top, "not paged")
        verify(menu.visible, "the menu stays")
    }

    // Over the library, the search results are paged and the library stays put
    function test_pageKeysPageTheSearchResults() {
        fakeServer.respond("POST", books, 200, "libraries/books-100-page0.json", {q: "book"})
        openLongLibrary()
        const list = find("bookList")
        const top = list.contentY
        tap("searchButton")
        type("searchField", "book")
        const results = find("searchResults")
        tryVerify(() => results.visible && results.count === 100, 5000, "the results")
        keyClick(Qt.Key_Return)

        keyClick(Qt.Key_PageDown)

        verify(results.contentY > 0, "the results page down")
        compare(list.contentY, top, "the library doesn't")
    }
}
