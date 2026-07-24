# pi-appletalk-print-bridge

Use a Raspberry Pi as an **AppleTalk print bridge** so machines running
**classic Mac OS** (System 7.x, Mac OS 8/9) can print to a **network laser
printer that only speaks PCL** (no PostScript).

Verified with a **Brother HL-L2360D** (PCL6, port 9100) and two Power Macs
(**6200 / System 7.5.3** and **6400 / System 7.6.1**), on a Pi 3A+ running
**Raspberry Pi OS / Debian 13 (trixie)**.

```
 Classic Mac                          Raspberry Pi                       Printer
┌───────────────┐   AppleTalk/PAP   ┌───────────────────────────────┐  ┌────────┐
│ LaserWriter 8 │ ────────────────► │ papd ─► lp ─► CUPS ─► Ghostscript ─► │ Brother│
│ (PostScript)  │   (EtherTalk)     │             └► rastertobrlaser ──► socket:9100 │
└───────────────┘                   └───────────────────────────────┘  └────────┘
```

To the Mac, the bridge presents as a PostScript **LaserWriter**. papd passes the
PostScript to CUPS, **Ghostscript** rasterises it, and **brlaser** converts that
to the printer's raster format, sent over a raw `socket://…:9100` connection.

## Notes and gotchas

- **No source build of Netatalk is needed.** Netatalk **3.x** removed AppleTalk
  support (AFP-over-TCP file sharing only), which is why older guides have you
  compile Netatalk **2.x** by hand. Netatalk **4.x** restored the AppleTalk
  daemons, and Debian 13 packages them as `atalkd` / `papd`. With the stock Pi
  kernel's DDP support (`CONFIG_ATALK=m` in 6.18), the stack installs from `apt`.
- **papd 4.2.3's native CUPS submission does not work** — it accepts the PAP job
  but never spools it. The working config pipes the job to `lp` instead
  (`:pr=|/usr/bin/lp -d <queue>:`). See
  [docs/troubleshooting.md](docs/troubleshooting.md).
- **The queue must not be `raw`.** The printer is PCL-only, so CUPS must do the
  PostScript→PCL conversion; a raw queue would forward PostScript it can't read.
- **AppleTalk works over Wi-Fi** if the router bridges EtherTalk (raw, non-IP
  Ethernet) frames between the wireless and wired segments, so a Pi with no
  Ethernet port can work. Some access points isolate Wi-Fi — see troubleshooting.

## Quick start

On the Pi (Raspberry Pi OS Lite / Debian 13, reachable over SSH):

```bash
git clone https://github.com/matthewdeaves/pi-appletalk-print-bridge.git
cd pi-appletalk-print-bridge
cp config.env.example config.env
nano config.env            # set PRINTER_IP, PRINTER_PPD, PAPER, PAP_NAME
./setup.sh                 # idempotent; re-run any time
```

Test from the Pi itself:

```bash
lp -d "$QUEUE_NAME" /usr/share/cups/data/testprint
nbplkup | grep -i laserwriter        # printer visible on AppleTalk
```

Then set up each Mac → [docs/mac-side.md](docs/mac-side.md).

## Requirements

- Raspberry Pi running **Raspberry Pi OS / Debian 13 (trixie)** or newer, kernel
  with **`CONFIG_ATALK`** (stock Pi OS 6.18 has it).
- A network laser printer supported by
  [`brlaser`](https://github.com/pdewacht/brlaser) that accepts raw **port 9100**
  (`lpinfo -m | grep -i brlaser` lists supported models/PPDs).
- The Pi and the Macs on the **same layer-2 network segment** (so EtherTalk
  frames reach both — see troubleshooting for Wi-Fi vs wired).
- On each Mac: **LaserWriter 8.4.x** and a generic PostScript PPD.

## What `setup.sh` does

1. Installs `cups`, `printer-driver-brlaser`, `atalkd`, `papd`.
2. Forces the `appletalk` kernel module at boot
   (`/etc/modules-load.d/appletalk.conf`).
3. Creates the CUPS queue → `socket://PRINTER_IP:9100` with your brlaser PPD.
4. Writes `/etc/netatalk/papd.conf` (pipe-to-`lp` form; backs up any original).
5. Enables `atalkd`/`papd`/`cups`; disables unneeded suite daemons
   (`a2boot`, `timelord`, `macipgw`).

Everything is boot-persistent. Roll it all back with **`./uninstall.sh`**.

## Files

| Path | Purpose |
|---|---|
| `setup.sh` | idempotent installer (reads `config.env`) |
| `uninstall.sh` | rollback |
| `config.env.example` | copy to `config.env` and edit |
| `config/papd.conf.template` | papd config (pipe-to-`lp`, no `raw`) |
| `config/appletalk.conf` | `modules-load.d` entry for DDP |
| `docs/mac-side.md` | classic Mac OS setup (LaserWriter 8) |
| `docs/troubleshooting.md` | the papd bug, EtherTalk-over-Wi-Fi, discovery, etc. |

## Credits

`brlaser` by Peter De Wachter. AppleTalk via the
[Netatalk](https://netatalk.io) project.

## License

MIT — see [LICENSE](LICENSE).
