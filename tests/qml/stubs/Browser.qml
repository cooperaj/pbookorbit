import QtQml

// Stands in for Browser (src/core/browser.h) in the tests
QtObject {
    property bool available: false
    function open(address) { return false }
}
