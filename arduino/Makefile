ARDUINODIR = /opt/arduino-1.0
INOFILE = poll.pde
BOARD = uno

.PHONY: ceu all
all: ceu _all

ceu:
	./ceu $(CEU) --output _ceu_code.tmp

clean: _clean
	rm -f _ceu_*

include arduino.mk
