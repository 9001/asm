#!/bin/bash
set -e

# builds asm.usb (a raw image which can be written to a flashdrive)

err=
iso="$1"
[ -z "$iso" ] && {
    echo "need argument 1: alpine iso"
    err=1
}

sz="$2"
[ -z "$sz" ] && {
    echo "need argument 2: size of the usb image in GiB"
    err=1
}

hybrid=
[ "$3" ] && {
    hybrid=asm.iso
    rm -f "$hybrid"
}

[ $err ] && {
    echo "note:"
    echo "  argument 3 (optional, requires root) will"
    echo "  create isohybrid \"asm.iso\" in addition"
    echo
    echo "example:"
    echo "  $0 dl/alpine-extended-3.15.0-x86_64.iso 1.8 yes"
    echo
    exit 1
}

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
qemu=qemu-system-$arch
need $qemu
need qemu-img
need bc
[ "$hybrid" ] && need xorrisofs
[ $err ] && exit 1

[ -e "$iso" ] || {
    echo "iso not found; downloading..."
    mkdir -p "$(dirname "$iso")"
    wget https://mirrors.edge.kernel.org/alpine/v$ver/releases/$arch/"$isoname" -O "$iso"
}

rm -rf b
mkdir -p b/fs/sm/img
cp -pR etc b/

# add unmodified apkovl + asm.sh for the final image
tar -czvf b/fs/sm/img/the.apkovl.tar.gz etc
cp -pR sm b/fs/sm/img/
cd b

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

cp -pR $AR/sm/img/* /mnt/
sync
fstrim -v /mnt || true
echo; df -h /mnt; echo
umount /mnt
poweroff
EOF
chmod 755 fs/sm/asm.sh

fallocate -l 16M ovl.img
mkfs.ext4 -Fd fs ovl.img

sz=$(echo "$sz*1024*1024*1024/1" | tr , . | LC_ALL=C bc)
fallocate -l ${sz} asm.usb

mkfifo s.{in,out}
(awk '1;/^ISOLINUX/{exit}' <s.out; echo "lts console=ttyS0" >s.in; cat s.out) &

$qemu -accel kvm -nographic -serial pipe:s -cdrom "$iso" -m 512 \
  -drive format=raw,if=virtio,discard=unmap,file=asm.usb \
  -drive format=raw,if=virtio,discard=unmap,file=ovl.img

cd ..
mv b/asm.usb .
rm -rf b

[ "$hybrid" ] && {
    c="mount -o ro,offset=1048576 asm.usb b"
    mkdir b
    $c || sudo $c || {
        printf "\nplease run the following as root:\n  %s\n" "$c"
        while sleep 0.2; do
            [ -e b/the.apkovl.tar.gz ] &&
                sleep 1 && break
        done
    }
    [ -e b/the.apkovl.tar.gz ] || {
        echo failed to mount the usb image for iso conversion
        exit 1
    }
    echo now building $hybrid ...
    # https://github.com/alpinelinux/aports/blob/569ab4c43cba612670f1a153a077b42474c33267/scripts/mkimg.base.sh
    xorrisofs \
      -quiet \
      -output $hybrid \
      -full-iso9660-filenames \
      -joliet \
      -rational-rock \
      -sysid LINUX \
      -volid asm-$(date +%Y-%m%d-%H%M%S) \
      -isohybrid-mbr b/boot/syslinux/isohdpfx.bin \
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
      b && rv= || rv=$?

    c="umount b"
    $c || sudo $c || {
        printf "\nplease run the following as root:\n  %s\n" "$c"
        while sleep 0.2; do
            [ ! -e b/the.apkovl.tar.gz ] &&
                sleep 1 && break
        done
    }
    rmdir b
    [ $rv ] &&
        exit $rv
}

cat <<EOF

=======================================================================

alpine-service-mode was built successfully (nice)

you can now write the image to a usb flashdrive:
  cat asm.usb >/dev/sdi && sync

or compress it for uploading:
  pigz asm.usb

or try it in qemu:
  qemu-system-$arch -accel kvm -drive format=raw,file=asm.usb -m 512

EOF
