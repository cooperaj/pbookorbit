import QtQuick

// All books of an author or series (from the book menu) or of a collection: library rows
// under a toolbar with a back button, e.g. "SERIES / A SONG OF ICE AND FIRE". Author and
// collection books are in A-Z sections like the library; a series is in series order, each
// book under its number. There's a jump rail when the list is longer than a screen (and,
// for a series, has at least 16 books). The library's sub-toolbar sits above for filtering
// and sorting (plus series order for a series), with menus shown by main.qml. Loads on
// scroll like the library list; bookOrbit.showBooksOf() fills it.
Rectangle {
    id: page
    // For the page-turn keys, which main.qml forwards to the front page
    readonly property alias pageButtons: books.pageButtons
    color: "white"

    // "Author", "Series" or "Collection", and the name
    property string kind
    property string name
    // Where the jump rail's entries go (see RailLayout)
    property RailLayout railLayout: null
    // Its sort and filter, for the sub-toolbar
    property ListQuery query: null
    // In series order: each book under its number, with a number rail
    property bool seriesOrder: false
    property bool downloadedOnly: false
    // The menus its sub-toolbar opens
    property ListMenus menus: null
    readonly property alias list: books.list

    signal back()
    signal bookClicked(var book)
    signal bookHeld(BookRow row)

    PageHeader {
        id: header
        width: parent.width
        title: page.kind + " / " + page.name
        onBack: page.back()
    }

    BookListPage {
        id: books
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        listName: "booksOfList"
        model: bookOrbit.booksOf
        query: page.query
        menus: page.menus
        jumpSections: bookOrbit.booksOfJumpSections
        error: bookOrbit.booksOfError
        railLayout: page.railLayout
        alphabetical: !page.seriesOrder
        // Short series are quick enough to scroll without one
        minSections: page.seriesOrder ? 16 : 1
        // Until the first page says how many there are. No books, or they failed to load,
        // says so.
        loading: bookOrbit.booksOfTotal !== 0
        empty: true
        emptyTitle: error !== "" ? "Something went wrong"
                    : page.downloadedOnly ? "No downloaded books" : "No books found"
        emptyText: error !== "" ? error
                   : !page.downloadedOnly ? ""
                   : bookOrbit.online ? "Turn off Downloaded only to see them all." : offlineText
        onRowsWanted: (first, last) => bookOrbit.loadBooksOf(first, last)
        onBookClicked: (book) => page.bookClicked(book)
        onBookHeld: (row) => page.bookHeld(row)

        // A different author or series starts at the top
        Connections {
            target: bookOrbit
            function onBooksOfChanged() {
                if (bookOrbit.booksOfTotal === -1)
                    books.list.positionViewAtBeginning()
            }
        }
    }
}
