#!/bin/sh
# Installer for the Omarchy "ASUS Fan" bar widget.
#
# Installs, as root:
#   /usr/local/bin/asus-fan-control-ec   the upstream EC fan tool (built from
#                                         source if not already present)
#   /usr/local/bin/omarchy-fanctl        the narrowly-scoped wrapper this
#                                         repository ships (helper/omarchy-fanctl)
#   /etc/sudoers.d/omarchy-fanctl        NOPASSWD for omarchy-fanctl, for the
#                                         desktop user only
#
# Usage:  sudo ./install.sh
#         sudo AFC_BINARY=/path/to/asus-fan-control-ec ./install.sh
#         sudo ./install.sh --no-build
#
# The widget itself is a shell plugin; install it separately with:
#   omarchy plugin add <this repo url> --enable
set -eu

UPSTREAM=https://github.com/Keyitdev/asus-fan-control-ec.git
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

ALLOW_BUILD=1
[ "${1:-}" = "--no-build" ] && ALLOW_BUILD=0

need_build_tools() {
  command -v git >/dev/null 2>&1 && command -v make >/dev/null 2>&1 &&
    { command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1; }
}

build_upstream() {
  need_build_tools || die "missing build tools (git/make/cc). Install them, or pass AFC_BINARY=/path/to/asus-fan-control-ec"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT INT TERM
  echo "Building asus-fan-control-ec from $UPSTREAM ..."
  git clone --depth 1 "$UPSTREAM" "$tmp/afc" >/dev/null 2>&1 || die "git clone failed"
  make -C "$tmp/afc" >/dev/null || die "build failed"
  install -Dm0755 "$tmp/afc/asus-fan-control-ec" "$BIN"
}

if [ -n "${AFC_BINARY:-}" ]; then
  [ -x "$AFC_BINARY" ] || die "AFC_BINARY is not executable: $AFC_BINARY"
  install -Dm0755 "$AFC_BINARY" "$BIN"
elif [ -x "$BIN" ]; then
  echo "Keeping existing $BIN"
elif [ "$ALLOW_BUILD" -eq 1 ]; then
  build_upstream
else
  die "$BIN not found and --no-build was given"
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
