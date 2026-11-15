import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml/books.js" as Books

// A book's records, versions and files on the device (books.js), and what Open with
// opens. Book 2's epub and book 3's m4b (its audiobook) are downloaded, and only epubs
// have an app.
UiTestCase {
    id: test
    name: "Books"

    readonly property var ebook: ({bookId: 2, fileId: 20, format: "epub", sizeBytes: 100, kind: "ebook"})
    readonly property var audiobook: ({bookId: 3, fileId: 30, format: "m4b", sizeBytes: 900, kind: "audiobook"})

    function init() {
        testApp.reset({}, {
            books: [
                {id: 2, title: "Dune", authors: ["Frank Herbert"], file: "dune.epub"},
                {id: 3, title: "Dune", authors: ["Frank Herbert"], file: "dune.m4b"},
            ],
            apps: {epub: [{app: "koreader.app", name: "KOReader"}]},
        })
    }

    function test_recordIdsEachOnce() {
        compare(Books.recordIds({id: 2, variants: [ebook, audiobook, audiobook]}), [2, 3])
        compare(Books.recordIds({}), [])
    }

    // The variants, or else the file a download would pick, as a version with no kind
    function test_versions() {
        compare(Books.versions({id: 2, variants: [ebook, audiobook]}, downloads).length, 2)

        const book = {id: 5, files: [{id: 50, format: "EPUB", role: "primary", sizeBytes: 100}]}
        const versions = Books.versions(book, downloads)
        compare(versions.length, 1)
        compare(versions[0].bookId, 5)
        compare(versions[0].fileId, 50)
        compare(versions[0].kind, "")

        compare(Books.versions({id: 6, files: []}, downloads), [])
    }

    function test_formatsOnDevice() {
        compare(Books.formatsOnDevice({id: 2, variants: [ebook, audiobook]}, downloads), ["epub", "m4b"])
        compare(Books.formatsOnDevice({id: 7}, downloads), [])
    }

    // The ebook first, whichever record the row is
    function test_kindsOnDevice() {
        compare(Books.kindsOnDevice({id: 3, variants: [audiobook, ebook]}, downloads), ["ebook", "audiobook"])
        compare(Books.kindsOnDevice({id: 3, variants: [audiobook]}, downloads), ["audiobook"])
    }

    // A file on the device in a format with an app
    function test_openWithAFileOnTheDevice() {
        const target = Books.openWithTarget({id: 2, variants: [ebook, audiobook]}, downloads)

        compare(target.bookId, 2)
        compare(target.format, "epub")
        compare(target.apps[0].name, "KOReader")
        compare(target.option, undefined, "nothing to download")
    }

    // Else a version to download first
    function test_openWithDownloadsFirst() {
        const version = {bookId: 8, fileId: 80, format: "epub", sizeBytes: 100, kind: "ebook"}

        const target = Books.openWithTarget({id: 8, variants: [version]}, downloads)

        compare(target.bookId, 8)
        compare(target.option.fileId, 80)
    }

    // With a kind, only that version: the audiobook's m4b has no app
    function test_openWithOneVersion() {
        const book = {id: 2, variants: [ebook, audiobook]}

        compare(Books.openWithTarget(book, downloads, "ebook").format, "epub")
        compare(Books.openWithTarget(book, downloads, "audiobook"), null)
    }

    // A version already on the device isn't offered for download again
    function test_noDownloadOfAVersionOnTheDevice() {
        compare(Books.openWithTarget({id: 3, variants: [audiobook]}, downloads), null)
    }

    function test_nothingWithoutAnApp() {
        const version = {bookId: 9, fileId: 90, format: "pdf", sizeBytes: 100, kind: "ebook"}

        compare(Books.openWithTarget({id: 9, variants: [version]}, downloads), null)
    }
}
