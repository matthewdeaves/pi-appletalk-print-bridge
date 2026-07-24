# Classic Mac OS side

Once `setup.sh` has run and the printer shows up in `nbplkup` on the Pi, set up
each Mac. This was verified on a Power Mac 6400 (System 7.6.1) and applies
equally to System 7.5.3.

## Printer driver

Use **LaserWriter 8.4.x** (8.4.1 is fine; 8.4.2/8.4.3 are minor bug-fixes).

- **Avoid 8.5 / 8.5.1** — a buggy rewrite, and its PostScript 3 features buy you
  nothing here because Ghostscript on the Pi rasterises any PostScript level.
- **8.6 / 8.7 don't apply** — they need Mac OS 8.1+ / 8.5+ respectively.

### System 7.5.3 note
LaserWriter 8.4.x depends on **Desktop Printing**. System 7.5.3 includes it —
just make sure the *Desktop PrintMonitor* / *Desktop Printer* extensions are
enabled in the Extensions Manager.

## Steps

1. **Control Panels → AppleTalk** → *Connect via:* **Ethernet**. Make sure
   AppleTalk is active (the Chooser's AppleTalk radio button = Active).
2. **Apple menu → Chooser** → select **LaserWriter 8** in the left pane.
3. Your printer's `PAP_NAME` (e.g. **`Pi Brother L2360D`**) appears on the right.
   Select it → click **Create** (a.k.a. Setup).
4. LaserWriter 8 tries **Auto Setup** (it queries the printer for a PPD). If it
   can't determine one, click **Select PPD…** and choose a generic 600 dpi mono
   PostScript LaserWriter:
   - **LaserWriter Pro 630** — recommended (Level 2, 600 dpi, A4 + Letter)
   - **LaserWriter 16/600 PS** — equally good
   - plain **LaserWriter** — also works (Level 1, 300 dpi) if that's all you have
   - Avoid colour/specialised PPDs.

   > Why generic: the Brother isn't really a PostScript printer — papd is
   > impersonating a LaserWriter — so a model-specific PPD would advertise
   > features the virtual printer doesn't have. A generic PPD keeps the emitted
   > PostScript clean and standard.
5. Close the Chooser. A **desktop printer icon** appears.
6. Print from any app (SimpleText is a good first test).

## Paper size

Match the Pi's default (`PAPER` in `config.env`, e.g. A4). Set it per-document
in **File → Page Setup** on the Mac.

## Multiple Macs

Repeat on each machine. Same driver version and PPD choice everywhere keeps
things predictable.
