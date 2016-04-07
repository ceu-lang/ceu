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
ARCH_DIR_ABS ?= $(PWD)/arch/dummy
endif

ifdef do_ceu
ARCH_DIR_ABS  ?= $(PWD)/arch/dummy
OUT_DIR   ?= build
OUT_EXE   ?= $(OUT_DIR)/$(basename $(notdir $(CEU_SRC))).exe
CEU_EXE   ?= ./ceu
CEU_FLAGS += --cpp-args "-I $(ARCH_DIR_ABS)"
ifndef CEU_SRC
$(error USAGE: make CEU_SRC=<path-to-ceu-file>)
endif
endif

ifdef do_c
ARCH_DIR_ABS ?= $(PWD)/arch/dummy
OUT_DIR  ?= build
OUT_EXE  ?= $(OUT_DIR)/a.out
C_EXE    ?= gcc
C_FLAGS  += -I$(OUT_DIR)
endif

ifdef do_clean
OUT_DIR  ?= build
endif

help:
	@echo "See the file README.md"

all: compiler ceu c
	$(OUT_EXE)

compiler:
	cd compiler/lua/ && $(LUA_EXE) pak.lua $(LUA_EXE) $(ARCH_DIR_ABS)
	mv compiler/lua/ceu .
	./ceu --dump

ceu:
	mkdir -p $(OUT_DIR)
	$(CEU_EXE) --out-dir $(OUT_DIR) $(CEU_FLAGS) $(CEU_SRC)

c:
	$(C_EXE) $(ARCH_DIR_ABS)/main.c $(C_FLAGS) -o $(OUT_EXE)

clean:
	rm -rf $(OUT_DIR)/

ifdef ARCH_DIR_ABS
include $(ARCH_DIR_ABS)/Makefile
endif

.PHONY: help all compiler ceu clean
