#!/bin/bash
# A release's files: for each SDK given, a device build packed as the update check expects,
# build/release/pbookorbit-<version>-<sdk>.zip, the version taken from the build's own
# pb_build.h. Each zip unzips into the device's applications/ folder: the launcher,
# pbookorbit.app, and the app, pbookorbit/pbookorbit (see LauncherFiles). Run by make release,
# with PB set to the kit's pb and SERVER to prefill the sign-in server, if any.
#
#   scripts/release.sh B288-6.10 B300-6.10

set -euo pipefail
cd "$(dirname "$0")/.."

for sdk in "$@"; do
    PB_SDK=$sdk PB_QMAKE_ARGS="${SERVER:+SUGGESTED_SERVER=$SERVER}" "$PB" arm .
    build=build/pbookorbit/$sdk/arm
    version=$(sed -n 's/^#define PB_APP_VERSION "\(.*\)"$/\1/p' "$build/pb_build.h")

    # Laid out as on the device, then zipped
    stage=build/release/$sdk
    mkdir -p "$stage/pbookorbit"
    install -m 755 src/launcher.sh "$stage/pbookorbit.app"
    install -m 755 "$build/pbookorbit.app" "$stage/pbookorbit/pbookorbit"
    zip=build/release/pbookorbit-$version-$sdk
    python3 -I -c 'import shutil, sys; shutil.make_archive(sys.argv[1], "zip", sys.argv[2])' "$zip" "$stage"
    echo "$zip.zip"
done
