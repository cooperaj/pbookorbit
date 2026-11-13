# Runs every tst_*.qml in this folder. qmltestcase points the runner at the folder itself,
# so a new test file needs no build change.
TARGET = tst_qml
CONFIG += qmltestcase
SOURCES += main.cpp
include(../common.pri)
include(../support/support.pri)

# Editable in the IDE, not compiled
DISTFILES += $$files(tst_*.qml) $$files(stubs/*.qml) $$files(../fixtures/*, true)
