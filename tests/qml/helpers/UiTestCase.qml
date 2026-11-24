import QtQuick
import QtTest

// A TestCase that taps and types on items found by objectName under root. A TestCase is
// invisible unless told otherwise, and an invisible item gets no mouse events.
TestCase {
    when: windowShown
    visible: true
    width: 600
    height: 800

    // Where find() looks
    property var root

    // The item with this objectName under root, or under another item. findChild() follows
    // object parents, which miss some delegates (a Repeater's in a Row), so visual children
    // are searched too.
    function find(name, under) {
        const item = findChild(under || root, name) || findVisual(under || root, name)
        verify(item, "no item named " + name)
        return item
    }

    function findVisual(item, name) {
        // A Window's items are under its contentItem
        for (const child of item.contentItem ? [item.contentItem] : item.children || []) {
            if (child.objectName === name)
                return child
            const found = findVisual(child, name)
            if (found)
                return found
        }
        return null
    }

    // Waits for the item's row or column to be laid out first. Something that has just
    // opened or changed, such as a menu or a dialog's buttons, has its items all at the same
    // place until the next frame, and a tap then lands on the last one.
    function tap(name, under) {
        const item = find(name, under)
        waitForItemPolished(item.parent)
        mouseClick(item)
    }

    // The text items under root, or under another item, that show exactly this text on
    // screen: visible, and inside the window and any list they're in. Matches the text as
    // set, so a button drawn in capitals is still "Download". text can be a RegExp, for
    // text that changes, e.g. /^Downloading /.
    function textItems(text, under) {
        const start = under || root
        const window = root.contentItem || root
        const matches = (shown) => typeof text === "string" ? shown === text : text.test(shown)
        const found = []
        const walk = (item) => {
            if (!item.visible)
                return
            if (item.font !== undefined && typeof item.text === "string" && matches(item.text)
                    && onScreen(item, window))
                found.push(item)
            for (const child of item.children || [])
                walk(child)
        }
        walk(start.contentItem || start)
        return found
    }

    // Whether any of the item shows inside the window and each list it's in
    function onScreen(item, window) {
        const overlaps = (area) => {
            const at = item.mapToItem(area, 0, 0)
            return at.x < area.width && at.x + item.width > 0 && at.y < area.height && at.y + item.height > 0
        }
        if (!overlaps(window))
            return false
        for (let above = item.parent; above && above !== window; above = above.parent) {
            if (above.contentY !== undefined && !overlaps(above))
                return false
        }
        return true
    }

    // Waits for the text to show
    function expectText(text, under) {
        tryVerify(() => textItems(text, under).length > 0, 5000, "\"" + text + "\" shows")
    }

    // Waits for the text to go, if it shows
    function expectNoText(text, under) {
        tryVerify(() => textItems(text, under).length === 0, 5000, "\"" + text + "\" doesn't show")
    }

    // Taps the one place the text shows, e.g. a dialog's "Download" or a menu's "Delete".
    // Waits for it to show, and for what it's in to be laid out, as tap() does.
    function tapText(text, under) {
        expectText(text, under)
        const items = textItems(text, under)
        verify(items.length === 1, "\"" + text + "\" shows " + items.length + " times")
        for (let above = items[0].parent; above; above = above.parent)
            waitForItemPolished(above)
        mouseClick(items[0])
    }

    // Taps the field and types into it, a key at a time
    function type(name, text) {
        tap(name)
        for (const c of text)
            keyClick(c)
    }

    // The system's text settings (Settings > Accessibility), as if just changed: size 100 to
    // 200 (percent), bold text and grey text contrast. A test that sets them puts them back
    // with textSettings(100) in its cleanup().
    function textSettings(scale, bold, contrast) {
        inkview.setTextSettings(scale, bold === true, contrast === true)
        accessibility.reload()
    }

    function signIn(server, username, password) {
        type("serverField", server)
        type("usernameField", username)
        type("passwordField", password)
        tap("signInButton")
    }
}
