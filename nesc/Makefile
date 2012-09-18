NESCFILE ?= AppAppC
CEUFILE  ?= samples/blink.ceu

COMPONENT   = $(NESCFILE)
SENSORBOARD = mts300

PFLAGS += -fno-strict-aliasing # required for accessing VARS
PFLAGS += -DCC2420_DEF_RFPOWER=3

BUILD_EXTRA_DEPS += ceu_noanalysis

include $(MAKERULES)

ceu_noanalysis:
	@echo "===================================================================="
	./ceu $(CEUFILE) --m4 --tp-word 2 --tp-pointer 2 --tp-lbl 1 --tp-off 1 --defs-file _ceu_defs.h
	@echo "===================================================================="

ceu_analysis:
	@echo "===================================================================="
	./ceu $(CEUFILE) --m4 --tp-word 4 --tp-pointer 4 --tp-lbl 2 --tp-off 2 --defs-file _ceu_defs.h --analysis-run
	gcc -std=c99 -o _ceu_analysis.exe analysis.c
	./_ceu_analysis.exe _ceu_analysis.lua
	./ceu $(CEUFILE) --m4 --tp-word 2 --tp-pointer 2 --tp-lbl 1 --tp-off 1 --defs-file _ceu_defs.h --analysis-use
	@echo "===================================================================="

ceu_clean:
	rm -f _ceu_*

.PHONY: ceu_noanalysis ceu_analysis ceu_clean
