#!/bin/bash
set -e

# static ip (for [n]etwork -> [s]tatic)
ip=10.1.2.51
mask=24

# sshd root password
pw=k

# screen orientation/rotation (0/1/2/3)
rot=0

. /etc/profile.d/hub.sh

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

quiet() { touch /dev/shm/nobeep; }
fbeep() { rm -f /dev/shm/nobeep; beeps $*; }


mainmenu() {
	while true; do

		# reapply colorsheme just in case
		. /etc/profile.d/bifrost.sh

		[ $nolm ] || mcat <<EOF
choose next action: $CYAN-------------$RST o) rotate
  n) start network + r0c          f) font
  c) copyparty (choose n first)   a) tmux
  s) start ssh-server (needs n)   v) verify
  i) collect hardware info        k) shutdown
  x) exit to shell                r) reboot
EOF
		nolm=
		t1=$(date +%s)
		read -u1 -n1 -rp $CYAN'sel> '$RST
		unlog; echo
		case $REPLY in
			N|n) menu_net;;
			C|c) party;;
			S|s) start_ssh;;
			I|i) infograb;;
			X|x) quiet; echo '(return by saying "menu")'; /bin/bash -l; exit 0;;
			G|g) menu_games;;
			O|o) nolm=1; rotate;;
			F|f) menu_font;;
			A|a) tmux a -t 0 || echo 'error: start r0c or copyparty first';;
			V|v) verify;;
			K|k) fbeep ok; poweroff; exit 0;;
			R|r) fbeep ok; reboot; exit 0;;
		esac
		fbeep ack
	done
}


setup_tmux() {
	tmux new -s 0 -d 2>/dev/null || true
	for n in {1..4}; do tmux neww -t 0:$n 2>/dev/null || true; done
	tmux killw -t 0:$1 2>/dev/null || true
	tmux neww -t 0:$1 -n $2
	tmux selectw -t 0:$1
	sleep 0.1  # cosmetic: bash init
}


showmotd() {
	printf '\033[s\033[2H'; cat /etc/motd
	printf '\033[1;999H\033[2D   \033[u\033[?7h'
	chvt 2; chvt 1
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
$PRPL${B1}exfat:$RST easier to corrupt than ntfs, but slightly faster
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
			x) ptype=07; fs=xfat; pkg=exfatprogs; break;;
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
			xfat) mkfs.exfat -L HUB_DATA $d2;;
			ext4) mkfs.ext4 -FT big -L HUB_DATA $d2;;
			btrf) mkfs.btrfs -fKL HUB_DATA $d2;;
		esac
		return 0
	}

	case $fs in
		ntfs) ntfslabel -f $d2 HUB_DATA;;
		vfat) dosfslabel $d2 HUB_DATA;;
		xfat) tune.exfat $d2 HUB_DATA;;
		ext4) e2label $d2 HUB_DATA;;
		btrf) btrfs fi label $d2 HUB_DATA;;
	esac
}


menu_net() {
	read i1 i2 < <(echo $ip | sed -r 's/(.*)\./\1 /')
	mcat <<EOF
choose ip address:
  d) dynamic / dhcp
  s) static, starting from $i1.$i2
  i) static, starting from $i1.N
  w) wifi and/or advanced
EOF
	ask1 'sel> '
	echo $REPLY | grep -q i && {
		ask "$i1.?> " i2
		REPLY=s
	}
	echo
	case $REPLY in
		S|s) ip l set lo up
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
		D|d)
			(sleep 1; rm -f /tmp/setup-interfaces*/w*.noconf) &
			printf 'autoconfiguring, pls wait... \033[1;30m'
			yes '' | setup-interfaces; printf '\033[0m'
			service -q networking restart;;
		W|w) setup-interfaces -r;;
		*) echo "bad input; aborting"; return;;
	esac

	log "ip: $(get_ip)"

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
	ask4webr0c
}


sfnt() { (cd /etc/cfnt; setfont $(ls -1 *.* | awk NR==${1:-1})); }
bfnt() { (cd /etc/cfnt/big; setfont $(ls -1 *.* | awk NR==${1:-1})); }
menu_font() {
	mcat <<EOF
select font:
  1) tiny   2) small   3) large   k) OK
EOF
	ask1 'sel>'
	case $REPLY in
		1) sfnt 2;;
		2) sfnt;;
		3) bfnt;;
		K|k) return;;
	esac
	printf '\n\n\n\n\033[4A'
	showmotd
	menu_font
}


menu_games() {
	[ $a310 ] && return
	mcat <<EOF
oh hi
  m) matrix    l) ls           t) treedude
  n) cat       s) solitaire    w) wp
EOF
	ask1 'sel>'
	case $REPLY in
		M|m) apka -q tmatrix; tmatrix || true;;
		N|n) apka -q nyancat; nyancat || true;;
		L|l) sl;;
		S|s) apka -q tty-solitaire; ttysolitaire --no-background-color;;
		T|t) apka -q treedude; treedude;;
		W|w) apka -q cmd:fbi font-droid; fbi -a $AF/kit/wp.*;;
	esac
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
		log "ssh root@$ip (password is 'k')" ||
		log "ssh server up, press n to start networking"
}


verify() {
	local nf=$(wc -l <$AF/SHA1SUMS)
	apka -q coreutils pv || return
	echo "now checking file integrity..." >&2
	(cd $AF; sha1sum -c SHA1SUMS 2>/dev/shm/ckng2) |
	pv -ls$nf | grep -vE ': OK$' | tee /dev/shm/ckng1
	grep -q ... /dev/shm/ckng1 || {
		printf '\033[1;30;42m ok good \033[0m\n'
		return
	}
	printf '\033[1;37;41m OH NO VERIFICATION FAILED \033[0;1;33m\n'
	cat -n /dev/shm/ckng1
	cat /dev/shm/ckng2
	fbeep sad; sleep 0.5
}


# collect and store some hardware info
infograb() {
	# to timeout the comment prompt after 3 sec, uncomment the '' 3
	hwscan $AF/infos  # '' 3

	touch $AF/infos 2>/dev/null || fs_ro=1

	apka -q python3 !pyc && (
		cd /dev/shm
		rm -f hw-inv.*

		# html: recommended (readable by libreoffice-calc)
		# json: recommended (enables caching)
		# txt/csv: indifferent; no particular usecase
		hwinv $AF/infos \
			--txt=hw-inv.txt \
			--csv=hw-inv.csv \
			--html=hw-inv.html \
			--json=hw-inv.json \
			--cache=$AF/infos/hw-inv.json

		[ $fs_ro ] && mount -o remount,rw $AF
		mv hw-inv.* $AF/infos/

		mkdir -p $AF/sm/bin
		for p in hwinv hwscan; do
			cp -npv $(which $p) $AF/sm/bin/$p 2>/dev/null || true
		done

		p=$AF/infos/dmesg-cln.sh
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


ask4webr0c() {
	echo
	while true; do
		ask1 'start r0c webserver on ports 823+423 (http+https)? y/n> '
		case $REPLY in
			y) break;;
			n) return;;
		esac
	done
	pkgs="socat ttyd"
	if [ $a310 ]; then
		cmd='$AF/kit/r0c-client.sh 127.0.0.1 531'
	else
		cmd='telnet -E -c 127.0.0.1 23'
		pkgs="$pkgs cmd:telnet"
	fi
	apka -q $pkgs

	cat >/dev/shm/webr0c <<EOF
targs=(
	-W
	-t disableReconnect=true
	-t enableSixel=false
	-t enableTrzsz=false
	-t enableZmodem=false
	-t 'theme={"background":"#222","black":"#404040","red":"#f03669","green":"#b8e346","yellow":"#ffa402","blue":"#02a2ff","magenta":"#f65be3","cyan":"#3da698","white":"#d2d2d2","brightBlack":"#606060","brightRed":"#c75b79","brightGreen":"#c8e37e","brightYellow":"#ffbe4a","brightBlue":"#71cbff","brightMagenta":"#b67fe3","brightCyan":"#9cf0ed","brightWhite":"#fff"}'
	-p 823
	-i 0.0.0.0
	-t titleFixed=r0c
	-t rendererType=dom
	-t disableResizeOverlay=true
	$cmd
)
socat openssl-listen:423,fork,reuseaddr,cert=$AF/sm/tls-cert.pem,verify=0 tcp4:127.0.0.1:823 &
ttyd "\${targs[@]}"
EOF

	setup_tmux 3 wr0c
	tmux pipe-pane -t 0:3 -o "exec tee /dev/shm/conlog >>$(tty)"
	tmux send -t 0:3 "tps1; bash /dev/shm/webr0c" ENTER
	[ $a310 ] &&
		expect=' port 823, ' ||
		expect='Listening on port: 823'
	while sleep 0.1; do grep -qF "$expect" /dev/shm/conlog && break; done
	tmux pipe-pane -t 0:3
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

	mcat <<EOF
configure features:
  1) both FFmpeg and Pillow (good choice)
  2) just enable FFmpeg for music, tags, video thumbs
  3) just enable Pillow for thumbnails
  4) no, just copyparty please
EOF
	while true; do
		ask1 'choose 1~4> '
		case $REPLY in
			1) have_ffmpeg=1; v='py3-pillow ffmpeg';;
			2) have_ffmpeg=1; v='ffmpeg';;
			3) have_ffmpeg=;  v='py3-pillow';;
			4) have_ffmpeg=;  v='';;
			*) continue;
		esac
		break
	done

	pkgs=(tmux python3 btrfs-progs e2fsprogs xfsprogs dosfstools ntfs-3g ntfs-3g-progs)
	[ $a310 ] || pkgs+=(exfatprogs)
	
	# 2x faster download-as-zip, 2x more ram usage in general
	#echo $IVER | grep -E '^3\.1[0-6]' || pkgs+=(mimalloc2)

	apka !pyc "${pkgs[@]}" $v 2>&1 |
	while IFS= read -r x; do log -b "$x"; done & pid=$!

	mcat <<EOF
configure indexing:
  1) uploads only (makes them resumable and searchable)
  2) ...and also scan for tags (make music searchable by title/artist)
  3) scan all disks and index all files within
  4) ...and also scan for tags (make music searchable by title/artist)
  5) no
EOF
	while true; do
		ask1 'choose 1~4> '
		case $REPLY in
			1) e2d='-e2d';;
			2) e2d='-e2t';;
			3) e2d='-e2dsa -e2t';;
			4) e2d='-e2dsa -e2ts';;
			5) e2d='--no-snap --hist /dev/shm';;
			*) continue;;
		esac
		break
	done

	echo
	uname=
	f=$AF/sm/copyparty.conf
	grep -qE '^[^#]*\[accounts' $f &&
		echo "password enabled in $f" && uname=,u ||
		echo "password NOT enabled in $f (anonymous access is allowed)"

	mcat <<EOF
configure permissions:
  1) read-write-move-delete
  2) read-write
  3) read
EOF
	while true; do
		ask1 'choose 1~3> '
		case $REPLY in
			1) axs='A';;
			2) axs='rw';;
			3) axs='r';;
			*) continue;;
		esac
		break
	done

	echo 'still unpacking deps, pls wait ... watch the top bar'
	wait $pid 2>/dev/null || true
	printf '\033[A\033[J'

	[ -e /usr/bin/fsck.ntfs ] || { f=$(command -v ntfsfix); [ $f ] && ln -s $f /usr/bin/fsck.ntfs; }

	blkid -ovalue -sTYPE | grep -q LVM && {
		echo "found LVM disk; unboxing..."
		apka -q lvm2 && vgchange -ay ||
			printf '\033[1;33mfailed to read LVM; some partitions will not be available\033[0m\n'
	}

	mcat <<EOF
configure filesystem access:
  1) share all local disks (usb/hdd)
  2) select from a list
  3) only share the boot-disk
choose 1 or 2 to autoshare hotplugged USB storage
EOF
	while true; do
		ask1 'choose 1~3> '
		case $REPLY in
			1) v=y; ds=; break;;
			2) v=y; ds=y; break;;
			3) v=; break;;
		esac
	done
	[ $v ] && {
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
		if [ $ds ]; then
			cat -n /dev/shm/harddiskar
			ask 'space-separated list of disk# to share> '
			rm -f /dev/shm/utvalg
			for n in $REPLY; do
				awk NR==$n /dev/shm/harddiskar >>/dev/shm/utvalg
			done
		else
			mv /dev/shm/harddiskar /dev/shm/utvalg
		fi
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
					exfat|ext*) c="fsck.$fs -p";;
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

		ash $AF/sm/bin/setup-hotplug  # takes effect for hotplugs henceforth, not retroactive
	}

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
			[ $axs != r ] && chkbootfs && mount -o remount,rw $AF &&
				afaxs=$axs || afaxs=r

			args+=(
				"-v $v:/usb/$blkdev:$afaxs$uname:c,fat32"
				"-v $v/sm:/usb/$blkdev/sm:"  # block access to /sm
			)
			continue
		}
		[ -e "$v" ] && args+=("-v $v:/usb/$blkdev:$axs$uname")
	done

	printf '\nwill run copyparty with the following args:\n'
	printf '  %s\n' "${args[@]}"
	printf 'press any key to confirm  -or-  press CTRL-C to abort\n'
	read -n1 -u1

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

apka -q --no-progress sl &

# intel-uhd-graphics <700 doesn't render past 3840x2117
(fbset 2>&1) | awk '$1=="geometry" && $4>2560 && $5>1920 {r=1} END {exit r-1}' && fbset -xres 2560 -yres 1920

# force ntfs-3g (less buggy)
echo blacklist ntfs3 >/etc/modprobe.d/no-ntfs3.conf

# rotate display orientation (requires kms/modeset)
[ $rot != 0 ] && [ ! -e /dev/shm/rotated ] &&
	touch /dev/shm/rotated && rot $rot

# if /sm/tty.cfg exists, launch consoles on each tty listed inside
ttycons

# create a 2nd partition to fill free space
maybe_mkpart

mainmenu
