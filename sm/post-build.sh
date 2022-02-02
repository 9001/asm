# example post-build step;  download extra APKs

fetch_apks() {
    sed -ri 's/"1fhr"/"c1fhr"/' /sbin/setup-apkrepos  # backport bugfix
    grep -q /v$IVER/community /etc/apk/repositories || {
        (sed -r 's/^https/http/' | tee -a /etc/apk/repositories) <<EOF
$MIRROR/v$IVER/main
$MIRROR/v$IVER/community
EOF
        apk update
    }
    cd /mnt/apks/*
    ls -1 >.a
    apk fetch -R "$@"
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
# another example; pops a reverse shell in the build env
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
# :^)

party() {
    mkdir -p /mnt/sm/bin
    cd /mnt/sm/bin
    wget https://github.com/9001/r0c/releases/latest/download/r0c.py \
        https://github.com/9001/copyparty/releases/latest/download/copyparty-sfx.py \
        https://github.com/9001/copyparty/raw/hovudstraum/bin/up2k.py \
        https://github.com/9001/copyparty/raw/hovudstraum/bin/copyparty-fuse.py
}


#recommended_apks
#rshell 192.168.122.1
#party


# chainload profile-specific steps
f=$AR/sm/img/sm/post-build-2.sh
[ ! -e $f ] || . $f
