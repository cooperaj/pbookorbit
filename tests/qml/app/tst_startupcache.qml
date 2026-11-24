import QtQuick
import "../helpers"

// The library's first rows are saved once loaded, and shown when the app starts again
// while it connects and the server answers. Only for the same sort and filter: the sort
// isn't kept between starts, so only the default A-Z list is shown from the cache.
// Signing out clears it.
AppTestCase {
    name: "StartupCache"

    readonly property string books: "/api/v1/libraries/1/books"
    readonly property string refresh: "/api/v1/auth/refresh"

    // Requests for the library's pages. Not the lookups for each page's other versions (an
    // ebook's audiobook), which filter by title.
    function libraryRequests() {
        return fakeServer.requests.filter(r => r.path === books && !r.body.filter).length
    }

    // Opens the library and waits for its rows to be saved, two seconds after they load
    function openAndCache(books, jumpBuckets) {
        openLibrary(books, jumpBuckets)
        tryVerify(() => find("bookList").count > 0, 5000, "the library loads")
        wait(2500)
    }

    function test_startShowsTheLastRowsUntilTheServerAnswers() {
        openAndCache("libraries/books.json")
        fakeServer.hold("POST", refresh)

        reopen()

        tryVerify(() => titlesIn(find("bookList")) === "Dune, Hyperion, Neuromancer", 5000, "the saved rows")
        compare(libraryRequests(), 1, "before the server is asked, past the first start's")

        serveLibrary("libraries/mixed.json")
        fakeServer.release("POST", refresh)
        tryVerify(() => titlesIn(find("bookList")) === "Dune, Neuromancer, The Martian", 5000, "the server's rows replace them")
    }

    // The saved rows keep the list's length and its A-Z sections, so the rail works and the
    // list doesn't jump when the rest arrive. They start under the sub-toolbar.
    function test_startKeepsTheLengthAndSections() {
        openAndCache("libraries/books-100-page0.json", "libraries/jump-buckets-100.json")
        fakeServer.hold("POST", refresh)

        reopen()

        const list = find("bookList")
        tryCompare(list, "count", 100)
        tryVerify(() => list.originY < 0, 5000, "the sub-toolbar is above the first row")
        tryCompare(list, "contentY", list.originY, 1000, "and showing")
        const rail = find("libraryRail")
        tryVerify(() => rail.visible, 5000, "the rail shows")
        compare(rail.sections.length, 25, "A to Y")
        bookRow("A Book 1")
        fakeServer.release("POST", refresh)
    }

    // Rows saved in another order aren't shown for the A-Z list the app starts with
    function test_otherSortIsntShownAtStart() {
        fakeServer.respond("POST", books, 200, "libraries/mixed-by-author.json", {sort: [{field: "author"}]})
        openLibrary("libraries/mixed.json", "libraries/mixed-jump-buckets.json")
        tryVerify(() => titlesIn(find("bookList")) === "Dune, Neuromancer, The Martian", 5000)
        tap("sortButton", find("bookList"))
        tap("Author", find("sortMenu"))
        tryVerify(() => titlesIn(find("bookList")) === "Neuromancer, Dune, The Martian", 5000, "by author")
        wait(2500)
        fakeServer.hold("POST", refresh)

        reopen()
        wait(500)

        compare(find("bookList").count, 0, "nothing until the server answers")
        fakeServer.release("POST", refresh)
    }

    // The next user mustn't see the last one's library
    function test_signingOutClearsTheSavedRows() {
        openAndCache("libraries/books.json")
        tap("menuButton")
        tap("signOut")
        verify(find("loginPage").visible)
        fakeServer.respond("POST", "/api/v1/auth/login", 200, "auth/login-success.json")
        fakeServer.hold("POST", books)

        reopen()
        signIn(fakeServer.url, "reader", "right")
        tryVerify(() => !find("loginPage").visible, 5000, "signed in")
        tryVerify(() => libraryRequests() === 2, 5000, "the library is asked for")

        compare(find("bookList").count, 0, "no saved rows")
        fakeServer.release("POST", books)
    }
}
