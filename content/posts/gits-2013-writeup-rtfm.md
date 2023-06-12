---
title: 'GITS 2013 Writeup: RTFM (re100)'
date: 2013-02-17T01:00:00+02:00
tags: ["CTF", "writeup", "hacking"]
draft: false
---

```
rtfm-67cc5dcb69df4244bcf2d573481e6d6a06b861a3: ELF 32-bit LSB executable
rtfm-e24f03bb1204f8e3d40fae8ac135187a11b0ba5c: data
```

`rtfm` is a binary processing ASCII input files and outputting seemingly
compressed versions of these files: testing on a few long text files shows that
the size of the output file is smaller than the input file. The second file
from this challenge is a file compressed by `rtfm`, our objective is to write
the decompression code for the `rtfm` compression.

The interesting part of the binary is the function at `0x08048910`, which
compresses the contents of an input buffer and writes it to a `calloc`-ed
output buffer. For each character of the input stream, the function will read
data from a 128 entries table at `0x08048CA0`. Each of these entry contains a
16-bit word as well as an 8-bit integer.

<!--more-->

After reading the details of the compression algorithm and noticing how it
outputs a bit stream with variable size depending on the input character, I
guessed that this was most likely implementing the well known Huffman encoding
algorithm. The table at `0x08048CA0` is a hardcoded mapping of input symbols to
output symbols, and the output symbols seem to be unambiguous when reading the
compressed stream bit by bit. From this information we can now write a simple
Huffman decoder using the same table.

{{< highlight python >}}
import struct

fp = open('bin')
fp.seek(0xca0)
descr_raw = fp.read(4 * 128)
descr = {}

for i in xrange(0, 4*128, 4):
    s = descr_raw[i:i+3]
    w, b = struct.unpack('<HB', s)
    descr[i/4] = { 'byte': b, 'word': w }

def bits(s):
    for c in s:
        n = ord(c)
        for i in xrange(8):
            yield (n & 0x80) >> 7
            n <<= 1

def decompress(buf):
    buf = buf[4:]

    ends = {}
    for i, d in enumerate(descr.values()):
        n = d['byte'] + 2
        s = bin(d['word'])[2:]
        s += ("0" * (n - len(s)))
        ends[s] = i

    out = []
    n = ""
    for i, b in enumerate(bits(buf)):
        n += str(b)
        if n in ends:
            out.append(chr(ends[n]))
            n = ""

    return ''.join(out)

if __name__ == '__main__':
    print decompress(
        open('rtfm-e24f03bb1204f8e3d40fae8ac135187a11b0ba5c').read()
    )
{{< / highlight >}}

Decompressing the file gives us a RTF document, which contains the key: "Did I
have Vari-good-code?".
