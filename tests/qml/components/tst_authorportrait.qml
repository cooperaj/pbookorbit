import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// An author's photo (tests/fixtures/covers/tall.png) or their initials, as the Authors list
// and an author's info page show them.
UiTestCase {
    id: test
    name: "AuthorPortrait"

    readonly property var savedSession: ({serverUrl: fakeServer.url, username: "reader",
                                          refreshToken: "saved-token"})
    readonly property var ann: ({id: 7, name: "Ann Leckie", photo: "/api/v1/authors/7/thumbnail?t=1"})
    readonly property var ted: ({id: 8, name: "Ted Chiang", photo: "/api/v1/authors/8/thumbnail?t=2"})

    Component {
        id: portrait
        AuthorPortrait {
            width: 30
            height: 40
        }
    }

    function init() {
        fakeServer.reset()
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        fakeServer.respond("GET", "/api/v1/authors/7/thumbnail", 200, "covers/tall.png")
        fakeServer.respond("GET", "/api/v1/authors/8/thumbnail", 200, "covers/tall.png")
        testApp.reset(savedSession, {})
    }

    function fetches(path) {
        return fakeServer.requests.filter(r => r.path === path).length
    }

    function photo(item) {
        return findChild(item, "photo")
    }

    // The info page shows one author, then another: the second's photo is theirs, and the
    // first's isn't fetched again and kept as theirs
    function test_anotherAuthorGetsTheirOwnPhoto() {
        const item = createTemporaryObject(portrait, test, {author: ann})
        tryVerify(() => photo(item).status === Image.Ready, 5000, "the first author's photo shows")

        item.author = ted

        tryVerify(() => fetches("/api/v1/authors/8/thumbnail") === 1, 5000, "the second's photo is fetched")
        tryVerify(() => photo(item).status === Image.Ready && photo(item).url.indexOf("author-8-") >= 0, 5000,
                  "and shown")
        wait(200)
        compare(fetches("/api/v1/authors/7/thumbnail"), 1, "the first's isn't fetched for the second")
        // "author-<id>-<version hash>-..."
        const annVersion = testApp.coverFiles("author-7")[0].split("-")[2]
        verify(!testApp.coverFiles("author-8").some(file => file.split("-")[2] === annVersion),
               "nothing is kept as the second's under the first's version")
    }

    function test_noPhotoShowsTheirInitials() {
        const item = createTemporaryObject(portrait, test, {author: {id: 9, name: "Ann Leckie", photo: ""}})

        compare(photo(item).url, "")
        wait(200)
        compare(fakeServer.requests.filter(r => r.path.indexOf("thumbnail") >= 0).length, 0, "nothing fetched")
    }
}
