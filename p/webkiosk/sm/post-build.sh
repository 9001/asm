#!/bin/bash

setup-interfaces -ar
sed -ri 's/"1fhr"/"c1fhr"/' /sbin/setup-apkrepos  # backport bugfix
(sed -r 's/^https/http/' | tee -a /etc/apk/repositories) <<EOF
$MIRROR/v$IVER/main
$MIRROR/v$IVER/community
EOF
apk update

cd /mnt/apks/*
ls -1 >.a

# from setup-xorg-base
apk fetch -R xorg-server xf86-input-libinput eudev mesa

# others
apk fetch -R firefox-esr \
    eudev-openrc udev-init-scripts-openrc \
    xf86-video-{fbdev,vesa} mesa-dri-{gallium,classic,intel} mesa-egl \
    ttf-dejavu xeyes xrandr xdotool socat
# acpi dbus mesa-{egl,gl,gles}

mkdir /mnt/sm/eapk
(ls -1; cat .a) | sort | uniq -c | awk '$1<2{print$2}' |
    while read -r x; do mv "$x" /mnt/sm/eapk/; done
rm .a
