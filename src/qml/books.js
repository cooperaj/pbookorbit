.pragma library

// A book's records, versions and files, worked out from its list entry and what Downloads
// (passed in) says is on the device. A version is {bookId, fileId, format, sizeBytes, kind,
// book}, as the list entry's variants and DownloadDialog's options are. Bindings that use
// these read downloads.revision too, so they're worked out again as downloads arrive or go.

// The book's own record id and any separately stored version's (e.g. an audiobook's),
// each once
function recordIds(book) {
    const ids = book.id === undefined ? [] : [book.id]
    for (const variant of book.variants || []) {
        if (ids.indexOf(variant.bookId) < 0)
            ids.push(variant.bookId)
    }
    return ids
}

// The versions a download could fetch: the book's variants, or else the file Downloads
// would pick, as a version with no kind. Empty if the book has no file.
function versions(book, downloads) {
    const variants = book.variants || []
    if (variants.length > 0 || book.id === undefined)
        return variants
    const file = downloads.fileToDownload(book)
    return file.format === undefined ? []
         : [{ bookId: book.id, fileId: file.id, format: file.format, sizeBytes: file.sizeBytes,
              kind: "", book: book }]
}

// Formats of the book's files on the device, e.g. ["epub", "m4b"]
function formatsOnDevice(book, downloads) {
    let formats = []
    for (const id of recordIds(book))
        formats = formats.concat(downloads.formatsOnDevice(id))
    return formats
}

// Which versions are on the device, the ebook first: ["ebook", "audiobook"], or fewer
function kindsOnDevice(book, downloads) {
    let kinds = []
    for (const id of recordIds(book))
        kinds = kinds.concat(downloads.kindsOnDevice(id))
    return ["ebook", "audiobook"].filter(kind => kinds.indexOf(kind) >= 0)
}

// What Open with opens: {bookId, format, apps} for a file on the device in a format the
// system has apps for, else the same plus option, a version to download first. Only
// versions not already on the device are offered for download. With a kind, only that
// version counts. null if there's nothing to open.
function openWithTarget(book, downloads, kind) {
    if (book.id === undefined)
        return null
    const offered = versions(book, downloads).filter(version => !kind || version.kind === kind)
    const ids = kind ? offered.map(version => version.bookId) : recordIds(book)
    for (const id of ids) {
        for (const format of downloads.formatsOnDevice(id)) {
            if (kind && downloads.kindOf(format) !== kind)
                continue
            const apps = downloads.appsFor(format)
            if (apps.length > 0)
                return { bookId: id, format: format, apps: apps }
        }
    }
    for (const version of offered) {
        const onDevice = version.kind ? downloads.kindsOnDevice(version.bookId).indexOf(version.kind) >= 0
                                       : downloads.isOnDevice(version.bookId)
        const apps = onDevice ? [] : downloads.appsFor(version.format)
        if (apps.length > 0)
            return { bookId: version.bookId, format: version.format, apps: apps, option: version }
    }
    return null
}
