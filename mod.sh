#!/bin/bash
set -e

msg()  { printf '\033[0;36;7m*\033[27m %s\033[0m%s\n' "$*" >&2; }
inf()  { printf '\033[1;92;7m+\033[27m %s\033[0m%s\n' "$*" >&2; }
warn() { printf '\033[0;33;7m!\033[27m %s\033[0m%s\n' "$*" >&2; }
err()  { printf '\033[1;91;7mx\033[27m %s\033[0m%s\n' "$*" >&2; }
absreal() { realpath "$1" || readlink -f "$1"; }

img=asm.usb
td=
sm=
sz=
mi=
vi=
vn=ASM
asm_key=
efi_key=
efi_crt=
trim=

[ $(id -u) -eq 0 ] && ex= || ex=1

help() {
    sed -r $'s/^( +)(-\w+ +)([A-Z]\w* +)/\\1\\2\e[36m\\3\e[0m/; s/(.*default: )(.*)/\\1\e[35m\\2\e[0m/' <<EOF

modifies an existing asm.usb (secureboot-sign and/or replace resources)

arguments:
  -u PATH   usb image to modify, default: ${img}
  -s GiB    resize image with mtools
  -di ID    mbr/gpt id (%08x), default: random
  -vi ID    filesystem id (%08x), default: random
  -vn ID    filesystem name, default: $vn
  -ak PATH  RSA pem-key for asm.sh, default: Do-Not-Modify
  -ek PATH  SB pem-key for the.efi, default: Do-Not-Modify
  -ec PATH  SB pem-cert for the.efi, default: Do-Not-Modify
  -sm PATH  delete and replace sm folder with PATH
  -z y      zero free space if fstrim fails
  -ex y     extract+rebuild with mtools (default if not root)

notes:
  UEFI only, MBR only
  -u can be a folder with rootfs instead of an usb image
  "-z f" will force free-space zeroing, even if fstrim is ok

EOF
    exit 1
}


err=
[ $# -eq 0 ] && help
while [ "$1" ]; do
    k="$1"; shift
    v="$1"; shift || true
    case "$k" in
        -u)  img="$v"; ;;
        -s)  sz="$v"; ;;
        -di) di="$v"; ;;
        -vi) vi="$v"; ;;
        -vn) vn="$v"; ;;
        -ak) asm_key="$v"; ;;
        -ek) efi_key="$v"; ;;
        -ec) efi_crt="$v"; ;;
        -sm) sm_path="$v"; ;;
        -z)  trim="$v"; ;;
        -ex) ex="$v"; ;;
        *)   err "unexpected argument: $k"; help; ;;
    esac
done

img="$(absreal "$img")"

[ ! "$efi_key$efi_crt" ] || [ "$efi_key" -a "$efi_crt" ] || {
    err "need both -ek and -ec to produce a secureboot-signed efi"
    exit 1
}


#####################################################################
# mount / extract

usb_open() {
    trap "rmdir '$td' 2>/dev/null || umount '$td' || sudo umount '$td' || true; rmdir '$td' 2>/dev/null || true" INT TERM EXIT
    mount -o offset=1048576 "$img" "$td"
}

mt_extract() {
    trap "rm -rf '$td'" INT TERM EXIT
    msg "extracting $img to $td"
    mcopy -Qbmsi "$img"@@1M '::*' "$td/"
}

[ -d "$img" ] && td="$img" || {
    td=$(mktemp --tmpdir -d asm.XXXXX || mktemp -d -t asm.XXXXX)
    if [ $ex ]; then mt_extract; else usb_open; fi
}

[ -e "$td/sm" ] || {
    err the source folder is not a valid asm filesystem
    exit 1
}


#####################################################################
# transformations

[ "$sm_path" ] && {
    d="$td/sm"
    msg "replacing $d with $sm_path"
    rm -rf "$d"
    cp -R --preserve=timestamps "$sm_path" "$d"
}

[ "$asm_key" ] && {
    f="$td/sm/asm.sh"
    msg "signing $f with $asm_key"
    openssl dgst -sha512 -sign "$asm_key" -out "$f.sig" "$f"
}

[ "$efi_key" ] && {
    efi="$(echo "$td"/efi/boot/boot*efi)"
    msg "signing $efi with $efi_key"

    t1="$(mktemp asm.XXXXX)"  # sbattach modifies inline...
    t2="$(mktemp asm.XXXXX)"  # ...but sbsign doesn't
    cat "$efi" > "$t1"
    sbattach --remove "$t1" || true
    sbsign --cert "$efi_crt" --key "$efi_key" --output "$t2" "$t1" || {
        err "secureboot signing failed"
        rm "$t1" "$t2"
        exit 1
    }
    cat "$t2" > "$efi"
    rm "$t1" "$t2"
}

inf all modifications ok


#####################################################################
# unmount / reassemble

usb_close() {
    fstrim -v "$td" && rv=0 || rv=$?
    [ "$trim" ] && {
        [ "$trim" = f ] || [ $rv -gt 0 ] && {
            command -v pv >/dev/null && pv="pv -i 0.2" || pv=cat
            $pv /dev/zero > "$td/nil" || true
            sync "$td/nil" || true
            rm "$td/nil"
        }
    }
}

mt_build() {
    msg building new image with mtools
    [ "$sz" ] && sz=$(echo "(($sz*1024*1024*1024+511)/512)*512" | tr , . | LC_ALL=C bc)
    [ "$sz" ] || sz=$(wc -c < "$img" | awk '{print$1}')
    truncate -s 0 "$img"
    truncate -s $sz "$img"
    echo ',,0c,*' | sfdisk -q --label dos "$img"
    [ "$di" ] && sfdisk -q --disk-id "$img" 0x$di
    local args=
    [ "$vi" ] && args="-i $vi"
    mkfs.vfat -F32 -n"$vn" $args --mbr=n -S512 --offset=2048 "$img"
    (cd "$td" && mcopy -Qbmsi "$img"@@1M ./* ./.* ::)
}

[ -d "$img" ] ||
    if [ $ex ]; then mt_build; else usb_close; fi

sz=$(du -sk "$img" | awk '{print$1}')
inf "new image ok ($sz KiB)"
exit 0
