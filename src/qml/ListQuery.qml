import QtQuick

// One view's sort and filter, as chosen in its sub-toolbar menus (library, collections, a
// collection's books). Emits applied() after each change, once the sort and its direction
// have both settled. Its list page goes back to the top then.
QtObject {
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
    property bool ebooks: true
    property bool audiobooks: true
    readonly property bool allContent: ebooks && audiobooks
    // The formats shown, none for all
    readonly property var formats: allContent ? [] : downloads.formatsOf(ebooks ? "ebook" : "audiobook")
    // "books", "ebooks" or "audiobooks", for empty lists
    readonly property string contentNoun: allContent ? "books" : ebooks ? "ebooks" : "audiobooks"

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
    // content type
    readonly property string filterName: {
        const library = libraryOptions.find(option => option.id === libraryId)
        if (library)
            return library.name
        return allContent ? "All titles" : ebooks ? "Ebooks" : "Audiobooks"
    }
    // Whether the view has a filter button
    readonly property bool hasFilter: hasContentType || libraryOptions.length > 0

    property int sortIndex: 0
    property bool sortReversed: false
    // Only books on the device, combined with the content type: as chosen, and always
    // while offline. Back online, the list returns to the choice.
    property bool downloadedChosen: false
    readonly property bool downloadedOnly: downloadedChosen || !bookOrbit.session.online

    readonly property bool sortDescending: descending()

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
    // Shows or hides "ebook" or "audiobook" content, unless that would hide both
    function showContent(kind, on) {
        const otherOn = kind === "ebook" ? audiobooks : ebooks
        if (!on && !otherOn)
            return
        if (kind === "ebook" && ebooks !== on)
            ebooks = on
        else if (kind === "audiobook" && audiobooks !== on)
            audiobooks = on
        else
            return
        applied()
    }
    function chooseLibrary(id) {
        if (id !== libraryId)
            libraryChosen(id)
    }
    function setDownloadedOnly(on) {
        downloadedChosen = on
        applied()
    }
}
