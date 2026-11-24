import QtQuick
import "units.js" as Units

// Text as the firmware's apps draw it (its StyledText): a size from the type scale (see
// units.js) grown by the system's text size, the system font (OpenDyslexic if chosen),
// bold if the system's bold text is on, and lines closing up as it grows.
Text {
    // In points, from the type scale
    property real size: Units.body
    // Off for text that stays its size, like a picture: the jump rail's letters
    property bool scaled: true

    font.family: accessibility.fontFamily
    font.pointSize: scaled ? size * Units.textScale() : size
    font.bold: accessibility.boldText
    lineHeight: scaled ? Units.lineSpacing() : 1
}
