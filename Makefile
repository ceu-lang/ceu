dist: clean
	mkdir -p ../ceu_`date +%F`/ ; \
	cp *.lua *.c *.h ../ceu_`date +%F`/ ; \
	cd .. ; \
	tar hcvzf ceu_`date +%F`.tgz ceu_`date +%F`/ ; \

clean:
	rm -f *.exe _ceu_*

.PHONY: clean dist
