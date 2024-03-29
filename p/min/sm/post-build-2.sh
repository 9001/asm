#!/bin/ash
set -e

# preconditions
wrepo

# options
imshrink_nosig
imshrink_rmkinfo
imshrink_filter_mods \
    '/(modules/firmware|sound|net/(netfilter|bridge|bonding|team|ethernet|usb|dsa|can|ppp|fddi|arcnet|fjes)|infiniband|drivers/(gpu|platform|iio|crypto|isdn|nfc|usb/serial)|input/touchscreen|staging|mei|hwmon|thunderbolt|firewire|f2fs|btrfs|nfsd?|sunrpc|cifs|ceph|gfs2|ksmbd|reiserfs|mac80211)/|/xt_|/scsi/(mega|cxgb|bnx|lpfc|qla|elx|mpt|aic|pm|mpi|aac|be2|fco)' \
    'rtl_nic|tigon|intel/(igb|e1000)|ethernet/(realtek|amd)|crypto/virtio'
    # hwmon is used by beefy NICs

# example for enabling alsa-beeper (remove the `|sound` above too, adds 6.5 MiB)
#fetch_apks tinyalsa
#imshrink_filter_apks -w alpine-base openssl tinyalsa

# but you probably don't want that so let's make it minimal instead
imshrink_filter_apks alpine-base openssl

#nomodeset
