🎊 !! CONGRATULATIONS !! 🥳 you are the lucky🍀 owner of the first🌟 (and probably last⚠️) physical edition💿🔥 of copyparty💾🎉 as one of the twenty👀 copies distributed at an2024 🎷🚚💿🎚🎛🎚💿🇨🇦🇨🇦🔥🔥🔥

or maybe you're reading this on the asm github repo, in which case you could just [build and burn some copies yourself](sm/how2build) but that'd be cheating 😤

anyways, in the folder [./edware/](./edware/) you'll find portable copies of copyparty and r0c which you can run on any device that speaks python, but you get the ～ＦＵＬＬ ＥＸＰＥＲＩＥＮＣＥ～ by rebooting your pc with this CD inserted


# edcd-001 users manual


## useful commands

| command           | what it does |
| ----------------- | ------------ |
| `menu`            | launch the menu again if you quit it |
| `a`               | reopen the tmux session |
| `mc` , `ranger`   | cool file explorers |
| `w3m ocv.me`      | browse the web... in text... |
| `sfnt` , `sfnt 2` | small fonts for small screens |
| `bfnt`            | huge font |
| `rot` 0/1/2/3     | rotate screen |
| `xmas`            | pretty lights |

* `setup-ntp -n busybox`


## included software

activate these with `apk add <NAME>`

* **chat:**      irssi, r0c
* **coding:**    bash, bc, entr, luajit, python3, sqlite, vim
* **disks:**     ddrescue, nbd, nbd-client, partclone, sgdisk, testdisk (undelete)
* **explore:**   mc, ranger, ncdu
* **fileinfo:**  diffutils, file, findutils, hexdump, hexyl, smf
* **filesys:**   btrfs-progs, cryptsetup, davfs2, dosfstools, exfatprogs, fuse, fuse3, hfsfuse, mtools, nbd, nbd-client, unionfs-fuse, ntfs-3g, ntfs-3g-progs, squashfs-tools, sshfs, xfsprogs
* **games:**     2048, nbsd (21-in-1), nethack, solitaire, treedude
* **hw-diag:**   dmidecode, efibootmgr, efivar, libcpuid-tool, lm-sensors, lshw, mokutil, nvme-cli, pciutils, sbsigntool, smartmontools, usbutils
* **media:**     ffmpeg, mpv, py3-pillow, sox
* **network:**   bmon, ethtool, inetutils-telnet, iperf3, iproute2, iputils, mtr, nmap, nmap-ncat, proxychains-ng, socat, tcpdump
* **packers:**   7zip, bzip2, gzip, lzo, pigz, xz (without backdoor), zstd
* **perf:**      htop, procps-ng
* **textmod:**   coreutils, grep, jq, less, patch, xxd
* **xfer:**      aria2, copyparty, curl, py3-requests, rsync, rtorrent, u2c
* **misc:**      psmisc, pv, sshpass, strace, tar, tinyalsa, tmux, util-linux, w3m, xorriso, xxhash


## how to tmux

after launching copyparty or irc, you will be in tmux

press `ctrl-b` then release `ctrl` and press one of the following:

* a number (1/2/3) to switch windows
* `PgUp` to start scrolling (press `ESC` when done)
* `d` to detach and return to menu
* `n` to create a new window
* `t` to see a big clock
* `?` for more


# SBOM

opensource stuff on this cd, in no particular order:

* https://www.memtest.org/
* https://github.com/9001/copyparty
* https://github.com/9001/r0c
* https://github.com/abakh/nbsdgames
* https://github.com/mevdschee/2048.c
* https://a.ocv.me/pub/demo/music/chiptunes/compressed/
* plus all the packages included from the alpine repos

