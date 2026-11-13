TARGET = pbookorbit.app
QT += quick network
CONFIG += c++17 qtquickcompiler

INCLUDEPATH += src

SOURCES += src/main.cpp
include(src/sources.pri)
RESOURCES += src/qml.qrc

include($$(PB_KIT)/qmake/pocketbook.pri)
LIBS += -lsqlite3
