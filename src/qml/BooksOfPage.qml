import QtQuick

// All books of an author or series (from the book menu) or of a collection: library rows
// under a toolbar with a back button, e.g. "SERIES / A SONG OF ICE AND FIRE". Author and
// collection books are in A-Z sections like the library; a series is in series order, each
// book under its number. There's a jump rail when the list is longer than a screen (and,
// for a series, has at least 16 books). The library's sub-toolbar sits above for filtering
// and sorting (plus series order for a series), with menus shown by main.qml. Loads on
// scroll like the library list; bookOrbit.booksOf.show() fills it.
BookListPage {
    id: page

    // "Author", "Series" or "Collection", and the name
    property string kind
    property string name
    // In series order: each book under its number, with a number rail
    readonly property bool seriesOrder: query !== null && query.sortField === "seriesIndex"
    readonly property bool downloadedOnly: query !== null && query.downloadedOnly

    title: kind + " / " + name
    listName: "booksOfList"
    model: bookOrbit.booksOf.model
    jumpSections: bookOrbit.booksOf.jumpSections
    error: bookOrbit.booksOf.error
    alphabetical: !seriesOrder
    // Short series are quick enough to scroll without one
    minSections: seriesOrder ? 16 : 1
    // Until the first page says how many there are. No books says so.
    loading: bookOrbit.booksOf.total !== 0
    empty: true
    emptyTitle: downloadedOnly ? "No downloaded books" : "No books found"
    emptyText: !downloadedOnly ? ""
               : bookOrbit.session.online ? "Turn off Downloaded only to see them all." : offlineText()
    onRowsWanted: (first, last) => bookOrbit.booksOf.load(first, last)
}
