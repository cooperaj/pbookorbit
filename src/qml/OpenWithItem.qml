import QtQuick

// A menu's Open with row (BookMenu, the book info page's actions), shown when there's
// something to open with (see Books.openWithTarget). Tapping it expands it in place, as in
// the system library: put a Repeater of subItem PopupMenuItems over apps after it.
PopupMenuItem {
    id: item
    // What Open with opens, or null
    property var target: null
    property bool expanded: false
    // The apps to list under it while expanded
    readonly property var apps: expanded && target ? target.apps : []

    objectName: "openWith"
    visible: target !== null
    icon: "e3_menu_open"
    text: "Open with"
    arrow: expanded ? "up" : "down"
    onClicked: expanded = !expanded
}
