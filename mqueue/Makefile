all: qu
	./ceu $(CEUFILE) --m4 --output _ceu_code.c
	gcc main.c $(CFLAGS) -lrt

qu: qu.c
	gcc qu.c -lrt -o qu

clean:
	rm -f qu *.exe _ceu_* *_m4

.PHONY: all clean
