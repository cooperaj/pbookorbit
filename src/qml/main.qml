import QtQuick
import QtQuick.Window
import "units.js" as Units
import "night.js" as Night
import "books.js" as Books

Window {
    id: root
    visible: true
    width: screenWidth
    height: windowHeight
    color: "white"

    // Faster e-ink updates while typing. callLater because moving focus between fields
    // briefly leaves neither focused.
    readonly property bool typing: (loginPage.visible && loginPage.typing)
                                   || (searchPage.visible && searchPage.typing)
    onTypingChanged: Qt.callLater(() => eink.setDynamicUpdates(root.typing))

    // Search page, over everything else
    property bool searching: false
    // Pages opened from the book menu, a collection or an author, stacked over the search
    // page: author info, then their series, then a books-of list, then book info
    property bool showingAuthor: false
    property bool showingAuthorSeries: false
    property bool showingBooksOf: false
    property bool showingInfo: false

    function closePages() {
        bookMenu.close()
        showingInfo = false
        showingBooksOf = false
        booksOfBack = []
        showingAuthorSeries = false
        showingAuthor = false
        searching = false
    }

    function openSearch() {
        menu.visible = false
        searching = true
        searchPage.open()
    }

    // Opens a downloaded book in its reader (the ebook if both versions are there).
    // Otherwise offers to download it, asking which version if there's an ebook and an
    // audiobook.
    function openBook(book) {
        const onDevice = Books.recordOnDevice(book, downloads)
        if (onDevice !== undefined)
            downloads.open(onDevice)
        else
            downloadDialog.show(book, book.variants || [])
    }

    // Opens target (see Books.openWithTarget) in app, downloading it first if needed
    function openWith(target, app) {
        if (target.option === undefined)
            downloads.openWith(target.bookId, target.format, app.app)
        else
            downloadDialog.show(target.option.book, [target.option], app)
    }

    // Tapping the title scrolls the current list back to the top
    function backToTop() {
        menu.visible = false
        closeDropdowns()
        if (activeList)
            activeList.positionViewAtBeginning()
    }

    // Footer views: Library, Collections, Series or Authors
    readonly property bool showingCollections: footer.currentIndex === 1
    readonly property bool showingSeries: footer.currentIndex === 2
    readonly property bool showingAuthors: footer.currentIndex === 3
    // The page in front: the topmost of the pages opened over the views, else the view.
    // Each has pageButtons; list pages also have their list and query.
    readonly property Item frontPage: showingInfo ? bookInfoPage
                                      : showingBooksOf ? booksOfPage
                                      : showingAuthorSeries ? authorSeriesPage
                                      : showingAuthor ? authorInfoPage
                                      : searching ? searchPage
                                      : !bookOrbit.session.signedIn ? null
                                      : showingCollections ? collectionsPage
                                      : showingSeries ? seriesPage
                                      : showingAuthors ? authorsPage : libraryPage
    // Its list, if it has one, whose sub-toolbar menus are in use
    readonly property ListView activeList: frontPage?.list ?? null

    AppHeader {
        id: header
        objectName: "appHeader"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        // "Orbit" in the user's BookOrbit accent colour
        title: "PocketBook × Book<font color=\"" + Night.color(bookOrbit.theme.accentColor) + "\">Orbit</font>"
        menuOpen: menu.visible
        offline: bookOrbit.session.signedIn && !bookOrbit.session.online
        showSearch: bookOrbit.session.signedIn
        onHomeClicked: Qt.quit()
        onTitleClicked: root.backToTop()
        onSecretTapped: {
            diagnostics.toggle()
            diagnosticsDialog.visible = true
        }
        onSearchClicked: root.openSearch()
        onMenuClicked: menu.visible = !menu.visible
    }

    // Signed out
    LoginPage {
        id: loginPage
        objectName: "loginPage"
        visible: !bookOrbit.session.signedIn
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    // Signed in: sub-toolbar with filter and sort, the book list, and a footer for the
    // Library sort and filter. Dates default to newest first, everything else to A-Z.
    ListQuery {
        id: libraryQuery
        sorts: [
            { name: "Date added", field: "addedAt", descending: true },
            { name: "Title", field: "title", descending: false },
            { name: "Author", field: "author", descending: false },
            { name: "Recently read", field: "lastReadAt", descending: true }
        ]
        sortIndex: 1   // Title, matching bookOrbit's default
        onApplied: bookOrbit.library.setQuery(sortField, descending(), formats, downloadedOnly)
    }
    // Collection sorts from BookOrbit's collections page, minus "Custom order": A-Z, and
    // most books first
    ListQuery {
        id: collectionsQuery
        sorts: [
            { name: "Name", field: "name", descending: false },
            { name: "Book count", field: "bookCount", descending: true }
        ]
        hasFilter: false
        onApplied: bookOrbit.collections.setSort(sortField, descending())
    }
    // Series sorts from BookOrbit's series page: A-Z, then most books, latest added and
    // most read first
    ListQuery {
        id: seriesQuery
        sorts: [
            { name: "Name", field: "name", descending: false },
            { name: "Book count", field: "bookCount", descending: true },
            { name: "Recently added", field: "lastAddedAt", descending: true },
            { name: "Read progress", field: "readProgress", descending: true }
        ]
        hasFilter: false
        onApplied: bookOrbit.series.setSort(sortField, descending())
    }
    // Author sorts from BookOrbit's authors page: A-Z by name or surname, most books and
    // latest added first. Filtered by their books, like the library.
    ListQuery {
        id: authorsQuery
        sorts: [
            { name: "Name", field: "name", descending: false },
            { name: "Sort name", field: "sortName", descending: false },
            { name: "Book count", field: "bookCount", descending: true },
            { name: "Recently added", field: "lastAddedAt", descending: true }
        ]
        onApplied: bookOrbit.authors.setQuery(sortField, descending(), formats, downloadedOnly)
    }
    // An author's series: the Series view's sorts, kept between authors
    ListQuery {
        id: authorSeriesQuery
        sorts: seriesQuery.sorts
        hasFilter: false
        onApplied: bookOrbit.authorSeries.setSort(sortField, descending())
    }
    function openAuthorSeries(name) {
        authorSeriesPage.name = name
        bookOrbit.authorSeries.show(name)
        authorSeriesPage.list.positionViewAtBeginning()
        showingAuthorSeries = true
    }
    // Books of an author, series or collection (see bookOrbit.booksOf.show()). Each field
    // keeps its own sort and filter between uses, like the library.
    property string booksOfField
    property var booksOfValues: []
    readonly property ListQuery booksOfQuery: booksOfField === "series" ? seriesBooksQuery
                                              : booksOfField === "collection" ? collectionBooksQuery
                                              : authorBooksQuery
    // field is "author", "series" or "collection", values the names (or collection id) to
    // match, and title the name shown, if not the values
    function openBooksOf(field, values, title) {
        booksOfBack.push({ booksOf: showingBooksOf ? { field: booksOfField, values: booksOfValues, title: booksOfPage.name }
                                                   : null,
                           info: null })
        showBooksOf(field, values, title)
    }
    function showBooksOf(field, values, title) {
        booksOfPage.kind = field === "series" ? "Series" : field === "collection" ? "Collection"
                           : values.length > 1 ? "Authors" : "Author"
        booksOfPage.name = title || values.join(", ")
        booksOfField = field
        booksOfValues = values
        booksOfQuery.applied()
        showingBooksOf = true
    }
    // Opened from a book's info page, which is above the books-of page, so closes it. Back
    // reopens it.
    function openBooksOfFromInfo(field, values) {
        const info = { book: bookInfoPage.book, kind: bookInfoPage.kind }
        showingInfo = false
        openBooksOf(field, values)
        booksOfBack[booksOfBack.length - 1].info = info
    }
    // What each books-of list replaced, for Back: the list before it, if any, and the info
    // page it was opened from
    property var booksOfBack: []
    function closeBooksOf() {
        const previous = booksOfBack.pop()
        if (previous?.booksOf)
            showBooksOf(previous.booksOf.field, previous.booksOf.values, previous.booksOf.title)
        else
            showingBooksOf = false
        if (previous?.info) {
            if (bookInfoPage.book !== previous.info.book)
                bookInfoPage.show(previous.info.book)
            if (bookInfoPage.kind !== previous.info.kind)
                bookInfoPage.choose(previous.info.kind)
            showingInfo = true
        }
    }
    function applyBooksOf(query) {
        bookOrbit.booksOf.show(booksOfField, booksOfValues, query.sortField, query.descending(), query.formats,
                               query.downloadedOnly)
    }
    // An author's books use the library's sorts
    ListQuery {
        id: authorBooksQuery
        sorts: libraryQuery.sorts
        sortIndex: 1
        onApplied: root.applyBooksOf(authorBooksQuery)
    }
    // A series' books: series order first, then the library's sorts
    ListQuery {
        id: seriesBooksQuery
        sorts: [{ name: "Series order", field: "seriesIndex", descending: false }].concat(libraryQuery.sorts)
        onApplied: root.applyBooksOf(seriesBooksQuery)
    }
    // A collection's books: the library's sorts, with Date added meaning when it was added
    // to the collection
    ListQuery {
        id: collectionBooksQuery
        sorts: libraryQuery.sorts.map(sort => sort.field === "addedAt" ? Object.assign({}, sort, { field: "collectionOrder" })
                                                                       : sort)
        sortIndex: 1
        onApplied: root.applyBooksOf(collectionBooksQuery)
    }
    // Downloads (and details lookups) change the downloaded book list, and with it the
    // lists showing it
    readonly property int downloadsRevision: downloads.revision
    onDownloadsRevisionChanged: bookOrbit.setLocalBooks(downloads.downloadedBooks())

    // Going offline or back online changes what lists that aren't downloaded only show
    Connections {
        target: bookOrbit.session
        function onOnlineChanged() {
            if (!libraryQuery.downloadedChosen)
                libraryQuery.applied()
            if (showingBooksOf && !booksOfQuery.downloadedChosen)
                booksOfQuery.applied()
            if (!authorsQuery.downloadedChosen)
                authorsQuery.applied()
            // Offline, series are the downloaded books'
            root.reloadGroupLists()
        }
        // The library list reloads itself; pages opened over the lists were the old library's
        function onLibraryChanged() {
            root.closePages()
            root.reloadGroupLists()
        }
    }

    // Loads the group lists on screen again
    function reloadGroupLists() {
        if (showingSeries)
            bookOrbit.series.load()
        if (showingAuthorSeries)
            bookOrbit.authorSeries.show(authorSeriesPage.name)
        if (showingAuthors)
            bookOrbit.authors.load()
        if (showingCollections)
            bookOrbit.collections.load()
    }
    Component.onCompleted: {
        bookOrbit.setLocalBooks(downloads.downloadedBooks())
        // Starting offline: list the downloaded books before bookOrbit.start() loads the
        // list
        if (!bookOrbit.session.online)
            libraryQuery.applied()
    }

    // The sort and filter shown by the menus, for whichever page is in front
    // The front page's, or the library's for a page without one, which has no menus
    readonly property ListQuery activeQuery: frontPage?.query ?? libraryQuery
    readonly property bool dropdownOpen: filterMenu.visible || sortMenu.visible

    // The page-turn keys (sent as Page Up/Page Down) page the front list or info page, like
    // its page buttons. Not on the sign-in page, and not while a menu or dialog is open,
    // since a tap would only close it.
    readonly property PageButtons frontPageButtons: frontPage?.pageButtons ?? null
    readonly property bool overlayOpen: dropdownOpen || menu.visible || bookMenu.visible
                                        || deleteDialog.visible || downloadDialog.visible
                                        || findBooksDialog.visible || libraryDialog.visible
                                        || bookInfoPage.menuOpen

    function pageFront(direction) {
        if (frontPageButtons && frontPageButtons.visible && !overlayOpen)
            frontPageButtons.page(direction)
    }

    Shortcut {
        sequence: "PgUp"
        onActivated: root.pageFront(-1)
    }
    Shortcut {
        sequence: "PgDown"
        onActivated: root.pageFront(1)
    }

    function closeDropdowns() {
        filterMenu.visible = false
        sortMenu.visible = false
    }

    // Where every list's jump rail puts its letters, so they're at the same height on every
    // page: centred in the library's rail space, between its sub-toolbar and page buttons
    // (every list's are the same height)
    RailLayout {
        id: rails
        top: header.height + openTab.height + inset
        bottom: footer.y - libraryPage.pageButtons.height - inset
    }

    // The shared menus, for the list pages' sub-toolbars
    ListMenus {
        id: listMenus
        filterOpen: filterMenu.visible
        sortOpen: sortMenu.visible
        onFilterClicked: root.toggleDropdown(filterMenu)
        onSortClicked: root.toggleDropdown(sortMenu)
    }

    function toggleDropdown(dropdown) {
        const open = !dropdown.visible
        closeDropdowns()
        if (open) {
            // Bring a partly scrolled-off bar fully into view first
            if (activeList.headerItem.mapToItem(root.contentItem, 0, 0).y
                    < activeList.mapToItem(root.contentItem, 0, 0).y)
                activeList.positionViewAtBeginning()
            // Align the menu and the tab copy with where the sub-toolbar has scrolled to.
            // The list can't move while a menu is open, since the fade takes taps.
            openTab.y = activeList.headerItem.mapToItem(root.contentItem, 0, 0).y
            dropdown.visible = true
        }
    }

    BookListPage {
        id: libraryPage
        objectName: "libraryPage"
        listName: "bookList"
        railName: "libraryRail"
        emptyName: "libraryEmptyState"
        visible: bookOrbit.session.signedIn && !root.showingCollections && !root.showingSeries && !root.showingAuthors
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        model: bookOrbit.library.model
        query: libraryQuery
        menus: listMenus
        // For A-Z sorts
        jumpSections: bookOrbit.library.jumpSections
        railLayout: rails
        error: bookOrbit.library.error
        // The spinner only until the first books arrive; later pages load on scroll. No
        // books says so.
        loading: bookOrbit.session.busy
        empty: bookOrbit.library.total === 0
        emptyTitle: libraryQuery.downloadedOnly
                    ? ["No downloaded books", "No downloaded ebooks", "No downloaded audiobooks"][libraryQuery.filterIndex]
                    : ["No books", "No ebooks", "No audiobooks"][libraryQuery.filterIndex]
        emptyText: !bookOrbit.session.online ? offlineText()
                   : libraryQuery.downloadedOnly ? "Books you download show here, and can be read offline."
                   : "Books in your BookOrbit library show here."
        onRowsWanted: (first, last) => bookOrbit.library.load(first, last)
        onBookClicked: (book) => root.openBook(book)
        onBookHeld: (row) => bookMenu.open(row)
    }

    GroupListPage {
        id: collectionsPage
        objectName: "collectionsPage"
        visible: bookOrbit.session.signedIn && root.showingCollections
        groups: bookOrbit.collections
        emptyTitle: "No collections"
        emptyText: bookOrbit.session.online ? "Collections you make in BookOrbit show here."
                                    : offlineText("collections containing downloaded books")
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        query: collectionsQuery
        railLayout: rails
        menus: listMenus
        // Reloaded every time the view opens, showing the last rows until then, and the books
        // of the collections in view looked up. Offline, the saved collections' downloaded
        // books.
        onVisibleChanged: if (visible) bookOrbit.collections.load()
        onGroupClicked: (collection) => root.openBooksOf("collection", [String(collection.id)], collection.name)
    }

    GroupListPage {
        id: seriesPage
        objectName: "seriesPage"
        visible: bookOrbit.session.signedIn && root.showingSeries
        groups: bookOrbit.series
        emptyTitle: "No series"
        emptyText: bookOrbit.session.online ? "Series show here once books in the library belong to one."
                                    : offlineText("series with downloaded books")
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        query: seriesQuery
        railLayout: rails
        menus: listMenus
        // Reloaded every time the view opens, showing the last rows until then, and the books
        // of the series in view looked up. Offline, the downloaded books'.
        onVisibleChanged: if (visible) bookOrbit.series.load()
        onGroupClicked: (series) => root.openBooksOf("series", [series.name])
    }

    GroupListPage {
        id: authorsPage
        objectName: "authorsPage"
        visible: bookOrbit.session.signedIn && root.showingAuthors
        groups: bookOrbit.authors
        // Filtered by format, authors appear once every author's books have been looked up.
        // Downloaded only uses the downloaded books.
        loaded: bookOrbit.authors.loaded && (bookOrbit.authors.allLookedUp || authorsQuery.filterIndex === 0
                                             || authorsQuery.downloadedOnly)
        emptyTitle: authorsQuery.downloadedOnly || authorsQuery.filterIndex === 0 ? "No authors"
                    : "No authors with " + authorsQuery.filterName.toLowerCase()
        emptyText: !bookOrbit.session.online ? offlineText("authors of downloaded books")
                   : authorsQuery.downloadedOnly ? "Turn off Downloaded only to see every author."
                   : authorsQuery.filterIndex !== 0 ? "Choose All titles to see every author."
                   : "Authors show here once the library has books."
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        query: authorsQuery
        railLayout: rails
        menus: listMenus
        // Reloaded every time the view opens, like the series
        onVisibleChanged: if (visible) bookOrbit.authors.load()
        onGroupClicked: (author) => {
            authorInfoPage.show(author.id)
            root.showingAuthor = true
        }
    }

    TabFooter {
        id: footer
        visible: bookOrbit.session.signedIn
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        // BookOrbit's views
        tabs: [
            { label: "Library", icon: "overdrive_library" },
            { label: "Collections", icon: "e3_filter_bookshelf" },
            { label: "Series", icon: "e3_filter_seria_bold" },
            { label: "Authors", icon: "e3_filter_author" }
        ]
        onTabClicked: (index) => {
            // Tapping the current tab again scrolls its list to the top
            if (index === currentIndex) {
                if (root.activeList)
                    root.activeList.positionViewAtBeginning()
            } else {
                root.closeDropdowns()
                currentIndex = index
            }
        }
    }

    // While a filter or sort menu is open the window fades, as in Libby. Tapping elsewhere
    // closes it.
    Fade {
        anchors.fill: parent
        z: 1
        visible: root.dropdownOpen
        onTapped: root.closeDropdowns()
    }
    // The open tab, drawn over the fade at the sub-toolbar's position
    SubToolbar {
        id: openTab
        visible: root.dropdownOpen
        z: 2
        width: parent.width
        onlyOpenTab: true
        query: root.activeQuery
        filterOpen: filterMenu.visible
        sortOpen: sortMenu.visible
        onFilterClicked: root.closeDropdowns()
        onSortClicked: root.closeDropdowns()
    }
    PopupMenu {
        id: filterMenu
        objectName: "filterMenu"
        visible: false
        z: 3
        x: openTab.filterMenuX
        y: openTab.y + openTab.menuY
        joinedCorner: "topLeft"
        sidePadding: 0

        MenuHeading { text: "Content type" }
        Repeater {
            model: root.activeQuery.filterOptions
            RadioMenuItem {
                required property string modelData
                required property int index
                objectName: modelData
                text: modelData
                checked: index === root.activeQuery.filterIndex
                showSeparator: index < root.activeQuery.filterOptions.length - 1
                onClicked: {
                    root.activeQuery.chooseFilter(index)
                    root.closeDropdowns()
                }
            }
        }
        // Tied to the content type, so the menu stays open for that choice too
        SwitchMenuItem {
            objectName: "downloadedOnly"
            text: "Downloaded only"
            checked: root.activeQuery.downloadedOnly
            // Always on offline
            enabled: bookOrbit.session.online
            onClicked: root.activeQuery.setDownloadedOnly(!root.activeQuery.downloadedOnly)
        }
    }
    PopupMenu {
        id: sortMenu
        objectName: "sortMenu"
        visible: false
        z: 3
        x: openTab.sortMenuRight - width
        y: openTab.y + openTab.menuY
        joinedCorner: "topRight"
        sidePadding: 0

        MenuHeading { text: "Sort by" }
        Repeater {
            model: root.activeQuery.sortOptions
            RadioMenuItem {
                required property string modelData
                required property int index
                objectName: modelData
                text: modelData
                checked: index === root.activeQuery.sortIndex
                onClicked: {
                    root.activeQuery.chooseSort(index)
                    root.closeDropdowns()
                }
            }
        }
    }

    // Header menu, dropping from the menu button. As in the system apps, the page below the
    // header fades and tapping it closes the menu.
    Fade {
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        objectName: "headerMenuFade"
        visible: menu.visible
        onTapped: menu.visible = false
    }
    PopupMenu {
        id: menu
        objectName: "headerMenu"
        visible: false
        anchors.top: header.bottom
        anchors.topMargin: Units.dp(1)
        anchors.right: parent.right
        anchors.rightMargin: Units.dp(9)

        // Offline: asks the system to connect
        PopupMenuItem {
            objectName: "reconnect"
            visible: bookOrbit.session.signedIn && !bookOrbit.session.online
            text: "Reconnect"
            onClicked: {
                menu.visible = false
                bookOrbit.session.goOnline()
            }
        }
        // Needs the server's library
        PopupMenuItem {
            objectName: "findBooks"
            visible: bookOrbit.session.signedIn && bookOrbit.session.online
            text: "Find books on this device"
            onClicked: {
                menu.visible = false
                findBooksDialog.search()
            }
        }
        // Only when there's another to choose
        PopupMenuItem {
            objectName: "changeLibrary"
            visible: bookOrbit.session.signedIn && bookOrbit.session.online
                     && bookOrbit.session.libraryCount > 1
            text: "Change library"
            onClicked: {
                menu.visible = false
                bookOrbit.session.changeLibrary()
            }
        }
        // Signed out too, in case an update is what signing in needs
        PopupMenuItem {
            objectName: "checkForUpdates"
            text: "Check for updates"
            onClicked: {
                menu.visible = false
                updateDialog.check()
            }
        }
        PopupMenuItem {
            objectName: "signOut"
            visible: bookOrbit.session.signedIn
            text: "Sign out"
            onClicked: {
                menu.visible = false
                root.closePages()
                bookOrbit.session.signOut()
            }
        }
    }

    SearchPage {
        id: searchPage
        objectName: "searchPage"
        anchors.fill: parent
        visible: root.searching
        headerHeight: header.height
        onBack: root.searching = false
        onBookClicked: (book) => root.openBook(book)
        onBookHeld: (row) => bookMenu.open(row)
    }

    AuthorInfoPage {
        id: authorInfoPage
        objectName: "authorInfoPage"
        anchors.fill: parent
        visible: root.showingAuthor
        onBack: root.showingAuthor = false
        onBooksClicked: {
            root.openBooksOf("author", [authorInfoPage.author.name])
        }
        // Go straight to the series if there's only one
        onSeriesClicked: {
            const names = authorInfoPage.seriesNames
            if (authorInfoPage.seriesCount === 1 && names.length === 1)
                root.openBooksOf("series", [names[0]])
            else
                root.openAuthorSeries(authorInfoPage.author.name)
        }
    }

    // An author's series, opened from their info page
    AuthorSeriesPage {
        id: authorSeriesPage
        objectName: "authorSeriesPage"
        anchors.fill: parent
        visible: root.showingAuthorSeries
        query: authorSeriesQuery
        railLayout: rails
        menus: listMenus
        onBack: {
            root.closeDropdowns()
            root.showingAuthorSeries = false
        }
        onGroupClicked: (series) => root.openBooksOf("series", [series.name])
    }

    BooksOfPage {
        id: booksOfPage
        objectName: "booksOfPage"
        railLayout: rails
        // Sub-toolbar, using the shared menus
        query: root.booksOfQuery
        menus: listMenus
        anchors.fill: parent
        visible: root.showingBooksOf
        onBack: {
            root.closeDropdowns()
            root.closeBooksOf()
        }
        onBookClicked: (book) => root.openBook(book)
        onBookHeld: (row) => bookMenu.open(row)
    }

    BookInfoPage {
        id: bookInfoPage
        objectName: "bookInfoPage"
        anchors.fill: parent
        visible: root.showingInfo
        onBack: root.showingInfo = false
        onBooksOfChosen: (field, values) => root.openBooksOfFromInfo(field, values)
        onOpenChosen: (bookId, kind) => downloads.open(bookId, kind)
        onDownloadChosen: (book, versions) => downloadDialog.show(book, versions)
        onDeleteChosen: (book, kind) => deleteDialog.ask(book, kind)
        onOpenWithChosen: (target, app) => root.openWith(target, app)
    }

    // Over the pages, opened from any of their book lists
    BookMenu {
        id: bookMenu
        objectName: "bookMenu"
        anchors.fill: parent
        onInfoChosen: (book) => {
            bookInfoPage.show(book)
            root.showingInfo = true
        }
        onBooksOfChosen: (field, values) => root.openBooksOf(field, values)
        onDeleteChosen: (book) => deleteDialog.ask(book)
        onOpenWithChosen: (target, app) => root.openWith(target, app)
    }

    // Confirms deleting a book from the device, as the system library does.
    // With an ebook and an audiobook on the device it asks which, as DownloadDialog does.
    SystemDialog {
        id: deleteDialog
        objectName: "deleteDialog"
        anchors.fill: parent
        property var book: ({})
        // The book's records, and the kinds on the device ("ebook", "audiobook")
        property var ids: []
        property var kinds: []
        // Set when asked about one version only
        property string onlyKind: ""
        // Set if a file couldn't be deleted
        property bool failed: false

        // onlyKind deletes just that version, after a Yes/No
        function ask(newBook, newOnlyKind) {
            book = newBook
            onlyKind = newOnlyKind || ""
            ids = Books.recordIds(newBook)
            kinds = onlyKind !== "" ? [onlyKind] : Books.kindsOnDevice(newBook, downloads)
            failed = false
            visible = true
        }

        icon: failed ? "icon_error" : "icon_question"
        buttons: failed ? [["Close", "no"]]
                 : kinds.length > 1 ? [["Cancel", "no"]].concat(kinds.map(k => [k, k]))
                 : [["No", "no"], ["Yes", onlyKind !== "" ? onlyKind : "all"]]
        onPressed: (action) => {
            if (action !== "no") {
                let deleted = true
                for (const id of ids)
                    deleted = downloads.remove(id, action === "all" ? "" : action) && deleted
                if (!deleted) {
                    failed = true
                    return
                }
            }
            visible = false
        }
        message: failed
                 ? "Couldn't delete " + (book.title || "") + " from your device."
                 : kinds.length > 1
                 ? "Delete the " + kinds.join(" or the ") + " of " + (book.title || "") + " from your device?"
                 : "Are you sure you want to delete " + (onlyKind !== "" ? "the " + onlyKind + " of " : "")
                   + (book.title || "") + " from your device?"
    }

    // Above everything, including the search page
    DownloadDialog {
        id: downloadDialog
        objectName: "downloadDialog"
        anchors.fill: parent
        onOpened: (bookId, format, app) => app ? downloads.openWith(bookId, format, app.app) : downloads.open(bookId)
    }
    LibraryDialog {
        id: libraryDialog
        objectName: "libraryDialog"
        anchors.fill: parent
    }
    FindBooksDialog {
        id: findBooksDialog
        objectName: "findBooksDialog"
        anchors.fill: parent
    }
    UpdateDialog {
        id: updateDialog
        objectName: "updateDialog"
        anchors.fill: parent
        // The launcher starts the app again, with the update
        onRestartRequested: Qt.quit()
    }
    // Shown when tapping the title six times turns diagnostics logging on or off
    SystemDialog {
        id: diagnosticsDialog
        anchors.fill: parent
        icon: "icon_information"
        buttons: [["Close", "close"]]
        onPressed: visible = false
        heading: diagnostics.enabled ? "Diagnostics logging is on" : "Diagnostics logging is off"
        message: diagnostics.enabled
                 ? "Details for bug reports are written to pbookorbit.log on your device's storage."
                 : "Only startup details and errors are written to pbookorbit.log."
    }
    // On first run, the app adds its tile to the applications screen. It only appears after
    // a restart.
    SystemDialog {
        id: launcherTileDialog
        anchors.fill: parent
        // The device is slow to begin restarting, so the dialog stays up to say so
        property bool restarting: false
        visible: launcherTile.added
        icon: "icon_information"
        buttons: restarting ? [] : [["Later", "close"], ["Restart now", "restart"]]
        onPressed: (action) => {
            if (action === "restart") {
                restarting = true
                restartTimer.start()
            } else
                visible = false
        }

        // Give the screen time to show the restarting message first
        Timer {
            id: restartTimer
            interval: 500
            onTriggered: launcherTile.restartDevice()
        }

        heading: restarting ? "Restarting…" : "Added to your applications"
        message: restarting
                 ? "Your device is restarting. This can take a minute."
                 : "PBookOrbit now has its own name and icon in your applications."
                   + " Restart your device to see them."
    }
    // After the first sign-in, offer to find books already on the device, if there are any.
    // Only once; after that it's in the menu. Not before the library is chosen, since it
    // looks through that library.
    property bool offerFindBooks: false
    Connections {
        target: bookOrbit.session
        function onSignedInChanged() {
            root.offerFindBooks = bookOrbit.session.signedIn
        }
        function onLibraryReady() {
            if (root.offerFindBooks && bookFinder.shouldOffer()) {
                bookFinder.markOffered()
                findBooksDialog.offer()
            }
            root.offerFindBooks = false
        }
    }
}
