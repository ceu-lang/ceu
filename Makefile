all:
	./ceu $(CEUFILE) --m4 --analysis
	gcc main.c $(CFLAGS)

clean:
	rm -f *.exe _ceu_*
	cd mqueue/  && make clean
	cd arduino/ && make clean
	cd nesc/    && make clean && rm -f _ceu_* samples/*_m4

.PHONY: all clean
