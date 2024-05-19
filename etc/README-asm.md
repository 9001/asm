everything in this folder is unpacked into `/etc` in the live-env

[`strap.sh`](./strap.sh) gets executed in TTY1 due to [`inittab`](./inittab) and does basic setup before it runs the main payload, [`asm.sh`](../sm/asm.sh)

[`bin`](./bin/) gets copied into `/usr/local/bin`, contains a subset of [ulb](https://github.com/9001/usr-local-bin) plus these:
* [`log`](./bin/log) sets a banner at the top of the screen
* [`unlog`](./bin/unlog) lets the banner scroll away
* [`utime`](./bin/utime) gives current unix-time with microseconds

[`cfnt`](./cfnt/) is a set of console fonts, two smaller ones and one big:
* `lat0-10.psfu.gz`, a tiny latin1 font from [kbd-misc](https://pkgs.alpinelinux.org/package/edge/main/x86_64/kbd-misc), autoenabled if screen is 35 lines or shorter
* `miniwi-8.psf.gz`, even smaller (3x5) from [github](https://github.com/josuah/miniwi), requires modeset due to not being mod8 tall
* `ter-i32b.psf.gz`, a huge font from [font-terminus](https://pkgs.alpinelinux.org/package/edge/main/x86_64/font-terminus), autoenabled if screen is 85 lines or taller
