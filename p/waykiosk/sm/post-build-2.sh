#!/bin/bash
set -e

fetch_apks \
    firefox-esr dbus font-droid \
    seatd seatd-openrc cage bash socat \
    eudev eudev-openrc udev-init-scripts-openrc \
    wayland wayland-protocols xwayland \
    mesa-{,e}gl libdrm pciutils-libs \
    mesa-dri-gallium mesa-vulkan-{intel,swrast}
