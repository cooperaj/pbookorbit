import QtQuick
import "night.js" as Night

// An author's photo filling the item (covers.authorPhoto() crops it to size, as BookOrbit
// does, see CoversImage), or if there's none their initials as BookOrbit shows them: a serif face on a
// gradient chosen by name near the accent hue (bookOrbit.authorMonogram()). The initials
// sit underneath, so they show while the photo downloads or if it fails. The caller sets
// the size; 3:4 suits most photos.
Item {
    id: portrait
    // A bookOrbit.authorsList row or bookOrbit.authorRow(): id, name, photo
    property var author: ({})

    // Recomputed when the accent changes
    readonly property var monogram: bookOrbit.accentColor, bookOrbit.authorMonogram(author.name || "")

    // Gradient from top left to bottom right, like CSS's 135deg: a square with a vertical
    // gradient, rotated so its ends just reach those corners
    Item {
        anchors.fill: parent
        clip: true
        Rectangle {
            anchors.centerIn: parent
            width: (portrait.width + portrait.height) / Math.SQRT2
            height: width
            rotation: -45
            gradient: Gradient {
                GradientStop { position: 0; color: Night.color(portrait.monogram.from) }
                GradientStop { position: 1; color: Night.color(portrait.monogram.to) }
            }
        }
    }
    Text {
        anchors.centerIn: parent
        text: portrait.monogram.initials
        color: Night.color(portrait.monogram.color)
        // 36% of the width, as in BookOrbit
        font.family: "PT Serif"
        font.bold: true
        font.pixelSize: Math.max(1, Math.round(portrait.width * 0.36))
    }

    CoversImage {
        anchors.fill: parent
        photo: true
        itemId: (portrait.author.photo || "") !== "" ? portrait.author.id : -1
        version: portrait.author.photo || ""
    }
}
