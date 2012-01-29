DATE = `date +%F`

dist: clean
	mkdir -p ../ceu_$(DATE)/ ; \
	cp *.lua *.c *.h ../ceu_$(DATE)/ ; \
	cd .. ; \
	tar hcvzf ceu_$(DATE).tgz ceu_$(DATE)/ ; \

arduino: clean
	lua pak.lua ; \
	cd arduino/ ; \
	mkdir -p ceu_arduino_$(DATE)/samples/ ; \
	cp ceu Makefile arduino.mk *.pde ceu_arduino_$(DATE)/ ; \
	cp samples/*.ceu ceu_arduino_$(DATE)/samples/ ; \
	tar hcvzf ceu_arduino_$(DATE).tgz ceu_arduino_$(DATE)/ ; \
	mv ceu_arduino_* ../../ ;

upload: dist
	rsync -e ssh -av ../ceu_$(DATE)/ fsantanna@ceu-lang.org:ceu/

clean:
	rm -f *.exe _ceu_* ceu

.PHONY: clean dist arduino upload
