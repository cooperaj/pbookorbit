import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// A row that inverts while pressed, shared by the menu rows and the recent searches: a
// black fill and white foreground while pressed, a line below that hides meanwhile, and a
// tap that says so.
UiTestCase {
    id: test
    name: "PressableRow"

    Component {
        id: pressableRow
        Item {
            width: 400
            height: 100
            PressableRow {
                objectName: "row"
                height: 50
                lineStartInset: 15
                lineEndInset: 25
                Text {
                    objectName: "label"
                    text: "Title"
                    color: parent.foreground
                }
            }
        }
    }

    SignalSpy { id: clicks; signalName: "clicked" }

    function make() {
        root = createTemporaryObject(pressableRow, test)
        verify(root)
        waitForRendering(root)
        const row = find("row")
        clicks.target = row
        clicks.clear()
        return row
    }

    // Its line below
    function line(row) {
        return row.children.find(child => child instanceof Line)
    }

    function test_tapSaysClicked() {
        const row = make()

        mouseClick(row)

        compare(clicks.count, 1)
    }

    function test_invertsWhilePressed() {
        const row = make()
        compare(find("label").color, Qt.color("black"))
        verify(line(row).visible, "a line below")

        mousePress(row)

        verify(row.pressed)
        compare(find("label").color, Qt.color("white"))
        verify(!line(row).visible, "no line while pressed")
        mouseRelease(row)
    }

    function test_lineIsInsetAtItsEnds() {
        const row = make()

        compare(line(row).x, 15)
        compare(line(row).width, 400 - 15 - 25)
        compare(line(row).y, 49)
    }

    // Theme icons have an opaque background, so the line goes over the content
    function test_lineOverTheContent() {
        const row = make()

        verify(line(row).z > find("label").z)
    }

    function test_noLineWithoutASeparator() {
        const row = make()

        row.showSeparator = false

        verify(!row.lineBelow)
        verify(!line(row).visible)
    }
}
