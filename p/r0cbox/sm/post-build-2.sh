#!/bin/ash
set -e

setup-interfaces -ar

# optional image shrinker, from 154 to 81 MiB 
shrink() {
    zram
    wrepo
    imshrink_nosig
    imshrink_filter_mods
    imshrink_filter_apks alpine-base openssh-server openssl
}

shrink
fetch_apks \
    alpine-base openssh-server openssl \
    python3 tmux

mkdir -p /mnt/sm/bin
cd /mnt/sm/bin

wget https://github.com/9001/r0c/releases/latest/download/r0c.py
