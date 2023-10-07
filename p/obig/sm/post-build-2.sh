#!/bin/bash
set -e

# optimized-big;
# download+include some additional packages
# then remove some rarely useful kernel modules (drops wifi)
# and disable KMS when booting the final image

recommended_apks py3-requests ranger aria2
imshrink_nosig  # faster boot (skips modloop verification)
imshrink_zinfo  # smaller (makes kernel debugging harder)
imshrink_filter_mods
nomodeset
grub_beep

# enable dual-UKI/BIOS; bumps size from 151 to 174 MiB
# (this UKI is not tamper-proof, see /p/uki for a safe one)
#uki_make; sign_efi
