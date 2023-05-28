#!/bin/ash
set -e

# hint for other options
export UKI=1

# preconditions
wrepo

# optional
imshrink_filter_mods  # saves ~50 MiB

# keep these last
uki_make 1  # secureboot + measured-boot; remove `1` to allow tty
uki_only    # remove bios support; saves 30 MiB