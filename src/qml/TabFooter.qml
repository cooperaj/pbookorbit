import QtQuick
import "night.js" as Night
import "units.js" as Units

// Footer for switching views, modelled on Libby on an Era Color: a full-width line, then
// equal tabs (inset from the sides), each an icon over a label. The current tab's
// label sits in a black pill.
Rectangle {
    id: footer
    // [{ label: "Collections", icon: "e3_filter_bookshelf" }, ...]: a theme icon by name,
    // or the app's own as image, e.g. "qrc:/icons/library.bmp"
    property var tabs: []
    property int currentIndex: 0
    signal tabClicked(int index)

    color: "white"
    height: 1 + Units.dp(1) + tabRow.height + Units.dp(7)

    Line {}

    Row {
        id: tabRow
        x: Units.dp(15)
        y: 1 + Units.dp(1)
        width: parent.width - 2 * x

        Repeater {
            model: footer.tabs
            delegate: Item {
                id: tab
                required property var modelData
                required property int index
                readonly property bool current: index === footer.currentIndex
                objectName: modelData.label + "Tab"

                width: tabRow.width / Math.max(1, footer.tabs.length)
                height: column.height

                Column {
                    id: column
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Units.dp(2)

                    ThemeIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: tab.modelData.icon ?? ""
                    }
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: source != ""
                        source: Night.image(tab.modelData.image ?? "")
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Taller for larger text, and the label cut short if it's wider
                        // than the tab, as in the system's home screen
                        width: label.width + 2 * Units.dp(12)
                        height: Math.max(Units.dp(22), label.implicitHeight)
                        radius: height / 2
                        color: tab.current ? "black" : "white"

                        StyledText {
                            id: label
                            anchors.centerIn: parent
                            width: Math.min(implicitWidth, tab.width - 2 * Units.dp(12))
                            text: tab.modelData.label
                            elide: Text.ElideRight
                            color: tab.current ? "white" : "black"
                            size: Units.textInIcons
                            font.bold: true
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: footer.tabClicked(tab.index)
                }
            }
        }
    }
}
