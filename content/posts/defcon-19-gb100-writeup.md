---
title: 'DEFCON 19 CTF Grab Bag 100 (gb100) writeup'
date: 2011-06-06T00:00:00+02:00
tags: ["CTF", "writeup", "hacking"]
draft: false
---

gb100 took a lot of time to pwn for us as we ran out of ideas really fast and
it was mostly guessing. Anyway, this is a small writeup about this really
simple problem from the DEFCON 19 CTF.

The description of this problem contained only a host:port which we had to
connect to. For the first 4 to 6 hours of the contest the server simply closed
any incoming connection on the specified port, which caused us to try a lot of
strange protocols, only to find out 4 hours later that the problem was fixed
and was simply an HTTP server.

On every request, the server replied a `HTTP/1.1 408 Too Slow` error code,
followed by some fixed `Date` and `Last-Modified` headers which turned out to
be useless. The solution to that problem was to connect to the server using the
SPDY protocol from Google, which is implemented in Google Chrome. You can force
Chrome to use SPDY to connect to a website by launching it with the
`–use-spdy=no-ssl` flag on the command line. After this is done, the server
simply returns a `text/plain` content with “you are speedy enough, but not good
enough”.

After a lot of time spent trying to fuzz SPDY headers and racing to be the
first to connect to the server after each of its apparently scheduled downtime,
we discovered that requesting `/cgi-bin/` did not display the string but an
HTTP 404 error, which was really odd. We then tried to guess what could be in
this `/cgi-bin/` directory: `printenv`, `phpmyadmin`, etc. and found a
`/cgi-bin/phf` binary, which is mostly known to be the most vulnerable CGI
script in the universe. We were able to launch commands on the web server, and
a `ls` showed that a `key` file was present in `$PWD`. The query string was
filtered and denied the command launch if the string `key` was found in the
command line, but doing `cat *` was fine and gave us the key for this problem.
