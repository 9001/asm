#!/bin/bash
set -e

#fastbuild=1  # skip expensive optional steps during prototyping

imshrink_filter_apks -w alpine-base openssl

PKGS=(
	device-mapper dmraid lvm2  # support LVM2
	bash coreutils util-linux iproute2-minimal
	openssh openssh-server python3 tmux
	btrfs-progs dosfstools e2fsprogs ntfs-3g ntfs-3g-progs xfsprogs  # filesystems
	mimalloc2 mimalloc2-insecure  # optional speed hack
	py3-pillow  # to create thumbnails
)
fetch_apks "${PKGS[@]}"

(cd /mnt/apks/ && rm -f  */*-pyc-*  */*-pycache-* )



[ $fastbuild ] || {

imshrink_zinfo  # compress kernel symbols (makes kernel debugging harder)

# remove large kmods from initramfs, saves 3 MiB
imshrink_filter_irmods \
	'/scsi/(lpfc|qla2xxx)/|/firmware/ql2[0-9]{3}_fw'

# remove large useless kmods (but keep wifi and GPUs), saves 30 MiB
imshrink_filter_mods '' '' '
	/\/(rtl_bt|bluetooth|infiniband|hfi1)/{next}  # bt, infiniband
    /\/(wireless|mac80211|brcmfmac|ti-connectivity)/{next}  # wifi
    /\/firmware\/(ath1[01]k|mediatek|iwlwifi|rtlwifi)/{next}  # wifi
    /\/(drivers\/multimedia|kernel\/drivers\/media)\//{next}  # capturecards, webcams
	/\/input\/(touchscreen|mouse)\//{next}
	/\/wacom|hid-(wiimote|playstation|nintendo)/{next}
	/\/kernel\/sound\//{next}
	/(raspberry|banana)pi|\.pine64/{next}  # arm sbc (normally covered by removing brcm)
	/\/firmware\/nvidia\//{next}  # nvidia gpus
	/\/amdgpu/{next}  # amd gpus
	/\/(netronome)\//{next}  # agilio smartnics
	/\/(ueagle-atm)\//{next}  # adsl modems
    /\/fs\/(ocfs2|smb|nfsd?|f2fs|ceph|gfs2|ubifs|reiserfs|nilfs2|ntfs3|jfs)\//{next}  # filesystems
    /\/fs\/(netfs|overlayfs|jffs2|orangefs|hfsplus)\//{next}  # more filesystems (smaller)
    /\/nls_cp(932|936|949|950)/{next}  # cjk fat32
    /\/(lpfc|qla[24]xxx)\//{next}  # big fw: fibre channel scsi (qlogic, emulex)
    /\/net\/(netfilter|bridge|bonding|team|wireguard|sunrpc|sched|ceph)\//{next}  # fancy networking
    /\/net\/(sctp|tipc|rxrpc|openvswitch|ieee802154)\//{next}  # more networking
	/\/updates(\/ACCOUNT|\/pknock)?\/xt_|\/netfilter\//{next}  # more netfilter
    /\/(x86\/kvm|drbd|rnbd|iscsi)\//{next}
'

}



bootmenu_title

rm -rf /mnt/sm/how2build
