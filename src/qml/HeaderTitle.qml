import QtQuick
import "units.js" as Units

// A toolbar's title as the firmware's Qt apps show it (its AppHeader): capitals, centred
// while it fits. A longer title starts at the left and fades out under a half-white to
// white strip at its right end, instead of ending in "…". Set its width to the space
// between the toolbar's buttons less titleGap on each side.
StyledText {
    id: title
    // From the buttons on each side
    readonly property int titleGap: Units.dp(8.5)
    readonly property bool overflows: contentWidth > width

    horizontalAlignment: overflows ? Text.AlignLeft : Text.AlignHCenter
    clip: true
    size: Units.body
    font.capitalization: Font.AllUppercase

    Rectangle {
        objectName: "titleFade"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Units.dp(44)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.5) }
            GradientStop { position: 1; color: "white" }
        }
    }
}
