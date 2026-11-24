import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// The frame every list page shares, on its own with plain rows: the sub-toolbar from a
// query, the error line, which rows it asks for, the spinner and empty state it's told to
// show, the rail, and what its sub-toolbar does when tapped. What a book or group row adds is tested
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
            sorts: [
                { name: "Date added", field: "addedAt", descending: true },
                { name: "Title", field: "title", descending: false }
            ]
            sortIndex: 1
        }
    }

    ListMenus { id: menus }

    SignalSpy { id: rowsWanted; signalName: "rowsWanted" }
    SignalSpy { id: scrolls; signalName: "scrollStarted" }
    SignalSpy { id: backs; signalName: "back" }
    SignalSpy { id: sortTaps; target: menus; signalName: "sortClicked" }
    SignalSpy { id: filterTaps; target: menus; signalName: "filterClicked" }

    // A page of this many rows
    function make(rows, properties) {
        root = createTemporaryObject(listPage, test, Object.assign({model: rows}, properties || {}))
        verify(root)
        for (const spy of [rowsWanted, scrolls, backs]) {
            spy.target = root
            spy.clear()
        }
        sortTaps.clear()
        filterTaps.clear()
        menus.filterOpen = false
        menus.sortOpen = false
        waitForRendering(root)
        return root
    }

    // With a query, and the menus its sub-toolbar opens
    function withQuery(properties) {
        return Object.assign({query: createTemporaryObject(query, test), menus: menus}, properties || {})
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

    // Whatever the page says about being empty
    function test_errorWithNoRowsSaysSomethingWentWrong() {
        make(0, {empty: false, error: "Internal server error (HTTP 500)"})

        const empty = find("emptyState")
        verify(empty.visible)
        compare(empty.title, "Something went wrong")
        compare(empty.text, "Internal server error (HTTP 500)")
    }

    function test_offlineText() {
        make(0)

        compare(root.offlineText(), "You're currently offline, only downloaded books can be shown.")
        compare(root.offlineText("series with downloaded books"),
                "You're currently offline, only series with downloaded books can be shown.")
        compare(root.offlineText("downloaded books", "searched"),
                "You're currently offline, only downloaded books can be searched.")
    }

    // A page opened over the views: its title in a toolbar, with a back button
    function test_titleShowsAToolbar() {
        make(3, withQuery({title: "Series / Dune"}))

        const back = find("backButton")
        verify(back.visible)
        verify(root.list.y >= back.y + back.height, "the rows and sub-toolbar below it")
        tap("backButton")
        compare(backs.count, 1)
    }

    function test_noToolbarWithoutATitle() {
        make(3)

        verify(!find("backButton").visible)
        compare(root.list.y, 0)
    }

    function test_noSubToolbarWithoutAQuery() {
        make(3)

        compare(root.list.headerItem, null)
    }

    function test_subToolbarShowsTheQuery() {
        make(3, withQuery())

        compare(find("sortButton").text, "By Title")
        compare(find("filterButton").text, "All titles")
        root.query.showContent("ebook", false)
        compare(find("filterButton").text, "Audiobooks")
        root.query.hasContentType = false
        verify(!find("filterButton").visible, "no filter when the query has none")
    }

    // Its buttons open the shared menus, which say which is open
    function test_subToolbarOpensTheMenus() {
        make(3, withQuery())

        tap("sortButton")
        tap("filterButton")

        compare(sortTaps.count, 1, "the sort")
        compare(filterTaps.count, 1, "the filter")
        menus.sortOpen = true
        verify(find("sortButton").open, "the sort tab shows open")
        verify(!find("filterButton").open)
    }

    // A new sort or filter starts at the top
    function test_queryChangeGoesBackToTheTop() {
        make(30, withQuery())
        root.list.contentY = 800
        verify(root.list.contentY > 0)

        root.query.chooseSort(0)

        compare(root.list.contentY, root.list.originY)
    }

    // The sort icon reverses the sort, without a menu
    function test_sortIconReversesTheQuery() {
        make(3, withQuery())

        tap("iconButton", find("sortButton"))

        verify(root.query.sortReversed)
        compare(sortTaps.count, 0)
    }

    ListModel { id: rowModel }
    function fillRows(count) {
        rowModel.clear()
        for (let i = 0; i < count; i++)
            rowModel.append({n: i})
    }

    // The icon changes with the rows, in one screen update, rather than in one of its own
    // that the rows wait behind
    function test_sortIconHeldUntilTheRowsChange() {
        fillRows(3)
        make(0, withQuery({model: rowModel}))
        const sort = find("sortButton")

        tap("iconButton", sort)

        verify(root.query.sortReversed)
        compare(sort.icon, "sorting_descending", "the direction before the tap")
        verify(sort.held, "the pressed look")

        fillRows(3)

        compare(sort.icon, "sorting_ascending")
        verify(!sort.held)
    }

    function test_sortIconReleasedOnError() {
        fillRows(3)
        make(0, withQuery({model: rowModel}))
        const sort = find("sortButton")

        tap("iconButton", sort)
        root.error = "Internal server error (HTTP 500)"

        compare(sort.icon, "sorting_ascending")
        verify(!sort.held)
    }

    // A list that comes back unchanged, or not at all
    function test_sortIconReleasedWithoutChange() {
        make(3, withQuery())
        const sort = find("sortButton")

        tap("iconButton", sort)
        verify(sort.held)

        tryCompare(sort, "held", false, 5000)
        compare(sort.icon, "sorting_ascending")
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

    // Rows that arrive before the page has a size still start under the sub-toolbar (the
    // cached rows at startup, on the device)
    function test_rowsBeforeASizeStartAtTheTop() {
        rowModel.clear()
        make(0, withQuery({model: rowModel, width: 0, height: 0}))

        fillRows(30)
        root.width = 600
        root.height = 800

        tryVerify(() => root.list.originY < 0, 2000, "the sub-toolbar is above the first row")
        compare(root.list.contentY, root.list.originY, "and showing")
    }
}
