local io = io
local s_rep = string.rep
local exec = os.execute

function dfa_tostr (S)
    local ret = '{'..S.n..'} '
    for _, qs_intl in ipairs(S.qs_all) do
        ret = ret.. '['
        local qs = set.filter(qs_intl, function(q) return not q.dfa_hide end)
        local n = 1
        for q in pairs(qs) do
            if n%5==0 then ret=ret..'\\n' end
            n = n + 1
            ret = ret ..' '.. nfa_tostr(q)
        end
        ret = ret .. ']'
    end
    return ret
end

function nfa_tostr (q, t)
    if q.hide then
        return ''
    else
        return ('('..q.n..':'..q.id..')')
    end
    --return '('..q.n..')'
end

--[[
function tostr (q, lvl)
    lvl = lvl or 1
    local ret = tostring(q)
    if q.id then
        ret = ret .. ' (' .. q.id .. ')'
    else
for k,v in pairs(q) do print(k,v) end
        for qq in pairs(q.qs) do
            ret = ret .. '\n' .. s_rep('\t',lvl) .. tostr(qq, lvl+1)
        end
    end
    return ret
end
]]

function nfa_q2dot (q)
    local ret = ''
    local q_str = nfa_tostr(q)
    ret = ret .. '\t"' .. q_str .. '";\n'
    for to,a in pairs(q.out) do
        if type(a)=='table' then a=a.id end
        ret = ret .. '\t"' .. q_str .. '" -> "' .. nfa_tostr(to) ..
              '" [label="'..tostring(a)..'"];\n'
    end
    return ret
end

function dfa_q2dot (S)
    local ret = ''
    local q_str = dfa_tostr(S)
    ret = ret .. '\t"' .. q_str .. '";\n'
    for a,to in pairs(S.delta) do
        ret = ret .. '\t"' .. q_str .. '" -> "' .. dfa_tostr(to) ..
              '" [label="'..(a.id)..'"];\n'
    end
    return ret
end

function dfa2dot (QS)
    local ret = 'digraph G {\n'
    for S in pairs(QS) do
        ret = ret .. dfa_q2dot(S)
    end
    ret = ret .. '}'
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

