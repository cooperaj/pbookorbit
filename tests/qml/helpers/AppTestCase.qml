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

    // Opens the app on a new database holding the given settings, with options for how it
    // starts (see TestApp::reset() in main.cpp), e.g. {offline: true, books: [...]}
    function open(settings, options) {
        testApp.reset(settings || {}, options || {})
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
