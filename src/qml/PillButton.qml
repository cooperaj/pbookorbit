import QtQuick
import "units.js" as Units

// Button in PocketBook's native style, measured from the OverDrive sign-in screen on an Era
// Color: pill-shaped with a 1px pure black border, capitalised label, optional theme icon
// on the left. Inverted while pressed, grey while disabled. While busy, a spinner turns at
// its right end and it can't be pressed. Sizes are the firmware's (its RoundedTextButton).
Rectangle {
    id: button
    property alias text: label.text
    property string icon            // optional theme resource name, e.g. "search"
    property string pressedIcon     // shown while pressed, e.g. "search_inv"
    property bool busy: false
    signal clicked()

    readonly property int padding: Units.fromDesign(64)
    readonly property bool dimmed: !enabled && !busy

    implicitWidth: Math.max(Units.dp(200), content.implicitWidth + 2 * padding)
    implicitHeight: Units.elementHeight
    radius: height / 2
    // One device pixel like the native buttons, so not dp-scaled
    border.width: 1
    border.color: dimmed ? Units.disabledColor : "black"
    color: mouse.pressed ? "black" : "white"

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Units.dp(12)

        ThemeIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: name !== "" && status === Image.Ready
            opacity: button.dimmed ? 0.5 : 1
            name: mouse.pressed && button.pressedIcon ? button.pressedIcon : button.icon
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            color: mouse.pressed ? "white" : button.dimmed ? Units.disabledColor : "black"
            font.pointSize: Units.body
            font.capitalization: Font.AllUppercase
        }
    }
    SpinnerImage {
        visible: button.busy
        frames: "progress_indicator_"
        anchors.right: parent.right
        anchors.rightMargin: (parent.height - height) / 2
        anchors.verticalCenter: parent.verticalCenter
    }
    PressArea {
        id: mouse
        anchors.fill: parent
        enabled: !button.busy
        onClicked: button.clicked()
    }
}
