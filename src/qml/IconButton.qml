import QtQuick
import "units.js" as Units

// Toolbar button showing a system theme icon at natural size, with pressedIcon drawn over
// it while pressed (like BitmapButton in the SDK's qml_test). Without a pressed icon the
// normal one stays; with neither, fallbackText shows. The pressed look draws with the fast
// e-ink waveform (see PressArea).
Item {
    id: button
    property string icon          // theme resource name, e.g. "home"
    property string pressedIcon   // e.g. "home_inv"
    property string fallbackText
    // Draws the icon white on black, for a darker background
    property bool inverted: false
    // Draws the icon at this many pixels square instead of natural size (0 for natural).
    // Set the button's width and height to keep a larger tap target.
    property int iconSize: 0
    signal clicked()

    implicitWidth: image.status === Image.Ready ? image.implicitWidth : fallback.implicitWidth
    implicitHeight: image.status === Image.Ready ? image.implicitHeight : fallback.implicitHeight

    ThemeIcon {
        id: image
        anchors.centerIn: parent
        sourceSize.width: button.iconSize
        sourceSize.height: button.iconSize
        name: button.icon
        inverted: button.inverted
    }
    ThemeIcon {
        id: pressedImage
        anchors.centerIn: parent
        visible: mouse.pressed && status === Image.Ready
        sourceSize.width: button.iconSize
        sourceSize.height: button.iconSize
        name: button.pressedIcon
    }
    StyledText {
        id: fallback
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        text: button.fallbackText
        size: Units.body
        font.bold: true
    }
    PressArea {
        id: mouse
        anchors.fill: parent
        onClicked: button.clicked()
    }
}
