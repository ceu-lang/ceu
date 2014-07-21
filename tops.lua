TOPS  = {}    -- holds all clss/exts/nats

local node = AST.node

F = {
    Root_pos = function (me)
        AST.root = node('Root', me.ln, unpack(TOPS))
        return AST.root
    end,

    Dcl_cls_pos = function (me)
        local ifc, id, blk = unpack(me)
        me.is_ifc = ifc
        me.id     = id
        TOPS[#TOPS+1] = me
        TOPS[id] = me
        return node('Nothing', me.ln)
    end,

    Dcl_nat_pos = function (me)
        TOPS[#TOPS+1] = me
        return node('Nothing', me.ln)
    end,
    Dcl_ext_pos = function (me)
        TOPS[#TOPS+1] = me
        return node('Nothing', me.ln)
    end,
}

local function id2ifc (id)
    for _, cls in ipairs(TOPS) do
        local _,id2 = unpack(cls)
        if id2 == id then
            return cls
        end
    end
    return nil
end

AST.visit(F)

-- substitute all Dcl_imp for the referred fields (simplifies later phases)
for _, cls in ipairs(TOPS) do
    if cls.tag=='Dcl_cls' and cls[2]~='Main' then   -- "Main" has no Dcl_imp's
        local dcls1 = cls.blk_ifc[1][1]
        assert(dcls1.tag == 'BlockI')
        for i=1, #dcls1 do
            local imp = dcls1[i]
            if imp.tag == '_Dcl_imp' then
                -- interface A,B,...
                for _,dcl in ipairs(imp) do
                    local ifc = id2ifc(dcl)  -- interface must exist
                    ASR(ifc and ifc[1]==true,
                        imp, 'interface "'..dcl..'" is not declared')
                    local dcls2 = ifc.blk_ifc[1][1]
                    assert(dcls2.tag == 'BlockI')
                    for _, dcl2 in ipairs(dcls2) do
                        assert(dcl2.tag ~= 'Dcl_imp')   -- impossible because I'm going in order
                        local new = AST.copy(dcl2)
                        dcls1[#dcls1+1] = new -- fields from interface should go to the end
                        new.isImp = true      -- to avoid redeclaration warnings indeed
                    end
                end
                table.remove(dcls1, i) -- remove _Dcl_imp
                i = i - 1                    -- repeat
            else
            end
        end
    end
end
