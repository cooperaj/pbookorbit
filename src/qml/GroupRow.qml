import QtQuick
import "format.js" as Format

// One collection or series in the Collections or Series list, laid out like BookRow (see
// ListRow): a stack of two covers (the second smaller and behind), then the name, then the
// authors by surname (elided) with their formats at the right, then the book count. Tapping
// sends clicked().
//
// An author row (Authors list) shows their photo, or initials if there's none
// (AuthorPortrait), their name, their books' formats, and book and series counts, e.g. "6
// books | 2 series".
ListRow {
    id: row
    // A row from bookOrbit.collections, seriesList or authorsList
    property var group

    readonly property bool isAuthor: group.kind === "author"
    readonly property var stackBooks: group.covers || []
    readonly property int books: group.bookCount || 0
    // An author's series, once their books have loaded
    readonly property int series: isAuthor && group.seriesCount !== undefined ? group.seriesCount : 0

    title: group.name || ""
    subtitle: (group.authors || []).join(", ")
    details: [Format.count(books, "book"), series > 0 ? series + " series" : ""]
    formats: group.formats || []
    sectionStart: group.sectionStart === true
    sectionLabel: group.sectionLabel || ""

    picture: Item {
        anchors.fill: parent

        // Behind, smaller, in the top right corner
        Cover {
            objectName: "backCover"
            visible: row.stackBooks.length > 1
            x: row.coverWidth - width
            width: Math.round(row.coverWidth * 0.74)
            height: Math.round(row.coverHeight * 0.74)
            corner: "topRight"
            book: row.stackBooks.length > 1 ? row.stackBooks[1] : ({})
        }
        // In front, in the bottom left corner, with a white edge over the one behind. Opaque,
        // to hide it.
        Cover {
            objectName: "frontCover"
            visible: row.stackBooks.length > 0
            y: row.coverHeight - height
            width: Math.round(row.coverWidth * 0.86)
            height: Math.round(row.coverHeight * 0.86)
            corner: "bottomLeft"
            edge: 2
            book: row.stackBooks.length > 0 ? row.stackBooks[0] : ({})
        }
        // No covers (yet): an outline in their place
        Rectangle {
            objectName: "noCovers"
            anchors.fill: parent
            visible: row.stackBooks.length === 0 && !row.isAuthor
            border.width: 1
            border.color: "#cccccc"
        }

        // Author photo or initials, 3:4, as wide as a cover, centred
        AuthorPortrait {
            objectName: "portrait"
            visible: row.isAuthor
            anchors.centerIn: parent
            width: row.coverWidth
            height: Math.round(row.coverWidth * 4 / 3)
            author: row.isAuthor ? row.group : ({})
        }
    }
}
