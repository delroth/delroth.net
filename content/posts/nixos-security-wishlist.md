---
title: 'My wishlist for NixOS security in 2024+'
date: 2023-11-04T00:00:00+02:00
tags: ["security", "nixos"]
draft: false
---

At the last [NixCon in Darmstadt](https://2023.nixcon.org/) and later in
private followup conversations I had the opportunity to talk with a lot of
amazing fellow NixOS contributors about NixOS security, and how we could
improve it in the future.

This article is my personal wishlist of what I think should be worked on in the
near-term to mid-term future. It's not really a roadmap, because I don't think
it has any consensus or authority to be called one, but hopefully it can be
used as a reference if anyone is looking for ideas or areas where they could
help! It's a mix of small, medium, and large sized projects. It's also roughly
ordered in terms of how I'd prioritize the work based on how much effort I
imagine there is to be done and how much benefit we'd get in return.

<!--more-->

Without further ado...

## delroth's NixOS security wishlist

### Vulnerabilities tracking

Probably the obvious one: we barely know where we're at currently in terms of
patching vulnerabilities in nixpkgs. Tracking of vulnerabilities is almost
entirely done manually, we're almost certainly missing vulns that are less
reported on or talked about, etc.

Once upon a time (in 2022), we had
[vulnix](https://github.com/nix-community/vulnix) and the Vulnerability Roundup
bugs. They were not great, but they at least attempted to be comprehensive.
Since the roundups happened regularly and were not incremental, things could
not slip through the cracks as much. Unfortunately, vulnix is now unmaintained,
and with ckauhaus unable to do the roundups nobody has taken up the work.

What I think we need is a vulnerability tracking dashboard aimed at {users,
package maintainers, security team members} and providing information about the
status of fixes for a given vulnerability, the currently unpatched
vulnerabilities impacting nixpkgs, etc. Several other distros have built
similar things ([Debian](https://security-tracker.debian.org/tracker/),
[Alpine](https://security.alpinelinux.org/),
[Arch](https://security.archlinux.org/), probably more) and we're behind the
curve there while *also* providing almost an order of magnitude more packages.
I have some more detailed ideas on the subject, but I don't think this is
necessarily the right place to spend several pages trying to design such a
dashboard, though I should probably write that down elsewhere at some point!

Luckily, things seem to be moving in this area, with even some funding secured
for development work! See [info about the Nixpkgs supply chain security
project](https://discourse.nixos.org/t/nixpkgs-supply-chain-security-project/34345)
for some more details. I haven't really seen any design nor active
conversations about the work yet, so I don't know how far along this is, but
hopefully we'll get there sooner rather than later?

### Better policy/discipline/tooling around backports

After talking about a large/complex project in the first item, let's talk about
something simpler: backports! We don't do very well at making sure security
relevant updates in `unstable` make it to the stable releases.

Currently, this relies entirely on either the PR author, the reviewer, or the
merger, to realize that a given update is security-relevant and apply the
backporting label on the PR. While this seems like a lot of opportunities to
succeed at having the backport happen, in practice:

- "The PR author, the reviewer, and the merger" often ends up being one single
  person, when "the PR author" is `nixpkgs-update`, and "the reviewer" and "the
  merger" are the same person (or the merger doesn't do a full review of the
  PR).
- It's not always obvious that a version bump is security relevant. PR authors
  don't necessarily know to mention it in the PR description (`nixpkgs-update`
  definitely doesn't for obvious reasons), reviewers don't always go and read
  the changelog, etc.

I think there's a lot of space for improvement here. Obviously, we could ask
the humans in the loop to be more careful, but there are also obvious
limitations and drawbacks to this in the kind of working environment that
nixpkgs is. Instead, I think there are two angles to consider:

- **Policy**: we might be too overly conservative with backports, causing
  people to not automatically consider them whenever they bump a package
  version / add a patch. Maybe we should change the default to always backport
  unless explicitly requested not to? (Probably not.) Maybe we should do that
  when the backport would apply and it's only a minor version bump?

- **Tooling**: could we teach `nixpkgs-update` to be smarter about backports,
  instead of requiring humans to always actively make a decision (while also
  not telling them they have to make a decision)? Could we have packages define
  some kind of "backport policy" where they say "always backport everything"
  (which we'd use for things like web browsers, chat apps, etc. that have a
  large attack surface exposed to the internet), or "backport minor versions"?
  Could we have a bot that detects that a given PR includes some
  security-relevant updates and auto-applies the backport label?

I think this is a mostly unexplored space, and there's likely a ton of easy
wins to be had!

### Getting vendoring under control

My current pet peeve. Recent vulnerabilities in `libwebp` then `libvpx` have
shown this to be a major problem and blind spot with our vulnerability response
and tracking. Across all of nixpkgs, we probably have more than 100 copies of
`libwebp` at various versions and various patch levels. We don't have good
metrics for this, and the tooling to even detect this is nascent (e.g. my
[`grep-nixos-cache`](https://github.com/delroth/grep-nixos-cache)). Who knows
what we even need to patch next time `libjpeg` or `libpng` have a major
vulnerability. (Who knows whether the *previous* major vulnerabilities were
even fixed in the majority of nixpkgs packages?)

There are two different approaches that I think we should use to tackle
vendoring:

- Strategic / broad / systemic: things that help us track the problem, contain
  the spread, and slowly reduce its size.
  - Have clearer policies around vendoring, so we can tell maintainers to "get
    their shit together". For example, when upstream provides a way to unvendor
    a dependency, it should be used as much as possible. This is not
    consistently done in nixpkgs, and it relies on the author knowing that this
    is a problem, and caring to fix it.
  - Have clearer policies around `meta.sourceProvenance = binary*`. As much as
    possible, we should package things from source. Prebuilt binaries vendor
    stuff by definition (ok, not always, but almost). Any time we have the
    option, we should strongly push for builds from source. Maybe we should
    have policies that require it for some subset of packages that are more
    risky?
  - Better track vendoring, either through source code analysis, or analysis of
    the build outputs from Hydra. I think we could for example expand
    `grep-nixos-cache` to have signatures for various libraries we know are
    "risky" and often vendored, and have a weekly run giving us an up to date
    status of who vendors what (with some reasonable level of confidence).
- Tactical / targeted: short-lived efforts that look at the largest parts of
  the problem as one-offs and reduce the size of the problem *now*.
  - Electron is the obvious one here. It has a gigantic attack surface,
    nixpkgs's support for building from source is limited, and most of the apps
    that vendor it don't follow security updates. I don't know enough about
    Electron to know for sure, but I strongly suspect we could in most cases
    de-vendor Electron apps and replace the Electron runner with a nixpkgs
    provided one of the same major version. This introduces the potential for
    more bugs / less stability, but it has major security benefits as well as
    closure size / cache disk usage benefits.

### Faster NixOS security patch releases with grafts

Any security patch that needs to go through `staging` or needs a mass Hydra
rebuild takes too long to get into our users hands. I think there are many
strategies we could take here, and hopefully in the future this is all mostly
an obsolete problem with CA derivations (one can always dream). I think the one
that's most likely to minimize time-to-patch-delivery while also not requiring
a large amount of work is providing "official" grafts for those
vulnerabilities.

I think there's obvious objections to this: grafts are hacky, maintaining
grafts is more work and not super easy to do. But I don't think anyone has a
better idea to make sure high severity updates in packages like `glibc` or
`openssl` don't take 3+ days to get patched in NixOS. Let's bless the concept,
provide the framework / documentation, and see where it goes?

### Two-people rule for nixpkgs merges

On the supply chain side of things: we've improved the situation a lot by
disallowing direct pushes to several protected branches without going through
pull requests. I think the next step is to require review by a separate person
before changes can get merged.

As we increase the pool of mergers in nixpkgs, we increase the risk that
someone will be malicious, or that someone will get their credentials
compromised by someone malicious. NixOS is becoming a more and more attractive
target as its user base grows, and compromising nixpkgs is an obvious way to
backdoor a whole bunch of people.

Exceptions would be PRs generated by bots: for example, nixpkgs-update, or
automated backports. Assuming that the code generating the PR is trustworthy
(because it runs on trusted infrastructure, with code subject to similar review
rules), it should be fine for a single person to handle those PRs.

There are non-security benefits to this too:
- Reviews are useful for more than just security: they catch bugs, they tend to
  increase code quality (by asking for stuff like documentation when it's
  missing), etc.
- It increases the fairness between mergers and non-mergers, by requiring
  *everyone* to be subject to the "finding a reviewer" problem. If it's hard to
  find a reviewer, the solution shouldn't be to have a few select people bypass
  the problem while the vast majority of contributors have to suffer. Let's
  build up the incentives and get the problem properly fixed.
- It increases incentive to build tooling to automate some part of the nixpkgs
  maintenance, since we could shortcut the two-people rule requirement for some
  trusted automation. I think this is a good thing likely to overall save time
  for the maintenance of the nixpkgs package set.

### Better sandboxing of Nix builds on Hydra

While I don't personally know of an escape for the Nix build sandbox, most
people I've talked to seem to agree that it's unlikely to stop a motivated
attacker, and that it's not a particularly good security boundary. Yet that's
the *only* boundary we have to prevent cross-contamination of builds on Hydra!

This is a particularly stealthy attack vector, because it doesn't require any
change to nixpkgs itself to be backdoored per se, it can be entirely contained
in the source code for a particular package being built on Hydra. We can't ever
assume that all the source code being built is trusted and non malicious - it's
way too easy for someone to get Hydra to build their malicious code if they
want to.

I think that at least, on Hydra, we should have the Nix sandbox be a better
security boundary. Or, alternatively, run each build in a throwaway VM which
itself runs the Nix sandbox, but that seems less resource efficient.

A few ideas of how we could do this:
- [gVisor](https://gvisor.dev/) is a Linux userspace sandbox relying on syscall
  interception and emulation.
  - Pros: very reduced attack surface, probably fairly easy to configure it to
    provide an environment similar to the Nix sandbox environment.
  - Cons: syscall emulation is not 100% accurate and could cause
    incompatibilities and build failures. Especially `checkPhase` failures
    worry me.
- Micro VMs such as [firecracker](https://firecracker-microvm.github.io/).
  - Pros: better compatibility, since it's running an actual Linux kernel.
  - Cons: we have to maintain a kernel image, the overhead is higher. Harder to
    embed without a separate daemon, I think?

Note that this would also help with other non-security problems of the Nix
sandbox. For example, the fact that it leaks several build host properties that
would be difficult to "hide" otherwise: page size, threads count, etc.

----

## Honorable mentions

I wanted to list in here a few more things that I didn't want to necessarily
include in my security wishlist for various reasons:

- **Reproducible Builds**: not listed because they're a large effort all on its
  own, tracked by a separate NixOS team. But there are obvious security
  benefits to reproducible builds: they're one of the main ways we can remove
  trust in NixOS's Hydra. They could allow detection of otherwise undetectable
  compromise and/or backdooring of the build infrastructure, via a Binary
  Transparency style model. We're unfortunately a long way off, not only in
  terms of making builds reproducible, but also in terms of infrastructure to
  collect and verify build hashes, and in terms of figuring out who'd be crazy
  enough to run parallel build infras under different ownership / trust
  boundaries.

- **Hydra infrastructure attestation and auditability**: not listed because
  it's technically complex and dependent on other projects I've listed above to
  actually be useful. Basically: make it so that each Hydra build also produces
  a signed attestation of the state of the system running on the build machine.
  Using DRTM attestations and TPMs / vTPMs, we could possibly get attestations
  signed by external trustable entities (e.g. Intel, or our Cloud infra
  provider in the case of vTPMs) which can be traced back to published /
  auditable build machine system configurations. But this would require very
  large efforts to actually achieve, and it would strongly depend on
  collaborating with the NixOS infra team, which is severly understaffed and
  overworked.

I want to also acknowledge the work being handled as part of the [Nixpkgs
supply chain security](https://discourse.nixos.org/t/nixpkgs-supply-chain-security-project/34345)
project. Some of their projects are already listed on my wishlist (vuln
tracking). Some are not (secure boot, minimal bootstrap) - not because I don't
think they're important, but because they're already at a pretty late stage and
I'm kind of seeing it as a given (esp. with proper funding) that these will be
driven to completion!

## Conclusion

I'd love to hear everyone else's ideas. Do you have your own NixOS security pet
project you'd like to see move forward? Do you think some of my ideas are off
base? I'm posting this article to the NixOS Discourse, feel free to send your
comments over there - or directly to me via
[Mastodon](https://mastodon.delroth.net/@delroth) or
[Matrix](https://matrix.to/#/@delroth:delroth.net)!
