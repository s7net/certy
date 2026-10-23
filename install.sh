#!/usr/bin/env bash
# certy installer
#
#   curl -fsSL https://raw.githubusercontent.com/s7net/certy/main/install.sh | bash
#
# User mode (default, no root needed - e.g. cPanel with terminal access):
#   installs certy + a standalone certbot binary into ~/bin
# Root mode (--root):
#   installs certbot with the OS package manager and certy into /usr/local/bin
#
# Options: --user | --root | --repo OWNER/NAME | --version TAG
set -euo pipefail

REPO="${CERTY_REPO:-s7net/certy}"
VERSION="${CERTY_VERSION:-latest}"
MODE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --root) MODE=root ;;
    --user) MODE=user ;;
    --repo) REPO="$2"; shift ;;
    --version) VERSION="$2"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'
info() { echo "${C}==>${N} $*"; }
ok()   { echo "${G}✔${N} $*"; }
warn() { echo "${Y}!${N} $*"; }
die()  { echo "${R}✘ $*${N}" >&2; exit 1; }

# raw.githubusercontent.com caches branches for ~5 minutes; pin to the
# current commit so fresh pushes are picked up immediately.
REF="$(curl -fsSL "https://api.github.com/repos/$REPO/commits/main" 2>/dev/null |
  sed -n 's/^  "sha": "\([0-9a-f]\{40\}\)".*/\1/p' | head -n1)"
RAW="https://raw.githubusercontent.com/$REPO/${REF:-main}"
if [ "$VERSION" = latest ]; then
  REL="https://github.com/$REPO/releases/latest/download"
else
  REL="https://github.com/$REPO/releases/download/$VERSION"
  RAW="https://raw.githubusercontent.com/$REPO/$VERSION"
fi

fetch() { # url dest
  if command -v curl >/dev/null 2>&1; then curl -fsSL --retry 3 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"
  else die "curl or wget is required"; fi
}

# Same as fetch, with a progress bar showing the percentage.
fetch_progress() { # url dest
  if command -v curl >/dev/null 2>&1; then curl -fL --retry 3 --progress-bar -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -q --show-progress --progress=bar:force -O "$2" "$1" 2>&1
  else die "curl or wget is required"; fi
}

cat <<EOF
${C}                 _
   ___ ___ _ __| |_ _   _
  / __/ _ \\ '__| __| | | |
 | (_|  __/ |  | |_| |_| |
  \\___\\___|_|   \\__|\\__, |
                    |___/${N}  ${B}installer${N}

EOF

# Ask about root access when the user didn't say (works under curl | bash).
if [ -z "$MODE" ]; then
  MODE=user
  if [ "$(id -u)" = 0 ]; then
    MODE=root
  elif { : </dev/tty; } 2>/dev/null; then
    printf '%s\n' "Install mode:" "  1) User - into ~/bin, no root needed" "  2) System - certbot from the OS package manager (root)" >/dev/tty
    printf '%s' "Choose [1]: " >/dev/tty
    read -r ans </dev/tty || ans=""
    [ "$ans" = 2 ] && MODE=root
  fi
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/certy.XXXXXX" 2>/dev/null || { mkdir -p "$HOME/.certy/tmp"; mktemp -d "$HOME/.certy/tmp/inst.XXXXXX"; })"
trap 'rm -rf "$TMP"' EXIT

info "Downloading certy"
fetch "$RAW/certy" "$TMP/certy" || die "Could not download certy"
chmod +x "$TMP/certy"

# ------------------------------------------------------------------ root mode
install_root() {
  local SUDO=""
  if [ "$(id -u)" != 0 ]; then
    command -v sudo >/dev/null 2>&1 || die "Root mode needs to run as root or with sudo"
    SUDO=sudo
  fi
  if command -v certbot >/dev/null 2>&1; then
    ok "certbot already installed: $(certbot --version 2>&1)"
  else
    info "Installing certbot with the system package manager"
    if command -v apt-get >/dev/null 2>&1; then
      $SUDO apt-get update -y && $SUDO apt-get install -y certbot
    elif command -v dnf >/dev/null 2>&1; then
      $SUDO dnf install -y epel-release 2>/dev/null || true
      $SUDO dnf install -y certbot
    elif command -v yum >/dev/null 2>&1; then
      $SUDO yum install -y epel-release 2>/dev/null || true
      $SUDO yum install -y certbot
    elif command -v zypper >/dev/null 2>&1; then
      $SUDO zypper --non-interactive install certbot
    elif command -v apk >/dev/null 2>&1; then
      $SUDO apk add certbot
    elif command -v pacman >/dev/null 2>&1; then
      $SUDO pacman -Sy --noconfirm certbot
    elif command -v snap >/dev/null 2>&1; then
      $SUDO snap install --classic certbot && $SUDO ln -sf /snap/bin/certbot /usr/bin/certbot
    else
      die "No supported package manager found; re-run with --user"
    fi
  fi
  command -v certbot >/dev/null 2>&1 || die "certbot installation failed"
  $SUDO install -m 755 "$TMP/certy" /usr/local/bin/certy
  ok "certy installed to /usr/local/bin/certy"
}

# ------------------------------------------------------------------ user mode
install_venv() { # fallback when the prebuilt binary can't run here
  local py=""
  for c in python3.13 python3.12 python3.11 python3.10 python3.9 python3; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys,venv; sys.exit(sys.version_info < (3,9))' 2>/dev/null; then
      py="$c"; break
    fi
  done
  [ -n "$py" ] || return 1
  info "Building certbot in a Python virtualenv ($($py --version))"
  rm -rf "$CERTY_HOME/venv"
  "$py" -m venv "$CERTY_HOME/venv" &&
    "$CERTY_HOME/venv/bin/pip" install -q --upgrade pip &&
    "$CERTY_HOME/venv/bin/pip" install --progress-bar on -q certbot || return 1
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$CERTY_HOME/venv/bin/certbot" >"$BIN/certbot"
  chmod +x "$BIN/certbot"
}

install_user() {
  BIN="$HOME/bin"
  CERTY_HOME="$HOME/.certy"
  mkdir -p "$BIN" "$CERTY_HOME/tmp"

  local arch
  case "$(uname -m)" in
    x86_64|amd64) arch=x86_64 ;;
    aarch64|arm64) arch=aarch64 ;;
    *) arch="" ;;
  esac

  local got=0 tag=""
  if [ "$(uname -s)" = Linux ] && [ -n "$arch" ]; then
    # Skip the download when the installed binary is from the same release.
    if [ "$VERSION" = latest ]; then
      tag="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null |
        sed -n 's/^  "tag_name": "\([^"]*\)".*/\1/p' | head -n1)"
    else
      tag="$VERSION"
    fi
    if [ -n "$tag" ] && [ "$(cat "$CERTY_HOME/certbot/.release" 2>/dev/null)" = "$tag" ] &&
       TMPDIR="$CERTY_HOME/tmp" "$CERTY_HOME/certbot/certbot" --version >/dev/null 2>&1; then
      got=1
    else
      info "Downloading certbot (linux-$arch)"
      if fetch_progress "$REL/certbot-linux-$arch.tar.gz" "$TMP/certbot.tar.gz"; then
        rm -rf "$CERTY_HOME/certbot.new"
        mkdir -p "$CERTY_HOME/certbot.new"
        tar -xzf "$TMP/certbot.tar.gz" -C "$CERTY_HOME/certbot.new" --strip-components=1
        if TMPDIR="$CERTY_HOME/tmp" "$CERTY_HOME/certbot.new/certbot" --version >/dev/null 2>&1; then
          [ -n "$tag" ] && echo "$tag" >"$CERTY_HOME/certbot.new/.release"
          rm -rf "$CERTY_HOME/certbot"
          mv "$CERTY_HOME/certbot.new" "$CERTY_HOME/certbot"
          got=1
        else
          rm -rf "$CERTY_HOME/certbot.new"
          warn "Prebuilt binary doesn't run on this system"
        fi
      else
        warn "Could not download prebuilt certbot"
      fi
    fi
    if [ "$got" = 1 ]; then
      printf '#!/bin/sh\nexec "%s" "$@"\n' "$CERTY_HOME/certbot/certbot" >"$BIN/certbot"
      chmod +x "$BIN/certbot"
    fi
  fi
  if [ "$got" = 0 ]; then
    install_venv || die "Could not install certbot (no working binary and no Python >= 3.9)"
  fi
  install -m 755 "$TMP/certy" "$BIN/certy"
  ok "$("$BIN/certy" version 2>/dev/null | paste -sd' ' -) -> $BIN"

  case ":$PATH:" in
    *":$BIN:"*) ;;
    *)
      for rc in "$HOME/.bashrc" "$HOME/.bash_profile"; do
        [ -f "$rc" ] || continue
        grep -qs 'HOME/bin' "$rc" || echo 'export PATH="$HOME/bin:$PATH"' >>"$rc"
      done
      [ -f "$HOME/.bashrc" ] || [ -f "$HOME/.bash_profile" ] || echo 'export PATH="$HOME/bin:$PATH"' >>"$HOME/.bashrc"
      warn "Added ~/bin to PATH - open a new shell or run: export PATH=\"\$HOME/bin:\$PATH\""
      ;;
  esac
}

if [ "$MODE" = root ]; then install_root; else install_user; fi

echo
echo "${B}Done!${N} Run ${B}certy${N} to get started."
