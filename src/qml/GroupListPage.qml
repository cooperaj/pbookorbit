import QtQuick

// A list of collections, series or authors (the Collections, Series and Authors tabs, and
// an author's series): one GroupRow per group, all loaded at once, in the ListPage frame.
// The spinner shows until the groups are loaded, unless offline, where they come from the
// downloads; then the empty state if there are none. Filtered by format, groups show once
// every group's books have been looked up; downloaded only uses the downloaded books.
ListPage {
    id: page

    model: groups ? groups.model : null
    jumpSections: groups ? groups.jumpSections : []
    error: groups ? groups.error : ""

    // The list shown: bookOrbit.collections, series, authors or authorSeries. None, for a
    // page whose rows are set some other way.
    property var groups: null
    property bool loaded: groups ? groups.loaded && (groups.allLookedUp || !filteredByFormat) : false
    // Filtered to the downloaded books, or else to a content type, which needs every group's
    // books looked up
    readonly property bool filteredToDownloads: !!query && query.hasContentType && query.downloadedOnly
    readonly property bool filteredByFormat: !!query && query.hasContentType && !query.allContent
                                             && !filteredToDownloads
    // What a group is, "author" or "series", and its plural, for the empty state
    property string noun
    property string pluralNoun: noun
    // The empty state's text when nothing is filtered out, and offline
    property string unfilteredText
    property string offlineGroups

    emptyTitle: filteredByFormat ? "No " + pluralNoun + " with " + query.contentNoun : "No " + pluralNoun
    emptyText: !online ? offlineText(offlineGroups)
               : filteredToDownloads ? "Turn off Downloaded only to see every " + noun + "."
               : filteredByFormat ? "Tick Ebooks and Audiobooks to see every " + noun + "."
               : unfilteredText
    // The client's, unless set
    property bool online: bookOrbit.session.online

    signal groupClicked(var group)

    loading: !loaded && online
    empty: loaded
    // The rows in view have their books looked up, not while hidden
    onRowsWanted: (first, last) => { if (visible && groups) groups.lookUpRows(first, last) }

    delegate: GroupRow {
        required property var book
        group: book
        onClicked: page.groupClicked(book)
    }
}
