###############################################################################
# EDIT
###############################################################################

LUA_EXE = lua5.3

CEU_EXE = /usr/local/bin/ceu

###############################################################################
# DO NOT EDIT
###############################################################################

compiler:
	cd ./src/lua/ && $(LUA_EXE) pak.lua $(LUA_EXE) && ./ceu --version

install:
	cp $(CEU_DIR)/src/lua/ceu $(CEU_EXE)

samples:
	for i in samples/*.ceu; do								\
		echo;												\
		echo -n "#####################################";	\
		echo    "#####################################";	\
		echo File: "$$i";									\
		grep "#@" "$$i" | cut -f2- -d" ";					\
		echo -n "#####################################";	\
		echo    "#####################################";	\
		echo -n "Press <enter> to start...";				\
		read _;												\
		if [ "$$i" = "samples/test-03.ceu" ]; then			\
			make ARCH_DIR=arch/pthread SRC=$$i all || exit 1;\
		else												\
			make SRC=$$i all || exit 1;						\
		fi;													\
		echo;												\
	done

.PHONY: help compiler install samples
