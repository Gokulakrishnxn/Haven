#!/bin/bash
# Build a local, unsigned Haven.app. Existing builds are preserved as backups.
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
swift build --configuration release --product Haven
bin_path="$(swift build --configuration release --product Haven --show-bin-path)"
if [[ ! -x "$bin_path/Haven" ]]; then
    printf 'Built executable not found: %s/Haven\n' "$bin_path" >&2
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
install -m 644 "$icon_path" "$staged_app/Contents/Resources/Haven.icns"

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
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$staged_app/Contents/Info.plist"
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

printf 'Built local app: %s\n' "$app_path"
if [[ -n "$backup_path" ]]; then printf 'Previous build preserved: %s\n' "$backup_path"; fi
printf 'Launch with: open "%s"\n' "$app_path"
