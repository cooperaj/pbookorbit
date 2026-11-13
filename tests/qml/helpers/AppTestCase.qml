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
    }
}
