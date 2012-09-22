all:
	./ceu $(CEUFILE) --m4
	gcc main.c $(CFLAGS) -lrt

clean:
	rm -f *.exe _ceu_* samples/*_m4

.PHONY: all clean
