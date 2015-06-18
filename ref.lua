function NODE2BLK (n)
    return n.fst and n.fst.blk or
           n.fst and n.fst.var and n.fst.var.blk or
           MAIN.blk_ifc
end

F = {
    -- before Var
    Set_pre = function (me)
        local _, _, _, to = unpack(me)
        local TO = (to.tag=='VarList' and to) or {to}
        for _, to in ipairs(TO) do
            F.__Set_pre(me, to)
        end
    end,
    __Set_pre = function (me, TO)
        local _, set, fr, _ = unpack(me)
        to = TO
        if not to.tp.ref then
            return
        end
        assert(to.lst.var, 'bug found')
        local cls = CLS()

        -- Detect source of assignment/binding:
        --  - internal:  assignment from body to normal variable (v, this.v)
        --  - constr:    assignment from constructor to interface variable (this.v)
        --  - interface: assignment from interface (var int v = <default value>)
        --  - outer:     assignment from outer body (t.v)

        local constr    = AST.par(me, 'Dcl_constr')
              constr    = constr and (constr.cls.blk_ifc.vars[to.lst.var.id]==to.lst.var) and constr
        local global    = to.tag=='Field' and to.org.cls.id=='Global' and cls.id=='Main'
        local outer     = (not constr) and to.tag=='Field' and to.org.cls~=cls and (not global)
        local interface = AST.par(me, 'BlockI')
        local internal  = not (constr or outer or interface)

        -- IGNORE NON-FIRST ASSIGNMENTS
        --  class T with
        --      var int& ref;
        --  do
        --      this.ref = <...>;   // this is not a first assignment
        --  end
        if (not constr) and to.lst.var.blk==cls.blk_ifc and (cls.id~='Main') then
            return
        end

        -- refuse first assignment inside loop with declaration outside it:
        --      var t& v;
        --      loop do
        --          v = <...>;      // rebindings are forbidden
        --          <...>
        --      end
        -- accept if inside a constructor:
        --      loop do
        --          var T with
        --              this.v = <...>;
        --          end;
        --      end
        local loop = AST.par(me, 'Loop')
        if loop then
            if (not to.lst.var.bind) and (not AST.par(me,'Dcl_constr')) then
                ASR(AST.isParent(loop, to.lst.var.blk), me,
                    'reference declaration and first binding cannot be separated by loops')
            end
        end

        -- ALREADY HAS INTERNAL BINDING

        if to.lst.var.bind=='internal' then
            assert(cls.id=='Main' or (to.blk ~= cls.blk_ifc))

        -- NO INTERNAL BINDING
        --  first assignment

        else
            local if_ = AST.par(me,'If')
            if if_ and (if_.__depth > to.lst.var.blk.__depth) and
               ((not constr) or if_.__depth > constr.__depth) and
               ((not to.lst.var.bind) or to.lst.var.bind=='partial')
            then else
                if_ = false
            end
            if if_ and AST.isParent(if_[2],me) then
                -- do not bind yet if inside a true branch of an if,
                -- force the else part to also set byRef
                to.lst.var.bind = 'partial'

            -- set source of binding
            elseif internal then
                to.lst.var.bind = 'internal'
                assert(cls.id=='Main' or (to.blk ~= cls.blk_ifc))
            elseif constr then
                if not to.lst.var.bind then
                    to.lst.var.bind = 'constr'
                end
                -- mark this field assigned inside this constructor
                -- later (Dcl_constr), we check if all unbounded fields have being assigned
                constr.__bounded = constr.__bounded or {}
                constr.__bounded[to.lst.var] = true
            elseif interface then
                to.lst.var.bind = 'interface'
            end

            -- save binds from if/else, check after
            if if_ then
                local T = if_.__ref_bounded or {}
                if_.__ref_bounded = T
                local t = T[to.lst.var] or {}
                T[to.lst.var] = t
                t[#t+1] = me
            end

            -- first assignment (and only first assignment) is byRef
            to.byRef = true
            fr.byRef = true

            -- refuses first assignment from constants and dereferences:
            -- var int& i = 1;
            -- var int& i = *p;
            if (not fr.tp.ref) then
                local adt_pool = fr.lst.var and fr.lst.var.adt_par and
                                 (fr.lst.var == fr.lst.var.adt_par.adt_pool)
                ASR(fr.lval or fr.tag=='Op1_&' or fr.tag=='Op2_call' or
                        (fr.lst and (fr.lst.tag=='Outer' or
                                     fr.lst.var and (fr.lst.var.cls or adt_pool))),
                                               -- orgs/adts are not lval
                    me, 'invalid attribution (not a reference)')
                ASR(fr.tag ~= 'Op1_*', me, 'invalid attribution')
            end

            -- refuses first assignment from awaits:
            -- var int& i = await <...>;
            ASR(set~='await', me, 'invalid attribution')

            -- check scopes
-- TODO: this code is duplicated with "fin.lua"
            local fr_blk = NODE2BLK(fr)
            local to_blk = NODE2BLK(to)
            local org_blk
            if to.tag=='Field' and to[2].tag=='This' then
                local constr = AST.par(me, 'Dcl_constr')
                if constr then
                    local dcl = AST.par(constr, 'Dcl_var')
                    if dcl then
                        org_blk = dcl.var.blk
                    else
                        local spw = AST.par(constr, 'Spawn')
                        org_blk = spw[2].var.blk or MAIN.blk_body    -- pool.blk
                    end
                end
            end
            if not (
                fr.fst.tag == 'Nat'        or -- natives are globals
                (fr.tag=='Op2_call' and       -- native calls are globals
                 fr[2].fst.tag=='Nat')     or
                (fr.org and                   -- "global:*" is global
                 fr.org.cls.id=='Global')  or
                fr_blk == MAIN.blk_body    or
                (org_blk and
                 org_blk.__depth>=fr_blk.__depth) or
                (   -- same class and scope of "to" <= "fr"
                    (AST.par(to_blk,'Dcl_cls') == AST.par(fr_blk,'Dcl_cls')) and
                        (   to_blk.__depth >= fr_blk.__depth            -- to <= fr
                        or (to_blk.__depth==cls.blk_ifc.__depth and     --    or
                            fr_blk.__depth==cls.blk_body.__depth)       -- ifc/bdy
                        )
                )
            ) then
                ASR(false, me, 'attribution to reference with greater scope')
                    -- NO:
                    -- var int& r;
                    -- do
                    --     var int v;
                    --     r = v;
                    -- end
            end
        end
    end,

    If = function (me)
        -- prepare to pass to parent
        local if_ = AST.par(me,'If')
        local T2
        if if_ then
            T2 = if_.__ref_bounded or {}
            if_.__ref_bounded = T2
        end

        local T1 = me.__ref_bounded or {}
        for var,t in pairs(T1) do
            ASR(#t==2, t[1], 'reference must be bounded in the other if-else branch')

            -- pass to parent
            if if_ then
                T2[var] = t
            end
        end
    end,

    -- Constructors (static/dynamic):
    -- If a ref field (class.field&) is not bounded internally,
    --  it must be bounded in all constructors.
    -- Checks if all class.field& are bounded or assigned here.
    __constr = function (me, cls, constr)
        constr.__bounded = constr.__bounded or {}
        for _, var in ipairs(cls.blk_ifc.vars) do
            if var.tp.ref and (not var.tp.opt)
                          and (var.bind=='constr' or (not var.bind))
            then
                ASR(constr.__bounded[var], me,
                    'field "'..var.id..'" must be assigned')
            end
        end
    end,
    Dcl_var = function (me)
        if me.var.cls and me.var.tp.ptr==0 then
            local _,_,_,constr = unpack(me)
            F.__constr(me, me.var.cls, constr or {})
        end

        -- ensures that global "ref" vars are initialized
        local glb = ENV.clss.Global
        local cls = CLS()   -- might be an ADT declaration
        if me.var.tp.ref and glb and cls and cls.id=='Main' then
            local var = glb.blk_ifc.vars[me.var.id]
            if var then
                local set = me.__par and me.__par[1]==me and
                            me.__par[2] and me.__par[2].tag=='Set'
                ASR(set, me,
                    'global references must be bounded on declaration')
            end
        end
    end,
    Spawn = function (me)
        local _,_,constr = unpack(me)
        F.__constr(me, me.cls, constr or {})
    end,

    -- Ensures that &ref var is bound before use.
    Var = function (me)
        local cls = CLS()
        if me.var.tp.ref and (not me.var.tp.opt) then
            -- ignore interface variables outside Main
            -- (they are guaranteed to be bounded)
            local inifc = (me.var.blk == cls.blk_ifc)
            inifc = inifc and cls.id~='Main'

            -- ignore global variables
            -- (they are guaranteed to be bounded)
            local glb = ENV.clss.Global
            if glb then
                if cls.id == 'Main' then
                    -- id = <...>   // id is a global accessed in Main
                    glb = glb.blk_ifc.vars[me.var.id]
                else
                    local fld = me.__par
                    if fld and fld.tag=='Field' and fld.org then
                        -- global:id = <...>
                        glb = fld.org.cls==glb
                    end
                end
            end

            -- ignore field accesses:
            --      x.ref.v
            -- (they are guaranteed to be bounded)
            local fld = (me.__par.tag=='Field' and me.__par[3]==me)

            if not (inifc or glb or fld) then
                ASR(me.var.bind, me, 'reference must be bounded before use')
            end
        end
    end,
}

AST.visit(F)
