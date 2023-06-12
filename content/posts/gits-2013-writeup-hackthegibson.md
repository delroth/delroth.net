---
title: 'GITS 2013 Writeup: HackTheGibson (re250)'
date: 2013-02-17T00:00:00+02:00
tags: ["CTF", "writeup", "hacking"]
draft: false
---

```
hackthegibson: ELF 64-bit LSB executable, x86-64, version 1 (SYSV),
    dynamically linked (uses shared libs), for GNU/Linux 2.6.15,
    BuildID[sha1]=0xb8515e4280130d84d4b4e1fd492da1b099ec0eb6, stripped
```

`hackthegibson` is a 64-bit ELF for Linux using OpenSSL (`libcrypto`) and FFTW
to analyze the spectrum of samples coming from `/dev/dsp`.

The program does not take a key as an input, only sound data. That means it
will most likely generate and display a key based on the sound. Indeed, at the
address `0x401963` we can see that the program uses `MD5_Final` to generate a
MD5 digest and displays it in hex using a `printf("%02x")` loop. Let's look at
all the references to `MD5_Update` to understand how this MD5 digest is
computed:

-   Just before the program main loop, the first call to `MD5_Update` hashes 1
    constant byte `0x14`
-   At each iteration of the program main loop, if the function analyzing the
    sound data returns the expected value (checked using a table mapping
    iteration number to expected value) `MD5_Update` is called using that
    expected value.
-   Just before the call to `MD5_Final` the constant byte `0x14` is hashed once
    again.

<!--more-->

iThis second point is the most important. Basically, here is the simplified
pseudocode of the program:

{{< highlight c >}}
int expected_vals[22];

void init_expected() { // sub_400df4
    expected_vals[0] = '_';
    expected_vals[1] = '<';
    expected_vals[2] = 'P';
    // ...
    expected_vals[21] = 'G';
}

void mainloop() {
    int iter_count = 0;

    MD5_Update(0x14);
    while (iter_count < 22) {
        int ret = analyze_sound_data();
        if (ret == expected_vals[iter_count]) {
            iter_count++;
            MD5_Update(ret);
        }
     }
     MD5_Update(0x14);
     MD5_Final();
}
{{< / highlight >}}

We can simply read all the expected values from the initialization function and
compute the MD5 without even running the program! (which was lucky: it
uses `/dev/dsp` which my system does not have...)

{{< highlight python >}}
>>> import hashlib
>>> hashlib.md5('\x14_<P_Y5GYP<jGPY5GYP5CPG\x14').hexdigest()
'667e948a0285b25dafd2c58a2531f2c3'
{{< / highlight >}}
