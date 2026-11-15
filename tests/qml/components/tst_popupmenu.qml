import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// A drop-down menu in the system style: as wide as its widest visible row, never narrower
// than the system's smallest menu, and squared off where it joins a tab.
UiTestCase {
    id: test
    name: "PopupMenu"

    Component {
        id: popupMenu
        PopupMenu {
            property alias longVisible: longRow.visible
            PopupMenuItem { text: "Book info" }
            PopupMenuItem {
                id: longRow
                text: "Find books on this device, and a good deal more besides"
                showSeparator: false
            }
        }
    }

    function make(properties) {
        root = createTemporaryObject(popupMenu, test, properties || {})
        verify(root)
        waitForRendering(root)
        return root
    }

    function test_asWideAsItsWidestVisibleRow() {
        const menu = make()
        const wide = menu.width

        menu.longVisible = false

        verify(menu.width < wide, "narrower without the long row")
    }

    function test_neverNarrowerThanTheSmallestMenu() {
        const menu = make({longVisible: false})

        verify(menu.width > menu.contentWidth + 2 * (menu.border.width + menu.padding),
               "wider than its short row needs")
    }

    function test_squaredWhereItJoinsATab() {
        const menu = make()
        compare(menu.topLeftRadius, menu.radius)
        compare(menu.topRightRadius, menu.radius)

        menu.joinedCorner = "topLeft"
        compare(menu.topLeftRadius, 0)
        compare(menu.topRightRadius, menu.radius)

        menu.joinedCorner = "topRight"
        compare(menu.topLeftRadius, menu.radius)
        compare(menu.topRightRadius, 0)
    }
}
