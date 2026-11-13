import QtQuick
import "../helpers"

// With no network, as with make run-offline (testApp.offline)
AppTestCase {
    name: "Offline"

    readonly property var savedSession: ({serverUrl: "https://books.example.com", username: "reader",
                                          refreshToken: "saved-token"})
    // One book downloaded, and one only seen in the library before
    readonly property var books: [
        {id: 1, title: "Downloaded Book", authors: ["A. Writer"], formats: ["epub"], file: "downloaded.epub"},
        {id: 2, title: "Library Book", authors: ["A. Writer"], formats: ["epub"]},
    ]

    // Signing in needs the server, so a message shows instead of the form. Books downloaded
    // before signing out don't change that; they open from the device's own library.
    function test_signedOutShowsOfflineMessageEvenWithDownloads() {
        open({serverUrl: "https://books.example.com", username: "reader"}, {offline: true, books: books})

        verify(find("offlineState").visible, "the offline message shows")
        compare(find("offlineState").title, "Currently offline")
        verify(!find("signInForm").visible, "the form is hidden")
        verify(!find("bookList").visible, "the library is hidden")
    }

    // Wi-Fi connection going between opening the app and signing in
    function test_noNetworkAtSignInShowsOfflineMessage() {
        open()
        testApp.offline = true

        signIn(fakeServer.url, "reader", "right")

        tryVerify(() => find("offlineState").visible, 5000, "the offline message shows")
        verify(!find("signInForm").visible, "the form is hidden")
    }

    // With the network up, no reply is the server's problem, so the form stays to try again
    function test_serverNotReplyingKeepsSignInForm() {
        open()
        fakeServer.reachable = false

        signIn(fakeServer.url, "reader", "right")

        tryCompare(find("errorText"), "text", "The server didn't reply")
        verify(find("signInForm").visible, "the form stays")
        verify(!find("offlineState").visible, "the offline message is hidden")
    }

    function test_connectShowsSignInAgain() {
        open({}, {offline: true})
        verify(find("offlineState").visible, "the offline message shows")

        testApp.offline = false
        tap("connectButton")

        tryVerify(() => find("signInForm").visible, 5000, "the form shows again")
        verify(!find("offlineState").visible, "the offline message goes")
    }

    // Offline, nothing can say the session has ended on the server, so a saved one is kept
    // and the downloads stay browsable
    function test_libraryShowsOnlyDownloadedBooks() {
        open(savedSession, {offline: true, books: books})

        const list = find("bookList")
        verify(list.visible, "the library shows")
        tryCompare(list, "count", 1)
        compare(list.itemAtIndex(0).book.title, "Downloaded Book")
    }

    // With the network up but the server down, a saved session works offline the same way
    function test_serverDownShowsOnlyDownloadedBooks() {
        fakeServer.reachable = false
        open({serverUrl: fakeServer.url, username: "reader", refreshToken: "saved-token"}, {books: books})

        tryVerify(() => find("offlineIcon").visible, 5000, "the offline icon shows")
        verify(bookOrbit.networkConnected, "the network is up")
        verify(bookOrbit.signedIn, "still signed in")
        const list = find("bookList")
        tryCompare(list, "count", 1)
        compare(list.itemAtIndex(0).book.title, "Downloaded Book")
    }

    // A red badge after the title
    function test_headerShowsOfflineIcon() {
        open(savedSession, {offline: true})

        verify(find("offlineIcon").visible, "the offline icon shows")
    }
}
