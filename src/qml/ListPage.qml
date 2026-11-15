import QtQuick
import "units.js" as Units

// The frame every list page shares (BookListPage, GroupListPage): rows from a delegate,
// with the sub-toolbar (when there's a query) and any error above them, a scrollbar, a jump
// rail, page buttons, a spinner and an empty state. The owner says when the spinner and
// the empty state show and what the empty state says; main.qml owns the sort and filter
// menus.
Item {
    id: page

    property var model
    // A row, given its model data
    property Component delegate
    // The sort and filter shown in the sub-toolbar. None: no sub-toolbar.
    property ListQuery query: null
    property bool filterOpen: false
    property bool sortOpen: false
    property int tabOverhang: Units.dp(4)
    // An error over rows already shown, under the sub-toolbar
    property bool showErrorLine: true
    // The list's own error (bookOrbit.booksError and the rest)
    property string error

    // The rail's sections, as JumpRail takes them, and where its first entry and spacing
    // line up with (page coordinates), if not its own
    property var jumpSections: []
    property bool alphabetical: true
    property bool descending: query ? query.sortDescending : false
    property int minSections: 1
    property real jumpRailTop: NaN
    property real jumpRailPitch: NaN

    // While there are no rows: whether they're on their way (the spinner), or there are
    // none to show (the empty state, saying these)
    property bool loading: false
    property bool empty: false
    property string emptyTitle
    property string emptyText

    // So the tests can tell the lists apart
    property string listName: "list"
    property string railName: "jumpRail"
    property string emptyName: "emptyState"

    // What the empty state says offline, for emptyText
    readonly property alias offlineText: emptyState.offlineText

    readonly property alias list: rows
    readonly property alias rail: rail
    readonly property alias pageButtons: pageButtons

    signal filterClicked()
    signal sortClicked()
    signal sortIconClicked()
    // The rows to load: the ones on screen and a screenful either side
    signal rowsWanted(int first, int last)
    // Scrolling began, by flicking rather than with the page buttons
    signal scrollStarted()

    ListView {
        id: rows
        objectName: page.listName
        anchors.fill: parent
        clip: true
        // No bounce at the ends; on e-ink that's just extra redraws
        boundsBehavior: Flickable.StopAtBounds
        model: page.model

        // Once scrolling pauses, so a fast flick doesn't fetch every page it passes. The jump
        // rail calls it too.
        function loadVisibleBooks() {
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
            onTriggered: rows.loadVisibleBooks()
        }
        onContentYChanged: loadTimer.restart()
        onCountChanged: loadTimer.restart()

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
                    showFilter: page.query?.hasFilter ?? false
                    filterText: page.query?.filterOptions[page.query.filterIndex] ?? ""
                    sortText: page.query ? "By " + page.query.sortOptions[page.query.sortIndex] : ""
                    sortReversed: page.query?.sortReversed ?? false
                    filterOpen: page.filterOpen
                    sortOpen: page.sortOpen
                    tabOverhang: page.tabOverhang
                    onFilterClicked: page.filterClicked()
                    onSortClicked: page.sortClicked()
                    onSortIconClicked: page.sortIconClicked()
                }
                Text {
                    id: errorLine
                    objectName: "errorLine"
                    x: Units.dp(26)
                    width: parent.width - 2 * x
                    visible: page.showErrorLine && page.error !== "" && rows.count > 0
                    topPadding: Units.dp(8)
                    text: page.error
                    font.pointSize: 8
                    wrapMode: Text.Wrap
                }
            }
        }

        // Fast black-and-white (A2) updates while it scrolls. A2 takes screen coordinates,
        // hence mapToGlobal (as in the SDK's qml_test).
        onMovementStarted: {
            page.scrollStarted()
            const pos = mapToGlobal(0, 0)
            eink.enterA2ForFlick(pos.x, pos.y, width, height)
        }
        // Fires when momentum stops, not when the finger lifts
        onMovementEnded: eink.leaveA2Soon()
        onVisibleChanged: if (!visible) eink.leaveA2()

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
        alignTop: page.jumpRailTop
        alignPitch: page.jumpRailPitch
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
        visible: rows.count === 0 && !spinner.visible && page.empty
        title: page.emptyTitle
        text: page.emptyText
    }
}
