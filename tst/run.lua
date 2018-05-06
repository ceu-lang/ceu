#!/usr/bin/env lua5.3

TESTS = {
    --cmd = true,
    --luacov = 'lua5.3 -lluacov'
    --valgrind = true,
--REENTRANT = true
--COMPLETE = true
    stats = {
        count  = 0,
        trails = 0,
        bytes  = 0,
        bcasts = 0,
        visits = 0,
    }
}

if TESTS.luacov then
    require 'luacov'
    os.remove('luacov.stats.out')
    os.remove('luacov.report.out')
end

if TESTS.cmd then
    print '>>> CMDS'
    os.execute('cd ../src/lua/ && lua5.3 pak.lua lua5.3 && cp ceu /usr/local/bin/')

    local tmp1 = os.tmpname()
    local f = assert(io.open(tmp1,'w'))
    f:write('escape 10;')
    f:close()

    --$ ceu
    -->>> ERROR : expected some option

    local f = assert(io.popen('ceu 2>&1'))
    local out = f:read'*a'
    local ok,mode,status = f:close()
    assert(ok==nil and mode=='exit' and status==1 and
           string.find(out, '^ceu 0%.20.*Usage:.*Options:.*>>> ERROR : expected some option'))

    --$ ceu --pre
    -->>> ERROR : expected option `pre-input`

    local f = assert(io.popen('ceu --pre 2>&1'))
    local out = f:read'*a'
    local ok,mode,status = f:close()
    assert(ok==nil and mode=='exit' and status==1 and
           string.find(out, '^>>> ERROR : expected option `pre%-input`'))

    --$ ceu --pre --pre-input=/tmp/xxx.ceu
    -- OK

    local tmp = os.tmpname()
    local f = assert(io.open(tmp,'w'))
    f:write('escape 10;')
    f:close()

    local f = assert(io.popen('ceu --pre --pre-input='..tmp))
    local out = f:read'*a'
    local ok,mode,status = f:close()
    assert(ok==true and mode=='exit' and status==0 and
           string.find(out, '^# 1 "'..tmp..'".*escape 10;'))

    --$ ceu --pre --pre-input=/tmp/xxx.ceu --pre-output=/tmp/yyy.ceu
    --      --ceu --ceu-input=x
    -->>> ERROR : don't match

    local tmp2 = os.tmpname()
    local f = assert(io.popen('ceu --pre --pre-input='..tmp1..' '..
                                        '--pre-output='..tmp2..' '..
                                  '--ceu --ceu-input=x 2>&1'))
    local out = f:read'*a'
    local ok,mode,status = f:close()
    assert(ok==nil and mode=='exit' and status==1 and
           string.find(out, "^>>> ERROR : `pre%-output` and `ceu%-input` don't match"))

    --$ ceu --pre --pre-input=/tmp/xxx.ceu --ceu
    -- OK

    local f = assert(io.popen('ceu --pre --pre-input='..tmp1..' '..
                                  '--ceu'))
    local out = f:read'*a'
    local ok,mode,status = f:close()
    assert(ok==true and mode=='exit' and status==0 and
           string.find(out, 'CEU_C.*ceu_vector.*tceu_app CEU_APP.*ceu_bcast.*ceu_loop'))

    --$ ceu --pre --pre-input=/tmp/xxx.ceu --env
    -->>> ERROR

    local f = assert(io.popen('ceu --pre --pre-input=x --env 2>&1'))
    local out = f:read'*a'
    local ok,mode,status = f:close()
    assert(ok==nil and mode=='exit' and status==1 and
           string.find(out, '>>> ERROR : expected option `ceu`'))

    --$ ceu --pre --pre-input=/tmp/xxx.ceu --ceu --env
    -- OK

    local f = assert(io.popen('ceu --pre --pre-input='..tmp1..' '..
                                  '--ceu '..
                                  '--env --env-types=../env/types.h '..
                                        '--env-threads=../env/threads.h '..
                                        '--env-main=../env/main.c'))
    local out = f:read'*a'
    local ok,mode,status = f:close()
    assert(ok==true and mode=='exit' and status==0 and
           string.find(out, 'This file is.*typedef uint32_t u32.*CEU_C.*ceu_vector.*tceu_app CEU_APP.*ceu_bcast.*ceu_loop.*int main'))

    --$ ceu --pre --pre-input=/tmp/xxx.ceu --ceu --env --cc --cc-output=/tmp/xxx.exe
    -- OK

    local tmp2 = os.tmpname()
    local f = assert(io.popen('ceu --pre --pre-input='..tmp1..' '..
                                  '--ceu '..
                                  '--env --env-types=../env/types.h '..
                                        '--env-threads=../env/threads.h '..
                                        '--env-main=../env/main.c '..
                                  '--cc --cc-args="-llua5.3 -lpthread" --cc-output='..tmp2))
    local out = f:read'*a'
    local ok,mode,status = f:close()
    assert(ok==true and mode=='exit' and status==0)

    local ok, mode, status = os.execute(tmp2)
    assert(ok==nil and mode=='exit' and status==10)
end

function check (T, mod)
    assert(T[mod]==nil or T[mod]==false or type(T[mod])=='string')
    local ok, msg = pcall(dofile, '../src/lua/'..mod..'.lua')
if not ok and string.find(msg, 'TODO%-PARSER') then
    return false
end
    if T[mod]~=nil then
        assert(ok==false, 'no error found')
        assert(string.find(msg, T[mod], nil, true), tostring(msg))
    else
        assert(ok==true, '['..mod..'] '..(msg or ''))
        return true
    end
end

Test = function (T)
    -- TODO: remove OS_START
    if string.find(T[1],'OS_START') and (not T.os_start) then
        if type(T.run) ~= 'table' then
            T.run = { [''] = T.run }
        end
        local t = {}
        for input, ret in pairs(T.run) do
            t['~>OS_START;'..input] = ret
        end
        T.run = t
        T.os_start = true
        return Test(T)
    end

    if type(T.run) == 'table' then
        local src = [[
par do
#line 1 "/tmp/tmp.ceu"
    ]]..T[1]..[[
with
    await async do
        `EVTS
    end
    await FOREVER;
end
]]
        for input, ret in pairs(T.run) do
            input = string.gsub(input, '([^;]*)~>(%d[^;]*);?', 'emit %2;')
            input = string.gsub(input, '[ ]*true[ ]*~>([^;]*);?', 'emit %1(true);')
            input = string.gsub(input, '[ ]*false[ ]*~>([^;]*);?', 'emit %1(false);')
            input = string.gsub(input, '[ ]*(%d+)[ ]*~>([^;]*);?', 'emit %2(%1);')
            input = string.gsub(input, '~>([^;]*);?', 'emit %1;')
            T[1] = string.gsub(src, '`EVTS', input)
            T.run = ret
            Test(T)
        end
        return
    end

    --assert(T.todo == nil)
    if T.todo then
        return
    end
    if T.complete and (not COMPLETE) then
        return  -- only run "t.complete=true" with the "COMPLETE=true" flag
    end

    if not T.complete then
        -- do not print large files
        --local source = 'C _fprintf(), _stderr;'..T[1]
        print('\n=============\n---\n'..T[1]..'\n---\n')
    end

    local f = assert(io.open('/tmp/tmp.ceu', 'w'))
    f:write(T[1])
    f:close()

    local defines = ''
    for k,v in pairs(T.defines or {}) do
        defines = defines..' -D'..k..'='..v
    end
    defines = defines..' -DCEU_TESTS'

    PAK = {
        lua_exe = '?',
        ceu_ver = '?',
        ceu_git = '?',
        files = {
            ceu_c = assert(io.open'../src/c/ceu_callback.c'):read'*a'..
                    assert(io.open'../src/c/ceu_vector.c'):read'*a'..
                    assert(io.open'../src/c/ceu_pool.c'):read'*a'..
                    assert(io.open'../src/c/ceu.c'):read'*a',
        }
    }
    CEU = {
        arg  = {},
        opts = T.opts or {
            ceu          = true,
            ceu_input    = '/tmp/tmp.ceu',
            ceu_output   = '/tmp/tmp.ceu.c',

            env          = true,
            env_types    = '../env/types.h',
            env_threads  = '../env/threads.h',
            env_ceu      = '/tmp/tmp.ceu.c',
            env_main     = '../env/main.c',
            env_output   = '/tmp/tmp.c',

            cc           = true,
            cc_input     = '/tmp/tmp.c',
            cc_output    = '/tmp/tmp.exe',
            cc_args      = '-Wall -Wextra -Werror'
                            -- TODO: remove all "-Wno-*"
                            ..' -Wno-unused'
                            ..' -Wno-missing-field-initializers'
                            ..' -Wno-implicit-fallthrough'
                            ..' -llua5.3 -lpthread '..defines
                         ,

            --ceu_features_lua    = 'true',
            --ceu_features_thread = 'true',
            --ceu_line_directives = 'true',
            --ceu_line_directives = 'false',
            --ceu_err_unused_native = 'pass'
        }
    }
    if T.opts_pre then
        CEU.opts.pre          = true
        CEU.opts.pre_args     = '-I ../include'
        CEU.opts.pre_input    = '/tmp/tmp.ceu'
        CEU.opts.pre_output   = '/tmp/tmp.ceu.cpp'
        CEU.opts.ceu_input    = '/tmp/tmp.ceu.cpp'
    end
    if T._opts then
        for k,v in pairs(T._opts) do
            CEU.opts[k] = v
        end
    end

    TESTS.stats.count = TESTS.stats.count + 1

    local DIR = '../src/lua/'

    dofile(DIR..'dbg.lua')
    DBG,ASR = DBG1,ASR1
    if not check(T,'cmd') then return end

    if CEU.opts.pre then
        if not check(T,'pre') then return end
    end
    if not CEU.opts.ceu then return end
    DBG,ASR = DBG2,ASR2

    dofile(DIR..'lines.lua')
    local _WRN = WRN
    if (not T.wrn) then
        WRN = ASR
    end

    if not check(T,'parser') then return end
    --dofile 'ast.lua'
    if not check(T,'ast')    then return end
    if not check(T,'adjs')   then return end
    dofile(DIR..'types.lua')
    dofile(DIR..'exps.lua')
    if not check(T,'dcls')   then return end
    if not check(T,'inlines')then return end
    --if not check(T,'exps')   then return end
    if not check(T,'consts') then return end
    if not check(T,'fins')   then return end
    if not check(T,'spawns') then return end
    if not check(T,'stmts')  then return end
    if not check(T,'tight_') then return end
    if not check(T,'inits')  then return end
    if not check(T,'ptrs')   then return end
    if not check(T,'scopes') then return end
    if not check(T,'props_') then return end
    if not check(T,'trails') then return end

    TESTS.stats.trails = TESTS.stats.trails + AST.root.trails_n

    if not check(T,'labels') then return end
    dofile(DIR..'vals.lua')
    dofile(DIR..'multis.lua')
    if not check(T,'mems')   then return end
    if not check(T,'codes')  then return end
--AST.dump(AST.root)
--do return end

if T.ana or T.tmp or T.props or T.mode then return end

    DBG,ASR = DBG1,ASR1
    if CEU.opts.env then
        dofile(DIR..'env.lua')
    end

    if T.cc == false then
        -- succeed w/o compiling
        return
    end

    if CEU.opts.cc then
        if not check(T,'cc') then return end

        local f = io.popen('du -b '..CEU.opts.cc_output)
        local n = string.match(f:read'*a', '(%d+)')
        TESTS.stats.bytes = TESTS.stats.bytes + tonumber(n)
        f:close()
    end

    if T.run == false then
        -- succeed w/o executing
        return
    end

    -- EXECUTE

    local exe = CEU.opts.cc_output..' 2>&1'

    if TESTS.valgrind and (T.valgrind ~= false) then
        exe = 'valgrind -q --leak-check=full --show-leak-kinds=all '..exe
    end

    local f = io.popen(exe)
    local out = f:read'*a'
    local _1,_,ret = f:close()

    if type(T.run) == 'number' then
        assert(ret == T.run%256, '>>> ERROR : run : expected '..T.run..' : got '..ret)

        local n1 = string.match(out, '_ceu_tests_bcasts_ = (%d+)\n')
        TESTS.stats.bcasts = TESTS.stats.bcasts + tonumber(n1)

        local n2 = string.match(out, '_ceu_tests_trails_visited_ = (%d+)\n')
        TESTS.stats.visits = TESTS.stats.visits + tonumber(n2)

        assert(out == '_ceu_tests_bcasts_ = '..n1..'\n'..
                      '_ceu_tests_trails_visited_ = '..n2..'\n',
            'code with output')
    else
        assert(type(T.run) == 'string', 'missing run value')
        assert(string.find(out, T.run, nil, true), '>>> ERROR : run : expected "'..T.run..'" : got "'..out..'"')
    end

-------------------------------------------------------------------------------

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

    if (not T.wrn) and (not T._ana) then
        WRN = _WRN
    end

    if T.tot then
        assert(T.tot==MEM.max, 'mem '..MEM.max)
    end

    assert(T._ana or (TIGHT and T.loop) or
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
                await async do
                    `EVTS
                end
                await FOREVER;
            end
        ]]
        for input, ret2 in pairs(T.run) do
            input = string.gsub(input, '([^;]*)~>(%d[^;]*);?', 'emit %2;')
            input = string.gsub(input, '[ ]*(%d+)[ ]*~>([^;]*);?', 'emit %2(%1);')
            input = string.gsub(input, '~>([^;]*);?', 'emit %1;')
            local source = string.gsub(source, '`EVTS', input)
            go(source, ret2)
        end
    end
end

dofile 'tests.lua'

-- check if all translation messages were used
do
    local err = false
    for i=1, #TESTS.parser_translate.original do
        if not TESTS.parser_translate.ok[i] then
            DBG('parser translate '..i)
        end
    end
    assert(not err)
end

print([[

=====================================

stats = {
    count  = ]]..TESTS.stats.count  ..[[,
    trails = ]]..TESTS.stats.trails ..[[,
    bytes  = ]]..TESTS.stats.bytes  ..[[,
    bcasts = ]]..TESTS.stats.bcasts ..[[,
    visits = ]]..TESTS.stats.visits ..[[,
}
]])

--[[
# luacov

1. Set `TESTS.luacov=true`
2. Run `run.lua`
    - It will generate `luacov.stats.out`
3. Run `luacov` in the same directory
    - It will generate `luacov.report.out`
4. Edit `luacov.report.out` and look for lines starting with `*****0`

# time

/usr/bin/time --format='(%C: %Us %Mk)' ./run.lua

# results

stats = {
    count  = 3195,
    trails = 5922,
    bytes  = 58066656,
    bcasts = 866575,
    visits = 2177461,
}
(./run.lua: 669.16s 40636k)

stats = {
    count  = 2856,
    trails = 5388,
    bytes  = 44183320,
    visits = 218821,
}
(./run.lua: 559.13s 30936k)
(./run.lua: 2254.76s 46932k)

stats = {
    count  = 2890,
    trails = 5418,
    bytes  = 44813000,
    visits = 218964,
}
(./run.lua: 602.31s 31884k)
(./run.lua: 2613.24s 46748k)

-- extra clean-up seq
stats = {
    count  = 2968,
    trails = 4987,
    bytes  = 46285792,
    visits = 374850,
}
(./run.lua: 619.16s 31156k)

stats = {
    count  = 2988,
    trails = 5092,
    bytes  = 46694368,
    visits = 391193,
}
(./run.lua: 642.92s 36688k)
(./run.lua: 2650.90s 46748k)

stats = {
    count  = 3042,
    trails = 5196,
    bytes  = 47429136,
    visits = 392062,
}
(./run.lua: 662.47s 37884k)
(./run.lua: 2509.72s 46824k)

stats = {
    count  = 3042,
    trails = 5196,
    bytes  = 47445520,
    visits = 395634,
}
(./run.lua: 653.53s 37648k)
(./run.lua: 2506.29s 46936k)

stats = {
    count  = 3106,
    trails = 5684,
    bytes  = 53819176,
    bcasts = 862322,
    visits = 2161183,
}
(./run.lua: 648.72s 42460k)

stats = {
    count  = 3462,
    trails = 6267,
    bytes  = 56626936,
    bcasts = 2263016,
    visits = 5881354,
}

(./run.lua: 784.45s 51300k)

-- 2-pass scheduler is back

stats = {
    count  = 3470,
    trails = 8202,
    bytes  = 50943840,
    bcasts = 0,
    visits = 3628872,
}

(./run.lua: 693.78s 46080k)
(./run.lua: 3164.34s 315148k)

-------------------------------------------------------------------------------

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
