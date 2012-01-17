#!/usr/bin/env lua

_OPTS = {
    input       = nil,
    output      = '-',

    events      = false,
    events_file = '_ceu_events.h',

    m4          = false,
    m4_file     = '/tmp/tmp.ceu',

    dfa         = false,
    dfa_viz     = false,
}

_OPTS_NPARAMS = {
    input       = nil,
    output      = 1,

    events      = 0,
    events_file = 1,

    m4          = 0,
    m4_file     = 1,

    dfa         = 0,
    dfa_viz     = 1,
}

local params = {...}
local i = 1
while i <= #params
do
    local p = params[i]
    i = i + 1

    if p == '-' then
        _OPTS.input = '-'

    elseif string.sub(p, 1, 2) == '--' then
        local opt = string.gsub(string.sub(p,3), '%-', '_')
        if _OPTS_NPARAMS[opt] == 0 then
            _OPTS[opt] = true
        else
            _OPTS[opt] = params[i]
            i = i + 1
        end

    else
        _OPTS.input = p
    end
end
assert(_OPTS.input, [[


    ./ceu.lua <filename>         # CEU input file (or `-' for stdin)

        # optional parameters (default value in parenthesis)

        --output <filename>      # C output file (stdout)

        --events                 # declare events in a separate file (false)
        --events-file <filename> # events output file (`_ceu_events.h')

        --m4                     # preprocess the input with `m4' (false)
        --m4-file <filename>     # m4 output file (`/tmp/tmp.ceu')

        --dfa                    # performs DFA analysis (false)
        --dfa-viz                # generates DFA graph (false)
]])

-- INPUT
local inp
if _OPTS.input == '-' then
    inp = io.stdin
else
    inp = assert(io.open(_OPTS.input))
end
_STR = inp:read'*a'

if _OPTS.m4 then
    local m4 = assert(io.popen('m4 - > '.._OPTS.m4_file, 'w'))
    m4:write(_STR)
    m4:close()

    _STR = assert(io.open(_OPTS.m4_file)):read'*a'
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
            if var.input then
                t[#t+1] = '#define IO_'..id..' '..var.trg0
            else
                -- negative doesn't interfere with trg0
                t[#t+1] = '#define IO_'..id..' -'..(#t+1)
            end
        end

        if _OPTS.events then
            local f = io.open('_ceu_events.h','w')
            f:write(table.concat(t,'\n'))
            f:close()
            tpl = sub(tpl, '=== EVTS ===',
                           '#include "'.. _OPTS.events_file ..'"')
        else
            tpl = sub(tpl, '=== EVTS ===', table.concat(t,'\n'))
        end
    end
end

-- OUTPUT
local out
if _OPTS.output == '-' then
    out = io.stdout
else
    out = assert(io.open(_OPTS.output,'w'))
end
out:write(tpl)
