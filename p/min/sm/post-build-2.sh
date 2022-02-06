#!/bin/ash
set -e

# preconditions
zram
wrepo

# options
imshrink_nosig
imshrink_filter_mods
imshrink_filter_apks alpine-base  # openssl (necessary without nosig)

#nomodeset
