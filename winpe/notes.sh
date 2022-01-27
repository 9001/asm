mkdir /mnt/wiso/
mount iso/en_windows_10_enterprise_ltsc_2019_x64_dvd_5795bb03.iso /mnt/wiso/
apt install wimtools  # wimlib

# figuring out the template;
# produces bios-only, iso-only media
# but we want the opposite (uefi usb)
mkwinpeimg --iso --windows-dir=/mnt/wiso pe.iso
qemu-system-x86_64 -accel kvm -m 1024 -cdrom pe.iso 
7z l pe.iso

#     16384  BOOT/BCD
#   3170304  BOOT/BOOT.SDI
#    408074  BOOTMGR
# 349004446  SOURCES/BOOT.WIM
#      4096  [BOOT]/Boot-NoEmul.img
