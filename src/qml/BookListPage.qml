import QtQuick

// A list of books as the library shows them, used for the library, an author's, series' or
// collection's books, and the search results: BookRows loaded on scroll, in the ListPage
// frame. The owner says what a tap or hold does.
ListPage {
    id: page

    signal bookClicked(var book)
    signal bookHeld(BookRow row)

    delegate: BookRow {
        id: row
        required book
        onClicked: page.bookClicked(book)
        onHeld: page.bookHeld(row)
    }
}
