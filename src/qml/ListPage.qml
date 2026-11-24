import QtQuick
import "units.js" as Units

// The frame every list page shares (BookListPage, GroupListPage): rows from a delegate,
// with the sub-toolbar (when there's a query) and any error above them, a scrollbar, a jump
// rail, page buttons, a spinner and an empty state. A page opened over the views has a
// title, in a toolbar with a back button above it all. The owner says when the spinner and
// the empty state show and what the empty state says, though an error with no rows always
// shows as "Something went wrong". main.qml owns the sort and filter menus, and the sort
// icon reverses the query here. The list goes back to the top when the query changes.
Rectangle {
    id: page
    color: "white"

    // For a page opened over the views, e.g. "Series / A Song of Ice and Fire". None: no
    // toolbar.
    property string title

    property var model
    // A row, given its model data
    property Component delegate
    // The sort and filter shown in the sub-toolbar. None: no sub-toolbar.
    property ListQuery query: null
    // The menus its buttons open
    property ListMenus menus: null
    // An error over rows already shown, under the sub-toolbar
    property bool showErrorLine: true
    // The list's own error (bookOrbit.library.error and the rest)
    property string error

    // The rail's sections, as JumpRail takes them, and where its entries go (see
    // RailLayout), if not centred on its own
    property var jumpSections: []
    property bool alphabetical: true
    // The rows' direction: the old one while the sort icon is held (see sortIconHeld)
    readonly property bool descending: sortIconHeld ? heldDescending : query ? query.sortDescending : false
    property int minSections: 1
    property RailLayout railLayout: null

    // While there are no rows: whether they're on their way (the spinner), or there are
    // none to show (the empty state, saying these)
    property bool loading: false
    property bool empty: false
    property string emptyTitle
    property string emptyText

    // For emptyText offline: "You're currently offline, only downloaded books can be shown."
    function offlineText(what = "downloaded books", verb = "shown") {
        return "You're currently offline, only " + what + " can be " + verb + "."
    }

    // So the tests can tell the lists apart
    property string listName: "list"
    property string railName: "jumpRail"
    property string emptyName: "emptyState"

    readonly property alias list: rows
    readonly property alias rail: rail
    readonly property alias pageButtons: pageButtons

    // The rows to load: the ones on screen and a screenful either side
    signal rowsWanted(int first, int last)
    // Scrolling began, by flicking rather than with the page buttons
    signal scrollStarted()
    // The toolbar's back button was tapped
    signal back()

    Connections {
        target: page.query
        function onApplied() { rows.positionViewAtBeginning() }
        function onLibraryChosen() { rows.positionViewAtBeginning() }
    }

    // After the sort icon is tapped, until the rows change: the icon keeps its pressed look
    // and old direction, and the rail its old order, so they change in the same screen
    // update as the rows. Otherwise they get an update of their own, which the rows' update
    // then waits behind. Lists that change at once (downloaded books only) release it in
    // the same frame.
    property bool sortIconHeld: false
    property bool heldDescending: false
    Connections {
        // A model object; a plain count of rows never changes
        target: page.sortIconHeld && typeof page.model === "object" ? page.model : null
        ignoreUnknownSignals: true
        function onModelReset() { page.sortIconHeld = false }
        function onRowsInserted() { page.sortIconHeld = false }
        function onRowsRemoved() { page.sortIconHeld = false }
        function onDataChanged() { page.sortIconHeld = false }
    }
    onErrorChanged: sortIconHeld = false
    // For a list that comes back unchanged, or not at all
    Timer {
        running: page.sortIconHeld
        interval: 3000
        onTriggered: page.sortIconHeld = false
    }

    PageHeader {
        id: header
        visible: page.title !== ""
        width: parent.width
        title: page.title
        onBack: page.back()
    }

    ListView {
        id: rows
        objectName: page.listName
        anchors.top: header.visible ? header.bottom : parent.top
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true
        // No bounce at the ends; on e-ink that's just extra redraws
        boundsBehavior: Flickable.StopAtBounds
        model: page.model

        // Once scrolling pauses, so a fast flick doesn't fetch every page it passes. The jump
        // rail calls it too.
        function loadVisibleRows() {
            if (count === 0)
                return
            let first = indexAt(width / 2, contentY)
            let last = indexAt(width / 2, contentY + height - 1)
            if (first < 0)
                first = 0   // the sub-toolbar is at the top
            if (last < 0)
                last = count - 1
            const screenful = last - first + 1
            page.rowsWanted(first - screenful, last + screenful)
        }
        Timer {
            id: loadTimer
            interval: 150
            onTriggered: rows.loadVisibleRows()
        }
        onContentYChanged: loadTimer.restart()
        // Rows in an empty list start at the top, under the sub-toolbar. Left to itself, the
        // view puts the first row at the top if the rows come before it and its sub-toolbar
        // have a size, hiding the sub-toolbar until something scrolls it back (the cached rows
        // at startup, which come while the page is built).
        property bool wasEmpty: true
        property bool toTop: false
        property int toTopTries: 0
        function moveToTop() {
            if (!toTop || height <= 0 || (headerItem && headerItem.height <= 0))
                return
            positionViewAtBeginning()
            // Ignored in the middle of the view's layout, when the sub-toolbar gets its height
            if (contentY !== originY && ++toTopTries < 3)
                Qt.callLater(moveToTop)
            else
                toTop = false
        }
        onCountChanged: {
            if (wasEmpty && count > 0) {
                toTop = true
                toTopTries = 0
            }
            wasEmpty = count === 0
            moveToTop()
            loadTimer.restart()
        }
        onHeightChanged: moveToTop()
        onOriginYChanged: moveToTop()

        // The sub-toolbar and any error scroll away with the rows. The first row sits right
        // under the bar, as in the system library.
        header: page.query ? toolbar : null
        Component {
            id: toolbar
            Column {
                width: ListView.view ? ListView.view.width : 0
                bottomPadding: errorLine.visible ? Units.dp(8) : 0

                // The query goes before the bar as the page closes
                SubToolbar {
                    width: parent.width
                    query: page.query
                    filterOpen: page.menus?.filterOpen ?? false
                    sortOpen: page.menus?.sortOpen ?? false
                    onFilterClicked: page.menus?.filterClicked()
                    onSortClicked: page.menus?.sortClicked()
                    holdSortIcon: page.sortIconHeld
                    onSortIconClicked: {
                        // Before reversing; tapped again while held, it keeps the rows' direction
                        if (!page.sortIconHeld)
                            page.heldDescending = page.descending
                        page.sortIconHeld = true
                        page.query.reverseSort()
                    }
                }
                Text {
                    id: errorLine
                    objectName: "errorLine"
                    x: Units.dp(26)
                    width: parent.width - 2 * x
                    visible: page.showErrorLine && page.error !== "" && rows.count > 0
                    topPadding: Units.dp(8)
                    text: page.error
                    font.pointSize: Units.body
                    wrapMode: Text.Wrap
                }
            }
        }

        onMovementStarted: {
            toTop = false
            page.scrollStarted()
        }
        A2Scrolling { target: rows }

        delegate: page.delegate
    }

    ListScrollbar {
        list: rows
        bottomInset: pageButtons.height
    }
    // Starts below the sub-toolbar, and stays put when it scrolls away
    JumpRail {
        id: rail
        objectName: page.railName
        list: rows
        sections: page.jumpSections
        alphabetical: page.alphabetical
        descending: page.descending
        minSections: page.minSections
        topInset: rows.headerItem ? rows.headerItem.height : 0
        bottomInset: pageButtons.height
        layout: page.railLayout
    }
    PageButtons {
        id: pageButtons
        list: rows
        anchors.bottom: rows.bottom
    }

    Spinner {
        id: spinner
        objectName: "spinner"
        list: rows
        visible: rows.count === 0 && page.loading && page.error === ""
    }
    EmptyState {
        id: emptyState
        objectName: page.emptyName
        anchors.fill: rows
        anchors.topMargin: rows.headerItem ? rows.headerItem.height : 0
        visible: rows.count === 0 && !spinner.visible && (page.empty || page.error !== "")
        title: page.error !== "" ? "Something went wrong" : page.emptyTitle
        text: page.error !== "" ? page.error : page.emptyText
    }
}
