#!/usr/bin/env python3
"""Writes the release fixtures: GitHub's list of releases as its API gives it, and a release
zip as `make release` packs it, with a stored copy and a damaged one for the zip reader.
Run it from anywhere after changing it: python3 tests/fixtures/releases/make.py"""

import hashlib
import json
import pathlib
import zipfile

HERE = pathlib.Path(__file__).parent
BASE = "https://github.com/cooperaj/pbookorbit/releases"
# Fixed, so the zips and their digests don't change from run to run
DATE = (2026, 11, 16, 12, 0, 0)
# The zip the app installs from; others in a release are for other devices
INSTALLED = "pbookorbit-0.10.0-B300-6.10.zip"


def make_zip(path, compression):
    with zipfile.ZipFile(path, "w") as archive:
        for name, data in [("pbookorbit.app", b"#!/bin/sh\n# launcher 0.10.0\n"),
                           ("pbookorbit/", b""),
                           ("pbookorbit/pbookorbit", b"binary 0.10.0\n" * 200)]:
            info = zipfile.ZipInfo(name, DATE)
            info.compress_type = compression
            info.external_attr = (0o40755 if name.endswith("/") else 0o100755) << 16
            archive.writestr(info, data)


def release(tag, sdks, prerelease=True):
    assets = []
    for sdk in sdks:
        name = f"pbookorbit-{tag}-{sdk}.zip"
        asset = {"name": name, "size": 836333,
                 "digest": "sha256:b251880b67fe35d155debf74e2fc212e1278ba2abfa4c631d0ace0bbef54b4dc",
                 "browser_download_url": f"{BASE}/download/{tag}/{name}"}
        # The fake server serves this one; {server} becomes its address
        if name == INSTALLED:
            data = (HERE / name).read_bytes()
            asset.update(size=len(data), digest="sha256:" + hashlib.sha256(data).hexdigest(),
                         browser_download_url="{server}/download/" + name)
        assets.append(asset)
    return {"tag_name": tag, "name": tag, "draft": False, "prerelease": prerelease,
            "html_url": f"{BASE}/tag/{tag}", "assets": assets}


make_zip(HERE / INSTALLED, zipfile.ZIP_DEFLATED)
make_zip(HERE / "stored.zip", zipfile.ZIP_STORED)
# The binary's data changed after its CRC was recorded
damaged = bytearray((HERE / "stored.zip").read_bytes())
damaged[damaged.index(b"binary 0.10.0") + 7] ^= 0xFF
(HERE / "damaged.zip").write_bytes(damaged)

lists = {
    "newer.json": [release("0.10.0", ["B288-6.10", "B300-6.10"]),
                   release("0.9.0", ["B288-6.10", "B300-6.10"])],
    "none-newer.json": [release("0.9.0", ["B288-6.10", "B300-6.10"]),
                        release("0.8.0", ["B288-6.10", "B300-6.10"])],
    "newer-not-for-b300.json": [release("0.10.0", ["B288-6.10", "RK3566-6.11"]),
                                release("0.9.0", ["B288-6.10", "B300-6.10"])],
}
for name, releases in lists.items():
    (HERE / name).write_text(json.dumps(releases, indent=2) + "\n")
