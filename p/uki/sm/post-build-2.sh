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

# optional -- shaves 3 MiB (zinfo) + 106 MiB (filtermods; arg1=drop, arg2=keep)
imshrink_zinfo
imshrink_filter_mods \
    '/(modules/firmware|net/(ethernet|usb|dsa|can|ppp|fddi|arcnet|fjes)|infiniband|drivers/gpu|echoaudio|staging|mei|thunderbolt|firewire|f2fs|btrfs|nfsd?|sunrpc|cifs|ceph|gfs2|ksmbd|reiserfs|mac80211)/|/xt_|/scsi/(lpfc|qla|elx|mpt|aic|pm|mpi|aac|be2|fco)' \
    'bnx2|rtl_nic|tigon|intel/(i40e|ix?gb|e1000)|ethernet/(broadcom|realtek|amd)'

# optional -- unbundle some APKs
(cd /mnt/apks/*/ && rm -rf wpa_supp* ppp* iw-*)

# keep these last
uki_make $noshell  # secureboot + measured-boot
uki_only    # remove bios support; saves 30 MiB
sign_asm    # try to sign asm.sh  (build.sh -ak asm.key)
sign_efi    # try to sign the.efi (build.sh -ek db.key -ec db.crt)
