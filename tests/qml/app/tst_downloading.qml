import QtQuick
import "../helpers"

// Downloading a book by tapping it in the library. The server has Dune (an ebook), The
// Martian (an audiobook) and Project Hail Mary (both). Once downloaded the dialog opens the
// book: an ebook in the system's reader, an audiobook in its audiobook player. inkview
// records both, and the library scans asked for, instead of doing them.
AppTestCase {
    name: "Downloading"

    readonly property string duneDownload: "/api/v1/books/files/11/download"
    readonly property string audiobookPlayer: "/ebrmain/bin/audio_books.app"

    // Checks the book at a path ending with this was opened in the reader, and nothing else
    function verifyOpenedInReader(file) {
        compare(inkview.openedBooks.length, 1, "one book opened")
        verify(inkview.openedBooks[0].path.endsWith(file), inkview.openedBooks[0].path + " is " + file)
        compare(inkview.openedBooks[0].app, "", "in the system's reader")
        compare(inkview.openedTasks.length, 0, "no other app started")
    }

    // Checks the audiobook player was started on a path ending with this, and nothing else
    function verifyOpenedInAudiobookPlayer(file) {
        compare(inkview.openedTasks.length, 1, "one app started")
        compare(inkview.openedTasks[0].app, audiobookPlayer, "the audiobook player")
        compare(inkview.openedTasks[0].args[0], "--bookPlay")
        verify(inkview.openedTasks[0].args[1].endsWith(file), inkview.openedTasks[0].args[1] + " is " + file)
        compare(inkview.openedBooks.length, 0, "no book opened in the reader")
    }

    function openDownloadsLibrary(options) {
        openLibrary("libraries/downloads.json", "libraries/downloads-jump-buckets.json", options)
    }

    // Taps a book that isn't on the device, and returns the dialog it opens
    function tapBook(title) {
        mouseClick(bookRow(title))
        const dialog = find("downloadDialog")
        verify(dialog.visible, "the download dialog shows")
        return dialog
    }

    function test_tappingABookOffersToDownloadIt() {
        openDownloadsLibrary()

        const dialog = tapBook("Dune")

        compare(dialog.message, "Download EPUB, 1.9 MB to the Books folder and open it?")
        findButton("Download", dialog)
        findButton("Cancel", dialog)
    }

    function test_downloadSavesTheBookAndMarksIt() {
        openDownloadsLibrary()
        fakeServer.respondFile(duneDownload, "files/book.epub", "Dune - Frank Herbert.epub")
        const dialog = tapBook("Dune")

        tapButton("Download", dialog)

        tryVerify(() => !dialog.visible, 5000, "the dialog closes to open the book")
        compare(testApp.filesIn("Books"), ["Dune - Frank Herbert.epub"], "saved under the server's name")
        verify(downloads.isOnDevice(1), "recorded as downloaded")
        tryVerify(() => find("onDevicePill", bookRow("Dune")).visible, 5000, "marked in the list")
        verifyOpenedInReader("/Books/Dune - Frank Herbert.epub")
        compare(inkview.libraryScans, 1, "the system library is asked to find it")
    }

    function test_audiobooksGoToTheAudioBooksFolder() {
        openDownloadsLibrary()
        fakeServer.respondFile("/api/v1/books/files/41/download", "files/book.m4b", "The Martian.m4b")
        const dialog = tapBook("The Martian")
        compare(dialog.message, "Download M4B, 591.3 MB to the Audio Books folder and open it?")

        tapButton("Download", dialog)

        tryVerify(() => !dialog.visible, 5000, "the dialog closes")
        compare(testApp.filesIn("Audio Books"), ["The Martian.m4b"])
        compare(testApp.filesIn("Books"), [], "nothing in Books")
        verifyOpenedInAudiobookPlayer("/Audio Books/The Martian.m4b")
    }

    // A book with an ebook and an audiobook asks which, and downloads only that one
    function test_bookWithBothVersionsAsksWhich() {
        openDownloadsLibrary()
        fakeServer.respondFile("/api/v1/books/files/52/download", "files/book.m4b", "Project Hail Mary.m4b")
        const dialog = tapBook("Project Hail Mary")
        compare(dialog.message,
                "Download the ebook (EPUB, 2.3 MB) or the audiobook (M4B, 1.1 GB) and open it?")

        tapButton("audiobook", dialog)

        tryVerify(() => !dialog.visible, 5000, "the dialog closes")
        compare(testApp.filesIn("Audio Books"), ["Project Hail Mary.m4b"])
        compare(testApp.filesIn("Books"), [], "not the ebook")
        compare(downloads.kindsOnDevice(5), ["audiobook"])
        verifyOpenedInAudiobookPlayer("/Audio Books/Project Hail Mary.m4b")
    }

    // Another book's file of the same name stays as it was
    function test_sameNameDoesntOverwrite() {
        openDownloadsLibrary({files: ["Dune - Frank Herbert.epub"]})
        fakeServer.respondFile(duneDownload, "files/book.epub", "Dune - Frank Herbert.epub")
        const dialog = tapBook("Dune")

        tapButton("Download", dialog)

        tryVerify(() => !dialog.visible, 5000, "the dialog closes")
        compare(testApp.filesIn("Books"), ["Dune - Frank Herbert (2).epub", "Dune - Frank Herbert.epub"])
        compare(downloads.pathsOnDevice(1).length, 1)
        verify(downloads.pathsOnDevice(1)[0].endsWith("Dune - Frank Herbert (2).epub"), "the new file is the book's")
    }

    // A failed download leaves nothing behind, and can be tried again
    function test_failedDownloadCanBeTriedAgain() {
        openDownloadsLibrary()
        fakeServer.respond("GET", duneDownload, 500, "server-error.json")
        const dialog = tapBook("Dune")

        tapButton("Download", dialog)

        tryCompare(dialog, "message", "The server couldn't send the book (HTTP 500)")
        compare(testApp.filesIn("Books"), [], "no part file left")
        verify(!downloads.isOnDevice(1), "not recorded")
        compare(inkview.openedBooks.length, 0, "nothing opened")

        fakeServer.respondFile(duneDownload, "files/book.epub", "Dune - Frank Herbert.epub")
        tapButton("Try again", dialog)

        tryVerify(() => !dialog.visible, 5000, "the second try opens the book")
        compare(testApp.filesIn("Books"), ["Dune - Frank Herbert.epub"])
        verifyOpenedInReader("/Books/Dune - Frank Herbert.epub")
    }

    function test_cancellingStopsTheDownload() {
        openDownloadsLibrary()
        fakeServer.respondFile(duneDownload, "files/book.epub", "Dune - Frank Herbert.epub")
        fakeServer.hold("GET", duneDownload)
        const dialog = tapBook("Dune")
        tapButton("Download", dialog)
        tryVerify(() => dialog.downloading, 5000, "downloading")

        tapButton("Cancel", dialog)
        fakeServer.release("GET", duneDownload)
        wait(300)

        verify(!dialog.visible, "the dialog closes")
        compare(testApp.filesIn("Books"), [], "nothing saved, no part file left")
        verify(!downloads.isOnDevice(1), "not recorded")
        compare(inkview.openedBooks.length, 0, "nothing opened")
        compare(inkview.libraryScans, 0, "no library scan")
    }

    // A book on the device opens straight away
    function test_downloadedBookOpensWithoutAsking() {
        openDownloadsLibrary({books: [{id: 1, title: "Dune", authors: ["Frank Herbert"], formats: ["epub"],
                                       file: "Dune.epub"}]})

        mouseClick(bookRow("Dune"))

        verify(!find("downloadDialog").visible, "no download dialog")
        verifyOpenedInReader("/Books/Dune.epub")
    }

    function test_downloadedAudiobookOpensWithoutAsking() {
        openDownloadsLibrary({books: [{id: 4, title: "The Martian", authors: ["Andy Weir"], formats: ["m4b"],
                                       file: "The Martian.m4b"}]})

        mouseClick(bookRow("The Martian"))

        verify(!find("downloadDialog").visible, "no download dialog")
        verifyOpenedInAudiobookPlayer("/Audio Books/The Martian.m4b")
    }

    // Having one version of a book is enough: it doesn't offer the other
    function test_bookWithItsAudiobookDownloadedOpensWithoutAsking() {
        openDownloadsLibrary({books: [{id: 5, title: "Project Hail Mary", authors: ["Andy Weir"],
                                       formats: ["epub", "m4b"], file: "Project Hail Mary.m4b"}]})

        mouseClick(bookRow("Project Hail Mary"))

        verify(!find("downloadDialog").visible, "no download dialog")
        verifyOpenedInAudiobookPlayer("/Audio Books/Project Hail Mary.m4b")
    }
}
