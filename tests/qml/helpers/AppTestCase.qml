import QtQuick
import QtTest

// For tests of the whole app, main.qml, with its real objects behind it (see testApp in
// main.cpp) talking to fakeServer. main.qml is a Window, so it opens a window of its own
// beside the test's.
UiTestCase {
    id: test

    function init() {
        fakeServer.reset()
    }

    // A signed-in user of fakeServer, as saved from an earlier sign-in
    readonly property var savedSession: ({serverUrl: fakeServer.url, username: "reader",
                                          refreshToken: "saved-token"})

    // Every library's books, which Series, Authors and books-of lists ask for to start with
    readonly property string everyLibrary: "/api/v1/books/query"

    // The server's library: one page of books, and the A-Z sections for it
    function serveLibrary(books, jumpBuckets) {
        fakeServer.respond("GET", "/api/v1/libraries", 200, "libraries/list.json")
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, books || "libraries/books.json")
        fakeServer.respond("POST", "/api/v1/libraries/1/books/jump-buckets", 200,
                           jumpBuckets || "libraries/jump-buckets.json")
    }

    // Opens the app signed in, on the library, with the server answering for it
    function openLibrary(books, jumpBuckets, options) {
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        serveLibrary(books, jumpBuckets)
        open(savedSession, options)
    }

    readonly property string audiobookPlayer: "/ebrmain/bin/audio_books.app"

    // A list's row for a title, once it has loaded: the library's unless another list's name
    // is given, e.g. "searchResults"
    function bookRow(title, listName) {
        const list = find(listName || "bookList")
        let row = null
        tryVerify(() => {
            for (let i = 0; i < list.count; i++) {
                const item = list.itemAtIndex(i)
                if (item && item.visible && item.book.title === title) {
                    row = item
                    return true
                }
            }
            return false
        }, 5000, "a row for " + title)
        return row
    }

    // The titles of a list's rows made so far, top to bottom, "" for a row still loading:
    // "Dune, Dune Messiah"
    function titlesIn(list) {
        const titles = []
        for (let i = 0; i < list.count; i++) {
            const row = list.itemAtIndex(i)
            if (row && row.visible)
                titles.push(row.book.loaded === false ? "" : row.book.title)
        }
        return titles.join(", ")
    }

    // A group list's rows made so far (a page such as "seriesPage"), top to bottom, "name
    // (count)": "Dune (3), Hyperion Cantos (1)"
    function groupRows(pageName) {
        const list = find(pageName).list
        const shown = []
        for (let i = 0; i < list.count; i++) {
            const row = list.itemAtIndex(i)
            if (row && row.visible)
                shown.push(row.group.name + " (" + row.group.bookCount + ")")
        }
        return shown.join(", ")
    }

    // A group list's row for a name, once it has loaded
    function groupRow(pageName, name) {
        const list = find(pageName).list
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

    // The series or authors (field "series" or "author") whose books have been asked for,
    // in the order asked, in a library or in all of them
    function lookedUp(field) {
        return fakeServer.requests.filter(r => (r.path === "/api/v1/libraries/1/books" || r.path === everyLibrary)
                                               && r.body.filter
                                               && r.body.filter.rules[0].field === field)
                                  .reduce((names, r) => names.concat(Array.from(r.body.filter.rules[0].value)), [])
    }

    // Picks a sort from a list page's sort menu
    function sortBy(pageName, option) {
        tap("sortButton", find(pageName))
        tap(option, find("sortMenu"))
    }

    // Shows only "Ebooks" or "Audiobooks", by unticking the other
    function showOnly(pageName, option) {
        tap("filterButton", find(pageName))
        tap(option === "Ebooks" ? "Audiobooks" : "Ebooks", find("filterMenu"))
    }

    function setDownloadedOnly(pageName) {
        tap("filterButton", find(pageName))
        tap("downloadedOnly", find("filterMenu"))
        // The menu stays open for the switch
        tap("filterButton", find(pageName))
    }

    // Opens a book's menu as holding its row would, and returns it. A real hold takes over a
    // second, for the hold and then the frame on the row, so this skips the wait;
    // tst_bookmenu's test_holdingABookOpensItsMenu holds for real.
    function holdBook(title, listName) {
        const menu = find("bookMenu")
        menu.open(bookRow(title, listName))
        menu.show()
        verify(menu.visible, "the menu opens")
        return menu
    }

    // The formats in the book's row marked as on the device: "epub, m4b"
    function formatsOnDevice(title) {
        const row = bookRow(title)
        return row.formats.filter(format => find("onDevicePill", find("format " + format, row)).visible)
                          .join(", ")
    }

    // Waits for the book's row to mark those formats, "epub, m4b", as on the device
    function expectOnDevice(title, formats) {
        tryVerify(() => formatsOnDevice(title) === formats, 5000,
                  title + " has " + formats + " on the device, not " + formatsOnDevice(title))
    }

    function expectNotOnDevice(title) {
        expectOnDevice(title, "")
    }

    // Waits for the app to open something, then checks the one thing opened was the book at
    // a path ending with file, in the system's reader or the app given
    function expectOpenedInReader(file, app) {
        tryVerify(() => inkview.openedBooks.length + inkview.openedTasks.length > 0, 5000, "something opened")
        compare(inkview.openedBooks.length, 1, "one book opened")
        verify(inkview.openedBooks[0].path.endsWith(file), inkview.openedBooks[0].path + " is " + file)
        compare(inkview.openedBooks[0].app, app || "", app ? "in " + app : "in the system's reader")
        compare(inkview.openedTasks.length, 0, "no other app started")
    }

    // As expectOpenedInReader, for the audiobook player on a path ending with file
    function expectOpenedInPlayer(file) {
        tryVerify(() => inkview.openedBooks.length + inkview.openedTasks.length > 0, 5000, "something opened")
        compare(inkview.openedTasks.length, 1, "one app started")
        compare(inkview.openedTasks[0].app, audiobookPlayer, "the audiobook player")
        compare(inkview.openedTasks[0].args[0], "--bookPlay")
        verify(inkview.openedTasks[0].args[1].endsWith(file), inkview.openedTasks[0].args[1] + " is " + file)
        compare(inkview.openedBooks.length, 0, "no book opened in the reader")
    }

    // Closes the app and opens it again on the same database, as when the device starts it
    // again. options as for open(), which only apply to how it starts, e.g. {offline: true}.
    function reopen(options) {
        root.destroy()
        root = null
        wait(0)
        testApp.restart(options || {})
        load()
    }

    // Opens the app on a new database holding the given settings, with options for how it
    // starts (see TestApp::reset() in main.cpp), e.g. {offline: true, books: [...]}
    function open(settings, options) {
        testApp.reset(settings || {}, options || {})
        load()
    }

    // Loads main.qml and starts it, as main.cpp does
    function load() {
        const component = Qt.createComponent(Qt.resolvedUrl("../../../src/qml/main.qml"))
        compare(component.status, Component.Ready, component.errorString())
        root = createTemporaryObject(component, test)
        verify(root)
        // Keys go to the active window
        root.requestActivate()
        tryVerify(() => root.active)
        // Taps before the first frame miss, which shows when a test is the first to open
        // the app
        waitForRendering(root.contentItem)
        // As main.cpp does once the first frame is drawn. A saved session then asks the
        // server for the library.
        bookOrbit.start()
    }
}
