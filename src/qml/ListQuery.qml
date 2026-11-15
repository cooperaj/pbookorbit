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
    // Whether the view has the filter button (content type and downloaded only)
    property bool hasFilter: true
    // The content types, as filterIndex counts them, and their file formats (BookOrbit's
    // EBOOK_FORMAT_LIST and AUDIO_FORMAT_LIST; none for all)
    readonly property var filterOptions: ["All titles", "Ebooks", "Audiobooks"]
    readonly property var filterFormats: [
        [],
        ["epub", "kepub", "mobi", "azw3", "azw", "fb2", "pdf", "djvu"],
        ["m4b", "mp3", "m4a", "opus", "ogg", "flac"]
    ]
    // The chosen content type's name and formats
    readonly property string filterName: filterOptions[filterIndex]
    readonly property var formats: filterFormats[filterIndex]

    property int sortIndex: 0
    property bool sortReversed: false
    property int filterIndex: 0
    // Only books on the device, combined with the content type: as chosen, and always
    // while offline. Back online, the list returns to the choice.
    property bool downloadedChosen: false
    readonly property bool downloadedOnly: downloadedChosen || !bookOrbit.online

    readonly property bool sortDescending: descending()

    signal applied()

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
    function chooseFilter(index) {
        if (index === filterIndex)
            return
        filterIndex = index
        applied()
    }
    function setDownloadedOnly(on) {
        downloadedChosen = on
        applied()
    }
}
