# example post-build steps, and/or:
# a library of functions to reuse in daisychained post-build steps


##
# pop a reverse shell in the build env
#
# call this with one of your host IPs as arg1
# and start listening on your host:
#   ncat -lvp 4321
# or better yet,
#   socat file:$(tty),raw,echo=0 tcp-l:4321

rshell() {
    if apk add socat; then
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
        dmidecode efibootmgr libcpuid-tool lm-sensors lshw nvme-cli pciutils sgdisk smartmontools testdisk usbutils \
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
        s/( quiet)( .*|$)/\1\2 nomodeset i915.modeset=0 nouveau.modeset=0 /;
        ' $f; 
    done )
}


##
# beep at grub menu

grub_beep() {
    apk add grub-efi
    tar -cC /usr/lib/grub x86_64-efi/play.mod | tar -xvC /mnt/boot/grub
    printf >> /mnt/boot/grub/grub.cfg '%s\n' '' 'insmod play' 'play 1920 330 1'
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

imshrink_filter_mods() {
    # shaves ~54 MiB
    # shrink modloop by removing rarely-useful stuff + invokes imshrink_fake_gz
    #
    # accepts optional regex for additional mods to remove; for example
    # imshrink_filter_mods '\/(vmwgfx|arcnet|isdn)\/'
    #
    apk add squashfs-tools pigz pv
    cd; rm -rf x x2; mkdir x x2
    mount -o loop /mnt/boot/modloop-* x
    cd x
    arg="$1"; [ -z "$arg" ] || arg="/$arg/{next}"
    log unpacking modloop
    find -type f | awk '
        /\/(brcm|mrvl|ath1.k|ti-connectivity|rtlwifi|rtl_bt|wireless|bluetooth)\/|iwlwifi/{next}  # wifi/bt
        /\/(amdgpu|radeon|nvidia|nouveau)\//{next}  # pcie gpus
        /\/(netronome)\//{next}  # agilio smartnics
        /\/(sound)\//{next}  # soundcards
        /\/(drivers\/multimedia|kernel\/drivers\/media)\//{next}  # capturecards, webcams
        /\/(ueagle-atm)\//{next}  # adsl modems
        /\/(ocfs2)\//{next}  # filesystems
        '"$arg"'  # from argv
    1' | tar -cT- | tar -xC ../x2
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
    mv x3 /mnt/boot/modloop-*
    cd; rm -rf x x2 x3
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
    # (bonus: zstd/xz produces a smaller initramfs)
    apk add zstd xz
    cd; mkdir x; cd x
    f=$(echo /mnt/boot/initramfs-*)
    log unpacking initramfs
    gzip -d < $f | cpio -idm
    rm -f var/cache/misc/modloop-*.SIGN.RSA.*
    log repacking initramfs
    # https://github.com/alpinelinux/mkinitfs/blob/a5f05c98f690d95374b69ae5405052b250305fdf/mkinitfs.in#L177
    umask 0077
    comp="zstd -19 -T0"     # boots ~.5sec / 10% faster, --long/--ultra can OOM
    comp="xz -C crc32 -T0"  # 320k..3M smaller
    find . | sort | cpio --renumber-inodes -o -H newc | $comp > $f
    cd; rm -rf x
}

##
########################################################################


#recommended_apks
#rshell 192.168.122.1
#party


# chainload profile-specific steps
f=$AR/sm/img/sm/post-build-2.sh
[ ! -e $f ] || { log $f; . $f; }
