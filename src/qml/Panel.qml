import QtQuick
import "units.js" as Units

// The box the system's menus and dialogs sit in, measured on an Era Color: white, with a
// thick black border and rounded corners (PopupMenu, SystemDialog)
Rectangle {
    radius: Units.dp(9)
    border.width: Units.panelBorder
    border.color: "black"
    color: "white"
}
