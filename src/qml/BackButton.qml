import QtQuick
import "units.js" as Units

// The back chevron at the left of a page's toolbar (PageHeader, the search page), with a
// little space either side, centred on the toolbar's height
IconButton {
    objectName: "backButton"
    x: Units.dp(7)
    anchors.verticalCenter: parent.verticalCenter
    icon: "back"
    pressedIcon: "back_inv"
    fallbackText: "Back"
}
