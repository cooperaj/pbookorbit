#include "fakeinkview.h"

// Declares the functions below with C linkage, as libinkview has them, and checks their
// signatures against it
#include <inkview.h>
#include <cstdlib>
#include <cstring>
#include <vector>

static FakeInkview *current = nullptr;

FakeInkview::FakeInkview(QObject *parent) : QObject(parent)
{
    current = this;
}

FakeInkview::~FakeInkview()
{
    if (current == this)
        current = nullptr;
}

FakeInkview *FakeInkview::instance()
{
    if (!current)
        qFatal("FakeInkview: an inkview call before one was made");
    return current;
}

void FakeInkview::reset(const QVariantMap &apps, bool night)
{
    fileTypes.clear();
    langTexts.clear();
    fileHandlers.clear();
    for (auto it = apps.begin(); it != apps.end(); ++it) {
        QStringList programs;
        for (const QVariant &value : it.value().toList()) {
            const QVariantMap app = value.toMap();
            const QString program = app.value("app").toString();
            programs.append(program);
            // The name the system shows for it, from the language file
            if (app.contains("name"))
                langTexts.insert(("@" + QString(program).remove(".app")).toUtf8(), app.value("name").toString().toUtf8());
        }
        fileTypes.append({it.key().toUtf8(), programs.join(',').toUtf8()});
    }
    nightMode = night;
    appCapabilities = 0;
    m_openedBooks.clear();
    m_openedTasks.clear();
    m_libraryScans = 0;
    emit changed();
}

void FakeInkview::bookOpened(const QString &path, const QString &app)
{
    m_openedBooks.append(QVariantMap{{"path", path}, {"app", app}});
    emit changed();
}

void FakeInkview::taskOpened(const QString &app, const QStringList &args)
{
    m_openedTasks.append(QVariantMap{{"app", app}, {"args", args}});
    emit changed();
}

void FakeInkview::libraryScanned()
{
    m_libraryScans++;
    emit changed();
}

// Opening books and tasks: recorded, nothing opens

void SetFileHandler(const char *path, const char *handler)
{
    FakeInkview::instance()->fileHandlers.insert(path, QString::fromUtf8(handler));
}

int OpenBook(const char *path, const char *, int)
{
    FakeInkview *inkview = FakeInkview::instance();
    inkview->bookOpened(QString::fromUtf8(path), inkview->fileHandlers.value(path));
    return 0;
}

int OpenTask(const char *path, int argc, const char *const *argv, int)
{
    QStringList args;
    for (int i = 0; i < argc; i++)
        args.append(QString::fromUtf8(argv[i]));
    FakeInkview::instance()->taskOpened(QString::fromUtf8(path), args);
    return 0;
}

int SendEventTo(int, int type, int, int)
{
    if (type == EVT_STARTSCAN)
        FakeInkview::instance()->libraryScanned();
    return 0;
}

// The system's apps for each format, as extensions.cfg lists them

iv_filetype *GetSupportedFileTypes()
{
    static std::vector<iv_filetype> types;
    types.clear();
    for (FakeInkview::FileType &type : FakeInkview::instance()->fileTypes)
        types.push_back({type.extension.data(), nullptr, 0, type.programs.data(), nullptr});
    return types.empty() ? nullptr : types.data();
}

int GetSupportedFileTypesLength()
{
    return int(FakeInkview::instance()->fileTypes.size());
}

// The text itself when there's no translation, as the real one does
const char *GetLangText(const char *s)
{
    const auto &texts = FakeInkview::instance()->langTexts;
    const auto it = texts.constFind(s);
    return it == texts.cend() ? s : it->constData();
}

// The theme: a white 32x32 icon for every name, about a theme icon's size, so buttons
// sized by their icon can be tapped. The caller frees it.

ibitmap *GetResource(const char *, const ibitmap *)
{
    const int size = 32;
    auto *bitmap = static_cast<ibitmap *>(malloc(sizeof(ibitmap) + size * size));
    bitmap->width = size;
    bitmap->height = size;
    bitmap->depth = 8;
    bitmap->scanline = size;
    memset(bitmap->data, 0xff, size * size);
    return bitmap;
}

// Night mode

bool IvGetScreenModeInversion(void)
{
    return FakeInkview::instance()->nightMode;
}

int IvGetAppCapability(void)
{
    return FakeInkview::instance()->appCapabilities;
}

void IvSetAppCapability(int caps)
{
    FakeInkview::instance()->appCapabilities = caps;
}

// The device and its task manager

char *GetDeviceModel()
{
    static char model[] = "Test Device";
    return model;
}

// Connected unless the test has turned the network off (testApp.offline)
int QueryNetwork()
{
    return qEnvironmentVariableIsSet("PBOOKORBIT_OFFLINE") ? 0 : NET_CONNECTED;
}

int GetCurrentTask()
{
    return 1;
}

taskinfo *GetTaskInfo(int)
{
    return nullptr;
}

int SetTaskParameters(int, const char *, const char *, ibitmap *, unsigned int)
{
    return 0;
}

int SetSubtaskInfo(int, int, const char *, const char *)
{
    return 0;
}
