_OPTS_NPARAMS = {
    version   = 0,
    input     = nil,

    out_c     = 1,
    out_h     = 1,
    out_s     = 1,
    out_f     = 1,

    join      = 0,
    c_calls   = 1,

    cpp       = 0,
    cpp_args  = 1,

    tp_word    = 1,

    os        = 0,
}

_OPTS = {
    input     = nil,

    out_c     = '_ceu_app.c',
    out_h     = '_ceu_app.h',
    out_s     = 'CEU_SIZE',
    out_f     = 'ceu_app_init',

    join      = true,
    c_calls   = false,

    cpp       = true,
    cpp_args  = false,

    tp_word   = 4,

    os        = false,
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

if _OPTS.version then
    print 'ceu 0.7'
    os.exit(0)
end

if not _OPTS.input then
    io.stderr:write([[

    ./ceu <filename>           # Ceu input file, or `-´ for stdin
    
        --out-c <filename>     # C output source file (_ceu_app.c)
        --out-h <filename>     # C output header file (_ceu_app.h)
        --out-s <NAME>         # TODO (CEU_SIZE)
        --out-f <NAME>         # TODO (ceu_app_init)
    
        --join (--no-join)     # join lines enclosed by /*{-{*/ and /*}-}*/ (join)
        --c-calls              # TODO

        --cpp (--no-cpp)       # preprocess the input with `cpp´ (no-cpp)
        --cpp-args             # preprocess the input with `cpp´ passing arguments in between `"´ (no)

        --tp-word              # sizeof a word in bytes    (4)

        --version              # version of Ceu

        --os                   # TODO
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

_OPTS.source = source

-- PARSE
do
    dofile 'tp.lua'
    dofile 'lines.lua'
    dofile 'parser.lua'
    dofile 'ast.lua'
    dofile 'adj.lua'
    dofile 'tops.lua'
    dofile 'env.lua'
    dofile 'fin.lua'
    dofile 'tight.lua'
    --dofile 'awaits.lua'
    dofile 'props.lua'
    dofile 'ana.lua'
    dofile 'acc.lua'
    --_AST.dump(_AST.root)
    dofile 'trails.lua'
    dofile 'sval.lua'
    dofile 'labels.lua'
    dofile 'tmps.lua'
    dofile 'mem.lua'
    dofile 'val.lua'
    dofile 'code.lua'
end

local CC, HH

-- TEMPLATE.C
do
    CC = _FILES.template_c

    CC = string.gsub(CC, '=== FILENAME ===', _OPTS.input)
    --CC = string.gsub(CC, '^#line.-\n', '')

    CC = string.gsub(CC, '=== LABELS_ENUM ===', _LBLS.code_enum)

    CC = string.gsub(CC, '=== CLSS_DEFS ===',  _MEM.clss)
    CC = string.gsub(CC, '=== POOLS_DCL ===',  _MEM.pools.dcl)
    CC = string.gsub(CC, '=== POOLS_INIT ===', _MEM.pools.init)

    CC = string.gsub(CC, '=== THREADS_C ===',   _CODE.threads)
    CC = string.gsub(CC, '=== FUNCTIONS_C ===', _CODE.functions)
    CC = string.gsub(CC, '=== STUBS ===',       _CODE.stubs)
    CC = string.gsub(CC, '=== NATIVE ===',      _CODE.native)
    CC = string.gsub(CC, '=== CODE ===',        _AST.root.code)

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
                if var.pre == 'event' then
                    local i = _ENV.ifcs.evts[var.ifc_id]
                    if i then
                        evts[i+1] = var.evt.idx
                    end
                elseif var.pre == 'var' then
                    local i = _ENV.ifcs.flds[var.ifc_id]
                    if i then
                        flds[i+1] = 'offsetof(CEU_'..cls.id..','..(var.id_ or var.id)..')'
                    end
                else    -- function
                    local i = _ENV.ifcs.funs[var.ifc_id]
                    if i then
                        funs[i+1] = var.val
                    end
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
        CC = string.gsub(CC, '=== CEU_NCLS ===',     #_ENV.clss_cls)
        CC = string.gsub(CC, '=== IFCS_NIFCS ===',   #_ENV.clss_ifc)
        CC = string.gsub(CC, '=== IFCS_NFLDS ===',   #_ENV.ifcs.flds)
        CC = string.gsub(CC, '=== IFCS_NEVTS ===',   #_ENV.ifcs.evts)
        CC = string.gsub(CC, '=== IFCS_NFUNS ===',   #_ENV.ifcs.funs)
        CC = string.gsub(CC, '=== IFCS_CLSS ===',    table.concat(CLSS,',\n'))
        CC = string.gsub(CC, '=== IFCS_FLDS ===',    table.concat(FLDS,',\n'))
        CC = string.gsub(CC, '=== IFCS_EVTS ===',    table.concat(EVTS,',\n'))
        CC = string.gsub(CC, '=== IFCS_FUNS ===',    table.concat(FUNS,',\n'))
    end

    if not _OPTS.os then
        _FILES.ceu_os_c = string.gsub(string.gsub(_FILES.ceu_os_c,'%%','%%%%'),
                                      '#include "ceu_os.h"',
                                      _FILES.ceu_os_h)
        CC = string.gsub(CC, '#include "ceu_types.h"',
                             _FILES.ceu_types_h)
        CC = string.gsub(CC, '#include "ceu_os.h"',
                             _FILES.ceu_os_h..'\n'.._FILES.ceu_os_c)
        CC = string.gsub(CC, '#include "ceu_pool.h"',
                             _FILES.ceu_pool_h..'\n'.._FILES.ceu_pool_c)
    end

    if _OPTS.out_s ~= 'CEU_SIZE' then
        CC = string.gsub(CC, 'CEU_SIZE', _OPTS.out_s)
    end
    if _OPTS.out_f ~= 'ceu_app_init' then
        CC = string.gsub(CC, 'ceu_app_init', _OPTS.out_f)
    end
end

-- TEMPLATE.H
do
    HH = _FILES.template_h

    local tps = { [0]='void', [1]='8', [2]='16', [4]='32' }
    HH = string.gsub(HH, '=== TCEU_NLBL ===',   's'..tps[_ENV.c.tceu_nlbl.len])
    HH = string.gsub(HH, '=== TCEU_NCLS ===',   's'..tps[_ENV.c.tceu_ncls.len])
    HH = string.gsub(HH, '=== CEU_NTRAILS ===', _MAIN.trails_n)

    -- DEFINES
    do
        local str = ''
        local t = {
            -- props.lua
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
            has_ret     = 'CEU_RET',
            -- code.lua
            has_goto    = 'CEU_GOTO',
        }
        for k, s in pairs(t) do
            if _PROPS[k] or _CODE[k] then
                str = str .. '#define ' .. s .. '\n'
            end
        end

        -- TODO: goto _OPTS
        --str = str .. '#define CEU_DEBUG_TRAILS\n'
        --str = str .. '#define CEU_NOLINES\n'

        if _OPTS.os then
            str = str .. [[
#ifndef CEU_OS
#define CEU_OS
#endif
]]
        end

        if _OPTS.run_tests then
            str = str .. '#define CEU_RUNTESTS\n'
        end

        HH = string.gsub(HH, '=== DEFS_H ===',
                     string.upper(string.gsub(_OPTS.out_h,'%.','_')))
        HH = string.gsub(HH, '=== DEFINES ===', str)
    end


    -- EVENTS
    do
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
                local s = '#define CEU_IN_'..evt.id..' '..(256-i)
                if _OPTS.verbose and i > 9 then
                    DBG('', s)
                end
                str = str..s..'\n'
                --ins = ins + 1
            else
                outs = outs + 1
                local s = '#define CEU_OUT_'..evt.id..' '..outs
                if _OPTS.verbose then
                    DBG('', s)
                end
                str = str..s..'\n'
            end
            assert(evt.pre=='input' or evt.pre=='output')
        end
        --str = str..'#define CEU_IN_n  '..ins..'\n'
        str = str..'#define CEU_OUT_n '..outs..'\n'

        HH = string.gsub(HH, '=== EVENTS ===', str)
    end

    -- FUNCTIONS called
    do
        local str = ''
        for id in pairs(_ENV.calls) do
            if id ~= '$anon' then
                str = str..'#define CEU_FUN'..id..'\n'
            end
        end
        HH = string.gsub(HH, '=== FUNCTIONS ===', str)
    end

    -- TUPLES
    do
        local str = ''
        for _,c in pairs(_ENV.c) do
            if c.tuple and #c.tuple>0 then
                str = str .. 'typedef struct {\n'
                for i, v in ipairs(c.tuple) do
                    local _,tp,_ = unpack(v)
                    if _ENV.clss[_TP.noptr(tp)] then
                        -- T* => void*
                        -- T** => void**
                        tp = 'void'..string.match(tp,'(%*+)')
                    end
                    str = str..'\t'.._TP.c(tp)..' _'..i..';\n'
                end
                str = str .. '} '.._TP.c(c.id)..';\n'
            end
        end
        HH = string.gsub(HH, '=== TUPLES ===', str)
    end
end

if _OPTS.verbose then
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
        ret     = _PROPS.has_ret,
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

if _OPTS.out_h then
    local f = assert(io.open(_OPTS.out_h,'w'))
    f:write(HH)
    f:close()
end
CC = string.gsub(CC, '=== OUT_H ===', HH)

local out
if _OPTS.out_c == '-' then
    out = io.stdout
else
    out = assert(io.open(_OPTS.out_c,'w'))
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
]] .. CC)
out:close()
