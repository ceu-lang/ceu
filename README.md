Céu is a reactive language that aims to offer a higher-level and safer 
alternative to C.

http://www.ceu-lang.org/

For Céu distributions targeted at specific platforms (e.g. Arduino, SDL), 
consult the wiki.

http://www.ceu-lang.org/wiki

Join the chat at https://gitter.im/fsantanna/ceu

# Starting

```
$ make all CEU=samples/test-00.ceu
```

You should get this output:

```
cd compiler/lua/ && lua pak.lua lua ../../arch/dummy
mv compiler/lua/ceu .
./ceu --dump
Version: ceu 0.10
Lua:     lua
Arch:    ../../arch/dummy
mkdir -p build/
./ceu --out_dir build samples/test-00.ceu
gcc arch/dummy/main.c -Ibuild -o build/a.out
build/a.out
*** END: 0
```

# Targets

## `compiler`

```
$ make compiler
```

