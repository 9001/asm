#!/bin/bash
set -e

# builds asm.usb (a raw image which can be written to a flashdrive)

msg()  { printf '\033[0;36;7m*\033[27m %s\033[0m%s\n' "$*" >&2; }
inf()  { printf '\033[1;92;7m+\033[27m %s\033[0m%s\n' "$*" >&2; }
warn() { printf '\033[0;33;7m!\033[27m %s\033[0m%s\n' "$*" >&2; }
err()  { printf '\033[1;91;7mx\033[27m %s\033[0m%s\n' "$*" >&2; }
absreal() { realpath "$1" || readlink -f "$1"; }


# osx support; choose macports or homebrew:
#   port install qemu coreutils findutils gnutar gsed gawk xorriso e2fsprogs
#   brew install qemu coreutils findutils gnu-tar gnu-sed gawk xorriso e2fsprogs
gtar=$(command -v gtar || command -v gnutar) || true
[ ! -z "$gtar" ] && command -v gfind >/dev/null && {
	tar()  { $gtar "$@"; }
	sed()  { gsed  "$@"; }
	find() { gfind "$@"; }
	sort() { gsort "$@"; }
	command -v grealpath >/dev/null &&
		realpath() { grealpath "$@"; }
    
    export PATH="/usr/local/opt/e2fsprogs/sbin/:$PATH"
    macos=1
}


td=$(mktemp --tmpdir -d asm.XXXXX || mktemp -d -t asm.XXXXX)
trap "rm -rf $td; tput smam || printf '\033[?7h'" INT TERM EXIT

profile=
sz=1.8
asm_key=
efi_key=
efi_crt=
bvars=()
bvarf=
iso=
iso_out=
usb_out=asm.usb
b=$td/b
mirror=https://mirrors.edge.kernel.org/alpine


help() {
    v=3.18.0
    sed -r $'s/^( +)(-\w+ +)([A-Z]\w* +)/\\1\\2\e[36m\\3\e[0m/; s/(.*default: )(.*)/\\1\e[35m\\2\e[0m/' <<EOF

arguments:
  -i ISO    original/input alpine release iso
  -p NAME   profile to apply, default: <NONE>
  -s SZ     fat32 partition size in GiB, default: $sz
  -m URL    mirror (for iso/APKs), default: $mirror
  -ou PATH  output path for usb image, default: ${usb_out:-DISABLED}
  -oi PATH  output path for isohybrid, default: ${iso_out:-DISABLED}
  -b PATH   build-dir, default: $b

build-vars:
  -v A,B,C  export A, B and C into build env
  -v K=V    export K into build env (assigned to V)
  -vf PATH  is copied into /etc/profile.d/buildvars.sh

secureboot:
  -ak PATH  RSA pem-key for asm.sh, default: None/Unsigned
  -ek PATH  SB pem-key for the.efi, default: None/Unsigned
  -ec PATH  SB pem-cert for the.efi, default: None/Unsigned

notes:
  -s cannot be smaller than the source iso
  -v can be repeated, -vf cannot

examples:
  $0 -i dl/alpine-extended-$v-x86_64.iso
  $0 -i dl/alpine-extended-$v-x86_64.iso -oi asm.iso -s 3.6 -b b
  $0 -i dl/alpine-standard-$v-x86_64.iso -p webkiosk
  $0 -i dl/alpine-standard-$v-x86.iso -s 0.2 -p r0cbox

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
        -p)  profile="$v"; ;;
        -v)  bvars+=("$v"); ;;
        -vf) bvarf="$v";   ;;
        -ak) asm_key="$v"; ;;
        -ek) efi_key="$v"; ;;
        -ec) efi_crt="$v"; ;;
        -ou) usb_out="$v"; ;;
        -oi) iso_out="$v"; ;;
        -m)  mirror="${v%/}"; ;;
        *)   err "unexpected argument: $k"; help; ;;
    esac
done

[ -z "$iso" ] && {
    err "need argument -i (path to original alpine iso, will be downloaded if it does not exist)"
    help
}

printf '%s\n' "$iso" | grep -q : && {
    err "the argument to -i should be a local path, not a URL -- it will be downloaded if it does not exist"
    help
}

[ ! "$profile" ] || [ -e "p/$profile" ] || {
    err "selected profile does not exist: $PWD/p/$profile"
    exit 1
}

not_mounted() {
    for f in /sys/class/block/*/loop/backing_file; do
        grep -F "$1" $f >/dev/null 2>&1 && return 1
    done
    return 0
}
not_mounted "$usb_out" || {
    echo "output file $usb_out is mounted; trying to unmount..."
    umount "$usb_out" || true
    not_mounted "$usb_out" || {
        echo "failed; cannot continue"
        exit 1
    }
}

isoname="${iso##*/}"
read flavor ver arch < <(echo "$isoname" |
  awk -F- '{sub(/.iso$/,"");v=$3;sub(/.[^.]+$/,"",v);print$2,v,$4}')

[ $macos ] && {
    accel="-M accel=hvf"
    video=""
} || {
    accel="-enable-kvm"
    video="-vga qxl"
}

need() {
    command -v $1 >/dev/null || {
        err need $1
        err=1
    }
}
qemu=qemu-system-$arch
[ $arch = x86 ] && qemu=${qemu}_64
command -v $qemu >/dev/null || qemu=$(
    PATH="/usr/libexec:$PATH" command -v qemu-kvm || echo $qemu)
need $qemu
need qemu-img
need bc
need truncate
need mkfs.ext3
[ "$iso_out" ] && need xorrisofs
[ $err ] && exit 1

need_root=
mkfs.ext3 -h 2>&1 | grep -qE '\[-d\b' ||
    need_root=1

[ $need_root ] && [ $(id -u) -ne 0 ] && {
    err "you must run this as root,"
    err "because your mkfs.ext3 is too old to have -d"
    exit 1
}

mkdir -p "$(dirname "$iso")"
iso="$(absreal "$iso")"

[ -s "$iso" ] || {
    iso_url="$mirror/v$ver/releases/$arch/$isoname"
    msg "iso not found; downloading from $iso_url"
    need wget
    need sha512sum
    [ $err ] && exit 1

    mkdir -p "$(dirname "$iso")"
    wget "$iso_url" -O "$iso" || {
        rm -f "$iso"; exit 1
    }
    wget "$iso_url.sha512" -O "$iso.sha512" || {
        rm -f "$iso.sha512"
        warn "iso.sha512 not found on mirror; trying the yaml"
        yaml_url="$mirror/v$ver/releases/$arch/latest-releases.yaml"
        wget "$yaml_url" -O "$iso.yaml" || {
            rm -f "$iso.yaml"; exit 1
        }
        awk -v iso="$isoname" '/^-/{o=0} $2==iso{o=1} o&&/sha512:/{print$2}' "$iso.yaml" > "$iso.sha512"
    }
    msg "verifying checksum:"
    (cat "$iso.sha512"; sha512sum "$iso") |
    awk '1;v&&v!=$1{exit 1}{v=$1}' || {
        err "sha512 verification of the downloaded iso failed"
        mv "$iso"{,.corrupt}
        exit 1
    }
}

usb_out="$(absreal "$usb_out")"
[ "$iso_out" ] &&
    rm -f "$iso_out" &&
    iso_out="$(absreal "$iso_out")"

# build-env: prepare apkovl
rm -rf $b
mkdir -p $b/fs/sm/img
cp -pR etc $b/
[ "$asm_key" ] && cp -pv "$asm_key" $b/etc/asm.key
[ "$efi_key" ] && cp -pv "$efi_key" $b/etc/efi.key
[ "$efi_crt" ] && cp -pv "$efi_crt" $b/etc/efi.crt

# export -v|-vf
f=$b/etc/profile.d/buildvars.sh
mkdir -p $(dirname $f)
[ "$bvarf" ] && cat "$bvarf" >$f
for bvar in "${bvars[@]}"; do
    [[ $bvar == *=* ]] && {
        printf 'export %q\n' "$bvar"
        continue
    }
    printf '%s\n' "$bvar" | tr , '\n' | while IFS= read -r x; do
        printf 'export %q\n' "$x=${!x}"
    done
done >>$f

# live-env: add apkovl + asm contents
msg "copying sources to $b"
cp -pR etc sm $b/fs/sm/img/
pdir=.
[ "$profile" ] && {
    pdir=p/$profile;
    (cd $pdir && tar -c *) |
    tar -xC $b/fs/sm/img/
}
[ "$asm_key" ] &&  # derive pubkey from privkey
    mkdir -p $b/fs/sm/img/etc &&
    openssl rsa -in "$asm_key" -pubout > $b/fs/sm/img/etc/asm.pub

# quick smoketests if profile mentions UKI
find $b/fs/sm/img/ -iname 'post-build*sh' -exec cat '{}' + | grep -qE '^export UKI=1|^\s*uki_make([^(]|$)' && {
    [ -e $pdir/sm/asm.sh ] && sigbase=$pdir || sigbase=.
    [ -e $b/fs/sm/img/etc/asm.pub ] || [ "$asm_key" ] || {
        err "UKI was requested but there is no etc/asm.pub"
        warn "either provide a privkey with -ak, or create a keypair and add your pubkey into the build:"
        cat <<EOF
---------------------------------------------------------------------
mkdir -p ~/keys $sigbase/etc
openssl genrsa -out ~/keys/asm.key 4096
openssl rsa -in ~/keys/asm.key -pubout > ~/keys/asm.pub
cp -pv ~/keys/asm.pub $sigbase/etc/
---------------------------------------------------------------------
EOF
        exit 1
    }
    [ -e $b/fs/sm/img/sm/asm.sh.sig ] || [ "$asm_key" ] || {
        err "UKI was requested but there is no sm/asm.sh.sig"
        warn "either provide a privkey with -ak, or manually sign your asm.sh using your rsa privkey:"
        cat <<EOF
---------------------------------------------------------------------
openssl dgst -sha512 -sign ~/keys/asm.key -out $sigbase/sm/asm.sh.sig $sigbase/sm/asm.sh
---------------------------------------------------------------------
EOF
        exit 1
    }
}

pushd $b >/dev/null

# both-envs: add mirror and profile info
tee fs/sm/img/etc/profile.d/asm-profile.sh >fs/sm/asm.sh <<EOF
export IVER=$ver
export IARCH=$arch
export MIRROR=$mirror
export AN=$profile
EOF

# live-env: finalize apkovl
( cd fs/sm/img
  tar -czvf the.apkovl.tar.gz etc
  rm -rf etc )

# build-env: finalize apkovl (tty1 is ttyS0 due to -nographic)
sed -ri 's/^tty1/ttyS0/' etc/inittab
tar -czvf fs/the.apkovl.tar.gz etc

cat >>fs/sm/asm.sh <<'EOF'
set -ex
eh() {
    [ $? -eq 0 ] && exit 0
    printf "\033[A\033[1;37;41m\n\n  asm build failed; blanking partition header  \n\033[0m\n"
    sync; head -c1024 /dev/zero >/dev/vda
    poweroff
}
trap eh INT TERM EXIT

log hello from asm builder
sed -ri 's/for i in \$initrds; do/for i in ${initrds\/\/,\/ }; do/' /sbin/setup-bootable
c="apk add -q bash util-linux sfdisk syslinux dosfstools"
if ! $c; then
    wrepo
    $c
fi
if command -v sfdisk; then
    echo ',,0c,*' | sfdisk -q --label dos /dev/vda
else
    # deadcode -- this branch is never taken --
    # left for reference if you REALLY cant install sfdisk
    printf '%s\n' o n p 1 '' '' t c a 1 w | fdisk -ub512 /dev/vda
fi
mdev -s
mkfs.vfat -n ASM /dev/vda1
log setup-bootable
setup-bootable -v /media/cdrom/ /dev/vda1
echo 1 | fsck.vfat -w /dev/vda1 | grep -vE '^  , '

log disabling modloop verification
mount -t vfat /dev/vda1 /mnt
( cd /mnt/boot;
for f in */syslinux.cfg */grub.cfg; do sed -ri '
    s/( quiet)( .*|$)/ modloop_verify=no\1\2/;
    s/(^TIMEOUT )[0-9]{2}$/\110/;
    s/(^set timeout=)[0-9]$/\11/;
    ' $f; 
done )

log adding ./sm/
(cd $AR/sm/img && tar --exclude 'sm/post-build*' -c *) | tar -xC /mnt
mkdir -p /mnt/sm/bin

f=$AR/sm/img/sm/post-build.sh
[ -e $f ] && log $f && $(command -v bash || echo $SHELL) $f

log all done -- shutting down
sync
fstrim -v /mnt || true
echo; df -h /mnt; echo
umount /mnt
poweroff
EOF
chmod 755 fs/sm/asm.sh

echo
msg "ovl size calculation..."
# 32 KiB per inode + apparentsize x1.1 + 8 MiB padding, ceil to 512b
osz=$(find fs -printf '%s\n' | awk '{n++;s+=$1}END{print int((n*32*1024+s*1.1+8*1024*1024)/512)*512}')
msg "ovl size estimate $osz"
truncate -s $osz ovl.img
a="-T big -I 128 -O ^ext_attr"
mkfs.ext3 -Fd fs $a ovl.img || {
    mkfs.ext3 -F $a ovl.img
    mkdir m
    mount ovl.img m
    cp -prT fs m
    umount m
    rmdir m
}

# user-provided; ceil to 16k
sz=$(echo "(($sz*1024*1024*1024+16383)/16384)*16384" | tr , . | LC_ALL=C bc)
truncate -s ${sz} asm.usb

mkfifo s.{in,out}
[ $flavor = virt ] && kern=virt || kern=lts
(awk '1;/^ISOLINUX/{exit}' <s.out; echo "$kern console=ttyS0" >s.in; cat s.out) &

cores=$(lscpu -p | awk -F, '/^[0-9]+,/{t[$2":"$3":"$4]=1} END{n=0;for(v in t)n++;print n}')

$qemu $accel -cpu host -nographic -serial pipe:s -cdrom "$iso" -cpu host -smp $cores -m 1536 \
  -drive format=raw,if=virtio,discard=unmap,file=asm.usb \
  -drive format=raw,if=virtio,discard=unmap,file=ovl.img

# builder nukes the partition header on error; check if it did
od -v <asm.usb | awk 'NR>4{exit e}{$1=""}/[^0 ]/{e=1}END{exit e}' && {
    err some of the build steps failed
    exit 1
}

popd >/dev/null
mv $b/asm.usb "$usb_out"
rm -rf $b

[ "$iso_out" ] &&
    ./u2i.sh "$usb_out" "$iso_out" -td "$b" &&
    du -sk "$iso_out"

du -sk "$usb_out"

cat <<EOF

=======================================================================

alpine-service-mode was built successfully (nice)

you can now write the image to a usb flashdrive:
  cat $usb_out >/dev/sdi && sync

or compress it for uploading:
  pigz $usb_out

or try it in qemu:
  $qemu $accel $video -cpu host -drive format=raw,file=$usb_out -m 512
  $qemu $accel $video -cpu host -drive format=raw,file=$usb_out -net bridge,br=virhost0 -net nic,model=virtio -m 192
  $qemu $accel $video -cpu host -device virtio-blk-pci,drive=asm,bootindex=1 -drive id=asm,if=none,format=raw,file=$usb_out -bios /usr/share/OVMF/OVMF_CODE.fd -m 512

some useful qemu args:
  -nic user   -nographic

activate host-only-network if necessary:
  ./doc/setup-virhost.sh

EOF


# sound: -device ich9-intel-hda,id=sound0 -device hda-duplex,id=sound0-codec0,bus=sound0.0,cad=0 -global ICH9-LPC.disable_s3=1 -global ICH9-LPC.disable_s4=1
