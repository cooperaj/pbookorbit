import QtQuick
import "units.js" as Units

// Option row in an options menu, modelled on Libby's filter menu on an Era Color: radio
// button, label, and an inset grey line below. Inverted while pressed (see PressableRow).
PressableRow {
    id: item
    property alias text: label.text
    property bool checked: false

    implicitWidth: label.x + label.implicitWidth + Units.dp(15)
    height: Units.dp(50)
    lineStartInset: Units.dp(15)
    lineEndInset: Units.dp(15)
    lineColor: "#777777"

    ThemeIcon {
        x: Units.dp(40) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        name: item.checked ? "radiobtn_checked_s" : "radiobtn_s"
        inverted: item.inverted
    }
    Text {
        id: label
        x: Units.dp(66)
        anchors.verticalCenter: parent.verticalCenter
        color: item.foreground
        font.pointSize: 8
    }
}
