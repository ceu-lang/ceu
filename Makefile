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

ifdef do_compiler
LUA_EXE  ?= lua
ARCH_DIR ?= arch/dummy
endif

ifdef do_ceu
ARCH_DIR ?= arch/dummy
OUT_DIR   ?= build
OUT_EXE   ?= $(OUT_DIR)/$(basename $(notdir $(CEU_SRC))).exe
CEU_EXE   ?= ./ceu
CEU_FLAGS += --cpp-args "-I $(ARCH_DIR)"
ifndef CEU_SRC
$(error USAGE: make CEU_SRC=<path-to-ceu-file>)
endif
endif

ifdef do_c
ARCH_DIR ?= arch/dummy
OUT_DIR  ?= build
OUT_EXE  ?= $(OUT_DIR)/a.out
CC       ?= gcc
CFLAGS   += -I$(OUT_DIR)
endif

ifdef do_clean
OUT_DIR  ?= build
endif

help:
	@echo "See the file README.md"

all: compiler ceu c
	$(OUT_EXE)

ifdef ARCH_DIR
include $(ARCH_DIR)/Makefile
endif

compiler:
	cd compiler/lua/ && $(LUA_EXE) pak.lua $(LUA_EXE) ../../$(ARCH_DIR)
	mv compiler/lua/ceu .
	./ceu --dump

ceu:
	mkdir -p build/
	$(CEU_EXE) --out-dir $(OUT_DIR) $(CEU_FLAGS) $(CEU_SRC)

c:
	$(CC) $(ARCH_DIR)/main.c $(CFLAGS) -o $(OUT_EXE)

clean:
	rm -rf $(OUT_DIR)/

.PHONY: help all compiler ceu clean
