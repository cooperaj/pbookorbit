# Helpers for tests that run the app's code against a fake BookOrbit server, with the
# inkview calls that would reach the device faked. Include after common.pri.
INCLUDEPATH += $$PWD
HEADERS += $$PWD/fakeinkview.h $$PWD/fakeserver.h
SOURCES += $$PWD/fakeinkview.cpp $$PWD/fakeserver.cpp
DEFINES += FIXTURES_DIR=\\\"$$clean_path($$PWD/../fixtures)\\\"
