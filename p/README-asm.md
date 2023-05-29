example profiles (config overlays) which replace corresponding files inside `sm` and `etc` with their own at build time

* usage example: `./build.sh -p uki`


# [`./uki/`](./uki/)

* suitable for secureboot as it does full integrity verification of all resources
  * should be impossible (but probably isn't) to get a shell


# [`./big/`](./big/)

* includes a bunch of convenient software for debugging
  * [`./obig/`](./obig/) is the same except smaller


# [`./r0cbox/`](./r0cbox/)

* adds a custom [`./sm/post-build.sh`](./sm/post-build.sh) to make [`../build.sh`](../build.sh) download and insert [`r0c.py`](https://github.com/9001/r0c/releases/latest/download/r0c.py) into the image, and
* replaces the default asm.sh (the bootscript) with [`./sm/asm.sh`](./sm/asm.sh) which:
  * sets up the first network interface with static ip `10.1.2.51`
  * sets up an sshd with root password `k`
  * launches the [r0c chat-server](https://github.com/9001/r0c/) on ports 23 (telnet) and 531 (netcat)

r0cbox hardware requirements:
* RAM: 128 MiB minimum, 192 MiB recommended
* CPU: yes preferably


# [`./dban/`](./dban/)

* the classic
* securely erase all detected harddrives by overwriting them with random data
  * no questions asked, it just GOES
  * also tries to blkdiscard for instant effect on SSD / NVMe drives
  * the "securely" part only applies to conventional magnetic drives (CMR), no guarantees for SMR / SSD / eMMC / NVMe


# [`./webkiosk/`](./webkiosk/)

* opens firefox in kiosk-mode
* just a demo, not actually safe for deployment
  * will exit to an interactive shell if firefox crashes / exits
  * and by default there are other TTYs without password protection anyways
* 1 GiB or more RAM is recommended depending on website contents


# [`./min/`](./min/)

* produces a 32 MiB iso, 27 MiB gzipped usb image:
  ```
  ./build.sh -i dl/alpine-virt-3.17.1-x86.iso -oi asm.iso -p min -s 0.06
  ```
  * (non-virt i386 is 68 / 63 MiB due to hw drivers)
