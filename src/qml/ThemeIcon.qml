import QtQuick

// A system theme icon (see ThemeImageProvider), at natural size unless sized, e.g. "back".
// Inverted draws it white on black, as on a pressed row. Hidden without a name.
Image {
    property string name
    property bool inverted: false

    visible: name !== ""
    source: name === "" ? "" : "image://theme/" + name + (inverted ? "@inverted" : "")
}
