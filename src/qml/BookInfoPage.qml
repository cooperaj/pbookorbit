import QtQuick
import "units.js" as Units
import "books.js" as Books
import "format.js" as Format

// A book's details, laid out like the system library's Book info page:
// cover on the left with title, author, series and file path beside it, then ADDED, SIZE
// and FORMAT. Author and series link to all their books, like the book menu's "All books
// of" items. Below that come the extra details from BookOrbit (published, pages or length,
// language, description), fetched on open and simply missing offline. The page scrolls when
// the description is long (see InfoPage).
//
// A book with an ebook and an audiobook has an AUDIOBOOK | EBOOK switch under the fields
// beside the cover. The boxes and details below describe the chosen version: the one on the
// device at first, else the ebook.
//
// CHOOSE ACTION at the bottom opens a menu in the middle of the page, as on the system's
// page, for the chosen version: Download, Open with, Delete, and
// Open book where there's no Open with (audiobooks).
//
// The system's page also has a favourite heart, and Add to Collection in its menu.
InfoPage {
    id: page

    // The book's list entry
    property var book: ({})
    // GET /books/:id by record id, as they load
    property var detailsById: ({})
    // The version described, "ebook" or "audiobook", when the book has both
    property string kind: ""

    readonly property alias menuOpen: actions.visible

    // Same as BookMenu's: field "author" or "series", and the names to match
    signal booksOfChosen(string field, var values)
    // The menu's actions, for the chosen version. kind is "" if the book has just one.
    signal openChosen(int bookId, string kind)
    // versions as in DownloadDialog's options
    signal downloadChosen(var book, var versions)
    signal deleteChosen(var book, string kind)
    // As BookMenu's
    signal openWithChosen(var target, var app)

    function show(newBook) {
        book = newBook
        detailsById = {}
        actions.visible = false
        // The cover draws in the same pass as the rest of the page
        eink.requireHqUpdate()
        scrollToTop()
        // The version on the device, if just one is
        kind = Books.kindsOnDevice(book, downloads).join() === "audiobook" ? "audiobook" : "ebook"
        loadDetails()
    }

    function choose(newKind) {
        kind = newKind
        loadDetails()
    }

    // The described record's details, unless already loaded
    function loadDetails() {
        if (record.id !== undefined && detailsById[record.id] === undefined)
            bookOrbit.details.loadBook(record.id)
    }

    Connections {
        target: bookOrbit.details
        function onBookDetails(bookId, newDetails) {
            if (page.records.every(r => r.id !== bookId))
                return
            const loaded = Object.assign({}, page.detailsById)
            loaded[bookId] = newDetails
            page.detailsById = loaded
        }
    }

    // Its own record plus any separately stored version (e.g. an audiobook)
    readonly property var records: Books.records(book)
    // Whether there's an ebook and an audiobook to switch between
    readonly property bool hasKinds: {
        const kinds = (book.variants || []).map(v => v.kind)
        return kinds.indexOf("ebook") >= 0 && kinds.indexOf("audiobook") >= 0
    }
    // The chosen version, as in DownloadDialog's options, or null if the book has no file
    readonly property var version: {
        const versions = book.variants || []
        return (hasKinds ? versions.find(v => v.kind === kind) : versions[0]) || null
    }
    // The record described: the chosen version's, which may be the book's own
    readonly property var record: hasKinds && version !== null ? version.book : book
    // GET /books/:id for the record, once loaded
    readonly property var details: detailsById[record.id] || ({})
    readonly property bool versionOnDevice: downloads.revision >= 0 && version !== null
                                            && Books.versionOnDevice(version, downloads)
    // What Open with opens (see Books.openWithTarget), for the chosen version
    readonly property var openWithTarget: version === null || downloads.revision < 0 ? null
                                          : Books.openWithTarget(book, downloads, hasKinds ? kind : "")
    // One file per format, each record's primary first (see bookOrbit.formatFiles()). Only
    // the chosen version's when there's a choice.
    readonly property var files: {
        const files = []
        for (const record of records) {
            for (const file of bookOrbit.formatFiles(record)) {
                if ((!hasKinds || file.kind === kind) && files.every(f => f.format !== file.format))
                    files.push(file)
            }
        }
        return files
    }
    // Files on the device, shown as the system shows them: "Internal
    // memory/Books/Dune.epub"
    readonly property var devicePaths: {
        if (downloads.revision < 0)
            return []
        let paths = []
        for (const record of records)
            paths = paths.concat(downloads.pathsOnDevice(record.id))
        // Only the chosen version's, when there's a choice
        if (hasKinds)
            paths = paths.filter(path => downloads.kindOf(path.split(".").pop()) === kind)
        return paths.map(path => path.replace(/^.*\/mnt\/ext1\//, "Internal memory/"))
    }

    title: "Book info / " + (book.title || "")

    // Cover with the main fields beside it
    Item {
        width: parent.width
        height: Math.max(cover.height, kindSwitch.visible ? kindSwitch.y + kindSwitch.height : fields.height)

        // Loaded before the page first draws, so the screen updates once rather than
        // again when it arrives. It's a PNG from the cover cache.
        Cover {
            id: cover
            width: Units.dp(197)
            height: Units.dp(297)
            book: page.book
            placeholder: "book_card_dummy_cover_land"
            asynchronous: false
        }

        Column {
            id: fields
            x: cover.width + Units.dp(15)
            width: parent.width - x

            // Label and value, plus the field and names for links
            Repeater {
                model: [
                    ["Title", page.book.title || ""],
                    [(page.book.authors || []).length > 1 ? "Authors" : "Author", (page.book.authors || []).join(", "),
                     "author", page.book.authors || []],
                    ["Series", page.book.seriesText || "",
                     "series", page.book.seriesName ? [page.book.seriesName] : []],
                    [page.devicePaths.length > 1 ? "Files" : "File name", page.devicePaths.join("\n")],
                ]
                InfoField {
                    required property var modelData
                    required property int index
                    objectName: ["titleField", "authorField", "seriesField", "fileField"][index]
                    width: fields.width
                    label: modelData[0]
                    value: modelData[1]
                    tappable: modelData.length > 2 && modelData[3].length > 0
                    onClicked: page.booksOfChosen(modelData[2], modelData[3])
                }
            }
        }

        // AUDIOBOOK | EBOOK, level with the bottom of the cover, or under the fields
        // if they reach further. The chosen half is black, like the footer's tabs.
        Rectangle {
            id: kindSwitch
            objectName: "kindSwitch"
            visible: page.hasKinds
            x: fields.x
            y: Math.max(fields.height + Units.dp(10), cover.height - height)
            width: fields.width
            height: Units.dp(30)
            radius: height / 2
            border.width: 1
            border.color: "black"

            Repeater {
                model: [["Audiobook", "audiobook"], ["Ebook", "ebook"]]
                Item {
                    id: half
                    required property var modelData
                    required property int index
                    readonly property bool chosen: page.kind === modelData[1] || halfMouse.pressed
                    objectName: modelData[1] + "Half"
                    x: index * kindSwitch.width / 2
                    width: kindSwitch.width / 2
                    height: kindSwitch.height

                    // A rounded end on the outside, square towards the middle
                    Rectangle {
                        visible: half.chosen
                        anchors.fill: parent
                        radius: kindSwitch.radius
                        color: "black"
                    }
                    Rectangle {
                        visible: half.chosen
                        x: half.index === 0 ? parent.width - width : 0
                        width: kindSwitch.radius
                        height: parent.height
                        color: "black"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: half.modelData[0]
                        color: half.chosen ? "white" : "black"
                        font.pointSize: 8
                        font.capitalization: Font.AllUppercase
                    }
                    MouseArea {
                        id: halfMouse
                        anchors.fill: parent
                        onClicked: page.choose(half.modelData[1])
                    }
                }
            }
            // Between the halves
            Line {
                vertical: true
                x: parent.width / 2
            }
        }
    }

    Item { width: 1; height: Units.dp(17) }   // space below the cover

    // ADDED, SIZE, FORMAT
    InfoCells {
        objectName: "fileCells"
        width: parent.width
        cells: [
            ["Added", Format.dateTime(page.record.addedAt)],
            // Size per format, in the same order
            ["Size", page.files.map(f => Format.fileSize(f.sizeBytes)).join(", ")],
            ["Format", Format.formats(page.files.map(f => f.format))],
        ]
    }
    // From the book's details, once loaded
    InfoCells {
        objectName: "detailCells"
        width: parent.width
        showTopLine: false
        cells: [
            ["Published", Format.date(page.details.publishedDate, page.details.publishedYear)],
            // Audiobooks have a length instead of pages
            (page.hasKinds ? page.kind === "ebook" : page.details.pageCount || !page.details.audioMetadata)
                ? ["Pages", (page.details.pageCount || "").toString()]
                : ["Length", Format.duration((page.details.audioMetadata || {}).durationSeconds)],
            ["Language", page.details.language || ""],
        ]
    }
    // A little more space under the cells than between fields, to separate the
    // sections
    Item { width: 1; height: Units.dp(16) }

    InfoField {
        objectName: "publisherField"
        width: parent.width
        label: "Publisher"
        value: page.details.publisher || ""
    }
    InfoField {
        objectName: "genresField"
        width: parent.width
        label: "Genres"
        value: (page.details.genres || []).join(", ")
    }
    InfoField {
        objectName: "descriptionField"
        width: parent.width
        label: "Description"
        value: page.details.description || ""
        showLine: false
    }

    // Over the page: CHOOSE ACTION and its menu
    overlay: [
        // CHOOSE ACTION, between the page buttons: rounded at the top, its bottom edge off
        // the screen
        Rectangle {
            objectName: "chooseAction"
            visible: page.version !== null
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - page.pageButtons.height
            width: Units.dp(384)
            height: page.pageButtons.height + radius
            radius: Units.dp(6)
            border.width: 1
            border.color: "black"
            color: actionMouse.pressed ? "black" : "white"

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: (page.pageButtons.height - height) / 2
                spacing: Units.dp(8)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Choose action"
                    color: actionMouse.pressed ? "white" : "black"
                    font.pointSize: 8
                    font.capitalization: Font.AllUppercase
                }
                ThemeIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "arrow_up"
                    inverted: actionMouse.pressed
                }
            }
            MouseArea {
                id: actionMouse
                anchors.fill: parent
                onClicked: actions.visible = true
            }
        },

        // The menu, in the middle of the faded page. Tapping outside closes it.
        Item {
            id: actions
            objectName: "actions"
            anchors.fill: parent
            visible: false
            onVisibleChanged: {
                openWithItem.expanded = false
                // The cover fades or returns in the same pass as the rest
                eink.requireHqUpdate()
            }

            Fade {
                anchors.fill: parent
                onTapped: actions.visible = false
            }

            PopupMenu {
                width: Units.dp(280)
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2

                // Only when there's no Open with, as for audiobooks: an ebook opens straight
                // from the list
                PopupMenuItem {
                    objectName: "openBook"
                    visible: page.versionOnDevice && page.openWithTarget === null
                    icon: "e3_menu_open"
                    text: "Open book"
                    onClicked: {
                        actions.visible = false
                        page.openChosen(page.version.bookId, page.hasKinds ? page.kind : "")
                    }
                }
                PopupMenuItem {
                    objectName: "download"
                    visible: !page.versionOnDevice
                    icon: "download_from_cloud"
                    text: "Download"
                    onClicked: {
                        actions.visible = false
                        page.downloadChosen(page.version.book, [page.version])
                    }
                }
                OpenWithItem {
                    id: openWithItem
                    target: page.openWithTarget
                }
                Repeater {
                    model: openWithItem.apps
                    PopupMenuItem {
                        required property var modelData
                        objectName: modelData.name
                        subItem: true
                        text: modelData.name
                        // Closing empties this Repeater and destroys the item, so ids and
                        // modelData are read first
                        onClicked: {
                            const infoPage = page
                            const target = page.openWithTarget
                            const app = modelData
                            actions.visible = false
                            infoPage.openWithChosen(target, app)
                        }
                    }
                }
                PopupMenuItem {
                    objectName: "deleteBook"
                    visible: page.versionOnDevice
                    icon: "trash"
                    text: "Delete"
                    onClicked: {
                        actions.visible = false
                        page.deleteChosen(page.book, page.hasKinds ? page.kind : "")
                    }
                }
            }
        }
    ]
}
