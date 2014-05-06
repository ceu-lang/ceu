#!/usr/bin/env lua

_RUNTESTS = true

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

    _OPTS = {
        tp_word    = 4,
        tp_off     = 2,
        tp_lbl     = 2,
        warn_nondeterminism = true,

        cpp     = true,
        cpp_exe = 'cpp',
        input   = 'tests.lua',
        source  = source,
    }

    --assert(T.todo == nil)
    if T.todo then
        return
    end

    STATS.count = STATS.count   + 1

    dofile 'tp.lua'

    if not check('lines')    then return end
    local _WRN = WRN
    if (not t.wrn) and (not t._ana) then
        WRN = ASR
    end

    if not check('parser')   then return end
    if not check('ast')      then return end
    --DBG'======= AST'
    --_AST.dump(_AST.root)
    if not check('adj')      then return end
    --DBG'======= ADJ'
    --_AST.dump(_AST.root)
    if not check('tops')     then return end
    --DBG'======= TOPS'
    --_AST.dump(_AST.root)
    if not check('env')      then return end
    if not check('sval')     then return end
    if not check('isr')      then return end
    if not check('tight')    then return end
    if not check('fin')      then return end
    --dofile 'awaits.lua'
    if not check('props')    then return end
    if not check('ana')      then return end
    dofile 'acc.lua'

    if not check('trails')   then return end
    if not check('labels')   then return end
    if not check('tmps')     then return end
    if not check('mem')      then return end
    if not check('val')      then return end
    --DBG'======= VAL'
    --_AST.dump(_AST.root)
    if not check('code')     then return end

    if (not t.wrn) and (not t._ana) then
        WRN = _WRN
    end

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

    assert(t._ana or (_TIGHT and T.loop) or
                     (not (_TIGHT or T.loop)))

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
            assert( v==_defs[k] and (T._ana==nil or T._ana[k]==nil)
                    or (T._ana and T._ana[k]==v),
                    --or (T._ana and T._ana.acc==_ANALYSIS.acc),
                            k..' = '..tostring(v))
end
end
end
        end
        if T._ana then
            for k, v in pairs(T._ana) do
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

    if not (T.run or T.gcc) then
        assert(T.loop or T._ana, 'missing run value')
        return
    end

    -- TODO: pedantic
    local O = ' -Wall -Wextra -Wformat=2 -Wstrict-overflow=3 -Werror '
            ..' -Wno-missing-field-initializers'
            ..' -Wno-unused'
            ..' -ansi'
            ..' -D CEU_DEBUG'
            --..' -g'

    if T.usleep then
        -- usleep is deprecated and gcc always complains
        O = O .. ' -Wno-implicit-function-declaration'
    end

    local CEU, GCC
    local r = (math.random(2) == 1)
    if _OS==true or (_OS==nil and r) then
        CEU = './ceu _ceu_tmp.ceu --run-tests --os 2>&1'
        GCC = 'gcc '..O..' -include _ceu_app.h -o ceu.exe main.c ceu_os.c _ceu_app.c 2>&1'
    else
        CEU = './ceu _ceu_tmp.ceu --run-tests 2>&1'
        GCC = 'gcc '..O..' -o ceu.exe main.c 2>&1'
    end
--DBG(GCC)

    if _PROPS.has_threads then
        GCC = GCC .. ' -lpthread'
    end

    local EXE = ((not _VALGRIND) and './ceu.exe 2>&1')
             or 'valgrind -q --leak-check=full ./ceu.exe 2>&1'
             --or 'valgrind -q --tool=helgrind ./ceu.exe 2>&1'

    local go = function (src, exp)
        local ceu = assert(io.open('_ceu_tmp.ceu', 'w'))
        ceu:write(src)
        ceu:close()
        local exec_ceu = os.execute(CEU)
        assert(exec_ceu == 0 or exec_ceu == true)

        if T.gcc then
            local ret = assert(io.popen(GCC)):read'*a'
            assert( string.find(ret, T.gcc, nil, true), ret )
            return
        else
            local exec_gcc = os.execute(GCC)
            assert(exec_gcc == 0 or exec_gcc == true)
        end

        local ret = io.popen(EXE):read'*a'
        assert(not string.find(ret, '==%d+=='), 'valgrind error')
        local v = tonumber( string.match(ret, 'END: (.-)\n') )

        if v then
            assert(v==exp, ret..' vs '..exp..' expected')
        else
            assert( string.find(ret, exp, nil, true), ret )
        end
    end

    -- T.run = N
    if type(T.run) ~= 'table' then
        print(source)
        go(source, T.run)
    else
        local par = (T.awaits and T.awaits>0 and 'par') or 'par/or'
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

-- w/ threads
--[[
STATS = {
    count   = 1770,
    mem     = 0,
    trails  = 3428,
    bytes   = 15920233,
}


real	10m16.197s
user	10m18.920s
sys	1m8.268s

STATS = {
    count   = 1763,
    mem     = 0,
    trails  = 3414,
    bytes   = 15826585,
}


real	7m38.080s
user	7m30.016s
sys	0m56.800s
}
]]

os.execute('rm -f /tmp/_ceu_*')
