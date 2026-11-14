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

    // The item with this objectName under root, or under another item
    function find(name, under) {
        const item = findChild(under || root, name)
        verify(item, "no item named " + name)
        return item
    }

    function tap(name, under) {
        mouseClick(find(name, under))
    }

    // A dialog's button by its label, e.g. "Download"
    function findButton(label, under) {
        const walk = (item) => {
            if (item.objectName && item.objectName.endsWith("Button") && item.modelData
                    && item.modelData[0] === label)
                return item
            for (const child of item.children) {
                const found = walk(child)
                if (found)
                    return found
            }
            return null
        }
        const button = walk(under || root)
        verify(button, "no button " + label)
        return button
    }

    // Waits for the buttons to be laid out first: a dialog that has just opened, or just
    // changed its buttons, has them all at the same place until the next frame
    function tapButton(label, under) {
        const button = findButton(label, under)
        waitForItemPolished(button.parent)
        mouseClick(button)
    }

    // Taps the field and types into it, a key at a time
    function type(name, text) {
        tap(name)
        for (const c of text)
            keyClick(c)
    }

    function signIn(server, username, password) {
        type("serverField", server)
        type("usernameField", username)
        type("passwordField", password)
        tap("signInButton")
    }
}
