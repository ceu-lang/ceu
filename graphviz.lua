local io = io
local s_rep = string.rep
local exec = os.execute

function TAB (n)
    return string.rep(' ',n*4)
end

function nfa_q2str (q)
    return '"'..q.n..':'..q.id..'"'
end

function nfa_q2dot (q)
    local ret = ''
    local q_str = nfa_q2str(q)
    ret = ret .. TAB(1) .. q_str .. ';\n'
    for to,a in pairs(q.out) do
        if type(a)=='table' then a=a.id end
        ret = ret..TAB(1).. q_str..' -> '..nfa_q2str(to)..
                ' [label="'..tostring(a)..'"];\n'
    end
    return ret
end

function dfa_q2dot (S)
    local ret = dfa_q2str(S)
    return ret
end

function p2id (p)
    return '"'..tostring(p)..'"'
end

function dfa_q2str (S)
    local ret = [[
    subgraph cluster_]]..S.n..[[ {
        style=filled;
        color=lightgrey;
        node [style=filled,color=white];
        label = "DFA #]]..S.n..[[";
]]
    local ps = P_flatten(S.qs_path)
    for p1 in pairs(ps) do
        local color = p1.err or 'white'
        ret = ret..TAB(2)..p2id(p1)..' [label='..nfa_q2str(p1.q)..',color='..
                color..'];\n'
        for _, p2 in ipairs(p1) do
            ret = ret..TAB(2)..p2id(p1)..' -> '..p2id(p2)..';\n'
        end
    end
    ret = ret .. [[
    }
]]
    for T,Sto in pairs(S.delta) do
        for qTo,t in pairs(T.qs_togo) do
            local pFr, pTo = unpack(t)
            if pFr.q ~= pTo.q then
                ret = ret..TAB(1) .. p2id(pFr) ..'->'.. p2id(pTo) --..';\n'
                    .. ' [label="'..T.id..'", color=red];\n'
            end
        end
    end
    return ret
end

function dfa2dot (QS)
    local ret = [[
digraph G {
    compound = true;
]]
    for S in pairs(QS) do
        ret = ret .. dfa_q2dot(S)
    end

    for _, t in ipairs(_DFA.nds.flw) do
        ret = ret..TAB(1).. p2id(t[1]) ..'->'.. p2id(t[2])
                    .. ' [style=dotted,arrowhead=none];\n'
    end

    for _, t in ipairs(_DFA.nds.acc) do
        ret = ret..TAB(1).. p2id(t[1]) ..'->'.. p2id(t[2])
                    .. ' [style=dotted,arrowhead=none];\n'
    end

    for _, t in ipairs(_DFA.nds.call) do
        ret = ret..TAB(1).. p2id(t[1]) ..'->'.. p2id(t[2])
                    .. ' [style=dotted,arrowhead=none];\n'
    end

    ret = ret .. [[
}
]]
    return ret
end

function nfa2dot (QS)
    local ret = 'digraph G {\n'
    for q in pairs(QS) do
        ret = ret .. nfa_q2dot(q)
    end
    ret = ret .. '}'
    return ret
end

function generate (str, out)
    local f = io.open('/tmp/fsm.dot', 'w')
    f:write(str)
    f:close()
    exec('dot -Tpng /tmp/fsm.dot -o'..out)
    --os.execute('rm /tmp/fsm.dot')
end

generate(nfa2dot(_NFA.nodes), '_ceu_nfa.png')
generate(dfa2dot(_DFA.states), '_ceu_dfa.png')

