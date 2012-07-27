_CEU = true

_OPTS = {
    input     = nil,
    output    = '-',

    defs_file  = '_ceu_defs.h',
    simul_file = nil,

    join      = true,

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
    simul_file = 1,

    join      = 0,

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
            _OPTS[opt] = params[i]
            i = i + 1
        end

    else
        _OPTS.input = p
    end
end
if not _OPTS.input then
    io.stderr:write([[

    ./ceu <filename>              # Ceu input file, or `-´ for stdin
    
        --output <filename>       # C output file (stdout)
    
        --defs-file <filename>    # define constants in a separate output file (no)
        --simul-file <filename>   # file containing the simulation analysis (no)
    
        --join (--no-join)        # join lines enclosed by /*{-{*/ and /*}-}*/ (join)

        --m4 (--no-m4)            # preprocess the input with `m4´ (no-m4)
        --m4-args                 # preprocess the input with `m4´ passing arguments in between `"´ (no)

        --tp-word                 # sizeof a word in bytes    (4)
        --tp-pointer              # sizeof a pointer in bytes (4)
        --tp-off                  # sizeof an offset in bytes (2)
        --tp-lbl                  # sizeof a label in bytes   (2)

]])
    os.exit(1)
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
    local m4_file = (_OPTS.input=='-' and '_tmp.ceu_m4') or _OPTS.input..'_m4'
    local m4 = assert(io.popen('m4 '..args..' - > '..m4_file, 'w'))
    m4:write(_STR)
    m4:close()

    _STR = assert(io.open(m4_file)):read'*a'
    --os.remove(m4_file)
end

-- PARSE
do
    dofile 'set.lua'

    dofile 'lines.lua'
    dofile 'parser.lua'
    dofile 'ast.lua'
    --ast.dump(ast.AST)
    dofile 'tp.lua'
    dofile 'env.lua'
    dofile 'mem.lua'
    dofile 'props.lua'
    dofile 'tight.lua'
    dofile 'async.lua'
    dofile 'code.lua'

    if _OPTS.simul_file then
        dofile(_OPTS.simul_file)
    end
end

-- TEMPLATE
local tpl
do
    tpl = assert(io.open'template.c'):read'*a'

    local sub = function (str, from, to)
        local i,e = string.find(str, from)
        return string.sub(str, 1, i-1) .. to .. string.sub(str, e+1)
    end

    tpl = sub(tpl, '=== N_TRACKS ===',  _AST.root.n_tracks)
    tpl = sub(tpl, '=== N_MEM ===',     _MEM.max)

    tpl = sub(tpl, '=== HOST ===',      _CODE.host)
    tpl = sub(tpl, '=== CODE ===',      _AST.root.code)

    -- lbl >= off (EMITS)
    local t = { [1]='u8', [2]='u16', [4]='u32' }
    tpl = sub(tpl, '=== TCEU_OFF ===',  t[_ENV.types.tceu_off])
    tpl = sub(tpl, '=== TCEU_LBL ===',  t[MAX(_ENV.types.tceu_lbl,_ENV.types.tceu_off)])

    DBG('# mem: '.._MEM.max)
    assert(_MEM.max < 2^(_ENV.types.tceu_off*8))
    assert(#_CODE.labels < 2^(_ENV.types.tceu_lbl*8))

    -- GTES
    do
        tpl = sub(tpl, '=== CEU_WCLOCK0 ===', _MEM.gtes.wclock0)
        tpl = sub(tpl, '=== CEU_ASYNC0 ===',  _MEM.gtes.async0)
        tpl = sub(tpl, '=== CEU_EMIT0 ===',   _MEM.gtes.emit0)
        tpl = sub(tpl, '=== CEU_FIN0 ===',    _MEM.gtes.fin0)
    end

    -- LABELS
    do
        local labels = ''
        for i, id in ipairs(_CODE.labels) do
            labels = labels..'    '..id..' = '..(i-1)..',\n'
        end
        tpl = sub(tpl, '=== LABELS ===', labels)
    end

    -- DEFINITIONS: constants & defines
    do
        -- EVENTS
        local str = ''
        local t = {}
        local outs = 0
        for _, ext in ipairs(_ENV.exts) do
            if ext.input then
                str = str..'#define IN_'..ext.id..' '.._MEM.gtes[ext.n]..'\n'
            else
                str = str..'#define OUT_'..ext.id..' '..outs..'\n'
                outs = outs + 1
            end
        end
        str = str..'#define OUT_n '..outs..'\n'

        -- FUNCTIONS called
        for id in pairs(_ENV.calls) do
            if id ~= '$anon' then
                str = str..'#define FUNC'..id..'\n'
            end
        end

        -- DEFINES
        if _PROPS.has_exts then
            str = str .. '#define CEU_EXTS\n'
            DBG('# EXTS')
        end
        if _PROPS.has_wclocks then
            str = str .. '#define CEU_WCLOCKS '.._ENV.n_wclocks..'\n'
            DBG('# WCLOCKS')
        end
        if _PROPS.has_asyncs then
            str = str .. '#define CEU_ASYNCS '.._ENV.n_asyncs..'\n'
            DBG('# ASYNCS')
        end
        if _PROPS.has_emits then
            str = str .. '#define CEU_EMITS\n'
            DBG('# EMITS')
        end
        if _PROPS.has_fins then
            str = str .. '#define CEU_FINS\n'
            DBG('# FINALIZERS')
        end
        if _SIMUL and (not _SIMUL.hasPrio) then
            str = str .. '#define CEU_TRK_NOPRIO\n'
            DBG('# TRK_NOPRIO')
        end
        if _SIMUL and (not _SIMUL.chkPrio) then
            str = str .. '#define CEU_TRK_NOCHK\n'
            DBG('# TRK_NOCHK')
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

-- OUTPUT
local out
if _OPTS.output == '-' then
    out = io.stdout
else
    out = assert(io.open(_OPTS.output,'w'))
end
out:write(tpl)
