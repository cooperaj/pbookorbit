import QtQuick

// What's behind a menu or dialog, faded as the system apps do. It takes every tap, sending
// tapped(), so nothing behind it reacts; a menu closes on it.
Rectangle {
    id: fade
    signal tapped()

    color: Qt.rgba(1, 1, 1, 0.5)

    MouseArea {
        anchors.fill: parent
        onClicked: fade.tapped()
    }
}
