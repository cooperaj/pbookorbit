import QtQuick
import "units.js" as Units

// Where a jump rail puts its entries: the alphabet centred between top and bottom, as
// tightly spaced as it needs, up to fullPitch. A rail lays itself out with one of its own;
// main.qml makes one in window coordinates for the library's rail space and gives it to
// every list page, so letters sit at the same height on every page.
QtObject {
    property real top
    property real bottom
    // Between a rail and the list's header or page buttons
    readonly property int inset: Units.dp(7)
    readonly property int letters: 27   // # and A to Z
    readonly property int fullPitch: Units.dp(20)

    readonly property real pitch: Math.min(fullPitch, Math.floor((bottom - top) / letters))
    readonly property real entriesTop: top + Math.max(0, (bottom - top - letters * pitch) / 2)
}
