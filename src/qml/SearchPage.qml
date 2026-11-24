import QtQuick
import QtQuick.Controls
import "units.js" as Units

// Full-window search page, modelled on the Era Color library's search: the toolbar turns
// into a back button and search box, with recent searches below. From three characters,
// matching books replace the recent searches once they arrive, with a spinner in the search
// box meanwhile. The results have a sub-toolbar for their library, filter and sort.
//
// A search is saved to recent searches when the keyboard closes for it (Enter, scrolling
// the results, tapping a book, or the keyboard's close key). Going back doesn't save it.
Rectangle {
    id: page
    // For the page-turn keys, which main.qml forwards to the front page
    readonly property alias pageButtons: results.pageButtons
    readonly property alias list: results.list
    color: "white"

    // The results' sort and filter, and the menus their sub-toolbar opens
    property ListQuery query: null
    property ListMenus menus: null

    // Same height as the main toolbar, so the page below doesn't jump
    property int headerHeight: Units.headerHeight
    // True while the search box has focus, for faster e-ink updates
    readonly property bool typing: searchField.activeFocus
    // Long enough to search (bookOrbit.search.find() ignores shorter text)
    readonly property bool showResults: searchField.text.trim().length >= 3
    // Waiting for typing to pause, or for the results. The spinner replaces the clear
    // button meanwhile.
    readonly property bool searching: showResults && (searchTimer.running || bookOrbit.search.total === -1)
    // The recent searches stay until there are results, or there are none. A refined
    // search keeps the last results until its own arrive.
    readonly property bool showingResults: showResults && (results.list.count > 0 || !searching)

    signal back()
    signal bookClicked(var book)
    signal bookHeld(BookRow row)

    // Set while going back, so losing focus doesn't save the search
    property bool closing: false

    // Focusing the search box opens the on-screen keyboard
    function open() {
        searchField.forceActiveFocus()
    }

    function close() {
        closing = true
        hideKeyboard()
        closing = false
        page.back()
    }

    // Empties the search box once the search has ended, without saving it
    function reset() {
        closing = true
        searchField.text = ""
        closing = false
    }

    // Finishes typing: the box loses focus, which saves the search
    function hideKeyboard() {
        page.forceActiveFocus()
        Qt.inputMethod.hide()
    }

    // Closing the on-screen keyboard ends editing: the box loses focus and its thick
    // border. Tapping it focuses it again.
    Connections {
        target: Qt.inputMethod
        enabled: page.visible
        function onVisibleChanged() {
            if (!Qt.inputMethod.visible && searchField.activeFocus)
                page.forceActiveFocus()
        }
    }

    Item {
        id: header
        width: parent.width
        height: page.headerHeight

        // The search box starts after it
        BackButton {
            id: backButton
            onClicked: page.close()
        }

        // Fills the toolbar right of the back button. With focus it gets a thick black
        // border (covering the toolbar's bottom line), otherwise a 1px line on its left
        // like the rest of the toolbar.
        Rectangle {
            id: searchBox
            readonly property int thickBorder: Units.dp(2)
            x: backButton.x + backButton.width + Units.dp(7)
            width: parent.width - x
            height: parent.height
            border.width: searchField.activeFocus ? thickBorder : 0
            border.color: "black"

            Line {
                visible: !searchField.activeFocus
                vertical: true
            }

            ThemeIcon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: searchBox.thickBorder
                anchors.verticalCenter: parent.verticalCenter
                name: "search_transp"
                // Not every theme has the transparent version
                onStatusChanged: if (status === Image.Error) name = "search"
            }
            // Clears the box once it has text. Under three characters the recent searches
            // come back, so clearing returns to them. Natural size, as in the system library.
            IconButton {
                id: clearButton
                objectName: "clearButton"
                visible: searchField.text !== "" && !page.searching
                anchors.right: parent.right
                anchors.rightMargin: searchBox.thickBorder
                anchors.verticalCenter: parent.verticalCenter
                icon: "remove"
                pressedIcon: "remove_inv"
                fallbackText: "×"
                onClicked: searchField.text = ""
            }
            // In the clear button's place while searching
            SpinnerImage {
                objectName: "searchSpinner"
                visible: page.searching
                anchors.centerIn: clearButton
                frames: "progress_indicator_"
            }
            TextField {
                id: searchField
                objectName: "searchField"
                anchors.left: searchIcon.status === Image.Ready ? searchIcon.right : parent.left
                anchors.right: searchField.text !== "" ? clearButton.left : parent.right
                anchors.margins: searchBox.thickBorder
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Units.dp(3)
                font.pointSize: Units.body
                placeholderText: "Search…"
                placeholderTextColor: "#949494"
                background: null
                // Search when typing pauses, not on every letter. Clearing (under three
                // characters) needn't wait.
                onTextChanged: {
                    // Use the text itself; showResults may not have caught up yet
                    if (text.trim().length >= 3)
                        searchTimer.restart()
                    else {
                        searchTimer.stop()
                        bookOrbit.search.find("")
                    }
                }
                onAccepted: {
                    if (text.trim() === "")
                        return
                    searchTimer.stop()
                    bookOrbit.search.find(text)
                    // Done typing: hide the keyboard to show the results
                    page.hideKeyboard()
                }
                // Save the search however typing ends, except going back
                onActiveFocusChanged: {
                    if (!activeFocus && page.visible && !page.closing)
                        bookOrbit.recentSearches.add(text)
                }
            }
            Timer {
                id: searchTimer
                interval: 400
                onTriggered: bookOrbit.search.find(searchField.text)
            }
        }

        // Toolbar bottom line, under the back button too
        Line {
            anchors.bottom: parent.bottom
        }
    }

    // "RECENT SEARCHES" heading over a full-width line
    Item {
        id: recentHeading
        visible: !page.showingResults
        anchors.top: header.bottom
        width: parent.width
        height: Units.listElementHeight

        Text {
            anchors.centerIn: parent
            text: "Recent searches"
            color: "#737373"
            font.pointSize: Units.body
            font.capitalization: Font.AllUppercase
        }
        Line {
            anchors.bottom: parent.bottom
        }
    }

    ListView {
        objectName: "recentSearches"
        visible: !page.showingResults
        anchors.top: recentHeading.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: bookOrbit.recentSearches.items

        // Inverted while pressed (see PressableRow), with a grey line below
        delegate: PressableRow {
            id: recentRow
            required property string modelData
            objectName: "recent " + modelData
            width: ListView.view.width
            height: Units.listElementHeight
            lineStartInset: Units.dp(26)
            lineEndInset: Units.dp(26)
            lineColor: "#7f7f7f"
            onClicked: {
                // Searched again, so it moves to the top. Grab the text first, since the
                // list changes under the tap.
                const search = modelData
                searchField.text = search
                bookOrbit.recentSearches.add(search)
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: Units.dp(42)
                anchors.right: parent.right
                anchors.rightMargin: Units.dp(26)
                anchors.verticalCenter: parent.verticalCenter
                text: modelData
                color: recentRow.foreground
                font.pointSize: Units.body
                elide: Text.ElideRight
            }
        }
    }

    // Matching books, as library rows without sections, loaded on scroll
    BookListPage {
        id: results
        visible: page.showingResults
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        listName: "searchResults"
        emptyName: "noBooksFound"
        model: bookOrbit.search.model
        query: page.query
        menus: page.menus
        // The spinner is in the search box
        empty: true
        emptyTitle: page.query ? "No " + page.query.listedNoun + " found"
                               : "No books found"
        emptyText: bookOrbit.session.online ? "Try a different title, author or series."
                                    : offlineText("downloaded books", "searched")
        onRowsWanted: (first, last) => bookOrbit.search.load(first, last)
        // Scrolling or tapping a book ends typing, which saves the search
        onScrollStarted: page.hideKeyboard()
        onBookClicked: (book) => {
            page.hideKeyboard()
            page.bookClicked(book)
        }
        onBookHeld: (row) => {
            page.hideKeyboard()
            page.bookHeld(row)
        }

        // New results start at the top
        Connections {
            target: bookOrbit.search
            function onChanged() {
                if (bookOrbit.search.total === -1)
                    results.list.positionViewAtBeginning()
            }
        }
    }
}
