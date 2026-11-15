import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// One book in a list, as the library, search and an author's or series' books show it:
// what it shows of a book, which rows can be opened, and which formats are on the device.
// The row itself is tested in tst_listrow.qml. Each test lists hand-made books; what a tap
// or a hold then does is up to each view.
UiTestCase {
    id: test
    name: "BookRow"

    // Books 2 (an epub) and 3 (an audiobook) are downloaded
    readonly property var downloaded: [
        {id: 2, title: "On Device", authors: ["A. Writer"], file: "on-device.epub"},
        {id: 3, title: "Heard", authors: ["A. Writer"], file: "heard.m4b"},
    ]

    Component {
        id: bookList
        ListView {
            property var books: []
            width: 600
            height: 400
            model: books
            delegate: BookRow {
                required property var modelData
                book: modelData
            }
        }
    }

    SignalSpy { id: clicks; signalName: "clicked" }
    SignalSpy { id: holds; signalName: "held" }

    function init() {
        testApp.reset({}, {books: downloaded})
        clicks.clear()
        holds.clear()
    }

    // A loaded book with every field a row reads, as the client gives them
    function book(fields) {
        return Object.assign({
            loaded: true, id: 1, title: "A Book", authors: ["A. Writer"], statusText: "",
            seriesText: "", hasCover: false, coverVersion: "", sectionStart: false,
            sectionLabel: "", variants: [], formats: ["epub"], hidden: false,
        }, fields)
    }

    // Lists the books, and returns the first row, watched by clicks and holds
    function show(books) {
        root = createTemporaryObject(bookList, test, {books: books})
        verify(root)
        waitForRendering(root)
        const row = root.itemAtIndex(0)
        clicks.target = row
        holds.target = row
        return row
    }

    function test_showsTitleAuthorsStatusAndSeries() {
        const row = show([book({title: "Dune", authors: ["Frank Herbert", "Brian Herbert"],
                                statusText: "Completed", seriesText: "Dune - 1"})])

        compare(find("title", row).text, "Dune")
        compare(find("author", row).text, "Frank Herbert, Brian Herbert")
        compare(find("status", row).text, "Completed")
        compare(find("series", row).text, "Dune - 1")
        verify(find("separator", row).visible, "a bar between status and series")
    }

    // A blank row waiting for its page can't be opened
    function test_placeholderIgnoresTapsAndHolds() {
        const row = show([book({loaded: false, id: -1, title: ""})])

        mouseClick(row)
        mousePress(row)
        wait(1000)
        mouseRelease(row)

        compare(clicks.count, 0)
        compare(holds.count, 0)
    }

    // An audiobook record whose ebook row stands in for it
    function test_hiddenRowTakesNoSpace() {
        const row = show([book({hidden: true}), book({id: 4})])

        compare(row.height, 0)
        verify(!row.visible)
    }

    // Its downloads say which formats are on the device
    function test_downloadedFormatsAreOnTheDevice() {
        const row = show([book({id: 2, formats: ["epub", "pdf"]})])

        verify(find("onDevicePill", find("format epub", row)).visible, "the epub is on the device")
        verify(!find("onDevicePill", find("format pdf", row)).visible, "the pdf isn't")
    }

    // An ebook row that also stands for its audiobook record counts that one's downloads
    function test_pairedRowShowsTheAudiobookOnDevice() {
        const row = show([book({id: 1, formats: ["epub", "m4b"], variants: [{bookId: 1}, {bookId: 3}]})])

        verify(!find("onDevicePill", find("format epub", row)).visible, "the ebook isn't on the device")
        verify(find("onDevicePill", find("format m4b", row)).visible, "the audiobook is")
    }
}
