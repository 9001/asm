example profiles (config overlays) which replace corresponding files inside `sm` and `etc` with their own at build time

* usage example: `./build.sh -p uki`


# [`./uki/`](./uki/)

* suitable for secureboot as it does full integrity verification of all resources
  * should be impossible (but probably isn't) to get a shell


# [`./big/`](./big/)

* includes a bunch of convenient software for debugging
  * [`./obig/`](./obig/) is the same except smaller


# [`./hwinfo/`](./hwinfo/)

* produces a 107 MiB usb image for collecting hardware info
  * see `hw-inv.html` afterwards for a summary of all machines
  * build it: `./build.sh -i dl/alpine-standard-3.21.3-x86_64.iso -p hwinfo -s 0.5 && xz -cz1T0 <asm.usb >hwinfo.usb.xz`
  * this profile removes kernel modules to reduce image size; if you need all hardware initialized for more accurate infodumps (especially wifi/bluetooth), you'll want profile `big` or `hub` which also have this feature


# [`./r0cbox/`](./r0cbox/)

* adds a custom [`./sm/post-build.sh`](./sm/post-build.sh) to make [`../build.sh`](../build.sh) download and insert [`r0c.py`](https://github.com/9001/r0c/releases/latest/download/r0c.py) into the image, and
* replaces the default asm.sh (the bootscript) with [`./sm/asm.sh`](./sm/asm.sh) which:
  * sets up the first network interface with static ip `10.1.2.51`
  * sets up an sshd with root password `k`
  * launches the [r0c chat-server](https://github.com/9001/r0c/) on ports 23 (telnet) and 531 (netcat)

r0cbox hardware requirements:
* RAM: 128 MiB minimum, 192 MiB recommended
* CPU: yes preferably


# [`./hub/`](./hub/)

* impromptu [nas](https://github.com/9001/copyparty/) and [chatserver](https://github.com/9001/r0c) in a pinch
  * r0cbox but much better/bigger; includes misc. rescue-tools
* hotplug USB-storage to automatically share it on copyparty, and use the web-UI to unmount/eject
* download a prebuilt image (or the demo-video) from [my homeserver](https://a.ocv.me/pub/stuff/edcd001/enterprise-edition/) or see the [build instructions](./hub/sm/how2build)


# [`./miniparty/`](./miniparty/)

* tiny version of [`hub`](./hub/) which boots straight to copyparty and r0c with dhcp, no questions asked
* no thumbnails because it doesn't install pillow
* iso size is 117 MiB


# [`./dban/`](./dban/)

* the classic
* securely erase all detected harddrives by overwriting them with random data
  * no questions asked, it just GOES
  * also tries to blkdiscard for instant effect on SSD / NVMe drives
  * the "securely" part only applies to conventional magnetic drives (CMR), no guarantees for SMR / SSD / eMMC / NVMe
* logs output to USB and the first serial-port


# [`./webkiosk/`](./webkiosk/)

* opens firefox in kiosk-mode
* just a demo, not actually safe for deployment
  * will exit to an interactive shell if firefox crashes / exits
  * and by default there are other TTYs without password protection anyways
* 1 GiB or more RAM is recommended depending on website contents


# [`./waykiosk/`](./waykiosk/)

* opens firefox in kiosk-mode
* same as `webkiosk` above except this uses wayland, so more modern
  * and mouse/keyboard works, so pressing ctrl-q will exit to shell


# [`./min/`](./min/)

* produces a 24 MiB iso and/or gzipped usb image:
  ```
  ./build.sh -i dl/alpine-virt-3.19.1-x86.iso -oi asm.iso -p min -s 0.06
  ```
  * (non-virt i386 is 33 MiB due to hw drivers)


----

# notes

* symlinks in profiles are kept as-is, unless listed in a profile-toplevel file named `symlinks-to-deref.txt` (see the hwinfo profile)
