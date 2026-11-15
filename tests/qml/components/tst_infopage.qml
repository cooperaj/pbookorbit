import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// The frame both info pages share, with plain blocks for content: its title and back
// button, scrolling with page buttons once the content is longer than the page, and what
// sits over it. What each page shows is tested with the book and the author.
UiTestCase {
    id: test
    name: "InfoPage"

    Component {
        id: infoPage
        InfoPage {
            property int blocks: 2
            width: 600
            height: 800
            title: "Book info / Dune"
            Repeater {
                model: blocks
                Rectangle { width: 100; height: 300 }
            }
            overlay: Rectangle {
                objectName: "over"
                width: 10
                height: 10
            }
        }
    }

    SignalSpy { id: backs; signalName: "back" }

    function make(properties) {
        root = createTemporaryObject(infoPage, test, properties || {})
        verify(root)
        backs.target = root
        backs.clear()
        waitForRendering(root)
        return root
    }

    function test_titleAndBack() {
        make()

        tap("backButton")

        compare(backs.count, 1)
    }

    // No page buttons while it all fits
    function test_noPageButtonsWhenItFits() {
        make()

        verify(!root.pageButtons.visible)
    }

    function test_longContentPages() {
        make({blocks: 6})
        const content = find("content")
        verify(root.pageButtons.visible)

        root.pageButtons.page(1)
        verify(content.contentY > 0, "down a page")

        root.scrollToTop()
        compare(content.contentY, 0)
    }

    // The overlay doesn't scroll with the content
    function test_overlayStaysPut() {
        make({blocks: 6})
        const over = find("over")
        const y = over.mapToItem(root, 0, 0).y

        root.pageButtons.page(1)

        compare(over.mapToItem(root, 0, 0).y, y)
    }
}
