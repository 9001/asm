# example post-build steps, and/or:
# a library of functions to reuse in daisychained post-build steps


die() {
    printf '%s\n' "$*"
    exit 1
}

. /etc/profile.d/buildvars.sh


##
# helper to drop pkgs that are only needed at build time

bdep_add() {
    local n=$1; shift
    ( cd /mnt/apks/*; find -maxdepth 1 -iname '*.apk' ) | sort > ~/.at$n.1
    apk add -t $n "$@"
    ( cd /mnt/apks/*; find -maxdepth 1 -iname '*.apk' ) | sort > ~/.at$n.2
}
bdep_del() {
    apk del $1
    comm ~/.at$1.* -13 | while IFS= read -r x; do rm -v /mnt/apks/*/"$x"; done
    rm ~/.at$1.*
}


##
# pop a reverse shell in the build env
#
# call this with one of your host IPs as arg1
# and start listening on your host:
#   ncat -lvp 4321
# or better yet,
#   socat file:$(tty),raw,echo=0 tcp-l:4321

rshell() {
    if apka socat; then
        log socat rshell
        socat exec:$SHELL' -li',pty,stderr,setsid,sigint,sane tcp:$1:4321,connect-timeout=1
    elif [ "$SHELL" = /bin/bash ]; then
        log bash rshell
        bash -i >&/dev/tcp/$1/4321 0>&1
    else
        log ash rshell
        local f=$(mktemp);rm $f;mkfifo $f;cat $f|ash -i 2>&1|nc $1 4321 >$f
    fi
}


##
# download extra APKs

read_idx() {
    tar -xOf $1 APKINDEX | awk -F: '
        function pr() {if (p) {printf "%s %s\n",p,v};p=""}
        /^P:/{p=$2} /^V:/{v=$2} /^$/{pr()} END{pr()}
    ';
}

fetch_apks() {
    local e=0  # defer errors until end of function (to build proxy cache)
    cd /mnt/apks/*
    setup-apkcache /mnt/apks/*
    wrepo
    #echo "$@"; rshell 192.168.122.1
    log DL $*
    apk fetch --repositories-file=/etc/apk/w -R "$@" || e=1

    log checking conditional deps
    for f in APKINDEX.*.tar.gz; do read_idx $f; done | LC_ALL=C sort > /dev/shm/nps
    (set +x; for f in *.apk; do gzip -d <"$f" | awk '/^pkgname = /{print$3;exit}'; done >/dev/shm/apks)
    sed -r 's/$/-openrc/' </dev/shm/apks | LC_ALL=C sort >/dev/shm/o1
    cut -d' ' -f1 </dev/shm/nps | LC_ALL=C sort >/dev/shm/o2
    comm -12 /dev/shm/o1 /dev/shm/o2 | xargs -r apk fetch --repositories-file=/etc/apk/w -R || e=1

    log upgrading on-disk pkgs
    read_idx APKINDEX.tar.gz | LC_ALL=C sort > /dev/shm/ops
    comm -23 /dev/shm/ops /dev/shm/nps > /dev/shm/dps
    awk '{printf "%s-%s.apk\n",$1,$2}' </dev/shm/dps | xargs rm -f --
    cut -d' ' -f1 /dev/shm/dps | xargs -r apk fetch --repositories-file=/etc/apk/w -R || e=1
    for f in APKINDEX.*.tar.gz; do gzip -d <$f | grep -qE "^P:apk-tools$" && cp -pv $f APKINDEX.tar.gz; done

    return $e
}

recommended_apks() {
    fetch_apks \
        bash coreutils util-linux \
        bzip2 gzip pigz xz zstd \
        bmon curl iperf3 iproute2 iputils nmap-ncat proxychains-ng rsync socat sshfs sshpass tcpdump \
        dmidecode libcpuid-tool lm-sensors lshw nvme-cli pciutils sgdisk smartmontools testdisk usbutils \
        efibootmgr efivar mokutil sbsigntool \
        cryptsetup fuse fuse3 nbd nbd-client partclone \
        btrfs-progs dosfstools exfatprogs mtools ntfs-3g ntfs-3g-progs squashfs-tools xfsprogs \
        bc diffutils file findutils grep hexdump htop jq less mc ncdu patch psmisc pv sqlite strace tar tmux vim \
        "$@"

    # suggestions:
    #  +15.8M py3-requests ranger
    #  +14.3M grub-bios grub-efi
    #   +4.9M sbctl sbsigntool
    #   +1.9M lvm2
    #   +1.5M aria2
    #   +1.5M net-snmp-tools
    #   +0.03 tinyalsa (only if there is no piezo and you want beeps)
    #
    # py3-requests ranger aria2
}


##
# :^)

party() {
    mkdir -p /mnt/sm/bin
    cd /mnt/sm/bin
    wget https://github.com/9001/r0c/releases/latest/download/r0c.py \
        https://github.com/9001/copyparty/releases/latest/download/copyparty-sfx.py \
        https://github.com/9001/copyparty/raw/hovudstraum/bin/up2k.py \
        https://github.com/9001/copyparty/raw/hovudstraum/bin/copyparty-fuse.py
}


##
# boot faster, may destroy graphics

nomodeset() {
    ( cd /mnt/boot;
    for f in */syslinux.cfg */grub.cfg; do sed -ri '
        s/( quiet)( .*|$)/ nomodeset i915.modeset=0 nouveau.modeset=0 module_blacklist=i915,snd_hda_codec_hdmi\1\2/;
        ' $f;
    done )
}


##
# beep at grub menu

grub_beep() {
    bdep_add .gb grub-efi
    (cd /usr/lib/grub; tar -c ./*-efi/play.mod) | tar -xvoC /mnt/boot/grub
    printf >> /mnt/boot/grub/grub.cfg '%s\n' '' 'insmod play' 'play 1920 330 1'
    bdep_del .gb
}


########################################################################
# image shrinkers;
# each of these are optional
#
# imshrink_filter_apks is the least hacky / least likely thing to fail in the future

imshrink_fake_gz() {
    # shaves ~9 MiB
    # uncompress kernel modules so squashfs can compress better,
    # assumes the current version of alpine still does .ko.gz,
    # harmless if that's not the case
    cd ~/x2
    printf '\033[?7h'
    log uncompressing kmods using $CORES cores
    find -iname '*.gz' > ~/l
    [ -s ~/l ] || return 0
    local nc=0
    while true; do
        awk \$NR%$CORES==$nc ~/l |
        while IFS= read -r x; do
            printf .
            gzip -d "$x"
            pigz -0 "${x%.*}"
        done &
        nc=$((nc+1))
        [ $nc -ge $CORES ] && break
    done
    wait
    echo
}

imshrink_zinfo() {
    # shaves ~3 MiB by compressing symbols (only useful for debugging kernel bugs)
    log compressing kernel info
    bdep_add .zki xz
    cd /mnt/boot
    xz -z9 System.map* &
    xz -z9 config* &
    wait
    cd
    bdep_del .zki
}

imshrink_rmkinfo() {
    # or shave 3.7 MiB by just deleting them entirely
    rm -f /mnt/boot/System.map* /mnt/boot/config*
}

imshrink_filter_mods() {
    # shaves ~54 MiB
    # shrink modloop by removing rarely-useful stuff + invokes imshrink_fake_gz
    #
    # accepts one, two, or three optional args:
    #   arg 1: regex of additional mods to remove
    #   arg 2: regex of mods to keep (override remove)
    #   arg 3: disables all default rules if non-empty
    #
    # example:
    #   imshrink_filter_mods '/(vmwgfx|arcnet|isdn|sound)/'
    #
    bdep_add .ml squashfs-tools pigz pv
    cd; rm -rf x x2; mkdir x x2
    local ml=$(echo /mnt/boot/modloop-*)
    [ -f $ml ] || die 'could not find modloop'
    mount -o loop $ml x
    cd x

    drop="$(printf '%s\n' "$1" | sed -r 's`/`\\/`g')"
    keep="$(printf '%s\n' "$2" | sed -r 's`/`\\/`g')"
    [ "$drop" ] && drop="/$drop/{next}"
    [ "$keep" ] && keep="/$keep/{print;next}"
    base='
        /\/(brcm|mrvl|ath1.k|ti-connectivity|rtlwifi|rtl_bt|wireless|bluetooth)\/|iwlwifi/{next}  # wifi/bt
        /\/(amdgpu|radeon|nvidia|nouveau)\//{next}  # pcie gpus
        /\/(netronome)\//{next}  # agilio smartnics
        /\/(drivers\/multimedia|kernel\/drivers\/media)\//{next}  # capturecards, webcams
        /\/(ueagle-atm)\//{next}  # adsl modems
        /\/(ocfs2)\//{next}  # filesystems
    '
    [ "$3" ] && base=

    log unpacking modloop
    find -type f | (set -x; awk "${keep}${base}${drop}1") | tar -cT- | tar -xC ../x2
    imshrink_fake_gz
    cd
    # https://github.com/alpinelinux/alpine-conf/blob/b511518795b03520248d9a64ff488716e3f01c38/update-kernel.in#L326
    case $ARCH in
        armhf) mksfs="-Xbcj arm" ;;
        armv7|aarch64) mksfs="-Xbcj arm,armthumb" ;;
        x86|x86_64) mksfs="-Xbcj x86" ;;
        *) mksfs=
    esac
    (sleep 1; pv -i0.3 -d $(pidof mksquashfs):3) &
    mksquashfs x2/ x3 -comp xz -exit-on-error $mksfs
    umount x
    mv x3 $ml
    cd; rm -rf x x2 x3
    bdep_del .ml
}

imshrink_filter_apks() {
    # shaves ~10 MiB when going from virt to just alpine-base;
    # reduces the on-disk apk selection
    cd; rm -rf x; mkdir x; cd x
    [ $1 = -w ] &&
        cp -p /etc/apk/repositories r && shift ||
        grep -vE 'https?://' </etc/apk/repositories >r

    log keeping $*
    apk fetch --repositories-file=r -R "$@"

    rm /mnt/apks/*/*.apk
    mv *.apk /mnt/apks/*/
    cd; rm -rf x
}

imshrink_nosig() {
    # shaves 1~3 MiB
    # remove modloop signature from initramfs to avoid pulling in openssl
    bdep_add .msig zstd xz
    cd; mkdir x; cd x
    f=$(echo /mnt/boot/initramfs-*)
    log unpacking initramfs
    gzip -d < $f | cpio -idm
    rm -f var/cache/misc/modloop-*.SIGN.RSA.*
    log repacking initramfs
    free -m
    local m=$(awk '/^MemAvailable:/{printf("%d\n",($2*0.9)/1024)}' < /proc/meminfo)
    # https://github.com/alpinelinux/mkinitfs/blob/a5f05c98f690d95374b69ae5405052b250305fdf/mkinitfs.in#L177
    umask 0077
    comp="zstd -19 -T0"     # boots ~.5sec / 10% faster, --long/--ultra can OOM
    comp="xz -C crc32 -T0 -M${m}MiB"  # 320k..3M smaller
    find . | sort | cpio --renumber-inodes -o -H newc | $comp > $f
    cd; rm -rf x
    bdep_del .msig
}


########################################################################
# uki / secureboot

uki_make() {
    # must be done after all initramfs / apkovl tweaks
    bdep_add .sbs gummiboot-efistub cmd:objcopy xz openssl patch

    local sec=
    [ $# -gt 0 ] && sec=secure

    local cmdline=/dev/shm/cmdline
    awk '/boot\/vmlinuz-/ {
        sub(/[^-]+/,"");
        sub(/[^ ]+ /,"");
        print $0 " apkovl=/the.apkovl.tar.gz pkgs=openssl '$sec' "
    }' </mnt/boot/grub/grub.cfg >$cmdline

    # sign modloop
    local rsa=/dev/shm/modloop
    local ml=$(echo /mnt/boot/modloop-*)
    [ -f $ml ] || die 'could not find modloop'
    openssl genrsa -out $rsa.priv 4096
    openssl rsa -in $rsa.priv -pubout > $rsa.pub
    openssl dgst -sha512 -sign $rsa.priv -out $ml.sig $ml

    # add modloop pubkey into apkovl, then move apkovl into initramfs
    cd; mkdir x; cd x
    f=$(echo /mnt/boot/initramfs-*)
    [ -e "$f" ] || die could not find initramfs

    log unpacking initramfs
    gzip -d < $f | cpio -idm
    patch init </etc/patches/init-uki.patch
    patch init </etc/patches/init-cmdline.patch
    patch init </etc/patches/init-no-ml-pgp.patch
    [ $sec ] && patch init </etc/patches/init-passwd.patch
    cp /dev/shm/cmdline .
    mkdir x; cd x
    tar -xzf /mnt/the.apkovl.tar.gz
    rm /mnt/the.apkovl.tar.gz
    cp -pv /dev/shm/modloop.pub .
    tar -czf ../the.apkovl.tar.gz .
    cd ..; rm -rf x

    log repacking initramfs
    free -m
    local m=$(awk '/^MemAvailable:/{printf("%d\n",($2*0.9)/1024)}' < /proc/meminfo)
    # https://github.com/alpinelinux/mkinitfs/blob/a5f05c98f690d95374b69ae5405052b250305fdf/mkinitfs.in#L177
    umask 0077
    comp="xz -C crc32 -T0 -M${m}MiB"
    find . | sort | cpio --renumber-inodes -o -H newc | $comp > $f
    cd; rm -rf x

    # based on https://github.com/jirutka/efi-mkuki/blob/master/efi-mkuki
    local osrel=/etc/os-release
    local march=
    case $(uname -m) in
		x86 | i686) march=ia32;;
		x86_64) march=x64;;
		arm*) march=arm;;
		aarch64) march=aa64;;
		*) die "unknown arch: $(uname -m)";;
	esac
    local efistub="/usr/lib/gummiboot/linux$march.efi.stub"
    [ -f "$efistub" ] || die "could not find efistub $efistub"

    local linux=$(echo /mnt/boot/vmlinuz-*)
    local initrd=$(echo /mnt/boot/initramfs-*)
    [ -f $linux ] && [ -f $initrd ] || die "could not find linux $linux or initrd $initrd"

    #rshell 192.168.122.1

    mv /mnt/efi/boot/boot$march.efi /mnt/efi/boot/grub$march.efi

    objcopy \
        --add-section .osrel="$osrel"     --change-section-vma .osrel=0x20000    \
        --add-section .cmdline="$cmdline" --change-section-vma .cmdline=0x30000  \
        --add-section .linux="$linux"     --change-section-vma .linux=0x40000    \
        --add-section .initrd="$initrd"   --change-section-vma .initrd=0x3000000 \
        "$efistub" "/mnt/efi/boot/boot$march.efi"

    bdep_del .sbs
}

uki_only() {
    # drop grub and bios support to save ~30 MiB
    rm -rf \
        /mnt/ldlinux* \
        /mnt/efi/boot/grub*.efi \
        /mnt/boot/grub \
        /mnt/boot/syslinux \
        /mnt/boot/dtbs-* \
        /mnt/boot/vmlinuz-* \
        /mnt/boot/initramfs-*
}

sign_asm() {
    local f=/mnt/sm/asm.sh

    [ -e /etc/asm.key ] || {
        log "WARNING: cannot sign $f because asm privkey (-ak) was not provided"
        return 0
    }

    log signing asm.sh with provided privkey
    bdep_add .asig openssl
    openssl dgst -sha512 -sign /etc/asm.key -out $f.sig $f
    bdep_del .asig
}

sign_efi() {
    local tf=/mnt/efi/boot/s.efi
    local efi=$(echo /mnt/efi/boot/boot*.efi)

    [ -e /etc/efi.key ] && [ -e /etc/efi.crt ] || {
        log "WARNING: cannot sign $tf because either the efi cert (-ec) or key (-ek) was not provided"
        return 0
    }

    log signing the.efi with provided privkey
    bdep_add .esig sbsigntool

    sbsign --cert /etc/efi.crt --key /etc/efi.key --output $tf $efi
    touch -r $efi $tf
    mv $tf $efi
    bdep_del .esig
}

##
########################################################################


#recommended_apks
#rshell 192.168.122.1
#party


# chainload profile-specific steps
f=$AR/sm/img/sm/post-build-2.sh
[ ! -e $f ] || { log $f; . $f; }
