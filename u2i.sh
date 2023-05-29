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
    
    trap "rmdir $td 2>/dev/null || umount $td || sudo umount $td || true; rmdir $td 2>/dev/null || true" INT TERM EXIT

    c="mount -o offset=1048576 $usb_src $td"
    $c || sudo $c || {
        warn "please run the following as root:"
        echo "    $c" >&2
        while sleep 0.2; do
            [ -e $td/sm ] &&
                sleep 1 && break
        done
    }
    [ -e $td/sm ] || {
        err failed to mount the usb image for iso conversion
        exit 1
    }
}

[ -e $td/sm ] || {
    err the source folder is not a valid asm filesystem
    exit 1
}

eimg=$td/boot/grub/efi.img
befi=$(echo $td/efi/boot/boot*.efi)
sz=$(wc -c <$befi | awk '{print int($1/1024)+256}')

[ $sz -gt 4141 ] && [ $befi -nt $eimg ] &&
    rm -f $eimg  # probably UKI; rebuild

[ -e $eimg ] || {
    msg upgrading $eimg ...
    mkdir -p $td/boot/grub
    touch $eimg
    truncate -s ${sz}k $eimg
    mkfs.vfat -F16 -nESP $eimg
    mcopy -i $eimg -s $td/efi ::
}

msg now building "$iso_out" ...
# https://github.com/alpinelinux/aports/blob/569ab4c43cba612670f1a153a077b42474c33267/scripts/mkimg.base.sh
args=(
    -quiet
    -output "$iso_out"
    -full-iso9660-filenames
    -joliet
    -rational-rock
    -sysid LINUX
    -volid asm-$(date +%Y-%m%d-%H%M%S)
)
[ -e $td/boot/syslinux/isohdpfx.bin ] && args+=(
    -isohybrid-mbr $td/boot/syslinux/isohdpfx.bin
    -eltorito-boot boot/syslinux/isolinux.bin
    -eltorito-catalog boot/syslinux/boot.cat
    -no-emul-boot
    -boot-load-size 4
    -boot-info-table
)
args+=(
    -eltorito-alt-boot
    -e boot/grub/efi.img
    -no-emul-boot
    -isohybrid-gpt-basdat
    -follow-links
    -m $td/efi/boot/boot*.efi
    $td
)
xorrisofs "${args[@]}" && rv= || rv=$?

[ -d "$usb_src" ] || {
    c="umount $td"
    $c || sudo $c || {
        warn "please run the following as root:"
        echo "    $c" >&2
        while sleep 0.2; do
            [ ! -e $td/sm ] &&
                sleep 1 && break
        done
    }
}

exit $rv
