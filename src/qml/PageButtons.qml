import QtQuick
import "units.js" as Units

// Page buttons over the bottom corners of a list or an info page's Flickable, as in the
// system library: up on the left, down on the right, each scrolling a
// screenful. Paging suits e-ink better than flicking, with one clean redraw per page. The
// buttons are half-white, fading the rows behind (black shows as 128 grey), with a 1px line
// along the top and inner side, rounded where they meet. Place in the list's parent with
// its bottom on the list's bottom; taps between the buttons reach the list.
Item {
    id: buttons
    property Flickable list

    // Each page overlaps the previous by this much, the strip under the buttons
    readonly property int overlap: height

    visible: list.visible && list.contentHeight > list.height
    width: parent.width
    height: Units.dp(57)

    // A ListView's origin shifts as it lays out unmeasured rows, so paging into either end
    // uses the ListView's own positioning instead of a computed one. An info page's
    // Flickable has fixed ends, so it goes straight there.
    function page(direction) {
        const top = list.originY
        const bottom = list.originY + list.contentHeight - list.height
        const target = list.contentY + direction * (list.height - overlap)
        const isListView = typeof list.positionViewAtBeginning === "function"
        if (target <= top) {
            if (isListView)
                list.positionViewAtBeginning()
            else
                list.contentY = top
        } else if (target >= bottom) {
            if (isListView)
                list.positionViewAtEnd()
            else
                list.contentY = bottom
        } else {
            list.contentY = target
        }
    }

    component PageButton: Item {
        id: button
        // Inner side, with the line and rounded corner
        property bool innerLeft
        property alias icon: image.name
        signal clicked()

        width: Units.dp(84)
        height: parent.height
        // No line on the outer side or bottom
        clip: true

        Rectangle {
            readonly property int hidden: radius + 1
            x: button.innerLeft ? 0 : -hidden
            width: button.width + hidden
            height: button.height + hidden
            radius: Units.dp(6)
            color: Qt.rgba(1, 1, 1, 0.5)
            border.width: 1
            border.color: "black"
        }
        ThemeIcon {
            id: image
            anchors.centerIn: parent
        }
        MouseArea {
            anchors.fill: parent
            onClicked: button.clicked()
        }
    }

    PageButton {
        objectName: "pageUp"
        anchors.left: parent.left
        icon: "arrow_page_prev"
        onClicked: buttons.page(-1)
    }
    PageButton {
        objectName: "pageDown"
        anchors.right: parent.right
        innerLeft: true
        icon: "arrow_page_next"
        onClicked: buttons.page(1)
    }
}
