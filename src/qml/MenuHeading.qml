import QtQuick
import "units.js" as Units

// Section heading in an options menu (Libby's "CONTENT TYPE"): grey capitals, centred, over
// an inset black line.
Item {
    property alias text: label.text

    width: parent ? parent.width : 0
    implicitWidth: label.implicitWidth + 2 * Units.dp(15)
    height: Units.dp(50)

    Text {
        id: label
        anchors.centerIn: parent
        color: "#606060"
        font.pointSize: Units.body
        font.capitalization: Font.AllUppercase
    }
    Line {
        anchors.bottom: parent.bottom
        inset: Units.dp(15)
    }
}
