import QtQuick
import "../helpers"

// A saved session lasts until the server refuses to refresh it. Access tokens expire after
// about 15 minutes: a request refused with 401 refreshes the session and is tried once more.
// A refresh refused with 401 means the session expired or was revoked, and the user signs
// in again. Other failures keep the session for next time.
AppTestCase {
    name: "Session"

    readonly property string books: "/api/v1/libraries/1/books"
    readonly property string refresh: "/api/v1/auth/refresh"

    // Not counting the lookups for a page's other versions (an ebook's audiobook), which
    // follow a page of books and filter by title
    function requestsTo(path) {
        return fakeServer.requests.filter(r => r.path === path && !(r.body && r.body.filter)).length
    }

    function verifySessionExpired() {
        tryVerify(() => find("loginPage").visible, 5000, "back to sign-in")
        compare(find("errorText").text, "Session expired, please sign in again")
        verify(find("serverPill").visible, "the server is kept")
        compare(find("usernameField").text, "reader", "and the username")
    }

    function test_refusedRefreshAtStartAsksToSignIn() {
        fakeServer.respond("POST", refresh, 401, "auth/login-invalid.json")
        serveLibrary()

        open(savedSession)

        verifySessionExpired()
        compare(requestsTo(books), 0, "the library isn't asked for")
    }

    // So the next start doesn't try it again
    function test_expiredSessionIsForgotten() {
        fakeServer.respond("POST", refresh, 401, "auth/login-invalid.json")
        serveLibrary()

        open(savedSession)

        verifySessionExpired()
        compare(testApp.setting("refreshToken"), "", "no saved session")
        compare(testApp.setting("username"), "reader", "the username is kept")
    }

    // Sorting asks for the books and their sections again
    function sortByAuthor() {
        tap("sortButton", find("bookList"))
        tap("Author", find("sortMenu"))
    }

    // The access token expires while the app is in use: the library is refused, the session
    // refreshed, and the library asked for again
    function test_refusedRequestRefreshesAndRetries() {
        fakeServer.respond("POST", refresh, 200, "auth/refresh-success.json")
        serveLibrary()
        open(savedSession)
        tryCompare(find("bookList"), "count", 3)
        fakeServer.respond("POST", books, 401, "auth/login-invalid.json")
        fakeServer.hold("POST", refresh)

        sortByAuthor()
        tryVerify(() => requestsTo(refresh) === 2, 5000, "the refusal refreshes the session")
        fakeServer.respond("POST", books, 200, "libraries/mixed-by-author.json")
        const asked = requestsTo(books)
        fakeServer.release("POST", refresh)

        tryVerify(() => requestsTo(books) === asked + 1, 5000, "the library is asked for again")
        tryVerify(() => find("bookList").itemAtIndex(0) && find("bookList").itemAtIndex(0).book.title === "Neuromancer",
                  5000, "and shows")
        verify(!find("loginPage").visible, "still signed in")
        compare(fakeServer.requests.filter(r => r.path === refresh).pop().body.refreshToken,
                "0000000000000000000000000000000000000000000000000000000000000001",
                "refreshed with the token the last refresh gave")
    }

    // A request still refused after a new access token isn't tried again and again
    function test_refusedRequestIsRetriedOnce() {
        fakeServer.respond("POST", refresh, 200, "auth/refresh-success.json")
        serveLibrary()
        fakeServer.respond("POST", books, 401, "auth/login-invalid.json")

        open(savedSession)
        tryVerify(() => find("bookList").count === 0 && requestsTo(books) === 2, 5000, "tried twice")
        wait(500)

        compare(requestsTo(books), 2, "and no more")
        compare(requestsTo(refresh), 2, "one refresh at start, one for the refusal")
        verify(!find("loginPage").visible, "still signed in, as the session was refreshed")
    }

    // Requests refused together share one refresh
    function test_refusedRequestsShareARefresh() {
        fakeServer.respond("POST", refresh, 200, "auth/refresh-success.json")
        serveLibrary()
        open(savedSession)
        tryCompare(find("bookList"), "count", 3)
        fakeServer.respond("POST", books, 401, "auth/login-invalid.json")
        fakeServer.respond("POST", books + "/jump-buckets", 401, "auth/login-invalid.json")
        fakeServer.hold("POST", refresh)
        const before = requestsTo(refresh)

        sortByAuthor()
        tryVerify(() => requestsTo(refresh) === before + 1, 5000, "a refresh")
        wait(500)

        compare(requestsTo(refresh), before + 1, "only one")
        fakeServer.release("POST", refresh)
    }

    // The access token expires and the refresh is refused too: the session has expired
    function test_refusedRefreshWhileInUseAsksToSignIn() {
        fakeServer.respond("POST", refresh, 200, "auth/refresh-success.json")
        serveLibrary()
        open(savedSession)
        tryCompare(find("bookList"), "count", 3)
        fakeServer.respond("POST", books, 401, "auth/login-invalid.json")
        fakeServer.respond("POST", refresh, 401, "auth/login-invalid.json")

        sortByAuthor()

        verifySessionExpired()
    }

    // A server error isn't the session expiring: it's kept for next time
    function test_serverErrorOnRefreshKeepsTheSession() {
        fakeServer.respond("POST", refresh, 500, "server-error.json")
        serveLibrary()

        open(savedSession)
        tryVerify(() => requestsTo(refresh) >= 1, 5000)
        wait(1000)

        compare(requestsTo(refresh), 1, "refreshed once, not again for each waiting request")
        verify(!find("loginPage").visible, "not sent to sign-in")
        verify(bookOrbit.signedIn, "the session is kept")
    }
}
