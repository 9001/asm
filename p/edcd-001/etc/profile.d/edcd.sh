menu() {
    printf '\n\n'; bash $AF/sm/asm.sh
}

edware() {
    [ -e /usr/bin/python3 ] || apka -q !pyc python3
    f=$1; shift; python3 $AF/edware/$f.py "$@"
}

r0c() { edware r0c "$@"; }
smf() { edware smf "$@"; }
copyparty() { edware copyparty-sfx "$@"; }

u2c() {
    local f=/usr/local/bin/u2c.py
    [ -e $f ] || {
        copyparty --version
        cp -pv /tmp/pe-copyparty.0/copyparty/web/a/u2c.py $f
        apka -q !pyc py3-requests
        echo
    }
    python3 $f "$@"
}

tps1() {
    export PS1="to leave this tmux and return to menu: press CTRL-B, release CTRL, press d\n$PS1"
}

for c in aria2c cryptsetup ddrescue entr ethtool hexyl irssi mtr nmap rsync rtorrent sensors w3m; do
	alias $c="unalias $c; which $c >/dev/null || apka $c !pyc || apka cmd:$c !pyc; $c"
done
