import QtQuick

// One view's sort and library, as chosen in its sub-toolbar menus, and the content type and
// Downloaded only, which are every view's (bookOrbit.filter) but search's. Emits applied()
// after a change of sort, once the sort and its direction have both settled; main.qml
// emits it for filter changes. Its list page goes back to the top then.
QtObject {
    // Where the content type and Downloaded only are kept: a ListFilter
    property QtObject filter: bookOrbit.filter

    // The sorts, as [{name, field, descending}]: the menu's name, the BookOrbit sort field,
    // and the default direction
    property var sorts: []
    readonly property var sortOptions: sorts.map(sort => sort.name)
    // The chosen sort's name and field
    readonly property string sortName: sorts.length > 0 ? sorts[sortIndex].name : ""
    readonly property string sortField: sorts.length > 0 ? sorts[sortIndex].field : ""

    // Whether the view filters by content type and downloaded only
    property bool hasContentType: true
    // Ebooks and audiobooks shown: one or both, never neither
    readonly property bool ebooks: filter.ebooks
    readonly property bool audiobooks: filter.audiobooks
    readonly property bool allContent: ebooks && audiobooks
    // The formats shown, none for all
    readonly property var formats: allContent ? [] : downloads.formatsOf(ebooks ? "ebook" : "audiobook")
    // "books", "ebooks" or "audiobooks", for empty lists
    readonly property string contentNoun: allContent ? "books" : ebooks ? "ebooks" : "audiobooks"
    // The same, after "downloaded" when downloaded only
    readonly property string listedNoun: (downloadedOnly ? "downloaded " : "") + contentNoun

    // Whether the view can be set to a library, and to all of them. libraryChosen() says
    // when one is chosen; the view sets libraryId.
    property bool hasLibraries: false
    property bool allLibraries: false
    // The library shown, or -1 for all
    property int libraryId: -1
    // The libraries to choose from, [{id, name}], shown while the server has several and
    // can be reached
    readonly property var libraryOptions: {
        const libraries = bookOrbit.session.libraries
        if (!hasLibraries || libraries.length < 2 || !bookOrbit.session.online)
            return []
        return (allLibraries ? [{ id: -1, name: "All libraries" }] : []).concat(libraries)
    }

    // The filter button's label: the library when there's a choice of them, else the
    // content type. Library while the libraries are fetched.
    readonly property string filterName: {
        const library = libraryOptions.find(option => option.id === libraryId)
        if (library)
            return library.name
        if (hasLibraries && bookOrbit.session.online && bookOrbit.session.libraries.length === 0)
            return "Library"
        return allContent ? "All titles" : ebooks ? "Ebooks" : "Audiobooks"
    }
    // Whether the view has a filter button
    readonly property bool hasFilter: hasContentType || libraryOptions.length > 0

    property int sortIndex: 0
    property bool sortReversed: false
    // The sort it started with, for reset()
    property int firstSortIndex: 0
    Component.onCompleted: firstSortIndex = sortIndex
    // Only books on the device, combined with the content type: as chosen, and always
    // while offline. Back online, the lists return to the choice.
    readonly property bool downloadedChosen: filter.downloadedOnly
    readonly property bool downloadedOnly: downloadedChosen || !bookOrbit.session.online

    readonly property bool sortDescending: descending()

    // Its filter's revision (see main.qml) when last applied, so a view applies a change
    // made elsewhere once it's shown
    property int filterRevision: -1

    signal applied()
    signal libraryChosen(int libraryId)

    // Computed here rather than read from sortDescending, which may lag when the sort and
    // sortReversed change together
    function descending() {
        return sorts.length > 0 && sorts[sortIndex].descending !== sortReversed
    }
    // A different sort starts in its default direction
    function chooseSort(index) {
        if (index === sortIndex)
            return
        sortReversed = false
        sortIndex = index
        applied()
    }
    function reverseSort() {
        sortReversed = !sortReversed
        applied()
    }
    // Back to the sort it started with, in its default direction, without applying it
    function resetSort() {
        sortIndex = firstSortIndex
        sortReversed = false
    }
    // A library, or all of them for -1
    function chooseLibrary(id) {
        if (id !== libraryId)
            libraryChosen(id)
    }
    // Shows or hides "ebook" or "audiobook" content, unless that would hide both
    function showContent(kind, on) {
        filter.showContent(kind, on)
    }
    function setDownloadedOnly(on) {
        filter.setDownloadedOnly(on)
    }
}
