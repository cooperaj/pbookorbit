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

    // Search page, over everything else. Each search starts with the lists' content type
    // and Downloaded only, every library and Title A-Z, and ends on going back, opening a
    // book or signing out. Pages opened from it keep it as it was.
    property bool searching: false
    onSearchingChanged: {
        if (searching) {
            bookOrbit.searchFilter.copy(bookOrbit.filter)
        } else {
            searchPage.reset()
            searchQuery.resetSort()
            searchQuery.libraryId = -1
            // With the text gone, nothing is searched
            searchQuery.applied()
        }
    }
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
            bookOpened(downloads.open(onDevice))
        else
            downloadDialog.show(book, book.variants || [])
    }

    // Opens target (see Books.openWithTarget) in app, downloading it first if needed
    function openWith(target, app) {
        if (target.option === undefined)
            bookOpened(downloads.openWith(target.bookId, target.format, app.app))
        else
            downloadDialog.show(target.option.book, [target.option], app)
    }

    // Opening a book ends a search, closing the pages opened from it
    function bookOpened(opened) {
        if (opened && searching)
            closePages()
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
        // The session's, kept until signing out
        hasLibraries: true
        libraryId: bookOrbit.session.libraryId
        onLibraryChosen: (id) => bookOrbit.session.chooseLibrary(id)
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
        hasContentType: false
        onApplied: bookOrbit.collections.setSort(sortField, descending())
    }
    // Series sorts from BookOrbit's series page: A-Z, then most books, latest added and
    // most read first. Filtered by their books, like the library.
    ListQuery {
        id: seriesQuery
        sorts: [
            { name: "Name", field: "name", descending: false },
            { name: "Book count", field: "bookCount", descending: true },
            { name: "Recently added", field: "lastAddedAt", descending: true },
            { name: "Read progress", field: "readProgress", descending: true }
        ]
        hasLibraries: true
        allLibraries: true
        libraryId: bookOrbit.series.libraryId
        onLibraryChosen: (id) => root.chooseGroupLibrary(bookOrbit.series, id)
        onApplied: bookOrbit.series.setQuery(sortField, descending(), formats, downloadedOnly)
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
        hasLibraries: true
        allLibraries: true
        libraryId: bookOrbit.authors.libraryId
        onLibraryChosen: (id) => root.chooseGroupLibrary(bookOrbit.authors, id)
        onApplied: bookOrbit.authors.setQuery(sortField, descending(), formats, downloadedOnly)
    }
    // Search results: the library's sorts, and every library's books or one library's. Its
    // content type and Downloaded only are its own (see searching).
    ListQuery {
        id: searchQuery
        filter: bookOrbit.searchFilter
        sorts: libraryQuery.sorts
        sortIndex: 1
        hasLibraries: true
        allLibraries: true
        onLibraryChosen: (id) => {
            libraryId = id
            applied()
        }
        onApplied: bookOrbit.search.setQuery(sortField, descending(), formats, downloadedOnly, libraryId)
    }
    Connections {
        target: bookOrbit.searchFilter
        function onChanged() {
            root.searchRevision++
            root.applyChangedFilter()
        }
    }
    // Shows the groups of one library, or all for -1, in Series or Authors, kept for next
    // time
    function chooseGroupLibrary(groups, id) {
        groups.setLibrary(id)
        groups.load()
    }
    // An author's series: the Series view's sorts, kept between authors, and every library's
    // each time
    ListQuery {
        id: authorSeriesQuery
        sorts: seriesQuery.sorts
        hasLibraries: true
        allLibraries: true
        libraryId: bookOrbit.authorSeries.libraryId
        onLibraryChosen: (id) => {
            bookOrbit.authorSeries.setLibrary(id)
            bookOrbit.authorSeries.show(authorSeriesPage.name)
        }
        onApplied: bookOrbit.authorSeries.setQuery(sortField, descending(), formats, downloadedOnly)
    }
    function openAuthorSeries(name) {
        authorSeriesPage.name = name
        bookOrbit.authorSeries.setLibrary(-1)
        bookOrbit.authorSeries.show(name)
        authorSeriesPage.list.positionViewAtBeginning()
        showingAuthorSeries = true
    }
    // Books of an author, series or collection (see bookOrbit.booksOf.show()). Each field
    // keeps its own sort between uses, like the library. Each list starts with every
    // library's books.
    property string booksOfField
    property var booksOfValues: []
    property int booksOfLibraryId: -1
    readonly property ListQuery booksOfQuery: booksOfField === "series" ? seriesBooksQuery
                                              : booksOfField === "collection" ? collectionBooksQuery
                                              : authorBooksQuery
    // field is "author", "series" or "collection", values the names (or collection id) to
    // match, and title the name shown, if not the values
    function openBooksOf(field, values, title) {
        booksOfBack.push({ booksOf: showingBooksOf ? { field: booksOfField, values: booksOfValues, title: booksOfPage.name,
                                                       libraryId: booksOfLibraryId }
                                                   : null,
                           info: null })
        showBooksOf(field, values, title, -1)
    }
    // libraryId is the library whose books to show, or -1 for every library's
    function showBooksOf(field, values, title, libraryId) {
        booksOfPage.kind = field === "series" ? "Series" : field === "collection" ? "Collection"
                           : values.length > 1 ? "Authors" : "Author"
        booksOfPage.name = title || values.join(", ")
        booksOfField = field
        booksOfValues = values
        booksOfLibraryId = libraryId
        applyFilter(booksOfQuery)
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
            showBooksOf(previous.booksOf.field, previous.booksOf.values, previous.booksOf.title,
                        previous.booksOf.libraryId)
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
                               query.downloadedOnly, booksOfLibraryId)
    }
    function chooseBooksOfLibrary(query, id) {
        booksOfLibraryId = id
        query.applied()
    }
    // An author's books use the library's sorts
    ListQuery {
        id: authorBooksQuery
        sorts: libraryQuery.sorts
        sortIndex: 1
        hasLibraries: true
        allLibraries: true
        libraryId: root.booksOfLibraryId
        onLibraryChosen: (id) => root.chooseBooksOfLibrary(authorBooksQuery, id)
        onApplied: root.applyBooksOf(authorBooksQuery)
    }
    // A series' books: series order first, then the library's sorts
    ListQuery {
        id: seriesBooksQuery
        sorts: [{ name: "Series order", field: "seriesIndex", descending: false }].concat(libraryQuery.sorts)
        hasLibraries: true
        allLibraries: true
        libraryId: root.booksOfLibraryId
        onLibraryChosen: (id) => root.chooseBooksOfLibrary(seriesBooksQuery, id)
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

    // The content type and Downloaded only: every list's (bookOrbit.filter), and search's
    // own (bookOrbit.searchFilter). A change applies to the list in front at once, and to
    // each of the others with that filter when it's next shown. Counted by filterRevision
    // and searchRevision; each query records its filter's when applied.
    property int filterRevision: 0
    property int searchRevision: 0
    function revisionOf(query) {
        return query.filter === bookOrbit.searchFilter ? searchRevision : filterRevision
    }
    readonly property ListQuery shownQuery: frontPage?.query ?? null
    onShownQueryChanged: applyChangedFilter()
    function applyFilter(query) {
        query.filterRevision = revisionOf(query)
        query.applied()
    }
    // Applies the front list's filter if it has changed since it was last applied
    function applyChangedFilter() {
        if (shownQuery && shownQuery.filterRevision !== revisionOf(shownQuery))
            applyFilter(shownQuery)
    }
    function filterChanged() {
        filterRevision++
        applyChangedFilter()
        // Signed out: ready for the book list's first load once signed in
        if (!shownQuery && !bookOrbit.session.signedIn)
            prepareLibrary()
    }
    // Lists that aren't downloaded only show other books online than offline
    function connectionChanged() {
        if (!bookOrbit.searchFilter.downloadedOnly)
            searchRevision++
        if (!bookOrbit.filter.downloadedOnly)
            filterChanged()
        else
            applyChangedFilter()
    }
    // Sets the book list's query without loading it, for bookOrbit.start()
    function prepareLibrary() {
        libraryQuery.filterRevision = filterRevision
        bookOrbit.library.setQuery(libraryQuery.sortField, libraryQuery.descending(), libraryQuery.formats,
                                   libraryQuery.downloadedOnly, false)
    }
    Connections {
        target: bookOrbit.filter
        function onChanged() { root.filterChanged() }
    }
    // Going offline or back online changes what lists that aren't downloaded only show
    Connections {
        target: bookOrbit.session
        function onOnlineChanged() {
            // Once the queries' downloadedOnly bindings have caught up
            Qt.callLater(root.connectionChanged)
            // Offline, series are the downloaded books'
            if (showingSeries)
                bookOrbit.series.load()
            if (showingAuthorSeries)
                bookOrbit.authorSeries.show(authorSeriesPage.name)
            if (showingAuthors)
                bookOrbit.authors.load()
            if (showingCollections)
                bookOrbit.collections.load()
        }
    }
    Component.onCompleted: {
        bookOrbit.setLocalBooks(downloads.downloadedBooks())
        // Starting offline: list the downloaded books before bookOrbit.start() loads the
        // list. Online, it loads with the saved filter.
        if (bookOrbit.session.online)
            prepareLibrary()
        else
            applyFilter(libraryQuery)
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
                                        || findBooksDialog.visible || bookInfoPage.menuOpen

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
        emptyTitle: "No " + libraryQuery.listedNoun
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
        noun: "series"
        unfilteredText: "Series show here once books in the library belong to one."
        offlineGroups: "series with downloaded books"
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
        noun: "author"
        pluralNoun: "authors"
        unfilteredText: "Authors show here once the library has books."
        offlineGroups: "authors of downloaded books"
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

        // Only with a choice of libraries
        MenuHeading {
            objectName: "libraries heading"
            visible: root.activeQuery.libraryOptions.length > 0
            text: "Libraries"
        }
        Repeater {
            model: root.activeQuery.libraryOptions
            OptionMenuItem {
                required property var modelData
                required property int index
                objectName: "library " + modelData.name
                text: modelData.name
                checked: modelData.id === root.activeQuery.libraryId
                showSeparator: index < root.activeQuery.libraryOptions.length - 1
                onClicked: {
                    root.activeQuery.chooseLibrary(modelData.id)
                    root.closeDropdowns()
                }
            }
        }
        // Either or both, so the menu stays open
        MenuHeading {
            visible: root.activeQuery.hasContentType
            text: "Content type"
        }
        Repeater {
            model: root.activeQuery.hasContentType ? [["ebook", "Ebooks", root.activeQuery.ebooks],
                                                      ["audiobook", "Audiobooks", root.activeQuery.audiobooks]] : []
            OptionMenuItem {
                required property var modelData
                required property int index
                objectName: modelData[1]
                text: modelData[1]
                checkbox: true
                checked: modelData[2]
                // The last one ticked
                locked: !root.activeQuery.ebooks || !root.activeQuery.audiobooks
                showSeparator: index === 0
                onClicked: root.activeQuery.showContent(modelData[0], !checked)
            }
        }
        // Tied to the content type, so the menu stays open for that choice too
        SwitchMenuItem {
            objectName: "downloadedOnly"
            visible: root.activeQuery.hasContentType
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
            OptionMenuItem {
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
        query: searchQuery
        menus: listMenus
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
        onBooksClicked: root.openBooksOf("author", [authorInfoPage.author.name])
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
        onOpenChosen: (bookId, kind) => root.bookOpened(downloads.open(bookId, kind))
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
        onOpened: (bookId, format, app) => root.bookOpened(app ? downloads.openWith(bookId, format, app.app)
                                                               : downloads.open(bookId))
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
    // Only once; after that it's in the menu.
    Connections {
        target: bookOrbit.session
        function onSignedInChanged() {
            if (bookOrbit.session.signedIn && bookFinder.shouldOffer()) {
                bookFinder.markOffered()
                findBooksDialog.offer()
            }
        }
    }
}
