NESCFILE ?= AppAppC
CEUFILE  ?= samples/blink.ceu

COMPONENT   = $(NESCFILE)
SENSORBOARD = mts300

#PFLAGS += -Wnesc-data-race -D$(MODE)
#PFLAGS += -I%T/lib/net/ctp -I%T/lib/net -I%T/lib/net/4bitle -I%T/lib/net/drip
#PFLAGS += -DCC2420_DEF_RFPOWER=3

BUILD_EXTRA_DEPS += ceu

include $(MAKERULES)

ceu:
	@echo "======================================================="
	./ceu $(CEUFILE) --dfa --events --output _ceu_code.tmp
	@echo "======================================================="

clean_ceu:
	rm -f _ceu_*

.PHONY: ceu
