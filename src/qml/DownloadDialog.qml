import QtQuick
import "units.js" as Units
import "books.js" as Books
import "format.js" as Format

// Offers to download a book that isn't on the device, shows progress, then opens it (in the
// app picked from Open with, if that's where it came from). Asks which version for books
// with an ebook and an audiobook. Says how much space the device has, and won't download a
// version that doesn't fit.
SystemDialog {
    id: dialog
    // The book on offer, as a list entry
    property var book: ({})
    // Versions to choose from: [{bookId, fileId, format, sizeBytes, kind, book}]
    property var options: []
    // The version downloading, or last attempted, by its index in options. Kept as an index
    // because QML gives a new wrapper each time an object is read from a var array, so
    // options.indexOf(chosen) wouldn't find it.
    property int chosenIndex: -1
    readonly property var chosen: chosenIndex >= 0 ? options[chosenIndex] : null
    readonly property bool hasFile: options.length > 0
    readonly property bool downloading: chosen !== null && downloads.bookId === chosen.bookId
    // Set when a download fails, until the next attempt
    property string error: ""
    // App to open it in, {app, name} from downloads.appsFor(), or null for the default
    property var app: null
    // Bytes free on the device when the dialog opened, or -1 if unknown
    property real freeBytes: -1
    // The chosen version is bigger than the space left
    readonly property bool tooBig: chosen !== null && !downloading && !fits(chosen)

    // format is the downloaded file's
    signal opened(int bookId, string format, var app)

    icon: error !== "" || !hasFile || tooBig ? "icon_error" : "icon_question"
    percent: downloading ? downloads.percent : -1
    onPressed: (action) => press(action)

    // The versions to offer, or all the book's (see Books.versions)
    function show(newBook, versions, newApp) {
        book = newBook
        app = newApp || null
        // Cleared first, so it never points past the end of the new list
        chosenIndex = -1
        options = versions && versions.length > 0 ? versions : Books.versions(newBook, downloads)
        chosenIndex = options.length === 1 ? 0 : -1
        error = ""
        freeBytes = downloads.freeSpace()
        visible = true
    }

    function close() {
        if (downloading)
            downloads.cancel()
        visible = false
    }

    // "EPUB, 1.9 MB"
    function fileText(option) {
        return option.format.toUpperCase() + ", " + Format.fileSize(option.sizeBytes || 0)
    }

    // Unknown sizes and free space count as fitting
    function fits(option) {
        return freeBytes < 0 || !option.sizeBytes || option.sizeBytes <= freeBytes
    }

    // A line of its own under the question: "3.2 GB free"
    readonly property string freeText: freeBytes < 0 ? "" : "\n\n" + Format.fileSize(freeBytes) + " free"

    function folderOf(option) {
        return downloads.fileToDownload(option.book, option.fileId).folder
    }

    heading: book.title || ""
    message: {
        if (error !== "")
            return error
        if (!hasFile)
            return "This book has no file to download."
        if (downloading)
            return "Downloading " + fileText(chosen) + "…  " + downloads.percent + "%"
        if (tooBig)
            return fileText(chosen) + " won't fit in the " + folderOf(chosen) + " folder." + freeText
        if (chosen === null) {
            // "Download the ebook (EPUB, 1.9 MB) or the audiobook (M4B, 1.1 GB) and open it?"
            return "Download the " + options.map(o => o.kind + " (" + fileText(o) + ")").join(" or the ")
                   + " and open it?" + freeText
        }
        return "Download " + fileText(chosen) + " to the " + folderOf(chosen) + " folder and open it"
               + (app ? " in " + app.name : "") + "?" + freeText
    }

    // Buttons left to right, as [label, action]; an option's index downloads it
    buttons: downloading ? [["Cancel", "close"]]
             : !hasFile || tooBig ? [["Close", "close"]]
             : error !== "" ? [["Try again", chosenIndex], ["Cancel", "close"]]
             : chosen === null ? options.map((o, i) => [o.kind, i]).concat([["Cancel", "close"]])
             : [["Download", 0], ["Cancel", "close"]]

    function press(action) {
        if (action === "close") {
            close()
            return
        }
        error = ""
        chosenIndex = action
        if (fits(chosen))
            downloads.download(chosen.book, chosen.fileId)
    }

    Connections {
        target: downloads
        function onDownloaded(bookId) {
            if (!dialog.visible || dialog.chosen === null || bookId !== dialog.chosen.bookId)
                return
            dialog.visible = false
            dialog.opened(bookId, dialog.chosen.format, dialog.app)
        }
        function onChanged() {
            // This book's download ended without the file arriving
            if (dialog.visible && downloads.bookId === -1 && downloads.error !== "")
                dialog.error = downloads.error
        }
    }

    messageGap: Units.dp(6)

    // Under the title
    SystemDialog.DialogText {
        visible: text !== ""
        text: (dialog.book.authors || []).join(", ")
    }
}
