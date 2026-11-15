import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// One field on an info page: label and value, links and tappable fields, and when its
// value shows as rich text.
UiTestCase {
    id: test
    name: "InfoField"

    Component {
        id: field
        InfoField {
            width: 400
            label: "Description"
            value: "Set on Arrakis."
        }
    }

    SignalSpy { id: clicks; signalName: "clicked" }
    SignalSpy { id: links; signalName: "linkClicked" }

    function make(properties) {
        root = createTemporaryObject(field, test, properties || {})
        verify(root)
        clicks.target = root
        links.target = root
        clicks.clear()
        links.clear()
        waitForRendering(root)
        return root
    }

    function test_hiddenWithoutAValue() {
        make({value: ""})

        verify(!root.visible)
    }

    function test_tappableFieldSendsClicked() {
        make({tappable: true})

        mouseClick(root, root.width / 2, 10)

        compare(clicks.count, 1)
    }

    function test_plainFieldIgnoresTaps() {
        make()

        mouseClick(root, root.width / 2, 10)

        compare(clicks.count, 0)
    }

    function test_linkSendsLinkClicked() {
        make({label: "Website", value: "https://example.com", link: true})

        tap("link")

        compare(links.count, 1)
    }

    // Some sources send HTML, others plain text, whose line breaks HTML would drop. Only
    // real tags make it HTML.
    function test_richTextOnlyForHtml() {
        const cases = [
            ["<p>One.</p><p>Two.</p>", Text.RichText],
            ["One.<br>Two.", Text.RichText],
            ["<i>Dune</i> begins on Arrakis.", Text.RichText],
            ["One.\nTwo.", Text.PlainText],
            ["Pick a <b and c> answer.", Text.PlainText],
            ["When x < y and y > z.", Text.PlainText],
        ]
        for (const [value, format] of cases) {
            make({value: value})
            compare(find("value").textFormat, format, value)
        }
    }
}
