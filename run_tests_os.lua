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
#include <stdlib.h>
#include <assert.h>
#include <stdio.h>
#include "ceu_os.h"
]])

    for i, _ in ipairs(T) do
        f:write([[
unsigned char* f_]]..i..[[;
tceu_app* app_]]..i..[[;
]])
    end

    f:write([[
int dt () {
    return 10000;
}
int main (void)
{
    int ret;
]])

    -- APPS
    for i, _ in ipairs(T) do
        f:write([[
    {
        FILE* f = fopen("_ceu_app_]]..i..[[.o", "r");
        assert(f != NULL);
        fseek(f, 0, SEEK_END);
        int sz = ftell(f) - 0x238;
        f_]]..i..[[ = malloc(sz);
        fseek(f, 0x238, SEEK_SET);
        fread(f_]]..i..[[, 1, sz, f);
        app_]]..i..[[ = ceu_sys_start(f_]]..i..[[);
    }
]])
    end

    -- LINKS
    T.lnks = T.lnks or {}
    for i, t in ipairs(T.lnks) do
        t[1] = 'app_'..t[1]
        t[3] = 'app_'..t[3]
        f:write([[
    ceu_sys_link(]]..table.concat(t,',')..[[);
]])
    end

    f:write([[
    ret = ceu_scheduler(dt);
]])

    for i, _ in ipairs(T) do
        f:write([[
    free(f_]]..i..[[);
]])
    end

    f:write([[
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

    for i,src in ipairs(T) do
        local name = '_ceu_app_'..i
        local ceu = assert(io.open(name..'.ceu', 'w'))
		ceu:write(src)
		ceu:close()
        local cmd = './ceu --os --verbose '..
                               '--out-c '..name..'.c '..
                               '--out-h '..name..'.h '..
                                           name..'.ceu 2>&1'
        assert(os.execute(cmd) == 0)

        cmd = 'gcc -Wall -DCEU_DEBUG -ansi '..
              '-Wa,--execstack '..
              '-fpie -nostartfiles '..
              --'-static '..
              '-Wl,-Telf_x86_64.x '..
              --'-Wl,--strip-all ' ..
              '-Wl,--no-export-dynamic '..
              '-Wl,--gc-sections '..
              --'-Wl,--no-check-sections '..
              --'-Wl,--section-start=.export=0x400000 '..
              --'-Wl,--section-start=.text=0x400026 '.. -- TODO: 0x26
              --'-Wl,--section-start=.interp=0x400721 '.. -- TODO: 0x26
              --'-Wl,--section-start=.rodata=0x40073d '.. -- TODO: 0x26
              --'-Wl,--section-start=.note.gnu.build-id=0x40078c '.. -- TODO: 0x26
              --'-Wl,--section-start=.eh_frame_hdr=0x4007b0 '.. -- TODO: 0x26
              --'-Wl,--section-start=.gnuhash=0x4007f4 '.. -- TODO: 0x26
              '-Wl,-uCEU_EXPORT '..
              ' -o '..name..'.o '..name..'.c'

print(cmd)
        assert(os.execute(cmd) == 0)
    end

    local GCC = 'gcc -g -Wall -DCEU_OS -DCEU_DEBUG -ansi -lpthread '..
                '-Wa,--execstack '..
                '-o ceu.exe '..
                '_ceu_main.c ceu_os.c ceu_pool.c'
print(GCC)
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
