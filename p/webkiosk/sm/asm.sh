#!/bin/bash
# asm profile example @ https://github.com/9001/asm/blob/hovudstraum/p/webkiosk/sm/asm.sh
set -e

log downloading more ram
zram 2048

log setting up network and packages
yes '' | setup-interfaces -r &
sleep 0.1  # cosmetic
echo
# vmware-3d needs pciutils-libs
apk add -q \
    xorg-server xf86-video-{fbdev,vesa,vmware} \
    mesa-dri-gallium mesa-{egl,gl} \
    pciutils-libs \
    ttf-dejavu xdotool eudev hhpc firefox-esr
setup-devd udev
wait

log starting firefox
cat >~/.xinitrc <<EOF
hhpc &
exec firefox-esr --kiosk 'https://ocv.me/life/#2/2c5-spaceship-gun-p690'
EOF

apk add socat
(while true; do socat exec:'/bin/bash -li',pty,stderr,setsid,sigint,sane tcp:192.168.122.1:4321,connect-timeout=1; sleep 1; done &)&

# and since there is no wm:
for a in $(seq 1 30); do
    sleep 0.5
    DISPLAY=:0.0 xdotool search --onlyvisible --name firefox windowsize 100% 100% || true
done &

# intentionally unsafe, drops to shell for debugging when firefox exits
xinit -- :0
