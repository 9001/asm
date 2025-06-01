#!/bin/bash
set -e

printf '\033[J'

ESC=$'\033'
CYAN="$ESC[36m"
PRPL="$ESC[35m"
B1="$ESC[1m"
B0="$ESC[22m"
RST="$ESC[0m"

enbri() { printf '%s\n' "$1" | sed -r "s/\[(.)\]/$B1\1$B0/g"; }
ask1() { read -u1 -n1 -rp "$CYAN$1$RST" $2 && echo; }
ask1b() { read -u1 -n1 -rp "$CYAN$(enbri "$1")$RST" $2 && echo; }
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



ask_hwinfo() {
	ask_yn "write hardware-info to USB flashdrive? y/n> " || return 0
	printf "\nyou can include a comment for this infodump, or just hit enter:\n\n"
	read_hwinfo; echo
	beeps 20 784 0 0 1047 &
}



ask_exit() {
	while true; do
		ask1b "end of program.  [p]oweroff, [r]eboot, e[x]it?  p/r/x> "
		case $REPLY in
			P|p) poweroff; exit 0;;
			R|r) reboot; exit 0;;
			X|x) break;;
		esac
	done
	echo "okay, run the command 'poweroff' when you're done"
	exec /bin/bash -l
}



# intel-uhd-graphics <700 doesn't render past 3840x2117
(fbset 2>&1) | awk '$1=="geometry" && $4>2560 && $5>1920 {r=1} END {exit r-1}' && fbset -xres 2560 -yres 1920

# max screen brightness
bri 100 &

# if /sm/tty.cfg exists, launch consoles on each tty listed inside
ttycons

test_apic
ask_hwinfo
ask_exit
