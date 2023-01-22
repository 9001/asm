#!/bin/bash
set -e

# usb-to-iso;
# converts asm.usb (or a folder where that is mounted) to asm.iso

msg()  { printf '\033[0;36;7m*\033[27m %s\033[0m%s\n' "$*" >&2; }
inf()  { printf '\033[1;92;7m+\033[27m %s\033[0m%s\n' "$*" >&2; }
warn() { printf '\033[0;33;7m!\033[27m %s\033[0m%s\n' "$*" >&2; }
err()  { printf '\033[1;91;7mx\033[27m %s\033[0m%s\n' "$*" >&2; }

usb_src=$1
iso_out=$2
[ "$iso_out" ] || {
    echo "need arg 1: asm.usb (input; can be a folder with rootfs instead)"
    echo "need arg 2: asm.iso (output)"
    echo "optional 3: tmpdir"
    exit 1
}

[ -d $usb_src ] && td=$1 || {
    td=$3
    [ "$td" ] && mkdir "$td" ||
        td=$(mktemp --tmpdir -d asm.XXXXX || mktemp -d -t asm.XXXXX)
    
    trap "rm -rf $td || umount $td || sudo umount $td || true; rm -rf $td; true" INT TERM EXIT

    c="mount -o ro,offset=1048576 $usb_src $td"
    $c || sudo $c || {
        warn "please run the following as root:"
        echo "    $c" >&2
        while sleep 0.2; do
            [ -e $td/the.apkovl.tar.gz ] &&
                sleep 1 && break
        done
    }
    [ -e $td/the.apkovl.tar.gz ] || {
        err failed to mount the usb image for iso conversion
        exit 1
    }
}

[ -e $td/the.apkovl.tar.gz ] || {
    err the source folder is not a valid asm filesystem
    exit 1
}

msg now building "$iso_out" ...
# https://github.com/alpinelinux/aports/blob/569ab4c43cba612670f1a153a077b42474c33267/scripts/mkimg.base.sh
xorrisofs \
    -quiet \
    -output "$iso_out" \
    -full-iso9660-filenames \
    -joliet \
    -rational-rock \
    -sysid LINUX \
    -volid asm-$(date +%Y-%m%d-%H%M%S) \
    -isohybrid-mbr $td/boot/syslinux/isohdpfx.bin \
    -eltorito-boot boot/syslinux/isolinux.bin \
    -eltorito-catalog boot/syslinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    -follow-links \
    $td && rv= || rv=$?

[ -d "$usb_src" ] || {
    c="umount $td"
    $c || sudo $c || {
        warn "please run the following as root:"
        echo "    $c" >&2
        while sleep 0.2; do
            [ ! -e $td/the.apkovl.tar.gz ] &&
                sleep 1 && break
        done
    }
}

exit $rv
