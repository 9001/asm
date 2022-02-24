#!/bin/bash
# asm-example @ https://github.com/9001/asm/blob/hovudstraum/sm/asm.sh
set -e

# static ip (for [n]etwork -> [s]tatic)
ip=10.1.2.51
mask=24

# sshd root password
pw=k

# the demo menu
menu() {
	unlog
	cat <<EOF

choose a demo:
  1) select local hdd
  i) collect hardware info
  n) start network + sshd
  z) exit 0 /success
  x) exit 1 /error
  k) shutdown
  r) reboot
EOF
	read -u1 -n1 -rp 'sel> '
	printf '\n\n'
	case $REPLY in
		1) disksel;;
		i) infograb;;
		n) menu_net;;
		z) exit 0;;
		x) exit 1;;
		k) poweroff; exit 0;;
		r) reboot; exit 0;;
		*) menu;;
	esac
}

# networking menu
menu_net() {
	read i1 i2 < <(echo $ip | sed -r 's/(.*)\./\1 /')
	cat <<EOF

choose ip address:
  d) dynamic / dhcp
  s) static, starting from $i1.$i2
EOF
	read -u1 -n1 -rp 'sel> '
	printf '\n\n'
	case $REPLY in
		s) ip l set lo up
			(. /lib/libalpine.sh; available_ifaces) | tr ' ' '\n' |
			while read dev; do
				[ $dev = lo ] && continue
				ip=$i1.$i2
				i2=$((i2+1))
				ip l set $dev up
				ip a a $ip/$mask dev $dev
				echo $dev = $ip /$mask
			done;;
		d) yes '' | setup-interfaces -r;;
		*) menu_net; return;;
	esac
	echo
	apk add -q openssh-server
	sed -ri 's/(Subsystem[^/]+sftp).*/\1 internal-sftp/' /etc/ssh/sshd_config
	keyfile=$AR/sm/authorized_keys
	if [ -e $keyfile ]; then
		log allowing $(grep ssh- $keyfile | wc -l) ssh-keys from $keyfile
		mkdir -p ~/.ssh
		cp -pv $keyfile ~/.ssh
	else
		log allowing auth using hardcoded password
		sed -ri '$aPermitRootLogin yes' /etc/ssh/sshd_config
		printf '%s\n' "$pw" "$pw" | passwd >/dev/null
	fi
	service sshd start
	menu
}

# list local HDDs and ask for a target
disksel() {
	lsblk; echo
	blkid | sort; echo

	disks="$(lsblk -bo SIZE,KNAME,SUBSYSTEMS,TYPE |
		awk 'NR>1 && !/:usb/ && $1 && / disk$/ && $2!="'$AD'" {print$2}')"

	[ -z "$disks" ] && {
		echo no harddrives found, cannot continue
		exit 1
	}

	log select target harddisk
	printf '%s\n' "$disks" | cat -n
	while true; do
		read -u1 -n1 -rp 'number> '
		echo
		[ "$REPLY" = x ] && exit 1
		disk="$(printf '%s\n' "$disks" | awk NR==$REPLY)"
		[ -z "$disk" ] || break
	done

	echo using disk $disk
	menu
}

# collect and store some hardware info
infograb() {
	apk add pciutils usbutils
	apk add coreutils || true
	apkf add $AR/sm/eapk/{dmidecode,lshw,smartmontools}-*.apk || true
	# note; blank cmd = commit to usb (since lspci -xxxx can crash the box)
	local cmds=(
		dmesg "dmesg --color=always" blkid "free -m" "uname -a"
		lsblk lscpu lshw lsipc lsirq lsmod fbset
		lsusb "lsusb -v" "lsusb -tvvv" "stdbuf -o0 -e0 lsusb -v 2>&1"
		lspci "lspci -nnP" "lspci -nnPP" "lspci -nnvvv"
		"lspci -bnnvvv" "lspci -mmnn" "lspci -mmnnvvv"
		dmidecode "dmidecode -u"
	)

	while IFS= read -r x; do
		cmds+=("smartctl -x /dev/$x")
	done < <(lsblk -bo SIZE,KNAME,SUBSYSTEMS,TYPE |
		awk 'NR>1 && !/:usb/ && $1 && / disk$/ {print$2}')

	cmds+=("" "lspci -mmnnvvvxxxx" "")

	local d=$AR/sm/infos/$(utime)
	read -u1 -rp 'optional-comment> '
	echo
	[ "$REPLY" ] && d="$d-$REPLY"
	rm -rf grab
	mkdir grab
	pushd grab
	for cmd in "${cmds[@]}"; do
		[ -z "$cmd" ] && {
			mount -o remount,rw $AR
			[ -e "$d" ] || {
				mkdir -p "$d"
				echo "$d" >> "$d/../log"
			}
			mv * "$d/"
			sync
			mount -o remount,ro $AR
			continue
		}
		log "running $cmd"
		local fn="$(printf '%s\n' "$cmd" | tr -s ' -./=&<>' -)"
		(eval "$cmd") >"$fn" || echo "CMD FAILED: $cmd => $?" | tee -a "$fn"
	done
	popd
	log info collected to "$d"
	menu
}

menu
