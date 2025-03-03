#!/bin/bash
set -e

#fastbuild=1  # skip expensive optional steps during prototyping

PKGS=(
    7zip alsa-utils aria2 chntpw ddrescue device-mapper dmraid entr ffmpeg
    gcompat git hexyl irssi lvm2 mtr nmap py3-pillow ranger rpm2cpio rsync
    sox treedude tty-solitaire ttyd unionfs-fuse w3m xorriso

    fbida-fbi font-{droid,terminus}
)
recommended_apks "${PKGS[@]}"

(cd /mnt/apks/ && rm  */*-pyc-*  */*-pycache-* )



[ $fastbuild ] || {

imshrink_zinfo  # compress kernel symbols (makes kernel debugging harder)

# remove large kmods from initramfs, saves 3 MiB
imshrink_filter_irmods \
    '/scsi/(lpfc|qla2xxx)/|/firmware/ql2[0-9]{3}_fw'

# remove large useless kmods (but keep wifi and GPUs), saves 30 MiB
imshrink_filter_mods '' '' '
    /\/(rtl_bt|bluetooth|infiniband|hfi1)/{next}  # bt, infiniband
    /(raspberry|banana)pi|\.pine64/{next}  # arm sbc (normally covered by removing brcm)
    /\/firmware\/nvidia\//{next}  # nvidia gpus
    /\/(netronome)\//{next}  # agilio smartnics
    /\/(ueagle-atm)\//{next}  # adsl modems
    /\/(ocfs2)\//{next}  # filesystems
    /\/(lpfc|qla2xxx)\//{next}  # big fw: fibre channel scsi (qlogic, emulex)
'

}



grub_beep
#grub64

rm -rf /mnt/sm/how2build



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

sed -ri 's/^(set timeout=).*/\13/' /mnt/boot/grub/grub.cfg 



gensums sha1  # smoketest for corruption, not for security (even crc32 would be fine)
