-- TODO:
--  - remove interface binding?
--      - only used for null hack?
F = {
    -- before Var
    SetExp_pre = function (me)
        local _, fr, to = unpack(me)
        if not to.tp.ref then
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
        local outer     = (not constr) and to.tag=='Field' and to.org.cls~=CLS()
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
            -- set source of binding
            if internal then
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

            -- first assignment (and only first assignment) is byRef
            to.byRef = true
            fr.byRef = true

            -- refuses first assignment from constants and dereferences:
            -- var int& i = 1;
            -- var int& i = *p;
            if (not fr.tp.ref) then
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

    -- Constructors (static/dynamic):
    -- If a ref field (class.field&) is not bounded internally,
    --  it must be bounded in all constructors.
    -- Checks if all class.field& are bounded or assigned here.
    Dcl_constr = function (me)
        me.__bounded = me.__bounded or {}
        for _, var in ipairs(me.cls.blk_ifc.vars) do
            if var.tp.ref and (var.bind == 'constr') then
                ASR(me.__bounded[var], me,
                    'field "'..var.id..'" must be assigned')
            end
        end
    end,

    -- Ensures that &ref var is bound before use.
    Var = function (me)
        if me.var.tp.ref then
            -- ignore interface variables outside Main
            -- (they are guaranteed to be bounded)
            local inifc = (me.var.blk == CLS().blk_ifc)
            inifc = inifc and CLS().id~='Main'
            if not inifc then
                ASR(me.var.bind, me, 'reference must be bounded before use')
            end
        end
    end,
}

AST.visit(F)
