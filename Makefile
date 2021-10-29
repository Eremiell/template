#!/usr/bin/make -f

SHELL := /bin/bash

cxx := g++
name := "$(shell pwd | sed -E "s/.*\/([[:alnum:] _-]*)/\1/")"
prof :=
std := c++20
warnflags := -Wall -Wextra -Wpedantic
binflags := -O3
dbgflags := -ggdb3 -Og
idirs := -Iinc -Ipub -Iext -Itin
ldirs :=
bindefines := -UDEBUG
dbgdefines := -DDEBUG
profdefines := -DPROF
buildopts := #-pthread #-fsanitize=
machopts := -march=native
lto := -flto
linkflags := -lstdc++fs

bindir := bin
srcdir := src
tstdir := tst

ifeq ($(cxx), clang++)
	CC := clang
	CXX := clang++
	stdlib := -stdlib=libc++
	ld := -fuse-ld=lld
else
	CC := gcc
	CXX := g++
	stdlib :=
	ld := -fuse-ld=gold
endif

ifeq ($(prof), gen)
	buildopts += -fprofile-generate -fprofile-correction
	bindefines += $(profdefines)
endif

ifeq ($(prof), use)
	buildopts += -fprofile-use -fprofile-correction
endif

ifeq ($(prof), call)
	buildopts += -ggdb3 -pg
	bindefines += $(profdefines)
endif

#bins := server client timer async_timer echo echocl
#dbgs := $(patsubst %, %dbg, $(bins))
#deps := $(patsubst %, $(bindir)/%.d, $(bins))
#srcs := $(wildcard $(srcdir)/*.cpp)

src := $(wildcard $(srcdir)/*.cpp)
tst := $(wildcard $(tstdir)/*.cpp)
obj := $(patsubst $(srcdir)/%.cpp, $(bindir)/%.o, $(src))
objdbg := $(patsubst $(srcdir)/%.cpp, $(bindir)/%dbg.o, $(src))
dep := $(patsubst $(srcdir)/%.cpp, $(bindir)/%.d, $(src)) $(patsubst $(tstdir)/%.cpp, $(bindir)/%.d, $(tst))
tst += $(filter-out $(srcdir)/main%.cpp, $(src))
tob := $(patsubst $(srcdir)/%.cpp, $(bindir)/%.o, $(patsubst $(tstdir)/%.cpp, $(bindir)/%.o, $(tst)))
depdbg := $(patsubst $(srcdir)/%.cpp, $(bindir)/%dbg.d, $(src))

#all: $(bindir)/server $(bindir)/client
#alldbg: $(bindir)/serverdbg $(bindir)/clientdbg

prod: $(bindir)/$(name)
all: prod test
dbg: $(bindir)/$(name)dbg
test: $(bindir)/test

$(bindir):
	mkdir -p $@

#$(bindir)/$(bins):
#$(bindir)/$(dbgs):

-include $(dep)
-include $(depdbg)

$(bindir)/%.d: $(srcdir)/%.cpp | $(bindir)
	$(cxx) -std=$(std) $(stdlib) $(binflags) $(warnflags) $(idirs) $(bindefines) $(buildopts) $(lto) $(machopts) -MM -MT $(@:.d=.o) $< >$@

$(bindir)/%.d: $(tstdir)/%.cpp | $(bindir)
	$(cxx) -std=$(std) $(stdlib) $(binflags) $(warnflags) $(idirs) $(bindefines) $(buildopts) $(lto) $(machopts) -MM -MT $(@:.d=.o) $< >$@

$(bindir)/%dbg.d: $(srcdir)/%.cpp | $(bindir)
	$(cxx) -std=$(std) $(stdlib) $(dbgflags) $(warnflags) $(idirs) $(dbgdefines) $(buildopts) $(machopts) -MM -MT $(@:.d=.o) $< >$@

$(bindir)/%.o: $(srcdir)/%.cpp | $(bindir)
	$(cxx) -c -std=$(std) $(stdlib) $(binflags) $(warnflags) $(idirs) $(bindefines) $(buildopts) $(lto) $(machopts) -o$@ $<

$(bindir)/%.o: $(tstdir)/%.cpp | $(bindir)
	$(cxx) -c -std=$(std) $(stdlib) $(binflags) $(warnflags) $(idirs) $(bindefines) $(buildopts) $(lto) $(machopts) -o$@ $<

$(bindir)/%dbg.o: $(srcdir)/%.cpp | $(bindir)
	$(cxx) -c -std=$(std) $(stdlib) $(dbgflags) $(warnflags) $(idirs) $(dbgdefines) $(buildopts) $(machopts) -o$@ $<

#$(bindir)/%: $(bindir)/%.o | $(bindir)
#	$(cxx) -std=$(std) $(stdlib) $(binflags) $(warnflags) $(idirs) $(ldirs) $(bindefines) $(buildopts) $(lto) -o$@ $< $(linkflags)

#$(bindir)/%dbg: $(bindir)/%dbg.o | $(bindir)
#	$(cxx) -std=$(std) $(stdlib) $(dbgflags) $(warnflags) $(idirs) $(ldirs) $(dbgdefines) $(buildopts) -o$@ $< $(linkflags)

$(bindir)/$(name): $(obj) | $(bindir)
	$(cxx) -std=$(std) $(stdlib) $(binflags) $(warnflags) $(idirs) $(ldirs) $(bindefines) $(buildopts) $(ld) $(lto) $(machopts) -o$@ $^ $(linkflags)

$(bindir)/test: $(tob) | $(bindir)
	$(cxx) -std=$(std) $(stdlib) $(binflags) $(warnflags) $(idirs) $(ldirs) $(bindefines) $(buildopts) $(ld) $(lto) $(machopts) -o$@ $^ $(linkflags)

$(bindir)/$(name)dbg: $(objdbg) | $(bindir)
	$(cxx) -std=$(std) $(stdlib) $(dbgflags) $(warnflags) $(idirs) $(ldirs) $(dbgdefines) $(buildopts) $(ld) $(machopts) -o$@ $^ $(linkflags)

#client: src/client.cpp
#	$(cxx) -std=$(std) $(stdlib) $(binflags) $(warnflags) $(idirs) $(ldirs) $(bindefines) $(buildopts) -o$@ $< $(linkflags)

#timer: src/timer.cpp
#	$(cxx) -std=$(std) $(stdlib) $(binflags) $(warnflags) $(idirs) $(ldirs) $(bindefines) $(buildopts) -o$@ $< $(linkflags)

#async_timer: src/async_timer.cpp
#	$(cxx) -std=$(std) $(stdlib) $(binflags) $(warnflags) $(idirs) $(ldirs) $(bindefines) $(buildopts) -o$@ $< $(linkflags)

compdb: compile_commands.json

compile_commands.json: clean
#	compiledb make
	bear -- make all
	compdb -p . list > $@2
	cat $@2 | sed -E "s/\"directory\": \".*\",/\"directory\": \"\.\",/" > $@
	rm $@2
	

pvs: compdb all $(bindir)/project.tasks $(src) $(tst) | $(bindir)

$(bindir)/project.tasks: $(bindir)/project.log | $(bindir)
	plog-converter -a "GA;64;OP;CS;MISRA" -t tasklist -o $@ $<

strace_out: | pvs-patch
	pvs-studio-analyzer trace -- make

$(bindir)/project.log: strace_out | $(bindir)
	pvs-studio-analyzer analyze -o $@

pvs-patch: $(src) $(tst)
	how-to-use-pvs-studio-free -c 3 .

cppcheck.list: $(src) $(tst)
	cppcheck --std=c++17 --enable=all --force $(idirs) --output-file=$@ .

clean:
	rm -rf $(bindir) strace_out compile_commands.json cppcheck.list

.PHONY:	all prod dbg test clean pvs pvs-patch compdb