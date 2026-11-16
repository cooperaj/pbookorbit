import QtQuick
import "../helpers"

// Reading a book that's on the device: a tap opens it, an ebook in the system's reader and
// an audiobook in its audiobook player, and Open with in its menu opens it in another app.
// The server has Dune (an ebook), The Martian (an audiobook) and Project Hail Mary (both).
AppTestCase {
    name: "ReadingBooks"

    readonly property var dune: ({id: 1, title: "Dune", authors: ["Frank Herbert"], formats: ["epub"]})

    // A book entry saved with a file of this name on the device
    function onDevice(book, file) {
        return Object.assign({}, book, {file: file})
    }

    function openDownloadsLibrary(options) {
        openLibrary("libraries/downloads.json", "libraries/downloads-jump-buckets.json", options)
    }

    function test_aDownloadedBookOpensWithATap() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub")]})

        mouseClick(bookRow("Dune"))

        expectOpenedInReader("/Books/Dune.epub")
        expectNoText("Download")
    }

    function test_aDownloadedAudiobookPlaysWithATap() {
        openDownloadsLibrary({books: [onDevice({id: 4, title: "The Martian", authors: ["Andy Weir"],
                                                formats: ["m4b"]}, "The Martian.m4b")]})

        mouseClick(bookRow("The Martian"))

        expectOpenedInPlayer("/Audio Books/The Martian.m4b")
        expectNoText("Download")
    }

    // Having one version of a book is enough: it doesn't offer the other
    function test_aBookWithOneVersionDownloadedOpensThatOne() {
        openDownloadsLibrary({books: [onDevice({id: 5, title: "Project Hail Mary", authors: ["Andy Weir"],
                                                formats: ["epub", "m4b"]}, "Project Hail Mary.m4b")]})

        mouseClick(bookRow("Project Hail Mary"))

        expectOpenedInPlayer("/Audio Books/Project Hail Mary.m4b")
        expectNoText("ebook")
    }

    // Open with lists the apps for the book's format
    function test_aUserCanReadABookInAnotherApp() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub")],
                              apps: {epub: [{app: "koreader.app", name: "KOReader"},
                                            {app: "eink-reader.app", name: "PB Reader"}]}})

        const menu = holdBook("Dune")
        tapText("Open with", menu)
        expectText("KOReader", menu)
        // The second, so it's the choice that counts and not the order
        tapText("PB Reader", menu)

        expectOpenedInReader("/Books/Dune.epub", "eink-reader.app")
        expectNoText("Open with")
    }

    function test_openWithNeedsAnAppForTheFormat() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub")],
                              apps: {pdf: [{app: "koreader.app", name: "KOReader"}]}})

        const menu = holdBook("Dune")

        expectText("Book info", menu)
        expectNoText("Open with", menu)
    }
}
