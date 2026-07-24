# pi-appletalk-print-bridge

Turn a Raspberry Pi into an **AppleTalk print bridge** so vintage Macs running
**classic Mac OS** (System 7.x, Mac OS 8/9) can print to a modern
**network laser printer** that only speaks PCL — no PostScript, no LocalTalk, no
serial hacks.

Built and verified with a **Brother HL-L2360D** (PCL6, port 9100) and two Power
Macs (**6200 / System 7.5.3** and **6400 / System 7.6.1**), on a Pi 3A+ running
**Raspberry Pi OS / Debian 13 (trixie)**.

```
 Classic Mac                          Raspberry Pi                       Printer
┌───────────────┐   AppleTalk/PAP   ┌───────────────────────────────┐  ┌────────┐
│ LaserWriter 8 │ ────────────────► │ papd ─► lp ─► CUPS ─► Ghostscript ─► │ Brother│
│ (PostScript)  │   (EtherTalk)     │             └► rastertobrlaser ──► socket:9100 │
└───────────────┘                   └───────────────────────────────┘  └────────┘
```

The Mac thinks it's talking to a genuine PostScript **LaserWriter**. papd hands
the PostScript to CUPS, **Ghostscript** rasterises it, and **brlaser** turns that
into the Brother's native language over a raw `socket://…:9100` connection.

## Why this exists / what's non-obvious

- **Debian 13 ships AppleTalk again.** Netatalk 3.x dropped AppleTalk/PAP, but
  Debian 13 packages the netatalk **4.2.x** AppleTalk suite (`atalkd`, `papd`,
  …) separately, and the stock Pi kernel (6.18) has DDP (`CONFIG_ATALK=m`). So
  you do **not** need to build old Netatalk 2.x from source.
- **papd 4.2.3's native CUPS submission is broken** — it takes the PAP job and
  silently drops it. The trick is to make papd **pipe the job to `lp`** instead.
  That single detail is the difference between "works" and "mysteriously prints
  nothing." (See [docs/troubleshooting.md](docs/troubleshooting.md).)
- **No `raw`** — the printer is PCL-only, so CUPS *must* do the PostScript→PCL
  conversion; a raw queue would send it PostScript it can't understand.
- **AppleTalk happily rode over the Pi's Wi-Fi** to a wired Mac (the router
  bridges EtherTalk frames), so a Pi with no Ethernet port still works — with a
  caveat, see troubleshooting.

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
[Netatalk](https://netatalk.io) project. Built with a lot of `strace`.

## License

MIT — see [LICENSE](LICENSE).
