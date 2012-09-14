#_______________________________________________________________________________
#
#                         edam's arduino makefile
#_______________________________________________________________________________
#                                                                    version 0.1
#
# Copyright (c) 2011 Tim Marston <tim@ed.am>.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#_______________________________________________________________________________
#
#
# This is a general purpose makefile for use with Arduino hardware and
# software.  It works with the arduino-1.0 release and requires that software
# to be downloaded separately (see http://arduino.cc/).  To download the latest
# version of this makefile, visit the following website, where you can also
# find more information and documentation on it's use.  The following text can
# only really be considered a reference to it's use.
#
#   http://ed.am/dev/make/arduino-mk
#
# This makefile can be used as a drop-in replacement for the Arduino IDE's
# build system.  To use it, save arduino.mk somewhere (I keep mine at
# ~/src/arduino.mk) and create a symlink to it in your project directory named
# "Makefile".  For example:
#
#   $ ln -s ~/src/arduino.mk Makefile
#
# You also need to set up a couple of environment varibales. ARDUINODIR should
# be set to the path where you unpacked the arduino software from arduino.cc
# (it defaults to ~/opt/arduino if unset).  You might be best to set this in
# your ~/.profile by adding something like this:
#
#   export ARDUINODIR=~/somewhere/arduino-1.0
#
# You will also need to set BOARD to the type of arduino you're using.  This
# can be done when running make (or you could set a default in ~/.profile and
# iverride it as necessary).  For example:
#
#   $ export BOARD=uno
#   $ make
#
# You may also need to set SERIALDEV if it is not detected correctly.
#
# The presence of a .ino or .pde file causes the arduino.mk to atuomatically
# determine va;ues for SOURCES, TARGET and LIBRARIES.  Any .c, .cc and .cpp
# files in the project directory (or any "util" or "utility" subdirectoried)
# are automatically included in the build and are scanned for Atduino libraries
# that have been #included.
#
# Alternatively, if you want to manually specify build variables, create a
# Makefile that defines SOURCES and LIBRARARIES and then includes arduino.mk.
# (There is no need to define TARGET).  Here is an example Makefile:
#
#   SOURCES := main.cc other.cc
#   LIBRARIES := EEPROM
#   include ~/src/arduino.mk
#
# Here is a complete list of configuration parameters:
#
# ARDUINODIR   The path where you have installed/unpacked the arduino software
#              (from http://arduino.cc/)
#
# BOARD        Specify a target board type.  Run `make boards` to see available
#              board types.
#
# SERIALDEV    The unix device of the device where the arduino can be found.
#              If unspecified, an attempt is made to determine the name of a
#              connected arduino's serial device.
#
# TARGET       The name of the target file.  This is set automatically if a
#              .ino or .pde is found, but it is not neccesary to set it
#              otherwise.
#
# SOURCES      A list of all source files of whatever language.  The language
#              type is determined by the file extension.  This is set
#              automatically if a .ino or .pde is found.
#
# LIBRARIES    A list of arduino libraries to build and include.  This is set
#              automatically if a .ino or .pde is found.
#
# This makefile also defines the following goals for use on the command line
# when you run make:
#
# _all          This is the default if no goal is specified.  It builds the
#              target and uploads it.
#
# target       Builds the target.
#
# upload       Uploads the last built target to an attached arduino.
#
# _clean        Deletes files created during the build.
#
# boards       Display a list of available board names, so that you can set the
#              BOARD environment variable appropriately.
#
# monitor      Start `screen` on the serial device.  It is ment to be an
#              equivelant to the arduino serial monitor.
#
# <file>       Builds the specified file, either an object file or the target,
#              from those that that would be built for the project.
#_______________________________________________________________________________
#

# The full path to the arduino software, from arduino.cc
ifndef ARDUINODIR
ARDUINODIR := $(wildcard ~/opt/arduino)
endif

# check arduino software
ifeq ($(wildcard $(ARDUINODIR)/hardware/arduino/boards.txt), )
$(error ARDUINODIR is not set correctly; arduino software not found)
endif

# auto mode?
ifndef INOFILE
INOFILE := $(wildcard *.ino *.pde)
endif
ifdef INOFILE
ifneq ($(words $(INOFILE)), 1)
$(error There is more than one .pde or .ino file in this directory!)
endif
TARGET := $(basename $(INOFILE))
SOURCES := $(INOFILE) \
	$(wildcard $(addprefix util/, *.c *.cc *.cpp)) \
	$(wildcard $(addprefix utility/, *.c *.cc *.cpp))
# automatically determine included libraries
ARDUINOLIBSAVAIL := $(notdir $(wildcard $(ARDUINODIR)/libraries/*))
LIBRARIES := $(filter $(ARDUINOLIBSAVAIL), \
	$(shell sed -ne "s/^ *\# *include *[<\"]\(.*\)\.h[>\"]/\1/p" $(SOURCES)))
endif

# no target? use default
ifndef TARGET
TARGET := a.out
endif

# no serial device? attempt to detect an arduino
ifndef SERIALDEV
SERIALDEV := $(firstword $(wildcard /dev/ttyACM? /dev/ttyUSB?))
endif

# no board? oh dear...
ifndef BOARD
ifneq "$(MAKECMDGOALS)" "boards"
ifneq "$(MAKECMDGOALS)" "_clean"
$(error BOARD is unset.  Type 'make boards' to see possible values)
endif
endif
endif

# files
OBJECTS := $(addsuffix .o, $(basename $(SOURCES)))
ARDUINOSRCDIR := $(ARDUINODIR)/hardware/arduino/cores/arduino
ARDUINOLIB := _arduino.a
ARDUINOLIBTMP := _arduino.a.tmp
ARDUINOLIBOBJS := $(patsubst %, $(ARDUINOLIBTMP)/%.o, $(basename $(notdir \
	$(wildcard $(addprefix $(ARDUINOSRCDIR)/, *.c *.cpp)))))
ARDUINOLIBOBJS += $(foreach lib, $(LIBRARIES), \
	$(patsubst %, $(ARDUINOLIBTMP)/%.o, $(basename $(notdir \
	$(wildcard $(addprefix $(ARDUINODIR)/libraries/$(lib)/, *.c *.cpp))))))

# obtain board parameters from the arduino boards.txt file
BOARDS_FILE := $(ARDUINODIR)/hardware/arduino/boards.txt
BOARD_BUILD_MCU := \
	$(shell sed -ne "s/$(BOARD).build.mcu=\(.*\)/\1/p" $(BOARDS_FILE))
BOARD_BUILD_FCPU := \
	$(shell sed -ne "s/$(BOARD).build.f_cpu=\(.*\)/\1/p" $(BOARDS_FILE))
BOARD_BUILD_VARIANT := \
	$(shell sed -ne "s/$(BOARD).build.variant=\(.*\)/\1/p" $(BOARDS_FILE))
BOARD_UPLOAD_SPEED := \
	$(shell sed -ne "s/$(BOARD).upload.speed=\(.*\)/\1/p" $(BOARDS_FILE))
BOARD_UPLOAD_PROTOCOL := \
	$(shell sed -ne "s/$(BOARD).upload.protocol=\(.*\)/\1/p" $(BOARDS_FILE))

# software
CC := avr-gcc
CXX := avr-g++
LD := avr-ld
AR := avr-ar
OBJCOPY := avr-objcopy
AVRDUDE := avrdude
AVRSIZE := avr-size

# flags
CPPFLAGS = -Os -Wall -fno-exceptions -ffunction-sections -fdata-sections
CPPFLAGS += -fno-strict-aliasing      # required for accessing VARS
CPPFLAGS += -mmcu=$(BOARD_BUILD_MCU) -DF_CPU=$(BOARD_BUILD_FCPU)
CPPFLAGS += -I. -Iutil -Iutility -I$(ARDUINOSRCDIR)
CPPFLAGS += -I$(ARDUINODIR)/hardware/arduino/variants/$(BOARD_BUILD_VARIANT)/
CPPFLAGS += $(addprefix -I$(ARDUINODIR)/libraries/, $(LIBRARIES))
CPPFLAGS += $(patsubst %, -I$(ARDUINODIR)/libraries/%/utility, $(LIBRARIES))
#AVRDUDEFLAGS = -C $(ARDUINODIR)/hardware/tools/avrdude.conf -DV
AVRDUDEFLAGS = -C /etc/avrdude.conf -DV
AVRDUDEFLAGS += -p $(BOARD_BUILD_MCU) -P $(SERIALDEV)
AVRDUDEFLAGS += -c $(BOARD_UPLOAD_PROTOCOL) -b $(BOARD_UPLOAD_SPEED)
LINKFLAGS = -Os -Wl,--gc-sections -mmcu=$(BOARD_BUILD_MCU)

# default rule
#.DEFAULT_GOAL := _all

#_______________________________________________________________________________
#                                                                          RULES

.PHONY:	_all target upload _clean boards monitor

_all: target upload

target: $(TARGET).hex

upload:
	@echo "\nUploading to board..."
	@test -n "$(SERIALDEV)" || { \
		echo "error: SERIALDEV could not be determined automatically." >&2; \
		exit 1; }
	stty -F $(SERIALDEV) hupcl
	$(AVRDUDE) $(AVRDUDEFLAGS) -U flash:w:$(TARGET).hex:i

_clean:
	rm -f $(OBJECTS)
	rm -f $(TARGET).elf $(TARGET).hex $(ARDUINOLIB) *~
	rm -rf $(ARDUINOLIBTMP)

boards:
	@echo Available values for BOARD:
	@sed -ne '/^#/d;s/^\(.*\).name=\(.*\)/\1            \2/;T' \
		-e 's/\(.\{12\}\) *\(.*\)/\1 \2/;p' $(BOARDS_FILE)

monitor:
	@test -n "$(SERIALDEV)" || { \
		echo "error: SERIALDEV could not be determined automatically." >&2; \
		exit 1; }
	screen $(SERIALDEV)

# building the target

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex -R .eeprom $< $@

.INTERMEDIATE: $(TARGET).elf

$(TARGET).elf: $(ARDUINOLIB) $(OBJECTS)
	$(CC) $(LINKFLAGS) $(OBJECTS) $(ARDUINOLIB) -o $@
	$(AVRSIZE) $@

%.o: %.ino
	$(COMPILE.cpp) -o $@ -x c++ -include $(ARDUINOSRCDIR)/Arduino.h $<

%.o: %.pde
	$(COMPILE.cpp) -o $@ -x c++ -include $(ARDUINOSRCDIR)/Arduino.h $<

# building the arduino library

$(ARDUINOLIB): $(ARDUINOLIBOBJS)
	$(AR) rcs $@ $?
	rm -rf $(ARDUINOLIBTMP)

.INTERMEDIATE: $(ARDUINOLIBOBJS)

$(ARDUINOLIBTMP)/%.o: $(ARDUINOSRCDIR)/%.c
	@test -d $(ARDUINOLIBTMP) || mkdir $(ARDUINOLIBTMP)
	$(COMPILE.c) -o $@ $<

$(ARDUINOLIBTMP)/%.o: $(ARDUINOSRCDIR)/%.cpp
	@test -d $(ARDUINOLIBTMP) || mkdir $(ARDUINOLIBTMP)
	$(COMPILE.cpp) -o $@ $<

$(ARDUINOLIBTMP)/%.o: $(ARDUINODIR)/libraries/*/%.c
	@test -d $(ARDUINOLIBTMP) || mkdir $(ARDUINOLIBTMP)
	$(COMPILE.c) -o $@ $<

$(ARDUINOLIBTMP)/%.o: $(ARDUINODIR)/libraries/*/%.cpp
	@test -d $(ARDUINOLIBTMP) || mkdir $(ARDUINOLIBTMP)
	$(COMPILE.cpp) -o $@ $<
