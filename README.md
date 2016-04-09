Céu is a reactive language that aims to offer a higher-level and safer 
alternative to C.

http://www.ceu-lang.org/

https://github.com/fsantanna/ceu/

Join our chat at https://gitter.im/fsantanna/ceu

# Summary

* [Quick Start](#quick-start)
* [Examples](#examples)
* [Environments](#environments)

# Quick Start

## Install `lua` and `lua-lpeg`:

First, you need to install `lua` and `lua-lpeg`:

```
# Ubuntu:
$ sudo apt-get install lua
$ sudo apt-get install lua-lpeg

# Sources:
- Lua:  http://www.lua.org/download.html
- LPeg: http://www.inf.puc-rio.br/~roberto/lpeg/#download
```

## Build & Install `ceu`:

Then, you need to build & install the compiler of Céu:

```
$ sudo make compiler
cd ./compiler/lua/ && lua pak.lua lua
mv ./compiler/lua/ceu /usr/local/bin/ceu
mv: cannot move ‘./compiler/lua/ceu’ to ‘/usr/local/bin/ceu’: Permission denied
make: *** [compiler] Error 1
```

The installation fails because it tries to write to `/usr/local/bin/ceu`.

Try again with `sudo`:

```
$ make compiler
cd ./compiler/lua/ && lua pak.lua lua
mv ./compiler/lua/ceu /usr/local/bin/ceu
/usr/local/bin/ceu --dump
Version: ceu <version>
Lua:     lua
```

Or edit the `Makefile` to change the destination `CEU_EXE`:

```
$ vi Makefile
CEU_EXE ?= /usr/local/bin/ceu   # EDIT THIS LINE
```

## Run the examples

Now, you are ready to run the examples:

```
$ make samples
for i in samples/*.ceu; do								\
		echo;									\
		echo -n "#####################################";		\
		echo    "#####################################";		\
		echo File: "$i";							\
		grep "#@" "$i" | cut -f2- -d" ";					\
		echo -n "#####################################";		\
		echo    "#####################################";		\
		echo -n "Press <enter> to start...";					\
		read _;									\
		if [ "$i" = "samples/test-03.ceu" ]; then				\
			make ARCH_DIR=arch/pthread SRC=$i all || exit 1;	\
		else									\
			make SRC=$i all || exit 1;					\
		fi;									\
		echo;									\
	done

##########################################################################
File: samples/test-00.ceu
Description: Terminates immediatelly with an `escape`.
Features:
 - `escape`
##########################################################################
Press <enter> to start...
make[1]: Entering directory `/data/ceu/ceu'
mkdir -p build
/usr/local/bin/ceu --out-dir build --cpp-args "-I arch/dummy" samples/test-00.ceu
gcc arch/dummy/ceu_main.c -I arch/dummy -I build -o build/test-00.exe
build/test-00.exe
*** END: 0
make[1]: Leaving directory `/data/ceu/ceu'

<...> # output for other samples
```

# Examples

### `test-00.ceu`

The example `test-00.ceu`, simply terminates immediatelly with an `escape`:

```
$ cat samples/test-00.ceu
escape 0;

$ make all SRC=samples/test-00.ceu
mkdir -p build
/usr/local/bin/ceu --out-dir build --cpp-args "-I arch/dummy" samples/test-00.ceu
gcc arch/dummy/ceu_main.c -I arch/dummy -I build -o build/test-00.exe
build/test-00.exe
*** END: 0
```

### `test-01.ceu`

The example `test-01.ceu`, prints `"Hello World"` every second and simulates 
the passage of `5` seconds in parallel:

```
$ cat samples/test-01.ceu
par/or do
    every 1s do
        _printf("Hello World!\n");
    end
with
    async do
        emit 5s;
    end
end
escape 0;

$ make all SRC=samples/test-01.ceu
mkdir -p build
/usr/local/bin/ceu --out-dir build --cpp-args "-I arch/dummy" samples/test-01.ceu
gcc arch/dummy/ceu_main.c -I arch/dummy -I build -o build/test-01.exe
build/test-01.exe
Hello World!
Hello World!
Hello World!
Hello World!
Hello World!
*** END: 0
```

### `test-02.ceu`

The example `test-02.ceu` is similar to `test-01.ceu`, but calls `_sleep` to 
make the application respect the "wall-clock time":

```
$ cat samples/test-02.ceu
par/or do
    every 1s do
        _printf("Hello World!\n");
    end
with
    async do
        loop i in 5 do
            _sleep(1);
            emit 1s;
        end
    end
end
escape 0;

$ make all SRC=samples/test-02.ceu
mkdir -p build
/usr/local/bin/ceu --out-dir build --cpp-args "-I arch/dummy" samples/test-02.ceu
gcc arch/dummy/ceu_main.c -I arch/dummy -I build -o build/test-02.exe
build/test-02.exe
Hello World!
Hello World!
Hello World!
Hello World!
Hello World!
*** END: 0
```

### `test-03.ceu`

The example `test-03` uses a real thread with `async/thread` that executes in 
parallel with the rest of the application:

```
$ cat samples/test-03.ceu
par/or do
    every 1s do
        _printf("[sync] hello\n");
    end
with
    async/thread do
        loop do
            _sleep(1);
            _printf("[thread] world\n");
        end
    end
with
    async do
        loop i in 5 do
            emit 1s;
            _sleep(1);
        end
    end
end
escape 0;

$ make ARCH_DIR=arch/pthread SRC=samples/test-03.ceu all
mkdir -p build
/usr/local/bin/ceu --out-dir build --cpp-args "-I arch/pthread" samples/test-03.ceu
gcc arch/pthread/ceu_main.c -I arch/pthread -I build -lpthread -o build/test-03.exe
build/test-03.exe
[sync] hello
[thread] world
[sync] hello
[thread] world
[sync] hello
[thread] world
[sync] hello
[thread] world
[sync] hello
[thread] world
*** END: 0
```

The `async/thread` requires `pthread` which is passed as 
`ARCH_DIR=arch/pthread` to the command `make`.

# Environments

Céu requires a real environment that provides actual input events and output 
functionality for the applications.

## SDL

[SDL](http://www.libsdl.org/) works in typical platforms (e.g., Windows, Mac, 
Linux, Android) and provides basic input & output functionality (e.g., timers, 
keyboard, mouse, display):

https://github.com/fsantanna/ceu-sdl/

## Arduino

[Arduino](http://www.arduino.cc/) is a platform for sensing and controlling 
physical devices:

https://github.com/fsantanna/ceu-arduino/
