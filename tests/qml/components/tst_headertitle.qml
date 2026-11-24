import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// A toolbar's title as the firmware's Qt apps show it: centred while it fits, and a longer
// one starting at the left and fading out at its right end, with no "…".
UiTestCase {
    id: test
    name: "HeaderTitle"

    Component {
        id: headerTitle
        HeaderTitle { width: 200 }
    }

    function make(text) {
        root = createTemporaryObject(headerTitle, test, {text: text})
        verify(root)
        return root
    }

    function test_centredWhileItFits() {
        const title = make("Series")

        verify(!title.overflows)
        compare(title.horizontalAlignment, Text.AlignHCenter)
    }

    function test_longTitleStartsAtTheLeftAndFades() {
        const title = make("Book info / The Hitchhiker's Guide to the Galaxy")

        verify(title.overflows)
        compare(title.horizontalAlignment, Text.AlignLeft)
        compare(title.elide, Text.ElideNone, "no …")
        verify(title.clip, "cut off at its edge")
        const fade = find("titleFade", title)
        compare(fade.x + fade.width, title.width, "the fade at its right end")
    }
}
