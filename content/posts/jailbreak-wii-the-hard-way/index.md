---
title: "Jailbreaking a Wii the hard way: how to"
date: 2011-03-25T00:00:00+02:00
tags: ["hacking", "nintendo", "emulation", "reverse-engineering"]
draft: false
---

This last Christmas I was happy to get gifted a brand new Nintendo Wii ("25
years of Mario" version) from someone in my family. Quickly my interests
shifted from "playing games on the system" to trying to understand how the
console works, and whether I could potentially run my own code on it. This led
to an article on this blog about [the Wii DVD file format](/posts/reading-wii-discs-python/),
but also a lot of research and reverse engineering to understand how games
themselves work.

However, while I did learn a lot, I was still not able to run my own code on
the console. It's kind of sad, I would have loved to be able to do more than
just *reading* about the hardware. To run unapproved code on a closed/locked
platform, one must use what is called a *jailbreak*. This usually involves
exploiting a security vulnerability in software that already runs on the device
(for example, on the Nintendo Wii, a game). Through this vulnerability,
arbitrary code gets executed, then this entry point is used to further root the
device. The iPhone, for example, was jailbroken via a vulnerability in its PDF
reading code, allowing rooting by direct access to a web page. On the Wii, the
*Bannerbomb* exploit allowed until last year jailbreaking a Wii by making it
read a malformed image. There are many similar examples.

<!--more-->

The Wii runs a firmware with an operating system and a GUI which allows
starting games, changing console settings, or copying save games on an SD card.
This firmware is available in several versions and is regularly update. The
last version, shipped with my Wii, is version 4.3. The only jailbreak methods
working for this Wii system version use vulnerabilities found in games. For
example: *Lego Indiana Jones* or *Yu-Gi-Oh Wheelie Breaker*. Only problem: once
those games are found to be vulnerable, they are usually not sold in retail
shops anymore, and get resold at a huge premium second hand (since most buyers
only buy them to jailbreak then resell just after). I don't own any of these
bames, and after some shopping in local game stores, I don't think I could find
a copy at a non-outrageous price.

I actually own only 4 Wii games at the moment: *Madworld*, *New Super Mario
Bros Wii*, *Final Fantasy Crystal Chronicles: Echoes of Time* et *Tales of
Symphonia: Dawn of the New World*. It's this last game that I spent the most
time exploring while trying to understand how the Wii works. During this
exploration, I spent a good amount of time reverse engineering the game saves
format. At that time, not really in the aim of doing anything jailbreak
related, more in order to document the format and allow patching saves to
impact gameplay. Let's look a bit more into those save files, this time with an
eye towards vulnerabilities.

## Analyzing Tales of Symphonia: DotNW save files

### Checksum

The saves for this game are made of two parts: a very small header, and a
~200KB binary payload. The header contains only data that gets displayed in the
saves list (play time, list of characters in the party, in-game location where
the save was created, etc.). The full payload contains everything: a copy of
the same information that is in the header, but also all the more detailed
information that is not needed for the saves list. Let's try editing some of
this data. At first, changing a character's name in the header:

{{< figure src="images/corrupted.png" link="images/corrupted.png" caption="Corrupted save." >}}

First failure. Next step is looking for whatever mechanism is in charge of
detecting data corruption. By analyzing a bunch of different save files, I was
able to quickly infer that the first 8 bytes of the save header are used as a
checksum. However, that doesn't tell us anything about the checksuming
algorithm. The game executable is around 20MB, so finding a tiny checksum
function in there is going to be difficult. To help in finding it, I patched
the PowerPC interpreter in the Dolphin Emulator in order to detect memory reads
to the 8 bytes that contain the checksum.

This method made finding the checksum function trivial! Once the code was
found, reverse engineering it showed a very simple algorithm:

- The first 4 checksum bytes are a header-only checksum, and are the result of
  the sum of the first 162 32-bit integers after the checksum.
- The last 4 checksum bytes are a full save checksum (including header), and
  are the result of the sum of the first 51,908 32-bit integers after the
  checksum.

After two days I had a simple, minimalist tool to recompute checksums, and I
was able to load modified save files!

{{< figure src="images/modified-save-1.png" link="images/modified-save-1.png" >}}
{{< figure src="images/modified-save-2.png" link="images/modified-save-2.png" >}}

### Overflowing strings

Some parts of the save data are obvious to understand: things that get directly
displayed on the string in menus and in character status screens, for example.
But while trying to understand the data, something caught my attention. In the
save file, character names seem to have a reserved, fixed size. However, as
shown in the second screenshot above, the code that reads and uses those
character names seems to just take them as zero-terminated C strings with no
size limit.

So, obviously, let's try a larger string. Channelling the elder hacker spirits,
I modified a save to have a character named `"A"x1000`. A thousand bytes should
definitely overflow anything that's designed for fixed name sizes. And indeed,
when opening the character status screen for that modified character, the
emulator gave me the following error:

{{< figure src="images/error.png" link="images/error.png" >}}

This could mean one of two things:

- The emulator tried to read or write memory at that address and failed. This
  could in theory happen even if no overflow happened. For example, saves could
  always get loaded at the same memory address, and store pointers with real
  RAM addresses. The Wii does not have anything like ASLR, after all. However,
  after checking an unmodified save file, nothing in there looks like a pointer
  or a RAM address. So at the very least we'd have a way via our overflow to
  overwrite a pointer somewhere.

- Or, better, the emulator tried to execute code from that address. That would
  be even better: it would mean that the overflow went into either function
  pointers, or, more likely, into the stack return address. This would make
  writing an exploit even easier than in the first case.

Luckily Dolphin is open source, so I could just patch the emulator once again
to clarify the message. It happens that we are indeed in the second case! By
pure luck, our overflow went into the stack and overwrote the return address,
giving us control over the execution without crashing prior to the return. With
a few more save modifications I was able to pinpoint exactly which offset in
the overflowed string overwrote the return address: offset `0x144`. If we put a
valid address there, the emulator jumps to it and executes the code.

## Running a payload

So, let's try executing something of our own. At first, I hand-assembled two
PowerPC instructions which read memory from a known address in memory, to cause
a memory read exception. I stored those instructions somewhere in the save game
that seemed to only contain `0x00` bytes. I dumped the emulator's memory state
after loading the save to find exactly at which address to jump (which is
consistent, since no ASLR is used). I put that address at offset `0x144` in the
name. And indeed, success: Dolphin reported the expected memory exception,
showing that we were indeed jumping and executing code from the save file.

Storing code directly in the save is not great though. It's hard to work with,
and there's only very limited space (at most 40-50K usable). Luckily, other
hackers have already developped small payloads that are designed to solve
exactly this problem. The [savezelda repository from segher](https://github.com/lewurm/savezelda)
contains a `loader` directory with code designed to load an ELF binary from an
SD card.

I recompiled said loader code, ensuring that it was linked to assume the
correct load address (where it would be placed in memory by the game's save
file loading code). It took a lot of fighting with PowerPC toolchains, EABI
issues, `-Os` mysterious linking errors, but after some work I was able to
finally execute some basic homebrew on Dolphin!

{{< figure src="images/mandelbrot.png" link="images/mandelbrot.png" >}}

## Running on real hardware

Now comes the real test: geting all of this to work on real hardware. Second
failure: the game freezes instead of executing the payload. I've tried making
the payload as small as a single PowerPC instruction which lights up the Wii's
DVD drive, nothing works. I tried many different things, I even convinced
myself at some point that all of my previous work only worked because of a bug
in Dolphin.

However a week ago I came back to this, and decided to investigate again. I
realized that the *stack overflow* which allowed me to overwrite the stack
return address was at the very beginning of a large function, and the jump to
my code happens all the way at the end (when the function returns). That gives
plenty of time for other overwritten local variables to cause problems, and
possibly crashes.

So, I randomly changed the value with which I overwrote the stack. Instead of
ASCII `A (0x61)`, I used `0x01` bytes. And like magic, it worked! My PowerPC
code successfully lit up the disc drive.

{{< figure src="images/lumiere.jpg" link="images/lumiere.jpg" >}}

## Cleaning up

From there, I went back to the SD loader in order to run some Wii homebrew. In
this case, a simple *Pong* clone in text mode. Here is a video for your viewing
pleasure (bad quality, sorry):

{{< youtube Sf93Z9SEMqE >}}

Unfortunately, while that particular piece of homebrew software worked, this
was not the case for 75% of them. I was encountering random crashes at
startup. Notably, the *Hackmii Installer*, which allows for rooting the console
and installing the famous *Homebrew Channel*, did not work with my loader.

Finally yesterday I realized what the problem was: I was chainloading the
homebrew code without ever cleaning up the system's state. The video context in
particular was problematic. Inspired by other game exploits whose source code
was released, I search in the game's code for the `video_stop` function from
Nintendo's SDK. And by calling that function before trying to execute code from
the SD card, my random crashes disappeared! I was able to run the *Hackmii
Installer* and finally jailbreak my Wii.

So yeah, that's how you jailbreak a Wii the hard way :-)
