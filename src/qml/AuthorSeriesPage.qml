import QtQuick

// An author's series, opened from their info page: series rows under a toolbar with a back
// button, e.g. "SERIES / ADRIAN TCHAIKOVSKY". The Series tab's sorts sit above, with the
// menu shown by main.qml. bookOrbit.showAuthorSeries() fills it.
Rectangle {
    id: page
    // For the page-turn keys and the menus, which main.qml takes from the front page
    readonly property alias pageButtons: series.pageButtons
    readonly property alias list: series.list
    color: "white"

    // The author's name
    property string name
    // Its sort, for the sub-toolbar
    property ListQuery query: null
    // Where the jump rail's entries go (see RailLayout)
    property RailLayout railLayout: null
    // The menu its sub-toolbar opens
    property ListMenus menus: null

    signal back()
    signal groupClicked(var series)

    PageHeader {
        id: header
        width: parent.width
        title: "Series / " + page.name
        onBack: page.back()
    }

    GroupListPage {
        id: series
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        model: bookOrbit.authorSeriesList
        jumpSections: bookOrbit.authorSeriesJumpSections
        error: bookOrbit.authorSeriesError
        loaded: bookOrbit.authorSeriesLoaded
        noneTitle: "No series"
        noneText: bookOrbit.online ? "None of their books are in a series."
                                   : "You're currently offline, only series with downloaded books can be shown."
        query: page.query
        railLayout: page.railLayout
        menus: page.menus
        onGroupClicked: (group) => page.groupClicked(group)
    }
}
