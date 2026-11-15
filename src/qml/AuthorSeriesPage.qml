import QtQuick

// An author's series, opened from their info page: series rows under a toolbar with a back
// button, e.g. "SERIES / ADRIAN TCHAIKOVSKY". The Series tab's sorts sit above, with the
// menu shown by main.qml. bookOrbit.showAuthorSeries() fills it.
GroupListPage {
    // The author's name
    property string name

    title: "Series / " + name
    model: bookOrbit.authorSeriesList
    jumpSections: bookOrbit.authorSeriesJumpSections
    error: bookOrbit.authorSeriesError
    loaded: bookOrbit.authorSeriesLoaded
    noneTitle: "No series"
    noneText: bookOrbit.online ? "None of their books are in a series."
                               : "You're currently offline, only series with downloaded books can be shown."
}
