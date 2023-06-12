---
title: "Why Dolphin is getting rid of asynchronous audio processing"
date: 2013-07-10T00:00:00+02:00
tags: ["emulation", "audio", "nintendo"]
draft: false
---

Since the release of Dolphin 3.5 half a year ago, audio processing in Dolphin
has changed a lot. In Dolphin versions up to 3.5, a lot of games required
low-level emulation of the DSP code in order to not crash or get audio output.
This low-level emulation (called DSP LLE) is unfortunately a lot slower than
high-level emulation (DSP HLE): while low-level emulation emulates extremely
accurately the DSP code by translating the binary code into x86, high-level
emulation simply runs C++ code which approximates what the DSP code does. I’ve
spent several months [rewriting most of the DSP HLE code](http://blog.lse.epita.fr/articles/38-emulating-the-gamecube-audio-processing-in-dolphin.html),
fixing sound issues in several dozens of games (my current estimate is around
~150), and now DSP HLE can be used in most GameCube and Wii games that
previously required DSP LLE.  HLE being a lot faster than LLE, everyone should
be happy, right?

Wrong. It turns out that one of the main source of bugs, crashes and
inaccuracies in DSP HLE was also one of its main features: the ability to run
sound emulation at full speed even if the emulated game is not able to reach
100% speed on a computer. This feature, called asynchronous audio processing,
is obviously being requested again by more and more people. This article is
here to explain why async audio will not come back and what async audio
actually breaks.

<!--more-->

*I’ll only talk about the GameCube audio emulation in this article in order to
make things easier – but DSP HLE on GC and Wii is extremely similar, and most
of the implementation is shared for these two consoles. I will also only talk
about AX HLE, which is emulation for the most used (99.9% of games) DSP
program.*

## What are the differences between sync and async audio emulation?

The audio processing code in a GameCube runs on the DSP, which is a second
processor engineered to be fast at tasks like audio mixing. The DSP
communicates with the CPU running a game in three ways: a pair of registers
used to pass very small messages, DMA in order to read and write from/to RAM,
and an IRQ in order for the DSP to interrupt the CPU.

Through these communication methods, every 5ms, the CPU sends to the DSP a list
of data blocks about sounds to process. Each of these blocks contain
information like “location of the sound data in memory”, “volume”, “looping or
oneshot”. The CPU also sends a list of commands to run – the DSP code supports
about 18 of these commands. When the DSP is done running the commands, it sends
an interrupt to the CPU to signal that it is done. The CPU then updates the
sound data blocks, copies the mixed sound samples that were sent to RAM by the
DSP, and a few other things.

{{< figure src="images/gc-audio-2.png" class="white-bg" caption="What these sound data blocks look like." >}}

What synchronous audio emulation does is very simple: when the DSP needs to run
(there are commands waiting to be executed), stop the CPU, execute all the
commands, and send an interrupt to signal we are done. Exactly what should be
done, which is the reason why I went that way when I reimplemented the DSP
high-level emulation.

What asynchronous audio emulation does is a bit more complicated: when the DSP
gets commands, it completely ignores the commands and just copies the list of
data blocks. It then sends an interrupt to signal that it’s done. In the
background, it will use these data blocks to mix audio and send it directly to
the audio output backend of the emulator, bypassing most of the standard audio
processing path. If the emulated CPU tries to read the sound data that the DSP
was supposed to copy to RAM, it will read garbage. But because the data blocks
processing is not tied to the CPU sending us commands, it doesn’t care about
the emulated CPU speed and can just run at 660full speed all the time.

{{< figure src="images/gc-audio-6.png" class="white-bg" caption="On the left, asynchronous audio emulation. On the right, synchronous audio emulation." >}}

If this doesn’t sound wrong enough to you, let’s take a few examples of why
this actually does not work in practice.

## AUX processing

AUX processing is a feature of the DSP program that allows the CPU to apply
audio effects on the sounds. It is implemented using DSP commands to download
and upload data to the CPU in order for the CPU to process it while the DSP is
working on something else. AUX is used for several very common audio effects:
echo, reverb, chorus, …

This simply cannot work with asynchronous audio processing: first of all, the
DSP<->CPU communication is obviously impossible (they don’t run in sync
anymore), but also all of the AUX code is implemented to handle a fixed number
of samples, which matches how much samples the DSP handles at a time (32×5, for
5ms at 32KHz). Let’s compare how some games sound like with and without AUX
effects applied:

### Without AUX processing

<iframe width="100%" height="166" scrolling="no" frameborder="no" src="https://w.soundcloud.com/player/?url=http%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F67619519"></iframe>

### With AUX processing

<iframe width="100%" height="166" scrolling="no" frameborder="no" src="https://w.soundcloud.com/player/?url=http%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F67619338"></iframe>

I think the music speaks by itself.

## Games requiring tight timing

This issue with asynchronous audio processing is actually what made me start
rewrite the DSP emulation code in Dolphin (see [this commit from November 2012](https://github.com/dolphin-emu/dolphin/commit/16060290c2dc3cac5c1cb4643d460bb778cc121d)).
Basically, as the DSP is engineered to handle 5ms of sound at a time, game
developers use this in order to time when sounds should start and stop in order
to make music from small samples of instruments. But a 5ms accuracy is often
not enough: for that, the DSP provides a feature called “sub-5ms updates”, with
which you can specify some slight changes to be made on the sound data blocks
for each millisecond.

<iframe width="100%" height="166" scrolling="no" frameborder="no" src="https://w.soundcloud.com/player/?url=http%3A%2F%2Fapi.soundcloud.com%2Ftracks%2F100518911"></iframe>

Fail to emulate that properly, and games become confused when the changes they
requested the DSP to make are not done.

## Games using the sound processing status to trigger events

This is a bug that is not fixed yet because it mostly impacts games using
another DSP program (called the “Zelda” program, because it’s mostly used by
Zelda games). Basically, some games wait for sounds to be completed before
triggering an event. When the sound processing is done asynchronously, the game
might miss the moment when the sound has finished playing (because it went too
fast compared to the emulated CPU speed) and just freeze. Or it might not
notice that it needs to start a new music track, and the music completely
stops, leaving you in a mostly silent world.

Once again: there is no way to fix that with asynchronous audio processing,
this is a direct consequence of how it works.

## Conclusion

A lot of people are still requesting asynchronous audio processing in Dolphin
because their computer is too slow to emulate games at full speed. They assume
that developers are being lazy by not implementing what they think is best. The
truth is: asynchronous audio processing causes way too much problems to be
worth spending our time on. It’s not easy to implement it besides the current
audio emulation code either, and some features simply can’t work with it
(Wiimote sound on the Wii, for example). I hope this article will help explain
why asynchronous audio emulation is broken and why we don’t want it in our
emulator anymore.
