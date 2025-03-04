menu() {
	printf '\n\n'; bash $AF/sm/asm.sh
}

edware() {
	[ -e /usr/bin/python3 ] || apka -q !pyc python3
	f=$1; shift; python3 $AF/kit/$f.py "$@"
}

r0c() { edware r0c "$@"; }
smf() { edware smf "$@"; }
copyparty() { edware copyparty-sfx "$@"; }

u2c() {
	local f=/usr/local/bin/u2c.py
	[ -e $f ] || {
		copyparty --version
		cp -pv /tmp/pe-copyparty.0/copyparty/web/a/u2c.py $f
		echo
	}
	python3 $f "$@"
}

tps1() {
	printf '%s\n' "$PS1" | grep -q CTRL-B ||
	export PS1="to leave this tmux and return to menu: press CTRL-B, release CTRL, press d\n$PS1"
}

for c in aria2c chntpw cryptsetup ddrescue entr ethtool git hexyl irssi mtr nmap rpm2cpio rsync sensors ttyd w3m; do
	alias $c="unalias $c; which $c >/dev/null || apka $c !pyc || apka cmd:$c !pyc; $c"
done
