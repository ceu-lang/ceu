_CEU = true

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
    dfa_viz     = 0,
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
if not _OPTS.input then
    io.stderr:write([[

    ./ceu <filename>             # CEU input file (or `-' for stdin)

        # optional parameters (default value in parenthesis)

        --output <filename>      # C output file (stdout)

        --events                 # declare events in a separate file (false)
        --events-file <filename> # events output file (`_ceu_events.h')

        --dfa                    # performs DFA analysis (false)
        --dfa-viz                # generates DFA graph (false)

]])
    os.exit(1)
end
        -- TODO: m4
        --m4                     # preprocess the input with `m4' (false)
        --m4-file <filename>     # m4 output file (`/tmp/tmp.ceu')


-- INPUT
local inp
if _OPTS.input == '-' then
    inp = io.stdin
else
    inp = assert(io.open(_OPTS.input))
end
_STR = inp:read'*a'

if _OPTS.m4 or _OPTS.m4_file then
    local m4 = assert(io.popen('m4 - > '.._OPTS.m4_file, 'w'))
    m4:write(_STR)
    m4:close()

    _STR = assert(io.open(_OPTS.m4_file)):read'*a'
end

-- PARSE
do
    dofile 'set.lua'

    dofile 'lines.lua'
    dofile 'parser.lua'
    dofile 'ast.lua'
    --ast.dump(ast.AST)
    dofile 'C.lua'
    dofile 'env.lua'
    dofile 'props.lua'
    dofile 'tight.lua'
    dofile 'exps.lua'
    dofile 'async.lua'
    dofile 'gates.lua'

    if _OPTS.dfa then
        DBG('WRN : the DFA algorithm is exponential, this may take a while!')
        dofile 'nfa.lua'
        dofile 'dfa.lua'
        DBG('# States  ||  nfa: '.._NFA.n_nodes..'  ||  dfa: '.._DFA.n_states)
        if _OPTS.dfa_viz then
            dofile 'graphviz.lua'
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
    tpl = sub(tpl, '=== N_ASYNCS ===', _AST.n_asyncs)
    tpl = sub(tpl, '=== N_EMITS ===',  _AST.n_emits)
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
            -- i+1: (Inactive=0,Init=1,...)
            labels = labels..'    '..id..' = '..(i+1)..',\n'
        end
        tpl = sub(tpl, '=== LABELS ===', labels)
    end

    -- EVENTS and FUNCTIONS used
    do
        local str = ''
        local t = {}
        local outs = 0
        for id, evt in pairs(_ENV.exts) do
            if evt.input then
                str = str..'#define IN_'..id..' '..(evt.trg0 or 0)..'\n'
            else
                str = str..'#define OUT_'..id..' '..outs..'\n'
                outs = outs + 1
            end
        end
        str = str..'#define OUT_n '..outs..'\n'

        -- FUNCTIONS called
        local funcs = 0
        for id in pairs(_EXPS.calls) do
            if id ~= '$anon' then
                str = str..'#define FUNC'..id..' '..funcs..'\n'
                funcs = funcs + 1
            end
        end

        if _OPTS.events or _OPTS.events_file then
            local f = io.open('_ceu_events.h','w')
            f:write(str)
            f:close()
            tpl = sub(tpl, '=== EVTS ===',
                           '#include "'.. _OPTS.events_file ..'"')
        else
            tpl = sub(tpl, '=== EVTS ===', str)
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
