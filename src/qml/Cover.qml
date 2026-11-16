import QtQuick

// A book's cover, made for the item's size (covers.source() scales it to fit, see
// CoversImage). Until it arrives, or if the book has none, the system's blank book fills
// the item. The image sits in the middle, or in a corner of the item.
Item {
    id: cover
    // {id, coverVersion} and, for list entries, hasCover
    property var book: ({})
    // The blank book (see CoverPlaceholder)
    property alias placeholder: placeholder.name
    // "", or "bottomLeft" or "topRight" to put the image in that corner
    property string corner: ""
    // A white edge this wide around the image (or the blank book), to separate it from
    // what's behind
    property int edge: 0
    property alias asynchronous: image.asynchronous
    readonly property bool ready: image.status === Image.Ready

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
    CoversImage {
        id: image
        objectName: "image"
        itemId: cover.book.id !== undefined && cover.book.hasCover !== false ? cover.book.id : -1
        version: cover.book.coverVersion || ""
        fetchWidth: cover.width
        fetchHeight: cover.height
        width: Math.min(implicitWidth, cover.width)
        height: Math.min(implicitHeight, cover.height)
        x: cover.corner === "bottomLeft" ? 0
           : cover.corner === "topRight" ? cover.width - width : Math.round((cover.width - width) / 2)
        y: cover.corner === "bottomLeft" ? cover.height - height
           : cover.corner === "topRight" ? 0 : Math.round((cover.height - height) / 2)
        fillMode: Image.PreserveAspectFit
    }
}
