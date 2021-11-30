# alpine service mode

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


## how it works

the [Alpine ISO](https://alpinelinux.org/downloads/) comes with a tool ([setup-bootable](https://wiki.alpinelinux.org/wiki/Alpine_setup_scripts#setup-bootable)) which writes a copy of the ISO onto a USB flashdrive, except you can then modify the USB contents just like a normal flashdrive

> the flashdrive will be mounted read-only while inside the live-env, so yanking it at runtime is still perfectly safe -- to enable editing you have to `mount -o remount,rw /media/usb`

after running `setup-bootable` for the initial setup, we'll splice in some stuff from this repo:


### [`asm.sh`](./asm.sh)

is the payload which does the cool stuff (this is probably what you want to modify)

the following environment variables are available;
* `$AR` = filesystem path to the usb, for example `/media/usb`
* `$AP` = the usb blockdevice with partition, for example `sda1`
* `$AD` = the usb blockdevice sans partition, for example `sda`

will be saved to the flashdrive at `sm/asm.sh` during installation


### [`etc`](./etc)

is the [apkovl](https://wiki.alpinelinux.org/wiki/Alpine_local_backup) which gets unpacked into `/etc` on boot

contains the logic to make Alpine run `asm.sh` after it has booted

will be placed at the root of the flashdrive as `the.apkovl.tar.gz` during installation


## compatibility

should work on most BIOS and UEFI boxes with a few exceptions;
1. BIOS boxes too ancient and buggy, requiring a proper hybrid-iso
2. UEFI-only boxes which refuse to boot from MBR

for case 2 you could replace the "o" fdisk command with "g" which creates a GPT-formatted usb stick instead, killing BIOS support


## notes

* you can mute the sfx by touching `sm/quiet` at the usb root

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


# creating the asm usb

* grab a copy of `alpine-standard.iso` or `alpine-extended.iso` from https://alpinelinux.org/downloads/

* write it onto a usb flashdrive using your favorite tool
  * on windows: [rufus](https://github.com/pbatard/rufus/releases/) probably
  * on linux: `cat alpine.iso >/dev/sdi && sync`

* boot into alpine

* apply [`setup-bootable.patch`](./setup-bootable.patch) by hand, it's tiny enough

* insert a second usb flashdrive and partition it:
  ```
  apk add util-linux
  fdisk /dev/sdb
  ```
  * press `o` to create a new MBR partition table,
  * `n` to create a new partition (then hammer enter for a bit),
  * `t` to change type to `c`,
  * then `a` to set bootable,
  * and finally `w` to confirm/write

* then copy the iso contents to the flashdrive:
  ```
  mdev -s
  mkfs.vfat -n ASM /dev/sdb1
  setup-bootable -v /media/cdrom/ /dev/sdb1
  ```

at this point the asm usb is just another copy of the Alpine ISO, so reboot into your favorite OS and then insert the flashdrive -- let's make some changes


## adding the apkovl and bootscript

* make the apkovl: `tar -czvf the.apkovl.tar.gz etc`
* copy the apkovl to the root of the flashdrive
* copy `asm.sh` into a folder named `sm/` on the flashdrive


## optional steps

reduce boot time by disabling the modloop verification:
```
for f in /mnt/boot/*/{syslinux,grub}.cfg;
  do sed -ri 's/( quiet) *$/\1 modloop_verify=no /' $f; done 
```
