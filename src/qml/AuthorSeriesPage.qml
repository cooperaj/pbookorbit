import QtQuick

// An author's series, opened from their info page: series rows under a toolbar with a back
// button, e.g. "SERIES / ADRIAN TCHAIKOVSKY". The Series tab's sorts sit above, with the
// menu shown by main.qml. bookOrbit.authorSeries.show() fills it.
GroupListPage {
    // The author's name
    property string name

    title: "Series / " + name
    groups: bookOrbit.authorSeries
    emptyTitle: "No series"
    emptyText: bookOrbit.session.online ? "None of their books are in a series." : offlineText("series with downloaded books")
}
