#!/bin/ash
set -e

# support building from standard.iso in addition to extended.iso
ls /mnt/apks/*/pv-* ||
    fetch_apks util-linux pv

# faster boot
nomodeset
