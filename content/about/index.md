---
title: "About me"
layout: single
draft: false
---

## In short

I'm delroth, or *Pierre Bourdon*. Originally from France, currently living in
Zürich, Switzerland. I'm an open source developer, mainly contributing to
[NixOS](https://nixos.org) these days. In the past, I was a core developer for
the [Dolphin Emulator](https://dolphin-emu.org), and I was the main
infrastructure maintainer as well as treasurer for the project.

In my working life, I've worked for around 10 years as a Software Engineer at
Google. I've spent around 3 years each specializing in site reliability,
counter-abuse technologies, then infrastructure security. Along the way, I also
became privacy reviewer for new infrastructure projects, as well as
teacher/mentor for new C++ developers at the company.

I'm currently on a sabbatical leave, spending my free time learning more about
the country I've lived in for 10 years, and finally learning the local
language.

<!--more-->

## My interests

### Outdoors

Hiking and cycling are almost the national hobby in Switzerland, and it would
be a waste to not appreciate the amazing forests, hills, and mountains of the
country. You can find an almost full list of the roads and trails I've hiked or
biked on my [Komoot profile](https://www.komoot.com/user/340296816274/tours?type=recorded).

{{< gallery match="images/outdoors/*" randomize=true loadJQuery=true rowHeight="150" margins="5" thumbnailResizeOptions="600x600 q90 Lanczos" previewType="blur" embedPreview=true >}}

### Travel

I enjoy traveling around Switzerland, Europe, and the rest of the world. My
favorite travel destination is by far Japan, where I've been almost every year
since 2016 (minus COVID-19 pandemic years). I log my flights on [my OpenFlights
profile](https://openflights.org/user/delroth) but I also travel by train more
often than I fly.

{{< gallery match="images/travel/*" randomize=true loadJQuery=true rowHeight="150" margins="5" thumbnailResizeOptions="600x600 q90 Lanczos" previewType="blur" embedPreview=true >}}

### Videogames

I play a lot (too much?) video games. I'm really into story driven role playing
games (*Disco Elysium*, *The Witcher*, *Final Fantasy* series, *Divinity:
Original Sin*, *OMORI*), roguelites / deck builders of various genres (*Slay the Spire*,
*Against the Storm*, *Griftlands*), and I like to think I'm decent at rhythm
games (*CHUNITHM* whenever I'm traveling somewhere where it's available,
otherwise *Project Sekai* on my phone).

### Anime

I watch a lot (also too much?) anime.
I keep my [Anilist](https://anilist.co/user/delroth/animelist) mostly up to
date with the series I've watched / I'm watching.

## Talks and publications

I don't really do academic stuff or very formal conference talks, but here are
a few (in my opinion) interesting articles I've written on other people's
websites and talks I've given in the past in various places.

### Articles

(Mar 2013) [Emulating the GameCube Audio Processing in Dolphin](http://blog.lse.epita.fr/articles/38-emulating-the-gamecube-audio-processing-in-dolphin.html)  
> A dive into how audio processing is commonly done on two Nintendo consoles: the
Gamecube and the Wii. This article explains why exactly audio processing is
hard to emulate properly, why the previous implementation was lacking and the
work I've done in a new implementation to solve these shortcomings.

(Oct 2012) [Writeup: Zombies PPTP (Hacklu CTF 2012)](http://blog.lse.epita.fr/articles/33-hacklu-ctf-2012-zombies-pptp-450-points.html)  
> Writeup of an interesting challenge involving hash cracking and clever
bruteforcing in order to recover the plaintext from a kind-of-MSCHAPv2
implementation.

(Jul 2012) [Using SAT and SMT to Defeat Simple Hashing Algorithms](http://blog.lse.epita.fr/articles/24-using-sat-and-smt-to-defeat-simple-hashing-algorit.html)  
> How to transform a broken hash algorithm into a logic formula that can be
solved in seconds using a SAT solver. Good example of why you should never try
to write these kind of algorithms yourself.

(May 2012) [PythonGDB Tutorial for Reverse Engineering](http://blog.lse.epita.fr/articles/10-pythongdb-tutorial-for-reverse-engineering---part-.html)  
> First and last article of a series that I planned to write on PythonGDB uses in
my reverse engineering work, sadly I never found the motivation to write more
(about topics like tracing automation, for example). Still, this is a pretty
nice introduction to what's possible with the PythonGDB API.

(Apr 2012) [Static Analysis of an Unknown Compression Format](http://blog.lse.epita.fr/articles/8-static-analysis-of-an-unknown-compression-format.html)  
> Taking an unknown binary compression format and staring at it long enough until
it makes sense. This was a very fun experience for me since I never really knew
much about compression before working on this reverse engineering work. This
article should be very interesting if you're interested in how reverse
engineers think when confronted with a new problem they don't know.

(Mar 2012) [More Fun with the NDH2K12 Prequals VM](http://blog.lse.epita.fr/articles/7-more-fun-with-the-ndh2k12-prequals-vm.html)  
> Escaping and exploiting a VM running with ASLR and NX enabled, using
/proc/self/mem to bypass memory write protections (very cool trick that is
unfortunately not that well known).

### Talks

30th Chaos Communication Congress (2013, 30C3)

- [Reverse Engineering the Wii U Gamepad](https://fahrplan.events.ccc.de/congress/2013/Fahrplan/events/5322.html) ([slides](https://docs.google.com/presentation/d/126fk9mO5jROMfuw-2ASDv7-YH_A0LZO0Phxedh9deiE/edit?usp=sharing), [video](https://media.ccc.de/v/30C3_-_5322_-_en_-_saal_g_-_201312292030_-_reverse_engineering_the_wii_u_gamepad_-_delroth))

At university / *LSE Week* seminars

- Using SAT Solvers for Security Related Problems ([slides](slides/sat-solvers-sec.pdf))
- Reverse Engineering a DSP Firmware ([slides](slides/re-emu-dsp.pdf))
- LSE Week 2012 Crackme Making-Of ([slides](slides/lseweek2k12-crackme.pdf))
- WPA2 Enterprise and Wi-Fi security ([slides](slides/wpa2-wifi.pdf))
- Video Game Consoles Emulation: HOWTO? ([slides](slides/vgemu.pdf))
- Security of Video Game Consoles ([slides](slides/state-of-the-hack.pdf))
- Anti-debugging on Linux using vm86 ([slides](slides/vm86.pdf))
- Merkle Trees and Integrity Checking ([slides](slides/merkle-trees.pdf))
- Reverse Engineering a Bytecode VM ([slides](slides/interpreter-re.pdf))
- The Nintendo Wii Security Model ([slides](slides/wii-security.pdf))
- 3D Programming With OpenGL ([slides](slides/gl-intro.pdf))
- Introduction to the Python Programming Language ([slides](slides/python-intro.pdf))

## In the past

### Non-profit work

I used to be an organizer for [Prologin](https://prologin.org), the French
national youth programming contest. I was an active member of the team from
2008 to 2016, and a [member of the board in
2011](https://prologin.org/team/2011).

At Prologin I ended up redesigning the whole software infrastructure used to
host the competition's finals (~100 contestants over ~48h, akin to a LAN Party
environment but with slightly higher stakes). I was also the main author of the
software used to run matches between AIs/actors written by the contestants.

### Education

I studied computer science at [EPITA](https://epita.fr) (Paris, France). I am
an *Ingénieur diplômé*, which is roughly equivalent to a Professional Engineer
status and is MSc equivalent.

During my studies I was a member of the [LSE](https://www.lse.epita.fr), the
university's Systems and Security research lab. There I worked on various
low-level projects such as kernel and drivers development, hardware and
firmware emulation, or reverse engineering tooling.

I was a part of the lab's CTF team, which made it to a respectable [5th place
CTFTime ranking](https://ctftime.org/stats/2012) in 2012.
