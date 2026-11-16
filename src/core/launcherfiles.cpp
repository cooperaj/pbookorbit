#include "core/launcherfiles.h"

#include <QFileInfo>

LauncherFiles LauncherFiles::current()
{
    return {qEnvironmentVariable("PBOOKORBIT_LAUNCHER")};
}

QString LauncherFiles::appDir() const
{
    return QFileInfo(script).absolutePath() + "/pbookorbit";
}

QString LauncherFiles::update() const
{
    return appDir() + "/update/pbookorbit";
}

QString LauncherFiles::restart() const
{
    return appDir() + "/restart";
}
