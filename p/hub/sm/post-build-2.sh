#!/bin/bash
set -e

#fastbuild=1  # skip expensive optional steps during prototyping

[ $IVER = 3.10 ] && a310=1 && fastbuild=1  # alpine-3.10 can't imshrink

# no265 ffmpeg
cp -pv /mnt/apk/*.pub /etc/apk/keys/
lfetch_apks /mnt/apk/$IARCH/ffmpeg-*.apk
rm -rf /mnt/apk

PKGS=(
	alsa-utils aria2 cdparanoia chntpw ddrescue device-mapper
	dmraid entr gcompat git ipcalc irssi kbd-vlock
	lvm2 mtr nmap pingu py3-pillow ranger rpm2cpio rsync
	sox ttyd unionfs-fuse w3m xdelta3 xorriso
)
[ $a310 ] && PKGS+=(
	p7zip py3-zmq sc
) || PKGS+=(
	7zip helix hexyl nyancat par2cmdline
	py3-pyzmq sc-im time tmatrix treedude
	tty-solitaire fbida-fbi font-{droid,terminus}
)
recommended_apks "${PKGS[@]}"

(cd /mnt/apks/ && rm -f  */*-pyc-*  */*-pycache-* )



[ $fastbuild ] || {

imshrink_zinfo  # compress kernel symbols (makes kernel debugging harder)

# remove large kmods from initramfs, saves 3 MiB
imshrink_filter_irmods '' '' '
	/\/scsi\/(lpfc|qla[24]xxx|elx|fnic)\//{next}  # big fw: fibre channel scsi (qlogic, emulex)
	/\/firmware\/ql2[0-9]{3}_fw/{next}
	/\/(drivers|nvme)\/target\//{next}  # iscsi
    /\/nls_cp(932|936|949|950)/{next}  # cjk fat32
	/\/infiniband\//{next}
	/\/kernel\/sound\//{next}
	/\/(de4x5|dmfe|irdma|evbug|eth1394|i8xx-tco|via-ircc|snd-atiixp-modem|snd-intel8x0m|snd-via82xx-modem|snd-pcsp|hostap|hostap_cs|aty128fb|atyfb|radeonfb|i810fb|cirrusfb|intelfb|kyrofb|i2c-matroxfb|hgafb|nvidiafb|rivafb|savagefb|sstfb|neofb|tridentfb|tdfxfb|viafb|virgefb|vga16fb|matroxfb_base|vt8623fb|ohci1394|video1394|dv1394|hfcmulti|hfcpci|hfcsusb|e_powersaver|microcode|tiny_power_button)\.ko/{next}
'
# `-awk <i/etc/modprobe.d/blacklist.conf '/^blacklist /{printf"%s|",$2}'

# remove large useless kmods (but keep wifi and GPUs), saves 30 MiB
imshrink_filter_mods '' '' '
	/\/(rtl_bt|bluetooth|infiniband|hfi1)/{next}  # bt, infiniband
	/(raspberry|banana)pi|\.pine64/{next}  # arm sbc (normally covered by removing brcm)
	/\/firmware\/nvidia\//{next}  # nvidia gpus
	/\/(netronome)\//{next}  # agilio smartnics
	/\/(ueagle-atm)\//{next}  # adsl modems
	/\/(ocfs2)\//{next}  # filesystems
    /\/nls_cp(932|936|949|950)/{next}  # cjk fat32
    /\/scsi\/(lpfc|qla[24]xxx|elx|fnic)\//{next}  # big fw: fibre channel scsi (qlogic, emulex)
	/\/(de4x5|dmfe|irdma|evbug|eth1394|i8xx-tco|via-ircc|snd-atiixp-modem|snd-intel8x0m|snd-via82xx-modem|snd-pcsp|hostap|hostap_cs|aty128fb|atyfb|radeonfb|i810fb|cirrusfb|intelfb|kyrofb|i2c-matroxfb|hgafb|nvidiafb|rivafb|savagefb|sstfb|neofb|tridentfb|tdfxfb|viafb|virgefb|vga16fb|matroxfb_base|vt8623fb|ohci1394|video1394|dv1394|hfcmulti|hfcpci|hfcsusb|e_powersaver|microcode|tiny_power_button)\.ko/{next}
'

}



bootmenu_title
grub_chainload shell.efi
grub_fwsetup
grub_beep

rm -rf /mnt/sm/how2build

mkdir /mnt/.fseventsd
touch /mnt/.fseventsd/no_log /mnt/.metadata_never_index



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



[ $a310 ] && {
	rm -rf /mnt/efi /mnt/boot/grub* /mnt/chiptunes
	cat /dev/zero >/mnt/n || true; sync; rm /mnt/n
}



gensums sha1  # smoketest for corruption, not for security (even crc32 would be fine)
