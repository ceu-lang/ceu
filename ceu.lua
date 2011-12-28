#!/usr/bin/env lua

_OPTS = {
    fnameIn    = nil,
    fnameOut   = '-',

    m4         = false,
    m4_tmpfile = nil,

    dfa        = false,
    dfa_viz    = false,
}

local params = {...}
local i = 1
while i <= #params
do
    local p = params[i]
    i = i + 1

    if p == '-' then
        _OPTS.fnameIn = '-'

    elseif p == '--output' then
        _OPTS.fnameOut = params[i]
        i = i + 1

    elseif p == '--m4-tmpfile' then
        _OPTS.m4_tmpfile = params[i]
        i = i + 1

    elseif string.sub(p, 1, 2) == '--' then
        local opt = string.gsub(string.match(p, '--(.*)'), '%-', '_')
        _OPTS[opt] = true

    else
        _OPTS.fnameIn = p
    end
end
assert(_OPTS.fnameIn, [[


    ./ceu.lua <filename>        # CEU input file (or `-' for stdin)

        # optional parameters (default value in parenthesis)

        --output <filename>     # C output file (stdout)

        --m4                    # preprocess the input with `m4' (false)
        --m4-tmpfile <filename> # m4 temporary file (/tmp/<input filename>)

        --dfa                   # performs DFA analysis (false)
        --dfa-viz               # generates DFA graph (false)
]])

-- INPUT
local inp
if _OPTS.fnameIn == '-' then
    inp = io.stdin
else
    inp = assert(io.open(_OPTS.fnameIn))
end
_STR = inp:read'*a'

if _OPTS.m4 then
    _STR = assert(io.popen('m4 -')):read'*a'

    _OPTS.m4_tmpfile = _OPTS.m4_tmpfile or '/tmp/'.._OPTS.fnameIn
    local fout = assert(io.open(_OPTS.m4_tmpfile), 'w')
    fout:write(_STR)
    fout:close()
end

-- PARSE
do
    dofile 'lines.lua'
    dofile 'parser.lua'
    dofile 'ast.lua'
    --ast.dump(ast.AST)
    dofile 'env.lua'
    dofile 'props.lua'
    dofile 'tight.lua'
    dofile 'exps.lua'
    dofile 'async.lua'
    dofile 'gates.lua'

    if _OPTS.dfa then
        dofile 'nfa.lua'
        dofile 'dfa.lua'
        DBG('nfa: '.._NFA.n_nodes..'  ||  dfa: '.._DFA.n_states)
        if _OPTS.dfa_viz then
            dofile 'graphviz'
        end
    end

    dofile 'code.lua'
end

-- TEMPLATE
local tpl
do
    tpl = assert(io.open'template.c'):read'*a'

    local sub = function (str, from, to)
        local i,e = string.find(str, from)
        return string.sub(str, 1, i-1) .. to .. string.sub(str, e+1)
    end

    tpl = sub(tpl, '=== N_TIMERS ===', _AST.n_timers)
    tpl = sub(tpl, '=== N_TRACKS ===', _AST.n_tracks)
    tpl = sub(tpl, '=== N_INTRAS ===', _AST.n_intras)
    tpl = sub(tpl, '=== N_ASYNCS ===', _AST.n_asyncs)
    tpl = sub(tpl, '=== N_GTES ===',   _GATES.n_gtes)
    tpl = sub(tpl, '=== N_ANDS ===',   _GATES.n_ands)
    tpl = sub(tpl, '=== TRGS ===',     table.concat(_GATES.trgs,','))
    tpl = sub(tpl, '=== N_VARS ===',   _ENV.n_vars)
    tpl = sub(tpl, '=== HOST ===',     _AST.host)
    tpl = sub(tpl, '=== CODE ===',     _AST.code)

    -- LABELS
    do
        local labels = ''
        for i, id in ipairs(_CODE.labels) do
            labels = labels..'    '..id..' = '..i..',\n'
        end
        tpl = sub(tpl, '=== LABELS ===', labels)
    end

    -- EVENTS
    do
        local str = ''
        local t = {}
        for id, var in pairs(_ENV.exts) do
            str = str..'#define IO_'..id..' '..#t..'\n'
            t[#t+1] = '{'..var.size..','..var.reg..','..var.trg0..'}'
        end
        tpl = sub(tpl, '=== EVTS ===', table.concat(t,','))
        local f = io.open('_ceu_events.h','w')
        f:write(str)
        f:close()
    end
end

-- OUTPUT
local out
if _OPTS.fnameOut == '-' then
    out = io.stdout
else
    out = assert(io.open(_OPTS.fnameOut,'w'))
end
out:write(tpl)
