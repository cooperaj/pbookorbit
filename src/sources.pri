# Everything but main.cpp, shared by the app and the tests' appcore library. Paths are
# relative to this file, so it works from either .pro.
SOURCES += \
    $$PWD/core/bookfinder.cpp \
    $$PWD/core/browser.cpp \
    $$PWD/core/booklistmodel.cpp \
    $$PWD/core/booklists.cpp \
    $$PWD/core/bookorbitclient.cpp \
    $$PWD/core/bookrecords.cpp \
    $$PWD/core/database.cpp \
    $$PWD/core/details.cpp \
    $$PWD/core/diagnostics.cpp \
    $$PWD/core/downloads.cpp \
    $$PWD/core/launcherfiles.cpp \
    $$PWD/core/network.cpp \
    $$PWD/core/pagedbooklist.cpp \
    $$PWD/core/recentsearches.cpp \
    $$PWD/core/savefile.cpp \
    $$PWD/core/session.cpp \
    $$PWD/core/systemlibrary.cpp \
    $$PWD/core/updater.cpp \
    $$PWD/core/zipreader.cpp \
    $$PWD/ui/accents.cpp \
    $$PWD/ui/covers.cpp \
    $$PWD/ui/eink.cpp \
    $$PWD/ui/einkcolors.cpp \
    $$PWD/ui/invertedimageprovider.cpp \
    $$PWD/ui/launchertile.cpp \
    $$PWD/ui/theme.cpp \
    $$PWD/ui/themeimageprovider.cpp
HEADERS += \
    $$PWD/core/bookfinder.h \
    $$PWD/core/browser.h \
    $$PWD/core/booklistmodel.h \
    $$PWD/core/booklists.h \
    $$PWD/core/bookorbitclient.h \
    $$PWD/core/bookrecords.h \
    $$PWD/core/database.h \
    $$PWD/core/details.h \
    $$PWD/core/diagnostics.h \
    $$PWD/core/downloads.h \
    $$PWD/core/launcherfiles.h \
    $$PWD/core/network.h \
    $$PWD/core/pagedbooklist.h \
    $$PWD/core/recentsearches.h \
    $$PWD/core/savefile.h \
    $$PWD/core/session.h \
    $$PWD/core/formats.h \
    $$PWD/core/systemlibrary.h \
    $$PWD/core/updater.h \
    $$PWD/core/zipreader.h \
    $$PWD/ui/accents.h \
    $$PWD/ui/covers.h \
    $$PWD/ui/eink.h \
    $$PWD/ui/einkcolors.h \
    $$PWD/ui/invertedimageprovider.h \
    $$PWD/ui/launchertile.h \
    $$PWD/ui/theme.h \
    $$PWD/ui/themeimageprovider.h

# qmake SUGGESTED_SERVER=books.example.com prefills the server field, for builds handed to
# users of that server. It's written to a generated header only when it changes, so
# switching servers recompiles what uses it.
SERVER_HEADER = $$OUT_PWD/suggestedserver.h
SERVER_DEFINE = "$${LITERAL_HASH}define SUGGESTED_SERVER \"$$SUGGESTED_SERVER\""
!equals(SERVER_DEFINE, $$cat($$SERVER_HEADER, blob)): write_file($$SERVER_HEADER, SERVER_DEFINE)
!isEmpty(SUGGESTED_SERVER): message("$$TARGET: suggesting the server $$SUGGESTED_SERVER")
