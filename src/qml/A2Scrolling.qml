import QtQuick

// Fast black-and-white (A2) e-ink updates while a list or page (target, a Flickable)
// scrolls, back to normal once it stops or hides. A2 takes screen coordinates, hence
// mapToGlobal (as in the SDK's qml_test).
Connections {
    function onMovementStarted() {
        const pos = target.mapToGlobal(0, 0)
        eink.enterA2ForFlick(pos.x, pos.y, target.width, target.height)
    }
    // Fires when momentum stops, not when the finger lifts
    function onMovementEnded() {
        eink.leaveA2Soon()
    }
    function onVisibleChanged() {
        if (!target.visible)
            eink.leaveA2()
    }
}
