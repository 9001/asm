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

assumes you already have a set of UEFI keys, for example produced by [efi-mkkeys](https://github.com/jirutka/efi-mkkeys) (the stuff below expects the same format as `efi-mkkeys` produces, which is a pem cert + pem privkey as separate files)

provide args `-ak ~/keys/asm.key -ek ~/keys/kek.key -ec ~/keys/kek.crt` to sign everything automatically during build

or, if you already have an `asm.usb` and just want to sign it, run `mod.sh` with the same args to (re)sign an already built image

* `mod.sh` can also take `-sm ~/some/path` to replace the `sm` folder inside the image; good for patching in new resources or runtime scripts


# notes

quick oneliner to insert the correct asm.sh signature into an asm.usb if you forgot to update it before building (basically what mod.sh does),

```bash
mount -o offset=1048576 asm.usb m && openssl dgst -sha512 -sign ~/keys/asm.key -out p/uki/sm/asm.sh.sig p/uki/sm/asm.sh && cp --preserve=timestamps p/uki/sm/asm.sh* m/sm/ && umount m
```
