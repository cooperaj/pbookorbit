import QtQuick
import "units.js" as Units

// Toolbar for pages opened over the book list, modelled on the system library's Book info
// page: back chevron on the left, centred capitalised title (e.g. "BOOK
// INFO / 99 BOTTLES OF OOP", see HeaderTitle), and a 1px line below.
Rectangle {
    id: header
    property alias title: titleText.text
    signal back()

    height: Units.headerHeight + 1
    color: "white"

    BackButton {
        id: backButton
        onClicked: header.back()
    }

    HeaderTitle {
        id: titleText
        objectName: "pageTitle"
        anchors.centerIn: parent
        // Centred, so reserve the back button's width on both sides
        width: parent.width - 2 * (backButton.x + backButton.width + titleGap)
    }

    Line {
        anchors.bottom: parent.bottom
    }
}
