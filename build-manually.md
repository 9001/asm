# creating the asm usb manually

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

if you are using msys2 or mingw on windows, first ensure you have gnutar:
* `pacman -S --needed tar`
* `hash -r`

and now,
* make the apkovl: `tar -czvf the.apkovl.tar.gz --mode=755 etc`
* copy the apkovl to the root of the flashdrive
* copy `asm.sh` into a folder named `sm/` on the flashdrive


## optional steps

reduce boot time by disabling the modloop verification:
```
for f in /mnt/boot/*/{syslinux,grub}.cfg;
  do sed -ri 's/( quiet) *$/\1 modloop_verify=no /' $f; done 
```
