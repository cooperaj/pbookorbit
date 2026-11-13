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

    function find(name) {
        const item = findChild(root, name)
        verify(item, "no item named " + name)
        return item
    }

    function tap(name) {
        mouseClick(find(name))
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
