import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// The jump rail on its own, beside a plain list of 20-high rows. Which sections a view gives
// it is tested with that view.
UiTestCase {
    id: test
    name: "JumpRail"

    Component {
        id: listWithRail
        Item {
            property alias list: list
            property alias rail: rail
            property int rows: 100
            width: 400
            height: 600

            ListView {
                id: list
                width: parent.width
                height: parent.height
                model: parent.rows
                delegate: Item { width: 1; height: 20 }
                // Called by the rail after a jump, as the app's lists load the rows they show
                function loadVisibleBooks() {}
            }
            JumpRail {
                id: rail
                list: list
            }
        }
    }

    function make(properties) {
        root = createTemporaryObject(listWithRail, test, properties || {})
        verify(root)
        return root.rail
    }

    function labels(rail) {
        return rail.entries.map(entry => entry.label).join(" ")
    }

    // Taps the entry with this label
    function tapEntry(rail, label) {
        const i = rail.entries.findIndex(entry => entry.label === label)
        verify(i >= 0, "no entry " + label)
        mouseClick(rail, rail.width / 2, rail.entriesTop + (i + 0.5) * rail.pitch)
    }

    function firstRowShown() {
        return root.list.indexAt(0, root.list.contentY)
    }

    // Every letter shows, and only those with books lead anywhere
    function test_lettersShowTheWholeAlphabet() {
        const rail = make()
        rail.sections = [{label: "A", index: 0}, {label: "C", index: 10}]

        compare(labels(rail), "# A B C D E F G H I J K L M N O P Q R S T U V W X Y Z")
        compare(rail.entries[1].index, 0)
        compare(rail.entries[2].index, undefined)
        compare(rail.entries[3].index, 10)
    }

    function test_descendingLettersRunZToA() {
        const rail = make()
        rail.sections = [{label: "A", index: 50}, {label: "Z", index: 0}]
        rail.descending = true

        compare(labels(rail), "Z Y X W V U T S R Q P O N M L K J I H G F E D C B A #")
        compare(rail.entries[0].index, 0)
    }

    // A book numbered 2.5 counts under 2, and a missing number is greyed
    function test_seriesNumbersThatFitAreAllShown() {
        const rail = make()
        rail.alphabetical = false
        rail.sections = [{label: "1", index: 0}, {label: "2.5", index: 1}, {label: "4", index: 2}]

        compare(labels(rail), "1 2 3 4")
        compare(rail.entries[1].index, 1)
        compare(rail.entries[2].index, undefined)
    }

    // Too many numbers for the rail: the first and last, round steps between, and a dot for
    // each gap that leads to its first book
    function test_longSeriesShowsRoundSteps() {
        const sections = []
        for (let n = 1; n <= 100; n++)
            sections.push({label: String(n), index: n - 1})
        // A short rail, 28 entries at most
        const rail = make({height: 214})
        rail.alphabetical = false
        rail.sections = sections

        compare(labels(rail), "1 • 10 • 20 • 30 • 40 • 50 • 60 • 70 • 80 • 90 • 100")
        compare(rail.entries[1].index, 1, "the dot after 1 leads to book 2")
        compare(rail.entries[2].index, 9, "10 leads to book 10")
    }

    function test_reversedSeriesNumbersCountDown() {
        const rail = make()
        rail.alphabetical = false
        rail.descending = true
        rail.sections = [{label: "3", index: 0}, {label: "2", index: 1}, {label: "1", index: 2}]

        compare(labels(rail), "3 2 1")
    }

    function test_hiddenWithoutSections() {
        const rail = make()
        verify(!rail.visible)
    }

    function test_hiddenBelowMinSections() {
        const rail = make()
        rail.minSections = 3
        rail.sections = [{label: "A", index: 0}, {label: "B", index: 5}]
        verify(!rail.visible, "two sections aren't enough")

        rail.sections = rail.sections.concat([{label: "C", index: 10}])
        verify(rail.visible, "three are")
    }

    // Nothing to jump to when every row is already on screen
    function test_hiddenWhenTheListFitsOnScreen() {
        const rail = make({rows: 10})
        rail.sections = [{label: "A", index: 0}, {label: "B", index: 5}]
        verify(!rail.visible)
    }

    function test_tappingALetterJumpsToItsSection() {
        const rail = make()
        rail.sections = [{label: "A", index: 0}, {label: "M", index: 40}]

        tapEntry(rail, "M")

        tryVerify(() => firstRowShown() === 40, 5000, "row 40 is at the top")
    }

    function test_tappingAnEmptyLetterStaysPut() {
        const rail = make()
        rail.sections = [{label: "A", index: 0}, {label: "M", index: 40}]

        tapEntry(rail, "B")

        compare(firstRowShown(), 0)
    }

    function test_tappingTheFirstSectionGoesBackToTheTop() {
        const rail = make()
        rail.sections = [{label: "A", index: 0}, {label: "M", index: 40}]
        tapEntry(rail, "M")
        tryVerify(() => firstRowShown() === 40, 5000, "row 40 is at the top")

        tapEntry(rail, "A")

        tryCompare(root.list, "contentY", 0)
    }
}
