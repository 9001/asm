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
		k) beeps ok; poweroff; exit 0;;
		r) beeps ok; reboot; exit 0;;
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
			( . /usr/lib/libalpine.sh || . /lib/libalpine.sh
				available_ifaces ) | tr ' ' '\n' |
			while read dev; do
				[ $dev = lo ] && continue
				local ip=$i1.$i2
				i2=$((i2+1))
				ip l set $dev up
				ip a a $ip/$mask dev $dev
				echo $dev = $ip /$mask
			done;;
		d) (sleep 1; rm -f /tmp/setup-interfaces*/w*.noconf) &
			yes '' | setup-interfaces 
			service -q networking restart;;
		*) menu_net; return;;
	esac
	echo
	apk add -q openssh-server
	sed -ri 's/(Subsystem[^/-]+sftp).*/\1 internal-sftp/' /etc/ssh/sshd_config
	keyfile=$AF/sm/authorized_keys
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
	hwscan $AF/sm/infos  # '' 3

	touch $AF/sm/infos 2>/dev/null || fs_ro=1

	apka -q python3 !pyc && (
		cd /dev/shm
		rm -f hw-inv.*

		# html: recommended (readable by libreoffice-calc)
		# json: recommended (enables caching)
		# txt/csv: indifferent; no particular usecase
		hwinv $AF/sm/infos \
			--txt=hw-inv.txt \
			--csv=hw-inv.csv \
			--html=hw-inv.html \
			--json=hw-inv.json \
			--cache=$AF/sm/infos/hw-inv.json

		[ $fs_ro ] && mount -o remount,rw $AF
		mv hw-inv.* $AF/sm/infos/

		mkdir -p $AF/sm/bin
		for p in hwinv hwscan; do
			cp -npv $(which $p) $AF/sm/bin/$p 2>/dev/null || true
		done

		p=$AF/sm/infos/dmesg-cln.sh
		[ -e $p ] || cat >$p <<'EOF'
#!/bin/bash
# strip timestamps from dmesg
find -iname dmesg\* | grep -E 'dmesg(-color-always)?$' | while IFS= read -r f; do
[ -e "$f.n" ] || sed -r 's/^(.\[32m)?\[[ 0-9\.]+\] /\1» /' <"$f" >"$f.n"; done
EOF
	)

	[ $fs_ro ] && mount -o remount,ro $AF
	menu
}

# clear bootloader status message ("plain exec")
printf '\033[K'

# intel-uhd-graphics <700 doesn't render past 3840x2117
(fbset 2>&1) | awk '$1=="geometry" && $4>2560 && $5>1920 {r=1} END {exit r-1}' && fbset -xres 2560 -yres 1920

# max screen brightness
bri 100 &

# portrait display rotation (requires kms/modeset)
#rot 3

# if /sm/tty.cfg exists, launch consoles on each tty listed inside
ttycons

menu
