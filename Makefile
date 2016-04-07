do_compiler =
do_ceu =
do_c =
do_clean =
ifeq ($(MAKECMDGOALS),all)
	do_compiler = yes
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

ARCH_DIR_ABS ?= $(PWD)/arch/dummy

LUA_EXE      ?= lua

C_EXE    ?= gcc
C_FLAGS  += -I$(OUT_DIR)

CEU_DIR   ?= .
CEU_EXE   ?= $(CEU_DIR)/ceu
CEU_FLAGS += --cpp-args "-I $(ARCH_DIR_ABS)"

OUT_DIR		 ?= build
OUT_EXE      ?= $(OUT_DIR)/$(basename $(notdir $(SRC))).exe

ifdef do_ceu
ifndef SRC
$(error USAGE: make SRC=<path-to-ceu-file>)
endif
endif

help:
	@echo "See the file README.md"

all: compiler ceu c
	$(OUT_EXE)

compiler:
	cd $(CEU_DIR)/compiler/lua/ && $(LUA_EXE) pak.lua $(LUA_EXE) $(ARCH_DIR_ABS)
	mv $(CEU_DIR)/compiler/lua/ceu .
	$(CEU_EXE) --dump

ceu:
	mkdir -p $(OUT_DIR)
	$(CEU_EXE) --out-dir $(OUT_DIR) $(CEU_FLAGS) $(SRC)

c:
	$(C_EXE) $(ARCH_DIR_ABS)/main.c $(C_FLAGS) -o $(OUT_EXE)

clean:
	rm -rf $(OUT_DIR)/

ifdef ARCH_DIR_ABS
include $(ARCH_DIR_ABS)/Makefile
endif

.PHONY: help all compiler ceu clean
