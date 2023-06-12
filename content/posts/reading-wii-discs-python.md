---
title: "Reading Wii discs with Python"
date: 2011-06-10T00:00:00+02:00
tags: ["emulation", "nintendo"]
draft: false
---

What I mean by reading a Wii disc is simple: from a Wii DVD image, being able
to get metadata about the game, like its name or its unique ID, but also being
able to read the filesystem on the disc to access the game executable and data.
We'll do this in three parts: first, we'll decrypt the disc clusters to be able
to access the raw partition data, then we'll parse the filesystem to access
files and directories, and we'll end this by a presentation of wiiodfs, the
software I created to mount Wii discs on Linux using FUSE.

I currently only have one game disc image on my computer: the one from *[Tales
of Symphonia: Dawn of the New
World](http://en.wikipedia.org/wiki/Tales_of_Symphonia:_Dawn_of_the_New_World)*,
PAL version, whose ID is `RT4PAF` (sha1sum:
`b2fb05a7fdf172ea61b5d1872e6b121140c95822`). I'm going to work on this disc image
for my tests, and if needed fix things when I'll have to open another game DVD
image which doesn't work. To write this article, I'm using documentation
from [WiiBrew](http://wiibrew.org/wiki/Main_Page), a wiki about Wii homebrew
with a lot of technical informations, and the [source code of
Dolphin](https://github.com/dolphin/dolphin-emu), the Wii emulator (mostly in
the `Source/Core/DiscIO` directory). Thanks a lot to all of the contributors to
these projects.

All of the examples from this article are given in the form of Python shell
transcripts. If you only want a working version of the software to use at home,
look at the third part of this article, where I'm talking about wiiodfs.

Reading raw data from a partition
---------------------------------

Some facts about Wii discs: they start with a simple header containing metadata
about the game (name, ID, disc number, disc type, etc.), placed at offset 0. At
offset `0x40000` is the *volume group* table, which contains all the partitions
on the disc. Wii discs generally contain several partitions: at least one for
the game and one containing the system upgrades. Each of these partitions have
a type: 0 is a data partition, 1 is a system upgrade partition. We'll only look
at the data partition, I'm not interested in the system upgrade files. The data
partition starts with another header containing informations needed to decrypt
the partition data. All of the data on a Wii disc are encrypted using the [AES
algorithm](http://en.wikipedia.org/wiki/Advanced_Encryption_Standard), with a
128 bytes key.

Let's start by importing useful modules and opening our disc image:

{{< highlight python >}}
Python 2.7.1 (r271:86832, Dec 20 2010, 11:54:29)
[GCC 4.5.1 20101125 (prerelease)] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> from collections import namedtuple
>>> from struct import unpack as up
>>> from Crypto.Cipher import AES
>>> fp = open('tos-2.img', 'rb')
{{< / highlight >}}

We'll read the disc header at offset `0x0` using `struct.unpack`. It's really
easy: the header has a fixed size and fixed size fields.

{{< highlight python >}}
>>> DiscHeader = namedtuple('DiscHeader',
...     'disc_id game_code region_code maker_code disc_number disc_version '
...     'audio_streaming stream_bufsize wii_magic gc_magic title'
... )
>>> disc_hdr = DiscHeader(*up('>c2sc2sBBBB14xLL64s', fp.read(96)))
>>> disc_hdr
DiscHeader(disc_id='R', game_code='T4', region_code='P', maker_code='AF',
           disc_number=0, disc_version=0, audio_streaming=0,
           stream_bufsize=0, wii_magic=1562156707, gc_magic=0,
           title='Tales of Symphonia: Dawn of the New World' + n*'\x00')
{{< / highlight >}}

The game metadata are all contained in this header: game ID (`RT4PAF`,
separated into `disc_id`, `game_code`, `region_code` and `maker_code`), game
title (zero terminated), and a magic number, `0x5d1c9ea3`, which confirms that
this is actually a Wii disc. Next step is the volume group table. Let's see
what it looks like using `xxd`:

{{< highlight shell-session >}}
$ xxd -s 0x40000 -l 48 tos-2.img
0040000: 0000 0002 0001 0008 0000 0000 0000 0000  ................
0040010: 0000 0000 0000 0000 0000 0000 0000 0000  ................
{{< / highlight >}}

There are 4 volume groups containing multiple partitions. That means a
partition is identified by its VG id and its partition ID. The VG table we just
dumped contains for each VG two 32 bytes words: the first one is the number of
partitions in that VG, and the second one is the offset to the partition table
(the offset is in block of 4 bytes, so we must multiply it by 4 to get an
offset in bytes). Here, we have the first VG containing 2 partitions, and its
partition table is at offset `0x10008 * 4`, which is `0x40020`. Let's
use `xxd` again:

{{< highlight shell-session >}}
$ xxd -s 0x40020 -l 16 tos-2.img
0040020: 0001 4000 0000 0001 03e0 0000 0000 0000  ..@.............
{{< / highlight >}}

Each entry in this table contains first the offset to the partition (again, in
block of 4 bytes), but also the type of the partition. As said above, type 1 =
system upgrade partition and type 0 = game data. Here, we have an update
partition at offset `0x14000 * 4` and a game data partition at
offset `0x3e00000 * 4`. Using Python, we can dump all of the VG entries and all
of the partitions in an easy to read format:

{{< highlight python >}}
>>> PartEntry = namedtuple('PartEntry', 'offset type')
>>> def read_part_entry(offset):
...     fp.seek(offset)
...     (data_offset, type) = up('>LL', fp.read(8))
...     data_offset *= 4
...     return PartEntry(data_offset, type)
>>>
>>> read_part_entry(0x40020)
PartEntry(offset=327680, type=1)
>>> read_part_entry(0x40028)
PartEntry(offset=260046848, type=0)
>>>
>>> VGEntry = namedtuple('VGEntry', 'part_count table_offset')
>>> def read_vg_entry(offset):
...     fp.seek(offset)
...     (part_count, table_offset) = up('>LL', fp.read(8))
...     table_offset *= 4
...     return VGEntry(part_count, table_offset)
...
>>> read_vg_entry(0x40000)
VGEntry(part_count=2, table_offset=262176)
>>> read_vg_entry(0x40008)
VGEntry(part_count=0, table_offset=0)
>>>
>>> def read_part_table():
...     base_off = 0x40000
...     vgs = {}
...     for vg_num in xrange(4):
...         vg_ent = read_vg_entry(base_off + 8 * vg_num)
...         if vg_ent.part_count == 0:
...             continue
...         vgs[vg_num] = {}
...         for part_num in xrange(vg_ent.part_count):
...             off = vg_ent.table_offset + 8 * part_num
...             part = read_part_entry(off)
...             vgs[vg_num][part_num] = part
...     return vgs
...
>>> read_part_table()
{0: {0: PartEntry(offset=327680, type=1),
     1: PartEntry(offset=260046848, type=0)}}
{{< / highlight >}}

The game data partition is encrypted using AES in CBC mode with a key stored in
the partition header. This key is itself encrypted using a master key, which is
the same on every Wii console, and is stored in One Time Programmable memory
inside the Wii CPU at manufacturing time. This key has been known for a long
time and can be found for example in the Dolphin code. AES CBC needs a key and
an IV (Initial Vector) to proceed. The IV is also stored in the partition
header: it is part of the *title ID* which uniquely identifies a game and is
for example used to know where a game stores its data on the console NAND. We
have all the informations we need to recover the game specific key (aka. *title
key*), let's start by parsing the *ticket*, which is the data structure
containing all the keys and infos we need about a title:

{{< highlight python >}}
>>> Ticket = namedtuple('Ticket',
...     'enc_tit_key tit_id data_off data_len'
... )
>>> part = read_part_table()[0][1]
>>> fp.seek(part.offset)
>>> ticket = Ticket(*up('>447x16s13x16s204xLL', fp.read(704)))
{{< / highlight >}}

For a reason I don't know, Nintendo did not use the whole title ID as the IV
but only the first 8 bytes. The 8 other bytes are filled with 0. Let's decrypt
the title key!

{{< highlight python >}}
>>> master_key = '\xeb\xe4\x2a\x22\x5e\x85\x93\xe4'
>>> master_key += '\x48\xd9\xc5\x45\x73\x81\xaa\xf7'
>>>
>>> iv = ticket.tit_id[:8] + '\x00' * 8
>>>
>>> aes = AES.new(master_key, AES.MODE_CBC, iv)
>>> key = aes.decrypt(ticket.enc_tit_key)
>>> key
'U\x84\xfb\x8b\x10\xdfu=B;\xdcyF\xd4G\x9d'
{{< / highlight >}}

With that, we are now able to decrypt the partition contents. Data are stored
at an offset found in the ticket (`data_off` in the ticket parsing code above).
From that offset, data is organized in clusters of `0x8000` bytes. These
clusters contain each `0x400` bytes of hashing informations to validate data
integrity, and `0x7C00` bytes of encrypted data. To decrypt the data, we use
the title key, and the IV is stored in the first `0x400` bytes of the cluster,
at offset `0x3D0`:

{{< highlight python >}}
>>> def read_cluster(idx):
...     data_offset = part.offset + ticket.data_off * 4
...     cluster_offset = data_offset + idx * 0x8000
...     fp.seek(cluster_offset)
...     data_enc = fp.read(0x8000)
...     iv = data_enc[0x3D0:0x3E0]
...     aes = AES.new(key, AES.MODE_CBC, iv)
...     return aes.decrypt(data_enc[0x400:])
{{< / highlight >}}

Let's test that by decoding the first 20 clusters and looking at their content:

{{< highlight python >}}
>>> for i in xrange(20):
...     open('/tmp/cluster%d' % i, 'wb').write(read_cluster(i))
{{< / highlight >}}

{{< highlight shell-session >}}
$ strings /tmp/cluster* | less
[...]
This Apploader built %s %s for RVL
APPLOADER WARNING >>> Older version of DEVKIT BOOT PROGRAM.
APPLOADER WARNING >>> Use v1.07 or later.
APPLOADER ERROR >>> FSTLength(%d) in BB2 is greater than FSTMaxLength(%d)
APPLOADER ERROR >>> Debug monitor size (%d) should be a multiple of 32
APPLOADER ERROR >>> Simulated memory size (%d) should be a multiple of 32
[...]
{{< / highlight >}}

Success! Data seems to have been read and decrypted correctly from the
partition (if it's working for the first 20 clusters, we can certainly assume
that it will work for the rest of the partition). Let's end this part by
dumping the entire partition to be able to analyze the filesystem easily later.
The partition size is stored in the ticket, let's go!

{{< highlight python >}}
>>> nclusters = ticket.data_len * 4 / 0x8000
>>> out_fp = open('/path/to/tos-2-dumped.img', 'wb')
>>> for i in xrange(nclusters):
...     print '%f%%' % (i * 100.0 / nclusters)
...     out_fp.write(read_cluster(i))
{{< / highlight >}}

We now have a `tos-2-dumped.img` file containing the raw partition data, with
the filesystem and the game data on it.

Parsing the filesystem
----------------------

On the partition we just dumped, there are three main parts to analyze:

-   The apploader, which is a small stub of code identical on each game and
    distributed in the Nintendo Wii SDK, whose role is to load the game
    executable in memory
-   The game executable, whose sections are not stored linearly. I won't spend
    a lot of time on how it is stored, but if I remember correctly each section
    contains the offset to the next section, and you can easily recreate a DOL
    executable (the format of most Wii/GC executables) which can be converted
    to an ELF
-   The filesystem, where all of the images, textures, sounds, musics, 3D
    models, animation data, scripts, etc. are stored for a game. Nintendo
    provides an API to access the filesystem so everyone uses the same format.
    That's what we are going to talk about here

The structure of a Wii filesystem is really simple: it is a fully read only
filesystem optimized to avoid seeking (slow on an optical disc) so there are no
things to handle like data fragmentation. First of all, all of the metadata are
stored in the same place, called the FST (*FileSystem Table*). These metadata
are actually only the name of the file, its size and where it is stored on the
disc. We can find the FST by looking at offset `0x424` on the partition, which
contains the 4 bytes offset to the FST (which means we need to multiply it by 4
to get an offset in bytes).

A filesystem is hierarchical: it is a tree of directories containing leaves
which are the regular files. However, the FST is a linear structure (a table).
To represent the hierarchy, a directory descriptor uses its size field to store
the index of the first descriptor which is not their child. For example, if the
root directory contains only 3 files, its size field will contain the value 4
(descriptor 0 is the root directory, 1/2/3 are the files, so 4 is the first
which is not a child of the root directory). A little example in ASCII art:

```
+---------------------+
| Directory 1         |
|   size = 7          |
+---------------------+
    +---------------------+
    | File 1              |
    |   size = 42         |
    +---------------------+
    +---------------------+
    | Directory 2         |
    |   size = 6          |
    +---------------------+
        +---------------------+
        | File 2              |
        |   size = 1337       |
        +---------------------+
        +---------------------+
        | File 3              |
        |   size = 1234       |
        +---------------------+
        +---------------------+
        | File 4              |
        |   size = 4321       |
        +---------------------+
    +---------------------+
    | File 5              |
    |   size = 101010     |
    +---------------------+
```

After the last descriptor comes the string table containing all the file names.
In a file descriptor, the file name is stored as an offset (in bytes this
time... consistency!) from the beginning of this string table. To find the
offset to this string table, we can use the fact that the first descriptor size
is also the total number of descriptors in the FST. And that's all there is to
know about a Wii disc filesystem! Quite simple, isn't it?

Let's start writing a bit of code. First, let's import the modules we need and
open the image we dumped at the end of the first part of this article:

{{< highlight python >}}
Python 2.7.1 (r271:86832, Dec 20 2010, 11:54:29)
[GCC 4.5.1 20101125 (prerelease)] on linux2
Type "help", "copyright", "credits" or "license" for more information.
>>> from collections import namedtuple
>>> from struct import unpack as up
>>> fp = open('tos-2-dumped.img', 'rb')
{{< / highlight >}}

Then, let's define a useful function which reads data at a specific offset in
the file (basically, `seek` then `read`):

{{< highlight python >}}
>>> def read_at(off, len):
...     fp.seek(off)
...     return fp.read(len)
{{< / highlight >}}

We're all set! First step, let's get the FST offset and multiply it by 4 to get
it in bytes:

{{< highlight python >}}
>>> fst_off = up('>L', read_at(0x424, 4))[0] * 4
{{< / highlight >}}

Next, the string table offset. We take the FST offset, reads the size of the
first descriptor, multiply it by `0xC` which is the size of a descriptor, and
adds those two to get the offset we need:

{{< highlight python >}}
>>> str_off = fst_off + up('>8xL', read_at(fst_off, 0xC))[0] * 0xC
{{< / highlight >}}

Filenames are stored as zero terminated strings of at most 256 characters.
Python has nothing standard to read that in the `struct` module, we will need a
small function which reads 256 bytes and cut at the first `\0` encountered:

{{< highlight python >}}
>>> def read_filename(off):
...     s = read_at(str_off + off, 256)
...     return s[:s.index('\0')]
...
>>> read_filename(0)
'BATTLE'
>>> read_filename(7)
'BG'
>>> read_filename(10)
'btl000.brres'
{{< / highlight >}}

Now comes the interesting code: the function which reads a file descriptor and
all its children recursively to build the filesystem tree. This is not easy to
understand with a single reading of the function, I'll explain it just after:

{{< highlight python >}}
>>> def read_descr(idx):
...     descr = read_at(fst_off + 12 * idx, 12)
...     (name_off, data_off, size) = up('>LLL', descr)
...     data_off *= 4
...
...     is_dir = bool(name_off & 0xFF000000)
...     name_off &= ~0xFF000000
...     name = read_filename(name_off) if idx else ''
...
...     if not is_dir:
...         return idx + 1, name, (data_off, size)
...     else:
...         children = {}
...         idx += 1
...         while idx < size:
...             idx, child_name, child = read_descr(idx)
...             children[child_name] = child
...         return idx, name, children
{{< / highlight >}}

First, let's identify what this function is returning: three values, the first
one if the index of the first descriptor which has not yet been handled (makes
the recursion easier), the name of the file or directory described by the
descriptor we just read, and finally, depending on the file type (regular or
directory), the children or the data offset. How this function does that is
actually not that difficult: first, we read the 12 bytes of the descriptor from
its index. Then, to check if it is a regular file or a directory, we check if
one of the top 8 bits of the name is set: if there is at least one, this is a
directory. We then read the name. If it is a regular file, we just end there
saying that the first non handled descriptor is the one just after us. If it is
a directory, we loop while the non handled offset is smaller than our last
child and we insert the parsed descriptor into our children. That's all!

To conclude this part, let's dump all of the files and directories in a local
directory on our PC. We just have to walk the tree returned by `read_descr(0)`:

{{< highlight python >}}
>>> from os.path import exists, join
>>> from os import mkdir
>>> def dump(name, data, where):
...     print 'dumping', name, 'to', where
...     if isinstance(data, dict): # directory
...         path = join(where, name)
...         if not exists(path):
...             mkdir(path)
...         for name, data in data.iteritems():
...             dump(name, data, path)
...     else:
...         print data[0], data[1]
...         data = read_at(data[0], data[1])
...         open(join(where, name), 'wb').write(data)
{{< / highlight >}}

Here we go! We just extracted all the files and directories from a Wii disc
onto our computer with just a Python shell. The last step is to make something
usable from all of these informations.

Creating a FUSE filesystem for Wii discs
----------------------------------------

This last part of the article will talk about how to make a usable filesystem
from all of that. Indeed, writing code snippets in a Python shell is far from
clean, even though it is useful for hacking around.

The result is named [wiiodfs](https://github.com/delroth/wiiodfs), which stands
for *Wii Optical Disc FileSystem*. It is an application able to mount a Wii
disc image on Linux, but also a library that people who need to access Wii
discs from their software can use. There is still a bit of work to do on it but
99% of the code is done and working.

The first difference of importance when comparing to the two previous parts is
that we can not afford to dump the whole parition in a temporary file or dump
all the files in a directory. It's ugly, slow and of little interest. The whole
decyphering and data access in wiiodfs is done on the fly, when needed. The
library is designed with that need in mind.

wiiodfs has a 4-layer design. The n-th layer can access every lower layers.
Here is a detailed explanation of the different layers:

-   Raw access to the disc image, metadata, and to the volume groups table.
    Quite straightforward: no decyphering, no filesystem support, only what is
    necessary to read the image from a location to another and to recover
    informations on the disc partitions.
-   Raw access to decyphered partition data. It is almost certainly the most
    interesting part therefore I will describe it further later, but to sum up,
    it reads raw data off the partition, decyphers it and returns it to the
    user.
-   Access to the partition files with an easy-to-use
    API: `Filesystem.open` returns an object behaving like a Python file, on
    which we can call methods like `read` or `seek`. There are also methods to
    list files in a directory, checking if a file exists, etc.
-   Finally, an interface to use our filesystem
    with [Pyfilesystem](http://code.google.com/p/pyfilesystem/), a library
    which aims to define a common interface for all file systems in order to
    use them in a uniform way.

As I said before, I think the most interesting part in all of this is the
second layer, handling the partition decyphering. Indeed, decrypting blocs
of `0x8000` bytes is quite slow and some kind of caching is needed to avoid
decrypting the same cluster 20 times in a row. I implemented a simple LRU cache
to solve this problem. LRU caches are the most simple caches you can think of:
they keep a certain number of values sorted by their last use time. That way,
the most recently used values will be kept in the cache, and the least recently
used values will slowly be replaced by other values which are more used. There
are probably a lot of way to cache clusters more efficiently but this was not
the goal of this project, and this LRU cache is enough to get a good
throughput.

wiiodfs is distributed with a script named `wiiodmount` which mounts a Wii disc
image on a local filesystem folder. To do this, we simply use a feature of
Pyfilesystem,
called [`expose.fuse`](http://packages.python.org/fs/expose/fuse.html#module-fs.expose.fuse).
It's magic and there is almost nothing to do on my side to handle that.

Wrapping up
-----------

I knew almost nothing about the Wii when I started writing this article at the
beginning of January 2011. This was a really interesting adventure, and I know
now in detail how Nintendo decided to store data on their optical discs (at
least on the logical layer, I don't know anything about how Wii discs are
physically different from classic DVDs). wiiodfs is almost certainly incomplete
and buggy, but it is a really simple implementation of the Wii Filesystem and
it is as far as I know the only one able to use FUSE to mount the disc on a
local folder.

I hope you liked this article 🙂 Let's end that with links and thanks to the
projects and people who helped me:

-   [Wiiodfs](https://bitbucket.org/delroth/wiiodfs/src), Mercurial repository
    of the project
-   [Wiibrew](http://wiibrew.org/), a great Wiki about Wii homebrew, with a lot
    of technical informations
-   [Dolphin](http://dolphin-emu.org/), the best Wii/GC emulator, which is
    licensed under the GPL license
-   Thanks to kalenz who helped me translate this long article to English
