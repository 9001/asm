# alpine-service-mode

write this to a usb stick and [`asm.sh`](./asm.sh) will be executed on bootup

good for fixing headless boxes or just general hardware wrangling


## what does it do

the example [`asm.sh`](./asm.sh) shows a menu with some demo features:

* `1` shows a list of local HDDs and asks for a selection
  * maybe for entering a chroot or something
* `2` collects a bunch of hardware info and saves it to `sm/infos` on the flashdrive
* `z` exits to a shell with `exit 0`
* `x` does an `exit 1` which also gives a shell but with `vim` and `tmux` preinstalled
* `k` shutdown
* `r` reboot

it plays the [pc98 bootup bleep](https://www.youtube.com/watch?v=9qof0qye1ao#t=6m28s) to let you know it's at the menu in case you don't have a monitor

* you can mute SFX by creating a file named `sm/quiet` on the flashdrive


# how to build it

if you are on linux,
* install qemu and run [`./build.sh`](./build.sh)
* you will get `asm.usb` which you can write to a usb flashdrive using [rufus](https://github.com/pbatard/rufus/releases/) or `cat asm.usb >/dev/sdi`

alternatively, you may [build-manually.md](./build-manually.md) instead of using [`./build.sh`](./build.sh)


# how it works

the [Alpine ISO](https://alpinelinux.org/downloads/) comes with a tool ([setup-bootable](https://wiki.alpinelinux.org/wiki/Alpine_setup_scripts#setup-bootable)) which writes a copy of the ISO onto a USB flashdrive, except you can then modify the USB contents just like a normal flashdrive

> the flashdrive will be mounted read-only while inside the live-env, so yanking it at runtime is still perfectly safe -- to enable editing you have to `mount -o remount,rw /media/usb`

after running `setup-bootable` for the initial setup, we'll splice in some stuff from this repo:


## [`asm.sh`](./asm.sh)

is the payload which does the cool stuff (this is probably what you want to modify)

the following environment variables are available;
* `$AR` = filesystem path to the usb, for example `/media/usb`
* `$AP` = the usb blockdevice with partition, for example `sda1`
* `$AD` = the usb blockdevice sans partition, for example `sda`

will be saved to the flashdrive at `sm/asm.sh` during installation


## [`etc`](./etc)

is the [apkovl](https://wiki.alpinelinux.org/wiki/Alpine_local_backup) which gets unpacked into `/etc` on boot

contains the logic to make Alpine run `asm.sh` after it has booted

will be placed at the root of the flashdrive as `the.apkovl.tar.gz` during installation


# compatibility

should work on most BIOS and UEFI boxes with a few exceptions;
1. BIOS boxes too ancient and buggy, requiring a proper hybrid-iso
2. UEFI-only boxes which refuse to boot from MBR

for case 2 you could replace the "o" fdisk command with "g" which creates a GPT-formatted usb stick instead, killing BIOS support


# notes

* need to debug the alpine init? boot it like this to stream a verbose log out through the serial port: `lts console=ttyS0,115200,n8 debug_init=1`

* modify and repack the apkovl while inside the live-env:
  * `strapmod` unpacks it into ~/etc for modifications
  * `strapsave` stores it back onto the USB

  (or use the actual [`lbu`](https://wiki.alpinelinux.org/wiki/Alpine_local_backup) instead of my hacks)

* rapid prototyping with qemu:
  ```
  losetup -f --show ~ed/asm.raw
  mount /dev/loop0p1 /mnt/ && tar -czvf /mnt/the.apkovl.tar.gz etc && cp asm-example.sh /mnt/sm/asm.sh && umount /mnt && sync && qemu-system-x86_64 -hda ~ed/asm.raw -m 768 -accel kvm
  ```
