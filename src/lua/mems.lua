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
        mems = '',
        enum = '',
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
        local _,_,_,_,_,body = unpack(me)
        if body then
            me.mems = { mem='' }
        end
    end,
    Code__POS = function (me)
        local _,_,_,_,_,body = unpack(me)
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
        local mod,_,id,Typepars_ids, Type, body = unpack(me)
        if not body then return end

        -- args
        me.mems.args = 'typedef struct tceu_code_args_'..id..' {\n'
        if mod=='code/instantaneous' and (not TYPES.check(Type,'void')) then
            -- returns immediatelly, uses an extra field for the return value
            me.mems.args = me.mems.args..'    '..TYPES.toc(Type)..' _ret;\n'
        end
        for _,Typepars_ids_item in ipairs(Typepars_ids) do
            local a,is_alias,c,Type,id2 = unpack(Typepars_ids_item)
            assert(a=='var' and c==false)
            local ptr = (is_alias and '*' or '')
            me.mems.args = me.mems.args..'    '..TYPES.toc(Type)..ptr..' '..id2..';\n'
        end
        me.mems.args = me.mems.args..'} tceu_code_args_'..id..';\n'

        if mod == 'code/delayed' then
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
        me.mems = { mem='' }
    end,
    Data__POS = function (me)
        me.mems.mem = [[
typedef struct tceu_data_]]..me.id_..[[ {
    tceu_data data;
    ]]..me.mems.mem..[[
} tceu_data_]]..me.id_..[[;
]]..'\n'
        MEMS.datas.mems = MEMS.datas.mems..me.mems.mem
        MEMS.datas.enum = MEMS.datas.enum..'CEU_DATA_'..me.id_..',\n'
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

    ---------------------------------------------------------------------------

    Block__PRE = function (me)
        local mem = {}
        for _, dcl in ipairs(me.dcls)
        do
            -- VAR
            if dcl.tag == 'Var' then
                if dcl.id ~= '_ret' then
                    dcl.id_ = dcl.id
                    if not AST.par(me,'Data') then
                        dcl.id_ = dcl.id_..'_'..dcl.n
                    end
                    local tp, is_alias = unpack(dcl)
                    local ptr = (is_alias and '*' or '')
                    mem[#mem+1] = TYPES.toc(tp)..ptr..' '..dcl.id_..';\n'
                end

            -- EVT
            elseif dcl.tag == 'Evt' then
                local _, is_alias = unpack(dcl)
                if is_alias then
-- TODO: per Code evts
                    MEMS.evts[#MEMS.evts+1] = dcl
                    dcl.id_ = dcl.id..'_'..dcl.n
                    mem[#mem+1] = 'tceu_nevt '..dcl.id_..';\n'
                else
                    MEMS.evts[#MEMS.evts+1] = dcl
                    dcl.id_ = string.upper('CEU_EVENT_'..dcl.id..'_'..dcl.n)
                end

            -- VEC
            elseif dcl.tag == 'Vec' then
                local tp, is_alias, dim = unpack(dcl)
                dcl.id_ = dcl.id..'_'..dcl.n
                local ptr = (is_alias and '*' or '')
                mem[#mem+1] = TYPES.toc(tp)..' ('..ptr..dcl.id_..')['..V(dim)..'];\n'

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
    local mem = 'typedef struct tceu_event_'..dcl.id..'_'..dcl.n..' {\n'
    for i,Type in ipairs(Typelist) do
        mem = mem..'    '..TYPES.toc(Type)..' _'..i..';\n'
    end
    mem = mem..'} tceu_event_'..dcl.id..'_'..dcl.n..';\n'
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
