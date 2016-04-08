###############################################################################
# EDIT
###############################################################################

ARCH_DIR ?= arch/dummy

LUA_EXE ?= lua

C_EXE    ?= gcc
C_FLAGS  += -I $(ARCH_DIR) -I $(OUT_DIR)

CEU_DIR   ?= .
CEU_EXE   ?= /usr/local/bin/ceu
CEU_FLAGS += --cpp-args "-I $(ARCH_DIR)"

OUT_DIR	?= build
OUT_EXE ?= $(OUT_DIR)/$(basename $(notdir $(SRC))).exe

###############################################################################
# DO NOT EDIT
###############################################################################

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
ifndef SRC
$(error USAGE: make SRC=<path-to-ceu-file>)
endif
endif

ifndef do_compiler
ifeq ("$(wildcard $(CEU_EXE))","")
$(error "$(CEU_EXE)" is not found: run "make compiler")
endif
endif

help:
	@echo "See the file README.md"

all: ceu c
	$(OUT_EXE)

compiler:
	cd $(CEU_DIR)/compiler/lua/ && $(LUA_EXE) pak.lua $(LUA_EXE)
	mv $(CEU_DIR)/compiler/lua/ceu $(CEU_EXE)
	$(CEU_EXE) --dump

ceu:
	mkdir -p $(OUT_DIR)
	$(CEU_EXE) --out-dir $(OUT_DIR) $(CEU_FLAGS) $(SRC)

c:
	$(C_EXE) $(ARCH_DIR)/ceu_main.c $(C_FLAGS) -o $(OUT_EXE)

samples:
	$(foreach var,samples/*.ceu,echo $(var);)
	for i in samples/*; do							\
		echo "#######################";				\
		echo "# $$i";								\
		echo "#######################";				\
		if [ "$$i" = "samples/test-03.ceu" ]; then	\
			make ARCH_DIR=arch/pthread SRC=$$i all;	\
		else										\
			make SRC=$$i all;						\
		fi											\
	done

clean:
	rm -rf $(OUT_DIR)/

ifndef do_compiler
ifdef ARCH_DIR
include $(ARCH_DIR)/Makefile
endif
endif

.PHONY: help all compiler ceu samples clean
