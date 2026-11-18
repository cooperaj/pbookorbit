import QtQuick
import "night.js" as Night

// A book's cover or an author's photo from covers (see Covers), made for fetchWidth x
// fetchHeight and asked for again when its download arrives. Night mode shows the
// inverted copy, so it keeps its colours. Loads in the background unless told otherwise.
Image {
    id: image
    // {id, version}: a book's id and coverVersion, or an author's id and photo URL from the
    // authors list. Set as one, so the URL is never asked for with one's id and another's
    // version while bindings update. null for none.
    property var item: null
    property bool photo: false
    // The space it's made for
    property int fetchWidth: width
    property int fetchHeight: height

    // Bumped when the download arrives, so the URL is asked for again. A binding rather
    // than setting the URL, so the image follows a re-sorted list.
    property int revision: 0
    readonly property string url: revision < 0 || !item ? ""
                                  : photo ? covers.authorPhoto(item.id, item.version, fetchWidth, fetchHeight)
                                  : covers.source(item.id, item.version, fetchWidth, fetchHeight)
    Connections {
        target: covers
        function onReady(id, photo) {
            if (image.item && id === image.item.id && photo === image.photo)
                image.revision++
        }
    }

    source: Night.image(url)
    asynchronous: true
}
