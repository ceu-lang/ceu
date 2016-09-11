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
	cp ./src/lua/ceu $(CEU_EXE)

samples:
	for i in samples/*.ceu; do                                              \
		echo;                                                               \
		echo -n "#####################################";                    \
		echo    "#####################################";                    \
		echo File: "$$i";                                                   \
		grep "#@" "$$i" | cut -f2- -d" ";                                   \
		echo -n "#####################################";                    \
		echo    "#####################################";                    \
		echo -n "Press <enter> to start...";                                \
		read _;                                                             \
		ceu --ceu --ceu-input=$$i                                           \
		    --env --env-header=env/header.h --env-main=env/main.c           \
            --cc --cc-args="-llua5.3 -lpthread" --cc-output=/tmp/ceu.exe;   \
		/tmp/ceu.exe;                                                       \
		echo ">>> OK";                                                      \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
	done

.PHONY: help compiler install samples
