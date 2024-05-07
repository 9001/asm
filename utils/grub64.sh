#!/bin/bash
set -e

# mounts an alpine iso and grabs a copy of the
# grub efi; useful when you want to build an
# i386 iso which is bootable on x64 / x86_64
#
# will create the following inside the folder given as arg 2:
#   boot/grub/x86_64-efi/play.mod  # if input iso is alpine-extended
#   efi/boot/bootx64.efi           # will always be created
#
# example usage at project root:
# 1) ./doc/grub64.sh dl/alpine-extended-3.19.1-x86_64.iso ./p/obig
# 2) uncomment the grub64 call in p/obig/sm/post-build-2.sh

absreal() { realpath "$1" || readlink -f "$1"; }

iso="$1"
out="$2"

[ "$iso" ] && [ ! -e "$iso" ] && {
    echo "iso not found, trying to download with build.sh"
    ./build.sh -p - -i "$iso"
}

[ "$iso" ] && [ -e "$iso" ] || {
    echo ERROR: need arg 1, input iso file to grab grub from
    exit 1
}

[ "$out" ] || {
    echo ERROR: need arg 2, path to an asm profile to write grub into
    exit 1
}

iso="$(absreal "$iso")"
out="$(absreal "$out")"

outp="$(basename "$out")"
[ "$outp" ] && mkdir -p "$outp"

td=$(mktemp --tmpdir -d asm.XXXXX || mktemp -d -t asm.XXXXX || mktemp -d)
cln() {
    trap - INT TERM EXIT
    cd; umount $td 2>/dev/null || true; rm -rf $td; exit $?
}
trap cln INT TERM EXIT

if [ $(id -u) -eq 0 ]; then
    echo have root, mounting iso
    mount -o loop "$iso" $td
else
    echo no root, extracting from iso
    (cd "$td" && 7z x "$iso" efi/boot 'apks/x86_64/grub-efi-*' >/dev/null)
fi

mkdir -p "$out/efi/boot"
cp -pv $td/efi/boot/bootx64.efi "$out/efi/boot/bootx64.efi"

apk=$td/apks/x86_64/grub-efi-*.apk
[ -e $apk ] && {
    mkdir -p "$out/boot/grub/x86_64-efi/"
    tar --warning=no-unknown-keyword -xvOf $apk \
        usr/lib/grub/x86_64-efi/play.mod > "$out/boot/grub/x86_64-efi/play.mod"
}

echo grub64 extracted
exit 0
