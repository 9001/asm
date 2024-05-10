#!/bin/bash
set -e

msg()  { printf '\033[0;36;7m*\033[27m %s\033[0m%s\n' "$*" >&2; }
inf()  { printf '\033[1;92;7m+\033[27m %s\033[0m%s\n' "$*" >&2; }
warn() { printf '\033[0;33;7m!\033[27m %s\033[0m%s\n' "$*" >&2; }
err()  { printf '\033[1;91;7mx\033[27m %s\033[0m%s\n' "$*" >&2; }

usb_src="$1"
iso_out="$2"
td=
wl=
cs=
vn=ASM_$(date +%Y_%m%d_%H%M%S)

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
  -wl PATH  weightlist (from isotrace.py)
  -cs TYPE  create checksums; md5, sha1, sha512, b2, b2:256

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
        -wl) wl="$v"; ;;
        -cs) cs="$v"; ;;
        *)   err "unexpected argument: $k"; help; ;;
    esac
done

[ ${#vn} -gt 32 ] && {
    vn="${vn:0:32}"
    warn "volume name cannot be longer than 32 characters; will truncate to [$vn]"
}

[ "$(printf '%s\n' "$vn" | tr -d '[A-Z0-9_]')" ] &&
    warn "according to iso9660, the volume name should only contain uppercase A-Z, digits 0-9, and _"

[ ! "$wl" ] || [ -e "$wl" ] || {
    echo "weightlist '$wl' given to -wl does not exist"
    exit 1
}

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

# files are extracted (safe to tamper with) and not uki?
[ $ex ] && [ "$td" != "$usb_src" ] && [ $sz -lt 4141 ] && (
    # write the correct volume identifier into the .efi
    cd "$td"/efi/boot
    grep -aboRE -- '--label "alpine-(std|ext|virt|xen) 3\.[0-9\.]+ (x86|x86_64|armv7|aarch64)".*' . |
    while IFS=: read fn tofs torig; do
        tmod="$(printf '%s\n' "$torig" | sed -r 's/([^"]+")[^"]+/\1'"$vn/")"
        while [ ${#tmod} -lt ${#torig} ]; do tmod="$tmod "; done
        msg "patching ${fn:2} @ $tofs"
        msg ' |--orig '"[$torig]"
        msg ' `---mod '"[$tmod]"
        [ ${#tmod} -gt ${#torig} ] &&
            warn 'failed; modified value exceeds original length' &&
            continue
        printf '%s' "$tmod" | dd of=$fn seek=$tofs bs=1 iflag=fullblock conv=sync,notrunc status=none
        rm -f "$eimg"  # make sure efi-image gets rebuilt
    done
)

[ $sz -gt 4141 ] && [ "$befi" -nt "$eimg" ] &&
    rm -f "$eimg"  # probably UKI; rebuild

[ -e "$eimg" ] || {
    [ $sz -gt 16384 ] && fat=16 || fat=12
    msg "rebuilding ${eimg##*/} (${sz} KiB, FAT-$fat)"
    mkdir -p "$td"/boot/grub
    touch "$eimg"
    truncate -s ${sz}k "$eimg"
    mkfs.vfat -F$fat -nESP "$eimg"
    mcopy -i "$eimg" -s "$td/efi" ::
}

[ $cs ] && (
    cd "$td"
    case $cs in
        md5) cmd=md5sum; sums=MD5SUMS;;
        sha1) cmd=sha1sum; sums=SHA1SUMS;;
        sha256) cmd=sha256sum; sums=SHA256SUMS;;
        sha512) cmd=sha512sum; sums=SHA512SUMS;;
        b2) cmd=b2sum; sums=B2SUMS;;
        b2:*) cmd="b2sum -l ${cs:3}"; sums=B2SUMS;;
        *) err "invalid -cs"; exit 1;;
    esac
    msg "creating $sums with $cmd"
    tfn="$(mktemp)"

    find -type f | cut -c3- |
    grep -vE '^boot/syslinux/(boot.cat|isolinux.bin)$' |
    LC_ALL=C sort | tr '\n' '\0' | xargs -0 $cmd -- > /$tfn

    mv $tfn $sums
)

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
[ "$wl" ] && args+=(
    --sort-weight-list "$wl"
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
)

# excluding uki efi from fs saves enough space to outweigh the convenience
[ $sz -gt 4141 ] && args+=(
    -m "$td"/efi/boot/boot*.efi
)

args+=(
    "$td"
)
xorrisofs "${args[@]}" && rv= || rv=$?

[ $rv ] &&
    err "failed to build iso" ||
    inf "iso OK"

exit $rv
