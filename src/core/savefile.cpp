#include "core/savefile.h"

#include <QSaveFile>

QString saveFile(const QString &path, const QByteArray &bytes)
{
    QSaveFile file(path);
    if (file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size() && file.commit())
        return QString();
    return "Can't write " + path + ": " + file.errorString();
}
