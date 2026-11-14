import QtQuick
import "../helpers"

// Signing out from the header menu
AppTestCase {
    name: "SignOut"

    function signOut() {
        tap("menuButton")
        tap("signOut")
    }

    // Signing out ends the session on the server and goes back to sign-in, keeping the
    // server and username
    function test_signOutReturnsToSignIn() {
        openLibrary()
        tryCompare(find("bookList"), "count", 3)
        tap("menuButton")

        tap("signOut")

        verify(find("loginPage").visible, "the sign-in page shows")
        verify(!find("headerMenu").visible, "the menu closes")
        tryVerify(() => fakeServer.requests.some(r => r.path === "/api/v1/auth/logout"), 5000,
                  "the session is ended on the server")
        verify(find("serverPill").visible, "the server is kept")
        compare(find("usernameField").text, "reader")
    }

    // A refresh still on its way when the user signs out mustn't sign them back in
    function test_signOutDuringStartupStaysSignedOut() {
        fakeServer.hold("POST", "/api/v1/auth/refresh")
        openLibrary()
        signOut()
        verify(find("loginPage").visible, "signed out")

        fakeServer.release("POST", "/api/v1/auth/refresh")
        tryVerify(() => !bookOrbit.busy, 5000, "the refresh reply is handled")

        verify(!bookOrbit.signedIn, "still signed out")
        verify(find("loginPage").visible, "the sign-in page stays")
        compare(bookOrbit.error, "", "no error for a sign-out the user asked for")
    }

    // Nor, if that session had expired, tell them so after they've signed out anyway
    function test_signOutDuringStartupShowsNoSessionError() {
        fakeServer.hold("POST", "/api/v1/auth/refresh")
        openLibrary()
        // After openLibrary's, so it's the one that answers
        fakeServer.respond("POST", "/api/v1/auth/refresh", 401, "auth/login-invalid.json")
        signOut()

        fakeServer.release("POST", "/api/v1/auth/refresh")
        tryVerify(() => !bookOrbit.busy, 5000, "the refresh reply is handled")

        compare(find("errorText").text, "", "no error on the sign-in page")
    }
}
