#!/bin/bash
set -e

# static ip (for [n]etwork -> [s]tatic)
ip=10.1.2.51
mask=24

# but we don't want static networking, so set it blank to enable dhcp
ip=

# sshd root password
pw=k

# screen orientation/rotation (0/1/2/3)
rot=0

. /etc/profile.d/miniparty.sh

[ $IVER = 3.10 ] && a310=1 || a310=

ESC=$'\033'
CYAN="$ESC[36m"
PRPL="$ESC[35m"
B1="$ESC[1m"
B0="$ESC[22m"
RST="$ESC[0m"

enbri() { printf '%s\n' "$1" | sed -r "s/\[(.)\]/$B1\1$B0/g"; }
ask() { read -u1 -rp "$CYAN$1$RST" $2; }
ask1() { read -u1 -n1 -rp "$CYAN$1$RST" $2 && echo; }
ask1b() { read -u1 -n1 -rp "$CYAN$(enbri "$1")$RST" $2 && echo; }
mcat() { printf "\n$CYAN%79s$RST\n\033[A"|tr ' ' -; sed -r 's/$/ /;s/( )([a-zA-Z0-9])(\) )/\1'$CYAN'\2'$RST'\3/g'; }


setup_tmux() {
	tmux new -s 0 -d 2>/dev/null || true
	for n in {1..4}; do tmux neww -t 0:$n 2>/dev/null || true; done
	tmux killw -t 0:$1 2>/dev/null || true
	tmux neww -t 0:$1 -n $2
	tmux selectw -t 0:$1
	sleep 0.1  # cosmetic: bash init
}


get_ip() {
	ip r | awk '/src /{print$NF;exit}'
}


rotate() {
	[ $rot -ge 3 ] && rot=0 || rot=$((rot+1))
	printf '\033[A'
	rot $rot
}


maybe_mkpart() {
	local bfree=$(
		lsblk -bnro NAME,SIZE /dev/$AD |
		awk -v d=$AD '
			NR==1&&$1==d{a=$2}
			NR==2&&$1==d"1"{b=$2}
			a&&b{v=int((a-b)/(1024*1024*1024))}
			NR>2&&$2{a=0;v=0}
			END{if(v)print v} ')
	[ $bfree ] || return 0

	echo "there is $bfree GiB unused space on the flashdrive,"
	while true; do
		ask1 'add 2nd partition for data (recommended)? y/n> '
		case $REPLY in
			y) break;;
			n) return 0;;
		esac
	done

	cat <<EOF

choose a filesystem for the 2nd partition;
$PRPL${B1} ntfs:$RST possible to corrupt by powerloss or unsafe flashdrive removal
$PRPL${B1}fat32:$RST even easier to corrupt, and max filesize is 4 GiB
$PRPL${B1} ext4:$RST almost impossible to corrupt, but only works on linux/mac
$PRPL${B1}btrfs:$RST also detects data-corruption, but no support on win/mac/rhel

note that there are two different types of corruption to consider:
$PRPL${B1}FILESYSTEM-CORRUPTION:$RST loss of entire files, or the entire filesystem,
$PRPL${B1}                  \`--:$RST or making it impossible to create new files
$PRPL${B1}DATA-CORRUPTION:$RST bitflips inside files; almost no filesystems care or notice

these filesystems can detect data-corruption:$ESC[32m btrfs, zfs, bcachefs $RST

recommendations:
  4 (ext4) for linux
  n (ntfs) for cross-platform
EOF

	local fs= pkg= ptype=
	while true; do
		ask1b '[n]tfs, [f]at32, e[x]fat, ext[4], [b]trfs?  n/f/x/4/b> '
		case $REPLY in
			n) ptype=07; fs=ntfs; pkg=ntfs-3g-progs; break;;
			f) ptype=0c; fs=vfat; pkg=dosfstools; break;;
			4) ptype=83; fs=ext4; pkg=e2fsprogs; break;;
			b) ptype=83; fs=btrf; pkg=btrfs-progs; break;;
		esac
	done

	[ $a310 ] &&
		pkgs="sfdisk util-linux" ||
		pkgs="sfdisk partx"
	apka -q $pkgs $pkg
	echo ,,$ptype | sfdisk --no-reread --no-tell-kernel -w never -W never -q -a /dev/$AD
	local d2=/dev/${AD}2
	while [ ! -e $d2 ]; do
		echo waiting for $d2 ...
		partx -a /dev/$AD 2>/dev/null || true
		sleep 0.5; mdev -s; sleep 0.5
	done

	local wipe=1 cmd=
	blkid $d2 | grep TYPE= &&
		while true; do
			ask1 'found existing filesystem!  Wipe or Keep?  w/k> '
			case $REPLY in
				w) break;;
				k) wipe=; break;;
			esac
		done

	[ $wipe ] && {
		echo "doing a blkdiscard on $d2 ... don't worry if this fails:"
		blkdiscard -f $d2 &&
			printf "\033[32mblkdiscard was successful?! nice$RST\n" ||
			printf "\033[33mblkdiscard failed, okay, yeah, whatever$RST\n"

		case $fs in
			ntfs) mkfs.ntfs -fL HUB_DATA $d2;;
			vfat) mkfs.vfat -F32 -n HUB_DATA $d2;;
			ext4) mkfs.ext4 -FT big -L HUB_DATA $d2;;
			btrf) mkfs.btrfs -fKL HUB_DATA $d2;;
		esac
		return 0
	}

	case $fs in
		ntfs) ntfslabel -f $d2 HUB_DATA;;
		vfat) dosfslabel $d2 HUB_DATA;;
		ext4) e2label $d2 HUB_DATA;;
		btrf) btrfs fi label $d2 HUB_DATA;;
	esac
}


menu_net() {
	rm -f /etc/network/interfaces
	read i1 i2 < <(echo $ip | sed -r 's/(.*)\./\1 /')
	case $ip in
		*.*) ip l set lo up
			( . /usr/lib/libalpine.sh || . /lib/libalpine.sh
				available_ifaces ) | tr ' ' '\n' |
			while read dev; do
				[ "$dev" ] || { echo "WARNING: no compatible network hardware found"; break; }
				[ $dev = lo ] && continue
				local ip=$i1.$i2
				i2=$((i2+1))
				ip l set $dev up
				ip a a $ip/$mask dev $dev
				echo $dev = $ip /$mask
			done;;
		*)
			(sleep 1; rm -f /tmp/setup-interfaces*/w*.noconf) &
			printf 'autoconfiguring, pls wait... \033[1;30m'
			yes '' | setup-interfaces; printf '\033[0m'
			service -q networking restart;;
	esac

	x="$(get_ip)"
	[ $x ] && {
		log "ip: $x"
		start_r0c
		return
	}
	echo
	echo "failed to obtain ip from dhcp; do you want to specify ip manually?"
	echo "hint: just press Enter to autoselect a linklocal ip to use instead"
	read -u1 -rp "ip> " ip
	[ -z $ip ] && mask=16 && ip=169.254.$((1+RANDOM%254)).$((1+RANDOM%240))
	ip=$(echo $ip | sed -r 's/[^0-9.].*//')
	menu_net
}


start_r0c() {
	# start r0c in tmux so ^C wont affect it
	pkgs=(python3 tmux openssh)
	[ $a310 ] &&
		pkgs+=(iproute2) ||
		pkgs+=(iproute2-minimal)
	apka -q !pyc "${pkgs[@]}"
	r0c --help 2>/dev/null >/dev/null
	setup_tmux 2 r0c
	tmux pipe-pane -t 0:2 -o "exec tee /dev/shm/conlog >>$(tty)"
	tmux send -t 0:2 "tps1; r0c --ara -pw $(base64 /dev/urandom | tr -dc a-z | head -c9)" ENTER
	while sleep 0.1; do grep -qF 'r0c is up' /dev/shm/conlog && break; done
	tmux pipe-pane -t 0:2
}


start_ssh() {
	echo
	apk add -q openssh-server
	sed -ri 's/(Subsystem[^/]+sftp).*/\1 internal-sftp/' /etc/ssh/sshd_config
	keyfile=$AF/sm/authorized_keys
	if [ -e $keyfile ]; then
		log allowing $(grep ssh- $keyfile | wc -l) ssh-keys from $keyfile
		mkdir -p ~/.ssh
		cp -pv $keyfile ~/.ssh
	else
		awk '/^$/&&!o{print"The root password is '\'k\''";o=1}1' /etc/issue>/tf;mv /tf /etc/issue
		sed -ri '$aPermitRootLogin yes' /etc/ssh/sshd_config
		printf '%s\n' "$pw" "$pw" | passwd >/dev/null
		killall getty || true
	fi
	service sshd start
	local ip=$(get_ip)
	[ $ip ] &&
		log "ssh root@$ip (password is 'k')" || true
}


party() {
	[ -e /root/.r0c ] || {
		echo error: start network first
		return
	}
	local f= n= v= ds= pid= args= uname= acct=
	if ps aux | grep -q 'rty-sfx\.py'; then
		tmux selectw -t 0:1
		tmux a -t 0
		return
	fi

	pkgs=(tmux python3 btrfs-progs e2fsprogs xfsprogs dosfstools ntfs-3g ntfs-3g-progs)

	# 2x faster download-as-zip, 2x more ram usage in general
	#echo $IVER | grep -E '^3\.1[0-6]' || pkgs+=(mimalloc2)

	apka !pyc "${pkgs[@]}" $v
	apka !pyc py3-pillow

	# choose one of these to uncomment:
	e2d='-e2d'  # index uploads only (makes them resumable and searchable)
	#e2d='-e2dsa'  # scan all disks and index all files within
	#e2d='--no-snap --hist /dev/shm'  # disable all indexing

	echo
	uname=
	f=$AF/sm/copyparty.conf
	grep -qE '^[^#]*\[accounts' $f &&
		echo "password enabled in $f" && uname=,u ||
		echo "password NOT enabled in $f (anonymous access is allowed)"

	# choose one of these to uncomment:
	axs='A'  # read-write-move-delete
	#axs='rw'  # read-write
	#axs='r'  # read-only

	[ -e /usr/bin/fsck.ntfs ] || { f=$(command -v ntfsfix); [ $f ] && ln -s $f /usr/bin/fsck.ntfs; }

	blkid -ovalue -sTYPE | grep -q LVM && {
		echo "found LVM disk; unboxing..."
		apka -q lvm2 && vgchange -ay ||
			printf '\033[1;33mfailed to read LVM; some partitions will not be available\033[0m\n'
	}

	echo scanning filesystems...
	[ $ds ] && hdr=stderr || hdr=null
	lsblk -o SIZE,KNAME,SUBSYSTEMS,TYPE,FSTYPE,LABEL | awk '
		NR==1 {print" disk#  "$0>"/dev/'$hdr'";next}
		$1!="0B" && / (disk|part|lvm) +[^ ]/ && $2!="'$AD'"
	' >/dev/shm/harddiskar

	grep -qE .. /dev/shm/harddiskar || {
		echo "no disks detected! will only share files from cdrom"
		ds=
	}
	mv /dev/shm/harddiskar /dev/shm/utvalg

	local d= fs= rc=
	rmdir /media/* 2>/dev/null || true
	awk '{print$2,$5,$6}' /dev/shm/utvalg | while read -r d fs label; do
		grep -qE "^/dev/$d " /proc/mounts && continue
		echo $fs | grep -qiE '^(swap|lvm)' && continue
		[ $axs = r ] || {
			# mounting read/write; do fsck
			#fs=$(blkid -ovalue -sTYPE /dev/$d)
			local c=
			case $fs in
				ntfs) c="fsck.$fs";;
				vfat) c="fsck.$fs -a";;
				ext*) c="fsck.$fs -p";;
			esac
			[ "$c" ] && {
				printf '\033[36m# %s %s (%s)\033[0m ' "$c" $d $fs &&
				$c /dev/$d </dev/null && rc=0 || rc=$?
				case $rc in
					0) c='2m `--filesystem-check OK';;
					1) c='3m `--found and repaired fs errors';;
					*) c='1m `--ERROR '$rc', FILESYSTEM CORRUPT? (see text above)';;
				esac
				printf '\033[3%s\033[0m\n' "$c"
			}
		}
		# if no fs-label, use lvm name
		[ "$label" ] || {
			label="$(lsblk -no NAME /dev/$d)"
			[ "$label" = $d ] && label=
		}
		# /media/{devname}_{label}_{fstype}
		local mp="$(printf '%s_%s_%s' $d "$label" $fs | tr -sc '[:alnum:]-' _)"
		echo "$d" | grep -qE "^$AD" && mp=$d  # no label for bootdisk
		mkdir /media/$mp 2>/dev/null &&
		mount /dev/$d /media/$mp || true
	done

	rmdir /media/* 2>/dev/null || true

	args=(
		"--cert $AF/sm/tls-cert.pem"
		$e2d
	)

	# if bootdisk has a 2nd partition (HUB_DATA) then make that
	# XDG_CONFIG_HOME so it gets all the databases, thumbnails &
	# statefiles, keeping the other disks/filesystems mostly clean
	#  (boy i sure hope your flashdrive is of the faster kind)
	xch=/root/
	local md2=/media/${AD}2
	[ -e $md2 ] && {
		xch=$md2/copyparty-state &&
		args+=("--hist $xch/hists")

		# also use this as the persistent r0c-logs location
		grep -qF /root/.r0c /proc/mounts || {
			local pr0c=$md2/r0c-state
			mkdir -p $pr0c
			tar -cC/root/.r0c . | tar -xC $pr0c
			mount --bind $pr0c /root/.r0c
		}
	}

	# map /media to /usb so usb-eject works
	args+=("-v /media:/usb:$axs$uname")
	for v in /media/*; do
		local blkdev=${v:7}
		[ $v = $AF ] && {
			[ $axs != r ] && [ $AD != sr0 ] &&
				chkbootfs && mount -o remount,rw $AF &&
					args+=("-v $v:/usb/$blkdev:$axs$uname:c,fat32") ||  # r/w ok
					args+=("-v $v:/usb/$blkdev:r$uname::c,hist=/.h.$AD")  # iso?

			args+=("-v $v/sm:/usb/$blkdev/sm:c,d2d")  # block access to /sm
			continue
		}
		[ -e "$v" ] && args+=("-v $v:/usb/$blkdev:$axs$uname")
	done

	printf '\nwill run copyparty with the following args:\n'
	printf '  %s\n' "${args[@]}"
	#printf 'press any key to confirm  -or-  press CTRL-C to abort\n'
	#read -n1 -u1
	sleep 1

	cat >/partycmd <<EOF
set -x
tmux set -g status-right "#(ip r | awk '/src /{print\\\$NF;exit}'), #(battery) %Y-%m-%d, %H:%M:%S"
sed -r 's/\{hub\}/$AD/g' <$AF/sm/copyparty.conf >/dev/shm/cpp.cfg
LD_PRELOAD=/usr/lib/libmimalloc-secure.so.2 \
XDG_CONFIG_HOME=$xch python3 $AF/kit/copyparty-sfx.py \
	-c /dev/shm/cpp.cfg \
	${args[@]} || true
EOF

	setup_tmux 1 cpp
	tmux send -t 0:1 "tps1; /bin/bash /partycmd" ENTER
	tmux a -t 0
}

# intel-uhd-graphics <700 doesn't render past 3840x2117
(fbset 2>&1) | awk '$1=="geometry" && $4>2560 && $5>1920 {r=1} END {exit r-1}' && fbset -xres 2560 -yres 1920

f=/dev/shm/.hub.init
[ -e $f ] || {
	touch $f

# force ntfs-3g (less buggy)
echo blacklist ntfs3 >/etc/modprobe.d/no-ntfs3.conf

# rotate display orientation (requires kms/modeset)
[ $rot = 0 ] || rot $rot

# if /sm/tty.cfg exists, launch consoles on each tty listed inside
ttycons

# create a 2nd partition to fill free space
maybe_mkpart

}

echo "will now autostart copyparty and r0c;"
echo "press CTRL-C within 1sec to abort ..."
sleep 1

menu_net
start_ssh
party
