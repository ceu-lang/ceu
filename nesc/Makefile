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
	m4 -D$(MODE) $(FILE).ceu > /tmp/$(notdir $(FILE)).ceu
	lua asm.lua /tmp/$(notdir $(FILE)).ceu > _ceu_code.c
	@echo "======================================================="

tests:
	make all FILE=radio_recv
	./radio_recv.exe | diff - radio_recv.out
	make all FILE=radio_send
	./radio_send.exe | diff - radio_send.out
	make all FILE=base_station
	./base_station.exe | diff - base_station.out

dist: clean_ceu
	cd .. ; \
	mv nesc/ ceu_nesc_`date +%F`/ ; \
	tar hcvzf ceu_nesc_`date +%F`.tgz ceu_nesc_`date +%F`/ ; \
	mv ceu_nesc_`date +%F`/ nesc/ ;

clean_ceu:
	rm -f *.exe _ceu_*

