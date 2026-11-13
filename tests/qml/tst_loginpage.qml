import QtQuick
import QtTest
import "../../src/qml"

// The sign-in form with the real BookOrbitClient behind it, talking to fakeServer. Each
// test starts signed out with an empty database.
TestCase {
    id: test
    name: "LoginPage"
    when: windowShown
    visible: true
    width: 600
    height: 800

    Component {
        id: loginPage
        LoginPage { anchors.fill: parent }
    }

    property Item page

    function init() {
        fakeServer.reset()
        testApp.reset()
        page = createTemporaryObject(loginPage, test)
        verify(page)
    }

    // Taps the field and types into it, a key at a time
    function type(name, text) {
        const field = findChild(page, name)
        mouseClick(field)
        for (const c of text)
            keyClick(c)
    }

    function signIn(username, password) {
        type("serverField", fakeServer.url)
        type("usernameField", username)
        type("passwordField", password)
        mouseClick(findChild(page, "signInButton"))
    }

    function test_wrongPasswordShowsError() {
        fakeServer.respond("POST", "/api/v1/auth/login", 401, "auth/login-invalid.json")

        signIn("reader", "wrong")

        tryCompare(findChild(page, "errorText"), "text", "Invalid credentials (HTTP 401)")
        compare(bookOrbit.signedIn, false)
        // What the server was sent
        compare(fakeServer.requests.length, 1)
        compare(fakeServer.requests[0].body.username, "reader")
        compare(fakeServer.requests[0].body.password, "wrong")
        // Cleared for the next try
        compare(findChild(page, "passwordField").text, "")
    }
}
