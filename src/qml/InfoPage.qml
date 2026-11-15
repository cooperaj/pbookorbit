import QtQuick
import "units.js" as Units

// A page of details opened over the views (BookInfoPage, AuthorInfoPage), laid out like the
// system library's Book info page (screenshot 11): a toolbar with a back button and the
// title, then a column with that page's margins, which scrolls when it's long, with a
// scrollbar and page buttons like the lists. Children go in the column; overlay is for
// what sits over it all, such as a menu.
Rectangle {
    id: page
    color: "white"

    property alias title: header.title
    default property alias content: column.data
    property alias overlay: overlayLayer.data
    // For the page-turn keys, which main.qml forwards to the front page
    readonly property alias pageButtons: pageButtons

    signal back()

    function scrollToTop() {
        flickable.contentY = 0
    }

    PageHeader {
        id: header
        width: parent.width
        onBack: page.back()
    }

    Flickable {
        id: flickable
        objectName: "content"
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        // Room at the end to scroll the last line clear of the page buttons
        contentHeight: column.height + Units.dp(26) + pageButtons.height

        A2Scrolling { target: flickable }

        Column {
            id: column
            // Margins as on the system's Book info page
            x: Units.dp(26)
            y: Units.dp(20)
            width: parent.width - 2 * x
        }
    }

    ListScrollbar {
        list: flickable
        bottomInset: pageButtons.height
    }
    PageButtons {
        id: pageButtons
        list: flickable
        anchors.bottom: flickable.bottom
    }

    Item {
        id: overlayLayer
        anchors.fill: parent
    }
}
