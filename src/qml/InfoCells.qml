import QtQuick
import "units.js" as Units

// Three cells side by side on an info page (BookInfoPage, AuthorInfoPage): grey capital
// labels over values, separated by grey lines. Empty cells are blank, and the row is hidden
// if all are. A cell with a third entry, true, is tappable: it has a chevron on the right,
// inverts while pressed like buttons, and sends cellClicked(index).
Item {
    id: cellRow
    property var cells: []
    property bool showTopLine: true
    signal cellClicked(int index)
    visible: cells.some(cell => cell[1] !== "")
    // dp(82), the label and value's part of it growing with the text (see ListRow)
    height: visible ? Units.dp(32 + 50 * Units.textScale() * Units.lineSpacing()) : 0

    Line {
        visible: cellRow.showTopLine
        color: "#7f7f7f"
    }
    Row {
        anchors.fill: parent
        Repeater {
            model: cellRow.cells
            Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool tappable: modelData.length > 2 && modelData[2] === true
                objectName: modelData[0] + "Cell"
                width: cellRow.width / 3
                height: cellRow.height

                // Pressed: black between the lines
                Rectangle {
                    visible: mouse.pressed
                    x: index > 0 ? 1 : 0
                    y: 1
                    width: parent.width - x
                    height: parent.height - 2
                    color: "black"
                }

                // Divider before every cell but the first, short of the row's top and
                // bottom
                Line {
                    visible: index > 0
                    vertical: true
                    inset: Units.dp(13)
                    color: "#7f7f7f"
                }
                Column {
                    x: Units.dp(11)
                    // Clear of the chevron
                    width: parent.width - 2 * x - (cell.tappable ? chevron.width + Units.dp(6) : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Units.dp(8)
                    StyledText {
                        width: parent.width
                        text: modelData[0]
                        color: mouse.pressed ? Units.grey("#c0c0c0", "white") : Units.grey("#808080")
                        size: Units.body
                        font.capitalization: Font.AllUppercase
                        elide: Text.ElideRight
                    }
                    StyledText {
                        width: parent.width
                        text: modelData[1]
                        color: mouse.pressed ? "white" : "black"
                        size: Units.body
                        elide: Text.ElideRight
                    }
                }
                Chevron {
                    id: chevron
                    visible: cell.tappable
                    inverted: mouse.pressed
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                }
                TapArea {
                    id: mouse
                    anchors.fill: parent
                    enabled: cell.tappable
                    onTapped: cellRow.cellClicked(cell.index)
                }
            }
        }
    }
    Line {
        anchors.bottom: parent.bottom
        color: "#7f7f7f"
    }
}
