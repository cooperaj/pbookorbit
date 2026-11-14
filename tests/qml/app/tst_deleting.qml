import QtQuick
import "../helpers"

// Deleting a downloaded book from the device, from its menu. The server has Dune (an
// ebook), The Martian (an audiobook) and Project Hail Mary (both). Deleting removes the
// book's files and their records, and asks the system library to drop them.
AppTestCase {
    name: "Deleting"

    readonly property var dune: ({id: 1, title: "Dune", authors: ["Frank Herbert"], formats: ["epub"]})
    readonly property var hailMary: ({id: 5, title: "Project Hail Mary", authors: ["Andy Weir"],
                                      formats: ["epub", "m4b"]})

    // A book entry saved with a file of this name on the device
    function onDevice(book, file, extra) {
        return Object.assign({}, book, {file: file}, extra || {})
    }

    function openDownloadsLibrary(options) {
        openLibrary("libraries/downloads.json", "libraries/downloads-jump-buckets.json", options)
    }

    function message(dialog) {
        return find("deleteMessage", dialog).text
    }

    // Chooses Delete in the book's menu, and returns the dialog it opens
    function deleteBook(title) {
        const menu = find("bookMenu")
        menu.open(bookRow(title))
        menu.show()
        tap("deleteBook", menu)
        const dialog = find("deleteDialog")
        verify(dialog.visible, "the delete dialog shows")
        return dialog
    }

    function test_yesDeletesTheBook() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub")]})
        const dialog = deleteBook("Dune")
        compare(message(dialog), "Are you sure you want to delete Dune from your device?")

        tapButton("Yes", dialog)

        verify(!dialog.visible, "the dialog closes")
        compare(testApp.filesIn("Books"), [], "the file is gone")
        verify(!downloads.isOnDevice(1), "no longer recorded as downloaded")
        tryVerify(() => !find("onDevicePill", bookRow("Dune")).visible, 5000, "unmarked in the list")
        compare(inkview.libraryScans, 1, "the system library is asked to drop it")
    }

    function test_noKeepsTheBook() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub")]})
        const dialog = deleteBook("Dune")

        tapButton("No", dialog)

        verify(!dialog.visible, "the dialog closes")
        compare(testApp.filesIn("Books"), ["Dune.epub"])
        verify(downloads.isOnDevice(1))
        compare(inkview.libraryScans, 0)
    }

    // Other books' files stay, including unrecorded ones beside it
    function test_deletesOnlyThatBook() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub"),
                                      onDevice({id: 4, title: "The Martian", authors: ["Andy Weir"],
                                                formats: ["m4b"]}, "The Martian.m4b")],
                              files: ["Copied.epub"]})

        tapButton("Yes", deleteBook("Dune"))

        compare(testApp.filesIn("Books"), ["Copied.epub"])
        compare(testApp.filesIn("Audio Books"), ["The Martian.m4b"])
        verify(downloads.isOnDevice(4), "The Martian is still downloaded")
    }

    // With both versions on the device it asks which, and deletes only that one
    function test_bookWithBothVersionsAsksWhich() {
        openDownloadsLibrary({books: [onDevice(hailMary, "Project Hail Mary.epub"),
                                      onDevice(hailMary, "Project Hail Mary.m4b")]})
        const dialog = deleteBook("Project Hail Mary")
        compare(message(dialog), "Delete the ebook or the audiobook of Project Hail Mary from your device?")

        tapButton("audiobook", dialog)

        verify(!dialog.visible, "the dialog closes")
        compare(testApp.filesIn("Audio Books"), [], "the audiobook is gone")
        compare(testApp.filesIn("Books"), ["Project Hail Mary.epub"], "the ebook stays")
        compare(downloads.kindsOnDevice(5), ["ebook"])
        verify(find("onDevicePill", bookRow("Project Hail Mary")).visible, "still marked in the list")
    }

    function test_cancelKeepsBothVersions() {
        openDownloadsLibrary({books: [onDevice(hailMary, "Project Hail Mary.epub"),
                                      onDevice(hailMary, "Project Hail Mary.m4b")]})
        const dialog = deleteBook("Project Hail Mary")

        tapButton("Cancel", dialog)

        verify(!dialog.visible)
        compare(downloads.kindsOnDevice(5), ["ebook", "audiobook"])
    }

    // With just one version on the device it asks Yes or No, and Yes deletes that one
    function test_bookWithOneVersionOnTheDeviceDoesntAskWhich() {
        openDownloadsLibrary({books: [onDevice(hailMary, "Project Hail Mary.m4b")]})
        const dialog = deleteBook("Project Hail Mary")
        compare(message(dialog), "Are you sure you want to delete Project Hail Mary from your device?")

        tapButton("Yes", dialog)

        compare(testApp.filesIn("Audio Books"), [])
        verify(!downloads.isOnDevice(5))
    }

    function test_fileThatCantBeDeletedSaysSo() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub", {undeletable: true})]})
        const dialog = deleteBook("Dune")

        tapButton("Yes", dialog)

        verify(dialog.visible, "the dialog stays")
        compare(message(dialog), "Couldn't delete Dune from your device.")
        verify(downloads.isOnDevice(1), "still recorded as downloaded")
        tapButton("Close", dialog)
        verify(!dialog.visible)
    }
}
