#pragma once

#include <QString>
#include <QStringList>

// Ebook and audiobook formats as BookOrbit names them, in lower case: its
// EBOOK_FORMAT_LIST and AUDIO_FORMAT_LIST
inline const QStringList &ebookFormats()
{
    static const QStringList ebook{"epub", "kepub", "mobi", "azw3", "azw", "fb2", "pdf", "djvu", "cbz", "cbr"};
    return ebook;
}
inline const QStringList &audioFormats()
{
    static const QStringList audio{"m4b", "mp3", "m4a", "opus", "ogg", "flac"};
    return audio;
}

// Any format not an audiobook's is an ebook's
inline bool isAudioFormat(const QString &format)
{
    return audioFormats().contains(format.toLower());
}

inline bool isBookFormat(const QString &format)
{
    return ebookFormats().contains(format.toLower()) || isAudioFormat(format);
}

// "ebook" or "audiobook"
inline QString mediaKind(const QString &format)
{
    return isAudioFormat(format) ? QStringLiteral("audiobook") : QStringLiteral("ebook");
}
