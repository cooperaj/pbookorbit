# Splitting up BookOrbitClient

`src/core/bookorbitclient.cpp` is about 2,800 lines and does seven jobs. This is the plan
for breaking it into parts with one job each. Delete this file once it's done.

## What it does now

| Job | Lines |
|---|---|
| Transport, auth and connectivity: tokens, refresh, send/call/callJson, whenNetwork, eventFilter, online, busy, library id | ~650 |
| Paged book lists (library, search, booksOf): pages, jump sections, section starts, list cache | ~750 |
| Book record logic: companions, variants, formats, decorateBook | ~180 |
| Group lists (collections, series, authors, an author's series): lookups, saved details, sorting | ~900 |
| Offline rows built from the local books | ~240 |
| Book and author details, updateSavedBooks | ~60 |
| Accent colour, monogram, recent searches | ~80 |

Each list's state is repeated as properties on the client (seven `xxxError`, plus
`xxxLoaded` and `xxxJumpSections`), and Downloads, BookFinder and Covers depend on the
whole client for five transport calls.

## Shape

```
BookOrbit (thin coordinator, the "bookOrbit" context property)
├── session          Session: auth, transport, connectivity
├── library          PagedBookList
├── search           PagedBookList (search text, local search)
├── booksOf          PagedBookList (field and values, collection ids)
├── collections      CollectionList : GroupList
├── series           SeriesList : GroupList
├── authors          AuthorList : GroupList (format filter, allLookedUp)
├── authorSeries     SeriesList for one author
├── GroupDetails     saved row details, shared by the group lists (not exposed)
├── LocalLibrary     local books and the offline rows built from them
├── details          book and author details, savedBooksChanged
├── theme            accent colours, author monograms
└── recentSearches
```

- **bookrecords** (namespace): pure helpers for book records. Companion keys and filters,
  files, variants, formats, status and series text, sort keys. Unit tested.
- **Session**: QNetworkAccessManager, tokens, refresh and retry, send/call/callJson,
  download/startStream/request, withLibrary, whenNetwork, the event filter, online, busy,
  networkConnected, sign in and out, serverUrl, username, error. Downloads, BookFinder and
  Covers take a `Session *`. Connectivity stays in Session for now: checkServer() needs
  refreshSession() and the transport needs setOnline(), so splitting them would make
  each depend on the other.
- **PagedBookList**: the PagedBooks struct as a QObject with its own model, total, error and
  jumpSections properties, and load(first, last), refresh(), pages, companion lookup,
  sections and the list cache.
- **GroupList** and subclasses: the Groups struct, with the Lookup enum replaced by virtual
  loadPage, lookUp and showLocal. The base keeps generations, the cache, sorting and
  sections, the wanted rows queue and listPageLoaded. `lookUpRows(model, first, last)`
  becomes `list.lookUpRows(first, last)`.
- **BookOrbit**: builds the parts, exposes them as CONSTANT properties, and fans out sign
  out, back online and setLocalBooks.

QML moves to the nested objects (`bookOrbit.collections.error`,
`bookOrbit.library.load(a, b)`, `bookOrbit.session.online`). No compatibility properties.

## Steps

Each step ends with `make test` passing, an emulator run and a before/after screenshot
comparison, then a pause for review.

1. Extract `bookrecords` and unit test it.
2. Extract `Session`. Downloads, BookFinder and Covers depend on it. QML for online,
   signedIn and busy moves to `bookOrbit.session`.
3. Extract theme, recent searches and details.
4. Promote `PagedBookList`. Library, search and booksOf move to it, with their QML.
   Removes the shared jumpSectionsChanged.
5. Promote `GroupList`, its subclasses and `GroupDetails`. The biggest, riskiest step:
   generations and the lookup queue.
6. Extract `LocalLibrary`'s offline builders.
7. Trim `BookOrbit` to the coordinator.

## Watch for

- Stale replies. Lambdas capture `Groups *` or `PagedBooks *` with a generation. As
  QObjects they capture `this` and keep the generation check. Every list lives as long as
  the root, so that's safe.
- busy (the pending count) and callJson's empty error when offline belong to Session,
  which every list goes through.
- The QML page tests use the real client and FakeServer, so they keep covering behaviour.
  Only their property paths change.
