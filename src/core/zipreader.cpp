#include "core/zipreader.h"

#include <optional>
#include <zlib.h>

namespace zip {
namespace {

// Record signatures, and the fixed sizes before each record's variable fields
const quint32 END_SIGNATURE = 0x06054b50;
const quint32 ENTRY_SIGNATURE = 0x02014b50;
const quint32 LOCAL_SIGNATURE = 0x04034b50;
const qsizetype END_SIZE = 22;
const qsizetype ENTRY_SIZE = 46;
const qsizetype LOCAL_SIZE = 30;
const quint16 STORED = 0;
const quint16 DEFLATED = 8;
// Far more than the app's binary, so a damaged size can't ask for gigabytes
const quint32 MAX_SIZE = 64 * 1024 * 1024;

class Reader
{
public:
    explicit Reader(const QByteArray &data) : m_data(data) {}

    bool fits(qsizetype at, qsizetype size) const { return at >= 0 && size >= 0 && at + size <= m_data.size(); }
    quint16 u16(qsizetype at) const { return quint8(m_data[at]) | quint8(m_data[at + 1]) << 8; }
    quint32 u32(qsizetype at) const { return u16(at) | quint32(u16(at + 2)) << 16; }
    const char *at(qsizetype at) const { return m_data.constData() + at; }

private:
    const QByteArray &m_data;
};

// Inflates raw deflate data that should come to size bytes
std::optional<QByteArray> inflateRaw(const char *data, quint32 dataSize, quint32 size)
{
    struct Stream {
        z_stream z{};
        bool open = false;
        ~Stream()
        {
            if (open)
                inflateEnd(&z);
        }
    } stream;
    QByteArray out(size, Qt::Uninitialized);
    stream.z.next_in = reinterpret_cast<Bytef *>(const_cast<char *>(data));
    stream.z.avail_in = dataSize;
    stream.z.next_out = reinterpret_cast<Bytef *>(out.data());
    stream.z.avail_out = size;
    // Negative window bits: no zlib header, as in zip files
    stream.open = inflateInit2(&stream.z, -MAX_WBITS) == Z_OK;
    if (!stream.open || inflate(&stream.z, Z_FINISH) != Z_STREAM_END || stream.z.total_out != size)
        return std::nullopt;
    return out;
}

}

QHash<QString, QByteArray> read(const QByteArray &archive, const QStringList &names)
{
    const Reader zip(archive);
    QHash<QString, QByteArray> files;

    // The end record is last, after a comment of up to 64 KiB
    qsizetype end = -1;
    for (qsizetype at = archive.size() - END_SIZE; at >= 0 && at >= archive.size() - END_SIZE - 0xFFFF; --at) {
        if (zip.u32(at) == END_SIGNATURE) {
            end = at;
            break;
        }
    }
    if (end < 0)
        return files;

    // The central directory lists every file, and where its local record is
    const int count = zip.u16(end + 10);
    qsizetype entry = zip.u32(end + 16);
    for (int i = 0; i < count; ++i) {
        if (!zip.fits(entry, ENTRY_SIZE) || zip.u32(entry) != ENTRY_SIGNATURE)
            break;
        const quint16 method = zip.u16(entry + 10);
        const quint32 crc = zip.u32(entry + 16);
        const quint32 packedSize = zip.u32(entry + 20);
        const quint32 size = zip.u32(entry + 24);
        const quint16 nameSize = zip.u16(entry + 28);
        const qsizetype local = zip.u32(entry + 42);
        if (!zip.fits(entry + ENTRY_SIZE, nameSize))
            break;
        const QString name = QString::fromUtf8(zip.at(entry + ENTRY_SIZE), nameSize);
        entry += ENTRY_SIZE + nameSize + zip.u16(entry + 30) + zip.u16(entry + 32);
        if (!names.contains(name) || size > MAX_SIZE)
            continue;

        // The data follows the local record, whose name and extra field can differ in size
        // from the directory's
        if (!zip.fits(local, LOCAL_SIZE) || zip.u32(local) != LOCAL_SIGNATURE)
            continue;
        const qsizetype data = local + LOCAL_SIZE + zip.u16(local + 26) + zip.u16(local + 28);
        if (!zip.fits(data, packedSize))
            continue;
        std::optional<QByteArray> content;
        if (method == STORED && packedSize == size)
            content = QByteArray(zip.at(data), size);
        else if (method == DEFLATED)
            content = inflateRaw(zip.at(data), packedSize, size);
        if (content && crc32(0, reinterpret_cast<const Bytef *>(content->constData()), size) == crc)
            files.insert(name, *content);
    }
    return files;
}

}
