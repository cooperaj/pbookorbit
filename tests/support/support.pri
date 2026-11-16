# Helpers for tests that run the app's code against a fake BookOrbit server, with the
# inkview calls that would reach the device faked, and the on-screen keyboard (gui-private,
# for Qt's hook to replace the input context). Include after common.pri.
QT += gui-private
INCLUDEPATH += $$PWD
HEADERS += $$PWD/fakeinkview.h $$PWD/fakekeyboard.h $$PWD/fakeserver.h
SOURCES += $$PWD/fakeinkview.cpp $$PWD/fakekeyboard.cpp $$PWD/fakeserver.cpp
