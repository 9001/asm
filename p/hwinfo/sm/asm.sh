#!/bin/bash
set -e

printf '\033[J'

ESC=$'\033'
CYAN="$ESC[36m"
PRPL="$ESC[35m"
B1="$ESC[1m"
B0="$ESC[22m"
RST="$ESC[0m"

ask1() { read -u1 -n1 -rp "$CYAN$1$RST" $2 && echo; }
ask_yn() {
	while true; do
		ask1 "$1"
		case $REPLY in
			Y|y) return 0;;
			N|n) return 1;;
		esac
	done
}



read_hwinfo() {
    hwscan $AF/infos
	#return  # don't generate html listing

	touch $AF/infos 2>/dev/null || fs_ro=1
	apka -q python3 !pyc && (
		cd /dev/shm
		rm -f hw-inv.*
		hwinv $AF/infos \
			--txt=hw-inv.txt \
			--csv=hw-inv.csv \
			--html=hw-inv.html \
			--json=hw-inv.json \
			--cache=$AF/infos/hw-inv.json

		[ $fs_ro ] && mount -o remount,rw $AF
		mv hw-inv.* $AF/infos/
	)
	[ $fs_ro ] && mount -o remount,ro $AF
}



test_apic() {
	n=$(nproc)
	[ $n = 1 ] && 
		t="1mWARNING: there's only one active CPU core; APIC is broken" ||
		t="2mGood; there are $n active CPU-cores; APIC appears to be fine"
	printf '%s\n' "" "$ESC[1;3$t$RST" ""
}



# intel-uhd-graphics <700 doesn't render past 3840x2117
(fbset 2>&1) | awk '$1=="geometry" && $4>2560 && $5>1920 {r=1} END {exit r-1}' && fbset -xres 2560 -yres 1920

# if /sm/tty.cfg exists, launch consoles on each tty listed inside
ttycons

test_apic

ask_yn "write hardware-info to USB flashdrive? y/n> " && read_hwinfo && echo

ask_yn "shutdown? y/n> " && poweroff && exit 0

echo "okay, just run the command 'poweroff' when you're done"
/bin/bash -l || true
