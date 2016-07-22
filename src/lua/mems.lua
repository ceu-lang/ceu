MEMS = {
    exts = {
        types       = '',
        enum_input  = '',
        enum_output = '',
    },
    evts = {
        types = '',
        enum  = '',
    },
    codes = {
        mems     = '',
        wrappers = '',
        args     = '',
--[[
        [1] = {
            mem     = '',
            wrapper = '',
            args    = '',
        }
]]
    },
    datas = {
        id     = 1,
        mems   = '',
        enum   = '',
        supers = '',
    },
    opts = {
        -- avoids duplications
        --[TYPES.tostring(tp)] = true,
    },
}

local function CUR ()
    return (AST.iter'Code'() or AST.iter'Data'() or AST.root).mems
end

F = {
    ROOT__PRE = function (me)
        me.mems = { mem='' }
    end,
    ROOT__POS = function (me)
        me.mems.mem = [[
typedef struct tceu_code_mem_ROOT {
    tceu_code_mem mem;
    tceu_trl      trails[]]..me.trails_n..[[];
    ]]..me.mems.mem..[[
} tceu_code_mem_ROOT;
]]..'\n'
        MEMS.codes[#MEMS.codes+1] = me.mems
    end,

    ---------------------------------------------------------------------------

    Code__PRE = function (me)
        local _,_,_,_,_,_,body = unpack(me)
        if body then
            me.mems = { mem='' }
        end
    end,
    Code__POS = function (me)
        local _,_,_,_,_,_,body = unpack(me)
        if body then
            me.mems.mem = [[
typedef struct tceu_code_mem_]]..me.id..[[ {
    tceu_code_mem mem;
    tceu_trl      trails[]]..me.trails_n..[[];
    ]]..me.mems.mem..[[
} tceu_code_mem_]]..me.id..[[;
]]..'\n'
            MEMS.codes[#MEMS.codes+1] = me.mems
        end
    end,

    Code = function (me)
        local mod,_,id, ins, mid, Type, body = unpack(me)
        if not body then return end

        -- args
        me.mems.args = 'typedef struct tceu_code_args_'..id..' {\n'
        if mod=='code/tight' and (not TYPES.check(Type,'void')) then
            -- returns immediatelly, uses an extra field for the return value
            me.mems.args = me.mems.args..'    '..TYPES.toc(Type)..' _ret;\n'
        end

        -- insert in "stmts" all parameters "ins"/"mid"
        local ins_mid = {} do
            AST.asr(ins,'Typepars_ids')
            for _, v in ipairs(ins) do ins_mid[#ins_mid+1]=v end
            if mid then
                AST.asr(mid,'Typepars_ids')
                for _, v in ipairs(mid) do ins_mid[#ins_mid+1]=v end
            end
        end

        for i,item in ipairs(ins_mid) do
            local kind,is_alias,dim,Type,id2 = unpack(item)
            local ptr = (is_alias and (not TYPES.is_nat_not_plain(TYPES.pop(Type,'?'))) and '*' or '')
            if i > #ins then
                ptr = ptr..'*'  -- extra indirection for mid's
            end
            if kind == 'var' then
                assert(dim == false)
                me.mems.args = me.mems.args..'    '..TYPES.toc(Type)..ptr..' '..id2..';\n'
            elseif kind == 'vector' then
                assert(is_alias)
                if TYPES.is_nat(TYPES.get(Type,1)) then
                    me.mems.args = me.mems.args .. [[
]]..TYPES.toc(Type)..' ('..ptr..id2..')['..V(dim)..[[];
]]
                else
                    if dim.is_const then
                        me.mems.args = me.mems.args .. [[
]]..TYPES.toc(Type)..' '..id2..'_buf['..V(dim)..[[];
]]
                    end
                    me.mems.args = me.mems.args .. [[
tceu_vector]]..ptr..' '..id2..[[;
]]
                end

            else
                error'bug found'
            end
        end
        me.mems.args = me.mems.args..'} tceu_code_args_'..id..';\n'

        if mod == 'code/await' then
            return
        end

        me.mems.wrapper = [[
static ]]..TYPES.toc(Type)..[[ 
CEU_WRAPPER_]]..id..[[ (tceu_stk* stk, tceu_ntrl trlK,
                        tceu_nlbl lbl, tceu_code_args_]]..id..[[ ps)
{
    tceu_code_mem_]]..id..[[ mem;
    CEU_STK_LBL((tceu_evt*)&ps, stk, (tceu_code_mem*)&mem, trlK, lbl);
]]
        if not TYPES.check(Type,'void') then
            me.mems.wrapper = me.mems.wrapper..[[
    return ps._ret;
]]
        end
        me.mems.wrapper = me.mems.wrapper..[[
}
]]
    end,

    ---------------------------------------------------------------------------

    Data__PRE = function (me)
        me.id_ = string.gsub(me.id,'%.','_')
        me.mems = {
            mem   = '',
            id    = MEMS.datas.id,
            super = (me.super and me.super.mems.id) or 'CEU_DATA__NONE',
        }
        MEMS.datas.id = MEMS.datas.id + 1
    end,
    Data__POS = function (me)
        local mem = me.mems.mem
        me.mems.mem = [[
typedef struct tceu_data_]]..me.id_..[[ {
]]
        if me.in_hier then
            me.mems.mem = me.mems.mem..[[
    tceu_data data;
]]
        end
        me.mems.mem = me.mems.mem..[[
    ]]..mem..[[
} tceu_data_]]..me.id_..[[;
]]..'\n'
        MEMS.datas.mems   = MEMS.datas.mems..me.mems.mem
        MEMS.datas.enum   = MEMS.datas.enum..'CEU_DATA_'..me.id_..',\n'
        MEMS.datas.supers = MEMS.datas.supers..me.mems.super..',\n'
    end,

    Var = function (me)
        -- new `?´ type
        local tp = unpack(me)
        if not TYPES.check(tp,'?') then
            return
        end

        local str = TYPES.tostring(tp)
        if not MEMS.opts[str] then
            MEMS.opts[str] = true
            local cc = TYPES.toc(tp)
            local c = TYPES.toc(TYPES.pop(tp,'?'))
            local opt = ''
            if TYPES.is_nat_not_plain(TYPES.pop(tp,'?')) then
                opt = opt..[[
static ]]..cc..' CEU_OPTION_'..cc..' ('..cc..[[ opt, char* file, int line) {
ceu_callback_assert_msg_ex(opt != NULL, "value is not set", file, line);
return opt;
}
]]
            else
                opt = opt..[[
typedef struct ]]..cc..[[ {
bool      is_set;
]]..c..[[ value;
} ]]..cc..[[;

static ]]..cc..'* CEU_OPTION_'..cc..' ('..cc..[[* opt, char* file, int line) {
ceu_callback_assert_msg_ex(opt->is_set, "value is not set", file, line);
return opt;
}
]]
            end
            MEMS.datas.mems = MEMS.datas.mems..opt
        end
    end,

    ---------------------------------------------------------------------------

    Block__PRE = function (me)
        local mem = {}
        for _, dcl in ipairs(me.dcls) do
            if dcl.ln then
                if CEU.opts.ceu_line_directives then
                    mem[#mem+1] = [[
#line ]]..dcl.ln[2]..' "'..dcl.ln[1]..[["
]]
                end
            end

            -- VAR
            if dcl.tag == 'Var' then
                if dcl.id ~= '_ret' then
                    dcl.id_ = dcl.id
                    if not AST.par(me,'Data') then
                        dcl.id_ = dcl.id_..'_'..dcl.n
                    end
                    local tp, is_alias = unpack(dcl)
                    local ptr = (is_alias and (not TYPES.is_nat_not_plain(TYPES.pop(tp,'?'))) and '*' or '')
                    mem[#mem+1] = TYPES.toc(tp)..ptr..' '..dcl.id_..';\n'
                end

            -- EVT
            elseif dcl.tag == 'Evt' then
                local _, is_alias = unpack(dcl)
                if is_alias then
-- TODO: per Code evts
                    MEMS.evts[#MEMS.evts+1] = dcl
                    dcl.id_ = dcl.id
                    if not AST.par(me,'Data') then
                        dcl.id_ = dcl.id..'_'..dcl.n
                    end
                    mem[#mem+1] = 'tceu_nevt '..dcl.id_..';\n'
                else
                    local data = AST.par(me,'Data')
                    if data then
                        -- same name for all class hierarchy
                        while true do
                            if not data.super then
                                break
                            else
                                data = data.super
                            end
                        end
                        dcl.id_ = string.upper('CEU_EVENT'..'_'..data.id..'_'..dcl.id)
                        if data == AST.par(me,'Data') then
                            -- avoids duplication with super
                            MEMS.evts[#MEMS.evts+1] = dcl
                        end
                    else
                        dcl.id_ = string.upper('CEU_EVENT_'..dcl.id..'_'..dcl.n)
                        MEMS.evts[#MEMS.evts+1] = dcl
                    end
                end

            -- VEC
            elseif dcl.tag == 'Vec' then
                local tp, is_alias, dim = unpack(dcl)
                local ptr = (is_alias and '*' or '')
                dcl.id_ = dcl.id
                if not AST.par(me,'Data') then
                    dcl.id_ = dcl.id..'_'..dcl.n
                end
                if TYPES.is_nat(TYPES.get(tp,1)) then
                    mem[#mem+1] = [[
]]..TYPES.toc(tp)..' ('..ptr..dcl.id_..')['..V(dim)..[[];
]]
                else
                    if dim.is_const and (not is_alias) then
                        mem[#mem+1] = [[
]]..TYPES.toc(tp)..' '..dcl.id_..'_buf['..V(dim)..[[];
]]
                    end
                    mem[#mem+1] = [[
tceu_vector]]..ptr..' '..dcl.id_..[[;
]]
                end

            -- POOL
            elseif dcl.tag == 'Pool' then
                local tp, is_alias, dim = unpack(dcl)
                local ptr = (is_alias and '*' or '')
                dcl.id_ = dcl.id
                if not AST.par(me,'Data') then
                    dcl.id_ = dcl.id..'_'..dcl.n
                end
                if dim.is_const and (not is_alias) then
                    mem[#mem+1] = [[
tceu_code_mem_dyn* ]]..dcl.id_..'_queue['..V(dim)..[[];
byte ]]..dcl.id_..[[_buf[
    (sizeof(tceu_code_mem_dyn)+sizeof(]]..TYPES.toc(tp)..')) * '..V(dim)..[[
];
]]
                end
                mem[#mem+1] = [[
tceu_pool_pak]]..ptr..' '..dcl.id_..[[;
]]

            -- EXT
            elseif dcl.tag == 'Ext' then
                local _, inout, id = unpack(dcl)
                MEMS.exts[#MEMS.exts+1] = dcl
                dcl.id_ = string.upper('CEU_'..inout..'_'..id)
            end
        end
        if AST.par(me,'Data') then
            CUR().mem = CUR().mem..table.concat(mem)
        else
            CUR().mem = CUR().mem..'struct {\n'..table.concat(mem)
        end
    end,
    Block__POS = function (me)
        if not AST.par(me,'Data') then
            CUR().mem = CUR().mem..'};\n'
        end
    end,

    ---------------------------------------------------------------------------

    Stmts__PRE = function (me)
        if not AST.par(me,'Data') then
            CUR().mem = CUR().mem..'union {\n'
        end
    end,
    Stmts__POS = function (me)
        if not AST.par(me,'Data') then
            CUR().mem = CUR().mem..'};\n'
        end
    end,

    Await_Wclock = function (me)
        CUR().mem = CUR().mem..'s32 __wclk_'..me.n..';\n'
    end,

    Abs_Await = function (me)
        local dcl = AST.asr(me,'', 1,'Abs_Cons', 1,'ID_abs').dcl
        CUR().mem = CUR().mem..'tceu_code_mem_'..dcl.id..' __mem_'..me.n..';\n'
    end,

    ---------------------------------------------------------------------------

    Par_Or__PRE  = 'Par__PRE',
    Par_And__PRE = 'Par__PRE',
    Par__PRE = function (me)
        CUR().mem = CUR().mem..'struct {\n'
    end,
    Par_Or__POS  = 'Par__POS',
    Par_And__POS = 'Par__POS',
    Par__POS = function (me)
        CUR().mem = CUR().mem..'};\n'
    end,

    Par_And = function (me)
        for i=1, #me do
            CUR().mem = CUR().mem..'u8 __and_'..me.n..'_'..i..': 1;\n'
        end
    end,

    ---------------------------------------------------------------------------

    Loop_Num__PRE = 'Loop__PRE',
    Loop__PRE = function (me)
        CUR().mem = CUR().mem..'struct {\n'
    end,
    Loop_Num__POS = 'Loop__POS',
    Loop__POS = function (me)
        CUR().mem = CUR().mem..'};\n'
    end,

    Loop = function (me)
        local max = unpack(me)
        if max then
            CUR().mem = CUR().mem..'int __max_'..me.n..';\n'
        end
    end,
    Loop_Num = function (me)
        local max, i, fr, dir, to, step, body = unpack(me)
        F.Loop(me)  -- max
        if to.tag ~= 'ID_any' then
            CUR().mem = CUR().mem..'int __lim_'..me.n..';\n'
        end
    end,
}

AST.visit(F)

for _, dcl in ipairs(MEMS.exts) do
    local Typelist, inout = unpack(dcl)

    -- enum
    if inout == 'input' then
        MEMS.exts.enum_input  = MEMS.exts.enum_input..dcl.id_..',\n'
    else
        MEMS.exts.enum_output = MEMS.exts.enum_output..dcl.id_..',\n'
    end

    -- type
    local mem = 'typedef struct tceu_'..inout..'_'..dcl.id..' {\n'
    for i,Type in ipairs(Typelist) do
        mem = mem..'    '..TYPES.toc(Type)..' _'..i..';\n'
    end
    mem = mem..'} tceu_'..inout..'_'..dcl.id..';\n'

    MEMS.exts.types = MEMS.exts.types..mem
end

for _, dcl in ipairs(MEMS.evts) do
    local Typelist = unpack(dcl)

    -- enum
    local _,is_alias = unpack(dcl)
    if not is_alias then
        MEMS.evts.enum = MEMS.evts.enum..dcl.id_..',\n'
    end

    -- type
    local mem = [[
typedef struct tceu_event_]]..dcl.id..'_'..dcl.n..[[ {
    tceu_code_mem* mem;
]]
    for i,Type in ipairs(Typelist) do
        mem = mem..'    '..TYPES.toc(Type)..' _'..i..';\n'
    end
    mem = mem..[[
} tceu_event_]]..dcl.id..'_'..dcl.n..[[;
]]
    MEMS.evts.types = MEMS.evts.types..mem
end

for i, code in ipairs(MEMS.codes) do
    MEMS.codes.mems = MEMS.codes.mems..code.mem
    if i < #MEMS.codes then
        MEMS.codes.args = MEMS.codes.args..code.args
        if code.wrapper then
            MEMS.codes.wrappers = MEMS.codes.wrappers..code.wrapper
        end
    end
end
