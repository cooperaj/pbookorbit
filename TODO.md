# To do

- Offline collections only know the books of collections looked up while online (see
  `group_details` in docs/technical.md), so a collection never scrolled to online won't
  list its downloaded books offline.
- Jump rail: dragging along it, and jumping by date for the date sorts (the jump-buckets
  endpoint returns days or months for those).
- Test data for reading status: the `app` test account has no reading progress or
  statuses, so "Completed" and "N% read" can't be seen in the emulator. Add a mock, e.g. an
  environment variable that makes `PagedBookList::decorateBook()` give books sample progress and statuses.
- Check the system library's schema on firmware 6.11 and add it to `CHECKED_FIRMWARE` in
  `src/core/systemlibrary.cpp` if it's the same.
- Find books: review unsure matches in a list. Since any title match is now offered, a
  device with many books can have dozens, and the dialog lists four and adds them all or
  none. Give them a page of their own, a row per file with the book it looks like, to
  accept or reject each (and all at once).
- Find books: offer it again after signing in to a different server. The offer is only
  made once per device (the `findBooksOffered` flag), so a second server's library is
  never offered, though "Find books on this device" in the menu still works.
- Read each book file's own metadata (title, authors, series, identifiers; EPUB's OPF,
  MOBI's EXTH), so Find books can match files whose name and hash no longer match the
  server's copy, and offline pages can show details nothing saved. Check first what the
  firmware offers for this rather than unzipping by hand.
- Quitting with the home button in the emulator sometimes crashes (segfault, exit 139,
  right after the emulator prints `hw_close`; the log stops without its usual shutdown
  lines). Seen a few times on 28 October 2026, at least once offline. Headless runs that
  quit with the home button or close the window exit cleanly, so it hasn't been
  reproduced. Next time, get a backtrace (run under gdb in `kit/pb.sh shell .`, or enable
  core dumps in the container). Seen again on 20 November 2026 going back from an author's
  books (`hw_close`, then the emulator closed). Home on the main header is where the back
  button is on the pages over it, so a quick extra back tap can quit the app without
  meaning to: consider ignoring Home for a second after a page closes.
- Check on the device that downloaded books show in the system library without a reboot
  (the app asks the scanner to scan; see NOTES.md for what else could be done).
- Books with an ebook and an audiobook: once one version is downloaded, a tap opens it;
  add a way to get or open the other version.
- Book menu: the system's menu also has Mark as read, Add to collection, Add to Favorites,
  Select and Open with; the Book info page has a favourite heart and CHOOSE ACTION.
- Deleting a book asks the scanner to scan again: check on the device that the book also
  leaves the system library. KOReader's `.sdr` folder beside the book is left in place.
- Home screen tile: check it in night mode (the icons are black on white). Other devices
  will want other icon sizes (106x64 on a PB629).
- Check the log's "Qt ..., QML compiled for ..." line on the device: if the firmware's Qt
  isn't 6.8.2 the compiled QML is ignored and compiled on every launch (see NOTES.md,
  Compiled QML).
- Compiled QML: most bindings run as bytecode, not C++ (NOTES.md has why). Time how long
  the first book list takes to fill on the device; if it's slow, start with `BookRow` and
  `GroupRow` (typed functions, required properties, then typed units and singletons).
- Firmware 6.11 on B288/B300 devices (Era, Verse Pro, InkPad 4 and others since October
  2026; there is no 6.11 SDK for them, so they run the 6.10 build): check the app starts.
  The launcher sets `GLIBC_TUNABLES=...glibc.rtld.execstack=2`, KOReader's workaround for
  "firmware 6.11.1480 rejecting executable-stack system libraries" (koreader/koreader#15720),
  as the 6.10 SDK's `libinkview` and `libhwconfig` are marked executable-stack.
- InkPad One (PB1030, RK3566, firmware 6.11): build and release it. PR 1 has what it needs:
  armhf, software rendering (`QSG_RHI_BACKEND=software`, `QT_QUICK_BACKEND=software`) and
  `/ebrmain/plugins/platforms` and `/ebrmain/lib` on the plugin and library paths, set by
  the launcher for that build only; and its firmware's Qt is 6.10.3, so the QML compiled
  for the SDK's 6.8.2 is ignored (see Compiled QML in NOTES.md). Then add RK3566-6.11 to
  `RELEASE_SDKS` in the Makefile.
- Search: test what a failed search shows. If it hides the error (it likely says "No books
  found"), make it say "Something went wrong" like the other lists.
- Server errors: revisit the messages and how they show. The line above a list (library,
  books-of, the tabs) is messy and incomplete: raw text such as "Internal server error
  (HTTP 500)" squeezed between the sub-toolbar and the rows. Consider an icon in the
  header's title instead, like the offline one, that opens the details.
- Sort names: the Series and Authors tabs call their newest-first sort "Recently added"
  (`lastAddedAt`, when their latest book was added), while the library calls its own
  "Date added" (`addedAt`). They're much the same thing, so pick one name for both.
- Test the author info page picking up an author's formats and series when they arrive
  after the list (its `Connections` on `bookOrbit.authors`). Nothing covers it: splitting
  that `Connections` in the client refactor only showed up as a QML warning.
