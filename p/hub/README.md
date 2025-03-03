# hub

impromptu nas or chatserver in a pinch (with misc rescue-tools)

this is basically [edcd-001](https://github.com/9001/asm/tree/hovudstraum/p/edcd-001) with some important changes:

* made for flashdrives, not CDs
* not a museum artifact frozen in time
* still not related to [the other hub](https://www.pub-hub.com/index.php/aboutus)

core features:

* `copyparty` - fileserver with resumable uploads
  * removable media can be automounted and shared when connected
  * speaks http / https / webdav / ftp / tftp 
* `r0c` - telnet / netcat chatserver
* `sshd` - sftp fileserver / debug


## included software

activate these with `apk add <NAME>` unless listed as `+foo` then the command is `apk add cmd:foo`

* **chat:**      irssi, r0c
* **coding:**    bash, bc, entr, git, luajit, python3, sqlite, vim
* **disks:**     ddrescue, device-mapper, dmraid, lvm2, nbd, nbd-client, partclone, sgdisk, testdisk (undelete)
* **explore:**   mc, ranger, ncdu
* **fileinfo:**  diffutils, file, findutils, hexdump, hexyl, smf
* **filesys:**   btrfs-progs, cryptsetup, dosfstools, exfatprogs, fuse, fuse3, mtools, nbd, nbd-client, unionfs-fuse, ntfs-3g, ntfs-3g-progs, squashfs-tools, sshfs, xfsprogs
* **hw-diag:**   dmidecode, efibootmgr, efivar, libcpuid-tool, lm-sensors, lshw, mokutil, nvme-cli, pciutils, sbsigntool, smartmontools, usbutils
* **media:**     +fbi, ffmpeg, py3-pillow, sox
* **network:**   +ab, bmon, ethtool, iperf3, iproute2, iputils, mtr, nmap, nmap-ncat, proxychains-ng, socat, tcpdump, +telnet, ttyd
* **packers:**   7zip, brotli, bzip2, gzip, lzo, pigz, xz, zstd
* **perf:**      htop, procps-ng
* **textmod:**   coreutils, grep, jq, less, patch, xxd
* **xfer:**      aria2, copyparty, curl, rsync, (u2c)
* **misc:**      chntpw, gcompat, psmisc, pv, sshpass, strace, tar, tmux, util-linux, w3m, xorriso, xxhash


## copyparty

the [portable fileserver](https://github.com/9001/copyparty/)

* `/sm/copyparty.conf` = the config that gets executed
* `/kit/copyparty-help.html` = more config options
* list folders with `curl hub.local/sda1/`
* download folders with `curl hub.local/sda1/?tar | tar -xv`
* upload from CLI using [/.cpr/a/u2c.py](/.cpr/a/u2c.py)
  * direct-download link: [/.cpr/a/u2c.py](/.cpr/a/u2c.py?mime=application/octet-stream)
* the `sm` folder is unmapped/inaccessible (it has the tls-cert and `asm.sh` with passwords)

if you need to run this on windows, run `start-copyparty.bat` which will unzip `python.zip` and launch the server

* edit the bat-file and keep adding more `-v` as necessary 


## r0c

the [telnet chatserver](https://github.com/9001/r0c), but you can also connect to a r0c-server at `10.1.2.51` using bash and only bash itself:

```bash
exec 97<>/dev/tcp/10.1.2.51/531;cat<&97&while IFS= read -rn1 x;do [ -z "$x" ]&&x=$'\n';printf %s "$x">&97;done
# if you need to disconnect, run this:
exec 97<&-; killall cat
```

optionally also available on http-port 823, https-port 423 using `sm/tls-cert.pem` (default is the copyparty-insecure cert)


# configuring

all of these are optional, and all of them can be done after building the image (if you don't mind the checksum-verifier complaining about the changes)

* change the sshd password near the top of `/sm/asm.sh`, specifically `pw=k`
* set a password on copyparty; bottom 4 lines of `/sm/copyparty.conf`
* change the https certificate by replacing `/sm/tls-cert.pem`
* disable multicast spam in `/sm/copyparty.conf` by removing the line that mentions stealth-mode


# SBOM

* https://www.memtest.org/
* https://github.com/9001/copyparty
* https://github.com/9001/r0c
* https://a.ocv.me/pub/demo/music/chiptunes/compressed/
* plus all the packages included from the alpine repos

