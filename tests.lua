--[===[
--]===]

Test { [[return(1);]],
    simul = {
        needsPrio = false,
        needsChk  = false,
        isForever = false,
        n_tracks  = 1,
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
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
    nothing;
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
return 1;
]],
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
do do do do do do do do do do do do do do do do do do do do
    nothing;
end end end end end end end end end end end end end end end end end end end end
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
    env = 'ERR : line 4 : max depth of 127',
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
Test { [[return 0 || 10;]], run=1 }
Test { [[return 0 && 10;]], run=0 }
Test { [[return 2>1 && 10!=0;]], run=1 }
Test { [[return (1<=2) + (1<2) + 2/1 - 2%3;]], run=2 }
-- TODO: linux gcc only?
--Test { [[return (~(~0b1010 & 0XF) | 0b0011 ^ 0B0010) & 0xF;]], run=11 }
Test { [[int sizeof;]],
    parser = "ERR : line 1 : before `int´ : invalid statement (or C identifier?)",
}
Test { [[return sizeof<int>;]], run=4 }
Test { [[return 1<2>3;]], run=0 }

Test { [[int a;]],
    simul = {
        n_reachs = 1,
        isForever = true,
    }
}
Test { [[a = 1; return a;]],
    env = 'variable/event "a" is not declared',
}
Test { [[int a; call a; return a;]],
    env = 'invalid statement',
}
Test { [[int a; a = 1; return a;]],
    run = 1,
}
Test { [[int a = 1; return a;]],
    run = 1,
}
Test { [[int a = 1; return (a);]],
    run = 1,
}
Test { [[int a = 1;]],
    simul = {
        n_reachs = 1,
        isForever = true,
    }
}
Test { [[int a=1;int a=0; return a;]],
    --env = 'variable/event "a" is already declared',
    run = 0,
}
Test { [[int a=1,a=0; return a;]],
    --env = 'variable/event "a" is already declared',
    run = 0,
}
Test { [[int a; a = b = 1]],
    parser = "ERR : line 1 : after `b´ : expected `;´",
}
Test { [[int a = b; return 0;]],
    env = 'variable/event "b" is not declared',
}
Test { [[return 1;2;]],
    parser = "ERR : line 1 : after `;´ : expected EOF",
}
Test { [[call 1;return 2;]],
    env = 'invalid statement',
}
Test { [[int aAa; aAa=1; return aAa;]],
    run = 1,
}
Test { [[int a; a=1; return a;]],
    run = 1,
}
Test { [[int a; a=1; a=2; return a;]],
    run = 2,
}
Test { [[int a; a=1; return a;]],
    run = 1,
}
Test { [[int a; a=1 ; a=a; return a;]],
    run = 1,
}
Test { [[int a; a=1 ; nothing; nothing;]],
    simul = {
        n_reachs = 1,
        isForever = true,
    }
}
Test { [[int a; a=1 ; call a; return a;]],
    env = 'invalid statement',
}

    -- IF

Test { [[if 1 then return 1; end; return 0;]],
    simul = {
        isForever = false,
        needsPrio = false,
        needsChk  = false,
        n_tracks  = 1,
    },
    run = 1,
}
Test { [[if 0 then return 0; end  return 1;]],
    run = 1,
}
Test { [[if 0 then return 0; else return 1; end]],
    simul = {
        isForever = false,
        needsPrio = false,
        needsChk  = false,
        n_tracks  = 1,
    },
    run = 1,
}
Test { [[if (0) then return 0; else return 1; end;]],
    run = 1,
}
Test { [[if (1) then return (1); end]],
    simul = {
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
int a = 1;
if a == 0 then
    return 1;
elseif a > 0 then
    return 0;
else
    return 1;
end
return 0;
]],
    run = 0,
}
Test { [[
int a = 1;
if a == 0 then
    return 0;
elseif a < 0 then
    return 0;
else
    a = a + 2;
    if a < 0 then
        return 0;
    elseif a > 1 then
        return 1;
    else
        return 0;
    end
    return 1;
end
return 0;
]],
    run = 1,
}
Test { [[if (2) then  else return 0; end;]],
    parser = "ERR : line 1 : after `then´ : invalid statement (or C identifier?)",
}

-- IF vs SEQ priority
Test { [[if 1 then int a; return 2; else return 3; end;]],
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
    simul = {
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
    simul = {
        isForever = false,
        needsPrio = false,
        needsChk  = false,
        n_tracks  = 1,
    },
    run = 2,
}
Test { [[
int a = 0;
int b = a;
if b then
    return 1;
else
    return 2;
end;
]],
    run = 2,
}
Test { [[
int a;
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
int a;
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
int a;
if 0 then
    return 1;
else
    a=1;a=2; return 3;
end;
]],
    run = 3,
}
Test { [[
int a = 0;
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
    parser = "ERR : line 2 : before `A´ : invalid statement (or C identifier?)",
}

Test { [[input  int A;]],
    simul = {
        n_reachs = 1,
        isForever = true,
    },
}
Test { [[input int A,A; return 0;]],
    env = 'event "A" is already declared',
}
Test { [[
input int A,B,C;
]],
    simul = {
        n_reachs = 1,
        isForever = true,
    },
}

Test { [[await A; return 0;]],
    env = 'event "A" is not declared',
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
    simul = {
        isForever = false,
        needsPrio = false,
        needsChk  = false,
        n_tracks  = 2,
    },
    run = 10,
}

Test { [[
input int A;
int ret;
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
int v;
par/and do
    v = await A;
with
    async do
        emit A(10);
    end;
end;
return v;
]],
    simul = {
        isForever = false,
        needsPrio = false,
        needsChk  = false,
        n_tracks  = 2,
    },
    run = 10,
}

Test { [[
input int A;
int v = await A;
return v;
]],
    run = {
        ['101~>A'] = 101,
        ['303~>A'] = 303,
    },
}

print'TODO: deveria dar erro!'
Test { [[int a = a+1; return a;]],
    --env = 'variable/event "a" is not declared',
    run = 1,
}

Test { [[int a; a = emit a(1); return a;]],
    parser = "ERR : line 1 : after `emit´ : expected event",
    --trig_wo = 1,
}

Test { [[int a; emit a(1); return a;]],
    env = 'ERR : line 1 : event "a" is not declared',
    --trig_wo = 1,
}
Test { [[event int a; emit a(1); return a;]],
    run = 1,
    --trig_wo = 1,
}

    -- OUTPUT

Test { [[
output xxx A;
return(1);
]],
    env = "ERR : line 1 : invalid event type",
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
    env = "ERR : line 1 : invalid event type",
}
Test { [[
output t A;
emit A(1);
return(1);
]],
    env = "ERR : line 1 : invalid event type",
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
_t v;
emit A(v);
return(1);
]],
    env = 'ERR : line 2 : undeclared type `_t´',
}
Test { [[
type _t = 1;
output int A;
_t v = 1;
call v();
emit A(v);
return(1);
]],
    todo = 'simul fail',
}
Test { [[
output int A;
int a;
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
type _t = 8;
output _t* A;
output int B;

_t v;
v.a = 1;
v.b = -1;
int a = emit A(&v);
int b = emit B(5);
return a + b;
]],
    run = 6,
}

Test { [[
output void A;
C do
    void A (int v) {}
end
cahr v = emit A(1);
return 0;
]],
    env = 'ERR : line 5 : undeclared type',
}
Test { [[
output void A;
C do
    void A (int v) {}
end
type _char = 1;
_char v = emit A(1);
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
    simul = {
        nd_acc = 1,
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
    simul = {
        nd_acc = 1,
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

    -- WALL-CLOCK TIME

Test { [[await 0ms; return 0;]],
    mem = 'ERR : line 1 : constant is out of range',
}
Test { [[
input void A;
await A;
return 0;
]],
    run = { ['~>10ms; ~>A'] = 0 }
}

Test { [[await -1ms; return 0;]],
    parser = "ERR : line 1 : after `await´ : expected event",
}

Test { [[await 1; return 0;]],
    parser = 'ERR : line 1 : after `1´ : expected <h,min,s,ms,us>',
}
Test { [[await -1; return 0;]],
    parser = 'ERR : line 1 : after `await´ : expected event',
}

Test { [[s32 a=await 10s; return a==8000000;]],
    simul = {
        isForever = false,
        needsPrio = false,
        needsChk  = false,
        n_tracks  = 1,
    },
    run = {
        ['~>10s'] = 0,
        ['~>9s ; ~>9s'] = 1,
    },
}

Test { [[await Forever;]],
    simul = {
        isForever = true,
        needsPrio = false,
        needsChk  = false,
        n_tracks  = 1,
    },
}
Test { [[await Forever; await Forever;]],
    parser = "ERR : line 1 : after `;´ : expected EOF",
}
Test { [[await Forever; return 0;]],
    parser = "ERR : line 1 : after `;´ : expected EOF",
}

Test { [[emit 1ms; return 0;]], props='not permitted outside `async´' }
Test { [[
int a;
a = set async do
    emit 1min;
end;
return a + 1;
]],
    todo = 'async nao termina',
    run = false,
}

Test { [[
async do
    nothing;
end
return 10;
]],
    simul = {
        isForever = false,
        needsPrio = false,
        needsChk  = false,
        n_tracks  = 1,
    },
    run = 10,
}

Test { [[
int a;
a = set async do
    emit 1min;
    return 10;
end;
return a + 1;
]],
    simul = {
        isForever = false,
        needsPrio = false,
        needsChk  = false,
        n_tracks  = 1,
    },
    run = 11,
}

Test { [[
async do
    emit 1min;
    return 10;
end
]],
    props = 'ERR : line 3 : invalid access from async',
}

-- Seq

Test { [[
input int A;
int v = await A;
return v;
]],
    run = { ['10~>A']=10 },
}
Test { [[
input int A,B;
await A;
int v = await B;
return v;
]],
    run = {
        ['3~>A ; 1~>B'] = 1,
        ['1~>B ; 2~>A ; 3~>B'] = 3,
    }
}
Test { [[
int a = await 10ms;
a = await 20ms;
return a;
]],
    run = {
        ['~>20ms ; ~>11ms'] = 1000,
        ['~>20ms ; ~>20ms'] = 10000,
    }
}
Test { [[
int a = await 10us;
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
    await Forever;
with
    await 1s;
end
return 0;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
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
    await Forever;
end
par/or do
    await Forever;
with
    await Forever;
end
return 0;
]],
    simul = {
        n_unreachs = 1,
        isForever =  true,
    },
}

Test { [[
par do
    await Forever;
with
    await 1s;
end
]],
    simul = {
        isForever = true,
    }
}

Test { [[
par do
    await Forever;
with
    await Forever;
end
]],
    simul = {
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
    simul = {
        n_reachs = 1,
        isForever = true,
    },
}

Test { [[
par do
    int v1,v2;
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
    simul = {
        isForever = false,
        needsPrio = true,
        needsChk  = true,
        n_tracks  = 3,
    },
    run = 3,
}

Test { [[
input int A;
await A;
await A;
int v = await A;
return v;
]],
    run  = {
        ['1~>A ; 2~>A ; 3~>A'] = 3,
    },
}

Test { [[
input int A,B;
int ret;
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
int v;
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
int v;
if 0 then
    v = await A;
end;
return v;
]],
    run = 0,
}

Test { [[
par/or do
    await Forever;
with
    return 1;
end
]],
    simul = {
        n_unreachs = 1,
        --nd_flw = 1,
    },
    run = 1,
}

Test { [[
input void F;
int a = 0;
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
    simul = {
        needsPrio = true,
        needsChk  = false,
        n_tracks  = 3,
        n_unreachs = 1,
        nd_acc = 1,         -- TODO: =0
    },
    run = { ['~>5s; ~>F']=42 },
}

Test { [[
int a;
loop do
    par/or do
        await 2s;
    with
        a = 1;
        await Forever;
    with
        await 1s;
        loop do
            a = 2;
            await 1s;
        end
    end
end
]],
    simul = {
        isForever = true,
        needsPrio = true,
        needsChk  = false,
        n_tracks  = 3,
        n_unreachs = 2,
        nd_acc = 1,         -- TODO: =0
    },
}

Test { [[
int a = set do
    int a = set do
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
    a = set do
        return 1;
    end;
with
    await a;
    nothing;
end;
return 0;
]],
    simul = {
        n_unreachs = 2,
        isForever = true,
    },
}

Test { [[
input void A,B;
par/or do
    await A;
    await Forever;
with
    await B;
    return 1;
end;
]],
    simul = {
        n_unreachs = 1,
    },
    run = { ['~>A;~>B']=1, },
}

Test { [[
par/and do
    nothing;
with
    return 1;
end
]],
    simul = {
        n_unreachs = 1,
    },
    run = 1,
}
Test { [[
par do
    nothing;
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
    simul = {
        n_unreachs = 1,
    },
    --nd_flw = 1,
    run = 1,
}
Test { [[
input int A;
par do
    async do nothing; end
with
    await A;
    return 1;
end
]],
    run = { ['1~>A']=1 },
}

Test { [[
par do
    async do nothing; end
with
    return 1;
end
]],
    todo = 'async dos not execute',
    simul = {
        --n_unreachs = 1,
        --nd_flw = 1,
    },
    run = 1,
}

Test { [[
par do
    await Forever;
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
    await Forever;
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
int a;
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
    simul = {
        n_unreachs = 1,
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
    simul = {
        isForever = true,
        n_unreachs = 1,
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
    simul = {
        n_unreachs = 2,  -- TODO: 0
        isForever = true,
    },
}

Test { [[
input int A,B,F;
int a;
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
    await Forever;
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
int a = set
    do
        par/or do
            par do
                int v;
                par/or do
                    int v = await 10ms;
                    return v;
                with
                    v = await A;
                end;
                return v;
            with
                int v = await B;
                return v;
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
int a = set
    do
        par/or do
            par do
                int v;
                par/or do
                    int v = await 10ms;
                    return v;
                with
                    v = await A;
                end;
                return v;
            with
                int v = await B;
                return v;
            end;
            // unreachable
            await Forever;
        with
            await F;
        end;
        return 0;
    end;
return a;
]],
    -- TODO: melhor seria: unexpected statement
    parser = "ERR : line 17 : after `;´ : expected `with´",
    --n_unreachs = 1,
    run = {
        ['1~>B; ~>20ms; 1~>F'] = 1,
        ['~>20ms; 5~>B; 2~>F'] = 10,
    }
}

-- testa BUG do ParOr que da clean em await vivo
Test { [[
input int A,B,C;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
with
    await C;
end;
return 100;
]],
    run = { ['1~>A;1~>C']=100 }
}

Test { [[
input int A;
int b;
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
    simul = {
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
    simul = {
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
    simul = {
        n_unreachs = 4,
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
    tight = 'tight loop'
}

Test { [[
loop do
    par do
        await Forever;
    with
        break;
    end;
end;
return 1;
]],
    simul = {
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
        await Forever;
    with
        await B;
        break;
    end;
end;
return 1;
]],
    simul = {
        n_unreachs = 1,
    },
    run = { ['~>A;~>B']=1, }
}

Test { [[
loop do
    par do
        await Forever;
    with
        return 1;
    end;
end;
return 1;   // n_unreachs
]],
    simul = {
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
        await Forever;
    with
        await B;
        return 1;
    end;
end;
return 1;   // n_unreachs
]],
    simul = {
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
    props = 'break without loop',
}

Test { [[
input int A;
int v;
int a;
loop do
    a = 0;
    v = await A;
end;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
}

Test { [[
int a;
loop do a=1; end;
return a;
]],
    tight = 'tight loop',
}

Test { [[break; return 1;]], parser="ERR : line 1 : after `;´ : expected EOF" }
Test { [[break; break;]], parser="ERR : line 1 : after `;´ : expected EOF" }
Test { [[loop do break; end; return 1;]],
    simul = {
        n_unreachs=1,
    },
    run=1
}
Test { [[
int ret;
loop do
    ret = 1;
    break;
end;
return ret;
]],
    simul = {
        n_unreachs = 1,
    },
    run = 1,
}

Test { [[
int a;
loop do
    loop do
        a = 1;
    end;
end;
]],
    tight = 'tight loop'
}

Test { [[
loop do
    loop do
        break;
    end;
end;
]],
    tight = 'tight loop'
}

Test { [[
loop do
    loop do
        await Forever;
    end;
end;
]],
    simul = {
        n_unreachs = 4,
        isForever = true,
    },
}

-- EX.05
Test { [[
input int A;
loop do
    await A;
end;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
}
Test{ [[
input int E;
int a;
loop do
    a = await E;
end;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
}
Test{ [[
input int E;
loop do
    int v = await E;
    if v then
        nothing;
    else
        nothing;
    end;
end;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
}
Test { [[
int a;
loop do
    if 0 then
        a = 0;
    else
        a = 1;
    end;
end;
return a;
]],
    tight = 'tight loop'
}
Test { [[
loop do
    if 0 then
        break;
    end;
end;
return 0;
]],
    tight = 'tight loop'
}

Test { [[
par/or do
    loop do
        nothing;
    end;
with
    loop do
        nothing;
    end;
end;
return 0;
]],
    tight='tight loop'
}

Test { [[
par/and do
    loop do
        nothing;
    end;
with
    loop do
        nothing;
    end;
end;
return 0;
]],
    tight='tight loop'
}

Test { [[
event int a;
par/and do
    await a;
with
    loop do nothing; end;
end;
return 0;
]],
    tight='tight loop'
}

Test { [[
input int A;
loop do
    par/or do
        await A;
    with
        nothing;
    end;
end;
return 0;
]],
    tight='tight loop'
}
Test { [[
input int A;
int a;
a = 0;
loop do
    par/or do
        nothing;
    with
        await A;
    end;
end;
return 0;
]],
    tight='tight loop'
}

Test { [[
input int A;
if 0 then
    loop do await A; end;
else
    loop do await A; end;
end;
return 0;
]],
    simul = {
        n_unreachs = 2,
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
    simul = {
        n_unreachs = 2,
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
    int v = await F;
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
int sum = 0;
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
    simul = {
        nd_acc = 1,
        n_unreachs = 2,
    },
    run = 1,
}

Test { [[
input int A;
int sum = 0;
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
    simul = {
        nd_acc = 1,
        n_unreachs = 2,
    },
    run = 1,
}

Test { [[
input int A;
int sum = 0;
int ret = 0;
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
    simul = {
        nd_acc = 1,
    },
    run = { ['~>A; ~>A; ~>A']=2 },
}

Test { [[
input int A;
int sum = 0;
int ret = 0;
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
    simul = {
        nd_acc = 1,
    },
    run = { ['~>A;~>A'] = 2 },
}

Test { [[
input int A;
int sum = 0;
par/or do
    loop i, 1 do
        await A;
        async do
            int a = 1;
        end
    end
    sum = 0;
with
    sum = 1;
end
return sum;
]],
    simul = {
        n_unreachs = 2,
        nd_acc = 1,
    },
    run = 1,
}

Test { [[
input int A;
int sum = 0;
par/or do
    sum = 5;
    loop i, 10 do
        await A;
        async do
            int a = 1;
        end
    end
    sum = 0;
with
    loop i, 2 do
        async do
            int a = 1;
        end
        sum = sum + 1;
    end
end
return sum;
]],
    run = 7,
}

Test { [[
int sum = 0;
loop i, 100 do
    sum = sum + (i+1);
end
return sum;
]],
    run = 5050,
}
Test { [[
int sum = 0;
for i=1, 100 do
    i = 1;
    sum = sum + i;
end
return sum;
]],
    todo = 'set should raise an error',
    run = 5050,
}
Test { [[
int sum = 5050;
loop i, 100 do
    sum = sum - (i+1);
end
return sum;
]],
    run = 0,
}
Test { [[
int sum = 5050;
int v = 0;
loop i, 100 do
    v = i;
    if sum == 100 then
        break;
    end
    sum = sum - (i+1);
end
return v;
]],
    run = 99,
}
Test { [[
input void A;
int sum = 0;
int v = 0;
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
int sum = 4;
loop i, 0 do
    sum = sum - i;
end
return sum;
]],
    run = 4,
}
Test { [[
input void A, B;
int sum = 0;
loop i, 10 do
    await A;
    sum = sum + 1;
end
return sum;
]],
    run = {['~>A;~>B;~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;']=10},
}
Test { [[
input int A,B,C,D,F;
int ret;
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
input int A,B,C,D,F;
int ret;
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
            ret = await C;
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
int a = 0;
loop do
    await A;
    a = a + 1;
    break;
end;
await A;
await A;
return a;
]],
    simul = {
        n_unreachs = 1,
    },
    run = { ['0~>A;0~>A;0~>A'] = 1 }
}

Test { [[
input int F;
int a = 0;
par do
    a = a + 1;
    await Forever;
with
    await F;
    return a;
end;
]],
    simul = {
        isForever = false,
        needsPrio = false,
        needsChk  = false,
        n_tracks  = 2,
    },
    run = { ['~>1min; ~>1min ; 0~>F'] = 1 },
}

Test { [[
input int A;
int a = await A;
await A;
return a;
]],
    run = {['10~>A;20~>A']=10},
}

Test { [[
input int A;
int a = await A;
int b = await A;
return a + b;
]],
    run = { ['10~>A;20~>A']=30, ['3~>A;0~>A;0~>A']=3 }
}

-- A changes twice, but first value must be used
Test { [[
input int A,F;
int a,f;
par/and do
    a = await A;
with
    f = await F;
end;
return a+f;
]],
    run = { ['1~>A;5~>A;1~>F'] = 2 },
}

-- INTERNAL EVENTS

Test { [[
event int c;
emit c(10);
await c;
return 0;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
    --trig_wo = 1,
}

-- EX.06: 2 triggers
Test { [[
event int c;
emit c(10);
emit c(10);
return c;
]],
    run = 10,
    --trig_wo = 2,
}

Test { [[
event int a,b;
a = 1;
emit b(a);
return b;
]],
    run = 1,
    --trig_wo = 1,
}

-- ParOr

Test { [[
input int Start;
event int a = 3;
par do
    await Start;
    emit a(a);
    return a;
with
    loop do
        int v = await a;
        a = v+1;
    end;
end;
]],
    simul = {
        n_unreachs = 1,
    },
    run = 4,
}

Test { [[
int ret = 0;
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
    simul = {
        n_unreachs = 1,
    },
    run = 5,
}

Test { [[
int[2] v;
int ret;
par/or do
    ret = v[0];
with
    ret = v[1];
end;
return ret;
]],
    simul = {
        nd_acc = 1,
    },
}
Test { [[
input int A;
int a;
par/or do
    if 1 then
        a = await A;
    end;
with
    a = await A;
end;
return a;
]],
    simul = {
        nd_acc  = 1,
    },
    run = { ['10~>A']=10 },
}

Test { [[
input int A,B;
int a = set
    par do
        await A;
        if 1 then
            await B;
            // unreachable
        end;
        return 0;
    with
        int v = await A;
        return v;
    end;
return a;
]],
    simul = {
        n_unreachs = 1,
        nd_acc = 1,
        --nd_flw = 2,
    },
}

Test { [[
input int A;
int a;
a = set
    par do
        if 1 then
            int v = await A;
            return v;
        end;
        return 0;
    with
        int v = await A;
        return v;
    end;
return a;
]],
    simul = {
        nd_acc = 1,
    --nd_flw = 3,
    },
}

Test { [[
input int A;
int a;
a = set par do
    await A;
    if 1 then
        int v = await A;
        // unreachable
        return v;
    end;
    return 0;
with
    int v = await A;
    return v;
end;
return a;
]],
    simul = {
        n_unreachs = 1,
        nd_acc  = 1,
        --nd_flw  = 2,
    },
    run = { ['1~>A']=1 },
}

Test { [[
input int A,B;
int a,v;
a = set par do
    if 1 then
        v = await A;
    else
        await B;
        return v;
    end;
    return 0;
with
    int v = await A;
    return v;
end;
return a;
]],
    simul = {
        nd_acc = 1,
        --nd_flw = 2,
    },
}

Test { [[
input int A,B;
int a,v;
a = set par do
    if 1 then
        v = await A;
        return v;
    else
        await B;
        return v;
    end;
    return 0;
with
    int v = await A;
    return v;
end;
return a;
]],
    simul = {
        nd_acc = 1,
        --nd_flw = 2,
    },
    run = { ['1~>A']=1 },
}

Test { [[
input int A;
int a = 0;
par/or do
    if 1 then
        a = await A;
    end;
with
    if ! 1 then
        a = await A;
    end;
end;
return a;
]],
    simul = {
        nd_acc  = 1,
    },
    run = 0,
}

Test { [[
input int A;
int a, b;
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
int a,b,c,d;
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
    simul = {
        nd_acc = 2,
    },
    run = { ['0~>A;5~>B']=8 },
}

Test { [[
input int A,B;
int a,b,ret;
par/and do
    await A;
    a = 1+2+3+4;
with
    int v = await B;
    b = 100+v;
    ret = a + b;
end;
return ret;
]],
    run = { ['1~>A;10~>B']=120 },
}

Test { [[
input int A,B;
int a=0,b=0;
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
    simul = {
        nd_acc = 2,
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
    simul = {
        nd_acc = 1,
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
    simul = {
        n_unreachs = 1,
        --nd_flw = 1,
    },
    run = 1,
}
Test { [[
input int A;
par do
    int v = await A;
    return v;
with
    int v = await A;
    return v;
end;
]],
    --nd_flw = 2,
    simul = {
        nd_acc = 1,
    },
    run = { ['1~>A']=1, ['2~>A']=2 },
}

Test { [[
par do
    await Forever;
with
    return 10;
end;
]],
    run = 10,
    --nd_flw = 1,
}

Test { [[
input int A,B,C;
par do
    int v = await A;
    return v;
with
    int v = await B;
    return v;
with
    int v = await C;
    return v;
end;
]],
    run = { ['1~>A']=1, ['2~>B']=2, ['3~>C']=3 }
}
Test { [[
par/and do
    nothing;
with
    nothing;
end;
return 1;
]],
    run = 1,
}
Test { [[
par/or do
    nothing;
with
    nothing;
end;
return 1;
]],
    run = 1,
}
Test { [[
input int A,B;
par do
    await A;
    int v = await A;
    return v;
with
    int v = await B;
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
    int v = await A;
    return v;
with
    int v = await B;
    return v;
end;
]],
    run = {
        ['0~>B ; 0~>B ; 1~>A ; 3~>A'] = 3,
        ['0~>B ; 0~>B ; 1~>A ; 3~>B'] = 3,
    },
}
Test { [[
input int A,B,C;
par do
    await A;
    int v = await B;
    return v;
with
    await A;
    int v = await C;
    return v;
end;
]],
    run = {
        ['0~>B ; 0~>B ; 1~>A ; 3~>B'] = 3,
        ['0~>B ; 0~>B ; 1~>A ; 3~>C'] = 3,
    },
}
Test { [[
input int A,B,C;
await A;
par do
    int v = await B;
    return v;
with
    int v = await C;
    return v;
end;
]],
    run = {
        ['0~>B ; 0~>B ; 1~>A ; 3~>B'] = 3,
        ['0~>B ; 0~>B ; 1~>A ; 3~>C'] = 3,
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
    int a = await 10ms;
    return a;
with
    int b = await 10ms;
    return b;
end;
]],
    --nd_flw = 2,
    simul = {
        nd_acc = 1,
    },
    run = {
        ['~>10ms'] = 0,
        ['~>20ms'] = 10000,
    }
}
Test { [[
int a;
par/or do
    a = await 10ms;
with
    a = await 10ms;
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
    run = {
        ['~>10ms'] = 0,
        ['~>20ms'] = 10000,
    }
}
Test { [[
int a=0,b=0;
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
        ['~>20us'] = 2,
    }
}
Test { [[
int a=0,b=0;
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
    run = {
        ['~>20us'] = 2,
    }
}
Test { [[
int a=0,b=0;
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
    run = {
        ['~>20us'] = 2,
    }
}
Test { [[
int a=0,b=0;
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
    run = {
        ['~>20us'] = 2,
    }
}
Test { [[
int a,b;
par/or do
    a = await 10us;
with
    b = await (10)us;
end;
return a + b;
]],
    run = {
        ['~>10us'] = 0,
        ['~>20us'] = 20,
    }
}
Test { [[
int a,b;
par do
    a = await 10ms;
    return a;
with
    b = await (10000)us;
    return b;
end;
]],
    simul = {
        nd_acc = 1,
        --nd_flw = 2,
    },
}
Test { [[
int a=0,b=0;
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
int a,b;
par do
    a = await 10us;
    return a;
with
    b = await (5)us;
    await 5us;
    return b;
end;
]],
    simul = {
        nd_acc = 1,
        --nd_flw = 3,
    },
}
Test { [[
int a,b;
par do
    a = await 10us;
    return a;
with
    b = await (5)us;
    await 10us;
    return b;
end;
]],
    todo = 'await(x) pode ser 0?',  -- TIME_undef
    simul = {
        nd_acc = 1,
    },
}

Test { [[
int v;
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
    simul = {
        n_unreachs = 1,
        nd_acc = 1,
    },
}

Test { [[
int v = 1;
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
    run = 2,
    simul = {
        n_unreachs = 3,
    },
}

Test { [[
input int A;
int a;
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
int a;
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
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
}
Test { [[
input int A;
int a;
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
    simul = {
        n_unreachs = 2,
        isForever = true,
    },
}
Test { [[
input int A;
int a;
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
    simul = {
        n_unreachs = 2,
        isForever = true,
    },
}
Test { [[
int a;
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
    todo = 'segfault em simul',
    simul = {
        n_unreachs = 2,
        isForever = true,
        nd_acc = 1,
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
    simul = {
        n_unreachs = 2,
        isForever = true
    },
}
Test { [[
int a;
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
    simul = {
        n_unreachs = 1,
        nd_acc = 1,
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
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
}
Test { [[
int a;
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
    todo = 'segfault em simul',
    simul = {
        n_unreachs = 2,
        isForever = true,
        nd_acc = 1,
    },
}
Test { [[
int a;
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
    todo = 'segfault em simul',
    simul = {
        n_unreachs = 2,
        isForever = true,
        nd_acc = 1,
    },
}
Test { [[
int a,b;
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
    simul = {
        nd_acc = 1,
    },
}
Test { [[
int a,b;
par do
    a = await 10ms;
    return a;
with
    b = await (10000)us;
    return b;
end;
]],
    --nd_flw = 2,
    simul = {
        nd_acc = 1,
    },
    run = {
        ['~>10ms'] = 0,
        ['~>20ms'] = 10000,
    }
}
Test { [[
int a,b;
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
int a,b,c;
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
    simul = {
        nd_acc = 3,
        --nd_flw = 6,
    },
}
Test { [[
int a=0,b=0,c=0;
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
int a,b,c;
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
int a,b,c;
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
    simul = {
        --nd_flw = 6,
        nd_acc = 3,
    },
}
Test { [[
s32 a,b;
par do
    a = await 10min;
    return a;
with
    b = await 20min;
    return b;
end;
]],
    simul = {
        n_unreachs = 1,
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
    mem = 'ERR : line 1 : constant is out of range',
}
Test { [[
int a = 2;
par/or do
    await 10s;
with
    await 20s;
    a = 0;
end;
return a;
]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['~>10s'] = 2,
        ['~>20s'] = 2,
        ['~>30s'] = 2,
    }
}
Test { [[
int a = 2;
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
int a = 2;
par/or do
    int b = await (10)us;
    a = b;
with
    await 20ms;
    a = 0;
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
}
Test { [[
s32 v1,v2;
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
    simul = {
        nd_acc = 1,
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
    simul = {
        n_unreachs = 1,
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
    simul = {
        n_unreachs = 1,
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
    simul = {
        n_unreachs = 1,
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
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
}

Test { [[
loop do
    await 10ms;
end;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
}

Test { [[
input int F;
int a;
par do
    await 5s;
    await Forever;
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
    simul = {
        n_unreachs = 1,
    },
    run = { ['~>10s;~>F']=10 }
}

Test { [[
input int F;
do
    int a=0, b=0, c=0;
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
    simul = {
        n_unreachs = 3,
    },
    run = {
        ['~>999ms; ~>F'] = 108,
        ['~>5s; ~>F'] = 555,
        ['~>F'] = 0,
    }
}

    -- TIME LATE

Test { [[
input int F;
int late = 0;
int v;
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
    simul = {
        n_unreachs = 1,
    },
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
    int v = await A;
    return v;
with
    int v = await (1)us;
    return v;
end;
]],
    run = {
        ['~>10us'] = 9,
        ['10~>A'] = 10,
    }
}

Test { [[
int v;
par/or do
    v = await 10us;
with
    v = await (1)us;
end;
return v;
]],
    simul = {
        nd_acc = 1,
    },
    run = {
        ['~>1us'] = 0,
        ['~>20us'] = 19,
    }
}

Test { [[
input int A;
int a;
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
int a;
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
int a;
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

-- 1st to use Start
Test { [[
input int Start;
event int a;
par/and do
    await Start;
    emit a(1);
with
    await a;
end;
return 10;
]],
    run = 10,
}

Test { [[
input int A;
event int b, c;
par do
    await A;
    emit b(1);
    await c;
    return 10;
with
    await b;
    await A;
    emit c(10);
    // unreachable
    await c;
    // unreachable
    return 0;
end;
]],
    simul = {
        isForever = false,
        n_unreachs = 2,
        --nd_esc = 1,
    },
    run = {
        ['0~>A ; 0~>A'] = 10,
    }
}

Test { [[
input int A;
int a = 1;
loop do
    par/or do
        a = await A;
    with
        a = await A;
    end;
end;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
        nd_acc = 1,
    },
}
Test { [[
event int a;
par/or do
    return 1;
with
    emit a(1);
    // unreachable
end;
// unreachable
await a;
// unreachable
return 0;
]],
    simul = {
        n_unreachs = 3,
        --nd_esc = 1,
        --nd_flw = 1,
    },
    run = 1,
    --dfa = 'unreachable statement',
    --trig_wo = 1,
}
-- TODO: nd_flw?
Test { [[
event int a;
par/or do
    nothing;
with
    emit a(1);
    // unreachable
end;
// unreachable
await a;
// unreachable
return 0;
]],
    simul = {
        n_unreachs = 2,
        isForever = true,
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
    emit a(1);
    // unreachable
end;
]],
    simul = {
        n_unreachs = 1,
        --nd_esc = 1,
        --nd_flw = 1,
    },
    run = 1,
    --trig_wo = 1,
}
Test { [[
event int a;
par do
    emit a(1);
    return 0;
with
    return 2;
end;
]],
    simul = {
        n_unreachs = 1,
        --nd_esc = 1,
        --nd_flw = 1,
        --trig_wo = 1,
    },
    run = 2,
}
Test { [[
event int a;
par/or do
    emit a(1);
with
    nothing;
end;
await a;
return 0;
]],
    simul = {
        n_unreachs = 2,
        --nd_esc = 1,
        isForever = true,
    },
    --trig_wo = 1,
}

Test { [[
input int Start;
event int a;
int v1=0,v2=0;
await Start;
par/or do
    emit a(2);
    v1 = 2;
with
    v2 = 2;
end
return v1+v2;
]],
    simul = {
        n_unreachs = 1,
        --nd_esc = 1,
    },
    run = 2,
}

Test { [[
input int Start;
event int a;
int v1=0,v2=0,v3=0;
par/or do
    await Start;
    emit a(2);
    v1 = 2;
with
    await Start;
    v2 = 2;
with
    await a;
    v3 = 2;
end
return v1+v2+v3;
]],
    simul = {
        n_unreachs = 2,
        --nd_esc = 1,
    },
    run = 2,
}

-- 1st to escape and terminate
Test { [[
input int Start;
event int a;
int ret;
par/or do
    await Start;
    par/or do
        emit a(2);
    with
        ret = 3;
    end;
with
    await a;
    ret = a + 1;
end;
return ret;
]],
    simul = {
        n_unreachs = 2,
        --nd_esc = 2,
        --nd_acc = 1,
    },
    todo = 'nd_acc = 1',
    run = 3,
}
Test { [[
input int A;
int a;
par do
    a = await A;
    return a;
with
    a = await A;
    return a;
end;
]],
    simul = {
        nd_acc = 4,
    --nd_flw = 2,
    },
    run = { ['5~>A']=5 },
}
Test { [[
input int A;
int a;
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
    }
}
Test { [[
input int A;
int a;
par/or do
    await A;
with
    a = await A;
end;
return a;
]],
    run = {
        ['1~>A'] = 1,
        ['2~>A'] = 2,
    }
}
Test { [[
input int A;
int a;
par/or do
    await A;
    a = 10;
with
    await A;
    int v = a;
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
    run = {
        ['1~>A'] = 10,
        ['2~>A'] = 10,
    }
}

Test { [[
input int A;
int a;
par/or do
    await A;
    a = 10;
with
    await A;
    a = 11;
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
}

Test { [[
input int A;
int a;
par/or do
    await A;
    a = 10;
with
    await A;
    return a;
end;
return a;
]],
    simul = {
        nd_acc = 1,
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
        await Forever;
    end;
end;
]],
    simul = {
        n_unreachs = 2,
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
    simul = {
        isForever = true,
        n_unreachs = 2,
    },
}

Test { [[
input int A;
int a = set par do
    await A;
    int v = 10;
    return a;
with
    await A;
    return a;
end;
return a;
]],
    todo = '"a"s deveriam ser diferentes',
    simul = {
        nd_acc = 1,
        --nd_flw = 2,
    },
}

Test { [[
input int A,B;
int a;
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
    simul = {
        nd_acc = 1,
        --nd_flw = 1,
    },
}

Test { [[
input int A,B;
int a = 0;
par/or do
    par/or do
        int v = await A;
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
input int A, C;
int v;
loop do
    par/or do
        await A;
    with
        v = await C;
        break;
    end;
end;
return v;
]],
    run = {
        ['0~>A ; 0~>A ; 3~>C'] = 3,
        ['0~>A ; 0~>A ; 4~>C'] = 4,
    }
}
Test { [[
input int A,B,C;
int v;
loop do
    par/or do
        await A;
        await B;
    with
        v = await C;
        break;
    end;
end;
return v;
]],
    run = {
        ['0~>A ; 0~>A ; 3~>C'] = 3,
        ['0~>A ; 0~>A ; 0~>B ; 1~>B ; 4~>C'] = 4,
    }
}
Test { [[
input int A,B,C;
int v;
loop do
    par/or do
        await A;
        await B;
    with
        v = await C;
        break;
    end;
end;
return v;
]],
    run = {
        ['0~>A ; 0~>A ; 3~>C'] = 3,
        ['0~>A ; 0~>A ; 0~>B ; 1~>B ; 4~>C'] = 4,
    }
}
Test { [[
input int A,B;
int v;
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
    simul = {
        n_unreachs = 2,
        --nd_flw = 1,
    },
    run = {
        ['0~>B ; 0~>B ; 3~>A'] = 3,
    }
}
Test { [[
input int A,B;
int v;
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
    simul = {
        n_unreachs = 3,
        --dfa = 'unreachable statement',
        --nd_flw = 1,
    },
    run = {
        ['0~>B ; 0~>B ; 3~>A'] = 3,
    }
}
Test { [[
input int A, B;
int v;
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
    simul = {
        nd_acc = 1,     -- TODO: should be 0
    },
    run = {
        ['0~>B ; 0~>A ; 0~>B ; 0~>A ; 3~>A'] = 3,
    }
}
Test{ [[
input int A;
int v;
loop do
    v = await A;
    break;
end;
return v;
]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['1~>A'] = 1,
        ['2~>A'] = 2,
    }
}

Test { [[
input int A;
int a;
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
input int Start;
event int a,b,c;
par/and do
    await Start;
    emit b(1);
    emit c(1);
with
    await b;
    par/or do
        nothing;
    with
        par/or do
            nothing;
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
int a;
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
    todo = true,
    run = {
        ['~>30ms ; 0~>A ; ~>50ms'] = 2,
        ['0~>A ; ~>40ms'] = 2,
        ['0~>A ; ~>20ms ; ~>20ms'] = 2,
    }
}

-- tests AwaitT after Ext
Test { [[
input int A;
int a;
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
    todo = true,
    run = {
        ['~>30ms ; 0~>A ; ~>50ms'] = 2,
        ['0~>A ; ~>40ms'] = 2,
        ['0~>A ; ~>20ms ; ~>20ms'] = 2,
    }
}

Test { [[
input int A;
int a;
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
    todo = true,
    run = {
        ['~>30ms ; 0~>A ; ~>50ms'] = 2,
        ['0~>A ; ~>40ms'] = 2,
        ['0~>A ; ~>20ms ; ~>20ms'] = 2,
    }
}

Test { [[
input void A;
int a;
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
    todo = true,
    run = {
        -- TODO: ext
        ['~>A ; ~>A ; ~>12ms; ~>A; ~>91ms'] = 2,
    }
}

Test { [[
input int A;
int dt;
par/or do
    dt = await 20ms;
with
    await A;
    dt = await 20ms;
end;
return dt;
]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['~>30ms'] = 10000,
        ['0~>A ; ~>40ms'] = 20000,
        ['~>10ms ; 0~>A ; ~>40ms'] = 30000,
    }
}
Test { [[
input int A;
int dt;
par/or do
    await A;
    dt = await 20ms;
with
    dt = await 20ms;
end;
return dt;
]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['~>30ms'] = 10000,
        ['0~>A ; ~>40ms'] = 20000,
        ['~>10ms ; 0~>A ; ~>40ms'] = 30000,
    }
}
Test { [[
input int A;
int dt;
par/or do
    dt = await 20us;
with
    await A;
    dt = await 10us;
end;
return dt;
]],
    run = {
        -- TODO: ext
        ['~>30us'] = 10,
        ['0~>A ; ~>12us'] = 0,
        ['0~>A ; ~>13us'] = 1,
    }
}
Test { [[
input int A;
int dt;
par/or do
    dt = await 20ms;
with
    dt = await 10ms;
    await A;
    dt = await 10ms;
end;
return dt;
]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['~>30ms'] = 10000,
        ['~>12ms ; 0~>A ; ~>8ms'] = 0,
        ['~>15ms ; 0~>A ; ~>10ms'] = 5000,
    }
}

Test { [[
input int A;
int dt;
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
    todo = true,
    n_unreachs = 0,    -- TODO: timer kills timer
    run = {
        ['~>30us'] = 1,
        ['~>12us ; 0~>A ; ~>8us'] = 1,
        ['~>15us ; 0~>A ; ~>10us'] = 1,
    }
}

Test { [[
input int A,B;
int ret;
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
    run = {
        ['1~>A;~>25ms'] = 1,
        ['1~>A;1~>B;~>25ms'] = 1,
        ['1~>B;~>25ms'] = 2,
        ['1~>B;1~>A;~>25ms'] = 2,
    }
}

Test { [[
input int A,B;
int ret;
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
    run = {
        ['1~>A;~>25ms'] = 1,
        ['1~>A;1~>B;~>25ms'] = 1,
        ['1~>B;~>25ms'] = 2,
        ['1~>B;1~>A;~>25ms'] = 2,
    }
}

Test { [[
input int A;
int dt;
par/or do
    dt = await 20ms;
with
    await A;
    await 10ms;
    dt = await 10ms;
end;
return dt;
]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['~>30ms'] = 10000,
        ['~>12ms ; 0~>A ; ~>8ms'] = 0,
        ['~>15ms ; 0~>A ; ~>10ms'] = 5000,
    }
}

Test { [[
input int A,B;
int dt;
par/or do
    await A;
    dt = await 20ms;
with
    await B;
    dt = await 20ms;
end;
return dt;
]],
    run = {
        ['~>30ms ; 0~>A ; ~>21ms'] = 997,
        ['~>12ms ; 0~>A ; 0~>B ; ~>27ms'] = 6997,
        ['~>12ms ; 0~>B ; ~>3ms ; 0~>A ; ~>20ms'] = 2997,
    }
}

Test { [[
input int A,B;
int dt;
par/or do
    await A;
    dt = await 20ms;
with
    await B;
    dt = await (20)ms;
end;
return dt;
]],
    run = {
        ['~>30ms ; 0~>A ; ~>21ms'] = 997,
        ['~>12ms ; 0~>A ; 0~>B ; ~>27ms'] = 6997,
        ['~>12ms ; 0~>B ; ~>3ms ; 0~>A ; ~>20ms'] = 2997,
    }
}

Test { [[
input int A,B;
int dt;
int ret = 10;
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
    run = {
        ['~>30ms ; 0~>A ; ~>25ms'] = 1,
        ['~>12ms ; 0~>A ; 0~>B ; ~>27ms'] = 1,
        ['~>12ms ; 0~>B ; ~>3ms ; 0~>A ; ~>20ms'] = 2,
    }
}

Test { [[
input int A, B;
int dt;
int ret = 10;
par/or do
    await A;
    await B;
    dt = await 20ms;
    ret = 1;
with
    await B;
    dt = await 20ms;
    ret = 2;
end;
return ret;
]],
    simul = {
        nd_acc = 2,
    },
    run = {
        ['~>12ms ; 0~>A ; 0~>B ; ~>27ms'] = 2,
        ['~>12ms ; 0~>B ; 0~>A ; 0~>B ; ~>26ms'] = 2,
    }
}

-- Boa comparacao de n_unreachs vs nd_flw para timers
Test { [[
int dt;
par/or do
    await 10ms;
    dt = await 10ms;
with
    dt = await 30ms;
end;
return dt;
]],
    simul = {
        n_unreachs = 1, -- apos ~30
    },
    run = {
        ['~>12ms ; ~>17ms'] = 9000,
    }
}
Test { [[
int dt;
par/or do
    await 10us;
    dt = await (10)us;
with
    dt = await 30us;
end;
return dt;
]],
    simul = {
        nd_acc = 1,
    },
    run = {
        ['~>12us ; ~>17us'] = 9,
    }
}

Test { [[
input int A,B;
int ret;
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
    run = {
        ['0~>A ; 0~>B ; ~>21ms'] = 0,
        ['0~>B ; 0~>A ; ~>21ms'] = 1,
        ['0~>A ; 0~>B ; ~>21ms'] = 0,
        ['0~>B ; 0~>A ; ~>21ms'] = 1,
    }
}

Test { [[
input int Start;
event int a, b;
int x;
par/or do
    await a;
    await 10ms;
    x = 0;
with
    await b;
    emit a(b);
    await 10ms;
    x = 1;
with
    await Start;
    emit b(1);
    x = 2;
    await Forever;
end;
return x;
]],
    simul = {
        nd_acc  = 1,    -- TODO: timer kills timer
        n_unreachs = 0,    -- TODO: timer kills timer
    },
    --run = { ['~>10ms']=0 },
}

Test { [[
input int Start;
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
    await Start;
    emit b(1);
    emit a(b);
    x = 2;
    await Forever;
end;
return x;
]],
    simul = {
        nd_acc = 1,     -- TODO: timer kills timer
    n_unreachs = 0,    -- TODO: timer kills timer
    },
    --run = { ['~>10ms']=0 },   -- TODO: intl timer
}

Test { [[
input int Start;
event int a, b;
int x;
par/or do
    await a;
    await 10ms;
    x = 1;
with
    await b;
    await 10ms;
    x = 0;
with
    await Start;
    b = 1;
    a = b;
    x = a;
end;
return x;
]],
    simul = {
        n_unreachs = 4,
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
    simul = {
        nd_acc = 1,
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
    simul = {
        nd_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
input int A,B, C;
par do
    loop do
        par/or do
            await A;
            break;
        with
            await C;
        with
            await B;
            break;
        end;
        await C;
    end;
    return 1;
with
    await A;
    return 2;
end;
]],
    simul = {
        nd_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
input int A;
int a;
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
    simul = {
        n_unreachs = 1,
    nd_acc = 1,
    },
}

Test { [[
input int A,B;
int a = 0;
par/or do
    par/or do
        await A;
    with
        await B;
    end;
    await 10ms;
    int v = a;
with
    await B;
    await 10ms;
    a = 2;
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
    run = {
        ['0~>A ; 0~>B ; ~>20ms'] = 0,
    }
}

Test { [[
input int A,B;
int a = 0;
par/or do
    await A;
    await B;
    await 10ms;
    int v = a;
with
    await B;
    await 10ms;
    a = 1;
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
}

Test { [[
input int A,B;
int a = 0;
par/or do
    par/and do
        await A;
    with
        await B;
        await 10ms;
    end;
    int v = a;
with
    await B;
    await 20ms;
    a = 1;
end;
return a;
]],
    run = {
        ['1~>A;~>10ms;1~>B;~>25ms'] = 0,
        ['~>10ms;1~>B;~>25ms'] = 1,
    }
}

Test { [[
input int A,B;
int a = 0;
par/or do
    par/or do
        await A;
    with
        await B;
        await (10)us;
    end;
    await 10us;
    int v = a;
with
    await A;
    await B;
    await (20)us;
    a = 1;
end;
return a;
]],
    run = {
        ['0~>A ; 0~>B ; ~>21us'] = 0,
    }
}
Test { [[
input int A,B;
int a;
par/or do
    par/and do
        await A;
    with
        await B;
        await 10ms;
    end;
    await 10ms;
    int v = a;
with
    await A;
    await B;
    await 20ms;
    a = 1;
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
}

Test { [[
int a;
par/or do
    await 10ms;
    int v = a;
with
    await 10ms;
    a = 1;
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
}

Test { [[
input int A;
int v;
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
    simul = {
        n_unreachs = 2,
        isForever = true,
        nd_acc = 1,
    },
}

Test { [[
input int A,B;
int v;
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
    simul = {
        n_unreachs = 2,
        isForever = true,
        nd_acc = 1,       -- fiz na mao!
    },
}
-- bom exemplo de explosao de estados!!!
Test { [[
input int A,B;
int v;
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
    simul = {
        n_unreachs = 2,
        isForever = true,
        nd_acc = 1,       -- nao fiz na mao!!!
    },
}

-- EX.04: join
Test { [[
input int A,B;
int a;
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
int a;
par/and do
    if a then
        await A;
    else
        await A;
        await A;
        int v = a;
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
    simul = {
        nd_acc = 1,
    },
}
Test { [[
input int A;
int a;
if a then
    await A;
else
    par/and do
        await A;
        await A;
        int v = a;
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
    simul = {
        nd_acc = 1,
    },
}
Test { [[
input int A;
int a;
par do
    loop do
        if a then
            await A;
        else
            await A;
            await A;
            int v = a;
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
    simul = {
        n_unreachs = 3,
        isForever = true,
        nd_acc = 5,
    },
}
Test { [[
int v = set par do
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
    simul = {
        nd_acc = 1,
    --nd_flw = 2,
    },
}
Test { [[
int a;
int v = set par do
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
    simul = {
        nd_acc = 1,
    --nd_flw = 2,
    },
}
Test { [[
int v = set par do
            return 1;
        with
            return 2;
        end;
return v;
]],
    simul = {
        nd_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
int a;
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
    simul = {
        nd_acc = 1,
    n_unreachs = 1,
    },
}
Test { [[
int a;
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
    simul = {
        nd_acc = 1,
    },
}
Test { [[
input int A;
int a;
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
    simul = {
        nd_acc = 1,
    },
}
Test { [[
input int A;
int a;
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
    simul = {
        nd_acc = 1,
    },
}
Test { [[
input int A;
int a;
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
    simul = {
        nd_acc = 1,
    },
}

Test { [[
int a;
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
    simul = {
        nd_acc = 1,
    },
}

Test { [[
int a;
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
    simul = {
        nd_acc = 1,
    },
}

Test { [[
int a;
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
    simul = {
        nd_acc = 0,
    },
}

Test { [[
input int A;
int a;
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
    simul = {
        nd_acc = 1,
    },
}

Test { [[
input int A;
int a;
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
    simul = {
        nd_acc = 1,
    },
}

Test { [[
input int A;
int a;
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
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['~>10ms'] = 2,
        ['1~>A ; ~>10ms'] = 2,
    }
}

Test { [[
int a;
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
    simul = {
        n_unreachs = 1,
    },
    run = { ['~>1s']=2 },
}
Test { [[
input int A;
int a;
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
    simul = {
        nd_acc = 3,
    },
}

Test { [[
input int A;
int a;
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
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['~>10ms'] = 2,
        ['~>A ; ~>10ms'] = 2,
    }
}

Test { [[
int x;
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
    simul = {
        nd_acc = 1,
    },
}

Test { [[
int x;
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
    simul = {
        n_unreachs = 2,
        isForever = true,
        nd_acc = 1,
    },
}

Test { [[
int x;
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
    simul = {
        n_unreachs = 2,
        isForever = true,
        nd_acc = 1,
    },
}

Test { [[
input int Start;
event int a;
int x;
par/or do
    await Start;
    par/and do
        await 10ms;
        x = 4;
    with
        emit a;
    end;
    int v = x;
with
    await a;
    await 10ms;
    x = 5;
end;
return x;
]],
    simul = {
        nd_acc = 2,  -- TODO: intl
    },
    run = { ['~>15ms']=5, ['~>25ms']=5 }
}

-- EX.02: trig e await depois de loop
Test { [[
input int A;
event int a;
loop do
    par/and do
        await A;
        emit a(1);
    with
        await a;
    end;
end;
]],
    simul = {
        n_unreachs = 1,
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
    simul = {
        n_unreachs = 1,
        nd_acc = 1,
    },
    run = 0,
}

Test { [[
input void A;
event void a;
int ret = 0;
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
    simul = {
        n_unreachs = 1,
    },
    run = { ['~>A']=2 },
}

Test { [[
input int Start;
event int a;
par do
    loop do
        par/or do
            await Start;
            emit a(1);
        with
            await a;
        end;
    end;
with
    await a;
    emit a(a);
end;
]],
    todo = 'nd_acc=1',
    simul = {
        isForever = true,
        --nd_esc = 1,
        nd_acc = 1, -- EX.10: trig2 vs await1 loop
        --trig_wo = 1,
        n_unreachs = 2,
    },
}

Test { [[
input int Start;
event int a;
par do
    loop do
        par/and do
            await Start;
            emit a(1);
        with
            await a;
        end;
    end;
with
    await a;
    emit a(a);
end;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
        --trig_wo = 1,
    },
}

Test { [[
input int A;
event int a, d, e, i, j;
par/and do
    await A;
    emit a(1);
with
    d = await a;
    emit i(5);
with
    e = await a;
    emit j(6);
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
    emit a(1);
with
    return a;
end;
]],
    simul = {
        --nd_esc = 1,
    --nd_flw = 1,
    n_unreachs = 1,
    --trig_wo = 1,
    nd_acc = 1,
    },
}

Test { [[
event int a;
int v;
loop do
    par do
        v = a;
    with
        await a;
    end;
end;
]],
    simul = {
        isForever = true,
        n_unreachs = 3,
    },
}
Test { [[
input int A;
event int b;
int a,v;
par do
    loop do
        v = a;
        await b;
    end;
with
    await A;
    emit b(1);
end;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
}
Test { [[
input int A,B;
event int a;
par do
    par do
        await A;
        emit a(1);
    with
        await a;
        await a;
    end;
with
    int v = await B;
    return v;
end;
]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['0~>A ; 10~>B'] = 10,
    }
}

Test { [[
event int a;
int b;
par/or do
    b = await a;
with
    emit a(3);
end;
return 0;
]],
    simul = {
        n_unreachs = 1,
    nd_acc = 1,
    --trig_wo = 1,
    },
}

Test { [[
event int a;
int b;
par/or do
    b = await a;
with
    emit a(3);
with
    a = b;
end;
return 0;
]],
    simul = {
        --nd_esc = 1,
    n_unreachs = 2,
    nd_acc = 2,
    --trig_wo = 1,
    },
}

Test { [[
input int Start;
event int b;
int i;
par/or do
    await Start;
    emit b(1);
    i = 2;
with
    await b;
    i = 1;
end;
return i;
]],
    simul = {
        --nd_esc = 1,
    n_unreachs = 1,
    },
    run = 1,
}
Test { [[
input int Start;
event int b,c;
par/or do
    await Start;
    emit b(1);
    await c;
with
    await b;
    emit c(5);
end;
return c;
]],
    simul = {
        --nd_esc = 1,
    n_unreachs = 2,
    --trig_wo = 1,
    },
    run = 5,
}
Test { [[
input int A;
int ret;
loop do
    int v = await A;
    if v == 5 then
        ret = 10;
        break;
    else
        nothing;
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
int a = 0;
loop do
    int b = await B;
    a = a + b;
    if a == 5 then
        return 10;
    end;
end;
return 0;
]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['1~>B ; 4~>B'] = 10,
        ['3~>B ; 2~>B'] = 10,
    }
}

Test { [[
input int A,B;
int ret = set
    loop do
        await A;
        par/or do
            await A;
        with
            int v = await B;
            return v;
        end;
    end;
return ret;
]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['1~>A ; 5~>B'] = 5,
        ['1~>A ; 1~>A ; 3~>B ; 1~>A ; 5~>B'] = 5,
    }
}

Test { [[
input int A;
event int a;
loop do
    int v = await A;
    if v==2 then
        return a;
    end;
    emit a(v);
end;
]],
    simul = {
        --trig_wo = 1,
    n_unreachs = 1,
    },
    run = {
        ['0~>A ; 0~>A ; 3~>A ; 2~>A'] = 3,
    }
}

Test { [[
input int A;
event int a;
loop do
    int v = await A;
    if v==2 then
        return a;
    else
        if v==4 then
            break;
        end;
    end;
    emit a(v);
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
int a = 0;
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
    simul = {
        n_unreachs = 1,
    },
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
int ret;
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
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['0~>A ; 0~>A ; 10~>A'] = 10,
        ['0~>B ; 0~>A ; 11~>B'] = 11,
        ['0~>B ; 0~>B ; 12~>B'] = 12,
    }
}

Test { [[
input int A,B;
int v;
par/or do
    v = await A;
with
    await B;
    v = await A;
end;
return v;
]],
    simul = {
        nd_acc = 1,     -- should be 0
    },
    run = {
        ['10~>A'] = 10,
        ['0~>B ; 10~>A'] = 10,
    }
}

Test { [[
input int A,B,C;
int ret;
par/or do
    par/or do
        ret = await A;
    with
        ret = await B;
    end;
with
    await C;
    await A;
end;
return ret;
]],
    run = {
        ['0~>C ; 10~>B'] = 10,
        ['0~>C ; 10~>A'] = 10,
        ['0~>C ; 1~>C ; 5~>A'] = 5,
    }
}

Test { [[
input int A,B,C;
int v;
par/or do
    par/and do
        v = await A;
    with
        await B;
    end;
with
    await C;
    v = await A;
end;
return v;
]],
    simul = {
        nd_acc = 1,
    },
    run = {
        ['0~>C ; 10~>A'] = 10,
        ['0~>A ; 1~>C ; 5~>A ; 1~>B'] = 5,
    }
}

Test { [[
input int A,B,C;
int v;
par/or do
    par/and do
        await A;
        await B;
        v = await A;
    with
        await C;
        await B;
        await C;
    end;
with
    await A;
    await C;
    await B;
    await B;
    v = await C;
end;
return v;
]],
--((~A;~B;~A)=>v&&(~C;~B;~C));v || (~A;~C;~B;~B;~C)]],
    run = {
        ['0~>A ; 1~>C ; 5~>B ; 1~>B ; 9~>C'] = 9,
        ['0~>A ; 1~>C ; 1~>B ; 5~>A ; 9~>C'] = 5,
    }
}

Test { [[
input int A,B,C;
int v;
par/or do
    par/and do
        await A;
        await B;
        v = await A;
    with
        await C;
        await B;
        v = await C;
    end;
with
    await A;
    await C;
    await B;
    await A;
    await C;
    await B;
end;
return v;
]],
--((~A;~B;~A)=>v&&(~C;~B;~C)=>v);v || (~A;~C;~B;~A;~C;~B)]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['0~>A ; 1~>C ; 5~>B ; 1~>A ; 1~>C ; 9~>B'] = 1,
    },
}

Test { [[
input int A,B;
int v;
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
--(1?~A:~B) || (~A;1) || (~B;2)]],
    simul = {
        nd_acc = 2,
    },
    run = {
        ['1~>A'] = 1,
        ['1~>B'] = 2,
    },
}
Test { [[
input int A,B;
int v;
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
--(1?~A:~B) || (~A;~B) || (~B;~A)]],
    simul = {
        nd_acc = 2,
    },
    run = {
        ['0~>B ; 10~>A'] = 10,
        ['0~>B ; 9~>A'] = 9,
    },
}
Test { [[
input int A,B,C;
int v;
par/or do
    await A;
    await B;
    v = await C;
with
    await B;
    await A;
    v = await C;
end;
return v;
]],
    simul = {
        nd_acc = 1,
    },
}
Test { [[
input int A,B,C;
int v;
par/or do
    if 1 then
        v = await A;
    else
        v = await B;
    end;
with
    await A;
    await B;
    v = await C;
with
    await B;
    await A;
    v = await C;
end;
return v;
]],
--(1?~A:~B) || (~A;~B;~C) || (~B;~A;~C)]],
    simul = {
        n_unreachs = 2,
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
        int v = await B;
        return v;
    end;
with
    int v = await A;
    return v;
end;
]],
    simul = {
        n_unreachs = 3,
        --nd_flw = 1,
    },
    run = {
        ['0~>B ; 10~>A'] = 10,
    },
}
Test { [[
input int A,B;
int v;
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
--(~A || ~B^)*]],
    run = {
        ['0~>A ; 0~>A ; 10~>B'] = 10,
    },
}
Test { [[
input int A,B,C;
int a;
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
    a = await C;
    return a;
end;
]],
--((a?~A^:~B))* || (~B;~C)]],
    run = {
        ['0~>B ; 10~>C'] = 10,
    },
}

Test { [[
input int A,B;
if 11 then
    int v = await A;
    return v;
else
    int v = await B;
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
if 1 then
    await A;
else
    await B;
end;
return 1;
]],
    simul = {
        isForever = true,
        n_unreachs = 3,
    },
}
Test { [[
par/or do
    nothing;
with
    nothing;
end
return 1;
]],
    run = 1,
}
Test { [[
input int A;
par do
    nothing;
with
    loop do
        await A;
    end;
end;
]],
--1&&(~A)*]],
    simul = {
        n_unreachs = 1,
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
--(~A)* && (~B)*]],
    simul = {
        n_unreachs = 2,
        isForever = true,
    },
}
Test { [[
input int A,B,C;
int v;
loop do
    v = await A;
    if v then
        v = await B;
        break;
    else
        await C;
    end
end
return v;
]],
--(((~A)?~B^:~C))*]],
    run = {
        ['1~>A ; 10~>B'] = 10,
        ['0~>A ; 0~>C ; 1~>A ; 9~>B'] = 9,
    },
}

Test { [[
input int A,B,C,D,E,F,G,H,I,J,K,L;
int v;
par/or do
    await A;
with
    await B;
end;
await C;
await D;
await E;
await F;
int g = await G;
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
--(~A||~B); ~C; (~D,~E); ~F; ((~G)?~H:~I); ~J; ((~K||~L^))*]],
    run = {
        ['0~>A ; 0~>C ; 0~>D ; 0~>E ; 0~>F ; 0~>G ; 0~>I ; 0~>J ; 0~>K ; 10~>L'] = 10,
        ['0~>B ; 0~>C ; 0~>D ; 0~>E ; 0~>F ; 1~>G ; 0~>H ; 0~>J ; 0~>K ; 11~>L'] = 11,
    },
}

-- NONDET

Test { [[
int a;
par do
    a = 1;
    return 1;
with
    return a;
end;
]],
--1=>a || a]],
    simul = {
        --nd_flw = 2,
    nd_acc = 2,
    },
}
Test { [[
input int B;
int a;
par do
    await B;
    a = 1;
    return 1;
with
    await B;
    return a;
end;
]],
--(~B;1=>a) || (~B;a)]],
    simul = {
        nd_acc = 2,
    --nd_flw = 2,
    },
}
Test { [[
input int B,C;
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
        await C;
    end;
    return a;
end;
]],
--(~B;1=>a) || ((~a||~B||~C); a)]],
    simul = {
        n_unreachs = 1,
    nd_acc = 2,
    --nd_flw = 2,
    },
}
Test { [[
input int Start, C;
event int a;
par do
    await Start;
    emit a(1);
    return 0;
with
    par/or do
        await a;
    with
        await Start;
    with
        await C;
    end;
    return a;
end;
]],
    simul = {
        nd_acc = 1,
    --nd_flw = 1,
    --nd_esc = 2,
    n_unreachs = 2,    -- +1 C n_unreachs
    },
    run = 1,
}
Test { [[
input int Start;
event int a;
par do
    await Start;
    emit a(1);
with
    await a;
    return a;
end;
]],
    simul = {
        n_unreachs = 1,
        --nd_esc = 1,
    },
    run = 1,
}
Test { [[
input int B,C;
event int a;
par/or do
    await B;
    emit a(5);
with
    await a;
    a = a + 1;
end;
return a;
]],
    simul = {
        n_unreachs = 1,
        --nd_esc = 1,
    },
    run = {
        ['1~>B'] = 6,
    },
}
Test { [[
input int B,C;
event int a;
par/or do
    await B;
    emit a(5);
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
    simul = {
        n_unreachs = 1,
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
    emit a(5);
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
    simul = {
        n_unreachs = 1,
        --nd_esc = 1,
    },
    run = {
        ['1~>B'] = 6,
    },
}
Test { [[
input int B,C;
event int a;
par/or do
    await B;
    emit a(5);
with
    par/and do
        await a;
    with
        await B;
    with
        await C;
    end;
    a = a + 1;
end;
return a;
]],
    simul = {
        --nd_esc = 1,
    },
    run = {
        ['1~>B'] = 5,
        ['2~>C; 1~>B'] = 6,
    },
}
Test { [[
input int Start;
event int a;
par do
    await Start;
    emit a(1);
    return a;
with
    par/and do
        await a;
    with
        await Start;
    end;
    return a;
end;
]],
    simul = {
        --nd_esc = 1,
    n_unreachs = 1,
    },
    run = 1,
}
Test { [[
input int Start, C;
event int a;
par do
    await Start;
    emit a(1);
    return a;
with
    par/and do
        await a;
    with
        await Start;
    with
        await C;
    end;
    return a;
end
]],
    simul = {
        --nd_esc = 1,
        --nd_flw = 1,
    },
    run = 1,
}
Test { [[
input int B,C;
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
        await C;
    end;
end;
]],
--(~B;1=>a) || ((~a&&~B&&~C); a)]],
    simul = {
        n_unreachs = 1,
    --nd_flw = 1,
    --nd_flw = 1,
    },
    run = {
        ['1~>B'] = 1,
    },
}
Test { [[
input int B,C;
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
        await C;
    end;
    return a;
end;
]],
--(~B;1=>a) || ((~a&&~B&&~C); a)]],
    simul = {
        --dfa = 'unreachable statement',
    --nd_flw = 1,
    n_unreachs = 2,
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
            nothing;
        with
            nothing;
        end;
        await A;
        // unreachable
    end;
    // unreachable
end;
return 1;
]],
    simul = {
        --dfa = 'unreachable statement',
    --nd_flw = 1,
    n_unreachs = 3,
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
    simul = {
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
    simul = {
        n_unreachs = 2,
    --nd_flw = 1,
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
    simul = {
        --dfa = 'unreachable statement',
    n_unreachs = 5,
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
    simul = {
        n_unreachs = 2,
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
            nothing;
        with
            nothing;
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
    nothing;
with
    par/or do
        nothing;
    with
        nothing;
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
        nothing;
    end;
    return a;
end;
return a;
]],
--1=>a || ( (~a||1);a )]],
    simul = {
        n_unreachs = 1,
    --nd_flw = 1,
    nd_acc  = 1,
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
        nothing;
    end;
    return a;
end;
]],
--(~B;1=>a) || (~B; (~a||1); a)]],
    simul = {
        n_unreachs = 1,
    --nd_flw = 2,
    nd_acc = 2,
    },
}
Test { [[
int a = 0;
par do
    return a;
with
    return a;
end;
]],
--0=>a ; (a||a)]],
    simul = {
        nd_acc = 1,
    --nd_flw = 2,
    },
}
Test { [[
int a;
par do
    return a;
with
    a = 1;
    return a;
end;
]],
    simul = {
        nd_acc = 2,
    --nd_flw = 2,
    },
}
Test { [[
int a;
par do
    a = 1;
    return a;
with
    return a;
end;
]],
    simul = {
        --nd_flw = 2,
    nd_acc = 2,
    },
}
Test { [[
int a;
par/or do
    a = 1;
with
    a = 1;
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
}
Test { [[
int a;
par/or do
    a = 1;
with
    a = 1;
with
    a = 1;
end;
return a;
]],
    simul = {
        nd_acc = 3,
    },
}
Test { [[
input int A;
par do
    int v = await A;
    return v;
with
    int v = await A;
    return v;
end;
]],
    simul = {
        nd_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
event int a;
par/or do
    await a;
with
    emit a(1);
end;
return a;
]],
--~a||1~>a]],
    simul = {
        nd_acc = 1,
    nd_acc = 1,
    n_unreachs = 1,
    --trig_wo = 1,
    },
}
Test { [[
event int a;
par/or do
    emit a(1);
with
    emit a(1);
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
    run = 1,
}
Test { [[
event int a,b;
par/or do
    emit a(1);
    a = 2;
with
    emit b(1);
    b = 5;
end;
return a+b;
]],
    run = 7,
}
Test { [[
event int a, b;
par/or do
    emit a(2);
with
    emit b(3);
end;
return a+b;
]],
    --trig_wo = 2,
    run = 5,
}
Test { [[
event int a;
int v = set par do
    emit a(1);
    return a;
with
    emit a(1);
    return a;
with
    emit a(1);
    return a;
end;
return v;
]],
    simul = {
        nd_acc = 8,
        --nd_flw = 6,
        --trig_wo = 3,
    },
}
Test { [[
int a,v;
v = set par do
    return 1;
with
    return 1;
with
    return 1;
end;
return v;
]],
--(1||1||1)~>a]],
    simul = {
        nd_acc = 3,
    --nd_flw = 6,
    --trig_wo = 1,
    },
}
Test { [[
input int A;
int a = 0;
par do
    await A;
    return a;
with
    await A;
    return a;
end;
]],
--0=>a ; ((~A;a) || (~A;a))]],
    simul = {
        --nd_flw = 2,
    nd_acc = 1,
    },
}
Test { [[
input int A;
int a;
par do
    await A;
    return a;
with
    await A;
    a = 1;
    return a;
end;
]],
--(~A;a) || (~A;1=>a)]],
    simul = {
        --nd_flw = 2,
    nd_acc = 2,
    },
}
Test { [[
input int A;
event int a;
await A;
emit a(1);
await A;
emit a(1);
return a;
]],
--~A;1~>a;~A;1~>a]],
    --trig_wo = 2,
    run = {
        ['0~>A ; 10~>A'] = 1,
    },
}
Test { [[
input int A;
event int a;
par/or do
    loop do
        await A;
        emit a(1);
    end;
with
    await A;
    await A;
    await a;
end;
return a;
]],
    simul = {
        --nd_esc = 1,
    n_unreachs = 1,
    nd_acc = 1,
    },
}
Test { [[
input int Start;
event int a;
par do
    await Start;
    emit a(1);
    return a;
with
    await a;
    a = a + 1;
    return a;
with
    await a;
    await Forever;
end;
]],
    simul = {
        --nd_esc = 1,
    n_unreachs = 1,
    --nd_flw = 1,
    },
    run = 2,
}
Test { [[
input int Start;
event int a;
par/or do
    await Start;
    emit a(1);
with
    await a;
    a = a + 1;
with
    await a;
    int v = a;
end;
return a;
]],
    simul = {
        --nd_esc = 1,
        n_unreachs = 1,
        nd_acc = 1,
    },
}
Test { [[
input int A;
int v;
par do
    await A;
    loop do
        await A;
        int a = v;
    end;
with
    loop do
        await A;
        await A;
        v = 2;
    end;
end;
]],
--(~A; (~A;v)*) && (~A;~A;2=>v)*]],
    simul = {
        n_unreachs = 2,
        isForever = true,
        nd_acc = 1,
    },
}
Test { [[
input int A;
int v;
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
--(~A;~A;1=>v)* && (~A;~A;~A;v)*]],
    simul = {
        n_unreachs = 2,
        isForever = true,
        nd_acc = 1,
    },
}
Test { [[
input int A, B;
int a;
par/or do
    int v = await A;
    a = v;
with
    int v = await B;
    a = v;
with
    await A;
    await B;
    int v = a;
end;
return a;
]],
--(~A||(~B;1=>a)) || (~A;~B;a)]],
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['3~>A'] = 3,
        ['1~>B'] = 1,
    },
}
Test { [[
input int A, B;
int a;
par/or do
    await A;
    await B;
    a = 1;
with
    await A;
    int v = await B;
    a = v;
end;
return a;
]],
--(~A;~B;1=>a) || (~A;~B;a)]],
    simul = {
        nd_acc = 1,
    nd_acc = 1,
    },
}
Test { [[
input int A, B;
int a;
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
--((~A;3=>a)||(~B;1=>a)) ; ~B ; a]],
    run = {
        ['3~>A ; 5~>B'] = 3,
        ['3~>A ; 5~>B ; 5~>B'] = 3,
        ['3~>B ; 5~>B'] = 1,
        ['3~>B ; 5~>A ; 5~>B'] = 1,
    },
}

Test { [[
input int A, B, C;
int v;
par/or do
    v = await A;
with
    par/or do
        v = await B;
    with
        v = await C;
    end;
end;
return v;
]],
--~A||(~B||~C)]],
    run = {
        ['10~>A ; 1~>A'] = 10,
        ['9~>B'] = 9,
        ['8~>C'] = 8,
    }
}
Test { [[
input int A;
par/or do
    nothing;
with
    nothing;
end;
int v = await A;
return v;
]],
--(1||2);~A]],
    run = {
        ['10~>A ; 1~>A'] = 10,
        ['9~>A'] = 9,
        ['8~>A'] = 8,
    }
}
Test { [[
event int a, b, c, d;
par/or do
    par/and do
        await a;
        // unreachable
    with
        await b;
        // unreachable
    with
        await c;
        // unreachable
    end;
    // unreachable
with
    par/or do
        emit b(1);
    with
        emit a(2);
    with
        emit c(3);
    end;
    await d;
    // unreachable
end;
// unreachable
return 0;
// unreachable
]],
    simul = {
        nd_acc = 3,
        --trig_wo = 3,
    },
}
Test { [[
event int a, b, c;
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
        emit a(10);
    with
        emit b(20);
    with
        emit c(30);
    end;
end;
return 0;
]],
    simul = {
        n_unreachs = 4,
    nd_acc = 3,
    --trig_wo = 3,
    },
}
Test { [[
event int a, b, c;
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
        emit a(10);
    with
        emit b(20);
    with
        emit c(30);
    end;
end;
return 0;
]],
    simul = {
        nd_acc = 3,
        --trig_wo = 3,
    },
}
Test { [[
event int a;
par/or do
    emit a(1);
with
    emit a(1);
    await a;
end;
return 0;
]],
    simul = {
        nd_acc = 1,
        n_unreachs = 1,
        --trig_wo = 2,
    },
}
Test { [[
event int a;
par/or do
    emit a(1);
    await a;
with
    emit a(1);
end;
return 0;
]],
    simul = {
        nd_acc = 1,
        n_unreachs = 1,
        --trig_wo = 2,
    },
}
Test { [[
event int a;
par do
    emit a(1);
with
    emit a(1);
    await a;
end;
]],
    simul = {
        isForever = true,
        nd_acc = 1,
        n_unreachs = 1,
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
    simul = {
        n_unreachs = 2,
    --nd_flw = 1,
    },
    run = 1,
}
Test { [[
input int A, B;
int v;
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
--(((0,~A);(1)^) || ~B->asr)*]],
    run = {
        ['4~>A'] = 4,
        ['1~>B ; 3~>A'] = 3,
    }
}
Test { [[
input int A;
par do
    nothing;
with
    loop do
        await A;
    end;
end;
]],
    simul = {
        n_unreachs = 1,
        isForever = true,
    },
}

Test { [[
int x;
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
    simul = {
        nd_acc = 1,
    nd_acc = 1,
    },
}

    -- PRIO

Test { [[
int a = 0;
par/or do
    par/or do
        nothing;
    with
        nothing;
    end;
    a = a + 1;
with
    nothing;
end;
a = a + 1;
return a;
]],
    run = 2,
}

Test { [[
int b;
par do
    return 3;
with
    b = 1;
    return b+2;
end;
]],
    simul = {
        --nd_flw = 2,
    nd_acc = 1,
    },
}

Test { [[
input int A;
int v;
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
    simul = {
        n_unreachs = 1,
    --nd_flw = 2,
    nd_acc = 1,     -- should be 0
    },
    run = {
        ['5~>A'] = 5,
    }
}
Test { [[
int v1=0, v2=0;
loop do
    par do
        v1 = 1;
        break;
    with
        par/or do
            v2 = 2;
        with
            nothing;
        end;
        await Forever;
    end;
end;
return v1 + v2;
]],
    simul = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = 3,
}
Test { [[
input int A;
int v;
loop do
    par do
        v = await A;
        break;
    with
        nothing;
    end;
end;
return v;
]],
    simul = {
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
    parser = "ERR : line 4 : after `;´ : expected `end´",
}

Test { [[
input int A;
int v1=0,v2=0;
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
    simul = {
        n_unreachs = 1,
        --nd_flw = 2,
    },
    run = {
        ['5~>A'] = 10,
    }
}

Test { [[
input int A;
int v1=0, v2=0;
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
    simul = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = { ['1~>A']=0 },
}

Test { [[
input int A;
int v1=0, v2=0, v3=0;
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
    simul = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = {
        ['2~>A'] = 5,
    }
}

Test { [[
int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
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
    simul = {
        n_unreachs = 2,
    --nd_flw = 2,
    },
    run = 21,
}

Test { [[
int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
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
    simul = {
        n_unreachs = 2,
    },
    run = 21,
}

Test { [[
input int A;
int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
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
    simul = {
        n_unreachs = 2,
    --nd_flw = 3,
    },
    run = { ['~>A'] = 21 },
}

Test { [[
input int A;
int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
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
    simul = {
        n_unreachs = 2,
    },
    run = { ['1~>A']=21 },
}

Test { [[
int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
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
return v1+v2+v3+v4+v5+v6;
]],
    simul = {
        n_unreachs = 3,
    nd_acc = 1,
    },
    --nd_flw = 3,
}

Test { [[
input int A,B;
int v;
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
--( ~A ; (~A||~B^) )*]],
    run = {
        ['1~>A ; 5~>B'] = 5,
        ['1~>A ; 1~>A ; 3~>B ; 1~>A ; 5~>B'] = 5,
    }
}

Test { [[
input int A,B,C,D;
int a = 0;
a = set par do
    par/and do
        await A;
    with
        await B;
    end;
    return a+1;
with
    await C;
    return a;
end;
a = a + 1;
await D;
return a;
]],
    run = { ['0~>A;0~>B;0~>C;0~>D'] = 2 }
}

Test { [[
input int A,B,C,D;
int a = 0;
a = set par do
    par do
        await A;
        return a;
    with
        await B;
        return a;
    end;
with
    await C;
    return a;
end;
a = a + 1;
await D;
return a;
]],
    run = { ['0~>A;0~>B;0~>C;0~>D'] = 1 }
}

Test { [[
input int A,B,C,D;
int a = 0;
a = set par do
    par do
        await A;
        return a;
    with
        await B;
        return a;
    end;
    // unreachable
with
    await C;
    return a;
end;
a = a + 1;
await D;
return a;
]],
    run = { ['0~>A;0~>B;0~>C;0~>D'] = 1 }
}

Test { [[
input int B;
int a = 0;
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
int a = 0;
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
int a = 1;
int b;
loop do
    par/or do
        await B;
    with
        int v = await B;
        b = v;
        break;
    end;
    b = a;
    break;
end;
a = a + 1;
return a;
]],
    simul = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = { ['2~>B'] = 2 }
}

Test { [[
input int B;
int a = 0;
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
    simul = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = { ['2~>B'] = 3 }
}

Test { [[
input int B;
int b = 0;
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
    simul = {
        --dfa = 'unreachable statement',
    n_unreachs = 2,
    --nd_flw = 2,
    },
    run = { ['0~>B'] = 0 }
}

Test { [[
input int B;
int b = 0;
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
    simul = {
        n_unreachs = 1,
        --nd_flw = 2,
    },
    run = { ['0~>B'] = 0 }
}

Test { [[
input int B;
int a = 1;
par/or do
    await B;
with
    int b = set
        loop do
            par/or do
                await B;
                            // prio 1
            with
                int v = await B;
                return v;   // prio 1
            end;
            a = a + 1;
            return a;
        end;
    a = a + 2 + b;
end;
return a;
]],
    simul = {
        --nd_flw = 1,
        n_unreachs = 2,
    },
    run = { ['10~>B'] = 6 },
}

Test { [[
input int B;
int a = 1;
par/or do
    await B;
with
    int b = set
        loop do
            par/or do
                await B;
            with
                int v = await B;
                return v;
            end;
            a = a + 1;
        end;
    a = a + 2 + b;
end;
return a;
]],
    simul = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = { ['10~>B'] = 14 },
}

Test { [[
input int B;
int a = 1;
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
    simul = {
        n_unreachs = 1,
    --nd_flw = 1,
    },
    run = { ['10~>B'] = 2 },
}

Test { [[
input int B;
int a = 1;
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
    simul = {
        n_unreachs = 1,
    --nd_flw = 2,
    },
    run = { ['0~>B'] = 1 }
}

Test { [[
input int B;
int a = 1;
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
    simul = {
        --nd_flw = 2,
    n_unreachs = 2,
    },
    run = { ['0~>B'] = 1 }
}

Test { [[
input int B;
int a = 1;
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
    simul = {
        --nd_flw = 2,
    n_unreachs = 2,
    },
    run = { ['0~>B'] = 1 }
}

-- pode inserir 2x na fila
Test { [[
input int B;
int b;
int a = 2;
par/or do
    nothing;
with
    a = a + 1;
end;
b = a;
a = a*2;
await B;
return a;
]],
    run = {
        ['0~>B'] = 6,
    }
}
Test { [[
input int B;
int a = 2;
par/and do
    nothing;
with
    par/and do
        nothing;
    with
        nothing;
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
int a;
a = 2;
par/and do
    nothing;
with
    par/and do
        nothing;
    with
        nothing;
    end;
end;
a = a * 2;
return a;
]],
    run = 4,
}
Test { [[
int a;
a = 2;
par/or do
    nothing;
with
    par/or do
        nothing;
    with
        nothing;
    end;
end;
a = a * 2;
return a;
]],
    run = 4,
}

Test { [[
int a, b, c, d, e, f;
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
int v;
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
    simul = {
        --nd_flw = 1,
    n_unreachs = 2,
    },
    run = { ['5~>A'] = 5, }
}

Test { [[
input int A;
int v;
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
int v;
par/or do
    loop do
        v = await A;
        break;
    end;
    return v;
with
    int v = await A;
    return v;
end;
]],
    simul = {
        n_unreachs = 2,
    nd_acc = 1,
    --nd_flw = 2,
    },
}

Test { [[
input int A,B;
int v;
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
    simul = {
        nd_acc = 1, -- should be 0 (same evt)
    },
    run = {
        ['0~>B ; 5~>A'] = 5,
    }
}

-- Testa prio em DFA.lua
Test { [[
input int A;
int b,c,d;
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
    simul = {
        n_unreachs = 1,
    },
    run = { ['0~>A'] = 9, }
}

Test { [[
input int A;
int b,c,d;
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
    run = { ['0~>A'] = 9, }
}

Test { [[
input int A,C,D;
int b;
par/or do
    b = 0;
    loop do
        int v;
        par/and do
            nothing;
        with
            v = await A;
        end;
        b = 1 + v;
    end;
with
    await C;
    await D;
    return b;
end;
]],
    simul = {
        n_unreachs = 2,
    },
    run = {
        ['2~>C ; 1~>A ; 1~>D'] = 2,
    }
}

Test { [[
input int A;
int c = 2;
int d = set par/and do
        nothing;
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
int c = 2;
int d = set par do
        nothing;
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
event int a,b;
par/or do
    emit a(2);
with
    emit b(5);
end;
return a + b;
]],
    run    = 7,
    --trig_wo = 2,
}

Test { [[
input int A;
event int counter = 0;
par/and do
    loop do
        await A;
        counter = counter + 1;
    end;
    // unreachable
with
    loop do
        await counter;
        // unreachable
        if counter == 200 then
            counter = 0;
        end;
    end;
    // unreachable
end;
// unreachable
]],
    simul = {
        isForever = true,
        n_unreachs = 5,
    },
}

Test { [[
event int a;
emit a(8);
return a;
]],
    run = 8,
    --trig_wo = 1,
}

Test { [[
event int a;
par/and do
    emit a(9);
with
    loop do
        await a;
    end;
end;
]],
    simul = {
        isForever = true,
        nd_acc = 1,
        n_unreachs = 4,
        --trig_wo = 1,
    },
}

Test { [[
input int A;
event int a,b;
int v;
par/or do
    v = await A;
    par/or do
        emit a(1);
    with
        emit b(1);
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
    simul = {
        n_unreachs = 1,
    nd_acc = 0,
    },
    run = {
        ['1~>A ; 1~>A'] = 1,
    }
}

Test { [[
input int D, E;
event int a, b;
int c;
par/or do
    await D;
    par/or do
        emit a(8);
    with
        emit b(5);
    end;
    int v = await D;
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
    simul = {
        n_unreachs = 2,
    nd_acc = 0,
    --trig_wo = 1,
    },
    run = {
        ['1~>D ; 1~>E'] = 13,
    }
}

Test { [[
input int A,B;
event int a,b;
int v;
par/or do
    par/and do
        int v = await A;
        emit a(v);
    with
        await B;
        emit b(1);
    end;
    return v;
with
    v = await a;
    return v;
with
    await b;
    return b;
end;
]],
    simul = {
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
int v;
par/or do
    par/and do
        a = await A;
        v = a;
        return v;
    with
        await B;
        emit b(1);
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
--((~A~>a)=>v && ((~B,v);1~>b));v || ~a ||~b]],
    simul = {
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
int a;
par/and do
    loop do
        par/or do
            await A;
            int x = a;
        with
            await B;
        end;
    end;
with
    await B;
    a = await A;
end;
]],
--(~A;a||~B)* && ~B;~A=>a]],
    simul = {
        isForever = true,
        nd_acc = 1,
        n_unreachs = 2,
    },
}

-- EX.07: o `and` executa 2 vezes
Test { [[
input int D;
event int a;
loop do
    int v = await D;
    emit a(a+v);
end;
]],
--((a,~D)->add~>a)*]],
    simul = {
        isForever = true,
        n_unreachs = 1,
        --trig_wo = 1,
    },
}

Test { [[
input int A, D, E;
event int a, b, c;
par/or do
    a = 0;
    loop do
        int v = await A;
        emit a(v);
    end;
with
    b = 0;
    loop do
        int v = await D;
        emit b(v+b);
    end;
with
    c = 0;
    loop do
        par/or do
            await a;
        with
            await b;
        end;
        emit c(a+b);
    end;
with
    await E;
    return c;
end;
]],
    simul = {
        n_unreachs = 4,
    },
    --trig_wo = 1,
    run = {
        ['1~>D ; 1~>D ; 3~>A ; 1~>D ; 8~>A ; 1~>E'] = 11,
    }
}

    -- Exemplo apresentacao RSSF
Test { [[
input int A, C;
event int b, d, e;
par/and do
    loop do
        await A;
        emit b(0);
        int v = await C;
        emit d(v);
    end;
with
    loop do
        await d;
        emit e(d);
    end;
end;
]],
    simul = {
        isForever = true,
        n_unreachs = 3,
        --trig_wo = 2,
    },
}

    -- SLIDESHOW
Test { [[
input int A,C,D;
int i;
par/or do
    await A;
    return i;
with
    i = 1;
    loop do
        int o = set
            par do
                await C;
                await C;
                int c = await C;
                return c;
            with
                int d = await D;
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
    simul = {
        n_unreachs = 2,
    },
    run = {
        [ [[
0~>C ; 0~>C ; 0~>C ;  // 2
0~>C ; 0~>C ; 2~>D ;  // 1
0~>C ; 1~>D ;         // 2
0~>C ; 0~>C ; 0~>C ;  // 3
0~>C ; 0~>C ; 0~>C ;  // 4
0~>C ; 0~>C ; 2~>D ;  // 3
1~>D ;                // 4
1~>D ;                // 5
1~>A ;                // 5
]] ] = 5
    }
}

Test { [[
input int A, B, C, D;
int v;
par/and do
    par/and do
        v = await A;
    with
        v = await B;
    end;
with
    par/or do
        await C;
    with
        await D;
    end;
end;
return v;
]],
    run = {
        ['0~>B ; 0~>B ; 1~>A ; 2~>C'] = 1,
        ['0~>B ; 0~>B ; 1~>D ; 2~>A'] = 2,
    }
}
Test { [[
input int A;
int a;
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
    simul = {
        n_unreachs = 1,
    nd_acc = 1,
    --nd_flw = 1,
    },
}
Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a(1);
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
    emit a(1);
with
    await a;
    emit a(a);
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
    emit a(1);
with
    await a;
    await a;
    return 1;
end;
]],
    simul = {
        isForever = true,
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
        emit a(1);
    with
        emit b(1);
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
    simul = {
        isForever = true,
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
        emit a(1);
    with
        emit b(1);
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
    simul = {
        isForever = true,
        n_unreachs = 4,
    },
}

Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a(1);
with
    await a;
    await a;
    // unreachable
with
    await A;
    await a;
    // unreachable
end;
// unreachable
return 0;
]],
    simul = {
        isForever = true,
        --n_unreachs = 3,
        nd_acc = 1,
    },
}

Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a(1);
    emit a(3);
with
    await a;
    await a;
end;
return a;
]],
    run = { ['1~>A']=3 }
}

Test { [[
input int A, B;
int v;
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
    simul = {
        n_unreachs = 1,
    nd_acc = 1,     -- should be 0
    },
    run = {
        ['5~>B ; 4~>B'] = 5,
        ['1~>A ; 0~>A ; 5~>B'] = 5,
    }
}

Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a(8);
with
    await a;
    await a;
    // unreachable
end;
// unreachable
return 0;
]],
    simul = {
        isForever = true,
        n_unreachs = 2,
    },
}
Test { [[
input int A,B;
event int a;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    emit a(1);
with
    par/and do
        nothing;
    with
        await B;
    end;
    await a;
end;
return 0;
]],
    simul = {
        --isForever = true,
        nd_acc = 1,
        --n_unreachs = 2,
    },
}

Test { [[
input int A, B, C;
event int a;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    emit a(1);
with
    par/or do
        await C;
    with
        await B;
    end;
    await a;
end;
return a;
]],
    simul = {
        nd_acc = 1,
    },
}

Test { [[
input int A;
event int a,b;
par/and do
    await A;
    emit a(1);
    emit b(1);
with
    await a;
    await b;
    return 1;
end;
return 0;
]],
    simul = {
        --nd_esc = 1,
    n_unreachs = 2,
    --trig_wo = 1,
    },
    run = { ['1~>A'] = 1 }
}

Test { [[
input int A, B, C, D, E;
int d;
par/or do
    await A;
with
    await B;
end;
await C;
par/and do
    d = await D;
with
    await E;
end;
return d;
]],
    run = {
        ['1~>A ; 0~>C ; 9~>D ; 10~>E'] = 9,
        ['0~>B ; 0~>C ; 9~>E ; 10~>D'] = 10,
    },
}
Test { [[
event int a;
par/and do
    emit a(1);
with
    par/or do
        nothing;
    with
        nothing;
    end;
    await a;
    // unreachable
end;
// unreachable
return 0;
]],
    simul = {
        --isForever = true,
        nd_acc = 1,
        --trig_wo = 1,
        --n_unreachs = 2,
    },
}
Test { [[
event int a;
par/and do
    emit a(1);
with
    par/or do
        nothing;
    with
        await a;
    end;
end;
return 0;
]],
    simul = {
        nd_acc = 1,
    --trig_wo = 1,
    n_unreachs = 1,
    },
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
input int Start;
int v = 0;
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
    await Start;
    emit b;
    emit b;
    emit a;
    return v;
end;
]],
    simul = {
        n_unreachs = 3,
    },
    run = 1,
}

Test { [[
input int Start;
int v = 0;
event int a, b;
par/or do
    loop do
        await a;
        emit b(a);
        v = v + 1;
    end
with
    await Start;
    emit a(1);
    return v;
end;
]],
    run = 1,
    simul = {
        n_unreachs = 2,
    },
}

Test { [[
input int Start;
int v = 0;
event int a, b;
par/or do
    loop do
        par/or do
            await a;
            emit b(a);
            v = v + 1;
        with
            loop do
                await b;
                if b then
                    break;
                end;
            end;
        end;
    end;
with
    await Start;
    emit a(1);
    emit a(1);
    emit a(0);
    return v;
end;
]],
    --nd_esc = 1,
    run = 1,
    simul = {
        n_unreachs = 2,
    },
}

Test { [[
input int A,B,X,F;
int v1=0,v2=0;
par do
    loop do
        par/or do
            await B;
            async do
                int v = v1 + 1;
            end;
        with
            await B;
            async do
                int v = v2 + 1;
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
int v=2;
int ret = set
    async (v) do
        return v + 1;
    end;
return ret + v;
]],
    run = 5,
}

Test { [[
int a = 0;
async (a) do
    a = 1;
    do
        nothing;
    end
end
return a;
]],
    run = 0,
}

Test { [[
input void F;
int v=2;
int ret;
par/or do
    ret = set
        async (v) do        // nd
            return v + 1;
        end;
with
    v = 3;                  // nd
    await F;
end
return ret + v;
]],
    simul = {
        nd_acc = 1,
    },
}

Test { [[
input int A,B,X,F;
int v1=0,v2=0;
par do
    loop do
        par/or do
            await B;
            async (v1) do
                int v = v1 + 1;
            end;
        with
            await B;
            async (v2) do
                int v = v2 + 1;
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
    simul = {
        n_unreachs = 1,
    },
    run = { ['1~>F']=2 },
}

Test { [[
input int A,B,X,F;
int v1=0,v2=0;
par do
    loop do
        par/or do
            await B;
            async do
                int v = v1 + 1;
            end;
        with
            await B;
            async do
                int v = v2 + 1;
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
int v;
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
    simul = {
        n_unreachs = 1,
    },
    run = {
        ['~>A; ~>A; ~>25ms; ~>F'] = 2,
    }
}

Test { [[
input int P2;
par do
    loop do
        par/or do
            int p2 = await P2;
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
    await Forever;      // TODO: ele acha que o async termina
end;
]],
    run = 0,
    simul = {
        n_unreachs = 2,
    },
}

    -- MISC

Test { [[
int v;
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
    simul = {
        nd_acc = 3,
    isForever = true,
    n_unreachs = 4,
    },
}

Test { [[
input void A, B;
int aa=0, bb=0;
par/and do
    await A;
    int a = 1;
    aa = a;
with
    int b = 3;
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
int x;
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
            vis = await occurring;
        end;
    with
        loop do
            par/or do
                await sleeping;
            with
                await sleeping;
            end;
            if sleeping == 0 then
                vis = 1;
            else
                vis = 0;
            end;
        end;
    with
        loop do
            await 100ms;
            emit draw(1);
        end;
    with
        loop do
            await 100ms;
            emit sleeping(1);
            await 100ms;
            emit occurring(1);
        end;
    end;
end;
]],
    simul = {
        n_unreachs = 6,
    },
    run = { ['~>1000ms;1~>F'] = 1 }
}

Test { [[
input int Start;
event int a, b;
int v=0;
par/or do
    loop do
        await a;
        emit b(1);
        v = 4;
    end;
    // unreachable
with
    loop do
        await b;
        v = 3;
    end;
    // unreachable
with
    await Start;
    emit a(1);
    return v;
end;
// unreachable
return 0;
]],
    simul = {
        n_unreachs = 3,
    },
    run = 4,
}

    -- SYNC TRIGGER

Test { [[
input int Start;
event int a;
int v1, v2;
par/and do
    par/or do
        await Start;
        emit a(10);
    with
        await Forever;
    end;
    v1 = a;
with
    par/or do
        await a;
    with
        await Forever;
    end;
    v2 = a+1;
end;
return v1 + v2;
]],
    run = 21,
}

Test { [[
input int Start;
event int a;
par/or do
    loop do
        await a;
        a = a + 1;
    end;
with
    await Start;
    emit a(1);
    emit a(a);
    emit a(a);
    emit a(a);
    emit a(a);
    emit a(a);
end;
return a;
]],
    simul = {
        n_unreachs = 1,
    },
    run = 7,
}

Test { [[
input int Start;
event int a, b;
par/or do
    loop do
        await b;
        b = b + 1;
    end;
with
    await a;
    emit b(1);
    emit b(b);
    emit b(b);
    emit b(b);
    emit b(b);
    emit b(b);
    emit b(b);
with
    await Start;
    emit a(1);
    b = 0;
end;
return b;
]],
    simul = {
        --nd_esc = 1,
    n_unreachs = 2,
    },
    run = 8,
}

Test { [[
input int Start;
event int a;
par/or do
    await Start;
    emit a(0);
with
    await a;
    emit a(a+1);
    await Forever;
end;
return a;
]],
    run = 1,
}

Test { [[
input int Start;
event int a,b;
par/or do
    await Start;
    emit a(0);
with
    await a;
    emit b(a+1);
    a = b + 1;
    await Forever;
with
    await b;
    b = b + 1;
    await Forever;
end;
return a;
]],
    run = 3,
}

Test { [[
input int A, F;
event int c = 0;
par do
    loop do
        await A;
        emit c(c);
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
    simul = {
        n_unreachs = 2,
    },
    run = { ['1~>A;1~>A;1~>A;1~>F'] = 3 },
}

Test { [[
input int Start;
event int a;
par do
    loop do
        await Start;
        emit a(0);
        emit a(a+1);
    end;
with
    int v1,v2;
    par/and do
        v1 = await a;
    with
        v2 = await a;
    end;
    return v1+v2;
end;
]],
    simul = {
        --nd_esc = 1,
        n_unreachs = 4,
        --trig_wo = 1,  -- n_unreachs
    },
    run = 0,
}

Test { [[
input int Start;
event int a;
par do
    loop do
        await Start;
        emit a(0);
        emit a(a+1);
    end;
with
    int v1,v2;
    v1 = await a;
    v2 = await a;
    return v1 + v2;
end;
]],
    simul = {
        --nd_esc = 1,
        n_unreachs = 3,
    },
    run = 1,
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
    emit c(1);
    a = c;
end;
return a;
]],
    simul = {
        n_unreachs = 1,
    },
    run = { ['10~>A'] = 1 },
}

Test { [[
input int Start;
event int a, b, c;
par/or do
    loop do
        await c;
        emit b(c+1);
        a = b;
    end;
with
    loop do
        await b;
        a = b + 1;
    end;
with
    await Start;
    emit c(1);
    a = c;
end;
return a;
]],
    simul = {
        n_unreachs = 2,
    },
    run = 1,
}

Test { [[
input int A, F;
int i = 0;
event int a, b;
par do
    par do
        loop do
            int v = await A;
            emit a(v);
        end;
    with
        loop do
            await a;
            emit b(a);
            await a;
            emit b(a);
        end;
    with
        loop do
            await b;
            emit a(b);
            i = i + 1;
        end;
    end;
with
    await F;
    return i;
end;
]],
    simul = {
        n_unreachs = 3,
        --trig_wo = 1,
    },
    run = { ['1~>A;1~>A;1~>A;1~>A;1~>A;1~>F'] = 5 },
}

Test { [[
input int F;
event int x = 0;
event int y = 0;
int a = 0;
int b = 0;
int c = 0;
par do
    loop do
        await 100ms;
        par/or do
            emit x(x+1);
        with
            emit y(y+1);
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
    simul = {
        n_unreachs = 2,
        --trig_wo = 1,
    },
    run = { ['~>1100ms ; ~>F'] = 132 }
}

Test { [[
input int Start;
event int a, b, c;
int x = 0;
int y = 0;
par/or do
    await Start;
    emit a(0);
with
    await b;
    emit c(0);
with
    par/or do
        await a;
        emit b(0);
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
    simul = {
        n_unreachs = 4,
        --nd_esc = 4,
    },
    run = 3,
}

Test { [[
input int F;
event int x = 0;
event int y = 0;
int a = 0;
int b = 0;
int c = 0;
par do
    loop do
        await 100ms;
        par/or do
            emit x(x+1);
        with
            emit y(y+1);
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
    simul = {
        n_unreachs = 2,
    },
    run = {
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
input int Start;
event int a, b;
par/and do
    await Start;
    emit a(1);
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
input int Start;
event int a;
int b;
par/or do
    await Start;
    emit a(1);
    b = a;
with
    await a;
    b = a + 1;
end;
return b;
]],
    simul = {
        n_unreachs = 1,
    --nd_esc = 1,
    },
    run = 2,
}

Test { [[
input int Start;
event int a;
par do
    await a;
    emit a(1);
    return a;
with
    await Start;
    emit a(2);
    return a;
end;
]],
    simul = {
        --nd_esc = 1,
    n_unreachs = 1,
    --trig_wo = 1,
    },
    run = 1,
}

Test { [[
input int Start;
event int a, b;
par/or do
    loop do
        await a;
        emit b(1);
    end;
with
    await Start;
    emit a(1);
with
    await b;
    emit a(2);
end;
return a;
]],
    simul = {
        --nd_esc = 2,
        n_unreachs = 4,
        --trig_wo = 1,
    },
    run = 2,
}

Test { [[
input int Start;
event int a;
int x = 0;
par do
    await Start;
    emit a(1);
    emit a(2);
    return x;
with
    loop do
        await a;
        x = x + 1;
    end
end
]],
    simul = {
        n_unreachs = 1,
    },
    run = 2,
}
Test { [[
input int Start;
event int a;
int x = 0;
par do
    await Start;
    emit a(1);
    emit a(2);
    return x;
with
    await a;
    x = x + 1;
    await a;
    x = x + 1;
end
]],
    run = 2,
}
Test { [[
input int Start;
event int a;
int x = 0;
par do
    emit a ( 1);
    return x;
with
    loop do
        await a;
        x = x + 1;
    end
end
]],
    todo = 'emit->awake->loop->await',
    simul = {
        nd_acc = 1,
        --nd_flw = 1,
        n_unreachs = 2,
    },
}
Test { [[
input int Start;
event int a, x;
x = 0;
par do
    await Start;
    emit a( 1);
    return x;
with
    await a;
    x = x + 1;
    await a;
    x = x + 1;
with
    await a;
    emit a;
end
]],
    simul = {
        nd_acc = 1,
    },
}

Test { [[
input int Start;
event int a, x, y, vis;
par/or do
    par/and do
        await Start;
        emit x(1);
        emit y(1);
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
    await Start;
    emit a(1);
    emit x(0);
    emit y(0);
    emit vis(1);
    await Forever;
end;
]],
    simul = {
        --trig_wo = 2,
        nd_acc = 2,         -- todo: maybe more
        n_unreachs = 3,
        isForever = true,
    },
}

Test { [[
input int Start, F;
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
    await Start;
    emit a(1);
    emit y(1);
    emit z(1);
    emit vis(1);
with
    await F;
    return a+x+y+z+w;
end;
]],
    simul = {
        --trig_wo = 2,
        n_unreachs = 3,
    },
    run = { ['1~>F']=7 },
}

    -- SCOPE / BLOCK

Test { [[do end;]], parser="ERR : line 1 : after `do´ : invalid statement (or C identifier?)" }
Test { [[do int a; end;]],
    simul = {
        n_reachs = 1,
        isForever = true,
    },
}
Test { [[
do
    int a;
    return 1;
end;
]],
    run = 1
}

Test { [[
do
    int a = 1;
    do
        int a = 0;
    end;
    return a;
end;
]],
    run = 1,
}

Test { [[
input int A, B;
do
    int a = 1;
    int tot = 0;
    par/and do
        int a = 2;
        await A;
        tot = tot + a;
    with
        int a = 5;
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
    int a = 1;
    int b = 0;
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
    int a = 0;
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
int a;
par/or do
    int a;
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
    int b;
    par/or do
        do b=1; end;
    with
        do b=2; end;
    end;
end;
return 0;
]],
    simul = {
        nd_acc = 1,
    },
}

Test { [[
input int A, B;
int i;
do
    par/or do
        i = 0;
        await A;
        i = i + 1;
    with
        nothing;
    end;
end;
await B;
return i;
]],
    simul = {
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
    parser = "ERR : line 1 : after `a´ : expected identifier",
}

Test { [[
input int Start, A;
int ret;
event int a;
par/or do
    do
        int a = 0;
        par/or do
            await Start;
            par/or do
                emit a(40);
            with
                nothing;
            end;
        with
            await a;
            ret = a;
        end;
    end;
    do
        int a = 0;
        await a;
        ret = a;
    end;
with
    await Start;
    a = await A;
end;
return a;
]],
    env = 'ERR : line 10 : event "a" is not declared',
}

Test { [[
input int Start, A;
int ret;
event int a;
par/or do
    do
        event int a = 0;
        par/or do
            await Start;
            par/or do
                emit a(40);
            with
                nothing;
            end;
        with
            await a;
            ret = a;
        end;
    end;
    do
        event int a = 0;
        await a;
        ret = a;
    end;
with
    await Start;
    a = await A;
end;
return a;
]],
    simul = {
        --nd_esc = 2,
    n_unreachs = 3,
    },
    run = { ['10~>A']=10 },
}

Test { [[
input int Start;
int ret;
par/or do
    event int a;
    par/or do
        await Start;
        emit a(5);
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
    simul = {
        --nd_esc = 1,
    n_unreachs = 2,
    },
    run = 5,
}

-- FINALIZE

Test { [[
do
    nothing;
finally
    nothing;
end
return 1;
]],
    --run = 1,
    tight = "ERR : line 1 : `do-finally´ body must await",
}

Test { [[
do
    nothing;
finally
    return 1;
end
return 0;
]],
    props = 'ERR : line 4 : not permitted inside `finally´',
}

Test { [[
do
    nothing;
finally
end
]],
    parser = "ERR : line 3 : after `finally´ : invalid statement (or C identifier?)",
}

Test { [[
do
finally
    nothing;
end
]],
    parser = "ERR : line 1 : after `do´ : invalid statement (or C identifier?)",
}

Test { [[
do
    int a;
finally
    await Forever;
end
]],
    props = "ERR : line 4 : not permitted inside `finally´",
}

Test { [[
do
    int a;
finally
    async do
        nothing;
    end
end
]],
    props = "ERR : line 4 : not permitted inside `finally´",
}

Test { [[
do
    int a;
finally
    return 0;
end
]],
    props = "ERR : line 4 : not permitted inside `finally´",
}

Test { [[
loop do
    do
        int a;
    finally
        break;
    end
end
]],
    props = "ERR : line 5 : not permitted inside `finally´",
}

Test { [[
int ret = 0;
do
    int b;
finally
    a = 1;
    loop do
        break;
    end
    ret = a;
end
return ret;
]],
    env = 'ERR : line 5 : variable/event "a" is not declared',
}

Test { [[
int r = 0;
do
    int a;
finally
    a = set do return 2; end;
    r = a;
end
return r;
]],
    props = "ERR : line 5 : not permitted inside `finally´",
}

Test { [[
int r = 0;
do
    int a;
finally
    int b = 1;
    r = b;
end
return r;
]],
    props = "ERR : line 5 : not permitted inside `finally´",
}

Test { [[
int ret = 0;
do
    nothing;
finally
    int a = 1;
end
return ret;
]],
    props = "ERR : line 5 : not permitted inside `finally´",
}

Test { [[
int ret;
do
    int a = 1;
    nothing;
finally
    a = a + 1;
    ret = a;
end
return ret;
]],
    tight = "ERR : line 2 : `do-finally´ body must await",
    --run = 2,
}

Test { [[
int ret;
do
    int a = 1;
    if 1 then
        await 1s;
    end
finally
    a = a + 1;
    ret = a;
end
return ret;
]],
    tight = "ERR : line 2 : `do-finally´ body must await",
    --run = 2,
}

Test { [[
int ret = 0;
do
    int a;
finally
    a = 1;
    ret = a;
end
return ret;
]],
    tight = "ERR : line 2 : `do-finally´ body must await",
    --run = 1,
}

Test { [[
int a;
par/or do
    do
        int a;
    finally
        a = 1;
    end
with
    a = 2;
end
return a;
]],
    tight = "ERR : line 3 : `do-finally´ body must await",
    --run = 2;
}

Test { [[
int ret;
par/or do
    do
        await 1s;
    finally
        ret = 2;
    end
with
    await 1s;
    ret = 2;
end
return ret;
]],
    simul = {
        nd_acc = 1,
    },
    run = { ['~>1s']=2 },
}

Test { [[
input void A;
int ret = 0;
loop do
    par/or do
        do
            await A;
        finally
            ret = ret + 1;
        end;
        return 0;
    with
        break;
    end
end
return ret;
]],
    run = 1,
    simul = {
        nd_flw = 1,
        n_unreachs = 3,
    },
}

Test { [[
input void A, B;
int ret = 1;
par/or do
    do
        await A;
    finally
        ret = 1;
    end
with
    do
        await B;
    finally
        ret = 2;
    end
end
return ret;
]],
    run = { ['~>A']=2, ['~>B']=1 },
}

Test { [[
input void A, B, C;
int ret = 1;
par/or do
    do
        await A;
    finally
        ret = 1;
    end
with
    do
        await B;
    finally
        ret = 2;
    end
with
    do
        await C;
    finally
        ret = 3;
    end
end
return ret;
]],
    simul = {
        nd_acc = 3,
    },
}

-- TODO: emit int?
--[=[
Test { [[
input void A, B, C;
event void a;
int ret = 1;
par/or do
    do
        await A;
    finally
        emit a;
        ret = ret * 2;
    end
with
    do
        await B;
    finally
        ret = ret + 5;
    end
with
    loop do
        await a;
        ret = ret + 1;
    end
end
return ret;
]],
    simul = {
        n_unreachs = 1,
    },
    run = { ['~>A']=9, ['~>B']=6 },
}
]=]

Test { [[
input void A;
int ret = 1;
par/or do
    do
        ret = ret + 1;
        do
            await A;
        finally
            ret = ret * 3;
        end
    finally
        ret = ret + 5;
    end
with
    await A;
    ret = ret * 2;
end
return ret;
]],
    simul = {
        nd_acc = 2,
    },
}

Test { [[
input void A;
int ret = 1;
par/or do
    do
        ret = ret + 1;
        do
            await A;
        finally
            ret = ret * 3;
        end
    finally
        ret = ret + 5;
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
int ret = 1;
par/or do
    do
        ret = ret + 1;
        do
            await A;
            ret = ret * 100;
        finally
            ret = ret * 3;
        end
    finally
        ret = ret + 5;
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
int ret = 0;
loop do
    do
        par/or do
            do
                await B;
                do
                    int a;
                    await B;
                    ret = ret + 1;
                finally
                    ret = ret + 2;
                end
            finally
                ret = ret + 3;
            end
        with
            await A;
            break;
        end
    finally
        ret = ret + 4;
    end
end
return ret;
]],
    run = { ['~>A']=7 , ['~>B;~>B;~>A']=17, ['~>B;~>A']=9 },
}

Test { [[
int ret = 0;
loop do
    do
        ret = ret + 1;
        break;
    finally
        ret = ret + 4;
    end
end
return ret;
]],
    tight = "ERR : line 3 : `do-finally´ body must await",
}

Test { [[
int ret = 0;
loop do
    do
        await 1s;
        ret = ret + 1;
        break;
    finally
        ret = ret + 4;
    end
end
return ret;
]],
    simul = {
        n_unreachs = 1,
    },
    run = { ['~>1s']=5 },
}

Test { [[
int ret = set do
    int ret = 0;
    loop do
        do
            await 1s;
            ret = ret + 1;
            return ret * 2;
        finally
            ret = ret + 4;  // executed after `return´ assigns to outer `ret´
        end
    end
end;
return ret;
]],
    simul = {
        n_unreachs = 1,
    },
    run = { ['~>1s']=2 },
}

Test { [[
int ret = 0;
par/or do
    await 1s;
with
    do
        await 1s;
    finally
        ret = ret + 1;
    end
end
return ret;
]],
    simul = {
        nd_acc = 1,
    },
    run = { ['~>1s']=1, },
}

Test { [[
int ret = 10;
par/or do
    await 500ms;
with
    par/or do
        await 1s;
    with
        do
            await 1s;
        finally
            ret = ret + 1;
        end
    end
end
return ret;
]],
    simul = {
        n_unreach = 2,
    },
    run = { ['~>1s']=11, },
}

Test { [[
int ret = 10;
par/or do
    await 500ms;
with
    par/or do
        await 1s;
    with
        do
            await 250ms;
            ret = ret + 1;
        finally
            ret = ret + 1;
        end
    end
end
return ret;
]],
    simul = {
        n_unreach = 3,  -- 500ms,1s,finally
    },
    run = { ['~>1s']=12 },
}

-- TODO: bounded loop on finally

    -- ASYNCHRONOUS

Test { [[
input void A;
int ret;
par/or do
   ret = set async do
      return 0;
    end;
with
   await A;
   ret = 1;
end
return ret;
]],
    run = { ['~>A']=0 },
}

Test { [[
async do
    return 1;
end;
return 0;
]],
    props = 'invalid access from async',
}

Test { [[
int a = set async do
    return 1;
end;
return a;
]],
    run = 1,
}

Test { [[
int a=12, b;
async (a) do
    a = 1;
end;
return a;
]],
    run = 12,
}
Test { [[
int a,b;
async (b) do
    a = 1;
end;
return a;
]],
    props = 'invalid access from async',
    --run = 1,
}

Test { [[
int a;
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
    props = 'invalid access from async',
}

Test { [[
par/and do
    int a = set async do
        return 1;
    end;
with
    return 2;
end;
]],
    --nd_flw = 1,
    run = 2,
    simul = {
        n_unreachs = 3,
    },
}

Test { [[
int a;
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
    simul = {
        --nd_acc = 1,
    },
}

Test { [[
async do
    return 1+2;
end;
]],
    props = 'invalid access from async',
}

Test { [[
int a = set async do
    int a = set do
        return 1;
    end;
    return a;
end;
return a;
]],
    run = 1
}

Test { [[
input void A;
int ret;
par/or do
   ret = set async do
      return 0;
    end;
with
   await A;
   ret = 1;
end
return ret;
]],
    run = { ['~>A']=0 },
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
int a;
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
int a;
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
    emit a(1);
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
        nothing;
    end;
end;
]],
    props='not permitted inside `async´'
}
Test { [[
async do
    par/or do
        nothing;
    with
        nothing;
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
    props='break without loop'
}

Test { [[
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
    simul = {
        nd_acc = 1,
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
    run = 3,
}

Test { [[
C do
    int a = 1;
end
int a;
par/or do
    _a = 1;
with
    a = 1;
end
return _a + a;
]],
    run = 2,
    simul = {
        nd_acc = 1,
    },
}

Test { [[
C do
    int a = 1;
end
int a;
deterministic a with _a;
par/or do
    _a = 1;
with
    a = 1;
end
return _a + a;
]],
    parser = 'ERR : line 5 : after `deterministic´ : expected identifier',
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
    simul = {
        nd_acc = 3,
    },
}

Test { [[
int r = set async do
    int i = 100;
    return i;
end;
return r;
]],
    run=100
}

Test { [[
int ret = set async do
    int i = 100;
    int sum = 10;
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
int ret = 0;
int f;
par/or do
    ret = set do
        int sum = 0;
        int i = 0;
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
int ret = 0;
int f;
par/and do
    ret = set async do
        int sum = 0;
        int i = 0;
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
int ret = 0;
int f;
par/or do
    ret = set async do
        int sum = 0;
        int i = 0;
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
            nothing;
        end;
    end;
end;
return 0;
]],
    todo = 'detect termination',
    props='async must terminate'
}

Test { [[
int ret = set async do
    int i = 100;
    i = i - 1;
    return i;
end;
return ret;
]],
    run = 99,
}

Test { [[
int ret = set async do
    int i = 100;
    loop do
        break;
    end;
    return i;
end;
return ret;
]],
    simul = {
        n_unreachs = 1,
    },
    run = 100,
}

Test { [[
int ret = set async do
    int i = 0;
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
int i = set
async do
    int i = 10;
    loop do
        i = i - 1;
        if !i then
            return i;
        end;
    end;
end;
return i;
]],
    simul = {
        n_unreachs = 1,
    },
    run = 0,
}

Test { [[
int i = set
async do
    int i = 10;
    loop do
        i = i - 1;
        if !i then
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
int i = set
async do
    int i = 10;
    loop do
        i = i - 1;
    end;
    return 0;
end;
return i;
]],
    simul = {
        n_unreachs = 3,
    isForever = false,
    },
    dfa = true,
    todo = true,    -- no simulation for async
}

Test { [[
int i = 10;
async do
    loop do
        i = i - 1;
        if !i then
            break;
        end;
    end;
end;
return i;
]],
    props = 'invalid access from async',
}

Test { [[
int sum = set async do
    int i = 10;
    int sum = 0;
    loop do
        sum = sum + i;
        i = i - 1;
        if !i then
            return sum;
        end;
    end;
end;
return sum;
]],
    simul = {
        n_unreachs = 1,
    },
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
int a = 0;
par/or do
    async do
        nothing;
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
    nothing;
end;
return 1;
]],
    simul = {
        n_unreachs = 1,
    },
    run = 1,
}

-- round-robin test
Test { [[
input void A;
int ret = 0;
par/or do
    loop do
        async do
            emit A;
        end
        ret = ret + 1;
    end
with
    par/and do
        int v = set async do
            int v;
            loop i, 5 do
                v = v + i;
            end
            return v;
        end;
        ret = ret + v;
    with
        int v = set async do
            int v;
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
    simul = {
        n_unreachs = 1,
    },
    run = 23,
}

-- HIDDEN
Test { [[
int a = 1;
int* b = &a;
int a = 0;
return *b;
]],
    run = 1,
}

    -- POINTERS & ARRAYS

-- int_int
Test { [[int*p; return p/10;]],  env='invalid operands to binary "/"'}
Test { [[int*p; return p|10;]],  env='invalid operands to binary "|"'}
Test { [[int*p; return p>>10;]], env='invalid operands to binary ">>"'}
Test { [[int*p; return p^10;]],  env='invalid operands to binary "^"'}
Test { [[int*p; return ~p;]],    env='invalid operand to unary "~"'}

-- same
Test { [[int*p; int a; return p==a;]], env='invalid operands to binary "=="'}
Test { [[int*p; int a; return p!=a;]], env='invalid operands to binary "!="'}
Test { [[int*p; int a; return p>a;]],  env='invalid operands to binary ">"'}

-- any
Test { [[int*p; return p||10;]], run=1 }
Test { [[int*p; return p&&0;]],  run=0 }
Test { [[int*p=null; return !p;]], run=1 }

-- arith
Test { [[int*p; return p+p;]],     env='invalid operands to binary'}--TODO: "+"'}
Test { [[int*p; return p+10;]],    env='invalid operands to binary'}
Test { [[int*p; return p+10&&0;]], env='invalid operands to binary' }

-- ptr
Test { [[int a; return *a;]], env='invalid operand to unary "*"' }
Test { [[int a; int*pa; (pa+10)=&a; return a;]], env='invalid operands to binary'}
Test { [[int a; int*pa; a=1; pa=&a; *pa=3; return a;]], run=3 }

Test { [[int  a;  int* pa=a; return a;]], env='invalid attribution' }
Test { [[int* pa; int a=pa;  return a;]], env='invalid attribution' }
Test { [[
int a;
int* pa = set do
    return a;
end;
return a;
]],
    env='invalid attribution'
}
Test { [[
int* pa;
int a = set do
    return pa;
end;
return a;
]],
    env='invalid attribution'
}

Test { [[
int* a;
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
type _char = 1;
int i;
int* pi;
_char c;
_char* pc;
i = c;
c = i;
i = <int> c;
c = <_char> i;
return 10;
]],
    run = 10
}

Test { [[
int* ptr1;
void* ptr2;
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
int* ptr1;
void* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
return 1;
]],
    run = 1,
}

Test { [[
void* ptr1;
int* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
return 1;
]],
    run = 1,
}

Test { [[
char* ptr1;
int* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
return 1;
]],
    run = 1,
}
Test { [[
int* ptr1;
char* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
return 1;
]],
    run = 1,
}

Test { [[
int* ptr1;
_FILE* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
return 1;
]],
    run = 1,
}

Test { [[
int a = 1;
int* b = &a;
*b = 2;
return a;
]],
    run = 2,
}

Test { [[
int a;
int* pa;
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
int b = 1;
int* a = &b;
par/or do
    b = 1;
with
    *a = 0;
end
return b;
]],
    simul = {
        nd_acc = 1,
    },
}

Test { [[
C do
    void f (int* v) {
        *v = 1;
    }
end
int a, b;
int* pb = &b;
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
    run = 2,
    simul = {
        nd_acc = 4,
        nd_call = 3,
    },
}

Test { [[
pure _f;
C do
    void f (int* v) {
        *v = 1;
    }
end
int a, b;
int* pb = &b;
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
    run = 2,
    simul = {
        nd_acc = 2,
    },
}

Test { [[
C do
    void f (int* p) {
        *p = 1;
    }
end
int[2] a;
int b;
par/or do
    b = 2;
with
    _f(a);
end
return a[0] + b;
]],
    run = 3,
}

    -- ARRAYS

Test { [[input int[1] E; return 0;]],
    parser = "ERR : line 1 : after `int´ : expected identifier",
}
Test { [[int[0] v; return 0;]],
    env='invalid array dimension'
}
Test { [[int[2] v; return v;]],
    env = 'invalid attribution'
}
Test { [[u8[2] v; return &v;]],
    env = 'invalid operand to unary "&"',
}

Test { [[int[2] v; v[0]=5; return v[0];]], run=5 }

Test { [[
int[2] v;
v[0] = 1;
v[1] = 1;
return v[0] + v[1];
]],
    run = 2,
}

Test { [[
int[2] v;
int i;
v[0] = 0;
v[1] = 5;
v[0] = 0;
i = 0;
return v[i+1];
]],
    run = 5
}

Test { [[
void a;
void[1] b;
]],
    env = "ERR : line 1 : invalid type",
}

Test { [[
int a;
void[1] b;
]],
    env = "ERR : line 2 : invalid type",
}

Test { [[
C do
    typedef struct {
        int v[10];
        int c;
    } T;
end
type _T = 44;

_T[10] vec;
int i = 110;

vec[3].v[5] = 10;
vec[9].c = 100;
return i + vec[9].c + vec[3].v[5];
]],
    run = 220,
}

Test { [[int[2] v; await v;     return 0;]], env='event "v" is not declared' }
Test { [[int[2] v; emit v;    return 0;]], env='event "v" is not declared' }
Test { [[int[2] v; await v[0];  return 0;]], parser="ERR : line 1 : after `v´ : expected `;´" }
Test { [[int[2] v; emit v[0]; return 0;]], parser="ERR : line 1 : after `v´ : expected `;´" }
Test { [[int[2] v; v=v; return 0;]], env='invalid attribution' }
Test { [[int v; return v[1];]], env='cannot index a non array' }
Test { [[int[2] v; return v[v];]], env='invalid array index' }

Test { [[
int[2] v ;
return v == &v[0] ;
]],
    run = 1,
}

    -- C FUNCS BLOCK

Test { [[
C do
    int V[2][2] = { {1, 2}, {3, 4} };
end

_V[0][1] = 5;
return _V[1][0] + _V[0][1];
]],
    run = 8,
}

Test { [[
C do
    int END = 1;
end
if ! _END-1 then
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
    parser = "ERR : line 2 : after `\"´ : expected `\"´",
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
    parser = "ERR : line 4 : before `A´ : invalid statement (or C identifier?)",
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
C do
    void A (int v) {}
end
_A();
return 0;
]],
    run = false,
}

Test { [[
C do
    void A () {}
end
int v = _A();
return v;
]],
    run = false,
}

Test { [[emit A(10); return 0;]],
    env = 'event "A" is not declared'
}

Test { [[
C do
    int Const () {
        return -10;
    }
end
int ret = _Const();
return ret;
]],
    run = -10
}

Test { [[
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
C do
    int ID (int v) {
        return v;
    }
end
int v = _ID(10);
return v;
]],
    run = 10
}

Test { [[
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
C do
    void VD (int v) {
    }
end
int ret = _VD(10);
return ret;
]],
    run = false,
}

Test { [[
C do
    void VD (int v) {
    }
end
void v = _VD(10);
return v;
]],
    env = 'ERR : line 5 : invalid type'
}

Test { [[
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
C do
    int NEG (int v) {
        return -v;
    }
end
int v = _NEG(10);
return v;
]],
    run = -10
}

Test { [[
C do
    int ID (int v) {
        return v;
    }
end
input int A;
int v;
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
C do
    int ID (int v) {
        return v;
    }
end
input int A;
int v;
par/or do
    await A;
with
    v = _ID(10);
end
return v;
]],
    n_unreachs = 1,
    run = 10,
}

Test { [[
C do int Z1 (int a) { return a; } end
input int A;
int c;
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
C do
    int f1 (u8* v) {
        return v[0]+v[1];
    }
    int f2 (u8* v1, u8* v2) {
        return *v1+*v2;
    }
end
u8[2] v;
v[0] = 8;
v[1] = 5;
return _f2(&v[0],&v[1]) + _f1(v) + _f1(&v[0]);
]],
    run = 39,
}

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
    simul = {
        nd_acc = 1,
        nd_call = 1,
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
    simul = {
        nd_acc = 1,
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
    simul = {
        nd_acc = 1,
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
    simul = {
        nd_acc = 1,
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
    simul = {
        nd_acc = 1,
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
    --run = 10,
    simul = {
        nd_flw = 1,
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
    simul = {
        nd_acc = 1,
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
    simul = {
        nd_acc = 1,
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
    simul = {
        nd_acc = 1,
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
    simul = {
        nd_acc = 1,
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
    nd_call = 1,
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
    simul = {
        nd_acc = 1,     -- 2 (1/stmt)
        nd_call = 1,
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
    simul = {
        nd_acc = 1,     -- TODO: const
        nd_call = 1,
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
    nd_call = 1,
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
    simul = {
        nd_acc = 1,
        nd_call = 1,
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
    simul = {
        nd_acc = 1,
        nd_call = 1,
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
    simul = {
        nd_acc = 1,
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
    nd_call = 1,
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
    run = 1,
}

Test { [[
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
    simul = {
        nd_acc = 1,
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
    simul = {
        nd_call = 6,
        isForever = true,
    },
}

Test { [[
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
    simul = {
        nd_acc = 6,
        nd_call = 6,
        isForever = true,
    },
}

Test { [[
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
    simul = {
        nd_call = 1,
        isForever = true,
    },
}

Test { [[
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
    simul = {
        nd_call = 3,
        isForever = true,
    },
}

Test { [[
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
    simul = {
        nd_call = 1,
        isForever = true,
    },
}

Test { [[
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
    simul = {
        nd_call = 1,
        nd_acc  = 3,
        isForever = true,
    },
}

Test { [[
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
    simul = {
        nd_call = 1,
        nd_acc  = 3,
        isForever = true,
    },
}

Test { [[
deterministic F with G;
output void F,G;
par do
    emit F;
with
    emit G;
end
]],
    simul = {
        isForever = true,
    },
}

    -- STRINGS

Test { [[char* a = "Abcd12" ; return 1;]], run=1 }
Test { [[
_printf("END: %s\n", "Abcd12");
return 0;
]],
    run='Abcd12',
}
Test { [[return _strlen("123");]], run=3 }
Test { [[_printf("END: 1%d\n",2); return 0;]], run=12 }
Test { [[_printf("END: 1%d%d\n",2,3); return 0;]], run=123 }

Test { [[
type _char = 1;
_char[10] str;
_strncpy(str, "123", 4);
_printf("END: %d %s\n", _strlen(str), str);
return 0;
]],
    run = '3 123'
}

Test { [[
type _char = 1;
_char[6] a; _strcpy(a, "Hello");
_char[2] b; _strcpy(b, " ");
_char[7] c; _strcpy(c, "World!");
_char[30] d;

int len = 0;
_strcpy(d,a);
_strcpy(&d[_strlen(d)], b);
_strcpy(&d[_strlen(d)], c);
_printf("END: %d %s\n", _strlen(d), d);
return 0;
]],
    run = '12 Hello World!'
}

Test { [[
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
C do
    int inv (int v) {
        return -v;
    }
end
int a;
a = _inv(_inv(1));
return a;
]],
    run = 1,
}

Test { [[
C do
    int id (int v) {
        return v;
    }
end
int a;
a = _id(1);
return a;
]],
    run = 1
}

Test { [[
int[2] v;
par/or do
    v[0] = 1;
with
    v[1] = 2;
end;
return 0;
]],
    simul = {
        nd_acc = 1,
    },
}
Test { [[
int[2] v;
int i,j;
par/or do
    v[j] = 1;
with
    v[i+1] = 2;
end;
return 0;
]],
    simul = {
        nd_acc = 1,
    },
}

-- STRUCTS

Test { [[
C do
typedef struct {
    u16 a;
    u8 b;
    u8 c;
} s;
end
type _s = 4;
_s vs;
vs.a = 10;
vs.b = 1;
return vs.a + vs.b + sizeof<_s>;
]],
    run = 15,
}

Test { [[
C do
    typedef struct {
        u16 ack;
        u8 data[16];
    } Payload;
end
type _Payload = 18;
_Payload final;
u8* neighs = &(final.data[4]);
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
type _s = 8;
_s vs;
par/and do
    vs.a = 10;
with
    vs.a = 1;
end;
return vs.a;
]],
    simul = {
        nd_acc = 1,
    },
}

Test { [[
C do
typedef struct {
    int a;
    int b;
} s;
end
type _s = 8;
_s vs;
par/and do
    vs.a = 10;
with
    vs.b = 1;
end;
return vs.a;
]],
    simul = {
        nd_acc = 1,     -- TODO: struct
    },
}

Test { [[
C do
    typedef struct {
        int a;
    } mys;
end
type _mys = 4;
_mys v;
_mys* pv;
pv = &v;
v.a = 10;
(*pv).a = 20;
pv->a = pv->a + v.a;
return v.a;
]],
    run = 40,
}

Test { [[
]],
    parser = "ERR : line 1 : after `BOF´ : invalid statement (or C identifier?)",
}

-- Exps

Test { [[int a = ]],
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
int a;
a = set do
    int b;
end
]],
    parser = "ERR : line 4 : after `end´ : expected `;´",
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
    props = "ERR : line 3 : not permitted inside `async´",
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
    props = "ERR : line 4 : not permitted inside `async´",
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
    props = "ERR : line 2 : not permitted inside `async´",
}

-- DFA

Test { [[
int a;
]],
    simul = {
        n_reachs = 1,
        isForever = true,
    },
}

Test { [[
int a;
a = set do
    int b;
end;
]],
    simul = {
        n_reachs = 2,
        isForever = true,
    },
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
    simul = {
        nd_acc = 1,
    },
}

    -- MEM

--[[
0-3: $ret
]]

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
     4-6:       d,e,f
]]

Test { [[
do
    int a, b, c;
end
u8 d, e, f;
return 0;
]],
    tot = 16,
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
    tot = 17,
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
    simul = {
        nd_acc = 6,
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
    simul = {
        nd_acc = 7,
        tot = 28,
        run = 33;
    },
}

Test { [[
input void A, B, C;
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
    await C;
    ret = ret + a;
end
]],
    simul = {
        tot = 21,
        isForever = true,
    },
}

Test { [[
input void A, B, C;
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
    await C;
    ret = ret + a;
end
return ret;
]],
    tot = 24,
    run = {
        ['~>A;~>B;~>C'] = 1110,
        ['~>B;~>A;~>C'] = 1110,
        ['~>C;~>B;~>A'] = 1110,
    }
}
Test { [[
input void A, B, C;
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
        await C;
        ret = ret + a;
    end
end
]],
    tot = 21,
    run = {
        ['~>A;~>B;~>C'] = 10,
        ['~>B;~>B;~>A;~>C'] = 110,
        ['~>C;~>B;~>C;~>A'] = 2110,
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
    simul = {
        tot = 12,
        isForever = true,
    }
}
print('COUNT', COUNT)

do return end

    -- SUSPEND

Test { [[
input void A;
suspend on A do
    nothing;
end
return 0;
]],
    env = 'invalid suspend event type',
}

Test { [[
input int A;
suspend on A do
    nothing;
end
return 1;
]],
    run = 1,
}

Test { [[
input int A;
input int B;
suspend on A do
    int v = await B;
    return v;
end
]],
    run = {
        ['1~>B'] = 1,
        ['0~>A ; 1~>B'] = 1,
        ['1~>A ; 1~>B ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 0~>A ; 1~>A ; 2~>B ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 0~>A ; 1~>A ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 1~>A ; 2~>B ; 0~>A ; 3~>B'] = 3,
    },
}

Test { [[
input int  A;
input int  B;
input void C;
suspend on A do
    await C;
_printf("oi\n");
    int v = await B;
    return v;
end
]],
    run = {
        ['~>C ; 1~>B'] = 1,
        ['0~>A ; 1~>B ; ~>C ; 2~>B'] = 2,
        ['~>C ; 1~>A ; 1~>B ; 0~>A ; 3~>B'] = 3,
        ['~>C ; 1~>A ; 1~>B ; 1~>A ; 2~>B ; 0~>A ; 3~>B'] = 3,
    },
}
