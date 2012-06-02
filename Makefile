DATE = `date +%F`

all:
	./ceu $(CEUFILE) --m4 --output _ceu_code.c
	gcc main.c $(CFLAGS)

clean:
	rm -f *.exe _ceu_* ceu

arduino: clean
	lua pak.lua ; \
	cd arduino/ ; \
	mkdir -p ceu_arduino_$(DATE)/samples/ ; \
	cp ceu README Makefile arduino.mk *.pde ceu_arduino_$(DATE)/ ; \
	cp samples/*.ceu ceu_arduino_$(DATE)/samples/ ; \
	tar hcvzf ceu_arduino_$(DATE).tgz ceu_arduino_$(DATE)/ ; \
	rm -Rf ../../ceu_arduino_$(DATE)/ ; \
	mv ceu_arduino_* ../../ ; \
	cd ../../site/downloads/ ; \
	cp ../../ceu_arduino_$(DATE).tgz . ; \
	rm -f ceu_arduino_current.tgz ; \
	ln -s ceu_arduino_$(DATE).tgz ceu_arduino_current.tgz ; \

nesc: clean
	lua pak.lua ; \
	cd nesc/    ; \
	\
	mkdir -p ceu_nesc_$(DATE)/ ; \
	cp ceu README Makefile *.nc *.c IO.h *.m4 ceu_nesc_$(DATE)/ ; \
	\
	mkdir -p ceu_nesc_$(DATE)/samples/ ; \
	cp samples/*.ceu ceu_nesc_$(DATE)/samples/ ; \
	\
	mkdir -p ceu_nesc_$(DATE)/simul/ ; \
	cd simul/ ; \
	cp ceu *.lua *.m4 *.c *.h ../ceu_nesc_$(DATE)/simul/ ; \
	cd ../ ; \
	\
	tar hcvzf ceu_nesc_$(DATE).tgz ceu_nesc_$(DATE)/ ; \
	rm -Rf ../../ceu_nesc_$(DATE)/ ; \
	mv ceu_nesc_* ../../ ; \
	\
	cd ../../site/downloads/ ; \
	cp ../../ceu_nesc_$(DATE).tgz . ; \
	rm -f ceu_nesc_current.tgz ; \
	ln -s ceu_nesc_$(DATE).tgz ceu_nesc_current.tgz ; \

.PHONY: all clean arduino nesc
