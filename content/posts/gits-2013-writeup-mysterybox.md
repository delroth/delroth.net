---
title: 'GITS 2013 Writeup: MysteryBox (re300)'
date: 2013-02-17T02:00:00+02:00
tags: ["CTF", "writeup", "hacking", "reverse-engineering"]
draft: false
---

MysteryBox was a remote server disassembling and running its input data for an
unknown RISC-like CPU. As far as I know the unknown CPU is not a "real" CPU but
a VM made solely for this challenge. Here is an example of how to interact with
the remote MysteryBox service:

{{< highlight shell-session >}}
$ perl -e 'print "\x00\x00\x00\x00"' |
        nc mysterybox.2013.ghostintheshellcode.com 4242
09007800  ldb sp, sp, sp
Caught signal 11.  Program terminated.
 sp=0900bc08  r1=00000000  r2=00000000  r3=00000000  r4=00000000  r5=00000000
 r6=00000000  r7=00000000  r8=00000000  r9=00000000 r10=00000000 r11=00000000
r12=00000000 r13=00000000 r14=00000000 r15=00000000 r16=00000000 r17=00000000
r18=00000000 r19=00000000 r20=00000000 r21=00000000 r22=00000000 r23=00000000
r24=00000000 r25=00000000 r26=00000000 r27=00000000 r28=00000000 r29=00000000
 lr=00000000  ip=09007800  cc=ffff
{{< / highlight >}}

<!--more-->

We can see the remote service disassembled our `00 00 00 00` bytes to `ldb sp,
sp, sp` and crashed while executing it (crash dump `ip` points to our
instruction). After playing a bit with the disassembler, I figured out how
instructions were encoded, and ran a loop to get all the instructions supported
by this CPU:

```
00000000        ldb sp, sp, sp
01000000        stb sp, sp, sp
02000000        ldbu sp, sp, sp
03000000        stbu sp, sp, sp
04000000        ldsxb sp, sp, sp
05000000        ldi sp, 0
06000000        add sp, sp, sp
07000000        mulx sp, sp, sp, sp
08000000        div sp, sp, sp
09000000        and sp, sp, sp
0a000000        shl sp, sp, sp
0b000000        syscall 0  ; SYS_restart_syscall
0c000000        ldfs f0, sp, sp
0d000000        ldfsu f0, sp, sp
0e000000        fadd f0, f0, f0
0f000000        fmod f0, f0, f0
00400000        ldh sp, sp, sp
01400000        sth sp, sp, sp
02400000        ldhu sp, sp, sp
03400000        sthu sp, sp, sp
04400000        ldsxh sp, sp, sp
05400000        ldih sp, 0
06400000        sub sp, sp, sp
07400000        imulx sp, sp, sp, sp
08400000        idiv sp, sp, sp
09400000        or sp, sp, sp
0a400000        shr sp, sp, sp
0b400000        cmplt0 sp, sp
0c400000        ldfd f0, sp, sp
0d400000        ldfdu f0, sp, sp
0e400000        fsub f0, f0, f0
0f400000        fpow f0, f0, f0
00800000        ldw sp, sp, sp
01800000        stw sp, sp, sp
02800000        ldwu sp, sp, sp
03800000        stwu sp, sp, sp
04800000        ldsxbu sp, sp, sp
05800000        jmp 0x08a3b898
06800000        addx sp, sp, sp
07800000        mul sp, sp, sp
08800000        mod sp, sp, sp
09800000        xor sp, sp, sp
0a800000        rol sp, sp, sp
0b800000        icmplt0 sp, sp
0c800000        stfs f0, sp, sp
0d800000        stfsu f0, sp, sp
0e800000        fmul f0, f0, f0
0f800000        flog f0, f0, f0
00c00000        ldmw sp, sp, sp
01c00000        stmw sp, sp, sp
02c00000        ldmwu sp, sp, sp
03c00000        stmwu sp, sp, sp
04c00000        ldsxhu sp, sp, sp
05c00000        call 0x08a3b8d8
06c00000        subx sp, sp, sp
07c00000        mov sp, sp
08c00000        imod sp, sp, sp
09c00000        sar sp, sp, sp
0ac00000        ror sp, sp, sp
0bc00000        fcmplt0 f0, f0
0cc00000        stfd f0, sp, sp
0dc00000        stfdu f0, sp, sp
0ec00000        fdiv f0, f0, f0
0fc00000        ldfi f0, sp
```

More details about this architecture: it is little-endian, each instruction can
be made conditional (like ARM) and the result of an arithmetic operation can be
shifted left by up to 16 bits. While most instructions use 3 registers, some
also use one register and a 16 bit, sign-extended immediate. From there, I
started to experiment a bit and wrote a simple `write(4, "h", 1)` shellcode:

{{< highlight python >}}
def gen_string(s):
    instrs = []
    for i, c in enumerate(s):
        c = ord(c)
        instrs.append(0x05020000 | i) # ldi r1, [i]
        instrs.append(0x05040000 | c) # ldi r2,
        instrs.append(0x03040020)     # stbu r2, sp, r1
    return instrs

instrs = gen_string('h')
instrs += [
    0x05020004, # ldi r1, 4
    0x07c40000, # mov r2, sp
    0x05060001, # ldi r3, 1
    0x0b000004, # syscall SYS_write
]
{{< / highlight >}}

This works well, however our goal is to get a shell! For that, we need
to `execve("/bin/sh", { "/bin/sh", NULL }, NULL)`. But this is not
enough: `sh` tries to communicate using standard stdin/out/err FDs (0, 1, 2).
We need to write something to `dup2` our socket over these FDs:

{{< highlight python >}}
def gen_string(s):
    instrs = []
    for i, c in enumerate(s):
        c = ord(c)
        instrs.append(0x05020000 | i) # ldi r1, [i]
        instrs.append(0x05040000 | c) # ldi r2,
        instrs.append(0x03040020)     # stbu r2, sp, r1
    return instrs

def dup2(f, g):
    return [
        0x05020000 | f, # ldi r1, [f]
        0x05040000 | g, # ldi r2, [g]
        0x0b000000 | 63 # syscall SYS_dup2
    ]

instrs = []
instrs += dup2(4, 0)
instrs += dup2(4, 1)
instrs += dup2(4, 2)
instrs += gen_string('h')
instrs += [
    0x05020001, # ldi r1, STDOUT_FILENO
    0x07c40000, # mov r2, sp
    0x05060001, # ldi r3, 1
    0x0b000004, # syscall SYS_write
]
{{< / highlight >}}

Our write syscall is now using `STDOUT_FILENO` (aka. 1) and working fine, which
means our `dup2` calls are working. Now we need to `execve` our shell. This
shellcode stores `"/bin/sh"` at address `sp+16`, and stores `argv` (aka. `{
sp+16, 0 }`) at address `sp`. Note that the previous `gen_string` had a bug
because it was using `stbu` (store then update the pointer) instead
of `stb` (simply store).

{{< highlight python >}}
def gen_string(s):
    instrs = []
    for i, c in enumerate(s):
        c = ord(c)
        instrs.append(0x05020000 | (i + 16)) # ldi r1, [i+16]
        instrs.append(0x05040000 | c) # ldi r2,
        instrs.append(0x01040020)     # stb r2, sp, r1
    return instrs

def dup2(f, g):
    return [
        0x05020000 | f, # ldi r1, [f]
        0x05040000 | g, # ldi r2, [g]
        0x0b000000 | 63 # syscall SYS_dup2
    ]

instrs = []
instrs += dup2(4, 0)
instrs += dup2(4, 1)
instrs += dup2(4, 2)
instrs += gen_string('/bin/sh\x00')
instrs += [
    0x05020010, # ldi r1, 16
    0x06021000, # add r1, r1, sp
    0x05040004, # ldi r2, 4
    0x06042000, # add r2, r2, sp
    0x01863040, # stw r3, r3, r2
    0x07c40000, # mov r2, sp
    0x01823040, # stw r1, r3, r2
    0x0b00000b, # syscall SYS_execve
]
{{< / highlight >}}

With our shell we can now `cat key` to finally solve this challenge.
