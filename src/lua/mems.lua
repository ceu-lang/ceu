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
        datas    = '',
        wrappers = '',
        args     = '',
--[[
        [1] = {
            data    = '',
            wrapper = '',
            args    = '',
        }
]]
    },
}

local function CUR ()
    return (AST.iter'Code'() or AST.root).mems
end

F = {
    ROOT__PRE = function (me)
        me.mems = { data='' }
    end,
    ROOT__POS = function (me)
        me.mems.data = [[
typedef struct tceu_code_data_ROOT {
    ]]..me.mems.data..[[
} tceu_code_data_ROOT;
]]..'\n'
        MEMS.codes[#MEMS.codes+1] = me.mems
    end,

    Code__PRE = function (me)
        local _,_,_,_,_,body = unpack(me)
        if body then
            me.mems = { data='' }
        end
    end,
    Code__POS = function (me)
        local _,_,_,_,_,body = unpack(me)
        if body then
            me.mems.data = [[
typedef struct tceu_code_data_]]..me.id..[[ {
    ]]..me.mems.data..[[
} tceu_code_data_]]..me.id..[[;
]]..'\n'
            MEMS.codes[#MEMS.codes+1] = me.mems
        end
    end,

    Code = function (me)
        local mod,_,id,Typepars_ids, Type, body = unpack(me)
        if not body then return end
        assert(mod == 'code/instantaneous')

        -- args
        me.mems.args = 'typedef struct tceu_code_args_'..id..' {\n'
        if not TYPES.check(Type,'void') then
            me.mems.args = me.mems.args..'    '..TYPES.toc(Type)..' _ret;\n'
        end

        -- wrapper
        local args, ps = {}, {}

        for _,Typepars_ids_item in ipairs(Typepars_ids) do
            local a,is_alias,c,Type,id2 = unpack(Typepars_ids_item)
            assert(a=='var' and c==false)
            local ptr = (is_alias and '*' or '')

            -- args
            me.mems.args = me.mems.args..'    '..TYPES.toc(Type)..ptr..' '..id2..';\n'

            -- wrapper
            args[#args+1] = TYPES.toc(Type)..ptr..' '..id2
            ps[#ps+1] = 'ps.'..id2..' = '..id2..';'
        end

        -- args
        me.mems.args = me.mems.args..'} tceu_code_args_'..id..';\n'

        -- wrapper
        if #args > 0 then
            args = ','..table.concat(args,', ')
            ps   = table.concat(ps,'\n')..'\n'
        else
            args = ''
            ps   = ''
        end
        me.mems.wrapper = [[
static ]]..TYPES.toc(Type)..[[ 
CEU_WRAPPER_]]..id..[[ (tceu_stk* stk, tceu_trl* trl, tceu_nlbl lbl ]]..args..[[)
{
    tceu_code_args_]]..id..[[ ps;
]]
        if ps ~= '' then
            me.mems.wrapper = me.mems.wrapper..ps
        end
        me.mems.wrapper = me.mems.wrapper..[[
    CEU_STK_LBL(stk, trl, lbl, (tceu_evt*)&ps);
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

    Stmts__PRE = function (me)
        CUR().data = CUR().data..'union {\n'
    end,
    Stmts__POS = function (me)
        CUR().data = CUR().data..'};\n'
    end,

    Await_Wclock = function (me)
        CUR().data = CUR().data..'s32 __wclk_'..me.n..';\n'
    end,

    ---------------------------------------------------------------------------

    Par_Or__PRE  = 'Par__PRE',
    Par_And__PRE = 'Par__PRE',
    Par__PRE = function (me)
        CUR().data = CUR().data..'struct {\n'
    end,
    Par_Or__POS  = 'Par__POS',
    Par_And__POS = 'Par__POS',
    Par__POS = function (me)
        CUR().data = CUR().data..'};\n'
    end,

    Par_And = function (me)
        for i=1, #me do
            CUR().data = CUR().data..'u8 __and_'..me.n..'_'..i..': 1;\n'
        end
    end,

    ---------------------------------------------------------------------------

    Loop_Num__PRE = 'Loop__PRE',
    Loop__PRE = function (me)
        CUR().data = CUR().data..'struct {\n'
    end,
    Loop_Num__POS = 'Loop__POS',
    Loop__POS = function (me)
        CUR().data = CUR().data..'};\n'
    end,

    Loop = function (me)
        local max = unpack(me)
        if max then
            CUR().data = CUR().data..'int __max_'..me.n..';\n'
        end
    end,
    Loop_Num = function (me)
        local max, i, fr, dir, to, step, body = unpack(me)
        F.Loop(me)  -- max
        if to.tag ~= 'ID_any' then
            CUR().data = CUR().data..'int __lim_'..me.n..';\n'
        end
    end,

    ---------------------------------------------------------------------------

    Block__PRE = function (me)
        local data = {}
        for _, dcl in ipairs(me.dcls)
        do
            -- VAR
            if dcl.tag == 'Var' then
                if dcl.id ~= '_ret' then
                    dcl.id_ = dcl.id..'_'..dcl.n
                    local tp, is_alias = unpack(dcl)
                    local ptr = (is_alias and '*' or '')
                    data[#data+1] = TYPES.toc(tp)..ptr..' '..dcl.id_..';\n'
                end

            -- EVT
            elseif dcl.tag == 'Evt' then
                local _, is_alias = unpack(dcl)
                if is_alias then
-- TODO: per Code evts
                    MEMS.evts[#MEMS.evts+1] = dcl
                    dcl.id_ = dcl.id..'_'..dcl.n
                    data[#data+1] = 'tceu_nevt '..dcl.id_..';\n'
                else
                    MEMS.evts[#MEMS.evts+1] = dcl
                    dcl.id_ = string.upper('CEU_EVENT_'..dcl.id..'_'..dcl.n)
                end

            -- VEC
            elseif dcl.tag == 'Vec' then
                local tp, is_alias, dim = unpack(dcl)
                dcl.id_ = dcl.id..'_'..dcl.n
                local ptr = (is_alias and '*' or '')
                data[#data+1] = TYPES.toc(tp)..' ('..ptr..dcl.id_..')['..V(dim)..'];\n'

            -- EXT
            elseif dcl.tag == 'Ext' then
                local _, inout, id = unpack(dcl)
                MEMS.exts[#MEMS.exts+1] = dcl
                dcl.id_ = string.upper('CEU_'..inout..'_'..id)
            end
        end
        CUR().data = CUR().data..'struct {\n'..table.concat(data)
    end,
    Block__POS = function (me)
        CUR().data = CUR().data..'};\n'
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
    local data = 'typedef struct tceu_'..inout..'_'..dcl.id..' {\n'
    for i,Type in ipairs(Typelist) do
        data = data..'    '..TYPES.toc(Type)..' _'..i..';\n'
    end
    data = data..'} tceu_'..inout..'_'..dcl.id..';\n'

    MEMS.exts.types = MEMS.exts.types..data
end

for _, dcl in ipairs(MEMS.evts) do
    local Typelist = unpack(dcl)

    -- enum
    local _,is_alias = unpack(dcl)
    if not is_alias then
        MEMS.evts.enum = MEMS.evts.enum..dcl.id_..',\n'
    end

    -- type
    local data = 'typedef struct tceu_event_'..dcl.id..'_'..dcl.n..' {\n'
    for i,Type in ipairs(Typelist) do
        data = data..'    '..TYPES.toc(Type)..' _'..i..';\n'
    end
    data = data..'} tceu_event_'..dcl.id..'_'..dcl.n..';\n'
    MEMS.evts.types = MEMS.evts.types..data
end

for i, code in ipairs(MEMS.codes) do
    MEMS.codes.datas = MEMS.codes.datas..code.data
    if i < #MEMS.codes then
        MEMS.codes.wrappers = MEMS.codes.wrappers..code.wrapper
        MEMS.codes.args     = MEMS.codes.args..code.args
    end
end
