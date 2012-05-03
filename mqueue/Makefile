all: qu.exe
	./ceu $(CEUFILE) --events --output _ceu_code.c
	gcc main.c $(CFLAGS) -lrt

qu.exe: qu.c
	gcc qu.c -o qu.exe -lrt

clean:
	rm -f *.exe _ceu_*

.PHONY: all clean
