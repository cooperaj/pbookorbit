import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// The list page the Collections, Series and Authors tabs and an author's series share, on
// its own with a plain model of groups. What it shows for its rows, loading, errors and
// sections, and what it says was tapped. Which groups a tab lists, and what a tap does,
// are tested with the tab.
UiTestCase {
    id: test
    name: "GroupsPage"

    Component {
        id: groupsPage
        GroupsPage {
            width: 600
            height: 800
            model: ListModel { dynamicRoles: true }
            sortText: "By Name"
            emptyTitle: "No groups"
            emptyText: "Groups show here."
            error: ""
            online: true
        }
    }

    SignalSpy { id: groupTaps; signalName: "groupClicked" }
    SignalSpy { id: sortTaps; signalName: "sortClicked" }
    SignalSpy { id: iconTaps; signalName: "sortIconClicked" }
    SignalSpy { id: filterTaps; signalName: "filterClicked" }

    // A page with groups named after the strings, e.g. ["Classics", "Space Opera"]
    function make(names, properties) {
        root = createTemporaryObject(groupsPage, test, properties || {})
        verify(root)
        for (const name of names || [])
            root.model.append({book: {name: name, bookCount: 1, covers: [], authors: [], formats: []}})
        for (const spy of [groupTaps, sortTaps, iconTaps, filterTaps]) {
            spy.target = root
            spy.clear()
        }
        waitForRendering(root)
        return root
    }

    function rowNamed(name) {
        let found = null
        tryVerify(() => {
            for (let i = 0; i < root.list.count; i++) {
                const row = root.list.itemAtIndex(i)
                if (row && row.group.name === name)
                    found = row
            }
            return found !== null
        }, 2000, "a row for " + name)
        return found
    }

    function test_tappingARowSaysWhichGroup() {
        make(["Classics", "Space Opera"], {loaded: true})

        mouseClick(rowNamed("Space Opera"))

        compare(groupTaps.count, 1)
        compare(groupTaps.signalArguments[0][0].name, "Space Opera")
    }

    function test_spinnerWhileLoading() {
        make([], {loaded: false})

        verify(find("spinner").visible)
        verify(!find("emptyState").visible, "not empty yet")
    }

    // Offline the rows are built from the downloads, so there's nothing to wait for
    function test_noSpinnerOffline() {
        make([], {loaded: false, online: false})

        verify(!find("spinner").visible)
    }

    function test_noRowsShowsItsEmptyState() {
        make([], {loaded: true})

        const empty = find("emptyState")
        verify(empty.visible)
        compare(empty.title, "No groups")
        compare(empty.text, "Groups show here.")
        verify(!find("spinner").visible)
    }

    function test_errorWithNoRows() {
        make([], {loaded: false, error: "Internal server error (HTTP 500)"})

        const empty = find("emptyState")
        verify(empty.visible)
        compare(empty.title, "Something went wrong")
        compare(empty.text, "Internal server error (HTTP 500)")
        verify(!find("spinner").visible, "no spinner")
        verify(!find("errorLine").visible, "no error line with nothing under it")
    }

    // Rows already shown stay, with the error above them
    function test_errorOverRows() {
        make(["Classics"], {loaded: true, error: "Internal server error (HTTP 500)"})

        const error = find("errorLine")
        verify(error.visible)
        compare(error.text, "Internal server error (HTTP 500)")
        verify(!find("emptyState").visible)
        verify(rowNamed("Classics").visible, "the rows stay")
    }

    function test_noErrorLineWithoutAnError() {
        make(["Classics"], {loaded: true})

        verify(!find("errorLine").visible)
    }

    function test_railShowsTheSectionsItIsGiven() {
        const names = []
        for (let i = 0; i < 30; i++)
            names.push(String.fromCharCode(65 + i % 26) + " group " + i)
        make(names, {loaded: true, jumpSections: [{label: "A", index: 0}, {label: "M", index: 12}]})

        const rail = find("jumpRail")
        compare(rail.sections.map(s => s.label).join(""), "AM")
        verify(rail.visible, "for a list longer than the page")

        root.jumpSections = []
        verify(!rail.visible, "and none without sections")
    }

    function test_railRunsZToAWhenDescending() {
        make(["Classics"], {loaded: true, descending: true})

        verify(find("jumpRail").descending)
    }

    function test_sortButtonsSayWhatWasTapped() {
        make(["Classics"], {loaded: true})

        tap("sortButton")
        compare(sortTaps.count, 1, "the sort")
        tap("iconButton", find("sortButton"))
        compare(iconTaps.count, 1, "the sort icon")
        compare(find("sortButton").text, "By Name")
    }

    function test_filterOnlyWhenItHasOne() {
        make(["Classics"], {loaded: true})
        verify(!find("filterButton").visible, "none by default")

        root.hasFilter = true
        root.filterText = "Audiobooks"

        verify(find("filterButton").visible)
        compare(find("filterButton").text, "Audiobooks")
        tap("filterButton")
        compare(filterTaps.count, 1)
    }
}
