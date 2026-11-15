import QtQuick
import "units.js" as Units
import "night.js" as Night

// A row in a list, modelled on the Era Color system library (screenshots 9 and 10), for
// BookRow and GroupRow: a picture in a cover's space, then the title, a second line, and
// a line of details in italics split by an upright grey bar ("Completed | Dune - 1"). A
// section's first row has a floating box at its left edge: a short label (a letter or
// series number) in a square, or a date written upwards in a narrow box. A black line
// runs under each row.
//
// Formats show in small capitals at the right of the second line: grey, or in an
// accent-coloured pill with a small e-reader mark if on the device (where the system
// shows its cloud icon).
//
// Tapping sends clicked(). A holdable row sends held() after a hold, and then no
// clicked().
Item {
    id: row
    property string title
    property string subtitle
    // Up to two, empty ones left out
    property var details: []
    // e.g. ["epub", "m4b"], and those of them on the device
    property var formats: []
    property var formatsOnDevice: []
    property bool sectionStart: false
    property string sectionLabel
    // The picture, filling the cover's space
    property alias picture: pictureBox.data
    property bool tappable: true
    property bool holdable: false
    signal clicked()
    signal held()

    readonly property bool squareSection: sectionLabel.length <= 4
    readonly property int rowHeight: Units.dp(83)
    readonly property int lineLeft: Units.dp(26)               // after the date box
    readonly property int contentLeft: Units.dp(33)            // the cover
    readonly property int contentRight: width - contentLeft    // rows end as far from the right
    readonly property int coverWidth: Units.dp(43)             // 2:3
    readonly property int coverHeight: Units.dp(65)

    width: ListView.view ? ListView.view.width : 0
    height: rowHeight

    TapArea {
        anchors.fill: parent
        list: row.ListView.view
        enabled: row.tappable
        pressAndHoldInterval: 750
        onTapped: row.clicked()
        // After a hold this long, releasing doesn't send clicked()
        onPressAndHold: (mouse) => {
            if (row.holdable)
                row.held()
            else
                mouse.accepted = false
        }
    }

    Item {
        id: pictureBox
        x: row.contentLeft
        anchors.verticalCenter: parent.verticalCenter
        width: row.coverWidth
        height: row.coverHeight
    }

    // Title, second line, then details, each on a fixed baseline so rows with fewer lines
    // align
    Item {
        id: texts
        x: pictureBox.x + pictureBox.width + Units.dp(12)
        width: row.contentRight - x - Units.dp(4)
        height: row.height

        Text {
            objectName: "title"
            y: Units.dp(24) - baselineOffset
            width: parent.width
            text: row.title
            font.pointSize: 10
            font.bold: true
            elide: Text.ElideRight
        }
        Text {
            id: subtitle
            objectName: "author"
            y: Units.dp(49) - baselineOffset
            // Leave room for the formats on the right
            width: parent.width - (formatRow.width > 0 ? formatRow.width + Units.dp(12) : 0)
            text: row.subtitle
            font.pointSize: 7.25
            elide: Text.ElideRight
        }
        // Formats, centred on the second line: "EPUB  AZW3  M4B", with those on the device
        // in pills
        Row {
            id: formatRow
            anchors.right: parent.right
            anchors.rightMargin: Units.dp(2)
            anchors.verticalCenter: subtitle.verticalCenter
            spacing: Units.dp(8)

            Repeater {
                model: row.formats
                Item {
                    id: format
                    required property string modelData
                    objectName: "format " + modelData
                    readonly property bool onDevice: row.formatsOnDevice.indexOf(modelData) >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: onDevice ? pill.width : label.implicitWidth
                    height: pill.height

                    Rectangle {
                        id: pill
                        objectName: "onDevicePill"
                        visible: format.onDevice
                        width: pillContent.width + 2 * Units.dp(7)
                        height: Units.dp(16)
                        radius: height / 2
                        color: Night.color(bookOrbit.accentColor)
                    }
                    Row {
                        id: pillContent
                        x: format.onDevice ? Units.dp(7) : 0
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Units.dp(3)

                        // A small e-reader: screen outline with a button below
                        Rectangle {
                            visible: format.onDevice
                            anchors.verticalCenter: parent.verticalCenter
                            width: Units.dp(5)
                            height: Units.dp(8)
                            radius: 2
                            color: "transparent"
                            border.width: 2
                            border.color: Night.color(bookOrbit.accentTextColor)
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                width: 3
                                height: 1
                                color: Night.color(bookOrbit.accentTextColor)
                            }
                        }
                        Text {
                            id: label
                            anchors.verticalCenter: parent.verticalCenter
                            text: format.modelData.toUpperCase()
                            color: format.onDevice ? Night.color(bookOrbit.accentTextColor) : "#606060"
                            font.pointSize: 6
                        }
                    }
                }
            }
        }
        // Details in italics, split by an upright grey bar
        Row {
            id: detailRow
            width: parent.width
            spacing: Units.dp(13)

            Text {
                id: first
                objectName: "status"
                y: Units.dp(73) - baselineOffset
                visible: text !== ""
                width: Math.min(implicitWidth, detailRow.width)
                text: row.details[0] || ""
                font.pointSize: 7.25
                font.italic: true
                elide: Text.ElideRight
            }
            Text {
                objectName: "separator"
                y: Units.dp(73) - baselineOffset
                visible: first.visible && second.visible
                text: "|"
                color: "#6e6e71"
                font.pointSize: 7.25
            }
            Text {
                id: second
                objectName: "series"
                y: Units.dp(73) - baselineOffset
                visible: text !== ""
                width: Math.max(0, detailRow.width - x)
                text: row.details[1] || ""
                font.pointSize: 7.25
                font.italic: true
                elide: Text.ElideRight
            }
        }
    }

    // 1px black line under the row, from after the date box to the row's end
    Rectangle {
        anchors.bottom: parent.bottom
        x: row.lineLeft
        width: row.contentRight - x
        height: 1
        color: "black"
    }

    // Section letter or number: a floating square at top left, over the picture's corner
    Rectangle {
        objectName: "squareSection"
        z: 1    // above BookRow's focus frame too
        visible: row.sectionStart && row.squareSection && row.sectionLabel !== ""
        x: 0
        y: 0
        width: Units.dp(35)
        height: width
        border.width: 1
        border.color: "black"

        Text {
            anchors.centerIn: parent
            width: parent.width - Units.dp(4)
            horizontalAlignment: Text.AlignHCenter
            text: row.sectionLabel
            font.pointSize: 9
            font.bold: true
            // Smaller for longer numbers such as 10.5
            fontSizeMode: Text.HorizontalFit
            minimumPointSize: 6
        }
    }

    // Section date: a narrow box down the left edge, written upwards
    Rectangle {
        objectName: "dateSection"
        z: 1
        visible: row.sectionStart && !row.squareSection
        x: 0
        y: 1
        width: row.lineLeft
        height: row.height - 4                                  // a 3px gap before the next box
        border.width: 1
        border.color: "black"

        Text {
            anchors.centerIn: parent
            rotation: -90
            text: row.sectionLabel
            font.pointSize: 6
        }
    }
}
