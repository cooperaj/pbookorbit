#pragma once

#include <QByteArray>

// InkView's OpenBook(), except in the emulator, where it opens nothing and logs what it
// would have. The emulator's OpenBook() forks the app and waits for the child, which can
// deadlock on a lock another thread held at the fork, freezing the app for good. The
// tests keep the call, to their fake OpenBook().
int openBook(const QByteArray &path, const QByteArray &parameters, int flags);
