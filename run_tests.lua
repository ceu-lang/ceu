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

    _OPTS = {
        tp_word    = 4,
        tp_pointer = 4,
        tp_off     = 2,
        tp_lbl     = 2,
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
    if not check('tight')    then return end
    if not check('props')    then return end
    if not check('labels')   then return end
    if not check('mem')      then return end
    if not check('code')     then return end

    if T.tot then
        assert(T.tot==_MEM.max, 'mem '.._MEM.max)
    end

    -- RUN

    if T.run == false then
        --assert(T.ana.nd_acc>0)
        return
    end

    if T.run == nil then
        assert(T.ana and T.ana.isForever or T.ana.nd_acc,
                -- or T.ana.nd_flw or T.ana.nd_esc,
                'missing run value')
        return
    end

    local CEU = './ceu _ceu_tmp.ceu --tp-word 4 --tp-pointer 4'

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
                await FOREVER;
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
