import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"
import "../../../src/qml/units.js" as Units

// The row every list shares, with its fields set directly: its lines, formats, section
// boxes, and which touches count as taps or holds (TapArea's own rules are tested in
// tst_taparea.qml). What a book or group puts in it is
// tested with BookRow and GroupRow.
UiTestCase {
    id: test
    name: "ListRow"

    Component {
        id: rowList
        ListView {
            property var rows: []
            width: 600
            height: 400
            model: rows
            delegate: ListRow {
                required property var modelData
                title: modelData.title || "A Row"
                subtitle: modelData.subtitle || ""
                details: modelData.details || []
                formats: modelData.formats || []
                formatsOnDevice: modelData.formatsOnDevice || []
                sectionStart: modelData.sectionStart === true
                sectionLabel: modelData.sectionLabel || ""
                tappable: modelData.tappable !== false
                holdable: modelData.holdable === true
            }
        }
    }

    SignalSpy { id: clicks; signalName: "clicked" }
    SignalSpy { id: holds; signalName: "held" }

    // Lists the rows, and returns the first, watched by clicks and holds
    function show(rows) {
        root = createTemporaryObject(rowList, test, {rows: rows})
        verify(root)
        waitForRendering(root)
        const row = root.itemAtIndex(0)
        clicks.target = row
        holds.target = row
        clicks.clear()
        holds.clear()
        return row
    }

    function test_showsItsLines() {
        const row = show([{title: "Dune", subtitle: "Frank Herbert", details: ["Completed", "Dune - 1"]}])

        compare(find("title", row).text, "Dune")
        compare(find("author", row).text, "Frank Herbert")
        compare(find("status", row).text, "Completed")
        compare(find("series", row).text, "Dune - 1")
        verify(find("separator", row).visible, "a bar between the details")
    }

    function test_noSeparatorWithOneDetail() {
        const first = show([{details: ["6 books", ""]}])
        verify(find("status", first).visible)
        verify(!find("series", first).visible)
        verify(!find("separator", first).visible, "no bar")

        const second = show([{details: ["", "Dune - 1"]}])
        verify(!find("status", second).visible)
        verify(find("series", second).visible)
        verify(!find("separator", second).visible, "no bar")
    }

    // Every format shows, and only those on the device are in a pill
    function test_formatsOnDeviceAreInAPill() {
        const row = show([{formats: ["epub", "pdf"], formatsOnDevice: ["epub"]}])

        verify(find("onDevicePill", find("format epub", row)).visible, "the epub is on the device")
        verify(!find("onDevicePill", find("format pdf", row)).visible, "the pdf isn't")
    }

    // Letters and series numbers in a square; longer labels, dates, in a tall box
    function test_sectionLabels() {
        const letter = show([{sectionStart: true, sectionLabel: "D"}])
        verify(find("squareSection", letter).visible, "D in a square")
        verify(!find("dateSection", letter).visible)

        const date = show([{sectionStart: true, sectionLabel: "12 Mar 2026"}])
        verify(find("dateSection", date).visible, "a date in a tall box")
        verify(!find("squareSection", date).visible)

        const inside = show([{sectionStart: false, sectionLabel: "D"}])
        verify(!find("squareSection", inside).visible, "only a section's first row has a box")
        verify(!find("dateSection", inside).visible)
    }

    function test_tapSendsClicked() {
        const row = show([{}])

        mouseClick(row)

        compare(clicks.count, 1)
    }

    // Long enough for the book menu; letting go after it isn't a tap as well
    function test_holdSendsHeldNotClicked() {
        const row = show([{holdable: true}])

        mousePress(row)
        tryCompare(holds, "count", 1, 2000)
        mouseRelease(row)

        compare(clicks.count, 0)
    }

    // A row with nothing to hold for still opens however long the finger stays
    function test_holdingARowThatCantBeHeldIsATap() {
        const row = show([{}])

        mousePress(row)
        wait(1000)
        mouseRelease(row)

        compare(holds.count, 0)
        compare(clicks.count, 1)
    }

    function test_untappableRowIgnoresTaps() {
        const row = show([{tappable: false, holdable: true}])

        mouseClick(row)
        mousePress(row)
        wait(1000)
        mouseRelease(row)

        compare(clicks.count, 0)
        compare(holds.count, 0)
    }

    function cleanup() {
        textSettings(100)
    }

    // As in the system library: the text grows and the row with it, keeping its lines in
    // order and apart; the cover keeps its size
    function test_growsWithTheSystemTextSize() {
        const row = show([{subtitle: "Frank Herbert", details: ["Completed", "Dune - 1"]}])
        const height = row.height
        const coverHeight = row.coverHeight

        textSettings(200)

        verify(row.height > 1.5 * height, "taller: " + row.height + " from " + height)
        compare(row.coverHeight, coverHeight)
        const title = find("title", row), author = find("author", row), status = find("status", row)
        verify(title.y + title.height <= author.y + 1, "the title above the second line")
        verify(author.y + author.height <= status.y + 1, "the second line above the details")
        verify(status.y + status.height <= row.height, "the details inside the row")
    }
}
