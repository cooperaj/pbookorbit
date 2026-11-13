# Helpers for tests that run the app's code against a fake BookOrbit server. Include after
# common.pri.
INCLUDEPATH += $$PWD
HEADERS += $$PWD/fakeserver.h
SOURCES += $$PWD/fakeserver.cpp
DEFINES += FIXTURES_DIR=\\\"$$clean_path($$PWD/../fixtures)\\\"
