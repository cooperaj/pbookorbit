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
    SignalSpy { id: libraryChosen; signalName: "libraryChosen" }

    property var query

    function make(options) {
        testApp.reset({}, options || {})
        query = createTemporaryObject(listQuery, test)
        verify(query)
        applied.target = query
        applied.clear()
        libraryChosen.target = query
        libraryChosen.clear()
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
        query.showContent("ebook", true)
        query.chooseLibrary(-1)

        compare(applied.count, 0)
        compare(libraryChosen.count, 0)
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

    // Both content types is no filter
    function test_bothContentTypesToStartWith() {
        make()

        verify(query.ebooks && query.audiobooks, "both")
        compare(query.filterName, "All titles")
        compare(query.formats, [])
        compare(query.contentNoun, "books")
    }

    function test_justEbooks() {
        make()

        query.showContent("audiobook", false)

        compare(query.filterName, "Ebooks")
        compare(query.contentNoun, "ebooks")
        verify(query.formats.indexOf("epub") >= 0, "ebook formats")
        verify(query.formats.indexOf("cbz") >= 0, "comics too")
        verify(query.formats.indexOf("m4b") < 0, "not audiobook ones")
        compare(applied.count, 1)
    }

    function test_justAudiobooks() {
        make()

        query.showContent("ebook", false)

        compare(query.filterName, "Audiobooks")
        compare(query.contentNoun, "audiobooks")
        verify(query.formats.indexOf("m4b") >= 0, "audiobook formats")
        verify(query.formats.indexOf("epub") < 0, "not ebook ones")
    }

    // Something is always shown
    function test_theLastContentTypeStays() {
        make()
        query.showContent("ebook", false)

        query.showContent("audiobook", false)

        verify(query.audiobooks, "audiobooks stay")
        compare(applied.count, 1, "only the first changed anything")
    }

    function test_bothAgain() {
        make()
        query.showContent("ebook", false)

        query.showContent("ebook", true)

        compare(query.filterName, "All titles")
        compare(query.formats, [])
    }

    // Choosing a library is the view's to act on
    function test_choosingALibrary() {
        make()

        query.chooseLibrary(2)

        compare(libraryChosen.count, 1)
        compare(libraryChosen.signalArguments[0][0], 2)
        compare(applied.count, 0)
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
