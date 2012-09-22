_CEU = true

_OPTS = {
    input     = nil,
    output    = '_ceu_code.cceu',

    defs_file  = '_ceu_defs.h',

    analysis      = false,
    analysis_run  = false,
    analysis_use  = false,
    analysis_file = '_ceu_analysis.lua',

    join      = true,
    c_calls   = false,

    m4        = false,
    m4_args   = false,

    tp_word    = 4,
    tp_pointer = 4,
    tp_off     = 2,
    tp_lbl     = 2,
}

_OPTS_NPARAMS = {
    input     = nil,
    output    = 1,

    defs_file  = 1,

    analysis      = 0,
    analysis_run  = 0,
    analysis_use  = 0,
    analysis_file = 1,

    join      = 0,
    c_calls   = 1,

    m4        = 0,
    m4_args   = 1,

    tp_word    = 1,
    tp_pointer = 1,
    tp_off     = 1,
    tp_lbl     = 1,
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
        local no = false
        local opt = string.gsub(string.sub(p,3), '%-', '_')
        if string.find(opt, '^no_') then
            no = true
            opt = string.sub(opt, 4)
        end
        if _OPTS_NPARAMS[opt] == 0 then
            _OPTS[opt] = not no
        else
            local opt = string.gsub(string.sub(p,3), '%-', '_')
            _OPTS[opt] = string.match(params[i], "%'?(.*)%'?")
            i = i + 1
        end

    else
        _OPTS.input = p
    end
end
if not _OPTS.input then
    io.stderr:write([[

    ./ceu <filename>           # Ceu input file, or `-´ for stdin
    
        --output <filename>    # C output file (stdout)
    
        --defs-file <filename> # define constants in a separate output file (no)

        --analysis                 # TODO
        --analysis-run             # TODO
        --analysis-use             # TODO
        --analysis-file <filename> # TODO

        --join (--no-join)     # join lines enclosed by /*{-{*/ and /*}-}*/ (join)
        --c-calls              # TODO

        --m4 (--no-m4)         # preprocess the input with `m4´ (no-m4)
        --m4-args              # preprocess the input with `m4´ passing arguments in between `"´ (no)

        --tp-word              # sizeof a word in bytes    (4)
        --tp-pointer           # sizeof a pointer in bytes (4)
        --tp-off               # sizeof an offset in bytes (2)
        --tp-lbl               # sizeof a label in bytes   (2)

]])
    os.exit(1)
end

if _OPTS.analysis then
    assert((not _OPTS.analysis_use) and (not _OPTS.analysis_run)
            and _OPTS.input~='-',
        'invalid analysis invocation')
    local params = table.concat(params,' ')
    do
        params = string.gsub(params, '--analysis[^ ]*', '')
        os.execute('./ceu '..params..
                    ' --analysis-run --analysis-file '.._OPTS.analysis_file)
        assert(os.execute('gcc -std=c99 -o ceu.exe analysis.c') == 0)
        assert(os.execute('./ceu.exe '.._OPTS.analysis_file) == 0)
    end
    _OPTS.analysis_use = true
    _OPTS.analysis = false
end

assert(not (_OPTS.analysis_use and _OPTS.analysis_run),
        'invalid analysis invocation')

-- C_CALLS
if _OPTS.c_calls then
    local t = {}
    for v in string.gmatch(_OPTS.c_calls, "(%w+)") do
        t[v] = true
    end
    _OPTS.c_calls = t
end


-- INPUT
local inp
if _OPTS.input == '-' then
    inp = io.stdin
else
    inp = assert(io.open(_OPTS.input))
end
_STR = inp:read'*a'

if _OPTS.m4 or _OPTS.m4_args then
    local args = _OPTS.m4_args and string.sub(_OPTS.m4_args, 2, -2) or ''   -- remove `"´
    local m4_file = (_OPTS.input=='-' and '_ceu_tmp.ceu_m4') or _OPTS.input..'_m4'
    local m4 = assert(io.popen('m4 '..args..' - > '..m4_file, 'w'))
    m4:write(_STR)
    m4:close()

    _STR = assert(io.open(m4_file)):read'*a'
    --os.remove(m4_file)
end

-- PARSE
do
    dofile 'tp.lua'

    dofile 'lines.lua'
    dofile 'parser.lua'
    dofile 'ast.lua'
    --ast.dump(ast.AST)
    dofile 'env.lua'
    dofile 'props.lua'
    dofile 'mem.lua'
    dofile 'tight.lua'
    dofile 'labels.lua'
    dofile 'analysis.lua'
    dofile 'code.lua'
end

local tps = { [1]='u8', [2]='u16', [4]='u32' }

local ALL = {
    n_tracks = _ANALYSIS.n_tracks,
    n_mem = _MEM.max,
    tceu_off = tps[_ENV.types.tceu_off],
    tceu_lbl = tps[MAX(_ENV.types.tceu_lbl,_ENV.types.tceu_off)],
}

assert(_MEM.max < 2^(_ENV.types.tceu_off*8))

-- TEMPLATE
local tpl
do
    tpl = assert(io.open'template.c'):read'*a'

    local sub = function (str, from, to)
        local i,e = string.find(str, from)
        return string.sub(str, 1, i-1) .. to .. string.sub(str, e+1)
    end

    tpl = sub(tpl, '=== N_TRACKS ===',  ALL.n_tracks)
    tpl = sub(tpl, '=== N_MEM ===',     ALL.n_mem)

    tpl = sub(tpl, '=== HOST ===',      (_OPTS.analysis_run and '') or _CODE.host)
    tpl = sub(tpl, '=== CODE ===',      _AST.root.code)

    -- lbl >= off (EMITS)
    tpl = sub(tpl, '=== TCEU_OFF ===',  ALL.tceu_off)
    tpl = sub(tpl, '=== TCEU_LBL ===',  ALL.tceu_lbl)

    -- GTES
    tpl = sub(tpl, '=== CEU_WCLOCK0 ===', _MEM.gtes.wclock0)
    tpl = sub(tpl, '=== CEU_ASYNC0 ===',  _MEM.gtes.async0)
    tpl = sub(tpl, '=== CEU_EMIT0 ===',   _MEM.gtes.emit0)

    -- LABELS
    tpl = sub(tpl, '=== N_LABELS ===', #_LABELS.list)
    tpl = sub(tpl, '=== LABELS ===',   _LABELS.code)

    -- DEFINITIONS: constants & defines
    do
        -- EVENTS
        local str = ''
        local t = {}
        local outs = 0
        local ins  = {}
        for _, ext in ipairs(_ENV.exts) do
            if ext.input then
                str = str..'#define IN_'..ext.id..' '.._MEM.gtes[ext.n]..'\n'
                ins[#ins+1] = _MEM.gtes[ext.n]
            else
                str = str..'#define OUT_'..ext.id..' '..outs..'\n'
                outs = outs + 1
            end
        end
        str = str..'#define OUT_n '..outs..'\n'
        if _OPTS.analysis_run then
            str = str..'#define IN_n '..#ins..'\n'
            str = str .. 'int IN_vec[] = { '..table.concat(ins,',')..' };\n'
        end

        -- FUNCTIONS called
        for id in pairs(_ENV.calls) do
            if id ~= '$anon' then
                str = str..'#define FUNC'..id..'\n'
            end
        end

        -- DEFINES
        if _PROPS.has_exts then
            str = str .. '#define CEU_EXTS\n'
            ALL.exts = true
        end
        if _PROPS.has_wclocks then
            str = str .. '#define CEU_WCLOCKS '.._ENV.n_wclocks..'\n'
            ALL.wclocks = true
        end
        if _PROPS.has_asyncs then
            str = str .. '#define CEU_ASYNCS '.._ENV.n_asyncs..'\n'
            ALL.asyncs = true
        end
        if _PROPS.has_emits then
            str = str .. '#define CEU_EMITS\n'
            ALL.emits = true
        end
        if _ANALYSIS.needsPrio then
            str = str .. '#define CEU_TRK_PRIO\n'
            ALL.prio = true
        end
        if _ANALYSIS.needsChk then
            str = str .. '#define CEU_TRK_CHK\n'
            ALL.chk = true
        end

        if _OPTS.defs_file then
            local f = io.open(_OPTS.defs_file,'w')
            f:write(str)
            f:close()
            tpl = sub(tpl, '=== DEFS ===',
                           '#include "'.. _OPTS.defs_file ..'"')
        else
            tpl = sub(tpl, '=== DEFS ===', str)
        end
    end
end

local t = {}
for k,v in pairs(ALL) do
    if v == true then
        t[#t+1] = k
    else
        t[#t+1] = k..'='..v
    end
end
table.sort(t)
DBG('[ '..table.concat(t,' | ')..' ]')

-- OUTPUT
local out
if _OPTS.output == '-' then
    out = io.stdout
else
    out = assert(io.open(_OPTS.output,'w'))
end
out:write(tpl)
