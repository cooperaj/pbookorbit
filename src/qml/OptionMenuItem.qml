import QtQuick
import "units.js" as Units

// Option row in an options menu, modelled on Libby's filter menu on an Era Color: radio
// button, label, and an inset grey line below. Inverted while pressed (see PressableRow).
// With checkbox, one of several that can be ticked together, as a ticked box that can't be
// unticked (locked) shows greyed.
PressableRow {
    id: item
    property alias text: label.text
    property bool checked: false
    property bool checkbox: false
    property bool locked: false

    implicitWidth: label.x + label.implicitWidth + Units.dp(15)
    height: Units.dp(50)
    lineStartInset: Units.dp(15)
    lineEndInset: Units.dp(15)
    lineColor: "#777777"

    ThemeIcon {
        x: Units.dp(40) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        // The theme's radio buttons are 74px with 46px drawn, its boxes 110px with 60px:
        // scaled to match
        width: item.checkbox ? 84 : 74
        height: width
        sourceSize.width: width
        sourceSize.height: height
        name: !item.checkbox ? (item.checked ? "radiobtn_checked_s" : "radiobtn_s")
              : !item.checked ? "checkbox_square_off"
              : item.locked ? "checkbox_square_on_disabled" : "checkbox_square_on"
        inverted: item.pressed
    }
    Text {
        id: label
        x: Units.dp(66)
        anchors.verticalCenter: parent.verticalCenter
        color: item.foreground
        font.pointSize: 8
    }
}
