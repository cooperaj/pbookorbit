# The app's code as a static library, so each test links only what it uses
TEMPLATE = lib
CONFIG += staticlib c++17
QT += quick network

INCLUDEPATH += ../../src
include(../../src/sources.pri)
include($$(PB_KIT)/qmake/pocketbook.pri)
