#pragma once

#include <QByteArray>
#include <QHash>
#include <QStringList>

// Reads files out of a zip archive in memory, with zlib: stored or deflated, as zip tools
// write them, without zip64 or encryption. Qt's own reader is private API, which changes
// between Qt versions, and devices run different ones.
namespace zip {

// The contents of the named files, by name, e.g. "pbookorbit/pbookorbit". A file that's
// missing, damaged (its CRC doesn't match) or stored another way is left out.
QHash<QString, QByteArray> read(const QByteArray &archive, const QStringList &names);

}
