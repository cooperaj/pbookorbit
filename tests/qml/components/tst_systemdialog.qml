import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// A dialog in the system's style: its heading, any extra lines and message, its buttons
// and what they say, progress, and the faded window behind it that ignores taps.
UiTestCase {
    id: test
    name: "SystemDialog"

    Component {
        id: dialog
        Item {
            width: 600
            height: 800
            property alias dialog: shown
            property int behindTaps: 0
            MouseArea {
                anchors.fill: parent
                onClicked: parent.behindTaps++
            }
            SystemDialog {
                id: shown
                anchors.fill: parent
                visible: true
                heading: "Find your books?"
                message: "There are 3 books on this device already."
                buttons: [["Find books", "search"], ["Not now", "close"]]
            }
        }
    }

    SignalSpy { id: presses; signalName: "pressed" }

    function make() {
        root = createTemporaryObject(dialog, test)
        verify(root)
        presses.target = root.dialog
        presses.clear()
        waitForRendering(root)
        return root.dialog
    }

    function test_headingAndMessage() {
        const shown = make()

        compare(find("heading").text, "Find your books?")
        verify(find("heading").font.bold)
        compare(find("message").text, "There are 3 books on this device already.")

        shown.heading = ""
        verify(!find("heading").visible, "no heading line without one")
    }

    function test_buttonsSayWhichWasPressed() {
        make()

        tap("closeButton")

        compare(presses.count, 1)
        compare(presses.signalArguments[0][0], "close")
    }

    function test_progressBarOnlyWithAPercent() {
        const shown = make()
        const bar = find("progress")
        verify(!bar.visible)

        shown.percent = 40

        verify(bar.visible)
        compare(find("progressFill").width, bar.width * 0.4)
    }

    // Only its buttons close it: taps on the faded window reach nothing behind it
    function test_fadeTakesTaps() {
        make()

        mouseClick(root, 300, 50)

        compare(root.behindTaps, 0)
        compare(presses.count, 0)
    }
}
