all:
	./ceu $(CEUFILE)
	gcc main.c $(CFLAGS)

clean:
	rm -f *.exe _ceu_* *.ceu_cpp *.ceu_m4 a.out

.PHONY: all clean
