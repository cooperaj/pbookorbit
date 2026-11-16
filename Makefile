# Builds PBookOrbit with pocketbook-kit: the kit/ submodule if present, otherwise pb from
# your PATH. PB_KIT=/path/to/pocketbook-kit uses another checkout.
PB_KIT ?= kit
PB := $(if $(wildcard $(PB_KIT)/pb.sh),$(PB_KIT)/pb.sh,pb)

.PHONY: setup run run-offline pc arm release test test-map shell clean icons

# Fetch the kit, its SDK and the container image
setup:
	git submodule update --init --recursive
	$(PB) setup

# Build for PC and open the app in the emulator
run:
	$(PB) run .

# Same, acting as though there were no network (see Offline in docs/technical.md)
run-offline:
	PB_ENV="PBOOKORBIT_OFFLINE=1 $(PB_ENV)" $(PB) run .

# Build for PC only
pc:
	$(PB) pc .

# Build for the device; copy build/pbookorbit/<sdk>/arm/pbookorbit.app to its applications/
# folder
arm:
	$(PB) arm .

# The SDKs a release has a file for. RK3566-6.11 (the 1030) needs more first: see PR 1.
RELEASE_SDKS ?= B288-6.10 B300-6.10

# A release's files, a zip per SDK in build/release, named as the update check expects:
# pbookorbit-<version>-<sdk>.zip, from each build's pb_build.h. Each unzips into the
# device's applications/ folder: the launcher, pbookorbit.app, and the app,
# pbookorbit/pbookorbit. SERVER=books.example.com prefills the sign-in server, for builds
# handed to users of that server. Needs python3.
release:
	@for sdk in $(RELEASE_SDKS); do \
		PB_SDK=$$sdk PB_QMAKE_ARGS="$(if $(SERVER),SUGGESTED_SERVER=$(SERVER))" $(PB) arm . || exit 1; \
		build=build/pbookorbit/$$sdk/arm; \
		version=$$(sed -n 's/^#define PB_APP_VERSION "\(.*\)"$$/\1/p' $$build/pb_build.h); \
		stage=build/release/$$sdk; \
		mkdir -p "$$stage/pbookorbit" || exit 1; \
		install -m 755 src/launcher.sh "$$stage/pbookorbit.app" || exit 1; \
		install -m 755 $$build/pbookorbit.app "$$stage/pbookorbit/pbookorbit" || exit 1; \
		python3 -I -c 'import shutil, sys; shutil.make_archive(sys.argv[1], "zip", sys.argv[2])' \
			build/release/pbookorbit-$$version-$$sdk "$$stage" || exit 1; \
		echo "build/release/pbookorbit-$$version-$$sdk.zip"; \
	done

# Build and run the tests in tests/; see Tests in docs/technical.md
test:
	$(PB) test .

# What the tests cover, as Markdown: each file's tests' names as sentences. Needs python3.
test-map:
	@python3 tests/map.py

# Render the icons built into the app (src/icons/*.bmp) from their SVG sources: the
# launcher tiles as 110x110 8-bit grey BMPs, the Era Color's theme icon size, and the
# header's offline badge in colour at dp(17) on the Era Color. Needs rsvg-convert and
# ImageMagick.
icons:
	for svg in src/icons/pbookorbit*.svg; do \
		rsvg-convert "$$svg" | magick - -colorspace Gray -type Palette -depth 8 -compress None "BMP3:$${svg%.svg}.bmp" || exit 1; \
	done
	rsvg-convert -w 37 -h 37 src/icons/offline.svg | magick - -background white -flatten -type TrueColor "BMP3:src/icons/offline.bmp"

# Shell in the build container
shell:
	$(PB) shell .

clean:
	$(PB) clean .
