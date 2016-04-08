Céu is a reactive language that aims to offer a higher-level and safer 
alternative to C.

http://www.ceu-lang.org/

For Céu distributions targeted at specific platforms (e.g. Arduino, SDL), 
consult the wiki.

http://www.ceu-lang.org/wiki

Join the chat at https://gitter.im/fsantanna/ceu

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
CEU_EXE ?= /usr/local/bin/ceu   # change this line and try again
```

## Run the examples

Now, you are ready to run the examples:

```
###############
# test-00.ceu #
###############

$ cat samples/test-00.ceu
escape 0;

$ make all SRC=samples/test-00.ceu
mkdir -p build
/usr/local/bin/ceu --out-dir build --cpp-args "-I arch/dummy" samples/test-00.ceu
gcc arch/dummy/ceu_main.c -I arch/dummy -I build -o build/test-00.exe
build/test-00.exe
*** END: 0

###############
# test-01.ceu #
###############

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

###############
# test-02.ceu #
###############

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

###############
# test-03.ceu #
###############

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

$ make all SRC=samples/test-03.ceu
mkdir -p build
/usr/local/bin/ceu --out-dir build --cpp-args "-I arch/dummy" samples/test-03.ceu
gcc arch/dummy/ceu_main.c -I arch/dummy -I build -o build/test-03.exe
In file included from samples/test-03.ceu:232:0,
                 from arch/dummy/ceu_main.c:28:
arch/dummy/ceu_threads.h:1:2: error: #error "no support for threads"
 #error "no support for threads"
  ^
```

The example `test-03.ceu` fails because it uses the `async/thread` primitive 
which requires the `pthread` architecture to execute:

```
###############
# test-03.ceu #
###############

$ cat samples/test-03.ceu
<...>

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
