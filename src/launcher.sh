#!/bin/sh
# PBookOrbit's launcher, applications/pbookorbit.app. Runs the app from
# applications/pbookorbit/, installs an update the app left there, and starts the app again
# when it asks to. Modelled on KOReader's koreader.app.

APP_DIR=/mnt/ext1/applications/pbookorbit
BINARY="$APP_DIR/pbookorbit"
# The app writes these: a new binary, and a request to start again once it exits
UPDATE="$APP_DIR/update/pbookorbit"
RESTART="$APP_DIR/restart"
PID_FILE=/tmp/pbookorbit.pid
LOG=/mnt/ext1/pbookorbit-launcher.log

log() {
    echo "$(date '+%H:%M:%S') [$$] $*" >>"$LOG"
}

# sh reads a script as it runs it, so run a copy, leaving this one free to be replaced
if [ "$(dirname "$0")" != /tmp ]; then
    : >"$LOG"
    log "started as $0 $*"
    cp -f "$0" /tmp/pbookorbit.app && chmod 755 /tmp/pbookorbit.app
    # For the app's tile, which would otherwise start the app without this
    export PBOOKORBIT_LAUNCHER="$0"
    exec /tmp/pbookorbit.app "$@"
fi

# Already running: bring it to the front instead
running=$(cat "$PID_FILE" 2>/dev/null)
if [ -n "$running" ] && [ -e "/proc/$running" ]; then
    iv2sh=/usr/bin/iv2sh
    [ -x "$iv2sh" ] || iv2sh=/ebrmain/bin/iv2sh
    log "already running as $running, $iv2sh SetActiveTask"
    exec "$iv2sh" SetActiveTask "$running" 0
fi
echo $$ >"$PID_FILE"

# Firmware 6.11 refuses system libraries marked executable-stack without this
export GLIBC_TUNABLES="${GLIBC_TUNABLES}${GLIBC_TUNABLES:+:}glibc.rtld.execstack=2"

while :; do
    if [ -f "$UPDATE" ]; then
        mv -f "$BINARY" "$BINARY.old" && mv -f "$UPDATE" "$BINARY" && sync
        log "installed update: $(ls -l "$BINARY")"
    fi

    log "running $BINARY"
    "$BINARY" "$@" >>"$LOG" 2>&1
    status=$?
    log "exited with $status"

    [ -f "$RESTART" ] || break
    rm -f "$RESTART"
    log "restarting"
done

rm -f "$PID_FILE"
exit "$status"
