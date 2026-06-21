#!/bin/ash
set -e

# shell-access at runtime is blocked by default;
# running build.sh with `-v nosec=1` negates that
[ $nosec ] && noshell= || noshell=1

# hint for other options
export UKI=1

# preconditions
wrepo

# optional
# note: `util-linux` adds 2 MiB and is unnecessary except for muting some harmless yet scary-looking warnings on startup
fetch_apks mokutil efitools util-linux  # autoinstall secureboot certs into uefi
nomodeset  # faster boot

# optional -- shaves 3 MiB (zinfo) + 110 MiB (filtermods; arg1=drop, arg2=keep)
imshrink_zinfo
imshrink_filter_mods \
    '/(modules/firmware|sound|net/(netfilter|bridge|bonding|team|ethernet|usb|dsa|can|ppp|fddi|arcnet|fjes|rxrpc)|infiniband|drivers/(gpu|accel)|echoaudio|/snd-so[fc]-|staging|mei|thunderbolt|firewire|sunrpc|cifs|drbd|ceph|ksmbd|mac80211)/|fs/(btrfs|f2fs|gfs2|jfs|nfsd?|nilfs2|ntfs3?|ocfs2|reiserfs|smb|ubifs|xfs)|/xt_|/nls_cp(932|936|949|950)|/scsi/(lpfc|qla|elx|fnic|mpt|aic|pm|mpi|aac|be2|fco)|/arch/x86(_64)?/kvm/|/(de4x5|dmfe|irdma|evbug|eth1394|i8xx-tco|via-ircc|snd-atiixp-modem|snd-intel8x0m|snd-via82xx-modem|snd-pcsp|hostap|hostap_cs|aty128fb|atyfb|radeonfb|i810fb|cirrusfb|intelfb|kyrofb|i2c-matroxfb|hgafb|nvidiafb|rivafb|savagefb|sstfb|neofb|tridentfb|tdfxfb|viafb|virgefb|vga16fb|matroxfb_base|vt8623fb|ohci1394|video1394|dv1394|hfcmulti|hfcpci|hfcsusb|e_powersaver|microcode|tiny_power_button)\.ko$' \
    'bnx2|rtl_nic|tigon|intel/(i40e|ix?gb|e1000)|ethernet/(broadcom|realtek|amd/pcnet)'

# optional -- unbundle some APKs
(cd /mnt/apks/*/ && rm -rf wpa_supp* ppp* iw-*)

# keep these last
[ $IVER = 3.21 ] && {
f=gummiboot-efistub-48.1-r8.apk; wget $MIRROR/v3.20/main/$IARCH/$f; apk add $f; rm $f
}

uki_make $noshell  # secureboot + measured-boot
uki_only    # remove bios support; saves 30 MiB
sign_asm    # try to sign asm.sh  (build.sh -ak asm.key)
sign_efi    # try to sign the.efi (build.sh -ek db.key -ec db.crt)
