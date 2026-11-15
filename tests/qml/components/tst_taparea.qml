import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// Which touches count as a tap, for anything tappable in a list or a page that scrolls:
// not a swipe that arrives as a press and a distant release, and not the finger lifting
// off a scroll. The Flickable it's in is found without being set.
UiTestCase {
    id: test
    name: "TapArea"

    // A long page with a tappable block at the top, the TapArea not told about the page
    Component {
        id: page
        Flickable {
            width: 400
            height: 300
            contentHeight: 2000
            Item {
                width: 400
                height: 80
                TapArea {
                    objectName: "area"
                    anchors.fill: parent
                }
            }
        }
    }

    SignalSpy { id: taps; signalName: "tapped" }

    function make() {
        root = createTemporaryObject(page, test)
        verify(root)
        waitForRendering(root)
        const area = find("area")
        taps.target = area
        taps.clear()
        return area
    }

    function test_tap() {
        const area = make()

        mouseClick(area, 100, 40)

        compare(taps.count, 1)
    }

    function test_findsTheFlickableItsIn() {
        compare(make().list, root)
    }

    // A swipe can arrive as a press and a distant release when the screen sends few moves
    function test_pressAndDistantReleaseIsntATap() {
        const area = make()

        mousePress(area, 100, 10)
        mouseRelease(area, 100, 60)

        compare(taps.count, 0)
    }

    // Lifting the finger off a scroll can register as a tap, so one just after is ignored
    function test_tapJustAfterScrollingIsIgnored() {
        const area = make()

        root.flick(0, -1500)
        tryVerify(() => !root.moving, 5000, "the page stops")
        root.contentY = 0
        mouseClick(area, 100, 40)
        compare(taps.count, 0, "ignored right after")

        wait(400)
        mouseClick(area, 100, 40)
        compare(taps.count, 1, "taken once it has settled")
    }
}
