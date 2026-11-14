import QtQuick
import "../helpers"

// The Collections tab. The server has Classics (Dune, and Project Hail Mary as an ebook and
// a separate audiobook), Space Opera (Hyperion), an empty Empty Shelf, and a podcast
// collection, which isn't shown. Each row's authors, formats and book count come from the
// collection's books, a book with an ebook and audiobook counting once. The list reloads
// each time the tab opens, and offline shows the collections with downloaded books.
//
// The page itself is tested in components/tst_groupspage.qml, and what every group list
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

    // The rows top to bottom, "name (count)"
    function rows() {
        const list = find("collectionsPage").list
        const shown = []
        for (let i = 0; i < list.count; i++) {
            const row = list.itemAtIndex(i)
            if (row && row.visible)
                shown.push(row.group.name + " (" + row.group.bookCount + ")")
        }
        return shown.join(", ")
    }

    function row(name) {
        const list = find("collectionsPage").list
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

    function collectionRequests() {
        return fakeServer.requests.filter(r => r.method === "GET" && r.path === collections).length
    }

    function test_listsTheCollectionsByName() {
        openCollections()

        tryVerify(() => rows() === "Classics (2), Empty Shelf (0), Space Opera (1)", 5000,
                  "book collections A-Z, not the podcasts: " + rows())
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

        tap("LibraryTab")
        tap("CollectionsTab")

        tryVerify(() => collectionRequests() === 2, 5000, "asked for again")
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
        verify(!find("spinner", find("collectionsPage")).visible, "no spinner over them")
        fakeServer.release("GET", collections)
    }
}
