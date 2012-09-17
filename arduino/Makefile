INOFILE ?= poll.ino
CEUFILE ?= samples/blink1.ceu

ARDUINODIR = /opt/arduino-1.0
BOARD = uno
#lilypad328
#uno

CEUCFILE = _ceu_$(notdir $(CEUFILE)).cceu

.PHONY: all all_analysis ceu_noanalysis ceu_analysis ino clean

all: ceu_noanalysis ino _all
all_analysis: ceu_analysis ino _all

ceu_noanalysis:
	./ceu $(CEUFILE) --m4 --tp-word 2 --tp-pointer 2 --tp-lbl 1 --tp-off 1

ceu_analysis:
	./ceu $(CEUFILE) --m4 --tp-word 4 --tp-pointer 4 --tp-lbl 2 --tp-off 2 --analysis-run
	gcc -std=c99 -o _ceu_analysis.exe analysis.c
	./_ceu_analysis.exe _ceu_analysis.lua
	./ceu $(CEUFILE) --m4 --tp-word 2 --tp-pointer 2 --tp-lbl 1 --tp-off 1 --analysis-use

ino:
	touch poll.ino async.ino

clean: _clean
	rm -f _ceu_* samples/*.ceu_m4 *.hex *.o

include arduino.mk

CPPFLAGS += -Wno-pointer-arith
