# Shared by every test project. testcase gives `make check`, which runs the test program;
# pb test runs it on Qt's offscreen platform.
CONFIG += c++17 testcase
QT += quick network testlib
INCLUDEPATH += $$PWD/../src

# appcore first, so the linker resolves its references in the kit's libraries after it. The
# build tree mirrors this folder, so the path from the test's build folder back up to
# tests/ is the same as in the source.
APPCORE = $$OUT_PWD/$$relative_path($$PWD, $$_PRO_FILE_PWD_)/appcore/libappcore.a
LIBS += $$APPCORE
PRE_TARGETDEPS += $$APPCORE

include($$(PB_KIT)/qmake/pocketbook.pri)
LIBS += -lsqlite3
