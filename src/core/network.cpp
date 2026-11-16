#include "core/network.h"

#include "core/diagnostics.h"
#include <inkview.h>
#include <QElapsedTimer>
#include <QString>

namespace network {

bool simulatingOffline()
{
    return qEnvironmentVariableIntValue("PBOOKORBIT_OFFLINE") != 0;
}

bool connected()
{
    if (simulatingOffline())
        return false;
#ifdef EMULATOR
    return true;
#else
    return QueryNetwork() & NET_CONNECTED;
#endif
}

bool ensure()
{
    if (simulatingOffline())
        return false;
#ifndef EMULATOR
    if (!(QueryNetwork() & NET_CONNECTED)) {
        QElapsedTimer netTimer;
        netTimer.start();
        // Shows the system's own dialog while it connects
        const int rc = NetConnect2(nullptr, 1);
        (rc != 0 ? diagnostics::log : diagnostics::trace)(QString("NetConnect2 -> %1 after %2 ms, %3")
                .arg(rc).arg(netTimer.elapsed()).arg(diagnostics::networkState()));
        return rc == 0;
    }
#endif
    return true;
}

}
