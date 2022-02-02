# example post-build step;  download extra APKs

eapks() {
    setup-interfaces -ar
    sed -ri 's/"1fhr"/"c1fhr"/' /sbin/setup-apkrepos  # backport bugfix
    #sed -ri 's`^(MIRRORS_URL=).*`\1http://192.168.122.1:3923/am/mirrors.txt`' /sbin/setup-apkrepos  # proxy
    #setup-apkrepos -1c
    (sed -r 's/^https/http/' | tee -a /etc/apk/repositories) <<EOF
$MIRROR/v$IVER/main
$MIRROR/v$IVER/community
EOF
    apk update
    
    cd /mnt/apks/*
    ls -1 >.a
    apk fetch -R \
        bzip2 gzip pigz zstd \
        aria2 bmon fuse fuse3 iperf3 nmap-ncat proxychains-ng sshfs sshpass \
        dmidecode lshw smartmontools sgdisk testdisk \
        ntfs-3g ntfs-3g-progs exfatprogs \
        bc file findutils grep jq less mc ncdu pv psmisc sqlite \
        py3-jinja2 py3-requests ranger

    mkdir /mnt/sm/eapk
    (ls -1; cat .a) | sort | uniq -c | awk '$1<2{print$2}' |
        while read -r x; do mv "$x" /mnt/sm/eapk/; done
    rm .a
}


##
# another example; pops a reverse shell in the build env
#
# replace the ip with one of your host IPs and start listening:
#   ncat -lvp 4321
# or better yet,
#   socat file:$(tty),raw,echo=0 tcp-l:4321

rshell() {
    i=192.168.122.1
    setup-interfaces -ar
    # bash -i >&/dev/tcp/$i/4321 0>&1
    apk add socat
    socat exec:'/bin/bash -li',pty,stderr,setsid,sigint,sane tcp:$i:4321,connect-timeout=1
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


#eapks
#rshell
#party
