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
  * or beep even more with `grub-efi` and `grub_beep` in [post-build-2.sh](https://github.com/9001/asm/blob/hovudstraum/p/big/sm/post-build-2.sh)
  * or if the beeps don't work, add `tinyalsa` to recommended_apks in your post-build-2

see [profiles](./p/) for additional examples including a chatserver, a disk wiper and a webkiosk


## secureboot

the [uki profile](./p/uki/) shows how to securely verify the integrity of all resources during boot, using secureboot and (a bespoke alternative to) measured boot


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
  * usbimager v1.0.9 is 10x faster than rufus if you are repeatedly writing similar usb images to the same flashdrive
  * rufus v3.15 permanently unmounts the flashdrive when done, so run [rufus-unhide.bat](./doc/rufus-unhide.bat) afterwards
  * do not use balenaEtcher, it is spyware

**tip:** if the flashdrive is larger than the image, it is safe and recommended to add a "data" partition to the flashdrive after writing the image:
* on windows, use the win10 `Disk Management` utility, or better yet:
* on linux, `echo ,,07 | sfdisk -a /dev/sdi` (followed by `mkfs.ntfs -fL ASM2 /dev/sdi2` if there is no existing filesystem to keep)
  * linux-only bonus: you can write a new asm image onto the flashdrive without losing anything on the data partition, as long as the new build is the same size or smaller -- just need to issue the sfdisk command again
    * linux-only because windows is very persistent in blanking any filesystem headers it can find


## rapid prototyping

if you are working on `asm.sh` and you're testing your image by repeatedly making an iso and booting that in virtualbox/vmware/bare-metal, it would be much faster to instead mount asm.usb and make changes directly inside the image, and then use `u2i.sh` to build the iso from the mounted folder instead of doing a full build:

```bash
mkdir -p m; mount -o offset=1048576,uid=1000 asm.usb m
# make changes inside m, leave it mounted and
# do the following to make an iso whenever:
./u2i.sh m asm.iso
cat <asm.iso >/dev/sdx
```

> `cat <asm.iso >/dev/sdx` can be replaced with `revert /dev/sdx <asm.iso` for much faster writes; see[revert](https://github.com/9001/usr-local-bin/blob/master/revert)

you still need to do a full build when you change the set of included packages or make changes to the initramfs


# make it your own

the recommended / intended way to replace the demos / examples with your own stuff is to create [profiles/overlays](#profiles) with your logic and payloads -- see [the examples](./p/) for some inspiration

you should never have to modify [`./build.sh`](./build.sh) since that should JustWork, so let me know if there's something i've missed


## custom build steps

[`./sm/post-build.sh`](./sm/post-build.sh) is executed in the build-env right before the end

by default it does nothing but it provides a library of helpers / examples,
* an rshell for prototyping / debugging your extensions
* shrinking the output image
* adding more APKs


## [profiles](./p/)

if you are building several images with different contents (bootscripts, initramfs, ...) you can use the `-p` option to specify a [profile/overlay](./p/) which will replace corresponding files inside `sm` and `etc` at build-time


# compatibility

should work on most BIOS and UEFI boxes with a few exceptions;

1. BIOS boxes too ancient and buggy, requiring a proper hybrid-iso
  * **workaround:** use `-oi` to create a read-only hybrid iso

2. UEFI-only boxes which refuse to boot from MBR
  * **workaround:** modify the fdisk/sfdisk invocation to build a GPT-formatted flashdrive instead of MBR, killing BIOS support


# notes

* [`./winpe/`](./winpe/) is unrelated bonus content

* details on [how it works](./doc/how-it-works.md)

* see [`./doc/notes.md`](./doc/notes.md) for more
