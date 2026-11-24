import QtQuick
import "units.js" as Units

// Section heading in an options menu (Libby's "CONTENT TYPE"): grey capitals, centred, over
// an inset black line.
Item {
    property alias text: label.text

    width: parent ? parent.width : 0
    implicitWidth: label.implicitWidth + 2 * Units.dp(15)
    height: Units.dp(50)

    StyledText {
        id: label
        anchors.centerIn: parent
        // Cut short if the menu can't widen enough for it
        width: Math.min(implicitWidth, parent.width - 2 * Units.dp(15))
        color: Units.grey("#606060")
        size: Units.body
        font.capitalization: Font.AllUppercase
        elide: Text.ElideRight
    }
    Line {
        anchors.bottom: parent.bottom
        inset: Units.dp(15)
    }
}
