import QtQuick

// A row that inverts while pressed or selected, as in the system's menus and lists: a black
// fill (rounded by radius) behind its content, which turns white with foreground, and a line
// below, inset at its ends and hidden while inverted. In a PopupMenu, the last visible row
// has no line. Tapping sends clicked() (see TapArea).
Item {
    id: row
    readonly property alias pressed: tap.pressed
    // Stays inverted, as the chosen row in a list to choose from
    property bool selected: false
    readonly property bool inverted: pressed || selected
    // For its text and icons: white while inverted
    readonly property color foreground: inverted ? "white" : "black"
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
        visible: row.inverted
    }
    // Over the content, since theme icons have an opaque background
    Line {
        id: line
        z: 1
        anchors.bottom: parent.bottom
        visible: row.lineBelow && !row.inverted
    }
    TapArea {
        id: tap
        anchors.fill: parent
        onTapped: row.clicked()
    }
}
