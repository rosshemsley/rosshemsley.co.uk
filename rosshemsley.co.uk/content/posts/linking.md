---
title: "The Axioms of linking"
date: 2019-07-30T07:04:35Z
---

# <s> How did things get this bad?</s> The Axioms of linking

Every few months I end up in the a shady corner of the internet, with twenty tabs open searching for variations on _'why the $%^&!@ does this not work'_. Hours later I end up re-discovering the truth: using binary libraries in `$CURRENT_YEAR` still pretty much sucks.

So let's try and get something positive out of this, and at least write up the facts of the situation. Here's to hoping someone comes along and shows me I missed that "one weird trick" that will make all of this make sense.

So here we are, in no particular order, a bunch of hard-learned facts about using libraries (on unix-flavored operating systems)

1. _Dynamic_ or _shared_ libraries are loaded up by your program at runtime. They contain lookup tables that map symbols to shared executable code. If you give someone a binary that links a dynamic library that they don't already have, the OS will complain about missing libraries when they try to run it.

1. Dynamic or "shared" libraries have names that start with `lib` and finish with `.so`. Unless you're on a Mac, where they end with `.dylib`.[^1]

1. Dynamic libraries themselves can link other dynamic libraries. These are known as _transitive dependencies_. All dependencies will need to be found to successfully run your binary.

1. If you want to move a binary from one machine (where it was compiled) to another, you'll almost certainly find that at least some of the shared libraries needed by your binary are no longer found. This is usually the first sign of trouble...

1. Linux knows how to find libraries because it has a list of known locations for shared libraries in `/etc/ld.so.conf`. Each time you run `ldconfig`, the OS updates its cache of known libraries by going through directories in this file and reading the libraries it finds. OS X works differently... see [dyld](https://www.unix.com/man-page/osx/1/dyld/) and friends.

1. Use `ldd` (linux) or `otool -L` (OS X) to query your binary for the missing libraries. Beware that it is [not safe](http://man7.org/linux/man-pages/man1/ldd.1.html) to do this on a binary you suspect may be malicious 😞.

1. You can safely copy dynamic libraries from one machine to another. As long as the environments are similar enough...[^2] . In a perfect world (on linux), you could just copy the library you want to use into `/usr/local/lib` (the recommended place for unstable libraries) and then run `ldconfig` to make your OS reload its library cache.

1. Of course, on OS X things work totally differently. Dynamic libraries have an _install name_ which contains the absolute path. This path is baked into your binary at compile time. You can use [install_name_tool](https://www.unix.com/man-page/osx/1/install_name_tool/) to change it. Good luck!

1. On linux, Adding libraries to `/usr/local/lib` makes them visible to everything, so you may want to copy your library somewhere else so that only _your_ binary knows how to find it. One way to do this is using _rpath_...

1. You can set the _rpath_ attribute of your binary to contain a directory hint for your OS to look in for libraries. This hint can be _relative_ to your binary. This is especially useful if you always ship libraries in a relative directory to your binary. You can use `@origin` as a placeholder for the path of the binary itself, so an rpath of `@origin/lib` causes the OS to always look in `<path to your binary>/lib` for shared libraries at runtime. This can be used on both OS X and linux, and is one of the most useful tools to actually getting things working in practice.

1. If your OS isn't finding a dynamic library that you _know_ exists, you can try helping your OS by setting the environment variable `LD_LIBRARY_PATH` to the directory containing it - your OS will look there first before default system paths. Beware, this is considered [bad practice](http://xahlee.info/UnixResource_dir/_/ldpath.html), but it might unblock you at a pinch. OS X has `DYLD_LIBRARY_PATH`, which is similar, and also `DYLD_FALLBACK_LIBRARY_PATH`, which is similar, but different (sorry).

1. Dynamic libraries also have a thing called a _soname_, which is the name of the library, plus version information. You have seen this if you've seen `libfoo.so.3.1` or similar. This allows us to use different versions of the same library on the same OS, and to make non backwards-compatible changes to libraries. The soname is also baked into the library itself.

1. Often, your OS will have multiple symlinks to a single library in the same directory, just with different paths containing version information, e.g. `libfoo.so.3`, `libfoo.so.3.1`. This is to allow programs to find compatible libraries with slightly different versions. Everything starts to get rather messy here... if you really need to get into the weeds, [this article](http://tldp.org/HOWTO/Program-Library-HOWTO/shared-libraries.html) will help. You probably only need to understand this if you are distributing libraries to users and need to support compatibility across versions.

1. Of course, even if your binary only depends on a single symbol in a dynamic library, it must still link that library. Now consider that the dependency itself may also link other unused transitive dependencies. Accidentally "catching a dependency" can cause your list of shared library dependencies to grow out of control, so that your simple `hello world` binary ends up depending on hundreds of megabytes of totally unused shared libraries 😞.

1. One solution to avoiding "dependency explosions" is to statically link symbols directly into your binary, so let's start to look at _static linking_!

1. _Static_ libraries (`.a` files) contain symbol lookup table, similarly to dynamic libraries.
However, they are much more dumb and also a total PITA to use correctly.

1. If you compile your binary and link in only static dependencies, you will end up with a _static binary_. This binary will not need to load any dependencies at runtime and thus much easier to share with others!

1. _People On The Internet_ will recommend that you do not not distribute static binaries, because it makes it hard to patch security flaws. With dynamic libraries, you just have to patch a single library e.g. `libssl.so`, instead of re-compiling everything on your machine that may have linked the broken library without your knowledge (i.e. everything).

1. People who build production systems at companies recommend static libraries because it's wayyyy the hell easier to just deploy a single binary with zero dependencies that can basically run anywhere. No one cares about how big binaries are these days anyway.

1. Still more people on the internet remind you that only one copy of a dynamic library is loaded into memory by the OS even when it is used by multiple processes, saving on memory pressure.

1. The static library people remind you that modern computers have plenty of memory and library size is hardly the thing killing us right now.

1. The OS X people point out that OS X [strongly discourages](https://developer.apple.com/library/archive/qa/qa1118/_index.html) the use of statically linked binaries.

1. Static libraries can't declare any kinds of library dependencies. This means it is _your_ responsibility to ensure all symbols are all baked correctly into your binary at link time - otherwise your linker will fail. This can make linking static libraries painfully error-prone.

1. If you get _symbol not found_ errors but literally swear that you linked every damn thing, you probably linked a static library, and forgot a transitive dependency that is needed by it. This pretty much sucks as it's basically impossible to figure out where that library comes from. Try having a guess by looking at the error messages. Or something?

1. Oh, and you must ensure that you link your static libraries in the [correct order](https://stackoverflow.com/questions/45135/why-does-the-order-in-which-libraries-are-linked-sometimes-cause-errors-in-gcc), otherwise you can still get `symbol not found errors`.

1. If you are starting to think it might be hard to keep track of static libraries, you are following along correctly. There are tools that can help you here, such as `pkgconfig`, `CMake`, `autotools`... or `bazel`. It's quite easy to get going, and achieve deterministic platform-independent static builds with no dynamic dependencies... Said no one ever 😓.

1. One classic way to screw up, is to compile a static library without using the `-fPIC` flag (for "position independent code"). If you do not do this, you will be able to use the static library in a binary, but you will not be able to link it into a dynamic library. This is especially frustrating if you were provided with a static library that was compiled without this flag and you can't easily recompile it.

1. Beware that `-fpic` is [not the same](https://stackoverflow.com/questions/3544035/what-is-the-difference-between-fpic-and-fpic-gcc-parameters) as `-fPIC`. Apparently, `-fPIC` always works but may result in a few nanoseconds of slowdown, or something. Probably you should use `-fPIC` and try not to think about it too much.

1. Your compiler toolchain (e.g. `CMake`) usually has a one-liner way to link a bunch of static libraries into a single dynamic library with no dependencies of its own. However, should you want to link a bunch of static libraries into another static library... well I've never successfully found a reliable way to do this 😞. Why do this you may ask? Mostly for cffi - when I want to build a single static library from C++ and then link it into e.g. a go binary.

1. Beware that your compiler/linker is not smart! Just because the header files declare a function and your linker manages to find symbols for it in your library, doesn't mean that the function is remotely the same. [You will discover this when you get undefined behavior at runtime.](https://github.com/libspatialindex/libspatialindex/issues/93)

1. Oh, and if the library you are linking was compiled with a `#define` switch set, but when you include the library's headers, you do not set the define to the same value, welcome again to runtime [undefined behavior land](https://github.com/openMVG/openMVG/issues/1474)! This is the same problem as the one above, where the symbols end up being incompatible.

1. If you are trying to ship C++, another thing that can bite you is that the C++ standard library uses dynamic linking. This means that even the most basic `hello world` program cannot be distributed to others unless they have a compatible version of `libstdc++`. Very often you'll end up compiling with a shiny new version of this library, only to find that your target is using an older, incompatible version.

1. One way to get around `libstdc++` problems is to statically link it into your binary. However, if you create a static library that statically links `libstdc++`, and your library uses C++ types in its public interface... welcome again to undefined behavior land ☠️.

1. Another piece of classic [advice](https://softwareengineering.stackexchange.com/questions/385127/is-it-good-practice-to-statically-link-libstdc-and-or-libgcc-when-creating-dis) is to statically link everything in your binary apart from core system libraries, such as `glibc` - which is basically a thin wrapper around syscalls. A practical goal I usually aim for is to statically link everything apart from `libc` and (preferably an older version of) `libstdc++`. This seems to be the safest approach.

1. Ultimately, my rule of thumb for building distributed systems is to statically link everything apart from `libc` and (an older version of) `libstdc++`. You can then put this library / binary into a Debian package, or an extremely lightweight Docker container that will run virtually anywhere. Setting up the static linking is a pain, but IMO worth the effort - the main benefits of dynamic libraries generally do not apply anymore when you are putting the binary in a container anyway.

1. Finally, for ultimate peace of mind, use a language that has a less insane build toolchain than C++. For example, Go builds everything statically by default and can link in both dynamic or static libraries if needed, using cgo. Rust also [seems to work this way](http://zderadicka.eu/static-build-of-rust-executables/). Static binaries have started becoming fashionable!

[^1]: Windows has `.dll` or something, sorry, you're own with that one. This doc is all about unix-flavored operating systems 🙂.
[^2]: There are three main things that get you into trouble: operating system compatibility (e.g. Linux vs OS X), instruction architecture, e.g. `arm` vs `amd`, and special instructions such as [SSE](https://en.wikipedia.org/wiki/Streaming_SIMD_Extensions).
