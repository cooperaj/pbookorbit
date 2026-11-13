import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// One book in a list, as the library, search and an author's or series' books show it.
// Each test lists hand-made books; what a tap or a hold then does is up to each view.
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
            // Called by the app's lists after a jump; rows don't need it
            function loadVisibleBooks() {}
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

    function test_noSeparatorWithoutStatus() {
        const row = show([book({seriesText: "Dune - 1"})])

        verify(!find("status", row).visible, "no status")
        verify(find("series", row).visible, "the series")
        verify(!find("separator", row).visible, "no bar")
    }

    function test_tapSendsClicked() {
        const row = show([book()])

        mouseClick(row)

        compare(clicks.count, 1)
    }

    // Long enough for the book menu; letting go after it isn't a tap as well
    function test_holdSendsHeldNotClicked() {
        const row = show([book()])

        mousePress(row)
        tryCompare(holds, "count", 1, 2000)
        mouseRelease(row)

        compare(clicks.count, 0)
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

    // Every format shows, and only those on the device are in a pill
    function test_formatsOnDeviceAreInAPill() {
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

    // Letters and series numbers in a square; longer labels, dates, in a tall box
    function test_sectionLabels() {
        const letter = show([book({sectionStart: true, sectionLabel: "D"})])
        verify(find("squareSection", letter).visible, "D in a square")
        verify(!find("dateSection", letter).visible)

        const date = show([book({sectionStart: true, sectionLabel: "12 Mar 2026"})])
        verify(find("dateSection", date).visible, "a date in a tall box")
        verify(!find("squareSection", date).visible)

        const inside = show([book({sectionStart: false, sectionLabel: "D"})])
        verify(!find("squareSection", inside).visible, "only a section's first row has a box")
        verify(!find("dateSection", inside).visible)
    }

    // Lifting the finger off a scroll can register as a tap, so one just after is ignored
    function test_tapJustAfterScrollingIsIgnored() {
        const books = []
        for (let i = 0; i < 30; i++)
            books.push(book({id: 100 + i, title: "Book " + i}))
        show(books)

        root.flick(0, -2000)
        tryVerify(() => !root.moving, 5000, "the list stops")
        const row = root.itemAtIndex(root.indexAt(10, root.contentY + 100))
        clicks.target = row
        mouseClick(row)
        compare(clicks.count, 0, "ignored right after")

        wait(400)
        mouseClick(row)
        compare(clicks.count, 1, "taken once the list has settled")
    }

    // A swipe can arrive as a press and a distant release when the screen sends few moves
    function test_pressAndDistantReleaseIsntATap() {
        const row = show([book()])

        mousePress(row, 100, 20)
        mouseRelease(row, 100, 70)

        compare(clicks.count, 0)
    }
}
