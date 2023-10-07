# uki

this profile produces a [unified kernel image](https://uapi-group.org/specifications/specs/boot_loader_specification/#type-2-efi-unified-kernel-images) suitable for secureboot

the call to `uki_make` near the end of the [post-build](sm/post-build-2.sh) does the magic

to make secureboot validate as much as possible for us, this will move the apkovl into the initramfs, which is not officially supported by alpine and causes some funny messages during boot but it's fine

security stuff considered,
* privkeys are never written to the output disk image
* alpine's modloop and `asm.sh` are verified on startup
* paths on the flashdrive (`/sm/bin`) are not added to PATH

if you do `uki_make 1` instead of just `uki_make`, it will also:
* disable shell (not ^C-interruptible)

note that, unless you provide an RSA privkey with `-ak`, this profile will fail to build because keys are not configured; follow the messages from build.sh to create the required keys

also note that file integrity is only validated down to (and including) your `asm.sh`, so if you refer to any other resources from there (binaries, images, ...) then you have to verify those -- for example with a hardcoded list of sha512 checksums inside asm.sh, like [this example](sm/asm.sh)


# secureboot

assumes you already have a set of UEFI keys/certs, for example produced by [efi-mkkeys](https://github.com/jirutka/efi-mkkeys) -- asm expects the same format as `efi-mkkeys` produces, which is the db pem cert + pem privkey as separate files

provide args `-ak ~/keys/asm.key -ek ~/keys/db.key -ec ~/keys/db.crt` to sign everything automatically during build

or, if you already have an `asm.usb` and just want to sign it, run `mod.sh` with the same args to (re)sign an already built image

* `mod.sh` can also take `-sm ~/some/path` to replace the `sm` folder inside the image; good for patching in new resources or runtime scripts


## secureboot certs

if you put your secureboot certs into [the certs folder](./certs/) and boot this asm image on a machine where secureboot is running in "setup mode", then `install_secureboot_certs` will autoinstall the secureboot certs into uefi and activate secureboot by switching the machine into "user mode"

if you ever need to replace your certs, the best approach is probably to sign a new PK with the old PK and use keytool.efi -- see [arch wiki](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot#Updating_keys)


# notes

quick oneliner to insert the correct asm.sh signature into an asm.usb if you forgot to update it before building (basically what mod.sh does),

```bash
mount -o offset=1048576 asm.usb m && openssl dgst -sha512 -sign ~/keys/asm.key -out p/uki/sm/asm.sh.sig p/uki/sm/asm.sh && cp --preserve=timestamps p/uki/sm/asm.sh* m/sm/ && umount m
```

test it in qemu,

```bash
cp -pv /usr/share/OVMF/OVMF_*.secboot.fd .; qemu-system-x86_64 -machine q35,smm=on,accel=kvm -global ICH9-LPC.disable_s3=1 -drive if=pflash,format=raw,unit=0,file=OVMF_CODE.secboot.fd,readonly=on -drive if=pflash,format=raw,unit=1,file=OVMF_VARS.secboot.fd -device virtio-blk-pci,drive=d0,bootindex=1 -drive id=d0,if=none,format=raw,file=asm.usb -m 512
```

if you want to allow editing of `asm.sh` (dangerous; arbitrary code execution) then disable the signature check by commenting/removing the `sign_asm` in `post_build_2.sh` (or see the obig profile's)
