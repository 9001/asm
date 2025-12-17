# building from scratch

first ensure you have all the necessary files by copypasting the following into a shell inside `/p/miniparty`:

```bash
[ -e etc/profile.d/miniparty.sh ] || exit 1
mkdir -p kit
dl() { [ -e $1 ] || wget -O $1 $2; }
dlf() { f=${2##*/}; [ -e $1/$f ] || wget -O $1/$f $2; }
dlf kit/                    https://github.com/9001/copyparty/releases/latest/download/copyparty-sfx.py
dl kit/copyparty-help.html  https://github.com/9001/copyparty/releases/latest/download/helptext.html
dl kit/r0c.py               https://github.com/9001/r0c/releases/latest/download/bigr0c.py
dl kit/r0c-client.sh        https://github.com/9001/r0c/raw/refs/heads/master/clients/bash.sh
dl kit/r0c-client.ps1       https://github.com/9001/r0c/raw/refs/heads/master/clients/powershell.ps1
dl sm/tls-cert.pem          https://raw.githubusercontent.com/9001/copyparty/refs/heads/hovudstraum/copyparty/res/insecure.pem
dlf kit/                    https://a.ocv.me/pub/ping.html
chmod 755 kit/{r0c,copyparty-sfx}.py
```

then see `local apk cache` in /doc/notes.md (or just remove the `-m http://192.168.122.1:2576/am` below) and finally build it:

```bash
av=3.23.2
./build.sh -p - -i dl/alpine-standard-$av-x86_64.iso  # just to ensure the iso is cached in dl/
function b() { ./build.sh -m http://192.168.122.1:2576/am -i dl/alpine-standard-$av-x86_64.iso -oi miniparty.iso -p miniparty; }  # sudo ./mod.sh -cs sha1; }
# and test it:
b && qemu-system-x86_64 -enable-kvm -vga qxl -cpu host -cdrom miniparty.iso -m 512
# and for quickly swapping out the faster-moving parts,
tar -c sm kit/res/ | sshpass -p k ssh -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no root@192.168.123.253 'cd /media/vda1 && mount -o remount,rw . && (tar -xv;true) && reboot'
# release:
xz -cz1T0 <asm.usb >miniparty.usb.xz
```
