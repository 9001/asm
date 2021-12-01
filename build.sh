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

[ $err ] && {
    echo "example:"
    echo "  $0 alpine-extended-3.15.0-x86_64.iso 1.8"
    exit 1
}

read flavor ver arch < <(echo "$iso" |
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
[ $err ] && exit 1

[ -e "$iso" ] || {
    echo "iso not found; downloading..."
    wget https://mirrors.edge.kernel.org/alpine/v$ver/releases/$arch/"$iso"
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

$qemu -accel kvm -nographic -serial pipe:s -cdrom "../$iso" -m 512 \
  -drive format=raw,if=virtio,discard=unmap,file=asm.usb \
  -drive format=raw,if=virtio,discard=unmap,file=ovl.img

cd ..
mv b/asm.usb .
rm -rf b
cat <<EOF

=======================================================================

alpine-service-mode was built successfully (nice)

you can now write the image to a usb flashdrive:
  cat asm.usb >/dev/sdi && sync

or try it in qemu:
  qemu-system-$arch -accel kvm -drive format=raw,file=asm.usb -m 512

EOF
