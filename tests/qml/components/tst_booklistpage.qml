import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// What BookListPage adds to the ListPage frame: a BookRow per book, saying which was tapped
// or held. What a view does with that is tested with the view.
UiTestCase {
    id: test
    name: "BookListPage"

    Component {
        id: bookListPage
        BookListPage {
            width: 600
            height: 800
            model: ListModel { dynamicRoles: true }
        }
    }

    SignalSpy { id: bookTaps; signalName: "bookClicked" }
    SignalSpy { id: bookHolds; signalName: "bookHeld" }

    // A page of this many books, "Book 0" on
    function make(count) {
        root = createTemporaryObject(bookListPage, test)
        verify(root)
        for (let i = 0; i < count; i++) {
            root.model.append({book: {id: i + 1, title: "Book " + i, authors: ["An Author"], formats: ["epub"],
                                      variants: [], loaded: true, hasCover: false, sectionStart: false,
                                      sectionLabel: "", statusText: "", seriesText: ""}})
        }
        for (const spy of [bookTaps, bookHolds]) {
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

    // A real hold is BookRow's to test
    function test_holdingABookSaysWhichRow() {
        make(3)
        const row = rowFor("Book 2")

        row.held()

        compare(bookHolds.count, 1)
        compare(bookHolds.signalArguments[0][0], row)
    }
}
