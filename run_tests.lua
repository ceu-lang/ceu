#!/usr/bin/env lua

dofile 'pak.lua'

COUNT = 0
T = nil

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
    local str_input = T[1]
    print('\n=============\n---\n'..str_input..'\n---\n')
    COUNT = COUNT + 1

    --assert(T.todo == nil)
    if T.todo then
        return
    end

    local ok = not (T.parser or T.env or T.mem or
                    T.props or T.tight)
    if ok then
        local CEU = './ceu - --simul-run '
                        .. '--tp-word 4 --tp-pointer 4 --tp-lbl 2 --tp-off 2'
        local ceu = assert(io.popen(CEU, 'w'))
        ceu:write(str_input)
        ceu:close()
        assert(os.execute('gcc -std=c99 -o ceu.exe simul.c') == 0)
        assert(os.execute('./ceu.exe _ceu_simul.lua') == 0)
    end

    _OPTS = {
        tp_word    = 4,
        tp_pointer = 4,
        tp_off     = 2,
        tp_lbl     = 2,
        simul_use  = true,
        simul_file = '_ceu_simul.lua',
    }

    -- LINES
    _STR = str_input
    --print(_STR)
    dofile 'tp.lua'
    dofile 'lines.lua'

    -- PARSER
    if not check('parser')   then return end
    if not check('ast')      then return end
    --_AST.dump(_AST.root)
    if not check('env')      then return end
    if not check('props')    then return end
    if not check('mem')      then return end
    if not check('tight')    then return end
    if not check('labels')   then return end
    if not check('analysis') then return end
    if not check('code')     then return end

    if T.tot then
        assert(T.tot==_MEM.max, 'mem '.._MEM.max)
    end

    -- SIMUL
    --if T.dfa then return end
    assert((not T.n_unreachs) and not (T.isForever)) -- move to simul
    do
        local _defs = { n_reachs=0, n_unreachs=0, isForever=false, nd_acc=0 }
        local _no = { needsPrio=true, needsChk=true, n_states=true, n_tracks=true }
        for k, v in pairs(_ANALYSIS) do
            assert( (v==_defs[k] or _no[k]) and (T.simul==nil or T.simul[k]==nil)
                    or (T.simul and T.simul[k]==v)
                    or (T.simul and T.simul.nd_acc==_ANALYSIS.nd_acc),
                            k..' = '..tostring(v))
        end
        if T.simul then
            for k, v in pairs(T.simul) do
                assert( v == _ANALYSIS[k],
                            k..' = '..tostring(_ANALYSIS[k]))
            end
        end
--[[
        assert(_DFA.nds.call.tot == (T.nd_call or 0),
            'nd_call '.._DFA.nds.call.tot)

        assert(_DFA.escs.tot == (T.nd_esc or 0),
            'nd_esc '.._DFA.escs.tot)

        if not _DFA.nd_stop then
            assert(_DFA.n_unreach == (T.unreach or 0),
                'unreach '.._DFA.n_unreach)
        end
]]
    end
--[=[
]=]

    -- RUN

    if T.run == false then
        --assert(T.simul.nd_acc>0)
        return
    end

    if T.run == nil then
        assert(T.simul and T.simul.isForever or T.simul.nd_acc,
                -- or T.simul.nd_flw or T.simul.nd_esc,
                'missing run value')
        return
    end

    local CEU = './ceu _ceu_tmp.ceu --simul '
                    .. '--tp-word 4 --tp-pointer 4 --tp-lbl 2 --tp-off 2'

    -- T.run = N
    if type(T.run) ~= 'table' then
        local str_all = str_input
        print(str_all)
        local ceu = assert(io.open('_ceu_tmp.ceu', 'w'))
        ceu:write(str_all)
        ceu:close()
        assert(os.execute(CEU))
        assert(os.execute('gcc -std=c99 -o ceu.exe main.c') == 0)
        local ret = io.popen('./ceu.exe'):read'*a'
        ret = string.match(ret, 'END: (.-)\n')
        assert(ret==T.run..'', ret..' vs '..T.run..' expected')

    else
        local str_all = [[
            par/or do
                ]]..str_input..[[
            with
                async do
                    `EVTS
                end
                await Forever;
            end
        ]]
        for input, ret2 in pairs(T.run) do
            input = string.gsub(input, '([^;]*)~>(%d[^;]*);?', 'emit %2;')
            input = string.gsub(input, '[ ]*(%d+)[ ]*~>([^;]*);?', 'emit %2(%1);')
            input = string.gsub(input, '~>([^;]*);?', 'emit %1;')
            local all = string.gsub(str_all, '`EVTS', input)
            local ceu = assert(io.open('_ceu_tmp.ceu', 'w'))
            ceu:write(all)
            ceu:close()
            assert(os.execute(CEU))
            assert(os.execute('gcc -std=c99 -o ceu.exe main.c') == 0)
            local ret = io.popen('./ceu.exe'):read'*a'
            ret = string.match(ret, 'END: (%-?%d+)')
            assert(tonumber(ret)==ret2, ret..' vs '..ret2..' expected')
        end
    end
end

dofile 'tests.lua'
print('Number of tests: '..COUNT)
