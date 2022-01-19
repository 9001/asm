# alpine-service-mode

write this to a usb flashdrive and [`./sm/asm.sh`](./sm/asm.sh) will be executed on bootup

good for fixing headless boxes or just general hardware wrangling


## what does it do

the example [`asm.sh`](./sm/asm.sh) shows a menu with some demo features:

* `1` shows a list of local HDDs and asks for a selection
  * maybe for entering a chroot or something
* `i` collects a bunch of hardware info and saves it to `sm/infos` on the flashdrive
* `n` starts networking and `sshd` after asking for `s`tatic or `d`ynamic IP
* `z` exits to a shell with `exit 0`
* `x` does an `exit 1` which also gives a shell but with `vim` and `tmux` preinstalled
* `k` shutdown
* `r` reboot

it plays the [pc98 bootup bleep](https://www.youtube.com/watch?v=9qof0qye1ao#t=6m28s) to let you know it's at the menu in case you don't have a monitor

* you can mute SFX by creating a file named `sm/quiet` on the flashdrive


# build it

if you are on linux,
* install qemu and run [`./build.sh`](./build.sh)
* you will get `asm.usb` which you can write to a usb flashdrive using [rufus](https://github.com/pbatard/rufus/releases/) or `cat asm.usb >/dev/sdi`
  * can additionally produce a hybrid ISO for burning to CD/DVD

alternatively, you may [build it manually](./manual-build.md) instead of using [`./build.sh`](./build.sh)


# how it works

the [Alpine ISO](https://alpinelinux.org/downloads/) comes with a tool ([setup-bootable](https://wiki.alpinelinux.org/wiki/Alpine_setup_scripts#setup-bootable)) which writes a copy of the ISO onto a USB flashdrive, except you can then modify the USB contents just like a normal flashdrive

> the flashdrive will be mounted read-only while inside the live-env, so yanking it at runtime is still perfectly safe -- to enable editing you have to `mount -o remount,rw /media/usb`

anyways, [`./build.sh`](./build.sh) does that and splices in some stuff from this repo:


## [`./sm/asm.sh`](./sm/asm.sh)

is the payload which does the cool stuff (this is probably what you want to modify)

the following environment variables are available;
* `$AR` = filesystem path to the usb, for example `/media/usb`
* `$AP` = the usb blockdevice with partition, for example `sda1`
* `$AD` = the usb blockdevice sans partition, for example `sda`

will be saved to the flashdrive at `/sm/asm.sh`
* can be modified at any time after building the image, either from inside the live-env or by accessing the flashdrive normally


## [`./etc`](./etc)

is the [apkovl](https://wiki.alpinelinux.org/wiki/Alpine_local_backup) which gets unpacked into `/etc` on boot

* contains the logic to make Alpine run `asm.sh` after it has booted
* will be placed at the root of the flashdrive as `the.apkovl.tar.gz` during installation
* can be modified inside the live-env using the `strapmod` command (load for editing) and `strapsave` (persist changes on flashdrive)


# compatibility

should work on most BIOS and UEFI boxes with a few exceptions;

1. BIOS boxes too ancient and buggy, requiring a proper hybrid-iso
  * **workaround:** use `-oi` to create a read-only hybrid iso

2. UEFI-only boxes which refuse to boot from MBR
  * **workaround:** modify the fdisk/sfdisk invocation to build a GPT-formatted flashdrive instead of MBR, killing BIOS support


# notes

* need to debug the alpine init? boot it like this to stream a verbose log out through the serial port: `lts console=ttyS0,115200,n8 debug_init=1`

* rapid prototyping with qemu:
  ```
  losetup -f --show ~ed/asm.raw
  mount /dev/loop0p1 /mnt/ && tar -czvf /mnt/the.apkovl.tar.gz etc && cp asm-example.sh /mnt/sm/asm.sh && umount /mnt && sync && qemu-system-x86_64 -hda ~ed/asm.raw -m 768 -accel kvm
  ```
