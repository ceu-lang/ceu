#!/usr/bin/env lua

_RUNTESTS = true

dofile 'pak.lua'

math.randomseed(os.time())

local LIBC = '/opt/musl-0.9.15'

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

    -- LOAD APPS
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
        app_]]..i..[[ = ceu_sys_load(f_]]..i..[[);
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

    -- START APPS
    for i, _ in ipairs(T) do
        f:write([[
    ceu_sys_start(app_]]..i..[[);
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
        local exec_ceu = os.execute(cmd)
        assert(exec_ceu == 0 or exec_ceu == true)

        cmd = 'gcc -Os -Wall -DCEU_DEBUG -ansi '..
              '-I '..LIBC..'/include '..
              '-Wa,--execstack '..
              '-fpie -nostartfiles '..
              --'-mcall-prologues -mshort-calls '..
              --'-nostdlib '..
              --'-static-libgcc -static-libstdc++ '..
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
              ' -o '..name..'.o '..name..'.c '..
              LIBC..'/lib/libc.a '..
              ''

print(cmd)
	local exec_cmd = os.execute(cmd)
        assert(exec_cmd == 0 or exec_cmd == true)

        -- no data and no undefined symbols
        local exec_objdump = os.execute('objdump -h '..name..'.o | fgrep ".data"')
        assert(not (exec_objdump == 0 or exec_objdump == true))
        local exec_nm = os.execute('nm -u      '..name..'.o | fgrep -v " U _start"')
        assert(not (exec_nm == 0 or exec_nm == true))
        -- cd /opt/musl-0.9.15
        -- rm lib/libc.a
        -- ar rc lib/libc.a src/string/*.o src/stdio/*.o
    end

    local GCC = 'gcc -g -Wall -DCEU_OS -DCEU_DEBUG -ansi -lpthread '..
                '-Wa,--execstack '..
                '-o ceu.exe '..
                '_ceu_main.c ceu_os.c ceu_pool.c'
print(GCC)
    local exec_gcc = os.execute(GCC)
    assert(exec_gcc == 0 or exec_gcc == true)

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

--[[
STATS = {
	count = 39,
	bytes = 1307901,
}
]]

os.execute('rm -f /tmp/_ceu_*')
