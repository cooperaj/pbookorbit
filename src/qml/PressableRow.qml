import QtQuick

// A row that inverts while pressed, as in the system's menus and lists: a black fill
// (rounded by radius) behind its content, which turns white with foreground, and a line
// below, inset at its ends and hidden while pressed. In a PopupMenu, the last visible row
// has no line. Tapping sends clicked() (see TapArea).
Item {
    id: row
    readonly property alias pressed: tap.pressed
    // For its text and icons: white while pressed
    readonly property color foreground: pressed ? "white" : "black"
    property alias radius: fill.radius
    property bool showSeparator: true
    // Whether the line below shows
    readonly property bool lineBelow: showSeparator && !(parent && parent.lastRow === row)
    property alias lineColor: line.color
    property alias lineStartInset: line.startInset
    property alias lineEndInset: line.endInset
    signal clicked()

    width: parent ? parent.width : 0

    Rectangle {
        id: fill
        anchors.fill: parent
        color: "black"
        visible: row.pressed
    }
    // Over the content, since theme icons have an opaque background
    Line {
        id: line
        z: 1
        anchors.bottom: parent.bottom
        visible: row.lineBelow && !row.pressed
    }
    TapArea {
        id: tap
        anchors.fill: parent
        onTapped: row.clicked()
    }
}
