DATE = `date +%F`

all:
	./ceu --dfa $(CEUFILE) --output _ceu_code.c
	gcc main.c

clean:
	rm -f *.exe _ceu_* ceu

arduino: clean
	lua pak.lua ; \
	cd arduino/ ; \
	mkdir -p ceu_arduino_$(DATE)/samples/ ; \
	cp ceu Makefile arduino.mk *.pde ceu_arduino_$(DATE)/ ; \
	cp samples/*.ceu ceu_arduino_$(DATE)/samples/ ; \
	tar hcvzf ceu_arduino_$(DATE).tgz ceu_arduino_$(DATE)/ ; \
	mv ceu_arduino_* ../../ ;

.PHONY: all clean arduino
