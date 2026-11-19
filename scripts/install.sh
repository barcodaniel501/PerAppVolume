#!/usr/bin/env bash
# Installs (or updates) the latest PerAppVolume release into /Applications.
#
#   curl -fsSL https://raw.githubusercontent.com/<your-user>/PerAppVolume/main/scripts/install.sh | bash
#
# Options (environment variables):
#   PERAPPVOLUME_REPO=owner/repo   GitHub repository to download from
#   PERAPPVOLUME_NO_OPEN=1         install without opening the app
set -euo pipefail

REPO="${PERAPPVOLUME_REPO:-<your-user>/PerAppVolume}"
APP_NAME="PerAppVolume"
DEST="/Applications/$APP_NAME.app"

say()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[31mError: %s\033[0m\n' "$*" >&2; exit 1; }

# 1. Checks
[[ "$(uname -s)" == "Darwin" ]] || fail "PerAppVolume only runs on macOS."
[[ "$REPO" != *"<your-user>"* ]] || fail "Set the repository first: PERAPPVOLUME_REPO=owner/PerAppVolume"

version="$(sw_vers -productVersion)"
major="${version%%.*}"
minor="$(echo "$version" | cut -d. -f2)"
minor="${minor:-0}"
if (( major < 14 || (major == 14 && minor < 2) )); then
    fail "macOS 14.2 or newer is required (this Mac has $version)."
fi

# 2. Find the latest release zip
say "Looking for the latest release of $REPO"
url="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*\.zip"' \
    | head -n 1 \
    | sed -E 's/.*"(https[^"]+)"/\1/')" || true
[[ -n "${url:-}" ]] || fail "No release zip found at https://github.com/$REPO/releases"

# 3. Download and unzip
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
say "Downloading $(basename "$url")"
curl -fL --progress-bar -o "$tmp/app.zip" "$url"
ditto -x -k "$tmp/app.zip" "$tmp/unzipped"
[[ -d "$tmp/unzipped/$APP_NAME.app" ]] || fail "The zip doesn't contain $APP_NAME.app"

# 4. Install
if pgrep -x "$APP_NAME" >/dev/null; then
    say "Quitting the running $APP_NAME"
    osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
    sleep 2
fi
say "Installing to $DEST"
rm -rf "$DEST"
ditto "$tmp/unzipped/$APP_NAME.app" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

# 5. Open
if [[ "${PERAPPVOLUME_NO_OPEN:-0}" != "1" ]]; then
    say "Opening $APP_NAME"
    open "$DEST"
fi

cat <<'EOF'

PerAppVolume is installed. Look for the sliders icon in the menu bar.
The first time you change an app's volume, macOS asks for "System Audio Recording": click Allow.

PerAppVolume está instalada. Busca el ícono de controles en la barra de menú.
La primera vez que cambies el volumen de una app, macOS pedirá "Grabación de audio del sistema": haz clic en Permitir.
EOF
