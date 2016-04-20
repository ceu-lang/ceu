#!/usr/bin/env lua

--RUNTESTS_file = assert(io.open('/tmp/fin.txt','w'))

RUNTESTS = true

-- Execution option for the tests:
--VALGRIND = true
--REENTRANT = true
--LUACOV = 'lua -lluacov'
--COMPLETE = true
OS = false   -- false, true, nil(random)

OUT_DIR = '/tmp/ceu-tests'
os.execute('mkdir -p '..OUT_DIR)

assert(loadfile'pak.lua')('lua')

math.randomseed(os.time())
T = nil

STATS = {
    count   = 0,
    mem     = 0,
    trails  = 0,
    bytes   = 0,
}

function check (mod)
    assert(T[mod]==nil or T[mod]==false or type(T[mod])=='string')
    local ok, msg = pcall(dofile, mod..'.lua')
    if T[mod]~=nil then
        assert(ok==false, 'no error found')
        assert(string.find(msg, T[mod], nil, true), tostring(msg))
        return false
    else
        assert(ok==true, msg)
        return true
    end
end

Test = function (t)
    T = t

    --assert(T.todo == nil)
    if T.todo then
        return
    end
    if T.complete and (not COMPLETE) then
        return  -- only run "t.complete=true" with the "COMPLETE=true" flag
    end

    local source = T[1]
    if not T.complete then
        -- do not print large files
        --local source = 'C _fprintf(), _stderr;'..T[1]
        print('\n=============\n---\n'..source..'\n---\n')
    end

    local ARCH = '../../arch/pthread'
    OPTS = {
        tp_word = 4,
        tp_off  = 2,
        tp_lbl  = 2,
        safety  = t.safety or 1,

        out_dir = '/tmp',
        cpp     = true,
        cpp_exe = 'cpp',
        cpp_args = (T.cpp_args or '')..'-I'..ARCH..' -I'..ARCH..'/up',
        input   = 'tests.lua',
        source  = source,
    }

    STATS.count = STATS.count   + 1

    dofile 'tp.lua'

    if not check('lines')    then return end
    local _WRN = WRN
    if (not t.wrn) and (not t._ana) then
        WRN = ASR
    end

    if not check('parser')   then return end
    if not check('ast')      then return end
    if not check('adj')      then return end
    if not check('sval')     then return end
    if not check('env')      then return end
    --AST.dump(AST.root)
    --if not check('exp')      then return end
    if not check('adt')      then return end
    if not check('mode')     then return end
    if not check('ref')      then return end
    if not check('cval')     then return end
    if not check('tight')    then return end
    if not check('fin')      then return end
    if not check('props')    then return end
    if not check('ana')      then return end
    if not check('acc')      then return end

    if not check('trails')   then return end
    if not check('labels')   then return end
    if not check('tmps')     then return end
    if not check('mem')      then return end
    if not check('val')      then return end
    if not check('code')     then return end

    if (not t.wrn) and (not t._ana) then
        WRN = _WRN
    end

    --STATS.mem     = STATS.mem     + AST.root.mem.max
    STATS.trails  = STATS.trails  + AST.root.trails_n

--[[
    if T.awaits then
        assert(T.awaits==_AWAITS.n, 'awaits '.._AWAITS.n)
    end
]]

    if T.tot then
        assert(T.tot==MEM.max, 'mem '..MEM.max)
    end

    assert(t._ana or (TIGHT and T.loop) or
                     (not (TIGHT or T.loop)))

    -- ANALYSIS
    --AST.dump(AST.root)
    assert((not T.unreachs) and (not T.isForever)) -- move to analysis
    do
        local _defs = { reachs=0, unreachs=0, isForever=false,
                        acc=0, abrt=0, excpt=0 }
        for k, v in pairs(ANA.ana) do
-- TODO
if k ~= 'excpt' then
if k ~= 'abrt' then
if k ~= 'unreachs' then
if not (k=='acc' and T._ana and T._ana.acc==true) then  -- ignore acc=true
            assert( v==_defs[k] and (T._ana==nil or T._ana[k]==nil)
                    or (T._ana and T._ana[k]==v),
                    --or (T._ana and T._ana.acc==ANALYSIS.acc),
                            k..' = '..tostring(v))
end
end
end
end
        end
        if T._ana then
            for k, v in pairs(T._ana) do
if k ~= 'excpt' then
if k ~= 'abrt' then
if k ~= 'unreachs' then
if not (k=='acc' and T._ana and T._ana.acc==true) then  -- ignore acc=true
                assert( v == ANA.ana[k],
                            k..' = '..tostring(ANA.ana[k]))
end
end
end
end
            end
        end
    end
--[[
]]
--do return end

    -- RUN

    if (not T.run) and not(T.gcc or T.asr) then
        assert(T.run==false or T.loop or T._ana,
            'missing run value')
        return
    end

    -- TODO: pedantic
    local O = ' -Wall -Wextra -Wformat=2 -Wstrict-overflow=3 -Werror '
            ..' -Wno-missing-field-initializers'
            ..' -Wno-maybe-uninitialized'
            ..' -Wno-unused'
            ..' -Wno-unused-parameter'
            ..' -I'..OUT_DIR
            ..' -ansi'
            ..' -DCEU_DEBUG'
            --..' -DCEU_DEBUG_TRAILS'
            ..' '..(OPTS.cpp_args or '')

    if VALGRIND then
        O = O .. ' -g'
    end

    if T.usleep or PROPS.has_threads then
        -- usleep is deprecated and gcc always complains
        O = O .. ' -Wno-implicit-function-declaration'
    end

    local CEU, GCC
    local cpp = (OPTS.cpp_args and '--cpp-args "'..OPTS.cpp_args..'"') or ''
    local opts = T.opts or ''
    opts = opts..' --out-dir '..OUT_DIR
    local main = ARCH..'/ceu_main.c'
    local tm  = (T.timemachine and '--timemachine') or ''
    local r = (math.random(2) == 1)
    if OS==true or (OS==nil and r) then
        CEU = (LUACOV or '')..' ./ceu '..OUT_DIR..'/_ceu_tmp.ceu '..cpp..' '..opts..'  --run-tests --os '..tm..' 2>&1'
        GCC = 'gcc '..O..' -include _ceu_app.h -o ceu.exe '..main..'  ceu_sys.c _ceu_app.c 2>&1'
    else
        CEU = (LUACOV or '')..' ./ceu '..OUT_DIR..'/_ceu_tmp.ceu '..cpp..' '..opts
                ..(REENTRANT and '--reentrant' or '')
                ..' --run-tests '..tm..' 2>&1'
        GCC = 'gcc '..O..' -o '..OUT_DIR..'/ceu.exe -I'..ARCH..' '..main..' 2>&1'
    end
    --local line = debug.getinfo(2).currentline
    --os.execute('echo "/*'..line..'*/" > /tmp/line')
    --os.execute('cat /tmp/line _ceu_app.c > /tmp/file')
    --os.execute('mv /tmp/file _ceu_app.c')

    if PROPS.has_threads then
        GCC = GCC .. ' -lpthread'
    end
    if PROPS.has_lua then
        GCC = GCC .. ' -llua5.1'
    end
--DBG(CEU)
--DBG(GCC)

    local ARGS = T.args or ''
    local EXE = (((not VALGRIND) or T.valgrind==false) and OUT_DIR..'/ceu.exe '..ARGS..' 2>&1')
             or 'valgrind -q --leak-check=full '..OUT_DIR..'/ceu.exe '..ARGS..' 2>&1'
             --or 'valgrind -q --tool=helgrind ./ceu.exe 2>&1'

    local go = function (src, exp)
        local ceu = assert(io.open(OUT_DIR..'/_ceu_tmp.ceu', 'w'))
        ceu:write(src)
        ceu:close()
        local exec_ceu = os.execute(CEU)
        assert(exec_ceu==0 or exec_ceu==true)

        if T.gcc then
            local ret = assert(io.popen(GCC)):read'*a'
            assert( string.find(ret, T.gcc, nil, true), ret )
            return
        else
            local gcc = os.execute(GCC)
            assert(gcc==0 or gcc==true)
        end

        if exp == true then
            return  -- T.run==true, do not run
        end

        -- skip "threads" tests with VALGRIND on
        if PROPS.has_threads and VALGRIND then
            return
        end

        if T.asr then
            local exe = os.execute(EXE)
            assert(exe ~= 256)  -- 256 = OK
        else
            -- test output
            local ret = io.popen(EXE):read'*a'
            assert(not string.find(ret, '==%d+=='), 'valgrind error')
            local v = tonumber( string.match(ret, 'END: (.-)\n') )

            if type(exp)=='number' then
                assert(v==exp, ret..' vs '..exp..' expected')
            else
                assert( string.find(ret, exp, nil, true), ret )
            end
        end
    end

    -- T.run = N
    if type(T.run) ~= 'table' then
        print(source)
        go(source, T.run)
    else
        local par = 'par'--(T.awaits and T.awaits>0 and 'par') or 'par/or'
        source =
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
            local source = string.gsub(source, '`EVTS', input)
            go(source, ret2)
        end
    end

    if not T.gcc then
        local f = io.popen('du -b '..OUT_DIR..'/ceu.exe')
        local n = string.match(f:read'*a', '(%d+)')
        STATS.bytes = STATS.bytes + n
        f:close()
    end
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

if LUACOV then
    os.execute('luacov')
    os.remove('luacov.stats.out')
end

os.execute('rm -f /tmp/_ceu_*')

--[[
===

-- COMPLETE=false, VALGRIND=false
> /usr/bin/time --format='(%C: %Us %Mk)' ./run_tests.lua

STATS = {
    count   = 2780,
    mem     = 0,
    trails  = 6063,
    bytes   = 37971664,
}
(./run_tests.lua: 729.84s 50348k)

-- with c-stack-longjmp-no, but not yet cleaned
STATS = {
    count   = 2953,
    mem     = 0,
    trails  = 6463,
    bytes   = 35420104,
}
(./run_tests.lua: 846.00s 50496k)

-- with c-stack-longjmp-no, but cleaned-1
STATS = {
    count   = 2953,
    mem     = 0,
    trails  = 6463,
    bytes   = 33295058,
}
(./run_tests.lua: 802.49s 53308k)

-- with c-stack-longjmp-no, but cleaned-2
STATS = {
    count   = 2953,
    mem     = 0,
    trails  = 6463,
    bytes   = 33110738,
}
(./run_tests.lua: 808.63s 51912k)
STATS = {
    count   = 2953,
    mem     = 0,
    trails  = 6463,
    bytes   = 33781282,
}
(./run_tests.lua: 828.69s 53068k)
STATS = {
    count   = 2953,
    mem     = 0,
    trails  = 6463,
    bytes   = 33721874,
}
(./run_tests.lua: 737.99s 52916k)



===

-- ROCKS
> cd ../ceu-sdl/rocks/
> make test

--- two-pass scheduler + clear_org
SCORE = 56 vs 49
(./rocks.exe: 2.33s 31916k)
294063
--- c-stack-longjmp-no, some mods in the game
SCORE = 40 vs 58
(./rocks.exe: 1.39s 31896k)
214734
]]

--[[
-- before changing to set/longjmp
-- goes up to the error in ASTs (I think)
STATS = {
    count   = 2698,
    mem     = 0,
    trails  = 5269,
    bytes   = 24166370,
}
(./run_tests.lua: 676.92s 22704k)


-- goes up to CLASSES

-- before removing CLEAR from blocks
STATS = {
    count   = 1388,
    mem     = 0,
    trails  = 2124,
    bytes   = 11889387,
}
(./run_tests.lua: 301.86s 21492k)
-- after removing CLEAR from blocks
STATS = {
    count   = 1388,
    mem     = 0,
    trails  = 2124,
    bytes   = 11889387,
}
(./run_tests.lua: 293.30s 21300k)
STATS = {
    count   = 1389,
    mem     = 0,
    trails  = 2126,
    bytes   = 11911256,
}
-- after removing end-of-block _ceu_trl readjustment
(./run_tests.lua: 287.60s 24216k)
STATS = {
    count   = 1389,
    mem     = 0,
    trails  = 2126,
    bytes   = 11898968,
}
(./run_tests.lua: 283.55s 21268k)
-- after including the test case that used to fail
STATS = {
    count   = 1389,
    mem     = 0,
    trails  = 2127,
    bytes   = 11912444,
}
(./run_tests.lua: 286.71s 27296k)
-- no unecessary longjmp
STATS = {
    count   = 1389,
    mem     = 0,
    trails  = 2127,
    bytes   = 11879676,
}
(./run_tests.lua: 285.22s 29660k)
-- tceu_ntrl
STATS = {
    count   = 1389,
    mem     = 0,
    trails  = 2127,
    bytes   = 11851004,
}
(./run_tests.lua: 282.82s 32340k)

-- inclui threads,lua
STATS = {
    count   = 1503,
    mem     = 0,
    trails  = 2390,
    bytes   = 13611846,
}
(./run_tests.lua: 419.44s 28536k)
-- with CEU_JMP_*
STATS = {
    count   = 1503,
    mem     = 0,
    trails  = 2390,
    bytes   = 13702282,
}
(./run_tests.lua: 411.36s 27440k)
-- w/o depth_abortion
STATS = {
    count   = 1504,
    mem     = 0,
    trails  = 2393,
    bytes   = 13770925,
}
(./run_tests.lua: 399.93s 29176k)


-- WRONG SEMANTICS
(./run_tests.lua: 743.23s 37444k)
(./run_tests.lua: 763.66s 37452k)


]]
