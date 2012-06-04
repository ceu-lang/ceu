NESCFILE ?= AppAppC
CEUFILE  ?= samples/blink.ceu

COMPONENT   = $(NESCFILE)
SENSORBOARD = mts300

PFLAGS += -fno-strict-aliasing # required for accessing VARS
PFLAGS += -DCC2420_DEF_RFPOWER=3

BUILD_EXTRA_DEPS += ceu

include $(MAKERULES)

ceu:
	@echo "======================================================="
	./ceu $(CEUFILE) --m4 --events --output _ceu_code.tmp
	@echo "======================================================="

clean_ceu:
	rm -f _ceu_*

.PHONY: ceu
