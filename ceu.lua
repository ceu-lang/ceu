_OPTS = {
    input     = nil,
    output    = '_ceu_code.cceu',

    defs_file  = '_ceu_defs.h',

    join      = true,
    c_calls   = false,

    m4        = false,
    m4_args   = false,

    tp_word    = 4,
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
local source = inp:read'*a'

if _OPTS.m4 or _OPTS.m4_args then
    local args = _OPTS.m4_args or ''
    local m4_file = (_OPTS.input=='-' and '_ceu_tmp.ceu_m4') or _OPTS.input..'_m4'
    local m4 = assert(io.popen('m4 '..args..' - > '..m4_file, 'w'))
    m4:write(source)
    m4:close()

    source = assert(io.open(m4_file)):read'*a'
    --os.remove(m4_file)
end

-- PARSE
do
    dofile 'tp.lua'
    dofile 'lines.lua'
    dofile 'parser.lua'
    dofile 'ast.lua'
    _AST.f(_OPTS.input, source)
    dofile 'adj.lua'
    --_AST.dump(_AST.root)
    dofile 'env.lua'
    dofile 'fin.lua'
    dofile 'tight.lua'
    --dofile 'awaits.lua'
    dofile 'props.lua'
    dofile 'ana.lua'
    dofile 'acc.lua'
    dofile 'trails.lua'
    dofile 'sval.lua'
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

    tpl = sub(tpl, '=== CEU_NTRAILS ===',  _MAIN.trails_n)

    tpl = sub(tpl, '=== TCEU_NLBL ===',    's'..tps[_ENV.c.tceu_nlbl.len])

    tpl = sub(tpl, '=== LABELS_ENUM ===', _LBLS.code_enum)

    tpl = sub(tpl, '=== POOL_C ===', assert(io.open'pool.c'):read'*a')
    tpl = sub(tpl, '=== CLSS_DEFS ===', _MEM.clss_defs)
    tpl = sub(tpl, '=== CLSS_INIT ===', _MEM.clss_init)

    tpl = sub(tpl, '=== THREADS_C ===', _CODE.threads)
    --tpl = sub(tpl, '=== HOST ===',     _CODE.host)
    tpl = sub(tpl, '=== CODE ===',     _AST.root.code)

    -- IFACES
    if _PROPS.has_ifcs then
        local CLSS = {}
        local FLDS = {}
        local EVTS = {}
        local FUNS = {}
        for _, cls in ipairs(_ENV.clss_cls) do
            local clss = {}
            local flds = {}
            local evts = {}
            local funs = {}
            for i=1, #_ENV.ifcs.flds do
                flds[i] = 0
            end
            for i=1, #_ENV.ifcs.evts do
                evts[i] = 0
            end
            for i=1, #_ENV.ifcs.funs do
                funs[i] = 'NULL'
            end
            for _, var in ipairs(cls.blk_ifc.vars) do
                if var.isEvt then
                    local i = _ENV.ifcs.evts[var.id_ifc]
                    if i then
                        evts[i+1] = var.evt_idx
                    end
                else
                    local i = _ENV.ifcs.flds[var.id_ifc]
                    if i then
                        flds[i+1] = 'offsetof(CEU_'..cls.id..','..var.id_..')'
                    end
                end
            end
            for id, c in pairs(cls.blk_ifc.funs) do
                local i = _ENV.ifcs.funs[id]
                if i then
                    funs[i+1] = c.id_
                end
            end

            -- IFCS_CLSS
            for _,ifc in ipairs(_ENV.clss_ifc) do
                clss[#clss+1] = cls.matches[ifc] and 1 or 0
            end

            CLSS[#CLSS+1] = '\t\t{'..table.concat(clss,',')..'}'
            FLDS[#FLDS+1] = '\t\t{'..table.concat(flds,',')..'}'
            EVTS[#EVTS+1] = '\t\t{'..table.concat(evts,',')..'}'
            FUNS[#FUNS+1] = '\t\t{'..table.concat(funs,',')..'}'
        end
        tpl = sub(tpl, '=== TCEU_NCLS ===',    'u'..tps[_ENV.c.tceu_ncls.len])
        tpl = sub(tpl, '=== CEU_NCLS ===',     #_ENV.clss_cls)
        tpl = sub(tpl, '=== IFCS_NIFCS ===',   #_ENV.clss_ifc)
        tpl = sub(tpl, '=== IFCS_NFLDS ===',   #_ENV.ifcs.flds)
        tpl = sub(tpl, '=== IFCS_NEVTS ===',   #_ENV.ifcs.evts)
        tpl = sub(tpl, '=== IFCS_NFUNS ===',   #_ENV.ifcs.funs)
        tpl = sub(tpl, '=== IFCS_CLSS ===',    table.concat(CLSS,',\n'))
        tpl = sub(tpl, '=== IFCS_FLDS ===',    table.concat(FLDS,',\n'))
        tpl = sub(tpl, '=== IFCS_EVTS ===',    table.concat(EVTS,',\n'))
        tpl = sub(tpl, '=== IFCS_FUNS ===',    table.concat(FUNS,',\n'))
    end

    -- EVENTS
    -- inputs: [max_evt+1...) (including _FIN,_WCLOCK,_ASYNC)
    --          cannot overlap w/ internal events
    local str = ''
    local t = {}
    --local ins  = 0
    local outs = 0

    -- TODO
    str = str..'#define CEU_IN__NONE 0\n'

    for i, evt in ipairs(_ENV.exts) do
        if evt.pre == 'input' then
            str = str..'#define CEU_IN_'..evt.id..' '
                    ..(_ENV.max_evt+i)..'\n'
            --ins = ins + 1
        else
            str = str..'#define CEU_OUT_'..evt.id..' '..outs..'\n'
            outs = outs + 1
        end
        assert(evt.pre=='input' or evt.pre=='output')
    end
    --str = str..'#define CEU_IN_n  '..ins..'\n'
    str = str..'#define CEU_OUT_n '..outs..'\n'

    -- FUNCTIONS called
    for id in pairs(_ENV.calls) do
        if id ~= '$anon' then
            str = str..'#define CEU_FUN'..id..'\n'
        end
    end

    -- DEFINES
    local t = {
        has_exts    = 'CEU_EXTS',
        has_wclocks = 'CEU_WCLOCKS',
        has_ints    = 'CEU_INTS',
        has_asyncs  = 'CEU_ASYNCS',
        has_threads = 'CEU_THREADS',
        has_orgs    = 'CEU_ORGS',
        has_news    = 'CEU_NEWS',
        has_news_pool   = 'CEU_NEWS_POOL',
        has_news_malloc = 'CEU_NEWS_MALLOC',
        has_ifcs    = 'CEU_IFCS',
        has_clear   = 'CEU_CLEAR',
        has_pses    = 'CEU_PSES',
    }
    for k, s in pairs(t) do
        if _PROPS[k] then
            str = str .. '#define ' .. s .. '\n'
        end
    end

    if _CODE.has_goto then
        str = str .. '#define CEU_GOTO\n'
    end

    -- TODO: goto _OPTS
    --str = str .. '#define CEU_DEBUG_TRAILS\n'

    if _OPTS.run_tests then
        str = str .. '#define CEU_RUNTESTS\n'
    end

    -- tuples
    do
        for _,c in pairs(_ENV.c) do
            if c.tuple then
                str = str .. 'typedef struct {\n'
                for i, f in ipairs(c.tuple) do
                    if _TP.deref(f) then
                        -- T* => void*
                        -- T** => void**
                        f = 'void'..string.match(f,'(%*+)')
                    end
                    str = str..'\t'.._TP.c(f)..' _'..i..';\n'
                end
                str = str .. '} '.._TP.c(c.id)..';\n'
            end
        end
    end

    if _OPTS.defs_file then
        local f = assert(io.open(_OPTS.defs_file,'w'))
        local h = [[
#ifndef _CEU_DEFS_H
#define _CEU_DEFS_H
void ceu_go_init ();
void ceu_go_event (int id, void* data);
void ceu_go_async ();
void ceu_go_wclock (s32 dt);
]]
        f:write(h..str..[[
#endif
]])
        f:close()
        tpl = sub(tpl, '=== DEFS ===',
                       '#include "'.. _OPTS.defs_file ..'"')
    else
        tpl = sub(tpl, '=== DEFS ===', str)
    end

    tpl = sub(tpl, '=== FILENAME ===', _OPTS.input)

    --tpl = string.gsub(tpl, '^#line.-\n', '')
end

if _OPTS.verbose or true then
    local T = {
        --mem  = _AST.root.mem.max,
        evts = _ENV.max_evt+#_ENV.exts,
        lbls = #_LBLS.list,

        trls       = _AST.root.trails_n,

        exts    = _PROPS.has_exts,
        wclocks = _PROPS.has_wclocks,
        ints    = _PROPS.has_ints,
        asyncs  = _PROPS.has_asyncs,
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
out:write([[
/*
 * This file is automatically generated.
 * Check the github repository for a readable version:
 * http://github.com/fsantanna/ceu
 *
 * Céu is distributed under the MIT License:
 *

Copyright (C) 2012 Francisco Sant'Anna

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
]] .. tpl)
