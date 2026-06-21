#!/bin/bash
set -e

#fastbuild=1  # skip expensive optional steps during prototyping

imshrink_filter_apks -w alpine-base openssl

PKGS=(
	device-mapper dmraid lvm2  # support LVM2
	bash coreutils util-linux iproute2-minimal
	openssh openssh-server python3 tmux
	btrfs-progs dosfstools e2fsprogs-extra ntfs-3g ntfs-3g-progs xfsprogs  # filesystems
	mimalloc2 mimalloc2-insecure  # optional speed hack
	py3-pillow  # to create thumbnails
)
fetch_apks "${PKGS[@]}"

(cd /mnt/apks/ && rm -f  */*-pyc-*  */*-pycache-* )



[ $fastbuild ] || {

imshrink_rmkinfo  # discard kernel symbols (makes kernel debugging harder)

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

# remove large useless kmods (but keep wifi and GPUs), saves a lot
imshrink_filter_mods '' '' '
	/\/(rtl_bt|bluetooth|infiniband|hfi1)/{next}  # bt, infiniband
    /\/(wireless|mac80211|brcmfmac|ti-connectivity)/{next}  # wifi
    /\/firmware\/(ath1[01]k|mediatek|iwlwifi|rtlwifi)/{next}  # wifi
    /\/(drivers\/multimedia|kernel\/drivers\/media)\//{next}  # capturecards, webcams
	/\/input\/(touchscreen|mouse)\//{next}
	/\/wacom|hid-(wiimote|playstation|nintendo)/{next}
	/\/kernel\/sound\//{next}
	/\/firmware\/cirrus\/cs35l/{next}  # big fw: sound/dsp
    /\/snd-soc-wm5102/{next}  # big fw: sound/dsp
	/(raspberry|banana)pi|\.pine64/{next}  # arm sbc (normally covered by removing brcm)
	/\/firmware\/nvidia\//{next}  # nvidia gpus
	/\/amdgpu/{next}  # amd gpus
	/\/(firmware|drm)\/xe\//{next}  # intel igpu (nextgen)
	/\/drivers\/accel\//{next}  # ML/LLM junk
	/\/amdnpu\//{next}  # ML/LLM junk
	/\/intel\/vpu\//{next}  # ML/LLM junk
	/\/intel\/ish\//{next}  # light-sensors, touch-input, low-power-sleep
	/\/(netronome)\//{next}  # agilio smartnics
	/\/ethernet\/(dec|sun)\//{next}  # old nics
	/\/(ueagle-atm)\//{next}  # adsl modems
	/\/(drivers|usb|net)\/atm\//{next}  # more adsl
	/\/drivers\/(isdn|nfc)\//{next}  # non-ethernet
    /\/fs\/(ceph|f2fs|gfs2|jfs|nfsd?|nilfs2|ntfs3?|ocfs2|reiserfs|smb|ubifs)\//{next}  # filesystems
    /\/fs\/(netfs|jffs2|orangefs|hfsplus)\//{next}  # more filesystems (smaller)
    /\/nls_cp(932|936|949|950)/{next}  # cjk fat32
	/\/dm-vdo\//{next}  # fancy blockdevs
	/\/block\/(rbd|nbd|floppy)\.ko/{next}  # more blockdevs
	/\/(drivers|nvme)\/target\//{next}  # iscsi
    /\/scsi\/(lpfc|qla[24]xxx|elx|fnic)\//{next}  # big fw: fibre channel scsi (qlogic, emulex)
    /\/net\/(netfilter|bridge|bonding|team|wireguard|sunrpc|sched|ceph)\//{next}  # fancy networking
    /\/net\/(sctp|tipc|rxrpc|openvswitch|ieee802154)\//{next}  # more networking
	/\/net\/(can|ppp|vxlan|arcnet|nfc)\//{next}  # more networking
	/\/updates(\/ACCOUNT|\/pknock)?\/xt_|\/netfilter\//{next}  # more netfilter
	/\/(x86\/kvm|drbd|rnbd|iscsi|firewire|speakup)\//{next}
	/\/(de4x5|dmfe|irdma|evbug|eth1394|i8xx-tco|via-ircc|snd-atiixp-modem|snd-intel8x0m|snd-via82xx-modem|snd-pcsp|hostap|hostap_cs|aty128fb|atyfb|radeonfb|i810fb|cirrusfb|intelfb|kyrofb|i2c-matroxfb|hgafb|nvidiafb|rivafb|savagefb|sstfb|neofb|tridentfb|tdfxfb|viafb|virgefb|vga16fb|matroxfb_base|vt8623fb|ohci1394|video1394|dv1394|hfcmulti|hfcpci|hfcsusb|e_powersaver|microcode|tiny_power_button)\.ko/{next}
'

}



bootmenu_title

rm -rf /mnt/sm/how2build
