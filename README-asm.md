# alpine-service-mode

* write this to a usb flashdrive and [`./sm/asm.sh`](./sm/asm.sh) will be executed on bootup
* good for fixing headless boxes or just general hardware wrangling
* based on [Alpine Linux](https://alpinelinux.org/), runs anywhere
  * trivial: `i386/x86` // `x64` // `aarch64` // `ppc64le` // `s390x`
  * possible: `armhf` // `armv7`


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

see [profiles](./p/) for additional examples including a chatserver, a disk wiper and a webkiosk


# build it

if you are on linux,
* install qemu and run [`./build.sh`](./build.sh)
* you will get `asm.usb` which you can write to a usb flashdrive
  * can additionally produce a hybrid ISO for burning to CD/DVD with `-oi`

alternatively, you may [build it manually](./doc/manual-build.md) instead of using [`./build.sh`](./build.sh)


## write it to a flashdrive

* on linux, `cat asm.usb >/dev/sdi`
* on windows, either use [rufus](https://github.com/pbatard/rufus/releases/) or [USBimager (Recommended)](https://bztsrc.gitlab.io/usbimager/)
  * you want the `GDI wo` edition of USBimager -- the default choice when visiting that URL on windows
  * rufus v3.15 permanently unmounts the flashdrive when done, so run [rufus-unhide.bat](./doc/rufus-unhide.bat) afterwards
  * do not use balenaEtcher, it is spyware

**tip:** if the flashdrive is larger than the image, it is safe and recommended to add a "data" partition to the flashdrive after writing the image:
* on windows, use the win10 `Disk Management` utility, or better yet:
* on linux, `echo ,,07 | sfdisk -a /dev/sdi` (followed by `mkfs.ntfs -fL ASM2 /dev/sdi2` if there is no existing filesystem to keep)
  * linux-only bonus: you can write a new asm image onto the flashdrive without losing anything on the data partition, as long as the new build is the same size or smaller -- just need to issue the sfdisk command again
    * linux-only because windows is very persistent in blanking any filesystem headers it can find


## custom build steps

[`./sm/post-build.sh`](./sm/post-build.sh) is executed in the build-env right before the end

by default it does nothing but it provides a library of helpers / examples,
* an rshell for prototyping / debugging your extensions
* shrinking the output image
* adding more APKs


## [profiles](./p/)

if you are building several images with different contents (bootscripts, initramfs, ...) you can use the `-p` option to specify a [profile/overlay](./p/) which will replace corresponding files inside `sm` and `etc` at build-time


# how it works

the [Alpine ISO](https://alpinelinux.org/downloads/) comes with a tool ([setup-bootable](https://wiki.alpinelinux.org/wiki/Alpine_setup_scripts#setup-bootable)) which writes a copy of the ISO onto a USB flashdrive, except you can then modify the USB contents just like a normal flashdrive

> the flashdrive will be mounted read-only while inside the live-env, so yanking it at runtime is still perfectly safe -- to enable editing you have to `mount -o remount,rw $AR`

anyways, [`./build.sh`](./build.sh) does that and splices in some stuff from this repo:


## [`./sm/asm.sh`](./sm/asm.sh)

is the payload which does the cool stuff (this is probably what you want to modify)

the following environment variables are available;
* `$AR` = filesystem path to the usb, for example `/media/usb`
* `$AP` = the usb blockdevice and partition, for example `sda1`
* `$AD` = the usb blockdevice sans partition, for example `sda`
* `$AN` = profile name, or blank if built without `-p`

will be saved to the flashdrive at `/sm/asm.sh`
* can be modified at any time after building the image, either from inside the live-env or by accessing the flashdrive normally


## [`./etc`](./etc)

is the [apkovl](https://wiki.alpinelinux.org/wiki/Alpine_local_backup) which gets unpacked into `/etc` on boot

* contains the logic to make Alpine run `asm.sh` after it has booted
* will be placed at the root of the flashdrive as `the.apkovl.tar.gz` during installation
* can be modified inside the live-env using the `strapmod` command (load for editing) and `strapsave` (persist changes to flashdrive)


## how it all comes together

(or, what the alpine boot process looks like, kinda)

when booting a computer with the flashdrive inserted, all the usual alpine stuff happens:

* bios finds [grub](https://en.wikipedia.org/wiki/GNU_GRUB) on the flashdrive, either at `fs0:/efi/boot/bootx64.efi` (UEFI-boot) or in the [boot partition](https://en.wikipedia.org/wiki/BIOS_boot_partition) (BIOS/[CSM](https://en.wikipedia.org/wiki/Unified_Extensible_Firmware_Interface#CSM_booting)-boot)
  * or [el-torito](https://en.wikipedia.org/wiki/ISO_9660#El_Torito) when booting the ISO on a non-UEFI box

* grub reads `fs0:/boot/grub/grub.cfg`, loads `fs0:/boot/initramfs-lts` into memory, and boots `fs0:/boot/vmlinuz-lts`
  * (`fs0:` as in how UEFI refers to the USB flashdrive filesystem)

* linux runs [`/init`](https://github.com/alpinelinux/mkinitfs/blob/master/initramfs-init.in) from the initramfs

* initramfs-init does a bunch of stuff, then scans all removable devices for an [apkovl](https://wiki.alpinelinux.org/wiki/Alpine_local_backup) to unpack, finds `fs0:/the.apkovl.tar.gz` (which is [`./etc/`](./etc/) from this repo), and unpacks it into `/etc`

* initramfs-init continues the usual setup before doing a handover to [`/sbin/init`](https://github.com/mirror/busybox/blob/master/init/init.c)

* busybox-init reads [the asm edition of `/etc/inittab`](./etc/inittab) and runs [`/sbin/openrc`](https://wiki.gentoo.org/wiki/OpenRC) to launch the `sysinit` and `boot` services as defined in `/etc/runlevels/$1`, and then spawns TTYs 1 through 6
  * except, according to our inittab, tty1 is [`/etc/strap.sh`](./etc/strap.sh) which is the asm entrypoint
  * a completely normal alpine bootup aside from that :^)

* [`/etc/strap.sh`](./etc/strap.sh) does some basic environment setup:
  * sets the `$AR/$AP/$AD` variables for easy access to the USB FS
  * switches the shell from `ash` to `bash` if available
  * keyboard layout, console font and colors, beeps the pc-speaker
  * and finally runs [`$AR/sm/asm.sh`](./sm/asm.sh) aka `fs0:/sm/asm.sh` exactly once, before turning tty1 back into a normal interactive console

so considering the minimal amount of hacks, this should all JustWork in future alpine versions too 🤞🤞


# compatibility

should work on most BIOS and UEFI boxes with a few exceptions;

1. BIOS boxes too ancient and buggy, requiring a proper hybrid-iso
  * **workaround:** use `-oi` to create a read-only hybrid iso

2. UEFI-only boxes which refuse to boot from MBR
  * **workaround:** modify the fdisk/sfdisk invocation to build a GPT-formatted flashdrive instead of MBR, killing BIOS support


# notes

* [`./winpe/`](./winpe/) is unrelated bonus content

* see [`./doc/notes.md`](./doc/notes.md) for more
