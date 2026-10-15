#!/usr/bin/env python3
"""Minimal RFB (VNC) framebuffer grabber - stdlib only.

Usage: rfbshot.py HOST PORT OUT.ppm

Speaks just enough RFB 3.8 with 'None' security and Raw
encoding to dump one full frame as a binary PPM. Written for
the boot-test workflow: packer's QEMU VNC display has no
password, and the runner may lack a working VNC snapshot
tool (vncsnapshot 1.2a silently produced nothing there).
"""
import socket
import struct
import sys


def read_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("eof after %d of %d bytes" % (len(buf), n))
        buf += chunk
    return buf


def main():
    host, port, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
    sock = socket.create_connection((host, port), timeout=30)
    version = read_exact(sock, 12)
    if not version.startswith(b"RFB "):
        raise ValueError("not an RFB server: %r" % version)
    sock.sendall(b"RFB 003.008\n")
    ntypes = read_exact(sock, 1)[0]
    if ntypes == 0:
        raise ConnectionError("server refused security negotiation")
    types = read_exact(sock, ntypes)
    if 1 not in types:
        raise ConnectionError("server offers no 'None' security: %r" % types)
    sock.sendall(bytes([1]))
    result = struct.unpack(">I", read_exact(sock, 4))[0]
    if result != 0:
        raise ConnectionError("security handshake failed: %d" % result)
    sock.sendall(bytes([1]))  # ClientInit: shared
    init = read_exact(sock, 24)
    width, height = struct.unpack(">HH", init[0:4])
    # Pixel format is init[4:20]; QEMU's default is 32bpp
    # true-colour, which is what we request frames in.
    name_len = struct.unpack(">I", init[20:24])[0]
    read_exact(sock, name_len)
    # SetEncodings: Raw only.
    sock.sendall(struct.pack(">BxH", 2, 1) + struct.pack(">i", 0))
    # FramebufferUpdateRequest: full, non-incremental.
    sock.sendall(struct.pack(">BHHH", 3, 0) + struct.pack(">HH", width, height))
    frame = bytearray(width * height * 4)
    while True:
        mtype = read_exact(sock, 1)[0]
        if mtype == 0:  # FramebufferUpdate
            read_exact(sock, 1)
            nrects = struct.unpack(">H", read_exact(sock, 2))[0]
            done = True
            for _ in range(nrects):
                hdr = read_exact(sock, 12)
                x, y, w, h, enc = struct.unpack(">HHHHi", hdr)
                if enc != 0:
                    raise ValueError("unexpected encoding %d" % enc)
                raw = read_exact(sock, w * h * 4)
                for row in range(h):
                    src = row * w * 4
                    dst = ((y + row) * width + x) * 4
                    frame[dst:dst + w * 4] = raw[src:src + w * 4]
            if done:
                break
        elif mtype == 2:  # Bell
            continue
        elif mtype == 3:  # ServerCutText
            ln = struct.unpack(">I", read_exact(sock, 7)[3:7])[0]
            read_exact(sock, ln)
        else:
            raise ValueError("unexpected message type %d" % mtype)
    # Server pixel format is BGRA (little-endian 32bpp); PPM is RGB.
    with open(out, "wb") as fh:
        fh.write(b"P6\n%d %d\n255\n" % (width, height))
        for i in range(0, len(frame), 4):
            fh.write(bytes([frame[i + 2], frame[i + 1], frame[i]]))
    print("wrote %s (%dx%d)" % (out, width, height))


if __name__ == "__main__":
    main()
