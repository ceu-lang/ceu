--[[
-- If an ISR acesses a symbol (Var/Nat), then all accesses outside it must be
-- atomic.
-- In the first pass "F", we mark all symbols accessed in ISRs.
-- In the second pass "G", we check if all accesses are protected.
--
-- If an ISR accesses a pointer or makes a call, we warn that this breaks the
-- analysis.
-- If outside gets a reference to a symbol used in an ISR, we warn that this
-- breaks the analysis.
--]]

local accs = {}

local function inIsr (me)
    return AST.par(me, 'Isr')
end

local msg = 'breaks the static check for `atomic´ sections'

F = {
    Var = function (me)
        if inIsr(me) then
            accs[me.var] = true
            local isPtr = (TP.check(me.var.tp,'&&','-&') and
                            (not TP.check(me.var.tp,'[]','-&')))
            WRN(not isPtr, me, 'pointer access '..msg)
        end
    end,
    Nat = function (me)
        if inIsr(me) and (me.c.mod~='@pure') then
            accs[me.id] = true
        end
    end,
    Op2_call = function (me)
        if inIsr(me) then
            WRN((me.c and me.c.mod=='@pure'), me,
                'call '..msg)
        end
    end,
}

G = {
    Var = function (me)
        if inIsr(me) or AST.par(me,'Dcl_var') then
            return  -- ignore isrs and var declarations
        end
        if accs[me.var] then
            ASR( AST.par(me,'Atomic'), me,
                    'access to "'..me.var.id..'" must be atomic' )
        end
    end,
    Nat = function (me)
        if inIsr(me) or AST.par(me,'Native') then
            return  -- ignore isrs and native declarations
        end
        if accs[me.id] then
            ASR( AST.par(me,'Atomic'), me,
                    'access to "'..me.id..'" must be atomic' )
        end
    end,
    ['Op1_&&'] = function (me)
        if accs[me.lst.var] then
            WRN(false, me, 'reference access '..msg)
        end
    end,
}

AST.visit(F)
AST.visit(G)
