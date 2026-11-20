import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// What GroupListPage adds to the ListPage frame: a GroupRow per group, saying which was
// tapped, a spinner until the groups are loaded (not offline, where they come from the
// downloads), and the empty state once loaded with none, saying what a filter hides. Which
// groups a tab lists is tested with the tab.
UiTestCase {
    id: test
    name: "GroupListPage"

    Component {
        id: groupListPage
        GroupListPage {
            width: 600
            height: 800
            model: ListModel { dynamicRoles: true }
            emptyTitle: "No groups"
            emptyText: "Groups show here."
            online: true
        }
    }

    // A series page with the shared filter (bookOrbit.filter), with its own empty state
    Component {
        id: filteredPage
        GroupListPage {
            width: 600
            height: 800
            model: ListModel { dynamicRoles: true }
            query: ListQuery {}
            noun: "series"
            unfilteredText: "Series show here."
            offlineGroups: "series with downloaded books"
            online: true
            loaded: true
        }
    }

    SignalSpy { id: groupTaps; signalName: "groupClicked" }

    // A page with groups named after the strings, e.g. ["Classics", "Space Opera"]
    function make(names, properties, component) {
        root = createTemporaryObject(component || groupListPage, test, properties || {})
        verify(root)
        for (const name of names || [])
            root.model.append({book: {name: name, bookCount: 1, covers: [], authors: [], formats: []}})
        groupTaps.target = root
        groupTaps.clear()
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

    function test_spinnerUntilLoaded() {
        make([], {loaded: false})

        verify(find("spinner").visible)
        verify(!find("emptyState").visible, "not empty yet")
    }

    // Offline the rows are built from the downloads, so there's nothing to wait for
    function test_noSpinnerOffline() {
        make([], {loaded: false, online: false})

        verify(!find("spinner").visible)
    }

    function test_noneSaysSoOnceLoaded() {
        make([], {loaded: true})

        const empty = find("emptyState")
        verify(empty.visible)
        compare(empty.title, "No groups")
        compare(empty.text, "Groups show here.")
        verify(!find("spinner").visible)
    }

    // Filtered, the empty state says what's hidden and how to see every group
    function test_emptyFilteredSaysHowToSeeEveryGroup() {
        testApp.reset({}, {})
        make([], {}, filteredPage)
        const empty = find("emptyState")
        compare(empty.title, "No series")
        compare(empty.text, "Series show here.")

        root.query.showContent("ebook", false)

        compare(empty.title, "No series with audiobooks")
        compare(empty.text, "Tick Ebooks and Audiobooks to see every series.")

        root.query.setDownloadedOnly(true)

        compare(empty.title, "No series")
        compare(empty.text, "Turn off Downloaded only to see every series.")
    }
}
