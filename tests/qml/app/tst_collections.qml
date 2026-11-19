import QtQuick
import "../helpers"

// The Collections tab. The server has Classics (Dune, and Project Hail Mary as an ebook and
// a separate audiobook), Space Opera (Hyperion) and an empty Empty Shelf. Each row's
// authors, formats and book count come from the collection's books, a book with an ebook
// and audiobook counting once, looked up for the collections in view and saved until
// looked up again. The list reloads each time the tab opens, and offline shows the
// collections with downloaded books.
//
// The page itself is tested in components/tst_grouplistpage.qml, and what every group list
// shares in tst_series.qml.
AppTestCase {
    name: "Collections"

    readonly property string collections: "/api/v1/collections"
    readonly property var dune: ({id: 1, title: "Dune", authors: ["Frank Herbert"], formats: ["epub"]})

    function serveCollections() {
        fakeServer.respond("GET", collections, 200, "collections/list.json")
        fakeServer.respond("POST", collections + "/1/books/query", 200, "collections/1-books.json")
        fakeServer.respond("POST", collections + "/2/books/query", 200, "collections/2-books.json")
        fakeServer.respond("POST", collections + "/2/books/jump-buckets", 200, "collections/2-jump-buckets.json")
    }

    function openCollections(options) {
        serveCollections()
        openLibrary(undefined, undefined, options)
        bookRow("Dune")
        tap("CollectionsTab")
        const page = find("collectionsPage")
        verify(page.visible, "the Collections view shows")
        return page
    }

    function rows() {
        return groupRows("collectionsPage")
    }

    function row(name) {
        return groupRow("collectionsPage", name)
    }

    function collectionRequests() {
        return fakeServer.requests.filter(r => r.method === "GET" && r.path === collections).length
    }

    // Requests for a collection's books, by its id
    function bookRequests(id) {
        return fakeServer.requests.filter(r => r.path === collections + "/" + id + "/books/query").length
    }

    function test_listsTheCollectionsByName() {
        openCollections()

        tryVerify(() => rows() === "Classics (2), Empty Shelf (0), Space Opera (1)", 5000,
                  "the collections A-Z: " + rows())
    }

    // Project Hail Mary's ebook and audiobook are separate records but one book
    function test_rowShowsItsBooksAuthorsAndFormats() {
        openCollections()

        // Counted once its books are in, which replaces the row's data
        tryVerify(() => row("Classics").group.bookCount === 2, 5000, "two books")
        const classics = row("Classics")
        compare(classics.group.authors.slice().sort(), ["Andy Weir", "Frank Herbert"])
        compare(classics.group.formats, ["epub", "m4b"])
    }

    function test_tappingACollectionListsItsBooks() {
        openCollections()

        mouseClick(row("Classics"))

        const page = find("booksOfPage")
        verify(page.visible, "the collection's books show")
        compare(page.name, "Classics")
        compare(page.kind, "Collection")
        tryVerify(() => page.list.count > 0 && page.list.itemAtIndex(0)
                        && page.list.itemAtIndex(0).book.title === "Dune", 5000, "its books, A-Z")
        verify(fakeServer.requests.some(r => r.path === collections + "/2/books/query" && r.body.sort
                                             && r.body.sort[0].field === "title"),
               "asked for by title")
    }

    function test_noCollectionsSaysSo() {
        fakeServer.respond("GET", collections, 200, "collections/none.json")
        openLibrary()
        bookRow("Dune")

        tap("CollectionsTab")

        const empty = find("emptyState", find("collectionsPage"))
        tryVerify(() => empty.visible, 5000, "No collections")
        compare(empty.title, "No collections")
        compare(empty.text, "Collections you make in BookOrbit show here.")
    }

    function test_reloadedEachTimeTheTabOpens() {
        openCollections()
        tryVerify(() => rows() !== "", 5000)
        compare(collectionRequests(), 1)

        tryVerify(() => bookRequests(2) === 1, 5000, "Classics' books are looked up")

        tap("LibraryTab")
        tap("CollectionsTab")

        tryVerify(() => collectionRequests() === 2, 5000, "asked for again")
        tryVerify(() => bookRequests(2) === 2, 5000, "and the books of those in view")
    }

    // Only the collections on screen, and a screen either side, have their books looked up,
    // and an empty one not at all
    function test_onlyCollectionsInViewAreLookedUp() {
        // Shelf 01 to Shelf 40, with ids 101 to 140
        fakeServer.respondJson("GET", collections, 200, Array.from({length: 40}, (_, i) => ({
            id: 101 + i, name: "Shelf " + String(i + 1).padStart(2, "0"), displayOrder: i, bookCount: 1
        })))
        for (let id = 101; id <= 140; id++)
            fakeServer.respond("POST", collections + "/" + id + "/books/query", 200, "collections/1-books.json")
        openLibrary()
        bookRow("Dune")

        tap("CollectionsTab")

        const list = find("collectionsPage").list
        tryVerify(() => list.count === 40, 5000, "every collection is listed")
        tryVerify(() => bookRequests(101) === 1, 5000, "the first are looked up")
        wait(300)
        compare(bookRequests(140), 0, "not the last")

        list.positionViewAtEnd()

        tryVerify(() => bookRequests(140) === 1, 5000, "the last once scrolled to")
    }

    function test_emptyCollectionIsntLookedUp() {
        openCollections()
        tryVerify(() => rows() === "Classics (2), Empty Shelf (0), Space Opera (1)", 5000)

        compare(bookRequests(4), 0)
    }

    // At the next start, what the collections' books showed is there before they're looked
    // up, and stays if they can't be
    function test_startShowsTheSavedDetails() {
        openCollections()
        tryVerify(() => rows() === "Classics (2), Empty Shelf (0), Space Opera (1)", 5000)
        fakeServer.respond("POST", collections + "/2/books/query", 500, "server-error.json")
        const lookups = bookRequests(2)

        reopen()
        tap("CollectionsTab")

        tryVerify(() => bookRequests(2) > lookups, 5000, "the books are asked for, and fail")
        wait(300)
        compare(rows(), "Classics (2), Empty Shelf (0), Space Opera (1)", "the saved counts")
        compare(row("Classics").group.authors.slice().sort(), ["Andy Weir", "Frank Herbert"])
        compare(row("Classics").group.formats, ["epub", "m4b"])
        compare(row("Classics").group.covers.length, 1)
        compare(row("Classics").group.covers[0].coverVersion, "v1")
    }

    // Offline, from the collections saved when last online: only those with downloaded
    // books, counting only those
    function test_offlineListsCollectionsWithDownloads() {
        openCollections()
        tryVerify(() => rows() === "Classics (2), Empty Shelf (0), Space Opera (1)", 5000)

        reopen({offline: true, books: [Object.assign({}, dune, {file: "Dune.epub"})]})
        tap("CollectionsTab")

        tryVerify(() => rows() === "Classics (1)", 5000, "Classics, with Dune: " + rows())
        compare(row("Classics").group.formats, ["epub"])
        compare(collectionRequests(), 1, "the server isn't asked again")
    }

    // Back online, the server's collections replace the offline ones
    function test_reconnectingShowsTheServersCollections() {
        open(savedSession, {offline: true, books: [Object.assign({}, dune, {file: "Dune.epub"})]})
        tap("CollectionsTab")
        const empty = find("emptyState", find("collectionsPage"))
        tryVerify(() => empty.visible, 5000, "none saved yet")
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        serveLibrary()
        serveCollections()

        testApp.offline = false
        tap("menuButton")
        tap("reconnect")

        tryVerify(() => rows() === "Classics (2), Empty Shelf (0), Space Opera (1)", 5000,
                  "the server's collections: " + rows())
    }

    function test_offlineWithoutDownloadsSaysSo() {
        openCollections()
        tryVerify(() => rows() !== "", 5000)

        reopen({offline: true})
        tap("CollectionsTab")

        const empty = find("emptyState", find("collectionsPage"))
        tryVerify(() => empty.visible, 5000, "No collections")
        compare(empty.text, "You're currently offline, only collections containing downloaded books can be shown.")
    }

    // The last collections show at the next start while the server answers
    function test_startShowsTheLastCollections() {
        openCollections()
        tryVerify(() => rows() === "Classics (2), Empty Shelf (0), Space Opera (1)", 5000)
        fakeServer.hold("GET", collections)

        reopen()
        tap("CollectionsTab")

        tryVerify(() => rows() === "Classics (2), Empty Shelf (0), Space Opera (1)", 5000,
                  "the saved rows: " + rows())
        compare(row("Classics").group.covers.length, 1, "the saved covers")
        compare(row("Classics").group.covers[0].coverVersion, "v1")
        verify(!find("spinner", find("collectionsPage")).visible, "no spinner over them")
        fakeServer.release("GET", collections)
    }
}
