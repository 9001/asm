# https://ocv.me/dev/?paralleli.sh
par() {
	type paf >/dev/null || {
		printf '%s\n' 'try this:' 'paf() { echo "processing file $1 ..."; sleep 1; }' 'find -type f -print0 | par  # -t'
		return 1
	}
	export -f paf
	xargs "$@" -0i -P$(nproc) bash -c 'paf "$@"' _ {}
}
