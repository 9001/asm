#!/usr/bin/env python3
# coding: utf-8
from __future__ import print_function, unicode_literals


import re
import socket
import struct
import subprocess as sp
import sys
import time
from bisect import bisect_right


"""isotrace.py: access-pattern logger"""
__version__   = "1.0"
__author__    = "ed <isotrace@ocv.me>"
__url__       = "https://github.com/9001/asm/blob/hovudstraum/utils/isotrace.py"
__credits__   = ["stackoverflow.com"]
__license__   = "MIT"
__copyright__ = 2024


class NBD_Server(object):
    def __init__(self, ip, port, fsize, readfun, writefun):
        self.ip = ip
        self.port = port
        self.fsize = fsize
        self.readfun = readfun
        self.writefun = writefun
        self._run()

    def srecv(self, nbytes):
        ret = b""
        while len(ret) < nbytes:
            buf = self.sck.recv(nbytes - len(ret))
            if not buf:
                t = "client eof, got %d of %d wanted bytes"
                raise Exception(t % (len(ret), nbytes))
            ret += buf
        return ret

    def sdec(self, nbytes, fmt):
        buf = self.srecv(nbytes)
        return struct.unpack(fmt, buf)

    def handshake_oldstyle(self):
        msg = b"NBDMAGIC" + b"\x00\x42\x02\x81\x86\x12\x53"
        msg += struct.pack(b">Q", self.fsize)
        msg += b"\x00" * 128  # 4 flags + 124 reserved
        self.sck.sendall(msg)

    def handshake_newstyle(self):
        sck = self.sck
        msg = b"NBDMAGIC" + b"IHAVEOPT"
        msg += struct.pack(b">H", 1)
        sck.sendall(msg)

        print("nbd client-flags: %r" % (self.srecv(4),))
        while True:
            msg = self.srecv(8)
            if not msg.endswith(b"IHAVEOPT"):
                raise Exception("expected IHAVEOPT, got %r" % (msg,))

            optnum = self.sdec(4, b">I")[0]
            optsize = self.sdec(4, b">I")[0]
            print("nbd client-opt %d |%d| ..." % (optnum, optsize))

            optval = self.srecv(optsize)
            print("nbd client-opt %d |%d| [%r]" % (optnum, optsize, optval))

            if optnum == 1:
                print("nbd replying with export name")
                msg = struct.pack(b">Q", self.fsize)
                msg += struct.pack(b">H", 1)
                msg += b"\x00" * 124  # reserved
                sck.sendall(msg)
                return

            print("nbd replying with unsupported")
            msg = b'\x00\x03\xe8\x89\x04\x55\x65\xa9'
            msg += struct.pack(b">I", optnum)
            msg += b"\x80\x00\x00\x01"
            msg += b"\x00" * 4  # len 0
            sck.sendall(msg)

    def _run(self):
        srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        srv.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

        srv.bind((self.ip, self.port))
        srv.listen(1)

        self.sck, addr = srv.accept()
        print("nbd connection from", addr)
        sck = self.sck

        self.handshake_newstyle()

        while True:
            reqt = self.sdec(28, b">IHHQQI")
            # print("nbd req:", reqt)

            magic, cflags, cmd, cookie, cofs, clen = reqt
            if magic != 0x25609513:
                raise Exception("bad req magic %d" % (magic,))

            bcookie = struct.pack(b">Q", cookie)

            if cmd == 0:
                # print("nbd read:", cofs, clen)
                data = self.readfun(cofs, clen)
                msg = b"\x67\x44\x66\x98"  # reply magic
                msg += b"\x00\x00\x00\x00"  # no error
                sck.sendall(msg + bcookie + data)

            elif cmd == 1:
                # print("nbd write:", cofs, clen)
                data = sck.read(clen)
                if self.writefun:
                    self.writefun(cofs, data)
                    err = b"\x00\x00\x00\x00"
                else:
                    err = b"\x00\x00\x00\x01"  # EPERM

                msg = b"\x67\x44\x66\x98"  # reply magic
                sck.sendall(msg + err + bcookie)

            else:
                msg = b"\x67\x44\x66\x98"  # reply magic
                msg += b"\x00\x00\x00\x5f"  # ENOTSUP
                sck.sendall(msg + bcookie + data)


class ISO(object):
    def __init__(self, fpath):
        self.fpath = fpath
        self.f = open(fpath, "rb")

        self.f.seek(0, 2)
        self.fsize = self.f.tell()

        self.map = {}  # lba -> list of files at lba
        self.lbas = []  # the 1st lba of all files
        self.assume_cached = set()  # offsets mod-2048 which have been accessed
        self.seen_fns = set()  # filenames visited
        self.fn_order = []  # filenames visited, in order
        self.last_uncached_ofs = 0  # last byte offset into iso file
        self.last_read_ofs = 0  # last byte offset into iso file

        cmd = ["xorriso", "-indev", fpath, "-find", ".", "-exec", "report_lba"]
        p = sp.Popen(cmd, stdout=sp.PIPE)
        lines = p.communicate()[0].decode("utf-8", "replace").split("\n")

        # Report layout: xt , Startlba ,   Blocks , Filesize , ISO image path
        sizes = {}
        for ln in lines:
            if not ln.startswith("File data lba:"):
                continue
            lv = ln.strip().split(",", 4)
            lba = int(lv[1].strip())
            sizes[lba] = int(lv[3])
            fn = lv[4].strip().strip("'")
            if lba in self.map:
                self.map[lba].append(fn)
            else:
                self.map[lba] = [fn]
                self.lbas.append(lba)

        self.lbas.sort()
        last_file_start = self.lbas[-1]
        after_last_file = last_file_start + (2047 + sizes[last_file_start]) // 2048
        self.lbas.append(after_last_file)
        self.map[after_last_file] = ["READ_PAST_END"]

    def read(self, ofs, nbytes):
        lba = ofs // 2048
        if lba not in self.assume_cached:
            self.assume_cached.add(lba)
            dist = abs(ofs - self.last_uncached_ofs)
            if dist > 4 * 1024 * 1024:
                # big seek; simulate delay
                slp = dist / (1024 * 1024 * 1024)
                print("z %.2f" % (slp))
                time.sleep(slp)

            self.last_uncached_ofs = ofs

        i = bisect_right(self.lbas, lba)
        if not i:
            # print("OUT OF BOUNDS READ?? ofs:", ofs)
            pass
        else:
            lba_base = self.lbas[i - 1]
            for fn in self.map[lba_base]:
                if fn == "READ_PAST_END":
                    continue  # probably efi img, dontcare
                suffix = ""
                if fn not in self.seen_fns:
                    if lba == lba_base:
                        # reading from start of file; add to weightlist
                        self.seen_fns.add(fn)
                        self.fn_order.append(fn)
                    else:
                        suffix = "[IGNORED::NOT_START_OF_FILE]"
                elif abs(self.last_read_ofs - ofs) <= 1024 * 1024:
                    continue  # only print new files and seeks
                print("%12d %s %s" % (ofs, fn, suffix))

        self.last_read_ofs = ofs
        self.f.seek(ofs)
        return self.f.read(nbytes)


def main():
    abspath_isofile = sys.argv[1]
    abspath_weightlist = sys.argv[2]

    exclude_pattern = sys.argv[3] if len(sys.argv) > 3 else ""
    ptn = re.compile(exclude_pattern) if exclude_pattern else None

    iso = ISO(abspath_isofile)
    try:
        NBD_Server("0.0.0.0", 2031, iso.fsize, iso.read, None)
    finally:
        with open(abspath_weightlist, "wb") as f:
            nw = 0
            n = len(iso.fn_order) + 10101
            for fn in iso.fn_order:
                n -= 1
                if ptn and ptn.search(fn):
                    continue

                if fn.startswith("./"):
                    fn = fn[1:]
                if not fn.startswith("/"):
                    fn = "/%s" % (fn,)

                nw += 1
                t = "%d %s\n" % (n, fn)
                f.write(t.encode("utf-8", "replace"))

        print("\nOK; wrote %d paths to %s\n" % (nw, abspath_weightlist))


if __name__ == '__main__':
    main()


_ = r""" usage:
./utils/isotrace.py asm.iso asm.wl lescue.webm
qemu-system-x86_64 --drive file=nbd:127.0.0.1:2031
./u2i.sh asm.usb asm.iso -wl asm.wl
"""
