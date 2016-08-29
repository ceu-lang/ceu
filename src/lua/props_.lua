local NO = {
    Every = {
        Await_Forever=true, Await_Ext=true, Await_Int=true, Await_Wclock=true,
        Abs_Await=true, Abs_Spawn_Single=true, Every=true, Finalize=true,
    },
    Loop_Pool = {
        Await_Forever=true, Await_Ext=true, Await_Int=true, Await_Wclock=true,
        Abs_Await=true, Every=true, Finalize=true,
    },
}

F = {
    Node = function (me)
        for k, t in pairs(NO) do
            local par = AST.par(me,k)
            if par and t[me.tag] then
                local sub = par
                if par.tag == 'Every' then
                    local _,Await = unpack(AST.asr(par,'', 1,'Loop', 2,'Block', 1,'Stmts'))
                    if AST.is_par(Await,me) then
                        return -- ok
                    end
                end
                ASR(false, me,
                    'invalid `'..AST.tag2id[me.tag]..
                    '´ : unexpected enclosing `'..AST.tag2id[par.tag]..'´')
            end
        end
    end,

    Emit_Wclock = function (me)
        ASR(AST.par(me,'Async') or AST.par(me,'Isr'), me,
            'invalid `emit´ : expected enclosing `async´ or `async/isr´')
    end,

    Escape = 'Continue',
    Break  = 'Continue',
    Continue = function (me)
-- TODO: join all possibilities (thread/isr tb)
        local Async = AST.par(me,'Async')
        if Async then
            ASR(me.outer.__depth > Async.__depth, me,
                'invalid `'..AST.tag2id[me.tag]..'´ : unexpected enclosing `async´')
        end

--[[
        local Every = AST.par(me,'Every')
        if Every then
            ASR(me.outer.__depth > Every.__depth, me,
                'invalid `'..AST.tag2id[me.tag]..'´ : unexpected enclosing `every´')
        end
]]

        local Finalize = AST.par(me,'Finalize')
        if Finalize then
            local _,_,later = unpack(Finalize)
            if AST.is_par(later,me) then
                ASR(me.outer.__depth > Finalize.__depth, me,
                    'invalid `'..AST.tag2id[me.tag]..'´ : unexpected enclosing `finalize´')
            end
        end
    end,

    List_Watching = function (me)
        local watch = AST.par(me,'Loop_Pool') or AST.par(me,'Watching')
        for _, ID in ipairs(me) do
            if ID.tag ~= 'ID_any' then
                ID.dcl.__no_access = watch  -- no access outside watch
            end
        end
    end,
    Set_Alias = function (me)
        local fr, to = unpack(me)
        local watch = AST.par(me,'Loop_Pool') or AST.par(me,'Watching')
        if watch then
            to.info.dcl.__no_access = watch -- no access outside watch
        end
    end,
    ID_int = function (me)
        local no = me.dcl[1]~='&?' and me.dcl.__no_access
        if no then
            ASR(AST.is_par(no, me), me,
                'invalid access to internal identifier "'..me.dcl.id..'"'..
                ' : crossed `'..AST.tag2id[no.tag]..'´'..
                ' ('..no.ln[1]..':'..no.ln[2]..')')
        end
    end,

    --------------------------------------------------------------------------

    Code = function (me)
        local mods,_,body = unpack(me)
        if mods.dynamic and body then
            local Code_Pars = AST.asr(body,'', 1,'Stmts', 1,'Stmts', 1,'Code_Pars')
            for i, dcl in ipairs(Code_Pars) do
                if dcl.mods.dynamic then
                    local _,Type,id = unpack(dcl)
                    local data = AST.get(Type,'',1,'ID_abs')
                    ASR(data and data.dcl.hier, me,
                        'invalid `dynamic´ declaration : parameter #'..i..
                        ' : expected `data´ in hierarchy')
                end
            end
        end
    end,

    __check = function (me)
        local _,num = unpack(me)
        ASR(num, me, 'invalid `data´ declaration : missing `is´')
        for _, sub in ipairs(me.hier.down) do
            F.__check(sub)
        end
    end,

    Data = function (me)
        local _,num = unpack(me)
        if num then
            ASR(me.hier, me, 'invalid `is´ declaration : expected `data´ hierarchy')
            F.__check(DCLS.base(me))
        end
    end,

    --------------------------------------------------------------------------

    Abs_Spawn_Single = '_in_loop_pool',
    Abs_Spawn_Pool   = '_in_loop_pool',
    Emit_Evt         = '_in_loop_pool',
    _in_loop_pool = function (me)
        for n in AST.iter() do
            if n.tag == 'Loop_Pool' then
                n.yields = true
            end
        end
    end,

    Loop_Pool = function (me)
        local _,list,pool = unpack(me)
        local Code = AST.asr(pool.info.dcl,'Pool', 2,'Type', 1,'ID_abs').dcl
        local ret = AST.get(Code,'Code', 3,'Block', 1,'Stmts',
                                         1,'Stmts', 3,'', 2,'Type')
        me.yields = me.yields and ret
            -- if "=>FOREVER" counts as not yielding

        if me.yields then
            for _,ID in ipairs(list) do
                if ID.tag ~= 'ID_any' then
                    ASR(ID.dcl[1] == '&?', me,
                        'invalid declaration : expected `&?´ modifier : yielding `loop´')
                end
            end
        end
    end
}

AST.visit(F)
