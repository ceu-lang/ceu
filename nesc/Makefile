NESCFILE ?= AppAppC
CEUFILE  ?= samples/blink.ceu

COMPONENT   = $(NESCFILE)
SENSORBOARD = mts300

#PFLAGS += -Wnesc-data-race -D$(MODE)
#PFLAGS += -I%T/lib/net/ctp -I%T/lib/net -I%T/lib/net/4bitle -I%T/lib/net/drip

CEUCFILE = _ceu_$(notdir $(CEUFILE)).tmp

BUILD_EXTRA_DEPS += ceu

include $(MAKERULES)

ceu: $(CEUCFILE)
	cp $(CEUCFILE) _ceu_code.tmp

$(CEUCFILE): $(CEUFILE)
	@echo "======================================================="
	./ceu $(CEUFILE) --dfa --events --output $(CEUCFILE)
	@echo "======================================================="

clean_ceu:
	rm -f _ceu_*


.PHONY: ceu
