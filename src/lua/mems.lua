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
        me.mems = { me=me, mem='' }
    end,
    Code__POS = function (me)
        local mods,id = unpack(me)
        if not me.is_impl then
            return
        end

        if me.is_dyn_base then
            me.dyns = {}
            me.mems.mem = ''
        else
            if mods.dynamic then
                local t = me.dyn_base.dyns
                t[#t+1] = me.id
            end

            me.mems.mem = [[
typedef struct tceu_code_mem_]]..me.id..[[ {
    tceu_code_mem mem;
    tceu_trl      trails[]]..me.trails_n..[[];
    ]]..me.mems.mem..[[
} tceu_code_mem_]]..me.id..[[;
]]
        end

        MEMS.codes[#MEMS.codes+1] = me.mems
    end,

    Code = function (me)
        local mods, ID, body = unpack(me)

        local Type = AST.asr(body,'Block', 1,'Stmts', 1,'Stmts', 3,'', 2,'Type')
        local ins  = AST.asr(body,'Block', 1,'Stmts', 1,'Stmts', 1,'Code_Pars')
        local mid  = AST.asr(body,'Block', 1,'Stmts', 1,'Stmts', 2,'Code_Pars')

        if (not me.is_impl) or (mods.dynamic and (not me.is_dyn_base)) then
            me.mems.args    = ''
            me.mems.wrapper = ''
            return
        end

        -- args
        me.mems.args = 'typedef struct tceu_code_args_'..me.id..' {\n'

        for i,dcl in ipairs(body.dcls) do
            local is_alias,Type,id2,dim = unpack(dcl)

            local ptr = '' do
                if is_alias then
                    if (dcl.tag~='Evt') and (not TYPES.is_nat_not_plain(TYPES.pop(Type,'?'))) then
                        ptr = ptr..'*'
                    end
                    if i > #ins then
                        ptr = ptr..'*'  -- extra indirection for mid's
                    end
                end
            end

            if dcl.tag == 'Var' then
                if dcl.id~='_ret' or mods.tight then
                    me.mems.args = me.mems.args..[[
]]..TYPES.toc(Type)..ptr..' '..id2..[[;
]]
                end
            elseif dcl.tag == 'Vec' then
                assert(is_alias)
                if TYPES.is_nat(TYPES.get(Type,1)) then
                    me.mems.args = me.mems.args .. [[
]]..TYPES.toc(Type)..' ('..ptr..id2..')['..V(dim)..[[];
]]
                else
                    me.mems.args = me.mems.args .. [[
tceu_vector]]..ptr..' '..id2..[[;
]]
                end

            elseif dcl.tag == 'Evt' then
-- TODO: per Code evts
                    me.mems.args = me.mems.args .. [[
tceu_evt]]..ptr..' '..id2..[[;
]]
            else
                error'bug found'
            end
        end

        local T = {}
        if mods.dynamic then
            for i, item in ipairs(ins) do
                local _,_,_,Type,id = unpack(item)
                local data = AST.get(Type,'',1,'ID_abs')
                if data then
                    local t = {id=id, i=i}
                    local id_super = TYPES.noc(data.dcl.id)
                    t[#t+1] = {
                        'CEU_DATA_'..TYPES.noc(id_super),
                        item.id,
                    }
                    if data.dcl.hier then
                        for _, sub in ipairs(data.dcl.hier.down) do
                            t[#t+1] = {
                                'CEU_DATA_'..TYPES.noc(sub.id),
                                string.gsub(item.id,
                                            '_'..id_super..'$',
                                            '_'..TYPES.noc(sub.id))
                                }
                        end
                    end
                    T[#T+1] = t
                    me.mems.args = me.mems.args .. [[
tceu_ndata _data_]]..i..[[;     /* force multimethod arg data id */
]]
                end
            end
            --assert(#T > 0, 'TODO')
        end

        me.mems.args = me.mems.args..'} tceu_code_args_'..me.id..';\n'

        if mods.tight then
            me.mems.wrapper = [[
static ]]..TYPES.toc(Type)..[[ 
CEU_WRAPPER_]]..me.id..[[ (tceu_stk* stk, tceu_ntrl trlK,
                           tceu_code_args_]]..me.id..[[ ps)
{
    tceu_code_mem_]]..me.id..[[ mem;
    tceu_nlbl lbl;
]]
            if mods.dynamic then
                local switch = F.__multimethods(T,ID)
                me.mems.wrapper = me.mems.wrapper .. switch
            else
                me.mems.wrapper = me.mems.wrapper .. [[
    lbl = ]]..me.lbl_in.id..[[;
]]
            end
            me.mems.wrapper = me.mems.wrapper .. [[
    CEU_STK_LBL((tceu_evt_occ*)&ps, stk, (tceu_code_mem*)&mem, trlK, lbl);
]]
            if not TYPES.check(Type,'void') then
                me.mems.wrapper = me.mems.wrapper..[[
    return ps._ret;
]]
        end
            me.mems.wrapper = me.mems.wrapper..[[
}
]]
        else
            me.mems.wrapper = [[
static void CEU_WRAPPER_]]..me.id..[[ (tceu_stk* stk, tceu_ntrl trlK,
                                       tceu_code_args_]]..me.id..[[ ps,
                                       tceu_code_mem* mem)
{
    tceu_nlbl lbl;
]]
            if mods.dynamic then
                local switch = F.__multimethods(T,ID)
                me.mems.wrapper = me.mems.wrapper .. switch
            else
                me.mems.wrapper = me.mems.wrapper .. [[
    lbl = ]]..me.lbl_in.id..[[;
]]
            end
            me.mems.wrapper = me.mems.wrapper .. [[
    CEU_STK_LBL((tceu_evt_occ*)&ps, stk, mem, trlK, lbl);
}
]]
        end
    end,

    __multimethods = function (T, ID, I, lbl)
        I = I or 1
        lbl = lbl or ''
        local t = T[I]
        if not t then
            local has = DCLS.get(AST.par(AST.iter()(),'Block'), ID..lbl)
            if has then
                return [[
lbl = CEU_LABEL_Code_]]..ID..lbl..[[;
]], true
            else
                return '', false
            end
        elseif #t == 1 then
            return F.__multimethods(T,ID,I+1,lbl..t[1][2])
        else
            local switch = [[
{
    tceu_ndata data_]]..t.i..[[ = ((ps._data_]]..t.i..[[ == CEU_DATA__NONE) ?
                                    ps.]]..t.id..[[->_enum :
                                    ps._data_]]..t.i..[[);
    switch (data_]]..t.i..[[) {
]]
            for i=#t, 1, -1 do
                local v = t[i]
                local id, f = unpack(v)
                local code,has = F.__multimethods(T,ID,I+1,lbl..f)
                switch = switch .. [[
        case ]]..id..[[:
            ]]..code
                if has then
                    switch = switch ..[[
            break;
]]
                end
            end
            switch = switch .. [[
        default:
            ceu_dbg_assert(0);  /* TODO: runtime error message */
    }
]]
            if I > 1 then
                switch = switch .. [[
    break;
]]
            end
            switch = switch .. [[
}
]]

            return switch
        end
    end,

    ---------------------------------------------------------------------------

    Data__PRE = function (me)
        me.id_ = TYPES.noc(me.id)
        me.mems = {
            mem   = '',
            id    = MEMS.datas.id,
            super = (me.hier and me.hier.up and me.hier.up.mems.id) or 'CEU_DATA__NONE',
        }
        MEMS.datas.id = MEMS.datas.id + 1
    end,
    Data__POS = function (me)
        local _,enum = unpack(me)
        local mem = me.mems.mem
        me.mems.mem = [[
typedef struct tceu_data_]]..me.id_..[[ {
]]
        if me.hier or enum then
            me.mems.mem = me.mems.mem..[[
    tceu_ndata _enum;
]]
        end
        me.mems.mem = me.mems.mem..[[
    ]]..mem..[[
} tceu_data_]]..me.id_..[[;
]]..'\n'

        enum = (enum and ' = '..V(enum)) or ''


        MEMS.datas.mems   = MEMS.datas.mems..me.mems.mem
        MEMS.datas.enum   = MEMS.datas.enum..'CEU_DATA_'..me.id_..enum..',\n'
        MEMS.datas.supers = MEMS.datas.supers..me.mems.super..',\n'
    end,

    Var = function (me)
        -- new `?´ type
        local _,tp = unpack(me)
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
                dcl.id_ = dcl.id
                if dcl.id ~= '_ret' then
                    if not AST.par(me,'Data') then
                        dcl.id_ = dcl.id_..'_'..dcl.n
                    end
                    local is_alias, tp = unpack(dcl)
                    local ptr = (is_alias and (not TYPES.is_nat_not_plain(TYPES.pop(tp,'?'))) and '*' or '')
                    mem[#mem+1] = TYPES.toc(tp)..ptr..' '..dcl.id_..';\n'
                end

            -- EVT
            elseif dcl.tag == 'Evt' then
                local is_alias = unpack(dcl)
                if is_alias then
-- TODO: per Code evts
                    MEMS.evts[#MEMS.evts+1] = dcl
                    dcl.id_ = dcl.id
                    if not AST.par(me,'Data') then
                        dcl.id_ = dcl.id..'_'..dcl.n
                    end
                    mem[#mem+1] = 'tceu_evt '..dcl.id_..';\n'
                else
                    local data = AST.par(me,'Data')
                    if data then
                        -- same name for all class hierarchy
                        while true do
                            if not (data.hier and data.hier.up) then
                                break
                            else
                                data = data.hier.up
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
                local is_alias, tp, _, dim = unpack(dcl)
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
                local is_alias, tp, _, dim = unpack(dcl)
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
                local inout, _, id = unpack(dcl)
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
        local Abs_Cons = unpack(me)
        CUR().mem = CUR().mem..'tceu_code_mem_'..Abs_Cons.id..' __mem_'..me.n..';\n'
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
        local max, i, range, body = unpack(me)
        local fr, dir, to, step = unpack(range)
        F.Loop(me)  -- max
        if to.tag ~= 'ID_any' then
            CUR().mem = CUR().mem..'int __lim_'..me.n..';\n'
        end
    end,
}

AST.visit(F)

for _, dcl in ipairs(MEMS.exts) do
    local inout, Typelist = unpack(dcl)

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
    local is_alias,Typelist = unpack(dcl)

    -- enum
    if not is_alias then
        MEMS.evts.enum = MEMS.evts.enum..dcl.id_..',\n'
    end

    -- type
    local mem = [[
typedef struct tceu_event_]]..dcl.id..'_'..dcl.n..[[ {
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
    local me = code.me
    local mods = me and unpack(me)

    MEMS.codes.mems = MEMS.codes.mems..code.mem
    if i < #MEMS.codes then
        MEMS.codes.args = MEMS.codes.args..code.args
        if code.wrapper then
            MEMS.codes.wrappers = MEMS.codes.wrappers..code.wrapper
        end
    end

    if code.me and code.me.dyn_base and code.me.dyn_base.dyn_last==code.me then
        MEMS.codes.mems = MEMS.codes.mems..[[
typedef union {
    tceu_code_mem mem;
]]
        for i, id2 in ipairs(code.me.dyn_base.dyns) do
            MEMS.codes.mems = MEMS.codes.mems..[[
    struct tceu_code_mem_]]..id2..' _'..i..[[;
]]
        end
        MEMS.codes.mems = MEMS.codes.mems..[[
} tceu_code_mem_]]..code.me.dyn_base.id..[[;
]]
    end
end
