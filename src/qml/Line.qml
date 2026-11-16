import QtQuick

// A 1px line, black unless coloured: across its parent, less an inset at each end, or down
// it if vertical. Place it with y (x if vertical) or an anchor on that side.
Rectangle {
    property bool vertical: false
    property real inset: 0
    // From the left, or the top if vertical, and from the other end
    property real startInset: inset
    property real endInset: inset

    readonly property real length: (parent ? (vertical ? parent.height : parent.width) : 0) - startInset - endInset

    x: vertical ? 0 : startInset
    y: vertical ? startInset : 0
    width: vertical ? 1 : length
    height: vertical ? length : 1
    color: "black"
}
