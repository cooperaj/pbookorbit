import QtQuick

// The chevron at the right of a tappable info field or cell: the toolbar's back chevron
// turned to point right, since the theme has no forward one this size. Its padding keeps
// it off the edge. Its back_inv is a disc, so the pressed state inverts the plain one.
ThemeIcon {
    name: "back"
    mirror: true
}
