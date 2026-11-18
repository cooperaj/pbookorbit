# The tests, built and run by the kit's pb test (make test at the repo root). Each test is
# its own program, linked against appcore, the app's code without main.cpp.
TEMPLATE = subdirs
SUBDIRS = appcore bookrecords formats booklistmodel updates zipreader qml

bookrecords.subdir = unit/bookrecords
formats.subdir = unit/formats
booklistmodel.subdir = unit/booklistmodel
updates.subdir = unit/updates
zipreader.subdir = unit/zipreader

bookrecords.depends = appcore
formats.depends = appcore
booklistmodel.depends = appcore
updates.depends = appcore
zipreader.depends = appcore
qml.depends = appcore
