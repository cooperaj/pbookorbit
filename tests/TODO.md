# Test backlog

In order. Done so far: sign-in/out, offline, start-up, library and sub-toolbar, downloading, book menu.

1. [x] Deleting books: the delete dialog's ebook / audiobook choices remove only the right files and records (`app/tst_deleting.qml`).
2. [x] Book info page: details, author and series links, saved details when offline, and its Delete for just the chosen version (`app/tst_bookinfo.qml`).
3. [x] Search: server search, recent searches, offline search over downloaded books, the search page's tap handler (`app/tst_search.qml`).
4. [x] Session expiry: a refused refresh returns to sign-in with "Session expired"; a refused request refreshes and retries once (`app/tst_session.qml`).
5. [x] Paging: more than 40 books loads the next page; hardware page keys; `components/tst_pagebuttons.qml` (`app/tst_paging.qml`).
6. [ ] Start-up cache: the last library rows show while waiting for the server.

Low priority: diagnostics toggle, night mode, launcher tile, form moving up for the keyboard.
