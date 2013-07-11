all:
	./ceu $(CEUFILE)
	gcc main.c $(CFLAGS)

clean:
	rm -f *.exe _ceu_* a.out

.PHONY: all clean
