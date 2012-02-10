#!/usr/bin/env lua

dofile 'pak.lua'

COUNT = 0

function Test (t)
    COUNT = COUNT + 1
    print'=========================================='
    print(t[1])
    local ceu = assert(io.popen('./ceu - --dfa --output _ceu_code.c 2>/tmp/err.txt', 'w'))
    ceu:write(t[1])
    ceu:close()
    local err = assert(io.open'/tmp/err.txt'):read'*a'
    assert(string.find(err, t.err, nil, true), err)
    print(t.err)
    print()
end

-- PARSER

Test { [[
]],
    err = "ERR : line 1 : after `BOF' : expected statement",
}

-- Exps

Test { [[int a = ]],
    err = "ERR : line 1 : after `=' : expected expression",
}

Test { [[return]],
    err = "ERR : line 1 : after `return' : expected expression",
}

Test { [[return()]],
    err = "ERR : line 1 : after `(' : expected expression",
}

Test { [[return 1+;]],
    err = "ERR : line 1 : before `+' : expected `;'",
}

Test { [[if then]],
    err = "ERR : line 1 : after `if' : expected expression",
}

Test { [[b = ;]],
    err = "ERR : line 1 : after `=' : expected expression",
}


Test { [[


return 1

+


;
]],
    err = "ERR : line 5 : before `+' : expected `;'"
}

Test { [[
int a;
a = do
    int b;
end
]],
    err = "ERR : line 4 : after `end' : expected `;'",
}

-- ASYNC

Test { [[
async do

    par/or do
        int a;
    with
        int b;
    end
end
]],
    err = "ERR : line 3 : not permitted inside async",
}
Test { [[
async do


    par/and do
        int a;
    with
        int b;
    end
end
]],
    err = "ERR : line 4 : not permitted inside async",
}
Test { [[
async do
    par do
        int a;
    with
        int b;
    end
end
]],
    err = "ERR : line 2 : not permitted inside async",
}

-- ...

-- DFA

-- TODO: "unreach stat" e "missing ret" se confundem

Test { [[
int a;
]],
    err = "ERR : line 2 : missing return statement",
}

Test { [[
int a;
a = do
    int b;
end;
]],
    err = "ERR : line 4 : missing return statement",
}

Test { [[
int a;
par/or do
    a = 1;
with
    a = 2;
end;
return a;
]],
    err = [[
WRN : line 3 : nondet access to "a"
WRN : line 5 : nondet access to "a"
]]
}

print('COUNT', COUNT)
