all:
	./ceu $(CEUFILE) --m4 --output _ceu_code.c
	gcc main.c $(CFLAGS) -lrt

clean:
	rm -f *.exe _ceu_* *_m4

.PHONY: all clean
