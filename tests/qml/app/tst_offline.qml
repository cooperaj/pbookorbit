import QtQuick
import "../helpers"

// Starting with no network. The app is told it's offline, as with make run-offline.
AppTestCase {
    name: "Offline"

    readonly property var savedSession: ({serverUrl: "https://books.example.com", username: "reader",
                                          refreshToken: "saved-token"})
    // One book downloaded, and one only seen in the library before
    readonly property var books: [
        {id: 1, title: "Downloaded Book", authors: ["A. Writer"], formats: ["epub"], file: "downloaded.epub"},
        {id: 2, title: "Library Book", authors: ["A. Writer"], formats: ["epub"]},
    ]

    function test_signedOutShowsSignIn() {
        open({}, {offline: true})

        verify(find("loginPage").visible, "the login page shows")
        verify(!find("bookList").visible, "the library is hidden")
    }

    function test_libraryShowsOnlyDownloadedBooks() {
        open(savedSession, {offline: true, books: books})

        const list = find("bookList")
        verify(list.visible, "the library shows")
        tryCompare(list, "count", 1)
        compare(list.itemAtIndex(0).book.title, "Downloaded Book")
    }

    // A red badge after the title
    function test_headerShowsOfflineIcon() {
        open(savedSession, {offline: true})

        verify(find("offlineIcon").visible, "the offline icon shows")
    }
}
