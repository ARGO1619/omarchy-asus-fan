#!/bin/sh
# Uninstaller for the Omarchy "ASUS Fan" bar widget.
#
# Removes:
#   /usr/local/bin/omarchy-fanctl
#   /etc/sudoers.d/omarchy-fanctl
#   /usr/local/bin/asus-fan-control-ec   (only with --purge)
#
# Usage:  sudo ./uninstall.sh
#         sudo ./uninstall.sh --purge
#
# The shell plugin itself is removed with:
#   omarchy plugin remove b5.fan
set -eu

BIN=/usr/local/bin/asus-fan-control-ec
WRAPPER=/usr/local/bin/omarchy-fanctl
SUDOERS=/etc/sudoers.d/omarchy-fanctl

die() { echo "uninstall.sh: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run with sudo: sudo ./uninstall.sh"

# Try to leave the fans under EC control before removing the wrapper.
[ -x "$WRAPPER" ] && "$WRAPPER" auto >/dev/null 2>&1 || true

rm -f "$SUDOERS" "$WRAPPER"

if [ "${1:-}" = "--purge" ]; then
  rm -f "$BIN"
  echo "Removed helper, sudoers rule and $BIN."
else
  echo "Removed helper and sudoers rule (kept $BIN; pass --purge to remove it)."
fi
