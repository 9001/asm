#!/bin/bash
# asm profile example @ https://github.com/9001/asm/blob/hovudstraum/p/dban/sm/asm.sh
set -e

apk add openssl pv

log shredding disks ...
while IFS= read -r disk; do
    command -v pv >/dev/null && pv="pv -cN $disk" || pv=cat
    k="$(head -c32 /dev/urandom | base64 -w0)"
    (
        c="blkdiscard /dev/$disk"
        $c && echo "$c succeeded #wow #whoa" || echo "$c failed, whatever, doing a full wipe anyways"
        openssl enc -aes-256-ctr -iter 1 -pass pass:"$k" -nosalt </dev/zero | $pv >/dev/$disk
    ) &
done < <(
    lsblk -bo SIZE,KNAME,SUBSYSTEMS,TYPE |
    awk 'NR>1 && !/:usb/ && $1 && / disk$/ && $2!="'$AD'" {print$2}'
)

echo waiting for all disks to finish shredding...

# if pv is not available, show progress manually
command -v pv >/dev/null || while true; do
    jobs | grep -qE . || break
    ps a | awk '/ cat$/{print$1}' | while IFS= read -r x; do
        printf "%s: %d bytes done\n" \
            $(readlink /proc/$x/fd/1) \
            $(awk 'NR==1{print$2}' /proc/$x/fdinfo/1)
    done
    echo
    sleep 10
done

wait
log all done -- shutting down
sync
poweroff
