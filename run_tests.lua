#!/usr/bin/env lua

--RUNTESTS_file = assert(io.open('/tmp/fin.txt','w'))

RUNTESTS = true

-- Execution option for the tests:
--VALGRIND = true
--LUACOV = '-lluacov'
--COMPLETE = true
OS = false   -- false, true, nil(random)

dofile 'pak.lua'

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

    OPTS = {
        tp_word = 4,
        tp_off  = 2,
        tp_lbl  = 2,
        safety  = t.safety or 1,

        cpp     = true,
        cpp_exe = 'cpp',
        cpp_args = T.cpp_args,
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
    if not check('ref')      then return end
    if not check('cval')     then return end
    if not check('isr')      then return end
    if not check('tight')    then return end
    if not check('fin')      then return end
    if not check('props')    then return end
    if not check('ana')      then return end
    dofile 'acc.lua'

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
            ..' -Wno-unused'
            ..' -Wno-unused-parameter'
            ..' -ansi'
            ..' -DCEU_DEBUG'
            --..' -DCEU_DEBUG_TRAILS'
            ..' '..(T.cpp_args or '')

    if VALGRIND then
        O = O .. ' -g'
    end

    if T.usleep then
        -- usleep is deprecated and gcc always complains
        O = O .. ' -Wno-implicit-function-declaration'
    end

    local CEU, GCC
    local cpp = (T.cpp_args and '--cpp-args "'..T.cpp_args..'"') or ''
    local tm  = (T.timemachine and '--timemachine') or ''
    local r = (math.random(2) == 1)
    if OS==true or (OS==nil and r) then
        CEU = 'lua '..(LUACOV or '')..' ceu _ceu_tmp.ceu '..cpp..' --run-tests --os '..tm..' 2>&1'
        GCC = 'gcc '..O..' -include _ceu_app.h -o ceu.exe main.c ceu_os.c _ceu_app.c 2>&1'
    else
        CEU = 'lua '..(LUACOV or '')..' ceu _ceu_tmp.ceu '..cpp..' --run-tests '..tm..' 2>&1'
        GCC = 'gcc '..O..' -o ceu.exe main.c 2>&1'
    end
    --local line = debug.getinfo(2).currentline
    --os.execute('echo "/*'..line..'*/" > /tmp/line')
    --os.execute('cat /tmp/line _ceu_app.c > /tmp/file')
    --os.execute('mv /tmp/file _ceu_app.c')
--DBG(CEU)
--DBG(GCC)

    if PROPS.has_threads then
        GCC = GCC .. ' -lpthread'
    end
    if PROPS.has_lua then
        GCC = GCC .. ' -llua5.1'
    end

    local EXE = (((not VALGRIND) or T.valgrind==false) and './ceu.exe 2>&1')
             or 'valgrind -q --leak-check=full ./ceu.exe 2>&1'
             --or 'valgrind -q --tool=helgrind ./ceu.exe 2>&1'

    local go = function (src, exp)
        local ceu = assert(io.open('_ceu_tmp.ceu', 'w'))
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
        local f = io.popen('du -b ceu.exe')
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
-- COMPLETE=false, VALGRIND=false
STATS = {
    count   = 2694,
    mem     = 0,
    trails  = 6522,
    bytes   = 40228346,
}
real	18m43.844s
user	18m3.222s
sys	2m24.000s





-- FULL
STATS = {
    count   = 2543,
    mem     = 0,
    trails  = 6446,
    bytes   = 53986810,
}


real	15m5.267s
user	15m22.006s
sys	2m10.014s


-- no TM

STATS = {
    count   = 2392,
    mem     = 0,
    trails  = 5350,
    bytes   = 29771950,
}


real	12m35.119s
user	12m57.313s
sys	2m8.698s

]]
