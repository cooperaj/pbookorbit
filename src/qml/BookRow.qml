import QtQuick
import "units.js" as Units
import "books.js" as Books

// One book in the list (see ListRow): cover, then title, authors, and a line with reading
// status and series. Formats show at the right of the author line (all of them when an
// ebook and audiobook share the row), in a pill if on the device. A row that another row
// stands in for (an audiobook record whose ebook row shows both) is hidden with zero
// height.
//
// Tapping sends clicked(). Holding sends held() for the book menu, which first sets
// focused to draw a thick black frame, like the focused search box.
ListRow {
    id: row
    property var book
    // Formats of this book's downloads still on the device, e.g. ["epub"]. revision
    // re-checks when a download arrives.
    formatsOnDevice: book.loaded !== true || downloads.revision < 0 ? [] : Books.formatsOnDevice(book, downloads)
    // Framed while about to open the book menu
    property bool focused: false

    title: book.title
    subtitle: book.authors.join(", ")
    details: [book.statusText, book.seriesText]
    formats: book.formats || []
    sectionStart: book.sectionStart
    sectionLabel: book.sectionLabel
    tappable: book.loaded === true
    holdable: true
    height: book.hidden === true ? 0 : rowHeight
    visible: book.hidden !== true

    picture: Cover {
        anchors.fill: parent
        book: row.book
    }

    // Focus frame, a pixel thinner than the search box's, slightly nearer the screen edges
    // than the line's start
    Rectangle {
        x: Math.round(row.lineLeft * 2 / 5)
        width: row.width - 2 * x
        height: parent.height
        visible: row.focused
        color: "transparent"
        border.width: Units.dp(2) - 1
        border.color: "black"
    }
}
