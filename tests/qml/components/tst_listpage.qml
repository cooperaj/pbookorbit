import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// The frame every list page shares, on its own with plain rows: the sub-toolbar from a
// query, the error line, which rows it asks for, the spinner and empty state it's told to
// show, the rail, and what it says was tapped. What a book or group row adds is tested
// with BookListPage and GroupListPage.
UiTestCase {
    id: test
    name: "ListPage"

    Component {
        id: listPage
        ListPage {
            width: 600
            height: 800
            model: 0
            emptyTitle: "Nothing"
            emptyText: "Things show here."
            error: ""
            delegate: Item {
                required property int index
                width: ListView.view.width
                height: 80
            }
        }
    }

    Component {
        id: query
        ListQuery {
            sortOptions: ["Date added", "Title"]
            sortFields: ["addedAt", "title"]
            sortDescendingByDefault: [true, false]
            sortIndex: 1
        }
    }

    SignalSpy { id: rowsWanted; signalName: "rowsWanted" }
    SignalSpy { id: sortTaps; signalName: "sortClicked" }
    SignalSpy { id: iconTaps; signalName: "sortIconClicked" }
    SignalSpy { id: filterTaps; signalName: "filterClicked" }
    SignalSpy { id: scrolls; signalName: "scrollStarted" }

    // A page of this many rows
    function make(rows, properties) {
        root = createTemporaryObject(listPage, test, Object.assign({model: rows}, properties || {}))
        verify(root)
        for (const spy of [rowsWanted, sortTaps, iconTaps, filterTaps, scrolls]) {
            spy.target = root
            spy.clear()
        }
        waitForRendering(root)
        return root
    }

    function withQuery(properties) {
        return Object.assign({query: createTemporaryObject(query, test)}, properties || {})
    }

    // The rows on screen and a screenful either side, once scrolling pauses
    function test_asksForTheRowsAroundTheScreen() {
        make(100)
        tryVerify(() => rowsWanted.count > 0, 2000, "rows asked for")
        const first = root.list.indexAt(1, root.list.contentY)
        const last = root.list.indexAt(1, root.list.contentY + root.list.height - 1)
        const screenful = last - first + 1
        compare(rowsWanted.signalArguments[rowsWanted.count - 1][0], first - screenful)
        compare(rowsWanted.signalArguments[rowsWanted.count - 1][1], last + screenful)

        rowsWanted.clear()
        root.pageButtons.page(1)
        tryVerify(() => rowsWanted.count > 0, 2000, "asked again after paging")
        const shown = root.list.indexAt(1, root.list.contentY)
        verify(rowsWanted.signalArguments[0][0] < shown && rowsWanted.signalArguments[0][1] > shown,
               "around the new screen")
    }

    function test_noRowsAskedForWithoutRows() {
        make(0)
        wait(300)

        compare(rowsWanted.count, 0)
    }

    function test_spinnerWhileLoading() {
        make(0, {loading: true, empty: true})

        verify(find("spinner").visible)
        verify(!find("emptyState").visible, "not empty yet")
    }

    function test_noSpinnerOnceThereAreRows() {
        make(3, {loading: true})

        verify(!find("spinner").visible)
    }

    function test_noSpinnerWithAnError() {
        make(0, {loading: true, error: "Internal server error (HTTP 500)"})

        verify(!find("spinner").visible)
    }

    function test_emptyStateSaysWhatItIsGiven() {
        make(0, {empty: true})

        const empty = find("emptyState")
        verify(empty.visible)
        compare(empty.title, "Nothing")
        compare(empty.text, "Things show here.")
    }

    function test_noEmptyStateUnlessEmpty() {
        make(0, {empty: false})

        verify(!find("emptyState").visible)
    }

    function test_noSubToolbarWithoutAQuery() {
        make(3)

        compare(root.list.headerItem, null)
    }

    function test_subToolbarShowsTheQuery() {
        make(3, withQuery())

        compare(find("sortButton").text, "By Title")
        compare(find("filterButton").text, "All titles")
        root.query.chooseFilter(2)
        compare(find("filterButton").text, "Audiobooks")
        root.query.hasFilter = false
        verify(!find("filterButton").visible, "no filter when the query has none")
    }

    function test_subToolbarSaysWhatWasTapped() {
        make(3, withQuery())

        tap("sortButton")
        tap("iconButton", find("sortButton"))
        tap("filterButton")

        compare(sortTaps.count, 1, "the sort")
        compare(iconTaps.count, 1, "the sort icon")
        compare(filterTaps.count, 1, "the filter")
    }

    // Rows already shown stay, with the error under the sub-toolbar
    function test_errorLineOverRows() {
        make(3, withQuery({error: "Internal server error (HTTP 500)"}))

        const error = find("errorLine")
        verify(error.visible)
        compare(error.text, "Internal server error (HTTP 500)")
        compare(root.list.count, 3, "the rows stay")
    }

    function test_noErrorLineWhenNotWanted() {
        make(3, withQuery({error: "Internal server error (HTTP 500)", showErrorLine: false}))

        verify(!find("errorLine").visible)
    }

    function test_noErrorLineWithoutRows() {
        make(0, withQuery({error: "Internal server error (HTTP 500)"}))

        verify(!find("errorLine").visible)
    }

    function test_noErrorLineWithoutAnError() {
        make(3, withQuery())

        verify(!find("errorLine").visible)
    }

    function test_railShowsTheSectionsItIsGiven() {
        make(100, {jumpSections: [{label: "A", index: 0}, {label: "M", index: 50}]})

        const rail = find("jumpRail")
        verify(rail.visible, "for a list longer than the page")
        compare(rail.sections.map(s => s.label).join(""), "AM")

        root.jumpSections = []
        verify(!rail.visible, "none without sections")
    }

    // Z to A when the query's sort runs that way
    function test_railFollowsTheQuerysDirection() {
        make(100, withQuery())
        const rail = find("jumpRail")
        verify(!rail.descending)

        root.query.reverseSort()

        verify(rail.descending)
    }

    function test_railTakesItsKind() {
        make(100, {alphabetical: false, minSections: 16})

        const rail = find("jumpRail")
        verify(!rail.alphabetical)
        compare(rail.minSections, 16)
    }

    function test_flickingSaysScrollingStarted() {
        make(100)

        mouseDrag(root.list, root.width / 2, root.height * 3 / 4, 0, -root.height / 2)

        tryVerify(() => scrolls.count > 0, 2000)
    }

    // The owner names them, so a view's tests can tell its lists apart
    function test_namesItsParts() {
        make(3, {listName: "myList", railName: "myRail", emptyName: "myEmpty"})

        compare(root.list.objectName, "myList")
        compare(root.rail.objectName, "myRail")
        verify(findChild(root, "myEmpty"))
    }
}
