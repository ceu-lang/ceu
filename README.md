Céu is a reactive language that aims to offer a higher-level and safer 
alternative to C.

Try it online:

http://www.ceu-lang.org/

Documentation:

http://fsantanna.github.io/ceu/

Source code:

https://github.com/fsantanna/ceu/

Join our chat:

https://gitter.im/fsantanna/ceu

<!--
# WHY CÉU

`TODO`
-->

# INSTALLATION

## Install required software:

```
$ sudo apt-get install git lua5.3 lua-lpeg liblua5.3-0 liblua5.3-dev
```

(Assuming a Linux/Ubuntu machine.)

## Clone the repository of Céu:

```
$ git clone https://github.com/fsantanna/ceu
$ cd ceu/
$ git checkout v0.30
```

## Install Céu:

```
$ make
$ sudo make install     # install as "/usr/local/bin/ceu"
```

## Run the tests (optional):

```
$ cd tst/
$ ./run.lua
```

## Run the examples

```
$ make samples
```
