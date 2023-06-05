---
title: "Emulators and bundling crypto keys: is it common? is it illegal?"
date: 2023-06-05T00:00:00+02:00
draft: false
---

*This blog post is a copy of [an article I posted on the /r/emulation subreddit](https://www.reddit.com/r/emulation/comments/140b7x5/are_dolphin_devs_special_in_bundling_decryption/)
regarding the recent Dolphin / Valve / Nintendo "drama". You can read it with
comments over there.*

On [/r/emulation 8 days
ago](https://www.reddit.com/r/emulation/comments/13ss1o9/nintendo_sends_valve_dmca_notice_to_block_steam/jlry1kq/?context=3)
/u/b0b_d0e (with a "Citra Developer" flair) mentioned:

> That's right, you know how on all these other emulators like citra, ryu,
> yuzu, cemu etc they all say "dump your keys by following this guide" ever
> wonder why you didn't need that with dolphin?
>
> BECAUSE DOLPHIN ILLEGALLY DISTRIBUTES NINTENDO'S WII DECRYPTION KEY


I never really spent the time trying to reply to this. At the time I was more
busy trying to make people understand the difference between a DMCA notice and
what happened between Valve and Nintendo. But then this was also [picked up by
my favorite emulation not-journalist
MVG](https://www.youtube.com/watch?v=W5bfpS-WYUA) who even doubled down on the
keys situation in his apology-update video.

So, I wondered: how do other emulators actually fare? I'll let you decide on
your own:

<!--more-->

- PPSSPP: https://github.com/hrydgard/ppsspp/blob/master/Core/ELF/PrxDecrypter.cpp#L20
- RPCS3: https://github.com/RPCS3/rpcs3/blob/master/rpcs3/Crypto/key_vault.cpp#L25
- Xenia: https://github.com/xenia-project/xenia/blob/master/src/xenia/cpu/xex_module.cc#L32
- Cemu: https://github.com/cemu-project/Cemu/blob/master/src/Cemu/ncrypto/ncrypto.cpp#L340
- Citra: https://github.com/citra-emu/citra/blob/master/src/core/hw/aes/key.cpp#L36
- Desmume: https://github.com/TASEmulators/desmume/blob/master/desmume/src/utils/decrypt/decrypt.cpp#L33
- Ryujinx: https://github.com/Thealexbarney/LibHac/blob/master/build/CodeGen/IncludedKeys.txt
- Vita3k: https://github.com/Vita3K/Vita3K/blob/master/vita3k/packages/src/sce_utils.cpp#L39
- melonDS: https://github.com/melonDS-emu/melonDS/blob/master/src/DSi_AES.cpp#L141
- no$gba: https://gist.github.com/delroth/4fb0528a2306147a38a89817c3ef304c

Almost everyone bundles keys, even Citra (who I'm sure will argue that their 16
random bytes aren't technically a key, they're just the seed burnt into the 3DS
hardware which is used as the source for most of the crypto keys used on the
console).

Is this illegal, as /u/b0b_d0e mentioned? I'm not a lawyer, but I've talked to
lawyers in the past, and here's my (personal) analysis.

### Are keys copyrightable?

Like many things related to copyright, [it's unclear](https://www.youtube.com/watch?v=1Jwo5qc78QU).
The laws are vague and very open to interpretation. One of the preconditions
for copyright is generally understood to be that the work needs to be
"creative" in nature. This would not apply for all of the keys listed here that
are either random numbers, random prime numbers, or just words like "Nintendo".

Interestingly, Apple did try to make copyright applicable to one of their
secret keys by making it a Haiku. Poetry is widely understood to be
copyrightable. I don't think they've tried suing anyone for copyright
infringement on that haiku yet, however they did try to claim it was a "trade
secret". Courts [denied that motion](https://www.rcfp.org/wp-content/uploads/imported/20120105_202426_apple_sealing.pdf)
with the interesting consequence that their haiku decryption key is now
publicly quoted in a court record document (page 3, line 16).

In 2007 the MPAA tried to remove the AACS decryption key from the internet by
sending legal letters to website owners(most famously Digg). Some websites
removed the keys, others did not. This is sometimes listed as an instance
showing that keys can be copyrighted. But in fact, it only shows that the AACS
believes they can strong-arm some website owners to remove material. No court
has ruled on the AACS decryption key case. If the MPAA believed to have a
strong legal case in their favor, it would have been trivial for their army of
lawyers to go defend it in court -- and I think it is a notable point that they
didn't.

### Are keys copy-protection circumvention measures?

17 USC 1201 (DMCA anti-circumvention) has even fewer legal precedents for its
grey areas than copyright does. It makes illegal the acts of "circumvent[ing] a
technological measure that effectively controls access to a work protected
under [copyright]" as well as "manufactur[ing], import[ing], offer[ing] to the
public, provid[ing], or otherwise traffic[king] in any technology, product,
service, device, component, or part thereof, that [...] is primarily designed
or produced for the purpose of circumventing a technological measure that
effectively controls access to a work protected under [copyright]".

Note that 17 USC 1201 does not mention encryption keys. It does however mention
that the primary purpose needs to be circumvention. So, let's say someone
distributes a tool which turns encrypted Wii disc images into decrypted Wii
disc images, and requires as input the Wii Common Key. In my opinion, that tool
would still have as primary purpose to circumvent a copy protection measure,
and bundling or not bundling the key would be irrelevant. As far as I know,
such a situation has never been tested in court, so this would be new legal
territory which could go either in Nintendo's favor or the tool author's favor
-- but I suspect it would go in Nintendo's favor.

### Are emulators copy-protection circumvention measures?

Now, the more interesting question is whether an emulator is "primarily
designed or produced for the purpose of circumventing a technological measure".
I don't think that's obvious. If a court were to rule that they are, emulation
for any console that employs DRM is pretty much illegal -- keys or not (again:
17 USC 1201 does not mention keys anywhere).

Nintendo, Sony, Microsoft, Sega, etc. have had 15+ years to try and fight that
case. So far, they haven't, so I suspect they also don't think it's obvious.

### Conclusion

Copyright and the DMCA are vague laws. There are things that are very clearly
disallowed: bundling BIOS code with an emulator, for example, since that code
would be a creative work. There are things that are very clearly allowed: for
example, using a work under the terms of its (explicit) licensing. And there
are many many things that aren't clearly allowed or disallowed. Video game
screenshots. Video game videos or streams that aren't reviews. What qualifies
as "fair use". Whether decryption keys are creative works covered under
copyright. Let's plays. Memes. And, whether emulators are or are not primarily
designed to circumvent copy protection.

Being in the grey area does not mean you're morally right or wrong. It's just a
consequence of the vagueness of laws written in the 90s that have very much not
kept up with technology. A third of the relevant law for emulation and
circumvention (17 USC 1201) is written to cover what kind of VHS copying is
allowed or disallowed. "No person shall apply the automatic gain control copy
control technology or colorstripe copy control technology to prevent or limit
consumer copying except such copying". Maybe if they went into that much
details on emulation or modern DRM technology that uses encryption, we could
have clear answers. But we don't, and anyone who claims they have those answers
are most likely lying to you.
