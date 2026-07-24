# Troubleshooting

## papd accepts the job but nothing prints

**Symptom:** the Mac spools the job, papd logs `child N for "..."` then
`child N done`, but no CUPS job is created and no page comes out.

**Cause:** papd 4.2.3 (Debian 13) has a broken *native* CUPS submission path. If
you give it a bare CUPS queue name (`:pr=Brother_HLL2360D:`) it receives the PAP
job but silently discards it.

**Fix (already baked into `config/papd.conf.template`):** pipe the received
PostScript to `lp` instead —

```
Pi Brother L2360D:\
	:pr=|/usr/bin/lp -d Brother_HLL2360D -t AppleTalk:\
	:op=root:
```

> Do **not** add `:co=raw:`. A PCL-only printer can't interpret PostScript, so
> CUPS must run its PS→raster→brlaser filter chain.

### A note on testing with the local `pap` client
The netatalk `pap` command-line client (`pap -p "Name:LaserWriter@*" file.ps`)
does **not** send a proper PAP end-of-job, so papd discards the job and it looks
like the bridge is broken even when it isn't. **A real LaserWriter 8 Mac works
fine.** Trust the real Mac over the loopback `pap` client.

## Printer doesn't appear in the Mac's Chooser

1. **AppleTalk transport:** on the Mac, Control Panels → AppleTalk → *Connect
   via: Ethernet*, and AppleTalk Active in the Chooser.
2. **Is it registered on the Pi?**
   ```
   nbplkup | grep -i laserwriter      # expect: Name:LaserWriter  <net.node>
   systemctl is-active atalkd papd
   cat /proc/net/atalk/interface      # your interface must have an address
   ```
3. **Layer-2 bridging (Wi-Fi Pis):** AppleTalk/EtherTalk uses raw, non-IP
   Ethernet frames. If the Pi is on **Wi-Fi** and the Macs are on **wired**
   Ethernet, your router/AP must bridge those frames between the two. Most home
   routers do; some isolate Wi-Fi. If the printer never shows in the Chooser but
   `nbplkup` on the Pi is fine, this bridging is the usual culprit — put the Pi
   on the same wired segment as the Macs (a USB-Ethernet adapter if the Pi has
   no RJ45, e.g. a Pi 3 Model A+).

## `appletalk` module / `/proc/net/atalk` missing

Your kernel needs `CONFIG_ATALK`. On Raspberry Pi OS (kernel 6.18) it's a module
(`=m`) and loads on demand; `setup.sh` also forces it at boot via
`/etc/modules-load.d/appletalk.conf`. Verify:

```
zcat /proc/config.gz | grep ATALK        # expect CONFIG_ATALK=m (or =y)
modprobe appletalk && ls /proc/net/atalk
```

If `CONFIG_ATALK` is absent you'd need a kernel that includes it — but stock Pi
OS has it.

## Find the printer's IP / confirm it speaks port 9100

```
# from the Pi, sweep the subnet and probe 9100 (adjust the range):
for i in $(seq 1 254); do (ping -c1 -W1 192.168.1.$i >/dev/null 2>&1 &); done; sleep 5
for h in $(ip neigh | awk '/REACHABLE|STALE/{print $1}'); do
  timeout 1 bash -c "echo > /dev/tcp/$h/9100" 2>/dev/null && echo "$h has 9100 open"
done
# identify a Brother via PJL:
printf '\033%%-12345X@PJL INFO ID\r\n\033%%-12345X\r\n' | nc <printer-ip> 9100
```

## Print from the Pi to isolate CUPS from AppleTalk

```
lp -d Brother_HLL2360D /usr/share/cups/data/testprint
lpstat -W all -o Brother_HLL2360D
tail -f /var/log/cups/error_log
```

If this prints but AppleTalk doesn't, the problem is in papd/atalkd, not CUPS.

## Which brlaser PPD for my model?

```
lpinfo -m | grep -i brlaser
```
Put the matching `drv:///brlaser.drv/<model>.ppd` in `config.env` as
`PRINTER_PPD`.
