#!/bin/bash
set -e

# optimized-big;
# download+include some additional packages
# then remove some rarely useful kernel modules (drops wifi)
# and disable KMS when booting the final image

recommended_apks py3-requests ranger aria2
imshrink_zinfo  # smaller (makes kernel debugging harder)
imshrink_filter_irmods  # faster boot (skips modloop verification + some kmods)
imshrink_filter_mods
nomodeset
grub_beep

# replace 32bit grub with 64bit to support booting 32bit image on 64bit efi;
# requires a copy of 64bit grub efi which can be obtained with the following:
# ./utils/grub64.sh dl/alpine-extended-3.19.1-x86_64.iso p/obig/
#grub64

# enable dual-UKI/BIOS; bumps size from 151 to 174 MiB
# (this UKI is not tamper-proof, see /p/uki for a safe one)
#uki_make; sign_efi
