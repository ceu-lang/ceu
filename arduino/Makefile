INOFILE ?= poll.pde
CEUFILE ?= samples/blink1.ceu

ARDUINODIR = /opt/arduino-1.0
BOARD = uno

CEUCFILE = _ceu_$(notdir $(CEUFILE)).tmp

.PHONY: all ceu

all: ceu _all

ceu: $(CEUCFILE)
	cp $(CEUCFILE) _ceu_code.tmp
	touch *.pde *.ino

$(CEUCFILE): $(CEUFILE)
	./ceu $(CEUFILE) --dfa --output $(CEUCFILE)

clean: _clean
	rm -f _ceu_*.tmp

include arduino.mk

CPPFLAGS += -Wno-pointer-arith
