MODE ?= work	# work|simul

all: ceu _all

ceu:
	lua ceu.lua $(FILE).ceu --m4 --output _ceu_code.c

clean: _clean
	rm -f _ceu_*

upload: all _upload

include Makefile-1.0-v6