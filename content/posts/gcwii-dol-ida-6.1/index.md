---
title: "GC/Wii DOL Plugin built for IDA 6.1"
date: 2012-03-22T00:00:00+02:00
tags: ["nintendo", "ida", "release"]
draft: false
---

Once upon a time, Stefan Esser from
the [Hitmen](http://hitmen.c02.at/index.html) programmed [an IDA loader
plugin](http://hitmen.c02.at/html/tools_ida.html) to be able to analyze DOL
files, which is the executable format used for Gamecube and Wii. Builds are
published for versions up to 5.2, but nothing more recent.

Fortunately they also released the source to their plugin, which allowed me
(with some very minor modifications to the code to use `linput_t` instead of
C `FILE` structures) to build a version of the IDA DOL loader plugin for IDA
6.1, the version I'm using in my day to day reverse engineering. Here is [a
link to this build](downloads/dol.ldw).

Have fun with it!

<!--more-->
