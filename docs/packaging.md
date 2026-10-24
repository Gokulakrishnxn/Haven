# Building and releasing the Mac app

## Build a local app

From the repository root on macOS:

```sh
./scripts/build-app.sh
open .build/Haven.app
```

The script builds release versions of Haven and its three helper commands and assembles `.build/Haven.app`:

| Inside the app | What it is |
|---|---|
| `Contents/MacOS/Haven` | The app (a menu-bar app; `LSUIElement` means no Dock icon) |
| `Contents/MacOS/haven-vault`, `haven-mac`, `haven-browser` | The helper commands agents run for logins and approvals, Mac control and browser control. They sit next to the app, which is where Haven looks for them |
| `Contents/Resources/extension/` | The Chrome extension; Settings > Browser points people to this folder |
| `Contents/Resources/Haven.icns`, resource bundles | The Finder icon and SwiftPM resources |
| `Contents/Info.plist` | Version from the `VERSION` file, build number from the commit count, macOS 13 or later, and the Apple Events usage text that browser-tab context needs |

Options (environment variables, plus an optional output directory argument):

```sh
./scripts/build-app.sh "$HOME/Desktop/Haven Development"   # somewhere else; quote paths with spaces
HAVEN_ZIP=1 ./scripts/build-app.sh                          # also write Haven-<version>.zip
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build-app.sh
```

The output is always named `Haven.app`. Rebuilding keeps the previous app as `Haven.previous.<timestamp>.<pid>.app`, and the script refuses to replace unrelated apps or symlinks. Quit any running copy of Haven before opening a new build so two instances do not compete for the same shortcuts.

## Signing

By default the app and helpers get an **ad-hoc signature**. That gives the bundle a consistent identity on this Mac, but it is not a distributable signature: other Macs will warn that the developer cannot be verified, and macOS asks again for Accessibility and other permissions after each rebuild because the code identity changes.

With `SIGN_IDENTITY` set to a Developer ID Application certificate, the script signs with the hardened runtime and `scripts/Haven.entitlements` (which allows Apple Events for browser-tab context). **Notarization is not done by the script.** After signing, submit the zip with `xcrun notarytool submit --wait` and staple the ticket with `xcrun stapler staple Haven.app`; this needs an Apple Developer account and was not tried here.

## Versions and releases

- The version lives in the `VERSION` file at the repository root (for example `0.1.0`). Change it, commit, then tag `v0.1.0`.
- Pushing a tag like `v0.2.0` runs `.github/workflows/release.yml`: it checks the tag matches `VERSION`, runs the tests, builds the app, and attaches `Haven-0.2.0.zip` to a GitHub release. **This workflow has not been run yet.**
- `.github/workflows/ci.yml` builds and tests the app and builds the site on every pull request. Also not yet run on GitHub.

## Updates

Haven checks GitHub's "latest release" page once a day (and when you press **Check Now** in Settings > About). If a newer version exists, the About pane and the menu-bar panel say so and the link opens the release page. That is all it does:

- It sends no information about you or your Mac, only a standard request to `api.github.com` with a `Haven/<version>` user agent.
- It never downloads or installs anything. Replace the app by hand with the new zip.
- It can be switched off in Settings > About. Development builds run without an app bundle do not check.
- Drafts and pre-releases are ignored, and only `https://github.com/...` links are opened.

In-place updating (the Sparkle framework) is a possible next step. It needs a Developer ID signature, notarization and a hosted update feed, none of which exist yet, so it was left out rather than faked.
