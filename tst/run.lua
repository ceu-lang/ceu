#!/usr/bin/env lua5.3

RUNTESTS = {
    --luacov = 'lua5.3 -lluacov'
-- Execution option for the tests:
--VALGRIND = true
--REENTRANT = true
--COMPLETE = true
--[[
STATS = {
    count   = 0,
    mem     = 0,
    trails  = 0,
    bytes   = 0,
    n_go    = 0,
}
]]
}

if RUNTESTS.luacov then
    require 'luacov'
    os.remove('luacov.stats.out')
    os.remove('luacov.report.out')
end

T = nil

function check (mod)
    assert(T[mod]==nil or T[mod]==false or type(T[mod])=='string')
    local ok, msg = pcall(dofile, '../src/lua/'..mod..'.lua')
if RUNTESTS_TODO then
    return true
end
    if T[mod]~=nil then
        assert(ok==false, 'no error found')
        assert(string.find(msg, T[mod], nil, true), tostring(msg))
    else
        assert(ok==true, msg)
        return true
    end
end

Test = function (t)
    RUNTESTS_TODO = false
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

    local f = assert(io.open('/tmp/tmp.ceu', 'w'))
    f:write(source)
    f:close()

    PAK = {
        lua_exe = '?',
        ceu_ver = '?',
        ceu_git = '?',
        files = {
            ceu_c = assert(io.open'../src/c/ceu.c'):read'*a',
        }
    }
    CEU = {
        arg  = {},
        opts = T.opts or {
            ceu          = true,
            ceu_input    = '/tmp/tmp.ceu',
            ceu_output_h = '/tmp/tmp.ceu.h',
            ceu_output_c = '/tmp/tmp.ceu.c',

            env          = true,
            env_header   = '../arch/ceu.h',
            env_ceu      = '/tmp/tmp.ceu.c',
            env_main     = '../arch/main.c',
            env_output   = '/tmp/tmp.c',

            cc           = true,
            cc_input     = '/tmp/tmp.c',
            cc_output    = '/tmp/tmp.exe',

            --ceu_line_directives = 'true',
            ceu_line_directives = 'false',
        }
    }
    if T.opts_pre then
        CEU.opts.pre          = true
        CEU.opts.pre_input    = '/tmp/tmp.ceu'
        CEU.opts.pre_output   = '/tmp/tmp.ceu.cpp'
        CEU.opts.ceu_input    = '/tmp/tmp.ceu.cpp'
    end

    --STATS.count = STATS.count   + 1

    local DIR = '../src/lua/'

    dofile(DIR..'dbg.lua')
    DBG,ASR = DBG1,ASR1
    dofile(DIR..'cmd.lua')

    if CEU.opts.pre then
        if not check('pre') then return end
    end
    if not CEU.opts.ceu then return end
    DBG,ASR = DBG2,ASR2

    dofile(DIR..'lines.lua')
    local _WRN = WRN
    if (not t.wrn) and (not t._ana) then
        WRN = ASR
    end

    if not check('parser')   then return end
    --dofile 'ast.lua'
    if not check('ast')      then return end
    if not check('adjs')     then return end
    dofile(DIR..'types.lua')
    if not check('dcls')     then return end
    if not check('names')    then return end
    if not check('exps')     then return end
    if not check('consts')   then return end
    if not check('stmts')    then return end
    if not check('inits')    then return end
    if not check('scopes')   then return end
    if not check('trails')   then return end
    if not check('labels')   then return end
    if not check('mems')     then return end
    dofile(DIR..'vals.lua')
    if not check('codes')    then return end
--AST.dump(AST.root)

if T.ana or T._ana or T.tmp then return end

    DBG,ASR = DBG1,ASR1
    if CEU.opts.env then
        dofile(DIR..'env.lua')
    end
    if CEU.opts.cc then
        if not check('cc') then return end
    end

    local f = io.popen(CEU.opts.cc_output..' 2>&1')
    local out = f:read'*a'
    local _,_,ret = f:close()

    if type(T.run) == 'number' then
        assert(out == '')
        assert(ret == T.run%256)
    elseif type(T.run) == 'table' then
        assert(out == '')
        error'TODO'
    else
        assert(type(T.run) == 'string')
        assert(string.find(out, T.run, nil, true), out)
    end

do return end
    DBG,ASR = DBG1,ASR1
    do
        local ceu = [[
./ceu --pre --pre-input=/tmp/tmp.ceu --pre-output=/tmp/tmp.ceu.cpp      \
      --ceu --ceu-input=/tmp/tmp.ceu.cpp --ceu-output-h=/tmp/tmp.ceu.h  \
                                         --ceu-output-c=/tmp/tmp.ceu.c  \
      --env --env-header=../arch/ceu_header.h --env-ceu=/tmp/tmp.ceu.c  \
            --env-main=../arch/ceu_main.c --env-output=/tmp/tmp.c       \
      --cc --cc-input=/tmp/tmp.c --cc-output=/tmp/tmp.exe               \
      --ceu-line-directives=true
]]
        os.execute(ceu)
DBG(ceu)
error'oi'
        if RUNTESTS.luacov then
            ceu = RUNTESTS.luacov..' '..ceu
        end
    end

do return end
AST.dump(AST.root)
    if not check('adt')      then return end
    if not check('mode')     then return end
    if not check('tight')    then return end
    if not check('props')    then return end
    if not check('ana')      then return end
    if not check('acc')      then return end

    if not check('trails')   then return end
    if not check('tmps')     then return end
    if not check('mem')      then return end

    if (not t.wrn) and (not t._ana) then
        WRN = _WRN
    end

    --STATS.mem     = STATS.mem     + AST.root.mem.max
    STATS.trails  = STATS.trails  + AST.root.trails_n

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
--do return end

    -- RUN

    if (not T.run) and not(T.gcc or T.asr) then
        assert(T.run==false or T.loop or T._ana,
            'missing run value')
        return
    end

    -- TODO: pedantic
-- TODO: remove all "no" warnings
    local O = ' -Wall -Wextra -Wformat=2 -Wstrict-overflow=3 -Werror '
            --..' -Wno-missing-field-initializers'
            --..' -Wno-maybe-uninitialized'
            --..' -Wno-unused'
            --..' -Wno-unused-function'
            --..' -Wno-unused-parameter'
            --..' -I'..OUT_DIR
            --..((PROPS.has_lua and '') or ' -ansi')
            --..' -DCEU_DEBUG'
            --..' -DCEU_DEBUG_TRAILS'
            --..' '..(OPTS.cpp_args or '')

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
        CEU = './ceu '..OUT_DIR..'/_ceu_tmp.ceu '..cpp..' '..opts
                      ..' --run-tests --os '..tm..' 2>&1'
        GCC = 'gcc '..O..' -include _ceu_app.h -o ceu.exe '..main..'  ceu_sys.c _ceu_app.c 2>&1'
    else
        CEU = './ceu '..OUT_DIR..'/_ceu_tmp.ceu '..cpp..' '..opts
                      ..(REENTRANT and '--reentrant' or '')
                       ..' --run-tests '..tm..' 2>&1'
        GCC = 'gcc '..O..' -o '..OUT_DIR..'/ceu.exe -I'..ARCH..' '..main..' 2>&1'
    end
    --local line = debug.getinfo(2).currentline
    --os.execute('echo "/*'..line..'*/" > /tmp/line')
    --os.execute('cat /tmp/line _ceu_app.c > /tmp/file')
    --os.execute('mv /tmp/file _ceu_app.c')

    if RUNTESTS.luacov then
        CEU = RUNTESTS.luacov..' '..CEU
    end
    if PROPS.has_threads then
        GCC = GCC .. ' -lpthread'
    end
    if PROPS.has_lua then
        GCC = GCC .. ' -llua5.3'
    end

    local ARGS = T.args or ''
    local EXE
    if VALGRIND and T.valgrind~=false and type(T.run)=='number' then
        EXE = 'valgrind -q --leak-check=full --max-stackframe=4194320 '..OUT_DIR..'/ceu.exe '..ARGS..' 2>&1'
         --or 'valgrind -q --tool=helgrind ./ceu.exe 2>&1'
    else
        EXE = OUT_DIR..'/ceu.exe '..ARGS..' 2>&1'
    end
--DBG(CEU)
--DBG(GCC)

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
            --return
        end

        if T.asr then
            local exe = os.execute(EXE)
            assert(exe ~= 256)  -- 256 = OK
        else
            -- test output
            local ret = io.popen(EXE):read'*a'
            assert(not string.find(ret, '==%d+=='), 'valgrind error')
            local v, n_go = string.match(ret, 'END: (.-) (.-)\n')
            v, n_go = tonumber(v), tonumber(n_go)

            if type(exp)=='number' then
                assert(v==exp, ret..' vs '..exp..' expected')
                STATS.n_go = STATS.n_go + n_go
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

-- check if all translation messages were used
do
    local err = false
    for i=1, #RUNTESTS.parser_translate.original do
        if not RUNTESTS.parser_translate.ok[i] then
            DBG('parser translate '..i)
        end
    end
    assert(not err)
end

do return end

print([[

=====================================

STATS = {
    count   = ]]..STATS.count  ..[[,
    mem     = ]]..STATS.mem    ..[[,
    trails  = ]]..STATS.trails ..[[,
    bytes   = ]]..STATS.bytes  ..[[,
    n_go    = ]]..STATS.n_go   ..[[,
}
]])

--[[
# luacov

1. Set `RUNTESTS.luacov=true`
2. Run `run_tests.lua`
    - It will generate `luacov.stats.out`
3. Run `luacov` in the same directory
    - It will generate `luacov.report.out`
4. Edit `luacov.report.out` and look for lines starting with `*****0`
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


=====================================

STATS = {
    count   = 3184,
    mem     = 0,
    trails  = 6914,
    bytes   = 37129848,
    n_go    = 31093344,
}


real	17m1.637s
user	14m36.196s
sys	2m47.229s

STATS = {
    count   = 3189,
    mem     = 0,
    trails  = 6925,
    bytes   = 37355994,
    n_go    = 30908511,
}
(./run_tests.lua: 883.24s 51240k)

STATS = {
    count   = 3191,
    mem     = 0,
    trails  = 6927,
    bytes   = 37735651,
    n_go    = 31000336,
}
(./run_tests.lua: 839.18s 52080k)


]]
