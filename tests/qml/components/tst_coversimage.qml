import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// A cover or an author photo from covers, shared by Cover and AuthorPortrait: fetched for
// a signed-in user (tests/fixtures/covers/tall.png, 30x90) and shown once its download
// arrives, nothing without an id, and asked for again when back online.
UiTestCase {
    id: test
    name: "CoversImage"

    readonly property var savedSession: ({serverUrl: fakeServer.url, username: "reader",
                                          refreshToken: "saved-token"})

    Component {
        id: coversImage
        CoversImage {
            width: 40
            height: 60
        }
    }

    function init() {
        fakeServer.reset()
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        fakeServer.respond("GET", "/api/v1/books/7/thumbnail", 200, "covers/tall.png")
        fakeServer.respond("GET", "/api/v1/authors/7/thumbnail", 200, "covers/tall.png")
    }

    function make(properties, options) {
        testApp.reset(savedSession, options || {})
        root = createTemporaryObject(coversImage, test, properties)
        verify(root)
        return root
    }

    function fetches(path) {
        return fakeServer.requests.filter(r => r.path === path).length
    }

    function test_nothingWithoutAnId() {
        const image = make({version: "v1"})

        compare(image.url, "")
        wait(200)
        compare(fakeServer.requests.length, 0, "nothing fetched")
    }

    // Empty while it downloads, then shown once covers says it's ready
    function test_coverArrives() {
        const image = make({itemId: 7, version: "v1"})
        compare(image.url, "", "downloading")

        tryVerify(() => image.status === Image.Ready, 5000, "the cover shows")
        compare(fetches("/api/v1/books/7/thumbnail"), 1)
    }

    function test_photoArrives() {
        const image = make({itemId: 7, photo: true, version: "/api/v1/authors/7/thumbnail?t=1"})

        tryVerify(() => image.status === Image.Ready, 5000, "the photo shows")
        compare(fetches("/api/v1/authors/7/thumbnail"), 1)
        compare(fetches("/api/v1/books/7/thumbnail"), 0, "not the book's cover")
    }

    // A book and an author can share an id
    function test_onlyItsOwnDownloadCounts() {
        const image = make({itemId: 7, photo: true, version: "/api/v1/authors/7/thumbnail?t=1"})
        const revision = image.revision

        covers.ready(7, false)

        compare(image.revision, revision, "a cover with its id isn't its photo")
        covers.ready(7, true)
        compare(image.revision, revision + 1)
    }

    // Offline there's nothing to fetch; back online it's asked for again
    function test_askedForAgainOnline() {
        const image = make({itemId: 7, version: "v1"}, {offline: true})
        wait(200)
        compare(image.url, "")
        compare(fetches("/api/v1/books/7/thumbnail"), 0, "nothing fetched offline")

        testApp.offline = false
        bookOrbit.goOnline()

        tryVerify(() => image.status === Image.Ready, 5000, "the cover shows once online")
    }
}
