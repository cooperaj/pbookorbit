import QtQuick
import QtTest
import "../../src/qml"

// The smallest kind of QML test: one component on its own. A TestCase is invisible unless
// told otherwise, and an invisible item gets no mouse events.
TestCase {
    id: test
    name: "PillButton"
    when: windowShown
    visible: true
    width: 400
    height: 200

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
