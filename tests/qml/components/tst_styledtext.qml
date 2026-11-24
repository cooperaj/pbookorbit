import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"
import "../../../src/qml/units.js" as Units

// Text as the firmware's apps draw it, following the system's text settings: size, bold
// text, font and grey text contrast. How layouts grow with the size is tested with the
// components that grow (ListRow, PopupMenu, SubToolbar).
UiTestCase {
    id: test
    name: "StyledText"

    Component {
        id: styledText
        StyledText { text: "Dune" }
    }

    function make(properties) {
        root = createTemporaryObject(styledText, test, properties || {})
        verify(root)
        return root
    }

    function cleanup() {
        textSettings(100)
    }

    function test_sizeFromTheTypeScale() {
        compare(make().font.pointSize, Units.body)
        compare(make({size: Units.heading}).font.pointSize, Units.heading)
    }

    function test_growsWithTheSystemTextSize() {
        textSettings(200)

        compare(make({size: Units.bodySmall}).font.pointSize, 2 * Units.bodySmall)
        compare(root.lineHeight, 0.9, "lines close up a little")
    }

    // The jump rail's letters, packed into a list's height
    function test_unscaledTextKeepsItsSize() {
        textSettings(200)

        const text = make({scaled: false})

        compare(text.font.pointSize, Units.body)
        compare(text.lineHeight, 1)
    }

    function test_followsTheTextSizeAsItChanges() {
        const text = make()

        textSettings(150)

        compare(text.font.pointSize, 1.5 * Units.body)
    }

    function test_boldTextMakesAllTextBold() {
        verify(!make().font.bold)

        textSettings(100, true)

        verify(root.font.bold)
    }

    function test_systemFont() {
        compare(make().font.family, accessibility.fontFamily)
    }

    function test_greyTextIsBlackWithContrast() {
        compare(Units.grey("#808080"), "#808080")

        textSettings(100, false, true)

        compare(Units.grey("#808080"), "black")
        compare(Units.grey("#c0c0c0", "white"), "white", "on a pressed row")
    }
}
