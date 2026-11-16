#!/bin/sh
# PBookOrbit's launcher, applications/pbookorbit.app. Runs the app from the pbookorbit
# folder beside it, installs an update the app left there, and starts the app again when it
# asks to. Modelled on KOReader's koreader.app. The firmware's sh is BusyBox without
# $((...)), so expr does the sums. Nothing else checks this script: try changes on the device.

# sh reads a script as it runs it, so a copy in /tmp runs, leaving this one free to be
# replaced. The copy is told where this one is.
COPY=/tmp/pbookorbit.app
[ "$0" = "$COPY" ] || PBOOKORBIT_LAUNCHER=$0
APPLICATIONS=$(dirname "$PBOOKORBIT_LAUNCHER")
APP_DIR="$APPLICATIONS/pbookorbit"
BINARY="$APP_DIR/pbookorbit"
# The app writes these: a new binary, and a request to start again once it exits
UPDATE="$APP_DIR/update/pbookorbit"
RESTART="$APP_DIR/restart"
# At the root of the storage, beside the app's own log
LOG="$(dirname "$APPLICATIONS")/pbookorbit-launcher.log"

log() {
    echo "$(date '+%H:%M:%S') [$$] $*" >>"$LOG"
}

if [ "$0" != "$COPY" ]; then
    : >"$LOG"
    # Its own errors too, such as a failed exec
    exec 2>>"$LOG"
    log "started as $0 $*"
    cp -f "$0" "$COPY" && chmod 755 "$COPY"
    # Also for the app's tile, which would otherwise start the app without this
    export PBOOKORBIT_LAUNCHER
    exec "$COPY" "$@"
fi
log "running from /tmp"

# Firmware 6.11 refuses system libraries marked executable-stack without this
export GLIBC_TUNABLES="${GLIBC_TUNABLES}${GLIBC_TUNABLES:+:}glibc.rtld.execstack=2"

while :; do
    # The old binary is kept, to go back to if the new one fails to start
    updated=
    if [ -f "$UPDATE" ] && mv -f "$BINARY" "$BINARY.old"; then
        if mv -f "$UPDATE" "$BINARY"; then
            updated=1
            log "installed update: $(ls -l "$BINARY")"
        else
            mv -f "$BINARY.old" "$BINARY"
            log "couldn't install the update"
        fi
        sync
    fi

    log "running $BINARY"
    started=$(date +%s)
    "$BINARY" "$@" >>"$LOG" 2>&1
    status=$?
    log "exited with $status"
    # Any start after this is a restart, so the app keeps its log
    export PBOOKORBIT_RESTARTED=1

    # A new version that fails as it starts is swapped for the one before
    # shellcheck disable=SC2003
    if [ -n "$updated" ] && [ "$status" -ne 0 ] && [ "$(expr "$(date +%s)" - "$started")" -lt 30 ]; then
        mv -f "$BINARY.old" "$BINARY" && sync
        rm -f "$RESTART"
        log "update failed to start, going back to the version before"
        continue
    fi
    # The new version started, so the one before isn't needed
    if [ -n "$updated" ]; then
        rm -f "$BINARY.old"
        log "removed the version before"
    fi

    [ -f "$RESTART" ] || break
    rm -f "$RESTART"
    log "restarting"
done

exit "$status"
