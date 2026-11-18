import QtQuick
import "units.js" as Units
import "format.js" as Format

// An author's details, opened from the Authors list and laid out like BookInfoPage: photo
// (or initials) in the cover's place, with name, born, died, genres and website (opens in
// the browser) beside it, then BOOKS, SERIES and FORMAT (BOOKS and SERIES link to them),
// then BookOrbit's description. Details beyond the list row are fetched on open and simply
// missing offline. The page scrolls when the description is long (see InfoPage).
InfoPage {
    id: page

    // The author's unfiltered Authors list row (bookOrbit.authors.row)
    property var author: ({})
    // GET /authors/:id, once loaded
    property var details: ({})

    signal booksClicked()
    signal seriesClicked()

    function show(authorId) {
        author = bookOrbit.authors.row(authorId)
        details = {}
        scrollToTop()
        bookOrbit.details.loadAuthor(authorId)
    }

    Connections {
        target: bookOrbit.details
        function onAuthorDetails(authorId, newDetails) {
            if (authorId === page.author.id)
                page.details = newDetails
        }
    }
    // Formats and series arrive after the list
    Connections {
        target: bookOrbit.authors
        function onChanged() {
            if (page.visible && page.author.id !== undefined)
                page.author = bookOrbit.authors.row(page.author.id)
        }
    }

    // Number of series their books are in (-1 until looked up), and which ones
    readonly property int seriesCount: author.seriesCount === undefined ? -1 : author.seriesCount
    readonly property var seriesNames: {
        const names = []
        const bookSeries = author.bookSeries || {}
        for (const key in bookSeries) {
            for (const name of bookSeries[key]) {
                if (names.indexOf(name) < 0)
                    names.push(name)
            }
        }
        return names.sort((a, b) => a.localeCompare(b))
    }

    title: "Author info / " + (author.name || "")

    // Photo with the main fields beside it
    Item {
        width: parent.width
        height: Math.max(photoBox.height, fields.height)

        // Cover width but 3:4, which crops most photos less than a cover's 2:3
        AuthorPortrait {
            id: photoBox
            width: Units.dp(197)
            height: Units.dp(263)
            author: page.author
        }

        Column {
            id: fields
            x: photoBox.width + Units.dp(15)
            width: parent.width - x

            Repeater {
                model: [
                    ["Name", page.author.name || ""],
                    ["Born", Format.date(page.details.birthDate, page.details.birthYear)],
                    ["Died", Format.date(page.details.deathDate, page.details.deathYear)],
                    ["Genres", (page.details.genres || []).join(", ")],
                    ["Website", page.details.website || ""],
                ]
                InfoField {
                    required property var modelData
                    width: fields.width
                    label: modelData[0]
                    value: modelData[1]
                    // Opens in the system browser
                    link: modelData[0] === "Website" && browser.available
                    onLinkClicked: browser.open(value)
                }
            }
        }
    }

    Item { width: 1; height: Units.dp(17) }   // space below the photo

    // BOOKS, SERIES and FORMAT across all their books, ignoring the list filter. An
    // ebook and its audiobook count once, as in their book list. BOOKS and SERIES
    // link through, like the book menu's "All books of" items; SERIES only if there
    // are any.
    InfoCells {
        width: parent.width
        cells: [
            ["Books", (page.author.bookCount || "").toString(), true],
            ["Series", page.seriesCount < 0 ? "" : page.seriesCount.toString(), page.seriesCount !== 0],
            ["Format", Format.formats(page.author.formats || [])],
        ]
        onCellClicked: (index) => index === 0 ? page.booksClicked() : page.seriesClicked()
    }
    // A little more space under the cells than between fields, as on the book info
    // page
    Item { width: 1; height: Units.dp(16) }

    InfoField {
        width: parent.width
        label: "Description"
        value: page.details.description || ""
        showLine: false
    }
}
