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
extern tceu_app _ceu_app_]]..i..[[;
]])

	end

    f:write([[
int main (void)
{
    int APPS[] = { ]]..table.concat(zeros,',')..[[ };
    int ok=0, ret=0;

]])

    for i, _ in ipairs(T) do

        f:write([[
    {
        int _ok, _ret;
        if (APPS[ ]]..(i-1)..[[ ] == 0) {
            _ok = ceu_go_init(&_ret, NULL, &_ceu_app_]]..i..[[);
            if (_ok) {
                APPS[ ]]..(i-1)..[[ ] = 1;
                ok++;
                ret += _ret;
            }
        }
    }
]])

    end

    f:write([[
    if (ok==]]..#T..[[) goto _CEU_END_;

    for (;;) {
]])

    for i, _ in ipairs(T) do

        f:write([[
        {
            int _ok, _ret;
            if (APPS[ ]]..(i-1)..[[ ] == 0) {
                _ok = ceu_go_wclock(&_ret, NULL, &_ceu_app_]]..i..[[, 10000);
                if (_ok) {
                    APPS[ ]]..(i-1)..[[ ] = 1;
                    ok++;
                    ret += _ret;
                }
            }
        }
        if (ok==]]..#T..[[) goto _CEU_END_;
]])

        f:write([[
        {
            int _ok, _ret;
            if (APPS[ ]]..(i-1)..[[ ] == 0) {
                _ok = ceu_go_async(&_ret, NULL, &_ceu_app_]]..i..[[);
                if (_ok) {
                    APPS[ ]]..(i-1)..[[ ] = 1;
                    ok++;
                    ret += _ret;
                }
            }
        }
        if (ok==]]..#T..[[) goto _CEU_END_;
]])

    end

    f:write([[
    }

_CEU_END_:;
    printf("*** END: %d\n", ret);
	return ret;
}
]])

	f:close()
end

Test = function (T)

	assert(T.todo == nil)
    if T.todo then
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
        local cmd = './ceu --os --out-c '..name..'.c '..
                               '--out-h '..name..'.h '..
                               '--out-v '..name..' '..
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
