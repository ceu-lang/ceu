INOFILE ?= poll.pde
CEUFILE ?= samples/blink1.ceu

ARDUINODIR = /opt/arduino-1.0
BOARD = uno

CEUTMPFILE = _ceu_$(notdir $(CEUFILE)).tmp

.PHONY: all

all: $(CEUTMPFILE) _all

$(CEUTMPFILE): $(CEUFILE)
	./ceu $(CEUFILE) --output $(CEUTMPFILE)
	cp $(CEUTMPFILE) _ceu_code.tmp

clean: _clean
	rm -f _ceu_*.tmp

include arduino.mk
