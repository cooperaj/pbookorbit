import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// Three cells side by side on an info page: what they show, and which can be tapped.
UiTestCase {
    id: test
    name: "InfoCells"

    Component {
        id: infoCells
        InfoCells {
            width: 600
            cells: [["Books", "12", true], ["Series", "0", false], ["Format", "EPUB"]]
        }
    }

    SignalSpy { id: taps; signalName: "cellClicked" }

    function make(properties) {
        root = createTemporaryObject(infoCells, test, properties || {})
        verify(root)
        taps.target = root
        taps.clear()
        waitForRendering(root)
        return root
    }

    function test_tappableCellSaysWhich() {
        make()

        tap("BooksCell")

        compare(taps.count, 1)
        compare(taps.signalArguments[0][0], 0)
    }

    function test_otherCellsIgnoreTaps() {
        make()

        tap("SeriesCell")
        tap("FormatCell")

        compare(taps.count, 0)
    }

    function test_hiddenWhenEveryCellIsEmpty() {
        make({cells: [["Added", ""], ["Size", ""], ["Format", ""]]})

        verify(!root.visible)
        compare(root.height, 0)
    }
}
