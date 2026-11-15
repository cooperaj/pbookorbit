import QtQuick
import QtTest
import "../helpers"
import "../../../src/qml"

// A book's cover, fetched from the server (tests/fixtures/covers/tall.png, 30x90) for a
// signed-in user, in a 60x60 box: the blank book until it's there, then the cover fitted
// in the middle or a corner, with any white edge around it.
UiTestCase {
    id: test
    name: "Cover"

    readonly property var savedSession: ({serverUrl: fakeServer.url, username: "reader",
                                          refreshToken: "saved-token"})

    Component {
        id: coverBox
        Cover {
            width: 60
            height: 60
        }
    }

    function init() {
        fakeServer.reset()
        fakeServer.respond("POST", "/api/v1/auth/refresh", 200, "auth/refresh-success.json")
        fakeServer.respond("GET", "/api/v1/books/1/thumbnail", 200, "covers/tall.png")
        testApp.reset(savedSession, {})
    }

    function make(properties) {
        root = createTemporaryObject(coverBox, test, properties)
        verify(root)
        return root
    }

    // A book with a cover, once it has arrived
    function loaded(properties) {
        const cover = make(Object.assign({book: {id: 1, coverVersion: "v1", hasCover: true}}, properties))
        tryVerify(() => cover.ready, 5000, "the cover arrives")
        return cover
    }

    function test_blankBookWithoutACover() {
        const cover = make({book: {id: 1, hasCover: false}})

        compare(cover.url, "")
        verify(find("placeholder").visible)
        wait(200)
        compare(fakeServer.requests.length, 0, "nothing fetched")
    }

    function test_coverReplacesTheBlankBook() {
        const cover = loaded()

        verify(!find("placeholder").visible)
        const image = find("image")
        compare(image.width, 20, "fitted to the box")
        compare(image.height, 60)
    }

    function test_fittedInTheMiddleOrACorner() {
        compare(find("image", loaded()).x, 20, "in the middle")
        compare(find("image", loaded({corner: "topRight"})).x, 40)
        compare(find("image", loaded({corner: "bottomLeft"})).x, 0)
    }

    function test_edgeAroundTheCover() {
        const cover = make({book: {id: 1, hasCover: false}, edge: 2})
        const edge = find("edge")
        compare(edge.width, 64, "around the blank book")

        const shown = loaded({edge: 2, corner: "bottomLeft"})
        const around = find("edge", shown)
        compare(around.x, -2)
        compare(around.width, 24, "around the cover")
        compare(around.height, 64)
    }
}
