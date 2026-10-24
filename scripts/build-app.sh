#!/bin/bash
# Build a local Haven.app with its helper commands and the Chrome extension.
# Existing builds are preserved as backups.
#
# Environment:
#   SIGN_IDENTITY  Developer ID identity to sign with (hardened runtime). Default: ad-hoc signature.
#   HAVEN_ZIP=1    also write Haven-<version>.zip next to the app, ready to attach to a release.
set -euo pipefail

if [[ $# -gt 1 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    printf 'Usage: %s [output-directory]\n' "$0"
    printf 'Default output: <repository>/.build/Haven.app\n'
    if [[ $# -gt 1 ]]; then exit 1; fi
    exit 0
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
    printf 'Haven.app must be built on macOS.\n' >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
output_dir="${1:-$repo_root/.build}"
case "$output_dir" in
    /*) ;;
    *) output_dir="$PWD/$output_dir" ;;
esac

icon_path="$repo_root/brand/Haven.icns"
if [[ ! -f "$icon_path" ]]; then
    printf 'App icon missing: %s\n' "$icon_path" >&2
    exit 1
fi

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd -P)"
app_path="$output_dir/Haven.app"
bundle_id="com.haven.app"

# Only replace a bundle made by this script. Never replace a symlink or an
# unrelated application, even when a custom output directory is supplied.
if [[ -L "$app_path" ]]; then
    printf 'Refusing to replace a symlink: %s\n' "$app_path" >&2
    exit 1
fi
if [[ -e "$app_path" ]]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Contents/Info.plist" 2>/dev/null || true)"
    if [[ ! -f "$app_path/.haven-local-build" || "$existing_id" != "$bundle_id" ]]; then
        printf 'An unrelated item already exists at %s. Choose another output directory.\n' "$app_path" >&2
        exit 1
    fi
fi

cd "$repo_root"
version="$(tr -d '[:space:]' < "$repo_root/VERSION")"
if [[ ! "$version" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
    printf 'VERSION must look like 1.2.3 (found "%s").\n' "$version" >&2
    exit 1
fi
build_number="$(git -C "$repo_root" rev-list --count HEAD 2>/dev/null || echo 1)"

# The app and the helper commands agents run (they live next to the app's executable).
helpers=(haven-vault haven-mac haven-browser)
for product in Haven "${helpers[@]}"; do
    swift build --configuration release --product "$product"
done
bin_path="$(swift build --configuration release --product Haven --show-bin-path)"
for product in Haven "${helpers[@]}"; do
    if [[ ! -x "$bin_path/$product" ]]; then
        printf 'Built executable not found: %s/%s\n' "$bin_path" "$product" >&2
        exit 1
    fi
done

extension_dir="$repo_root/extension"
if [[ ! -f "$extension_dir/manifest.json" ]]; then
    printf 'Chrome extension missing: %s\n' "$extension_dir" >&2
    exit 1
fi

staging_root="$(mktemp -d "$output_dir/.haven-bundle.XXXXXX")"
cleanup_staging() {
    # Preserve partial output on failure for inspection; only remove an empty
    # temporary directory after a successful move.
    if [[ -d "$staging_root" ]]; then
        if ! rmdir "$staging_root" 2>/dev/null; then
            printf 'Build staging preserved at: %s\n' "$staging_root" >&2
        fi
    fi
}
trap cleanup_staging EXIT

staged_app="$staging_root/Haven.app"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources"
install -m 755 "$bin_path/Haven" "$staged_app/Contents/MacOS/Haven"
for helper in "${helpers[@]}"; do
    install -m 755 "$bin_path/$helper" "$staged_app/Contents/MacOS/$helper"
done
install -m 644 "$icon_path" "$staged_app/Contents/Resources/Haven.icns"
# The extension folder the Settings > Browser pane points people to.
/usr/bin/ditto "$extension_dir" "$staged_app/Contents/Resources/extension"

# SwiftPM's generated Bundle.module accessor searches the app's Resources.
# Ignore cached test bundles; they are not part of the application.
shopt -s nullglob
for resource_bundle in "$bin_path"/*.bundle; do
    resource_name="$(basename "$resource_bundle")"
    case "$resource_name" in
        *Tests.bundle) continue ;;
    esac
    /usr/bin/ditto "$resource_bundle" "$staged_app/Contents/Resources/$resource_name"
done

cat > "$staged_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Haven</string>
    <key>CFBundleDisplayName</key><string>Haven</string>
    <key>CFBundleIdentifier</key><string>com.haven.app</string>
    <key>CFBundleExecutable</key><string>Haven</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>Haven</string>
    <key>CFBundleShortVersionString</key><string>0.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>NSAppleEventsUsageDescription</key><string>Haven reads the address and title of your active browser tab so you can attach it to a task.</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$staged_app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$staged_app/Contents/Info.plist"
/usr/bin/plutil -lint "$staged_app/Contents/Info.plist"

# Sign helpers first, then the app. Without SIGN_IDENTITY this is an ad-hoc signature: enough for a stable
# identity on this Mac, not for distribution. With a Developer ID identity the hardened runtime is used.
identity="${SIGN_IDENTITY:--}"
sign_args=(--force --sign "$identity")
if [[ "$identity" != "-" ]]; then
    sign_args+=(--options runtime --timestamp)
fi
for helper in "${helpers[@]}"; do
    /usr/bin/codesign "${sign_args[@]}" --identifier "com.haven.$helper" "$staged_app/Contents/MacOS/$helper"
done
/usr/bin/codesign "${sign_args[@]}" --entitlements "$repo_root/scripts/Haven.entitlements" --identifier "$bundle_id" "$staged_app"
/usr/bin/codesign --verify --deep --strict "$staged_app"
printf 'Created by scripts/build-app.sh\n' > "$staged_app/.haven-local-build"

backup_path=""
if [[ -e "$app_path" ]]; then
    backup_path="$output_dir/Haven.previous.$(date -u '+%Y%m%dT%H%M%SZ').$$.app"
    if [[ -e "$backup_path" ]]; then
        printf 'Backup path already exists: %s\n' "$backup_path" >&2
        exit 1
    fi
    mv "$app_path" "$backup_path"
fi
if ! mv "$staged_app" "$app_path"; then
    if [[ -n "$backup_path" ]]; then mv "$backup_path" "$app_path"; fi
    exit 1
fi

printf 'Built Haven %s (build %s): %s\n' "$version" "$build_number" "$app_path"
if [[ "${HAVEN_ZIP:-}" == "1" ]]; then
    zip_path="$output_dir/Haven-$version.zip"
    rm -f "$zip_path"
    /usr/bin/ditto -c -k --keepParent "$app_path" "$zip_path"
    printf 'Release archive: %s\n' "$zip_path"
fi
if [[ -n "$backup_path" ]]; then printf 'Previous build preserved: %s\n' "$backup_path"; fi
printf 'Launch with: open "%s"\n' "$app_path"
