# uki

this profile produces a [unified kernel image](https://uapi-group.org/specifications/specs/boot_loader_specification/#type-2-efi-unified-kernel-images) suitable for secureboot

the call to `uki_make` near the end of the [post-build](sm/post-build-2.sh) does the magic

to make secureboot validate as much as possible for us, this will move the apkovl into the initramfs, which is not officially supported by alpine and causes some funny messages during boot but it's fine

security stuff considered,
* alpine's modloop and `asm.sh` are verified on startup
* the `bin` folder on the flashdrive is not added to PATH

if you do `uki_make 1` instead of just `uki_make`, it will also:
* disable shell

note that this profile will fail to build because keys are not configured; follow the steps provided by build.sh to fix that

also note that file integrity is only validated down to (and including) your `asm.sh`, so if you refer to any other resources from there (binaries, images, ...) then you have to verify those -- for example with a hardcoded list of sha512 checksums inside asm.sh, like [this example](sm/asm.sh)


# secureboot

after the image has been built, mount the asm.usb and sign `efi/boot/bootx64.efi` with your KEK

this can be automated using `sbsign.sh` which does not yet exist because zelda:totk is too good


# notes

quick oneliner to insert the correct asm.sh signature into an asm.usb if you forgot to update it before building,

```bash
mount -o offset=1048576 asm.usb m && openssl dgst -sha512 -sign ~/keys/asm.priv -out p/uki/sm/asm.sh.sig p/uki/sm/asm.sh && cp --preserve=timestamps p/uki/sm/asm.sh* m/sm/ && umount m
```
