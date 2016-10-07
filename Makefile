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
		echo File: "$$i -> /tmp/$$(basename $$i .ceu)";	                    \
		grep "#@" "$$i" | cut -f2- -d" ";                                   \
		echo -n "#####################################";                    \
		echo    "#####################################";                    \
		echo -n "Press <enter> to start...";                                \
		read _;                                                             \
		echo ceu --ceu --ceu-input=$$i                                      \
		    --env --env-types=env/types.h --env-threads=env/threads.h --env-main=env/main.c \
            --cc --cc-args=\"-llua5.3 -lpthread\"                           \
	             --cc-output=/tmp/$$(basename $$i .ceu);                    \
		ceu --ceu --ceu-input=$$i                                           \
		    --env --env-types=env/types.h --env-threads=env/threads.h --env-main=env/main.c \
            --cc --cc-args="-llua5.3 -lpthread"                             \
	             --cc-output=/tmp/$$(basename $$i .ceu);                    \
		/tmp/$$(basename $$i .ceu);	                                        \
		echo ">>> OK";                                                      \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
	done

.PHONY: help compiler install samples
