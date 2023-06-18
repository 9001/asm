# logging

`echo 1 > sm/log.cfg` to enable logging to disk, or `echo ttyS0` to log to serial port instead (or both with `echo 1 ttyS0`)

* needs `util-linux` (so either `recommended_apks` or `fetch_apks util-linux` in post-build)
* note that execution will halt if the logging destination dies
* log can be replayed with `scriptreplay -t runlog.pce -B runlog.txt`
* `echo 2 > sm/log.cfg` logs to the 2nd partition instead (must be created manually) and is probably much safer since the primary partition can remain read-only
  * to create a 2nd partition, `truncate -s +64M asm.usb && echo ',,0c' | sfdisk -qa asm.usb && mkfs.vfat -F16 -nLOGS --offset=$(sfdisk asm.usb -l | awk '{v=$2}END{print v}') asm.usb`


# misc 

* need to debug the alpine init? boot it like this to stream a verbose log out through the serial port: `lts console=ttyS0,115200,n8 debug_init=1`
  * or append the extra args after `modloop_verify=no` in `build.sh`
  * qemu: `-serial pipe:s` as extra arg, and `mkfifo s.{in,out}; tee serial.log <s.out&` before launch
    * optionally just `-serial stdio` for interactive without logging

* rapid prototyping with qemu:
  ```
  losetup -f --show ~ed/asm.raw
  mount /dev/loop0p1 /mnt/ && tar -czvf /mnt/the.apkovl.tar.gz etc && cp asm-example.sh /mnt/sm/asm.sh && umount /mnt && sync && qemu-system-x86_64 -hda ~ed/asm.raw -m 768 -accel kvm
  ```

* local apk cache; `-m http://192.168.122.1:3923/am` and...
  ```
  echo http://192.168.122.1:3923/am/ > am/mirrors.txt && PYTHONPATH=~/dev/copyparty python3 -um copyparty -v am:am:r | tee log
  awk '!/GET  \/am\//{next} {sub(/.*GET  \/am\//,"");sub(/ @.$/,"")} 1' ../log | sort | uniq | while IFS= read -r x; do [ -e "$x" ] || echo "https://mirrors.edge.kernel.org/alpine/$x"; done | wget -xnH --cut-dirs=1 -i-
  ```

* initramfs hacking:
  ```
  mkdir x x2
  mount -o offset=1048576 asm.usb x
  (cd x2 && gzip -d < ../x/boot/initramfs-virt | cpio -idmv)
  vim x2/init
  (umask 0077; cd x2 && find . | sort | cpio --quiet --renumber-inodes -o -H newc | zstd -19 -T0) > x/boot/initramfs-virt
  umount x
  ```

* test boot speed:
  ```
  bst() { (t0=$(date +%s.%N); ncat -l -p 4322; t=$(date +%s.%N); echo "v=$t-$t0;scale=3;v/1" | bc) & qemu-system-x86_64 -enable-kvm -vga qxl -drive format=raw,file=asm.usb -m 256; }
  ./build.sh -i dl/alpine-standard-3.15.0-x86_64.iso -m http://192.168.122.1:3923/am/ -s 0.2 -p min && bst
  ```
  asm.sh:
  ```
  printf '%s\n' "" 10.0.2.15 24 10.0.2.2 done n | setup-interfaces -r
  echo h | nc 192.168.122.1 4322
  poweroff
  ```
