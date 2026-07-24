#!/usr/bin/env bash
#
# Raspberry Pi AppleTalk print bridge — one-shot, idempotent setup.
#
# Bridges a network-connected PCL/brlaser Brother laser printer to classic
# Mac OS over AppleTalk (PAP):
#
#   Mac (LaserWriter 8) -> AppleTalk/PAP -> papd -> lp -> CUPS
#     -> Ghostscript (PostScript->raster) -> rastertobrlaser -> printer
#
# Tested on: Raspberry Pi OS / Debian 13 (trixie), kernel 6.18, Pi 3A+ (arm64).
# Requires:  a kernel with AppleTalk DDP (CONFIG_ATALK=m) — present in Pi OS 6.18.
#
# Usage:
#   cp config.env.example config.env   # then edit config.env
#   ./setup.sh                         # re-run any time; it is idempotent
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${1:-$HERE/config.env}"
if [ ! -f "$CONF" ]; then
  echo "!! Missing $CONF" >&2
  echo "   Copy config.env.example to config.env and edit it first." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONF"

# Defaults for anything not set in config.env
: "${PRINTER_IP:?set PRINTER_IP in config.env}"
: "${PRINTER_PORT:=9100}"
: "${QUEUE_NAME:=Brother_HLL2360D}"
: "${PRINTER_PPD:=drv:///brlaser.drv/brl2360d.ppd}"
: "${PAPER:=A4}"
: "${PAP_NAME:=Pi Brother L2360D}"

# Re-exec as root, preserving the chosen config path.
if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E bash "$0" "$CONF"
fi

echo "==> Installing packages (cups, brlaser, atalkd, papd)"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y cups printer-driver-brlaser atalkd papd

echo "==> Ensuring the appletalk (DDP) kernel module loads at boot"
install -m 0644 "$HERE/config/appletalk.conf" /etc/modules-load.d/appletalk.conf
modprobe appletalk || true
if [ ! -e /proc/net/atalk/interface ]; then
  echo "!! WARNING: /proc/net/atalk is absent — this kernel may lack CONFIG_ATALK." >&2
  echo "   AppleTalk will not work without it. Check: zcat /proc/config.gz | grep ATALK" >&2
fi

echo "==> Creating / updating CUPS queue '$QUEUE_NAME' -> socket://$PRINTER_IP:$PRINTER_PORT"
lpadmin -p "$QUEUE_NAME" -E \
  -v "socket://$PRINTER_IP:$PRINTER_PORT" \
  -m "$PRINTER_PPD" \
  -D "$PAP_NAME (brlaser)" \
  -L "AppleTalk print bridge" \
  -o PageSize="$PAPER"
lpadmin -d "$QUEUE_NAME"
cupsenable "$QUEUE_NAME" 2>/dev/null || true
cupsaccept "$QUEUE_NAME" 2>/dev/null || true

echo "==> Writing /etc/netatalk/papd.conf"
mkdir -p /etc/netatalk
if [ -f /etc/netatalk/papd.conf ] && [ ! -f /etc/netatalk/papd.conf.orig ]; then
  cp /etc/netatalk/papd.conf /etc/netatalk/papd.conf.orig
fi
sed -e "s|@PAP_NAME@|$PAP_NAME|g" \
    -e "s|@QUEUE_NAME@|$QUEUE_NAME|g" \
    "$HERE/config/papd.conf.template" > /etc/netatalk/papd.conf

echo "==> Enabling services (atalkd, papd, cups) and disabling unneeded daemons"
systemctl enable --now cups atalkd papd
# These netatalk AppleTalk-suite daemons are pulled in as deps but not needed
# for printing; disable them to reduce noise/attack surface.
for s in a2boot timelord macipgw; do
  systemctl disable --now "$s" 2>/dev/null || true
done
systemctl restart papd

echo "==> Verifying"
sleep 3
lpstat -p "$QUEUE_NAME" -d || true
if nbplkup 2>/dev/null | grep -qi laserwriter; then
  echo "OK: printer is registered on AppleTalk:"
  nbplkup 2>/dev/null | grep -i laserwriter
else
  echo "NOTE: LaserWriter not in NBP yet — give atalkd ~30s, then: nbplkup | grep -i laserwriter"
fi

cat <<EOF

Done.

Test from the Pi itself (CUPS -> brlaser -> printer):
  lp -d $QUEUE_NAME /usr/share/cups/data/testprint

Then set up each classic Mac — see docs/mac-side.md.
Trouble? see docs/troubleshooting.md.
EOF
