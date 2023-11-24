#!/bin/bash
set -e

msg()  { printf '\033[0;36;7m*\033[27m %s\033[0m%s\n' "$*" >&2; }
inf()  { printf '\033[1;92;7m+\033[27m %s\033[0m%s\n' "$*" >&2; }
warn() { printf '\033[0;33;7m!\033[27m %s\033[0m%s\n' "$*" >&2; }
err()  { printf '\033[1;91;7mx\033[27m %s\033[0m%s\n' "$*" >&2; }

usb_src="$1"
iso_out="$2"
td=
vn=asm-$(date +%Y-%m%d-%H%M%S)

[ $(id -u) -eq 0 ] && ex= || ex=1

help() {
    sed -r $'s/^( +)(-\w+ +)([A-Z]\w* +)/\\1\\2\e[36m\\3\e[0m/; s/(.*default: )(.*)/\\1\e[35m\\2\e[0m/' <<EOF

converts asm.usb (or a folder where that is mounted) to asm.iso

need arg 1: input (asm.usb or folder with rootfs)
need arg 2: output (asm.iso)

optional-args:
  -td PATH  temp dir
  -vn ID    volume name, default: $vn
  -ex y     extract with mtools (default if not root)

EOF
    exit 1
}

shift 2 || help
while [ "$1" ]; do
    k="$1"; shift
    v="$1"; shift || true
    case "$k" in
        -td) td="$v"; ;;
        -vn) vn="$v"; ;;
        -ex) ex="$v"; ;;
        *)   err "unexpected argument: $k"; help; ;;
    esac
done

usb_open() {
    trap "rmdir '$td' 2>/dev/null || umount '$td' || true; rmdir '$td' 2>/dev/null || true; exit" INT TERM EXIT
    mount -o offset=1048576 "$usb_src" "$td"
}

mt_extract() {
    trap "rm -rf '$td'; exit" INT TERM EXIT
    msg "extracting $usb_src to $td"
    mcopy -Qbmsi "$usb_src"@@1M '::*' "$td/"
}

[ -d $usb_src ] && td="$usb_src" || {
    [ "$td" ] && mkdir "$td" ||
        td=$(mktemp --tmpdir -d asm.XXXXX || mktemp -d -t asm.XXXXX || mktemp -d)

    if [ $ex ]; then mt_extract; else usb_open; fi
}

[ -e "$td/sm" ] || {
    err the source folder is not a valid asm filesystem
    exit 1
}

eimg="$td"/boot/grub/efi.img
befi=$(echo "$td"/efi/boot/boot*.efi)
sz=$(cat "$td"/efi/boot/* | wc -c | awk '{print int($1/1024)+256}')

[ $sz -gt 4141 ] && [ $befi -nt $eimg ] &&
    rm -f $eimg  # probably UKI; rebuild

[ -e $eimg ] || {
    msg upgrading $eimg ...
    mkdir -p "$td"/boot/grub
    touch $eimg
    truncate -s ${sz}k $eimg
    mkfs.vfat -F16 -nESP $eimg
    mcopy -i $eimg -s "$td/efi" ::
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
    -volid $vn
)
[ -e "$td"/boot/syslinux/isohdpfx.bin ] && args+=(
    -isohybrid-mbr "$td"/boot/syslinux/isohdpfx.bin
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
    -m "$td"/efi/boot/boot*.efi
    "$td"
)
xorrisofs "${args[@]}" && rv= || rv=$?

exit $rv
