# building from scratch

first ensure you have all the necessary files by copypasting the following into a shell inside `/p/hub`:

```bash
[ -e etc/profile.d/hub.sh ] || exit 1
mkdir -p kit/res boot efi/boot
dl() { [ -e $1 ] || wget -O $1 $2; }
dlf() { f=${2##*/}; [ -e $1/$f ] || wget -O $1/$f $2; }
dl /tmp/memtestu.zip        https://www.memtest.org/download/v7.20/mt86plus_7.20.binaries.zip
dl /tmp/memtestb.zip        https://www.memtest.org/download/v8.00/mt86plus_8.00.binaries.zip
dlf kit/                    https://github.com/9001/copyparty/releases/latest/download/copyparty-sfx.py
dlf kit/                    https://github.com/9001/copyparty/releases/latest/download/copyparty-en.pyz
dl kit/copyparty-git.zip    https://github.com/9001/copyparty/archive/refs/heads/hovudstraum.zip
dl kit/copyparty-help.html  https://github.com/9001/copyparty/releases/latest/download/helptext.html
dl kit/copyparty-help.txt   https://copyparty.eu/helptext.txt
dl kit/oneliners.html       https://ocv.me/doc/unix/oneliners/
dl kit/oneliners.sh         https://ocv.me/doc/unix/oneliners/nix.sh
dl kit/r0c.py               https://github.com/9001/r0c/releases/latest/download/bigr0c.py
dl kit/r0c-client.sh        https://github.com/9001/r0c/raw/refs/heads/master/clients/bash.sh
dl kit/r0c-client.ps1       https://github.com/9001/r0c/raw/refs/heads/master/clients/powershell.ps1
dlf kit/                    https://raw.githubusercontent.com/9001/smf/master/smf.py
dl kit/python3.zip          https://www.python.org/ftp/python/3.13.11/python-3.13.11-embed-amd64.zip
dlf kit/res/                https://raw.githubusercontent.com/9001/copyparty/refs/heads/hovudstraum/bin/hooks/usb-eject.js
dlf kit/res/                https://raw.githubusercontent.com/9001/copyparty/refs/heads/hovudstraum/bin/hooks/reject-ramdisk.py
dl sm/tls-cert.pem          https://raw.githubusercontent.com/9001/copyparty/refs/heads/hovudstraum/copyparty/res/insecure.pem
dl kit/wp.jpg               https://a.ocv.me/pub/g/wp/bliss-1200p-12-1-255-q90-420.jpg
dlf kit/                    https://a.ocv.me/pub/stuff/bin/9001-lxc.sfx  # https://github.com/9001/lxc
dlf kit/                    https://a.ocv.me/pub/ping.html
dlf sm/bin/                 https://github.com/9001/usr-local-bin/raw/refs/heads/master/allsmart
dlf sm/bin/                 https://github.com/9001/usr-local-bin/raw/refs/heads/master/bindiff
dlf sm/bin/                 https://github.com/9001/usr-local-bin/raw/refs/heads/master/hashtar
dlf sm/bin/                 https://github.com/9001/usr-local-bin/raw/refs/heads/master/hashwalk
dlf sm/bin/                 https://github.com/9001/usr-local-bin/raw/refs/heads/master/migratory
dlf sm/bin/                 https://github.com/9001/usr-local-bin/raw/refs/heads/master/revert
dlf sm/bin/                 https://github.com/9001/usr-local-bin/raw/refs/heads/master/timecmp
dlf efi/boot/               https://ocv.me/stuff/bin/shell.efi  # https://github.com/9001/lxc/tree/hovudstraum/uefi-shellbin
chmod 755 kit/{r0c,smf,copyparty-sfx}.py sm/bin/*
[ -e boot/memtst32 ] || { (cd /tmp && unzip memtestb.zip) && mv /tmp/mt86p_*_i586 boot/memtst32 && mv /tmp/mt86p_*_x86_64 boot/memtst64; }
[ -e efi/boot/memtest64.efi ] || { (cd /tmp && unzip memtestu.zip) && rm -f /tmp/*la64.efi && mv /tmp/memtest*.efi efi/boot/; }
[ -e chiptunes ] || { curl https://a.ocv.me/pub/demo/music/chiptunes/?tar | tar -xv; }
unzip -l kit/copyparty-git.zip | grep -q docs/changelog.md && zip -d kit/copyparty-git.zip copyparty-hovudstraum/docs/changelog.md
```

then see `local apk cache` in /doc/notes.md (or just remove the `-m http://192.168.122.1:2576/am` below) and finally build it:

```bash
av=3.23.2
./build.sh -p - -i dl/alpine-standard-$av-x86_64.iso  # just to ensure the iso is cached in dl/
function b() { ./build.sh -m http://192.168.122.1:2576/am -i dl/alpine-standard-$av-x86_64.iso -p hub; }  # sudo ./mod.sh -cs sha1; }
# or if you're building for ancient 32bit machines (non-SSE2 such as 1st-gen celeron)...
function b() { ./build.sh -m http://192.168.122.1:2576/am -i dl/alpine-standard-3.10.9-x86.iso -p hub; }
# and one of these to test:
virsh -c qemu:///system destroy live-bios; b && virsh -c qemu:///system start live-bios 
b && qemu-system-x86_64 -enable-kvm -vga qxl -cpu host -drive format=raw,file=asm.usb,bps=$((1024*1024*8)) -m 512
# and for quickly swapping out the faster-moving parts,
tar -c sm kit/res/ | sshpass -p k ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no root@192.168.123.253 'cd /media/vda1 && mount -o remount,rw . && (tar -xv;true) && reboot'
# release:
xz -cz1T0 <asm.usb >hub.usb.xz
```
