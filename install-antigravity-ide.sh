#!/usr/bin/env bash

set -Eeuo pipefail

APP_NAME="Antigravity IDE"
INSTALL_DIR="/opt/antigravity-ide"
DOWNLOAD_DIR="$HOME/Downloads/antigravity-installer"
TARBALL="$DOWNLOAD_DIR/Antigravity-IDE-latest.tar.gz"
EXTRACT_DIR="$DOWNLOAD_DIR/extracted"
STAGE_DIR="$DOWNLOAD_DIR/staged"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/antigravity-ide.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
ICON_FILE="$ICON_DIR/antigravity-ide.svg"
LOCAL_BIN="$HOME/.local/bin"
CLI_LINK="$LOCAL_BIN/antigravity-ide"
RELEASE_PAGE="https://antigravity.google/releases?platform=linux"

PURGE_DATA=false
DOWNLOAD_URL=""


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
die() { error "$1"; exit 1; }

cleanup() { rm -rf -- "$EXTRACT_DIR" "$STAGE_DIR"; }

on_error() {
    local code=$?
    error "Installation failed with exit code $code."
    cleanup
    exit "$code"
}

trap on_error ERR
trap cleanup EXIT

show_help() {
    cat <<EOF
$APP_NAME - Clean Installer / Updater

Usage:
  $0
      Clean application update; user data is preserved.

  $0 --purge-data
      Clean update plus removal of common Antigravity user data.

  $0 --url "https://..."
      Supply the official .tar.gz URL without being prompted.

  $0 --purge-data --url "https://..."
      Full purge and install using the supplied URL.

  $0 --help
      Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge-data) PURGE_DATA=true; shift ;;
        --url)
            [[ $# -ge 2 ]] || die "--url requires a value."
            DOWNLOAD_URL="$2"
            shift 2
            ;;
        --help|-h) show_help; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ -f /etc/os-release ]] || die "Unable to determine operating system."
source /etc/os-release
info "Detected OS: ${PRETTY_NAME:-Unknown}"

if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *"debian"* ]]; then
    warning "This script is primarily intended for Ubuntu/Debian."
fi

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64) DOWNLOAD_ARCH="x86_64" ;;
    aarch64|arm64) DOWNLOAD_ARCH="arm64" ;;
    *) die "Unsupported architecture: $ARCH" ;;
esac
info "Architecture: $ARCH"

for command in curl tar sudo pgrep find sed grep sort awk; do
    command -v "$command" >/dev/null 2>&1 || die "Required command '$command' is not installed."
done
sudo -v || die "sudo privileges are required."

echo
echo "============================================================"
echo "       Antigravity IDE Clean Installer / Updater"
echo "============================================================"
echo
echo "Installation directory:"
echo "  $INSTALL_DIR"
echo
if [[ "$PURGE_DATA" == true ]]; then
    warning "FULL PURGE MODE ENABLED"
    echo "Common user data will be removed if present."
else
    echo "User data: PRESERVED"
fi
echo
read -rp "Continue? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

mkdir -p "$DOWNLOAD_DIR"
rm -rf -- "$EXTRACT_DIR" "$STAGE_DIR"
mkdir -p "$EXTRACT_DIR" "$STAGE_DIR"

if [[ -z "$DOWNLOAD_URL" ]]; then
    echo
    echo "Official Antigravity release page:"
    echo "  $RELEASE_PAGE"
    echo
    echo "Download the Linux ${DOWNLOAD_ARCH} .tar.gz package."
    echo
    read -rp "Paste the official .tar.gz URL: " DOWNLOAD_URL
fi

[[ -n "$DOWNLOAD_URL" ]] || die "No download URL supplied."
[[ "$DOWNLOAD_URL" == http://* || "$DOWNLOAD_URL" == https://* ]] || die "URL must start with http:// or https://"

if [[ "$DOWNLOAD_URL" != *".tar.gz"* ]]; then
    warning "URL does not contain '.tar.gz'."
    read -rp "Continue anyway? [y/N]: " CONTINUE
    [[ "$CONTINUE" =~ ^[Yy]$ ]] || exit 1
fi

info "Downloading Antigravity IDE..."
rm -f -- "$TARBALL"
curl --fail --location --show-error --progress-bar --retry 3 --retry-delay 2 \
    "$DOWNLOAD_URL" --output "$TARBALL"
[[ -s "$TARBALL" ]] || die "Downloaded archive is empty."
success "Download completed."

info "Validating archive..."
tar -tzf "$TARBALL" >/dev/null 2>&1 || die "Downloaded file is not a valid tar.gz archive."
COUNT="$(tar -tzf "$TARBALL" | wc -l | tr -d ' ')"
[[ "$COUNT" -ge 5 ]] || die "Archive appears suspiciously small."
success "Archive validated ($COUNT entries)."

info "Extracting archive..."
tar -xzf "$TARBALL" -C "$EXTRACT_DIR"
success "Archive extracted."

info "Locating Antigravity application..."
APP_SOURCE=""
while IFS= read -r executable; do
    [[ -n "$executable" ]] || continue
    case "$(basename "$executable")" in
        antigravity|Antigravity|antigravity-ide)
            APP_SOURCE="$(dirname "$executable")"
            break
            ;;
    esac
done < <(find "$EXTRACT_DIR" -type f \( -name "antigravity" -o -name "Antigravity" -o -name "antigravity-ide" \) -print 2>/dev/null)

if [[ -n "$APP_SOURCE" ]]; then
    CURRENT="$APP_SOURCE"
    for _ in 1 2 3 4 5; do
        if [[ -d "$CURRENT/resources/app" || -f "$CURRENT/chrome-sandbox" || -f "$CURRENT/product.json" ]]; then
            APP_SOURCE="$CURRENT"
            break
        fi
        PARENT="$(dirname "$CURRENT")"
        [[ "$PARENT" != "$CURRENT" ]] || break
        CURRENT="$PARENT"
    done
fi

if [[ -z "$APP_SOURCE" ]]; then
    mapfile -t TOP_LEVEL_DIRS < <(find "$EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d -print)
    [[ "${#TOP_LEVEL_DIRS[@]}" -eq 1 ]] && APP_SOURCE="${TOP_LEVEL_DIRS[0]}"
fi

[[ -n "$APP_SOURCE" && -d "$APP_SOURCE" ]] || die "Could not locate Antigravity application."

info "Application source: $APP_SOURCE"

EXPECTED_ICON="$APP_SOURCE/resources/app/out/vs/platform/browserOnboarding/static/antigravity.svg"
[[ -f "$EXPECTED_ICON" ]] || warning "Expected Antigravity SVG was not found in the archive."

info "Preparing staged installation..."
rm -rf -- "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp -a "$APP_SOURCE"/. "$STAGE_DIR"/

info "Checking for running Antigravity processes..."
PIDS=""
if [[ -d "$INSTALL_DIR" ]]; then
    PIDS="$(pgrep -f "^${INSTALL_DIR}/" 2>/dev/null || true)"
fi

for pattern in \
    "$HOME/Applications/antigravity" \
    "$HOME/Applications/Antigravity" \
    "$HOME/Applications/Antigravity IDE" \
    "$HOME/.local/opt/antigravity" \
    "$HOME/.local/opt/antigravity-ide"
do
    if [[ -e "$pattern" ]]; then
        FOUND="$(pgrep -f "^${pattern}/" 2>/dev/null || true)"
        [[ -n "$FOUND" ]] && PIDS="$PIDS"$'\n'"$FOUND"
    fi
done

PIDS="$(printf '%s\n' "$PIDS" | sed '/^[[:space:]]*$/d' | sort -u)"

if [[ -n "$PIDS" ]]; then
    info "Stopping Antigravity..."
    while read -r PID; do [[ -n "$PID" ]] && kill "$PID" 2>/dev/null || true; done <<< "$PIDS"
    sleep 3
    while read -r PID; do
        [[ -n "$PID" ]] || continue
        if kill -0 "$PID" 2>/dev/null; then
            warning "Forcing process $PID to stop."
            kill -9 "$PID" 2>/dev/null || true
        fi
    done <<< "$PIDS"
    success "Antigravity stopped."
else
    success "Antigravity is not running."
fi

BACKUP_DIR=""
if [[ -d "$INSTALL_DIR" ]]; then
    BACKUP_DIR="${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    info "Moving old installation to temporary backup."
    sudo mv -- "$INSTALL_DIR" "$BACKUP_DIR"
fi

info "Installing staged application..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp -a "$STAGE_DIR"/. "$INSTALL_DIR"/
sudo chmod -R a+rX "$INSTALL_DIR"

SANDBOX="$INSTALL_DIR/chrome-sandbox"
if [[ -f "$SANDBOX" ]]; then
    info "Configuring Electron/Chromium sandbox..."
    sudo chown root:root "$SANDBOX"
    sudo chmod 4755 "$SANDBOX"
    OWNER="$(stat -c '%U:%G' "$SANDBOX")"
    MODE="$(stat -c '%a' "$SANDBOX")"
    [[ "$OWNER" == "root:root" && "$MODE" == "4755" ]] || die "chrome-sandbox verification failed: $OWNER $MODE"
    success "Chrome/Electron sandbox configured: $OWNER $MODE"
else
    warning "chrome-sandbox was not found."
fi

IDE_EXECUTABLE=""
for candidate in \
    "$INSTALL_DIR/antigravity-ide" \
    "$INSTALL_DIR/antigravity" \
    "$INSTALL_DIR/Antigravity" \
    "$INSTALL_DIR/bin/antigravity-ide"
do
    if [[ -f "$candidate" ]]; then IDE_EXECUTABLE="$candidate"; break; fi
done

if [[ -z "$IDE_EXECUTABLE" ]]; then
    IDE_EXECUTABLE="$(find "$INSTALL_DIR" -type f \( -name "antigravity-ide" -o -name "antigravity" -o -name "Antigravity" \) -print -quit 2>/dev/null || true)"
fi
[[ -n "$IDE_EXECUTABLE" ]] || die "Installed Antigravity executable could not be found."
sudo chmod +x "$IDE_EXECUTABLE"
success "Executable verified: $IDE_EXECUTABLE"

mkdir -p "$LOCAL_BIN"
rm -f -- "$CLI_LINK"
ln -s "$IDE_EXECUTABLE" "$CLI_LINK"

INSTALLED_ICON="$INSTALL_DIR/resources/app/out/vs/platform/browserOnboarding/static/antigravity.svg"
if [[ -f "$INSTALLED_ICON" ]]; then
    info "Installing official Antigravity icon..."
    mkdir -p "$ICON_DIR"
    cp -f -- "$INSTALLED_ICON" "$ICON_FILE"
    success "Icon installed: $ICON_FILE"
else
    warning "Official Antigravity SVG was not found; launcher will have no custom icon."
    rm -f -- "$ICON_FILE"
fi

info "Creating desktop launcher..."
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Antigravity IDE
Comment=AI-first development environment
Exec=$IDE_EXECUTABLE %F
Icon=antigravity-ide
Terminal=false
Type=Application
Categories=Development;IDE;
StartupNotify=true
MimeType=text/plain;inode/directory;
EOF
chmod +x "$DESKTOP_FILE"

if [[ "$PURGE_DATA" == true ]]; then
    info "Purging Antigravity user data..."
    DATA_PATHS=(
        "$HOME/.antigravity-ide"
        "$HOME/.config/Antigravity IDE"
        "$HOME/.cache/Antigravity IDE"
        "$HOME/.local/share/Antigravity IDE"
        "$HOME/.config/antigravity-ide"
        "$HOME/.cache/antigravity-ide"
        "$HOME/.local/share/antigravity-ide"
    )
    for path in "${DATA_PATHS[@]}"; do
        if [[ -e "$path" || -L "$path" ]]; then
            info "Removing: $path"
            rm -rf -- "$path"
        fi
    done
    success "Antigravity user data purged."
fi

command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null 2>&1 && \
    update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true

[[ -x "$IDE_EXECUTABLE" ]] || die "Final executable verification failed."
[[ -f "$DESKTOP_FILE" ]] || die "Desktop launcher verification failed."

if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]]; then
    info "Removing verified old-installation backup..."
    sudo rm -rf -- "$BACKUP_DIR"
fi

rm -f -- "$TARBALL"

if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    SHELL_RC=""
    [[ "${SHELL:-}" == */zsh ]] && SHELL_RC="$HOME/.zshrc"
    [[ "${SHELL:-}" == */bash ]] && SHELL_RC="$HOME/.bashrc"
    if [[ -n "$SHELL_RC" ]] && ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_RC"; then
        {
            echo
            echo '# Antigravity IDE CLI'
            echo 'export PATH="$HOME/.local/bin:$PATH"'
        } >> "$SHELL_RC"
        info "Added ~/.local/bin to $SHELL_RC."
    fi
fi

echo
echo "============================================================"
echo "              Installation Complete"
echo "============================================================"
echo
success "Antigravity IDE installed successfully."
echo
echo "Application:       $INSTALL_DIR"
echo "Executable:        $IDE_EXECUTABLE"
echo "CLI:                $CLI_LINK"
echo "Desktop launcher:  $DESKTOP_FILE"
echo "Icon:              $ICON_FILE"
echo
if [[ -f "$SANDBOX" ]]; then
    echo "Sandbox:           $(stat -c '%U:%G %a' "$SANDBOX")"
else
    echo "Sandbox:           NOT FOUND"
fi
echo
if [[ "$PURGE_DATA" == true ]]; then
    echo "Mode:              FULL PURGE + CLEAN INSTALL"
else
    echo "Mode:              CLEAN UPDATE; USER DATA PRESERVED"
fi
echo
echo "Start with:"
echo "  antigravity-ide"
echo
success "All installation checks completed."
