MODE?=WORK
#OPTFLAGS = -O2

COMPONENT=AppAppC
SENSORBOARD=mts300

PFLAGS += -Wnesc-data-race -D$(MODE)
PFLAGS += -I%T/lib/net/ctp -I%T/lib/net -I%T/lib/net/4bitle -I%T/lib/net/drip

BUILD_EXTRA_DEPS += ceu

include $(MAKERULES)

ceu:
	@echo "======================================================="
	./ceu.lua --m4 --events --output _ceu_code.c $(FILE).ceu
	@echo "======================================================="

tests:
	make all FILE=radio_recv
	./radio_recv.exe | diff - radio_recv.out
	make all FILE=radio_send
	./radio_send.exe | diff - radio_send.out
	make all FILE=base_station
	./base_station.exe | diff - base_station.out

dist: clean_ceu
	mkdir -p ../ceu_nesc_`date +%F`/ ; \
	cp -R Makefile *.lua *.c *.h *.m4 *.nc samples/ ../ceu_nesc_`date +%F`/ ; \
	cd .. ; \
	tar hcvzf ceu_nesc_`date +%F`.tgz ceu_nesc_`date +%F`/ ; \

clean_ceu:
	rm -f *.exe _ceu_*

