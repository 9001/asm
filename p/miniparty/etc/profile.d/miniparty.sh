edware() {
	[ -e /usr/bin/python3 ] || apka -q python3
	f=$1; shift; python3 $AF/kit/$f.py "$@"
}

r0c() { edware r0c "$@"; }
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
