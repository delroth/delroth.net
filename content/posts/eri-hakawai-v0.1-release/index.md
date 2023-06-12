---
title: "Release: Eri HaKawai v0.1 for PAL Wiis"
date: 2011-03-27T00:00:00+02:00
tags: ["release", "nintendo", "hacking"]
draft: false
---

Eri HaKawai is a new exploit for PAL Wiis, which works for all currently
released System Menu versions (<= 4.3). It works by using a bug in the savegame
loading code of Tales of Symphonia: Dawn of the New World, the sequel to the
Gamecube game Tales of Symphonia.

I'm releasing it in a source format (no binary `data.bin`) under the GPLv2.
You'll need a Broadway cross-compilation toolchain, as well as a checkout of
Segher's Wii Git repository. Do whatever you want with it (as long as it is
allowed by the license, of course!), I'm just too lazy to distribute binaries.

[Download Eri HaKawai v0.1](downloads/erihakawai-0.1.tar.bz2)

<!--more-->

How to use (directly copied from the `README` file in the tarball):

Usage:
 - Compile it with `./make.sh`
 - Copy the `private` folder to the root of your SD card.
 - Put the homebrew you want to load on the root of your SD card, named
   `boot.elf`
 - Start the game and load the first save
 - Press the PLUS button to enter the game menu
 - Scroll to the STATUS button and press A
 - Scroll to the monster named "Eri HaKawai" and press A
 - The `boot.elf` file should be loaded from your SD card.

That's it! Have fun with this new exploit, and don't forget to play the great
game that Tales of Symphonia: Dawn of the New World is :-) .
