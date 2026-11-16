import QtQuick
import "../helpers"

// Deleting a downloaded book from the device, from its menu. Deleting removes the book's
// files and their records, and asks the system library to drop them. The server has Dune
// (an ebook), The Martian (an audiobook) and Project Hail Mary (both).
AppTestCase {
    name: "DeletingBooks"

    readonly property var dune: ({id: 1, title: "Dune", authors: ["Frank Herbert"], formats: ["epub"]})
    readonly property var martian: ({id: 4, title: "The Martian", authors: ["Andy Weir"], formats: ["m4b"]})
    readonly property var hailMary: ({id: 5, title: "Project Hail Mary", authors: ["Andy Weir"],
                                      formats: ["epub", "m4b"]})

    // A book entry saved with a file of this name on the device
    function onDevice(book, file, extra) {
        return Object.assign({}, book, {file: file}, extra || {})
    }

    function openDownloadsLibrary(options) {
        openLibrary("libraries/downloads.json", "libraries/downloads-jump-buckets.json", options)
    }

    // Chooses Delete in the book's menu, and waits for the question
    function deleteBook(title, question) {
        tapText("Delete", holdBook(title))
        expectText(question)
    }

    // Other books' files stay, including ones the app didn't download
    function test_aUserCanDeleteABookFromTheDevice() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub"), onDevice(martian, "The Martian.m4b")],
                              files: ["Copied.epub"]})
        const question = "Are you sure you want to delete Dune from your device?"

        deleteBook("Dune", question)
        tapText("Yes")

        expectNoText(question)
        compare(testApp.filesIn("Books"), ["Copied.epub"], "Dune's file is gone")
        compare(testApp.filesIn("Audio Books"), ["The Martian.m4b"])
        compare(inkview.libraryScans, 1, "the system library is asked to drop it")
        expectNotOnDevice("Dune")
        expectOnDevice("The Martian", "m4b")

        const menu = holdBook("Dune")
        expectText("Book info", menu)
        expectNoText("Delete", menu)

        reopen()
        expectNotOnDevice("Dune")
    }

    // No, or Cancel for a book with both versions, keeps everything
    function test_changingYourMindKeepsTheBook() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub"),
                                      onDevice(hailMary, "Project Hail Mary.epub"),
                                      onDevice(hailMary, "Project Hail Mary.m4b")]})

        deleteBook("Dune", "Are you sure you want to delete Dune from your device?")
        tapText("No")
        deleteBook("Project Hail Mary", "Delete the ebook or the audiobook of Project Hail Mary from your device?")
        tapText("Cancel")

        expectNoText("Cancel")
        compare(testApp.filesIn("Books"), ["Dune.epub", "Project Hail Mary.epub"])
        compare(testApp.filesIn("Audio Books"), ["Project Hail Mary.m4b"])
        compare(inkview.libraryScans, 0)
        expectOnDevice("Dune", "epub")
        expectOnDevice("Project Hail Mary", "epub, m4b")
    }

    function test_aBookWithBothVersionsDeletesTheOneChosen() {
        openDownloadsLibrary({books: [onDevice(hailMary, "Project Hail Mary.epub"),
                                      onDevice(hailMary, "Project Hail Mary.m4b")]})
        const question = "Delete the ebook or the audiobook of Project Hail Mary from your device?"

        deleteBook("Project Hail Mary", question)
        tapText("audiobook")

        expectNoText(question)
        compare(testApp.filesIn("Audio Books"), [], "the audiobook is gone")
        compare(testApp.filesIn("Books"), ["Project Hail Mary.epub"], "the ebook stays")
        expectOnDevice("Project Hail Mary", "epub")
    }

    function test_aBookWithOneVersionOnTheDeviceDeletesItWithoutAskingWhich() {
        openDownloadsLibrary({books: [onDevice(hailMary, "Project Hail Mary.m4b")]})
        const question = "Are you sure you want to delete Project Hail Mary from your device?"

        deleteBook("Project Hail Mary", question)
        tapText("Yes")

        expectNoText(question)
        compare(testApp.filesIn("Audio Books"), [])
        expectNotOnDevice("Project Hail Mary")
    }

    function test_aBookThatCantBeDeletedSaysSo() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub", {undeletable: true})]})

        deleteBook("Dune", "Are you sure you want to delete Dune from your device?")
        tapText("Yes")

        expectText("Couldn't delete Dune from your device.")
        expectOnDevice("Dune", "epub")
        tapText("Close")
        expectNoText("Couldn't delete Dune from your device.")
    }
}
