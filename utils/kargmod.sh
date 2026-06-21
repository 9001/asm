#!/bin/bash
set -e

# modify a stock alpine iso by adding kernel args; 20 chars or less
#
# WARNING: propagates into build output

iso="$1"
add="$2"
t="$iso.t"

# find+grab boot/syslinux/syslinux.cfg
lba=$(grep -ba '^MENU LABEL ' "$iso" | awk -F: '{print int($1/2048);t++}END{exit t-1}')
dd if="$iso" bs=2048 count=1 skip=$lba 2>/dev/null | tr -d '\0' >"$t.1"
grep -qE '^KERNEL ' "$t.1"  # assert

# carve space, add args, pad
sed -r '/^MENU LABEL /d;s/^(APPEND.*[^ ]) *$/\1 '"$add /" <"$t.1" >"$t.2"
printf "%$(( $(wc -c <"$t.1") - $(wc -c <"$t.2") -1 ))s\n" '' >>"$t.2"
[ $(wc -c <"$t.1") -eq $(wc -c <"$t.2") ]  # assert

dd if="$t.2" of="$iso" bs=2048 count=1 conv=notrunc seek=$lba 2>/dev/null
diff -U0 "$t.1" "$t.2" | tail -n+3
rm "$iso".t*
