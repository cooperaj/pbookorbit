import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// The page buttons on their own, over a list of 20-high rows or a plain Flickable, as the
// info pages use. Each tap moves a screenful less the strip the buttons cover, and stops at
// the ends. Which list the page-turn keys page is tested with the app.
UiTestCase {
    id: test
    name: "PageButtons"

    Component {
        id: listWithButtons
        Item {
            property alias list: list
            property alias buttons: buttons
            property int rows: 100
            width: 400
            height: 600

            ListView {
                id: list
                anchors.fill: parent
                model: parent.rows
                delegate: Item { width: 1; height: 20 }
            }
            PageButtons {
                id: buttons
                list: list
                anchors.bottom: list.bottom
            }
        }
    }

    Component {
        id: flickableWithButtons
        Item {
            property alias list: list
            property alias buttons: buttons
            width: 400
            height: 600

            Flickable {
                id: list
                anchors.fill: parent
                contentHeight: 2000
            }
            PageButtons {
                id: buttons
                list: list
                anchors.bottom: list.bottom
            }
        }
    }

    function make(component, properties) {
        root = createTemporaryObject(component, test, properties || {})
        verify(root)
        waitForRendering(root)
        return root
    }

    // A screenful less the buttons' strip, so the row under them is the next page's first
    function step() {
        return root.list.height - root.buttons.height
    }

    function test_downMovesAScreenfulLessTheButtons() {
        make(listWithButtons)

        tap("pageDown", root.buttons)

        compare(root.list.contentY, step())
    }

    function test_upMovesBack() {
        make(listWithButtons)
        tap("pageDown", root.buttons)
        tap("pageDown", root.buttons)

        tap("pageUp", root.buttons)

        compare(root.list.contentY, step())
    }

    function test_downStopsAtTheEnd() {
        make(listWithButtons)

        for (let i = 0; i < 6; i++)
            tap("pageDown", root.buttons)

        verify(root.list.atYEnd, "at the end")
        compare(root.list.contentY, root.list.originY + root.list.contentHeight - root.list.height,
                "not past it")
    }

    function test_upStopsAtTheTop() {
        make(listWithButtons)
        tap("pageDown", root.buttons)

        tap("pageUp", root.buttons)
        tap("pageUp", root.buttons)

        verify(root.list.atYBeginning)
        compare(root.list.contentY, root.list.originY)
    }

    function test_hiddenWhenTheListFits() {
        make(listWithButtons, {rows: 20})

        verify(!root.buttons.visible)
    }

    function test_hiddenWithTheList() {
        make(listWithButtons)
        verify(root.buttons.visible)

        root.list.visible = false

        verify(!root.buttons.visible)
    }

    // As on the info pages
    function test_pagesAPlainFlickable() {
        make(flickableWithButtons)

        tap("pageDown", root.buttons)
        compare(root.list.contentY, step())

        for (let i = 0; i < 4; i++)
            tap("pageDown", root.buttons)
        compare(root.list.contentY, 2000 - root.list.height, "stops at the end")

        for (let i = 0; i < 5; i++)
            tap("pageUp", root.buttons)
        compare(root.list.contentY, 0, "and the top")
    }
}
