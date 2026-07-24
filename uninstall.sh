#!/usr/bin/env bash
#
# Roll back the AppleTalk print bridge created by setup.sh.
# Does NOT purge packages by default (prints the command to do so).
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${1:-$HERE/config.env}"
# shellcheck disable=SC1090
[ -f "$CONF" ] && source "$CONF" || true
: "${QUEUE_NAME:=Brother_HLL2360D}"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" "$CONF"
fi

echo "==> Stopping/disabling atalkd + papd"
systemctl disable --now papd atalkd 2>/dev/null || true

echo "==> Removing CUPS queue '$QUEUE_NAME'"
lpadmin -x "$QUEUE_NAME" 2>/dev/null || true

echo "==> Removing config files"
rm -f /etc/modules-load.d/appletalk.conf
if [ -f /etc/netatalk/papd.conf.orig ]; then
  mv -f /etc/netatalk/papd.conf.orig /etc/netatalk/papd.conf
  echo "   restored /etc/netatalk/papd.conf from .orig"
else
  rm -f /etc/netatalk/papd.conf
fi

cat <<EOF

Rolled back the bridge.

To also remove the packages:
  sudo apt-get remove --purge printer-driver-brlaser papd atalkd

(CUPS was left installed. The appletalk kernel module will simply stop being
loaded at boot now that /etc/modules-load.d/appletalk.conf is gone.)
EOF
