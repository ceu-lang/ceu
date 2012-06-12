all: qu.exe
	./ceu $(CEUFILE) --m4 --output _ceu_code.c
	gcc main.c $(CFLAGS) -lrt

qu.exe: qu.c
	gcc qu.c -lrt -o qu.exe

clean:
	rm -f *.exe _ceu_* *_m4

.PHONY: all clean
