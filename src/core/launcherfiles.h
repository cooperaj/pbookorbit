#pragma once

#include <QString>

// The launcher script that starts the app, applications/pbookorbit.app (src/launcher.sh),
// and the files beside it that the app leaves for it. The script finds them the same way,
// from where it is.
struct LauncherFiles {
    // The script; empty if it didn't start the app, as in the emulator
    QString script;

    // The script that started this app, as it says in PBOOKORBIT_LAUNCHER
    static LauncherFiles current();

    // applications/pbookorbit, which has the app
    QString appDir() const;
    // A new binary, installed when the app next starts
    QString update() const;
    // Asks for the app to be started again once it exits
    QString restart() const;
};
