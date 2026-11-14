import QtQuick
import "../helpers"

// A book's info page, opened from its menu. Its fields come from the library's entry, and
// the rest from the server's details for the book, saved for when offline. A book with an
// ebook and an audiobook switches between them, and Choose action acts on the one shown.
AppTestCase {
    name: "BookInfo"

    readonly property var epubApps: ({epub: [{app: "koreader.app", name: "KOReader"},
                                             {app: "eink-reader.app", name: "PB Reader"}]})
    readonly property var dune: ({id: 1, title: "Dune", authors: ["Frank Herbert"], formats: ["epub"]})
    readonly property var hailMary: ({id: 5, title: "Project Hail Mary", authors: ["Andy Weir"],
                                      formats: ["epub", "m4b"]})
    readonly property string audiobookPlayer: "/ebrmain/bin/audio_books.app"

    function onDevice(book, file, extra) {
        return Object.assign({}, book, {file: file}, extra || {})
    }

    // Dune and Dune Messiah, by Frank Herbert in the Dune series, and Hyperion, by Dan
    // Simmons in no series
    function openMenuLibrary(options) {
        fakeServer.respond("GET", "/api/v1/books/1", 200, "books/dune-details.json")
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/menu-dune-books.json",
                           {filter: {rules: [{field: "author", value: ["Frank Herbert"]}]}})
        fakeServer.respond("POST", "/api/v1/libraries/1/books", 200, "libraries/menu-dune-books.json",
                           {filter: {rules: [{field: "series", value: ["Dune"]}]}})
        openLibrary("libraries/menu.json", "libraries/menu-jump-buckets.json", options)
    }

    // Dune (an ebook), The Martian (an audiobook) and Project Hail Mary (both)
    function openDownloadsLibrary(options) {
        fakeServer.respond("GET", "/api/v1/books/5", 200, "books/hail-mary-details.json")
        openLibrary("libraries/downloads.json", "libraries/downloads-jump-buckets.json", options)
    }

    // Opens the book's info page from its menu, and returns it
    function openInfo(title) {
        const menu = find("bookMenu")
        menu.open(bookRow(title))
        menu.show()
        tap("bookInfo", menu)
        const info = find("bookInfoPage")
        verify(info.visible, "the info page shows")
        return info
    }

    function field(info, name) {
        return find(name, info).value
    }

    // A cell's value by its label, e.g. "Size", in fileCells or detailCells
    function cell(info, cells, label) {
        const found = find(cells, info).cells.find(c => c[0] === label)
        return found ? found[1] : undefined
    }

    // Opens Choose action, and returns its menu
    function chooseAction(info) {
        tap("chooseAction", info)
        const actions = find("actions", info)
        verify(actions.visible, "the menu opens")
        return actions
    }

    // The menu's items, top to bottom, each with "-" after it if it draws a line below:
    // "download, openWith-, KOReader-, PB Reader"
    function menuLines(actions) {
        const column = find("deleteBook", actions).parent
        waitForItemPolished(column)
        const items = []
        for (const item of column.children) {
            if (item.visible && item.showSeparator !== undefined)
                items.push(item)
        }
        items.sort((a, b) => a.y - b.y)
        return items.map(item => item.objectName + (item.showSeparator ? "-" : "")).join(", ")
    }

    function test_showsTheBooksFields() {
        openMenuLibrary()

        const info = openInfo("Dune")

        compare(field(info, "titleField"), "Dune")
        compare(field(info, "authorField"), "Frank Herbert")
        compare(field(info, "seriesField"), "Dune - 1")
        verify(!find("fileField", info).visible, "no file, as it's not on the device")
        // In local time, as the page shows it
        compare(cell(info, "fileCells", "Added"),
                Qt.formatDateTime(new Date("2026-01-03T10:00:00.000Z"), "dd/MM/yy hh:mm"))
        compare(cell(info, "fileCells", "Size"), "1.9 MB")
        compare(cell(info, "fileCells", "Format"), "EPUB")
        verify(!find("kindSwitch", info).visible, "no switch for a book with one version")
    }

    function test_showsTheServersDetails() {
        openMenuLibrary()

        const info = openInfo("Dune")

        tryCompare(find("publisherField", info), "value", "Chilton Books")
        compare(field(info, "genresField"), "Science Fiction, Classics")
        verify(field(info, "descriptionField").indexOf("Set on the desert planet Arrakis.") >= 0)
        compare(cell(info, "detailCells", "Published"), "01/08/1965")
        compare(cell(info, "detailCells", "Pages"), "412")
        compare(cell(info, "detailCells", "Language"), "en")
    }

    function test_noSeriesOutsideASeries() {
        openMenuLibrary()

        const info = openInfo("Hyperion")

        verify(!find("seriesField", info).visible)
    }

    function test_downloadedBookShowsItsFile() {
        openMenuLibrary({books: [onDevice(dune, "Dune.epub")]})

        const info = openInfo("Dune")

        verify(find("fileField", info).visible)
        verify(field(info, "fileField").endsWith("Books/Dune.epub"), field(info, "fileField"))
    }

    function test_authorShowsAllTheirBooks() {
        openMenuLibrary()
        const info = openInfo("Dune")

        tap("authorField", info)

        verify(!info.visible, "the info page closes")
        const page = find("booksOfPage")
        verify(page.visible, "the author's books show")
        compare(page.name, "Frank Herbert")
        tryVerify(() => page.list.count === 2, 5000, "Frank Herbert's two books")
    }

    function test_seriesShowsAllItsBooks() {
        openMenuLibrary()
        const info = openInfo("Dune")

        tap("seriesField", info)

        verify(!info.visible, "the info page closes")
        const page = find("booksOfPage")
        verify(page.visible, "the series' books show")
        compare(page.name, "Dune")
    }

    function test_backReturnsToTheLibrary() {
        openMenuLibrary()
        const info = openInfo("Dune")

        tap("backButton", info)

        verify(!info.visible)
        verify(find("bookList").visible, "the library shows")
    }

    // Offline the details saved when it was downloaded are shown
    function test_savedDetailsShowOffline() {
        open(savedSession, {offline: true,
                            books: [onDevice(dune, "Dune.epub", {details: {publisher: "Chilton Books"}})]})

        const info = openInfo("Dune")

        tryCompare(find("publisherField", info), "value", "Chilton Books")
    }

    function test_bothVersionsStartOnTheEbook() {
        openDownloadsLibrary()

        const info = openInfo("Project Hail Mary")

        verify(find("kindSwitch", info).visible, "a switch between the versions")
        compare(info.kind, "ebook")
        compare(cell(info, "fileCells", "Format"), "EPUB")
        compare(cell(info, "fileCells", "Size"), "2.3 MB")
        tryVerify(() => cell(info, "detailCells", "Pages") === "476", 5000, "its pages")
    }

    function test_switchingToTheAudiobook() {
        openDownloadsLibrary()
        const info = openInfo("Project Hail Mary")

        tap("audiobookHalf", info)

        compare(info.kind, "audiobook")
        compare(cell(info, "fileCells", "Format"), "M4B")
        compare(cell(info, "fileCells", "Size"), "1.1 GB")
        tryVerify(() => cell(info, "detailCells", "Length") === "16 h 16 min", 5000, "its length, not pages")
    }

    function test_audiobookOnTheDeviceIsShownFirst() {
        openDownloadsLibrary({books: [onDevice(hailMary, "Project Hail Mary.m4b")]})

        const info = openInfo("Project Hail Mary")

        compare(info.kind, "audiobook")
        compare(cell(info, "fileCells", "Format"), "M4B")
        verify(field(info, "fileField").endsWith("Project Hail Mary.m4b"))
    }

    // Choose action downloads the version shown, and only that one
    function test_downloadTheChosenVersion() {
        openDownloadsLibrary()
        const info = openInfo("Project Hail Mary")
        tap("audiobookHalf", info)
        const actions = chooseAction(info)
        verify(!find("deleteBook", actions).visible, "no Delete for a book not on the device")

        tap("download", actions)

        verify(!actions.visible, "the menu closes")
        const dialog = find("downloadDialog")
        verify(dialog.visible, "the download dialog shows")
        compare(dialog.message, "Download M4B, 1.1 GB to the Audio Books folder and open it?")
    }

    // Choose action deletes the version shown, and leaves the other
    function test_deleteTheChosenVersion() {
        openDownloadsLibrary({books: [onDevice(hailMary, "Project Hail Mary.epub"),
                                      onDevice(hailMary, "Project Hail Mary.m4b")]})
        const info = openInfo("Project Hail Mary")
        tap("audiobookHalf", info)
        const actions = chooseAction(info)
        verify(!find("download", actions).visible, "no Download for a version on the device")

        tap("deleteBook", actions)

        const dialog = find("deleteDialog")
        verify(dialog.visible, "the delete dialog shows")
        compare(find("deleteMessage", dialog).text,
                "Are you sure you want to delete the audiobook of Project Hail Mary from your device?")
        tapButton("Yes", dialog)
        compare(testApp.filesIn("Audio Books"), [], "the audiobook is gone")
        compare(testApp.filesIn("Books"), ["Project Hail Mary.epub"], "the ebook stays")
    }

    // Audiobooks have no Open with, so Open book starts the audiobook player
    function test_openBookForADownloadedAudiobook() {
        openDownloadsLibrary({books: [onDevice({id: 4, title: "The Martian", authors: ["Andy Weir"],
                                                formats: ["m4b"]}, "The Martian.m4b")]})
        const info = openInfo("The Martian")
        const actions = chooseAction(info)

        tap("openBook", actions)

        verify(!actions.visible, "the menu closes")
        compare(inkview.openedTasks.length, 1, "one app started")
        compare(inkview.openedTasks[0].app, audiobookPlayer)
        verify(inkview.openedTasks[0].args[1].endsWith("/Audio Books/The Martian.m4b"))
    }

    // Lines go between items, never under the last
    function test_menuLinesOnlyBetweenItems() {
        openDownloadsLibrary({books: [onDevice(hailMary, "Project Hail Mary.epub")], apps: epubApps})
        const info = openInfo("Project Hail Mary")
        let actions = chooseAction(info)
        compare(menuLines(actions), "openWith-, deleteBook", "the ebook on the device")
        tap("openWith", actions)
        compare(menuLines(actions), "openWith-, KOReader-, PB Reader-, deleteBook", "with its apps")
        mouseClick(actions, 5, 5)

        tap("audiobookHalf", info)
        actions = chooseAction(info)
        compare(menuLines(actions), "download", "the audiobook, not on the device and no app for it")
        mouseClick(actions, 5, 5)

        tap("ebookHalf", info)
        tap("deleteBook", chooseAction(info))
        tapButton("Yes", find("deleteDialog"))
        actions = chooseAction(info)
        compare(menuLines(actions), "download-, openWith", "the ebook, deleted")
    }

    function test_menuLinesWithOpenBook() {
        openDownloadsLibrary({books: [onDevice({id: 4, title: "The Martian", authors: ["Andy Weir"],
                                                formats: ["m4b"]}, "The Martian.m4b")]})
        const info = openInfo("The Martian")

        compare(menuLines(chooseAction(info)), "openBook-, deleteBook")
    }

    function test_openWithTheChosenApp() {
        openDownloadsLibrary({books: [onDevice(dune, "Dune.epub")], apps: epubApps})
        const info = openInfo("Dune")
        const actions = chooseAction(info)
        verify(!find("openBook", actions).visible, "Open with instead of Open book")

        tap("openWith", actions)
        // The second, so it's the choice that counts and not the order
        tap("PB Reader", actions)

        verify(!actions.visible, "the menu closes")
        compare(inkview.openedBooks.length, 1, "one book opened")
        verify(inkview.openedBooks[0].path.endsWith("/Books/Dune.epub"))
        compare(inkview.openedBooks[0].app, "eink-reader.app", "in PB Reader")
    }
}
