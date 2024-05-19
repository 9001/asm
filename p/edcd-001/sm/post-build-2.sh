#!/bin/bash
set -e

recommended_apks 7zip aria2 davfs2 ddrescue entr ffmpeg \
    gpm hexyl hfsfuse irssi mpv mtr nethack nmap \
    py3-{pillow,requests} ranger rsync rtorrent sox \
    tinyalsa treedude tty-solitaire unionfs-fuse w3m xorriso

(cd /mnt/apks/ && rm  */*-pyc-*  */*-pycache-* )

# build games
bdep_add .vidya gcc make pkgconf {ncurses,libc}-dev zstd
(cd /mnt/games && mv nbsdgames s && mkdir nbsd && cd s && make -j$(nproc) && make install GAMES_DIR=mnt/games/nbsd)
(cd /mnt/games && rm -rf s && tar -c nbsd | zstd -T0 -19 >nbsd.tzst && rm -rf nbsd)
(cd /mnt/games && gcc -o 2048 2048.c && rm 2048.c)
bdep_del .vidya

# tinyalsa got buggy in 3.18, build from src
bdep_add .talsa gcc make pkgconf libc-dev bash linux-headers doxygen graphviz
(mv /mnt/games/tinyalsa ~ && cd ~/tinyalsa && make)
bdep_del .talsa

(cd; rm -rf etc; tar -xf /mnt/the.apkovl.tar.gz
mv ~/tinyalsa/utils/tiny{cap,mix,pcminfo,play} etc/bin
tar -czf /mnt/the.apkovl.tar.gz etc; rm -rf etc)

imshrink_zinfo  # compress kernel symbols (makes kernel debugging harder)

# remove large kmods from initramfs, saves 3 MiB
imshrink_filter_irmods \
    '/scsi/(lpfc|qla2xxx)/|/firmware/ql2[0-9]{3}_fw|/(chelsio|firmware)/cxgb[34]/'

# remove large useless kmods (but keep wifi and GPUs), saves 30 MiB
imshrink_filter_mods '' '' '
    /\/(rtl_bt|bluetooth|infiniband|cxgb4|hfi1)/{next}  # bt, infiniband
    /(raspberry|banana)pi|\.pine64/{next}  # arm sbc (normally covered by removing brcm)
    /touchscreen/{next}
    /\/(netronome)\//{next}  # agilio smartnics
    /\/(ueagle-atm)\//{next}  # adsl modems
    /\/(ocfs2)\//{next}  # filesystems
    /\/(lpfc|qla2xxx)\//{next}  # big fw: fibre channel scsi (qlogic, emulex)
    /\/(cxgb[34])\//{next}  # big fw: old 10gbit nic
'

grub_beep
#grub64

for f in /mnt/boot/*/{grub,syslinux}.cfg; do sed -ri 's/Linux lts/EDCD-001/' $f; done
sed -ri 's/^(MENU AUTOBOOT ).*/\1- now booting EDCD-001 -/' /mnt/boot/*/syslinux.cfg


##
## add memtest86+

cat >>/mnt/boot/*/grub.cfg <<'EOF'
menuentry "memtest64 (x86_64)" {
linux /boot/memtst64
}
menuentry "memtest64 (x86_64) failsafe" {
linux /boot/memtst64 nosmp nosm nobench
}
menuentry "memtest32 (i686)" {
linux /boot/memtst32
}
menuentry "memtest32 (i686) failsafe" {
linux /boot/memtst32 nosmp nosm nobench
}
EOF

cat >>/mnt/boot/*/syslinux.cfg <<'EOF'

LABEL mt64
MENU LABEL memtest64 (x86_64)
LINUX /boot/memtst64

LABEL mt64s
MENU LABEL memtest64 (x86_64) failsafe
LINUX /boot/memtst64 nosmp nosm nobench

LABEL mt32
MENU LABEL memtest32 (i686)
LINUX /boot/memtst32

LABEL mt32s
MENU LABEL memtest32 (i686) failsafe
LINUX /boot/memtst32 nosmp nosm nobench
EOF

sed -ri 's/^(set timeout=).*/\14/' /mnt/boot/grub/grub.cfg 
