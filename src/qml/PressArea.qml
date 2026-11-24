import QtQuick

// A MouseArea for something with a pressed look. The pressed look draws with the fast
// e-ink waveform (Eink::requireFastUpdate()), so what the tap opens, which waits for it,
// shows sooner. Leave pressedLook off where pressing changes nothing on screen: the fast
// waveform would then draw the next screen, covers included, in black and white.
MouseArea {
    property bool pressedLook: true

    onPressedChanged: if (pressed && pressedLook) eink.requireFastUpdate()
}
