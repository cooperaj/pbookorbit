import QtQuick
import "../helpers"

// Signing in to a BookOrbit server, staying signed in when the app starts again, and
// signing out. The on-screen keyboard (keyboard) covers the bottom of the screen while a
// field has it, and Enter on it moves to the next field, then signs in.
AppTestCase {
    name: "SigningIn"

    readonly property string login: "/api/v1/auth/login"
    readonly property string refresh: "/api/v1/auth/refresh"

    // A field's bottom edge in the window
    function bottomOf(name) {
        const field = find(name)
        return field.mapToItem(null, 0, field.height).y
    }

    // Waits for the keyboard, and checks the field shows above it
    function expectAboveTheKeyboard(name) {
        tryVerify(() => keyboard.visible, 5000, "the keyboard is up")
        tryVerify(() => bottomOf(name) <= keyboard.rect.y, 5000,
                  name + " is above the keyboard: " + bottomOf(name) + " > " + keyboard.rect.y)
    }

    // Types into the focused field a key at a time, then presses the keyboard's Enter
    function enter(text) {
        for (const c of text)
            keyClick(c)
        keyClick(Qt.Key_Return)
    }

    function signOut() {
        tap("menuButton")
        tapText("Sign out")
    }

    // The form moves up so the field being typed in shows above the keyboard
    function test_aUserCanSignInAndSeeTheirLibrary() {
        open()
        fakeServer.respond("POST", login, 200, "auth/login-success.json")
        serveLibrary()
        expectText("Sign in")
        const passwordAtFirst = bottomOf("passwordField")

        tap("serverField")
        expectAboveTheKeyboard("serverField")
        enter(fakeServer.url)
        expectAboveTheKeyboard("usernameField")
        enter("reader")
        expectAboveTheKeyboard("passwordField")
        verify(passwordAtFirst > keyboard.rect.y, "where it was, the keyboard would cover it")
        enter("right")

        expectText("Dune")
        verify(!find("loginPage").visible, "the sign-in page goes")
        verify(!keyboard.visible, "the keyboard goes")
        compare(fakeServer.requests[0].body.username, "reader", "the server is sent the username")
        compare(fakeServer.requests[0].body.password, "right", "and the password")

        fakeServer.respond("POST", refresh, 200, "auth/refresh-success.json")
        reopen()
        expectText("Dune")
        verify(!find("loginPage").visible, "still signed in")
    }

    // The password is cleared for the next try
    function test_aWrongPasswordCanBeTriedAgain() {
        open()
        fakeServer.respond("POST", login, 401, "auth/login-invalid.json")

        signIn(fakeServer.url, "reader", "wrong")

        expectText("Invalid credentials (HTTP 401)")
        verify(find("loginPage").visible, "the sign-in page stays")
        compare(find("passwordField").text, "")

        fakeServer.respond("POST", login, 200, "auth/login-success.json")
        serveLibrary()
        type("passwordField", "right")
        tapText("Sign in")

        expectText("Dune")
    }

    // Signing out ends the session on the server, and keeps the server and username to sign
    // in again with the password
    function test_signingOutKeepsTheServerAndUsername() {
        openLibrary()
        expectText("Dune")

        signOut()

        verify(find("loginPage").visible, "the sign-in page shows")
        expectNoText("Sign out")
        tryVerify(() => fakeServer.requests.some(r => r.path === "/api/v1/auth/logout"), 5000,
                  "the session is ended on the server")
        expectText(fakeServer.url)
        verify(!find("serverField").visible, "the server isn't asked for")
        compare(find("usernameField").text, "reader")
        compare(find("passwordField").text, "")

        reopen()
        verify(find("loginPage").visible, "still signed out")
    }

    // https:// is assumed, so only http:// shows
    function test_aSavedServerShowsWithoutHttps() {
        open({serverUrl: "https://books.example.com", username: "reader"})

        expectText("books.example.com")
    }

    // The saved server's cross forgets it for good, and asks for a server again
    function test_aUserCanSignInToAnotherServer() {
        open({serverUrl: "https://books.example.com", username: "reader"})
        fakeServer.respond("POST", login, 200, "auth/login-success.json")
        serveLibrary()

        tap("forgetServer")

        expectNoText("books.example.com")
        verify(find("serverField").visible, "the server is asked for")
        compare(find("usernameField").text, "reader", "the username stays")
        reopen()
        expectNoText("books.example.com")
        verify(find("serverField").visible, "still asked for")

        type("serverField", fakeServer.url)
        type("passwordField", "right")
        tapText("Sign in")

        expectText("Dune")
        compare(fakeServer.requests[0].path, login, "signed in on the new server")
    }

    // Signs out while the session's refresh is on its way, then lets the server answer it
    function signOutWhileRefreshing(status, fixture) {
        fakeServer.hold("POST", refresh)
        openLibrary()
        // After openLibrary's, so it's the one that answers
        fakeServer.respond("POST", refresh, status, fixture)
        signOut()

        fakeServer.release("POST", refresh)
        tryVerify(() => !bookOrbit.session.busy, 5000, "the refresh's reply is handled")
    }

    // A refresh still on its way when the user signs out doesn't sign them back in
    function test_signingOutAsTheAppStartsStaysSignedOut() {
        signOutWhileRefreshing(200, "auth/refresh-success.json")

        verify(find("loginPage").visible, "still signed out")
        compare(find("errorText").text, "", "no error")
    }

    // Nor, if the session had expired, tell them so after they've signed out anyway
    function test_signingOutAsTheAppStartsSaysNothingOfAnExpiredSession() {
        signOutWhileRefreshing(401, "auth/login-invalid.json")

        verify(find("loginPage").visible, "still signed out")
        compare(find("errorText").text, "", "no error")
    }

    // Books downloaded before signing out don't change that; they open from the device's own
    // library
    function test_signingInWithoutANetworkOffersToConnect() {
        open({serverUrl: fakeServer.url, username: "reader"},
             {offline: true, books: [{id: 1, title: "Downloaded Book", authors: ["A. Writer"],
                                      formats: ["epub"], file: "downloaded.epub"}]})

        expectText("Currently offline")
        expectText("Connect to Wi-Fi to sign in to BookOrbit.")
        verify(!find("signInForm").visible, "the form is hidden")
        verify(!find("bookList").visible, "the library is hidden")

        testApp.offline = false
        tapText("Connect")

        tryVerify(() => find("signInForm").visible, 5000, "the form shows again")
        expectNoText("Currently offline")
    }

    // Wi-Fi going between opening the app and signing in
    function test_losingTheNetworkBeforeSigningInOffersToConnect() {
        open()
        testApp.offline = true

        signIn(fakeServer.url, "reader", "right")

        expectText("Currently offline")
        verify(!find("signInForm").visible, "the form is hidden")
    }

    // With the network up, no reply is the server's problem, so the form stays to try again
    function test_aServerThatDoesntReplyKeepsTheFormToTryAgain() {
        open()
        fakeServer.reachable = false

        signIn(fakeServer.url, "reader", "right")

        expectText("The server didn't reply")
        verify(find("signInForm").visible, "the form stays")
        expectNoText("Currently offline")
    }
}
