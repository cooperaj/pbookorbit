import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// One view's sort and filter choices, shared by every view with a sub-toolbar. Here with
// the library's sorts: dates newest first, everything else A to Z.
UiTestCase {
    id: test
    name: "ListQuery"

    Component {
        id: listQuery
        ListQuery {
            sorts: [
                { name: "Date added", field: "addedAt", descending: true },
                { name: "Title", field: "title", descending: false },
                { name: "Author", field: "author", descending: false }
            ]
            sortIndex: 1
        }
    }

    SignalSpy { id: applied; signalName: "applied" }

    property var query

    function make(options) {
        testApp.reset({}, options || {})
        query = createTemporaryObject(listQuery, test)
        verify(query)
        applied.target = query
        applied.clear()
    }

    function test_eachSortStartsInItsOwnDirection() {
        make()
        verify(!query.descending(), "A to Z by title")

        query.chooseSort(0)

        verify(query.descending(), "newest first by date")
        verify(query.sortDescending, "sortDescending agrees")
        compare(applied.count, 1)
    }

    function test_reversingFlipsTheDirection() {
        make()

        query.reverseSort()

        verify(query.sortReversed, "reversed")
        verify(query.descending(), "Z to A")
        compare(applied.count, 1)
    }

    // A reversal belongs to the sort it was made on
    function test_anotherSortStartsUnreversed() {
        make()
        query.reverseSort()

        query.chooseSort(2)

        verify(!query.sortReversed, "not reversed")
        verify(!query.descending(), "A to Z by author")
    }

    function test_choosingWhatsChosenChangesNothing() {
        make()

        query.chooseSort(1)
        query.chooseFilter(0)

        compare(applied.count, 0)
    }

    // The chosen sort's name and field, for the sub-toolbar and the request
    function test_chosenSort() {
        make()
        compare(query.sortOptions, ["Date added", "Title", "Author"])
        compare(query.sortName, "Title")
        compare(query.sortField, "title")

        query.chooseSort(2)

        compare(query.sortName, "Author")
        compare(query.sortField, "author")
    }

    // The content type's name and the formats it stands for; all titles is no filter
    function test_chosenFilter() {
        make()
        compare(query.filterName, "All titles")
        compare(query.formats, [])

        query.chooseFilter(1)

        compare(query.filterName, "Ebooks")
        verify(query.formats.indexOf("epub") >= 0, "ebook formats")
        verify(query.formats.indexOf("cbz") >= 0, "comics too")
        verify(query.formats.indexOf("m4b") < 0, "not audiobook ones")

        query.chooseFilter(2)

        compare(query.filterName, "Audiobooks")
        verify(query.formats.indexOf("m4b") >= 0, "audiobook formats")
        verify(query.formats.indexOf("epub") < 0, "not ebook ones")
    }

    function test_choosingAFilter() {
        make()

        query.chooseFilter(2)

        compare(query.filterIndex, 2)
        compare(applied.count, 1)
    }

    function test_downloadedOnlyAsChosen() {
        make()
        verify(!query.downloadedOnly, "off to start")

        query.setDownloadedOnly(true)

        verify(query.downloadedOnly, "on as chosen")
        compare(applied.count, 1)
    }

    // Offline only downloads can show, whatever was chosen, and the choice is kept for
    // when it's back online
    function test_offlineMeansDownloadedOnlyUntilOnline() {
        make({offline: true})
        verify(query.downloadedOnly, "downloaded only offline")
        verify(!query.downloadedChosen, "though not chosen")

        testApp.offline = false
        bookOrbit.session.goOnline()

        tryVerify(() => bookOrbit.session.online, 5000, "online")
        verify(!query.downloadedOnly, "back to the choice")
    }
}
