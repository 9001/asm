#!/bin/bash
set -e

# builds asm.usb (a raw image which can be written to a flashdrive)

need_root=
mkfs.ext3 -h 2>&1 | grep -qE '\[-d\b' ||
    need_root=1

[ $need_root ] && [ $(id -u) -ne 0 ] && {
    echo "you must run this as root,"
    echo "because your mkfs.ext3 is too old to have -d"
    exit 1
}

td=$(mktemp --tmpdir -d asm.XXXXX)
trap "rv=$?; rm -rf $td; exit $rv" INT TERM EXIT

sz=1.8
iso=
iso_out=
usb_out=asm.usb
b=$td/b


help() {
    sed -r $'s/^( +)(-\w+ +)(\w+ +)/\\1\\2\e[36m\\3\e[0m/; s/(.*default: )(.*)/\\1\e[35m\\2\e[0m/' <<EOF

arguments:
  -i ISO    original/input alpine release iso
  -s SZ     fat32 partition size in GiB, default: $sz
  -b PATH   build-dir, default: $b
  -ou PATH  output path for usb image, default: ${usb_out:-DISABLED}
  -oi PATH  output path for isohybrid, default: ${iso_out:-DISABLED}

examples:
  $0 -i dl/alpine-extended-3.15.0-x86_64.iso
  $0 -i dl/alpine-extended-3.15.0-x86_64.iso -oi asm.iso -s 3.6 -b b

EOF
    exit 1
}


err=
while [ "$1" ]; do
    k="$1"; shift
    v="$1"; shift || true
    case "$k" in
        -i)  iso="$v"; ;;
        -s)  sz="$v";  ;;
        -b)  b="$v";   ;;
        -ou) usb_out="$v"; ;;
        -oi) iso_out="$v"; ;;
        *)   echo "unexpected argument: $k"; help; ;;
    esac
done

[ -z "$iso" ] && {
    echo "need argument -i (original alpine iso)"
    help
}

[ $iso_out ] &&
    rm -f "$iso_out"

iso="$(realpath "$iso" || readlink -f "$iso")"
isoname="${iso##*/}"

read flavor ver arch < <(echo "$isoname" |
  awk -F- '{sub(/.iso$/,"");v=$3;sub(/.[^.]+$/,"",v);print$2,v,$4}')

need() {
    command -v $1 >/dev/null || {
        echo need $1
        err=1
    }
}
qemu=$(
    PATH="/usr/libexec:$PATH" command -v qemu-kvm ||
    echo qemu-system-$arch
)
need $qemu
need qemu-img
need bc
[ "$iso_out" ] && need xorrisofs
[ $err ] && exit 1

[ -e "$iso" ] || {
    echo "iso not found; downloading..."
    mkdir -p "$(dirname "$iso")"
    wget https://mirrors.edge.kernel.org/alpine/v$ver/releases/$arch/"$isoname" -O "$iso"
}

rm -rf $b
mkdir -p $b/fs/sm/img
cp -pR etc $b/

# add unmodified apkovl + asm.sh for the final image
tar -czvf $b/fs/sm/img/the.apkovl.tar.gz etc
printf "\ncopying sources to %s\n" "$b"
cp -pR sm $b/fs/sm/img/
pushd $b >/dev/null

# tty1 is ttyS0 due to -nographic
sed -ri 's/^tty1/ttyS0/' etc/inittab
tar -czvf fs/the.apkovl.tar.gz etc

cat >fs/sm/asm.sh <<'EOF'
sed -ri 's/for i in \$initrds; do/for i in ${initrds\/\/,\/ }; do/' /sbin/setup-bootable
c="apk add -q util-linux sfdisk syslinux"
if ! $c; then
    setup-interfaces -ar
    setup-apkrepos -1
    $c
fi
if apk add -q sfdisk; then
    echo ',,0c,*' | sfdisk -q --label dos /dev/vda
else
    # deadcode -- this branch is never taken --
    # left for reference if you REALLY cant install sfdisk
    printf '%s\n' o n p 1 '' '' t c a 1 w | fdisk -ub512 /dev/vda
fi
mdev -s
mkfs.vfat -n ASM /dev/vda1
setup-bootable -v /media/cdrom/ /dev/vda1

mount -t vfat /dev/vda1 /mnt
( cd /mnt/boot;
for f in */syslinux.cfg */grub.cfg; do sed -ri '
    s/( quiet) *$/\1 modloop_verify=no /;
    s/(^TIMEOUT )[0-9]{2}$/\110/;
    s/(^set timeout=)[0-9]$/\11/;
    ' $f; 
done )

cp -pR $AR/sm/img/* /mnt/ 2>&1 | grep -vF 'preserve ownership of'
$SHELL $AR/sm/img/sm/post-build.sh || true
sync
fstrim -v /mnt || true
echo; df -h /mnt; echo
umount /mnt
poweroff
EOF
chmod 755 fs/sm/asm.sh

echo
echo "ovl size calculation..."
# 32 KiB per inode + apparentsize x1.1 + 8 MiB padding, ceil to 512b
osz=$(find fs -printf '%s\n' | awk '{n++;s+=$1}END{print int((n*32*1024+s*1.1+8*1024*1024)/512)*512}')
echo "ovl size estimate $osz"
fallocate -l $osz ovl.img
a="-T big -I 128 -O ^ext_attr"
mkfs.ext3 -Fd fs $a ovl.img || {
    mkfs.ext3 -F $a ovl.img
    mkdir m
    mount ovl.img m
    cp -prT fs m
    umount m
    rmdir m
}

# user-provided; ceil to 512b
sz=$(echo "(($sz*1024*1024*1024+511)/512)*512" | tr , . | LC_ALL=C bc)
fallocate -l ${sz} asm.usb

mkfifo s.{in,out}
(awk '1;/^ISOLINUX/{exit}' <s.out; echo "lts console=ttyS0" >s.in; cat s.out) &

$qemu -enable-kvm -nographic -serial pipe:s -cdrom "$iso" -m 512 \
  -drive format=raw,if=virtio,discard=unmap,file=asm.usb \
  -drive format=raw,if=virtio,discard=unmap,file=ovl.img

popd >/dev/null
mv $b/asm.usb "$usb_out"
rm -rf $b

[ "$iso_out" ] && {
    c="mount -o ro,offset=1048576 $usb_out $b"
    mkdir $b
    $c || sudo $c || {
        printf "\nplease run the following as root:\n  %s\n" "$c"
        while sleep 0.2; do
            [ -e $b/the.apkovl.tar.gz ] &&
                sleep 1 && break
        done
    }
    [ -e $b/the.apkovl.tar.gz ] || {
        echo failed to mount the usb image for iso conversion
        exit 1
    }
    echo now building "$iso_out" ...
    # https://github.com/alpinelinux/aports/blob/569ab4c43cba612670f1a153a077b42474c33267/scripts/mkimg.base.sh
    xorrisofs \
      -quiet \
      -output "$iso_out" \
      -full-iso9660-filenames \
      -joliet \
      -rational-rock \
      -sysid LINUX \
      -volid asm-$(date +%Y-%m%d-%H%M%S) \
      -isohybrid-mbr $b/boot/syslinux/isohdpfx.bin \
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
      $b && rv= || rv=$?

    c="umount $b"
    $c || sudo $c || {
        printf "\nplease run the following as root:\n  %s\n" "$c"
        while sleep 0.2; do
            [ ! -e $b/the.apkovl.tar.gz ] &&
                sleep 1 && break
        done
    }
    rmdir $b
    [ $rv ] &&
        exit $rv
}

cat <<EOF

=======================================================================

alpine-service-mode was built successfully (nice)

you can now write the image to a usb flashdrive:
  cat $usb_out >/dev/sdi && sync

or compress it for uploading:
  pigz $usb_out

or try it in qemu:
  $qemu -accel kvm -drive format=raw,file=$usb_out -m 512

EOF
