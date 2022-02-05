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
    # bash -i >&/dev/tcp/$1/4321 0>&1
    apk add socat
    socat exec:'/bin/bash -li',pty,stderr,setsid,sigint,sane tcp:$1:4321,connect-timeout=1
}


##
# download extra APKs

fetch_apks() {
    wrepo
    cd /mnt/apks/*
    ls -1 >.a
    echo "$@"
    #rshell 192.168.122.1
    apk fetch --repositories-file=/etc/apk/w -R "$@"
    mkdir -p /mnt/sm/eapk
    (ls -1; cat .a) | sort | uniq -c | awk '$1<2{print$2}' |
        while read -r x; do mv "$x" /mnt/sm/eapk/; done
    rm .a
}

recommended_apks() {
    fetch_apks \
        bzip2 gzip pigz zstd \
        aria2 bmon fuse fuse3 iperf3 nmap-ncat proxychains-ng sshfs sshpass \
        dmidecode lshw smartmontools sgdisk testdisk \
        ntfs-3g ntfs-3g-progs exfatprogs \
        bc file findutils grep jq less mc ncdu pv psmisc sqlite \
        py3-jinja2 py3-requests ranger \
        "$@"
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
    printf 'uncompressing kmods\033[?7h\n'
    find -iname '*.gz' | while IFS= read -r x; do
        echo -n .
        gzip -d "$x"
        pigz -0 "${x%.*}"
    done
    echo
}

imshrink_filter_mods() {
    # shaves ~54 MiB
    # shrink modloop by removing rarely-useful stuff + invokes imshrink_fake_gz
    apk add squashfs-tools pigz
    cd; rm -rf x x2; mkdir x x2
    mount -o loop /mnt/boot/modloop-* x
    cd x
    find -type f | awk '
        /\/(brcm|mrvl|ath1.k|ti-connectivity|rtlwifi|rtl_bt|wireless|bluetooth)\/|iwlwifi/{next}  # wifi/bt
        /\/(amdgpu|radeon|nvidia|nouveau)\//{next}  # pcie gpus
        /\/(netronome)\//{next}  # agilio smartnics
        /\/(sound)\//{next}  # soundcards
        /\/drivers\/multimedia\//{next}  # capturecards, webcams
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
    mksquashfs x2/ x3 -comp xz -exit-on-error $mksfs
    umount x
    mv x3 /mnt/boot/modloop-*
    cd; rm -rf x x2 x3
}

imshrink_filter_apks() {
    # shaves ~10 MiB when going from virt to just alpine-base;
    # reduces the on-disk apk selection
    cd; rm -rf x; mkdir x; cd x
    [ $1 = -w ] && shift || 
        grep -vE 'https?://' </etc/apk/repositories >r
    
    apk fetch --repositories-file=r -R "$@"

    rm /mnt/apks/*/*.apk
    mv *.apk /mnt/apks/*/
    cd; rm -rf x
}

imshrink_nosig() {
    # shaves ~1 MiB lol
    # remove modloop signature from initramfs to avoid pulling in openssl
    # (bonus: zstd produces a smaller initramfs)
    apk add zstd xz
    cd; mkdir x; cd x
    f=$(echo /mnt/boot/initramfs-*)
    echo unpacking initramfs
    gzip -d < $f | cpio -idm
    rm -f var/cache/misc/modloop-*.SIGN.RSA.*
    echo repacking initramfs
    # https://github.com/alpinelinux/mkinitfs/blob/a5f05c98f690d95374b69ae5405052b250305fdf/mkinitfs.in#L177
    umask 0077
    comp="xz -C crc32 -T 0"  #     <-- 320k smaller, but
    comp="zstd -19 -T0 --long"  #  <-- faster decompression
    find . | sort | cpio --quiet --renumber-inodes -o -H newc | $comp > $f
}

##
########################################################################


#recommended_apks
#rshell 192.168.122.1
#party


# chainload profile-specific steps
f=$AR/sm/img/sm/post-build-2.sh
[ ! -e $f ] || . $f
