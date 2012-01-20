DATE = `date +%F`

dist: clean
	mkdir -p ../ceu_$(DATE)/ ; \
	cp *.lua *.c *.h ../ceu_$(DATE)/ ; \
	cd .. ; \
	tar hcvzf ceu_`date +%F`.tgz ceu_$(DATE)/ ; \

upload: dist
	rsync -e ssh -av ../ceu_$(DATE)/ fsantanna@sinistra.dreamhost.com:ceu/

clean:
	rm -f *.exe _ceu_*

.PHONY: clean dist
