import QtQuick

// The sort and filter menus a list page's sub-toolbar opens. main.qml has one pair, shared
// by every list page, and gives each page this to show which is open and say when the
// buttons are tapped.
QtObject {
    property bool filterOpen: false
    property bool sortOpen: false
    signal filterClicked()
    signal sortClicked()
}
