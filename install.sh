#!/bin/sh
# Installer for the Omarchy "ASUS Fan" bar widget.
#
# Installs, as root:
#   /usr/local/bin/asus-fan-control-ec   the upstream EC fan tool (must already
#                                         be built: see below)
#   /usr/local/bin/omarchy-fanctl        the narrowly-scoped wrapper this
#                                         repository ships (helper/omarchy-fanctl)
#   /etc/sudoers.d/omarchy-fanctl        NOPASSWD for omarchy-fanctl, for the
#                                         desktop user only
#
# This script never downloads anything. Obtain asus-fan-control-ec first, either
# from the AUR (asus-fan-control-ec-git), by building it yourself, or by pointing
# at a prebuilt binary:
#
#   sudo ./install.sh                          # use an already installed binary
#   sudo AFC_BINARY=/path/to/asus-fan-control-ec ./install.sh
#   sudo AFC_SOURCE=/path/to/cloned/upstream ./install.sh   # build a local checkout
#
# The widget itself is a shell plugin; install it separately with:
#   omarchy plugin add <this repo url> --enable
set -eu

BIN=/usr/local/bin/asus-fan-control-ec
WRAPPER=/usr/local/bin/omarchy-fanctl
SUDOERS=/etc/sudoers.d/omarchy-fanctl

die() { echo "install.sh: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run with sudo: sudo ./install.sh"

SRC=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

[ -f "$SRC/helper/omarchy-fanctl" ] || die "helper/omarchy-fanctl not found next to install.sh"

USER_NAME=${SUDO_USER:-$(logname 2>/dev/null || true)}
[ -n "$USER_NAME" ] && [ "$USER_NAME" != root ] ||
  die "could not determine the desktop user; re-run with: sudo SUDO_USER=<name> ./install.sh"

build_local() { # build a local upstream checkout
  [ -d "$1" ] || die "AFC_SOURCE is not a directory: $1"
  command -v make >/dev/null 2>&1 || die "make is required to build from AFC_SOURCE"
  { command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1; } || die "a C compiler is required to build from AFC_SOURCE"
  make -C "$1" >/dev/null || die "build failed in $1"
  install -Dm0755 "$1/asus-fan-control-ec" "$BIN"
}

if [ -n "${AFC_BINARY:-}" ]; then
  [ -x "$AFC_BINARY" ] || die "AFC_BINARY is not executable: $AFC_BINARY"
  install -Dm0755 "$AFC_BINARY" "$BIN"
elif [ -x "$BIN" ]; then
  echo "Keeping existing $BIN"
elif [ -n "${AFC_SOURCE:-}" ]; then
  build_local "$AFC_SOURCE"
else
  die "asus-fan-control-ec is not installed.
Install it first (any of):
  * AUR:            asus-fan-control-ec-git
  * build upstream: git clone https://github.com/Keyitdev/asus-fan-control-ec.git
  * prebuilt:       sudo AFC_BINARY=/path/to/asus-fan-control-ec ./install.sh
  * local source:   sudo AFC_SOURCE=/path/to/cloned/upstream ./install.sh"
fi

install -Dm0755 "$SRC/helper/omarchy-fanctl" "$WRAPPER"

printf '%s ALL=(root) NOPASSWD: %s\n' "$USER_NAME" "$WRAPPER" > "$SUDOERS"
chown root:root "$SUDOERS"
chmod 0440 "$SUDOERS"
visudo -cf "$SUDOERS" || die "invalid sudoers file: $SUDOERS"

echo
echo "Installed:"
echo "  $BIN"
echo "  $WRAPPER"
echo "  $SUDOERS  (for user: $USER_NAME)"
echo
echo "Verify as $USER_NAME:"
echo "  sudo -n $WRAPPER status"
echo
echo "Install the widget:"
echo "  omarchy plugin add <this repo url> --enable"
