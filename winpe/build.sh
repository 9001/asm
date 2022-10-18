#!/bin/bash
set -e

# if iso is provided, do cleanbuild
[ $1 ] && {
	umount /mnt/wiso 2>/dev/null || true
	rm -rf t
}

help() {
	echo need arg 1: windows iso, for example:
	echo '  ~/iso/en_windows_10_enterprise_ltsc_2019_x64_dvd_5795bb03.iso'
	echo '  ~/iso/win7-X17-59186-english-64bit-professional.iso'
	exit 1
}

[ "$1" ] && [ ! -e "$1" ] && echo "file not found: $1" && help

[ -e /mnt/wiso/efi/microsoft/boot/cdboot.efi ] || {
	[ -z "$1" ] && help
	mkdir -p /mnt/wiso
	sudo mount "$1" /mnt/wiso/
}

[ -e t/efi/boot/bootx64.efi ] || {
	mkdir -p t/sources
	tar -cC /mnt/wiso boot/{bcd,boot.sdi} bootmgr efi | tar -xvC t
	[ -e t/efi/boot/bootx64.efi ] || (
		# win7 support
		mkdir -p t/efi/boot/
		cd t/efi/boot/
		7z e /mnt/wiso/sources/boot.wim 1/Windows/Boot/EFI/bootmgfw.efi
		mv boot{mgfw,x64}.efi
	)
}

rm -f t/sources/boot.wim
#mkwinpeimg -W /mnt/wiso -o t/sources/boot.wim
mkwinpeimg -W /mnt/wiso -O src -s src/start.cmd -o t/sources/boot.wim
#xorrisofs -quiet -output t.iso -sysid '' -e efi/boot/bootx64.efi -no-emul-boot -isohybrid-gpt-basdat t 
#qemu-system-x86_64 -accel kvm -m 1024 -cdrom t.iso -bios /usr/share/OVMF/OVMF_CODE.fd
# nevermind doesnt work
sz=$(du -sb t | awk '{print (int($1/1024/1024)+4)*1024*1024}')
rm -f t.usb
fallocate -l $sz t.usb
echo ,,U | sfdisk -X gpt t.usb
mkfs.vfat -n PE -S 512 --offset=2048 t.usb
mmd -i t.usb@@1M $( (cd t; find -type d) | cut -c3- | grep . | awk '{printf " ::%s", $0}')
(cd t; find -type f) | cut -c3- | while IFS= read -r x; do mcopy -i t.usb@@1M t/"$x" ::"$x"; done
qemu-system-x86_64 -accel kvm -drive format=raw,file=t.usb -bios /usr/share/OVMF/OVMF_CODE.fd -m 1024
