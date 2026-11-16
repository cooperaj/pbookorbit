import QtQuick
import "night.js" as Night

// A book's cover or an author's photo from covers (see Covers), made for fetchWidth x
// fetchHeight and asked for again when its download arrives. Night mode shows the
// inverted copy, so it keeps its colours. Loads in the background unless told otherwise.
Image {
    id: image
    // The book's or author's id, or -1 for none
    property int itemId: -1
    property bool photo: false
    // A cover's coverVersion, or a photo's URL from the authors list
    property string version
    // The space it's made for
    property int fetchWidth: width
    property int fetchHeight: height

    // Bumped when the download arrives, so the URL is asked for again. A binding rather
    // than setting the URL, so the image follows a re-sorted list.
    property int revision: 0
    readonly property string url: revision < 0 || itemId < 0 ? ""
                                  : photo ? covers.authorPhoto(itemId, version, fetchWidth, fetchHeight)
                                  : covers.source(itemId, version, fetchWidth, fetchHeight)
    Connections {
        target: covers
        function onReady(id, photo) {
            if (id === image.itemId && photo === image.photo)
                image.revision++
        }
    }

    source: Night.image(url)
    asynchronous: true
}
