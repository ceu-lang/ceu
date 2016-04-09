###############################################################################
# EDIT
###############################################################################

SRC =

ARCH_DIR ?= arch

LUA_EXE ?= lua

C_EXE   ?= gcc
C_FLAGS =

CEU_DIR   ?= .
CEU_EXE   ?= /usr/local/bin/ceu
CEU_FLAGS =

OUT_DIR	?= build
OUT_EXE ?= $(OUT_DIR)/$(basename $(notdir $(SRC_))).exe

###############################################################################
# DO NOT EDIT
###############################################################################

SRC_	   = $(SRC)
C_FLAGS_   = $(C_FLAGS) -I $(ARCH_DIR) -I $(OUT_DIR) -I .
CEU_FLAGS_ = $(CEU_FLAGS) --cpp-args "$(C_FLAGS_)"

do_compiler =
do_ceu =
do_c =
do_clean =
ifeq ($(MAKECMDGOALS),all)
	do_ceu = yes
	do_c = yes
endif
ifeq ($(MAKECMDGOALS),compiler)
	do_compiler = yes
endif
ifeq ($(MAKECMDGOALS),ceu)
	do_ceu = yes
endif
ifeq ($(MAKECMDGOALS),c)
	do_c = yes
endif
ifeq ($(MAKECMDGOALS),clean)
	do_clean = yes
endif

ifdef do_ceu
ifndef SRC_
$(error USAGE: make SRC=<path-to-ceu-file>)
endif
else
ifdef SRC_
$(error invalid target for "SRC")
endif
endif

ifndef do_compiler
ifeq ("$(wildcard $(CEU_EXE))","")
$(error "$(CEU_EXE)" is not found: run "make compiler")
endif
endif

ifdef TM
# TODO: -DTM_QUEUE
TM_SRC	   := $(SRC_)
SRC_	    = $(ARCH_DIR)/tm/main.ceu
C_FLAGS_   += -DCEU_TIMEMACHINE -DTM_SRC=$(TM_SRC) -DTM_QUEUE
CEU_FLAGS_ += --timemachine
endif

help:
	@echo "See the file README.md"

all: ceu c
	$(OUT_EXE)

compiler:
	cd $(CEU_DIR)/src/lua/ && $(LUA_EXE) pak.lua $(LUA_EXE)
	mv $(CEU_DIR)/src/lua/ceu $(CEU_EXE)
	$(CEU_EXE) --dump

ceu:
	echo "-=-=-=-=-=- $(SRC_) $(TM_SRC)"
	mkdir -p $(OUT_DIR)
	$(CEU_EXE) --out-dir $(OUT_DIR) $(CEU_FLAGS_) $(SRC_)

c:
	$(C_EXE) $(ARCH_DIR)/ceu_main.c $(C_FLAGS_) -o $(OUT_EXE)

samples:
	for i in samples/*.ceu; do									\
		echo;													\
		echo -n "#####################################";		\
		echo    "#####################################";		\
		echo File: "$$i";										\
		grep "#@" "$$i" | cut -f2- -d" ";						\
		echo -n "#####################################";		\
		echo    "#####################################";		\
		echo -n "Press <enter> to start...";					\
		read _;													\
		if [ "$$i" = "samples/test-03.ceu" ]; then				\
			make ARCH_DIR=arch/pthread SRC=$$i all || exit 1;	\
		else													\
			make SRC=$$i all || exit 1;							\
		fi;														\
		echo;													\
	done

clean:
	rm -rf $(OUT_DIR)/

ifndef do_compiler
ifdef ARCH_DIR
include $(ARCH_DIR)/Makefile
endif
endif

.PHONY: help all compiler ceu samples clean
