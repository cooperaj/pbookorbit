import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// What a page shows when it has nothing to list: the title and explanation it's given,
// anything inside it under them, a little above the middle.
UiTestCase {
    id: test
    name: "EmptyState"

    Component {
        id: emptyState
        EmptyState {
            width: 600
            height: 800
            title: "No collections"
            text: "Collections you make in BookOrbit show here."
            Rectangle {
                objectName: "button"
                width: 100
                height: 40
            }
        }
    }

    function make(properties) {
        root = createTemporaryObject(emptyState, test, properties || {})
        verify(root)
        waitForRendering(root)
        return root
    }

    function textItem(text) {
        let found = null
        const look = (item) => {
            for (const child of item.children) {
                if (child.text === text)
                    found = child
                look(child)
            }
        }
        look(root)
        verify(found, "no " + text)
        return found
    }

    function test_titleAboveTheExplanationAboveItsChildren() {
        make()
        const title = textItem("No collections").mapToItem(root, 0, 0).y
        const text = textItem("Collections you make in BookOrbit show here.").mapToItem(root, 0, 0).y
        const button = find("button").mapToItem(root, 0, 0).y

        verify(title < text && text < button)
    }

    // The middle of it all 38% of the way down
    function test_aLittleAboveTheMiddle() {
        make()
        const top = textItem("No collections").mapToItem(root, 0, 0).y
        const bottom = find("button").mapToItem(root, 0, 40).y

        fuzzyCompare((top + bottom) / 2, 800 * 0.38, 1)
    }

    function test_noExplanationLineWithoutOne() {
        make({text: ""})

        verify(!textItem("").visible)
    }
}
