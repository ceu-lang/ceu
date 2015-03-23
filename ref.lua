-- TODO:
--  - remove interface binding?
--      - only used for null hack?

F = {
    -- before Var
    SetExp_pre = function (me)
        local _, fr, to = unpack(me)
        if not REF(to.tp) then
            return
        end
        assert(to.lst.var, 'bug found')

        -- Detect source of assignment/binding:
        --  - internal:  assignment from body to normal variable (v, this.v)
        --  - constr:    assignment from constructor to interface variable (this.v)
        --  - interface: assignment from interface (var int v = <default value>)
        --  - outer:     assignment from outer body (t.v)

        local constr    = AST.par(me, 'Dcl_constr')
              constr    = constr and (constr.cls.blk_ifc.vars[to.lst.var.id]==to.lst.var) and constr
        local global    = to.tag=='Field' and to.org.cls.id=='Global' and CLS().id=='Main'
        local outer     = (not constr) and to.tag=='Field' and to.org.cls~=CLS() and (not global)
        local interface = AST.par(me, 'BlockI')
        local internal  = not (constr or outer or interface)

        -- ALREADY HAS INTERNAL BINDING

        if to.lst.var.bind=='internal' then
            -- Bounded inside the class body, refuse external assignments:
            --  - constructor
            --      var T t with
            --          this.v = ...;   // v was bounded in T
            --      end;
            --  - outer body
            --      var T t;
            --      t.v = ...;          // v was bounded in T
            ASR(internal or interface, me,
                'cannot assign to reference bounded inside the class')

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
            if (not REF(fr.tp)) then
                ASR(fr.lval or fr.tag=='Op1_&' or fr.tag=='Op2_call' or
                        (fr.lst and (fr.lst.tag=='Outer' or
                                     fr.lst.var and fr.lst.var.cls)),
                                               -- orgs are not lval
                    me, 'invalid attribution (not a reference)')

                -- TODO: temporary hack (null references)
                if not AST.child(fr,'NULL') then
                    ASR(not AST.child(fr,'Op1_*'), me, 'invalid attribution')
                end
            end
        end
    end,

    If = function (me)
        local T = me.__ref_bounded or {}
        for var,t in pairs(T) do
            ASR(#t==2, t[1], 'reference must be bounded in the other if-else branch')
        end
    end,

    -- Constructors (static/dynamic):
    -- If a ref field (class.field&) is not bounded internally,
    --  it must be bounded in all constructors.
    -- Checks if all class.field& are bounded or assigned here.
    __constr = function (me, cls, constr)
        constr.__bounded = constr.__bounded or {}
        for _, var in ipairs(cls.blk_ifc.vars) do
            if REF(var.tp) and (var.bind=='constr' or (not var.bind)) then
                ASR(constr.__bounded[var], me,
                    'field "'..var.id..'" must be assigned')
            end
        end
    end,
    Dcl_var = function (me)
        if me.var.cls then
            local _,_,_,constr = unpack(me)
            F.__constr(me, me.var.cls, constr or {})
        end

        -- ensures that global "ref" vars are initialized
        local glb = ENV.clss.Global
        local cls = CLS()   -- might be an ADT declaration
        if REF(me.var.tp) and glb and cls and cls.id=='Main' then
            local var = glb.blk_ifc.vars[me.var.id]
            if var then
                local set = me.__par and me.__par[1]==me and
                            me.__par[2] and me.__par[2].tag=='SetExp'
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
        if REF(me.var.tp) and (not me.var.tp.opt) then
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

            if (not inifc) and (not glb) then
                ASR(me.var.bind, me, 'reference must be bounded before use')
            end
        end
    end,
}

AST.visit(F)
