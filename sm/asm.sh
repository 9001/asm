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
  i) static, starting from $i1.N
EOF
	read -u1 -n1 -rp 'sel> '
	echo
	echo $REPLY | grep -q i && {
		read -u1 -rp "$i1.?> " i2
		REPLY=s
	}
	echo
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
		d) (sleep 1; rm -f /tmp/setup-interfaces*/w*.noconf) &
			yes '' | setup-interfaces -r;;
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
	# to timeout the comment prompt after 3 sec, uncomment the '' 3
	hwscan $AR/sm/infos  # '' 3

	touch $AR/sm/infos 2>/dev/null || fs_ro=1

	apka -q python3 !pyc && (
		cd /dev/shm
		rm -f hw-inv.*

		# html: recommended (readable by libreoffice-calc)
		# json: recommended (enables caching)
		# txt/csv: indifferent; no particular usecase
		hwinv $AR/sm/infos \
			--txt=hw-inv.txt \
			--csv=hw-inv.csv \
			--html=hw-inv.html \
			--json=hw-inv.json \
			--cache=$AR/sm/infos/hw-inv.json

		[ $fs_ro ] && mount -o remount,rw $AR
		mv hw-inv.* $AR/sm/infos/

		mkdir -p $AR/sm/bin
		for p in hwinv hwscan; do
			cp -npv $(which $p) $AR/sm/bin/$p 2>/dev/null || true
		done
	)

	[ $fs_ro ] && mount -o remount,ro $AR
	menu
}

# intel-uhd-graphics <700 doesn't render past 3840x2117
(fbset 2>&1) | awk '$1=="geometry" && $4>2560 && $5>1920 {r=1} END {exit r-1}' && fbset -xres 2560 -yres 1920

# portrait display rotation (requires kvm)
#echo 3 > /sys/class/graphics/fbcon/rotate_all

menu
