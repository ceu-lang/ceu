_CEU = true

_OPTS = {
    input     = nil,
    output    = '_ceu_code.cceu',

    defs_file  = '_ceu_defs.h',

    join      = true,
    c_calls   = false,

    m4        = false,
    m4_args   = false,

    tp_word    = 4,
    tp_pointer = 4,
}

_OPTS_NPARAMS = {
    input     = nil,
    output    = 1,

    defs_file  = 1,

    join      = 0,
    c_calls   = 1,

    m4        = 0,
    m4_args   = 1,

    tp_word    = 1,
    tp_pointer = 1,
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
        if _OPTS_NPARAMS[opt]==0 or _OPTS_NPARAMS[opt]==nil then
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

        --join (--no-join)     # join lines enclosed by /*{-{*/ and /*}-}*/ (join)
        --c-calls              # TODO

        --m4 (--no-m4)         # preprocess the input with `m4´ (no-m4)
        --m4-args              # preprocess the input with `m4´ passing arguments in between `"´ (no)

        --tp-word              # sizeof a word in bytes    (4)
        --tp-pointer           # sizeof a pointer in bytes (4)

]])
    os.exit(1)
end

-- C_CALLS
if _OPTS.c_calls then
    local t = {}
    for v in string.gmatch(_OPTS.c_calls, "([_%w]+)") do
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
    local args = _OPTS.m4_args or ''
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
    dofile 'env.lua'
    dofile 'fin.lua'
    dofile 'ana.lua'
    dofile 'acc.lua'
    --_AST.dump(_AST.root)
    dofile 'tight.lua'
    --dofile 'awaits.lua'
    dofile 'props.lua'
    dofile 'trails.lua'
    dofile 'labels.lua'
    dofile 'tmps.lua'
    dofile 'mem.lua'
    dofile 'val.lua'
    dofile 'code.lua'
end

local tps = { [0]='void', [1]='8', [2]='16', [4]='32' }

-- TEMPLATE
local tpl
do
    tpl = assert(io.open'template.c'):read'*a'

    local sub = function (str, from, to)
        assert(to, from)
        local i,e = string.find(str, from)
        return string.sub(str, 1, i-1) .. to .. string.sub(str, e+1)
    end

    tpl = sub(tpl, '=== CEU_NMEM ===',     _AST.root.mem.max)
    tpl = sub(tpl, '=== CEU_NTRAILS ===',  _MAIN.trails_n)

    tpl = sub(tpl, '=== TCEU_NLBL ===',    's'..tps[_ENV.c.tceu_nlbl.len])

    tpl = sub(tpl, '=== LABELS_ENUM ===', _LBLS.code_enum)

    tpl = sub(tpl, '=== HOST ===',     _CODE.host)
    tpl = sub(tpl, '=== CODE ===',     _AST.root.code)

    tpl = sub(tpl, '=== CLSS_DEFS ===', _MEM.clss_defs)
    tpl = sub(tpl, '=== CLSS_INIT ===', _MEM.clss_init)
    tpl = sub(tpl, '=== CLSS_FREE ===', _MEM.clss_free)

    -- IFACES
    if _PROPS.has_ifcs then
        local T = {}
        local off_max = 0
        for _, cls in ipairs(_ENV.clss_cls) do
            local t = {}
            for i=1, #_ENV.ifcs do
                t[i] = 0
            end
            for _, var in ipairs(cls.blk_ifc.vars) do
                local i = _ENV.ifcs[var.id_ifc]
                if i then
                    t[i+1] = var.off
                    if var.off > off_max then
                        off_max = var.off
                    end
                end
            end
            T[#T+1] = '{'..table.concat(t,',')..'}'
        end
        tpl = sub(tpl, '=== TCEU_NCLS ===', 'u'..tps[_ENV.c.tceu_ncls.len])
        tpl = sub(tpl, '=== TCEU_NOFF ===', 'u'..tps[_TP.n2bytes(off_max)])
        tpl = sub(tpl, '=== CEU_NCLS ===',  #_ENV.clss_cls)
        tpl = sub(tpl, '=== CEU_NIFCS ===', #_ENV.ifcs)
        tpl = sub(tpl, '=== IFCS ===', table.concat(T,','))
    end

    -- EVENTS
    -- inputs: [evt_off+1...) (including _FIN,_WCLOCK,_ASYNC)
    --          cannot overlap w/ internal events
    local str = ''
    local t = {}
    --local ins  = 0
    local outs = 0

    -- TODO
    str = str..'#define IN__NONE 0\n'

    for i, evt in ipairs(_ENV.exts) do
        if evt.pre == 'input' then
            str = str..'#define IN_'..evt.id..' '
                    ..(_MEM.evt_off+i)..'\n'
            --ins = ins + 1
        else
            str = str..'#define OUT_'..evt.id..' '..outs..'\n'
            outs = outs + 1
        end
        assert(evt.pre=='input' or evt.pre=='output')
    end
    --str = str..'#define IN_n  '..ins..'\n'
    str = str..'#define OUT_n '..outs..'\n'

    -- FUNCTIONS called
    for id in pairs(_ENV.calls) do
        if id ~= '$anon' then
            str = str..'#define FUNC'..id..'\n'
        end
    end

    -- DEFINES
    local t = {
        has_exts    = 'CEU_EXTS',
        has_wclocks = 'CEU_WCLOCKS',
        has_ints    = 'CEU_INTS',
        has_asyncs  = 'CEU_ASYNCS',
        has_fins    = 'CEU_FINS',
        has_orgs    = 'CEU_ORGS',
        has_news    = 'CEU_NEWS',
        has_ifcs    = 'CEU_IFCS',
        has_clear   = 'CEU_CLEAR',
    }
    for k, s in pairs(t) do
        if _PROPS[k] then
            str = str .. '#define ' .. s .. '\n'
        end
    end

    -- TODO: goto _OPTS
    --str = str .. '#define CEU_DEBUG_TRAILS\n'

    if _OPTS.run_tests then
        str = str .. '#define CEU_RUNTESTS\n'
    end

    if _OPTS.defs_file then
        local f = assert(io.open(_OPTS.defs_file,'w'))
        local h = [[
void ceu_go_init ();
void ceu_go_event (int id, void* data);
void ceu_go_async ();
void ceu_go_wclock (s32 dt);
]]
        f:write(h..str)
        f:close()
        tpl = sub(tpl, '=== DEFS ===',
                       '#include "'.. _OPTS.defs_file ..'"')
    else
        tpl = sub(tpl, '=== DEFS ===', str)
    end

    tpl = sub(tpl, '=== FILENAME ===', _OPTS.input)
end

if _OPTS.verbose or true then
    local T = {
        mem  = _AST.root.mem.max,
        evts = _MEM.evt_off+#_ENV.exts,
        lbls = #_LBLS.list,

        trls       = _AST.root.trails_n,

        exts    = _PROPS.has_exts,
        wclocks = _PROPS.has_wclocks,
        ints    = _PROPS.has_ints,
        asyncs  = _PROPS.has_asyncs,
        fins    = _PROPS.has_fins,
        orgs    = _PROPS.has_orgs,
        news    = _PROPS.has_news,
        ifcs    = _PROPS.has_ifcs,
    }
    local t = {}
    for k, v in pairs(T) do
        if v == true then
            t[#t+1] = k
        elseif v then
            t[#t+1] = k..'='..v
        end
    end
    table.sort(t)
    DBG('[ '..table.concat(t,' | ')..' ]')
end

-- OUTPUT
local out
if _OPTS.output == '-' then
    out = io.stdout
else
    out = assert(io.open(_OPTS.output,'w'))
end
out:write(tpl)
