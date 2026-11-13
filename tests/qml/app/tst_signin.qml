import QtQuick
import "../helpers"

AppTestCase {
    name: "SignIn"

    function test_signingInShowsTheLibrary() {
        open()
        fakeServer.respond("POST", "/api/v1/auth/login", 200, "auth/login-success.json")
        verify(find("loginPage").visible, "the login page shows")

        signIn(fakeServer.url, "reader", "right")

        tryVerify(() => !find("loginPage").visible, 5000, "the login page goes")
        verify(find("bookList").visible, "the library shows")
    }

    function test_wrongPasswordShowsError() {
        open()
        fakeServer.respond("POST", "/api/v1/auth/login", 401, "auth/login-invalid.json")

        signIn(fakeServer.url, "reader", "wrong")

        tryCompare(find("errorText"), "text", "Invalid credentials (HTTP 401)")
        verify(find("loginPage").visible, "the login page stays")
        // What the server was sent
        compare(fakeServer.requests.length, 1)
        compare(fakeServer.requests[0].body.username, "reader")
        compare(fakeServer.requests[0].body.password, "wrong")
        // Cleared for the next try
        compare(find("passwordField").text, "")
    }

    // The server from the last sign-in shows as a pill instead of a field, without https://
    function test_savedServerShowsAsPill() {
        open({serverUrl: "https://books.example.com"})

        verify(find("serverPill").visible, "the pill shows")
        verify(!find("serverField").visible, "the server field is hidden")
        compare(find("serverPillText").text, "books.example.com")
    }

    // After signing out, the username stays but the password has to be typed again
    function test_savedUsernameIsFilledInButNotThePassword() {
        open({serverUrl: "https://books.example.com", username: "reader"})

        compare(find("usernameField").text, "reader")
        compare(find("passwordField").text, "")
    }
}
