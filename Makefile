all:
	./ceu $(CEUFILE) --m4 --analysis
	gcc main.c $(CFLAGS)

clean:
	rm -f *.exe _ceu_* *.ceu_m4
	cd mqueue/  && make clean
	cd arduino/ && make clean
	cd nesc/    && make clean && rm -f _ceu_* *_m4 samples/*.ceu_m4

.PHONY: all clean
