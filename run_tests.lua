#!/usr/bin/env lua

dofile 'pak.lua'
dofile 'set.lua'
dofile 'C.lua'

COUNT = 0
T = nil

function check (mod)
    assert(T[mod]==nil or T[mod]==false or type(T[mod])=='string')
    local ok, msg = pcall(dofile, mod..'.lua')
    if T[mod]~=nil then
        assert(ok==false and
                (T[mod]==false or
                 string.find(msg,T[mod])),tostring(msg))
        return false
    else
        assert(ok==true, msg)
        return true
    end
end

Test = function (t)
    T = t
    local str_input = T[1]
    print('---', str_input)
    COUNT = COUNT + 1

    if T.todo then
        return
    end

    -- LINES
    _STR = PRE .. str_input
    --print(_STR)
    dofile 'lines.lua'

    -- PARSER
    if not check('parser') then return end
    if not check('ast')    then return end
    --_DUMP(_AST)
    if not check('env')    then return end
    if not check('props')  then return end
    if not check('tight')  then return end
    if not check('exps')   then return end
    if not check('async')  then return end
    if not check('gates')  then return end

    -- GRAPH

    -- nfa
    if not check('nfa') then return end
    DBG('nfa', _NFA.n_nodes)

    -- dfa
    do
        if not check('dfa') then return end

        dofile 'graphviz.lua' ; DBG('>>> VIZ')
        DBG('dfa', _DFA.n_states)

        assert(#_DFA.nd_acc == (T.nd_acc or 0),
            'nd_acc '..#_DFA.nd_acc)

        assert(#_DFA.nd_esc == (T.nd_esc or 0),
            'nd_esc '..#_DFA.nd_esc)

        if not _DFA.nd_stop then
            assert(_DFA.n_unreach == (T.unreach or 0),
                'unreach '.._DFA.n_unreach)
        end

        assert(_DFA.forever==true and T.forever or T.forever==nil,
            'forever '..tostring(_DFA.forever))
    end

    -- RUN
    if T.run==nil then return end
--print'=============='

    if not check('code') then return end

    if T.run == false then
        local str_all = PRE..str_input
        --print(str_all)
        local ceu = assert(io.popen('./ceu - --output _ceu_code.c', 'w'))
        ceu:write(str_all)
        ceu:close()
        assert(os.execute('gcc -std=c99 -o ceu.exe main.c 2>/dev/null') ~= 0)

    -- T.run = N
    elseif type(T.run) ~= 'table' then
        local str_all = PRE..str_input
        --print(str_all)
        local ceu = assert(io.popen('./ceu - --output _ceu_code.c', 'w'))
        ceu:write(str_all)
        ceu:close()
        assert(os.execute('gcc -std=c99 -o ceu.exe main.c') == 0)
        --print(os.execute("/tmp/ceu.exe")/256, T.run, str_input)
        --assert(os.execute("/tmp/ceu.exe")/256 == T.run, str_input)
        local ret = io.popen('./ceu.exe'):read'*a'
        ret = string.match(ret, 'END: (.-)\n')
        assert(ret==T.run..'', ret..' vs '..T.run..' expected')

    else
        local str_all = PRE .. [[
            par/or do
                ]]..str_input..[[

            with
                async do
                    `EVTS
                end;
                await forever;
            end;
        ]]
        for input, ret2 in pairs(T.run) do
            input = string.gsub(input, '([^;]*)~>(%d[^;]*);?', 'emit %2;')
            input = string.gsub(input, '([^;]*)~>([^;]*);?', 'emit %2(%1);')
            local all = string.gsub(str_all, '`EVTS', input)
            local ceu = assert(io.popen('./ceu - --output _ceu_code.c', 'w'))
            --print(all)
            ceu:write(all)
            ceu:close()
            assert(os.execute('gcc -std=c99 -o ceu.exe main.c') == 0)
            local ret = io.popen('./ceu.exe'):read'*a'
            ret = string.match(ret, 'END: (%-?%d+)')
            assert(tonumber(ret)==ret2, ret..' vs '..ret2..' expected')
        end
    end
end

dofile 'tests.lua'
print('Number of tests: '..COUNT)
