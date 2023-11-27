#!/bin/bash
set -e

fetch_apks \
    firefox-esr bash \
    xorg-server xf86-input-libinput eudev mesa \
    eudev-openrc udev-init-scripts-openrc \
    xf86-video-{fbdev,vesa,vmware} mesa-dri-gallium mesa-egl \
    pciutils-libs \
    ttf-dejavu xeyes xrandr xdotool socat hhpc

# acpi dbus mesa-{egl,gl,gles}
