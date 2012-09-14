NESCFILE ?= AppAppC
CEUFILE  ?= samples/blink.ceu

COMPONENT   = $(NESCFILE)
SENSORBOARD = mts300

PFLAGS += -fno-strict-aliasing # required for accessing VARS
PFLAGS += -DCC2420_DEF_RFPOWER=3

BUILD_EXTRA_DEPS += ceu_sim

include $(MAKERULES)

ceu_nosim:
	@echo "===================================================================="
	./ceu $(CEUFILE) --m4 --tp-word 2 --tp-pointer 2 --tp-lbl 1 --tp-off 1 --defs-file _ceu_defs.h
	@echo "===================================================================="

ceu_sim:
	@echo "===================================================================="
	./ceu $(CEUFILE) --m4 --tp-word 4 --tp-pointer 4 --tp-lbl 2 --tp-off 2 --defs-file _ceu_defs.h --simul-run
	gcc -std=c99 -o _ceu_sim.exe simul.c
	./_ceu_sim.exe _ceu_simul.lua
	./ceu $(CEUFILE) --m4 --tp-word 2 --tp-pointer 2 --tp-lbl 1 --tp-off 1 --defs-file _ceu_defs.h --simul-use
	@echo "===================================================================="

clean_ceu:
	rm -f _ceu_*

.PHONY: ceu
