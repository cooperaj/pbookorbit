# View consolidation

The library, a books-of list (an author's, a series' or a collection's books), the search
results and the four group lists (Collections, Series, Authors, an author's series) are
the same list page built four times. Only the row and how rows load really differ.

## Today

| Part | Library (main.qml) | BooksOfPage | GroupsPage | Search results |
|---|---|---|---|---|
| ListView, sub-toolbar header, error line | inline | copy, no error line | copy | copy, no toolbar |
| A2 flick handling | inline | copy | copy | copy |
| Scrollbar, jump rail, page buttons | inline | copy | copy | copy, no rail |
| Spinner, empty state | inline | copy, own rules | copy, own rules | own rules |
| Loading rows | paged: `loadVisibleBooks` + timer | same code, copied | all at once | same code, copied |
| Row | BookRow, tap/hold wired in main | BookRow, re-emitted | GroupRow | BookRow, re-emitted |
| Sort labels | six properties built from `libraryQuery` | the same six, from main | the same six, per instance | none |

main.qml also picks the front page with ten `showingX ? … :` chains (`frontPageButtons`,
`activeList`, `activeQuery` and the rest).

In C++ the split already exists: `PagedBooks` (library, books-of, search) and `Groups` (the
four group lists). Each list is exposed through its own properties (`books`, `totalBooks`,
`jumpSections`; `booksOf`, `booksOfTotal`, `booksOfJumpSections`; ...), so each page is
wired separately.

## Target

1. **ListPage**: the shared frame. ListView with the sub-toolbar and error line in its
   header, A2 handling, scrollbar, jump rail, page buttons, spinner and empty state. Takes
   a `query` (ListQuery) and builds its own labels from it, a `delegate`, and `loading`,
   `loaded`, `emptyTitle` and `emptyText`. Exposes `list` and `pageButtons`. Its rail
   aligns to a shared metric rather than to the library's rail.
2. **BookListPage**: ListPage with BookRow and paged loading through one `loadRange(first,
   last)`. Tap and hold handled once. Used by the library, BooksOfPage (a PageHeader over
   a BookListPage) and the search results.
3. **GroupListPage**: ListPage with GroupRow and `groupClicked`. Used by Collections,
   Series, Authors and an author's series.
4. **One front page in main.qml**: every page exposes `list`, `pageButtons` and `query`,
   so the chains become `frontPage`. The shared sort and filter menus and the fade stay in
   main.qml.
5. **Optional, C++**: one list object per list (`model`, `total`, `jumpSections`, `loaded`,
   `loadRange()`), so a page takes a single `source`. Only if step 2 still leaves awkward
   wiring.

## Open questions

BookListPage and GroupListPage take their spinner and empty-state rules as inputs, so each
view decides them. Side by side, as of step 3:

| Rule | Library | Books-of | Search | Group lists |
|---|---|---|---|---|
| Spinner while | the client is busy | the total is unknown | never (in the search box) | not loaded, online |
| Empty state when no rows | only with an error or downloaded only | always, once loaded | always, once searched | once loaded, or an error |
| Online, no books, no error | blank | "No books found" | "No books found" | "No …" text |
| Error line over rows | yes | no | no sub-toolbar | yes |
| Error, no rows | "Something went wrong" | "Something went wrong" | untested | "Something went wrong" |

Decided:

- **Online, no books**: drift. The library now says "No books" ("No ebooks", "No
  audiobooks" with a filter), once the server has answered.
- **Error line over rows**: drift. Books-of now shows it, as the library does.
- **Search, error with no rows**: to check later (TODO.md).
- **Spinner**: deliberate. Search's is in the search box, and the library and books-of
  read "still loading" from different client signals that mean the same.

One rule changed in step 3: a books-of page's rail now starts below the sub-toolbar, as
the library's does, rather than over it. It lines up with the library's rail as before
(the emulator's screens are pixel-identical).

## Testing

Shared behaviour is tested once:

- **A shared QML component** gets a component test (`tests/qml/components/`), with its
  inputs set directly rather than through the client.
- **Shared client code** (sorting, sections, errors every list gets) is tested once,
  through one view's feature file.
- **A feature file** keeps what's built or wired for that view alone: which loader runs,
  its sort options, its empty and offline texts, what a tap opens, its reload rule, its
  offline builder, its reconnect rule, and its call to restore cached rows.

Feature files find things by objectNames and `list`, never by component type, so they
survive the refactor.

## Order

1. Done: GroupsPage (now GroupListPage) takes `error` and `online` (defaulting to the
   client's) and has a component test. The Collections, Series and Authors files keep only their own
   behaviour, with the shared client behaviour in Series.
2. Done: an author's series, its own behaviour only (straight to the books for a single
   series, exact author matching, reloading per author, the sort kept between authors).
3. Done: BookListPage for the library, books-of and search, with a component test. Their
   feature files drop what it covers, and books-of has its own feature file.
4. Done: ListPage is the frame under BookListPage and GroupListPage (GroupsPage renamed),
   both taking a ListQuery. main.qml has one `frontPage`; `frontPageButtons`, `activeList`
   and `activeQuery` come from it. Component tests: ListPage for the frame, BookListPage
   and GroupListPage only for what each adds.

Target step 5 (one list object per list in C++) is left until the QML wiring shows a
need for it. Step 5 below may be that need.

## Left after step 4

A review of every QML file after step 4 (15 November) found one bug and duplication the
list pages didn't reach:

- **Shared error (bug)**: `bookOrbit.error` is one value for every list, cleared only at
  sign-in and sign-out. Every ListPage reads it, so after one failed request the library
  shows the error over its rows, an empty Collections tab says "Something went wrong"
  instead of "No collections", and a loading list shows the error instead of the spinner.
- **Wiring in main.qml**: each of the six list pages repeats `filterOpen`, `sortOpen`,
  `tabOverhang`, `onFilterClicked`/`onSortClicked: toggleDropdown(...)`,
  `onSortIconClicked: query.reverseSort()` and the rail alignment. So tst_series and
  tst_library_subtoolbar each test the sort icon.
- **Rail alignment**: still taken from the library's rail
  (`libraryPage.y + libraryPage.rail.entriesY`, five times), not the shared metric Target
  step 1 asked for.
- **Pages with a header**: BooksOfPage and AuthorSeriesPage are the same page (a
  PageHeader over a list page, passing ten properties through). BooksOfPage also takes
  `downloadedOnly` and `seriesOrder`, which its query already has.
- **Rows**: BookRow and GroupRow repeat the row metrics, the three text baselines, the
  "a | b" detail line, the formats row, the section square and the line under the row.
  Only BookRow's square shrinks long labels.
- **Covers**: the "re-fetch when the download arrives" image is written four times
  (BookRow, GroupRow's StackCover, BookInfoPage, AuthorPortrait's photo).
- **Info pages**: BookInfoPage and AuthorInfoPage share a skeleton (PageHeader, Flickable,
  image beside fields, InfoCells, description, scrollbar, page buttons) but no component.
  Their date formatting is written twice, and the book's description is always rich text
  while the author's is only when it has tags.
- **Small repeats**: A2 flick handling (ListPage and both info pages); the faded window
  (main.qml twice, BookInfoPage, SystemDialog, BookMenu); the dialog text style (10
  copies over main.qml, DownloadDialog and FindBooksDialog).
- **Book logic**: a book's record ids (BookMenu, the delete dialog, BookInfoPage, BookRow,
  `openBook`), Open with's target (BookMenu, BookInfoPage), the download option for a
  book with no variants (BookMenu, DownloadDialog) and file sizes (BookInfoPage,
  DownloadDialog).
- **Loose ends**: the recent-searches rows and the info pages' links use a plain
  MouseArea, not TapArea, so a scroll can end in a tap. SectionHeading is unused.
  ListPage's `loadVisibleBooks` serves group lists too and JumpRail calls it unseen.
  `tabOverhang` defaults to `dp(4)` but every caller sets `border.width - 1`.
- **Untested shared components**: GroupRow, InfoField, InfoCells, EmptyState,
  SystemDialog, PopupMenu, TapArea.

## Remaining order

Each step leaves the app working and the tests passing, with an emulator run before it's
done. A component that becomes shared gets its component test in the same step, and the
feature files drop what it covers.

5. Done: **an error per list (the bug)**. `PagedBooks` and `Groups` keep their own error
   (`booksError`, `collectionsError` and the rest), cleared when the list starts loading
   and when a page of it arrives. `callJson` hands its message to the caller, which sets
   its list's; `loadLibrary` passes a failure to every list waiting for it, and requests
   waiting for a failed session refresh fail with its error instead of never finishing.
   `bookOrbit.error` is only signing in's. ListPage's `error` has no default; each page
   passes its list's. Search doesn't pass one yet (its TODO.md item). Tested once, in
   tst_booksof: an error stays on its own list and goes when the list loads again. The
   extra properties didn't call for Target step 5.
6. Done: **menu wiring once**. ListPage reverses its own query's sort. main.qml makes
   one `ListMenus` (which menu is open, `filterClicked()`, `sortClicked()`) and gives it
   to every list page as `menus`, in place of five properties and three handlers each.
   SubToolbar's `tabOverhang` defaults to what every caller passed (PopupMenu's border
   less the bar's line), so nobody sets it. The Series sort-icon test went; the library's
   stays as its check that a reversed sort reaches the server. The emulator's screens
   match before and after. The QML tests now run with Qt's disk cache off: it's kept in
   the build folder and wasn't refreshed when ListPage's properties changed, which hung
   the first app test.
7. Done: **shared rail metric**. `RailLayout` says where a rail's entries go: the alphabet
   centred between a top and bottom, spaced as tightly as it needs. main.qml makes one in
   window coordinates for the library's rail space (between its sub-toolbar and page
   buttons) and every list page, the library too, takes it as `railLayout`; a rail
   without one centres itself with a RailLayout of its own. No page refers to
   `libraryPage`, `jumpRailTop` and `jumpRailPitch` are gone, and the library's error
   line no longer moves every rail. The emulator's screens (library, Series, Authors, an
   author's books and series) match before and after.
8. Done: **one page with a header**. ListPage takes an optional `title`, shown in a
   PageHeader with a back button (`back()`), and has a white background for pages opened
   over the views. BooksOfPage is now a BookListPage and AuthorSeriesPage a
   GroupListPage, each with a title and its own rules, with nothing passed through.
   BooksOfPage reads `seriesOrder` and `downloadedOnly` from its query. ListPage's
   component test covers the toolbar. The emulator's screens match before and after.
9. Done: **rows**. `Cover` is a book's cover for BookRow, GroupRow's stack and
   BookInfoPage: fetched at its size and again when the download arrives, the blank book
   until then, fitted in the middle or a corner, with an optional white edge. A cover is
   fetched unless the book says it has none (`hasCover: false`). AuthorPortrait keeps its
   own photo, which comes from another cache call. `ListRow` is the row BookRow and
   GroupRow build on: sizes, tap and hold (a row that can't be held still opens on a long
   press), title, second line, the "a | b" details, formats with pills for those on the
   device, the section square or date box, and the line under the row. Group rows'
   section letters now render as book rows' do, moving them by under a pixel; covers,
   stacks and portraits match before and after in the emulator. Component tests: ListRow
   for the row (moved from BookRow's), Cover, and GroupRow; BookRow keeps what's its own.
10. Done: **info pages**. `InfoPage` is the frame BookInfoPage and AuthorInfoPage build
    on: PageHeader with title and back, a column with the system page's margins that
    scrolls (A2 while moving), scrollbar, page buttons, `scrollToTop()`, and an `overlay`
    for what sits over the page (the book's CHOOSE ACTION and its menu). The cover or
    photo beside the fields stays in each page, since the book's AUDIOBOOK | EBOOK switch
    sits level with the cover's bottom. `format.js` has the date ("12/03/1948", else the
    year) and `isHtml()`: only a closing tag descriptions use, or `<br>`, makes text HTML.
    Every InfoField uses it, so book descriptions keep a plain text's line breaks too.
    InfoField's and InfoCells' taps are TapAreas, which now find the Flickable they're in
    when not told, so lifting a finger off a scroll doesn't open a link. Component tests
    for InfoPage, InfoField (including the HTML rule) and InfoCells. The emulator's book
    info, its menu and author info match before and after.
11. Done: **small shared pieces**. `A2Scrolling` (a Connections on a Flickable) gives
    ListPage and InfoPage their A2 updates while scrolling. `Fade` is the faded window that
    takes taps, used by the sort and filter menus, the header menu, the info page's menu,
    SystemDialog and the book menu. SystemDialog takes a `heading` (bold) and `message`,
    with children between them in its `DialogText` style and `messageGap` above the
    message; the delete, diagnostics, launcher tile, download and Find books dialogs use
    them, and every dialog's message is named "message". Recent searches use TapArea.
    SectionHeading is gone and `loadVisibleBooks` is `loadVisibleRows`. Component tests for
    TapArea (the tap rules, moved from ListRow's and InfoField's tests, and finding its
    Flickable), SystemDialog (with Fade), EmptyState and PopupMenu. The emulator's menus,
    fades and dialogs match before and after.
12. **Book logic in one place**. A JS library (or `downloads`) for record ids, Open
    with's target (with the info page's chosen version as an option), the download option
    and file sizes, used by BookMenu, BookInfoPage, DownloadDialog, the delete dialog,
    BookRow and `openBook`.

Steps 9 to 12 are independent of each other; 6, 7 and 8 go in that order.

## Decided after step 4

- **Empty-state wording**: varies by view, deliberately ("No books found" doesn't say the
  same as "No collections"). EmptyState already only lays out the `title` and `text` it's
  given, through ListPage's `emptyTitle` and `emptyText`, so each page keeps setting its
  own. The same goes for offline texts: each view says what it can still show.
- **Description format**: book and author descriptions both arrive as HTML from some
  sources and plain text from others, and both pages show either. One rule for both (step
  10): rich text only for real HTML, plain text otherwise so its line breaks stay. The
  check is strict enough that plain text with a stray `<` isn't taken for HTML, and its
  component test covers HTML, plain text with line breaks, and plain text with `<` in it.
- **Server error presentation** stays in TODO.md. Step 5 only makes each list show its
  own error.
