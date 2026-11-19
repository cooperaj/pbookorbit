import QtQuick
import "units.js" as Units

// A dialog styled like the system's own (InkView's Dialog(), which Qt apps can't use),
// measured on an Era Color: thick black rounded border, a round theme icon on the left with
// the message beside it, and buttons along the bottom split by thin grey lines. The window
// fades behind it, and only its buttons close it.
//
// Beside the icon: a bold heading, any children, then the message. DialogText is their
// text style, for children.
Item {
    id: dialog
    property string heading
    property string message
    // Extra space above the message
    property int messageGap: 0
    // Theme icon: icon_question, icon_error, icon_info...
    property string icon: "icon_question"
    // Buttons left to right, as [label, action]: as in the system's dialogs, the way out
    // (Cancel, No, Close) first and the one that goes ahead last. Leave empty for a
    // status-only dialog.
    property var buttons: []
    // Progress 0-100 for a bar under the message, or -1 for none
    property int percent: -1
    default property alias content: extra.data

    signal pressed(var action)

    component DialogText: Text {
        width: parent ? parent.width : 0
        font.pointSize: 7.25
        wrapMode: Text.Wrap
    }

    visible: false

    // Taps on the faded window do nothing
    Fade {
        anchors.fill: parent
    }

    Panel {
        id: panel
        // Near the bottom of the screen, like the system's dialogs
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Units.dp(60)
        width: parent.width - 2 * Units.dp(42)
        height: body.height + buttonRow.height + 2 * border.width

        // Icon and message
        Item {
            id: body
            x: panel.border.width
            y: panel.border.width
            width: panel.width - 2 * x
            readonly property int minHeight: Units.dp(175)
            height: Math.max(minHeight, messageArea.height + 2 * Units.dp(25))

            // Where it's centred in the shortest dialog, so a taller one keeps it at the top
            ThemeIcon {
                id: icon
                x: Units.dp(25)
                y: Math.round((body.minHeight - height) / 2)
                name: dialog.icon
            }

            Column {
                id: messageArea
                x: icon.x + icon.width + Units.dp(52)
                width: parent.width - x - Units.dp(25)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Units.dp(6)

                DialogText {
                    objectName: "heading"
                    visible: text !== ""
                    text: dialog.heading
                    font.bold: true
                }
                Column {
                    id: extra
                    visible: childrenRect.height > 0
                    width: parent.width
                    spacing: Units.dp(6)
                }
                DialogText {
                    objectName: "message"
                    visible: text !== ""
                    topPadding: dialog.messageGap
                    text: dialog.message
                }
                // Progress: a black bar filling a 1px outline
                Rectangle {
                    objectName: "progress"
                    width: parent.width
                    height: Units.dp(8)
                    visible: dialog.percent >= 0
                    border.width: 1
                    border.color: "black"
                    Rectangle {
                        objectName: "progressFill"
                        width: parent.width * Math.max(0, dialog.percent) / 100
                        height: parent.height
                        color: "black"
                    }
                }
            }
        }

        // Buttons along the bottom, with grey lines above and between them, inverted while
        // pressed
        Row {
            id: buttonRow
            x: panel.border.width
            y: body.y + body.height
            width: panel.width - 2 * x
            height: dialog.buttons.length > 0 ? Units.dp(54) : 0

            Repeater {
                model: dialog.buttons
                Item {
                    required property var modelData
                    required property int index
                    objectName: modelData[1] + "Button"
                    width: buttonRow.width / dialog.buttons.length
                    height: buttonRow.height

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        color: "black"
                        visible: press.pressed
                        // Square on top, rounded into the panel's corners at the bottom
                        bottomLeftRadius: index === 0 ? panel.radius - panel.border.width : 0
                        bottomRightRadius: index === dialog.buttons.length - 1 ? panel.radius - panel.border.width : 0
                    }
                    Text {
                        anchors.centerIn: parent
                        text: modelData[0]
                        color: press.pressed ? "white" : "black"
                        font.pointSize: 8
                        font.capitalization: Font.AllUppercase
                    }
                    // Divider before this button
                    Line {
                        visible: index > 0
                        vertical: true
                        color: "#7f7f7f"
                    }
                    MouseArea {
                        id: press
                        anchors.fill: parent
                        onClicked: dialog.pressed(modelData[1])
                    }
                }
            }
        }
        // Line above the buttons
        Line {
            visible: dialog.buttons.length > 0
            y: buttonRow.y
            inset: buttonRow.x
            color: "#7f7f7f"
        }
    }
}
