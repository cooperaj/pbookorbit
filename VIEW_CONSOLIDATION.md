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

The spinner and empty-state rules differ between the library (busy, downloaded only), the
group lists (`loaded`), books-of (total) and search. Each difference gets listed and
decided when ListPage takes them over: deliberate, or drift.

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

1. Done: GroupsPage takes `error` and `online` (defaulting to the client's) and has a
   component test. The Collections, Series and Authors files keep only their own
   behaviour, with the shared client behaviour in Series.
2. Done: an author's series, its own behaviour only (straight to the books for a single
   series, exact author matching, reloading per author, the sort kept between authors).
3. BookListPage for the library, books-of and search, with a component test. Then their
   feature files are trimmed to what's particular to each.
4. Steps 1, 3 and 4 of the target, with every test passing after each.
