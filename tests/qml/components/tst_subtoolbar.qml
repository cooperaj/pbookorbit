import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// The bar of filter and sort buttons over a list. It shows its query's sort and filter and
// says what was tapped; each view decides what that does.
UiTestCase {
    id: test
    name: "SubToolbar"

    Component {
        id: subToolbar
        SubToolbar {
            width: 600
        }
    }
    Component {
        id: listQuery
        ListQuery {
            sorts: [
                { name: "Title", field: "title", descending: false },
                { name: "Author", field: "author", descending: false }
            ]
        }
    }

    SignalSpy { id: filterTaps; signalName: "filterClicked" }
    SignalSpy { id: sortTaps; signalName: "sortClicked" }
    SignalSpy { id: iconTaps; signalName: "sortIconClicked" }

    // queryProperties set up its query, e.g. {sortIndex: 1}
    function make(properties, queryProperties) {
        const query = createTemporaryObject(listQuery, test, queryProperties || {})
        root = createTemporaryObject(subToolbar, test, Object.assign({query: query}, properties || {}))
        verify(root)
        for (const spy of [filterTaps, sortTaps, iconTaps]) {
            spy.target = root
            spy.clear()
        }
        return root
    }

    function test_showsItsLabels() {
        make({}, {audiobooks: false, sortIndex: 1})

        compare(find("filterButton").text, "Ebooks")
        compare(find("sortButton").text, "By Author")
    }

    function test_filterTapSaysSo() {
        make()

        tap("filterButton")

        compare(filterTaps.count, 1)
        compare(sortTaps.count, 0)
    }

    // The label opens the sort menu; the icon before it is the inverter
    function test_sortLabelAndIconAreSeparateButtons() {
        make()
        const sort = find("sortButton")

        mouseClick(sort, sort.width - 10, sort.height / 2)
        compare(sortTaps.count, 1, "the label opens the menu")
        compare(iconTaps.count, 0)

        tap("iconButton", sort)
        compare(iconTaps.count, 1, "the icon reverses")
        compare(sortTaps.count, 1)
    }

    function test_iconShowsTheDirection() {
        make()
        compare(find("sortButton").icon, "sorting_descending")

        root.query.reverseSort()
        compare(find("sortButton").icon, "sorting_ascending")
    }

    // Collections have no content type or library to filter by
    function test_filterCanBeLeftOut() {
        make({}, {hasContentType: false})

        verify(!find("filterButton").visible, "no filter button")
        verify(find("sortButton").visible, "the sort button")
    }

    function test_openMenuMarksItsButton() {
        make({sortOpen: true})

        verify(find("sortButton").open, "the sort button is the open tab")
        verify(!find("filterButton").open, "the filter button isn't")
    }

    // The copy drawn over the faded page while a menu is open has just that menu's tab
    function test_openTabCopyShowsOnlyTheOpenTab() {
        make({onlyOpenTab: true, sortOpen: true})

        verify(find("sortButton").visible, "the open tab")
        verify(!find("filterButton").visible, "not the other button")
        verify(!find("iconButton", find("sortButton")).visible, "not the icon button")
    }
}
