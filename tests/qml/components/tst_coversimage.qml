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

    // A changed cover is fetched and the old one's files deleted. A list that still has the
    // old version, not yet refreshed, shows the new cover without fetching either again.
    function test_newVersionReplacesOld() {
        const image = make({itemId: 7, version: "v1"})
        tryVerify(() => image.status === Image.Ready, 5000, "the first version shows")
        const oldFiles = testApp.coverFiles("7")
        compare(oldFiles.length, 2, "the download and its size")

        image.version = "v2"
        tryVerify(() => fetches("/api/v1/books/7/thumbnail") === 2, 5000, "the new version is fetched")
        tryVerify(() => image.status === Image.Ready && image.url !== "", 5000, "and shows")
        const newFiles = testApp.coverFiles("7")
        compare(newFiles.length, 2, "only the new version's files are kept")
        verify(!newFiles.some(file => oldFiles.includes(file)), "the old version's files are gone")

        image.version = "v1"
        tryVerify(() => image.status === Image.Ready && image.url !== "", 5000, "the old version shows the new cover")
        verify(image.url.endsWith(newFiles.find(file => file.endsWith(".png"))))
        wait(200)
        compare(fetches("/api/v1/books/7/thumbnail"), 2, "nothing fetched again")
    }

    // The series list gives no cover versions: a book's cover is used as downloaded
    function test_noVersionUsesTheDownload() {
        const versioned = make({itemId: 7, version: "v1"})
        tryVerify(() => versioned.status === Image.Ready, 5000, "the cover shows")

        const unversioned = createTemporaryObject(coversImage, test, {itemId: 7, version: "", width: 20, height: 30})
        tryVerify(() => unversioned.status === Image.Ready, 5000, "the series' cover shows")
        wait(200)
        compare(fetches("/api/v1/books/7/thumbnail"), 1, "not fetched again")
    }

    // A series list and a book list fetching the same cover at once keep the download with a
    // version, so the book list needn't fetch it again at the next start
    function test_versionedDownloadKeptOverUnversioned() {
        fakeServer.hold("GET", "/api/v1/books/7/thumbnail")
        const versioned = make({itemId: 7, version: "v1"})
        const unversioned = createTemporaryObject(coversImage, test, {itemId: 7, version: ""})
        tryVerify(() => fetches("/api/v1/books/7/thumbnail") === 2, 5000, "both fetch it")

        fakeServer.release("GET", "/api/v1/books/7/thumbnail")
        tryVerify(() => versioned.status === Image.Ready && unversioned.status === Image.Ready, 5000, "both show")
        compare(testApp.coverFiles("7").filter(file => file.endsWith("-source")).length, 1, "one download kept")

        testApp.restart()
        const again = createTemporaryObject(coversImage, test, {itemId: 7, version: "v1"})
        tryVerify(() => again.status === Image.Ready, 5000, "the cover shows after a restart")
        compare(fetches("/api/v1/books/7/thumbnail"), 2, "without fetching it again")
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
