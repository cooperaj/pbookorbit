#pragma once

#include <QHash>
#include <QString>
#include <QStringList>
#include <optional>

// Read-only use of the firmware's own databases, the library's (explorer-3.db) and the
// audiobook player's (audiobooks.db), for what BookOrbit can't tell us about books on the
// device. Their schemas are only relied on for firmware versions they were checked on;
// anywhere else, or if neither can be read, calls answer with nothing, so callers treat what
// they give as optional.
namespace systemlibrary {

// The firmware's version, e.g. "U700k3.6.10.2359"
QString firmwareVersion();

// Whether the schema is known for this firmware, so reading it can be tried
bool supported();

// When the system's reader last opened each of these files, or its player last played them
// (as stored, e.g. /mnt/ext1/Books/Dune.epub), as Unix seconds. Files never opened, or not
// known, are left out. Nothing if neither database can be read.
std::optional<QHash<QString, qint64>> lastOpened(const QStringList &paths);

}
