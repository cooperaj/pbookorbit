import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// One collection, series or author in a list: what it shows of the group, and its stack of
// covers or the author's portrait. The row itself is tested in tst_listrow.qml.
UiTestCase {
    id: test
    name: "GroupRow"

    Component {
        id: groupList
        ListView {
            property var groups: []
            width: 600
            height: 400
            model: groups
            delegate: GroupRow {
                required property var modelData
                group: modelData
            }
        }
    }

    SignalSpy { id: clicks; signalName: "clicked" }

    function init() {
        testApp.reset({}, {})
    }

    // A collection or series as the client gives them, with these fields
    function group(fields) {
        return Object.assign({id: 1, name: "Space Opera", bookCount: 2, authors: ["Banks", "Reynolds"],
                              formats: ["epub", "m4b"], covers: [], sectionStart: false, sectionLabel: ""},
                             fields)
    }

    // Lists the groups, and returns the first row, watched by clicks
    function show(groups) {
        root = createTemporaryObject(groupList, test, {groups: groups})
        verify(root)
        waitForRendering(root)
        const row = root.itemAtIndex(0)
        clicks.target = row
        clicks.clear()
        return row
    }

    function test_showsNameAuthorsFormatsAndCount() {
        const row = show([group()])

        compare(find("title", row).text, "Space Opera")
        compare(find("author", row).text, "Banks, Reynolds")
        verify(find("format epub", row))
        verify(find("format m4b", row))
        compare(find("status", row).text, "2 books")
        verify(!find("series", row).visible, "no series count but an author's")
    }

    function test_oneBook() {
        const row = show([group({bookCount: 1})])

        compare(find("status", row).text, "1 book")
    }

    // An author: their portrait, and how many books and series
    function test_authorShowsBooksAndSeries() {
        const row = show([group({kind: "author", name: "Iain M. Banks", authors: undefined, bookCount: 6,
                                 seriesCount: 2})])

        compare(find("status", row).text, "6 books")
        compare(find("series", row).text, "2 series")
        verify(find("separator", row).visible)
        verify(find("portrait", row).visible)
        verify(!find("noCovers", row).visible)
    }

    // Two covers stacked, one in front of the other; an outline with none yet
    function test_coversStack() {
        const two = show([group({covers: [{id: 10}, {id: 11}]})])
        verify(find("frontCover", two).visible)
        verify(find("backCover", two).visible)
        compare(find("frontCover", two).book.id, 10, "the first in front")
        verify(!find("noCovers", two).visible)

        const one = show([group({covers: [{id: 10}]})])
        verify(find("frontCover", one).visible)
        verify(!find("backCover", one).visible)

        const none = show([group()])
        verify(find("noCovers", none).visible)
        verify(!find("frontCover", none).visible)
    }

    function test_tapSendsClicked() {
        const row = show([group()])

        mouseClick(row)

        compare(clicks.count, 1)
    }
}
