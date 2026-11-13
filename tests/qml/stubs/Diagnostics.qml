import QtQml

// Stands in for diagnostics::Log (src/core/diagnostics.h) in the tests
QtObject {
    property bool enabled: false
    function toggle() {}
    function log(message) { console.log(message) }
    function trace(message) {}
}
