--[===[

Test { [[
input void A, B, Z;
event void a;
var int ret = 1;
var _t* a;
C _f();
C _t = 0;
par/or do
    _f(a)
        finalize with
            ret = 1;    // DET
        end;
with
    var _t* b;
    _f(b)
        finalize with
            ret = 2;    // DET
        end;
end
return ret;
]],
    ana = {
        n_acc = 2,
    },
    run = false,
}

Test { [[
input int A;
var int a;
par/or do
    loop do
        a = 1;
        await A;
    end;
with
    await A;
    await A;
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
input int A;
var int a;
par do
    loop do
        par/or do
            a = 1;
            await A;
        with
            await A;
            a = 2;
        end;
    end
with
    loop do
        await A;
        a = 3;
    end
end
]],
    ana = {
        isForever = true,
        n_acc = 2,
    },
}

Test { [[
input void START;
event int a, x, y;
var int ret = 0;
par do
    par/or do
        await y;
        return 1;   // 12
    with
        await x;
        return 2;   // 15
    end;
with
    await START;
    emit x=1;
    emit y=1;
end
]],
    ana = {
        n_acc = 0,
    },
    run = 2;
}

--]===]

--do return end

Test { [[return(1);]],
    ana = {
        isForever = false,
    },
    run = 1,
}

Test { [[return (1);]], run=1 }
Test { [[return 1;]], run=1 }

Test { [[return 1; // return 1;]], run=1 }
Test { [[return /* */ 1;]], run=1 }
Test { [[return /*

*/ 1;]], run=1 }
Test { [[return /**/* **/ 1;]], run=1 }
Test { [[return /**/* */ 1;]],
    parser = "ERR : line 1 : after `return´ : expected expression" }

Test { [[
do do do do do do do do do do do do do do do do do do do do
end end end end end end end end end end end end end end end end end end end end
return 1;
]],
    run = 1
}

Test { [[
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
return 1;
]],
    --ast = 'ERR : line 2 : max depth of 127',
    run = 1
}

Test { [[
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
return 1;
]],
    ast = 'ERR : line 7 : max depth of 0xFF',
}

Test { [[return 0;]], run=0 }
Test { [[return 9999;]], run=9999 }
Test { [[return -1;]], run=-1 }
Test { [[return --1;]], run=1 }
Test { [[return - -1;]], run=1 }
Test { [[return -9999;]], run=-9999 }
Test { [[return 'A';]], run=65, }
Test { [[return (((1)));]], run=1 }
Test { [[return 1+2*3;]], run=7 }
Test { [[return 1==2;]], run=0 }
Test { [[return 0  or  10;]], run=1 }
Test { [[return 0 and 10;]], run=0 }
Test { [[return 2>1 and 10!=0;]], run=1 }
Test { [[return (1<=2) + (1<2) + 2/1 - 2%3;]], run=2 }
-- TODO: linux gcc only?
--Test { [[return (~(~0b1010 & 0XF) | 0b0011 ^ 0B0010) & 0xF;]], run=11 }
Test { [[nt a;]],
    parser = "ERR : line 1 : before `nt´ : expected statement",
}
Test { [[nt sizeof;]],
    parser = "ERR : line 1 : before `nt´ : expected statement",
}
Test { [[var int sizeof;]],
    parser = "ERR : line 1 : after `int´ : expected identifier",
}
Test { [[return sizeof<int>;]], run=4 }
Test { [[return 1<2>3;]], run=0 }

Test { [[var int a;]],
    ana = {
        n_reachs = 1,
        isForever = true,
    }
}

Test { [[
var int a, b;
return 10;
]],
    run = 10,
}

Test { [[a = 1; return a;]],
    env = 'variable/event "a" is not declared',
}
Test { [[var int a; a = 1; return a;]],
    run = 1,
}
Test { [[var int a = 1; return a;]],
    run = 1,
}
Test { [[var int a = 1; return (a);]],
    run = 1,
}
Test { [[var int a = 1;]],
    ana = {
        n_reachs = 1,
        isForever = true,
    }
}
Test { [[var int a=1;var int a=0; return a;]],
    --env = 'ERR : line 1 : variable/event "a" is already declared at line 1',
    run = 0,
}
Test { [[do var int a=1; end var int a=0; return a;]],
    run = 0,
}
Test { [[var int a=1,a=0; return a;]],
    --env = 'ERR : line 1 : variable/event "a" is already declared at line 1',
    run = 0,
}
Test { [[var int a; a = b = 1]],
    parser = "ERR : line 1 : after `b´ : expected `;´",
}
Test { [[var int a = b; return 0;]],
    env = 'variable/event "b" is not declared',
}
Test { [[return 1;2;]],
    parser = "ERR : line 1 : before `;´ : expected statement",
}
Test { [[var int aAa; aAa=1; return aAa;]],
    run = 1,
}
Test { [[var int a; a=1; return a;]],
    run = 1,
}
Test { [[var int a; a=1; a=2; return a;]],
    run = 2,
}
Test { [[var int a; a=1; return a;]],
    run = 1,
}
Test { [[var int a; a=1 ; a=a; return a;]],
    run = 1,
}
Test { [[var int a; a=1 ; ]],
    ana = {
        n_reachs = 1,
        isForever = true,
    }
}

Test { [[
C _abc = 0;
event void a;
var _abc b;
]],
    env = 'ERR : line 3 : cannot instantiate type "_abc"',
}

Test { [[
C _abc = 0;
event void a;
var _abc a;
]],
    --env = 'ERR : line 3 : variable/event "a" is already declared at line 2',
    env = 'ERR : line 3 : cannot instantiate type "_abc"',
}

Test { [[
input void A;
var int a? = 1;
a_ = 2;
return a?;
]],
    run = 2,
}

Test { [[
return 0x1 + 0X1 + 001;
]],
    run = 3,
}

Test { [[
return 0x1 + 0X1 + 0a01;
]],
    env = 'ERR : line 1 : malformed number',
}

    -- IF

Test { [[if 1 then return 1; end; return 0;]],
    ana = {
        isForever = false,
    },
    run = 1,
}
Test { [[if 0 then return 0; end  return 1;]],
    run = 1,
}
Test { [[if 0 then return 0; else return 1; end]],
    ana = {
        isForever = false,
    },
    run = 1,
}
Test { [[if (0) then return 0; else return 1; end;]],
    run = 1,
}
Test { [[if (1) then return (1); end]],
    ana = {
        n_reachs = 1,
    },
    run = 1,
}
Test { [[
if (0) then
    return 1;
end
return 0;
]],
    run = 0,
}
Test { [[
var int a = 1;
if a == 0 then
    return 1;
else/if a > 0 then
    return 0;
else
    return 1;
end
return 0;
]],
    ana = {
        n_unreachs = 1,
    },
    run = 0,
}
Test { [[
var int a = 1;
if a == 0 then
    return 0;
else/if a < 0 then
    return 0;
else
    a = a + 2;
    if a < 0 then
        return 0;
    else/if a > 1 then
        return 1;
    else
        return 0;
    end
    return 1;
end
return 0;
]],
    ana = {
        n_unreachs = 2,
    },
    run = 1,
}
Test { [[if (2) then  else return 0; end;]],
    ana = {
        n_reachs = 1,
    },
    run = 0,
}

-- IF vs SEQ priority
Test { [[if 1 then var int a; return 2; else return 3; end;]],
    run = 2,
}

Test { [[
if 0 then
    return 1;
else
    if 1 then
        return 1;
    end
end;]],
    ana = {
        n_reachs = 1,
    },
    run = 1,
}
Test { [[
if 0 then
    return 1;
else
    if 0 then
        return 1;
    else
        return 2;
    end
end;]],
    ana = {
        isForever = false,
    },
    run = 2,
}
Test { [[
var int a = 0;
var int b = a;
if b then
    return 1;
else
    return 2;
end;
]],
    run = 2,
}
Test { [[
var int a;
if 0 then
    a = 1;
else
    a = 2;
end;
return a;
]],
    run = 2,
}
Test { [[
var int a;
if 1 then
    a = 1;
    if 1 then
        a = 2;
    end;
end;
return a;
]],
    run = 2,
}
Test { [[
var int a;
if 0 then
    return 1;
else
    a=1;a=2; return 3;
end;
]],
    run = 3,
}
Test { [[
var int a = 0;
if (0) then
    a = 1;
end
return a;
]],
    run = 0,
}

    -- EVENTS

Test { [[input int A=1;]], parser="ERR : line 1 : after `A´ : expected `;´" }
Test { [[
input int A;
A=1;
return 1;
]],
    parser = 'ERR : line 1 : after `;´ : expected statement',
}

Test { [[input  int A;]],
    ana = {
        n_reachs = 1,
        isForever = true,
    },
}
Test { [[input int A,A; return 0;]],
    env = 'event "A" is already declared',
}
Test { [[
input int A,B,Z;
]],
    ana = {
        n_reachs = 1,
        isForever = true,
    },
}

Test { [[await A; return 0;]],
    env = 'event "A" is not declared',
}

Test { [[
input void A;
await A;
return 1;
]],
    run = false,
}
Test { [[
input void A;
par/and do
    await A;
with
    nothing;
end
return 1;
]],
    run = false,
}

Test { [[
input int A;
par/or do
    await A;
with
    async do
        emit A(10);
    end
end;
return 10;
]],
    ana = {
        isForever = false,
    },
    run = 10,
}
Test { [[
input int A;
var int ret;
par/or do
    ret = await A;
with
    async do
        emit A(10);
    end;
end
return ret;
]],
    run = 10
}

Test { [[
input int A;
par/and do
    await A;
with
    async do
        emit A(10);
    end;
end;
return A;
]],
    parser = "ERR : line 9 : after `return´ : expected expression",
}

Test { [[
input int A;
var int v;
par/and do
    v = await A;
with
    async do
        emit A(10);
    end;
end;
return v;
]],
    ana = {
        isForever = false,
    },
    run = 10,
}

Test { [[
input int A;
tmp int v = await A;
return v;
]],
    run = {
        ['101~>A'] = 101,
        ['303~>A'] = 303,
    },
}

print'TODO: deveria dar erro!'
Test { [[var int a = a+1; return a;]],
    --env = 'variable/event "a" is not declared',
    run = 1,
}

Test { [[var int a; a = emit a=1; return a;]],
    parser = "ERR : line 1 : after `emit´ : expected event",
    --trig_wo = 1,
}

Test { [[var int a; emit a=1; return a;]],
    env = 'ERR : line 1 : event "a" is not declared',
    --trig_wo = 1,
}
Test { [[event int a; emit a=1; return a;]],
    run = 1,
    --trig_wo = 1,
}

Test { [[
input void START;
do
    var int v = 0;
end
event void e;
par do
    await START;
    emit e;
    return 1;       // 9
with
    await e;
    return 2;       // 12
end
]],
    ana = {
        --n_unreachs = 1,
    },
    run = 2,
}

    -- OUTPUT

Test { [[
output xxx A;
return(1);
]],
    parser = "ERR : line 1 : after `output´ : expected type",
}
Test { [[
output int A;
emit A(1);
return(1);
]],
    run=1
}
Test { [[
output int A;
if emit A(1) then
    return 0;
end
return(1);
]],
    run=1
}
Test { [[
C do
    #define ceu_out_event(a,b,c) 1
end
output int A;
if emit A(1) then
    return 0;
end
return(1);
]],
    run=0
}

Test { [[
output t A;
emit A(1);
return(1);
]],
    parser = 'ERR : line 1 : after `output´ : expected type',
}
Test { [[
output t A;
emit A(1);
return(1);
]],
    parser = 'ERR : line 1 : after `output´ : expected type',
}
Test { [[
output _t* A;
emit A(1);
return(1);
]],
    env = 'ERR : line 2 : non-matching types on `emit´',
}
Test { [[
output int A;
var _t v;
emit A(v);
return(1);
]],
    env = 'ERR : line 2 : undeclared type `_t´',
}
Test { [[
C do
    void f (int* a) {
        *a = 10;
    }
    typedef void (*t)(int*);
end
C _t = 4;
var _t v = _f;
var int a;
v(&a);
return(a);
]],
    env = 'ERR : line 8 : C variable/function "_f" is not declared',
}

Test { [[
output int A;
var int a;
if emit A(&a) then
    return 0;
end
return(1);
]],
    env = 'ERR : line 3 : non-matching types on `emit´',
}
Test { [[
output _char A;
]],
    env = "lines.lua:35: ERR : line 1 : invalid event type",
}

Test { [[
C do
    /******/
    int end = 1;
    /******/
end
C _end;
return _end;
]],
    run = 1
}

Test { [[
C do
    #include <assert.h>
    typedef struct {
        int a;
        int b;
    } t;
    #define ceu_out_event(a,b,c) Fa(a,b,c)
    int Fa (int id, int len, void* data) {
        assert(len == 8);
        t v = *((t*)data);
        return v.a - v.b;
    }
    #define ceu_out_event_B(c) Fb(c)
    int Fb (int* data) {
        return *data - 1;
    }
end
C _t = 8;
output _t* A;
output int B;
var int a, b;

var _t v;
v.a = 1;
v.b = -1;
a = emit A(&v);
b = emit B(5);
return a + b;
]],
    run = 6,
}

Test { [[
C _char = 1;
output void A;
C do
    void A (int v) {}
end
var _cahr v = emit A(1);
return 0;
]],
    env = 'ERR : line 6 : undeclared type `_cahr´',
}
Test { [[
C _char = 1;
output void A;
var _char v = emit A();
return v;
]],
    env = 'ERR : line 3 : invalid attribution',
}
Test { [[
output void A;
C do
    void A (int v) {}
end
C _char = 1;
var _char v = emit A(1);
return 0;
]],
    env = 'ERR : line 6 : non-matching types on `emit´',
}

Test { [[
C do
    void A (int v) {}
end
emit A(1);
return 0;
]],
    env = 'event "A" is not declared',
}

Test { [[
output void A, B;
par/or do
    emit A;
with
    emit A;
end
return 1;
]],
    --loop = 'ERR : line 3 : parallel branch must await',
    ana = {
        n_acc = 1,
    },
    run = 1,
}

Test { [[
output void A, B;
par/or do
    emit A;
with
    emit B;
end
return 1;
]],
    ana = {
        n_acc = 1,
    },
    run = 1,
}

Test { [[
deterministic A with B;
output void A, B;
par/or do
    emit A;
with
    emit B;
end
return 1;
]],
    run = 1,
}

    -- WALL-CLOCK TIME / WCLOCK

Test { [[await 0ms; return 0;]],
    val = 'ERR : line 1 : constant is out of range',
}
Test { [[
input void A;
await A;
return 0;
]],
    run = { ['~>10ms; ~>A'] = 0 }
}

Test { [[await -1ms; return 0;]],
    --parser = "ERR : line 1 : after `await´ : expected event",
    parser = 'ERR : line 1 : after `1´ : expected `;´',
}

Test { [[await 1; return 0;]],
    parser = 'ERR : line 1 : after `1´ : expected <h,min,s,ms,us>',
}
Test { [[await -1; return 0;]],
    env = 'ERR : line 1 : event "?" is not declared',
}

Test { [[var s32 a=await 10s; return a==8000000;]],
    ana = {
        isForever = false,
    },
    run = {
        ['~>10s'] = 0,
        ['~>9s ; ~>9s'] = 1,
    },
}

Test { [[await FOREVER;]],
    ana = {
        isForever = true,
    },
}
Test { [[await FOREVER; await FOREVER;]],
    parser = "ERR : line 1 : before `;´ : expected event",
}
Test { [[await FOREVER; return 0;]],
    parser = "ERR : line 1 : before `;´ : expected event",
}

Test { [[emit 1ms; return 0;]], props='not permitted outside `async´' }
Test { [[
var int a;
a = async do
    emit 1min;
end;
return a + 1;
]],
    todo = 'async nao termina',
    run = false,
}

Test { [[
async do
end
return 10;
]],
    ana = {
        isForever = false,
    },
    run = 10,
}

Test { [[
var int a;
a = async do
    emit 1min;
    return 10;
end;
return a + 1;
]],
    ana = {
        isForever = false,
    },
    run = 11,
}

Test { [[
async do
    emit 1min;
    return 10;
end
]],
    props = 'ERR : line 3 : `return´ without block',
}

-- Seq

Test { [[
input int A;
var int v = await A;
return v;
]],
    run = { ['10~>A']=10 },
}
Test { [[
input int A,B;
await A;
var int v = await B;
return v;
]],
    run = {
        ['3~>A ; 1~>B'] = 1,
        ['1~>B ; 2~>A ; 3~>B'] = 3,
    }
}
Test { [[
var int a = await 10ms;
a = await 20ms;
return a;
]],
    run = {
        ['~>20ms ; ~>11ms'] = 1000,
        ['~>20ms ; ~>20ms'] = 10000,
    }
}
Test { [[
var int a = await 10us;
a = await 40us;
return a;
]],
    run = {
        ['~>20us ; ~>30us'] = 0,
        ['~>30us ; ~>10us ; ~>10us'] = 0,
        ['~>30us ; ~>10us ; ~>30us'] = 20,
    }
}

Test { [[
par/and do
    await 1s;
with
    await 1s;
end
par/and do
    await FOREVER;
with
    await 1s;
end
return 0;
]],
    ana = {
        n_unreachs = 2,
        isForever = true,
    },
}

Test { [[
input void F;
var int ret = 0;
par/or do
    await 2s;
    ret = 10;
    await F;
with
    await 1s;
    ret = 1;
    await F;
end
return ret;
]],
    ana = {
        n_acc = 1,  -- false positive
    },
    run = { ['~>1s; ~>F']=1 },
}

Test { [[
par/or do
    await 1s;
with
    await 1s;
end
par/or do
    await 1s;
with
    await FOREVER;
end
par/or do
    await FOREVER;
with
    await FOREVER;
end
return 0;
]],
    ana = {
        n_unreachs = 2,
        isForever =  true,
    },
}

Test { [[
par do
    await FOREVER;
with
    await 1s;
end
]],
    ana = {
        isForever = true,
    }
}

Test { [[
par do
    await FOREVER;
with
    await FOREVER;
end
]],
    ana = {
        isForever = true,
    },
}

Test { [[
par do
    await 1s;
with
    await 1s;
end
]],
    ana = {
        n_reachs = 1,
        isForever = true,
    },
}

Test { [[
par do
    await 1s;
    await 1s;
    return 1;
with
    await 2s;
    return 2;
end
]],
    ana = {
        n_acc = 1,  -- false positive
    },
    run = { ['~>2s']=1 }
}

Test { [[
par do
    var int v1=4,v2=4;
    par/or do
        await 10ms;
        v1 = 1;
    with
        await 10ms;
        v2 = 2;
    end
    return v1 + v2;
with
    async do
        emit 5ms;
        emit(5000)ms;
    end
end
]],
    ana = {
        isForever = false,
    },
    run = 5,
    --run = 3,
    --todo = 'nd kill',
}

Test { [[
input int A;
await A;
await A;
var int v = await A;
return v;
]],
    run  = {
        ['1~>A ; 2~>A ; 3~>A'] = 3,
    },
}

Test { [[
input int A,B;
var int ret;
if 1 then
    ret = await A;
else
    ret = await B;
end;
return ret;
]],
    run = {
        ['1~>A ; 0~>A'] = 1,
        ['3~>B ; 0~>A'] = 0,
    },
}

Test { [[
input int A;
var int v;
if 1 then
    v = await A;
end;
return v;
]],
    run = {
        ['1~>A ; 0~>A'] = 1,
    },
}

Test { [[
input int A;
var int v;
if 0 then
    v = await A;
end;
return v;
]],
    run = 0,
}

Test { [[
par/or do
    await FOREVER;
with
    return 1;
end
]],
    ana = {
        n_unreachs = 1,
        --nd_flw = 1,
    },
    run = 1,
}

Test { [[
input void F;
var int a = 0;
loop do
    par/or do
        await 2s;
    with
        a = a + 1;
        await F;
        break;
    with
        await 1s;
        loop do
            a = a * 2;
            await 1s;
        end
    end
end
return a;
]],
    ana = {
        --n_acc = 3,      -- TODO: bad
    },
    run = { ['~>5s; ~>F']=14 },
    --run = { ['~>5s; ~>F']=42 },
}

Test { [[
var int a;
loop do
    par/or do
        await 2s;
    with
        a = 1;
        await FOREVER;
    with
        await 1s;
        loop do
            a = 2;
            await 1s;
        end
    end
end
]],
    ana = {
        isForever = true,
        --n_acc = 1,
    },
}

Test { [[
var int a = do
    var int a = do
        return 1;
    end;
    return a;
end;
return a;
]],
    run = 1
}

Test { [[
event int a;
par/and do
    a = do
        return 1;
    end;
with
    await a;
end;
return 0;
]],
    ana = {
        --n_unreachs = 2,
        --isForever = true,
    },
}

Test { [[
input void A,B;
par/or do
    await A;
    await FOREVER;
with
    await B;
    return 1;
end;
]],
    ana = {
        n_unreachs = 1,
    },
    run = { ['~>A;~>B']=1, },
}

Test { [[
par/and do
with
    return 1;
end
]],
    ana = {
        n_unreachs = 1,
    },
    run = 1,
}
Test { [[
par do
with
    return 1;
end
]],
    --nd_flw = 1,
    run = 1,
}
Test { [[
par do
    await 10ms;
with
    return 1;
end
]],
    ana = {
        --n_unreachs = 1,
    },
    --nd_flw = 1,
    run = 1,
}
Test { [[
input int A;
par do
    async do end
with
    await A;
    return 1;
end
]],
    run = { ['1~>A']=1 },
}

Test { [[
par do
    async do end
with
    return 1;
end
]],
    todo = 'async dos not exec',
    ana = {
        --n_unreachs = 1,
        --nd_flw = 1,
    },
    run = 1,
}

Test { [[
par do
    await FOREVER;
with
    return 1;
end;
]],
    nd_flw = 1,
    run = 1,
}

Test { [[
input void A,B;
par do
    await A;
    await FOREVER;
with
    await B;
    return 1;
end;
]],
    run = { ['~>A;~>B']=1, },
}

-- testa BUG do ParOr que da clean em ParOr que ja terminou
Test { [[
input int A,B,F;
var int a;
par/or do
    await A;
with
    await B;
end;

par/or do
    a = 255+255+3;
with
    await F;
end;
return a;
]],
    ana = {
        --n_unreachs = 1,
    },
    run = { ['1~>A;1~>F']=513, ['2~>B;0~>F']=513 },
}

Test { [[
input int A;
loop do
    await A;
    await 2s;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
input int A;
par do
    loop do
        await A;
        await 2s;
    end;
with
    loop do
        await 2s ;
    end;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
input int A,B,F;
var int a;
par/or do
    par/or do
        par/or do
            a = await 10us;
        with
            await A;
        end;
    with
        a = await B;
    end;
    await FOREVER;
with
    await F;
end;
return a;
]],
    run = {
        ['1~>B; ~>20us; 1~>F'] = 1,
        ['~>20us; 5~>B; 2~>F'] = 10,
    }
}
Test { [[
input int A,B,F;
var int a = do
        par/or do
            par do
                var int v;
                par/or do
                    var int v = await 10ms;
                    return v; //  8
                with
                    v = await A;
                end;
                return v;     // 12
            with
                var int v = await B;
                return v;     // 15
            end;
        with
            await F;
        end;
        return 0;
    end;
return a;
]],
    run = {
        ['1~>B; ~>20ms; 1~>F'] = 1,
        ['~>20ms; 5~>B; 2~>F'] = 10000,
    }
}

Test { [[
input int A,B,F;
var int a = do
        par/or do
            par do
                var int v;
                par/or do
                    var int v = await 10ms;
                    return v;
                with
                    v = await A;
                end;
                return v;
            with
                var int v = await B;
                return v;
            end;
            // unreachable
            await FOREVER;
        with
            await F;
        end;
        return 0;
    end;
return a;
]],
    -- TODO: melhor seria: unexpected statement
    parser = "ERR : line 16 : after `;´ : expected `with´",
    --n_unreachs = 1,
    run = {
        ['1~>B; ~>20ms; 1~>F'] = 1,
        ['~>20ms; 5~>B; 2~>F'] = 10,
    }
}

-- testa BUG do ParOr que da clean em await vivo
Test { [[
input int A,B,D;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
with
    await D;
end;
return 100;
]],
    run = { ['1~>A;1~>D']=100 }
}

Test { [[
input int A;
var int b;
if 1 then
    await A;
    b = 1;
else
    if 1 then
        await A;
        b = 1;
    else
        await A;
    end;
end;
return b;
]],
    run = {
        ['0~>A ; 0~>A'] = 1,
    },
}

    -- LOOP

Test { [[
input int A;
loop do
    do
        break;
    end;
end;
return 1;
]],
    ana = {
        n_unreachs = 1,    -- re-loop
    },
    run = 1,
}
Test { [[
input int A;
loop do
    do
        return 1;
    end;
end;
return 0;
]],
    ana = {
        n_unreachs = 2,
    },
    run = 1,
}

Test { [[
input int A;
loop do
    loop do
        return 1;
    end;
end;
return 0;
]],
    ana = {
        n_unreachs = 3,
    },
    run = 1,
}

Test { [[
input int A;
loop do
    loop do
        break;
    end;
end;
return 0;
]],
    ana = {
        isForever = true,
        n_unreachs = 2,
    },
    loop = 'tight loop',
}

Test { [[
loop do
    par do
        await FOREVER;
    with
        break;
    end;
end;
return 1;
]],
    ana = {
        n_unreachs = 1,
        --nd_flw = 1,
    },
    run = 1,
}

Test { [[
input int A,B;
loop do
    par do
        await A;
        await FOREVER;
    with
        await B;
        break;
    end;
end;
return 1;
]],
    ana = {
        n_unreachs = 1,
    },
    run = { ['~>A;~>B']=1, }
}

Test { [[
loop do
    par do
        await FOREVER;
    with
        return 1;
    end;
end;        // n_unreachs
return 1;   // n_unreachs
]],
    ana = {
        n_unreachs = 2,
        --nd_flw =1,
    },
    run = 1,
}

Test { [[
input int A,B;
loop do
    par do
        await A;
        await FOREVER;
    with
        await B;
        return 1;
    end;
end;        // n_unreachs
return 1;   // n_unreachs
]],
    ana = {
        n_unreachs = 2,
    },
    run = { ['~>A;~>B']=1, }
}

Test { [[
loop do
    async do
        break;
    end;
end;
return 1;
]],
    props = '`break´ without loop',
}

Test { [[
input int A;
var int v;
var int a;
loop do
    a = 0;
    v = await A;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
var int a;
loop do a=1; end;
return a;
]],
    ana = {
        isForever = true,
        n_unreachs = 1,
    },
    loop = 'tight loop',
}

Test { [[break; return 1;]], parser="ERR : line 1 : before `;´ : expected statement" }
Test { [[break; break;]], parser="ERR : line 1 : before `;´ : expected statement" }
Test { [[loop do break; end; return 1;]],
    ana = {
        n_unreachs=1,
    },
    run=1
}
Test { [[
var int ret;
loop do
    ret = 1;
    break;
end;
return ret;
]],
    ana = {
        n_unreachs = 1,
    },
    run = 1,
}

Test { [[
var int a;
loop do
    loop do
        a = 1;
    end;
end;
]],
    ana = {
        isForever = true,
        n_unreachs = 1,
    },
    loop = 'tight loop'
}

Test { [[
loop do
    loop do
        break;
    end;
end;
]],
    loop = 'tight loop',
    ana = {
        isForever = true,
        n_unreachs = 1,
    },
}

Test { [[
loop do
    loop do
        await FOREVER;
    end;
end;
]],
    ana = {
        n_unreachs = 2,
        isForever = true,
    },
}

-- CONTINUE
Test { [[
loop do
    if 0 then
        continue;
    else
        nothing;
    end
end
]],
    ast = 'ERR : line 3 : invalid `continue´',
}

Test { [[
loop do
    do continue; end
end
]],
    ast = 'ERR : line 2 : invalid `continue´',
}

Test { [[
loop do
    do
        if 0 then
            continue;
        end
    end
end
]],
    ast = 'ERR : line 4 : invalid `continue´',
}

Test { [[
loop do
    if 0 then
        continue;
    end
    await 1s;
end
]],
    loop = 'tight loop',
    ana = {
        isForever = true,
        --n_unreachs = 1,
    },
}

Test { [[
var int ret = 0;
loop i, 10 do
    if i%2 == 0 then
        ret = ret + 1;
        await 1s;
        continue;
    end
    await 1s;
end
return ret;
]],
    run = { ['~>10s']=5 }
}

-- EX.05
Test { [[
input int A;
loop do
    await A;
end;
]],
    ana = {
        isForever = true,
    },
}
Test{ [[
input int E;
var int a;
loop do
    a = await E;
end;
]],
    ana = {
        isForever = true,
    },
}
Test{ [[
input int E;
loop do
    tmp int v = await E;
    if v then
    else
    end;
end;
]],
    ana = {
        isForever = true,
    },
}
Test { [[
var int a;
loop do
    if 0 then
        a = 0;
    else
        a = 1;
    end;
end;
return a;
]],
    loop = 'tight loop',
    ana = {
        isForever = true,
        n_unreachs = 1,
    },
}
Test { [[
loop do
    if 0 then
        break;
    end;
end;
return 0;
]],
    loop = 'tight loop'
}

Test { [[
par/or do
    loop do
    end;
with
    loop do
    end;
end;
return 0;
]],
    loop='tight loop',
    ana = {
        isForever = true,
        n_unreachs = 2,
    },
}

Test { [[
par/and do
    loop do
    end;
with
    loop do
    end;
end;
return 0;
]],
    loop='tight loop',
    ana = {
        isForever = true,
        n_unreachs = 2,
    },
}

Test { [[
event int a;
par/and do
    await a;
with
    loop do end;
end;
return 0;
]],
    loop='tight loop',
    ana = {
        isForever = true,
        n_unreachs = 2,
    },
}

Test { [[
input int A;
loop do
    par/or do
        await A;
    with
    end;
end;
return 0;
]],
    loop='tight loop',
    ana = {
        isForever = true,
        n_unreachs = 1,
    },
}
Test { [[
input int A;
var int a;
a = 0;
loop do
    par/or do
    with
        await A;
    end;
end;
return 0;
]],
    loop='tight loop',
    ana = {
        isForever = true,
        n_unreachs = 1,
    },
}

Test { [[
input void START;
event void a,b;
par/and do
    await a;
with
    await START;
    emit b;
    emit a;
end
return 5;
]],
    run = 5,
}

Test { [[
input int A;
if 0 then
    loop do await A; end;
else
    loop do await A; end;
end;
return 0;   // TODO
]],
    ana = {
        n_unreachs = 1,
        isForever = true,
    },
}
Test { [[
input int A;
if 0 then
    loop do await A; end;
else
    loop do await A; end;
end;
]],
    ana = {
        isForever = true,
    },
}
Test { [[
input int A;
loop do
    if 0 then
        await A;
    else
        break;
    end;
end;
return 1;
]],
    run = 1,
}
Test { [[
input int A;
loop do
    if 0 then
        await A;
        await A;
    else
        break;
    end;
end;
return 1;
]],
    run = 1,
}
Test { [[
input int F, A;
loop do
    var int v = await F;
    if v then
        await A;
    else
        break;
    end;
end;
return 1;
]],
    run = {
        ['0~>F'] = 1,
        ['1~>F;0~>A;0~>F'] = 1,
    }
}

-- FOR

Test { [[
input int A;
var int sum = 0;
par/or do
    loop i, 1+1 do
        await A;
    end
    sum = 0;
with
    sum = 1;
end
return sum;
]],
    todo = 'for',
    ana = {
        n_acc = 1,
        n_unreachs = 1,
    },
    run = 1,
}

Test { [[
input int A;
var int sum = 0;
par/or do
    loop i, 1 do
        await A;
    end
    sum = 0;
with
    sum = 1;
end
return sum;
]],
    ana = {
        --n_unreachs = 2,
    },
    run = 1,
}

Test { [[
input int A;
var int sum = 0;
var int ret = 0;
par/or do
    loop i, 2 do
        await A;
        ret = ret + 1;
    end
    sum = 0;
with
    await A;
    await A;
    sum = 1;
end
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = { ['~>A; ~>A; ~>A']=2 },
    --todo = 'nd kill',
}

Test { [[
input int A;
var int sum = 0;
var int ret = 0;
par/or do
    loop i, 3 do
        await A;
        ret = ret + 1;
    end
    sum = 0;
with
    await A;
    await A;
    sum = 1;
end
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = { ['~>A;~>A'] = 2 },
    --todo = 'nd kill',
}

Test { [[
input int A;
var int sum = 0;
par/or do
    loop i, 1 do
        await A;
        async do
            var int a = 1;
        end
    end
    sum = 0;
with
    sum = 1;
end
return sum;
]],
    ana = {
        --n_unreachs = 3,
    },
    run = 1,
}

Test { [[
input int A;
var int sum = 0;
par/or do
    sum = 5;            // 4
    loop i, 10 do
        await A;
        async do
            var int a = 1;
        end
    end
    sum = 0;            // 11
with
    loop i, 2 do
        async do
            var int a = 1;
        end
        sum = sum + 1;  // 17
    end
end
return sum;
]],
    run = 7,
}

Test { [[
var int sum = 0;
loop i, 100 do
    sum = sum + (i+1);
end
return sum;
]],
    loop = true,
    run = 5050,
}
Test { [[
var int sum = 0;
for i=1, 100 do
    i = 1;
    sum = sum + i;
end
return sum;
]],
    loop = true,
    todo = 'should raise an error',
    run = 5050,
}
Test { [[
var int sum = 5050;
loop i, 100 do
    sum = sum - (i+1);
end
return sum;
]],
    loop = true,
    run = 0,
}
Test { [[
var int sum = 5050;
var int v = 0;
loop i, 100 do
    v = i;
    if sum == 100 then
        break;
    end
    sum = sum - (i+1);
end
return v;
]],
    loop = true,
    run = 99,
}
Test { [[
input void A;
var int sum = 0;
var int v = 0;
loop i, 101 do
    v = i;
    if sum == 6 then
        break;
    end
    sum = sum + i;
    await A;
end
return v;
]],
    run = {['~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;']=4},
}
Test { [[
var int sum = 4;
loop i, 0 do
    sum = sum - i;
end
return sum;
]],
    loop = true,
    run = 4,
}
Test { [[
input void A, B;
var int sum = 0;
loop i, 10 do
    await A;
    sum = sum + 1;
end
return sum;
]],
    run = {['~>A;~>B;~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;']=10},
}
Test { [[
input int A,B,Z,D,F;
var int ret;
par/and do
    ret = await A;
with
    ret = await B;
end;
return ret;
]],
    run = { ['1~>A;2~>B'] = 2 }
}

Test { [[
input int A,B,Z,D,F;
var int ret;
par/or do
    par/and do
        ret = await A;
    with
        ret = await B;
    end;
    par/or do
        par/or do
            ret = await B;
        with
            ret = await Z;
        end;
    with
        ret = await D;
    end;
with
    ret = await F;
end;
return ret;
]],
    run = { ['1~>F'] = 1 }
}

Test { [[
input int A;
var int a = 0;
loop do
    await A;
    a = a + 1;
    break;
end;
await A;
await A;
return a;
]],
    ana = {
        n_unreachs = 1,
    },
    run = { ['0~>A;0~>A;0~>A'] = 1 }
}

Test { [[
input int F;
var int a = 0;
par do
    a = a + 1;
    await FOREVER;
with
    await F;
    return a;
end;
]],
    ana = {
        isForever = false,
    },
    run = { ['~>1min; ~>1min ; 0~>F'] = 1 },
}

Test { [[
input int A;
var int a = await A;
await A;
return a;
]],
    run = {['10~>A;20~>A']=10},
}

Test { [[
input int A;
var int a = await A;
var int b = await A;
return a + b;
]],
    run = { ['10~>A;20~>A']=30, ['3~>A;0~>A;0~>A']=3 }
}

-- A changes twice, but first value must be used
Test { [[
input int A,F;
var int a,f;
par/and do
    a = await A;
with
    f = await F;
end;
return a+f;
]],
    run = { ['1~>A;5~>A;1~>F'] = 2 },
}

Test { [[
input int A,F;
var int a,f;
par/or do
    par do
        a = await A;
    with
        await FOREVER;
    end
with
    f = await F;
end;
return a+f;
]],
    run = { ['1~>A;5~>A;1~>F'] = 2 },
}

-- INTERNAL EVENTS

Test { [[
input void START;
var int ret;
event void a,b;
par/and do
    await START;
    emit a;
with
    await START;
    emit b;
with
    await a;
    ret = 1;    // 12: nd
with
    await b;
    ret = 2;    // 15: nd
end
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = 2,
}

Test { [[
input void START;
var int ret;
event void a,b;
par/and do
    await START;
    emit a;
with
    par/or do
        await START;
    with
        await 1s;
    end
    emit b;
with
    await a;
    ret = 1;        // n_acc
with
    par/or do
        await b;
    with
        await 1s;
    end
    ret = 2;        // n_acc
end
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = 2,
}

Test { [[
input void START;
var int ret;
event void a,b,c,d;
par/and do
    await START;
    emit a;
with
    await START;
    emit b;
with
    await a;
    emit c;
with
    await b;
    emit d;
with
    await c;
    ret = 1;    // 18: n_acc
with
    await d;
    ret = 2;    // 21: n_acc
end
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = 2,
}

Test { [[
event int c;
emit c=10;
await c;
return 0;
]],
    ana = {
        --n_unreachs = 1,
        --isForever = true,
    },
    --trig_wo = 1,
}

-- EX.06: 2 triggers
Test { [[
event int c;
emit c=10;
emit c=10;
return c;
]],
    run = 10,
    --trig_wo = 2,
}

Test { [[
event int a,b;
a = 1;
emit b=a;
return b;
]],
    run = 1,
    --trig_wo = 1,
}

-- ParOr

Test { [[
input void START;
event int a = 3;
par do
    await START;
    emit a=a;
    return a;
with
    loop do
        var int v = await a;
        a = v+1;
    end;
end;
]],
    awaits = 0,
    run = 4,
}

Test { [[
input void START;
event int a = 3;
par do
    await START;
    emit a=a;
    return a;
with
    loop do
        var int v = await a;
        a = v+1;
    end;
end;
]],
    run = 4,
}

Test { [[
var int ret = 0;
event int a = 3;
par/or do
    await a;
    ret = ret + 1;
with
    ret = 5;
end
emit a;
return ret;
]],
    ana = {
        --n_unreachs = 1,
    },
    run = 5,
}

Test { [[
var int[2] v;
var int ret;
par/or do
    ret = v[0];
with
    ret = v[1];
end;
return ret;
]],
    ana = {
        n_acc = 1,
    },
}
Test { [[
input int A;
var int a;
par/or do
    if 1 then
        a = await A;
    end;
with
    a = await A;
end;
return a;
]],
    ana = {
        n_acc  = 1,
    },
    run = { ['10~>A']=10 },
}

Test { [[
input int A,B;
var int a = par do
        await A;
        if 1 then
            await B;
            // unreachable
        end;
        return 0;
    with
        var int v = await A;
        return v;
    end;
return a;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 1,
        --nd_flw = 2,
    },
}

Test { [[
input int A;
var int a;
a = par do
        if 1 then
            var int v = await A;
            return v;
        end;
        return 0;
    with
        var int v = await A;
        return v;
    end;
return a;
]],
    ana = {
        n_acc = 1,
    --nd_flw = 3,
    },
}

Test { [[
input int A;
var int a;
a = par do
    await A;
    if 1 then
        var int v = await A;
        // unreachable
        return v;               // 8
    end;
    return 0;                   // 10
with
    var int v = await A;
    return v;                   // 13
end;
return a;
]],
    ana = {
        --n_unreachs = 1,
        n_acc  = 2,
        --nd_flw  = 2,
    },
    run = { ['1~>A']=1 },
}

Test { [[
input void START;
event int e;
var int v;
par/or do
    await START;
    emit e;
    v = 1;
with
    await e;
    emit e;
    v = 2;
end
return v;
]],
    run = 2,
}

Test { [[
input int A,B;
var int a,v;
a = par do
    if 1 then
        v = await A;
    else
        await B;
        return v;
    end;
    return 0;
with
    var int v = await A;
    return v;
end;
return a;
]],
    ana = {
        n_acc = 1,
        --nd_flw = 2,
    },
}

Test { [[
input int A,B;
var int a,v;
a = par do
    if 1 then
        v = await A;
        return v;
    else
        await B;
        return v;
    end;
    return 0;
with
    var int v = await A;
    return v;
end;
return a;
]],
    ana = {
        n_unreachs = 1,
        n_acc = 1,
        --nd_flw = 2,
    },
    run = { ['1~>A']=1 },
}

Test { [[
input void START;
event void a, b, c, d;
C _assert();
var int v=0;
par do
    loop do
        await START;
        _assert(v==0);
        v = v + 1;
        emit a;
        _assert(v==6);
    end
with
    loop do
        await a;
        _assert(v==1);
        v = v + 1;
        emit b;
        _assert(v==4);
        v = v + 1;
    end
with
    loop do
        await a;
        _assert(v==5);
        v = v + 1;
    end
with
    loop do
        await b;
        _assert(v==2);
        v = v + 1;
        emit c;
        _assert(v==4);
        return v;
    end                 // unreach
with
    loop do
        await c;
        _assert(v==3);
        emit d;
        _assert(v==3);
        v = v + 1;
    end
end
]],
    ana = {
        n_acc = 29,         -- TODO: not checked
        n_unreachs = 1,
    },
    run = 4,
}

Test { [[
input int A;
var int a = 0;
par/or do
    if 1 then
        a = await A;
    end;
with
    if not 1 then
        a = await A;
    end;
end;
return a;
]],
    ana = {
        n_acc  = 1,
    },
    run = 0,
}

-- internal glb awaits
Test { [[
input void START;
event void a;
C _ret_val, _ret_end;
_ret_val = 0;
par do
    loop do
        par/or do
            await a;
            _ret_val = _ret_val + 1;
            _ret_end = 1;
        with
            await a;
            _ret_val = _ret_val + 2;
        end
    end
with
    await START;
    emit a;
    emit a;
end
]],
    ana = {
        isForever = true,
        n_acc = 3,
    },
    awaits = 1,
    run = 1,
}

Test { [[
input void START;
event int a, x, y;
var int ret = 0;
par do
    par/and do
        await START;
        emit x=1;   // 7
        emit y=1;   // 8
    with
        par/or do
            await y;
            return 1;   // 12
        with
            await x;
            return 2;   // 15
        end;
    end;
with
    await START;
    emit x=1;       // 20
    emit y=1;       // 21
end
]],
    ana = {
        n_acc = 3,
    },
    run = 2;
}

Test { [[
input void START;
event void a, b;
par do
    par do
        await a;
        return 1;
    with
        await b;
        return 2;
    end
with
    await START;
    emit b;
with
    await START;
    emit a;
end
]],
    run = 2,
    ana = {
        n_acc = 1,
    },
}

Test { [[
input int A;
var int a, b;
par/and do
    a = await A;
    a = a + 1;
with
    b = await A;
    b = b+1+1;
end;
return a + b;
]],
    run = { ['0~>A']=3, ['5~>A']=13 },
}

Test { [[
input int A,B;
var int a,b,c,d;
par/or do
    par/and do
        a = await A;
    with
        b = await B;
    end;
    c = 1;
with
    par/and do
        b = await B;
    with
        a = await A;
    end;
    d = 2;
end;
return a + b + c + d;
]],
    ana = {
        n_acc = 2,
    },
    run = { ['0~>A;5~>B']=6 },
    --run = { ['0~>A;5~>B']=8 },
    --todo = 'nd kill',
}

Test { [[
input int A,B;
var int a,b,ret;
par/and do
    await A;
    a = 1+2+3+4;
with
    tmp int v = await B;
    b = 100+v;
    ret = a + b;
end;
return ret;
]],
    run = { ['1~>A;10~>B']=120 },
}

Test { [[
input int A,B;
var int a=0,b=0;
par/or do
    if 1 then
        a = await A;
    else
        b = await B;
    end;
with
    if 1 then
        b = await B;
    else
        a = await A;
    end;
end;
return a + b;
]],
    ana = {
        n_acc = 2,
    },
    run = { ['1~>A;10~>B']=1 },
}

Test { [[
par do
    return 1;
with
    return 2;
end;
]],
    ana = {
        n_acc = 1,
        --nd_flw = 2,
    },
}
Test { [[
input int A;
par do
    return 1;
with
    await A;
    return 1;
end;
]],
    ana = {
        --n_unreachs = 1,
        --nd_flw = 1,
    },
    run = 1,
}
Test { [[
input int A;
par do
    var int v = await A;
    return v;
with
    var int v = await A;
    return v;
end;
]],
    --nd_flw = 2,
    ana = {
        n_acc = 1,
    },
    run = { ['1~>A']=1, ['2~>A']=2 },
}

Test { [[
par do
    await FOREVER;
with
    return 10;
end;
]],
    run = 10,
    --nd_flw = 1,
}

Test { [[
input int A,B,Z;
par do
    var int v = await A;
    return v;
with
    var int v = await B;
    return v;
with
    var int v = await Z;
    return v;
end;
]],
    run = { ['1~>A']=1, ['2~>B']=2, ['3~>Z']=3 }
}
Test { [[
par/and do
with
end;
return 1;
]],
    run = 1,
}
Test { [[
par/or do
with
end;
return 1;
]],
    run = 1,
}
Test { [[
input int A,B;
par do
    await A;
    var int v = await A;
    return v;
with
    var int v = await B;
    return v;
end;
]],
    run = {
        ['0~>B'] = 0,
        ['0~>A ; 3~>A'] = 3,
        ['0~>A ; 2~>B'] = 2,
    },
}

Test { [[
input int A,B;
await A;
par do
    var int v = await A;
    return v;
with
    var int v = await B;
    return v;
end;
]],
    run = {
        ['0~>B ; 0~>B ; 1~>A ; 3~>A'] = 3,
        ['0~>B ; 0~>B ; 1~>A ; 3~>B'] = 3,
    },
}
Test { [[
input int A,B,Z;
par do
    await A;
    var int v = await B;
    return v;
with
    await A;
    var int v = await Z;
    return v;
end;
]],
    run = {
        ['0~>B ; 0~>B ; 1~>A ; 3~>B'] = 3,
        ['0~>B ; 0~>B ; 1~>A ; 3~>Z'] = 3,
    },
}
Test { [[
input int A,B,Z;
await A;
par do
    var int v = await B;
    return v;
with
    var int v = await Z;
    return v;
end;
]],
    run = {
        ['0~>B ; 0~>B ; 1~>A ; 3~>B'] = 3,
        ['0~>B ; 0~>B ; 1~>A ; 3~>Z'] = 3,
    },
}

Test { [[
par/or do
    await 10s;
with
    await 10s;
end;
return 1;
]],
    run = {
        ['~>10s'] = 1,
        ['~>20s'] = 1,
    }
}
Test { [[
par do
    var int a = await 10ms;
    return a;
with
    var int b = await 10ms;
    return b;
end;
]],
    --nd_flw = 2,
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>10ms'] = 0,
        ['~>20ms'] = 10000,
    }
}
Test { [[
var int a;
par/or do
    a = await 10ms;
with
    a = await 10ms;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>10ms'] = 0,
        ['~>20ms'] = 10000,
    }
}
Test { [[
var int a=0,b=0;
par/or do
    await 10us;
    await 10us;
    a = 1;
with
    await 20us;
    b = 1;
end;
return a + b;
]],
    run = {
        ['~>20us'] = 1,
        --['~>20us'] = 2,
    },
    --todo = 'nd kill',
}
Test { [[
var int a=0,b=0;
par/or do
    await (10)us;
    await (10)us;
    a = 1;
with
    await 20us;
    b = 1;
end;
return a + b;
]],
    --todo = 'nd kill',
    run = {
        --['~>20us'] = 2,
        ['~>20us'] = 1,
    }
}
Test { [[
var int a=0,b=0;
par/or do
    await (10)us;
    await (10)us;
    a = 1;
with
    await (20)us;
    b = 1;
end;
return a + b;
]],
    --todo = 'nd kill',
    run = {
        ['~>20us'] = 1,
        --['~>20us'] = 2,
    }
}
Test { [[
var int a=0,b=0;
par/or do
    await 10us;
    await 10us;
    a = 1;
with
    await (20)us;
    b = 1;
end;
return a + b;
]],
    --todo = 'nd kill',
    run = {
        ['~>20us'] = 1,
        --['~>20us'] = 2,
    }
}
Test { [[
var int a=100,b=100;
par/or do
    a = await 10us;
with
    b = await (10)us;
end;
return a + b;
]],
    --todo = 'nd kill',
    run = {
        --['~>10us'] = 0,
        ['~>10us'] = 100,
        --['~>20us'] = 20,
        ['~>20us'] = 110,
    }
}
Test { [[
var int a,b;
par do
    a = await 10ms;
    return a;
with
    b = await (10000)us;
    return b;
end;
]],
    ana = {
        n_acc = 1,
        --nd_flw = 2,
    },
}
Test { [[
var int a=0,b=0;
par/or do
    a = await 10ms;
with
    await (5)ms;
    b = await (2)ms;
end;
return a+b;
]],
    run = {
        ['~>10ms'] = 3000,
        ['~>20ms'] = 13000,
    }
}
Test { [[
var int a=0,b=0;
par/or do
    a = await 10ms;
with
    await (5)ms;
    b = await 2ms;
end;
return a+b;
]],
    run = {
        ['~>10ms'] = 3000,
        ['~>20ms'] = 13000,
    }
}
Test { [[
var int a,b;
par do
    a = await 10us;
    return a;
with
    b = await (5)us;
    await 5us;
    return b;
end;
]],
    ana = {
        n_acc = 1,
        --nd_flw = 3,
    },
}
Test { [[
var int a,b;
par do
    a = await 10us;
    return a;
with
    b = await (5)us;
    await 10us;
    return b;
end;
]],
    ana = {
        n_acc = 1,     -- TODO: =0 (await(5) cannot be 0)
    },
}

Test { [[
input void A;
var int v1=0, v2=0;
par/or do
    await 1s;
    v1 = v1 + 1;
with
    loop do
        par/or do
            await 1s;
        with
            await A;
        end
        v2 = v2 + 1;
    end
end
return v1 + v2;
]],
    run = { ['~>A;~>1ms;~>A;~>1ms;~>A;~>1ms;~>A;~>1ms;~>A;~>1ms;~>1s']=6 }
}

Test { [[
input void A;
var int v1=0, v2=0, v3=0;
par/or do
    await 1s;
    v1 = v1 + 1;
with
    loop do
        par/or do
            await 1s;
        with
            await A;
        end
        v2 = v2 + 1;
    end
with
    loop do
        par/or do
            await 1s;
        with
            await A;
            await A;
        end
        v3 = v3 + 1;
    end
end
return v1 + v2 + v3;
]],
    run = { ['~>A;~>1ms;~>A;~>1ms;~>A;~>1ms;~>A;~>1ms;~>A;~>1s']=8 }
}

Test { [[
par do
    loop do
        loop do
            await 1s;
        end
    end
with
    loop do
        await 500ms;
        async do
        end
    end
end
]],
    ana = {
        isForever = true,
        n_unreachs = 1,
    }
}
Test { [[
par do
    loop do
        await 1s;
        loop do
            await 1s;
        end
    end
with
    loop do
        await 1s;
        async do
        end
    end
end
]],
    ana = {
        isForever = true,
        n_unreachs = 1,
    }
}

Test { [[
var int v;
par/or do
    loop do
        break;
    end
    v = 2;
with
    v = 1;
end
return v;
]],
    ana = {
        n_unreachs = 1,
        n_acc = 1,
    },
}

Test { [[
var int v = 1;
loop do
    par/or do
        break;
    with
        v = v + 1;
        await 1s;
    end
    v = v * 2;
end
return v;
]],
    --nd_flw = 1,
    run = 1,
    --run = 2,
    ana = {
        --n_unreachs = 3,
    },
}

Test { [[
input int A;
var int a;
loop do
    par/or do
        await 10ms;
        a = 1;
        break;
    with
        a = 1;
        await A;
    end
end
return 0;
]],
    run = 0,
}
Test { [[
input void A,B;
var int a;
loop do
    par/or do
        await B;
        a = 2;
    with
        a = 1;
        await A;
    end
end
]],
    ana = {
        isForever = true,
    },
}
Test { [[
input int A;
var int a;
loop do
    par/or do
        loop do
            await (10)us;
            await 10ms;
            if 1 then
                a = 1;
                break;
            end
        end
    with
        loop do
            a = 1;
            await A;
        end
    end
end
]],
    ana = {
        isForever = true,
    },
}
Test { [[
input int A;
var int a;
loop do
    par/or do
        loop do
            await 10ms;
            await (10)us;
            if 1 then
                break;
            end;
        end;
    with
        loop do
            await A;
        end;
    end;
end;
]],
    ana = {
        isForever = true,
    },
}
Test { [[
var int v;
par/or do
    await 10ms;
    v = 10;
with
    await (1)ms;
    await 10ms;
    v = 0;
end
return v;
]],
    todo = 'n_acc should be 0',
    simul = {
        n_unreachs = 1,
    },
    run = 10,
}

Test { [[
var int a;
loop do
    par/or do
        loop do
            await (10)us;
            await 10ms;
            if 1 then
                break;
            end;
        end;
        a = 1;
    with
        loop do
            await 10ms;
            a = 1;
        end;
    end;
end;
]],
    ana = {
        isForever = true,
        n_acc = 1,
    },
}
Test { [[
loop do
    await 10ms;
    await (10)us;
    if 1 then
        break;
    end;
end;
return 0;
]],
    run = { ['~>20ms'] = 0 }
}
Test { [[
par do
    loop do
        await (20)ms;
    end;
with
    loop do
        await 20ms;
    end;
end;
]],
    ana = {
        isForever = true
    },
}
Test { [[
var int a;
par/or do
    loop do
        await 10ms;
        await (10)us;
        if 1 then
            break;
        end;
    end;
    a = 1;
with
    loop do
        await 100ms;
        a = 1;
    end;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = { ['~>11ms']=1 },
}
Test { [[
input int A;
loop do
    par/or do
        await 10ms;
        await A;
    with
        await 20ms;
    end;
end;
]],
    ana = {
        isForever = true,
    },
}
Test { [[
var int a;
loop do
    par/or do
        loop do
            await 10ms;
            await (10)us;
            if 1 then
                break;
            end;
        end;
        a = 1;
    with
        loop do
            await 10ms;
            a = 1;
        end;
    end;
end;
]],
    ana = {
        isForever = true,
        n_acc = 1,
    },
}
Test { [[
var int a;
loop do
    par/or do
        loop do
            await (10)us;
            await 10ms;
            if 1 then
                break;
            end;
        end;
        a = 1;
    with
        loop do
            await 100ms;
            a = 1;
        end;
    end;
end;
]],
    ana = {
        isForever = true,
        n_acc = 1,
    },
}
Test { [[
var int a,b;
par/or do
    a = await 10ms;
    return a;
with
    b = await (5)us;
    await 11ms;
    return b;
end;
]],
    todo = 'await(x) pode ser <0?',  -- TIME_undef
    ana = {
        n_acc = 1,
    },
}
Test { [[
var int a,b;
par do
    a = await 10ms;
    return a;
with
    b = await (10000)us;
    return b;
end;
]],
    --nd_flw = 2,
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>10ms'] = 0,
        ['~>20ms'] = 10000,
    }
}
Test { [[
var int a,b;
par/and do
    a = await 10us;
with
    b = await (9)us;
end;
return a+b;
]],
    run = {
        ['~>10us'] = 1,
        ['~>20us'] = 21,
    }
}
Test { [[
var int a,b,c;
par do
    a = await 10us;
    return a;
with
    b = await (9)us;
    return b;
with
    c = await (8)us;
    return c;
end;
]],
    ana = {
        n_acc = 3,
        --nd_flw = 6,
    },
}
Test { [[
var int a=0,b=0,c=0;
par/or do
    a = await 10us;
with
    b = await (9)us;
with
    c = await (8)us;
end;
return a+b+c;
]],
    run = {
        ['~>10us'] = 2,
        ['~>20us'] = 12,
    }
}
Test { [[
var int a,b,c;
par/and do
    a = await 10ms;
with
    b = await (9000)us;
with
    c = await (8000)us;
end;
return a+b+c;
]],
    run = {
        ['~>10ms'] = 3000,
        ['~>20ms'] = 33000,
    }
}
Test { [[
var int a,b,c;
par do
    a = await 10us;
    return a;
with
    b = await (10)us;
    return b;
with
    c = await 10us;
    return c;
end;
]],
    ana = {
        --nd_flw = 6,
        n_acc = 3,
    },
}
Test { [[
var s32 a,b;
par do
    a = await 10min;
    return a;
with
    b = await 20min;
    return b;
end;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 1,
    },
    run = {
        ['~>10min']  = 0,
        ['~>20min']  = 600000000,
    }
}
Test { [[
await 35min;
return 0;
]],
    val = 'ERR : line 1 : constant is out of range',
}
Test { [[
var int a = 2;
par/or do
    await 10s;
with
    await 20s;
    a = 0;
end;
return a;
]],
    ana = {
        --n_unreachs = 1,
    },
    run = {
        ['~>10s'] = 2,
        ['~>20s'] = 2,
        ['~>30s'] = 2,
    }
}
Test { [[
var int a = 2;
par/or do
    await (10)us;
with
    await 20ms;
    a = 0;
end;
return a;
]],
    run = {
        ['~>10ms'] = 2,
        ['~>20ms'] = 2,
        ['~>30ms'] = 2,
    }
}
Test { [[
var int a = 2;
par/or do
    tmp int b = await (10)us;
    a = b;
with
    await 20ms;
    a = 0;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}
Test { [[
var s32 v1,v2;
par do
    v1 = await 5min;
    return v1;
with
    await 1min;
    v2 = await 4min;
    return v2;
end;
]],
    --nd_flw = 2,
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>1min ; ~>1min ; ~>1min ; ~>1min ; ~>1min'] = 0,
        ['~>2min ; ~>4min'] = 60000000,
        ['~>4min ; ~>1min'] = 0,
    }
}

Test { [[
input int A;
loop do
    await 10ms;
    await A;
    await 10ms;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
input int A;
loop do
    await A;
    await 10ms;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
input int A;
loop do
    await A;
    await 10ms;
    await A;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
input int A;
loop do
    await 10ms;
    await A;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
loop do
    await 10ms;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
input int F;
var int a;
par do
    await 5s;
    await FOREVER;
with
    a = 0;
    loop do
        await 1s;
        a = a + 1;
    end;
with
    await F;
    return a;
end;
]],
    run = { ['~>10s;~>F']=10 }
}

Test { [[
input int F;
do
    var int a=0, b=0, c=0;
    par do
        loop do
            await 10ms;
            a = a + 1;
        end;
    with
        loop do
            await 100ms;
            b = b + 1;
        end;
    with
        loop do
            await 1000ms;
            c = c + 1;
        end;
    with
        await F;
        return a + b + c;
    end;
end;
]],
    run = {
        ['~>999ms; ~>F'] = 108,
        ['~>5s; ~>F'] = 555,
        ['~>F'] = 0,
    }
}

    -- TIME LATE

Test { [[
input int F;
var int late = 0;
var int v;
par do
    loop do
        v = await 1ms;
        late = late + v;
    end;
with
    await F;
    return late;
end;
]],
    run = {
        ['~>1ms; ~>1ms; ~>1ms; ~>1ms; ~>1ms; 1~>F'] = 0,
        ['~>1ms; ~>1ms; ~>1ms; ~>10ms; 1~>F'] = 45000,
        ['~>1ms; ~>1ms; ~>2ms; 1~>F'] = 1000,
        ['~>2ms; 1~>F'] = 1000,
        ['~>2ms; ~>2ms; 1~>F'] = 2000,
        ['~>4ms; 1~>F'] = 6000,
        ['1~>F'] = 0,
    }
}

Test { [[
input int A;
par do
    var int v = await A;
    return v;
with
    var int v = await (1)us;
    return v;
end;
]],
    run = {
        ['~>10us'] = 9,
        ['10~>A'] = 10,
    }
}

Test { [[
var int v;
par/or do
    v = await 10us;
with
    v = await (1)us;
end;
return v;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>1us'] = 0,
        ['~>20us'] = 19,
    }
}

Test { [[
input int A;
var int a;
par/or do
    a = await A;
with
    a = await (1)us;
end;
return a;
]],
    run = {
        ['~>10us'] = 9,
        ['10~>A'] = 10,
    }
}

Test { [[
input int A;
var int a;
par/or do
    a = await 30us;
with
    a = await A;
end;
return a;
]],
    run = {
        ['~>30us'] = 0,
        ['~>60us'] = 30,
        ['10~>A'] = 10,
    }
}

-- 1st to test timer clean
Test { [[
input int A, F;
var int a;
par/or do
    a = await 10min;
with
    a = await A;
end;
await F;
return a;
]],
    run = {
        ['1~>A  ; 1~>F'] = 1,
        ['~>10min ; 1~>F'] = 0,
        ['~>10min ; 1~>A ; 1~>F'] = 0,
        ['1~>A  ; ~>10min; 1~>F'] = 1,
    }
}

Test { [[
C _assert();
input void T;
var int ret = 0;
par/or do
    loop do
        tmp int late = await 10ms;
        ret = ret + late;
        _assert(late <= 10000);
    end
with
    loop do
        var int i = 0;
        var int t;
        par/or do
            t = await 1s;
        with
            loop do
                await T;
                i = i + 1;
            end
        end
    end
with
    async do
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
        emit 12ms;
        emit T;
    end
end
return ret;
]],
    run = 72000,
}

Test { [[
input void START;
event int a;
var int ret = 1;
par/or do
    await START;
    emit a=10;
with
    ret = await a;
end;
return ret;
]],
    run = 10,
}

Test { [[
event int a;
var int ret = 1;
par/or do
    emit a=10;
with
    ret = await a;
end;
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = 1,
}

Test { [[
input void START;
event int a;
var int ret = 1;
par/and do
    await START;
    emit a=10;
with
    ret = await a;
end;
return ret;
]],
    ana = {
        --n_acc = 1,
    },
    run = 10,
}
Test { [[
event int a;
par/and do
    await a;
with
    emit a=1;
end;
return 10;
]],
    ana = {
        n_acc = 1,
    },
    run = 0,
}

Test { [[
input int A;
event int b, c;
par do
    await A;
    emit b=1;
    await c;
    return 10;
with
    await b;
    await A;
    emit c=10;
    // unreachable
    await c;
    // unreachable
    return 0;
end;
]],
    ana = {
        isForever = false,
        --n_unreachs = 2,
        --nd_esc = 1,
        n_acc = 1,
    },
    run = {
        ['0~>A ; 0~>A'] = 10,
    }
}

Test { [[
input int A;
var int a = 1;
loop do
    par/or do
        a = await A;
    with
        a = await A;
    end;
end;
]],
    ana = {
        isForever = true,
        n_acc = 1,
    },
}
Test { [[
event int a;
par/or do
    return 1;       // TODO: [false]=true
with
    emit a=1;       // TODO: elimina o [false]
    // unreachable
end;
// unreachable
await a;
// unreachable
return 0;
]],
    ana = {
        --n_unreachs = 3,
        --nd_esc = 1,
        --nd_flw = 1,
    },
    run = 1,
    --trig_wo = 1,
    --todo = 'nd kill',
}
-- TODO: nd_flw?
Test { [[
event int a;
par/or do
with
    emit a=1;
    // unreachable
end;
// unreachable
await a;
// unreachable
return 0;
]],
    ana = {
        --n_unreachs = 2,
        --isForever = true,
        --nd_esc = 1,
    },
    --dfa = 'unreachable statement',
    --trig_wo = 1,
}
Test { [[
event int a;
par do
    return 1;
with
    emit a=1;
    // unreachable
end;
]],
    ana = {
        --n_unreachs = 1,
        --nd_esc = 1,
        --nd_flw = 1,
    },
    run = 1,
    --trig_wo = 1,
}
Test { [[
event int a;
par do
    emit a=1;
    return 0;
with
    return 2;
end;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 1,
        --nd_esc = 1,
        --nd_flw = 1,
        --trig_wo = 1,
    },
    run = false,    -- TODO: stack change
    --run = 2,
}
Test { [[
event int a;
par/or do
    emit a=1;
with
end;
await a;
return 0;
]],
    ana = {
        --n_unreachs = 2,
        --nd_esc = 1,
        --isForever = true,
    },
    --trig_wo = 1,
}

Test { [[
event int a;
var int v1=0,v2=0;
par/or do
    emit a=2;
    v1 = 3;
with
    v2 = 2;
end
return v1+v2;
]],
    ana = {
        --n_unreachs = 1,
        --nd_esc = 1,
    },
    --run = 4,        -- TODO: stack change
    run = 3,
    --todo = 'nd kill',
}

Test { [[
event int a;
var int v1=0,v2=0,v3=0;
par/or do
    emit a=2;
    v1 = 2;
with
    v2 = 2;
with
    await a;
    v3 = 2;
end
return v1+v2+v3;
]],
    ana = {
        --n_unreachs = 2,
        n_acc = 1,
        --nd_esc = 1,
    },
    --run = 4,        -- TODO: stack change
    run = 2,
    --todo = 'nd kill',
}

Test { [[
event int a;
var int v1=0,v2=0,v3=0;
par/or do
    emit a=2;
    v1 = 2;
with
    await a;
    v3 = 2;
with
    v2 = 2;
end
return v1+v2+v3;
]],
    ana = {
        --n_unreachs = 2,
        n_acc = 1,
        --nd_esc = 1,
    },
    --run = 4,        -- TODO: stack change
    run = 2,
    --todo = 'nd kill',
}


Test { [[
var int ret = 0;
par/or do
    ret = 1;
with
    ret = 2;
end
ret = ret * 2;
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = 2,
}

-- 1st to escape and terminate
Test { [[
event int a;
var int ret=9;
par/or do
    par/or do
        emit a=2;
    with
        ret = 3;
    end;
with
    await a;
    ret = a + 1;
end;
return ret;
]],
    ana = {
        --n_unreachs = 2,
        --nd_esc = 2,
        n_acc = 1,
    },
    --run = 3,
    run = 9,
}

-- 1st to escape and terminate
Test { [[
event int a;
var int ret=9;
par/or do
    par/or do
        emit a=2;
    with
        ret = 3;
    end;
with
    await a;
    ret = a + 1;
end;
return ret;
]],
    ana = {
        --n_unreachs = 2,
        --nd_esc = 2,
        n_acc = 1,
    },
    --run = 3,
    run = 9,
}

-- 1st to escape and terminate
Test { [[
event int a;
var int ret=9;
par/or do
    await a;
    ret = a + 1;
with
    par/or do
        emit a=2;
    with
        ret = 3;
    end;
end;
return ret;
]],
    ana = {
        --n_unreachs = 2,
        --nd_esc = 2,
        n_acc = 1,
    },
    --run = 3,
    run = 9,
}

Test { [[
input int A;
var int a;
par do
    a = await A;
    return a;
with
    a = await A;
    return a;
end;
]],
    ana = {
        n_acc = 4,
    --nd_flw = 2,
    },
    run = { ['5~>A']=5 },
}
Test { [[
input int A;
var int a;
par/or do
    a = await A;
with
    await A;
end;
return a;
]],
    run = {
        ['1~>A'] = 1,
        ['2~>A'] = 2,
    },
    --todo = 'nd kill',
}
Test { [[
input int A;
var int a=10;
par/or do
    await A;
with
    a = await A;
end;
return a;
]],
    run = {
        --['1~>A'] = 1,
        --['2~>A'] = 2,
        ['1~>A'] = 10,
        ['2~>A'] = 10,
    }
}
Test { [[
input int A;
var int a;
par/or do
    await A;
    a = 10;
with
    await A;
    var int v = a;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['1~>A'] = 10,
        ['2~>A'] = 10,
    },
    --todo = 'nd kill',
}

Test { [[
input int A;
var int a;
par/or do
    await A;
    a = 10;
with
    await A;
    a = 11;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
input int A;
var int a;
par/or do
    await A;
    a = 10;
with
    await A;
    return a;
end;
return a;
]],
    ana = {
        n_acc = 1,
    --nd_flw = 1,
    },
}

Test { [[
input int A;
loop do
    par/or do
        await A;
    with
        await A;
        if 1 then
            break;
        end;
    end;
end;
return 0;
]],
    --nd_flw = 1,
    run = 0,
}

Test { [[
input int A;
loop do
    loop do
        par/or do
            await 1s;
        with
            if 0 then
                await A;
                break;
            end;
        end;
        await FOREVER;
    end;
end;
]],
    ana = {
        n_unreachs = 1,
        isForever = true,
    },
}

Test { [[
input int A,B;

loop do
    par/or do
        await B;
    with
        await A;
        if 1 then
            break;
        end;
    end;
end;

par do
    loop do
        await A;
    end;

with
    loop do
        await 2s;
    end;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
input int A;
var int a = par do
    await A;
    var int v = 10;
    return a;
with
    await A;
    return a;
end;
return a;
]],
    todo = '"a"s deveriam ser diferentes',
    ana = {
        n_acc = 1,
        --nd_flw = 2,
    },
}

Test { [[
input int A,B;
var int a = 5;
par/or do
    par/or do
        await A;
    with
        await B;
    end;
    a = 10;
with
    await A;
    return a;
end;
return a;
]],
    run = { ['~>A']=10, ['~>B']=10 },
    ana = {
        n_acc = 1,
        --nd_flw = 1,
    },
    --todo = 'nd kill',
}

Test { [[
input int A,B;
var int a = 5;
par/or do
    par/and do
        await A;
    with
        await B;
    end;
    a = 10;
with
    await A;
    return a;
end;
return a;
]],
    run = { ['~>A']=5, ['~>B;~>A']=10 },
    ana = {
        n_acc = 1,
        --nd_flw = 1,
    },
    --todo = 'nd kill',
}

Test { [[
input int A,B;
var int a = 0;
par/or do
    par/or do
        var int v = await A;
        return v;
    with
        await B;
    end;
    a = 10;
with
    await A;
end;
return a;
]],
    --nd_flw = 1,
    run = {
        ['1~>B'] = 10,
        --['2~>A'] = 1,
    }
}

Test { [[
input int A, Z;
var int v;
loop do
    par/or do
        await A;
    with
        v = await Z;
        break;
    end;
end;
return v;
]],
    run = {
        ['0~>A ; 0~>A ; 3~>Z'] = 3,
        ['0~>A ; 0~>A ; 4~>Z'] = 4,
    }
}
Test { [[
input int A,B,Z;
var int v;
loop do
    par/or do
        await A;
        await B;
    with
        v = await Z;
        break;
    end;
end;
return v;
]],
    run = {
        ['0~>A ; 0~>A ; 3~>Z'] = 3,
        ['0~>A ; 0~>A ; 0~>B ; 1~>B ; 4~>Z'] = 4,
    }
}
Test { [[
input int A,B,Z;
var int v;
loop do
    par/or do
        await A;
        await B;
    with
        v = await Z;
        break;
    end;
end;
return v;
]],
    run = {
        ['0~>A ; 0~>A ; 3~>Z'] = 3,
        ['0~>A ; 0~>A ; 0~>B ; 1~>B ; 4~>Z'] = 4,
    }
}
Test { [[
input int A,B;
var int v;
loop do
    par do
        await A;
        await B;
    with
        v = await A;
        break;
    end;
end;
return v;
]],
    ana = {
        n_unreachs = 1,
        --nd_flw = 1,
    },
    run = {
        ['0~>B ; 0~>B ; 3~>A'] = 3,
    }
}
Test { [[
input int A,B;
var int v;
loop do
    par/or do
        await A;
        await B;
    with
        v = await A;
        break;
    end;
end;
return v;
]],
    ana = {
        --n_unreachs = 3,
        --dfa = 'unreachable statement',
        --nd_flw = 1,
    },
    run = {
        ['0~>B ; 0~>B ; 3~>A'] = 3,
    }
}
Test { [[
input int A, B;
var int v;
loop do
    par/or do
        v = await A;
        v = await A;
        break;
    with
        v = await A;
        await B;
    end;
end;
return v;
]],
    ana = {
        n_acc = 2,     -- TODO: should be 0
    },
    run = {
        ['0~>B ; 0~>A ; 0~>B ; 0~>A ; 3~>A'] = 3,
    }
}
Test{ [[
input int A;
var int v;
loop do
    v = await A;
    break;
end;
return v;
]],
    ana = {
        n_unreachs = 1,
    },
    run = {
        ['1~>A'] = 1,
        ['2~>A'] = 2,
    }
}

Test { [[
input int A;
var int a;
par/and do
    a = await 30ms;
with
    await A;
end;
return a;
]],
    run = {
        ['~>30ms ; 0~>A'] = 0,
        ['0~>A   ; ~>30ms'] = 0,
        ['~>60ms ; 0~>A'] = 30000,
        ['0~>A   ; ~>60ms'] = 30000,
    }
}

Test { [[
input int A,B;
par/and do
    await A;
with
    await B;
    await A;
end;
return 1;
]],
    run = {
        ['1~>A ; 0~>B ; 0~>B ; 1~>A'] = 1,
    }
}
Test { [[
input int A;
par/and do
    await 30ms;
with
    await A;
    await 30ms;
end;
return 1;
]],
    run = {
        ['~>30ms ; 0~>A ; ~>50ms'] = 1,
        ['0~>A ; ~>40ms'] = 1,
        ['0~>A ; ~>20ms ; ~>20ms'] = 1,
    }
}
Test { [[
input int A;
par/and do
    await 30ms;
with
    await A;
    await (30)us;
end;
return 1;
]],
    run = {
        ['~>30ms ; 0~>A ; ~>50ms'] = 1,
        ['0~>A ; ~>40ms'] = 1,
        ['0~>A ; ~>20ms ; ~>20ms'] = 1,
    }
}

Test { [[
input void START;
event int a,b,c;
par/and do
    await START;
    emit b=1;
    emit c=1;
with
    await b;
    par/or do
    with
        par/or do
        with
            c = 5;
        end;
    end;
end;
return c;
]],
    run = 1,
}

Test { [[
input int A;
var int a;
par/and do
    await 30ms;
    a = 1;
with
    await A;
    await 30ms;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>30ms ; 0~>A ; ~>50ms'] = 2,
        ['~>1ms ; 0~>A ; ~>40ms'] = 2,
        ['~>1ms ; 0~>A ; ~>20ms ; ~>20ms'] = 2,
    }
}

-- tests AwaitT after Ext
Test { [[
input int A;
var int a;
par/and do
    await A;
    await 30ms;
    a = 2;
with
    await 30ms;
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>30ms ; 0~>A ; ~>50ms'] = 2,
        ['~>1us; 0~>A ; ~>40ms'] = 2,
        ['~>1us; 0~>A ; ~>20ms ; ~>20ms'] = 2,
    }
}

Test { [[
input int A;
var int a;
par/and do
    await 30ms;
    a = 1;
with
    await A;
    await 30ms;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>30ms ; 0~>A ; ~>50ms'] = 2,
        ['~>1ms ; 0~>A ; ~>40ms'] = 2,
        ['~>1ms ; 0~>A ; ~>20ms ; ~>20ms'] = 2,
    }
}

Test { [[
input void A;
var int a;
par/and do
    await A;
    await A;
    await 100ms;
    a = 1;
with
    await A;
    await A;
    await 10ms;
    await A;
    await 90ms;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>A ; ~>A ; ~>12ms; ~>A; ~>91ms'] = 2,
    }
}

Test { [[
input int A;
var int dt;
par/or do
    dt = await 20ms;
with
    await A;
    dt = await 20ms;
end;
return dt;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>30ms'] = 10000,
        ['0~>A ; ~>40ms'] = 20000,
        ['~>10ms ; 0~>A ; ~>40ms'] = 30000,
    }
}
Test { [[
input int A;
var int dt;
par/or do
    await A;
    dt = await 20ms;
with
    dt = await 20ms;
end;
return dt;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>30ms'] = 10000,
        ['0~>A ; ~>40ms'] = 20000,
        ['~>10ms ; 0~>A ; ~>40ms'] = 30000,
    }
}
Test { [[
input int A;
var int dt;
par/or do
    dt = await 20us;
with
    await A;
    dt = await 10us;
end;
return dt;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>30us'] = 10,
        ['~>1us ; 0~>A ; ~>12us'] = 2,
        ['~>1us ; 0~>A ; ~>13us'] = 3,
    }
}
Test { [[
input int A;
var int dt;
par/or do
    dt = await 20ms;
with
    dt = await 10ms;
    await A;
    dt = await 10ms;
end;
return dt;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 2,
    },
    run = {
        ['~>30ms'] = 10000,
        ['~>12ms ; 0~>A ; ~>8ms'] = 0,
        ['~>15ms ; 0~>A ; ~>10ms'] = 5000,
    }
}

Test { [[
input int A;
var int dt;
par do
    dt = await 20us;
    return 1;
with
    dt = await 10us;
    await A;
    dt = await 10us;
    return 2;
end;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 3,
    },
    run = {
        ['~>30us'] = 1,
        ['~>12us ; 0~>A ; ~>8us'] = 1,
        ['~>15us ; 0~>A ; ~>10us'] = 1,
    }
}

Test { [[
input int A,B;
var int ret;
par/or do
    await A;
    await 20ms;
    ret = 1;
with
    await B;
    await 20ms;
    ret = 2;
end;
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>1us; 1~>A;~>25ms'] = 1,
        ['~>1us; 1~>A;~>1us; 1~>B;~>25ms'] = 1,
        ['~>1us; 1~>B;~>25ms'] = 2,
        ['~>1us; 1~>B;~>1us; 1~>A;~>25ms'] = 2,
    }
}

Test { [[
input int A,B;
var int ret;
par/or do
    await B;
    await 20ms;
    ret = 2;
with
    await A;
    await 20ms;
    ret = 1;
end;
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>1us; 1~>A;~>25ms'] = 1,
        ['~>1us; 1~>A;~>1us; 1~>B;~>25ms'] = 1,
        ['~>1us; 1~>B;~>25ms'] = 2,
        ['~>1us; 1~>B;~>1us; 1~>A;~>25ms'] = 2,
    }
}

Test { [[
input int A;
var int dt;
par/or do
    dt = await 20ms;
with
    await A;
    await 10ms;
    dt = await 10ms;
end;
return dt;
]],
    ana = {
        n_acc = 1,
        --n_unreachs = 1,
    },
    run = {
        ['~>30ms'] = 10000,
        ['~>12ms ; 0~>A ; ~>8ms'] = 0,
        ['~>15ms ; 0~>A ; ~>10ms'] = 5000,
    }
}

Test { [[
input int A,B;
var int dt;
par/or do
    await A;
    dt = await 20ms;
with
    await B;
    dt = await 20ms;
end;
return dt;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>30ms ; 0~>A ; ~>21ms'] = 1000,
        ['~>12ms ; 0~>A ; ~>1us; 0~>B ; ~>27ms'] = 7001,
        ['~>12ms ; 0~>B ; ~>3ms ; 0~>A ; ~>20ms'] = 3000,
    }
}

Test { [[
input int A,B;
var int dt;
par/or do
    await A;
    dt = await 20ms;
with
    await B;
    dt = await (20)ms;
end;
return dt;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>30ms ; 0~>A ; ~>21ms'] = 1000,
        ['~>12ms ; 0~>A ; ~>1ms ; 0~>B ; ~>27ms'] = 8000,
        ['~>12ms ; 0~>B ; ~>3ms ; 0~>A ; ~>20ms'] = 3000,
    }
}

Test { [[
input int A,B;
var int dt;
var int ret = 10;
par/or do
    await A;
    dt = await 20ms;
    ret = 1;
with
    await B;
    dt = await (20)ms;
    ret = 2;
end;
return ret;
]],
    ana = {
        n_acc = 2,
    },
    run = {
        ['~>30ms ; 0~>A ; ~>25ms'] = 1,
        ['~>12ms ; 0~>A ; ~>1ms ; 0~>B ; ~>27ms'] = 1,
        ['~>12ms ; 0~>B ; ~>3ms ; 0~>A ; ~>20ms'] = 2,
    }
}

Test { [[
input int A, B;
var int dt;
var int ret = 10;
par/or do
    await A;
    dt = await 20ms;
    ret = 1;
with
    await B;
    dt = await 20ms;
    ret = 2;
end;
return ret;
]],
    ana = {
        n_acc = 2,
    },
    run = {
        ['~>12ms ; 0~>A ; ~>1ms ; 0~>B ; ~>27ms'] = 1,
        ['~>12ms ; 0~>B ; ~>1ms ; 0~>A ; ~>26ms'] = 2,
    }
}

-- Boa comparacao de n_unreachs vs nd_flw para timers
Test { [[
var int dt;
par/or do
    await 10ms;
    dt = await 10ms;
with
    dt = await 30ms;
end;
return dt;
]],
    ana = {
        n_acc = 1,
        --n_unreachs = 1, -- apos ~30
    },
    run = {
        ['~>12ms ; ~>17ms'] = 9000,
    }
}
Test { [[
var int dt;
par/or do
    await 10us;
    dt = await (10)us;
with
    dt = await 30us;
end;
return dt;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['~>12us ; ~>17us'] = 9,
    }
}

Test { [[
input int A,B;
var int ret;
par/or do
    await A;
    await 10ms;
    ret = 0;
with
    await B;
    await 10ms;
    ret = 1;
end;
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['0~>A ; ~>1ms ; 0~>B ; ~>21ms'] = 0,
        ['0~>B ; ~>1ms ; 0~>A ; ~>21ms'] = 1,
        ['0~>A ; ~>1ms ; 0~>B ; ~>21ms'] = 0,
        ['0~>B ; ~>1ms ; 0~>A ; ~>21ms'] = 1,
    }
}

Test { [[
event int a, b;
var int x;
par/or do
    await a;
    await 10ms;
    x = 0;
with
    await b;        // 8
    emit a=b;
    await 10ms;
    x = 1;
with
    emit b=1;       // 13
    x = 2;
    await FOREVER;
end;
return x;
]],
    ana = {
        n_acc  = 2,    -- TODO: timer kills timer
        n_unreachs = 0,    -- TODO: timer kills timer
    },
    --run = { ['~>10ms']=0 },
}

Test { [[
event int a, b, x;
par/or do
    await a;
    await 10ms;
    x = 0;
with
    await b;
    await 10ms;
    x = 1;
with
    emit b=1;
    emit a=b;
    x = 2;
    await FOREVER;
end;
return x;
]],
    ana = {
        n_acc = 3,     -- TODO: timer kills timer
    n_unreachs = 0,    -- TODO: timer kills timer
    },
    --run = { ['~>10ms']=0 },   -- TODO: intl timer
}

Test { [[
event int a, b;
var int x;
par/or do
    await a;
    await 10ms;
    x = 1;
with
    await b;
    await 10ms;
    x = 0;
with
    b = 1;
    a = b;
    x = a;
end;
return x;
]],
    ana = {
        n_acc = 1,
        --n_unreachs = 4,
    },
    run = 1,
}

Test { [[
input int A,B;
par do
    par/or do
        await A;
    with
        await B;
    end;
    return 1;
with
    await A;
    return 2;
end;
]],
    ana = {
        n_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
input int A,B;
par do
    par/and do
        await A;
    with
        await B;
    end;
    return 1;
with
    await A;
    return 2;
end;
]],
    ana = {
        n_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
input int A,B, Z;
par do
    loop do
        par/or do
            await A;
            break;
        with
            await Z;
        with
            await B;
            break;
        end;
        await Z;
    end;
    return 1;
with
    await A;
    return 2;
end;
]],
    ana = {
        n_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
input int A,B;
var int a = 0;
par/or do
    par/or do
        await A;
    with
        await B;
    end;
    await 10ms;
    var int v = a;
with
    await B;
    await 10ms;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['0~>A ; ~>1ms ; 0~>B ; ~>20ms'] = 0,
    }
}

Test { [[
input int A,B;
var int a = 0;
par/or do
    await A;
    await B;
    await 10ms;
    var int v = a;
with
    await B;
    await 10ms;
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
input int A,B;
var int a = 0;
par/or do
    par/and do
        await A;
    with
        await B;
        await 10ms;
    end;
    var int v = a;
with
    await B;
    await 20ms;
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['1~>A;~>10ms;1~>B;~>25ms'] = 0,
        ['~>10ms;1~>B;~>25ms'] = 1,
    }
}

Test { [[
input int A,B;
var int a = 0;
par/or do
    par/or do
        await A;
    with
        await B;
        await (10)us;
    end;
    await 10us;
    var int v = a;
with
    await A;
    await B;
    await (20)us;
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['0~>A ; 0~>B ; ~>21us'] = 0,
    }
}
Test { [[
input int A,B;
var int a;
par/or do
    par/and do
        await A;
    with
        await B;
        await 10ms;
    end;
    await 10ms;
    var int v = a;
with
    await A;
    await B;
    await 20ms;
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
var int a;
par/or do
    await 10ms;
    var int v = a;
with
    await 10ms;
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
input int A;
var int v;
par do
    loop do
        await A;
        await A;
        v = 1;
    end;
with
    loop do
        await A;
        await A;
        await A;
        v = 2;
    end;
end;
]],
    ana = {
        isForever = true,
        n_acc = 1,
    },
}

Test { [[
input int A,B;
var int v;
par do
    loop do
        await A;
        v = 1;
    end;
with
    loop do
        await A;
        await B;
        await A;
        v = 2;
    end;
end;
]],
    ana = {
        isForever = true,
        n_acc = 1,       -- fiz na mao!
    },
}
-- bom exemplo de explosao de estados!!!
Test { [[
input int A,B;
var int v;
par do
    loop do
        await A;
        await A;
        v = 1;
    end;
with
    loop do
        await A;
        await B;
        await A;
        await A;
        v = 2;
    end;
end;
]],
    ana = {
        isForever = true,
        n_acc = 1,       -- nao fiz na mao!!!
    },
}

-- EX.04: join
Test { [[
input int A,B;
var int a;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    a = 1;
with
    await A;
    await B;
end;
return a;
]],
    run = {
        ['0~>A ; 0~>B'] = 1,
        ['0~>B ; 0 ~>A ; 0~>B'] = 1,
    }
}

Test { [[
input int A;
var int a;
par/and do
    if a then
        await A;
    else
        await A;
        await A;
        var int v = a;
    end;
with
    await A;
    a = await A;
with
    await A;
    await A;
    a = await A;
end;
return a;
]],
    ana = {
        --n_acc = 1,
        n_acc = 3,
    },
}
Test { [[
input int A;
var int a;
if a then
    await A;
else
    par/and do
        await A;
        await A;
        var int v = a;
    with
        await A;
        a = await A;
    with
        await A;
        await A;
        a = await A;
    end;
end;
return a;
]],
    ana = {
        --n_acc = 1,
        n_acc = 3,
    },
}
Test { [[
input int A;
var int a;
par do
    loop do
        if a then
            await A;
        else
            await A;
            await A;
            var int v = a;
        end;
    end;
with
    loop do
        await A;
        a = await A;
    end;
with
    loop do
        await A;
        await A;
        a = await A;
    end;
end;
]],
    ana = {
        isForever = true,
        n_acc = 3,
    },
}
Test { [[
var int v = par do
            return 0;
        with
            return 0;
        end;
if v then
    return 1;
else
    if 1==1 then
        return 1;
    else
        return 0;
    end;
end;
]],
    ana = {
        n_acc = 1,
    --nd_flw = 2,
    },
}
Test { [[
var int a;
var int v = par do
            return 0;
        with
            return 0;
        end;
if v then
    a = 1;
else
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    --nd_flw = 2,
    },
}
Test { [[
var int v = par do
            return 1;
        with
            return 2;
        end;
return v;
]],
    ana = {
        n_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
var int a;
par/or do
    loop do
        await 10ms;
        a = 1;
    end;
with
    await 100ms;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}
Test { [[
var int a;
par/or do
    await (10)us;
    a = 1;
with
    await (5)us;
    await (10)us;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}
Test { [[
input int A;
var int a;
par/or do
    await (10)us;
    await A;
    a = 1;
with
    await (5)us;
    await A;
    await (10)us;
    await A;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}
Test { [[
input int A;
var int a;
par/or do
    await (10)us;
    await A;
    a = 1;
with
    await (5)us;
    await A;
    await A;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}
Test { [[
input int A;
var int a;
par/or do
    await 10ms;
    await A;
    a = 1;
with
    await (5)us;
    await A;
    await A;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
var int a;
par/or do
    await (10)us;
    await 10ms;
    a = 1;
with
    await 10ms;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
var int a;
par/or do
    loop do
        await 10ms;
        if (1) then
            break;
        end;
    end;
    a = 1;
with
    await 100ms;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
var int a;
par/or do
    loop do
        await 11ms;
        if (1) then
            break;
        end;
    end;
    a = 1;
with
    await 100ms;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
input int A;
var int a;
par/or do
    await 10ms;
    await A;
    a = 1;
with
    await (10)us;
    await A;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
input int A;
var int a;
par/or do
    await (10)us;
    await A;
    a = 1;
with
    await (10)us;
    await A;
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
input int A;
var int a;
par/or do
    await A;
    await 10ms;
    a = 1;
with
    await 10ms;
    a = 2;
end;
return a;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 1,
    },
    run = {
        ['~>10ms'] = 2,
        ['~>1ms ; 1~>A ; ~>10ms'] = 2,
    }
}

Test { [[
var int a;
await (10)us;
par/or do
    await 10ms;
    a = 2;
with
    await 20ms;
    a = 3;
end
return a;
]],
    todo = 'wclk_any=0',
    ana = {
        n_unreachs = 1,
    },
    run = { ['~>1s']=2 },
}
Test { [[
input int A;
var int a;
par/or do
    await (10)us;
    a = 1;
    par/or do
        await 10ms;
        a = 2;
        await A;
    with
        await 20ms;
        a = 3;
        await A;
    end;
with
    await 30ms;
    a = 4;
end;
return a;
]],
    todo = 'wclk_any=0',
    ana = {
        n_acc = 3,
    },
}

Test { [[
input int A;
var int a;
par/or do
    await A;
    await (10)us;
    a = 1;
with
    await (10)us;
    a = 2;
end;
return a;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 1,
    },
    run = {
        ['~>10ms'] = 2,
        ['~>1ms; ~>A ; ~>10ms'] = 2,
    }
}

Test { [[
var int x;
par/or do
    await 12ms;
    x = 0;
with
    await 4ms;
    await 4ms;
    await 4ms;
    x = 1;
end;
return x;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
var int x;
par do
    loop do
        await 10ms;
        x = 1;
    end;
with
    loop do
        await (200)us;
        x = 2;
    end;
end;
]],
    ana = {
        isForever = true,
        n_acc = 1,
    },
}

Test { [[
var int x;
par do
    loop do
        x = await 10ms;
    end;
with
    loop do
        x = await 200ms;
    end;
end;
]],
    ana = {
        isForever = true,
        n_acc = 1,
    },
}

Test { [[
event int a;
var int x;
par/or do
    par/and do
        await 10ms;
        x = 4;
    with
        emit a;
    end;
    var int v = x;
with
    await a;
    await 10ms;
    x = 5;
end;
return x;
]],
    ana = {
        n_acc = 3,
    },
    --run = { ['~>15ms']=5, ['~>25ms']=5 }
}

-- EX.02: trig e await depois de loop
Test { [[
input int A;
event int a;
loop do
    par/and do
        await A;
        emit a=1;
    with
        await a;
    end;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
event void a;
par/or do
    emit a;
with
    await a;
end
return 0;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 1,
    },
    run = 0,
}

Test { [[
input void A;
event void a;
var int ret = 0;
par/or do
    await A;
    emit a;
with
    await a;
    ret = 1;
end
ret = ret + 1;
return ret;
]],
    ana = {
        --n_unreachs = 1,
    },
    run = { ['~>A']=2 },
}

Test { [[
event void a;
loop do
    par/and do
        emit a;
    with
        await a;
    end
end
]],
    todo = 'TIGHT',
    ana = {
        loop = true,
    },
}

Test { [[
event int a;
par do
    loop do
        par/or do
            emit a=1;
        with
            await a;
        end;
    end;
with
    await a;
    emit a=a;
end;
]],
    ana = {
        n_acc = 2,
        isForever = true,
    },
    loop = 'ERR : line 3 : tight loop',
}

Test { [[
input int A;
event int a, d, e, i, j;
par/and do
    await A;
    emit a=1;
with
    d = await a;
    emit i=5;
with
    e = await a;
    emit j=6;
end;
return d + e;
]],
    --trig_wo = 2,
    run = {
        ['0~>A'] = 2,
    }
}

Test { [[
event int a;
par do
    emit a=1;
with
    return a;
end;
]],
    ana = {
        --nd_esc = 1,
        --nd_flw = 1,
        --n_unreachs = 1,
        --trig_wo = 1,
        n_acc = 1,
    },
}

Test { [[
event int a;
var int v;
loop do
    par do
        v = a;
    with
        await a;
    end;
end;
]],
    ana = {
        isForever = true,
        n_unreachs = 1,
        n_reachs = 1,
    },
}
Test { [[
input int A;
event int b;
var int a,v;
par do
    loop do
        v = a;
        await b;
    end;
with
    await A;
    emit b=1;
end;
]],
    ana = {
        isForever = true,
    },
}
Test { [[
input int A,B;
event int a;
par do
    par do
        await A;
        emit a=1;
    with
        await a;
        await a;
    end;
with
    var int v = await B;
    return v;
end;
]],
    ana = {
        --n_unreachs = 1,
        n_reachs = 1,
    },
    run = {
        ['0~>A ; 10~>B'] = 10,
    }
}

Test { [[
input void START;
event int a;
var int b;
par/or do
    b = await a;
with
    await START;
    emit a=3;
end;
return a+b;
]],
    ana = {
        --n_unreachs = 1,
        --trig_wo = 1,
    },
    run = 6,
}

Test { [[
event int a;
var int b;
par/or do
    b = await a;
with
    emit a=3;
with
    a = b;
end;
return 0;
]],
    ana = {
        --nd_esc = 1,
        --n_unreachs = 2,
        n_acc = 2,
        --trig_wo = 1,
    },
}

Test { [[
input void START;
event int b;
var int i;
par/or do
    await START;
    emit b=1;
    i = 2;
with
    await b;
    i = 1;
end;
return i;
]],
    ana = {
        --nd_esc = 1,
        n_unreachs = 0,
    },
    run = 1,
}
Test { [[
input void START;
event int b,c;
par/or do
    await START;
    emit b=1;
    await c;
with
    await b;
    emit c=5;
end;
return c;
]],
    ana = {
        --nd_esc = 1,
        n_unreachs = 0,
        --trig_wo = 1,
    },
    run = 5,
}
Test { [[
input int A;
var int ret;
loop do
    tmp int v = await A;
    if v == 5 then
        ret = 10;
        break;
    else
    end;
end;
return ret;
]],
    run = {
        ['1~>A ; 2~>A ; 3~>A ; 4~>A ; 5~>A'] = 10,
        ['5~>A'] = 10,
    }
}
Test { [[
input int B;
var int a = 0;
loop do
    tmp int b = await B;
    a = a + b;
    if a == 5 then
        return 10;
    end;
end;
return 0;   // TODO
]],
    ana = {
        n_unreachs = 1,
    },
    run = {
        ['1~>B ; 4~>B'] = 10,
        ['3~>B ; 2~>B'] = 10,
    }
}

Test { [[
input int A,B;
var int ret = loop do
        await A;
        par/or do
            await A;
        with
            var int v = await B;
            return v;
        end;
    end;
return ret;
]],
    run = {
        ['1~>A ; 5~>B'] = 5,
        ['1~>A ; 1~>A ; 3~>B ; 1~>A ; 5~>B'] = 5,
    }
}

Test { [[
input int A;
event int a;
loop do
    var int v = await A;
    if v==2 then
        return a;
    end;
    emit a=v;
end;
]],
    ana = {
        --trig_wo = 1,
    },
    run = {
        ['0~>A ; 0~>A ; 3~>A ; 2~>A'] = 3,
    }
}

Test { [[
input int A;
event int a;
loop do
    tmp int v = await A;
    if v==2 then
        return a;
    else
        if v==4 then
            break;
        end;
    end;
    emit a=v;
end;
return a-1;
]],
    --trig_wo = 1,
    run = {
        ['0~>A ; 0~>A ; 3~>A ; 2~>A'] = 3,
        ['0~>A ; 0~>A ; 3~>A ; 4~>A'] = 2,
    }
}

Test { [[
input int A,B;
var int a = 0;
par do
    await B;
    return a;
with
    loop do
        await A;
        a = a+1;
        await A;
        a = a+1;
    end;
end;
]],
    run = {
        ['0~>A ; 0~>A ; 0~>B'] = 2,
    }
}


Test { [[
input int A,B;
loop do
    par/or do
        await A;
        break;
    with
        await B;
    end;
end;
return 1;
]],
    run = {
        ['2~>A ; 4~>A'] = 1,
        ['0~>B ; 0~>B ; 2~>A ; 0~>B'] = 1,
    }
}

    -- UNREACH

Test { [[
input int A,B;
var int ret;
par/or do
    par/or do await A; with await B; end;
    par/or do await A; with await B; end;
    par/or do ret=await A; with ret=await B; end;
with
    await B;
    await B;
    await B;
    await B;
end;
return ret;
]],
    ana = {
        --n_unreachs = 1,
    },
    run = {
        ['0~>A ; 0~>A ; 10~>A'] = 10,
        ['0~>B ; 0~>A ; 11~>B'] = 11,
        ['0~>B ; 0~>B ; 12~>B'] = 12,
    }
}

Test { [[
input int A,B;
var int v;
par/or do
    v = await A;
with
    await B;
    v = await A;
end;
return v;
]],
    ana = {
        n_acc = 1,     -- should be 0
    },
    run = {
        ['10~>A'] = 10,
        ['0~>B ; 10~>A'] = 10,
    }
}

Test { [[
input int A,B,Z;
var int ret;
par/or do
    par/or do
        ret = await A;
    with
        ret = await B;
    end;
with
    await Z;
    ret = await A;
end;
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['0~>Z ; 10~>B'] = 10,
        ['0~>Z ; 10~>A'] = 10,
        ['0~>Z ; 1~>Z ; 5~>A'] = 5,
    }
}

Test { [[
input int A,B,Z;
var int v;
par/or do
    par/and do
        v = await A;
    with
        await B;
    end;
with
    await Z;
    v = await A;
end;
return v;
]],
    ana = {
        n_acc = 1,
    },
    run = {
        ['0~>Z ; 10~>A'] = 10,
        ['0~>A ; 1~>Z ; 5~>A ; 1~>B'] = 5,
    }
}

Test { [[
input int A,B,Z;
var int v;
par/or do
    par/and do
        await A;
        await B;
        v = await A;
    with
        await Z;
        await B;
        await Z;
    end;
with
    await A;
    await Z;
    await B;
    await B;
    v = await Z;
end;
return v;
]],
    run = {
        ['0~>A ; 1~>Z ; 5~>B ; 1~>B ; 9~>Z'] = 9,
        ['0~>A ; 1~>Z ; 1~>B ; 5~>A ; 9~>Z'] = 5,
    }
}

Test { [[
input int A,B,Z;
var int v;
par/or do
    par/and do
        await A;
        await B;
        v = await A;
    with
        await Z;
        await B;
        v = await Z;
    end;
with
    await A;
    await Z;
    await B;
    await A;
    await Z;
    await B;
end;
return v;
]],
    ana = {
        --n_unreachs = 1,
    },
    run = {
        ['0~>A ; 1~>Z ; 5~>B ; 1~>A ; 1~>Z ; 9~>B'] = 1,
    },
}

Test { [[
input int A,B;
var int v;
par/or do
    if 1 then
        v = await A;
    else
        v = await B;
    end;
with
    await A;
    v = 1;
with
    await B;
    v = 2;
end;
return v;
]],
    ana = {
        n_acc = 2,
    },
    run = {
        ['1~>A'] = 1,
        ['1~>B'] = 2,
    },
}
Test { [[
input int A,B;
var int v;
par/or do
    if 1 then
        v = await A;
    else
        v = await B;
    end;
with
    await A;
    v = await B;
with
    await B;
    v = await A;
end;
return v;
]],
    ana = {
        n_acc = 2,
    },
    run = {
        ['0~>B ; 10~>A'] = 10,
        ['0~>B ; 9~>A'] = 9,
    },
}
Test { [[
input int A,B,Z;
var int v;
par/or do
    await A;
    await B;
    v = await Z;
with
    await B;
    await A;
    v = await Z;
end;
return v;
]],
    ana = {
        n_acc = 1,
    },
}
Test { [[
input int A,B,Z;
var int v;
par/or do
    if 1 then
        v = await A;
    else
        v = await B;
    end;
with
    await A;
    await B;
    v = await Z;
with
    await B;
    await A;
    v = await Z;
end;
return v;
]],
    ana = {
        --n_unreachs = 2,
        n_acc = 1,
    },
    run = {
        ['0~>B ; 10~>A'] = 10,
    },
}
Test { [[
input int A,B;
par do
    loop do
        await A;
        var int v = await B;
        return v;
    end;
with
    var int v = await A;
    return v;
end;
]],
    ana = {
        n_unreachs = 1,
        --nd_flw = 1,
    },
    run = {
        ['0~>B ; 10~>A'] = 10,
    },
}
Test { [[
input int A,B;
var int v;
loop do
    par/or do
        await A;
    with
        v = await B;
        break;
    end;
end;
return v;
]],
    run = {
        ['0~>A ; 0~>A ; 10~>B'] = 10,
    },
}
Test { [[
input int A,B,Z;
var int a;
par do
    loop do
        if a then
            a = await A;
            break;
        else
            await B;
        end;
    end;
    return a;
with
    await B;
    a = await Z;
    return a;
end;
]],
    run = {
        ['0~>B ; 10~>Z'] = 10,
    },
}

Test { [[
input int A,B;
if 11 then
    var int v = await A;
    return v;
else
    var int v = await B;
    return v;
end;
]],
--(11?~A:~B)]],
    run = {
        ['10~>A ; 10~>B'] = 10,
        ['0~>B ; 9~>A'] = 9,
    },
}
Test { [[
input int A,B;
loop do
    await A;
end;
if 1 then       // TODO: unreach
    await A;
else
    await B;
end;
return 1;
]],
    ana = {
        isForever = true,
        n_unreachs = 1,
    },
}
Test { [[
par/or do
with
end
return 1;
]],
    run = 1,
}
Test { [[
input int A;
par do
with
    loop do
        await A;
    end;
end;
]],
--1and(~A)*]],
    ana = {
        isForever = true
    },
}
Test { [[
input int A,B;
par do
    loop do
        await A;
    end;
with
    loop do
        await B;
    end;
end;
]],
--(~A)* and (~B)*]],
    ana = {
        isForever = true,
    },
}
Test { [[
input int A,B,Z;
var int v;
loop do
    v = await A;
    if v then
        v = await B;
        break;
    else
        await Z;
    end
end
return v;
]],
--(((~A)?~B^:~Z))*]],
    run = {
        ['1~>A ; 10~>B'] = 10,
        ['0~>A ; 0~>Z ; 1~>A ; 9~>B'] = 9,
    },
}

Test { [[
input int A,B,Z,D,E,F,G,H,I,J,K,L;
var int v;
par/or do
    await A;
with
    await B;
end;
await Z;
await D;
await E;
await F;
tmp int g = await G;
if g then
    await H;
else
    await I;
end;
await J;
loop do
    par/or do
        await K;
    with
        v = await L;
        break;
    end;
end;
return v;
]],
    run = {
        ['0~>A ; 0~>Z ; 0~>D ; 0~>E ; 0~>F ; 0~>G ; 0~>I ; 0~>J ; 0~>K ; 10~>L'] = 10,
        ['0~>B ; 0~>Z ; 0~>D ; 0~>E ; 0~>F ; 1~>G ; 0~>H ; 0~>J ; 0~>K ; 11~>L'] = 11,
    },
}

-- NONDET

Test { [[
var int a;
par do
    a = 1;
    return 1;
with
    return a;
end;
]],
    ana = {
        --nd_flw = 2,
    n_acc = 2,
    },
}
Test { [[
input int B;
var int a;
par do
    await B;
    a = 1;
    return 1;
with
    await B;
    return a;
end;
]],
    ana = {
        n_acc = 2,
    --nd_flw = 2,
    },
}
Test { [[
input int B,Z;
event int a;
par do
    await B;
    a = 1;
    return 1;
with
    par/or do
        await a;
    with
        await B;
    with
        await Z;
    end;
    return a;
end;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 2,
        --nd_flw = 2,
    },
}
Test { [[
input int Z;
event int a;
par do
    emit a=1;
    return 10;
with
    par/or do
        await a;
    with
    with
        await Z;
    end;
    return a;
end;
]],
    ana = {
        n_acc = 3,
        --nd_flw = 1,
        --nd_esc = 2,
        --n_unreachs = 2,    -- +1 C n_unreachs
    },
    --run = 1,
    run = 10,
    --todo = 'nd kill',
}
Test { [[
input void START;
event int a;
par do
    await START;
    emit a=1;
with
    await a;
    return a;
end;
]],
    ana = {
        --n_unreachs = 1,
        --nd_esc = 1,
    },
    run = 1,
}
Test { [[
input int B,Z;
event int a;
par/or do
    await B;
    emit a=5;
with
    await a;
    a = a + 1;
end;
return a;
]],
    ana = {
        --n_unreachs = 1,
        --nd_esc = 1,
    },
    run = {
        ['1~>B'] = 6,
    },
}
Test { [[
input int B,Z;
event int a;
par/or do
    await B;
    emit a=5;
with
    par/and do
        await a;
    with
        await a;
    end
    a = a + 1;
end;
return a;
]],
    ana = {
        --n_unreachs = 1,
        --nd_esc = 1,
    },
    run = {
        ['1~>B'] = 6,
    },
}
Test { [[
input int B;
event int a;
par/or do
    await B;
    emit a=5;
with
    par/and do
        await B;
    with
        await a;
    end
    a = a + 1;
end;
return a;
]],
    ana = {
        n_acc = 2,
        --n_unreachs = 1,
        --nd_esc = 1,
    },
    run = {
        --['1~>B'] = 6,
        ['1~>B'] = 5,
    },
    --todo = 'nd kill',
}
Test { [[
input int B,Z;
event int a=0;
par/or do
    await B;
    emit a=5;
with
    par/and do
        await a;
    with
        await B;
    with
        await Z;
    end;
    a = a + 1;
end;
return a;
]],
    ana = {
        n_acc = 2,
        --nd_esc = 1,
    },
    run = {
        --['1~>B'] = 5,
        --['2~>Z; 1~>B'] = 6,
        ['1~>B'] = 5,
        ['2~>Z; 1~>B'] = 5,
    },
}
Test { [[
event int a;
par do
    emit a=1;
    return a;
with
    par/and do
        await a;
    with
    end;
    return a;
end;
]],
    ana = {
        n_acc = 1,
        --nd_esc = 1,
        --n_unreachs = 1,
    },
    run = 1,
}
Test { [[
input int Z;
event int a;
par do
    emit a=1;
    return a;
with
    par/and do
        await a;
    with
    with
        await Z;
    end;
    return a;
end
]],
    ana = {
        n_acc = 1,
        --nd_esc = 1,
        --nd_flw = 1,
    },
    run = 1,
}
Test { [[
input int B,Z;
event int a;
par do
    await B;
    a = 1;
    return a;
with
    par do
        await a;
    with
        await B;
    with
        await Z;
    end;
end;
]],
    ana = {
        --n_unreachs = 1,
        --nd_flw = 1,
        n_reachs = 1,
    },
    run = {
        ['1~>B'] = 1,
    },
}
Test { [[
input int B,Z;
event int a;
par do
    await B;
    a = 1;
    return a;
with
    par/and do
        await a;
    with
        await B;
    with
        await Z;
    end;
    return a;
end;
]],
    ana = {
        --dfa = 'unreachable statement',
        --nd_flw = 1,
        --n_unreachs = 2,
        n_acc = 2,
    },
    run = {
        ['1~>B'] = 1,
    },
}
Test { [[
input int A;
loop do
    par/or do
        break;
    with
        par/or do
        with
        end;
        await A;
        // unreachable
    end;
    // unreachable
end;
return 1;
]],
    ana = {
        --dfa = 'unreachable statement',
        --nd_flw = 1,
        --n_unreachs = 3,
    },
    run = 1,
}

Test { [[
input int A;
loop do
    par/or do
        break;
    with
        break;
    end
end
return 1;
]],
    ana = {
        --nd_flw = 2,
    n_unreachs = 2,
    },
    run = 1,
}

Test { [[
input int A;
par/or do
    return 1;
with
    await A;
end;
]],
    ana = {
        --n_unreachs = 2,
        --nd_flw = 1,
        n_reachs = 1,
    },
    run = 1,
}
Test { [[
input int A;
loop do
    par/or do
        break;
    with
        par/or do
            return 1;
        with
            await A;
            // unreachable
        end;
        // unreachable
        await A;
        // unreachable
    end;
    // unreachable
end;
return 2;       // executes last
]],
    ana = {
        --dfa = 'unreachable statement',
        --n_unreachs = 5,
        --nd_flw = 3,
    },
    run = 2,
}

Test { [[
input int A;
loop do
    par do
        break;
    with
        par do
            return 1;
        with
            await A;
            // unreachable
        end;
    end;
end;
return 2;   // executes last
]],
    ana = {
        n_unreachs = 1,
        --nd_flw = 3,
    },
    run = 2,
}

Test { [[
input int A;
loop do
    await A;
    par/or do
        break;          // prio1
    with
        par/or do
        with
        end;
                        // prio2
    end;
end;
return 1;
]],
    --nd_flw = 1,
    run = { ['~>A'] = 1, },
}
Test { [[
par/or do
with
    par/or do
    with
    end;
end;
return 1;
]],
    run = 1,
}
Test { [[
event int a;
par/or do
    a = 1;
with
    par/or do
        await a;
    with
    end;
    return a;
end;
return a;
]],
    ana = {
        --n_unreachs = 1,
        --nd_flw = 1,
        n_acc  = 1,
    },
}
Test { [[
input int B;
event int a;
par do
    await B;
    a = 1;
    return a;
with
    await B;
    par/or do
        await a;
    with
    end;
    return a;
end;
]],
    ana = {
        --n_unreachs = 1,
        --nd_flw = 2,
        n_acc = 2,
    },
}
Test { [[
var int a = 0;
par do
    return a;
with
    return a;
end;
]],
    ana = {
        n_acc = 1,
    --nd_flw = 2,
    },
}
Test { [[
var int a;
par do
    return a;
with
    a = 1;
    return a;
end;
]],
    ana = {
        n_acc = 2,
    --nd_flw = 2,
    },
}
Test { [[
var int a;
par do
    a = 1;
    return a;
with
    return a;
end;
]],
    ana = {
        --nd_flw = 2,
    n_acc = 2,
    },
}
Test { [[
var int a;
par/or do
    a = 1;
with
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}
Test { [[
var int a;
par/or do
    a = 1;
with
    a = 1;
with
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 3,
    },
}
Test { [[
input int A;
par do
    var int v = await A;
    return v;
with
    var int v = await A;
    return v;
end;
]],
    ana = {
        n_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
event int a;
par/or do
    await a;
with
    emit a=1;
end;
return a;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 1,
        --trig_wo = 1,
    },
    run = 1,
}
Test { [[
event int a;
par/or do
    emit a=1;
with
    emit a=1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = 1,
}
Test { [[
event int a=2,b=2;
par/or do
    emit a=1;
    a = 2;
with
    emit b=1;
    b = 5;
end;
return a+b;
]],
    --run = 7,
    run = 4,
}
Test { [[
event int a=0, b=0;
par/or do
    emit a=2;
with
    emit b=3;
end;
return a+b;
]],
    --trig_wo = 2,
    --run = 5,
    run = 2,
}
Test { [[
event int a;
var int v = par do
    emit a=1;
    return a;
with
    emit a=1;
    return a;
with
    emit a=1;
    return a;
end;
return v;
]],
    ana = {
        n_acc = 12, -- TODO: not checked
        --nd_flw = 6,
        --trig_wo = 3,
    },
}
Test { [[
var int a,v;
v = par do
    return 1;
with
    return 1;
with
    return 1;
end;
return v;
]],
    ana = {
        n_acc = 3,
    --nd_flw = 6,
    --trig_wo = 1,
    },
}
Test { [[
input int A;
var int a = 0;
par do
    await A;
    return a;
with
    await A;
    return a;
end;
]],
    ana = {
        --nd_flw = 2,
    n_acc = 1,
    },
}
Test { [[
input int A;
var int a;
par do
    await A;
    return a;
with
    await A;
    a = 1;
    return a;
end;
]],
    ana = {
        --nd_flw = 2,
    n_acc = 2,
    },
}
Test { [[
input int A;
event int a;
await A;
emit a=1;
await A;
emit a=1;
return a;
]],
--~A;1~>a;~A;1~>a]],
    --trig_wo = 2,
    run = {
        ['0~>A ; 10~>A'] = 1,
    },
}
Test { [[
input void START;
input int A;
event int a;
par/or do
    loop do
        tmp int v = await A;
        emit a=v;
    end;
with
    await A;
    await A;
    await a;
end;
return a;
]],
    ana = {
        n_acc = 1,
        --nd_esc = 1,
    },
    run = { ['1~>A;2~>A;3~>A']=3 },
}
Test { [[
input void START;
event int a;
par do
    await START;
    emit a=1;
    return a;
with
    await a;
    a = a + 1;
    return a;
with
    await a;
    await FOREVER;
end;
]],
    ana = {
        --nd_esc = 1,
        --n_unreachs = 1,
        --nd_flw = 1,
    },
    run = 2,
}
Test { [[
event int a;
par/or do
    emit a=1;
with
    await a;
    a = a + 1;
with
    await a;
    var int v = a;
end;
return a;
]],
    ana = {
        --nd_esc = 1,
        --n_unreachs = 1,
        n_acc = 2,
    },
}
Test { [[
input int A;
var int v;
par do
    await A;
    loop do
        await A;
        var int a = v;
    end;
with
    loop do
        await A;
        await A;
        v = 2;
    end;
end;
]],
--(~A; (~A;v)*) and (~A;~A;2=>v)*]],
    ana = {
        isForever = true,
        n_acc = 1,
    },
}
Test { [[
input int A;
var int v;
par do
    loop do
        await A;
        await A;
        v = 1;
    end;
with
    loop do
        await A;
        await A;
        await A;
        v = 2;
    end;
end;
]],
--(~A;~A;1=>v)* and (~A;~A;~A;v)*]],
    ana = {
        isForever = true,
        n_acc = 1,
    },
}
Test { [[
input int A, B;
var int a;
par/or do
    var int v = await A;
    a = v;
with
    var int v = await B;
    a = v;
with
    await A;
    await B;
    var int v = a;
end;
return a;
]],
    ana = {
        --n_unreachs = 1,
        n_acc = 1,
    },
    run = {
        ['3~>A'] = 3,
        ['1~>B'] = 1,
    },
}
Test { [[
input int A, B;
var int a;
par/or do
    await A;
    await B;
    a = 1;
with
    await A;
    var int v = await B;
    a = v;
end;
return a;
]],
    ana = {
        n_acc = 1,
    n_acc = 1,
    },
}
Test { [[
input int A, B;
var int a;
par/or do
    await A;
    a = 3;
with
    await B;
    a = 1;
end;
await B;
return a;
]],
    run = {
        ['3~>A ; 5~>B'] = 3,
        ['3~>A ; 5~>B ; 5~>B'] = 3,
        ['3~>B ; 5~>B'] = 1,
        ['3~>B ; 5~>A ; 5~>B'] = 1,
    },
}

Test { [[
input int A, B, Z;
var int v;
par/or do
    v = await A;
with
    par/or do
        v = await B;
    with
        v = await Z;
    end;
end;
return v;
]],
    run = {
        ['10~>A ; 1~>A'] = 10,
        ['9~>B'] = 9,
        ['8~>Z'] = 8,
    }
}
Test { [[
input int A;
par/or do
with
end;
var int v = await A;
return v;
]],
    run = {
        ['10~>A ; 1~>A'] = 10,
        ['9~>A'] = 9,
        ['8~>A'] = 8,
    }
}
Test { [[
event int a=0, b=0, c=0, d=0;
par/or do
    par/and do
        await a;
    with
        await b;
    with
        await c;
    end;
    await d;
with
    par/or do
        emit b=1;
    with
        emit a=2;
    with
        emit c=3;
    end;
    emit d=4;
end;
return a+b+c+d;
]],
    ana = {
        n_acc = 3,
        --n_unreachs = 1,
    },
    --run = 10,
    run = 5,
}
Test { [[
event int a=0, b=0, c=0;
par/or do
    par/or do
        await a;
    with
        await b;
    with
        await c;
    end;
with
    par/or do
        emit a=10;
    with
        emit b=20;
    with
        emit c=30;
    end;
end;
return a+b+c;
]],
    ana = {
        n_acc = 3,
        --n_unreachs = 4,
    },
    --run = 60,
    run = 10,
}
Test { [[
event int a=0, b=0, c=0;
par/or do
    par do
        await a;
    with
        await b;
    with
        await c;
    end;
with
    par/or do
        emit a=10;
    with
        emit b=20;
    with
        emit c=30;
    end;
end;
return a+b+c;
]],
    ana = {
        n_acc = 3,
        n_reachs = 1,
        --trig_wo = 3,
    },
    --run = 60,
    run = 10,
}
Test { [[
event int a;
par/or do
    emit a=1;
with
    emit a=1;
    await a;
end;
return 0;
]],
    ana = {
        n_acc = 2,
        --n_unreachs = 1,
        --trig_wo = 2,
    },
}
Test { [[
event int a;
par/or do
    emit a=1;
    await a;
with
    emit a=1;
end;
return 0;
]],
    ana = {
        n_acc = 2,
        --n_unreachs = 1,
        --trig_wo = 2,
    },
}
Test { [[
event int a;
par do
    emit a=1;
with
    emit a=1;
    await a;
end;
]],
    ana = {
        isForever = true,
        n_acc = 2,
        --n_unreachs = 1,
        n_reachs = 1,
        --trig_wo = 2,
    },
}
Test { [[
input int B;
loop do
    par do
        break;
    with
        await B;
    end;
end;
return 1;
]],
    ana = {
        n_unreachs = 1,
        --nd_flw = 1,
    },
    run = 1,
}
Test { [[
input int A, B;
var int v;
loop do
    par/or do
        v = await A;
        break;
    with
        await B;
    end;
end;
return v;
]],
    run = {
        ['4~>A'] = 4,
        ['1~>B ; 3~>A'] = 3,
    }
}
Test { [[
input int A;
par do
with
    loop do
        await A;
    end;
end;
]],
    ana = {
        isForever = true,
    },
}

Test { [[
var int x;
par/or do
    await 8ms;
    x = 0;
with
    await 4ms;
    await 4ms;
    x = 1;
end;
return x;
]],
    ana = {
        n_acc = 1,
    n_acc = 1,
    },
}

    -- PRIO

-- prios
Test { [[
var int ret = 10;
loop do
    par/or do
    with
        break;
    end
    ret = 5;
    return ret;
end
return ret;
]],
    ana = {
        n_unreachs = 1,
    },
    run = 5,
}

Test { [[
var int ret = 10;
loop do
    par/or do
        return 100;
    with
        break;
    end
    ret = 5;
    await 1s;
end
return ret;
]],
    ana = {
        n_unreachs = 3,
    },
    --run = 10,
    run = 100,
}

Test { [[
var int a = 0;
par/or do
    par/or do
    with
    end;
    a = a + 1;
with
end;
a = a + 1;
return a;
]],
    run = 2,
}

Test { [[
var int b;
par do
    return 3;
with
    b = 1;
    return b+2;
end;
]],
    ana = {
        --nd_flw = 2,
    n_acc = 1,
    },
}

Test { [[
input int A;
var int v;
loop do
    par do
        v = await A;
        break;
    with
        v = await A;
        break;
    end;
end;
return v;
]],
    ana = {
        n_unreachs = 1,
    --nd_flw = 2,
    n_acc = 1,     -- should be 0
    },
    run = {
        ['5~>A'] = 5,
    }
}
Test { [[
var int v1=0, v2=0;
loop do
    par do
        v1 = 1;
        break;
    with
        par/or do
            v2 = 2;
        with
        end;
        await FOREVER;
    end;
end;
return v1 + v2;
]],
    ana = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    --run = 3,
    run = 1,
}
Test { [[
input int A;
var int v;
loop do
    par do
        v = await A;
        break;
    with
    end;
end;
return v;
]],
    ana = {
        n_unreachs = 1,
    },
    run = {
        ['5~>A'] = 5,
    }
}

Test { [[
input int A;
loop do
    await A;
    break;
    await A;
    break;
end;
]],
    --parser = "ERR : line 4 : after `;´ : expected `end´",
    parser = 'ERR : line 4 : before `;´ : expected statement',
}

Test { [[
input int A;
var int v1=0,v2=0;
loop do
    par do
        v1 = await A;
        break;
    with
        v2 = await A;
        break;
    end;
end;
return v1 + v2;
]],
    ana = {
        n_unreachs = 1,
        --nd_flw = 2,
    },
    run = {
        --['5~>A'] = 10,
        ['5~>A'] = 5,
    }
}

Test { [[
input int A;
var int v1=0, v2=0;
loop do
    par/or do
        await A;
    with
        v1 = await A;
        break;
    end;
    v2 = 2;
    break;
end;
return 0;
]],
    ana = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = { ['1~>A']=0 },
}

Test { [[
input int A;
var int v1=0, v2=0, v3=0;
loop do
    par/or do
        v1 = await A;
    with
        v3 = await A;
        break;
    end;
    v2 = 1;
    break;
end;
return v1+v2+v3;
]],
    ana = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = {
        --['2~>A'] = 5,
        ['2~>A'] = 3,
    }
}

Test { [[
var int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
loop do
    par/or do
        v1 = 1;
        break;
    with
        loop do
            par/or do
                v2 = 2;
            with
                v3 = 3;
                break;
            end;
            v4 = 4;
            break;
        end;
        v5 = 5;
    end;
    v6 = 6;
    break;
end;
return v1+v2+v3+v4+v5+v6;
]],
    ana = {
        n_unreachs = 2,
    --nd_flw = 2,
    },
    --run = 21,
    run = 1,
}

Test { [[
var int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
loop do
    par/or do
        v1 = 1;
    with
        loop do
            par/or do
                v2 = 2;
            with
                v3 = 3;
            end;
            v4 = 4;
            break;
        end;
        v5 = 5;
    end;
    v6 = 6;
    break;
end;
return v1+v2+v3+v4+v5+v6;
]],
    ana = {
        n_unreachs = 2,
    },
    --run = 21,
    run = 7,
}

Test { [[
input int A;
var int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
loop do
    par/or do
        await A;
        v1 = 1;
        break;
    with
        loop do
            par/or do
                await A;
                v2 = 2;
            with
                await A;
                v3 = 3;
                break;
            end;
            v4 = 4;
            break;
        end;
        v5 = 5;
    end;
    v6 = 6;
    break;
end;
return v1+v2+v3+v4+v5+v6;
]],
    ana = {
        n_unreachs = 2,
    --nd_flw = 3,
    },
    --run = { ['~>A'] = 21 },
    run = { ['~>A'] = 1 },
}

Test { [[
input int A;
var int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
loop do
    par/or do
        await A;
        v1 = 1;
    with
        loop do
            par/or do
                await A;
                v2 = 2;
            with
                await A;
                v3 = 3;
            end;
            v4 = 4;
            break;
        end;
        v5 = 5;
    end;
    v6 = 6;
    break;
end;
return v1+v2+v3+v4+v5+v6;
]],
    ana = {
        n_unreachs = 2,
    },
    --run = { ['1~>A']=21 },
    run = { ['1~>A']=7 },
}

Test { [[
var int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
loop do
    par do
        return 1;           // acc 1
    with
        loop do
            par/or do
                v2 = 2;
                            // prio 1
            with
                v3 = 3;
                break;      // prio 1
            end;
            v4 = 4;
            break;
        end;
        return 1;           // acc 1
    end;
end;
// unreachable
return v1+v2+v3+v4+v5+v6;   // TODO: unreach
]],
    ana = {
        n_unreachs = 3,
        n_acc = 1,
    },
    --nd_flw = 3,
}

Test { [[
input int A,B;
var int v;
loop do
    await A;
    par/or do
        await A;
    with
        v = await B;
        break;
    end;
end;
return v;
]],
    run = {
        ['1~>A ; 5~>B'] = 5,
        ['1~>A ; 1~>A ; 3~>B ; 1~>A ; 5~>B'] = 5,
    }
}

Test { [[
input int A,B,Z,D;
var int a = 0;
a = par do
    par/and do
        await A;
    with
        await B;
    end;
    return a+1;
with
    await Z;
    return a;
end;
a = a + 1;
await D;
return a;
]],
    run = { ['0~>A;0~>B;0~>Z;0~>D'] = 2 }
}

Test { [[
input int A,B,Z,D;
var int a = 0;
a = par do
    par do
        await A;
        return a;
    with
        await B;
        return a;
    end;
with
    await Z;
    return a;
end;
a = a + 1;
await D;
return a;
]],
    run = { ['0~>A;0~>B;0~>Z;0~>D'] = 1 }
}

Test { [[
input int A,B,Z,D;
var int a = 0;
a = par do
    par do
        await A;
        return a;
    with
        await B;
        return a;
    end;
    // unreachable
with
    await Z;
    return a;
end;
a = a + 1;
await D;
return a;
]],
    run = { ['0~>A;0~>B;0~>Z;0~>D'] = 1 }
}

Test { [[
input int B;
var int a = 0;
par/or do
    par/or do
        await B;
    with
        await B;
    end;
with
    await B;
end;
a = a + 1;
return a;
]],
    run = { ['0~>B'] = 1 }
}

Test { [[
input int B;
var int a = 0;
par/or do
    par/or do
        await B;
    with
        await B;
    end;
with
    await B;
end;
a = a + 1;
return a;
]],
    run = { ['0~>B'] = 1 }
}

Test { [[
input int B;
var int a = 1;
var int b;
loop do
    par/or do
        await B;
    with
        tmp int v = await B;
        b = v;
        break;
    end;
    b = a;
    break;
end;
a = a + 1;
return a;
]],
    ana = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = { ['2~>B'] = 2 }
}

Test { [[
input int B;
var int a = 0;
loop do
    par/or do
        await B;
    with
        await B;
        a = a + 1;
        break;
    end;
    a = a + 1;
    break;
end;
a = a + 1;
return a;
]],
    ana = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    --run = { ['2~>B'] = 3 }
    run = { ['2~>B'] = 2 }
}

Test { [[
input int B;
var int b = 0;
loop do
    par/and do
        await B;
        break;
    with
        await B;
        break;
    end;
    b = b + 1;
end;
return b;
]],
    ana = {
        --dfa = 'unreachable statement',
        n_unreachs = 3,
        --nd_flw = 2,
    },
    run = { ['0~>B'] = 0 }
}

Test { [[
input int B;
var int b = 0;
loop do
    par do
        await B;
        break;
    with
        await B;
        break;
    end;
end;
return b;
]],
    ana = {
        n_unreachs = 1,
        --nd_flw = 2,
    },
    run = { ['0~>B'] = 0 }
}

Test { [[
input int B;
var int a = 1;
par/or do
    await B;
with
    var int b = loop do
            par/or do
                await B;
                            // prio 1
            with
                var int v = await B;
                return v;   // prio 1
            end;
            a = a + 1;
            return a;
        end;
    a = a + 2 + b;
end;
return a;
]],
    ana = {
        --nd_flw = 1,
        n_unreachs = 1,
    },
    --run = { ['10~>B'] = 6 },
    run = { ['10~>B'] = 1 },
}

Test { [[
input int B;
var int a = 1;
par/or do
    await B;
with
    var int b = loop do
            par/or do
                await B;
            with
                var int v = await B;
                return v;
            end;
            a = a + 1;
        end;
    a = a + 2 + b;
end;
return a;
]],
    ana = {
    --nd_flw = 1,
    },
    --run = { ['10~>B'] = 14 },
    run = { ['10~>B'] = 1 },
}

Test { [[
input int B;
var int a = 1;
loop do
    par/or do
        await B;
    with
        await B;
        break;
    end;
    a = a + 1;
    break;
end;
return a;
]],
    ana = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = { ['10~>B'] = 2 },
}

Test { [[
input int B;
var int a = 1;
loop do
    par do
        await B;
        break;
    with
        await B;
        break;
    end;
end;
return a;
]],
    ana = {
        n_unreachs = 1,
    --nd_flw = 2,
    },
    run = { ['0~>B'] = 1 }
}

Test { [[
input int B;
var int a = 1;
loop do
    par/or do
        await B;
        break;
    with
        await B;
        break;
    end;
    // unreachable
    a = a + 1;
    break;
end;
return a;
]],
    ana = {
        --nd_flw = 2,
        n_unreachs = 3,
    },
    run = { ['0~>B'] = 1 }
}

Test { [[
input int B;
var int a = 1;
loop do
    par/and do
        await B;
        break;
    with
        await B;
        break;
    end;
    // unreachable
    a = a + 1;
    break;
end;
return a;
]],
    ana = {
        --nd_flw = 2,
        n_unreachs = 3,
    },
    run = { ['0~>B'] = 1 }
}

-- pode inserir 2x na fila
Test { [[
input int B;
var int b;
var int a = 2;
par/or do
with
    a = a + 1;
end;
b = a;
a = a*2;
await B;
return a;
]],
    run = {
        --['0~>B'] = 6,
        ['0~>B'] = 4,
    }
}
Test { [[
input int B;
var int a = 2;
par/and do
with
    par/and do
    with
    end;
    a = a + 1;
end;
a = a * 2;
await B;
return a;
]],
    run = {
        ['0~>B'] = 6,
    }
}
Test { [[
var int a;
a = 2;
par/and do
with
    par/and do
    with
    end;
end;
a = a * 2;
return a;
]],
    run = 4,
}
Test { [[
var int a;
a = 2;
par/or do
with
    par/or do
    with
    end;
end;
a = a * 2;
return a;
]],
    run = 4,
}

Test { [[
var int a, b, c, d, e, f;
par/and do
    a = 1;
with
    par/and do
        par/and do
            b = 1;
        with
            c = 1;
        end;
    with
        par/and do
            d = 1;
        with
            e = 1;
        end;
    end;
with
    f = 1;
end;
return a+b+c+d+e+f;
]],
    run = 6,
}

-- EX.12: gates do AND podem conflitar com ret do loop
Test { [[
input int A;
var int v;
loop do
    par/and do
        v = await A;
        break;
    with
        await A;
    end;
end;
return v;
]],
    ana = {
        --nd_flw = 1,
    n_unreachs = 2,
    },
    run = { ['5~>A'] = 5, }
}

Test { [[
input int A;
var int v;
loop do
    par/or do
        v = await A;
        break;
    with
        await A;
    end;
end;
return v;
]],
    --nd_flw = 1,
    run = { ['5~>A'] = 5, }
}

Test { [[
input int A;
var int v;
par/or do
    loop do
        v = await A;
        break;
    end;
    return v;
with
    var int v = await A;
    return v;
end;
]],
    ana = {
        n_unreachs = 2,
    n_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
input int A,B;
var int v;
par/or do
    loop do
        par/or do
            v = await A;
            break;
        with
            await B;
        end;
    end;
with
    v = await A;
end;
return v;
]],
    ana = {
        n_acc = 1, -- should be 0 (same evt)
    },
    run = {
        ['0~>B ; 5~>A'] = 5,
    }
}

-- Testa prio em DFA.lua
Test { [[
input int A;
var int b,c,d;
par/or do
    par/and do
        loop do
            par/or do
                await A;
            with
                await A;
            end;
            b = 3;
            break;
        end;
    with
        await A;
        c = 3;
    end;
with
    await A;
    d = 3;
end;
return b+c+d;
]],
    ana = {
        n_unreachs = 1,
    },
    --run = { ['0~>A'] = 9, }
    run = { ['0~>A'] = 6, }
}

Test { [[
input int A;
var int b,c,d;
par/or do
    par/and do
        loop do
            par/or do
                await A;
                break;
            with
                await A;
            end;
            b = 3;
        end;
    with
        await A;
        c = 3;
    end;
with
    await A;
    d = 3;
end;
return b+c+d;
]],
    --nd_flw = 1,
    --run = { ['0~>A'] = 9, }
    run = { ['0~>A'] = 3, }
}

Test { [[
input int A,Z,D;
var int b;
par/or do
    b = 0;
    loop do
        var int v;
        par/and do
            await A;
        with
            v = await A;
        end;
        b = 1 + v;
    end;
with
    await Z;
    await D;
    return b;
end;
]],
    ana = {
        n_unreachs = 1,
    },
    run = {
        ['2~>Z ; 1~>A ; 1~>D'] = 2,
    }
}

Test { [[
input int A,Z,D;
var int b;
par/or do
    b = 0;
    loop do
        var int v;
        par/and do
        with
            v = await A;
        end;
        b = 1 + v;
    end;
with
    await Z;
    await D;
    return b;
end;
]],
    ana = {
        n_unreachs = 1,
    },
    run = { ['1~>A;~>Z;2~>A;~>D']=3 },
}

Test { [[
input int A;
var int c = 2;
var int d = par/and do
    with
        return c;
    end;
c = d + 1;
await A;
return c;
]],
    parser = "ERR : line 3 : after `par´ : expected `do´",
}

Test { [[
input int A;
var int c = 2;
var int d = par do
    with
        return c;
    end;
c = d + 1;
await A;
return c;
]],
    --nd_flw = 1,
    run = {
        ['0~>A'] = 3,
    }
}

    -- FRP
Test { [[
event int a=0,b=0;
par/or do
    emit a=2;
with
    emit b=5;
end;
return a + b;
]],
    --run    = 7,
    run    = 2,
    --trig_wo = 2,
}

-- TODO: PAREI DE CONTAR n_unreachs AQUI
Test { [[
input int A;
event int counter = 0;
par/and do
    loop do
        await A;
        counter = counter + 1;
    end;
with
    loop do
        await counter;
        // unreachable
        if counter == 200 then
            counter = 0;
        end;
    end;
end;
// unreachable
]],
    ana = {
        isForever = true,
        n_unreachs = 3,
    },
}

Test { [[
event int a;
emit a=8;
return a;
]],
    run = 8,
    --trig_wo = 1,
}

Test { [[
event int a;
par/and do
    emit a=9;
with
    loop do
        await a;
    end;
end;
]],
    ana = {
        n_acc = 1,
        isForever = true,
        n_unreachs = 1,
        --trig_wo = 1,
    },
}

Test { [[
event int a;
par/and do
    emit a=9;
with
    loop do
        await a;
    end;
end;
]],
    ana = {
        n_acc = 1,
        isForever = true,
        n_unreachs = 1,
    },
}

Test { [[
input int A;
event int a,b;
var int v;
par/or do
    v = await A;
    par/or do
        emit a=1;
    with
        emit b=1;
    end;
    v = await A;
with
    loop do
        par/or do
            await a;
        with
            await b;
        end;
    end;
end;
return v;
]],
    run = {
        ['1~>A ; 1~>A'] = 1,
    }
}

Test { [[
input int D, E;
event int a, b;
var int c;
par/or do
    await D;
    par/or do
        emit a=8;
    with
        emit b=5;
    end;
    var int v = await D;
    return v;
with
    c = 0;
    loop do
        par/or do
            await a;
        with
            await b;
        end;
        c = a + b;
    end;
with
    await E;
    return c;
end;
]],
    ana = {
        n_unreachs = 1,
        n_acc = 0,
        --trig_wo = 1,
    },
    run = {
        ['1~>D ; 1~>E'] = 8,    -- TODO: stack change (8 or 5)
    }
}

Test { [[
input int A,B;
event int a,b;
var int v;
par/or do
    par/and do
        var int v = await A;
        emit a=v;
    with
        await B;
        emit b=1;
    end;
    return v;
with
    v = await a;
    return v;       // 15
with
    await b;
    return b;       // 18
end;
]],
    ana = {
        --nd_esc = 2,
        n_unreachs = 4,
    },
    run = {
        ['10~>A'] = 10,
        ['4~>B'] = 1,
    }
}

Test { [[
input int A, B;
event int a,b;
var int v;
par/or do
    par/and do
        a = await A;
        v = a;
        return v;
    with
        await B;
        emit b=1;
        return v;
    end;
with
    await a;
    return a;
with
    await b;
    return b;
end;
]],
    ana = {
        --nd_esc = 1,
    n_unreachs = 4,
    },
    run = {
        ['10~>A'] = 10,
        ['4~>B'] = 1,
    }
}

-- EX.08: join pode tirar o A da espera
Test { [[
input int A, B;
var int a;
par/and do
    loop do
        par/or do
            await A;
            var int x = a;
        with
            await B;
        end;
    end;
with
    await B;
    a = await A;
end;
]],
    ana = {
        isForever = true,
        n_acc = 1,
        n_unreachs = 1,
    },
}

-- EX.07: o `and` executa 2 vezes
Test { [[
input int D;
event int a;
loop do
    var int v = await D;
    emit a=a+v;
end;
]],
--((a,~D):add~>a)*]],
    ana = {
        isForever = true,
        --trig_wo = 1,
    },
}

Test { [[
input int A, D, E;
event int a, b, c;
par/or do
    a = 0;
    loop do
        var int v = await A;
        emit a=v;
    end;
with
    b = 0;
    loop do
        var int v = await D;
        emit b=v+b;
    end;
with
    c = 0;
    loop do
        par/or do
            await a;
        with
            await b;
        end;
        emit c=a+b;
    end;
with
    await E;
    return c;
end;
]],
    ana = {
        n_unreachs = 1,
    },
    --trig_wo = 1,
    run = {
        ['1~>D ; 1~>D ; 3~>A ; 1~>D ; 8~>A ; 1~>E'] = 11,
    }
}

    -- Exemplo apresentacao RSSF
Test { [[
input int A, Z;
event int b, d, e;
par/and do
    loop do
        await A;
        emit b=0;
        var int v = await Z;
        emit d=v;
    end;
with
    loop do
        await d;
        emit e=d;
    end;
end;
]],
    ana = {
        isForever = true,
        n_unreachs = 1,
        --trig_wo = 2,
    },
}

    -- SLIDESHOW
Test { [[
input int A,Z,D;
var int i;
par/or do
    await A;
    return i;
with
    i = 1;
    loop do
        var int o = par do
                await Z;
                await Z;
                var int c = await Z;
                return c;
            with
                var int d = await D;
                return d;
            end;
        if o == 0 then
            i = i + 1;
        else
            if o == 1 then
                i = i + 1;
            else
                i = i - 1;
            end;
        end;
    end;
end;
]],
    ana = {
        n_unreachs = 1,
    },
    run = {
        [ [[
0~>Z ; 0~>Z ; 0~>Z ;  // 2
0~>Z ; 0~>Z ; 2~>D ;  // 1
0~>Z ; 1~>D ;         // 2
0~>Z ; 0~>Z ; 0~>Z ;  // 3
0~>Z ; 0~>Z ; 0~>Z ;  // 4
0~>Z ; 0~>Z ; 2~>D ;  // 3
1~>D ;                // 4
1~>D ;                // 5
1~>A ;                // 5
]] ] = 5
    }
}

Test { [[
input int A, B, Z, D;
var int v;
par/and do
    par/and do
        v = await A;
    with
        v = await B;
    end;
with
    par/or do
        await Z;
    with
        await D;
    end;
end;
return v;
]],
    run = {
        ['0~>B ; 0~>B ; 1~>A ; 2~>Z'] = 1,
        ['0~>B ; 0~>B ; 1~>D ; 2~>A'] = 2,
    }
}
Test { [[
input int A;
var int a;
par/and do
    a = await A;
with
    par/or do
        await A;
    with
        await A;
    end;
    return a;
end;
]],
    ana = {
        n_unreachs = 1,
    n_acc = 1,
    --nd_flw = 1,
    },
}
Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a=1;
with
    await a;
with
    await a;
end;
return a;
]],
    run = {
        ['0~>A'] = 1,
    }
}

-- EX.01: dois triggers no mesmo ciclo
Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a=1;
with
    await a;
    emit a=a;
end;
return a;
]],
    run = {
        ['0~>A'] = 1,
    }
}
-- EX.03: trig/await + await
Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a=1;
with
    await a;
    await a;
    return 1;
end;
]],
    ana = {
        --isForever = true,
        n_unreachs = 2,
    },
}
-- EX.03: trig/await + await
Test { [[
input int A;
event int a, b;
par/and do
    await A;
    par/or do
        emit a=1;
    with
        emit b=1;
    end;
with
    par/or do
        await a;
    with
        await b;
    end;
    par/or do
        await a;
        // unreachable
    with
        await b;
        // unreachable
    end;
    // unreachable
end;
// unreachable
return 0;
]],
    ana = {
        --isForever = true,
        n_unreachs = 4,
    },
}

-- EX.03: trig/await + await
Test { [[
input int A;
event int a,b;
par/and do
    await A;
    par/or do
        emit a=1;
    with
        emit b=1;
    end;
with
    par/and do
        await a;
    with
        await b;
    end;
    par/or do
        await a;
    // unreachable
    with
        await b;
        // unreachable
    end;
    // unreachable
end;
// unreachable
return 0;
]],
    ana = {
        --isForever = true,
        n_unreachs = 4,
    },
}

Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a=1;
with
    await a;
    await a;
    // unreachable
with
    await A;
    await a;
end;
// unreachable
return 0;
]],
    ana = {
        n_acc = 1,
        --isForever = true,
        n_unreachs = 2,
    },
}

Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a=1;
    emit a=3;
with
    await a;
end;
return a;
]],
    run = { ['1~>A']=3 }
}

Test { [[
input int A;
event int a;
par/or do
    await A;
    emit a=1;
    emit a=3;
with
    await a;
    await a;
    a = a + 1;
end;
return a;
]],
    run = { ['1~>A;1~>A']=3 }
}

Test { [[
input int A, B;
var int v;
par/and do
    par/or do
        v = await A;
    with
        v = await B;
    end;
with
    loop do
        v = await B;
        break;
    end;
end;
return v;
]],
    ana = {
        n_unreachs = 1,
    n_acc = 1,     -- should be 0
    },
    run = {
        ['5~>B ; 4~>B'] = 5,
        --['1~>A ; 0~>A ; 5~>B'] = 5,
    }
}

Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a=8;
with
    await a;
    await a;
    // unreachable
end;
// unreachable
return 0;
]],
    ana = {
        --isForever = true,
        n_unreachs = 2,
    },
}
Test { [[
input void START;
input int A,B;
event int a;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    await B;
    emit a=1;
with
    par/and do
    with
        await B;
    end;
    await a;
end;
return 10;
]],
    ana = {
        n_acc = 1,
        --isForever = true,
        --n_unreachs = 2,
    },
    run = { ['1~>B;~>B']=10 },
}

Test { [[
input int A, B, Z;
event int a;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    await B;
    emit a=10;
with
    par/or do
        await Z;
    with
        await B;
    end;
    await a;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = { ['1~>B;~>B']=10 },
}

Test { [[
input int A;
event int a,b;
par/and do
    await A;
    emit a=1;
    await A;
    emit b=1;
with
    await a;
    await b;
    return 1;
end;
return 0;
]],
    ana = {
        --nd_esc = 1,
        n_unreachs = 2,
        --trig_wo = 1,
    },
    run = { ['1~>A;~>A'] = 1 }
}

Test { [[
input int A, B, Z, D, E;
var int d;
par/or do
    await A;
with
    await B;
end;
await Z;
par/and do
    d = await D;
with
    await E;
end;
return d;
]],
    run = {
        ['1~>A ; 0~>Z ; 9~>D ; 10~>E'] = 9,
        ['0~>B ; 0~>Z ; 9~>E ; 10~>D'] = 10,
    },
}
Test { [[
input void START;
event int a;
par/and do
    await START;
    emit a=1;
with
    par/or do
    with
    end;
    await a;
end;
return a;
]],
    ana = {
        --n_acc = 1,
    },
    run = 1,
}
Test { [[
event int a;
par/and do
    emit a=1;
with
    par/or do
    with
        await a;
    end;
end;
return a;
]],
    ana = {
        n_acc = 1,
        n_unreachs = 1,
    },
    run = 1,
}


--[[
    -- GTES vs QUEUES:
    - Q_TIMERS
    (1) timer A triggers
    (2) timer A is cancelled (par/or), but remains in Q
    (3) timer A is reached again in a loop
    (4) both gates are on now
    (5) PROBLEM! (buffer overflow and execution)
    - Q_ASYNCS: similar to Q_TIMERS
    - Q_INTRA
    (1) event event triggers, await/cont go to Q
    (2) they are cancelled (par/or), both remain in Q
    (3) they cannot be reached in the same _intl_
    (4) so the gates are tested to 0, and halt
    - Q_TRACKS: similar to Q_INTRA
]]

Test { [[
input void START, A;
var int v = 0;
event int a,b;
par/or do
    loop do
        par/or do
            loop do
                await a;
                v = v + 1;
            end;
        with
            await b;
        end;
    end;
with
    await START;
    emit b;
    emit b;
    await A;
    emit a;
    return v;
end;
]],
    ana = {
        n_unreachs = 1,
    },
    run = { ['~>A']=1 },
}

Test { [[
input void START;
var int v = 0;
event int a, b;
par/or do
    loop do
        await a;
        emit b=a;
        v = v + 1;
    end
with
    await START;
    emit a=1;
    return v;
end;
]],
    run = 1,
    ana = {
        n_unreachs = 1,
    },
}

Test { [[
input void START, F;
event int a, b;
par/or do
    loop do
        par/or do
            await a;
            emit b;
        with
            await b;
        end;
    end;
with
    await START;
    emit a;
    await FOREVER;
with
    await F;
end;
return 1;
]],
    run = { ['~>F'] = 1 },
}

Test { [[
input void START,A;
var int v = 0;
var int x = 0;
event int a, b;
par/or do
    loop do
        par/or do
            await a;
            emit b=a;
            v = v + 1;
        with
            loop do
                await b;
                if b then
                    break;
                end;
            end;
        end;
        x = x + 1;
    end;
with
    await START;
    emit a=1;
    await A;
    emit a=1;
    await A;
    emit a=0;
    return v+x;
end;
return 10;
]],
    --nd_esc = 1,
    --run = { ['~>A;~>A'] = 1 },
    run = { ['~>A;~>A'] = 4 },
    ana = {
        n_unreachs = 1,
    },
}

Test { [[
input int A,B,X,F;
var int v1=0,v2=0;
par do
    loop do
        par/or do
            await B;
            async do
                var int v = v1 + 1;
            end;
        with
            await B;
            async do
                var int v = v2 + 1;
            end;
        with
            await A;
        end;
    end;
with
    await F;
    v1 = 1;
    v2 = 1;
    return v1 + v2;
end;
]],
    props = "ERR : line 8 : invalid access from async",
}

Test { [[
var int v=2;
var int ret = async (v) do
        return v + 1;
    end;
return ret + v;
]],
    run = 5,
}

Test { [[
var int a = 0;
async (a) do
    a = 1;
    do
    end
end
return a;
]],
    run = 0,
}

Test { [[
input void F;
var int v=2;
var int ret;
par/or do
    ret = async (v) do        // nd
            return v + 1;
        end;
with
    v = 3;                  // nd
    await F;
end
return ret + v;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
input int A,B,X,F;
var int v1=0,v2=0;
par do
    loop do
        par/or do
            await B;
            async (v1) do
                var int v = v1 + 1;
            end;
        with
            await B;
            async (v2) do
                var int v = v2 + 1;
            end;
        with
            await A;
        end;
    end;
with
    await F;
    v1 = 1;
    v2 = 1;
    return v1 + v2;
end;
]],
    run = { ['1~>F']=2 },
}

Test { [[
input int A,B,X,F;
var int v1=0,v2=0;
par do
    loop do
        par/or do
            await B;
            async do
                var int v = v1 + 1;
            end;
        with
            await B;
            async do
                var int v = v2 + 1;
            end;
        with
            await A;
        end;
    end;
with
    await F;
    v1 = 1;
    v2 = 1;
    return v1 + v2;
end;
]],
    props = "ERR : line 8 : invalid access from async",
}

Test { [[
input int A,F;
var int v;
par do
    loop do
        par/or do
            await 10ms;
            v = v + 1;
        with
            await A;
        end;
    end;
with
    await F;
    return v;
end;
]],
    run = {
        ['~>A; ~>A; ~>25ms; ~>F'] = 2,
    }
}

Test { [[
input int P2;
par do
    loop do
        par/or do
            tmp int p2 = await P2;
            if p2 == 1 then
                return 0;
            end;
        with
            loop do
                await 200ms;
            end;
        end;
    end;
with
    async do
        emit P2(0);
        emit P2(0);
        emit P2(0);
        emit P2(0);
        emit P2(0);
        emit P2(0);
        emit P2(0);
        emit P2(1);
    end;
    await FOREVER;      // TODO: ele acha que o async termina
end;
]],
    run = 0,
}

    -- MISC

Test { [[
var int v;
loop do
    par/and do
        par/or do
            loop do
                v = 1;
                await 400ms;
                v = 1;
                await 100ms;
            end;
        with
            await 1000ms;
        end;
    with
        par/or do
            loop do
                v = 1;
                await 600ms;
                v = 1;
                await 150ms;
            end;
        with
            await 1500ms;
        end;
    with
        par/or do
            loop do
                v = 1;
                await 800ms;
                v = 1;
                await 200ms;
            end;
        with
            await 2000ms;
        end;
    end;
end;
]],
    ana = {
        --n_acc = 3,
        n_acc = 6,
        isForever = true,
    },
}

Test { [[
input void A, B;
var int aa=0, bb=0;
par/and do
    await A;
    var int a = 1;
    aa = a;
with
    var int b = 3;
    await B;
    bb = b;
end
return aa+bb;
]],
    run = { ['~>A;~>B']=4 },
}

Test { [[
input int F;
event int draw, occurring, vis, sleeping;
var int x;
par do
    await F;
    return vis;
with
    par/and do
        loop do
            await draw;
            x = x + 1;
        end;
    with
        loop do
            vis = await occurring;      // 15
        end;
    with
        loop do
            par/or do
                await sleeping;
            with
                await sleeping;
            end;
            if sleeping == 0 then
                vis = 1;                // 25
            else
                vis = 0;                // 27
            end;
        end;
    with
        loop do
            await 100ms;
            emit draw=1;
        end;
    with
        loop do
            await 100ms;
            emit sleeping=1;
            await 100ms;
            emit occurring=1;
        end;
    end;
end;
]],
    ana = {
        n_unreachs = 1,
        n_acc = 2,
    },
    run = { ['~>1000ms;1~>F'] = 1 }
}

Test { [[
input void START;
event int a, b;
var int v=0;
par/or do
    loop do
        await a;
        emit b=1;
        v = 4;
    end;
with
    loop do
        await b;
        v = 3;
    end;
with
    await START;
    emit a=1;
    return v;
end;
// unreachable
return 0;
]],
    ana = {
        n_unreachs = 1,
    },
    run = 4,
}

    -- SYNC TRIGGER

Test { [[
input void START;
event int a;
var int v1, v2;
par/and do
    par/or do
        await START;
        emit a=10;
    with
        await FOREVER;
    end;
    v1 = a;
with
    par/or do
        await a;
    with
        await FOREVER;
    end;
    v2 = a+1;
end;
return v1 + v2;
]],
    run = 21,
}

Test { [[
input void START,A;
event int a;
par/or do
    loop do
        await a;
        a = a + 1;
    end;
with
    await START;
    emit a=1;
    emit a=a;
    emit a=a;
    emit a=a;
    emit a=a;
    emit a=a;
end;
return a;
]],
    run = 2,
}

Test { [[
input void START,A;
event int a;
par/or do
    loop do
        await a;
        a = a + 1;
    end;
with
    await START;
    emit a=1;
    await A;
    emit a=a;
    await A;
    emit a=a;
    await A;
    emit a=a;
    await A;
    emit a=a;
    await A;
    emit a=a;
end;
return a;
]],
    run = { ['~>A;~>A;~>A;~>A;~>A'] = 7, },
}

Test { [[
input void START, A;
event int a, b;
par/or do
    loop do
        await b;
        b = b + 1;
    end;
with
    await a;
    emit b=1;
    await A;
    emit b=b;
    await A;
    emit b=b;
    await A;
    emit b=b;
    await A;
    emit b=b;
    await A;
    emit b=b;
    await A;
    emit b=b;
with
    await START;
    emit a=1;
    b = 0;
end;
return b;
]],
    ana = {
        --nd_esc = 1,
        n_unreachs = 1,
    },
    run = 0,
}

Test { [[
input void START;
event int a;
par/or do
    await START;
    emit a=0;
with
    await a;
    emit a=a+1;
    await FOREVER;
end;
return a;
]],
    run = 1,
}

Test { [[
input void START;
event int a,b;
par/or do
    await START;
    emit a=0;
with
    await a;
    emit b=a+1;
    a = b + 1;
    await FOREVER;
with
    await b;
    b = b + 1;
    await FOREVER;
end;
return a;
]],
    run = 3,
}

Test { [[
input void START;
input int A, F;
event int c = 0;
par do
    loop do
        await A;
        emit c=c;
    end;
with
    loop do
        await c;
        c = c + 1;
    end;
with
    await F;
    return c;
end;
]],
    run = { ['1~>A;1~>A;1~>A;1~>F'] = 3 },
}

Test { [[
input void START;
event int a;
par do
    loop do
        await START;
        emit a=0;
        emit a=a+1;
        await 10s;
    end;
with
    var int v1,v2;
    par/and do
        v1 = await a;
    with
        v2 = await a;
    end;
    return v1+v2;
end;
]],
    ana = {
        --nd_esc = 1,
        n_unreachs = 3,
        --trig_wo = 1,  -- n_unreachs
    },
    run = 0,
}

Test { [[
input void START, A;
event int a;
par do
    loop do
        await START;
        emit a=0;
        await A;
        emit a=a+1;
        await 10s;
    end;
with
    var int v1,v2;
    v1 = await a;
    v2 = await a;
    return v1 + v2;
end;
]],
    ana = {
        --nd_esc = 1,
        n_unreachs = 2,
    },
    run = { ['~>A']=1 },
}

Test { [[
input int A;
event int a, c;
par/or do
    loop do
        a = await c;
    end;
with
    await A;
    emit c=1;
    a = c;
end;
return a;
]],
    run = { ['10~>A'] = 1 },
}

Test { [[
event int a, b, c;
par/or do
    loop do
        await c;        // 4
        emit b=c+1;     // 5
        a = b;
    end;
with
    loop do
        await b;        // 10
        a = b + 1;
    end;
with
    emit c=1;           // 14
    a = c;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
    run = 1,
}

Test { [[
input int A, F;
var int i = 0;
event int a, b;
par do
    par do
        loop do
            var int v = await A;
            emit a=v;
        end;
    with
        loop do
            await a;
            emit b=a;
            await a;
            emit b=a;
        end;
    with
        loop do
            await b;
            emit a=b;
            i = i + 1;
        end;
    end;
with
    await F;
    return i;
end;
]],
    run = { ['1~>A;1~>A;1~>A;1~>A;1~>A;1~>F'] = 5 },
}

Test { [[
input int F;
event int x = 0;
event int y = 0;
var int a = 0;
var int b = 0;
var int c = 0;
par do
    loop do
        await 100ms;
        par/or do
            emit x=x+1;
        with
            emit y=y+1;
        end;
    end;
with
    loop do
        par/or do
            await x;
            a = a + x;
        with
            await y;
            b = b + y;
        end;
        c = a + b;
    end;
with
    await F;
    return c;
end;
]],
    run = { ['~>1100ms ; ~>F'] = 66 }   -- TODO: stack change
}

Test { [[
input void START;
event int a, b, c;
var int x = 0;
var int y = 0;
par/or do
    await START;
    emit a=0;
with
    await b;
    emit c=0;
with
    par/or do
        await a;
        emit b=0;
    with
        par/or do
            await b;
            x = 3;
        with
            await c;
            y = 6;
        end;
    end;
end;
return x + y;
]],
    ana = {
        n_unreachs = 4,
        --nd_esc = 4,
    },
    run = 6,    -- TODO: stack change (6 or 3)
}

Test { [[
input int F;
event int x = 0;
event int y = 0;
var int a = 0;
var int b = 0;
var int c = 0;
par do
    loop do
        await 100ms;
        par/or do
            emit x=x+1;
        with
            emit y=y+1;
        end;
        c = c + 1;
    end;
with
    loop do
        par/or do
            await x;
            a = x + a;
        with
            await y;
            b = y + b;
        end;
        c = a + b + c;
    end;
with
    await F;
    return c;
end;
]],
    run = false,    -- TODO: stack change (ND)
    run1 = {
        ['~>99ms;  ~>F'] = 0,
        ['~>199ms; ~>F'] = 3,
        ['~>299ms; ~>F'] = 10,
        ['~>300ms; ~>F'] = 23,
        ['~>330ms; ~>F'] = 23,
        ['~>430ms; ~>F'] = 44,
        ['~>501ms; ~>F'] = 75,
    }
}

Test { [[
input void START;
event int a, b;
par/and do
    await START;
    emit a=1;
    b = a;
with
    await a;
    b = a + 1;
end;
return b;
]],
    run = 1,
}
Test { [[
input void START;
event int a;
var int b;
par/or do
    await START;
    emit a=1;
    b = a;
with
    await a;
    b = a + 1;
end;
return b;
]],
    ana = {
        n_unreachs = 1,
    --nd_esc = 1,
    },
    run = 2,
}

Test { [[
input void START;
event int a;
par do
    await a;
    emit a=1;
    return a;
with
    await START;
    emit a=2;
    return a;
end;
]],
    ana = {
        --nd_esc = 1,
    n_unreachs = 1,
    --trig_wo = 1,
    },
    run = 1,
}

Test { [[
input void START;
event int a, b;
par/or do
    loop do
        await a;
        emit b=1;
    end;
with
    await START;
    emit a=1;
with
    await b;
    emit a=2;
end;
return a;
]],
    ana = {
        --nd_esc = 2,
        n_unreachs = 3,
        --trig_wo = 1,
    },
    run = 2,
}

Test { [[
input void START;
event int a;
var int x = 0;
par do
    await START;
    emit a=1;
    emit a=2;
    return x;
with
    loop do
        await a;
        x = x + 1;
    end
end
]],
    run = 1,
}
Test { [[
input void START, A;
event int a;
var int x = 0;
par do
    await START;
    emit a=1;
    await A;
    emit a=2;
    return x;
with
    await a;
    x = x + 1;
    await a;
    x = x + 1;
end
]],
    run = {['~>A']=2,},
}
Test { [[
event int a;
var int x = 0;
par do
    emit a = 1;
    return x;
with
    loop do
        await a;
        x = x + 1;
    end
end
]],
    ana = {
        n_acc = 1,
        --nd_flw = 1,
        n_unreachs = 0,
    },
}
Test { [[
input void START;
event int a, x;
x = 0;
par/or do
    await START;
    emit a= 1;
    // unreachable
with
    await a;
    x = x + 1;
    await a;        // 11
    x = x + 1;
with
    await a;
    emit a;         // 15
    // unreachable
end
return x;
]],
    ana = {
        n_acc = 1,
        n_unreachs = 2,
    },
    run = 1,
}

Test { [[
event int a, x, y, vis;
par/or do
    par/and do
        emit x=1;
        emit y=1;
    with
        loop do
            par/or do
                await x;
            with
                await y;
            end;
        end;
    end;
with
    emit a=1;
    emit x=0;
    emit y=0;
    emit vis=1;
    await FOREVER;
end;
]],
    ana = {
        --n_acc = 1,
        n_acc = 6,     -- TODO: not checked
        --trig_wo = 2,
        n_unreachs = 2,
        isForever = true,
    },
}

Test { [[
input void START;
event void x, y;
var int ret = 0;
par/or do
    par/and do
        await START;
        emit x;         // 7
        emit y;         // 8
    with
        loop do
            par/or do
                await x;
                ret = 1;    // 13
            with
                await y;
                ret = 10;   // 16
            end;
        end;
    end;
with
    await START;
    emit x;             // 22
    emit y;             // 23
end;
return ret;
]],
    ana = {
        n_acc = 3,
        --n_acc = 4,
        --trig_wo = 2,
        n_unreachs = 1,
    },
    run = 1,
}

Test { [[
input void START;
event int a, x, y;
var int ret = 0;
par do
    par/and do
        await START;
        emit x=1;           // 7
        emit y=1;           // 8
    with
        par/or do
            await x;
            ret = ret + 3;  // 12
        with
            await y;
            ret = 0;        // 15
        end;
    end;
with
    await START;
    ret = ret + 1;
    emit a=1;
    ret = ret * 2;
    emit x=0;               // 7
    ret = ret + 1;
    emit y=0;               // 25
    ret = ret * 2;
    return ret;
end;
]],
    ana = {
        n_acc = 4,
        --n_acc = 1,
        --trig_wo = 2,
        n_unreachs = 1,
    },
    run = false,        -- TODO: stack change (ND)
    --run = 18,
}

Test { [[
event int a, x, y, vis;
par/or do
    par/and do
        emit x=1;
        emit y=1;
    with
        loop do
            par/or do
                await x;
            with
                await y;
            end;
        end;
    end;
with
    emit a=1;
    emit x=0;
    emit y=0;
    emit vis=1;
    await FOREVER;
end;
]],
    ana = {
        n_acc = 6,
        --trig_wo = 2,
        n_unreachs = 2,
        isForever = true,
    },
}

Test { [[
input void START;
input int F;
event int x, w, y, z, a, vis;
par do
    loop do
        par/or do
            await x;
            x = x + 1;
        with
            await y;
            y = y + 1;
        with
            await z;
            z = z + 1;
        with
            await w;
            w = w + 1;
        end;
        a = a + 1;
    end;
with
    await START;
    emit a=1;
    emit y=1;
    emit z=1;
    emit vis=1;
with
    await F;
    return a+x+y+z+w;
end;
]],
    ana = {
        --trig_wo = 2,
        n_unreachs = 2,
    },
    run = { ['1~>F']=5 },
}

    -- SCOPE / BLOCK

Test { [[do end;]],
    ana = {
        n_reachs = 1,
        isForever = true,
    },
}
Test { [[do var int a; end;]],
    ana = {
        n_reachs = 1,
        isForever = true,
    },
}
Test { [[
do
    var int a;
    return 1;
end;
]],
    run = 1
}

Test { [[
do
    var int a = 1;
    do
        var int a = 0;
    end;
    return a;
end;
]],
    run = 1,
}

Test { [[
input int A, B;
do
    var int a = 1;
    var int tot = 0;
    par/and do
        var int a = 2;
        await A;
        tot = tot + a;
    with
        var int a = 5;
        await B;
        tot = tot + a;
    end;
    return tot + a;
end;
]],
    run = { ['~>A;~>B']=8 },
}

Test { [[
do
    var int a = 1;
    var int b = 0;
    do
        return a + b;
    end;
end;
]],
    run = 1,
}

Test { [[
input int A, B;
do
    var int a = 0;
    par/or do
        await A;
        a = 1;
        await A;
    with
        a = 2;
        await B;
    end;
    return a;
end;
]],
    run = { ['~>A;~>B']=1 },
}

Test { [[
input int A, B;
var int a;
par/or do
    var int a;
    await A;
    a = 1;
    await A;
with
    a = 2;
    await B;
end;
return a;
]],
    run = { ['~>A;~>B']=2 },
}

Test { [[
do
    var int b;
    par/or do
        do b=1; end;
    with
        do b=2; end;
    end;
end;
return 0;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
input int A, B;
var int i;
do
    par/or do
        i = 0;
        await A;
        i = i + 1;
    with
    end;
end;
await B;
return i;
]],
    ana = {
        n_unreachs = 1,
    },
    run = {
        ['~>B'] = 0,
        ['~>A ; ~>B'] = 0,
        ['~>A ; ~>A ; ~>B'] = 0,
    }
}

Test { [[
event a;
return 0;
]],
    parser = 'ERR : line 1 : after `event´ : expected type',
}

Test { [[
var int ret;
event int a;
par/or do
    do
        var int a = 0;
        par/or do
            par/or do
                emit a=40;
            with
            end;
        with
            await a;
            ret = a;
        end;
    end;
    do
        var int a = 0;
        await a;
        ret = a;
    end;
with
    a = await A;
end;
return a;
]],
    env = 'ERR : line 8 : event "a" is not declared',
}

Test { [[
var int ret = 0;
event int a,b;
par/or do
    ret = ret + 1;
with
    par/or do
        await a;    // 7
        emit b;
    with
        await b;
    end
with
    emit a;         // 13
end
par/and do
    emit a;
with
    emit b;
with
    ret = ret + 1;
end
return ret;
]],
    ana = {
        n_acc = 1,
    },
    run = 2,
}

Test { [[
var int ret = 0;
event int a;
par/or do
    ret = ret + 1;
with
    emit a;
with
    emit a;
end
par/and do
    emit a;
with
    emit a;
with
    ret = ret + 1;
end
return ret;
]],
    ana = {
        n_acc = 2,
    },
    run = 2,
}

Test { [[
input int A;
var int ret;
event int a;
par/or do
    do
        event int a = 0;
        par/or do
            par/or do
                emit a=40;  // 9
            with
            end;
        with
            await a;        // 13
            ret = a;
        end;
    end;
    do
        event int a = 0;
        await a;
        ret = a;
    end;
with
    a = await A;
end;
return a;
]],
    ana = {
        --nd_esc = 2,
        n_unreachs = 3,
        n_acc = 1,
    },
    run = { ['10~>A']=10 },
}

Test { [[
input void START;
var int ret;
par/or do
    event int a;
    par/or do
        await START;
        emit a=5;
        // unreachable
    with
        await a;
        ret = a;
    end;
with
    event int a;
    await a;
    // unreachable
    ret = 0;
end;
return ret;
]],
    ana = {
        --nd_esc = 1,
    n_unreachs = 2,
    },
    run = 5,
}

-- FINALLY

Test { [[
do
finalize with nothing; end
end
return 1;
]],
    run = 1,
}

Test { [[
finalize with
    do return 1; end;
end
return 0;
]],
    props = 'ERR : line 2 : not permitted inside `finalize´',
}

Test { [[
C _f();
do
    var int* a;
    finalize
        a = _f();
    with
        do await FOREVER; end;
    end
end
]],
    props = "ERR : line 7 : not permitted inside `finalize´",
}

Test { [[
C _f();
do
    var int* a;
    finalize
        a = _f();
    with
        async do
        end;
    end
end
]],
    props = "ERR : line 7 : not permitted inside `finalize´",
}

Test { [[
C _f();
do
    var int* a;
    finalize
        a = _f();
    with
        do return 0; end;
    end
end
]],
    props = "ERR : line 7 : not permitted inside `finalize´",
}

Test { [[
loop do
    var int* a;
    do
        var int* b;
        finalize
            a = b;
        with
            do break; end;
        end
    end
end
]],
    loop = 'ERR : line 1 : tight loop',    -- TODO: par/and
    props = "ERR : line 8 : not permitted inside `finalize´",
}

Test { [[
var int ret = 0;
do
    var int b;
    finalize with
        do
            a = 1;
            loop do
                break;
            end
            ret = a;
        end;
    end
end
return ret;
]],
    env = 'ERR : line 6 : variable/event "a" is not declared',
}

Test { [[
C _f();
var int r = 0;
do
    var int* a;
    finalize
        a = _f();
    with
        var int b = do return 2; end;       // TODO: why not?
    end
    r = 1;
end
return r;
]],
    props = "ERR : line 8 : not permitted inside `finalize´",
}

Test { [[
C _f();
_f() finalize with nothing;
    end;
return 1;
]],
    env = 'ERR : line 2 : invalid `finalize´',
}

Test { [[
var int v = 0;
do
    finalize with
        v = v * 2;
    end
    v = v + 1;
    finalize with
        v = v + 3;
    end
end
return v;
]],
    run = 8,
}

Test { [[
C _f();
C do void f () {} end

var void* p;
_f(p) finalize with nothing;
    end;
return 1;
]],
    run = 1,
}

Test { [[
C _f();
C do void f () {} end

var void* p;
_f(p!=null) finalize with nothing;
    end;
return 1;
]],
    env = 'ERR : line 5 : invalid `finalize´',
    run = 1,
}

Test { [[
C _f();
do
    var int* p1;
    do
        var int* p2;
        _f(p1, p2);
    end
end
return 1;
]],
    env = 'ERR : line 6 : call requires `finalize´',
    -- multiple scopes
}

Test { [[
C _f();
C _v;
_f(_v);
return 0;
]],
    env = 'ERR : line 3 : call requires `finalize´',
}

Test { [[
C _f();
C do
    V = 10;
    int f (int v) {
        return v;
    }
end
C constant _V;
return _f(_V);
]],
    run = 10;
}

Test { [[
C _f();
C do
    int f (int* v) {
        return 1;
    }
end
var int v;
return _f(&v) == 1;
]],
    env = 'ERR : line 8 : call requires `finalize´',
}

Test { [[
C nohold _f();
C do
    int f (int* v) {
        return 1;
    }
end
var int v;
return _f(&v) == 1;
]],
    run = 1,
}

Test { [[
C _V;
C nohold _f();
C do
    int V=1;
    int f (int* v) {
        return 1;
    }
end
var int v;
return _f(&v) == _V;
]],
    run = 1,
}

Test { [[
var int ret = 0;
var int* pa;
do
    var int v;
    if 1 then
        finalize with
            ret = ret + 1;
    end
    else
        finalize with
            ret = ret + 2;
    end
    end
end
return ret;
]],
    run = 1,
}

Test { [[
var int ret = 0;
var int* pa;
do
    var int v;
    if 1 then
        finalize
            pa = &v;
        with
            ret = ret + 1;
    end
    else
        finalize
            pa = &v;
        with
            ret = ret + 2;
    end
    end
end
return ret;
]],
    run = 1,
}

Test { [[
var int r = 0;
do
    var int a;
    await 1s;
    finalize with
        do
C nohold _fprintf(), _stderr;
_fprintf(_stderr, "oi\n");
            var int b = 1;
            r = b;
        end;
    end
end
return r;
]],
    run = { ['~>1s']=1 },
}

Test { [[
var int ret = 0;
do
    await 1s;
    finalize with
        var int a = 1;
    end
end
return ret;
]],
    run = { ['~>1s']=0 },
}

Test { [[
do
    finalize with
        if 1 then
        end;
    end
end
return 1;
]],
    run = 1,
}

Test { [[
var int ret;
do
    var int a = 1;
    finalize with
        do
            a = a + 1;
            ret = a;
        end;
    end
end
return ret;
]],
    run = 2,
}

Test { [[
var int ret;
do
    var int a = 1;
    finalize with
        do
            a = a + 1;
            ret = a;
        end;
    end
end
return ret;
]],
    run = 2,
}

Test { [[
var int ret = 0;
do
    var int a;
    finalize with
        do
            a = 1;
            ret = a;
        end;
    end
end
return ret;
]],
    run = 1,
}

Test { [[
var int a;
par/or do
    finalize with
        a = 1;
    end
with
    a = 2;
end
return a;
]],
    todo = '1 or 2: stack change',
    run = 1;
}

Test { [[
var int a;
par/or do
    do
        var int a;
        finalize with
            a = 1;
    end
    end
with
    a = 2;
end
return a;
]],
    todo = '1 or 2: stack change',
    run = 2;
}

Test { [[
var int ret;
par/or do
    do
        await 1s;
        finalize with
            ret = 3;
    end
    end
with
    await 1s;
    ret = 2;
end
return ret;
]],
    todo = '2 or 3: stack change',
    run = { ['~>1s']=3 },
}

Test { [[
input void A;
var int ret = 1;
loop do
    par/or do
        do
            await A;
            finalize with
                ret = ret + 1;
    end
        end;
        return 0;
    with
        break;
    end
end
return ret;
]],
    run = 1,
}

Test { [[
input void A;
var int ret = 1;
loop do
    par/or do
        do
            finalize with
                ret = ret + 1;
    end
            await A;
        end;
        return 0;
    with
        break;
    end
end
return ret;
]],
    run = 2,
}

Test { [[
input void A, B;
var int ret = 1;
par/or do
    do
        finalize with
            ret = 1;
    end
        await A;
    end
with
    do
        await B;
        finalize with
            ret = 2;
    end
    end
end
return ret;
]],
    run = {
        ['~>A']=1,
        ['~>B']=1
    },
}

Test { [[
input void A, B, Z;
var int ret = 1;
par/or do
    do
        await A;
        finalize with
            ret = 1;
    end
    end
with
    do
        await B;
        finalize with
            ret = 2;
    end
    end
with
    do
        await Z;
        finalize with
            ret = 3;
    end
    end
end
return ret;
]],
    todo = 'finalizers do not run in parallel',
    ana = {
        n_acc = 3,
    },
    run = { ['~>A']=0, ['~>B']=0, ['~>Z']=0 },
}

Test { [[
input void A, B, Z;
event void a;
var int ret = 1;
par/or do
    do
        await A;
        finalize with
            do
                emit a;
                ret = ret * 2;
    end
            end;
    end
with
    do
        await B;
        finalize with
            ret = ret + 5;
    end
    end
with
    loop do
        await a;
        ret = ret + 1;
    end
end
return ret;
]],
    props = 'ERR : line 9 : not permitted inside `finalize´',
}

Test { [[
input void A, B, Z;
event void a;
var int ret = 1;
par/or do
    do
        finalize with
            ret = ret * 2;      // 7
    end
        await A;
        emit a;
    end
with
    do
        finalize with
            ret = ret + 5;      // 15
    end
        await B;
    end
with
    loop do
        await a;
        ret = ret + 1;
    end
end
return ret;
]],
    ana = {
        n_acc = 3,
    },
    run = {
        ['~>A'] = 9,
        ['~>B'] = 12,
    },
}

Test { [[
input void A;
var int ret = 1;
par/or do
    do
        ret = ret + 1;
        do
            await A;
            finalize with
                ret = ret * 3;
    end
        end
        finalize with
            ret = ret + 5;
    end
    end
with
    await A;
    ret = ret * 2;
end
return ret;
]],
    todo = 'ND: stack change',
    run = { ['~>A']=17 },
}

Test { [[
input void A;
var int ret = 1;
par/or do
    do
        ret = ret + 1;
        do
            await A;
            finalize with
                ret = ret * 3;
            end
        end
        finalize with
            ret = ret + 5;
        end
    end
with
    await A;
end
ret = ret * 2;
return ret;
]],
    run = { ['~>A']=22 },
}

Test { [[
input void A, B;
var int ret = 1;
C nohold _fprintf(), _stderr;
par/or do
    do
        finalize with
            ret = ret + 5;
_fprintf(_stderr, "1\n");
        end
        ret = ret + 1;
        do
            finalize with
                ret = ret * 3;
_fprintf(_stderr, "2\n");
            end
            await A;
            ret = ret * 100;
        end
    end
with
    await B;
    ret = ret * 2;
end
return ret;
]],
    run = { ['~>B']=17, ['~>A']=605 },
}

Test { [[
input void A,B;
var int ret = 0;
loop do
    do
        finalize with
            ret = ret + 4;
    end
        par/or do
            do
                finalize with
                    ret = ret + 3;
    end
                await B;
                do
                    finalize with
                        ret = ret + 2;
    end
                    var int a;
                    await B;
                    ret = ret + 1;
                end
            end
        with
            await A;
            break;
        end
    end
end
return ret;
]],
    run = { ['~>A']=7 , ['~>B;~>B;~>A']=17, ['~>B;~>A']=9 },
}

Test { [[
var int ret = 0;
loop do
    do
        ret = ret + 1;
        do break; end
        finalize with
            ret = ret + 4;
    end
    end
end
return ret;
]],
    run = 1,
}

Test { [[
var int ret = 0;
loop do
    do
        ret = ret + 1;
        finalize with
            ret = ret + 4;
    end
        break;
    end
end
return ret;
]],
    ana = {
        n_unreachs = 2,
    },
    run = 5,
}

Test { [[
var int ret = 0;
loop do
    do
        await 1s;
        ret = ret + 1;
        do break; end
        finalize with
            ret = ret + 4;
    end
    end
end
return ret;
]],
    run = { ['~>1s']=1 },
}

Test { [[
var int ret = 0;
loop do
    do
        await 1s;
        ret = ret + 1;
        finalize with
            ret = ret + 4;
    end
        break;
    end
end
return ret;
]],
    ana = {
        n_unreachs = 2,
    },
    run = { ['~>1s']=5 },
}

Test { [[
var int ret = do
    var int ret = 0;
    loop do
        do
            await 1s;
            ret = ret + 1;
            do return ret * 2; end
            finalize with
                ret = ret + 4;  // executed after `return´ assigns to outer `ret´
    end
        end
    end
end;
return ret;
]],
    ana = {
        n_unreachs = 2,
    },
    run = { ['~>1s']=2 },
}

Test { [[
var int ret = do
    var int ret = 0;
    loop do
        do
            await 1s;
            ret = ret + 1;
            finalize with
                ret = ret + 4;  // executed after `return´ assigns to outer `ret´
    end
            return ret * 2;
        end
    end
end;
return ret;
]],
    ana = {
        n_unreachs = 2,
    },
    run = { ['~>1s']=2 },
}

Test { [[
var int ret = 0;
par/or do
    await 1s;
with
    do
        await 1s;
        finalize with
            ret = ret + 1;
    end
    end
end
return ret;
]],
    run = { ['~>1s']=0, },
}

Test { [[
var int ret = 10;
par/or do
    await 500ms;
with
    par/or do
        await 1s;
    with
        do
            finalize with
                ret = ret + 1;
    end
            await 1s;
        end
    end
end
return ret;
]],
    ana = {
        n_unreachs = 4,  -- 1s,1s,or,fin
    },
    run = { ['~>1s']=11, },
}

Test { [[
var int ret = 10;
par/or do
    await 500ms;
with
    par/or do
        await 1s;
    with
        do
            finalize with
                ret = ret + 1;
    end
            await 250ms;
            ret = ret + 1;
        end
    end
end
return ret;
]],
    ana = {
        n_unreachs = 2,  -- 500ms,1s
    },
    run = { ['~>1s']=12 },
}

Test { [[
input void A, F;
event void e;
var int v = 1;
par/or do
    do
        finalize with
            do
                v = v + 1;
                v = v * 2;
            end;
    end
        await A;
        v = v + 3;
    end
with
    await e;
    v = v * 3;
with
    await F;
    v = v * 5;
end
return v;
]],
    run = {
        ['~>F'] = 12,
        ['~>A'] = 10,
    }
}

Test { [[
C do
    void f (int* a) {
        *a = 10;
    }
    typedef void (*t)(int*);
end
C _t=4;
C nohold _f();
var _t v = _f;
var int ret;
do
    var int a;
    v(&a)
        finalize with nothing; end;
    ret = a;
end
return(ret);
]],
    run = 10,
}
Test { [[
C _t=4, _A;
C _f();
C do
    int* A = NULL;;
    void f (int* a) {
        A = a;
    }
    typedef void (*t)(int*);
end
var int ret = 0;
if _A then
    ret = ret + *_A;
end
do
    var int a = 10;;
    var _t v = _f;
    v(&a)
        finalize with
            do
                ret = ret + a;
                _A = null;
        end
            end;
    if _A then
        a = a + *_A;
    end
end
if _A then
    ret = ret + *_A;
end
return(ret);
]],
    run = 20,
}
Test { [[
input void START;
C _t=4, _A;
C _f();
C do
    int* A = NULL;;
    void f (int* a) {
        A = a;
    }
    typedef void (*t)(int*);
end
var int ret = 0;
if _A then
    ret = ret + *_A;
end
par/or do
        var int a = 10;;
        var _t v = _f;
        v(&a)
            finalize with
                do
                    ret = ret + a;
                    _A = null;
            end
                end;
        if _A then
            a = a + *_A;
        end
        await FOREVER;
with
    await START;
end
if _A then
    ret = ret + *_A;
end
return(ret);
]],
    run = 20,
}
-- TODO: bounded loop on finally

    -- ASYNCHRONOUS

Test { [[
input void A;
var int ret;
par/or do
   ret = async do
      return 10;
    end;
with
   await A;
   ret = 1;
end
return ret;
]],
    run = { ['~>A']=10 },
}

Test { [[
async do
    return 1;
end;
return 0;
]],
    props = '`return´ without block',
}

Test { [[
var int a = async do
    return 1;
end;
return a;
]],
    run = 1,
}

Test { [[
var int a=12, b;
async (a) do
    a = 1;
end;
return a;
]],
    run = 12,
}
Test { [[
var int a,b;
async (b) do
    a = 1;
end;
return a;
]],
    props = 'invalid access from async',
    --run = 1,
}

Test { [[
var int a;
async do
    a = 1;
end;
return a;
]],
    props = 'invalid access from async',
    --run = 1,
}

Test { [[
par/and do
    async do
        return 1;
    end;
with
    return 2;
end;
]],
    props = '`return´ without block',
}

Test { [[
par/and do
    var int a = async do
        return 1;
    end;
with
    return 2;
end;
]],
    --nd_flw = 1,
    run = 2,
    ana = {
        n_unreachs = 3,
    },
}

Test { [[
var int a;
par/and do
    async do
        a = 1;
    end;
with
    a = 2;
end;
return a;
]],
    props = 'invalid access from async',
    ana = {
        --n_acc = 1,
    },
}

Test { [[
async do
    return 1+2;
end;
]],
    props = '`return´ without block',
}

Test { [[
var int a = async do
    var int a = do
        return 1;
    end;
    return a;
end;
return a;
]],
    run = 1
}

Test { [[
input void X;
async do
    emit X;
end;
return 0;
]],
    run=0
}

Test { [[
input int A;
var int a;
async do
    a = 1;
    emit A(a);
end;
return a;
]],
    props = 'invalid access from async',
    --run=1
}

Test { [[
input void A;
var int a;
async do
    a = emit A;
end;
return a;
]],
    env = "ERR : line 4 : invalid input `emit´",
}

Test { [[
event int a;
async do
    emit a=1;
end;
return 0;
]],
    props = 'ERR : line 3 : invalid access from async',
}
Test { [[
event int a;
async do
    await a;
end;
return 0;
]],
    props = 'ERR : line 3 : invalid access from async',
}
Test { [[
async do
    await 1ms;
end;
return 0;
]],
    props='not permitted inside `async´'
}
Test { [[
input int X;
async do
    emit X(1);
end;
emit X(1);
return 0;
]],
  props='not permitted outside `async´'
}
Test { [[
async do
    async do
    end;
end;
]],
    props='not permitted inside `async´'
}
Test { [[
async do
    par/or do
    with
    end;
end;
]],
    props='not permitted inside `async´'
}

Test { [[
loop do
    async do
        break;
    end;
end;
return 0;
]],
    props='`break´ without loop'
}

Test { [[
C _a;
C do
    int a;
end
async do
    _a = 1;
end
return _a;
]],
    run = 1,
}

Test { [[
C _a;
C do
    int a, b;
end
par/and do
    async do
        _a = 1;
    end
with
    async do
        _a = 1;
    end
end
return _a+_b;
]],
    todo = 'async is not simulated',
    ana = {
        n_acc = 1,
    },
}

Test { [[
constant _a;
deterministic _b with _c;
C do
    int a = 1;
    int b;
    int c;
end
par/and do
    async do
        _b = 1;
    end
with
    async do
        _a = 1;
    end
with
    _c = 1;
end
return _a+_b+_c;
]],
    todo = true,
    run = 3,
}

Test { [[
C _a,_b;
C do
    int a=1,b=1;
end
par/or do
    _a = 1;
with
    _b = 1;
end
return _a + _b;
]],
    run = 2,
}

Test { [[
C _a,_b;
C do
    int a = 1;
end
var int a=0;
par/or do
    _a = 1;
with
    a = 1;
end
return _a + a;
]],
    run = 1,
}

Test { [[
C do
    int a = 1;
end
var int a;
deterministic a with _a;
par/or do
    _a = 1;
with
    a = 1;
end
return _a + a;
]],
    todo = true,
    run = 2,
}

Test { [[
C do
    int a = 1;
    int b;
    int c;
end
par/and do
    async do
        _b = 1;
    end
with
    async do
        _a = 1;
    end
with
    _c = 1;
end
return _a+_b+_c;
]],
    todo = 'nd in async',
    ana = {
        n_acc = 3,
    },
}

Test { [[
var int r = async do
    var int i = 100;
    return i;
end;
return r;
]],
    run=100
}

Test { [[
var int ret = async do
    var int i = 100;
    var int sum = 10;
    sum = sum + i;
    return sum;
end;
return ret;
]],
    run = 110,
}

-- sync version
Test { [[
input int F;
var int ret = 0;
var int f;
par/or do
    ret = do
        var int sum = 0;
        var int i = 0;
        loop do
            sum = sum + i;
            if i == 100 then
                break;
            else
                await 1ms;
                i = i + 1;
            end
        end
        return sum;
    end;
with
    f = await F;
end;
return ret+f;
]],
    run = {
        ['10~>F'] = 10,
        ['~>1s'] = 5050,
    }
}

Test { [[
input int F;
var int ret = 0;
var int f;
par/and do
    ret = async do
        var int sum = 0;
        var int i = 0;
        loop do
            sum = sum + i;
            if i == 100 then
                break;
            else
                i = i + 1;
            end
        end
        return sum;
    end;
with
    f = await F;
end;
return ret+f;
]],
    run = { ['10~>F']=5060 }
}

Test { [[
input int F;
var int ret = 0;
var int f;
par/or do
    ret = async do
        var int sum = 0;
        var int i = 0;
        loop do
            sum = sum + i;
            if i == 100 then
                break;
            else
                i = i + 1;
            end
        end
        return sum;
    end;
with
    f = await F;
end;
return ret+f;
]],
    run = { ['10~>F']=10 }
}

Test { [[
input int F;
par do
    await F;
    return 1;
with
    async do
        loop do
            if 0 then
                break;
            end;
        end;
    end;
    return 0;
end;
]],
    run = { ['1~>F'] = 1 },
}

Test { [[
input int F;
par/or do
    await F;
with
    async do
        loop do
        end;
    end;
end;
return 0;
]],
    todo = 'detect termination',
    props='async must terminate'
}

Test { [[
var int ret = async do
    var int i = 100;
    i = i - 1;
    return i;
end;
return ret;
]],
    run = 99,
}

Test { [[
var int ret = async do
    var int i = 100;
    loop do
        break;
    end;
    return i;
end;
return ret;
]],
    ana = {
        --n_unreachs = 1,       -- TODO: loop iter
    },
    run = 100,
}

Test { [[
var int ret = async do
    var int i = 0;
    if i then
        i = 1;
    else
        i = 2;
    end
    return i;
end;
return ret;
]],
    run = 2,
}

Test { [[
var int i = async do
    var int i = 10;
    loop do
        i = i - 1;
        if not i then
            return i;
        end;
    end;
end;
return i;
]],
    run = 0,
}

Test { [[
var int i = async do
    var int i = 10;
    loop do
        i = i - 1;
        if not i then
            break;
        end;
    end;
    return 0;
end;
return i;
]],
    run = 0,
}


Test { [[
var int i = async do
    var int i = 10;
    loop do
        i = i - 1;
    end;
    return 0;
end;
return i;
]],
    ana = {
        n_unreachs = 3,
        isForever = false,
    },
    --dfa = true,
    todo = true,    -- no simulation for async
}

Test { [[
var int i = 10;
async do
    loop do
        i = i - 1;
        if not i then
            break;
        end;
    end;
end;
return i;
]],
    props = 'invalid access from async',
}

Test { [[
var int sum = async do
    var int i = 10;
    var int sum = 0;
    loop do
        sum = sum + i;
        i = i - 1;
        if not i then
            return sum;
        end;
    end;
end;
return sum;
]],
    run = 55,
}

Test { [[
input int A;
par do
    async do
        emit A(1);
    end;
    return 0;
with
    await A;
    return 5;
end;
]],
    run = 5,
}

Test { [[
input int A, B;
var int a = 0;
par/or do
    async do
    end;
with
    await B;
end;
a = a + 1;
await A;
return a;
]],
    run = {
        ['1~>B ; 10~>A'] = 1,
    },
}

Test { [[
input int A;
par/or do
    async do
        emit A(4);
    end;
with
end;
return 1;
]],
    ana = {
        n_unreachs = 1,
    },
    run = 1,
}

-- round-robin test
Test { [[
input void A;
var int ret = 0;
par/or do
    loop do
        async do
            emit A;
        end
        ret = ret + 1;
    end
with
    par/and do
        var int v = async do
            var int v;
            loop i, 5 do
                v = v + i;
            end
            return v;
        end;
        ret = ret + v;
    with
        var int v = async do
            var int v;
            loop i, 5 do
                v = v + i;
            end
            return v;
        end;
        ret = ret + v;
    end
end
return ret;
]],
    todo = 'algo now is nondet',
    ana = {
        --n_unreachs = 1,       -- TODO: async
    },
    run = 23,
}

-- HIDDEN
Test { [[
var int a = 1;
var int* b = &a;
do
var int a = 0;
end
return *b;
]],
    run = 1,
}

    -- POINTERS & ARRAYS

-- int_int
Test { [[var int*p; return p/10;]],  env='invalid operands to binary "/"'}
Test { [[var int*p; return p|10;]],  env='invalid operands to binary "|"'}
Test { [[var int*p; return p>>10;]], env='invalid operands to binary ">>"'}
Test { [[var int*p; return p^10;]],  env='invalid operands to binary "^"'}
Test { [[var int*p; return ~p;]],    env='invalid operand to unary "~"'}

-- same
Test { [[var int*p; var int a; return p==a;]],
        env='invalid operands to binary "=="'}
Test { [[var int*p; var int a; return p!=a;]],
        env='invalid operands to binary "!="'}
Test { [[var int*p; var int a; return p>a;]],
        env='invalid operands to binary ">"'}

-- any
Test { [[var int*p; return p or 10;]], run=1 }
Test { [[var int*p; return p and 0;]],  run=0 }
Test { [[var int*p=null; return not p;]], run=1 }

-- arith
Test { [[var int*p; return p+p;]],     env='invalid operands to binary'}--TODO: "+"'}
Test { [[var int*p; return p+10;]],    env='invalid operands to binary'}
Test { [[var int*p; return p+10 and 0;]], env='invalid operands to binary' }

-- ptr
Test { [[var int a; return *a;]], env='invalid operand to unary "*"' }
Test { [[var int a; var int*pa; (pa+10)=&a; return a;]],
        env='invalid operands to binary'}
Test { [[var int a; var int*pa; a=1; pa=&a; *pa=3; return a;]], run=3 }

Test { [[var int  a;  var int* pa=a; return a;]], env='invalid attribution' }
Test { [[var int* pa; var int a=pa;  return a;]], env='invalid attribution' }
Test { [[
var int a;
var int* pa = do
    return a;
end;
return a;
]],
    env='invalid attribution'
}
Test { [[
var int* pa;
var int a = do
    return pa;
end;
return a;
]],
    env='invalid attribution'
}

Test { [[
var int* a;
a = null;
if a then
    return 1;
else
    return -1;
end;
]],
    run = -1,
}

Test { [[
C _char = 1;
var int i;
var int* pi;
var _char c;
var _char* pc;
i = c;
c = i;
i = <int> c;
c = <_char> i;
return 10;
]],
    env = 'ERR : line 6 : invalid attribution',
}

Test { [[
C _char = 1;
var int i;
var int* pi;
var _char c;
var _char* pc;
i = <int> c;
c = <_char> i;
return 10;
]],
    run = 10
}

Test { [[
var int* ptr1;
var void* ptr2;
if 1 then
    ptr2 = ptr1;
else
    ptr2 = ptr2;
end;
return 1;
]],
    run = 1,
}

Test { [[
var int* ptr1;
var void* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
return 1;
]],
    run = 1,
}

Test { [[
var void* ptr1;
var int* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
return 1;
]],
    run = 1,
}

Test { [[
C _char=1;
var _char* ptr1;
var int* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
return 1;
]],
    env = 'ERR : line 4 : invalid attribution',
}
Test { [[
C _char=1;
var _char* ptr1;
var int* ptr2;
ptr1 = <_char*>ptr2;
ptr2 = <int*>ptr1;
return 1;
]],
    run = 1,
}
Test { [[
C _char=1;
var int* ptr1;
var _char* ptr2;
ptr1 = <int*> ptr2;
ptr2 = <_char*> ptr1;
return 1;
]],
    run = 1,
}

Test { [[
C _FILE=0;
var int* ptr1;
var _FILE* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
return 1;
]],
    env = 'ERR : line 4 : invalid attribution',
}

Test { [[
var int a = 1;
var int* b = &a;
*b = 2;
return a;
]],
    run = 2,
}

Test { [[
var int a;
var int* pa;
par/or do
    a = 1;
with
    pa = &a;
end;
return a;
]],
    run = 1,
}

Test { [[
var int b = 1;
var int* a = &b;
par/or do
    b = 1;
with
    *a = 0;
end
return b;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
var int b = 1;
var int c = 2;
var int* a = &c;
deterministic b with a, c;
par/and do
    b = 1;
with
    *a = 3;
end
return *a+b+c;
]],
    run = 7,
}

Test { [[
C nohold _f();
C do
    void f (int* v) {
        *v = 1;
    }
end
var int a, b;
par/and do
    _f(&b);
with
    _f(&a);
end
return a + b;
]],
    run = 2,
    ana = {
        n_acc = 1,
    },
}

Test { [[
C nohold _f();
C do
    void f (int* v) {
        *v = 1;
    }
end
var int a, b;
var int* pb = &b;
par/and do
    a = 1;              // 10
with
    _f(&b);             // 12
with
    _f(&a);             // 14
with
    _f(pb);             // 16
end
return a + b;
]],
    run = 2,
    ana = {
        n_acc = 7,
    },
}

Test { [[
C nohold _f();
C do
    void f (int* v) {
        *v = 1;
    }
end
var int a, b;
var int* pb = &b;
par/or do
    a = 1;
with
    _f(&b);
with
    _f(&a);
with
    _f(pb);
end
return a + b;
]],
    run = 1,
    ana = {
        n_acc = 7,
    },
}

Test { [[
pure _f;
C do
    void f (int* v) {
        *v = 1;
    }
end
var int a, b;
var int* pb = &b;
par/and do
    a = 1;
with
    _f(&b);
with
    _f(&a);
with
    _f(pb);
end
return a + b;
]],
    todo = true,
    run = 2,
    ana = {
        n_acc = 2,
    },
}

Test { [[
pure _f;
C do
    void f (int* v) {
        *v = 1;
    }
end
var int a, b;
var int* pb = &b;
par/or do
    a = 1;
with
    _f(&b);
with
    _f(&a);
with
    _f(pb);
end
return a + b;
]],
    todo = true,
    run = 1,
    ana = {
        n_acc = 2,
    },
}

Test { [[
var int b = 10;
var int* a = <int*> &b;
var int* c = &b;
return *a + *c;
]],
    run = 20;
}

Test { [[
C _f();
C do
    int* f () {
        int a = 10;
        return &a;
    }
end
var int* p = _f();
return *p;
]],
    env = 'ERR : line 8 : attribution requires `finalize´',
}

Test { [[
var int a := 1;
return a;
]],
    env = 'ERR : line 1 : invalid attribution',
}

Test { [[
C _f();
C do
    int a;
    int* f () {
        a = 10;
        return &a;
    }
end
var int* p;
finalize
    p = _f();
with
    nothing;
end
return *p;
]],
    run = 10,
}
Test { [[
C _f();
C do
    int a;
    int* f () {
        a = 10;
        return &a;
    }
end
var int* p;
finalize
    p = _f();
with
    nothing;
end
return *p;
]],
    run = 10,
}
Test { [[
C pure _f();    // its is actually impure
C do
    int a;
    int* f () {
        a = 10;
        return &a;
    }
end
var int* p;
    p = _f();
return *p;
]],
    run = 10,
}
Test { [[
C _f();
C do
    int A = 10;
    int* f () {
        return &A;
    }
end
var int a;
do
    var int* p;
    finalize
        p = _f();
    with
        a = *p;
end
end
return a;
]],
    run = 10,
}

Test { [[
C _f();
C do
    int A = 10;
    int* f () {
        return &A;
    }
end
var int a = 10;
do
    var int* p;
    do
        finalize
            p = _f();
        with
            a = a + *p;
end
    end
    a = 0;
end
return a;
]],
    run = 10,
}

Test { [[
C _char = 1;
var _char* p;
*(p:a) = <_char>1;
return 1;
]],
    run = false,
}

    -- ARRAYS

Test { [[input int[1] E; return 0;]],
    parser = "ERR : line 1 : after `int´ : expected identifier",
}
Test { [[var int[0] v; return 0;]],
    env='invalid array dimension'
}
Test { [[var int[2] v; return v;]],
    env = 'invalid attribution'
}
Test { [[var u8[2] v; return &v;]],
    env = 'invalid operand to unary "&"',
}

Test { [[
void[10] a;
]],
    parser = 'ERR : line 1 : after `<BOF>´ : expected statement',
}

Test { [[
var void[10] a;
]],
    env = 'ERR : line 1 : cannot instantiate type "void"',
}

Test { [[
var int[2] v;
v[0] = 5;
return v[0];
]],
    run = 5
}

Test { [[
var int[2] v;
v[0] = 1;
v[1] = 1;
return v[0] + v[1];
]],
    run = 2,
}

Test { [[
var int[2] v;
var int i;
v[0] = 0;
v[1] = 5;
v[0] = 0;
i = 0;
return v[i+1];
]],
    run = 5
}

Test { [[
var void a;
var void[1] b;
]],
    env = 'ERR : line 1 : cannot instantiate type "void"',
}

Test { [[
var int a;
var void[1] b;
]],
    env = 'ERR : line 2 : cannot instantiate type "void"',
}

Test { [[
C do
    typedef struct {
        int v[10];
        int c;
    } T;
end
C _T = 44;

var _T[10] vec;
var int i = 110;

vec[3].v[5] = 10;
vec[9].c = 100;
return i + vec[9].c + vec[3].v[5];
]],
    run = 220,
}

Test { [[var int[2] v; await v;     return 0;]],
        env='event "v" is not declared' }
Test { [[var int[2] v; emit v;    return 0;]],
        env='event "v" is not declared' }
Test { [[var int[2] v; await v[0];  return 0;]],
        env='ERR : line 1 : event "?" is not declared'}
Test { [[var int[2] v; emit v[0]; return 0;]],
        env='event "?" is not declared' }
Test { [[var int[2] v; v=v; return 0;]], env='invalid attribution' }
Test { [[var int v; return v[1];]], env='cannot index a non array' }
Test { [[var int[2] v; return v[v];]], env='invalid array index' }

Test { [[
var int[2] v ;
return v == &v[0] ;
]],
    run = 1,
}

Test { [[
C nohold _f();
C do
    void f (int* p) {
        *p = 1;
    }
end
var int[2] a;
var int b;
par/and do
    b = 2;
with
    _f(a);
end
return a[0] + b;
]],
    run = 3,
}

Test { [[
C nohold _f();
C do
    void f (int* p) {
        *p = 1;
    }
end
var int[2] a;
var int b;
par/or do
    b = 2;
with
    _f(a);
end
return a[0] + b;
]],
    run = 2,
}

Test { [[
var u8[255] vec;
event void  e;
return 1;
]],
    run = 1,
}

local evts = ''
for i=1, 256 do
    evts = evts .. 'event u8 e'..i..';\n'
end
Test { [[
]]..evts..[[
return 1;
]],
    mem = 'ERR : line 1 : too many events',
}

Test { [[
tmp int a = 1;
return a;
]],
    run = 1,
}

    -- C FUNCS BLOCK

Test { [[
C _printf();
do
    _printf("oi\n");
end
return 10;
]],
    run = 10;
}

Test { [[
C _V;
C do
    int V[2][2] = { {1, 2}, {3, 4} };
end

_V[0][1] = 5;
return _V[1][0] + _V[0][1];
]],
    run = 8,
}

Test { [[
C _END;
C do
    int END = 1;
end
if not  _END-1 then
    return 1;
else
    return 0;
end
]],
    run = 1,
}

Test { [[
C do
end
return 1;
]],
    run = 1,
}

Test { [[
C do
    char* a = "end";
end
return 1;
]],
    run = 1,
}

Test { [[
C do
    /*** END ***/
    char* a = "end";
    /*** END ***/
end
return 1;
]],
    run = 1,
}

Test { [[
C do
    int A () {}
end
A = 1;
return 1;
]],
    parser = 'ERR : line 3 : after `end´ : expected statement'
}

Test { [[
C do
    void A (int v) {}
end
return 0;
]],
    run = 0;
}

Test { [[
C do
    int A (int v) {}
end
return 0;
]],
    --env = 'A : incompatible with function definition',
    run = 0,
}

Test { [[
C _A;
C do
    void A (int v) {}
end
_A();
return 0;
]],
    env = 'ERR : line 5 : C function "_A" is not declared',
}

Test { [[
C _A();
C do
    void A (int v) {}
end
_A();
return 0;
]],
    run = false,
}

Test { [[
C _A();
C do
    void A () {}
end
var int v = _A();
return v;
]],
    run = false,
}

Test { [[emit A(10); return 0;]],
    env = 'event "A" is not declared'
}

Test { [[
C _Const();
C do
    int Const () {
        return -10;
    }
end
var int ret = _Const();
return ret;
]],
    run = -10
}

Test { [[
C _ID();
C do
    int ID (int v) {
        return v;
    }
end
return _ID(10);
]],
    run = 10,
}

Test { [[
C _ID();
C do
    int ID (int v) {
        return v;
    }
end
var int v = _ID(10);
return v;
]],
    run = 10
}

Test { [[
C _VD();
C do
    void VD (int v) {
    }
end
_VD(10);
return 1;
]],
    run = 1
}

Test { [[
C _VD();
C do
    void VD (int v) {
    }
end
var int ret = _VD(10);
return ret;
]],
    run = false,
}

Test { [[
C do
    void VD (int v) {
    }
end
var void v = _VD(10);
return v;
]],
    env = 'line 5 : cannot instantiate type "void"',
}

Test { [[
C _NEG();
C do
    int NEG (int v) {
        return -v;
    }
end
return _NEG(10);
]],
    run = -10,
}

Test { [[
C _NEG();
C do
    int NEG (int v) {
        return -v;
    }
end
var int v = _NEG(10);
return v;
]],
    run = -10
}

Test { [[
C _ID();
C do
    int ID (int v) {
        return v;
    }
end
input int A;
var int v;
par/and do
    await A;
with
    v = _ID(10);
end;
return v;
]],
    run = {['1~>A']=10},
}

Test { [[
C _ID();
C do
    int ID (int v) {
        return v;
    }
end
input int A;
var int v;
par/or do
    await A;
with
    v = _ID(10);
end
return v;
]],
    ana = {
        n_unreachs = 1,
    },
    run = 10,
}

Test { [[
C _Z1();
C do int Z1 (int a) { return a; } end
input int A;
var int c;
_Z1(3);
c = await A;
return c;
]],
    run = {
        ['10~>A ; 20~>A'] = 10,
        ['3~>A ; 0~>A'] = 3,
    }
}

Test { [[
C nohold _f1(), _f2();
C do
    int f1 (u8* v) {
        return v[0]+v[1];
    }
    int f2 (u8* v1, u8* v2) {
        return *v1+*v2;
    }
end
var u8[2] v;
v[0] = 8;
v[1] = 5;
return _f2(&v[0],&v[1]) + _f1(v) + _f1(&v[0]);
]],
    run = 39,
}

--[=[

PRE = [[
C do
    static inline int idx (const int* vec, int i) {
        return vec[i];
    }
    static inline int set (int* vec, int i, int val) {
        vec[i] = val;
        return val;
    }
end
pure _idx;
int[2] va;

]]

Test { PRE .. [[
_set(va,1,1);
return _idx(va,1);
]],
    run = 1,
}

Test { PRE .. [[
_set(va,0,1);
_set(va,1,2);
return _idx(va,0) + _idx(va,1);
]],
    run = 3,
}

Test { PRE .. [[
par/and do
    _set(va,0,1);
with
    _set(va,1,2);
end;
return _idx(va,0) + _idx(va,1);
]],
    ana = {
        n_acc = 2,
    },
}
Test { PRE .. [[
par/and do
    _set(va,0,1);
with
    _idx(va,1);
end;
return _idx(va,0) + _idx(va,1);
]],
    ana = {
        n_acc = 1,
    },
}
Test { PRE .. [[
_set(va,0,1);
_set(va,1,2);
par/and do
    _idx(va,0);
with
    _idx(va,1);
end;
return _idx(va,0) + _idx(va,1);
]],
    run = 3,
}

Test { [[
int a, b;
int* pa, pb;

par/or do
    pa = &a;
with
    pb = &b;
end;
return 1;
]],
    run = 1
}

PRE = [[
pure _f3, _f5;
C do
int f1 (int* a, int* b) {
    return *a + *b;
}
int f2 (const int* a, int* b) {
    return *a + *b;
}
int f3 (const int* a, const int* b) {
    return *a + *b;
}
int f4 (int* a) {
    return *a;
}
int f5 (const int* a) {
    return *a;
}
end
]]

Test { PRE .. [[
int a = 1;
int b = 2;
return _f1(&a,&b);
]],
    run = 3,
}

Test { PRE .. [[
int* pa;
par/or do
    _f4(pa);
with
    int v = 1;
end;
return 0;
]],
    ana = {
        n_acc = 1,
    },
}
Test { PRE .. [[
int a;
par/or do
    _f4(&a);
with
    int v = a;
end;
return 0;
]],
    ana = {
        n_acc = 1,
    },
}
Test { PRE .. [[
int a, b;
par/or do
    _f5(&a);
with
    a = 1;
end;
return 0;
]],
    ana = {
        n_acc = 1,
    },
}
Test { PRE .. [[
int a = 10;
par/or do
    _f5(&a);
with
    return a;
end;
return 0;
]],
    run = false,
    ana = {
        --nd_flw = 1,
    }
}
Test { PRE .. [[
int a;
int* pa;
par/or do
    _f5(pa);
with
    return a;
end;
return 0;
]],
    --nd_flw = 1,
    ana = {
        n_acc = 1,
    },
}
Test { PRE .. [[
int a, b;
par/or do
    _f4(&a);
with
    int v = b;
end;
return 0;
]],
    run = 0,
}
Test { PRE .. [[
int a, b;
par/or do
    _f5(&a);
with
    b = 1;
end;
return 0;
]],
    run = 0,
}

Test { PRE .. [[
int a, b;
par/or do
    _f5(&a);
with
    int v = b;
end;
return 0;
]],
    run = 0,
}
Test { PRE .. [[
int* pa;
do
    int a;
    pa = &a;
end;
return 1;
]],
    run = 1,     -- TODO: check_depth
    --env = 'invalid attribution',
}
Test { PRE .. [[
int a=1;
do
    int* pa = &a;
    *pa = 2;
end;
return a;
]],
    run = 2,
}

Test { PRE .. [[
int a;
int* pa;
par/or do
    _f4(pa);
with
    int v = a;
end;
return 0;
]],
    ana = {
        n_acc = 2, -- TODO: scope of v vs pa
    },
}
Test { PRE .. [[
int a;
int* pa;
par/or do
    _f5(pa);
with
    a = 1;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}
Test { PRE .. [[
int a;
int* pa;
par do
    return _f5(pa);
with
    return a;
end;
]],
    --nd_flw = 2,
    ana = {
        n_acc = 2, -- TODO: $ret vs anything is DET
    },
}

Test { PRE .. [[
int a=1, b=5;
par/or do
    _f4(&a);
with
    _f4(&b);
end;
return a+b;
]],
    ana = {
        n_acc = 1,
    },
    run = 6,
}

Test { PRE .. [[
int a = 1;
int b = 2;
int v1, v2;
par/and do
    v1 = _f1(&a,&b);
with
    v2 = _f1(&a,&b);
end;
return v1 + v2;
]],
    ana = {
        n_acc = 3,
    },
}

Test { PRE .. [[
int a = 1;
int b = 2;
int v1, v2;
par/and do
    v1 = _f2(&a,&b);
with
    v2 = _f2(&a,&b);
end;
return v1 + v2;
]],
    ana = {
        n_acc = 3,     -- TODO: f2 is const
    },
}

Test { PRE .. [[
int a = 1;
int b = 2;
int v1, v2;
par/and do
    v1 = _f3(&a,&b);
with
    v2 = _f3(&a,&b);
end;
return v1 + v2;
]],
    run = 6,
}

Test { PRE .. [[
int a = 2;
int b = 2;
int v1, v2;
par/and do
    v1 = _f4(&a);
with
    v2 = _f4(&b);
end;
return a+b;
]],
    run = 4,
    ana = {
        n_acc = 1,
    },
}

Test { PRE .. [[
int a = 2;
int b = 2;
int v1, v2;
par/and do
    v1 = _f4(&a);
with
    v2 = _f4(&a);
end;
return a+a;
]],
    ana = {
        n_acc = 2,
    },
}

Test { PRE .. [[
int a = 2;
int b = 2;
int v1, v2;
par/and do
    v1 = _f5(&a);
with
    v2 = _f5(&a);
end;
return a+a;
]],
    run = 4,
}

Test { PRE .. [[
int a;
int* pa = &a;
a = 2;
int v1,v2;
par/and do
    v1 = _f4(&a);
with
    v2 = _f4(pa);
end;
return v1+v2;
]],
    ana = {
        n_acc = 3,
    },
}

Test { PRE .. [[
int a;
int* pa = &a;
a = 2;
int v1,v2;
par/and do
    v1 = _f5(&a);
with
    v2 = _f5(pa);
end;
return v1+v2;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
par/and do
    _printf("END: 1\n");
with
    _assert(1);
end
return 0;
]],
    ana = {
        n_acc = 1,
    },
    run = false,
}

Test { [[
deterministic _printf with _assert;
C do #include <assert.h> end
par/and do
    _printf("END: 1\n");
with
    _assert(1);
end
return 0;
]],
    todo = true,
    run = 1,
}
--]=]

Test { [[
C _a;
C do
    int a;
end
par/or do
    _a = 1;
with
    _a = 2;
end
return _a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
constant _HIGH, _LOW;
par do
    loop do
        _digitalWrite(11, _HIGH);
        await 1s;
        _digitalWrite(11, _LOW);
        await 1s;
    end
with
    loop do
        _digitalWrite(12, _HIGH);
        await 500ms;
        _digitalWrite(12, _LOW);
        await 500ms;
    end
with
    loop do
        _digitalWrite(13, _HIGH);
        await 250ms;
        _digitalWrite(13, _LOW);
        await 250ms;
    end
end
]],
    todo = true,
    ana = {
        n_acc = 6,
        isForever = true,
    },
}

Test { [[
C _LOW, _HIGH, _digitalWrite();
par do
    loop do
        _digitalWrite(11, _HIGH);
        await 1s;
        _digitalWrite(11, _LOW);
        await 1s;
    end
with
    loop do
        _digitalWrite(12, _HIGH);
        await 500ms;
        _digitalWrite(12, _LOW);
        await 500ms;
    end
with
    loop do
        _digitalWrite(13, _HIGH);
        await 250ms;
        _digitalWrite(13, _LOW);
        await 250ms;
    end
end
]],
    ana = {
        n_acc = 24,        -- TODO: nao conferi
        isForever = true,
    },
    env = 'line 4 : call requires `finalize´',
}

Test { [[
C constant _LOW, _HIGH;
C _digitalWrite();
par do
    loop do
        _digitalWrite(11, _HIGH);
        await 1s;
        _digitalWrite(11, _LOW);
        await 1s;
    end
with
    loop do
        _digitalWrite(12, _HIGH);
        await 500ms;
        _digitalWrite(12, _LOW);
        await 500ms;
    end
with
    loop do
        _digitalWrite(13, _HIGH);
        await 250ms;
        _digitalWrite(13, _LOW);
        await 250ms;
    end
end
]],
    ana = {
        n_acc = 6,   -- TODO: loop
        isForever = true,
    },
}

Test { [[
C _F();
output int F;
C do
    void F() {};
end
par do
    _F();
with
    emit F(1);
end
]],
    ana = {
        n_reachs = 1,
        n_acc = 1,
        isForever = true,
    },
}

Test { [[
C _F();
output int F,G;
C do
    void F() {};
end
par do
    _F();
with
    emit F(1);
with
    emit G(0);
end
]],
    ana = {
        n_reachs = 1,
        n_acc = 3,
        isForever = true,
    },
}

Test { [[
C _F();
deterministic _F with F,G;
output int F,G;
C do
    void F() {};
end
par do
    _F();
with
    emit F(1);
with
    emit G(0);
end
]],
    todo = true,
    ana = {
        n_acc = 1,
        isForever = true,
    },
}

Test { [[
C _F();
output int* F,G;
deterministic _F with F,G;
int a = 1;
int* b;
C do
    void F (int v) {};
end
par do
    _F(&a);
with
    emit F(b);
with
    emit G(&a);
end
]],
    todo = true,
    ana = {
        n_acc = 4,
        isForever = true,
    },
}

Test { [[
C _F();
pure _F;
output int* F,G;
int a = 1;
int* b;
C do
    void F (int v) {};
end
par do
    _F(&a);
with
    emit F(b);
with
    emit G(&a);
end
]],
    todo = true,
    ana = {
        n_acc = 4,
        isForever = true,
    },
}

Test { [[
C _F();
deterministic F with G;
output void F,G;
par do
    emit F;
with
    emit G;
end
]],
    todo = true,
    ana = {
        n_reachs = 1,
        isForever = true,
    },
}

    -- STRINGS

Test { [[
C _char=1;
var _char* a = "Abcd12" ;
return 1;
]],
    run = 1
}
Test { [[
C _printf();
_printf("END: %s\n", "Abcd12");
return 0;
]],
    run='Abcd12',
}
Test { [[
C _strncpy(), _printf(), _strlen();
return _strlen("123");
]], run=3 }
Test { [[
C _printf();
_printf("END: 1%d\n",2); return 0;]], run=12 }
Test { [[
C _printf();
_printf("END: 1%d%d\n",2,3); return 0;]], run=123 }

Test { [[
C nohold _strncpy(), _printf(), _strlen();
C _char = 1;
var _char[10] str;
_strncpy(str, "123", 4);
_printf("END: %d %s\n", _strlen(str), str);
return 0;
]],
    run = '3 123'
}

Test { [[
C nohold _strncpy(), _printf(), _strlen(), _strcpy();
C _char = 1;
var _char[6] a; _strcpy(a, "Hello");
var _char[2] b; _strcpy(b, " ");
var _char[7] c; _strcpy(c, "World!");
var _char[30] d;

var int len = 0;
_strcpy(d,a);
_strcpy(&d[_strlen(d)], b);
_strcpy(&d[_strlen(d)], c);
_printf("END: %d %s\n", _strlen(d), d);
return 0;
]],
    run = '12 Hello World!'
}

Test { [[
C _const_1();
C do
    int const_1 () {
        return 1;
    }
end
return _const_1();
]],
    run = 1;
}

Test { [[
C _const_1();
C do
    int const_1 () {
        return 1;
    }
end
return _const_1() + _const_1();
]],
    run = 2;
}

Test { [[
C _inv();
C do
    int inv (int v) {
        return -v;
    }
end
var int a;
a = _inv(_inv(1));
return a;
]],
    env = 'ERR : line 8 : call requires `finalize´',
}

Test { [[
C pure _inv();
C do
    int inv (int v) {
        return -v;
    }
end
var int a;
a = _inv(_inv(1));
return a;
]],
    run = 1,
}

Test { [[
C _id();
C do
    int id (int v) {
        return v;
    }
end
var int a;
a = _id(1);
return a;
]],
    run = 1
}

Test { [[
var int[2] v;
par/or do
    v[0] = 1;
with
    v[1] = 2;
end;
return 0;
]],
    ana = {
        n_acc = 1,
    },
}
Test { [[
var int[2] v;
var int i,j;
par/or do
    v[j] = 1;
with
    v[i+1] = 2;
end;
return 0;
]],
    ana = {
        n_acc = 1,
    },
}

-- STRUCTS / SIZEOF

Test { [[
C do
typedef struct {
    u16 a;
    u8 b;
    u8 c;
} s;
end
C _s = 4;
var _s vs;
vs.a = 10;
vs.b = 1;
return vs.a + vs.b + sizeof<_s>;
]],
    run = 15,
}

Test { [[
C _SZ;
C _aaa = (sizeof<void*,u16>) * 2;
C do
    typedef struct {
        void* a;
        u16 b;
    } t1;
    typedef struct {
        t1 v[2];
    } aaa;
    int SZ = sizeof(aaa);
end
return sizeof<_aaa> + _SZ;
]],
    run = 28,   -- TODO: different packings
}

Test { [[
C do
    typedef struct {
        u16 ack;
        u8 data[16];
    } Payload;
end
C _Payload = 18;
var _Payload final;
var u8* neighs = &(final.data[4]);
return 1;
]],
    run = 1;
}

Test { [[
C do
typedef struct {
    int a;
    int b;
} s;
end
C _s = 8;
var _s vs;
par/and do
    vs.a = 10;
with
    vs.a = 1;
end;
return vs.a;
]],
    ana = {
        n_acc = 1,
    },
}

Test { [[
C do
typedef struct {
    int a;
    int b;
} s;
end
C _s = 8;
var _s vs;
par/and do
    vs.a = 10;
with
    vs.b = 1;
end;
return vs.a;
]],
    ana = {
        n_acc = 1,     -- TODO: struct
    },
}

Test { [[
C do
    typedef struct {
        int a;
    } mys;
end
C _mys = 4;
var _mys v;
var _mys* pv;
pv = &v;
v.a = 10;
(*pv).a = 20;
pv:a = pv:a + v.a;
return v.a;
]],
    run = 40,
}

Test { [[
]],
    ana = {
        n_reachs = 1,
        isForever = true,
    }
}

Test { [[
C _char=1;
tmp u8[10] v1;
tmp _char[10] v2;

loop i, 10 do
    v1[i] = i;
    v2[i] = <_char> (i*2);
end

var int ret = 0;
loop i, 10 do
    ret = ret + <u8>v2[i] - v1[i];
end

return ret;
]],
    loop = 1,
    run = 45,
}

Test { [[
C _message_t = 52;
C _t = sizeof<_message_t, u8>;
return sizeof<_t>;
]],
    run = 53,
}

Test { [[
C _char=1;
tmp _char a = <_char> 1;
return <int>a;
]],
    run = 1,
}

-- Exps

Test { [[var int a = ]],
    parser = "ERR : line 1 : after `=´ : expected expression",
}

Test { [[return]],
    parser = "ERR : line 1 : after `return´ : expected expression",
}

Test { [[return()]],
    parser = "ERR : line 1 : after `(´ : expected expression",
}

Test { [[return 1+;]],
    parser = "ERR : line 1 : before `+´ : expected `;´",
}

Test { [[if then]],
    parser = "ERR : line 1 : after `if´ : expected expression",
}

Test { [[b = ;]],
    parser = "ERR : line 1 : after `=´ : expected expression",
}


Test { [[


return 1

+


;
]],
    parser = "ERR : line 5 : before `+´ : expected `;´"
}

Test { [[
var int a;
a = do
    var int b;
end
]],
    parser = "ERR : line 4 : after `end´ : expected `;´",
}

-- ASYNC

Test { [[
async do

    par/or do
        var int a;
    with
        var int b;
    end
end
]],
    props = "ERR : line 3 : not permitted inside `async´",
}
Test { [[
async do


    par/and do
        var int a;
    with
        var int b;
    end
end
]],
    props = "ERR : line 4 : not permitted inside `async´",
}
Test { [[
async do
    par do
        var int a;
    with
        var int b;
    end
end
]],
    props = "ERR : line 2 : not permitted inside `async´",
}

-- DFA

Test { [[
var int a;
]],
    ana = {
        n_reachs = 1,
        isForever = true,
    },
}

Test { [[
var int a;
a = do
    var int b;
end;
]],
    ana = {
        n_reachs = 1,
        n_unreachs = 1,
        isForever = true,
    },
}

Test { [[
var int a;
par/or do
    a = 1;
with
    a = 2;
end;
return a;
]],
    ana = {
        n_acc = 1,
    },
}

-- BIG // FULL // COMPLETE
Test { [[
input int KEY;
if 1 then return 50; end
par do
    var int pct, dt, step, ship, points;
    var int win = 0;
    loop do
        if win then
            // next phase (faster, harder, keep points)
            step = 0;
            ship = 0;
            if dt > 100 then
                dt = dt - 50;
            end
            if pct > 10 then
                pct = pct - 1;
            end
        else
            // restart
            pct    = 35;    // map generator (10 out of 35 for a '#')
            dt     = 500;   // game speed (500ms/step)
            step   = 0;     // current step
            ship   = 0;     // ship position (0=up, 1=down)
            points = 0;     // number of steps alive
        end
        await KEY;
        win = par do
                loop do
                    await (dt)ms;
                    step = step + 1;

                    if step == 1 then
                        return 1;           // finish line
                    end
                    points = points + 1;
                end
            with
                loop do
                    tmp int key = await KEY;
                    if key == 1 then
                        ship = 0;
                    end
                    if key == 1 then
                        ship = 1;
                    end
                end
            end;
        par/or do
            await 1s;
            await KEY;
        with
            if not win then
                loop do
                    await 100ms;
                    await 100ms;
                end
            end
        end
    end
with
    var int key = 1;
    loop do
        var int read1 = 1;
            read1 = 1;
        await 50ms;
        var int read2 = 1;
            read2 = 1;
        if read1==read2 and key!=read1 then
            key = read1;
            if key != 1 then
                async (read1) do
                    emit KEY(read1);
                end
            end
        end
    end
end
]],
    run = 50,
}

    -- PAUSE

Test { [[
input void A;
pause/if A do
end
return 0;
]],
    parser = 'ERR : line 2 : after `pause/if´ : expected variable/event',
}

Test { [[
event void a;
pause/if a do
end
return 0;
]],
    --env = 'ERR : line 2 : event type must be numeric',
    env = 'ERR : line 2 : invalid operands to binary "!="',
}

Test { [[
event int a;
pause/if a do
end
return 1;
]],
    run = 1,
}

Test { [[
input int A, B;
event int a;
par/or do
    loop do
        var int v = await A;
        emit a=v;
    end
with
    pause/if a do
        var int v = await B;
        return v;
    end
end
]],
    ana = {
        n_unreachs = 1,
    },
    run = {
        ['1~>B'] = 1,
        ['0~>A ; 1~>B'] = 1,
        ['1~>A ; 1~>B ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>A ; 1~>B ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 1~>B ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 0~>A ; 1~>A ; 2~>B ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 0~>A ; 1~>A ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 1~>A ; 2~>B ; 0~>A ; 3~>B'] = 3,
    },
}

-- TODO: nesting with same event
Test { [[
input int A,B;
event int a;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a=v;
    end
with
    pause/if a do
        pause/if a do
            ret = await B;
        end
    end
end
return ret;
]],
    run = {
        ['1~>B'] = 1,
        ['0~>A ; 1~>B'] = 1,
        ['1~>A ; 1~>B ; 0~>A ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 0~>A ; 1~>A ; 2~>B ; 0~>A ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 0~>A ; 1~>A ; 0~>A ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 1~>A ; 2~>B ; 0~>A ; 0~>A ; 3~>B'] = 3,
    },
}

Test { [[
input int A, B, Z;
event int a, b;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a=v;
    end
with
    loop do
        var int v = await B;
        emit b=v;
    end
with
    pause/if a do
        pause/if b do
            ret = await Z;
        end
    end
end
return ret;
]],
    run = {
        ['1~>Z'] = 1,
        ['1~>A ; 10~>Z ; 1~>B ; 10~>Z ; 0~>B ; 10~>Z ; 0~>A ; 5~>Z'] = 5,
        ['1~>A ; 1~>B ; 0~>B ; 10~>Z ; 0~>A ; 1~>B ; 5~>Z ; 0~>B ; 100~>Z'] = 100,
    },
}

Test { [[
input int  A;
input int  B;
input void Z;
event int a;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a=v;
    end
with
    pause/if a do
        await Z;
        ret = await B;
    end
end
return ret;
]],
    run = {
        ['~>Z ; 1~>B'] = 1,
        ['0~>A ; 1~>B ; ~>Z ; 2~>B'] = 2,
        ['~>Z ; 1~>A ; 1~>B ; 0~>A ; 3~>B'] = 3,
        ['~>Z ; 1~>A ; 1~>B ; 1~>A ; 2~>B ; 0~>A ; 3~>B'] = 3,
    },
}

Test { [[
input int  A;
input void Z;
event int a;
var int ret = 0;
par/or do
    emit a=1;
    await A;
with
    pause/if a do
        finalize with
            ret = 10;
    end
        await Z;
    end
end
return ret;
]],
    run = {
        ['1~>A'] = 10,
    },
}

Test { [[
input int  A;
input void Z;
event int a;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a=v;
    end
with
    pause/if a do
        await 9s;
    end
    ret = 9;
with
    await 10s;
    ret = 10;
end
return ret;
]],
    ana = {
        n_acc = 1,     -- TODO: 0
    },
    run = {
        ['1~>A ; ~>5s ; 0~>A ; ~>5s'] = 10,
    },
}

Test { [[
input int  A,B,F;
input void Z;
event int a;
var int ret = 50;
par/or do
    loop do
        var int v = await A;
        emit a=v;
    end
with
    pause/if a do
        ret = await B;
    end
with
    await F;
end
return ret;
]],
    run = {
        ['1~>A ; 10~>B ; 1~>F'] = 50,
    },
}

Test { [[
input void F;
par/or do
    await F;
with
    await 1us;
end
tmp int v = await 1us;
return v;
]],
    run = { ['~>1us; ~>F; ~>4us; ~>F']=3 }
}

Test { [[
input int  A;
input void Z;
event int a;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a=v;
    end
with
    pause/if a do
        ret = await 9us;
    end
end
return ret;
]],
    run = {
        ['~>1us;0~>A;~>1us;0~>A;~>19us'] = 12,
        ['~>1us;1~>A;~>1s;0~>A;~>19us'] = 11,
        ['~>1us;1~>A ; ~>5us ; 0~>A ; ~>5us ; 1~>A ; ~>5us ; 0~>A ; ~>9us'] = 6,
    },
}

-- TIGHT LOOPS

Test { [[
loop i, 10 do
    i = 0;
end
]],
    env = 'ERR : line 2 : read-only variable',
}

Test { [[
C _ret_val, _ret_end;
_ret_val = 1;
_ret_end = 1;
event void e, f;
par do
    loop do
        par/or do
            await f;        // 8
_ret_val = _ret_val + 11;
        with
            emit e;         // 11
            await FOREVER;
        end
    end
with
    loop do
        par/or do
            emit f;         // 18
        with
            await f;        // 20
        end
_ret_val = _ret_val + 5;
        await e;            // 23
    end
end
]],
    ana = {
        isForever = true,
        n_acc = 3,
    },
    awaits = 0,
    run = 6,
}

Test { [[
C _ret_val, _ret_end;
_ret_val = 1;
_ret_end = 1;
event void e, f;
par do
    loop do
        par/or do
            emit e;     // 8
_ret_val = _ret_val + 5;
            await FOREVER;
        with
            await f;
        end
    end
with
    loop do
        await e;        // 17
_ret_val = _ret_val + 11;
        par/or do
            emit f;     // 20
        with
            await f;    // 22
        end
    end
end
]],
    ana = {
        isForever = true,
        n_acc = 2,
    },
    awaits = 0,
    run = 6
}

Test { [[
event void e, k1, k2;
C _ret_val, _ret_end;
_ret_val = 1;
_ret_end = 1;
par do
    loop do
        par/or do
            emit e;
_ret_val = _ret_val + 5;
            await FOREVER;
        with
            await k1;
        end
        emit k2;
    end
with
    loop do
        await e;
_ret_val = _ret_val + 11;
        par/or do
            emit k1;
        with
            await k2;
        end
    end
end
]],
    ana = {
        isForever = true,
        n_acc = 1,
    },
    awaits = 1,
    run = 6,
}

-- CLASSES, ORGS, ORGANISMS

Test { [[
class T with
    var int x;
do
    var int v;
end

C do
    int V = sizeof(CLS_T);
end
C _V;
return _V;
]],
    run = 12,    -- +1 trail0 (+3 align)
}

Test { [[
interface I with end

class T with
    var int x;
do
    var int v;
end

C do
    int V = sizeof(CLS_T);
end
C _V;
return _V;
]],
    run = 12,   -- +1 cls / +1 trl / +2 align
}

Test { [[
class T with
    var int a, b;
do
end

var T y;

var T x with
    x.a = 10;
end

return x.a;
]],
    run = 10,
}

Test { [[
class T with
    var int a;
do
end
var T x with
    x.a = 30;
end

return x.a;
]],
    run = 30,
}
Test { [[
class T with
    var int a, b;
do
end

var T[2] y with
    y[0].a = 10;
    y[1].a = 20;
end

var T x with
    x.a = 30;
end

return x.a + y[0].a + y[1].a;
]],
    run = 60,
}

    -- CLASSES / ORGS

Test { [[
class T with
    var int v;
do
end
return 0;
]],
    run = 0,
}

Test { [[
class T with
do
    class T1 with var int v; do end
    var int v;
end
return 0;
]],
    run = 0, -- TODO
    --props = 'ERR : line 2 : must be in top-level',
}

Test { [[
class T with
do
    class T1 with do var int v; end
    var int v;
end
return 0;
]],
    run = 0, -- TODO
    --props = 'ERR : line 2 : must be in top-level',
}

Test { [[
class T with
do
end
var T[5] a;
return 0;
]],
    run = 0,
}

Test { [[
class T with
do
end
event T a;
return 0;
]],
    env = 'ERR : line 4 : invalid declaration',
}

Test { [[
class T with
do
end
var T a = 1;
return 0;
]],
    env = 'ERR : line 4 : invalid attribution',
}

Test { [[
class T with
do
    var int a;
    var T b;
end
var T aa;
return 0;
]],
    env = 'ERR : line 4 : invalid declaration',
}

Test { [[
class T with
do
end
var T a;
return 0;
]],
    run = 0,
}

Test { [[
class T with
do
end
var T a;
a.v = 0;
return a.v;
]],
    env = 'ERR : line 5 : variable/event "v" is not declared',
}

Test { [[
class T with
    var int a;
do
end
var T aa;
aa.b = 1;
return 0;
]],
    env = 'ERR : line 6 : variable/event "b" is not declared',
}

Test { [[
class T with
do
    var int v;
end
var T a;
a.v = 5;
return a.v;
]],
    env = 'ERR : line 6 : variable/event "v" is not declared',
}

Test { [[
class T with
    var int v;
do
end
var T a;
a.v = 5;
return a.v;
]],
    run = 5,
}

Test { [[
class T with
    var int v;
do
end
do
    var T a;
    a.v = 5;
end
a.v = 5;
return a.v;
]],
    env = 'ERR : line 9 : variable/event "a" is not declared',
}

Test { [[
class T with
    var int v;
    C _f(), _t=10;   // TODO: refuse _t
do
end
return 10;
]],
    run = 10,
}

Test { [[
C _V;
C do
    int V = 1;
end

class J with
do
    _V = _V * 2;
end

class T with
do
    var J j;
    _V = _V + 1;
end

var T t1;
_V = _V*3;
var T t2;
_V = _V*3;
var T t3;
_V = _V*3;
return _V;
]],
    run = 345;
}

Test { [[
var int a=8;
do
    var int a = 1;
    this.a = this.a + a + 5;
end
return a;
]],
    env = 'ERR : line 4 : invalid access',
    --run = 14,
}

Test { [[
class T with
    var int a;
do
    this.a = 8;
    var int a = 1;
    this.a = this.a + a + 5;
end
var T t;
return t.a;
]],
    run = 14,
}

Test { [[
class T3 with
    var int v3;
do
end
class T2 with
    var T3 t3;
    var int v;
do
end
class T with
    var int v,v2;
    var T2 x;
do
end
var T a;
a.v = 5;
a.x.v = 5;
a.v2 = 10;
a.x.t3.v3 = 15;
return a . v + a.x .v + a .v2 + a.x  .  t3 . v3;
]],
    run = 35,
}

Test { [[
var int v;
class T with
    var int v;
    v = 5;
do
end
]],
    parser = 'ERR : line 3 : before `;´ : expected statement',
}

Test { [[
input void START;
var int v;
class T with
    var int v;
do
    v = 5;
end
var T a;
await START;
v = a.v;
a.v = 4;
return a.v + v;
]],
    run = 9,
}

Test { [[
input void START;
input void A,F;
var int v = 0;
class T with
    event void e, ok, go;
do
    await A;
    emit e;
    emit ok;
end
var T a;
await START;
par/or do
    loop i,3 do
        par/and do
            emit a.go;
        with
            await a.e;
            v = v + 1;
        with
            await a.ok;
        end
    end
with
    await F;
end
return v;
]],
    run = { ['~>A;~>A;~>A;~>F']=1 },
}

Test { [[
input void START;
input void A,F;
var int v;
class T with
    event void e, ok;
do
    await A;
    emit e;
    emit ok;
end
var T a;
await START;
par/or do
    loop i,3 do
        par/and do
            await a.e;
            v = v + 1;
        with
            await a.ok;
        end
    end
with
    await F;
end
return v;
]],
    run = { ['~>A;~>A;~>A;~>F']=1 },
}

Test { [[
input void START;
input void A,F;
var int v;
class T with
    event void e;
do
    loop do
        await A;
        emit e;
    end
end
await START;
var T a;
par/or do
    loop i,3 do
        await a.e;
        v = v + 1;
    end
with
    await F;
end
return v;
]],
    run = { ['~>A;~>A;~>A;~>F']=3 },
}

Test { [[
input void START;
input void A,F;
var int v;
class T with
    event void e;
do
    loop do
        await A;
        emit e;
    end
end
var T a;
await START;
loop i,3 do
    await a.e;
    v = v + 1;
end
return v;
]],
    run = { ['~>A;~>A;~>A']=3 },
}

Test { [[
input void START;
class T with
    var int v;
do
    this.v = 5;
end
do
    var T a;
    await START;
    var int v = a.v;
    a.v = 4;
    return a.v + v;
end
]],
    run = 9,
}

Test { [[
input void START;
class T with
    event void go;
    var int v;
do
    await go;
    v = 5;
end
do
    var T a;
    await START;
    par/and do
        emit a.go;      // 13
    with
        emit a.go;      // 15
    end
    var int v = a.v;
    a.v = 4;
    return a.v + v;
end
]],
    ana = {
        n_acc = 1,
    },
    run = 9,
}

Test { [[
input void START;
class T with
    event int a, go, ok;
do
    await go;
    emit a=100;
    a = 5;
    emit ok;
end
var T aa;
    par/or do
        await START;
        emit aa.go;
    with
        await aa.ok;
    end
return aa.a;
]],
    run = 5,
}

Test { [[
input void START;
class T with
    var int v;
do
    v = 5;
end
var T a;
    await START;
var int v = a.v;
a.v = 4;
return a.v + v;
]],
    run = 9,
}

Test { [[
var int ret = 0;
do
    var int a;
    do
        class T with
        do
            a = 1;
        end
        var T v;
        emit v.go;
    end
    ret = a;
end
return ret;
]],
    env = 'ERR : line 7 : variable/event "a" is not declared',
    --props = 'ERR : line 5 : must be in top-level',
}

Test { [[
do
    var int a;
    do
        class T with
        do
            a = 1;
        end
    end
end
var T v;
emit v.go;
return 0;
]],
    env = 'ERR : line 6 : variable/event "a" is not declared',
    --props = 'ERR : line 4 : must be in top-level',
}

Test { [[
var int a;
do
    do
        class T with
        do
            a = 1;
            b = 1;
        end
    end
end
var int b;
var T v;
emit v.go;
return a;
]],
    env = 'ERR : line 6 : variable/event "a" is not declared',
    --env = 'ERR : line 6 : variable/event "b" is not declared',
}

Test { [[
var int a;
var int b;
do
    do
        class T with
        do
            a = 1;
            b = 3;
        end
    end
end
do
    var int a;
end
do
    var int b;
    do
        var T v;
        emit v.go;
    end
end
return a+b;
]],
    env = 'ERR : line 7 : variable/event "a" is not declared',
    --props = 'ERR : line 5 : must be in top-level',
    --env = 'ERR : line 17 : class "T" is not declared',
}

Test { [[
var int a;
var int b;
class T with
do
    a = 1;
    b = 3;
end
do
    var int a;
end
do
    var int b;
    do
        var T v;
        emit v.go;
    end
end
return a+b;
]],
    env = 'ERR : line 5 : variable/event "a" is not declared',
    --run = 4,
}

Test { [[
class Sm with
    var int id;
do
end

class Image_media with
    var Sm sm;
do
end

var Image_media img1;
    img1.sm.id = 10;

var Image_media img2;
    img2.sm.id = 12;

var Image_media img3;
    img3.sm.id = 11;

return img1.sm.id + img2.sm.id + img3.sm.id;
]],
    run = 33;
}
Test { [[
class Sm with
    var int id;
do
end

class Image_media with
    var Sm sm;
do
    par do with with with with end
end

var Image_media img1;
    img1.sm.id = 10;

var Image_media img2;
    img2.sm.id = 12;

var Image_media img3;
    img3.sm.id = 11;

return img1.sm.id + img2.sm.id + img3.sm.id;
]],
    ana = {
        n_reachs = 1,
    },
    run = 33;
}

Test { [[
class T with
    var int v;
do
end

var T t;
    t.v = 10;
var T* p = &t;
return p:v;
]],
    run = 10,
}

Test { [[
class T with
    var int v;
do
end

var T t1, t2;
t1.v = 1;
t2.v = 2;
return t1.v+t2.v;
]],
    run = 3,
}

Test { [[
class T with
    event void go;
do
end
var T aa;
loop do
    emit aa.go;
end
]],
    ana = {
        isForever = true,
    },
    loop = true,
}

Test { [[
input void START;
class T with
    event void go, ok;
do
    await go;
    await 1s;
    emit ok;
end
var T aa;
par/and do
    await START;
    emit aa.go;
with
    await aa.ok;
end
return 10;
]],
    run = { ['~>1s']=10 },
}

Test { [[
input void START;
do
class T with
    event void go, ok;
do
    await 1s;
    emit ok;
end
end
var T aa;
par/and do
    await START;
with
    await aa.ok;
end
return 10;
]],
    run = { ['~>1s']=10 },
}

Test { [[
class T with
    var int v = await F;
do
end
]],
    parser = 'ERR : line 2 : after `v´ : expected `;´',
}

Test { [[
input void START;
input int F;
do
    class T with
        event void ok;
        var int v;
    do
        v = await F;
        emit ok;
    end
end
var T aa;
par/and do
    await START;
with
    await aa.ok;
end
return aa.v;
]],
    run = { ['10~>F']=10 },
}

Test { [[
class T with
    event void e;
do
end

input void F, START;
var int ret = 0;

var T a, b;
par/and do
    await a.e;
    ret = 2;
with
    await START;
    emit a.e;
end
return ret;
]],
    run = 2,
}

Test { [[
class T with
    event void e;
do
end

input void F, START;
var int ret = 0;

var T a, b;
par/or do
    par/and do
        await a.e;
        ret = 2;
    with
        await START;
        emit b.e;
    end
with
    await F;
    ret = 1;
end
return ret;
]],
    run = { ['~>F']=1 }
}

Test { [[
C _fprintf(), _stderr;
input void START;
input void F;
class T1 with
    event void ok;
do
    loop do
        await 1s;
        emit this.ok;
    end
end
class T with
    event void ok;
do
    var T1 a;
    par/and do
        await 1ms;
    with
        await a.ok;
    end
    await 1s;
    emit ok;
end
var int ret = 10;
par/or do
    do
        var T aa;
        par/and do
            await START;
        with
            await aa.ok;
        end
    end
    ret = ret + 1;
with
    await F;
end
await F;
return ret;
]],
    run = {
        --['~>F;~>5s;~>F'] = 10,
        ['~>1s;~>F;~>F;~>1s'] = 10,
        --['~>1s;~>F;~>1s;~>F'] = 10,
        --['~>1s;~>2s;~>F'] = 11,
    },
}

Test { [[
input void START;
input void F;
class T1 with
    event void ok;
do
    await 1s;
    emit ok;
end
class T with
    event void ok;
do
    var T1 a;
    par/and do
        await (0)ms;
    with
        await a.ok;
    end
    await 1s;
    emit ok;
end
var int ret = 10;
var T aa;
par/or do
    do
        par/and do
            await START;
        with
            await aa.ok;
        end
    end
    ret = ret + 1;
with
    await F;
end
await F;
return ret;
]],
    run = {
        ['~>F;~>5s;~>F'] = 10,
        ['~>1s;~>F;~>F;~>1s'] = 10,
        ['~>1s;~>F;~>1s;~>F'] = 10,
        ['~>1s;~>1s;~>F'] = 11,
    },
}

Test { [[
input void E,F;

class T with
do
    await E;
end
var int ret = 10;
par/or do
    var T aa;
    await FOREVER;
with
    await F;
    ret = 5;
end
return ret;
]],
    run = {
        ['~>F;~>E'] = 5,
        ['~>E;~>F'] = 5,
    },
}

Test { [[
input void E,F;

class T with
do
    par/or do
        await E;
    with
        await 1s;
    end
end
var int ret = 10;
par/or do
    var T aa;
    await FOREVER;
with
    await F;
    ret = 5;
end
return ret;
]],
    run = {
        ['~>F;~>1s;~>E'] = 5,
        ['~>E;~>1s;~>F'] = 5,
    },
}

Test { [[
input void START;
input void F;
C nohold _fprintf(), _stderr;
class T with
    event void ok;
do
    input void E;
    par/or do
        await 1s;
    with
        await E;
    end
_fprintf(_stderr, "1\n");
    await 1s;
    emit ok;
end
var int ret = 10;
par/or do
    do
        var T aa;
        await aa.ok;
    end
    ret = ret + 1;
with
_fprintf(_stderr, "oioi\n");
    await F;
_fprintf(_stderr, "zzz\n");
end
await F;
return ret;
]],
    run = {
        --['~>F;~>5s;~>F'] = 10,
        ['~>1s;~>F;~>F;~>1s'] = 10,
        --['~>1s;~>F;~>1s;~>F'] = 10,
        --['~>1s;~>1s;~>F'] = 11,
        --['~>1s;~>E;~>1s;~>F'] = 11,
    },
}

Test { [[
input void START;
input void F;
class T1 with
    event void ok;
do
    await 1s;
    emit ok;
end
class T with
    event void ok;
do
    input void E;
    par/or do
        var T1 a;
        par/and do
            await (0)ms;
        with
            await a.ok;
        end
    with
        await E;
    end
    await 1s;
    emit ok;
end
var int ret = 10;
par/or do
    do
        var T aa;
            await aa.ok;
    end
    ret = ret + 1;
with
    await F;
end
await F;
return ret;
]],
    run = {
        ['~>F;~>5s;~>F'] = 10,
        ['~>1s;~>F;~>F;~>1s'] = 10,
        ['~>1s;~>F;~>1s;~>F'] = 10,
        ['~>1s;~>1s;~>F'] = 11,
        ['~>1s;~>E;~>1s;~>F'] = 11,
    },
}

Test { [[
input void START;
input void F;
class T with
    event void ok;
do
    await 1s;
    emit ok;
end
var T aa;
var int ret = 10;
par/or do
    par/and do
        await START;
    with
        await aa.ok;
    end
    ret = ret + 1;
with
    await F;
end
await F;
return ret;
]],
    run = {
        ['~>1s;~>F'] = 11,
        ['~>F;~>1s;~>F'] = 10,
    },
}

Test { [[
input void START;
input void F;
class T with
    event void ok;
do
    loop do
        await 1s;
        emit this.ok;
    end
end
var T aa;
var int ret = 0;
par/or do
    loop do
        par/and do
            await (0)ms;
        with
            await aa.ok;
        end
        ret = ret + 1;
    end
with
    await F;
end
return ret;
]],
    run = { ['~>5s;~>F'] = 5 },
}

Test { [[
input void A;
class T with
    var int v;
    event void ok;
do
    v = 0;
    loop do
        await A;
        v = v + 1;
    end
end
var T aa;
par do
    await aa.ok;
with
    await A;
    if aa.v == 3 then
        return aa.v;
    end
end
]],
    ana = {
        n_acc = 1,
        n_reachs = 1,
    },
}

Test { [[
input void START;
input void A;
class T with
    event int a, ok;
do
    par/or do
        await A;
        emit a=10;
        this.a = 5;
    with
        await a;
        a = 7;
    end
    emit ok;
end
var T aa;
par/and do
    await START;
with
    await aa.ok;
end
return aa.a;
]],
    run = { ['~>A']=7 },
}

Test { [[
input void START;
class T with
    event int a;
do
    par/and do
        emit this.a=10;
        a = 5;
    with
        await a;
        a = 7;
    end
end
var T aa;
await START;
return aa.a;
]],
    run = 5,
}

Test { [[
input void A,B;
var int a = 0;
do
    var u8 a = 1;
end
par/and do
    await A;
    a = a + 1;
with
    await B;
    a = a + 1;
end
return a;
]],
    run = { ['~>B;~>A']=2 },
}

Test { [[
class T with do end
var T a;
var T* p = a;
]],
    env = 'ERR : line 3 : invalid attribution',
}

Test { [[
C _c, _d;
C do
    int c, d;
end

class T with
    var int a;
do
end

var int i;
i = 10;
var int* pi = &i;

var T t;
t.a = 10;
var T* p = &t;
_c = t.a;
_d = p:a;
return p:a + t.a + _c + _d;
]],
    run = 40,
}

Test { [[
input void START;
class T with
    event void ok, go;
    var int v, going;
do
    await go;
    going = 1;
    v = 10;
    emit ok;
end
var T a;
var T* ptr;
ptr = &a;
par/or do
    await START;
    emit a.go;
    if ptr:going then
        await FOREVER;
    end
with
    await ptr:ok;
end
return ptr:v + a.v;
]],
    run = 20,
}

Test { [[
input void F, B;

var s16 x = 10;

par/or do
    loop do
        par/or do
            loop do
                await 10ms;
                x = x + 1;
            end
        with
            await B;
        end
        par/or do
            loop do
                await 10ms;
                x = x - 1;
            end
        with
            await B;
        end
    end
with
    await F;
with
    async do
        emit B;
        emit 10ms;
        emit F;
    end
end
return x;
]],
    run = 9,
}

Test { [[
C _assert();
input int  BUTTON;
input void F;

class Rect with
    var s16 x;
    var s16 y;
    event int go;
do
    loop do
        par/or do
            loop do
                await 10ms;
                x = x + 1;
//C _stderr, _fprintf();
//_fprintf(_stderr, "this=%p, &this.x=%p\n", this, &this.x);
            end
        with
            await go;
        end
        par/or do
            loop do
                await 10ms;
                y = y + 1;
            end
        with
            await go;
        end
        par/or do
            loop do
                await 10ms;
                x = x - 1;
            end
        with
            await go;
        end
        par/or do
            loop do
                await 10ms;
                y = y - 1;
            end
        with
            await go;
        end
    end
end

var Rect[2] rs;
rs[0].x = 10;
rs[0].y = 50;
rs[1].x = 100;
rs[1].y = 300;

//C _stderr, _fprintf();
//_fprintf(_stderr, "&rs[0]=%p, &rs[0].x=%p\n", &rs[0], &rs[0].x);
//_fprintf(_stderr, "&rs[1]=%p, &rs[1].x=%p\n", &rs[1], &rs[1].x);

par/or do
    loop do
        var int i = await BUTTON;
        emit rs[i].go;
    end
with
    await F;
with
    async do
        emit 100ms;
    end
    _assert(rs[1].x==110);
    _assert(rs[0].x==20 and rs[0].y==50 and rs[1].x==110 and rs[1].y==300);

    async do
        emit BUTTON(0);
        emit 100ms;
    end
    _assert(rs[0].x==20 and rs[0].y==60 and rs[1].x==120 and rs[1].y==300);

    async do
        emit BUTTON(1);
        emit 100ms;
    end
    _assert(rs[0].x==20 and rs[0].y==70 and rs[1].x==120 and rs[1].y==310);

    async do
        emit BUTTON(1);
        emit 100ms;
    end
    _assert(rs[0].x==20 and rs[0].y==80 and rs[1].x==110 and rs[1].y==310);

    async do
        emit BUTTON(1);
        emit 99ms;
    end
    _assert(rs[0].x==20 and rs[0].y==89 and rs[1].x==110 and rs[1].y==301);

    async do
        emit BUTTON(0);
        emit 1ms;
    end
    _assert(rs[0].x==20 and rs[0].y==89 and rs[1].x==110 and rs[1].y==300);

    async do
        emit 18ms;
    end
    _assert(rs[0].x==19 and rs[0].y==89 and rs[1].x==110 and rs[1].y==299);

    async do
        emit BUTTON(0);
        emit BUTTON(1);
        emit 1s;
    end
    _assert(rs[0].x==19 and rs[0].y==-11 and rs[1].x==210 and rs[1].y==299);

end
return 100;
]],
    awaits = 0,
    run = 100,
}

Test { [[
input void START;
class T with
    event int e, ok, go;
do
    await this.go;
    if e == 1 then
        emit this.e;
    end
    await (0)ms;
    emit ok;
end
var T a1, a2;
var int ret = 0;
await START;
par/or do
    par/and do
        a1.e = 1;
        emit a1.go;
        await a1.ok;
        ret = 1;
    with
        a2.e = 2;
        emit a2.go;
        await a2.ok;
        ret = 1;
    end
with
    await a2.e;
    ret = 100;
end
return ret;
]],
    run = { ['~>1s']=1 },
}

Test { [[
class T with
    event int a, go, ok;
do
    par/or do
        emit a=10;
        a = 5;
    with
        await this.a;
        a = 7;
    end
end
var T aa;
par/or do
    par/and do
        emit aa.go;
    with
        await aa.ok;
    end
with
end
return aa.a;
]],
    run = 5,
}

Test { [[
class T with
    event int a, ok, go;
do
    emit a=10;
    a = 5;
end
var T aa;
par/or do
    par/and do
        emit aa.go;
    with
        await aa.ok;
    end
with
end
return aa.a;
]],
    run = 5,
}

Test { [[
    input void START;
class T with
    event int a, ok, go, b;
do
    par/and do
        await a;
        emit b;
    with
        await b;
    end
    a = 5;
    b = 4;
    emit ok;
end
var T aa;

var int ret;
par/or do
        await aa.ok;
    ret = 1;
with
        await START;
    emit aa.a;
    ret = 2;
end
return ret + aa.a + aa.b;
]],
    run = 10,
}

Test { [[
C nohold _f();
input void START;
class T with
    event int e, ok, go, b;
    var u8 a;
do
    await go;
    a = 1;
    emit ok;
end
var T a, b;
C do
    int f (char* a, char* b) {
        return *a + *b;
    }
end
par/and do
    await START;
    emit a.go;
with
    await a.ok;
with
    await START;
    emit b.go;
with
    await b.ok;
end
return _f(&a.a,&b.a);
]],
    run = 2,
}

Test { [[
input void START,B;
class T with
    event int ok, go, b;
    event void e, f;
    var int v;
do
    v = 10;
    await e;
    emit f;
    v = 100;
    emit ok;
end
var T a;
var T* ptr;
ptr = &a;
var int ret = 0;
par/and do
    par/and do
        await START;
        emit ptr:go;
    with
        await ptr:ok;
    end
    ret = ret + 1;
with
        await B;
    emit ptr:e;
    ret = ret + 1;
with
    await ptr:f;
    ret = ret + 1;
end
return ret + ptr:v + a.v;
]],
    run = { ['~>B']=203, }
}

Test { [[
input void START, B;
class T with
    var int v;
    event int ok, go, b;
    event void e, f;
do
    await go;
    v = 10;
    await e;
    emit f;
    v = 100;
    emit ok;
end
var T[2] ts;
var int ret = 0;
par/and do
    par/and do
        await START;
        emit ts[0].go;
    with
        await ts[0].ok;
    end
    ret = ret + 1;
with
    par/and do
        await START;
        emit ts[1].go;
    with
        await ts[1].ok;
    end
    ret = ret + 1;
with
    await B;
    emit ts[0].e;
    ret = ret + 1;
with
    await ts[0].f;
    ret = ret + 1;
with
    await B;
    emit ts[1].e;
    ret = ret + 1;
with
    await ts[1].f;
    ret = ret + 1;
end
return ret + ts[0].v + ts[1].v;
]],
    run = { ['~>B']=206, }
}

Test { [[
input int S,F;
class T with
    event int a,ok;
do
    par/or do
        a = await S;
        emit this.a;
    with
        await 10s;
        await a;
        a = 7;
    end
    emit ok;
end
var T aa;
await aa.ok;
await F;
return aa.a;
]],
    run = {
        ['11~>S;~>10s;~>F'] = 11,
        ['~>10s;11~>S;~>F'] = 7,
    },
}

Test { [[
input void START;
class T with
    var int v;
    event void e, f, ok;
do
    v = 10;
    await e;
    await (0)s;
    emit f;
    v = 100;
    emit ok;
end
var T[2] ts;
var int ret = 0;
par/and do
    par/and do
        await ts[0].ok;
    with
        await ts[1].ok;
    end
    ret = ret + 1;
with
    await START;
    emit ts[0].e;
    ret = ret + 1;
with
    await ts[0].f;
    ret = ret + 1;
with
    await START;
    emit ts[1].e;
    ret = ret + 1;
with
    await ts[1].f;
    ret = ret + 1;
end
return ret + ts[0].v + ts[1].v;
]],
    run = { ['~>1s']=205, }
}

Test { [[
input void START;
class T with
    var int v;
do
    v = 1;
end
var T a, b;
await START;
return a.v + b.v;
]],
    run = 2,
}

Test { [[
input void START;
input void F;
class T1 with
    event void ok;
do
    await 1s;
    emit ok;
end
class T with
    event void ok;
do
    var T1 a;
    await a.ok;
    await 1s;
    emit ok;
end
var int ret = 10;
await START;
par/or do
    do
        var T aa;
        await aa.ok;
    end
    ret = ret + 1;
with
    await F;
end
await F;
return ret;
]],
    run = {
        ['~>F;~>5s;~>F'] = 10,
        ['~>1s;~>F;~>F;~>1s'] = 10,
        ['~>1s;~>F;~>1s;~>F'] = 10,
        ['~>1s;~>1s;~>F'] = 11,
    },
}

Test { [[
C _V;
C do
    static int V = 0;
end
input void F;
class T with
    // nothing
do
    do
        finalize with
            _V = 100;
        end
        await F;
    end
end
do
    var T t;
end
return _V;
]],
    run = 100,
}

Test { [[
C _V;
C do
    static int V = 1;
end
input void F;
class T with
do
    _V = 10;
    do
        finalize with
            _V = _V + 100;
        end
        await F;
    end
end
par/or do
    var T t;
    await F;
with
    // nothing;
end
return _V;
]],
    run = 110,      -- TODO: stack change
}

Test { [[
C _V;
C do
    static int V = 0;
end
input void START;
class T with
    // nothing
do
    do
        finalize with
            _V = 100;
        end
        await START;
    end
end
par/or do
    var T t;
    await START;
with
    await START;
end
return _V;
]],
    run = 100,
}

Test { [[
C _V;
input void A, F, START;
C do
    int V = 0;
end
class T with
    event void e, ok;
    var int v;
do
    finalize with
        _V = _V + 1;        // * writes after
    end
    v = 1;
    await A;
    v = v + 3;
    emit e;
    emit ok;
end
var T t;
await START;
par/or do
    do
        finalize with
            _V = _V*10;
        end
        await t.ok;
    end
with
    await t.e;
    t.v = t.v * 3;
with
    await F;
    t.v = t.v * 5;
end
return t.v + _V;        // * reads before
]],
    run = {
        ['~>F'] = 5,
        ['~>A'] = 12,
    }
}

Test { [[
C _V;
input void A, F, START;
C do
    int V = 0;
end
class T with
    event void e, ok;
    var int v;
do
    finalize with
        _V = _V + 1;        // * writes before
    end
    v = 1;
    await A;
    v = v + 3;
    emit e;
    emit ok;
end
await START;
var int ret;
do
    var T t;
    par/or do
        do
            finalize with
                _V = _V*10;
            end
            await t.ok;
        end
    with
        await t.e;
        t.v = t.v * 3;
    with
        await F;
        t.v = t.v * 5;
    end
    ret = t.v;
end
return ret + _V;        // * reads after
]],
    run = {
        ['~>F'] = 6,
        ['~>A'] = 13,
    }
}

Test { [[
class T with do end
do
var T* t;
t = new T;
end
return 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T* t;
t = new T;
return 10;
]],
    run = 10,
}

Test { [[
class T with
do
    par/or do
        await 10s;
    with
        await 10s;
    with
        await 10s;
    end
end
var T* t;
do
    t = new T;
    t = new T;
    t = new T;
end
return 10;
]],
    run = 10;
}

Test { [[
new i;
]],
    parser = 'ERR : line 1 : after `<BOF>´ : expected statement',
}
Test { [[
_f(new T);
]],
    parser = 'ERR : line 1 : after `(´ : expected `)´',
}

Test { [[
class T with do end
var T* a;
a = new U;
]],
    env = 'ERR : line 3 : class "U" is not declared'
}

Test { [[
class T with do end
do
    var T* t;
    t = new T;
end
return 10;
]],
    run = 10,
}

Test { [[
class T with
    var int* a1;
do
    var int* a2;
    a1 = a2;
end
return 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T* a = null;
free a;
return 10;
]],
    run = 10,
}

-- TODO: tests for `free´:
-- remove from tracks
-- invalid pointers
Test { [[
class T with do end
var T a;
free a;
return 0;
]],
    env = 'ERR : line 3 : invalid `free´',
}

Test { [[
var int* b;
var int* a := b;
return a;
]],
    env = 'ERR : line 2 : invalid attribution',
}

Test { [[
class T with do end;
var T a;
var T* b;
b := &a;
]],
    env = 'ERR : line 4 : invalid attribution',
}

Test { [[
class T with do end;
var T* a = new T;
var T* b;
b := a;
return 10;
]],
    run = 10;
}

Test { [[
class T with
    var int v;
do
end

var T* a;
do
    var T* b = new T;
    b:v = 10;
    a = b;
end
return a:v;
]],
    env = 'ERR : line 10 : attribution requires `finalize´',
}

Test { [[
class T with
    var int v;
do
end

var T* a;
var T aa;
do
    var T* b = new T;
    b:v = 10;
    finalize
        a = b;
    with
        do
            aa.v = b:v;
            a = &aa;
        end
    end
end
return a:v;
]],
    todo = 'free runs after block fin (correct leak!)',
    run = 10,
}

Test { [[
C _V;
C do
    int V = 0;
end
class T with
    var int v;
do
    finalize with
        _V = 10;
    end
    await FOREVER;
end

var T* a;
var T aa;
do
    var T* b = new T;
    b:v = 10;
    finalize
        a = b;
    with
        nothing;
    end
end
return _V;
]],
    run = 10,
}

Test { [[
C _V;
C do
    int V = 5;
end
class T with
    var int v;
do
    finalize with
        _V = 10;
    end
    await FOREVER;
end

var T* a;
do
    var T* b = new T;
    b:v = 10;
    a := b;
end
return _V;
]],
    run = 5,
}
Test { [[
class T with
    var int* i1;
do
    var int i2;
    i1 = &i2;
end
var T a;
return 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T* t1;
do
do
    var T t2;
    t1 = &t2;
end
end
return 10;
]],
    env = 'ERR : line 6 : attribution requires `finalize´',
}

Test { [[
class T with do end
var T* t1;
do
do
    var T t2;
    finalize
        t1 = &t2;
    with
        nothing;
    end
end
end
return 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T* t;
do
    t = new T;
end
return 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T* a = new T;
return 10;
]],
    run = 10,
}

Test { [[
class T with do end
class U with do end
var T* a;
a = new U;
]],
    env = 'ERR : line 4 : invalid attribution',
}

Test { [[
C _V;
input void START;
C do
    int V = 0;
end

class T with
    var int a;
do
    finalize with
        _V = 1;
    end
    a = 10;
end

var int ret = 0;

do
    var T* o;
    o = new T;
    await START;
    ret = o:a;
end

return ret + _V;
]],
    run = 11,
}

Test { [[
input void START, F;
C _V;
C do
    int V = 0;
end

class T with
    var int a;
do
    finalize with
        _V = 1;
    end
    a = 10;
    await 1s;
end

var int ret = 0;

par/or do
    var T* o;
    o = new T;
    await START;
    ret = o:a;
with
    await F;
end

return ret + _V;
]],
    run = { ['~>F']=11 },
}

Test { [[
input void START, F;
C _V;
C do
    int V = 0;
end

class T with
    var int a;
do
    finalize with
        _V = 1;
    end
    a = 10;
    await 1s;
end

var int ret = 0;

var T* o;
par/or do
    o = new T;
    await START;
    ret = o:a;
with
    await F;
end

return ret + _V;    // V still 0
]],
    run = { ['~>F']=10 },
}

Test { [[
class V with
do
end

var V* v;
v = new V;
await 1s;

return 10;
]],
    run = { ['~>1s']=10, }
}

Test { [[
C _f(), _V;
C do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int* v;
    finalize
        v = _f();
    with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V* v;
do
    var V* vv = new V;
    await FOREVER;
end

class T with
    var U u;
do
    u.v = new V;
    await FOREVER;
end

var T t;
return _V;
]],
    run = 1,
}

Test { [[
C _f(), _V;
C do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int* v;
    finalize
        v = _f();
    with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V* v;
do
    var V* vv = new V;
    await FOREVER;
end

class T with
    var U u;
do
    u.v = new V;
    await FOREVER;
end

var T t;
do
    var V* v := t.u.v;
end

return _V;
]],
    run = 2,
}

Test { [[
C _f(), _V;
C do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int* v;
    finalize
        v = _f();
    with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V* v;
do
    var V* vv = new V;
    await FOREVER;
end

class T with
    var U u;
do
    u.v = new V;
    await FOREVER;
end

var T t;
do
    var U u;
    u.v := t.u.v;
end

return _V;
]],
    run = 3,
}

Test { [[
class V with
do
end

class T with
    var V* v;
do
    await 1s;
    v = new V;
end

var T t;
await 1s;
return 1;

]],
    run = { ['~>1s']=1, }
}

Test { [[
C _V, _assert();
C do
    int V = 1;
end

class V with
do
    _V = 20;
    _V = 10;
end

class U with
    var V* v;
do
end

class T with
    var U* u;
do
    await 1s;
    u:v = new V;
end

do
    var U u;
    do
        var T t;
        t.u = &u;
        await 1s;
    end
    _assert(_V == 10);
end
_assert(_V == 10);
return _V;
]],
    run = { ['~>1s']=10, }       -- TODO: stack change
}

Test { [[
C _assert();
C _V;
C do
    int V = 10;
end
class T with
do
    finalize with
        _V = _V - 1;
    end
    await 500ms;
    _V = _V - 1;
end

do
    var T* a;
    a = new T;
    free a;
    _assert(_V == 9);
    await 1s;
end

return _V;
]],
    run = { ['~>1s']=9 },
}

Test { [[
C _assert();
C _X, _Y;
C do
    int X = 0;
    int Y = 0;
end

class T with
do
    finalize with
        _Y = _Y + 1;
    end
    _X = _X + 1;
    await FOREVER;
end

do
    var T* ptr = null;
    loop i, 100 do
        if ptr != null then
            free ptr;
        end
        ptr = new T;
    end
    _assert(_X == 100 and _Y == 99);
end

_assert(_X == 100 and _Y == 100);
return 10;
]],
    loop = true,
    run = 10,
}

-- TODO: mem out e mem ever
--[=[
Test { [[
var void* ptr;
class T with
do
end
loop i, 100000 do
    ptr = new T;
end
return 10;
]],
    loop = true,
    run = 10;
}
]=]

Test { [[
C _V, _assert();
C do
    int V = 0;
end
class T with
    var int v;
do
    finalize with
        do
            loop i, 0 do
                do break; end
            end
            _V = _V + this.v;
        end
    end
    await FOREVER;
end
do
    var T* p;
    p = new T;
    p:v = 1;
    p = new T;
    p:v = 1;
    p = new T;
    p:v = 1;
end
_assert(_V == 3);
return _V;
]],
    run = 3,
}

Test { [[
class T with
do
end
var T* t;
t = new T;
return t.v;
]],
    env = 'ERR : line 6 : not a struct',
}

Test { [[
class T with
    var int v;
do
end

var T*[10] ts;
var T* t;
t = new T;
t:v = 10;
ts[0] = t;
return t:v + ts[0]:v;
]],
    run = 20,
}

Test { [[
input void A,X, START;
event int a=0;
var int ret = 0;

class T with
    event void v, ok, go;
do
    await A;
    emit v;
    emit ok;
end

par/or do
    pause/if a do
        var T[2] ts;
        par/or do
            par/and do
                await ts[0].ok;
            with
                await ts[1].ok;
            end
        with
            par do
                await ts[0].v;
                ret = ret + 1;
            with
                await ts[1].v;
                ret = ret + 1;
            end
        end
    end
with
    await START;
    emit a=1;
    await X;
    emit a=0;
    ret = 10;
    await FOREVER;
end
return ret;
]],
    run = { ['~>A; ~>X; ~>A']=12 }
}

--[=[
-- todo pause hierarquico dentro de um org
Test { [[
input int SDL_KEYDOWN;
input int SDL_MOUSEBUTTONDOWN;

class Global with
    int rects_n;
do
    rects_n = 0;
end
Global glb;

class Rect with
    Global* glb;
    int v;
    event int pse;
do
    pse = 0;
    glb:rects_n = glb:rects_n + 1;

    par/or do
        pause/if pse do
            loop do
                await 20ms;
                this.v = v + 1;
                if v > 500 then
                    break;
                end
            end
        end
    with
        loop do
            int but = await CLICK;
            if but == this.v then
                emit pse=not pse;
            end
        end
    end
finally
    glb:rects_n = glb:rects_n - 1;
end

event int pse_all = 0;

par/or do
    loop do
        par/or do
            pause/if pse_all do
                Rect* r;
                loop do
                    int pos = await CREATE;
                    if glb.rects_n<10 then
                        r = new Rect;
                        r:glb = &glb;
                        r:v = pos;
                    end
                end
            end
        with
            loop do
                _SDL_KeyboardEvent* key = await SDL_KEYDOWN;
                if key:keysym.sym == _SDLK_ESCAPE then
                    break;
                end
            end
        end
    end
with
    loop do
        _SDL_KeyboardEvent* key = await SDL_KEYDOWN;
        if key:keysym.sym == _SDLK_p then
            emit pse_all = not pse_all;
_printf("PSE %d\n", pse_all);
        end
    end
with
    loop do
        await SDL_DT;

        _SDL_SetRenderDrawColor(ren, 0, 0, 0, 0);
        _SDL_RenderClear(ren);

        loop i, glb.rects_n do
            Rect* r = glb.rects[i];
            _SDL_SetRenderDrawColor(ren, 0, 255, 0, 0);
            if r:pse then
                _SDL_RenderDrawRect(ren, &r:rect);
            else
                _SDL_RenderFillRect(ren, &r:rect);
            end
        end

        _SDL_RenderPresent(ren);
    end
with
    loop do
        int i = 0;
        int t;
        par/or do
            t = await 1s;
        with
            loop do
                await SDL_DT;
                i = i + 1;
            end
        end
        //_printf("FPS: %d (%d)\n", i, t/1000);
    end
with
    await SDL_QUIT;
end

_SDL_DestroyRenderer(ren);
_SDL_DestroyWindow(win);
_SDL_Quit();

C do
    int contains (SDL_Rect* r, s16 x, s16 y) {
        return (x >= r->x) and (x <= r->x+r->w)
            and (y >= r->y) and (y <= r->y+r->h);
    }
end

return 0;
]]
}
]=]

-- INTERFACES / IFACES / IFCES

Test { [[
C _ptr;
C do
    void* ptr;
end
interface I with
    event void e;
end
var J* i = _ptr;
return 10;
]],
    env = 'ERR : line 8 : undeclared type `J´',
}

Test { [[
C _ptr;
C do
    void* ptr;
end
interface I with
    event void e;
end
var I* i = _ptr;
return 10;
]],
    run = 10;
}

Test { [[
C _ptr;
C do
    void* ptr;
end
interface I with
    event int e;
end
var I* i = <I*> _ptr;
return 10;
]],
    run = 10;
}

-- CAST

Test { [[
C _assert();

interface T with
end

class T1 with
do
end

class T2 with
do
end

var T1 t1;
var T2 t2;
var T* t;

t = &t1;
var T1* x1 = <T1*> t;
_assert(x1 != null);

t = &t1;
var T2* x2 = <T2*> t;
_assert(x2 == null);

return 10;
]],
    run = 10;
}

Test { [[
input void START;

interface I with
    event int e;
end

class T with
    event int e;
do
    await e;
    e = 100;
end

var T t;
var I* i = &t;

await START;
emit i:e;
return i:e;
]],
    run = 100,
}

Test { [[
input void START;

interface I with
    event int e, f;
end

class T with
    event int e, f;
do
    var int v = await e;
    emit f=v;
end

var T t1, t2;
var I* i1 = &t1;
var I* i2 = &t2;

var int ret = 0;
par/and do
    await START;
    emit i1:e=7;
with
    var int v = await i1:f;
    ret = ret + v;
with
    await START;
    emit i2:e=6;
with
    var int v = await i2:f;
    ret = ret + v;
end
return ret;
]],
    run = 13,
}

Test { [[
interface I with
    event int a;
end
return 10;
]],
    run = 10;
}

Test { [[
interface I with
end
var I[10] a;
]],
    env = 'ERR : line 3 : cannot instantiate an interface',
}

Test { [[
input void START;
interface Global with
    event int a?;
end
event int a?;
class U with
    event int a?;
do
end
class T with
    event int a?;
    var Global* g;
do
    await START;
    emit g:a? = 10;
end
var U u;
var Global* g = &u;
var T t;
t.g = &u;
var int v = await g:a?;
return v;
]],
    run = 10,
}

Test { [[
interface I with
end

interface Global with
    var I* t;
end

class T with
do
    global:t = &this;
end

var I* t;

return 1;
]],
    env = 'ERR : line 10 : attribution requires `finalize´'
}

Test { [[
interface Global with
    var int* a;
end
var int* a;
var int* b;
b = global:a;
do
    var int* c;
    c = global:a;
end
return 1;
]],
    run = 1,
}
Test { [[
interface Global with
    var int* a;
end
var int* a;
var int* b;
global:a = b;       // don't use global
do
    var int* c;
    global:a = c;
end
return 1;
]],
    env = 'ERR : line 6 : attribution requires `finalize´',
}
Test { [[
interface Global with
    var int* a;
end
class T with
do
    var int* b;
    b = global:a;
end
var int* a;
return 1;
]],
    run = 1,
}
Test { [[
interface Global with
    var int* a;
end
class T with
do
    var int* b;
    global:a = b;
end
var int* a;
return 1;
]],
    env = 'ERR : line 7 : attribution requires `finalize´'
}

Test { [[
input void START;
interface Global with
    event int a;
end
event int a;
class T with
    event int a;
do
    await START;
    emit global:a = 10;
end
var T t;
var int v = await a;
return v;
]],
    run = 10,
}
Test { [[
input void START;
interface Global with
    event int a;
end
event int a;
class T with
    event int a;
do
    a = await global:a;
end
var T t;
await START;
emit a = 10;
return t.a;
]],
    run = 10,
}

Test { [[
interface I with
    var int v;
    C _f(), _a;      // TODO: refuse _a
end
return 10;
]],
    run = 10,
}

Test { [[
C do
    void CLS_T__f (void* org, int v) {
        CLS_T_v(org) += v;
    }
    void IFC_I__f (void* org, int v) {
        IFC_I_v(org) += v;
    }
end

interface I with
    var int v;
    C nohold _f();
end

class T with
    var int v;
    C nohold _f();
do
    v = 50;
    this._f(10);
end

var T t;
var I* i = &t;
i:_f(100);
return i:v;
]],
    run = 160,
}

Test { [[
class T with
    var int a;
do
    a = global:a;
end
var int a = 10;
var T t;
t.a = t.a + a;
return t.a;
]],
    env = 'ERR : line 4 : interface "Global" is not defined',
}

Test { [[
interface Global with
    var int a;
end
class T with
    var int a;
do
    a = global:a;
end
do
    var int a = 10;
    var T t;
    t.a = t.a + a;
    return t.a;
end
]],
    env = 'ERR : line 1 : interface "Global" must be implemented by class "Main"',
}

Test { [[
interface Global with
    var int a;
end
class T with
    var int a;
do
    a = global:a;
end
var int a = 10;
do
    var T t;
    t.a = t.a + a;
    return t.a;
end
]],
    run = 20,
}

Test { [[
C nohold _attr();
C do
    void attr (void* org) {
        IFC_Global_a(GLOBAL) = CLS_T_a(org) + 1;
    }
end

interface Global with
    var int a;
end
class T with
    var int a;
do
    a = global:a;
    _attr(this);
    a = a + global:a + this.a;
end
var int a = 10;
do
    var T t;
    t.a = t.a + a;
    return t.a + global:a;
end
]],
    run = 53,
}

Test { [[
interface I with
    event int a;
end
var I t;
return 10;
]],
    env = 'ERR : line 4 : cannot instantiate an interface',
}

Test { [[
interface I with
    event int a;
end
var I[10] t;
return 10;
]],
    env = 'ERR : line 4 : cannot instantiate an interface',
}

Test { [[
interface I with
    event int a;
end
var I* t;
t = new I;
return 10;
]],
    env = 'ERR : line 5 : cannot instantiate an interface',
}

Test { [[
class T with
do
end

interface I with
    event int a;
end

var I* i;
var T t;
i = &t;
return 10;
]],
    env = 'ERR : line 11 : invalid attribution',
}

Test { [[
class T with
    event void a;
do
end

interface I with
    event int a;
end

var I* i;
var T t;
i = &t;
return 10;
]],
    env = 'ERR : line 12 : invalid attribution',
}

Test { [[
class T with
    event int a;
do
end

interface I with
    event int a;
end

var I* i;
var T t;
i = t;
return 10;
]],
    env = 'ERR : line 12 : invalid attribution',
}

Test { [[
class T with
    event int a;
do
end

interface I with
    event int a;
end

var I* i;
var T t;
i = &t;
return 10;
]],
    run = 10;
}

Test { [[
class T with
    event int a;
do
end

interface I with
    event int a;
end
interface J with
    event int a;
end

var I* i;
var T t;
i = &t;
var J* j = i;
return 10;
]],
    run = 10;
}

Test { [[
class T with
    event int a;
do
end

interface I with
    event int a;
end
interface J with
    event int* a;
end

var I* i;
var T t;
i = &t;
var J* j = i;
return 10;
]],
    env = 'ERR : line 16 : invalid attribution',
}

Test { [[
class T with
    var int v;
    var int* x;
    event int a;
do
    a = 10;
end

interface I with
    event int a;
end
interface J with
    event int a;
    var int v;
end

var I* i;
var T t;
i = &t;
var J* j = i;
return 0;
]],
    env = 'ERR : line 20 : invalid attribution',
}

Test { [[
input void START;
class T with
    event int a;
do
    a = 10;
end

interface I with
    event int a;
end
interface J with
    event int a;
end

var I* i;
var T t;
i = &t;
var J* j = i;
await START;
return i:a + j:a + t.a;
]],
    run = 30,
}

Test { [[
input void START;
class T with
    var int v;
    var int* x;
    event int a;
do
    a = 10;
    v = 1;
end

interface I with
    event int a;
    var int v;
end
interface J with
    event int a;
end

var I* i;
var T t;
i = &t;
var J* j = i;
await START;
return i:a + j:a + t.a + i:v + t.v;
]],
    run = 32,
}

Test { [[
class Sm with
do
end
interface Media with
    var Sm sm;
end
return 10;
]],
    run = 10;
}

Test { [[
interface I with
    var int a;
end
class T with
    interface J;
do
    a = 10;
end
var T t;
return t.a;
]],
    env = 'ERR : line 5 : class "J" is not declared',
}

Test { [[
interface I with
    var int a;
end
class T with
    interface I;
do
    a = 10;
end
var T t;
return t.a;
]],
    run = 10,
}

Test { [[
C do
    int IFC_I__ins (void* org) {
        return IFC_I_v(org);
    }
end

interface I with
    var int v;
end

class T with
    var int v;
do
end

var T t;
    t.v = 10;
var I* i = &t;
return t._ins();
]],
    env = 'ERR : line 19 : C function "CLS_T__ins" is not declared',
}
Test { [[
C do
    int IFC_I__ins (void* org) {
        return IFC_I_v(org);
    }
end

interface I with
    var int v;
end

class T with
    var int v;
do
end

var T t;
    t.v = 10;
var I* i = &t;
return i:_ins();
]],
    env = 'ERR : line 19 : C function "IFC_I__ins" is not declared',
}
Test { [[
C do
    int IFC_I__ins (void* org) {
        return IFC_I_v(org);
    }
end

interface I with
    var int v;
    C nohold _ins();
end

class T with
    var int v;
do
end

var T t;
    t.v = 10;
var I* i = &t;
return i:_ins() + t._ins();;
]],
    env = 'ERR : line 20 : C function "CLS_T__ins" is not declared',
}

Test { [[
C do
    int IFC_I__ins (void* org) {
        return IFC_I_v(org);
    }
end

C do
    int CLS_T__ins (void* org) {
        return CLS_T_v(org);
    }
end

interface I with
    var int v;
    C nohold _ins();
end

class T with
    var int v;
    C nohold _ins();
do
end

var T t;
    t.v = 10;
var I* i = &t;
return i:_ins() + t._ins();
]],
    run = 20,
}

-- RET_VAL / RET_END

Test { [[
C _ret_val, _ret_end;
class T with
do
    _ret_val = 10;
    _ret_end = 1;
end
var T a with
end;
await FOREVER;
]],
    run = 10,
}

Test { [[
input int A;
C _ret_val, _ret_end;
class T with
    var int i;
do
    loop do
        i = await A;
        _ret_val = i;
        _ret_end = 1;
    end
end
var T a;
async do
    emit A(1);
end
await FOREVER;
]],
    awaits = 1,
    run = 1,
}

Test { [[
input int A;
C _ret_val, _ret_end;
_ret_val=0;
class T with
    var int i;
do
    loop do
        i = await A;
        _ret_val = i+_ret_val;
        _ret_end = 1;
    end
end
var T[10] a;
async do
    emit A(1);
end
await FOREVER;
]],
    awaits = 1,
    run = 10,
}

Test { [[
input int A;
C _ret_val, _ret_end;
_ret_val = 10;
class T with
    event int i, x;
do
    par do
        loop do
            i = await A;
            emit i=i+1;
        end
    with
        loop do
            var int v = await x;
            emit i=v+1;
        end
    end
end
var T a,b;
par do
    loop do
        var int v = await a.i;
        emit a.x=v;
        _ret_val = _ret_val + a.i;
        _ret_end = 1;
    end
with
    loop do
        tmp int v = await b.i;
        emit b.x=v+1;
        _ret_val = _ret_val + b.i*2;
        _ret_end = 1;
    end
with
    async do
        emit A(2);
    end
    await FOREVER;
end
]],
    awaits = 2,
    run = 24,
}

Test { [[
input int A;
C _ret_val, _ret_end;
class T with
    event int i;
do
    loop do
        i = await A;
        emit i=i+1;
    end
end
var T a,b;
par do
    loop do
        var int v = await a.i;
        _ret_val = _ret_val + v;
        _ret_end = 1;
    end
with
    loop do
        var int v = await a.i;
        _ret_val = _ret_val + v;
        _ret_end = 1;
    end
with
    async do
        emit A(2);
    end
    await FOREVER;
end
]],
    awaits = 1,
    run = 6,
}

Test { [[
input void A;
C _ret_val, _ret_end;
_ret_val = 0;
loop do
    par/or do
        await A;
        _ret_val = _ret_val + 1;
        _ret_end = 1;
    with
        await A;
        _ret_val = _ret_val + 2;
    end
end
]],
    run = { ['~>A']=1 },
}

Test { [[
input void START;
event void a;
C _ret_val, _ret_end;
_ret_val = 0;
loop do
    par/or do
        await a;
        _ret_val = _ret_val + 1;
        _ret_end = 1;
    with
        await a;
        _ret_val = _ret_val + 2;
    with
        await START;
        emit a;
    end
end
]],
    run = 1,
}

Test { [[
input void A;
C _assert();
C _ret_end, _ret_val;
var int v = 1;
par do
    loop do
        await A;
        v = v + 1;
        _assert(v == 2);
    end
with
    loop do
        await A;
        v = v * 2;
        _assert(v == 4);
        _ret_val = v;
        _ret_end = 1;
    end
end
]],
    awaits = 1,
    run = { ['~>A']=4 };
}

Test { [[
input void A;
C _ret_val, _ret_end;
_ret_val = 0;
loop do
    await A;
    _ret_val = _ret_val+1;
    if _ret_val == 2 then
        _ret_end = 1;
    end
end
]],
    awaits = 1,
    run = { ['~>A; ~>A']=2 },
}

--do return end

-- GLOBAL AWAITS (deprecated)

Test { [[
input void A, B;
loop do
    if 1 then
        await B;
    end
    await A;
end
]],
    awaits = 0,
    run = false,
}

Test { [[
input void A, B;
loop do
    if 1 then
        await B;
    else
        await A;
        await A;
    end
end
]],
    awaits = 0,
    run = false,
}

Test { [[
input void A, B;
loop do
    if 1 then
        await B;
    end
end
]],
    awaits = 0,
    loop = true,
    run = false,
}

Test { [[
input void A;
await A;
loop i, 10 do
end
return 0;
]],
    awaits = 0,
    loop = true,
    run = false,
}

Test { [[
input void A;
loop do
    await A;
end
await FOREVER;
]],
    awaits = 0,     -- stmts
    run = false,
}

Test { [[
input void A;
loop do
    await A;
end
return 1;
]],
    awaits = 0,     -- stmts
    run = false,
}

Test { [[
input void A,B;
C _ret_val, _ret_end, _assert();
_ret_val = 0;
loop do
    par/or do
        loop do
            await A;
            _ret_val = _ret_val + 10;
        end
    with
        loop do
            await B;
            _assert(_ret_val == 20);
            _ret_val = 2;
            _ret_end = 1;
        end
    end
end
]],
    awaits = 2,
    run = { ['~>A;~>A; ~>B']=2 },
}

Test { [[
input void A,B;
    par do
        loop do
            await A;
        end
    with
        loop do
            await B;
        end
    end
]],
    awaits = 2,
    run = false,
}

Test { [[
input void A,B, D;
loop do
    par/or do
        loop do
            await A;
        end
        await D;
    with
        await D;
        loop do
            await B;
        end
    end
end
]],
    awaits = 0,
    run = false,
}

Test { [[
input void A,B, D;
loop do
    par/or do
        loop do
            await A;
        end
    with
        await D;
        loop do
            await A;
        end
    end
end
]],
    awaits = 1,
    run = false,
}

Test { [[
input void A, B;
class T with
    event void e;
do
    await A;
    await A;
end
var T a,b;
C _f();
var int c;
par do
    loop do
        _f();
        await A;
        if 0 then
            break;
        end
    end
with
    loop do
        await 2s;
        if _f() then
            break;
        end
    end
with
    loop do
        await B;
        c = 1;
    end
with
    loop do
        await a.e;
    end
with
    loop do
        await b.e;
    end
end
]],
    awaits = 3,
    run = false,
}
--do return end

Test { [[
input int A, B;
class T with
    event int e;
do
    await A;
    await A;
end
var T a,b;
C _f();
var int c;
par do
    loop do
        _f();
        var int x = await A;
        if 0 then
            break;
        end
    end
with
    loop do
        await 2s;
        if _f() then
            break;
        end
    end
with
    loop do
        var int x = await B;
        c = 1;
    end
with
    loop do
        var int x = await a.e;
    end
with
    loop do
        await b.e;
    end
end
]],
    awaits = 1,
    run = false,
}

Test { [[
input void A, B, D;
loop do
    par/or do
        await A;
    with
        await B;
    end
    await D;
end
]],
    awaits = 0,
    run = false,
}

Test { [[
input void A;
class T with
do
    loop do
        await A;
    end
end
par do
    loop do
        await A;
    end
with
    await FOREVER;
end
]],
    run = false,
    awaits = 1,
}

Test { [[
input void A;
class T with
do
    loop do
        await A;
    end
end
par do
    loop do
        await A;
    end
with
    var T a;
    await FOREVER;
end
]],
    run = false,
    awaits = 2,
}

--[==[
    -- MEM

--[[
0-3: $ret
]]

Test { [[
await FOREVER;
]],
    tot = 4,
    ana = {
        isForever = true,
    }
}

Test { [[
return 0;
]],
    tot = 4,
    run = 0,
}

--[[
0-18:
     0-3: $ret
    4-18: a..f
]]

Test { [[
int a, b, c;
u8 d, e, f;
return 0;
]],
    tot = 19,
    run = 0,
}

--[[
0-15:       _Root
     0-3:       $ret
    4-15:       a,b,c
     4-6:       d,e,f   // TODO: first
]]

Test { [[
do
    int a, b, c;
end
u8 d, e, f;
return 0;
]],
    tot = 19,
    run = 0,
}

--[[
0-15:       _Root
     0-4:       $ret
    4-15:       a..c
     4-6:       d..f
]]

Test { [[
do
    int a, b, c;
end
do
    u8 d, e, f;
end
return 0;
]],
    tot = 16,
    run = 0,
}

Test { [[
int ret = 0;
do
    s16 a=1, b=2, c=3;
    ret = ret + a + b + c;
    do
        s8 a=10, b=20, c=30;
        ret = ret + a + b + c;
    end
end
u8 d=4, e=5, f=6;
return ret + d + e + f;
]],
    tot = 20,
    run = 81,
}

Test { [[
int ret = 0;
par/and do
    ret = ret + 1;
with
    ret = ret + 1;
with
    ret = ret + 1;
end
par/and do
    ret = ret + 1;
with
    ret = ret + 1;
with
    ret = ret + 1;
end
return ret;
]],
    tot = 11,
    ana = {
        n_acc = 18,
    },
    run = 6,
}

Test { [[
int ret = 10;
do
    int v = -5;
    ret = ret + v;
end
par/or do
    int a = 1;
    ret = ret + a;
    par/and do
        s8 a = 10;
        ret = ret + a;
    with
        ret = ret + 1;
    with
        int b = 5;
        ret = ret + b;
    end
with
    u8 a=1, b=2, c=3;
    ret = ret + a + b + c;
end
int a = 10;
do
    int v = -5;
    ret = ret + v;
end
return ret+a;
]],
    ana = {
        n_acc = 21,
    },
    tot = 28,
    run = 33;
}

Test { [[
input void A, B, Z;
s16 ret = 0;
par do
    s16 a = 10;
    await A;
    ret = ret + a;
    a = 10;
with
    s16 a = 100;
    await B;
    ret = ret + a;
with
    s16 a = 1000;
    await Z;
    ret = ret + a;
end
]],
    ana = {
        isForever = true,
        n_reachs = 1,
    },
    tot = 21,
}

Test { [[
input void A, B, Z;
s16 ret = 0;
par/and do
    s16 a = 10;
    await A;
    ret = ret + a;
    a = 10;
with
    s16 a = 100;
    await B;
    ret = ret + a;
with
    s16 a = 1000;
    await Z;
    ret = ret + a;
end
return ret;
]],
    tot = 24,
    run = {
        ['~>A;~>B;~>Z'] = 1110,
        ['~>B;~>A;~>Z'] = 1110,
        ['~>Z;~>B;~>A'] = 1110,
    }
}
Test { [[
input void A, B, Z;
s16 ret = 0;
par do
    s16 a = 10;
    await A;
    ret = ret + a;
    a = 10;
    return ret;
with
    s16 a = 100;
    await B;
    ret = ret + a;
with
    loop do
        s16 a = 1000;
        await Z;
        ret = ret + a;
    end
end
]],
    tot = 21,
    run = {
        ['~>A;~>B;~>Z'] = 10,
        ['~>B;~>B;~>A;~>Z'] = 110,
        ['~>Z;~>B;~>Z;~>A'] = 2110,
    }
}

Test { [[
par do
    do
        do
            int a;
        end
    end

with
    int b;
end
]],
    ana = {
        isForever = true,
        n_reachs = 1,
    },
    tot = 12,
}
]==]
