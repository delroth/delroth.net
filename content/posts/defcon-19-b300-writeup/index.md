---
title: 'DEFCON 19 CTF Binary L33tness 300 (b300) writeup'
date: 2011-06-07T00:00:00+02:00
tags: ["CTF", "writeup", "hacking", "reverse-engineering"]
draft: false
---

As in the other binary l33tness problems, only a single file was provided in
the problem description:

```
b300_b258110ad2d6100c4b8: gzip compressed data
```

Decompressing this gives us a tar archive containing these files:

```
./0/
./0/heap-dump-tm1306902723-pid12959.hprof
./0/classes.dex
./1/
./1/1306902613084.jpgs
./1/1306903692478.jpgs
./2/
./2/1306902613084.jpgs
./2/1306903692478.jpgs
```

The binary is classes.dex, which is bytecode for the Dalvik virtual machine
found on Android devices. The hprof file is a heap profiler output file which
contains the state of the program heap at some point during the execution. The
.jpgs files seems to contain random data at first, which leaded us to think it
was encrypted data we needed to decrypt.

But first, let's decompile the bytecode. We first
used [dex2jar](http://code.google.com/p/dex2jar/) to get a classes.jar file,
which we unzipped to get .class Java bytecode files. Then we
used [JAD](http://en.wikipedia.org/wiki/JAD_(JAva_Decompiler)) to decompile the
Java bytecode. It's not a perfect tool (a lot of things are not handled, for
example exception handling is kind of crappy in the decompiled output) but it
did the job quite well. The code was obfuscated: all classes, method and fields
names were transformed to strings like "a", "b", "ab", "g", ...

We first tried to find where the .jpgs files were created in the code. Grepping
the code gives us three matching classes: as.class, a Runnable instance which
is probably the main thread code, i.class, which seems to take pictures from
the Android device camera and saving them as JPEG, and r.class which is a
FilenameFilter instance filtering files ending with .jpgs. But reading all the
code to find where the encryption is done was a bit too tedious, so we decided
to grep for another thing: Java standard encryption library. Grepping
"java.security" returns us a single class: g.class, which seems to contain
methods to generate random bytes, to compute the SHA1 hash of a string or to
XOR encrypt/decrypt a string. Interesting.

Reading the code in this file gives us a lot of informations about the
encryption method. This is simply a XOR cipher using the first 8 bytes of
SHA1(password) as the key. Now we just need to find the key in the heap
profiler dump we got in the TAR archive. The .hprof file first needs to be
converted to the standard (non Android) hprof format using the hprof-conf tool
found in the Android SDK. Then, using the [Eclipse Memory
Analyzer](http://www.eclipse.org/mat/) we need to find the "g" class instance.
Using OQL, a SQL like used to query memory dumps, this does what we need:

{{< highlight sql >}}
select * from com.closecrowd.lokpixlite.g
{{< / highlight >}}

{{< figure src="images/sshot.png" link="images/sshot.png" caption="Using Eclipse MAT to find the b300 key." >}}

Now we just need a simple tool to decrypt the images. Behold!

{{< highlight python >}}
#! /usr/bin/env python

import sys

KEY = (44, -47, -51, -106, 72, -106, 61, 104)

def decrypt(infile, outfile):
    intext = infile.read()
    outbytes = []
    key_index = 0
    for byte in intext:
        key_byte = KEY[key_index] % 256 # wrap to 0-255
        outbytes.append(byte ^ key_byte)
        key_index = (key_index + 1) % len(KEY)
    outfile.write(bytes(outbytes))

if __name__ == '__main__':
    for filename in sys.argv[1:]:
        infile = open(filename, 'rb')
        outfile = open(filename + '.jpg', 'wb')
        decrypt(infile, outfile)
{{< / highlight >}}

Let's launch this on the "1" directory images:

{{< highlight shell-session >}}
$ ./decrypt.py *.jpgs
$ file *.jpg
1306902613084.jpgs.jpg: data
1306903692478.jpgs.jpg: data
$ xxd -l 64 1306902613084.jpgs.jpg
0000000: 1dd1 c716 4f11 9c20 fdc8 0f64 619c d87d  ....O.. ...da..}
0000010: ffd8 ffe0 0010 4a46 4946 0001 0100 0001  ......JFIF......
0000020: 0001 0000 ffdb 0043 0010 0b0c 0e0c 0a10  .......C........
0000030: 0e0d 0e12 1110 1318 281a 1816 1618 3123  ........(.....1#
{{< / highlight >}}

Woops. It looks like the JFIF marker is not at the correct offset. Looking at a
JPEG picture, we see that it should be at 0x6, but it is instead at 0x16. Let's
see what happens if we assume that the first 0x10 bytes are junk:

{{< highlight shell-session >}}
$ diff -u decrypt.py.old decrypt.py
--- decrypt.py.old      2011-06-07 07:26:45.603332762 +0200
+++ decrypt.py  2011-06-07 07:26:10.253333216 +0200
@@ -5,6 +5,7 @@
 KEY = (44, -47, -51, -106, 72, -106, 61, 104)

 def decrypt(infile, outfile):
+    infile.read(0x10)
     intext = infile.read()
     outbytes = []
     key_index = 0
$ ./decrypt.py *.jpgs
$ file *.jpg
1306902613084.jpgs.jpg: JPEG image data, JFIF standard 1.01
1306903692478.jpgs.jpg: JPEG image data, JFIF standard 1.01
$ md5sum *.jpg
0527c046512de51504790d03f00bda1c  1306902613084.jpgs.jpg
0527c046512de51504790d03f00bda1c  1306903692478.jpgs.jpg
{{< / highlight >}}

Success! Here is the image duplicated in the "1" directory:

{{< figure src="images/1306902613084.jpgs_.jpg" link="images/1306902613084.jpgs_.jpg" >}}

Looks like a thumbnail... well, let's look into the "2" directory. Again, two images with the same md5sum. Let's open one:

{{< figure src="images/13069026130841.jpgs_1.jpg" link="13069026130841.jpgs_1.jpg" >}}

And this is the key for b300: `ANDROIDSEKURITYisOXYMORON`. IMHO this was a
really easy problem for 300 points, as long as you know Java and its ecosystem
a bit (and I think even without knowing anything about DEX files, JAD, MAT,
etc. this could easily be done in an hour or two with enough Googling...).
