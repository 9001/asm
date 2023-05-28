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
