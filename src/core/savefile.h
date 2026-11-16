#pragma once

#include <QByteArray>
#include <QString>

// Writes bytes to path atomically, through a temporary file renamed into place, so nothing
// reads half of it. Returns why it couldn't, or an empty string.
QString saveFile(const QString &path, const QByteArray &bytes);
