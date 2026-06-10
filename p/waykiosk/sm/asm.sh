#!/bin/bash
# asm profile example @ https://github.com/9001/asm/blob/hovudstraum/p/waykiosk/sm/asm.sh
set -e

log downloading more ram
zram 2048

log setting up network and packages
dhcp &
sleep 0.1  # cosmetic
echo
pkgs=(
  eudev dbus font-droid
  seatd wayland wayland-protocols #xwayland
  mesa-{,e}gl libdrm pciutils-libs
  mesa-dri-gallium mesa-vulkan-{intel,swrast}
  cage firefox-esr socat
)
apka -q "${pkgs[@]}"
setup-devd udev
service dbus start
service seatd start
wait

# reverse-shell for debug:
#(while true; do socat exec:'/bin/bash -li',pty,stderr,setsid,sigint,sane tcp:192.168.122.1:4321,connect-timeout=1; sleep 1; done &)&

adduser -D u
adduser u seat
adduser u video

t=$(mktemp -d)
chmod 0700 $t
chown u:u $t

log starting graphics
su u -c /bin/bash <<EOF

export XDG_RUNTIME_DIR=$t
export WLR_RENDERER_ALLOW_SOFTWARE=1
export MOZ_ENABLE_WAYLAND=1
export MOZ_DBUS_REMOTE=1

dbus-run-session cage -d -- firefox-esr --kiosk >~/so 2>~/se \
  'https://ocv.me/life/#2/2c5-spaceship-gun-p690'

EOF
