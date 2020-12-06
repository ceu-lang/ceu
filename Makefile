###############################################################################
# EDIT
###############################################################################

LUA_EXE   = lua5.3
CEU_EXE   = /usr/local/bin/ceu
CEU_ARGS_ = --ceu-features-trace=true --ceu-err-unused=pass $(CEU_ARGS)
CC_ARGS_  = -llua5.3 -lpthread $(CC_ARGS)

###############################################################################
# DO NOT EDIT
###############################################################################

compiler:
	cd ./src/lua/ && $(LUA_EXE) pak.lua $(LUA_EXE) && ./ceu --version

install:
	install ./src/lua/ceu $(CEU_EXE)

one:
	ceu --pre --pre-input=$(CEU_SRC) --pre-args=\"-I./include\"                \
		--ceu $(CEU_ARGS_) --ceu-features-os=true \
		--env --env-types=env/types.h --env-threads=env/threads.h --env-main=env/main.c --env-output=/tmp/_ceu_app.c \
		--cc --cc-args="$(CC_ARGS_)"                        \
			 --cc-output=/tmp/$$(basename $(CEU_SRC) .ceu);                    \

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
		mkdir -p ./tmp;																											\
		echo ceu --pre --pre-input=$$i --pre-args=\"-I./include\"           \
	        --ceu --ceu-features-os=true --ceu-features-lua=true --ceu-features-thread=true --ceu-features-dynamic=true --ceu-err-unused=pass \
		    --env --env-types=env/types.h --env-threads=env/threads.h --env-main=env/main.c \
            --cc --cc-args=\"-llua5.3 -lpthread\"                           \
	             --cc-output=./tmp/$$(basename $$i .ceu);                    \
		ceu --pre --pre-input=$$i --pre-args=\"-I./include\"                \
	        --ceu --ceu-features-async=true --ceu-features-os=true --ceu-features-lua=true --ceu-features-thread=true --ceu-features-dynamic=true --ceu-err-unused=pass \
		    --env --env-types=env/types.h --env-threads=env/threads.h --env-main=env/main.c \
            --cc --cc-args="-llua5.3 -lpthread"                             \
	             --cc-output=./tmp/$$(basename $$i .ceu);                    \
		./tmp/$$(basename $$i .ceu);	                                        \
		echo ">>> OK";                                                      \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
		echo;                                                               \
	done

.PHONY: help compiler install samples
