# Building the Mac app

From the repository root on macOS, run:

```sh
./scripts/build-app.sh
open .build/Haven.app
```

The script builds the release executable with Swift Package Manager and creates
`.build/Haven.app`. Finder uses `brand/Haven.icns` as the app icon. The bundle also
contains the runtime SwiftPM resource bundles and an `Info.plist` declaring macOS
13 or later. Haven remains a menu bar app: `LSUIElement` is enabled, so launching
the bundle does not add a Dock icon.

To place the app in a different directory, pass that directory as the only
argument. Paths with spaces must be quoted:

```sh
./scripts/build-app.sh "$HOME/Desktop/Haven Development"
```

The output is always named `Haven.app`. Rebuilding preserves the previous app in
the same directory as `Haven.previous.<timestamp>.<process-id>.app`. The script
refuses to replace unrelated apps or symlinks and never deletes previous builds.
Quit any running copy of Haven before opening a new build; this avoids two menu
bar instances competing for the same keyboard shortcuts.

This is a local development bundle for the build machine's architecture. The
script does not perform Developer ID signing, notarization, installation, or
distribution. Swift may apply its normal linker signature to the executable;
the assembled app is not signed as a distributable application. A release
workflow should choose its bundle identifier and version, build the supported
architectures, then sign and notarize the finished bundle.

The icon is static in Finder. Logo animation belongs to Haven's running interface
and website; the menu bar uses the separate monochrome template mark so macOS can
adapt it to the menu bar appearance.
