#!/usr/bin/env python3

import os
import re
import stat
import subprocess as sp
import sys


def main():
    try:
        with open("/etc/profile.d/asm-paths.sh", "rb") as f:
            zs = f.read().decode("utf-8", "replace")

        bootdisk = zs.split("xport AF=")[1].split("\n")[0].strip().rstrip("1")

        label = sys.argv[1].split(":usb-eject:")[1].split(":")[0].split("/")[-1]
        smp = os.path.abspath(os.path.realpath("/media/" + label))
        if smp.startswith(bootdisk):
            return print("cannot eject bootdisk")

        # print("ejecting [%s]... " % (smp,), end="")
        mp = smp.encode("utf-8")
        st = os.lstat(mp)
        if not stat.S_ISDIR(st.st_mode):
            return print("not a regular directory")

        # /media/sdc
        # /media/sdc1
        # /media/sdc_foobar_ntfs
        # /media/sdc1_foobar_ntfs
        m = re.search(br"^[^_]+([0-9]+)(_|$)", mp)
        if not m:
            # whole block device, not a partition
            mps = [mp]
        else:
            # find all partitions on parent dev
            mps = []
            top, name = os.path.split(mp.split(b"_")[0])
            prefix = name[:-len(m.group(1))]
            print("top=%s name=%s prefix=%s" % (top, name, prefix), file=sys.stderr)
            for name in os.listdir(top):
                if name.startswith(prefix):
                    mps.append(os.path.join(top, name))

        for mp in mps:
            try:
                os.rmdir(mp)
                continue
            except:
                pass
            ret = sp.run([b"umount", mp], capture_output=True)
            if ret.returncode:
                try:
                    zb = b"\n".join([ret.stdout, ret.stderr])
                    zs = zb.decode("utf-8", "replace")
                except:
                    zs = "%s\n%s" % (ret.stdout, ret.stderr)

                return print("unmount failed:\n%s" % (zs.strip()))
            os.rmdir(mp)

        print(label + " can be safely unplugged")

    except Exception as ex:
        print("unmount failed: %r" % (ex,))


if __name__ == "__main__":
    main()
