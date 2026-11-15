import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// A drop-down menu in the system style: as wide as its widest visible row, never narrower
// than the system's smallest menu, squared off where it joins a tab, and with no line under
// its last visible row.
UiTestCase {
    id: test
    name: "PopupMenu"

    Component {
        id: popupMenu
        PopupMenu {
            property alias longVisible: longRow.visible
            PopupMenuItem { objectName: "first"; text: "Book info" }
            PopupMenuItem {
                id: longRow
                objectName: "long"
                text: "Find books on this device, and a good deal more besides"
            }
            Repeater {
                model: 0
                PopupMenuItem { objectName: "repeated" }
            }
        }
    }

    function make(properties) {
        root = createTemporaryObject(popupMenu, test, properties || {})
        verify(root)
        waitForRendering(root)
        return root
    }

    function test_noLineUnderTheLastVisibleRow() {
        const menu = make()
        verify(find("first").lineBelow, "a line between the rows")
        verify(!find("long").lineBelow, "none under the last")

        menu.longVisible = false

        verify(!find("first").lineBelow, "none under the row that's now last")
    }

    // A Repeater's rows are moved into place after they're made
    function test_noLineUnderARepeatersLastRow() {
        const menu = make()
        const column = find("long").parent

        column.children.find(c => c instanceof Repeater).model = 2
        waitForItemPolished(column)

        const repeated = column.children.filter(c => c.objectName === "repeated").sort((a, b) => a.y - b.y)
        compare(repeated.length, 2)
        verify(find("long").lineBelow, "a line above the repeated rows")
        verify(repeated[0].lineBelow, "and between them")
        verify(!repeated[1].lineBelow, "but not under the last")
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
