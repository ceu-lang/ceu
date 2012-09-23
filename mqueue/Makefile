all:
	./ceu $(CEUFILE) --m4
	gcc main.c $(CFLAGS) -lrt

clean:
	rm -f *.exe _ceu_* *.ceu_m4 samples/*.ceu_m4

.PHONY: all clean
