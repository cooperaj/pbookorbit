import QtQuick
import "night.js" as Night

// A book's cover, fetched at the item's size (covers.source() scales it to fit) and fetched
// again once its download arrives. Until then, or if the book has none, the system's blank
// book fills the item. The image sits in the middle, or in a corner of the item.
Item {
    id: cover
    // {id, coverVersion} and, for list entries, hasCover
    property var book: ({})
    // The blank book (see CoverPlaceholder)
    property alias placeholder: placeholder.icon
    // "", or "bottomLeft" or "topRight" to put the image in that corner
    property string corner: ""
    // A white edge this wide around the image (or the blank book), to separate it from
    // what's behind
    property int edge: 0
    property alias asynchronous: image.asynchronous
    readonly property bool ready: image.status === Image.Ready

    // Bumped when the download arrives so the URL is re-fetched. A binding rather than
    // setting the URL, so the cover follows a re-sorted list.
    property int revision: 0
    readonly property string url: revision >= 0 && book.id !== undefined && book.hasCover !== false
                                  ? covers.source(book.id, book.coverVersion, width, height) : ""
    Connections {
        target: covers
        function onReady(bookId) {
            if (bookId === cover.book.id)
                cover.revision++
        }
    }

    Rectangle {
        objectName: "edge"
        visible: cover.edge > 0
        x: (cover.ready ? image.x : 0) - cover.edge
        y: (cover.ready ? image.y : 0) - cover.edge
        width: (cover.ready ? image.width : cover.width) + 2 * cover.edge
        height: (cover.ready ? image.height : cover.height) + 2 * cover.edge
        color: "white"
    }
    CoverPlaceholder {
        id: placeholder
        objectName: "placeholder"
        visible: !cover.ready
    }
    Image {
        id: image
        objectName: "image"
        width: Math.min(implicitWidth, cover.width)
        height: Math.min(implicitHeight, cover.height)
        x: cover.corner === "bottomLeft" ? 0
           : cover.corner === "topRight" ? cover.width - width : Math.round((cover.width - width) / 2)
        y: cover.corner === "bottomLeft" ? cover.height - height
           : cover.corner === "topRight" ? 0 : Math.round((cover.height - height) / 2)
        fillMode: Image.PreserveAspectFit
        source: Night.image(cover.url)
        asynchronous: true
    }
}
