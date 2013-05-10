all:
	./ceu $(CEUFILE) --m4
	gcc main.c $(CFLAGS)

clean:
	rm -f *.exe _ceu_* *.ceu_m4 a.out

.PHONY: all clean
