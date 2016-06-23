RUN = {}

local function FF (F, str)
    local f = F[str]
    if type(f) == 'string' then
        return FF(F, f)
    end
    assert(f==nil or type(f)=='function')
    return f
end

local function visit (F, me)
    local pre, mid, pos = FF(F,me.tag..'__PRE'), FF(F,me.tag), FF(F,me.tag..'__POS')
    if pre then
        pre(me)
    end
    if mid then
        mid(me)
    end

    if me.tag == 'Stmts' then
        for _, stmt in ipairs(me) do
            local yields = visit(F, stmt)
            if yields then
                break
            end
        end
    elseif me.tag=='Par_And' or me.tag=='Par_Or' or me.tag=='Par' then
        for _, blk in ipairs(me) do
            visit(F, blk)
        end
    else
        for _, node in ipairs(me) do
            if AST.isNode(node) then
                visit(F, node)
            end
        end
    end

    if pos then
        pos(me)
    end
end

function RUN.visit (F, node)
    return visit(F, node or AST.root)
end
