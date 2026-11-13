import QtQml

// Stands in for Eink (src/ui/eink.h) in the tests
QtObject {
    property bool nightMode: false
    function enterA2ForFlick(x, y, width, height) {}
    function leaveA2Soon() {}
    function leaveA2() {}
    function requireHqUpdate() {}
    function setDynamicUpdates(enabled) {}
}
