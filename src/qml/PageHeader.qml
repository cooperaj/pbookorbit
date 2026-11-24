import QtQuick
import "units.js" as Units

// Toolbar for pages opened over the book list, modelled on the system library's Book info
// page: back chevron on the left, centred capitalised title (e.g. "BOOK
// INFO / 99 BOTTLES OF OOP"), and a 1px line below.
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

    StyledText {
        id: titleText
        anchors.centerIn: parent
        // Centred, so reserve the back button's width on both sides
        width: parent.width - 2 * (backButton.x + backButton.width)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        size: Units.body
        font.capitalization: Font.AllUppercase
    }

    Line {
        anchors.bottom: parent.bottom
    }
}
