import QtQuick
import "../helpers"

AppTestCase {
    name: "Startup"

    function test_firstStartShowsSignIn() {
        open()

        verify(find("loginPage").visible, "the login page shows")
        verify(!find("bookList").visible, "the library is hidden")
    }

    // A saved session opens straight on the library, before anything is asked of the server
    function test_savedSessionSkipsSignIn() {
        open({serverUrl: fakeServer.url, username: "reader", refreshToken: "saved-token"})

        verify(!find("loginPage").visible, "the login page is hidden")
        verify(find("bookList").visible, "the library shows")
    }
}
