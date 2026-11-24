import QtQuick
import "units.js" as Units
import "format.js" as Format

// One field on an info page (BookInfoPage, AuthorInfoPage): bold label over value with a
// grey line below; nothing if there's no value. A tappable field has a chevron on the
// right, inverts while pressed like InfoCells' cells, and sends clicked(). A link field
// (web address) underlines its value instead; only the text is tappable, inverting while
// pressed, and it sends linkClicked(). A value that's HTML (see Format.isHtml) shows as
// rich text, anything else as plain text.
Item {
    id: field
    property string label
    property string value
    property bool showLine: true
    property bool tappable: false
    property bool link: false
    signal clicked()
    signal linkClicked()
    visible: value !== ""
    implicitHeight: column.height

    // Pressed fill: black from the line above (halfway down the gap) to its own
    Rectangle {
        visible: mouse.pressed
        y: -Units.dp(9) + 1
        width: parent.width
        height: column.height - 1
        color: "black"
    }

    // Link text, with a black background while pressed
    Rectangle {
        visible: linkMouse.pressed
        x: valueText.x
        y: valueText.y
        width: valueText.contentWidth
        height: valueText.contentHeight
        color: "black"
    }

    Column {
        id: column
        width: parent.width
        spacing: Units.dp(6)

        StyledText {
            // Clear of the chevron
            width: parent.width - (field.tappable ? chevron.width + Units.dp(6) : 0)
            text: field.label
            color: mouse.pressed ? "white" : "black"
            size: Units.body
            font.bold: true
            wrapMode: Text.Wrap
        }
        StyledText {
            id: valueText
            objectName: "value"
            width: parent.width - (field.tappable ? chevron.width + Units.dp(6) : 0)
            text: field.value
            color: mouse.pressed || linkMouse.pressed ? "white" : "black"
            font.underline: field.link
            textFormat: Format.isHtml(field.value) ? Text.RichText : Text.PlainText
            size: Units.body
            wrapMode: Text.Wrap
        }
        Item {
            width: parent.width
            height: Units.dp(18)
            Line {
                visible: field.showLine
                anchors.verticalCenter: parent.verticalCenter
                color: "#7f7f7f"
            }
        }
    }

    // Level with the label and value
    Chevron {
        id: chevron
        visible: field.tappable
        inverted: mouse.pressed
        anchors.right: parent.right
        y: (valueText.y + valueText.height - height) / 2
    }
    TapArea {
        id: linkMouse
        objectName: "link"
        enabled: field.link
        x: valueText.x
        y: valueText.y
        width: valueText.contentWidth
        height: valueText.contentHeight
        onTapped: field.linkClicked()
    }
    TapArea {
        id: mouse
        enabled: field.tappable
        y: -Units.dp(9)
        width: parent.width
        height: column.height
        onTapped: field.clicked()
    }
}
