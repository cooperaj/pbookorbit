#include "core/openbook.h"

#include "core/diagnostics.h"

#include <inkview.h>

int openBook(const QByteArray &path, const QByteArray &parameters, int flags)
{
#if defined(EMULATOR) && !defined(PBOOKORBIT_TESTS)
    // The caller logs what was asked
    Q_UNUSED(path);
    Q_UNUSED(parameters);
    Q_UNUSED(flags);
    diagnostics::log("OpenBook not called in the emulator");
    return 0;
#else
    return OpenBook(path.constData(), parameters.constData(), flags);
#endif
}
