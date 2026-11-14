import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// The book list the library, a books-of page and the search results share, on its own with
// a plain model of books. What it shows for its rows, loading, errors and sections, which
// rows it asks for, and what it says was tapped. Which books a view lists, when it counts
// as loading or empty, and what a tap does, are tested with the view.
UiTestCase {
    id: test
    name: "BookListPage"

    Component {
        id: bookListPage
        BookListPage {
            width: 600
            height: 800
            model: ListModel { dynamicRoles: true }
            emptyTitle: "No books"
            emptyText: "Books show here."
            error: ""
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

    SignalSpy { id: bookTaps; signalName: "bookClicked" }
    SignalSpy { id: bookHolds; signalName: "bookHeld" }
    SignalSpy { id: rowsWanted; signalName: "rowsWanted" }
    SignalSpy { id: sortTaps; signalName: "sortClicked" }
    SignalSpy { id: iconTaps; signalName: "sortIconClicked" }
    SignalSpy { id: filterTaps; signalName: "filterClicked" }
    SignalSpy { id: scrolls; signalName: "scrollStarted" }

    // A page of this many books, "Book 0" on
    function make(count, properties) {
        root = createTemporaryObject(bookListPage, test, properties || {})
        verify(root)
        for (let i = 0; i < count; i++) {
            root.model.append({book: {id: i + 1, title: "Book " + i, authors: ["An Author"], formats: ["epub"],
                                      variants: [], loaded: true, hasCover: false, sectionStart: false,
                                      sectionLabel: "", statusText: "", seriesText: ""}})
        }
        for (const spy of [bookTaps, bookHolds, rowsWanted, sortTaps, iconTaps, filterTaps, scrolls]) {
            spy.target = root
            spy.clear()
        }
        waitForRendering(root)
        return root
    }

    function rowFor(title) {
        let found = null
        tryVerify(() => {
            for (let i = 0; i < root.list.count; i++) {
                const row = root.list.itemAtIndex(i)
                if (row && row.book.title === title)
                    found = row
            }
            return found !== null
        }, 2000, "a row for " + title)
        return found
    }

    function test_tappingABookSaysWhich() {
        make(3)

        mouseClick(rowFor("Book 1"))

        compare(bookTaps.count, 1)
        compare(bookTaps.signalArguments[0][0].title, "Book 1")
    }

    function test_holdingABookSaysWhichRow() {
        make(3)
        const row = rowFor("Book 2")

        row.held()

        compare(bookHolds.count, 1)
        compare(bookHolds.signalArguments[0][0], row)
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
        compare(empty.title, "No books")
        compare(empty.text, "Books show here.")
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
        const q = createTemporaryObject(query, test)
        make(3, {query: q})

        compare(find("sortButton").text, "By Title")
        compare(find("filterButton").text, "All titles")
        q.chooseFilter(2)
        compare(find("filterButton").text, "Audiobooks")
        q.hasFilter = false
        verify(!find("filterButton").visible, "no filter when the query has none")
    }

    function test_subToolbarSaysWhatWasTapped() {
        make(3, {query: createTemporaryObject(query, test)})

        tap("sortButton")
        tap("iconButton", find("sortButton"))
        tap("filterButton")

        compare(sortTaps.count, 1, "the sort")
        compare(iconTaps.count, 1, "the sort icon")
        compare(filterTaps.count, 1, "the filter")
    }

    // Books already shown stay, with the error under the sub-toolbar
    function test_errorLineOverBooks() {
        make(3, {query: createTemporaryObject(query, test), error: "Internal server error (HTTP 500)"})

        const error = find("errorLine")
        verify(error.visible)
        compare(error.text, "Internal server error (HTTP 500)")
        verify(rowFor("Book 0").visible, "the books stay")
    }

    function test_noErrorLineWhenNotWanted() {
        make(3, {query: createTemporaryObject(query, test), error: "Internal server error (HTTP 500)",
                 showErrorLine: false})

        verify(!find("errorLine").visible)
    }

    function test_noErrorLineWithoutBooks() {
        make(0, {query: createTemporaryObject(query, test), error: "Internal server error (HTTP 500)"})

        verify(!find("errorLine").visible)
    }

    function test_railShowsTheSectionsItIsGiven() {
        make(100, {jumpSections: [{label: "A", index: 0}, {label: "M", index: 50}]})

        const rail = find("jumpRail")
        verify(rail.visible)
        compare(rail.sections.map(s => s.label).join(""), "AM")

        root.jumpSections = []
        verify(!rail.visible, "none without sections")
    }

    function test_railTakesItsDirectionAndKind() {
        make(100, {descending: true, alphabetical: false, minSections: 16})

        const rail = find("jumpRail")
        verify(rail.descending)
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
