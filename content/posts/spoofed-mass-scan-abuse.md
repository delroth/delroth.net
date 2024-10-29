---
title: 'One weird trick to get the whole planet to send abuse complaints to your best friend(s)'
date: 2024-10-29T10:00:00+01:00
tags: ["security", "networking", "abuse"]
draft: false
---

It all begins with one scary email late at night just before I had to go to
sleep:

<div class="smaller">

```
From: abuse@hetzner.com
Date: 2024-10-29 01:03:00 CET
Subject: AbuseInfo: Potential Security issue: AS24940: 195.201.9.37

We have received an abuse report from abuse@watchdogcyberdefense.com for your
IP address 195.201.9.37.

We are automatically forwarding this report on to you, for your information.
You do not need to respond, but we do expect you to check it and to resolve any
potential issues.

> To assist you in understanding the situation, we have provided the relevant
> log data below, with timestamps adjusted to our GMT +8 timezone:
>
>                 DateTime   Action      AttackClass      SourceIP Srcport Protocol   DestinationIP DestPort
> 0   28-Oct-2024 19:39:11   DENIED                   195.201.9.37   36163      TCP  202.91.162.233       22
> <snip>
> 20  28-Oct-2024 20:36:33   DENIED                   195.201.9.37   22044      TCP   202.91.161.97       22
> 21  28-Oct-2024 20:41:37   DENIED                   195.201.9.37    9305      TCP   202.91.163.36       22
> 22  28-Oct-2024 20:50:33   DENIED                   195.201.9.37   39588      TCP  202.91.163.199       22
> 23  28-Oct-2024 20:50:58   DENIED                   195.201.9.37   62973      TCP   202.91.161.41       22
> 24  28-Oct-2024 20:51:50   DENIED                   195.201.9.37    3085      TCP   202.91.161.97       22
```

</div>

<!--more-->

At first glance, this sounds pretty bad. One of my servers suddenly deciding to
start sending SSH connections to the wider internet. This is usually a pretty
strong indicator of malware compromise, and I had to act quickly if that was
the case.  Luckily, I've worked in infosec for a while, and some years ago I
even did some freelance work doing forensics and cleanup of infected servers.

So, not completely out of my element, I was surprised when after an hour or two
I found no evidence of anything happening out of the ordinary. It's always hard
to prove a negative, but really, the machine was fine. No odd process, no
filesystem modifications, no odd network traffic (as observed by the
hypervisor, not by the server itself which happens to be a VM - just to be
extra sure!). If it was a malware compromise incident, the malware would have
been pretty stealthy, and that runs against the idea of it having been
commanded to scan the internet - in general, a very loud and noticeable action.

I turned to the regularly running services on the machine. This is my main
datacenter-hosted server, and I run a bunch of distributed or federated
services on there:

- Syncthing relay.
- Mastodon instance.
- Tor relay (not exit, internal node only).
- Matrix homeserver.

After close inspection, the Tor relay does connect to a few other relays that
are hosted on port 22, but that's a very limited set of IPs, and it doesn't
include anything in the network that sent my ISP the abuse complaint. Unlikely
candidate. I thought maybe Matrix or Mastodon could be abused to send commanded
requests to arbitrary IP:port destinations, but logging for both indicated
nothing of the sort was (visibly) happening. The Sidekiq queue for my Mastodon
instance was also absent of any trace of this, when I'd have expected to see
e.g. retries queued if it was involved.

What was happening there? Was the abuse complaint just bogus?

## The smoking gun

Then, I noticed something in one of my `tcpdump` that was still running to
monitor traffic involving port 22 on that server. I had originally ran
`tcpdump` filtering on `dst port 22`, since this is what would show traffic
originating from my server going to remote destinations. However, for some
reason, I dropped that filter at some point, instead filtering `not src host
195.201.9.37` instead (my server's IP). This is when this showed up:

<div class="smaller">

```
04:14:25.286063 IP 45.187.212.68.22 > 195.201.9.37.59639: Flags [R.], seq 0, ack 41396686, win 0, length 0
04:14:25.291455 IP 107.152.7.33.22 > 195.201.9.37.39793: Flags [R.], seq 0, ack 1391844539, win 0, length 0
04:14:25.322255 IP 107.91.78.158.22 > 195.201.9.37.48900: Flags [R.], seq 0, ack 1434896088, win 65535, length 0
```

</div>

Something *was* in fact going on. But not at all what I was expecting. Turns
out: no connections were coming out of my server and going to the port 22 of
random machines. But some random internet machines *were* in fact sending me
TCP reset packets.

If you've been around networking/infosec communities for a while, you might now
be screaming: backscatter! Source IP spoofing! And yeah, this was my first
thought too. Let's do a quick aside to go into what those things mean.

## IP spoofing on the internet

Turns out, it's pretty trivial to send packets to various destinations on the
Internet with a fake source IP address (of course, the destination IP needs to
be correct, since it determines... the destination). Many ISPs adhere to the
[Best Current Practice (BCP) 38](https://www.rfc-editor.org/info/bcp38), which
can be summarized by the following: "if you peer with a network, you should
only allow them to send IP packets using IP address you expect from them".
Unfortunately, that filtering can often only be done early on in a packet's
route to its destination. Once the packet gets to a large transit provider,
their peers expect that provider to carry traffic from the whole internet to
them, and thus are not able to do any meaningful filtering.

Which means, if you just find one transit provider which doesn't do BCP38
filtering... you can send IP packets tagged with any source IP you want! And
unfortunately, even though the origins of BCP38 date back to 1998... there are
still network providers 25 years later that don't implement it. APNIC has [a
great article from last year on the subject](https://blog.apnic.net/2023/05/03/why-is-source-address-validation-still-a-problem/).

The consequences in practice shouldn't be too bad. TCP, QUIC, and generally
anything using (d)TLS requires roundtrips, which can't happen when a source IP
is spoofed. Spoofing the source IP means that you get to send a "wrong"
packets, but the replies to that packet still get sent to the source IP you
spoofed, the spoofer doesn't get to see them and process them. There are a few
well known abuse vectors that rely on spoofing, such as reflection DDoS, but
it's not usually a concern.

Unless...

## Guessing the motive

Let's come back to my `RST` packets. The main hypothesis is that someone is
using my source IP to send outbound connections to the port 22 of various
internet machines. But it doesn't really make logical sense at a first glance.
Usually, people would do this to scan for open ports or servers with a working
SSH server. However, none of that works when you spoof a source IP, since you
don't get to see the results of you probing!

Back in the earlier days of the internet, there used to be a technique called
"Idle Scanning", which relied on 1. servers being way less busy than today; 2.
network stacks lacking randomization of some fields and using auto-incrementing
predictable counters. This could be used to probe whether a port is open while
spofing a source IP (for anonymity, or to bypass firewalls). But that technique
has been dead and unusable for decades.

So, maybe someone set up a scanner and typo'd their source IP in a
configuration file, causing random internet machines to think I'm initiating
connections to them? But... the traffic volume seems too low, the duration of
the weirdness too long, and really it would be a stretch anyway.

Whatever the spoofer's motive, it's kind of annoying. Their scan is hitting
honeypots, networks with intrusion detection systems that send (sometimes
automated) abuse complaints, and so on. I wish they'd notice that whatever
they're doing isn't working, because I don't particularly enjoy getting abuse
complaints, and they put me at risk of being kicked out of my hosting provider.

... wait a minute?!

## The Tor connection

I mentioned in passing earlier that one of the services I run on my server is a
Tor relay. Relays are internal nodes of the Tor network. They only carry
anonymous, encrypted traffic (in fact, usually with multiple layers of
encryption), and only between consenting opt-in nodes of the Tor network.
Relays aren't exit nodes, they don't talk to the open internet. A few selected
relays are also "Guard Nodes", which can serve as the entry point to the Tor
network. These technically talk to the open internet, but still, only
consenting users connecting to the Tor network.

For that reason I originally kind of ruled out Tor having any connection (pun
intended) to this abuse issue. And I'm sure some of you were screaming about
it, but hey, you probably have the benefit of 1. hindsight; 2. not being up at
4AM running `tcpdump`.

But Tor has one peculiarity: there are actors on the internet that don't like
it. There are many good and bad reasons for this - I personally view Tor as a
"useful neutral cesspool", but this is not an article about ethics, and it's
simple enough to say that some people disagree. Said people range from
"individual hacktivists" to "police forces" to "government agencies", with
various levels of sophistications and differing techniques.

Could someone be deliberately trying to induce abuse complaints on Tor network
participants to take down parts of the network (or disincetivize running
internal nodes, which are key for the network's health)?

Easy enough to check. I run more relay nodes, so let's just `tcpdump` there
too. One at home on my residential IP connection, one on a Linode VPS in Japan:

<div class="smaller">

```
04:19:14.705034 IP 198.30.233.69.22 > 172.105.199.155.39998: Flags [R.], seq 0, ack 171173954, win 0, length 0
04:20:15.135733 IP 124.198.33.196.22 > 172.105.199.155.23506: Flags [R.], seq 0, ack 1985822135, win 0, length 0
04:21:30.222739 IP 223.29.149.158.22 > 172.105.199.155.27507: Flags [R.], seq 0, ack 3614869158, win 0, length 0

04:12:39.470366 IP 121.150.242.252.22 > 77.109.152.87.57627: Flags [R.], seq 0, ack 2452733863, win 0, length 0
04:13:05.549920 IP 46.188.201.102.22 > 77.109.152.87.9999: Flags [R.], seq 0, ack 3253922544, win 0, length 0
04:14:33.027326 IP 1.1.195.62.22 > 77.109.152.87.52448: Flags [R.], seq 0, ack 351972505, win 0, length 0
```

</div>

Annnnnd yep, my two other relays running in completely different countries and
with completely different ISPs are seeing the same spoofed TCP SYN pattern.

This is when I sent [an email to the `tor-relays` mailing list](https://lists.torproject.org/pipermail/tor-relays/2024-October/021953.html),
where... it turns out someone had [noticed and diagnosed the same thing](https://gitlab.torproject.org/tpo/network-health/analysis/-/issues/85)
a few days before. This spoofing "attack" actually started on other types of
nodes before migrating to relays, and those other nodes were hit with a much
larger volume of spoofed connections, leading to them actually getting
temporarily taken down in some cases! Proving the attack does in fact work...

## You could be the target too!

To recap what's (probably) going on:

1. A malicious attacker has access to a network without BCP38 filtering.
2. They send TCP connection requests to port 22 on many random internet
   machines - possibly deliberately selecting known honeypots or networks known
   to send automated abuse complaints.
3. Those TCP connection requests use a spoofed source IP address, making the
   destination machines think the spoofed source sent that connection. They
   become the target of the automated abuse complaints.
4. With a large enough volume, the spoofed IP quickly becomes widely
   blacklisted from many internet entities following blocklists, and the
   hosting provider might take action due to many abuse reports and shut down
   the server for being compromised / malicious.

There is nothing at all in this attack that's specific to Tor! I'm actually
surprised this is the first time I hear of this, because while ingenious,
nothing in there seems particularly difficult to do for a single motivated
attacker. You, too, can probably make your friend's hosting provider (with
their consent, of course) shut down their server and cancel their hosting
contract by getting them flooded with well-meaning but confused abuse
complaints.

## Conclusion

The internet was broken 25 years ago and is still broken 25 years later.
Spoofed source IP addresses should not still be a problem in 2024, but the
larger internet community seems completely unwilling to enforce any kind of
rules or baseline security that would make the internet safer for everyone.
This is not just BCP38 - RPKI is a similar disaster in terms of deployment, and
has only started ramping up because it impacts large internet companies who
started enforcing requirements on their direct peers.

It's not clear to me what the next steps are in regards to this attack. It's
clearly already in the wild. I don't know if it was already known and
documented. But it still seems to be working, it's hard to track (I don't know
of any way one could figure out the real source of a spoofed IP packet - there
is no "after the fact" traceroute, and even if there was, it would have to be
done by some upstream provider to get useful info).

However, if you now get such an abuse complaint, you might now have a better
idea what to look for and what to reply to your hosting provider to try and
convince them you are in fact a victim and not a perpetrator! Who knows, they
might even care to listen.

-----

*This article was written in a rush a few hours before getting on a plane.
Sorry for the lack of proof-reading and potential typos!*
