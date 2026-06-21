#!/bin/ash
set -e

# preconditions
wrepo

# options
imshrink_rmkinfo
imshrink_filter_irmods '' '' '
    /\/scsi\/(mega|cxgb|bnx|lpfc|qla|elx|fnic|mpt|aic|pm|mpi|aac|be2|fco)/{next}
    /\/(chelsio|firmware)\/cxgb[34]\//{next}  # big fw: old 10gbit nic
    /\/firmware\/ql2[0-9]{3}_fw\.bin/{next}  # big fw: fibre channel scsi (qlogic)
    /\/infiniband\//{next}  # enterprise networking
	/\/(drivers|nvme)\/target\//{next}  # iscsi
    /\/nls_cp(932|936|949|950)/{next}  # cjk fat32
	/\/kernel\/sound\//{next}
    /\/gpu\/drm\//{next}  # modeset? pssh
	/\/(de4x5|dmfe|irdma|evbug|eth1394|i8xx-tco|via-ircc|snd-atiixp-modem|snd-intel8x0m|snd-via82xx-modem|snd-pcsp|hostap|hostap_cs|aty128fb|atyfb|radeonfb|i810fb|cirrusfb|intelfb|kyrofb|i2c-matroxfb|hgafb|nvidiafb|rivafb|savagefb|sstfb|neofb|tridentfb|tdfxfb|viafb|virgefb|vga16fb|matroxfb_base|vt8623fb|ohci1394|video1394|dv1394|hfcmulti|hfcpci|hfcsusb|e_powersaver|microcode|tiny_power_button)\.ko/{next}
'
# `-awk <i/etc/modprobe.d/blacklist.conf '/^blacklist /{printf"%s|",$2}'

imshrink_filter_mods \
    '/(modules/firmware|sound|net/(netfilter|bridge|bonding|team|ethernet|usb|dsa|can|ppp|fddi|arcnet|fjes|rxrpc)|infiniband|/amdgpu|gpu/drm|drivers/(accel|platform|iio|crypto|isdn|nfc|usb/serial)|input/touchscreen|staging|mei|hwmon|thunderbolt|firewire|sunrpc|cifs|drbd|ceph|ksmbd|mac80211)/|fs/(btrfs|f2fs|gfs2|jfs|nfsd?|nilfs2|ntfs3?|ocfs2|reiserfs|smb|ubifs|xfs)|/xt_|/nls_cp(932|936|949|950)|/scsi/(mega|cxgb|bnx|lpfc|qla|elx|fnic|mpt|aic|pm|mpi|aac|be2|fco)|/arch/x86(_64)?/kvm/|/(de4x5|dmfe|irdma|evbug|eth1394|i8xx-tco|via-ircc|snd-atiixp-modem|snd-intel8x0m|snd-via82xx-modem|snd-pcsp|hostap|hostap_cs|aty128fb|atyfb|radeonfb|i810fb|cirrusfb|intelfb|kyrofb|i2c-matroxfb|hgafb|nvidiafb|rivafb|savagefb|sstfb|neofb|tridentfb|tdfxfb|viafb|virgefb|vga16fb|matroxfb_base|vt8623fb|ohci1394|video1394|dv1394|hfcmulti|hfcpci|hfcsusb|e_powersaver|microcode|tiny_power_button)\.ko$' \
    'rtl_nic|tigon|intel/(igb|e1000)|ethernet/(realtek|amd/pcnet)|crypto/virtio'
    # hwmon is used by beefy NICs

nomodeset  # necessary for 3.23 virt, and due to removal of gpu/drm

# example for enabling alsa-beeper (remove the `|sound` above too, adds 6.5 MiB)
#fetch_apks tinyalsa
#imshrink_filter_apks -w alpine-base openssl tinyalsa

# but you probably don't want that so let's make it minimal instead
imshrink_filter_apks alpine-base openssl

#nomodeset
