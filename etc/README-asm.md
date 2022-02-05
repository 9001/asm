everything in this folder is unpacked into `/etc` in the live-env

[`strap.sh`](./strap.sh) gets executed in TTY1 due to [`inittab`](./inittab) and does basic setup before it runs the main payload, [`asm.sh`](../sm/asm.sh)

[`bin`](./bin/) gets copied into `/usr/local/bin`, contains a subset of [ulb](https://github.com/9001/usr-local-bin) plus these:
* [`log`](./bin/log) sets a banner at the top of the screen
* [`unlog`](./bin/unlog) lets the banner scroll away
* [`utime`](./bin/utime) gives current unix-time with microseconds

[`cfnt`](./cfnt/) is a tiny latin1 font from [kbd-misc](https://pkgs.alpinelinux.org/package/edge/main/x86_64/kbd-misc) and is enabled if the screen is sufficiently small
