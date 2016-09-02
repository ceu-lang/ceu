OPTS_NPARAMS = {
    version   = 0,
    dump      = 0,
    input     = nil,

    out_dir   = 1,
    out_c     = 1,
    out_h     = 1,
    out_s     = 1,
    out_f     = 1,

    tmp_vars  = 0,
    join      = 0,
    c_calls   = 1,

    tuple_vector = 0,

    cpp       = 0,
    cpp_exe   = 1,
    cpp_args  = 1,

    safety    = 1,

    tp_word   = 1,

    os        = 0,
    os_luaifc = 0,

    timemachine = 0,
    reentrant = 0,

    verbose = 0,
}

OPTS = {
    input     = nil,

    out_dir   = '.',
    out_c     = '_ceu_app.c',
    out_h     = '_ceu_app.h',
    out_s     = 'CEU_SIZE',
    out_f     = 'ceu_app_init',

    tmp_vars  = true,
    join      = true,
    c_calls   = nil,    -- [nil=accept]

    tuple_vector = false,

    cpp       = true,
    cpp_exe   = 'cpp',
    cpp_args  = false,

    safety    = 0,

    tp_word   = 4,

    os        = false,
    os_luaifc = false,

    timemachine = false,
    reentrant = false,

    verbose = false,
}

local params = {...}
local i = 1
while i <= #params
do
    local p = params[i]
    i = i + 1

    if p == '-' then
        OPTS.input = '-'

    elseif string.sub(p, 1, 2) == '--' then
        local no = false
        local opt = string.gsub(string.sub(p,3), '%-', '_')
        if string.find(opt, '^no_') then
            no = true
            opt = string.sub(opt, 4)
        end
        if OPTS_NPARAMS[opt]==0 or OPTS_NPARAMS[opt]==nil then
            OPTS[opt] = not no
        else
            local opt = string.gsub(string.sub(p,3), '%-', '_')
            OPTS[opt] = string.match(params[i], "%'?(.*)%'?")
            i = i + 1
        end

    else
        OPTS.input = p
    end
end

if OPTS.version then
    print 'ceu 0.10'
    os.exit(0)
end

if OPTS.dump then
    print([[
Version: ceu 0.10
Lua:     ]]..LUA_EXE..[[
]])
    os.exit(0)
end

if OPTS.safety then
    OPTS.safety = assert(tonumber(OPTS.safety), '`--safety´ must be a number')
end

if OPTS.os_luaifc then
    assert(OPTS.os, '`--os-luaifc´ requires `--os´')
end

if not OPTS.input then
    io.stderr:write([[

    ./ceu <filename>           # Ceu input file, or `-´ for stdin
    
        --out-dir <dir>        # C output directory (.)
        --out-c <filename>     # C output source file (_ceu_app.c)
        --out-h <filename>     # C output header file (_ceu_app.h)
        --out-s <NAME>         # TODO (CEU_SIZE)
        --out-f <NAME>         # TODO (ceu_app_init)
    
        --tmp-vars (--no-tmp-vars) # TODO
        --join (--no-join)     # join lines enclosed by /*{-{*/ and /*}-}*/ (join)
        --c-calls              # TODO

        --tuple-vector         # TODO

        --cpp (--no-cpp)       # preprocess the input with `cpp´ (no-cpp)
        --cpp-exe              # preprocessor executable (cpp)
        --cpp-args             # preprocess the input with `cpp´ passing arguments in between `"´ (no)

        --safety <LEVEL>       # safety checks (*0=none*, 1=event, 2=par)

        --tp-word <SIZE>       # sizeof a word in bytes (4)

        --version              # version of Ceu

        --os                   # TODO
        --os-luaifc            # TODO

        --timemachine          # TODO

        --reentrant            # TODO
]])
    os.exit(1)
end

-- C_CALLS
if OPTS.c_calls then
    local t = {}
    for v in string.gmatch(OPTS.c_calls, "([_%w]+)") do
        t[v] = true
    end
    OPTS.c_calls = t
end


-- INPUT
local inp
if OPTS.input == '-' then
    inp = io.stdin
else
    inp = assert(io.open(OPTS.input))
end
local source = inp:read'*a'

OPTS.source = source

-- PARSE
do
    dofile 'tp.lua'
    dofile 'lines.lua'
    dofile 'parser.lua'
    dofile 'ast.lua'
    dofile 'adj.lua'
    dofile 'sval.lua'
    dofile 'env.lua'
    dofile 'adt.lua'
    dofile 'mode.lua'
    dofile 'ref.lua'
    dofile 'tight.lua'
    dofile 'fin.lua'
    dofile 'props.lua'
    dofile 'ana.lua'
    dofile 'acc.lua'
    dofile 'trails.lua'
    dofile 'labels.lua'
    dofile 'tmps.lua'
    dofile 'mem.lua'
    dofile 'val.lua'
    dofile 'code.lua'
    --AST.dump(AST.root)
end

local function SUB (str, from, to)
    assert(to, from)
    local i,e = string.find(str, from, 1, true)
    if i then
        return SUB(string.sub(str,1,i-1) .. to .. string.sub(str,e+1),
                   from, to)
    else
        return str
    end
end

local HH, CC

-- TEMPLATE.H
do
    HH = FILES.template_h
    HH = SUB(HH, '#include "ceu_sys.h"',  FILES.ceu_sys_h)
    --HH = SUB(HH, '#include "ceu_threads.h"', FILES.ceu_threads_h)
    --HH = SUB(HH, '#include "ceu_types.h"',   FILES.ceu_types_h)


    local tps = { [0]='void', [1]='8', [2]='16', [4]='32' }
    HH = SUB(HH, '=== TCEU_NLBL ===',   's'..tps[TP.types.tceu_nlbl.len])
    HH = SUB(HH, '=== TCEU_NCLS ===',   's'..tps[TP.types.tceu_ncls.len])
    HH = SUB(HH, '=== CEU_NTRAILS ===', MAIN.trails_n)
    HH = SUB(HH, '=== TOPS_H ===',      MEM.tops_h)

    if not OPTS.os then
        -- TODO: ceu_pool_* => ceu_sys_pool_*
        --FILES.ceu_pool_h = SUB(FILES.ceu_pool_h, '#include "ceu_types.h"',
                                                 --FILES.ceu_types_h)
        HH = SUB(HH, '#include "ceu_pool.h"', FILES.ceu_pool_h)

        -- TODO: ceu_vector_* => ceu_sys_vector_*
        FILES.ceu_vector_h = SUB(FILES.ceu_vector_h, '#include "ceu_sys.h"',
                                                     FILES.ceu_sys_h)
        HH = SUB(HH, '#include "ceu_vector.h"', FILES.ceu_vector_h)
    end

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
            has_isrs    = 'CEU_ISRS',
            has_orgs    = 'CEU_ORGS',
            has_orgs_news        = 'CEU_ORGS_NEWS',
            has_orgs_news_pool   = 'CEU_ORGS_NEWS_POOL',
            has_orgs_news_malloc = 'CEU_ORGS_NEWS_MALLOC',
            has_adts_news        = 'CEU_ADTS_NEWS',
            has_adts_news_pool   = 'CEU_ADTS_NEWS_POOL',
            has_adts_news_malloc = 'CEU_ADTS_NEWS_MALLOC',
            has_ifcs    = 'CEU_IFCS',
            has_clear   = 'CEU_CLEAR',
            has_stack_clear = 'CEU_STACK_CLEAR',
            has_pses    = 'CEU_PSES',
            has_ret     = 'CEU_RET',
            has_lua     = 'CEU_LUA',
            has_orgs_await = 'CEU_ORGS_AWAIT',

            has_vector        = 'CEU_VECTOR',
            has_vector_pool   = 'CEU_VECTOR_POOL',
            has_vector_malloc = 'CEU_VECTOR_MALLOC',

            -- code.lua
            has_goto    = 'CEU_GOTO',
        }
        for k, s in pairs(t) do
            if PROPS[k] or CODE[k] then
                str = str .. '#define ' .. s .. '\n'
            end
        end

        if next(PROPS.has_adts_await) then
            str = str .. '#define CEU_ADTS_AWAIT\n'
        end
        for id in pairs(PROPS.has_adts_await) do
            str = str .. '#define CEU_ADTS_AWAIT_' .. id .. '\n'
        end

        if ANA.no_nested_termination then
            str = str .. '#define CEU_ANA_NO_NESTED_TERMINATION\n'
        end

        -- TODO: goto OPTS
        --str = str .. '#define CEU_DEBUG_TRAILS\n'
        --str = str .. '#define CEU_NOLINES\n'

        if OPTS.os then
            str = str .. [[
#ifndef CEU_OS_APP
#define CEU_OS_APP
#endif
]]
            if OPTS.os_luaifc then
                str = str .. [[
#ifndef CEU_OS_LUAIFC
#define CEU_OS_LUAIFC
#endif
]]
            end
        end

        if OPTS.timemachine then
            str = str .. [[
#ifndef CEU_TIMEMACHINE
#define CEU_TIMEMACHINE
#endif
]]
        end

        if OPTS.reentrant then
            str = str .. [[
#ifndef CEU_REENTRANT
#define CEU_REENTRANT
#endif
]]
        end

        if OPTS.run_tests then
            str = str .. '#define CEU_RUNTESTS\n'
        end

        local h = OPTS.out_h
        if OPTS.out_h == '-' then
            h = '_STDIN_H'
        end

        HH = SUB(HH, '=== DEFS_H ===',
                     string.upper(string.gsub(h,'%.','_')))
        HH = SUB(HH, '=== DEFINES ===', str)
    end

    -- ISRS
    do
        local str = ''
        for id in pairs(ENV.isrs) do
            str = str..'#define CEU_ISR_'..id..'\n'
        end
        HH = SUB(HH, '=== ISRS ===', str)
    end

    -- EVENTS
    do
        -- inputs: [max_evt+1...) (including _FIN,_WCLOCK,_ASYNC)
        --          cannot overlap w/ internal events
        local str = ''
        local t = {}
        local ins  = 0
        local outs = 0

        -- TODO
        str = str..'#define CEU_IN__NONE 0\n'

        HH = SUB(HH, '=== NATIVE_PRE ===', (OPTS.c_calls and '') or MEM.native_pre)

        for i, evt in ipairs(ENV.exts) do
            if evt.pre == 'input' then
                ins = ins + 1
                evt.n = (256-ins)
                local s = '#define CEU_IN_'..evt.id..' '..evt.n
                if OPTS.verbose and i > 9 then
                    DBG('', s)
                end
                if not (evt.os and OPTS.os) then
                    str = str..s..'\n'
                end
            else
                outs = outs + 1
                evt.n = outs
                local s = '#define CEU_OUT_'..evt.id..' '..evt.n
                if OPTS.verbose then
                    DBG('', s)
                end
                if not (evt.os and OPTS.os) then
                    str = str..s..'\n'
                end
            end
            assert(evt.pre=='input' or evt.pre=='output')
            ASR(ins+outs < 255, me, 'too many events')
        end

        if not OPTS.os then
            str = str..'#define CEU_IN_lower '..(256-ins)..'\n'
        end

        --str = str..'#define CEU_IN_n  '..ins..'\n'
        str = str..'#define CEU_OUT_n '..outs..'\n'

        HH = SUB(HH, '=== EVENTS ===', str)
    end

    -- FUNCTIONS called
    do
        local str = ''
        for id in pairs(ENV.calls) do
            if id ~= '$anon' then
                str = str..'#define CEU_FUN'..id..'\n'
            end
        end
        HH = SUB(HH, '=== FUNCTIONS ===', str)
    end

    -- TUPLES
    do
        local str = ''
        for _,T in pairs(TP.types) do
            if T.tup and #T.tup>0 then
                str = str .. [[
typedef struct {
]]
                if OPTS.tuple_vector then
                    str = str .. [[

#ifdef CEU_VECTOR     /* TODO: check for each tuple */
    u8 vector_offset; /* >0 if this->_N is a vector */
#endif
]]
                end
                for i, t in ipairs(T.tup) do
                    local tmp = TP.toc(t)
                    local tp_id = TP.id(t)
                    if ENV.clss[tp_id] then
                        -- T* => void*
                        -- T** => void**
                        tmp = 'void'..string.match(tmp,'(%*+)')
                    end
                    str = str..'\t'..tmp..' _'..i..';\n'
                end
                if OPTS.tuple_vector then
                    str = str .. [[

#ifdef CEU_VECTOR
    char mem[0];
#endif
]]
                end
                str = str .. [[
} ]]..TP.toc(T)..[[;
]]
            end
        end
        HH = SUB(HH, '=== TUPLES ===', str)
    end
end

-- TEMPLATE.C
do
    CC = FILES.template_c

    CC = SUB(CC, '=== FILENAME ===', OPTS.input)
    --CC = SUB(CC, '^#line.-\n', '')

    CC = SUB(CC, '=== LABELS_ENUM ===', LBLS.code_enum)

    CC = SUB(CC, '=== TOPS_INIT ===',  MEM.tops_init)

    CC = SUB(CC, '=== CONSTRS_C ===',   CODE.constrs)
    CC = SUB(CC, '=== PRES_C ===',      CODE.pres)
    CC = SUB(CC, '=== THREADS_C ===',   CODE.threads)
    CC = SUB(CC, '=== ISRS_C ===',      CODE.isrs)
    CC = SUB(CC, '=== FUNCTIONS_C ===', CODE.functions)
    CC = SUB(CC, '=== STUBS ===',       CODE.stubs)
    CC = SUB(CC, '=== CODE ===',        AST.root.code)
    CC = SUB(CC, '=== NATIVE ===', (OPTS.c_calls and '') or MAIN.native[false])
    CC = SUB(CC, '=== TOPS_C ===',      MEM.tops_c)

    -- IFACES
    if PROPS.has_ifcs then
        local CLSS = {}
        local FLDS = {}
        local EVTS = {}
        local FUNS = {}
        local TRLS = {}
        for _, cls in ipairs(ENV.clss_cls) do
            local clss = {}
            local flds = {}
            local evts = {}
            local funs = {}
            local trls = {}
            for i=1, #ENV.ifcs.flds do
                flds[i] = 0
            end
            for i=1, #ENV.ifcs.evts do
                evts[i] = 0
            end
            for i=1, #ENV.ifcs.funs do
                funs[i] = 'NULL'
            end
            for _, var in ipairs(cls.blk_ifc.vars) do
                if var.pre == 'event' then
                    local i = ENV.ifcs.evts[var.ifc_id]
                    if i then
                        evts[i+1] = var.evt.idx
                    end
                elseif var.pre=='var' or var.pre=='pool' then
                    local i = ENV.ifcs.flds[var.ifc_id]
                    if i then
                        if var.isTmp then
                            flds[i+1] = '0' -- never acessed
                        else
                            flds[i+1] = 'offsetof(CEU_'..cls.id..','..(var.id_ or var.id)..')'
                        end
                    end
                elseif var.pre=='function' then
                    local i = ENV.ifcs.funs[var.ifc_id]
                    if i then
                        funs[i+1] = '(void*)CEU_'..cls.id..'_'..var.id
                    end
                else
                    error 'not implemented'
                end
            end

            -- IFCS_CLSS
            for _,ifc in ipairs(ENV.clss_ifc) do
                clss[#clss+1] = cls.matches[ifc] and 1 or 0
            end

            CLSS[#CLSS+1] = '\t\t{'..table.concat(clss,',')..'}'
            FLDS[#FLDS+1] = '\t\t{'..table.concat(flds,',')..'}'
            EVTS[#EVTS+1] = '\t\t{'..table.concat(evts,',')..'}'
            FUNS[#FUNS+1] = '\t\t{'..table.concat(funs,',')..'}'
            TRLS[#TRLS+1] = '\t\t{'..table.concat(trls,',')..'}'
        end
        CC = SUB(CC, '=== CEU_NCLS ===',     #ENV.clss_cls)
        CC = SUB(CC, '=== IFCS_NIFCS ===',   #ENV.clss_ifc)
        CC = SUB(CC, '=== IFCS_NFLDS ===',   #ENV.ifcs.flds)
        CC = SUB(CC, '=== IFCS_NEVTS ===',   #ENV.ifcs.evts)
        CC = SUB(CC, '=== IFCS_NFUNS ===',   #ENV.ifcs.funs)
        CC = SUB(CC, '=== IFCS_CLSS ===',    table.concat(CLSS,',\n'))
        CC = SUB(CC, '=== IFCS_FLDS ===',    table.concat(FLDS,',\n'))
        CC = SUB(CC, '=== IFCS_EVTS ===',    table.concat(EVTS,',\n'))
        CC = SUB(CC, '=== IFCS_FUNS ===',    table.concat(FUNS,',\n'))
        CC = SUB(CC, '=== IFCS_TRLS ===',    table.concat(TRLS,',\n'))
    end

    if not OPTS.os then
        FILES.ceu_sys_c = SUB(FILES.ceu_sys_c, '#include "ceu_sys.h"',
                                             FILES.ceu_sys_h)
        --CC = SUB(CC, '#include "ceu_types.h"', FILES.ceu_types_h)
        CC = SUB(CC, '#include "ceu_sys.h"',
                     FILES.ceu_sys_h..'\n'..FILES.ceu_sys_c)

        -- TODO: ceu_pool_* => ceu_sys_pool_*
        --FILES.ceu_pool_h = SUB(FILES.ceu_pool_h, '#include "ceu_types.h"',
                                                 --FILES.ceu_types_h)
        FILES.ceu_pool_c = SUB(FILES.ceu_pool_c, '#include "ceu_pool.h"', '')
        CC = SUB(CC, '#include "ceu_pool.h"',
                             FILES.ceu_pool_h..'\n'..FILES.ceu_pool_c)

        -- TODO: ceu_vector_* => ceu_sys_vector_*
        FILES.ceu_vector_h = SUB(FILES.ceu_vector_h, '#include "ceu_sys.h"',
                                                     FILES.ceu_sys_h)
        FILES.ceu_vector_c = SUB(FILES.ceu_vector_c, '#include "ceu_vector.h"', '')
        CC = SUB(CC, '#include "ceu_vector.h"',
                             FILES.ceu_vector_h..'\n'..FILES.ceu_vector_c)
    end

    if OPTS.out_s ~= 'CEU_SIZE' then
        CC = SUB(CC, 'CEU_SIZE', OPTS.out_s)
    end
    if OPTS.out_f ~= 'ceu_app_init' then
        CC = SUB(CC, 'ceu_app_init', OPTS.out_f)
    end

    -- app lua interface
    if OPTS.os_luaifc then
        local ifc = ''
        for i, evt in ipairs(ENV.exts) do
            if string.sub(evt.id,1,1) ~= '_' then
                ifc = ifc ..[[
[ ']]..evt.id..[[' ] = {
    ln  = { ']]..evt.ln[1].."', "..evt.ln[2]..[[ },
    pre = ']]..evt.pre..[[',
    n   = ]]..evt.n..[[,
},
]]
            end
        end
        ifc = 'return {\n'..ifc..'}'
        CC = SUB(CC, '=== APP_LUAIFC ===', string.format("%q",ifc))
    end
end

if OPTS.verbose then
    local T = {
        --mem  = AST.root.mem.max,
        evts = ENV.max_evt+#ENV.exts,
        lbls = #LBLS.list,

        trls = AST.root.trails_n,

        exts      = PROPS.has_exts,
        wclocks   = PROPS.has_wclocks,
        ints      = PROPS.has_ints,
        asyncs    = PROPS.has_asyncs,
        orgs      = PROPS.has_orgs,
        orgs_news = PROPS.has_orgs_news,
        ifcs      = PROPS.has_ifcs,
        ret       = PROPS.has_ret,
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

if OPTS.out_h and OPTS.out_h~='-' then
    local f = assert(io.open(OPTS.out_dir..'/'..OPTS.out_h,'w'))
    f:write(HH)
    f:close()
end
CC = SUB(CC, '=== OUT_H ===', HH)

local out
if OPTS.out_c == '-' then
    out = io.stdout
else
    out = assert(io.open(OPTS.out_dir..'/'..OPTS.out_c,'w'))
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
