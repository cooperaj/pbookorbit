# The tests, built and run by the kit's pb test (make test at the repo root). Each test is
# its own program, linked against appcore, the app's code without main.cpp.
TEMPLATE = subdirs
SUBDIRS = appcore formats booklistmodel qml

formats.subdir = unit/formats
booklistmodel.subdir = unit/booklistmodel

formats.depends = appcore
booklistmodel.depends = appcore
qml.depends = appcore
