import QtQuick

// A list of collections, series or authors (the Collections, Series and Authors tabs, and
// an author's series): one GroupRow per group, all loaded at once, in the ListPage frame.
// The spinner shows until the groups are loaded, unless offline, where they come from the
// downloads; then the empty state if there are none.
ListPage {
    id: page

    property bool loaded: false
    // The client's, unless set
    property bool online: bookOrbit.session.online

    signal groupClicked(var group)

    loading: !loaded && online
    empty: loaded
    // The rows in view have their books looked up, not while hidden
    onRowsWanted: (first, last) => { if (visible) bookOrbit.lookUpRows(model, first, last) }

    delegate: GroupRow {
        required property var book
        group: book
        onClicked: page.groupClicked(book)
    }
}
