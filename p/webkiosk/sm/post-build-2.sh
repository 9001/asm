#!/bin/bash
set -e

setup-interfaces -ar
fetch_apks \
    firefox-esr \
    xorg-server xf86-input-libinput eudev mesa \
    eudev-openrc udev-init-scripts-openrc \
    xf86-video-{fbdev,vesa,vmware} mesa-dri-{gallium,classic,intel} mesa-egl \
    ttf-dejavu xeyes xrandr xdotool socat

# acpi dbus mesa-{egl,gl,gles}
