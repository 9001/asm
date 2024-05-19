# building edcd-001 from scratch

first ensure you have all the necessary files by copypasting the following into a shell inside `/p/edcd-001`:

```bash
[ -e etc/profile.d/edcd.sh ] || exit 1
mkdir -p edware boot games
dl() { [ -e $1 ] || wget -O $1 $2; }
dl /tmp/memtest.zip          https://www.memtest.org/download/v7.00/mt86plus_7.00.binaries.zip
dl lescue.webm               https://ocv.me/stuff/lescue/lescue.webm
dl edware/folder.png         https://ocv.me/edcd-001.png
dl edware/folder2.png        https://ocv.me/edcd-001-inlay.png
dl edware/copyparty-sfx.py   https://github.com/9001/copyparty/releases/latest/download/copyparty-sfx.py
dl edware/copyparty.pyz      https://github.com/9001/copyparty/releases/latest/download/copyparty.pyz
dl edware/copyparty.exe      https://github.com/9001/copyparty/releases/latest/download/copyparty.exe
dl edware/copyparty32.exe    https://github.com/9001/copyparty/releases/latest/download/copyparty32.exe
dl edware/u2c.exe            https://github.com/9001/copyparty/releases/download/v1.13.0/u2c.exe
dl edware/r0c.py             https://github.com/9001/r0c/releases/latest/download/bigr0c.py
dl edware/smf.py             https://raw.githubusercontent.com/9001/smf/master/smf.py
dl edware/python-3.11.9.zip  https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-win32.zip
chmod 755 edware/{r0c,copyparty-sfx}.py
[ -e boot/memtst32 ] || { (cd /tmp && unzip memtest.zip) && mv /tmp/memtest32.bin boot/memtst32 && mv /tmp/memtest64.bin boot/memtst64; }
[ -e games/nbsdgames ] || (cd games; git clone https://github.com/abakh/nbsdgames)
[ -e games/2048.c ] || ( cd games; wget https://raw.githubusercontent.com/mevdschee/2048.c/master/2048.c)
[ -e games/tinyalsa ] || ( cd games; git clone https://github.com/tinyalsa/tinyalsa)
gb() { [ -e $1.gb ] || (git clone https://github.com/9001/$1 t.r && cd t.r && git -c core.compression=9 repack -a -d -f -F --window=250 --depth=250 && git bundle create ../$1.gb --all); rm -rf t.r; }
(mkdir -p edware/src && cd edware/src && for v in copyparty r0c asm usr-local-bin partftpy softchat lxc party-up diodes defrost loopstream uptt ; do gb $v ; done)
[ -e chiptunes ] || { curl https://a.ocv.me/pub/demo/music/chiptunes/compressed/?tar | tar -xv; mv compressed chiptunes; }
find -printf '%TY%Tm%Td%TH%TM%TS %p\n' | awk '{t=int($1/2)*2;t1=int(t/100);t2=t%100;printf "%d.%02d %s\n",t1,t2,$2}' | while read t f; do touch -t $t "$f"; done  # brace for fat32 storing mtimes at mod2 seconds
PYTHONPATH=~/dev/copyparty python3 -m copyparty -v.:: -e2dsa -e2ts --dbd=acid --exit=idx --ign-ebind-all --no-idx "/etc/profile\.d/edcd\.sh$|/games/" -mtp=.bpm=f,t30,~/dev/copyparty/bin/mtag/audio-bpm.py -mtp=key=f,t30,~/dev/copyparty/bin/mtag/audio-key.py  # build tags index
PYTHONPATH=~/dev/copyparty python3 -m copyparty -v.::r:c,pngquant & pid=$!; for suf in p w; do curl -so/dev/null --retry 123 --retry-all-errors '127.0.0.1:3923/?tar&'$suf; done; kill $pid; wait  # and generate thumbnails
```

then see `local apk cache` in /doc/notes.md (or just remove the `-m http://192.168.122.1:3923/am` below) and finally build it:

```bash
./build.sh -p - -i dl/alpine-standard-3.19.1-x86_64.iso  # just to ensure the iso is cached in dl/
function b() { ./build.sh -m http://192.168.122.1:3923/am -i dl/alpine-standard-3.19.1-x86_64.iso -cb - -p edcd-001 -s 0.5 -oi /var/lib/libvirt/images/asm.iso; }
# and one of these to test:
b && (virsh destroy live-bios; virsh start live-bios) 
b && qemu-system-x86_64 -enable-kvm -vga qxl -cpu host -drive format=raw,media=cdrom,file=/var/lib/libvirt/images/asm.iso,bps=$((4*1024*1024)) -m 512
```

when everything looks good, make a pgo build of the iso (see asm main readme)
