#!/usr/bin/env lua

_RUNTESTS = true

dofile 'pak.lua'

math.randomseed(os.time())

STATS = {
    count   = 0,
    mem     = 0,
    trails  = 0,
    bytes   = 0,
}

function main (T)
	local f = assert(io.open('_ceu_main.c','w'))

    f:write([[
#include <stdio.h>
#include "ceu_os.h"
]])

    local zeros = {}
    for i, _ in ipairs(T) do
        zeros[#zeros+1] = 0

		f:write([[
#include "_ceu_app_]]..i..[[.h"
extern void _ceu_app_]]..i..[[_init (tceu_app* app);
extern int  _ceu_app_]]..i..[[_size;
]])
        for i, _ in ipairs(T) do
            f:write([[
tceu_app _ceu_app_]]..i..[[;
]])
        end
    end

    f:write([[
int dt () {
    return 10000;
}
int main (void)
{
    char MEM[1000000];
    int MEM_i = 0;
    int ret;
]])

    -- APPS
    for i, _ in ipairs(T) do
        f:write([[
    _ceu_app_]]..i..[[.data = (tceu_org*) &MEM[MEM_i];
    MEM_i += _ceu_app_]]..i..[[_size;
    _ceu_app_]]..i..[[.init = &_ceu_app_]]..i..[[_init;
    _ceu_app_]]..i..[[.sys_vec = CEU_SYS_VEC;
]])
    end

    -- LINKS
    T.lnks = T.lnks or {}
    for i, t in ipairs(T.lnks) do
        local src_app, src_evt, dst_app, dst_evt = unpack(t)
        f:write([[
    tceu_lnk lnk_]]..i..[[ = {
        &_ceu_app_]]..src_app..','..
        src_evt..','..[[
        &_ceu_app_]]..dst_app..','..
        dst_evt..[[
    };
]])
        f:write([[
    ceu_sys_link(&lnk_]]..i..[[);
]])
    end

    -- APPS
    for i, _ in ipairs(T) do
        f:write([[
    ceu_sys_start(&_ceu_app_]]..i..[[);
]])
    end

    f:write([[
    ret = ceu_scheduler(dt);
    printf("*** END: %d\n", ret);
	return ret;
}
]])
    f:close()
end

Test = function (T)

    if T.todo then
        print('*** TODO: '..T.todo)
        return
    end

	STATS.count = STATS.count + 1

    main(T)

    local objs = {}

    for i,src in ipairs(T) do
        local name = '_ceu_app_'..i
        local ceu = assert(io.open(name..'.ceu', 'w'))
		ceu:write(src)
		ceu:close()
        local cmd = './ceu --os --verbose '..
                               '--out-c '..name..'.c '..
                               '--out-h '..name..'.h '..
                               '--out-s '..name..'_size '..
                               '--out-f '..name..'_init '..
                                           name..'.ceu 2>&1'
        assert(os.execute(cmd) == 0)

        cmd = 'gcc -Wall -DCEU_DEBUG -ansi -o '..name..'.o'..
              ' -c '..name..'.c'
        assert(os.execute(cmd) == 0)

        objs[#objs+1] = name..'.o'
    end

    local GCC = 'gcc -Wall -DCEU_OS -DCEU_DEBUG -ansi -lpthread -o ceu.exe'..
                ' _ceu_main.c ceu_os.c ceu_pool.c '..table.concat(objs,' ')
    assert(os.execute(GCC) == 0)

    local EXE = ((not _VALGRIND) and './ceu.exe 2>&1')
             or 'valgrind -q --leak-check=full ./ceu.exe 2>&1'
             --or 'valgrind -q --tool=helgrind ./ceu.exe 2>&1'

	local ret = io.popen(EXE):read'*a'
	assert(not string.find(ret, '==%d+=='), 'valgrind error')
	local v = tonumber( string.match(ret, 'END: (.-)\n') )

	if v then
		assert(v==T.run, ret..' vs '..T.run..' expected')
	else
		assert( string.find(ret, T.run, nil, true) )
	end

	local f = io.popen('du -b ceu.exe')
    local n = string.match(f:read'*a', '(%d+)')
    STATS.bytes = STATS.bytes + n
    f:close()
end

dofile 'tests_os.lua'

print([[

=====================================

STATS = {
	count = ]]..STATS.count  ..[[,
	bytes = ]]..STATS.bytes  ..[[,
}
]])

-- w/ threads
--[[
-- before ceu_go_one
STATS = {
    count   = 1541,
    mem     = 0,
    trails  = 3034,
    bytes   = 13218173,
}

STATS = {
    count   = 1550,
    mem     = 0,
    trails  = 2987,
    bytes   = 14599117,
}


real	6m9.277s
user	5m48.772s
sys	0m47.880s
]]

os.execute('rm -f /tmp/_ceu_*')
