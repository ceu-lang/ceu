local function asr (e, cnds, err)
    ASR(e.loc, e, 'invalid '..err..' : expected name expression')
    local ok do
        for _, tag in ipairs(cnds) do
            if tag == e.loc.tag then
                ok = true
                break
            end
        end
    end
    if err then
        ASR(ok, e,
            'invalid '..err..' : '..
            'unexpected context for '..AST.tag2id[e.loc.tag]
                                     ..' "'..e.loc.id..'"')
    else
        ASR(ok, e,
            'unexpected context for '..AST.tag2id[e.loc.tag]
                                     ..' "'..e.loc.id..'"')
    end
end

F = {
    -- vec[i]
    ['Exp_idx'] = function (me)
        local _,vec,idx = unpack(me)
        asr(vec, {'Nat','Vec','Var'}, 'vector')
        if idx.loc then
            asr(idx, {'Nat','Var'}, 'index')
        end
    end,

    -- $/$$vec
    ['Exp_$$'] = 'Exp_$',
    ['Exp_$'] = function (me)
        local op,vec = unpack(me)
        asr(vec, {'Vec'}, 'operand to `'..op..'´')
    end,

    -- &id
    ['Exp_1&'] = function (me)
        local _,e = unpack(me)
        assert(e.loc or e.tag=='Exp_Call')
    end,

    ['Exp_1*'] = function (me)
        local op,e = unpack(me)
        asr(e, {'Nat','Var','Pool'}, 'operand to `'..op..'´')
DBG('TODO: remove pool')
    end,
    ['Exp_&&'] = function (me)
        local op,e = unpack(me)
        asr(e, {'Nat','Var','Pool'}, 'operand to `'..op..'´')
    end,

    Exp_as = 'Exp_is',
    Exp_is = function (me)
        local op,e = unpack(me)
        if e.loc then
            asr(e, {'Nat','Var','Pool'}, 'operand to `'..op..'´')
        end
    end,

    Exp_Call = function (me)
        local _, e = unpack(me)
        asr(e, {'Nat','Code'}, 'call')
    end,
    Explist = function (me)
        for _, e in ipairs(me) do
            if e.loc then
                asr(e, {'Nat','Var'}, 'argument to call')
            end
        end
    end,

    ['Exp_!='] = 'Exp_==',
    ['Exp_=='] = function (me)
        local op, e1, e2 = unpack(me)
        if e1.loc then
            asr(e1, {'Nat','Var'}, 'operand to `'..op..'´')
        end
        if e2.loc then
            asr(e2, {'Nat','Var'}, 'operand to `'..op..'´')
        end
    end,

    --------------------------------------------------------------------------

    _Data_Explist = function (me)
        for _, e in ipairs(me) do
            if e.loc then
                asr(e, {'Nat','Var'}, 'argument to constructor')
            end
        end
    end,

    --------------------------------------------------------------------------

    Set_Exp = function (me)
        local fr, to = unpack(me)
        asr(to, {'Nat','Var','Pool'}, 'assignment')
        if fr.loc then
            asr(fr, {'Nat','Var'}, 'assignment')
        end
    end,

    Set_Vec = function (me)
        local fr,to = unpack(me)

        -- vec = ...
        asr(to, {'Vec'}, 'constructor')

        -- ... = []..vec
        if fr.tag == '_Vec_New' then
DBG'TODO: _Vec_New'
            for _, e in ipairs(fr) do
                if e.loc then
                    asr(e, {'Vec'}, 'constructor')
                end
            end
        end
    end,

    Set_Lua = function (me)
        local _,to = unpack(me)
        asr(to, {'Nat','Var'}, 'Lua assignment')
    end,

    Set_Data = function (me)
        local Data_New, Exp_Name = unpack(me)
        local is_new = unpack(Data_New)
        if is_new then
            -- pool = ...
            asr(Exp_Name, {'Var','Pool'}, 'constructor')
        else
            asr(Exp_Name, {'Var'}, 'constructor')
        end
    end,

    --------------------------------------------------------------------------

    _Pause    = 'Await_Evt',
    Emit_Evt  = 'Await_Evt',
    Await_Evt = function (me, tag)
        local Exp_Name = unpack(me)
        local tag do
            if me.tag == 'Await_Evt' then
                tag = 'await'
            elseif me.tag == 'Emit_Evt' then
                tag = 'emit'
            else
                assert(me.tag == '_Pause')
                tag = 'pause/if'
            end
        end
        if me.tag == 'Await_Evt' then
            asr(Exp_Name, {'Var','Evt','Pool'}, '`'..tag..'´')
        else
            asr(Exp_Name, {'Evt'}, '`'..tag..'´')
        end
    end,

    Varlist = function (me)
        local cnds = {'Nat','Var'}
        if string.sub(me.__par.tag,1,7) == '_Async_' then
            cnds[#cnds+1] = 'Vec'
        end
        for _, var in ipairs(me) do
            asr(var, cnds, 'variable')
        end
    end,

    Do = function (me)
        local _,_,e = unpack(me)
        if e then
            asr(e, {'Nat','Var'}, 'assignment')
        end
    end,
}
AST.visit(F)
