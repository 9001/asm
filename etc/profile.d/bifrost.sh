# https://ocv.me/dot/bifrost.html
tty | grep -q /tty && {
	printf '\033]P0202020\033]P1f03669\033]P2b8e346\033]P3ffa402\033]P402a2ff\033]P5f65be3\033]P63da698\033]P7d2d2d2'
	printf '\033]P8505050\033]P9c75b79\033]Pac8e37e\033]Pbffbe4a\033]Pc71cbff\033]Pdb67fe3\033]Pe9cf0ed\033]Pfffffff'
	printf '\033\\\033[J'
}
true
