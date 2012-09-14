INOFILE ?= poll.ino
CEUFILE ?= samples/blink1.ceu

ARDUINODIR = /opt/arduino-1.0
BOARD = uno
#lilypad328
#uno

CEUCFILE = _ceu_$(notdir $(CEUFILE)).cceu

.PHONY: all all_sim ceu_nosim ceu_sim ino clean

all: ceu_nosim ino _all
sim: ceu_sim ino _all

ceu_nosim:
	./ceu $(CEUFILE) --m4 --tp-word 2 --tp-pointer 2 --tp-lbl 1 --tp-off 1

ceu_sim:
	./ceu $(CEUFILE) --m4 --tp-word 4 --tp-pointer 4 --tp-lbl 2 --tp-off 2 --simul-run
	gcc -std=c99 -o _ceu_sim.exe simul.c
	./_ceu_sim.exe _ceu_simul.lua
	./ceu $(CEUFILE) --m4 --tp-word 2 --tp-pointer 2 --tp-lbl 1 --tp-off 1 --simul-use

ino:
	touch poll.ino async.ino

clean: _clean
	rm -f _ceu_* samples/*.ceu_m4 *.hex *.o

include arduino.mk

CPPFLAGS += -Wno-pointer-arith
