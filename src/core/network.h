#pragma once

// The device's network connection, as the system reports it. PBOOKORBIT_OFFLINE=1 makes it
// seem to have none, for make run-offline and tests; it's read each time, so tests can
// change it.
namespace network {

// Whether PBOOKORBIT_OFFLINE says to act as though there were no network
bool simulatingOffline();

// Whether the device has a connection. Always in the emulator, unless simulating offline.
bool connected();

// On the device, connects Wi-Fi if needed, with the system's dialog. Returns whether it's
// connected. For what the user asked for, as it blocks while connecting.
bool ensure();

}
