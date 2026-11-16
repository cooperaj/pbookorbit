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

    // Waits for the book's row to be marked as on the device, or not
    function expectOnDevice(title) {
        tryVerify(() => find("onDevicePill", bookRow(title)).visible, 5000, title + " is marked on the device")
    }

    function expectNotOnDevice(title) {
        tryVerify(() => !find("onDevicePill", bookRow(title)).visible, 5000, title + " isn't marked on the device")
    }

    // Checks the one thing opened was the book at a path ending with file, in the system's
    // reader or the app given
    function expectOpenedInReader(file, app) {
        compare(inkview.openedBooks.length, 1, "one book opened")
        verify(inkview.openedBooks[0].path.endsWith(file), inkview.openedBooks[0].path + " is " + file)
        compare(inkview.openedBooks[0].app, app || "", app ? "in " + app : "in the system's reader")
        compare(inkview.openedTasks.length, 0, "no other app started")
    }

    // Checks the one thing opened was the audiobook player, on a path ending with file
    function expectOpenedInPlayer(file) {
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
