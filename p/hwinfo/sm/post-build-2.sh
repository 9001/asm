#!/bin/bash
set -e

#fastbuild=1  # skip expensive optional steps during prototyping

echo $IVER | grep -qE '^3\.1[0-4]' && fastbuild=1  # can't imshrink



pkgs=(
    bash coreutils util-linux dosfstools
    acpica dmidecode libcpuid-tool lshw nvme-cli
      pciutils smartmontools usbutils
)
pkgs+=(python3)  # enable hw-info html generator; disable to save 8 MiB
excl=()
grep -E '^3\.1[0-6]\.' /etc/alpine-release && excl=(
    libcpuid-tool lm-sensors
)
[ $excl ] && {
    printf '%s\n' "${pkgs[@]}" >/dev/shm/plst
    for x in "${excl[@]}"; do
        sed -ri "/^$x$/d" /dev/shm/plst
    done
    readarray -t pkgs </dev/shm/plst
}
echo $IVER | grep -qE '^3\.1[0-2]' ||
    imshrink_filter_apks -w alpine-base openssl
fetch_apks "${pkgs[@]}"

(cd /mnt/apks/ && rm -f  */*-pyc-*  */*-pycache-* )



[ $fastbuild ] || {

imshrink_rmkinfo

# remove large kmods from initramfs
imshrink_filter_irmods '' '' '
	/\/scsi\/(lpfc|qla[24]xxx|elx|fnic)\//{next}  # big fw: fibre channel scsi (qlogic, emulex)
	/\/firmware\/ql2[0-9]{3}_fw/{next}
	/\/(drivers|nvme)\/target\//{next}  # iscsi
    /\/nls_cp(932|936|949|950)/{next}  # cjk fat32
	/\/infiniband\//{next}
	/\/(de4x5|dmfe|irdma|evbug|eth1394|i8xx-tco|via-ircc|snd-atiixp-modem|snd-intel8x0m|snd-via82xx-modem|snd-pcsp|hostap|hostap_cs|aty128fb|atyfb|radeonfb|i810fb|cirrusfb|intelfb|kyrofb|i2c-matroxfb|hgafb|nvidiafb|rivafb|savagefb|sstfb|neofb|tridentfb|tdfxfb|viafb|virgefb|vga16fb|matroxfb_base|vt8623fb|ohci1394|video1394|dv1394|hfcmulti|hfcpci|hfcsusb|e_powersaver|microcode|tiny_power_button)\.ko/{next}
'
# `-awk <i/etc/modprobe.d/blacklist.conf '/^blacklist /{printf"%s|",$2}'

# remove large useless kmods
imshrink_filter_mods '' '' '
	/\/(rtl_bt|bluetooth|infiniband|hfi1)/{next}  # bt, infiniband
    /\/(wireless|mac80211|brcmfmac|ti-connectivity)/{next}  # wifi
    /\/firmware\/(ath1[01]k|mediatek|iwlwifi|rtlwifi)/{next}  # wifi
    /\/(drivers\/multimedia|kernel\/drivers\/media)\//{next}  # capturecards, webcams
	/(raspberry|banana)pi|\.pine64/{next}  # arm sbc (normally covered by removing brcm)
	/\/firmware\/nvidia\//{next}  # nvidia gpus
	/\/amdgpu/{next}  # amd gpus
	/\/(netronome)\//{next}  # agilio smartnics
	/\/(ueagle-atm)\//{next}  # adsl modems
    /\/fs\/(ocfs2|xfs|btrfs|smb|nfsd?|f2fs|ceph|gfs2|ubifs|reiserfs|nilfs2|ntfs3|jfs)\//{next}  # filesystems
    /\/fs\/(fuse|netfs|jffs2|orangefs|hfsplus)\//{next}  # more filesystems (smaller)
    /\/nls_cp(932|936|949|950)/{next}  # cjk fat32
    /\/scsi\/(lpfc|qla[24]xxx|elx|fnic)\//{next}  # big fw: fibre channel scsi (qlogic, emulex)
    /\/net\/(netfilter|bridge|bonding|team|wireguard|sunrpc|sched|ceph)\//{next}  # fancy networking
    /\/net\/(sctp|tipc|ipv6|rxrpc|openvswitch|ieee802154)\//{next}  # more networking
    /\/(kernel\/drivers\/md)\//{next}  # raid etc
    /\/(x86\/kvm|drbd|rnbd|iscsi)\//{next}
'

}



bootmenu_title

#add_kargs nox2apic  # force xAPIC / x1APIC for hardware debugging

sed -ri 's/^(set timeout=).*/\14/' /mnt/boot/grub/grub.cfg 

[ $IARCH = x86 ] && rm -rf /mnt/efi /mnt/boot/grub*

true
