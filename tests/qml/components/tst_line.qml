import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// A 1px line across or down its parent, less its insets
UiTestCase {
    id: test
    name: "Line"

    Component {
        id: lines
        Item {
            width: 400
            height: 100
            Line { objectName: "across"; inset: 10 }
            Line { objectName: "uneven"; startInset: 5; endInset: 20 }
            Line { objectName: "down"; vertical: true; inset: 13; x: 200; color: "#7f7f7f" }
        }
    }

    function test_acrossLessItsInsets() {
        root = createTemporaryObject(lines, test)

        const across = find("across")
        compare([across.x, across.width, across.height], [10, 380, 1])
        compare(across.color, Qt.color("black"))
        const uneven = find("uneven")
        compare([uneven.x, uneven.width], [5, 375])
    }

    function test_downLessItsInsets() {
        root = createTemporaryObject(lines, test)

        const down = find("down")
        compare([down.x, down.y, down.width, down.height], [200, 13, 1, 74])
        compare(down.color, Qt.color("#7f7f7f"))
    }
}
