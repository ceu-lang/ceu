INOFILE ?= poll.ino
CEUFILE ?= samples/blink1.ceu

ARDUINODIR = /opt/arduino-1.0
BOARD = uno
#lilypad328
#uno

CEUCFILE = _ceu_$(notdir $(CEUFILE)).tmp

.PHONY: all ceu

all: ceu _all

ceu: $(CEUCFILE)
	cp $(CEUCFILE) _ceu_code.tmp
	touch *.ino

$(CEUCFILE): $(CEUFILE)
	./ceu $(CEUFILE) --m4 --output $(CEUCFILE)

clean: _clean
	rm -f _ceu_*.tmp

include arduino.mk

CPPFLAGS += -Wno-pointer-arith
