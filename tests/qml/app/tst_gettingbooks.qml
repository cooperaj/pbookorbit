import QtQuick
import "../helpers"

// Getting a book onto the device. Tapping a book that isn't on it offers to download it,
// and once downloaded it opens: an ebook in the system's reader, an audiobook in its
// audiobook player. The server has Dune (an ebook), The Martian (an audiobook) and Project
// Hail Mary (both). inkview records what's opened, and the library scans asked for,
// instead of doing them.
AppTestCase {
    name: "GettingBooks"

    readonly property string duneDownload: "/api/v1/books/files/11/download"
    readonly property string duneOffer: "Download EPUB, 1.9 MB to the Books folder and open it?"

    function openDownloadsLibrary(options) {
        openLibrary("libraries/downloads.json", "libraries/downloads-jump-buckets.json", options)
    }

    function serveDune() {
        fakeServer.respondFile(duneDownload, "files/book.epub", "Dune - Frank Herbert.epub")
    }

    function test_aUserCanDownloadABookAndReadIt() {
        openDownloadsLibrary()
        serveDune()

        mouseClick(bookRow("Dune"))
        expectText(duneOffer)
        tapText("Download")

        expectNoText(duneOffer)
        expectOpenedInReader("/Books/Dune - Frank Herbert.epub")
        compare(testApp.filesIn("Books"), ["Dune - Frank Herbert.epub"], "saved under the server's name")
        compare(inkview.libraryScans, 1, "the system library is asked to find it")
        expectOnDevice("Dune", "epub")

        reopen()
        expectOnDevice("Dune", "epub")
    }

    function test_anAudiobookDownloadsToTheAudioBooksFolderAndPlays() {
        openDownloadsLibrary()
        fakeServer.respondFile("/api/v1/books/files/41/download", "files/book.m4b", "The Martian.m4b")
        const offer = "Download M4B, 591.3 MB to the Audio Books folder and open it?"

        mouseClick(bookRow("The Martian"))
        expectText(offer)
        tapText("Download")

        expectNoText(offer)
        expectOpenedInPlayer("/Audio Books/The Martian.m4b")
        compare(testApp.filesIn("Audio Books"), ["The Martian.m4b"])
        compare(testApp.filesIn("Books"), [], "nothing in Books")
        expectOnDevice("The Martian", "m4b")
    }

    function test_aBookWithBothVersionsDownloadsTheOneChosen() {
        openDownloadsLibrary()
        fakeServer.respondFile("/api/v1/books/files/52/download", "files/book.m4b", "Project Hail Mary.m4b")
        const offer = "Download the ebook (EPUB, 2.3 MB) or the audiobook (M4B, 1.1 GB) and open it?"

        mouseClick(bookRow("Project Hail Mary"))
        expectText(offer)
        tapText("audiobook")

        expectNoText(offer)
        expectOpenedInPlayer("/Audio Books/Project Hail Mary.m4b")
        compare(testApp.filesIn("Audio Books"), ["Project Hail Mary.m4b"])
        compare(testApp.filesIn("Books"), [], "not the ebook")
        expectOnDevice("Project Hail Mary", "m4b")
    }

    // From the book's menu, choosing the app it opens in
    function test_aUserCanDownloadABookToReadInAnotherApp() {
        openDownloadsLibrary({apps: {epub: [{app: "koreader.app", name: "KOReader"},
                                            {app: "eink-reader.app", name: "PB Reader"}]}})
        serveDune()
        const offer = "Download EPUB, 1.9 MB to the Books folder and open it in PB Reader?"

        const menu = holdBook("Dune")
        tapText("Open with", menu)
        // The second, so it's the choice that counts and not the order
        tapText("PB Reader", menu)
        expectText(offer)
        tapText("Download")

        expectNoText(offer)
        expectOpenedInReader("/Books/Dune - Frank Herbert.epub", "eink-reader.app")
        expectOnDevice("Dune", "epub")
    }

    // Another file of the same name stays as it was, and the book is the new one
    function test_aDownloadDoesntOverwriteAFileOfTheSameName() {
        openDownloadsLibrary({files: ["Dune - Frank Herbert.epub"]})
        serveDune()

        mouseClick(bookRow("Dune"))
        tapText("Download")

        expectOpenedInReader("/Books/Dune - Frank Herbert (2).epub")
        compare(testApp.filesIn("Books"), ["Dune - Frank Herbert (2).epub", "Dune - Frank Herbert.epub"])

        reopen()
        mouseClick(bookRow("Dune"))
        expectOpenedInReader("/Books/Dune - Frank Herbert (2).epub")
    }

    // A failed download leaves nothing behind
    function test_aFailedDownloadCanBeTriedAgain() {
        openDownloadsLibrary()
        fakeServer.respond("GET", duneDownload, 500, "server-error.json")

        mouseClick(bookRow("Dune"))
        tapText("Download")

        expectText("The server couldn't send the book (HTTP 500)")
        compare(testApp.filesIn("Books"), [], "no part file left")
        expectNotOnDevice("Dune")
        compare(inkview.openedBooks.length, 0, "nothing opened")

        serveDune()
        tapText("Try again")

        expectOpenedInReader("/Books/Dune - Frank Herbert.epub")
        compare(testApp.filesIn("Books"), ["Dune - Frank Herbert.epub"])
        expectOnDevice("Dune", "epub")
    }

    function test_cancellingADownloadLeavesNothingBehind() {
        openDownloadsLibrary()
        serveDune()
        fakeServer.hold("GET", duneDownload)

        mouseClick(bookRow("Dune"))
        tapText("Download")
        expectText(/^Downloading EPUB, 1.9 MB/)
        tapText("Cancel")
        fakeServer.release("GET", duneDownload)
        wait(300)

        expectNoText(/^Downloading /)
        compare(testApp.filesIn("Books"), [], "nothing saved, no part file left")
        expectNotOnDevice("Dune")
        compare(inkview.openedBooks.length, 0, "nothing opened")
        compare(inkview.libraryScans, 0, "no library scan")
    }
}
