import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// The smallest kind of QML test: one component on its own
UiTestCase {
    id: test
    name: "PillButton"

    Component {
        id: pill
        PillButton { text: "Sign in" }
    }
    SignalSpy {
        id: clicks
        signalName: "clicked"
    }

    // A busy button shows a spinner and can't be pressed again until the work is done
    function test_busyIgnoresClicks() {
        const button = createTemporaryObject(pill, test, {busy: true})
        clicks.target = button
        mouseClick(button)
        compare(clicks.count, 0)
    }
}
