---
title: 'Boston Key Party crackme300 "hypercube" writeup'
date: 2014-03-02T00:00:00+02:00
tags: ["CTF", "writeup", "hacking", "reverse-engineering", "nintendo"]
draft: false
---

Been a while since I last took the time to solve a CTF challenge. I did not
take part in the Boston Key Party CTF, but a friend of mine told me that I
might be interested in this crackme.

hypercube.dol is a GameCube binary that computes a value using terribly
unoptimized code. The goal of the challenge is to understand the code and
“optimize” the slow parts. Kind of like the “supercomputer” category from
PlaidCTF. I like crackmes and I like GameCube RE, so let’s get started!

<!--more-->

## First look

{{< highlight shell-session >}}
$ strings hypercube-5f456d4afe1cae8909b3ff9abba66c0a.dol | grep -i libogc
|libOGC Release 1.8.11
{{< / highlight >}}

This GameCube binary is in [DOL format](http://wiibrew.org/wiki/DOL) (the main
executable format for GameCube and Wii) and was built using the [libogc homebrew library](http://wiibrew.org/wiki/Libogc),
and more precisely its latest release. The DOL is stripped, but using
symbolizer from [GiantPune’s WiiQt project](https://code.google.com/p/wiiqt/source/browse/#svn%2Ftrunk%2Fsymbolizer)
we can easily get a .idc out of it:

{{< highlight shell-session >}}
$ ./symbolizer ../../hypercube-5f456d4afe1cae8909b3ff9abba66c0a.dol \
        /opt/devkitpro/libogc/lib/cube out.idc
Loading dol...
Loading libs...
matching data...
 -- Round 0 / 10 --
 - added 106 new functions -
 -- Round 1 / 10 --
 - added 16 new functions -
 -- Round 2 / 10 --
 - added 4 new functions -
 -- Round 3 / 10 --
no new functions found 3
Total functions found: 310
 -- Round 0 / 10  following branches --
 - added 70 new functions -
 -- Round 1 / 10  following branches --
 - added 2 new functions -
 -- Round 2 / 10  following branches --
 -- Round 0 / 10  following branches and global variables --
 - added 2 new functions -
 -- Round 1 / 10  following branches and global variables --
Total global variables:  87
Total data matches:      21
Total functions found:   395
Generating idc file...

$ wc -l out.idc
858 out.idc
{{< / highlight >}}

## Looking at the code

Let’s start disassembling the thing now that we have a few symbols. For that,
we use IDA and the very convenient DOL loader module created by HyperIris: [IDA 6.1 version](http://blog.delroth.net/2012/03/gcwii-dol-plugin-built-for-ida-6-1/).
Let’s look for `__lwp_sysinit`, since it is usually where the `main` function
is used:

{{< highlight c >}}
void __lwp_sysinit() {
  // ...
  __lwp_thread_start(_thr_main,(void*)__crtmain,NULL);
  // ...
}
{{< / highlight >}}

From there, we determine that `__crtmain` is at `0x8000340C`, and it then calls
`main` at `0x80005BC4`. We could have looked at string x-refs to determine the
same thing, but we usually don’t get this luxury (and at this point we haven’t
run the binary yet so we don’t know about `main` displaying some strings).

`main` has a loop that computes four different values (stored on the stack:
`0x8(r31)`, `0xC(r31)`, `0x10(r31)` and `0x14(r31)`, with `r31` being the frame
pointer). Let’s call these values a, b, c, d and look at how they’re
initialized:

{{< highlight asm >}}
.text1:80005C2C                 li        r0, 0xADD
.text1:80005C30                 stw       r0, StackFrame.a(r31)
.text1:80005C34                 lis       r0, 5 # 0x5DD11
.text1:80005C38                 ori       r0, r0, 0xDD11 # 0x5DD11
.text1:80005C3C                 stw       r0, StackFrame.b(r31)
.text1:80005C40                 lis       r0, 0x35 # 0x352463
.text1:80005C44                 ori       r0, r0, 0x2463 # 0x352463
.text1:80005C48                 stw       r0, StackFrame.c(r31)
.text1:80005C4C                 lis       r0, 0x800 # 0x8008135
.text1:80005C50                 ori       r0, r0, 0x8135 # 0x8008135
.text1:80005C54                 stw       r0, StackFrame.d(r31)
{{< / highlight >}}

We start with `a = 0xADD, b = 0x5DD11, c = 0x352463` and `d = 0x8008135`. Now
we need to look at the loop and what exactly it computes (then how we can make
it faster):

## The loop

First things first: how do we exit the loop. The relevant code is this:

{{< highlight asm >}}
.text1:80005C58 loop_entry:
.text1:80005C58                 li        r0, 0
.text1:80005C5C                 stw       r0, 0x18(r31)
.text1:80005C60                 b         loop_condition

.text1:80005D3C loop_condition:                         # CODE XREF: sub_80005BC4+9C
.text1:80005D3C                 lwz       r0, 0x18(r31)
.text1:80005D40                 cmpwi     cr7, r0, 0x7A9E
.text1:80005D44                 crnot     4*cr7+eq, 4*cr7+gt
.text1:80005D48                 mfcr      r0
.text1:80005D4C                 extrwi    r0, r0, 1,30
.text1:80005D50                 clrlwi    r0, r0, 24
.text1:80005D54                 cmpwi     cr7, r0, 0
.text1:80005D58                 bne       cr7, loop_body
{{< / highlight >}}

This code is an horribly unoptimized way to have the following: an integer
variable that goes from 0 to 0x7A9E (non inclusive). But what’s inside this
loop?

{{< highlight asm >}}
.text1:80005C64 loop_body:                              # CODE XREF: sub_80005BC4+194
.text1:80005C64                 li        r0, 0
.text1:80005C68                 stw       r0, 0x1C(r31)
.text1:80005C6C                 b         inside_loop_condition

.text1:80005D10 inside_loop_condition:                  # CODE XREF: sub_80005BC4+A8
.text1:80005D10                 lwz       r0, 0x1C(r31)
.text1:80005D14                 cmpwi     cr7, r0, 0x15
.text1:80005D18                 crnot     4*cr7+eq, 4*cr7+gt
.text1:80005D1C                 mfcr      r0
.text1:80005D20                 extrwi    r0, r0, 1,30
.text1:80005D24                 clrlwi    r0, r0, 24
.text1:80005D28                 cmpwi     cr7, r0, 0
.text1:80005D2C                 bne       cr7, inside_loop_body
{{< / highlight >}}

The exact same thing! A loop, which this times goes from 0 to 0x15. Now, the
inner loop code is quite long, so I will directly skip to the pseudocode of the
whole outer loop:

{{< highlight c >}}
  for (u32 i = 0; i < 0x7A9E; ++i) {
    for (u32 j = 0; i < 0x15; ++j) {
      a = func1(b, c); // approximate
      b = func1(b, 0x6DDB); // approximate
      c = b ^ 0x1BA41C3C;
      d = func2(d);
    }
  }
{{< / highlight >}}

The inner loop calls two functions: `func1 (@ 0x80005B18)` and `func2 (@
0x800059E4)`. `func1`'s code calls `func3 (@ 0x80005A4C)`, which itself calls
`func2`. It looks like `func2` is where it all ends up, let's start there.

### func2 (@ 0x800059E4)

{{< highlight c >}}
u32 func2(u32 x) {
  s32 y = 1;
  do {
    x -= 1;
    y += 1;
  } while (y != 0);
  return x;
}
{{< / highlight >}}

Computes `x - 0xFFFFFFFF`, aka. `x + 1`. In a very, very slow way. We can
replace the code of this function with the following code:

{{< highlight asm >}}
.text1:800059E4 func2:                                  # CODE XREF: sub_80005A4C+34
.text1:800059E4                                         # sub_80005A4C+78 ...
.text1:800059E4                 addic     r3, r3, 1
.text1:800059E8                 blr
.text1:800059E8 # End of function func2
{{< / highlight >}}

### func3 (@ 0x80005A4C)

When looking at the code of `func3(x, y)`, we can notice it is doing `ret =
func2(ret);` several times and contains two loops that seem to depend on the
values of the arguments: x and y. Let's make an educated guess: `func3(x, y) ->
x + y`:

{{< highlight asm >}}
.text1:80005A4C func3:                                  # CODE XREF: func1+58
.text1:80005A4C                 add       r3, r3, r4
.text1:80005A50                 blr
{{< / highlight >}}

### func1 (@ 0x0x80005B18)

`func1(x, y)` adds something in a loop to the output value. Another educated
guess: `func1(x, y) -> x * y`:

{{< highlight asm >}}
.text1:80005B18 func1:                                  # CODE XREF: sub_80005BC4+B4
.text1:80005B18                                         # sub_80005BC4+F0
.text1:80005B18                 mullw     r3, r3, r4
.text1:80005B1C                 blr
{{< / highlight >}}

## Result

We can now running the code, and with the only loops remaining being the two
loops in main, we instantly get the result:

`key{1337812927326272294680194969380h4x134941407}`
