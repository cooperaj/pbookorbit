# Runs every tst_*.qml in this folder. qmltestcase points the runner at the folder itself,
# so a new test file needs no build change.
TARGET = tst_qml
CONFIG += qmltestcase
SOURCES += main.cpp
include(../common.pri)
include(../support/support.pri)
# The app's icons (qrc:/icons/...). The tests load the QML itself from src/qml on disk.
RESOURCES += ../../src/qml.qrc

# Editable in the IDE, not compiled
DISTFILES += $$files(*.qml, true) $$files(../fixtures/*, true)
