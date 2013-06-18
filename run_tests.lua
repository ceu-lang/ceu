#!/usr/bin/env lua

_RUNTESTS = true

dofile 'pak.lua'

T = nil

STATS = {
    count   = 0,
    mem     = 0,
    trails  = 0,
    bytes   = 0,
}

VALGRIND = ...

function check (mod)
    assert(T[mod]==nil or T[mod]==false or type(T[mod])=='string')
    local ok, msg = pcall(dofile, mod..'.lua')
    if T[mod]~=nil then
        assert(string.find(msg, T[mod], nil, true), tostring(msg))
        return false
    else
        assert(ok==true, msg)
        return true
    end
end

Test = function (t)
    T = t
    local source = T[1]
    --local source = 'C _fprintf(), _stderr;'..T[1]
    print('\n=============\n---\n'..source..'\n---\n')

    --assert(T.todo == nil)
    if T.todo then
        return
    end

    _OPTS = {
        tp_word    = 4,
        tp_off     = 2,
        tp_lbl     = 2,
        warn_nondeterminism = true,
    }

    -- require's (don't do anything)
    dofile 'tp.lua'
    dofile 'lines.lua'
    dofile 'parser.lua'
    dofile 'ast.lua'

    STATS.count = STATS.count   + 1

    local ok, msg = pcall(_AST.f, 'tests.lua', source)
    if not ok then
        assert(string.find(msg, T.ast, nil, true), tostring(msg))
        return
    end

    if not check('adj')      then return end
    --_AST.dump(_AST.root)
    if not check('env')      then return end
    if not check('fin')      then return end
    if not check('tight')    then return end
    --dofile 'awaits.lua'
    if not check('props')    then return end
    dofile 'ana.lua'
    dofile 'acc.lua'

    if not check('trails')   then return end
    if not check('labels')   then return end
    if not check('tmps')     then return end
    if not check('mem')      then return end
    if not check('val')      then return end
    if not check('code')     then return end

    --STATS.mem     = STATS.mem     + _AST.root.mem.max
    STATS.trails  = STATS.trails  + _AST.root.trails_n

--[[
    if T.awaits then
        assert(T.awaits==_AWAITS.n, 'awaits '.._AWAITS.n)
    end
]]

    if T.tot then
        assert(T.tot==_MEM.max, 'mem '.._MEM.max)
    end

    assert(_TIGHT and T.loop or
           not (_TIGHT or T.loop))

    -- ANALYSIS
    --_AST.dump(_AST.root)
    assert((not T.unreachs) and (not T.isForever)) -- move to analysis
    do
        local _defs = { reachs=0, unreachs=0, isForever=false,
                        acc=0, abrt=0, excpt=0 }
        for k, v in pairs(_ANA.ana) do
-- TODO
if k ~= 'excpt' then
if k ~= 'abrt' then
if k ~= 'unreachs' then
            assert( v==_defs[k] and (T.ana==nil or T.ana[k]==nil)
                    or (T.ana and T.ana[k]==v),
                    --or (T.ana and T.ana.acc==_ANALYSIS.acc),
                            k..' = '..tostring(v))
end
end
end
        end
        if T.ana then
            for k, v in pairs(T.ana) do
if k ~= 'excpt' then
if k ~= 'abrt' then
if k ~= 'unreachs' then
                assert( v == _ANA.ana[k],
                            k..' = '..tostring(_ANA.ana[k]))
end
end
end
            end
        end
    end
--[[
]]

    -- RUN

    if T.run == false then
        return
    end
    if T.run == nil then
        assert(T.loop or T.ana, 'missing run value')
        return
    end

    local CEU = './ceu _ceu_tmp.ceu --run-tests'
    local EXE = (VALGRIND=='false' and './ceu.exe')
             or 'valgrind -q --leak-check=full ./ceu.exe 2>&1'
    local GCC = 'gcc -Wall -DCEU_DEBUG -ansi -o ceu.exe main.c'

    -- T.run = N
    if type(T.run) ~= 'table' then
        local str_all = source
        print(str_all)
        local ceu = assert(io.open('_ceu_tmp.ceu', 'w'))
        ceu:write(str_all)
        ceu:close()
        assert(os.execute(CEU))
        assert(os.execute(GCC) == 0)
        local ret = io.popen(EXE):read'*a'
        assert(not string.find(ret, '==%d+=='), 'valgrind error')
        ret = string.match(ret, 'END: (.-)\n')
        assert(ret==T.run..'', ret..' vs '..T.run..' expected')

    else
        local par = (T.awaits and T.awaits>0 and 'par') or 'par/or'
        local str_all =
            par .. [[ do
                ]]..source..[[
            with
                async do
                    `EVTS
                end
                await FOREVER;
            end
        ]]
        for input, ret2 in pairs(T.run) do
            input = string.gsub(input, '([^;]*)~>(%d[^;]*);?', 'emit %2;')
            input = string.gsub(input, '[ ]*(%d+)[ ]*~>([^;]*);?', 'emit %2=>%1;')
            input = string.gsub(input, '~>([^;]*);?', 'emit %1;')
            local all = string.gsub(str_all, '`EVTS', input)
            local ceu = assert(io.open('_ceu_tmp.ceu', 'w'))
            ceu:write(all)
            ceu:close()
            assert(os.execute(CEU))
            assert(os.execute(GCC) == 0)
            local ret = io.popen(EXE):read'*a'
            assert(not string.find(ret, '==%d+=='), 'valgrind error')
            ret = string.match(ret, 'END: (%-?%d+)')
            assert(tonumber(ret)==ret2, ret..' vs '..ret2..' expected')
        end
    end

    local f = io.popen('du -b ceu.exe')
    local n = string.match(f:read'*a', '(%d+)')
    STATS.bytes = STATS.bytes + n
    f:close()
end

dofile 'tests.lua'

print([[

=====================================

STATS = {
    count   = ]]..STATS.count  ..[[,
    mem     = ]]..STATS.mem    ..[[,
    trails  = ]]..STATS.trails ..[[,
    bytes   = ]]..STATS.bytes  ..[[,
}
]])

--./run_tests.lua false  114.32s user 23.74s system 76% cpu 3:00.12 total
--./run_tests.lua false  108.37s user 22.98s system 86% cpu 2:31.85 total
--./run_tests.lua false  112.09s user 23.11s system 86% cpu 2:36.97 total

assert(STATS.count  ==    1274)
assert(STATS.mem    ==       0)
assert(STATS.trails ==    2328)
assert(STATS.bytes  == 7496893)

os.execute('rm -f /tmp/_ceu_*')

do return end

-- TODO: antes emit stack
--102.94s user 21.87s system 85% cpu 2:26.66 total
assert(STATS.count  ==    1213)
assert(STATS.mem    ==       0)
assert(STATS.trails ==    2233)
assert(STATS.bytes  == 6979008)

-- TODO: antes scheduler double link
assert(STATS.count  ==    1210)
assert(STATS.mem    ==       0)
assert(STATS.trails ==    2244)
assert(STATS.bytes  == 7179277)

-- TODO: antes de mem => structs
assert(STATS.count  ==    1204)
assert(STATS.mem    ==   40452)
assert(STATS.trails ==    2355)
assert(STATS.bytes  == 7055283)

-- TODO: antes de trail de 8 bytes
assert(STATS.count  ==    1157)
assert(STATS.mem    ==   14177)
assert(STATS.trails ==    2082)
assert(STATS.bytes  == 7610546)

--[[
STATS = {
    mem   = BIG,  -- ints 1 byte  //  trlN
    bytes = BIG,  -- ON/ceu_param
}
]]
