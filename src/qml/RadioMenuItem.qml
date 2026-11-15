import QtQuick
import "units.js" as Units

// Option row in an options menu, modelled on Libby's filter menu on an Era Color: radio
// button, label, and an inset grey line below. Inverted while pressed.
Item {
    id: item
    property alias text: label.text
    property bool checked: false
    property bool showSeparator: true
    // Whether the line below shows: not under a PopupMenu's last row
    readonly property bool lineBelow: showSeparator && !(parent && parent.lastRow === item)
    signal clicked()

    width: parent ? parent.width : 0
    implicitWidth: label.x + label.implicitWidth + Units.dp(15)
    height: Units.dp(50)

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: mouse.pressed
    }
    ThemeIcon {
        x: Units.dp(40) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        name: item.checked ? "radiobtn_checked_s" : "radiobtn_s"
        inverted: mouse.pressed
    }
    Text {
        id: label
        x: Units.dp(66)
        anchors.verticalCenter: parent.verticalCenter
        color: mouse.pressed ? "white" : "black"
        font.pointSize: 8
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Units.dp(15)
        anchors.rightMargin: Units.dp(15)
        height: 1
        color: "#777777"
        visible: item.lineBelow && !mouse.pressed
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: item.clicked()
    }
}
