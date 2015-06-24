local function INCLUDE (fname, src)
    local f = assert(io.open(fname,'w'))
    f:write(src)
    f:close()
end

----------------------------------------------------------------------------
-- NO: testing
----------------------------------------------------------------------------

--[===[
do return end
--]===]
-------------------------------------------------------------------------------

----------------------------------------------------------------------------
-- OK: well tested
----------------------------------------------------------------------------

Test { [[escape (1);]], run=1 }
Test { [[escape 1;]], run=1 }

Test { [[escape 1; // return 1;]], run=1 }
Test { [[escape /* */ 1;]], run=1 }
Test { [[escape /*

*/ 1;]], run=1 }
Test { [[escape /**/* **/ 1;]], run=1 }
Test { [[escape /**/* */ 1;]],
    parser = "line 1 : after `escape´ : expected expression"
}

Test { [[
do do do do do do do do do do do do do do do do do do do do
end end end end end end end end end end end end end end end end end end end end
escape 1;
]],
    run = 1
}

Test { [[
do do
end end
escape 1;
]],
    --ast = 'line 2 : max depth of 127',
    run = 1
}
Test { [[
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
do do do do do do do do do do do do do do do do do do do do
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
end end end end end end end end end end end end end end end end end end end end
escape 1;
]],
    --ast = 'line 2 : max depth of 127',
    run = 1
}

Test { [[
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
escape 1;
]],
    ast = 'line 5 : max depth of 0xFF',
}

Test { [[escape 0;]], run=0 }
Test { [[escape 9999;]], run=9999 }
Test { [[escape -1;]], run=-1 }
Test { [[escape --1;]], run=1 }
Test { [[escape - -1;]], run=1 }
Test { [[escape -9999;]], run=-9999 }
Test { [[escape 'A';]], run=65, }
Test { [[escape (((1)));]], run=1 }
Test { [[escape 1+2*3;]], run=7 }
Test { [[escape(4/2*3);]], run=6 }
Test { [[escape 2-1;]], run=1 }

Test { [[escape 1==2;]], run=0 }
Test { [[escape 0  or  10;]], run=1 }
Test { [[escape 0 and 10;]], run=0 }
Test { [[escape 2>1 and 10!=0;]], run=1 }
Test { [[escape (1<=2) + (1<2) + 2/1 - 2%3;]], run=2 }
-- TODO: linux gcc only?
--Test { [[escape (~(~0b1010 & 0XF) | 0b0011 ^ 0B0010) & 0xF;]], run=11 }
Test { [[nt a;]],
    parser = "line 1 : after `nt´ : expected `;´",
}
Test { [[nt sizeof;]],
    parser = "line 1 : after `nt´ : expected `;´",
}
Test { [[var int sizeof;]],
    parser = "line 1 : after `int´ : expected identifier",
}
Test { [[escape sizeof(int);]], run=4 }
Test { [[escape 1<2>3;]], run=0 }

Test { [[var int a;]],
    ana = 'line 1 : missing `escape´ statement for the block',
}

Test { [[var int a;]],
    wrn = true,
    _ana = {
        reachs = 1,
        isForever = true,
    }
}

Test { [[
var int a, b;
escape 10;
]],
    run = 10,
}

Test { [[a = 1; escape a;]],
    env = 'variable/event "a" is not declared',
}
Test { [[var int a; a = 1; escape a;]],
    run = 1,
}
Test { [[var int a = 1; escape a;]],
    run = 1,
}
Test { [[var int a = 1; escape (a);]],
    run = 1,
}
Test { [[var int a = 1;]],
    wrn = true,
    _ana = {
        reachs = 1,
        isForever = true,
    }
}
Test { [[var int a=1;var int a=0; escape a;]],
    env = 'line 1 : declaration of "a" hides the one at line 1',
}
Test { [[var int a=1;var int a=0; escape a;]],
    --env = 'line 1 : variable/event "a" is already declared at line 1',
    wrn = true,
    run = 0,
}
Test { [[var int b=2; var int a=1; b=a; var int a=0; escape b+a;]],
    wrn = true,
    --env = 'line 1 : variable/event "a" is already declared at line 1',
    run = 1,
}
Test { [[do var int a=1; end var int a=0; escape a;]],
    run = 0,
}
Test { [[var int a=1,a=0; escape a;]],
    wrn = true,
    --env = 'line 1 : variable/event "a" is already declared at line 1',
    run = 0,
}
Test { [[var int a; a = b = 1]],
    parser = "line 1 : after `b´ : expected `;´",
}
Test { [[var int a = b; escape 0;]],
    env = 'variable/event "b" is not declared',
}
Test { [[escape 1;2;]],
    parser = "line 1 : before `;´ : expected statement",
}
Test { [[var int aAa; aAa=1; escape aAa;]],
    run = 1,
}
Test { [[var int a; a=1; escape a;]],
    run = 1,
}
Test { [[var int a; a=1; a=2; escape a;]],
    run = 2,
}
Test { [[var int a; a=1; escape a;]],
    run = 1,
}
Test { [[var int a; a=1 ; a=a; escape a;]],
    run = 1,
}
Test { [[var int a; a=1 ; ]],
    wrn = true,
    _ana = {
        reachs = 1,
        isForever = true,
    }
}

Test { [[
inputintMY_EVT;
ifv==0thenbreak;end
]],
    parser = 'line 2 : after `0´ : expected `;´',
}
Test { [[
inputintMY_EVT;
escape 1;
]],
    env = 'line 1 : variable/event "inputintMY_EVT" is not declared',
}

Test { [[
// input event identifiers must be all in uppercase
// 'MY_EVT' is an event of ints
native_printf();
escape 0;
]],
    env = 'line 3 : variable/event "native_printf" is not declared',
}

Test { [[
native_printf();
loopdo await250ms;_printf("Hello World!\n");end
]],
    parser = 'line 2 : after `loopdo´ : expected `;´',
}

-- TYPE / BOOL

Test { [[
input void A;
var bool a? = 1;
a? = 2;
escape a?;
]],
    parser = 'line 2 : after `a´ : expected `with´',
    --run = 2,
}

Test { [[
input void A;
var bool a = 1;
a = 2;
escape a;
]],
    run = 2,
}

Test { [[
var bool v = true;
v = false;
if v then
    escape 1;
else
    escape 2;
end
]],
    run = 2,
}

Test { [[
var bool v = false;
v = true;
if v then
    escape 1;
else
    escape 2;
end
]],
    run = 1,
}

-- TYPE / NATIVE / ANON

Test { [[
escape 1;
native do end
]],
    run = 1,
}

Test { [[
native do
    int _ = 3;
end
native @const __;

var int _ = 1;
var int _ = 2;

escape __;
]],
    --env = 'line 6 : invalid access to `_´',
    env = 'line 6 : variable/event "_" is not declared',
    --run = 3,
}
Test { [[
native do
    int _ = 3;
end
native @const __;
native @const _;      // `_´ is special (not C)

var int _ = 1;
var int _ = 2;

escape __;
]],
    parser = 'line 5 : after `@const´ : expected declaration',
    --run = 3,
}
Test { [[
native do
    int _ = 3;
end
native @const __;

var int _;
var int _;
do
    var char _;
end

escape (int) __;
]],
    run = 3,
}

Test { [[
native _abc = 0;
event void a;
var _abc b;
]],
    env = 'line 3 : cannot instantiate type "_abc"',
}

Test { [[
native _abc;
native do
    typedef u8  abc;
end
event void a;
var _abc b;
escape 1;
]],
    run = 1,
}

Test { [[
native _abc = 0;
event void a;
var _abc a;
]],
    wrn = true,
    --env = 'line 3 : variable/event "a" is already declared at line 2',
    env = 'line 3 : cannot instantiate type "_abc"',
}

Test { [[
input void A;
var int a = 1;
a = 2;
escape a;
]],
    run = 2,
}

Test { [[
input void A;
var word a = 1;
a = 2;
escape a;
]],
    run = 2,
}

Test { [[
input void A;
var byte a = 1;
a = 2;
escape a;
]],
    run = 2,
}

Test { [[
escape 0x1 + 0X1 + 001;
]],
    run = 3,
}

Test { [[
escape 0x1 + 0X1 + 0a01;
]],
    env = 'line 1 : malformed number',
}

Test { [[
escape 1.;
]],
    run = 1,
}

Test { [[
var float x = 1.5;
escape x + 0.5;
]],
    run = 2,
}

Test { [[
var uint x = 1.5;
escape x + 0.5;
]],
    run = 1,
}

Test { [[
var char x = 1.5;
escape x + 0.5;
]],
    run = 1,
}

Test { [[
var char x = 255;
escape x + 0.5;
]],
    run = 0,
}

Test { [[

                            if (_ISPOINTER(check) && ((check:x+_MINDIST) >> 
                                _TILESHIFT) == tilex ) then
                                escape 0;
end
]],
    env = 'line 2 : variable/event "check" is not declared',
}

    -- IF

Test { [[if 1 then escape 1; end; escape 0;]],
    _ana = {
        isForever = false,
    },
    run = 1,
}
Test { [[if 0 then escape 0; end  escape 1;]],
    run = 1,
}
Test { [[if 0 then escape 0; else escape 1; end]],
    _ana = {
        isForever = false,
    },
    run = 1,
}
Test { [[if (0) then escape 0; else escape 1; end;]],
    run = 1,
}
Test { [[if (1) then escape (1); end]],
    _ana = {
        reachs = 1,
    },
    run = 1,
}
Test { [[
if (0) then
    escape 1;
end
escape 0;
]],
    run = 0,
}
Test { [[
var int a = 1;
if a == 0 then
    escape 1;
else/if a > 0 then
    escape 0;
else
    escape 1;
end
escape 0;
]],
    _ana = {
        unreachs = 1,
    },
    run = 0,
}
Test { [[
var int a = 1;
if a == 0 then
    escape 0;
else/if a < 0 then
    escape 0;
else
    a = a + 2;
    if a < 0 then
        escape 0;
    else/if a > 1 then
        escape 1;
    else
        escape 0;
    end
    escape 1;
end
escape 0;
]],
    _ana = {
        unreachs = 2,
    },
    run = 1,
}
Test { [[if (2) then  else escape 0; end;]],
    _ana = {
        reachs = 1,
    },
    run = 0,    -- TODO: may be anything
}

-- IF vs SEQ priority
Test { [[if 1 then var int a; escape 2; else escape 3; end;]],
    run = 2,
}

Test { [[
if 0 then
    escape 1;
else
    if 1 then
        escape 1;
    end
end;]],
    _ana = {
        reachs = 1,
    },
    run = 1,
}
Test { [[
if 0 then
    escape 1;
else
    if 0 then
        escape 1;
    else
        escape 2;
    end
end;]],
    _ana = {
        isForever = false,
    },
    run = 2,
}
Test { [[
var int a = 0;
var int b = a;
if b then
    escape 1;
else
    escape 2;
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
escape a;
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
escape a;
]],
    run = 2,
}
Test { [[
var int a;
if 0 then
    escape 1;
else
    a=1;a=2; escape 3;
end;
]],
    run = 3,
}
Test { [[
var int a = 0;
if (0) then
    a = 1;
end
escape a;
]],
    run = 0,
}

    -- EVENTS

Test { [[input int A=1;]], parser="line 1 : after `A´ : expected `;´" }
Test { [[
input int A;
A=1;
escape 1;
]],
    --adj = 'line 2 : invalid expression',
    --parser = 'line 1 : after `;´ : expected statement',
    parser = 'line 1 : after `;´ : expected statement (usually a missing `var´ or C prefix `_´)',
}

Test { [[input  int A;]],
    _ana = {
        reachs = 1,
        isForever = true,
    },
}
Test { [[input int A,A; escape 0;]],
    --env = 'event "A" is already declared',
    run = 0,
}
Test { [[input int A,A; escape 0;]],
    wrn = true,
    --env = 'event "A" is already declared',
    run = 0,
}
Test { [[
input int A,B,Z;
]],
    _ana = {
        reachs = 1,
        isForever = true,
    },
}

Test { [[await A; escape 0;]],
    env = 'event "A" is not declared',
}

Test { [[
input void A;
par/or do
    await A;
with
    async do
        emit A;
    end
end
escape 1;
]],
    run = 1,
}
Test { [[
input void A;
await A;
escape 1;
]],
    run = { ['~>A']=1 },
}
Test { [[
input void A;
par/and do
    await A;
with
    nothing;
end
escape 1;
]],
    run = { ['~>A']=1 },
}

Test { [[
input int A;
par/or do
    await A;
with
    async do
        emit A=>10;
    end
end;
escape 10;
]],
    _ana = {
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
        emit A => 10;
    end;
end
escape ret;
]],
    run = 10
}

Test { [[
input int A;
par/and do
    await A;
with
    async do
        emit A => 10;
    end;
end;
escape A;
]],
    parser = "line 9 : after `escape´ : expected expression",
    --adj = 'line 9 : invalid expression',
}

Test { [[
input int A;
var int v;
par/and do
    v = await A;
with
    async do
        emit A => 10;
    end;
end;
escape v;
]],
    _ana = {
        isForever = false,
    },
    run = 10,
}

Test { [[
input int A;
var int v = await A;
escape v;
]],
    run = {
        ['101~>A'] = 101,
        ['303~>A'] = 303,
    },
}

Test { [[var int a = a+1; escape a;]],
    --env = 'variable/event "a" is not declared',
    todo = 'TODO: deveria dar erro!',
    run = 1,
}

Test { [[var int a; a = emit a => 1; escape a;]],
    --parser = 'line 1 : after `=´ : expected expression',
    parser = "line 1 : after `emit´ : expected event",
    --trig_wo = 1,
}

Test { [[var int a; emit a => 1; escape a;]],
    env = 'line 1 : event "a" is not declared',
    --trig_wo = 1,
}
Test { [[event int a=0; emit a => 1; escape a;]],
    parser = 'line 1 : after `a´ : expected `;´',
    --trig_wo = 1,
}
Test { [[
event int a;
emit a => 1;
escape a;
]],
    env = 'line 3 : types mismatch (`int´ <= `void´)',
    --run = 1,
    --trig_wo = 1,
}

Test { [[
input void OS_START;
event void e;
every OS_START do
    loop i in 10 do
        emit e;
    end
    do break; end
end
escape 10;
]],
    props = 'line 7 : not permitted inside `every´',
}

Test { [[
input void OS_START;
event void e;
loop do
    await OS_START;
    loop i in 10 do
        emit e;
    end
    do break; end
end
escape 10;
]],
    ana = 'line 3 : `loop´ iteration is not reachable',
    run = 10,
}

Test { [[
input void OS_START;
event void e;
loop do
    await OS_START;
    loop i in 10 do
        emit e;
    end
    do break; end
end
escape 10;
]],
    --ana = 'line 3 : `loop´ iteration is not reachable',
    wrn = true,
    run = 10,
}

Test { [[
var int a=10;
do
    var int b=1;
end
escape a;
]],
    run = 10,
}

Test { [[
input void OS_START;
do
    var int v = 0;
end
event void e;
par do
    await OS_START;
    emit e;
    escape 1;       // 9
with
    await e;
    escape 2;       // 12
end
]],
    _ana = {
        excpt = 1,
        --unreachs = 1,
    },
    run = 2,
}
Test { [[
input void OS_START;
do
    var int v = 0;
end
event void e;
par do
    await OS_START;
    emit e;
    escape 1;       // 9
with
    await e;
    escape 2;       // 12
end
]],
    safety = 2,
    _ana = {
        acc   = 1,
        excpt = 1,
        --unreachs = 1,
    },
    run = 2,
}

Test { [[
input void OS_START;
event void a, b, c, d;
native _assert();
var int v=0;
par do
    loop do
        await OS_START;
        v = 0;
        emit a;
        v = 1;
        escape v;
    end
with
    loop do
        await a;
        v = 2;
    end
end
]],
    wrn = true,
    run = 1,
}

Test { [[
input void OS_START;
event void a, b, c, d;
native _assert();
var int v=0;
par do
    loop do
        await OS_START;
        v = 0;
        emit a;
        v = 1;
        escape v;
    end
with
    loop do
        await a;
        v = 2;
    end
end
]],
    safety = 2,
    wrn = true,
    run = 1,
    _ana = {
        acc = 3,
    },
}

Test { [[
input int E;
var int x;
loop do
    var int tmp = await E;
    if tmp == 0 then
        break;              // non-ceu code might have cleared x on stack
    end
    x = tmp;
end
escape x;
]],
    run = { ['1~>E; 2~>E;0~>E']=2 }
}

Test { [[
native do ##include <assert.h> end
input void OS_START;
event void a, b, c, d;
native _assert();
var int v=0;
par do
    loop do
        await OS_START;
        emit a;         // killed
        _assert(0);
    end
with
    loop do
        await a;
        escape 1;       // kills emit a
    end                 // unreach
end
]],
    _ana = {
        unreachs = 1,
        excpt = 1,
    },
    run = 1,
}

Test { [[
input void OS_START;
event void a,b;
par do
    await OS_START;
    emit a;
    escape 10;
with
    await a;
    emit b;
    escape 100;
end
]],
    run = 100;
}

    -- WALL-CLOCK TIME / WCLOCK

Test { [[await 0ms; escape 0;]],
    sval = 'line 1 : constant is out of range',
}
Test { [[
input void A;
await A;
escape 0;
]],
    run = { ['~>10ms; ~>A'] = 0 }
}

Test { [[await -1ms; escape 0;]],
    --ast = "line 1 : after `await´ : expected event",
    parser = 'line 1 : after `1´ : expected `;´',
}

Test { [[await 1; escape 0;]],
    parser = 'line 1 : after `1´ : expected <h,min,s,ms,us>',
}
Test { [[await -1; escape 0;]],
    env = 'line 1 : event "?" is not declared',
}

Test { [[var s32 a=await 10s; escape a==8000000;]],
    _ana = {
        isForever = false,
    },
    run = {
        ['~>10s'] = 0,
        ['~>9s ; ~>9s'] = 1,
    },
}

Test { [[await FOREVER;]],
    _ana = {
        isForever = true,
    },
}
Test { [[await FOREVER; await FOREVER;]],
    parser = "line 1 : before `;´ : expected event",
}
Test { [[await FOREVER; escape 0;]],
    parser = "line 1 : before `;´ : expected event",
}

Test { [[emit 1ms; escape 0;]],
    props = 'invalid `emit´'
}

Test { [[
var int a;
a = async do
    emit 1min;
end;
escape a + 1;
]],
    todo = 'async nao termina',
    run = false,
}

Test { [[
async do
end
escape 10;
]],
    _ana = {
        isForever = false,
    },
    run = 10,
}

Test { [[
var int a = 0;
async do
    emit 1min;
    escape 10;
end;
escape a + 1;
]],
    --env = 'line 1 : variable/event "_ret" is not declared',
    props = 'line 4 : not permitted inside `async´',
}

Test { [[
var int a;
var int& pa = a;
async (pa) do
    emit 1min;
    pa = 10;
end;
escape a + 1;
]],
    run = 11,
}

-- Seq

Test { [[
input int A;
var int v = await A;
escape v;
]],
    run = { ['10~>A']=10 },
}
Test { [[
input int A,B;
await A;
var int v = await B;
escape v;
]],
    run = {
        ['3~>A ; 1~>B'] = 1,
        ['1~>B ; 2~>A ; 3~>B'] = 3,
    }
}
Test { [[
var int a = await 10ms;
a = await 20ms;
escape a;
]],
    run = {
        ['~>20ms ; ~>11ms'] = 1000,
        ['~>20ms ; ~>20ms'] = 10000,
    }
}
Test { [[
var int a = await 10us;
a = await 40us;
escape a;
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
escape 0;
]],
    _ana = {
        unreachs = 2,
        isForever = true,
    },
}

Test { [[
var int ret;
par/or do
    ret = 1;
with
    ret = 2;
end
escape ret;
]],
    _ana = {
        acc = 1,
    },
    run = 1,
}

Test { [[
var int ret;
par/or do
    await FOREVER;
with
    ret = 2;
end
escape ret;
]],
    run = 2,
}

Test { [[
var int ret;
par/or do
    par/or do
        await FOREVER;
    with
        ret = 1;
    end
with
    ret = 2;
end
escape ret;
]],
    _ana = {
        acc = 1,
    },
    run = 1,
}

Test { [[
var int ret;
par/or do
    ret = 2;
with
    par/or do
        await FOREVER;
    with
        ret = 1;
    end
end
escape ret;
]],
    _ana = {
        acc = 1,
    },
    run = 2,
}

Test { [[
var int ret;
par/or do
    await FOREVER;
with
    par/or do
        await FOREVER;
    with
        ret = 1;
    end
end
escape ret;
]],
    run = 1,
}

Test { [[
input void F;
var int ret = 0;
par/or do
    await 2s;   // 4
    ret = 10;
    await F;    // 6
with
    await 1s;   // 8
    ret = 1;
    await F;    // 10
end
escape ret;
]],
    _ana = {
        acc = 1,  -- false positive
        abrt = 3,
    },
    run = { ['~>1s; ~>F']=1 },
}

Test { [[
par/or do
    await 1s;       // 2
with
    await 1s;       // 4
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
escape 0;
]],
    _ana = {
        unreachs = 2,
        isForever =  true,
        abrt = 3,
    },
}

Test { [[
par do
    await FOREVER;
with
    await 1s;
end
]],
    _ana = {
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
    _ana = {
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
    _ana = {
        reachs = 1,
        isForever = true,
    },
}

Test { [[
par do
    await 1s;
    await 1s;
    escape 1;   // 4
with
    await 2s;
    escape 2;   // 7
end
]],
    _ana = {
        acc = 1,
        abrt = 4,
    },
    run = { ['~>2s']=1 }
}

Test { [[
input void F;
var int a = 0;
loop do
    par/or do       // 4
        await 2s;
    with
        a = a + 1;          // 7
        await F;
        break;
    with
        await 1s;   // 11
        loop do
            a = a * 2;      // 13
            await 1s;   // 14
        end
    end
end
escape a;
]],
    _ana = {
        abrt = 2,
    },
    run = { ['~>5s; ~>F']=14 },
}

Test { [[
input void F;
var int a = 0;
loop do
    par/or do       // 4
        await 2s;
    with
        a = a + 1;          // 7
        await F;
        break;
    with
        await 1s;   // 11
        loop do
            a = a * 2;      // 13
            await 1s;   // 14
        end
    end
end
escape a;
]],
    _ana = {
        abrt = 2,
        acc  = 3,
    },
    run = { ['~>5s; ~>F']=14 },
    safety = 2,
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
    _ana = {
        isForever = true,
        --acc = 1,
        abrt = 2,
    },
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
    escape v1 + v2;
with
    async do
        emit 5ms;
        emit(5000)ms;
    end
end
]],
    _ana = {
        isForever = false,
        abrt = 3,
    },
    run = 5,
    --run = 3,
    --todo = 'nd excpt',
}

Test { [[
input int A;
await A;
await A;
var int v = await A;
escape v;
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
escape ret;
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
escape v;
]],
    run = {
        ['1~>A ; 0~>A'] = 1,
    },
}

Test { [[
input int A;
var int v = 0;
if 0 then
    v = await A;
end;
escape v;
]],
    run = 0,
}

Test { [[
par/or do
    await FOREVER;
with
    escape 1;
end
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
    },
    run = 1,
}

Test { [[
var int a = do
    var int a = do
        escape 1;
    end;
    escape a;
end;
escape a;
]],
    wrn = true,
    run = 1
}

Test { [[
event int aa;
var int a;
par/and do
    a = do
        escape 1;
    end;
with
    await aa;
end;
escape 0;
]],
    _ana = {
        --unreachs = 2,
        --isForever = true,
    },
}

Test { [[
event int a;
par/and do
    a = do
        escape 1;
    end;
with
    await a;
end;
escape 0;
]],
    env = 'line 4 : types mismatch (`void´ <= `int´)',
}

Test { [[
input void A,B;
par/or do
    await A;
    await FOREVER;
with
    await B;
    escape 1;
end;
]],
    _ana = {
        unreachs = 1,
    },
    run = { ['~>A;~>B']=1, },
}

Test { [[
par/and do
with
    escape 1;
end
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
    },
    run = 1,
}
Test { [[
par do
with
    escape 1;
end
]],
    run = 1,
    _ana = {
        abrt = 1,
    },
}
Test { [[
par do
    await 10ms;
with
    escape 1;
end
]],
    _ana = {
        abrt = 1,
        --unreachs = 1,
    },
    run = 1,
}
Test { [[
input int A;
par do
    async do end
with
    await A;
    escape 1;
end
]],
    run = { ['1~>A']=1 },
}

Test { [[
par do
    async do end
with
    escape 1;
end
]],
    todo = 'async dos not exec',
    _ana = {
        --unreachs = 1,
    },
    run = 1,
}

Test { [[
par do
    await FOREVER;
with
    escape 1;
end;
]],
    run = 1,
    _ana = {
        abrt = 1,
    },
}

Test { [[
input void A,B;
par do
    await A;
    await FOREVER;
with
    await B;
    escape 1;
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
escape a;
]],
    _ana = {
        --unreachs = 1,
        abrt = 1,
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
    _ana = {
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
    _ana = {
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
escape a;
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
                    escape v; //  8
                with
                    v = await A;
                end;
                escape v;     // 12
            with
                var int v = await B;
                escape v;     // 15
            end;
        with
            await F;
        end;
        escape 0;
    end;
escape a;
]],
    wrn = true,
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
                    escape v; //  8
                with
                    v = await A;
                end;
                escape v;     // 12
            with
                var int v = await B;
                escape v;     // 15
            end;
        with
            await F;
        end;
        escape 0;
    end;
escape a;
]],
    wrn = true,
    run = {
        ['1~>B; ~>20ms; 1~>F'] = 1,
        ['~>20ms; 5~>B; 2~>F'] = 10000,
    },
    safety = 2,
    _ana = {
        acc = 2,
    },
}

Test { [[
input int A,B,F;
var int a = do
        par/or do
            par do
                var int v;
                par/or do
                    var int v = await 10ms;
                    escape v;
                with
                    v = await A;
                end;
                escape v;
            with
                var int v = await B;
                escape v;
            end;
            // unreachable
            await FOREVER;
        with
            await F;
        end;
        escape 0;
    end;
escape a;
]],
    -- TODO: melhor seria: unexpected statement
    parser = "line 16 : after `;´ : expected `with´",
    --unreachs = 1,
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
escape 100;
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
escape b;
]],
    run = {
        ['0~>A ; 0~>A'] = 1,
    },
}

    -- LOOP

Test { [[
var int ret = 0;
loop i in 256-1 do
    ret = ret + 1;
end
escape ret;
]],
    run = 255,
}
Test { [[
var int ret = 0;
loop i in 256-1 do
    ret = ret + 1;
end
escape ret;
]],
    --loop = true,
    wrn = true,
    run = 255,
}

Test { [[
var int n = 10;
var int sum = 0;
loop i in n do
    sum = sum + 1;
end
escape n;
]],
    loop = true,
    tight = 'tight loop',
    run = 10,
}

Test { [[
break;
]],
    props = 'line 1 : `break´ without loop',
}

Test { [[
input int A;
loop do
    do
        break;
    end;
end;
escape 1;
]],
    _ana = {
        unreachs = 1,    -- re-loop
    },
    run = 1,
}
Test { [[
input int A;
loop do
    do
        escape 1;
    end;
end;
escape 0;
]],
    _ana = {
        unreachs = 2,
    },
    run = 1,
}

Test { [[
input int A;
loop do
    loop do
        escape 1;
    end;
end;
escape 0;
]],
    _ana = {
        unreachs = 3,
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
escape 0;
]],
    _ana = {
        isForever = true,
        unreachs = 2,
    },
    --tight = 'tight loop',
}

Test { [[
loop do
    par do
        await FOREVER;
    with
        break;
    end;
end;
escape 1;
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
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
escape 1;
]],
    _ana = {
        unreachs = 1,
    },
    run = { ['1~>A;2~>B']=1, }
}

Test { [[
loop do
    par do
        await FOREVER;
    with
        escape 1;
    end;
end;        // unreachs
escape 1;   // unreachs
]],
    _ana = {
        unreachs = 2,
        abrt = 1,
    },
    run = 1,
}

Test { [[
input void A,B;
loop do
    par do
        await A;
        await FOREVER;
    with
        await B;
        escape 1;
    end;
end;        // unreachs
escape 1;   // unreachs
]],
    _ana = {
        unreachs = 2,
    },
    run = { ['~>A;~>B']=1, }
}

Test { [[
loop do
    async do
        break;
    end;
end;
escape 1;
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
    _ana = {
        isForever = true,
    },
}

Test { [[
var int a;
loop do a=1; end;
escape a;
]],
    --_ana = {
        --isForever = true,
        --unreachs = 1,
    --},
    tight = 'tight loop',
}

Test { [[break; escape 1;]],
    parser="line 1 : before `;´ : expected statement"
}
Test { [[break; break;]],
    parser="line 1 : before `;´ : expected statement"
}
Test { [[loop do break; end; escape 1;]],
    _ana = {
        unreachs=1,
    },
    run=1
}
Test { [[
var int ret;
loop do
    ret = 1;
    break;
end;
escape ret;
]],
    _ana = {
        unreachs = 1,
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
    _ana = {
        isForever = true,
        unreachs = 1,
    },
    --tight = 'tight loop'
}

Test { [[
loop do
    loop do
        break;
    end;
end;
]],
    tight = 'tight loop',
    --_ana = {
        --isForever = true,
        --unreachs = 1,
    --},
}

Test { [[
loop do
    loop do
        await FOREVER;
    end;
end;
]],
    _ana = {
        unreachs = 2,
        isForever = true,
    },
}

Test { [[
loop i in -1 do
end
escape 1;
]],
    --loop = true,
    wrn = true,
    run = 1,
    -- TODO: with sval -1 would be constant
}
Test { [[
loop i in -1 do
end
escape 1;
]],
    --tight = 'line 1 : tight loop',
    run = 1,
}
Test { [[
loop i in 0 do
end
escape 1;
]],
    run = 1,
}

Test { [[
input void A;
loop do
    loop do
        await A;
    end
end
]],
    _ana = { isForever=true },
}

Test { [[
input void A;
loop do
    loop i in 1 do
        await A;
    end
end
]],
    _ana = { isForever=true },
}

Test { [[
input void OS_START;
var int v = 1;
loop do
    loop i in v do
        await OS_START;
        escape 2;
    end
end
escape 1;
]],
    ana = 'line 4 : `loop´ iteration is not reachable',
    --ana = 'line 4 : statement is not reachable',    -- TODO: should be line 7
    run = 2,
}

Test { [[
input void OS_START;
var int v = 1;
loop do
    loop i in v do
        await OS_START;
        escape 2;
    end
end
escape 1;
]],
    wrn = true,
    run = 2,
}

-- LOOP / BOUNDED

Test { [[
native do
    int V;
end
loop/_V do
end
escape 1;
]],
    gcc = ':4:5: error: variable-sized object may not be initialized',
}
Test { [[
loop/10 do
end
escape 1;
]],
    asr = 'runtime error: loop overflow',
    --run = 1,
}

Test { [[
var int ret = 0;
loop/3 do
    ret = ret + 1;
end
escape ret;
]],
    asr = 'runtime error: loop overflow',
}

Test { [[
loop/10 i in 10 do
end
escape 1;
]],
    run = 1,
}
Test { [[
var int a = 0;
loop/a i do
end
escape 1;
]],
    tight = '`loop´ bound must be constant',
}
Test { [[
loop/10 i do
end
escape 1;
]],
    asr = true,
}
Test { [[
native do
    ##define A 10
end
#define A 10

var int ret = 0;
var int lim = 10 + 10 + _A + A;
loop/(10+10+_A+A) i in lim do
    ret = ret + 1;
end
escape ret;
]],
    run = 40;
}

-- EVERY

Test { [[
par/or do
    nothing;
with
    every (2)s do
        nothing;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
input void A;
var int ret = 0;
every A do
    ret = ret + 1;
    if ret == 3 then
        escape ret;
    end
end
]],
    props = 'line 6 : not permitted inside `every´',
}

Test { [[
input int E;
var int x;
every x in E do
end
escape 1;
]],
    env = 'line 3 : implicit declaration of "x" hides the one at line 2',
}

Test { [[
input void A;
var int ret = 0;
loop do
    await A;
    ret = ret + 1;
    if ret == 3 then
        escape ret;
    end
end
]],
    run = { ['~>A;~>A;~>A']=3 }
}

Test { [[
var int ret = 0;
every 1s do
    await 1s;
    ret = ret + 1;
    if ret == 10 then
        escape ret;
    end
end
]],
    props = 'line 3 : `every´ cannot contain `await´',
}

Test { [[
var int ret = 0;
loop do
    await 1s;
    ret = ret + 1;
    if ret == 10 then
        escape ret;
    end
end
]],
    run = { ['~>10s']=10 }
}

Test { [[
var int ret = 0;
var int dt;
loop do
    var int dt = await 1s;
    ret = ret + dt;
    if ret == 10000000 then
        escape ret;
    end
end
]],
    env = 'line 4 : declaration of "dt" hides the one at line 2',
}

Test { [[
var int ret = 0;
loop do
    var int dt = await 1s;
    ret = ret + dt;
    if ret == 10000000 then
        escape ret;
    end
end
]],
    run = { ['~>5s']=10000000 }
}

Test { [[
event void inc;
loop do
    await inc;
    nothing;
end
every inc do
    nothing;
end
]],
    _ana = { isForever=true },
}

Test { [[
input (int,int) A;
par do
    var int a, b;
    (a,b) = await A;
with
    await A;
    escape 1;
with
    async do
        emit A => (1,1);
    end
end
]],
    run = 1;
}

Test { [[
input (int,int) A;
par do
    var int a, b;
    (a,b) = await A;
with
    escape 1;
end
]],
    run = 1;
}

Test { [[
input (int,int) A;
async do
    emit A => (1,3);
end
escape 1;
]],
    run = 1;
}

Test { [[
input (int,int) A;
par do
    loop do
        var int a, b;
        (a,b) = await A;
        escape a+b;
    end
with
    async do
        emit A => (1,3);
    end
end
]],
    wrn = true,
    run = 4;
}
Test { [[
input (int,int) A;
par do
    loop do
        var int a, b;
        (a,b) = await A;
        escape a+b;
    end
with
    async do
        emit A => (1,3);
    end
end
]],
    ana = 'line 3 : `loop´ iteration is not reachable',
    --run = 4;
}

Test { [[
input (int,int) A;
par do
    var int a, b;
    every (a,b) in A do
        escape a+b;
    end
with
    async do
        emit A => (1,3);
    end
end
]],
    env = 'line 4 : implicit declaration of "a" hides the one at line 3',
}
Test { [[
input (int,int) A;
par do
    every (a,b) in A do
        escape a+b;
    end
with
    async do
        emit A => (1,3);
    end
end
]],
    props = 'line 4 : not permitted inside `every´',
}
Test { [[
input (int,int) A;
par do
    loop do
        var int a,b;
        (a,b) = await A;
        escape a+b;
    end
with
    async do
        emit A => (1,3);
    end
end
]],
    ana = 'line 3 : `loop´ iteration is not reachable',
}
Test { [[
input (int,int) A;
par do
    var int a, b;
    loop do
        (a,b) = await A;
        escape a+b;
    end
with
    async do
        emit A => (1,3);
    end
end
]],
    wrn = true,
    run = 4;
}

Test { [[
input void A,F;
var int ret = 0;
par/or do
    every A do
        ret = ret + 1;
    end
with
    await F;
end
escape ret;
]],
    run = { ['~>A;~>A;~>A;~>F;~>A']=3 },
}

Test { [[
every 1s do
    break;
end
]],
    props = 'line 2 : not permitted inside `every´',
}

Test { [[
every 1s do
    escape 1;
end
]],
    props = 'line 2 : not permitted inside `every´',
}

Test { [[
every 1s do
    loop do
        if 1 then
            break;
        end
    end
end
]],
    tight = 'line 2 : tight loop',
}

Test { [[
par do
    every 1s do
        var int ok = do
            escape 1;
        end;
    end
with
    await 2s;
    escape 10;
end
]],
    run = { ['~>10s'] = 10 },
}

-- CONTINUE

Test { [[
var int ret = 1;
loop i in 10 do
    if 1 then
        continue;
    end
    ret = ret + 1;
    if 0 then
        continue;
    end
end
escape ret;
]],
    run = 1,
}

Test { [[
loop do
    if 0 then
        continue;
    else
        nothing;
    end
end
]],
    adj = 'line 3 : invalid `continue´',
}

Test { [[
loop do
    do continue; end
end
]],
    adj = 'line 2 : invalid `continue´',
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
    adj = 'line 4 : invalid `continue´',
}

Test { [[
loop do
    if 0 then
        continue;
    end
    await 1s;
end
]],
    --tight = 'tight loop',
    _ana = {
        isForever = true,
        --unreachs = 1,
    },
}

Test { [[
var int ret = 0;
loop i in 10 do
    if i%2 == 0 then
        ret = ret + 1;
        await 1s;
        continue;
    end
    await 1s;
end
escape ret;
]],
    run = { ['~>10s']=5 }
}

Test { [[
every 1s do
    if 1 then
        continue;
    end
end
]],
    _ana = {
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
    _ana = {
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
    _ana = {
        isForever = true,
    },
}
Test{ [[
input int E;
loop do
    var int v = await E;
    if v then
    else
    end;
end;
]],
    _ana = {
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
escape a;
]],
    tight = 'tight loop',
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
escape a;
]],
    --tight = 'tight loop',
    _ana = {
        isForever = true,
        unreachs = 1,
    },
}
Test { [[
loop do
    if 0 then
        break;
    end;
end;
escape 0;
]],
    tight = 'line 1 : tight loop',
}

Test { [[
par/or do
    loop do
    end;
with
    loop do
    end;
end;
escape 0;
]],
    loop='tight loop',
    _ana = {
        isForever = true,
        unreachs = 2,
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
escape 0;
]],
    loop='tight loop',
    _ana = {
        isForever = true,
        unreachs = 2,
    },
}

Test { [[
event int a;
par/and do
    await a;
with
    loop do end;
end;
escape 0;
]],
    loop='tight loop',
    _ana = {
        isForever = true,
        unreachs = 2,
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
escape 0;
]],
    loop='tight loop',
    _ana = {
        isForever = true,
        unreachs = 1,
        abrt = 1,
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
escape 0;
]],
    loop='tight loop',
    _ana = {
        abrt = 1,
        isForever = true,
        unreachs = 1,
    },
}

Test { [[
input void OS_START;
event void a,b;
par/and do
    await a;
with
    await OS_START;
    emit b;
    emit a;
end
escape 5;
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
escape 0;   // TODO
]],
    _ana = {
        unreachs = 1,
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
    _ana = {
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
escape 1;
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
escape 1;
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
escape 1;
]],
    run = {
        ['0~>F'] = 1,
        ['1~>F;0~>A;0~>F'] = 1,
    }
}

Test { [[
input int A;
var int a;
par/or do           // 3
    loop do
        a = 1;      // 5
        await A;    // 6
    end;
with
    await A;        // 9
    await A;
    a = 1;          // 11
end;
escape a;
]],
    _ana = {
        abrt = 1,
        acc = 1,
    },
}

Test { [[
input int A;
var int a;
par do
    loop do
        par/or do
            a = 1;      // 6
            await A;    // 7
        with
            await A;    // 9
            a = 2;      // 10
        end;
    end
with
    loop do
        await A;
        a = 3;          // 16
    end
end
]],
    _ana = {
        isForever = true,
        acc = 2,        -- 6/16  10/16
        abrt = 3,
    },
}

Test { [[
input int A;
var int a;
par do
    loop do
        par/or do
            a = 1;      // 6
            await A;    // 7
        with
            await A;    // 9
            a = 2;      // 10
        end;
    end
with
    loop do
        await A;
        a = 3;          // 16
    end
end
]],
    _ana = {
        isForever = true,
        acc = 3,        -- 6/16  10/16  6/10
        abrt = 3,
    },
    safety = 2,
}

-- FOR

Test { [[
input int A;
var int sum = 0;
par/or do
    loop i in 1+1 do
        await A;
    end
    sum = 0;
with
    sum = 1;
end
escape sum;
]],
    todo = 'for',
    _ana = {
        acc = 1,
        unreachs = 1,
    },
    run = 1,
}

Test { [[
input int A;
var int sum = 0;
par/or do
    loop i in 1 do    // 4
        await A;
    end
    sum = 0;
with
    sum = 1;        // 9
end
escape sum;
]],
    _ana = {
        abrt = 1,
        --unreachs = 2,
    },
    run = 1,
}

Test { [[
input void A;
var int sum = 0;
var int ret = 0;
par/or do
    loop i in 2 do
        await A;
        ret = ret + 1;
    end
    sum = 0;    // 9
with
    await A;
    await A;
    sum = 1;    // 13
end
escape ret;
]],
    _ana = {
        acc = 1,
        abrt = 5,    -- TODO: not checked
    },
    run = { ['~>A; ~>A; ~>A']=2 },
}

Test { [[
input void A;
var int sum = 0;
var int ret = 0;
par/or do
    loop i in 3 do
        await A;
        ret = ret + 1;
    end
    sum = 0;
with
    await A;
    await A;
    sum = 1;
end
escape ret;
]],
    _ana = {
        acc = 1,
        abrt = 5,    -- TODO: not checked
    },
    run = { ['~>A;~>A'] = 2 },
    --todo = 'nd excpt',
}

Test { [[
input int A;
var int sum = 0;
par/or do
    loop i in 1 do    // 4
        await A;
        async do
            var int a = 1;
        end
    end
    sum = 0;
with
    sum = 1;        // 12
end
escape sum;
]],
    _ana = {
        abrt = 1,
        --unreachs = 3,
    },
    run = 1,
}

Test { [[
input int A;
var int sum = 0;
par/or do
    sum = 5;            // 4
    loop i in 10 do       // 5
        await A;
        async do
            var int a = 1;
        end
    end
    sum = 0;            // 11
with
    loop i in 2 do        // 13
        async do
            var int a = 1;
        end
        sum = sum + 1;  // 17
    end
end
escape sum;
]],
    run = 7,
}

Test { [[
input int A;
var int sum = 0;
par/or do
    sum = 5;            // 4
    loop i in 10 do       // 5
        await A;
        async do
            var int a = 1;
        end
    end
    sum = 0;            // 11
with
    loop i in 2 do        // 13
        async do
            var int a = 1;
        end
        sum = sum + 1;  // 17
    end
end
escape sum;
]],
    run = 7,
    safety = 2,
    _ana = {
        acc = 4,
    },
}

Test { [[
var int sum = 0;
loop i in 100 do
    sum = sum + (i+1);
end
escape sum;
]],
    --loop = true,
    run = 5050,
}
Test { [[
var int sum = 0;
for i=1, 100 do
    i = 1;
    sum = sum + i;
end
escape sum;
]],
    --loop = true,
    todo = 'should raise an error',
    run = 5050,
}
Test { [[
var int sum = 5050;
loop i in 100 do
    sum = sum - (i+1);
end
escape sum;
]],
    --loop = true,
    run = 0,
}
Test { [[
var int sum = 5050;
var int v = 0;
loop i in 100 do
    v = i;
    if sum == 100 then
        break;
    end
    sum = sum - (i+1);
end
escape v;
]],
    --loop = true,
    run = 99,
}
Test { [[
input void A;
var int sum = 0;
var int v = 0;
loop i in 101 do
    v = i;
    if sum == 6 then
        break;
    end
    sum = sum + i;
    await A;
end
escape v;
]],
    run = {['~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;']=4},
}
Test { [[
var int sum = 4;
loop i in 0 do
    sum = sum - i;
end
escape sum;
]],
    --loop = true,
    --adj = 'line 2 : constant should not be `0´',
    run = 4,
}
Test { [[
input void A, B;
var int sum = 0;
loop i in 10 do
    await A;
    sum = sum + 1;
end
escape sum;
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
escape ret;
]],
    run = { ['1~>A;2~>B'] = 2 }
}

Test { [[
input int A,B,Z,D,F;
var int ret;
par/and do
    ret = await A;
with
    ret = await B;
end;
escape ret;
]],
    run = { ['1~>A;2~>B'] = 2 },
    safety = 2,
    _ana = {
        acc = 1,
    },
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
        par/or do               // 10
            ret = await B;
        with
            ret = await Z;      // 13 (false w/ 10)
        end;
    with
        ret = await D;          // 16 (false w/10,9)
    end;
with
    ret = await F;
end;
escape ret;
]],
    run = { ['1~>F'] = 1 }
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
        par/or do               // 10
            ret = await B;
        with
            ret = await Z;      // 13 (false w/ 10)
        end;
    with
        ret = await D;          // 16 (false w/10,9)
    end;
with
    ret = await F;
end;
escape ret;
]],
    run = { ['1~>F'] = 1 },
    safety = 2,
    _ana = {
        acc = 9,
    },
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
escape a;
]],
    _ana = {
        unreachs = 1,
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
    escape a;
end;
]],
    _ana = {
        isForever = false,
    },
    run = { ['~>1min; ~>1min ; 0~>F'] = 1 },
}

Test { [[
input int F;
var int a = 0;
par do
    a = a + 1;
    await FOREVER;
with
    await F;
    escape a;
end;
]],
    safety = 2,
    _ana = {
        isForever = false,
        acc = 1,
    },
    run = { ['~>1min; ~>1min ; 0~>F'] = 1 },
}

Test { [[
input int A;
var int a = await A;
await A;
escape a;
]],
    run = {['10~>A;20~>A']=10},
}

Test { [[
input int A;
var int a = await A;
var int b = await A;
escape a + b;
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
escape a+f;
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
escape a+f;
]],
    run = { ['1~>A;5~>A;1~>F'] = 2 },
}

-- LOOP/RECURSE
--[=[

Test { [[
loop v in 10 do
    traverse 1;
end
]],
    adt = 'line 2 : invalid `traverse´: no data',
}

Test { [[
var int* vs;
loop/10 v in vs do
    traverse 1;
end
escape 1;
]],
    env = 'line 3 : invalid `traverse´',
}

Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;
loop/1 v in _VS do      // think its numeric
    if v == null then
        break;
    else
        ret = ret + v:v;
        traverse v:nxt;
    end
end

escape 1;
]],
    env = 'line 13 : invalid operands to binary "=="',
    --run = 1,
}

Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;

loop/1 v in &_VS do
    if v == null then
        break;
    else
        ret = ret + v:v;
        traverse v:nxt;
    end
end

escape ret;
]],
    todo = '&_VS cannot be numeric, but it think it is',
    run = 1,
}

Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;

var _tp* vs = &_VS;
loop/3 v in vs do
    if v == null then
        break;
    else
        ret = ret + v:v;
        traverse v:nxt;
    end
end

escape ret;
]],
    run = 6,
}

Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;

var _tp* vs = &_VS;
loop/3 v in vs do
    if v == null then
        continue;
    end
    ret = ret + v:v;
    traverse v:nxt;
end

escape ret;
]],
    run = 6,
}

Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;

var _tp* vs = &_VS;
loop/3 v in vs do
    if v == null then
    else
        ret = ret + v:v;
        traverse v:nxt;
    end
end

escape ret;
]],
    run = 6,
}

Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;

var _tp* vs = &_VS;
loop/3 v in vs do
    if v == null then
        break;
    else
        traverse v:nxt;
        ret = ret + v:v;
    end
end

escape ret;
]],
    run = 0,
}

Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;

var _tp* vs = &_VS;
loop/3 v in vs do
    if v == null then
        continue;
    end
    traverse v:nxt;
    ret = ret + v:v;
end

escape ret;
]],
    run = 6,
}

Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;

var _tp* vs = &_VS;
loop/3 v in vs do
    if v == null then
    else
        traverse v:nxt;
        ret = ret + v:v;
    end
end

escape ret;
]],
    run = 6,
}

Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;

var _tp* vs = &_VS;
loop/1 v in vs do
    if v == null then
        break;
    else
        ret = ret + v:v;
        traverse v:nxt;
    end
end

escape ret;
]],
    asr = 'runtime error: loop overflow',
}

Test { [[
traverse 1;
]],
    adt = 'line 1 : missing enclosing `traverse´ block',
}
]=]

-- INTERNAL EVENTS

Test { [[
input void OS_START;
event int a;
var int ret = 0;
par/or do
    await OS_START;
    emit a => 1;
with
    ret = await a;
end
escape ret;
]],
    run = 1,
    _ana = {
        excpt = 1,
    },
}

Test { [[
input void OS_START;
var int ret;
event void a,b;
par/and do
    await OS_START;
    emit a;
with
    await OS_START;
    emit b;
with
    await a;
    ret = 1;    // 12: nd
with
    await b;
    ret = 2;    // 15: nd
end
escape ret;
]],
    _ana = {
        acc = 1,
    },
    run = 2,
}

Test { [[
input void OS_START;
var int ret;
event void a,b;
par/and do
    await OS_START;
    emit a;         // 6
with
    par/or do
        await OS_START;
    with
        await 1s;
    end
    emit b;         // 13
with
    await a;        // 15
    ret = 1;        // acc
with
    par/or do
        await b;    // 19
    with
        await 1s;   // 21
    end
    ret = 2;        // acc
end
escape ret;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
    run = 2,
}

Test { [[
input void OS_START;
var int ret;
event void a,b,c,d;
par/and do
    await OS_START;
    emit a;
with
    await OS_START;
    emit b;
with
    await a;
    emit c;
with
    await b;
    emit d;
with
    await c;
    ret = 1;    // 18: acc
with
    await d;
    ret = 2;    // 21: acc
end
escape ret;
]],
    _ana = {
        acc = 1,
    },
    run = 2,
}

Test { [[
event int c;
emit c => 10;
await c;
escape 0;
]],
    _ana = {
        --unreachs = 1,
        --isForever = true,
    },
    --trig_wo = 1,
}

-- EX.06: 2 triggers
Test { [[
event int c;
emit c => 10;
emit c => 10;
escape c;
]],
    env = 'line 4 : types mismatch (`int´ <= `void´)',
    --trig_wo = 2,
}

Test { [[
event int c;
emit c => 10;
emit c => 10;
escape 10;
]],
    run = 10,
    --trig_wo = 2,
}

Test { [[
event int b;
var   int a;
a = 1;
emit b => a;
escape a;
]],
    run = 1,
    --trig_wo = 1,
}

Test { [[
input void OS_START;
event float x;
var float ret = 0;
par/and do
    ret = await x;
with
    await OS_START;
    emit x => 1.1;
end
escape ret>1.0 and ret<1.2;
]],
    run = 1,
}

Test { [[
input float X;
var float ret;
par/and do
    ret = await X;
with
    async do
        emit X => 1.1;
    end
end
escape ret>1.0 and ret<1.2;
]],
    run = 1,
}

-- the inner "emit e" is aborted and the outer "emit e"
-- awakes the last "await e"
Test { [[
input void OS_START;

event int e;

var int ret = 0;

par/or do
    await OS_START;
    emit e => 2;
    escape -1;
with
    par/or do
        await e;
        emit e => 3;
        escape -1;
    with
        var int v = await e;
        ret = ret + v;          // 0+3
    end
    await FOREVER;
with
    var int v = await e;
    ret = ret * v;              // 3*2
end

escape ret;
]],
    --_ana = {acc=3},
    _ana = {acc=true},
    run = 6,
}

-- "emit e" on the stack has to die
Test { [[
input void OS_START;

event int* e;
var int ret = 0;

par/or do
    do
        var int i = 10;
        par/or do
            await OS_START;
            emit e => &i;           // stacked
        with
            var int* pi = await e;
            ret = *pi;
        end                         // has to remove from stack
    end
    do
        var int i = 20;
        await 1s;
        i = i + 1;
    end
with
    var int* i = await e;           // to avoid awaking here
    escape *i;
end
escape ret;
]],
    run = { ['~>1s']=10 },
}

Test { [[
event void e;
input void OS_START;

par do
    par do
        par/or do
            await e;
        with
            await FOREVER;
        end
    with
        await OS_START;
        emit e;
        escape 2;   // should continue after the awake below
    end
with
    await e;
    escape 1;       // should escape before the one above
end
]],
    run = 1,
}

-- ParOr

Test { [[
input void OS_START;
event int a;
var int aa = 3;
par do
    await OS_START;
    emit a => aa;      // 6
    escape aa;
with
    loop do
        var int v = await a;
        aa = v+1;
    end;
end;
]],
    awaits = 0,
    run = 4,
}

Test { [[
input void OS_START;
event int a;
var int aa = 3;
par do
    await OS_START;
    emit a => aa;      // 6
    escape aa;
with
    loop do
        var int v = await a;
        aa = v+1;
    end;
end;
]],
    awaits = 0,
    run = 4,
    safety = 2,
    _ana = {
        acc = 2,
    },
}

Test { [[
input void OS_START;
event int a;
var int aa = 3;
par do
    await OS_START;
    emit a => aa;
    escape aa;
with
    loop do
        var int v = await a;
        aa = v+1;
    end;
end;
]],
    run = 4,
}

Test { [[
var int ret = 0;
event int a;
var int aa = 3;
par/or do
    await a;
    ret = ret + 1;  // 6
with
    ret = 5;        // 8
end
emit a;
escape ret;
]],
    --env = 'line 10 : missing parameters on `emit´',
    env = 'line 10 : arity mismatch',
}

Test { [[
var int ret = 0;
event int a;
var int aa = 3;
par/or do
    await a;
    ret = ret + 1;  // 6
with
    ret = 5;        // 8
end
emit a => 1;
escape ret;
]],
    _ana = {
        abrt = 1,
        --unreachs = 1,
    },
    run = 5,
}

Test { [[
var int[2] v;
v[0] = 1;
var int ret;
par/or do
    ret = v[0];
with
    ret = v[1];
end;
escape ret;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
        escape 0;               // 8
    with
        var int v = await A;
        escape v;               // 11
    end;
escape a;
]],
    _ana = {
        --unreachs = 1,
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input int A;
var int a;
a = par do
        if 1 then
            var int v = await A;
            escape v;           // 6
        end;
        escape 0;
    with
        var int v = await A;
        escape v;               // 11
    end;
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 4,
    },
}

Test { [[
input int A;
var int a;
a = par do
    await A;                    // 4
    if 1 then
        var int v = await A;
        // unreachable
        escape v;               // 8
    end;
    escape 0;                   // 10
with
    var int v = await A;
    escape v;                   // 13
end;
escape a;
]],
    _ana = {
        --unreachs = 1,
        acc  = 2,
        abrt  = 6,
    },
    run = { ['1~>A']=1 },
}

Test { [[
input void OS_START;
event void e;
var int v;
par/or do           // 4
    await OS_START;
    emit e;         // 6
    v = 1;
with
    await e;        // 9
    emit e;
    v = 2;
end
escape v;
]],
    _ana = {
        excpt = 1,
    },
    run = 2,
}

Test { [[
input void OS_START;
event void e;
var int v;
par/or do           // 4
    await OS_START;
    emit e;         // 6
    v = 1;
with
    await e;        // 9
    emit e;
    v = 2;
end
escape v;
]],
    _ana = {
        excpt = 1,
    },
    run = 2,
    safety = 2,
    _ana = {
        acc = 1,
    },
}

Test { [[
input int A,B;
var int a,v;
a = par do
    if 1 then
        v = await A;    // 5
    else
        await B;
        escape v;
    end;
    escape 0;           // 10
with
    var int v = await A;
    escape v;           // 13
end;
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input int A,B;
var int a,v;
a = par do
    if 1 then
        v = await A;
        escape v;       // 6
    else
        await B;
        escape v;
    end;
    escape 0;
with
    var int v = await A;
    escape v;           // 14
end;
escape a;
]],
    _ana = {
        unreachs = 1,
        acc = 1,
        abrt = 3,
    },
    run = { ['1~>A']=1 },
}

Test { [[
input void OS_START;
event void c,d;
par do
    await OS_START;
    emit c;
    escape 10;       // 35
with
    loop do
        await c;
        emit d;
    end
end
]],
    _ana = {
        acc = true,
        unreachs = 1,
        abrt = 1,
    },
    run = 10,
}

Test { [[
native do
    ##include <assert.h>
end
input void OS_START;
event void a, b, c, d;
native _assert();
var int v=0;
par do
    loop do
        await OS_START;
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
        await a;        // 24
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
        escape v;       // 35
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
    _ana = {
        acc = true,
        unreachs = 1,
        abrt = 1,
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
escape a;
]],
    _ana = {
        acc  = 1,
        abrt  = 3,
    },
    run = 0,
}

Test { [[
input int B;
event int a;
var int aa;
par do
    await B;
    escape 1;
with
    await B;
    par/or do
    with
    end;
    escape 2;
end;
]],
    _ana = {
        --unreachs = 1,
        abrt = 6,      -- TODO: not checked
        acc = 1,
    },
}
Test { [[
input int B;
event int a;
var int aa;
par do
    await B;
    escape 1;
with
    await B;
    par/or do
        escape 2;
    with
    end;
    escape 3;
end;
]],
    _ana = {
        --unreachs = 1,
        abrt = 8,      -- TODO: not checked
        acc = 2,
    },
}

Test { [[
event void a, b;
input void OS_START,A;
var int ret = 0 ;

par/or do
    loop do
        await a;
        ret = ret + 1;
    end
with
    await b;
    emit a;
    await FOREVER;
with
    await OS_START;
    emit a;
    await A;
    emit b;
end
escape ret;
]],
    run = { ['~>A']=2 },
}

-- the second E cannot awake
Test { [[
input void E;
event void e;
var int ret = 1;
par do
    await E;
    emit e;
    ret = ret * 2;
    escape ret;
with
    await e;
    ret = ret + 1;
    await E;
    ret = ret + 1;
    escape 10;
end
]],
    _ana = { acc=true },
    run = { ['~>E']=4 },
}

-- TODO: STACK
Test { [[
event void a, b;
input void OS_START;
var int ret = 0 ;

par/or do
    loop do
        await a;
        ret = ret + 1;
    end
with
    await b;
    emit a;
    await FOREVER;
with
    await OS_START;
    emit a;
    emit b;
end
escape ret;
]],
    _ana = { acc=1 },
    --run = 2,
    run = 1,
}

-- TODO: STACK
-- internal glb awaits
Test { [[
input void OS_START;
event void a;
native _ret_val, _ret_end;
_ret_val = 0;
par do
    loop do
        par/or do
            await a;    // 8
            _ret_val = _ret_val + 1;
            _ret_end = 1;
        with
            await a;    // 12
            _ret_val = _ret_val + 2;
        end
    end
with
    await OS_START;
    emit a;
    emit a;
end
]],
    todo = 'no more ret_val/ret_end',
    _ana = {
        isForever = true,
        acc = 3,
        abrt  = 3,
    },
    awaits = 1,
    run = 1,
}

Test { [[
input void OS_START;
event int a, x, y;
var int ret = 0;
par do
    par/and do
        await OS_START;
        emit x => 1;   // 7
        emit y => 1;   // 8
    with
        par/or do
            await y;
            escape 1;   // 12
        with
            await x;
            escape 2;   // 15
        end;
    end;
with
    await OS_START;
    emit x => 1;       // 20
    emit y => 1;       // 21
end
]],
    _ana = {
        acc = 3,
        abrt = 5,   -- TODO: not checked
    },
    run = 2;
}

Test { [[
input void OS_START;
event void a, b;
par do
    par do
        await a;    // 5
        escape 1;   // 6
    with
        await b;
        escape 2;   // 9
    end
with
    await OS_START;    // 12
    emit b;
with
    await OS_START;    // 15
    emit a;
end
]],
    run = 2,
    _ana = {
        acc = 1,
        abrt = 5,
    },
}

Test { [[
native do
    int V = 10;
end
event void a;
par/or do
    await 1s;
    emit a;
    _V = 1;
with
    await a;
end
await 1s;
escape _V;
]],
    run = { ['~>2s']=10 },
}
Test { [[
native do
    int V = 10;
end
event void a;
par/or do
    await a;
with
    await 1s;
    emit a;
    _V = 1;
end
await 1s;
escape _V;
]],
    run = { ['~>2s']=10 },
}
Test { [[
input void OS_START;
event int e;
var int ret = 1;
par/or do
    do
        var int x = 2;
        par/or do
            await OS_START;
            emit e => x;
        with
            await e;
        end
    end
    do
        var int x = 10;
        await 1s;
        ret = x;
    end
with
    var int v = await e;
    ret = v;
end
escape ret;
]],
    run = { ['~>2s']=10 },
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
escape a + b;
]],
    run = { ['0~>A']=3, ['5~>A']=13 },
}

Test { [[
input int A,B;
var int a,b,c,d=0;
par/or do
    par/and do          // 4
        a = await A;
    with
        b = await B;
    end;
    c = 1;
with
    par/and do          // 11
        b = await B;
    with
        a = await A;
    end;
    d = 2;
end;
escape a + b + c + d;
]],
    _ana = {
        acc = 2,
        abrt = 5,   -- TODO: not checked
    },
    run = { ['0~>A;5~>B']=6 },
    --run = { ['0~>A;5~>B']=8 },
    --todo = 'nd excpt',
}

---

Test { [[
input int A,B;
var int a,b,ret;
par/and do
    await A;
    a = 1+2+3+4;
with
    var int v = await B;
    b = 100+v;
    ret = a + b;
end;
escape ret;
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
escape a + b;
]],
    _ana = {
        acc = 2,
        abrt = 5,   -- TODO: not checked
    },
    run = { ['1~>A;10~>B']=1 },
}

Test { [[
par do
    escape 1;
with
    escape 2;
end;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
input int A;
par do
    escape 1;
with
    await A;
    escape 1;
end;
]],
    _ana = {
        abrt = 1,
        --unreachs = 1,
    },
    run = 1,
}
Test { [[
input int A;
par do
    var int v = await A;
    escape v;
with
    var int v = await A;
    escape v;
end;
]],
    _ana = {
        abrt = 3,
        acc = 1,
    },
    run = { ['1~>A']=1, ['2~>A']=2 },
}

Test { [[
par do
    await FOREVER;
with
    escape 10;
end;
]],
    _ana = {
        abrt = 1,
    },
    run = 10,
}

Test { [[
input int A,B,Z;
par do
    var int v = await A;
    escape v;
with
    var int v = await B;
    escape v;
with
    var int v = await Z;
    escape v;
end;
]],
    run = { ['1~>A']=1, ['2~>B']=2, ['3~>Z']=3 }
}
Test { [[
par/and do
with
end;
escape 1;
]],
    run = 1,
}
Test { [[
par/or do
with
end;
escape 1;
]],
    _ana = {
        abrt = 3,
    },
    run = 1,
}
Test { [[
input int A,B;
par do
    await A;
    var int v = await A;
    escape v;
with
    var int v = await B;
    escape v;
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
    escape v;
with
    var int v = await B;
    escape v;
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
    escape v;
with
    await A;
    var int v = await Z;
    escape v;
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
    escape v;
with
    var int v = await Z;
    escape v;
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
escape 1;
]],
    _ana = {
        abrt = 3,
    },
    run = {
        ['~>10s'] = 1,
        ['~>20s'] = 1,
    }
}
Test { [[
par do
    var int a = await 10ms;
    escape a;
with
    var int b = await 10ms;
    escape b;
end;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape a + b;
]],
    _ana = {
        abrt = 4,
    },
    run = {
        ['~>20us'] = 1,
        --['~>20us'] = 2,
    },
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
escape a + b;
]],
    _ana = {
        abrt = 4,
    },
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
escape a + b;
]],
    _ana = {
        abrt = 4,
    },
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
escape a + b;
]],
    _ana = {
        abrt = 4,
    },
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
escape a + b;
]],
    _ana = {
        abrt = 3,
    },
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
    escape a;
with
    b = await (10000)us;
    escape b;
end;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape a+b;
]],
    _ana = {
        abrt = 4,
    },
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
escape a+b;
]],
    _ana = {
        abrt = 4,
    },
    run = {
        ['~>10ms'] = 3000,
        ['~>20ms'] = 13000,
    }
}
Test { [[
var int a,b;
par do
    a = await 10us;
    escape a;
with
    b = await (5)us;
    await 5us;
    escape b;
end;
]],
    _ana = {
        acc = 1,
        abrt = 4,
    },
}
Test { [[
var int a,b;
par do
    a = await 10us;
    escape a;
with
    b = await (5)us;
    await 10us;
    escape b;
end;
]],
    _ana = {
        acc = 1,     -- TODO: =0 (await(5) cannot be 0)
        abrt = 4,
    },
}

Test { [[
input void A;
var int v1=0, v2=0;
par/or do
    await 1s;           // 4
    v1 = v1 + 1;
with
    loop do
        par/or do
            await 1s;   // 9
        with
            await A;
        end
        v2 = v2 + 1;
    end
end
escape v1 + v2;
]],
    _ana = {
        abrt = 1,
    },
    run = { ['~>A;~>1ms;~>A;~>1ms;~>A;~>1ms;~>A;~>1ms;~>A;~>1ms;~>1s']=6 }
}

Test { [[
input void A;
var int v1=0, v2=0, v3=0;
par/or do
    await 1s;           // 4
    v1 = v1 + 1;
with
    loop do
        par/or do
            await 1s;   // 9
        with
            await A;
        end
        v2 = v2 + 1;
    end
with
    loop do
        par/or do
            await 1s;   // 18
        with
            await A;
            await A;
        end
        v3 = v3 + 1;
    end
end
escape v1 + v2 + v3;
]],
    _ana = {
        abrt = 2,
    },
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
    _ana = {
        isForever = true,
        unreachs = 1,
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
    _ana = {
        isForever = true,
        unreachs = 1,
    }
}

Test { [[
var int v;
par/or do
    loop do         // 3
        break;      // 4
    end
    v = 2;
with
    v = 1;          // 8
end
escape v;
]],
    _ana = {
        unreachs = 1,
        acc = 1,
        abrt = 4,
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
escape v;
]],
    run = 1,
    --run = 2,
    _ana = {
        abrt = 1,
        --unreachs = 3,
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
escape 0;
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
    _ana = {
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
                a = 1;      // 9
                break;
            end
        end
    with
        loop do
            a = 1;          // 15
            await A;
        end
    end
end
]],
    _ana = {
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
                a = 1;      // 9
                break;
            end
        end
    with
        loop do
            a = 1;          // 15
            await A;
        end
    end
end
]],
    safety = 2,
    _ana = {
        acc = 1,
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
    _ana = {
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
escape v;
]],
    todo = 'acc should be 0',
    simul = {
        unreachs = 1,
    },
    run = 10,
}

Test { [[
var int a;
loop do
    par/or do
        loop do             // 4
            await (10)us;
            await 10ms;
            if 1 then
                break;
            end;
        end;
        a = 1;
    with
        loop do
            await 10ms;     // 14
            a = 1;
        end;
    end;
end;
]],
    _ana = {
        isForever = true,
        acc = 1,
        abrt = 1,
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
escape 0;
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
    _ana = {
        isForever = true
    },
}
Test { [[
var int a;
par/or do
    loop do             // 3
        await 10ms;
        await (10)us;
        if 1 then
            break;
        end;
    end;
    a = 1;
with
    loop do
        await 100ms;    // 13
        a = 1;
    end;
end;
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 1,
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
    _ana = {
        abrt = 1,
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
    _ana = {
        abrt = 1,
        isForever = true,
        acc = 1,
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
    _ana = {
        abrt = 1,
        isForever = true,
        acc = 1,
    },
}
Test { [[
var int a,b;
par/or do
    a = await 10ms;
    escape a;
with
    b = await (5)us;
    await 11ms;
    escape b;
end;
]],
    todo = 'await(x) pode ser <0?',  -- TIME_undef
    _ana = {
        acc = 1,
    },
}
Test { [[
var int a,b;
par do
    a = await 10ms;
    escape a;
with
    b = await (10000)us;
    escape b;
end;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape a+b;
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
    escape a;
with
    b = await (9)us;
    escape b;
with
    c = await (8)us;
    escape c;
end;
]],
    _ana = {
        acc = 3,
        abrt = 9,
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
escape a+b+c;
]],
    _ana = {
        abrt = 9,
    },
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
escape a+b+c;
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
    escape a;
with
    b = await (10)us;
    escape b;
with
    c = await 10us;
    escape c;
end;
]],
    _ana = {
        abrt = 9,
        acc = 3,
    },
}
Test { [[
var s32 a,b;
par do
    a = await 10min;
    escape a;
with
    b = await 20min;
    escape b;
end;
]],
    _ana = {
        --unreachs = 1,
        acc = 1,
        abrt = 3,
    },
    run = {
        ['~>10min']  = 0,
        ['~>20min']  = 600000000,
    }
}
Test { [[
await 35min;
escape 0;
]],
    sval = 'line 1 : constant is out of range',
}
Test { [[
var int a = 2;
par/or do
    await 10s;
with
    await 20s;
    a = 0;
end;
escape a;
]],
    _ana = {
        abrt = 3,
        --unreachs = 1,
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
escape a;
]],
    _ana = {
        abrt = 3,
    },
    run = {
        ['~>10ms'] = 2,
        ['~>20ms'] = 2,
        ['~>30ms'] = 2,
    }
}
Test { [[
var int a = 2;
par/or do
    var int b = await (10)us;
    a = b;
with
    await 20ms;
    a = 0;
end;
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
var s32 v1,v2;
par do
    v1 = await 5min;
    escape v1;
with
    await 1min;
    v2 = await 4min;
    escape v2;
end;
]],
    _ana = {
        acc = 1,
        abrt = 4,
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
    _ana = {
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
    _ana = {
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
    _ana = {
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
    _ana = {
        isForever = true,
    },
}

Test { [[
loop do
    await 10ms;
end;
]],
    _ana = {
        isForever = true,
    },
}

Test { [[
input int A;
async do
    emit A;
end
escape 1;
]],
    env = 'line 3 : arity mismatch',
    --env = 'line 3 : missing parameters on `emit´',
}

Test { [[
input void F;
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
    escape a;
end;
]],
    run = { ['~>10s;~>F']=10 }
}

Test { [[
input void F;
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
        escape a + b + c;
    end;
end;
]],
    run = {
        ['~>999ms; ~>F'] = 108,
        ['~>5s; ~>F'] = 555,
        ['~>F'] = 0,
    }
}

Test { [[
input void F;
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
        escape a + b + c;
    end;
end;
]],
    run = {
        ['~>999ms; ~>F'] = 108,
        ['~>5s; ~>F'] = 555,
        ['~>F'] = 0,
    },
    safety = 2,
    _ana = {
        acc = 3,
    },
}

    -- TIME LATE

Test { [[
var int a, b;
(a,b) = await 1s;
escape 1;
]],
    env = 'line 2 : arity mismatch',
    --gcc = 'error: ‘tceu__s32’ has no member named ‘_2’',
    --run = 1,
}

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
    escape late;
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
    escape v;
with
    var int v = await (1)us;
    escape v;
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
escape v;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape a;
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
escape a;
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
escape a;
]],
    run = {
        ['1~>A  ; 1~>F'] = 1,
        ['~>10min ; 1~>F'] = 0,
        ['~>10min ; 1~>A ; 1~>F'] = 0,
        ['1~>A  ; ~>10min; 1~>F'] = 1,
    }
}

Test { [[
native do ##include <assert.h> end
native _assert();
input void T;
var int ret = 0;
par/or do
    loop do
        var int late = await 10ms;
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
escape ret;
]],
    run = 72000,
}

Test { [[
input void OS_START;
event int a;
var int ret = 1;
par/or do
    await OS_START;
    emit a => 10;
with
    ret = await a;
end;
escape ret;
]],
    _ana = {
        excpt = 1,
    },
    run = 10,
}

Test { [[
event int a;
var int ret = 1;
par/or do
    emit a => 10;
with
    ret = await a;
end;
escape ret;
]],
    _ana = {
        acc = 1,
        abrt = 1,
    },
    run = 1,
}

Test { [[
input void OS_START;
event int a;
var int ret = 1;
par/and do
    await OS_START;
    emit a => 10;
with
    ret = await a;
end;
escape ret;
]],
    _ana = {
        --acc = 1,
    },
    run = 10,
}
-- TODO: STACK
Test { [[
event int a;
par/and do
    await a;
with
    emit a => 1;
end;
escape 10;
]],
    _ana = {
        acc = 1,
    },
    --run = 10,
    run = 0,
}

Test { [[
input int A;
event int b, c;
par do
    await A;
    emit b => 1;
    await c;        // 6
    escape 10;      // 7
with
    await b;
    await A;
    emit c => 10;      // 11
end;
]],
    _ana = {
        isForever = false,
        --unreachs = 2,
        --nd_esc = 1,
        acc = 1,
    },
    run = {
        ['0~>A ; 0~>A'] = 10,
    }
}

Test { [[
input int A;
event int b, c;
par do
    await A;
    emit b => 1;
    await c;        // 6
    escape 10;      // 7
with
    await b;
    await A;
    emit c => 10;      // 11
    // unreachable
    await c;
    // unreachable
    escape 0;       // 15
end;
]],
    _ana = {
        isForever = false,
        --unreachs = 2,
        --nd_esc = 1,
        acc = 1,
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
    _ana = {
        isForever = true,
        acc = 1,
        abrt = 3,
    },
}
Test { [[
event int a;
par/or do
    escape 1;       // TODO: [false]=true
with
    emit a => 1;       // TODO: elimina o [false]
    // unreachable
end;
// unreachable
await a;
// unreachable
escape 0;
]],
    _ana = {
        abrt = 3,
        --unreachs = 3,
    },
    run = 1,
    --trig_wo = 1,
}
Test { [[
event int a;
par/or do
with
    emit a => 1;
    // unreachable
end;
// unreachable
await a;
// unreachable
escape 0;
]],
    _ana = {
        abrt = 3,
        --unreachs = 2,
        --isForever = true,
    },
    --dfa = 'unreachable statement',
    --trig_wo = 1,
}
Test { [[
event int a;
par do
    escape 1;
with
    emit a => 1;
    // unreachable
end;
]],
    _ana = {
        --unreachs = 1,
        --nd_esc = 1,
        abrt = 1,
    },
    run = 1,
    --trig_wo = 1,
}
Test { [[
event int a;
par do
    emit a => 1;
    escape 1;
with
    escape 2;
end;
]],
    _ana = {
        --unreachs = 1,
        acc = 1,
        abrt = 3,
        --trig_wo = 1,
    },
    run = 1,
}
Test { [[
event int a;
par/or do
    emit a => 1;
with
end;
await a;
escape 0;
]],
    _ana = {
        --unreachs = 2,
        abrt = 3,
        --isForever = true,
    },
    --trig_wo = 1,
}

Test { [[
var int v1=2,v2=3;
par/or do
with
end
escape v1+v2;
]],
    run = 5,
}
Test { [[
var int v1,v2;
par/or do
with
end
v1=2;
v2=3;
escape v1+v2;
]],
    run = 5,
}
Test { [[
var int v1,v2;
do
    par/or do
    with
    end
    v1=2;
    v2=3;
end
escape v1+v2;
]],
    run = 5,
}

Test { [[
var int v1=0,v2=0;
par/and do
    v1 = 3;
with
    v2 = 2;
end
escape v1+v2;
]],
    run = 5,
}

Test { [[
event int a;
var int v1=0,v2=0;
par/or do
    emit a => 2;
    v1 = 3;
with
    v2 = 2;
end
escape v1+v2;
]],
    _ana = {
        abrt = 3,
        --unreachs = 1,
        --nd_esc = 1,
    },
    --run = 4,        -- TODO: stack change
    run = 3,
}

Test { [[
event int a;
var int v1=0,v2=0,v3=0;
par/or do
    emit a => 2;
    v1 = 2;
with
    v2 = 2;
with
    await a;
    v3 = 2;
end
escape v1+v2+v3;
]],
    _ana = {
        --unreachs = 2,
        acc = 1,
        abrt = 5,
    },
    --run = 4,        -- TODO: stack change
    run = 2,
}

Test { [[
event int a;
var int v1=0,v2=0,v3=0;
par/or do
    emit a => 2;
    v1 = 2;
with
    await a;
    v3 = 2;
with
    v2 = 2;
end
escape v1+v2+v3;
]],
    _ana = {
        --unreachs = 2,
        acc = 1,
        abrt = 5,
    },
    --run = 4,        -- TODO: stack change
    run = 2,
}

Test { [[
var int ret = 0;
par/or do
    ret = 1;
with
    ret = 2;
end
ret = ret * 2;
escape ret;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
    run = 2,
}

-- 1st to escape and terminate
Test { [[
event int a;
var int ret=9;
par/or do
    par/or do
        emit a => 2;
    with
        ret = 3;
    end;
with
    var int aa = await a;
    ret = aa + 1;
end;
escape ret;
]],
    _ana = {
        --unreachs = 2,
        abrt = 4,
        acc = 1,
    },
    --run = 3,
    run = 9,
}

-- 1st to escape and terminate
-- TODO: STACK
Test { [[
event int a;
var int ret=9;
par/or do
    var int aa = await a;
    ret = aa + 2;
with
    par/or do
        emit a => 2;
    with
        ret = 3;
    end;
end;
escape ret;
]],
    _ana = {
        --unreachs = 2,
        abrt = 4,
        acc = 1,
    },
    run = 9,
    --run = 4,
}

Test { [[
input int A;
var int a;
par do
    a = await A;
    escape a;
with
    a = await A;
    escape a;
end;
]],
    _ana = {
        acc = 4,
        abrt = 3,
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
escape a;
]],
    _ana = {
        abrt = 3,
    },
    run = {
        ['1~>A'] = 1,
        ['2~>A'] = 2,
    },
    --todo = 'nd excpt',
}
Test { [[
input int A;
var int a=10;
par/or do
    await A;
with
    a = await A;
end;
escape a;
]],
    _ana = {
        abrt = 3,
    },
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
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
    run = {
        ['1~>A'] = 10,
        ['2~>A'] = 10,
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
    a = 11;
end;
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
    escape a;
end;
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input int A;
loop do
    par/or do
        await A;    // 4
    with
        await A;    // 6
        if 1 then
            break;  // 8
        end;
    end;
end;
escape 0;
]],
    _ana = {
        abrt = 5,
    },
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
    _ana = {
        abrt = 1,
        unreachs = 1,
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
    _ana = {
        isForever = true,
    },
}

Test { [[
input int A;
var int a = par do
    await A;
    var int v = 10;
    escape a;
with
    await A;
    escape a;
end;
escape a;
]],
    todo = '"a"s deveriam ser diferentes',
    _ana = {
        acc = 1,
        abrt = 1,
    },
}

Test { [[
input void A,B;
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
    escape a;
end;
escape a;
]],
    run = { ['~>A']=10, ['~>B']=10 },
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input void A,B;
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
    escape a;
end;
escape a;
]],
    run = { ['~>A']=5, ['~>B;~>A']=10 },
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input int A,B;
var int a = 0;
par/or do
    par/or do
        var int v = await A;
        escape v;
    with
        await B;
    end;
    a = 10;
with
    await A;
end;
escape a;
]],
    _ana = {
        abrt = 3,
    },
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
escape v;
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
escape v;
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
escape v;
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
escape v;
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
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
escape v;
]],
    _ana = {
        --unreachs = 3,
        --dfa = 'unreachable statement',
        abrt = 1,
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
escape v;
]],
    _ana = {
        acc = 2,     -- TODO: should be 0
        abrt = 1,
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
escape v;
]],
    _ana = {
        unreachs = 1,
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
escape a;
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
escape 1;
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
escape 1;
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
escape 1;
]],
    run = {
        ['~>30ms ; 0~>A ; ~>50ms'] = 1,
        ['0~>A ; ~>40ms'] = 1,
        ['0~>A ; ~>20ms ; ~>20ms'] = 1,
    }
}

Test { [[
input void OS_START;
event int a,b,c;
var int cc = 1;
par/and do
    await OS_START;
    emit b => 1;
    emit c => 1;
with
    await b;
    par/or do
    with
        par/or do
        with
            cc = 5;
        end;
    end;
end;
escape cc;
]],
    _ana = {
        abrt = 6,   -- TODO: not checked
    },
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
escape a;
]],
    _ana = {
        acc = 1,
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
escape a;
]],
    _ana = {
        acc = 1,
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
escape a;
]],
    _ana = {
        acc = 1,
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
escape a;
]],
    _ana = {
        acc = 1,
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
escape dt;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape dt;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape dt;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape dt;
]],
    _ana = {
        --unreachs = 1,
        acc = 2,
        abrt = 4,
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
    escape 1;
with
    dt = await 10us;
    await A;
    dt = await 10us;
    escape 2;
end;
]],
    _ana = {
        --unreachs = 1,
        abrt = 4,
        acc = 3,
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
escape ret;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape ret;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape dt;
]],
    _ana = {
        acc = 1,
        abrt = 4,
        --unreachs = 1,
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
escape dt;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape dt;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape ret;
]],
    _ana = {
        acc = 2,
        abrt = 3,
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
escape ret;
]],
    _ana = {
        acc = 2,
        abrt = 3,
    },
    run = {
        ['~>12ms ; 0~>A ; ~>1ms ; 0~>B ; ~>27ms'] = 1,
        ['~>12ms ; 0~>B ; ~>1ms ; 0~>A ; ~>26ms'] = 2,
    }
}

-- Boa comparacao de unreachs vs abrt para timers
Test { [[
var int dt;
par/or do
    await 10ms;
    dt = await 10ms;
with
    dt = await 30ms;
end;
escape dt;
]],
    _ana = {
        acc = 1,
        abrt = 4,
        --unreachs = 1, -- apos ~30
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
escape dt;
]],
    _ana = {
        acc = 1,
        abrt = 4,
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
escape ret;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
    await a;                // 4
    await 10ms;             // 5
    x = 0;
with
    var int bb = await b;   // 8
    emit a => bb;              // 9
    await 10ms;
    x = 1;
with
    emit b => 1;       // 13
    x = 2;
    await FOREVER;
end;
escape x;
]],
    _ana = {
        abrt = 3,
        acc  = 2,    -- TODO: timer kills timer
        unreachs = 0,    -- TODO: timer kills timer
    },
    --run = { ['~>10ms']=0 },
}

Test { [[
event int a, b;
var int x;
var int bb;
par/or do
    await a;
    await 10ms;
    x = 0;
with
    bb = await b;
    await 10ms;
    x = 1;
with
    emit b => 1;
    emit a => bb;
    x = 2;
    await FOREVER;
end;
escape x;
]],
    _ana = {
        abrt = 3,
        acc = 3,     -- TODO: timer kills timer
        unreachs = 0,    -- TODO: timer kills timer
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
    var int b = 1;
    var int a = b;
    x = a;
end;
escape x;
]],
    _ana = {
        abrt = 5,
        acc = 1,
        --unreachs = 4,
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
    escape 1;
with
    await A;
    escape 2;
end;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
    escape 1;
with
    await A;
    escape 2;
end;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input int A,B, Z;
par do
    loop do
        par/or do
            await A;    // 5
            break;      // 6
        with
            await Z;
        with
            await B;
            break;
        end;
        await Z;
    end;
    escape 1;           // 15
with
    await A;            // 17
    escape 2;           // 18
end;
]],
    _ana = {
        abrt = 4,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 4,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 4,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
    _ana = {
        isForever = true,
        acc = 1,
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
    _ana = {
        isForever = true,
        acc = 1,       -- fiz na mao!
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
    _ana = {
        isForever = true,
        acc = 1,       -- nao fiz na mao!!!
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
escape a;
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
escape a;
]],
    _ana = {
        --acc = 1,
        acc = 3,
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
escape a;
]],
    _ana = {
        --acc = 1,
        acc = 3,
    },
}
Test { [[
input int A;
var int a;
par do
    loop do
        if a then           // 5
            await A;
        else
            await A;
            await A;
            var int v = a;  // 10
        end;
    end;
with
    loop do
        await A;
        a = await A;        // 16
    end;
with
    loop do
        await A;
        await A;
        a = await A;        // 22
    end;
end;
]],
    _ana = {
        isForever = true,
        acc = 5,
    },
}
Test { [[
var int v = par do
            escape 0;
        with
            escape 0;
        end;
if v then
    escape 1;
else
    if 1==1 then
        escape 1;
    else
        escape 0;
    end;
end;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
var int a;
var int v = par do
            escape 0;
        with
            escape 0;
        end;
if v then
    a = 1;
else
    a = 1;
end;
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
var int v = par do
            escape 1;
        with
            escape 2;
        end;
escape v;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 1,
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
escape a;
]],
    _ana = {
        abrt = 4,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 4,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 4,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 4,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 4,
        acc = 1,
    },
}

Test { [[
par/or do
    loop do
        break;  // 3
    end
with
    nothing;    // 6
end
escape 0;
]],
    _ana = {
        abrt = 4,   -- TODO: break is inside par/or (should be 3)
    },
    run = 0,
}

Test { [[
var int a;
par/or do
    loop do
        await 10ms;     // 4
        if (1) then
            break;      // 6
        end;
    end;
    a = 1;
with
    await 100ms;        // 11
    a = 2;
end;
escape a;
]],
    _ana = {
        abrt = 4,   -- TODO: break is inside par/or (should be 3)
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 4,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 3,
        --unreachs = 1,
        acc = 1,
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
escape a;
]],
    --todo = 'wclk_any=0',
    _ana = {
        acc = 1,
        abrt = 3,
        unreachs = 1,
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
escape a;
]],
    todo = 'wclk_any=0',
    _ana = {
        acc = 3,
    },
}

Test { [[
input void A;
var int a;
par/or do
    await A;
    await (10)us;
    a = 1;
with
    await (10)us;
    a = 2;
end;
escape a;
]],
    _ana = {
        --unreachs = 1,
        acc = 1,
        abrt = 3,
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
escape x;
]],
    _ana = {
        abrt = 5,
        acc = 1,
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
    _ana = {
        isForever = true,
        acc = 1,
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
    _ana = {
        isForever = true,
        acc = 1,
    },
}

Test { [[
event void a;
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
escape x;
]],
    _ana = {
        abrt = 3,
        acc = 3,
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
        emit a => 1;
    with
        await a;
    end;
end;
]],
    _ana = {
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
escape 0;
]],
    _ana = {
        --unreachs = 1,
        acc = 1,
        abrt = 1,
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
escape ret;
]],
    _ana = {
        --unreachs = 1,
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
    _ana = {
        loop = true,
    },
}

Test { [[
event int a;
par do
    loop do
        par/or do
            emit a => 1;
        with
            await a;
        end;
    end;
with
    var int aa = await a;
    emit a => aa;
end;
]],
    _ana = {
        abrt = 1,
        acc = 2,
        isForever = true,
    },
    loop = 'line 3 : tight loop',
}

Test { [[
input int A;
event int a, d, e, i, j;
var int dd, ee;
par/and do
    await A;
    emit a => 1;
with
    dd = await a;
    emit i => 5;
with
    ee = await a;
    emit j => 6;
end;
escape dd + ee;
]],
    --trig_wo = 2,
    run = {
        ['0~>A'] = 2,
    }
}

Test { [[
event int a;
var int aa;
par do
    emit a => 1;
    aa = 1;
with
    escape aa;
end;
]],
    _ana = {
        --nd_esc = 1,
        abrt = 1,
        --unreachs = 1,
        --trig_wo = 1,
        acc = 1,
    },
}

Test { [[
event int a;
var int v,aa=1;
loop do
    par do
        v = aa;
    with
        await a;
    end;
end;
]],
    _ana = {
        isForever = true,
        unreachs = 1,
        reachs = 1,
    },
}
Test { [[
input int A;
event int b;
var int a=1,v;
par do
    loop do
        v = a;
        await b;
    end;
with
    await A;
    emit b => 1;
end;
]],
    _ana = {
        isForever = true,
    },
}
Test { [[
input int A,B;
event int a;
par do
    par do
        await A;
        emit a => 1;
    with
        await a;
        await a;
    end;
with
    var int v = await B;
    escape v;
end;
]],
    _ana = {
        --unreachs = 1,
        reachs = 1,
    },
    run = {
        ['0~>A ; 10~>B'] = 10,
    }
}

Test { [[
input void OS_START;
event int a;
var int b;
par/or do
    b = await a;
with
    await OS_START;
    emit a => 3;
end;
escape b+b;
]],
    _ana = {
        --unreachs = 1,
        --trig_wo = 1,
    },
    run = 6,
}

Test { [[
event int a;
var int b;
par/or do
    b = await a;        // 4
with
    emit a => 3;           // 6
with
    var int a = b;
end;
escape 0;
]],
    _ana = {
        abrt = 5,
        --unreachs = 2,
        acc = 1,
        --trig_wo = 1,
    },
}

Test { [[
input void OS_START;
event int b;
var int i;
par/or do
    await OS_START;
    emit b => 1;
    i = 2;
with
    await b;
    i = 1;
end;
escape i;
]],
    _ana = {
        --nd_esc = 1,
        unreachs = 0,
    },
    run = 1,
}
Test { [[
input void OS_START;
event int b,c;
var int cc;
par/or do
    await OS_START;
    emit b => 1;
    cc = await c;
with
    await b;
    cc = 5;
    emit c => 5;
end;
escape cc;
]],
    _ana = {
        --nd_esc = 1,
        unreachs = 0,
        --trig_wo = 1,
    },
    run = 5,
}
Test { [[
input int A;
var int ret;
loop do
    var int v = await A;
    if v == 5 then
        ret = 10;
        break;
    else
    end;
end;
escape ret;
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
    var int b = await B;
    a = a + b;
    if a == 5 then
        escape 10;
    end;
end;
escape 0;   // TODO
]],
    _ana = {
        unreachs = 1,
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
            escape v;
        end;
    end;
escape ret;
]],
    run = {
        ['1~>A ; 5~>B'] = 5,
        ['1~>A ; 1~>A ; 3~>B ; 1~>A ; 5~>B'] = 5,
    }
}

Test { [[
input int A;
event int a;
var int aa;
loop do
    var int v = await A;
    if v==2 then
        escape aa;
    end;
    emit a => v;
    aa = v;
end;
]],
    _ana = {
        --trig_wo = 1,
    },
    run = {
        ['0~>A ; 0~>A ; 3~>A ; 2~>A'] = 3,
    }
}

Test { [[
input int A;
event int a;
var int aa;
loop do
    var int v = await A;
    if v==2 then
        escape aa;
    else
        if v==4 then
            break;
        end;
    end;
    emit a => v;
    aa = v;
end;
escape aa-1;
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
    escape a;
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
escape 1;
]],
    run = {
        ['2~>A ; 4~>A'] = 1,
        ['0~>B ; 0~>B ; 2~>A ; 0~>B'] = 1,
    }
}

    -- UNREACH

Test { [[
input int A,B;
var int ret = 0;
par/or do await A; with await B; end;
par/or do
    ret=await A;
with
    ret=await B;
end;
escape ret;
]],
    run = {
        ['1~>A;2~>B;1~>A'] = 2,
        ['2~>B;1~>A;2~>B'] = 1,
    },
}

Test { [[
input int A,B;
var int ret;
par/or do
    par/or do
        await A;
    with
        await B;
    end;
    par/or do
        await A;
    with
        await B;
    end;
    par/or do
        ret=await A;
    with
        ret=await B;
    end;
with
    await B;
    await B;
    await B;
    await B;
end;
escape ret;
]],
    _ana = {
        abrt = 8,   -- TODO: not checked
        --unreachs = 1,
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
escape v;
]],
    _ana = {
        acc = 1,     -- should be 0
        abrt = 3,
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
escape ret;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape v;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape v;
]],
    _ana = {
        abrt = 6,   -- TODO: not checked
    },
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
escape v;
]],
    _ana = {
        abrt = 6,   -- TODO: not checked
        --unreachs = 1,
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
escape v;
]],
    _ana = {
        acc = 2,
        abrt = 6,
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
escape v;
]],
    _ana = {
        acc = 2,
        abrt = 10,
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
escape v;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape v;
]],
    _ana = {
        --unreachs = 2,
        acc = 1,
        abrt = 7,   -- TODO: not checked
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
        escape v;
    end;
with
    var int v = await A;
    escape v;
end;
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
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
escape v;
]],
    run = {
        ['0~>A ; 0~>A ; 10~>B'] = 10,
    },
}
Test { [[
input int A,B,Z;
var int a = 0;
par do
    loop do
        if a then
            a = await A;
            break;
        else
            await B;
        end;
    end;
    escape a;
with
    await B;
    a = await Z;
    escape a;
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
    escape v;
else
    var int v = await B;
    escape v;
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
escape 1;
]],
    _ana = {
        isForever = true,
        unreachs = 1,
    },
}
Test { [[
par/or do
with
end
escape 1;
]],
    _ana = {
        abrt = 3,
    },
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
    _ana = {
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
    _ana = {
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
escape v;
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
var int g = await G;
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
escape v;
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
    escape 1;
with
    escape a;
end;
]],
    _ana = {
        abrt = 3,
    acc = 2,
    },
}
Test { [[
input int B;
var int a;
par do
    await B;
    a = 1;
    escape 1;
with
    await B;
    escape a;
end;
]],
    _ana = {
        acc = 2,
        abrt = 3,
    },
}
Test { [[
input int B,Z;
event int a;
var int aa;
par do
    await B;
    aa = 1;
    escape 1;
with
    par/or do
        await a;
    with
        await B;
    with
        await Z;
    end;
    escape aa;
end;
]],
    _ana = {
        --unreachs = 1,
        abrt = 3,
        acc = 2,
    },
}
Test { [[
input int Z;
event int a;
var int aa;
par do
    emit a => 1;       // 5
    aa = 1;
    escape 10;
with
    par/or do
        await a;    // 10
    with
    with
        await Z;
    end;
    escape aa;
end;
]],
    _ana = {
        acc = 1,
        abrt = 3,
        --unreachs = 2,    -- +1 native unreachs
    },
    --run = 1,
    run = 10,
}
Test { [[
input void OS_START;
event int a;
par do
    await OS_START;
    emit a => 1;
with
    var int aa = await a;
    escape aa;
end;
]],
    _ana = {
        --unreachs = 1,
        --nd_esc = 1,
    },
    run = 1,
}
Test { [[
input int B,Z;
event int a;
var int aa;
par/or do
    await B;
    emit a => 5;
with
    aa = await a;
    aa = aa + 1;
end;
escape aa;
]],
    _ana = {
        --unreachs = 1,
        --nd_esc = 1,
    },
    run = {
        ['1~>B'] = 6,
    },
}
Test { [[
input int B,Z;
event int a;
var int aa;
par/or do
    await B;
    emit a => 5;
with
    par/and do
        aa = await a;   // 9
    with
        aa = await a;   // 11
    end
    aa = aa + 1;
end;
escape aa;
]],
    _ana = {
        --unreachs = 1,
        --nd_esc = 1,
        acc = 1,
    },
    run = {
        ['1~>B'] = 6,
    },
}
Test { [[
input int B;
event int a;
var int aa;
par/or do
    await B;        // 5
    emit a => 5;
    aa = 5;
with
    par/and do      // 9
        await B;    // 10
    with
        await a;
    end
    aa = aa + 1;
end;
escape aa;
]],
    _ana = {
        acc = 2,
        --unreachs = 1,
        abrt = 3,
    },
    run = {
        --['1~>B'] = 6,
        ['1~>B'] = 5,
    },
    --todo = 'nd excpt',
}
Test { [[
input int B,Z;
event int a;
var int aa=5;
par/or do
    await B;
    emit a => 5;
with
    par/and do
        aa = await a;
    with
        await B;
    with
        await Z;
    end;
    aa = aa + 1;
end;
escape aa;
]],
    _ana = {
        abrt = 3,
    },
    run = {
        ['1~>B'] = 5,
        ['2~>Z; 1~>B'] = 5,
    },
}
Test { [[
event int a;
var int aa = 1;
par do
    emit a => 0;
    escape aa;  // 5
with
    par/and do  // 7
        aa = await a;
    with
    end;
    escape aa;
end;
]],
    _ana = {
        acc = 1,
        abrt = 1,
        --unreachs = 1,
    },
    run = 1,
}
Test { [[
input int Z;
event int a;
var int aa = 0;
par do
    emit a => 1;
    aa = 1;
    escape aa;
with
    par/and do
        aa = await a;
    with
    with
        await Z;
    end;
    escape aa;
end
]],
    _ana = {
        acc = 1,
        --nd_esc = 1,
        abrt = 1,
    },
    run = 1,
}
Test { [[
input int Z;
event int a;
var int aa = 0;
par do
    emit a => 1;
    aa = 1;
    escape aa;
with
    par/and do
        aa = await a;
    with
    with
        await Z;
    end;
    escape aa;
end
]],
    safety = 2,
    _ana = {
        acc = 5,
        --nd_esc = 1,
        abrt = 1,
    },
    run = 1,
}
Test { [[
input int B,Z;
event int a;
var int aa;
par do
    await B;
    aa = 1;
    escape aa;
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
    _ana = {
        --unreachs = 1,
        abrt = 1,
        reachs = 1,
    },
    run = {
        ['1~>B'] = 1,
    },
}
Test { [[
input int B,Z;
event int aa;
var int a;
par do
    await B;
    a = 1;
    escape a;
with
    par/and do
        await aa;
    with
        await B;
    with
        await Z;
    end;
    escape a;
end;
]],
    _ana = {
        abrt = 3,
        --unreachs = 2,
        acc = 2,
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
escape 1;
]],
    _ana = {
        abrt = 4,
        --unreachs = 3,
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
escape 1;
]],
    _ana = {
        abrt = 3,
        unreachs = 2,
    },
    run = 1,
}

Test { [[
input int A;
par/or do
    escape 1;
with
    await A;
end;
]],
    _ana = {
        --unreachs = 2,
        abrt = 1,
        reachs = 1,
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
            escape 1;
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
escape 2;       // executes last
]],
    _ana = {
        --unreachs = 5,
        abrt = 4,
    },
    run = 2,
}

Test { [[
input int A;
loop do
    par do
        break;
    with
        escape 1;
    with
        await A;
    end;
end;
escape 2;   // executes last
]],
    _ana = {
        unreachs = 1,
        abrt = 5,
    },
    run = 2,
}

Test { [[
input int A;
loop do
    par do
        break;          // 4
    with
        par do
            escape 1;   // 7
        with
            await A;    // 9
            // unreachable
        end;
    end;
end;
escape 2;   // executes last
]],
    _ana = {
        unreachs = 1,
        abrt = 4,
    },
    run = 2,
}

Test { [[
input void A;
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
escape 1;
]],
    _ana = {
        abrt = 6,       -- TODO: not checked
    },
    run = { ['~>A'] = 1, },
}
Test { [[
par/or do
with
    par/or do
    with
    end;
end;
escape 1;
]],
    _ana = {
        abrt = 6,
    },
    run = 1,
}
Test { [[
event int a;
var int aa;
par/or do
    aa = 1;
with
    par/or do
        await a;
    with
    end;
    escape aa;
end;
escape aa;
]],
    _ana = {
        --unreachs = 1,
        abrt = 4,
        acc  = 1,
    },
}
Test { [[
input int B;
event int a;
var int aa;
par do
    await B;
    aa = 1;
    escape aa;
with
    await B;
    par/or do
        await a;
    with
    end;
    escape aa;
end;
]],
    _ana = {
        --unreachs = 1,
        abrt = 4,
        acc = 2,
    },
}
Test { [[
var int a = 0;
par do
    escape a;
with
    escape a;
end;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
var int a;
par do
    escape a;
with
    a = 1;
    escape a;
end;
]],
    _ana = {
        acc = 2,
        abrt = 3,
    },
}
Test { [[
var int a;
par do
    a = 1;
    escape a;
with
    escape a;
end;
]],
    _ana = {
        abrt = 3,
        acc = 2,
    },
}
Test { [[
var int a;
par/or do
    a = 1;
with
    a = 1;
end;
escape a;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape a;
]],
    _ana = {
        abrt = 9,
        acc = 3,
    },
}
Test { [[
input int A;
par do
    var int v = await A;
    escape v;
with
    var int v = await A;
    escape v;
end;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

-- TODO: STACK
Test { [[
event int a;
var int aa=10;
par/or do
    await a;
with
    emit a => 1;
    aa = 1;
end;
escape aa;
]],
    _ana = {
        abrt = 1,
        --unreachs = 1,
        acc = 1,
        --trig_wo = 1,
    },
    run = 1,
    --run = 10,
}
Test { [[
event int a;
par/or do
    emit a => 1;
with
    emit a => 1;
end;
escape 1;
]],
    _ana = {
        abrt = 3,
        acc = 1,
    },
    run = 1,
}
Test { [[
event int a,b;
var int aa=2,bb=2;
par/or do
    emit a => 1;
    aa = 2;
with
    emit b => 1;
    bb = 5;
end;
escape aa+bb;
]],
    _ana = {
        abrt = 3,
    },
    --run = 7,
    run = 4,
}
Test { [[
var int a=0, b=0;
par/or do
    a=2;
with
    b=3;
end;
escape a+b;
]],
    _ana = {
        abrt = 3,
    },
    --trig_wo = 2,
    --run = 5,
    run = 2,
}
Test { [[
event int a;
var int aa;
var int v = par do
    emit a => 1;
    aa = 1;
    escape aa;
with
    emit a => 1;
    escape aa;
with
    emit a => 1;
    escape aa;
end;
escape v;
]],
    _ana = {
        acc = 8, -- TODO: not checked
        abrt = 9,
        --trig_wo = 3,
    },
}
Test { [[
var int a,v;
v = par do
    escape 1;
with
    escape 1;
with
    escape 1;
end;
escape v;
]],
    _ana = {
        acc = 3,
        abrt = 9,
    --trig_wo = 1,
    },
}
Test { [[
input int A;
var int a = 0;
par do
    await A;
    escape a;
with
    await A;
    escape a;
end;
]],
    _ana = {
        abrt = 3,
        acc = 1,
    },
}
Test { [[
input int A;
var int a;
par do
    await A;
    escape a;
with
    await A;
    a = 1;
    escape a;
end;
]],
    _ana = {
        abrt = 3,
        acc = 2,
    },
}
Test { [[
input int A;
event int a;
await A;
emit a => 1;
await A;
emit a => 1;
escape 1;
]],
--~A;1~>a;~A;1~>a]],
    --trig_wo = 2,
    run = {
        ['0~>A ; 10~>A'] = 1,
    },
}
Test { [[
input void OS_START;
input int A;
event int a;
var int ret;
par/or do
    loop do
        var int v = await A;
        emit a => v;
    end;
with
    await A;
    await A;
    ret = await a;
end;
escape ret;
]],
    _ana = {
        acc = 1,
        --nd_esc = 1,
    },
    run = { ['1~>A;2~>A;3~>A']=3 },
}
Test { [[
input void OS_START;
event int a;
par do
    await OS_START;
    emit a => 1;
    escape 1;
with
    var int aa = await a;
    aa = aa + 1;
    escape aa;      // 10
with
    await a;        // 12
    await FOREVER;
end;
]],
    _ana = {
        --nd_esc = 1,
        --unreachs = 1,
        abrt = 1,
    },
    run = 2,
}
Test { [[
event int a;
var int aa;
par/or do
    emit a => 1;
    aa = 1;
with
    aa = await a;
    aa = aa + 1;
with
    var int aa = await a;
    var int v = aa;
end;
escape aa;
]],
    _ana = {
        --nd_esc = 1,
        --unreachs = 1,
        acc = 2,
        abrt = 2,
    },
}
Test { [[
event int a;
var int aa;
par/or do
    emit a => 1;
    aa = 1;
with
    aa = await a;
    aa = aa + 1;
with
    var int aa = await a;
    var int v = aa;
end;
escape aa;
]],
    safety = 2,
    _ana = {
        --nd_esc = 1,
        --unreachs = 1,
        acc = 5,
        abrt = 2,
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
    _ana = {
        isForever = true,
        acc = 1,
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
    _ana = {
        isForever = true,
        acc = 1,
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
escape a;
]],
    _ana = {
        --unreachs = 1,
        acc = 1,
        abrt = 4,
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
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 3,
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
escape a;
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
escape v;
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
escape v;
]],
    _ana = {
        abrt = 3,
    },
    run = {
        ['10~>A ; 1~>A'] = 10,
        ['9~>A'] = 9,
        ['8~>A'] = 8,
    }
}
Test { [[
var int a=0, b=0, c=0, d=0;
event int aa, bb, cc, dd;
par/or do
    par/and do
        await aa;
    with
        await bb;
    with
        await cc;
    end;
    await dd;
with
    par/or do
        emit bb => 1;
        b=1;
    with
        emit aa => 2;
        a=2;
    with
        emit cc => 3;
        c=3;
    end;
    emit dd => 4;
    d=4;
end;
escape a+b+c+d;
]],
    _ana = {
        acc = 3,
        abrt = 10,  -- TODO: not checked
        --unreachs = 1,
    },
    --run = 10,
    run = 5,
}
Test { [[
event int a, b, c;
var int aa=0, bb=0, cc=0;
par/or do
    par/or do
        await a;
        aa=10;
    with
        await b;
    with
        await c;
    end;
with
    par/or do
        emit a => 10;
        aa=10;
    with
        emit b => 20;
        bb=20;
    with
        emit c => 30;
        cc=30;
    end;
end;
escape aa+bb+cc;
]],
    _ana = {
        acc = 3,
        abrt = 10,  -- TODO: not checked
        --unreachs = 4,
    },
    --run = 60,
    run = 10,
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
        emit a => 10;
    with
        emit b => 20;
    with
        emit c => 30;
    end;
end;
escape 10;
]],
    _ana = {
        acc = 3,
        abrt = 10,  -- TODO: not checked
        reachs = 1,
        --trig_wo = 3,
    },
    --run = 60,
    run = 10,
}
Test { [[
event int a;
par/or do
    emit a => 1;
with
    emit a => 1;
    await a;
end;
escape 0;
]],
    _ana = {
        acc = 2,
        abrt = 1,
        --unreachs = 1,
        --trig_wo = 2,
    },
}
Test { [[
event int a;
par/or do
    emit a => 1;
    await a;
with
    emit a => 1;
end;
escape 0;
]],
    _ana = {
        acc = 2,
        abrt = 1,
        --unreachs = 1,
        --trig_wo = 2,
    },
}
Test { [[
event int a;
par do
    emit a => 1;
with
    emit a => 1;
    await a;
end;
]],
    _ana = {
        isForever = true,
        acc = 2,
        --unreachs = 1,
        reachs = 1,
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
escape 1;
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
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
escape v;
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
    _ana = {
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
escape x;
]],
    _ana = {
        acc = 1,
        abrt = 4,
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
    escape ret;
end
escape ret;
]],
    _ana = {
        unreachs = 1,
        abrt = 3,
    },
    run = 5,
}

Test { [[
var int ret = 10;
loop do
    par/or do
        escape 100;
    with
        break;
    end
    ret = 5;
    await 1s;
end
escape ret;
]],
    _ana = {
        abrt = 3,
        unreachs = 3,
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
escape a;
]],
    _ana = {
        abrt = 6,
    },
    run = 2,
}

Test { [[
var int b;
par do
    escape 3;
with
    b = 1;
    escape b+2;
end;
]],
    _ana = {
        abrt = 3,
        acc = 1,
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
escape v;
]],
    _ana = {
        unreachs = 1,
        abrt = 3,
        acc = 1,     -- should be 0
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
escape v1 + v2;
]],
    _ana = {
        unreachs = 1,
        abrt = 4,
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
escape v;
]],
    _ana = {
        unreachs = 1,
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
    --ast = "line 4 : after `;´ : expected `end´",
    parser = 'line 4 : before `;´ : expected statement',
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
escape v1 + v2;
]],
    _ana = {
        unreachs = 1,
        abrt = 3,
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
escape 0;
]],
    _ana = {
        unreachs = 1,
        abrt = 3,
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
escape v1+v2+v3;
]],
    _ana = {
        unreachs = 1,
        abrt = 3,
    },
    run = {
        --['2~>A'] = 5,
        ['2~>A'] = 3,
    }
}

-- TODO: parei com abrt aqui!!!
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
escape v1+v2+v3+v4+v5+v6;
]],
    _ana = {
        unreachs = 2,
        abrt = 6,
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
escape v1+v2+v3+v4+v5+v6;
]],
    _ana = {
        unreachs = 2,
        abrt = 6,
    },
    --run = 21,
    run = 7,
}

Test { [[
input void A;
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
escape v1+v2+v3+v4+v5+v6;
]],
    _ana = {
        unreachs = 2,
        abrt = 6,
    },
    --run = { ['~>A'] = 21 },
    run = { ['~>A'] = 1 },
}

Test { [[
input int A;
var int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
loop do
    par/or do
        await A;    // 5
        v1 = 1;
    with
        loop do     // 8
            par/or do
                await A;    // 10
                v2 = 2;
            with
                await A;    // 13
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
escape v1+v2+v3+v4+v5+v6;
]],
    _ana = {
        unreachs = 2,
        abrt = 6,
    },
    --run = { ['1~>A']=21 },
    run = { ['1~>A']=7 },
}

Test { [[
var int v1=0,v2=0,v3=0,v4=0,v5=0,v6=0;
loop do
    par do
        escape 1;           // acc 1
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
        escape 1;           // acc 1
    end;
end;
// unreachable
escape v1+v2+v3+v4+v5+v6;   // TODO: unreach
]],
    _ana = {
        unreachs = 3,
        acc = 1,
        abrt = 3,
    },
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
escape v;
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
    escape a+1;
with
    await Z;
    escape a;
end;
a = a + 1;
await D;
escape a;
]],
    run = { ['0~>A;0~>B;0~>Z;0~>D'] = 2 }
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
    escape a+1;
with
    await Z;
    escape a;
end;
a = a + 1;
await D;
escape a;
]],
    run = { ['0~>A;0~>B;0~>Z;0~>D'] = 2 },
    safety = 2,
    _ana = {
        acc = 3,
    },
}

Test { [[
input int A,B,Z,D;
var int a = 0;
a = par do
    par do
        await A;
        escape a;
    with
        await B;
        escape a;
    end;
with
    await Z;
    escape a;
end;
a = a + 1;
await D;
escape a;
]],
    run = { ['0~>A;0~>B;0~>Z;0~>D'] = 1 }
}

Test { [[
input int A,B,Z,D;
var int a = 0;
a = par do
    par do
        await A;
        escape a;
    with
        await B;
        escape a;
    end;
    // unreachable
with
    await Z;
    escape a;
end;
a = a + 1;
await D;
escape a;
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
escape a;
]],
    _ana = {
        abrt = 2,
    },
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
        var int v = await B;
        b = v;
        break;
    end;
    b = a;
    break;
end;
a = a + 1;
escape a;
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
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
escape a;
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
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
escape b;
]],
    _ana = {
        --dfa = 'unreachable statement',
        unreachs = 3,
        abrt = 1,
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
escape b;
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
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
                escape v;   // prio 1
            end;
            a = a + 1;
            escape a;
        end;
    a = a + 2 + b;
end;
escape a;
]],
    _ana = {
        abrt = 2,
        unreachs = 1,
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
                escape v;
            end;
            a = a + 1;
        end;
    a = a + 2 + b;
end;
escape a;
]],
    _ana = {
        abrt = 2,
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
escape a;
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
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
escape a;
]],
    _ana = {
        unreachs = 1,
        abrt = 1,
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
escape a;
]],
    _ana = {
        abrt = 2,
        unreachs = 3,
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
escape a;
]],
    _ana = {
        abrt = 1,
        unreachs = 3,
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
escape a;
]],
    _ana = {
        abrt = 1,
    },
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
escape a;
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
escape a;
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
escape a;
]],
    _ana = {
        abrt = 2,
    },
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
escape a+b+c+d+e+f;
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
escape v;
]],
    _ana = {
        --abrt = 1,
        unreachs = 2,
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
escape v;
]],
    _ana = {
        abrt = 1,
    },
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
    escape v;
with
    var int v = await A;
    escape v;
end;
]],
    _ana = {
        unreachs = 2,
        acc = 1,
        abrt = 2,
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
escape v;
]],
    _ana = {
        acc = 1, -- should be 0 (same evt)
        abrt = 1,
    },
    run = {
        ['0~>B ; 5~>A'] = 5,
    }
}

-- Testa prio em DFA.lua
Test { [[
input int A;
var int b=0,c=0,d=0;
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
escape b+c+d;
]],
    _ana = {
        unreachs = 1,
        abrt = 2,
    },
    --run = { ['0~>A'] = 9, }
    run = { ['0~>A'] = 6, }
}

Test { [[
input int A;
var int b=0,c=0,d=0;
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
escape b+c+d;
]],
    _ana = {
        abrt = 2,
    },
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
    escape b;
end;
]],
    _ana = {
        unreachs = 1,
    },
    run = {
        ['2~>Z ; 1~>A ; 1~>D'] = 2,
    }
}

Test { [[
input void A,Z;
var int ret = 0;
par/or do
    loop do
        par/and do
        with
            await A;
        end;
        ret = ret + 1;
    end;
with
    await Z;
end;
escape ret;
]],
    _ana = {
        unreachs = 1,
    },
    run = { ['~>A;~>A;~>Z']=2 },
}
Test { [[
input int A;
input void D,Z;
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
    escape b;
end;
]],
    _ana = {
        unreachs = 1,
    },
    run = { ['1~>A;~>Z;2~>A;~>D']=3 },
}

Test { [[
input int A;
var int c = 2;
var int d = par/and do
    with
        escape c;
    end;
c = d + 1;
await A;
escape c;
]],
    parser = "line 3 : after `par´ : expected `do´",
}

Test { [[
input int A;
var int c = 2;
var int d = par do
    with
        escape c;
    end;
c = d + 1;
await A;
escape c;
]],
    --abrt = 1,
    run = {
        ['0~>A'] = 3,
    }
}

    -- FRP
Test { [[
event int a,b;
par/or do
    emit a => 2;
with
    emit b => 5;
end;
escape 2;
]],
    _ana = {
        abrt = 1,
    },
    --run    = 7,
    run    = 2,
    --trig_wo = 2,
}

-- TODO: PAREI DE CONTAR unreachs AQUI
Test { [[
input int A;
var int counter;
event int c;
par/and do
    loop do
        await A;
        counter = counter + 1;
    end;
with
    loop do
        await c;
        // unreachable
        if counter == 200 then
            counter = 0;
        end;
    end;
end;
// unreachable
]],
    _ana = {
        isForever = true,
        unreachs = 3,
    },
}

Test { [[
input int A;
var int counter;
event int c;
par/and do
    loop do
        await A;
        counter = counter + 1;
    end;
with
    loop do
        await c;
        // unreachable
        if counter == 200 then
            counter = 0;
        end;
    end;
end;
// unreachable
]],
    safety = 2,
    _ana = {
        isForever = true,
        unreachs = 3,
        acc = 3,
    },
}

Test { [[
event int a;
emit a => 8;
escape 8;
]],
    run = 8,
    --trig_wo = 1,
}

Test { [[
event int a;
par/and do
    emit a => 9;
with
    loop do
        await a;
    end;
end;
]],
    _ana = {
        acc = 1,
        isForever = true,
        unreachs = 1,
        --trig_wo = 1,
    },
}

Test { [[
event int a;
par/and do
    emit a => 9;
with
    loop do
        await a;
    end;
end;
]],
    _ana = {
        acc = 1,
        isForever = true,
        unreachs = 1,
    },
}

Test { [[
input int A;
event int a,b;
var int v;
par/or do
    v = await A;
    par/or do
        emit a => 1;
    with
        emit b => 1;
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
escape v;
]],
    _ana = {
        abrt = 2,
    },
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
        emit a => 8;
    with
        emit b => 5;
    end;
    var int v = await D;
    escape v;
with
    c = 0;
    loop do
        var int aa=0,bb=0;
        par/or do
            aa=await a;
        with
            bb=await b;
        end;
        c = aa + bb;
    end;
with
    await E;
    escape c;
end;
]],
    _ana = {
        abrt = 2,
        unreachs = 1,
        acc = 0,
        --trig_wo = 1,
    },
    run = {
        ['1~>D ; 1~>E'] = 8,    -- TODO: stack change (8 or 5)
    }
}

Test { [[
input int D, E;
event int a, b;
var int c;
par/or do
    await D;
    par/or do
        emit a => 8;
    with
        emit b => 5;
    end;
    var int v = await D;
    escape v;
with
    c = 0;
    loop do
        var int aa=0,bb=0;
        par/or do
            aa=await a;
        with
            bb=await b;
        end;
        c = aa + bb;
    end;
with
    await E;
    escape c;
end;
]],
    safety = 2,
    _ana = {
        abrt = 2,
        unreachs = 1,
        acc = 3,
        --trig_wo = 1,
    },
    run = {
        ['1~>D ; 1~>E'] = 8,    -- TODO: stack change (8 or 5)
    },
}

Test { [[
input int A,B;
event int a,b;
var int v;
par/or do
    par/and do
        var int v = await A;
        emit a => v;
    with
        await B;
        emit b => 1;
    end;
    escape v;
with
    v = await a;
    escape v;       // 15
with
    var int bb = await b;
    escape bb;       // 18
end;
]],
    _ana = {
        --nd_esc = 2,
        unreachs = 4,
    },
    run = {
        ['10~>A'] = 10,
        ['4~>B'] = 1,
    }
}

Test { [[
input int A,B;
event int a,b;
var int v;
par/or do
    par/and do
        var int v = await A;
        emit a => v;
    with
        await B;
        emit b => 1;
    end;
    escape v;
with
    v = await a;
    escape v;       // 15
with
    var int bb = await b;
    escape bb;       // 18
end;
]],
    safety = 2,
    _ana = {
        acc = 4,
        --nd_esc = 2,
        unreachs = 4,
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
        var int a = await A;
        v = a;
        escape v;
    with
        await B;
        emit b => 1;
        escape v;
    end;
with
    var int aa = await a;
    escape aa;
with
    var int bb = await b;
    escape bb;
end;
]],
    _ana = {
        --nd_esc = 1,
    unreachs = 4,
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
    _ana = {
        isForever = true,
        acc = 1,
        unreachs = 1,
    },
}

-- EX.07: o `and` executa 2 vezes
Test { [[
input int D;
event int a;
loop do
    var int v = await D;
    emit a => v;
end;
]],
    _ana = {
        isForever = true,
        --trig_wo = 1,
    },
}

Test { [[
input int A, D, E;
event int a, b, c;
var int cc = 0;
par/or do
    loop do
        var int v = await A;
        emit a => v;
    end;
with
    var int bb = 0;
    loop do
        var int v = await D;
        bb = v + bb;
        emit b => bb;
    end;
with
    cc = 0;
    loop do
        var int aa,bb;
        par/or do
            aa = await a;
        with
            bb = await b;
        end;
        cc = aa+bb;
        emit c => cc;
    end;
with
    await E;
    escape cc;
end;
]],
    _ana = {
        unreachs = 1,
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
        emit b => 0;
        var int v = await Z;
        emit d => v;
    end;
with
    loop do
        var int dd = await d;
        emit e => dd;
    end;
end;
]],
    _ana = {
        isForever = true,
        unreachs = 1,
        --trig_wo = 2,
    },
}

    -- SLIDESHOW
Test { [[
input int A,Z,D;
var int i;
par/or do
    await A;
    escape i;
with
    i = 1;
    loop do
        var int o = par do
                await Z;
                await Z;
                var int c = await Z;
                escape c;
            with
                var int d = await D;
                escape d;
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
    _ana = {
        unreachs = 1,
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
escape v;
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
    escape a;
end;
]],
    _ana = {
        unreachs = 1,
        acc = 1,
        abrt = 1,
    },
}
Test { [[
input int A;
event int a;
var int aa;
par/and do
    await A;
    emit a => 1;
with
    aa = await a;   // 8
with
    aa=await a;     // 10
end;
escape aa;
]],
    _ana = {
        acc = 1,
    },
    run = {
        ['0~>A'] = 1,
    }
}

-- EX.01: dois triggers no mesmo ciclo
Test { [[
input int A;
event int a;
var int aa;
par/and do
    await A;
    emit a => 1;
with
    aa = await a;
    emit a => aa;
end;
escape aa;
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
    emit a => 1;
with
    await a;
    await a;
    escape 1;
end;
]],
    _ana = {
        --isForever = true,
        unreachs = 2,
    },
}
-- EX.03: trig/await + await
Test { [[
input int A;
event int a, b;
par/and do
    await A;
    par/or do
        emit a => 1;
    with
        emit b => 1;
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
escape 0;
]],
    _ana = {
        --isForever = true,
        unreachs = 4,
        abrt = 3,
    },
}

-- EX.03: trig/await + await
Test { [[
input int A;
event int a,b;
par/and do
    await A;
    par/or do
        emit a => 1;
    with
        emit b => 1;
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
escape 0;
]],
    _ana = {
        --isForever = true,
        unreachs = 4,
        abrt = 2,
    },
}

Test { [[
input int A;
event int a;
par/and do
    await A;
    emit a => 1;
with
    await a;
    await a;
    // unreachable
with
    await A;
    await a;
end;
// unreachable
escape 0;
]],
    _ana = {
        acc = 1,
        --isForever = true,
        unreachs = 2,
    },
}

Test { [[
input int A;
event int a;
var int aa=3;
par/and do
    await A;
    emit a => 1;
    aa=1;
    emit a => 3;
    aa=3;
with
    aa = await a;
end;
escape aa;
]],
    run = { ['1~>A']=3 }
}

-- TODO: STACK
Test { [[
input int A;
event int a;
var int aa;
par/or do
    await A;
    emit a => 1;
    emit a => 3;
    aa = 3;
with
    await a;
    aa = await a;
    aa = aa + 1;
end;
escape aa;
]],
    run = { ['1~>A;1~>A']=3 }
    --run = { ['1~>A;1~>A']=4 }
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
escape v;
]],
    _ana = {
        unreachs = 1,
    acc = 1,     -- should be 0
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
    emit a => 8;
with
    await a;
    await a;
    // unreachable
end;
// unreachable
escape 0;
]],
    _ana = {
        --isForever = true,
        unreachs = 2,
    },
}
Test { [[
input void OS_START;
input int A,B;
event int a;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    await B;
    emit a => 1;
with
    par/and do
    with
        await B;
    end;
    await a;
end;
escape 10;
]],
    _ana = {
        acc = 1,
        --isForever = true,
        --unreachs = 2,
    },
    run = { ['1~>B;1~>B']=10 },
}

Test { [[
input int A, B, Z;
event int a;
var int aa;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    await B;
    emit a => 10;
with
    par/or do
        await Z;
    with
        await B;
    end;
    aa = await a;
end;
escape aa;
]],
    _ana = {
        acc = 1,
    },
    run = { ['1~>B;1~>B']=10 },
}

Test { [[
input int A, B, Z;
event int a;
var int aa;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    await B;
    emit a => 10;
with
    par/or do
        await Z;
    with
        await B;
    end;
    aa = await a;
end;
escape aa;
]],
    _ana = {
        acc = 1,
    },
    run = { ['1~>B;1~>B']=10 },
}

Test { [[
input void A;
event int a,b;
par/and do
    await A;
    emit a => 1;
    await A;
    emit b => 1;
with
    await a;
    await b;
    escape 1;
end;
escape 0;
]],
    _ana = {
        --nd_esc = 1,
        unreachs = 2,
        --trig_wo = 1,
    },
    run = { ['~>A;~>A'] = 1 }
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
escape d;
]],
    run = {
        ['1~>A ; 0~>Z ; 9~>D ; 10~>E'] = 9,
        ['0~>B ; 0~>Z ; 9~>E ; 10~>D'] = 10,
    },
}
Test { [[
input void OS_START;
event int a;
var int aa;
par/and do
    await OS_START;
    emit a => 1;
with
    par/or do
    with
    end;
    aa = await a;
end;
escape aa;
]],
    _ana = {
        --acc = 1,
        abrt = 1,
    },
    run = 1,
}
Test { [[
event int a;
par/and do
    emit a => 1;
with
    par/or do
    with
        await a;
    end;
end;
escape 1;
]],
    _ana = {
        acc = 1,
        unreachs = 1,
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
input void OS_START, A;
var int v = 0;
event void a,b;
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
    await OS_START;
    emit b;
    emit b;
    await A;
    emit a;
    escape v;
end;
]],
    _ana = {
        unreachs = 1,
    },
    run = { ['~>A']=1 },
}

Test { [[
input void OS_START;
var int v = 0;
event int a, b;
par/or do
    loop do
        var int aa = await a;
        emit b => aa;
        v = v + 1;
    end
with
    await OS_START;
    emit a => 1;
    escape v;
end;
]],
    run = 1,
    _ana = {
        unreachs = 1,
    },
}

Test { [[
input void OS_START, F;
event void a, b;
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
    await OS_START;
    emit a;
    await FOREVER;
with
    await F;
end;
escape 1;
]],
    run = { ['~>F'] = 1 },
}

Test { [[
input void OS_START,A;
var int v = 0;
var int x = 0;
event int a, b;
par/or do
    loop do
        par/or do
            var int aa = await a;
            emit b => aa;
            v = v + 1;
        with
            loop do
                var int bb = await b;
                if bb then
                    break;
                end;
            end;
        end;
        x = x + 1;
    end;
with
    await OS_START;
    emit a => 1;
    await A;
    emit a => 1;
    await A;
    emit a => 0;
    escape v+x;
end;
escape 10;
]],
    --nd_esc = 1,
    --run = { ['~>A;~>A'] = 1 },
    run = { ['~>A;~>A'] = 4 },
    _ana = {
        unreachs = 1,
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
    escape v1 + v2;
end;
]],
    env = 'line 8 : variable/event "v1" is not declared',
}

Test { [[
var int v=2;
async (v) do
    var int a = v;
end;
escape v;
]],
    run = 2,
}

Test { [[
var int v=2;
var int x=v;
var int& px = x;
async (px, v) do
    px = v + 1;
end;
escape x + v;
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
escape a;
]],
    run = 1,
}

Test { [[
var int a = 0;
async (a) do
    a = 1;
    do
    end
end
escape a;
]],
    run = 1,
}

Test { [[
input void F;
var int v=2;
var int ret = 0;
par/or do
    async (ret,v) do        // nd
        ret = v + 1;
    end;
with
    v = 3;                  // nd
    await F;
end
escape ret + v;
]],
    _ana = {
        acc = 1,
    },
    run = 7,
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
    escape v1 + v2;
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
    escape v1 + v2;
end;
]],
    env = 'line 8 : variable/event "v1" is not declared',
}

Test { [[
input void A,F;
var int v=0;
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
    escape v;
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
            var int p2 = await P2;
            if p2 == 1 then
                escape 0;
            end;
        with
            loop do
                await 200ms;
            end;
        end;
    end;
with
    async do
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 1;
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
    _ana = {
        --acc = 3,
        acc = 12,           -- TODO: not checked
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
escape aa+bb;
]],
    run = { ['~>A;~>B']=4 },
}

Test { [[
input int F;
event int draw, occurring, sleeping;
var int x, vis;
par do
    await F;
    escape vis;
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
            var int s;
            par/or do
                s = await sleeping;     // 21
            with
                s = await sleeping;     // 23
            end;
            if s== 0 then
                vis = 1;                // 26
            else
                vis = 0;                // 28
            end;
        end;
    with
        loop do
            await 100ms;
            emit draw => 1;
        end;
    with
        loop do
            await 100ms;
            emit sleeping => 1;
            await 100ms;
            emit occurring => 1;
        end;
    end;
end;
]],
    _ana = {
        unreachs = 1,
        acc = 3,
        abrt = 1,
    },
    run = { ['~>1000ms;1~>F'] = 1 }
}

Test { [[
input int F;
event int draw, occurring, sleeping;
var int x, vis;
par do
    await F;
    escape vis;
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
            var int s;
            par/or do
                s = await sleeping;     // 21
            with
                s = await sleeping;     // 23
            end;
            if s== 0 then
                vis = 1;                // 26
            else
                vis = 0;                // 28
            end;
        end;
    with
        loop do
            await 100ms;
            emit draw => 1;
        end;
    with
        loop do
            await 100ms;
            emit sleeping => 1;
            await 100ms;
            emit occurring => 1;
        end;
    end;
end;
]],
    safety = 2,
    _ana = {
        unreachs = 1,
        acc = 6,
        abrt = 1,
    },
    run = { ['~>1000ms;1~>F'] = 1 }
}

Test { [[
input void OS_START;
event int a, b;
var int v=0;
par/or do
    loop do
        await a;
        emit b => 1;
        v = 4;
    end;
with
    loop do
        await b;
        v = 3;
    end;
with
    await OS_START;
    emit a => 1;
    escape v;
end;
// unreachable
escape 0;
]],
    _ana = {
        unreachs = 1,
    },
    run = 4,
}

Test { [[
input void OS_START;
await OS_START;

native do
##define pinMode(a,b)
##define digitalWrite(a,b)
end
_pinMode(13, 1);
_digitalWrite(13, 1);
do escape 1; end

par do
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
end
]],
    wrn = true,
    run = 1,
}

Test { [[
input void OS_STOP;
var int ret = 0;

par/or do

input void OS_START;

await OS_START;

finalize with
    nothing;
end

par do
    loop do
        await 10min;
    end
with
    await 1s;
    loop do
        par/or do
            loop do
                await 10min;
            end
        with
            await 1s;
            ret = ret + 1;
        end
    end
end

with
    await OS_STOP;
end

escape ret;
]],
    run = { ['~>OS_START; ~>10s; ~>OS_STOP']=9 },
}

Test { [[
var int ret = 0;
input void STOP;
par/or do
    loop do
        await 1s;
        ret = ret + 1;
    end

    loop do
        await 1s;
        par/or do with end
    end
with
    await STOP;
end
escape ret;
]],
    wrn = true,
    run = {['~>5s; ~>STOP']=5},
}

    -- SYNC TRIGGER

Test { [[
input void OS_START;
event int a;
var int v1, v2;
par/and do
    par/or do
        await OS_START;
        emit a => 10;
        v1=10;
    with
        await FOREVER;
    end;
with
    par/or do
        v2=await a;
        v2=v2+1;
    with
        await FOREVER;
    end;
end;
escape v1 + v2;
]],
    run = 21,
}

-- TODO: STACK
Test { [[
input void OS_START,A;
event int a;
var int aa=0;
par/or do
    loop do
        aa = await a;
        aa = aa + 1;
    end;
with
    await OS_START;
    emit a => 1;
    emit a => aa;
    emit a => aa;
    emit a => aa;
    emit a => aa;
    emit a => aa;
end;
escape aa;
]],
    --run = 7,
    run = 2,
}

Test { [[
input void OS_START,A;
event int a;
var int aa;
par/or do
    loop do
        aa=await a;
        aa = aa + 1;
    end;
with
    await OS_START;
    emit a => 1;
    await A;
    emit a => aa;
    await A;
    emit a => aa;
    await A;
    emit a => aa;
    await A;
    emit a => aa;
    await A;
    emit a => aa;
end;
escape aa;
]],
    run = { ['~>A;~>A;~>A;~>A;~>A'] = 7, },
}

Test { [[
input void OS_START, A;
event int a, b;
var int bb;
par/or do
    loop do
        bb=await b;
        bb = bb + 1;
    end;
with
    await a;
    emit b => 1;
    await A;
    emit b => bb;
    await A;
    emit b => bb;
    await A;
    emit b => bb;
    await A;
    emit b => bb;
    await A;
    emit b => bb;
    await A;
    emit b => bb;
with
    await OS_START;
    emit a => 1;
    bb = 0;
end;
escape bb;
]],
    _ana = {
        --nd_esc = 1,
        unreachs = 1,
    },
    run = 0,
}

Test { [[
input void OS_START;
event int a;
var int aa;
par/or do
    await OS_START;
    emit a => 0;
with
    aa = await a;
    aa= aa+1;
    emit a => aa;
    await FOREVER;
end;
escape aa;
]],
    run = 1,
}

Test { [[
input void OS_START;
event int a,b;
var int aa;
par/or do
    await OS_START;
    emit a => 0;
with
    aa=await a;
    aa=aa+1;
    emit b => aa;
    aa = aa + 1;
    await FOREVER;
with
    var int bb = await b;
    bb = bb + 1;
    await FOREVER;
end;
escape aa;
]],
    run = 2,
}

Test { [[
input void OS_START;
input int A, F;
event int c;
var int cc = 0;
par do
    loop do
        await A;
        emit c => cc;
    end;
with
    loop do
        cc = await c;
        cc = cc + 1;
    end;
with
    await F;
    escape cc;
end;
]],
    run = { ['1~>A;1~>A;1~>A;1~>F'] = 3 },
}

Test { [[
input void OS_START;
input int A, F;
event int c;
var int cc = 0;
par do
    loop do
        await A;
        emit c => cc;
    end;
with
    loop do
        cc = await c;
        cc = cc + 1;
    end;
with
    await F;
    escape cc;
end;
]],
    run = { ['1~>A;1~>A;1~>A;1~>F'] = 3 },
    safety = 2,
    _ana = {
        acc = 4,
    },
}

Test { [[
input void OS_START;
event int a;
par do
    loop do
        await OS_START;
        emit a => 0;
        emit a => 1;
        await 10s;
    end;
with
    var int v1,v2;
    par/and do
        v1 = await a;
    with
        v2 = await a;
    end;
    escape v1+v2;
end;
]],
    _ana = {
        --nd_esc = 1,
        unreachs = 3,
        --trig_wo = 1,  -- unreachs
    },
    run = 0,
}

Test { [[
input void OS_START, A;
event int a;
par do
    loop do
        await OS_START;
        emit a => 0;
        await A;
    emit a => 1;
        await 10s;
    end;
with
    var int v1,v2;
    v1 = await a;
    v2 = await a;
    escape v1 + v2;
end;
]],
    _ana = {
        --nd_esc = 1,
        unreachs = 2,
    },
    run = { ['~>A']=1 },
}

Test { [[
input int A;
event int c;
var int a;
par/or do
    loop do
        a = await c;
    end;
with
    await A;
    emit c => 1;
    a = 1;
end;
escape a;
]],
    run = { ['10~>A'] = 1 },
}

Test { [[
event int b, c;
var int a;
par/or do
    loop do
        var int cc = await c;        // 4
        emit b => cc+1;     // 5
        a = cc+1;
    end;
with
    loop do
        var int bb = await b;        // 10
        a = bb + 1;
    end;
with
    emit c => 1;           // 14
    a = 1;
end;
escape a;
]],
    _ana = {
        acc = 1,
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
            emit a => v;
        end;
    with
        loop do
            var int aa = await a;
            emit b => aa;
            var int aa = await a;
            emit b => aa;
        end;
    with
        loop do
            var int bb = await b;
            emit a => bb;
            i = i + 1;
        end;
    end;
with
    await F;
    escape i;
end;
]],
    wrn = true,
    run = { ['1~>A;1~>A;1~>A;1~>A;1~>A;1~>F'] = 5 },
}

Test { [[
input void F;
event int x;
event int y;
var int xx = 0;
var int yy = 0;
var int a = 0;
var int b = 0;
var int c = 0;
par do
    loop do
        await 100ms;
        par/or do
            xx = xx + 1;
            emit x => xx;
        with
            yy = yy + 1;
            emit y => yy;
        end;
    end;
with
    loop do
        par/or do
            var int xx = await x;
            a = a + xx;
        with
            var int yy = await y;
            b = b + yy;
        end;
        c = a + b;
    end;
with
    await F;
    escape c;
end;
]],
    _ana = {
        abrt = 2,
    },
    run = { ['~>1100ms ; ~>F'] = 66 }   -- TODO: stack change
}

Test { [[
input void F;
event int x;
event int y;
var int xx = 0;
var int yy = 0;
var int a = 0;
var int b = 0;
var int c = 0;
par do
    loop do
        await 100ms;
        par/or do
            xx = xx + 1;
            emit x => xx;
        with
            yy = yy + 1;
            emit y => yy;
        end;
    end;
with
    loop do
        par/or do
            var int xx = await x;
            a = a + xx;
        with
            var int yy = await y;
            b = b + yy;
        end;
        c = a + b;
    end;
with
    await F;
    escape c;
end;
]],
    safety = 2,
    _ana = {
        acc = 1,
        abrt = 2,
    },
    run = { ['~>1100ms ; ~>F'] = 66 }   -- TODO: stack change
}

Test { [[
input void OS_START;
event int a, b, c;
var int x = 0;
var int y = 0;
par/or do
    await OS_START;
    emit a => 0;
with
    await b;
    emit c => 0;
with
    par/or do
        await a;
        emit b => 0;
    with
        par/or do
            await b;    // 17
            x = 3;
        with
            await c;    // 20
            y = 6;
        end;
    end;
end;
escape x + y;
]],
    _ana = {
        unreachs = 4,
        abrt = 1,
    },
    run = 6,    -- TODO: stack change (6 or 3)
}

Test { [[
input void F;
event int x;
event int y;
var int xx = 0;
var int yy = 0;
var int a = 0;
var int b = 0;
var int c = 0;
par do
    loop do
        await 100ms;
        par/or do
            xx = xx + 1;
            emit x => xx;
        with
            yy=yy+1;
            emit y => yy;
        end;
        c = c + 1;
    end;
with
    loop do
        par/or do
            var int xx = await x;
            a = xx + a;
        with
            var int yy = await y;
            b = yy + b;
        end;
        c = a + b + c;
    end;
with
    await F;
    escape c;
end;
]],
    _ana = {
        abrt = 2,
    },
    run = {
        ['~>99ms;  ~>F'] = 0,
        ['~>199ms; ~>F'] = 2,
        ['~>299ms; ~>F'] = 6,
        ['~>300ms; ~>F'] = 13,
        ['~>330ms; ~>F'] = 13,
        ['~>430ms; ~>F'] = 24,
        ['~>501ms; ~>F'] = 40,
    }
}

Test { [[
input void OS_START;
event int a;
var int b;
par/and do
    await OS_START;
    emit a => 1;
    b = 1;
with
    var int aa = await a;
    b = aa + 1;
end;
escape b;
]],
    run = 1,
}
Test { [[
input void OS_START;
event int a;
var int b;
par/or do
    await OS_START;
    emit a => 1;
    b = 1;
with
    var int aa =await a;
    b = aa + 1;
end;
escape b;
]],
    _ana = {
        unreachs = 1,
    --nd_esc = 1,
    },
    run = 2,
}

Test { [[
input void OS_START;
event int a;
par do
    var int aa = await a;
    emit a => 1;
    escape aa;
with
    await OS_START;
    emit a => 2;
    escape 0;
end;
]],
    _ana = {
        --nd_esc = 1,
    unreachs = 1,
    --trig_wo = 1,
    },
    run = 2,
}

Test { [[
input void OS_START;
event int a, b;
var int aa;
par/or do
    loop do
        await a;
        emit b => 1;
    end;
with
    await OS_START;
    emit a => 1;
with
    await b;
    emit a => 2;
    aa = 2;
end;
escape aa;
]],
    _ana = {
        --nd_esc = 2,
        unreachs = 3,
        --trig_wo = 1,
    },
    run = 2,
}

-- TODO: STACK
Test { [[
input void OS_START;
event int a;
var int x = 0;
par do
    await OS_START;
    emit a => 1;
    emit a => 2;
    escape x;
with
    loop do
        await a;
        x = x + 1;
    end
end
]],
    --run = 2,
    run = 1,
}
Test { [[
input void OS_START;
event int a;
var int x = 0;
par do
    await OS_START;
    emit a => 1;
    emit a => 2;
    escape x;
with
    loop do
        await a;
        x = x + 1;
    end
end
]],
    --run = 2,
    run = 1,
    safety = 2,
    _ana = {
        acc = 1,
    },
}
Test { [[
input void OS_START, A;
event int a;
var int x = 0;
par do
    await OS_START;
    emit a => 1;
    await A;
    emit a => 2;
    escape x;
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
input void OS_START, A;
event int a;
var int x = 0;
par do
    await OS_START;
    emit a => 1;
    await A;
    emit a => 2;
    escape x;
with
    await a;
    x = x + 1;
    await a;
    x = x + 1;
end
]],
    run = {['~>A']=2,},
    safety = 2,
    _ana = {
        acc = 2,
    },
}
Test { [[
event int a;
var int x = 0;
par do
    emit a  =>  1;
    escape x;
with
    loop do
        await a;
        x = x + 1;
    end
end
]],
    _ana = {
        acc = 1,
        --abrt = 1,
        unreachs = 0,
    },
}
Test { [[
input void OS_START;
event void a;
var int x = 0;
par/or do
    await OS_START;
    emit a =>  1;
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
escape x;
]],
    _ana = {
        abrt = 1,
        acc = 1,
        unreachs = 2,
    },
    run = 1,
    env = 'line 6 : arity mismatch',
    --env = 'line 6 : non-matching types on `emit´ (void vs int)',
}

-- TODO: STACK
Test { [[
input void OS_START;
event int a;
var int x = 0;
par/or do
    await OS_START;
    emit a =>  1;
    // unreachable
with
    await a;
    x = x + 1;
    await a;        // 11
    x = x + 1;
with
    await a;
    emit a => 1;         // 15
    // unreachable
end
escape x;
]],
    _ana = {
        abrt = 1,
        acc = 1,
        unreachs = 2,
    },
    --run = 2,
    run = 1,
}

Test { [[
event int a, x, y, vis;
par/or do
    par/and do
        emit x => 1;
        emit y => 1;
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
    emit a => 1;
    emit x => 0;
    emit y => 0;
    emit vis => 1;
    await FOREVER;
end;
]],
    _ana = {
        --acc = 1,
        acc = 6,     -- TODO: not checked
        --trig_wo = 2,
        unreachs = 2,
        isForever = true,
    },
}

-- TODO: STACK
Test { [[
input void OS_START;
event void x, y;
var int ret = 0;
par/or do
    par/and do
        await OS_START;
        emit x;         // 7
        emit y;         // 8
    with
        loop do
            par/or do
                await x;    // 12
                ret = 1;    // 13
            with
                await y;    // 15
                ret = 10;   // 16
            end;
        end;
    end;
with
    await OS_START;
    emit x;             // 22
    emit y;             // 23
end;
escape ret;
]],
    _ana = {
        abrt = 1,
        acc = 5,
        --acc = 4,
        --trig_wo = 2,
        unreachs = 1,
    },
    --run = 10,
    run = 1,
}

Test { [[
input void OS_START;
event int a, x, y;
var int ret = 0;
par do
    par/and do
        await OS_START;
        emit x => 1;           // 7
        emit y => 1;           // 8
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
    await OS_START;
    ret = ret + 1;
    emit a => 1;
    ret = ret * 2;
    emit x => 0;               // 7
    ret = ret + 1;
    emit y => 0;               // 25
    ret = ret * 2;
    escape ret;
end;
]],
    _ana = {
        abrt = 1,
        acc = 4,
        --acc = 1,
        --trig_wo = 2,
        unreachs = 1,
    },
    run = 18,
}

Test { [[
event int a, x, y, vis;
par/or do
    par/and do
        emit x => 1;
        emit y => 1;
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
    emit a => 1;
    emit x => 0;
    emit y => 0;
    emit vis => 1;
    await FOREVER;
end;
]],
    _ana = {
        acc = 6,
        --trig_wo = 2,
        unreachs = 2,
        isForever = true,
    },
}

-- TODO: STACK
Test { [[
input void OS_START;
input int F;
event int x, w, y, z, a, vis;
var int xx=0, ww=0, yy=0, zz=0, aa=0, vvis=0;
par do
    loop do
        par/or do
            xx = await x;
            xx = xx + 1;
        with
            yy = await y;    // 10
            yy = yy + 1;
        with
            zz = await z;    // 13
            zz = zz + 1;
        with
            ww = await w;
            ww = ww + 1;
        end;
        aa = aa + 1;
    end;
with
    await OS_START;
    aa=1;
    emit a => aa;
    yy=1;
    emit y => yy;
    zz=1;
    emit z => zz;
    vvis=1;
    emit vis => vvis;
with
    await F;
    escape aa+xx+yy+zz+ww;
end;
]],
    _ana = {
        abrt = 1,        -- false positive
        --trig_wo = 2,
        unreachs = 2,
    },
    --run = { ['1~>F']=7 },
    run = { ['1~>F']=5 },
}

    -- SCOPE / BLOCK

Test { [[do end;]],
    _ana = {
        reachs = 1,
        isForever = true,
    },
}
Test { [[do var int a; end;]],
    _ana = {
        reachs = 1,
        isForever = true,
    },
}
Test { [[
do
    var int a;
    escape 1;
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
    escape a;
end;
]],
    wrn = true,
    run = 1,
}

Test { [[
input void A, B;
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
    escape tot + a;
end;
]],
    wrn = true,
    run = { ['~>A;~>B']=8 },
}

Test { [[
do
    var int a = 1;
    var int b = 0;
    do
        escape a + b;
    end;
end;
]],
    run = 1,
}

Test { [[
input void A, B;
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
    escape a;
end;
]],
    run = { ['~>A;~>B']=1 },
}

Test { [[
input void A, B;
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
escape a;
]],
    wrn = true,
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
escape 0;
]],
    _ana = {
        acc = 1,
        abrt = 1,
    },
}

Test { [[
input void A, B;
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
escape i;
]],
    _ana = {
        unreachs = 1,
    },
    run = {
        ['~>B'] = 0,
        ['~>A ; ~>B'] = 0,
        ['~>A ; ~>A ; ~>B'] = 0,
    }
}

Test { [[
event a;
escape 0;
]],
    parser = 'line 1 : after `event´ : expected type',
}

Test { [[
var int ret;
event int a;
par/or do
    do
        var int a = 0;
        par/or do
            par/or do
                emit a => 40;
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
escape a;
]],
    wrn = true,
    env = 'line 8 : event "a" is not declared',
}

Test { [[
var int ret = 0;
event void a,b;
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
escape ret;
]],
    _ana = {
        abrt = 1,
        acc = 1,
    },
    run = 2,
}

Test { [[
var int ret = 0;
event void a;
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
escape ret;
]],
    _ana = {
        acc = 2,
        abrt = 3,
    },
    run = 2,
}

Test { [[
input int A;
var int ret;
var int aa;
par/or do
    do
        event int aa;
        par/or do
            par/or do
                emit aa => 1;  // 9
            with
            end;
        with
            ret = await aa;        // 13
        end;
    end;
    do
        event int aa;
        ret = await aa;
    end;
with
    aa = await A;
end;
escape aa;
]],
    _ana = {
    abrt = 1,
        --nd_esc = 2,
        unreachs = 3,
        acc = 1,
    },
    run = { ['10~>A']=10 },
}

Test { [[
input void OS_START;
var int ret;
par/or do
    event int a;
    par/or do
        await OS_START;
        emit a => 5;
        // unreachable
    with
        ret =await a;
    end;
with
    event int a;
    await a;
    // unreachable
    ret = 0;
end;
escape ret;
]],
    _ana = {
        --nd_esc = 1,
    unreachs = 2,
    },
    run = 5,
}

-- REFERENCES / REFS / &

Test { [[
var int a = 1;
var int& b = a;
a = 2;
escape b;
]],
    run = 2,
}
Test { [[
native do
    int V = 10;
end
var int& v = _V;
escape v;
]],
    gcc = 'error: assignment makes pointer from integer without a cast',
    --run = 10;
}

Test { [[
var int a = 1;
var int& b = &a;
a = 2;
escape b;
]],
    env = 'line 2 : types mismatch (`int&´ <= `int*´)',
    --run = 2,
}
Test { [[
native do
    int V = 10;
end
var int& v;
v = &_V;
escape v;
]],
    --env = 'line 5 : invalid attribution (int& vs _*)',
    run = 10;
}

Test { [[
var int a = 1;
var int& b;
escape b;
]],
    ref = 'line 3 : reference must be bounded before use',
    --run = 2,
}
Test { [[
var int a = 1;
var int& b;
b = a;
a = 2;
escape b;
]],
    run = 2,
}
Test { [[
native do
    int V = 10;
end
var int& v;
v = &_V;
escape v;
]],
    run = 10;
}

Test { [[
var int& a;
var int* b = null;
a = b;
await 1s;
var int* c = a;
escape 1;
]],
    env = 'line 3 : types mismatch (`int&´ <= `int*´)',
    --run = { ['~>1s']=1 },
}
Test { [[
native do
    int V = 10;
end
var int vv = 10;
var int& v;
v = &vv;
await 1s;
do
    var int vvv = 1;
end
escape *v;
]],
    env = 'line 6 : types mismatch (`int&´ <= `int*´)'
}
Test { [[
native do
    int V = 10;
end
var int vv = 10;
var int& v;
v = vv;
await 1s;
do
    var int vvv = 1;
end
escape *v;
]],
    env = 'line 11 : invalid operand to unary "*"',
    --run = { ['~>1s']=10 };
}
Test { [[
native do
    int V = 10;
end
var int vv = 10;
var int& v;
v = vv;
await 1s;
do
    var int vvv = 1;
end
escape v;
]],
    run = { ['~>1s']=10 };
}

Test { [[
var int[] v;
escape 1;
]],
    --run = 1,
    sval = 'line 1 : invalid array dimension',
}

Test { [[
var int a=1, b=2;
var int& v;
if true then
else
    v = b;
end
v = 5;
escape a + b + v;
]],
    ref = 'line 5 : reference must be bounded in the other if-else branch',
}
Test { [[
var int a=1, b=2;
var int& v;
if true then
    v = a;
else
end
v = 5;
escape a + b + v;
]],
    ref = 'line 4 : reference must be bounded in the other if-else branch',
}
Test { [[
var int a=1, b=2;
var int& v;
if true then
    v = a;
else
    v = b;
end
var int& x;
if false then
    x = a;
else
    x = b;
end
v = 5;
x = 1;
escape a + b + x + v;
]],
    run = 12,
}

Test { [[
native do
    int V1 = 10;
    int V2 = 5;
end
var int& v;
if true then
    v = &_V1;
else
    v = &_V2;
end
v = 1;
escape _V1+_V2;
]],
    run = 6,
}

Test { [[
var int a=1, b=2, c=3;
var int& v;
if true then
    v = a;
else
    v = b;
end
var int& x;
if false then
    x = a;
else/if true then
    x = b;
else
    x = c;
end
v = 5;
x = 1;
escape a + b + x + v;
]],
    run = 12,
}

Test { [[
var int a=1, b=2, c=3;
var int& v;
if true then
    v = a;
else
    v = b;
end
var int& x;
if false then
    x = a;
else
    if true then
        x = b;
    else
        x = c;
    end
end
v = 5;
x = 1;
escape a + b + x + v;
]],
    run = 12,
}

Test { [[
var int v = 10;
loop do
    var int& i = v;
    i = i + 1;
    break;
end
escape v;
]],
    wrn = true,
    run = 11,
}

Test { [[
var int v = 10;
var int& i;
loop do
    i = v;
    i = i + 1;
    break;
end
escape v;
]],
    wrn = true,
    ref = 'reference declaration and first binding cannot be separated by loops',
}

Test { [[
var int v = 10;
loop do
    var int&? i = v;
    i = i + 1;
    break;
end
escape v;
]],
    wrn = true,
    run = 11,
}

Test { [[
var int v = 10;
var int&? i;
loop do
    i = v;
    i = i + 1;
    break;
end
escape v;
]],
    wrn = true,
    --run = 11,
    ref = 'reference declaration and first binding cannot be separated by loops',
}

Test { [[
var _SDL_Surface&? sfc;
every 1s do
    finalize
        sfc = _TTF_RenderText_Blended();
    with
        _SDL_FreeSurface(&sfc);
    end
end
escape 1;
]],
    ref = 'line 4 : reference declaration and first binding cannot be separated by loops',
}

Test { [[
native do
    int V = 10;
    int* fff (int v) {
        V += v;
        return &V;
    }
end
var int   v = 1;
var int*  p = &v;
var int&? r;
finalize
    r = _fff(*p);
with
    nothing;
end
escape r;
]],
    run = 11,
}

Test { [[
var int& v;
do
    var int x;
    v = x;
end
escape 1;
]],
    ref = 'line 4 : attribution to reference with greater scope',
}

Test { [[
data V with
    var int v;
end

var V& v1 = V(1);
var V& v2, v3;
do
    v2 = V(2);
end
do
    v3 = V(3);
end
escape v1.v+v2.v+v3.v;
]],
    ref = 'line 5 : invalid attribution (not a reference)',
    --run = 6,
}

Test { [[
data V with
    var int v;
end

var V v1_ = V(1);
var V& v1 = v1_;
var V& v2, v3;
do
    var V v2_ = V(2);
    v2 = v2_;
end
do
    var V v3_ = V(3);
    v3 = v3_;
end
escape v1.v+v2.v+v3.v;
]],
    ref = 'line 10 : attribution to reference with greater scope',
    --run = 6,
}

Test { [[
native @nohold _g();

var _SDL_Renderer&? ren;
    finalize
        ren = _f();
    with
    end

await 1s;
_g(&ren);

escape 1;
]],
    gcc = 'error: unknown type name ‘SDL_Renderer’',
}

-- FINALLY / FINALIZE

Test { [[
    native @pure _Radio_getPayload();
    var _message_t msg;
    loop do
        await 1s;
        var _Cnt* snd = _Radio_getPayload(&msg, sizeof(_Cnt));
    end
]],
    --fin = 'line 5 : pointer access across `await´',
    _ana = {
        isForever = true,
    },
}
Test { [[
    native @plain _message_t;
    native @pure _Radio_getPayload();
    var _message_t msg;
    loop do
        await 1s;
        var _Cnt* snd = _Radio_getPayload(&msg, sizeof(_Cnt));
    end
]],
    _ana = {
        isForever = true,
    },
}
Test { [[
do
finalize with nothing; end
end
escape 1;
]],
    run = 1,
}

Test { [[
finalize with
    do escape 1; end;
end
escape 0;
]],
    props = 'line 2 : not permitted inside `finalize´',
}

Test { [[
var int* ptr = _malloc();
]],
    fin = 'line 1 : must assign to a option reference (declared with `&?´)',
}

Test { [[
native _f();
do
    var int* a;
    finalize
        a = _f();
    with
        do await FOREVER; end;
    end
end
]],
    fin = 'line 5 : must assign to a option reference (declared with `&?´)',
}

Test { [[
native _f();
do
    var int&? a;
    finalize
        a = _f();
    with
        do await FOREVER; end;
    end
end
]],
    props = "line 7 : not permitted inside `finalize´",
}

Test { [[
native _f();
do
    var int&? a;
    finalize
        a = _f();
    with
        async do
        end;
    end
end
]],
    props = "line 7 : not permitted inside `finalize´",
}

Test { [[
native _f();
do
    var int&? a;
    finalize
        a = _f();
    with
        do escape 0; end;
    end
end
]],
    props = "line 7 : not permitted inside `finalize´",
}

Test { [[
loop do
    var int* a;
    do
        var int* b = null;
            a = b;
    end
end
]],
    tight = 'line 1 : tight loop', -- TODO: par/and
    --props = "line 8 : not permitted inside `finalize´",
    --fin = 'line 6 : attribution does not require `finalize´',
    --fin = 'line 6 : attribution to pointer with greater scope',
}

Test { [[
var int v = 10;
var int* ptr = &v;
await 1s;
escape *ptr;
]],
    fin = 'line 4 : unsafe access to pointer "ptr" across `await´',
}

Test { [[
var int* a;
var int* b = null;
a = b;
await 1s;
var int* c = a;
escape 1;
]],
    fin = 'line 5 : unsafe access to pointer "a" across `await´',
}

Test { [[
var int* a;
var int* b = null;
a = b;
await 1s;
var int* c = a;
escape 1;
]],
    fin = 'line 5 : unsafe access to pointer "a" across `await´',
}

Test { [[
input void E;
var int&? n;
finalize
    this.n = _f();
with
end
await E;
escape this.n;
]],
    gcc = 'error: implicit declaration of function ‘f’',
}

Test { [[
loop do
    var int* a;
    do
        var int* b = null;
        finalize
            a = b;
        with
            do break; end;
        end
    end
end
]],
    --loop = 'line 1 : tight loop', -- TODO: par/and
    --props = "line 8 : not permitted inside `finalize´",
    fin = 'line 6 : attribution does not require `finalize´',
    --fin = 'line 6 : attribution to pointer with greater scope',
}

Test { [[
loop do
    var int* a;
    do
        var int* b = null;
        finalize
            a := b;
        with
            do break; end;
        end
    end
end
]],
    --loop = 'line 1 : tight loop', -- TODO: par/and
    --props = "line 8 : not permitted inside `finalize´",
    fin = 'line 6 : attribution does not require `finalize´',
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
escape ret;
]],
    env = 'line 6 : variable/event "a" is not declared',
}

Test { [[
native _f();
native do
    int* f (void) {
        return NULL;
    }
end
var int r = 0;
do
    var int&? a;
    finalize
        a = _f();
    with
        var int b = do escape 2; end;
    end
    r = 1;
end
escape r;
]],
    --props = "line 8 : not permitted inside `finalize´",
    run = 1,
}

Test { [[
native do
    void f (int* a) {
        *a = 10;
    }
    typedef void (*t)(int*);
end
native _t = 4;
var _t v = _f;
await 1s;
var int a;
v(&a) finalize with nothing; end;
escape(a);
]],
    --env = 'line 8 : native variable/function "_f" is not declared',
    --fin = 'line 8 : attribution to pointer with greater scope',
    fin = 'line 11 : unsafe access to pointer "v" across `await´',
    --run = { ['~>1s']=10 },
}

Test { [[
native do
    void f (int* a) {
        *a = 10;
    }
    typedef void (*t)(int*);
end
native _t = 4;
var _t v = _f;
await 1s;
var int a;
v(&a) finalize with nothing; end;
escape(a);
]],
    --env = 'line 8 : native variable/function "_f" is not declared',
    --fin = 'line 8 : attribution to pointer with greater scope',
    fin = 'line 11 : unsafe access to pointer "v" across `await´',
}
Test { [[
native do
    void f (int* a) {
        *a = 10;
    }
    typedef void (*t)(int*);
end
native _t = 4;
var _t v = _f;
await 1s;
var int a;
_f(&a) finalize with nothing; end;
escape(a);
]],
    --env = 'line 8 : native variable/function "_f" is not declared',
    --fin = 'line 8 : attribution to pointer with greater scope',
    --fin = 'line 11 : pointer access across `await´',
    run = { ['~>1s']=10 },
}

Test { [[
native do
    void f (int* a) {
        *a = 10;
    }
    typedef void (*t)(int*);
end
native _t = 4;
var _t v = _f;
var int a;
v(&a) finalize with nothing; end;
escape(a);
]],
    --env = 'line 8 : native variable/function "_f" is not declared',
    run = 10,
}

Test { [[
native _f();
_f() finalize with nothing;
    end;
escape 1;
]],
    fin = 'line 2 : invalid `finalize´',
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
escape v;
]],
    run = 8,
}

Test { [[
native _f();
native do void f (void* p) {} end

var void* p=null;
_f(p) finalize with nothing;
    end;
escape 1;
]],
    run = 1,
}

Test { [[
native _f();
native do void f () {} end

var void* p = null;
_f(p!=null) finalize with nothing;
    end;
escape 1;
]],
    fin = 'line 5 : invalid `finalize´',
    --run = 1,
}

Test { [[
native _f();
do
    var int* p1 = null;
    do
        var int* p2 = null;
        _f(p1, p2);
    end
end
escape 1;
]],
    fin = 'line 6 : invalid call (multiple scopes)',
}
Test { [[
var char* buf;
_enqueue(buf);
escape 1;
]],
    fin = 'line 2 : call requires `finalize´',
}

Test { [[
var char[255] buf;
_enqueue(buf);
escape 1;
]],
    fin = 'line 2 : call requires `finalize´',
}

Test { [[
native _f();
do
    var int* p1 = null;
    do
        var int* p2 = null;
        _f(p1, p2);
    end
end
escape 1;
]],
    wrn = true,
    fin = 'line 6 : call requires `finalize´',
    -- multiple scopes
}

Test { [[
native _f();
native _v;
native do
    int v = 1;
    int f (int v) {
        return v + 1;
    }
end
escape _f(_v);
]],
    --fin = 'line 3 : call requires `finalize´',
    run = 2,
    --fin = 'line 9 : attribution requires `finalize´',
}
Test { [[
native @pure _f();
native _v;
native do
    int v = 1;
    int f (int v) {
        return v + 1;
    }
end
escape _f(_v);
]],
    --fin = 'line 3 : call requires `finalize´',
    run = 2,
}


Test { [[
native @pure _f();
native do
    int* f (int a) {
        return NULL;
    }
end
var int* v = _f(0);
escape v == null;
]],
    run = 1,
}

Test { [[
native @pure _f();
native do
    int V = 10;
    int f (int v) {
        return v;
    }
end
native @const _V;
escape _f(_V);
]],
    run = 10;
}

Test { [[
native _f();
native do
    int f (int* v) {
        return 1;
    }
end
var int v;
escape _f(&v) == 1;
]],
    fin = 'line 8 : call requires `finalize´',
}

Test { [[
native @nohold _f();
native do
    int f (int* v) {
        return 1;
    }
end
var int v;
escape _f(&v) == 1;
]],
    run = 1,
}

Test { [[
native _V;
native @nohold _f();
native do
    int V=1;
    int f (int* v) {
        return 1;
    }
end
var int v;
escape _f(&v) == _V;
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
escape ret;
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
escape ret;
]],
    --run = 1,
    fin = 'line 7 : attribution does not require `finalize´',
}
Test { [[
var int ret = 0;
var int* pa;
do
    var int v;
    if 1 then
            pa = &v;
    else
            pa = &v;
    end
end
escape ret;
]],
    --run = 1,
    fin = 'line 6 : attribution to pointer with greater scope',
}

Test { [[
var int r = 0;
do
    var int a;
    await 1s;
    finalize with
        do
            var int b = 1;
            r = b;
        end;
    end
end
escape r;
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
escape ret;
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
escape 1;
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
escape ret;
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
escape ret;
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
escape ret;
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
escape a;
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
escape a;
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
escape ret;
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
        escape 0;
    with
        break;
    end
end
escape ret;
]],
    wrn = true,
    run = 1,
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
        escape 0;
    with
        break;
    end
end
escape ret;
]],
    wrn = true,
    run = 1,
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
        escape 0;
    with
        break;
    end
end
escape ret;
]],
    ana = 'line 4 : at least one trail should terminate',
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
        escape 0;
    with
        break;
    end
end
escape ret;
]],
    wrn = true,
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
escape ret;
]],
    run = {
        ['~>A']=1,
        ['~>B']=1
    },
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
escape ret;
]],
    safety = 2,
    _ana = {
        acc = 1,
    },
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
escape ret;
]],
    todo = 'finalizers do not run in parallel',
    _ana = {
        acc = 3,
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
escape ret;
]],
    props = 'line 9 : not permitted inside `finalize´',
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
escape ret;
]],
    _ana = {
        acc = 3,
    },
    run = {
        ['~>A'] = 9,
        ['~>B'] = 12,
    },
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
escape ret;
]],
    safety = 2,
    _ana = {
        acc = 9,
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
escape ret;
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
escape ret;
]],
    _ana = {
        abrt = 1,
    },
    run = { ['~>A']=22 },
}

Test { [[
input void A, B;
var int ret = 1;
par/or do
    do
        finalize with
            ret = ret + 5;
        end
        ret = ret + 1;
        do
            finalize with
                ret = ret * 3;
            end
            await A;
            ret = ret * 100;
        end
    end
with
    await B;
    ret = ret * 2;
end
escape ret;
]],
    run = { ['~>B']=17, ['~>A']=605 },
}

Test { [[
input void OS_START;
await OS_START;
par/or do
    await OS_START;
with
    await OS_START;
end
escape 1;
]],
    run = 0,
}

Test { [[
input void OS_START;
await OS_START;
do
    finalize with
        var int ret = 1;
    end
    await OS_START;
end
escape 1;
]],
    run = 0,
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
escape ret;
]],
    run = {
        ['~>A']         =  7,
        ['~>B;~>B;~>A'] = 17,
        ['~>B;~>A']     =  9,
    },
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
escape ret;
]],
    wrn = true,
    run = 1,
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
escape ret;
]],
     ana = 'line 6 : statement is not reachable',
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
escape ret;
]],
    _ana = {
        unreachs = 2,
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
escape ret;
]],
    wrn = true,
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
escape ret;
]],
    _ana = {
        unreachs = 2,
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
            do escape ret * 2; end
            finalize with
                ret = ret + 4;  // executed after `escape´ assigns to outer `ret´
    end
        end
    end
end;
escape ret;
]],
    _ana = {
        unreachs = 2,
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
                ret = ret + 4;  // executed after `escape´ assigns to outer `ret´
    end
            escape ret * 2;
        end
    end
end;
escape ret;
]],
    _ana = {
        unreachs = 2,
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
escape ret;
]],
    _ana = {
        abrt = 1,
    },
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
escape ret;
]],
    _ana = {
        unreachs = 4,  -- 1s,1s,or,fin
        abrt = 2,
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
escape ret;
]],
    _ana = {
        unreachs = 2,  -- 500ms,1s
        abrt = 2,
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
escape v;
]],
    run = {
        ['~>F'] = 12,
        ['~>A'] = 10,
    }
}

Test { [[
native do
    void f (int* a) {
        *a = 10;
    }
    typedef void (*t)(int*);
end
native _t=4;
native @nohold _f();
var _t v = _f;
var int ret;
do
    var int a;
    v(&a)
        finalize with nothing; end;
    ret = a;
end
escape(ret);
]],
    run = 10,
}
Test { [[
native _t=4, _A;
native _f();
native do
    int* A = NULL;;
    void f (int* a) {
        A = a;
    }
    typedef void (*t)(int*);
end
var int ret = 0;
if _A then
    ret = ret + *(int*)_A;
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
        a = a + *(int*)_A;
    end
end
if _A then
    ret = ret + *(int*)_A;
end
escape(ret);
]],
    run = 20,
}
Test { [[
input void OS_START;
native _t=4, _A;
native _f();
native do
    int* A = NULL;;
    void f (int* a) {
        A = a;
    }
    typedef void (*t)(int*);
end
var int ret = 0;
if _A then
    ret = ret + *(int*)_A;
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
            a = a + *(int*)_A;
        end
        await FOREVER;
with
    await OS_START;
end
if _A then
    ret = ret + *(int*)_A;
end
escape(ret);
]],
    --fin = 'line 32 : pointer access across `await´',
    run = 20,
}
Test { [[
var int v = 1;
par/or do
    nothing;
with
    v = *(int*)null;
end
escape v;
]],
    run = 1,
}

Test { [[
finalize with
end
escape 1;
]],
    run = 1,
}

Test { [[
native _f(), _V;
native do
    int V;
    void f (int* x) {
        V = *x;
    }
end
var int ret = 10;
do
    var int x = 5;
    _f(&x) finalize with
        _V = _V + 1;
    end;
end
escape ret + _V;
]],
    run = 16,
}

Test { [[
event void* e;
var void* v = await e;
escape 1;
]],
    run = 0,
}

Test { [[
event void* e;
var void* v = await e;
await e;
escape 1;
]],
    --fin = 'line 3 : cannot `await´ again on this block',
    run = 0,
}

Test { [[
event int* e;
var int* v = await e;
await e;
escape *v;
]],
    fin = 'line 4 : unsafe access to pointer "v" across `await´',
    --fin = 'line 3 : cannot `await´ again on this block',
    --run = 0,
}

Test { [[
var int* p;
do
    event int* e;
    p = await e;
end
escape 1;
]],
    run = 0,
    --fin = 'line 4 : invalid block for awoken pointer "p"',
}

Test { [[
var int* p1;
do
    var int* p;
    event int* e;
    p = await e;
    p1 = p;
    await e;
    escape *p1;
end
escape 1;
]],
    --fin = 'line 6 : attribution requires `finalize´',
    --fin = 'line 8 : pointer access across `await´',
    fin = 'line 6 : attribution to pointer with greater scope',
}

Test { [[
var int* p1 = null;
do
    var int* p;
    event int* e;
    p = await e;
    _f(p);
    await e;
    escape *p1;
end
escape 1;
]],
    fin = 'line 6 : call requires `finalize´',
}

Test { [[
var int* p;
do
    event int* e;
    p = await e;
end
await 1s;
escape 1;
]],
    run = 0,
    --fin = 'line 4 : invalid block for pointer across `await´',
}

Test { [[
var int x = 10;
var int* p = &x;
par/or do
    await 1s;
with
    event int* e;
    p = await e;
end
escape x;
]],
    --fin = 'line 8 : pointer access across `await´',
    --fin = 'line 6 : invalid block for pointer across `await´',
    --fin = 'line 6 : cannot `await´ again on this block',
    run = { ['~>1s']=10 },
}

Test { [[
input int* A;
var int v;
par/or do
    do
        var int* p = await A;
        v = *p;
    end
    await A;
with
    async do
        var int v = 10;
        emit A => &v;
        emit A => null;
    end
end
escape v;
]],
    wrn = true,
    run = 10,
}

Test { [[
input int* A;
var int v;
par/or do
    do
        var int* p = await A;
        v = *p;
    end
    await A;
with
    async do
        var int v = 10;
        emit A => &v;
        emit A => null;
    end
end
escape v;
]],
    wrn = true,
    run = 10,
    safety = 2,
    _ana = {
        acc = 1,
    },
}

Test { [[
input int* A;
var int v;
par/or do
    do
        var int* p = await A;
        v = *p;
    end
    await A;
with
    async do
        var int v = 10;
        emit A => (void*) &v;
        emit A => null;
    end
end
escape v;
]],
    env = 'line 12 : wrong argument #1',
    --wrn = true,
    --run = 10,
}

Test { [[
var int* p;
var int ret;
input void OS_START;
do
    event int* e;
    par/and do
        finalize
            p = await e;
        with
            ret = *p;
            p = &ret;
        end
    with
        await OS_START;
        var int i = 1;
        emit e => &i;
    end
end
escape ret + *p;
]],
    adj = 'line 7 : invalid `finalize´',
    --fin = 'line 8 : attribution does not require `finalize´',
    --fin = 'line 8 : invalid block for awoken pointer "p"',
    --fin = 'line 14 : cannot `await´ again on this block',
}

Test { [[
var int ret;
var int* p = &ret;
input void OS_START;
do
    event int* e;
    par/and do
        p = await e;
    with
        await OS_START;
        var int i = 1;
        emit e => &i;
    end
end
escape ret + *p;
]],
    fin = 'line 14 : unsafe access to pointer "p" across `par/and´',
    --fin = 'line 8 : invalid block for awoken pointer "p"',
    --fin = 'line 14 : cannot `await´ again on this block',
}

Test { [[
var void* p;
var int i;
input void OS_START;
do
    var int r;
    do
        event (int,void*) ptr;
        par/or do
            finalize
                (i,p) = await ptr;
            with
                r = i;
            end
        with
            await OS_START;
            emit ptr => (1, null);
        end
    end
    _assert(r == 1);
    escape r;
end
]],
    adj = 'line 9 : invalid `finalize´',
    --run = 1,
    -- TODO: impossible to place the finally in the correct parameter?
}

Test { [[
var int* p;
var int ret;
input void OS_START;
do
    event int* e;
    par/and do
        p = await e;
        ret = *p;
    with
        await OS_START;
        var int i = 1;
        emit e => &i;
    end
end
escape ret;
]],
    --fin = 'line 7 : invalid block for awoken pointer "p"',
    --fin = 'line 7 : wrong operator',
    run = 1,
}

Test { [[
var int* p;
var int ret;
input void OS_START;
do
    event int* e;
    par/and do
        p = await e;
        ret = *p;
    with
        await OS_START;
        var int i = 1;
        emit e => &i;
    end
end
escape ret;
]],
    --fin = 'line 7 : invalid block for awoken pointer "p"',
    --fin = 'line 7 : wrong operator',
    run = 1,
    safety = 2,
    _ana = {
        acc = 1,
    },
}

Test { [[
input void OS_START;
var int ret;
event (bool,int) ok;
par/or do
    await OS_START;
    emit ok => (true,10);
with
    var bool b;
    (b,ret) = await ok;
end
escape ret;
]],
    run = 10,
}

Test { [[
input void OS_START;
event (int,void*) ptr;
var void* p;
var int i;
par/or do
    (i,p) = await ptr;
with
    await OS_START;
    emit ptr => (1, null);
end
escape i;
]],
    --fin = 'line 6 : invalid block for awoken pointer "p"',
    --fin = 'line 6 : attribution to pointer with greater scope',
    run = 1,
}
Test { [[
input void OS_START;
event (int,void*) ptr;
var void* p;
var int i;
par/or do
    var void* p1;
    (i,p1) = await ptr;
    p := p1;
with
    await OS_START;
    emit ptr => (1, null);
end
escape i;
]],
    --fin = 'line 6 : invalid block for awoken pointer "p"',
    run = 1,
}

Test { [[
event (int,void*) ptr;
var void* p;
var int i;
(i,p) = await ptr;
await 1s;
escape i;
]],
    --fin = 'line 5 : cannot `await´ again on this block',
    run = 0,
}

Test { [[
input void OS_START;
event (int,void*) ptr;
var void* p;
var int i;
par/or do
    var void* p1;
    (i,p1) = await ptr;
    p := p1;
with
    await OS_START;
    emit ptr => (1, null);
end
await 1s;
escape i;
]],
    run = 0,
    --fin = 'line 6 : invalid block for awoken pointer "p"',
}

Test { [[
var void* p;
var int i;
input void OS_START;
do
    event (int,void*) ptr;
    par/or do
        (i,p) := await ptr;
    with
        await OS_START;
        emit ptr => (1, null);
    end
end
escape i;
]],
    fin = 'line 7 : wrong operator',
    --fin = 'line 7 : attribution does not require `finalize´',
    --run = 1,
}

Test { [[
var void* p;
var int i;
input void OS_START;
do
    event (int,void*) ptr;
    par/or do
        var void* p1;
        (i,p1) = await ptr;
        p := p1;
    with
        await OS_START;
        emit ptr => (1, null);
    end
end
escape i;
]],
    --fin = 'line 7 : wrong operator',
    --fin = 'line 7 : attribution does not require `finalize´',
    run = 1,
}

Test { [[
var int* p;
var int i;
input void OS_START;
do
    event (int,int*) ptr;
    par/or do
        var int* p1;
        (i,p1) = await ptr;
        p := p1;
    with
        await OS_START;
        var int v = 10;
        emit ptr => (1, &v);
    end
    i = *p;
end
escape i;
]],
    --fin = 'line 7 : wrong operator',
    --fin = 'line 7 : attribution does not require `finalize´',
    --fin = 'line 14 : pointer access across `await´',
    run = 10,
}

Test { [[
input (int,int,int*) A;
async do
    emit A =>
        (1, 1, null);
end
escape 1;
]],
    run = 1;
}

Test { [[
native do
    void* ptr;
end
_ptr = _malloc(1);
escape 1;
]],
    fin = 'line 4 : attribution requires `finalize´',
}
Test { [[
native @nohold _free();
native do
    void* ptr;
end
finalize
    _ptr = _malloc(100);
with
    _free(_ptr);
end
escape 1;
]],
    run = 1,
}

Test { [[
native do
    int V;
    int* alloc (int ok) {
        return &V;
    }
    void dealloc (int* ptr) {
    }
end
native @nohold _dealloc();

var int&? tex;
finalize
    tex = _alloc(1);    // v=2
with
    _dealloc(&tex);
end

escape 1;
]],
    run = 1,
}

Test { [[
native do
    int* alloc (int ok) {
        return NULL;
    }
    void dealloc (int* ptr) {
    }
end
native @nohold _dealloc();

var int&? tex;
finalize
    tex = _alloc(1);    // v=2
with
    _dealloc(&tex);
end

escape 1;
]],
    asr = true,
}

Test { [[
native do
    int* alloc (int ok) {
        return NULL;
    }
    int V = 0;
    void dealloc (int* ptr) {
        if (ptr == NULL) {
            V = 1;
        }
    }
end
native @nohold _dealloc();

do
    var int&? tex;
    finalize
        tex = _alloc(1);
    with
        _dealloc(tex);
    end
end

escape _V;
]],
    run = 1,
}

Test { [[
native do
    struct T;
    typedef struct T t;
    int V = 1;
    t* alloc (int ok) {
        if (ok) {
            V++;
            return (t*) &V;
        } else {
            return NULL;
        }
    }
    void dealloc (t* ptr) {
        if (ptr != NULL) {
            V *= 2;
        }
    }
end
native @nohold _dealloc();

var int ret = _V;           // v=1, ret=1

do
    var _t&? tex;
    finalize
        tex = _alloc(1);    // v=2
    with
        _dealloc(tex);
    end
    ret = ret + _V;         // ret=3
    if not tex? then
        ret = 0;
    end
end                         // v=4

ret = ret + _V;             // ret=7

do
    var _t&? tex;
    finalize
        tex = _alloc(0);    // v=4
    with
        if tex? then
            _dealloc(tex);
        end
    end
    ret = ret + _V;         // ret=11
    if not tex? then
        ret = ret + 1;      // ret=12
    end
end                         // v=4

ret = ret + _V;             // ret=16

escape ret;
]],
    run = 16,
}

Test { [[
native do
    void* f () {
        return NULL;
    }
end

var void&? ptr;
finalize
    ptr = _f();
with
    nothing;
end

escape &ptr == &ptr;  // ptr.SOME fails
]],
    asr = true,
}

Test { [[
native do
    void* f () {
        return NULL;
    }
end

var void&? ptr;
finalize
    ptr = _f();
with
    nothing;
end

escape not ptr?;
]],
    run = 1,
}

Test { [[
native do
    void* f () {
        return NULL;
    }
    void g (void* g) {
    }
end
native @nohold _g();

var void&? ptr;
finalize
    ptr = _f();
with
    _g(&ptr);    // error (ptr is NIL)
end

escape not ptr?;
]],
    asr = true
}

Test { [[
native do
    void* f () {
        return NULL;
    }
    void g (void* g) {
    }
end
native @nohold _g();

var int ret = 0;

do
    var void&? ptr;
    finalize
        ptr = _f();
    with
        if ptr? then
            _g(ptr);
        else
            ret = ret + 1;
        end
    end
    ret = ret + (not ptr?);
end

escape ret;
]],
    run = 2,
}

Test { [[
native do
    int V = 1;
    int* alloc () {
        return &V;
    }
end

var int&? tex1;
finalize
    tex1 = _alloc(1);
with
    nothing;
end

var int& tex2 = tex1;

escape &tex2==&_V;
]],
    run = 1,
}

Test { [[
native do
    int V = 1;
    int* alloc () {
        return NULL;
    }
end

var int&? tex1;
finalize
    tex1 = _alloc(1);
with
    nothing;
end

var int& tex2 = tex1;

escape &tex2==&_V;
]],
    asr = true,
}

Test { [[
native do
    struct T;
    typedef struct T t;
    int V = 1;
    t* alloc (int ok) {
        if (ok) {
            V++;
            return (t*) &V;
        } else {
            return NULL;
        }
    }
    void dealloc (t* ptr) {
        if (ptr != NULL) {
            V *= 2;
        }
    }
end
native @nohold _dealloc();

var int ret = _V;           // v=1, ret=1

do
    var _t&? tex;
    finalize
        tex = _alloc(1);    // v=2
    with
        _dealloc(tex);
    end
    ret = ret + _V;         // ret=3
    if not tex? then
        ret = 0;
    end
end                         // v=4

ret = ret + _V;             // ret=7

do
    var _t&? tex;
    finalize
        tex = _alloc(0);    // v=4
    with
        if tex? then
            _dealloc(tex);
        end
    end
    ret = ret + _V;         // ret=11
    if not tex? then
        ret = ret + 1;      // ret=12
    end
end                         // v=4

ret = ret + _V;             // ret=16

escape ret;
]],
    run = 16,
}

Test { [[
native @nohold _SDL_DestroyWindow();
var int win_w;
var int win_h;
var _SDL_Window& win;
    finalize
        win = _SDL_CreateWindow("UI - Texture",
                            500, 1300, 800, 480, _SDL_WINDOW_SHOWN);
    with
        _SDL_DestroyWindow(win);
    end
escape 0;
]],
    fin = 'line 6 : must assign to a option reference (declared with `&?´)',
}

Test { [[
native do
    int V = 0;
    void* my_alloc (void) {
        V += 1;
        return NULL;
    }
    void my_free () {
        V *= 2;
    }
end

input void SDL_REDRAW;

par/or do
    await 1s;
    _V = _V + 100;
with
    every SDL_REDRAW do
        var void&? srf;
        finalize
            srf = _my_alloc();
        with
            _my_free();
        end
    end
end
escape _V;
]],
    run = { ['~>SDL_REDRAW;~>SDL_REDRAW;~>SDL_REDRAW;~>1s']=114 },
}

Test { [[
loop do
    finalize with
        break;
    end
end
escape 1;
]],
    props = 'line 3 : not permitted inside `finalize´',
}

Test { [[
finalize with
    escape 1;
end
escape 1;
]],
    props = 'line 2 : not permitted inside `finalize´',
}

Test { [[
finalize with
    loop do
        if 1 then
            break;
        end
    end
end
escape 1;
]],
    tight = 'line 2 : tight loop',
    run = 1,
}

Test { [[
finalize with
    var int ok = do
        escape 1;
    end;
end
escape 1;
]],
    run = 1,
}

    -- ASYNCHRONOUS

Test { [[
input void A;
var int ret;
var int& pret = ret;
par/or do
   async(pret) do
      pret=10;
    end;
with
   await A;
   ret = 1;
end
escape ret;
]],
    run = { ['~>A']=10 },
}

Test { [[
input void A;
var int ret;
var int& pret = ret;
par/or do
   async(pret) do
      pret=10;
    end;
with
   await A;
   ret = 1;
end
escape ret;
]],
    run = { ['~>A']=10 },
    safety = 2,
    _ana = {
        acc = 1,
    },
}

Test { [[
async do
    escape 1;
end;
escape 0;
]],
    props = 'line 2 : not permitted inside `async´',
}

Test { [[
var int a = async do
    escape 1;
end;
escape a;
]],
    parser = 'line 1 : after `=´ : expected expression',
}

Test { [[
var int a,b;
async (b) do
    a = 1;
end;
escape a;
]],
    env = 'line 3 : variable/event "a" is not declared',
    --run = 1,
}

Test { [[
var int a;
async do
    a = 1;
end;
escape a;
]],
    env = 'line 3 : variable/event "a" is not declared',
    --run = 1,
}

Test { [[
par/and do
    async do
        escape 1;
    end;
with
    escape 2;
end;
]],
    props = 'line 3 : not permitted inside `async´',
}

Test { [[
par/and do
    async do
    end;
    escape 1;
with
    escape 2;
end;
]],
    --abrt = 1,
    run = 2,
    _ana = {
        unreachs = 3,
    },
}

Test { [[
par/and do
    async do
    end;
    escape 1;
with
    escape 2;
end;
]],
    --abrt = 1,
    run = 2,
    safety = 2,
    _ana = {
        acc = 1,
        unreachs = 3,
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
escape a;
]],
    env = 'line 4 : variable/event "a" is not declared',
    _ana = {
        --acc = 1,
    },
}

Test { [[
async do
    escape 1+2;
end;
]],
    props = 'line 2 : not permitted inside `async´',
}

Test { [[
var int a = 1;
var int& pa = a;
async (a) do
    var int a = do
        escape 1;
    end;
    escape a;
end;
escape a;
]],
    wrn = true,
    props = 'line 5 : not permitted inside `async´',
}

Test { [[
input void X;
async do
    emit X;
end;
escape 0;
]],
    run=0
}

Test { [[
input int A;
var int a;
async do
    a = 1;
    emit A => a;
end;
escape a;
]],
    env = 'line 4 : variable/event "a" is not declared',
    --run=1
}

Test { [[
input void A;
var int a;
async do
    a = emit A;
end;
escape a;
]],
    --env = "line 4 : invalid attribution",
    env = 'line 4 : variable/event "a" is not declared',
    --parser = 'line 4 : after `=´ : expected expression',
}

Test { [[
event int a;
async do
    emit a => 1;
end;
escape 0;
]],
    env = 'line 3 : variable/event "a" is not declared',
}
Test { [[
event int a;
async do
    await a;
end;
escape 0;
]],
    env = 'line 3 : variable/event "a" is not declared',
}
Test { [[
async do
    await 1ms;
end;
escape 0;
]],
    props='not permitted inside `async´'
}
Test { [[
input int X;
async do
    emit X => 1;
end;
emit X => 1;
escape 0;
]],
  props='invalid `emit´'
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
escape 0;
]],
    props='`break´ without loop'
}

Test { [[
native _a;
native do
    int a;
end
async do
    _a = 1;
end
escape _a;
]],
    run = 1,
}

Test { [[
native _a;
native do
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
escape _a+_b;
]],
    todo = 'async is not simulated',
    _ana = {
        acc = 1,
    },
}

Test { [[
@const _a;
@safe _b with _c;

native do
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
escape _a+_b+_c;
]],
    todo = true,
    run = 3,
}

Test { [[
native _a,_b;
native do
    int a=1,b=1;
end
par/or do
    _a = 1;
with
    _b = 1;
end
escape _a + _b;
]],
    _ana = {
        abrt = 1,
    },
    run = 2,
}

Test { [[
native _a,_b;
native do
    int a = 1;
end
var int a=0;
par/or do
    _a = 1;
with
    a = 1;
end
escape _a + a;
]],
    _ana = {
        abrt = 1,
    },
    run = 1,
}

Test { [[
native _a;
native do
    int a = 1;
end
var int a=0;
@safe a with _a;
par/or do
    _a = 1;
with
    a = 1;
end
escape _a + a;
]],
    _ana = {
        abrt = 1,
    },
    run = 1,
}

Test { [[
native do
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
escape _a+_b+_c;
]],
    todo = 'nd in async',
    _ana = {
        acc = 3,
    },
}

Test { [[
var int r;
async(r) do
    var int i = 100;
    r = i;
end;
escape r;
]],
    run=100
}

Test { [[
var int ret;
async (ret) do
    var int i = 100;
    var int sum = 10;
    sum = sum + i;
    ret = sum;
end;
escape ret;
]],
    run = 110,
}

-- sync version
Test { [[
input int F;
var int ret = 0;
var int f = 0;
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
        escape sum;
    end;
with
    f = await F;
end;
escape ret+f;
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
    async(ret) do
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
        ret = sum;
    end;
with
    f = await F;
end;
escape ret+f;
]],
    run = { ['10~>F']=5060 }
}

Test { [[
input int F;
var int ret = 0;
var int f;
par/and do
    async(ret) do
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
        ret = sum;
    end;
with
    f = await F;
end;
escape ret+f;
]],
    run = { ['10~>F']=5060 },
    safety = 2,
}

Test { [[
input int F;
var int ret = 0;
var int f;
par/or do
    async(ret) do
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
        ret =  sum;
    end;
with
    f = await F;
end;
escape ret+f;
]],
    run = { ['10~>F']=10 }
}

Test { [[
input int F;
par do
    await F;
    escape 1;
with
    async do
        loop do
            if 0 then
                break;
            end;
        end;
    end;
    escape 0;
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
escape 0;
]],
    todo = 'detect termination',
    props='async must terminate'
}

Test { [[
var int ret;
async (ret) do
    var int i = 100;
    i = i - 1;
    ret = i;
end;
escape ret;
]],
    run = 99,
}

Test { [[
var int ret;
async(ret) do
    var int i = 100;
    loop do
        break;
    end;
    ret = i;
end;
escape ret;
]],
    _ana = {
        --unreachs = 1,       -- TODO: loop iter
    },
    run = 100,
}

Test { [[
var int ret;
async(ret) do
    var int i = 0;
    if i then
        i = 1;
    else
        i = 2;
    end
    ret = i;
end;
escape ret;
]],
    run = 2,
}

Test { [[
var int i;
var int& pi=i;
async (pi) do
    var int i = 10;
    loop do
        i = i - 1;
        if not i then
            pi = i;
            break;
        end;
    end;
end;
escape i;
]],
    run = 0,
    wrn = true,
}

Test { [[
var int i;
var int& pi = i;
async (pi) do
    var int i = 10;
    loop do
        i = i - 1;
        if not i then
            pi = i;
            break;
        end;
    end;
end;
escape i;
]],
    run = 0,
    wrn = true,
}


Test { [[
var int i = async do
    var int i = 10;
    loop do
        i = i - 1;
    end;
    escape 0;
end;
escape i;
]],
    _ana = {
        unreachs = 3,
        isForever = false,
    },
    --dfa = true,
    todo = true,    -- no simulation for async
}

Test { [[
var int i = 10;
var int& pi = i;
async (pi) do
    loop do
        i = i - 1;
        if not i then
            pi = i;
            break;
        end;
    end;
end;
escape i;
]],
    env = 'line 5 : variable/event "i" is not declared',
}

Test { [[
var int sum;
var int& p = sum;
async (p) do
    var int i = 10;
    var int sum = 0;
    loop do
        sum = sum + i;
        i = i - 1;
        if not i then
            p = sum;
            break;
        end;
    end;
end;
escape sum;
]],
    wrn = true,
    run = 55,
}

Test { [[
input int A;
par do
    async do
        emit A => 1;
    end;
    escape 0;
with
    await A;
    escape 5;
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
escape a;
]],
    run = {
        ['1~>B ; 10~>A'] = 1,
    },
}

Test { [[
input int A;
par/or do
    async do
        emit A => 4;
    end;
with
end;
escape 1;
]],
    _ana = {
        unreachs = 1,
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
            loop i in 5 do
                v = v + i;
            end
            escape v;
        end;
        ret = ret + v;
    with
        var int v = async do
            var int v;
            loop i in 5 do
                v = v + i;
            end
            escape v;
        end;
        ret = ret + v;
    end
end
escape ret;
]],
    todo = 'algo now is nondet',
    _ana = {
        --unreachs = 1,       -- TODO: async
    },
    run = 23,
}

Test { [[
input void* E;
event _tceu_queue* go;
every qu_ in go do
    var _tceu_queue qu = * qu_;
    async(qu) do
        emit E => qu.param.ptr;
    end
end
]],
    fin = 'line 5 : unsafe access to pointer "qu" across `async´',
    --_ana = { isForever=true },
    --run = 1,
}

Test { [[
input void* E;
native @plain _tceu_queue;
event _tceu_queue* go;
every qu_ in go do
    var _tceu_queue qu = * qu_;
    async(qu) do
        emit E => qu.param.ptr;
    end
end
]],
    _ana = {
        isForever = true,
    },
}

-- HIDDEN
Test { [[
var int a = 1;
var int* b = &a;
do
var int a = 0;
end
escape *b;
]],
    wrn = true,
    run = 1,
}

-- INPUT / OUTPUT / CALL

Test { [[
input void A;
input void A;
escape 1;
]],
    run = 1,
}

Test { [[
input void A;
input int A;
escape 1;
]],
    env = 'line 2 : event "A" is already declared',
}

--if not OS then

Test { [[
output xxx A;
escape(1);
]],
    parser = "line 1 : after `output´ : expected type",
}
Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) 1
end
output int A;
emit A => 1;
escape(1);
]],
    run=1
}
Test { [[
output int A;
if emit A => 1 then
    escape 0;
end
escape(1);
]],
    parser = 'line 2 : after `if´ : expected expression',
}
Test { [[
native do
    #define ceu_out_emit(a,b,c,d) 1
end
output int A;
if emit A => 1 then
    escape 0;
end
escape(1);
]],
    parser = 'line 5 : after `if´ : expected expression',
}

Test { [[
output t A;
emit A => 1;
escape(1);
]],
    parser = 'line 1 : after `output´ : expected type',
}
Test { [[
output t A;
emit A => 1;
escape(1);
]],
    parser = 'line 1 : after `output´ : expected type',
}
Test { [[
output _t* A;
emit A => 1;
escape(1);
]],
    env = 'line 2 : wrong argument #1',
}
Test { [[
output int A;
var _t v=1;
emit A => v;
escape(1);
]],
    --env = 'line 2 : undeclared type `_t´',
    --env = 'line 3 : non-matching types on `emit´',
    gcc = 'error: unknown type name',
}
Test { [[
native do
    #define ceu_out_emit(a,b,c,d) 1
end
output int A;
native do
    typedef int t;
end
var _t v=1;
emit A => v;
escape(1);
]],
    --env = 'line 2 : undeclared type `_t´',
    --env = 'line 3 : non-matching types on `emit´',
    run = 1,
}
Test { [[
output int A;
var int a;
emit A => &a;
escape(1);
]],
    env = 'line 3 : wrong argument #1',
}
Test { [[
output int A;
var int a;
if emit A => &a then
    escape 0;
end
escape(1);
]],
    parser = 'line 3 : after `if´ : expected expression',
    --env = 'line 3 : non-matching types on `emit´',
}
Test { [[
output _char A;
escape 1;
]],
    run = 1,
    --env = "line 1 : invalid event type",
}

Test { [[
native do
    /******/
    int end = 1;
    /******/
end
native _end;
escape _end;
]],
    run = 1
}

Test { [[
native/pre do
    ##include <assert.h>
    typedef struct {
        int a;
        int b;
    } t;
end
native do
    ##define ceu_out_emit(a,b,c,d) Fa(a,b,c,d)
    int Fa (tceu_app* app, int evt, int sz, void* v) {
        if (evt == CEU_OUT_A) {
            t* x = ((tceu__t_*)v)->_1;
            return x->a + x->b;
        } else {
            return *((int*)v);
        }
    }
end
native _t = 8;
output _t* A;
output int B;
var int a, b;

var _t v;
v.a = 1;
v.b = -1;
a = emit A => &v;
b = emit B => 5;
escape a + b;
]],
    run = 5,
    --parser = 'line 26 : after `=´ : expected expression',
}

Test { [[
native/pre do
    ##include <assert.h>
    typedef struct {
        int a;
        int b;
    } t;
end
native do
    ##define ceu_out_emit(a,b,c,d) Fa(a,b,c,d)
    int Fa (tceu_app* app, int evt, int sz, void* v) {
        if (evt == CEU_OUT_A) {
            t x = ((tceu__t*)v)->_1;
            return x.a + x.b;
        } else {
            return *((int*)v);
        }
    }
end
native _t = 8;
output _t A;
output int B;
var int a, b;

var _t v;
v.a = 1;
v.b = -1;
a = emit A => v;
b = emit B => 5;
escape a + b;
]],
    run = 5,
    --parser = 'line 26 : after `=´ : expected expression',
}

Test { [[
native _char = 1;
output void A;
native do
    void A (int v) {}
end
var _cahr v = emit A => 1;
escape 0;
]],
    env = 'line 6 : arity mismatch',
    --env = 'line 6 : non-matching types on `emit´',
    --parser = 'line 6 : after `=´ : expected expression',
    --env = 'line 6 : undeclared type `_cahr´',
}
Test { [[
native _char = 1;
output void A;
var _char v = emit A => ;
escape v;
]],
    --parser = 'line 3 : after `=´ : expected expression',
    parser = 'line 3 : before `=>´ : expected `;´',
    --env = 'line 3 : invalid attribution',
}
Test { [[
output void A;
native do
    void A (int v) {}
end
native _char = 1;
var _char v = emit A => 1;
escape 0;
]],
    --parser = 'line 6 : after `=´ : expected expression',
    --env = 'line 6 : non-matching types on `emit´',
    env = 'line 6 : arity mismatch',
}

Test { [[
native do
    void A (int v) {}
end
emit A => 1;
escape 0;
]],
    env = 'event "A" is not declared',
}

Test { [[
native do
    #define ceu_out_emit(a,b,c,d) 0
end
output void A, B;
par/or do
    emit A;
with
    emit B;
end
escape 1;
]],
    _ana = {
        acc = 1,
        abrt = 3,
    },
    run = 1,
}

Test { [[
native do
    #define ceu_out_emit(a,b,c,d) 0
end
@safe A with B;
output void A, B;
par/or do
    emit A;
with
    emit B;
end
escape 1;
]],
    _ana = {
        abrt = 3,
    },
    run = 1,
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) F(d)
    void F (void* p) {
        tceu__int___int_* v = (tceu__int___int_*) p;
        *(v->_1) = 1;
        *(v->_2) = 2;
    }
end

output (int*,  int*) RADIO_SEND;
var int a=1,b=1;
emit RADIO_SEND => (&a,&b);

escape a + b;
]],
    run = 3,
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) F(a,b,d)
    void F (tceu_app* app, int evt, void* p) {
        tceu__int___int_* v = (tceu__int___int_*) p;
        *(v->_1) = (evt == CEU_OUT_RADIO_SEND);
        *(v->_2) = 2;
    }
end

output (int*,  int*) RADIO_SEND;
var int a=1,b=1;
emit RADIO_SEND => (&a,&b);

escape a + b;
]],
    run = 3,
}

Test { [[
native _F();
output int F;
native do
    void F() {};
end
par do
    _F();
with
    emit F => 1;
end
]],
    _ana = {
        reachs = 1,
        acc = 1,
        isForever = true,
    },
}

Test { [[
native _F();
output int F,G;
native do
    void F() {};
end
par do
    _F();
with
    emit F => 1;
with
    emit G => 0;
end
]],
    _ana = {
        reachs = 1,
        acc = 3,
        isForever = true,
    },
}

Test { [[
native _F();
@safe _F with F,G;
output int F,G;
native do
    void F() {};
end
par do
    _F();
with
    emit F => 1;
with
    emit G => 0;
end
]],
    todo = true,
    _ana = {
        acc = 1,
        isForever = true,
    },
}

Test { [[
native _F();
output int* F,G;
@safe _F with F,G;
int a = 1;
int* b;
native do
    void F (int v) {};
end
par do
    _F(&a);
with
    emit F => b;
with
    emit G => &a;
end
]],
    todo = true,
    _ana = {
        acc = 4,
        isForever = true,
    },
}

Test { [[
native _F();
@pure _F;
output int* F,G;
int a = 1;
int* b;
native do
    void F (int v) {};
end
par do
    _F(&a);
with
    emit F => b;
with
    emit G => &a;
end
]],
    todo = true,
    _ana = {
        acc = 4,
        isForever = true,
    },
}

Test { [[
native _F();
@safe F with G;
output void F,G;
par do
    emit F;
with
    emit G;
end
]],
    todo = true,
    _ana = {
        reachs = 1,
        isForever = true,
    },
}

Test { [[
output (int)=>int F;
escape call F=>1;
]],
    parser = 'line 2 : after `call´ : expected expression',
    --parser = 'line 2 : after `F´ : expected `;´',
}

Test { [[
output (int)=>int F;
call F=>1;
escape 1;
]],
    gcc = 'error: #error ceu_out_call_* is not defined',
}

Test { [[
output (int)=>int F;
emit F=>1;
escape 1;
]],
    env = 'line 2 : invalid `emit´',
    --run = 1,
}

Test { [[
native do
    ##define ceu_out_emit_F(a) F(a)
    int F (int v) {
        return v+1;
    }
end
output (int)=>int F;
call F=>1;
escape 1;
]],
    gcc = 'error: #error ceu_out_call_* is not defined',
    --run = 1,
}

Test { [[
native do
    ##define ceu_out_call_F(a) F((int*)a)
    int F (int* v) {
        return *v+1;
    }
end
output (int)=>int F;
call F=>1;
escape 1;
]],
    run = 1,
}

Test { [[
native do
    ##define ceu_out_call(a,b,c) F((int*)c)
    int F (int* v) {
        return *v+1;
    }
end
output (int)=>int F;
var int ret = call F=>1;
escape ret;
]],
    run = 2,
}

Test { [[
native do
    ##define ceu_out_call_F(a) F(a)
    int F (int v) {
        return v+1;
    }
end
output (int)=>int F;
var int ret = call F=>(1,2);
escape ret;
]],
    env = 'line 8 : arity mismatch',
    --env = 'line 8 : invalid attribution (void vs int)',
    --env = 'line 8 : invalid type',
}

Test { [[
output int E;
emit E=>(1,2);
escape 1;
]],
    env = 'line 2 : arity mismatch',
}

Test { [[
event (int) e;
emit e=>(1,2);
escape 1;
]],
    env = 'line 2 : arity mismatch',
}

Test { [[
event (int) e;
emit e;
escape 1;
]],
    env = 'line 2 : arity mismatch',
}

Test { [[
output int E;
emit E;
escape 1;
]],
    env = 'line 2 : arity mismatch',
}

Test { [[
output (int,int) E;
emit E=>1;
escape 1;
]],
    env = 'line 2 : arity mismatch',
}

Test { [[
event (int,int) e;
emit e=>(1);
escape 1;
]],
    env = 'line 2 : arity mismatch',
}

Test { [[
native do
    ##define ceu_out_call_F(a) F(a)
    int F (tceu__int__int* p) {
        return p->_1 + p->_2;
    }
end
output (int,int)=>int F;
var int ret = call F=>(1,2);
escape ret;
]],
    run = 3,
}

Test { [[
native do
    ##define ceu_out_call(a,b,c) F(a,b,c)
    int F (tceu_app* app, tceu_nevt evt, int* p) {
        return (evt == CEU_OUT_F) + *p;
    }
end
output (int)=>int F;
var int ret = (call F=>2);
escape ret;
]],
    run = 3,
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) F(a,b,d)
    int F (tceu_app* app, tceu_nevt evt, void* p) {
        return (evt==CEU_OUT_F && p==NULL);
    }
end
output void F;
var int ret = (emit F);
escape ret;
]],
    run = 1,
}

Test { [[
native do
    ##define ceu_out_emit_F() F()
    int F () {
        return 1;
    }
end
output void F;
var int ret = (emit F);
escape ret;
]],
    run = 1,
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) F(a,b,d)
    int F (tceu_app* app, tceu_nevt evt, int* p) {
        return (evt == CEU_OUT_F) + *p;
    }
end
output int F;
par/and do
    emit F=>1;
with
    emit F=>1;
end
escape 1;
]],
    _ana = {
        acc = 1,
    },
    run = 1,
}

Test { [[
native do
    ##define ceu_out_call(a,b,c) F(a,b,c)
    int F (tceu_app* app, tceu_nevt evt, int* p) {
        return (evt == CEU_OUT_F) + *p;
    }
end
output (int)=>int F;
par/and do
    call F=>1;
with
    call F=>1;
end
escape 1;
]],
    _ana = {
        acc = 1,
    },
    run = 1,
}

Test { [[
input (int a)=>int F,G do
    return a + 1;
end
]],
    adj = 'line 1 : same body for multiple declarations',
}

-- XXX
Test { [[
input (int a)=>int F do
    return a + 1;
end
input (int a)=>int G;
var int ret = call F=>1;
escape ret;
]],
    code = 'line 4 : missing function body',
    --run = 2,
}

Test { [[
input (int a)=>void F do
    this.v = a;
end
var int v = 0;
call F=>1;
escape this.v;
]],
    env = 'line 2 : variable/event "v" is not declared',
}

Test { [[
native @nohold _fprintf(), _stderr;
var int v = 0;
input (int a)=>void F do
    this.v = a;
    _fprintf(_stderr,"a=%d v=%d\n", a, v);
end
_fprintf(_stderr,"v=%d\n", v);
call F=>1;
_fprintf(_stderr,"v=%d\n", v);
escape this.v;
]],
    run = 1,
}

Test { [[
var int v = 0;
input (int a)=>int G do
    return a + 1;
end
input (int a)=>void F do
    this.v = call G=>a;
end
call F=>1;
escape this.v;
]],
    run = 2,
}

Test { [[
input (void,int) A;
escape 1;
]],
    env = 'line 1 : invalid type',
}
Test { [[
input (int,void) A;
escape 1;
]],
    env = 'line 1 : invalid type',
}
Test { [[
output (void,int) A;
escape 1;
]],
    env = 'line 1 : invalid type',
}
Test { [[
output (int,void) A;
escape 1;
]],
    env = 'line 1 : invalid type',
}

Test { [[
input (void)=>void A do
end
escape 1;
]],
    run = 1,
}

Test { [[
input (void, int a)=>void A do
    v = 1;
end
escape 1;
]],
    env = 'line 1 : invalid type',
}

Test { [[
input void OS_START;
var int v = 0;
input (void)=>void A do
    v = 1;
end
call A;
escape v;
]],
    run = 1,
}

Test { [[
input (int c)=>int WRITE do
    return c + 1;
end
var byte b = 1;
var int ret = call WRITE => b;
escape ret;
]],
    run = 2,
}

Test { [[
input (int c)=>int F1 do
    return c + 1;
end
input (int c)=>void F2 do
end
call F2 => 0;
var int ret = call F1 => 1;
escape ret;
]],
    run = 2,
}

--end -- OS (INPUT/OUTPUT)

Test { [[

input (int tilex, int tiley, bool vertical, int lock, int door, word* position) DOOR_SPAWN;

    var int tilex;
    var int tiley;
    var bool vertical;
    var int lock;
    var int door;
    var word* position;
    every (tilex,tiley,vertical,lock,door,position) in DOOR_SPAWN do
    end
]],
    parser = 'line 2 : before `)´ : expected `,´',
    _ana = {
        isForever = true,
    },
}

    -- POINTERS & ARRAYS

-- int_int
Test { [[var int*p; escape p/10;]],  env='invalid operands to binary "/"'}
Test { [[var int*p; escape p|10;]],  env='invalid operands to binary "|"'}
Test { [[var int*p; escape p>>10;]], env='invalid operands to binary ">>"'}
Test { [[var int*p; escape p^10;]],  env='invalid operands to binary "^"'}
Test { [[var int*p; escape ~p;]],    env='invalid operand to unary "~"'}

-- same
Test { [[var int*p; var int a; escape p==a;]],
        env='invalid operands to binary "=="'}
Test { [[var int*p; var int a; escape p!=a;]],
        env='invalid operands to binary "!="'}
Test { [[var int*p; var int a; escape p>a;]],
        env='invalid operands to binary ">"'}

-- any
Test { [[var int*p=null; escape p or 10;]], run=1 }
Test { [[var int*p=null; escape p and 0;]],  run=0 }
Test { [[var int*p=null; escape not p;]], run=1 }

-- arith
Test { [[var int*p; escape p+p;]],     env='invalid operands to binary'}--TODO: "+"'}
Test { [[var int*p; escape p+10;]],    env='invalid operands to binary'}
Test { [[var int*p; escape p+10 and 0;]], env='invalid operands to binary' }

-- ptr
Test { [[var int a; escape *a;]], env='invalid operand to unary "*"' }
Test { [[var int a; var int*pa; (pa+10)=&a; escape a;]],
        env='invalid operands to binary'}
Test { [[var int a; var int*pa; a=1; pa=&a; *pa=3; escape a;]], run=3 }

Test { [[
*((u32*)0x100) = _V;
escape 1;
]],
    gcc = 'error: ‘V’ undeclared (first use in this function)',
}

Test { [[var int  a;  var int* pa=a; escape a;]], env='types mismatch' }
Test { [[var int* pa; var int a=pa;  escape a;]], env='types mismatch' }
Test { [[
var int a;
var int* pa = do
    escape a;
end;
escape a;
]],
    env='types mismatch'
}
Test { [[
var int* pa;
var int a = do
    escape pa;
end;
escape a;
]],
    env='types mismatch'
}

Test { [[
var int* a;
a = null;
if a then
    escape 1;
else
    escape -1;
end;
]],
    run = -1,
}

Test { [[
native _char = 1;
var int i;
var int* pi;
var _char c=10;
var _char* pc;
i = c;
c = i;
i = (int) c;
c = (_char) i;
escape c;
]],
    --env = 'line 6 : invalid attribution',
    run = 10,
}

Test { [[
native _char = 1;
var int i;
var int* pi;
var _char c;
var _char* pc;
i = (int) c;
c = (_char) i;
escape 10;
]],
    run = 10
}

Test { [[
var int* ptr1=null;
var void* ptr2=null;
if 1 then
    ptr2 = ptr1;
else
    ptr2 = ptr2;
end;
escape 1;
]],
    --gcc = 'may be used uninitialized in this function',
    --fin = 'line 6 : pointer access across `await´',
    run = 1,
}

Test { [[
var int* ptr1 = null;
var void* ptr2 = null;
if 1 then
    ptr2 = (void*)ptr1;
else
    ptr2 = ptr2;
end;
escape 1;
]],
    --fin = 'line 6 : pointer access across `await´',
    run = 1,
}

Test { [[
var int* ptr1;
var void* ptr2;
ptr1 = (int*)ptr2;
ptr2 = (void*)ptr1;
escape 1;
]],
    run = 1,
}

Test { [[
var void* ptr1;
var int* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
escape 1;
]],
    env = 'line 4 : types mismatch (`int*´ <= `void*´)',
    run = 1,
}

Test { [[
native _char=1;
var _char* ptr1;
var int* ptr2=(void*)0xFF;
ptr1 = ptr2;
ptr2 = ptr1;
escape (int)ptr2;
]],
    env = 'line 3 : types mismatch (`int*´ <= `void*´)',
    --env = 'line 4 : invalid attribution',
    --run = 255,
    gcc = 'error: assignment from incompatible pointer type'
}
Test { [[
native _char=1;
var _char* ptr1;
var int* ptr2=(void*)0xFF;
ptr1 = (_char*)ptr2;
ptr2 = (int*) ptr1;
escape (int)ptr2;
]],
    env = 'line 3 : types mismatch (`int*´ <= `void*´)',
    --env = 'line 4 : invalid attribution',
    --run = 255,
    gcc = 'error: cast from pointer to integer of different size',
}
Test { [[
native _char=1;
var _char* ptr1;
var int* ptr2;
ptr1 = (_char*)ptr2;
ptr2 = (int*)ptr1;
escape 1;
]],
    run = 1,
}
Test { [[
native _char=1;
var int* ptr1;
var _char* ptr2;
ptr1 = (int*) ptr2;
ptr2 = (_char*) ptr1;
escape 1;
]],
    run = 1,
}

Test { [[
native _FILE=0;
var int* ptr1;
var _FILE* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
escape 1;
]],
    --env = 'line 4 : invalid attribution (int* vs _FILE*)',
    gcc = 'error: assignment from incompatible pointer type',
    --run = 1,
    --env = 'line 4 : invalid attribution',
}

Test { [[
native _FILE=0;
var int* ptr1;
var _FILE* ptr2;
ptr1 = (int*)ptr2;
ptr2 = (_FILE*)ptr1;
escape 1;
]],
    run = 1,
    --env = 'line 4 : invalid attribution',
}

Test { [[
var int a = 1;
var int* b = &a;
*b = 2;
escape a;
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
escape a;
]],
    _ana = {
        abrt = 1,
    },
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
escape b;
]],
    _ana = {
        abrt = 1,
        acc = 1,
    },
    run = 1,
}

Test { [[
var int b = 1;
var int c = 2;
var int* a = &c;
@safe b with a, c;
par/and do
    b = 1;
with
    *a = 3;
end
escape *a+b+c;
]],
    run = 7,
}

Test { [[
native @nohold _f();
native do
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
escape a + b;
]],
    run = 2,
    _ana = {
        acc = 1,
    },
}

Test { [[
native @nohold _f();
native do
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
escape a + b;
]],
    run = 2,
    _ana = {
        acc = 9,
    },
}

Test { [[
native @nohold _f();
native do
    void f (int* v) {
        *v = 1;
    }
end
var int a, b=0;
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
escape a + b;
]],
    run = 1,
    _ana = {
        abrt = 6,
        acc = 9,
    },
}

Test { [[
@pure _f;
native do
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
escape a + b;
]],
    todo = true,
    run = 2,
    _ana = {
        acc = 2,
    },
}

Test { [[
@pure _f;
native do
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
escape a + b;
]],
    todo = true,
    run = 1,
    _ana = {
        acc = 2,
    },
}

Test { [[
var int b = 10;
var int* a = (int*) &b;
var int* c = &b;
escape *a + *c;
]],
    run = 20;
}

Test { [[
native _f();
native do
    int* f () {
        int a = 10;
        escape &a;
    }
end
var int&? p = _f();
escape p;
]],
    fin = 'line 8 : attribution requires `finalize´',
}

Test { [[
native _f();
native do
    int a;
    int* f () {
        a = 10;
        return &a;
    }
end
var int&? p;
finalize
    p = _f();
with
    nothing;
end
escape p;
]],
    run = 10,
}
Test { [[
native _f();
native do
    int a;
    int* f () {
        a = 10;
        return &a;
    }
end
var int&? p;
finalize
    p = _f();
with
    nothing;
end
escape p;
]],
    run = 10,
}
Test { [[
native @pure _f();    // its actually impure
native do
    int a;
    int* f () {
        a = 10;
        return &a;
    }
end
var int* p;
    p = _f();
escape *p;
]],
    run = 10,
}
Test { [[
native _f();
native do
    int A = 10;
    int* f () {
        return &A;
    }
end
var int a;
do
    var int&? p;
    finalize
        p = _f();
    with
        a = p;
end
end
escape a;
]],
    run = 10,
}

Test { [[
native _f();
native do
    int A = 10;
    int* f () {
        return &A;
    }
end
var int a = 10;
do
    var int&? p;
    do
        finalize
            p = _f();
        with
            a = a + p;
end
    end
    a = 0;
end
escape a;
]],
    run = 10,
}

Test { [[
native do
    ##define f(p)
end
par/or do
    _f(_p)
        finalize with
            _f(null);
        end;
with
    await FOREVER;
end
escape 1;
]],
    fin = 'line 5 : invalid `finalize´',
    --run = 1,
}

Test { [[
native do
    ##define f(p)
end
par/or do
    _f(_p);
with
    await FOREVER;
end
escape 1;
]],
    run = 1,
}

Test { [[
native _char = 1;
var _char* p;
*(p:a) = (_char)1;
escape 1;
]],
    --env = 'line 3 : invalid operand to unary "*"',
    gcc = 'error: request for member',
}

Test { [[
input void OS_START;
var int h = 10;
var int& p = h;
do
    var int x = 0;
    await OS_START;
    var int z = 0;
end
escape p;
]],
    run = 10;
}

    -- ARRAYS

Test { [[input int[1] E; escape 0;]],
    run = 0,
    --env = 'invalid event type',
    --parser = "line 1 : after `int´ : expected identifier",
}
Test { [[var int[0] v; escape 0;]],
    run = 0,
    --env='invalid array dimension'
}
Test { [[var int[2] v; escape v;]],
    env = 'types mismatch'
}
Test { [[var u8[2] v; escape &v;]],
    env = 'invalid operand to unary "&"',
}

Test { [[
N;
]],
    --adj = 'line 1 : invalid expression',
    --parser = 'line 1 : after `<BOF>´ : expected statement',
    parser = 'line 1 : after `<BOF>´ : expected statement (usually a missing `var´ or C prefix `_´)',
}

Test { [[
void[10] a;
]],
    parser = 'line 1 : after `<BOF>´ : expected statement',
}

Test { [[
var void[10] a;
]],
    env = 'line 1 : cannot instantiate type "void"',
}

Test { [[
var int[2] v;
v[0] = 5;
escape v[0];
]],
    run = 5
}

Test { [[
var int[2] v;
v[0] = 1;
v[1] = 1;
escape v[0] + v[1];
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
escape v[i+1];
]],
    run = 5
}

Test { [[
var void a;
var void[1] b;
]],
    env = 'line 1 : cannot instantiate type "void"',
}

Test { [[
var int a;
var void[1] b;
]],
    env = 'line 2 : cannot instantiate type "void"',
}

Test { [[
native do
    typedef struct {
        int v[10];
        int c;
    } T;
end
native _T = 44;

var _T[10] vec;
var int i = 110;

vec[3].v[5] = 10;
vec[9].c = 100;
escape i + vec[9].c + vec[3].v[5];
]],
    run = 220,
}

Test { [[
var int i = do
    var char[5] abcd;
    escape 1;
end;
escape i;
]],
    run = 1,
}

Test { [[var int[2] v; await v;     escape 0;]],
        env='event "v" is not declared' }
Test { [[var int[2] v; emit v;    escape 0;]],
        env='event "v" is not declared' }
Test { [[var int[2] v; await v[0];  escape 0;]],
        env='line 1 : event "?" is not declared'}
Test { [[var int[2] v; emit v[0]; escape 0;]],
        env='event "?" is not declared' }
Test { [[var int[2] v; v=v; escape 0;]], env='types mismatch' }
Test { [[var int v; escape v[1];]], env='cannot index a non array' }
Test { [[var int[2] v; escape v[v];]], env='invalid array index' }

Test { [[
var int[2] v ;
escape v == &v[0] ;
]],
    run = 1,
}

Test { [[
native @nohold _f();
native do
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
escape a[0] + b;
]],
    run = 3,
}

Test { [[
native @nohold _f();
native do
    void f (int* p) {
        *p = 1;
    }
end
var int[2] a;
a[0] = 0;
a[1] = 0;
var int b;
par/or do
    b = 2;
with
    _f(a);
end
escape a[0] + b;
]],
    _ana = {
        abrt = 1,
    },
    run = 2,
}

Test { [[
var u8[255] vec;
event void  e;
escape 1;
]],
    --mem = 'too many events',    -- TODO
    run = 1,
}

local evts = ''
for i=1, 256 do
    evts = evts .. 'event int e'..i..';\n'
end
Test { [[
]]..evts..[[
escape 1;
]],
    env = 'line 1 : too many events',
}

Test { [[
var int a = 1;
escape a;
]],
    run = 1,
}

    -- NATIVE C FUNCS BLOCK RAW

Test { [[
var _char c = 1;
escape c;
]],
    run = 1,
}

Test { [[
native @plain _int;
var _int a=1, b=1;
a = b;
await 1s;
escape a==b;
]],
    run = { ['~>1s'] = 1 },
}

Test { [[
native @plain _int;
var int a=1, b=1;
a = b;
await 1s;
escape a==b;
]],
    run = { ['~>1s'] = 1 },
}

Test { [[
escape {1};
]],
    run = 1,
}

Test { [[
{ int V = 10; };
escape _V;
]],
    run = 10,
}

Test { [[
var void&? p;
finalize
    p = { NULL };
with
    nothing;
end
escape p==null;
]],
    env = 'line 7 : invalid operands to binary "=="',
    --run = 1,
}

Test { [[
var void&? p;
p := { NULL };
escape 1;
//escape p==null;
]],
    fin = 'line 2 : attribution requires `finalize´',
}

Test { [[
_f()
]],
    parser = 'line 1 : after `)´ : expected `;´',
}

Test { [[
native _printf();
do
    _printf("oi\n");
end
escape 10;
]],
    run = 10;
}

Test { [[
native _V;
native do
    int V[2][2] = { {1, 2}, {3, 4} };
end

_V[0][1] = 5;
escape _V[1][0] + _V[0][1];
]],
    run = 8,
}

Test { [[
native _END;
native do
    int END = 1;
end
if not  _END-1 then
    escape 1;
else
    escape 0;
end
]],
    run = 1,
}

Test { [[
native do
end
escape 1;
]],
    run = 1,
}

Test { [[
native do
    char* a = "end";
end
escape 1;
]],
    run = 1,
}

Test { [[
native do
    /*** END ***/
    char* a = "end";
    /*** END ***/
end
escape 1;
]],
    run = 1,
}

Test { [[
native do
    int A () {}
end
A = 1;
escape 1;
]],
    --adj = 'line 4 : invalid expression',
    --parser = 'line 3 : after `end´ : expected statement'
    parser = 'line 3 : after `end´ : expected statement (usually a missing `var´ or C prefix `_´)',
}

Test { [[
native do
    void A (int v) {}
end
escape 0;
]],
    run = 0;
}

Test { [[
native do
    int A (int v) { return 1; }
end
escape 0;
]],
    --env = 'A : incompatible with function definition',
    run = 0,
}

Test { [[
native _A;
native do
    void A (int v) {}
end
_A();
escape 0;
]],
    --env = 'line 5 : native function "_A" is not declared',
    --run  = 1,
    gcc = 'error: too few arguments to function ‘A’',
}

Test { [[
native _A();
native do
    void A (int v) { }
end
_A(1);
escape 0;
]],
    run = 0,
}

Test { [[
native _A();
native do
    void A () {}
end
var int v = _A();
escape v;
]],
    gcc = 'error: void value not ignored as it ought to be',
}

Test { [[emit A => 10; escape 0;]],
    env = 'event "A" is not declared'
}

Test { [[
native _Const();
native do
    int Const () {
        return -10;
    }
end
var int ret = _Const();
escape ret;
]],
    run = -10
}

Test { [[
native _ID();
native do
    int ID (int v) {
        return v;
    }
end
escape _ID(10);
]],
    run = 10,
}

Test { [[
native _ID();
native do
    int ID (int v) {
        return v;
    }
end
var int v = _ID(10);
escape v;
]],
    run = 10
}

Test { [[
native _VD();
native do
    void VD (int v) {
    }
end
_VD(10);
escape 1;
]],
    run = 1
}

Test { [[
native _VD();
native do
    void VD (int v) {
    }
end
var int ret = _VD(10);
escape ret;
]],
    gcc = 'error: void value not ignored as it ought to be',
}

Test { [[
native do
    void VD (int v) {
    }
end
var void v = _VD(10);
escape v;
]],
    env = 'line 5 : cannot instantiate type "void"',
}

Test { [[
native _NEG();
native do
    int NEG (int v) {
        return -v;
    }
end
escape _NEG(10);
]],
    run = -10,
}

Test { [[
native _NEG();
native do
    int NEG (int v) {
        return -v;
    }
end
var int v = _NEG(10);
escape v;
]],
    run = -10
}

Test { [[
native _ID();
native do
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
escape v;
]],
    run = {['1~>A']=10},
}

Test { [[
native _ID();
native do
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
escape v;
]],
    _ana = {
        unreachs = 1,
    },
    run = 10,
}

Test { [[
native _Z1();
native do int Z1 (int a) { return a; } end
input int A;
var int c;
_Z1(3);
c = await A;
escape c;
]],
    run = {
        ['10~>A ; 20~>A'] = 10,
        ['3~>A ; 0~>A'] = 3,
    }
}

Test { [[
native @nohold _f1(), _f2();
native do
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
escape _f2(&v[0],&v[1]) + _f1(v) + _f1(&v[0]);
]],
    run = 39,
}

Test { [[
native do
    void* V;
end
var void* v;
_V = v;
escape 1;
]],
    run = 1,
}

Test { [[
native do
    void* V;
end
var void* v=null;
_V = v;
await 1s;
escape _V==null;
]],
    run = false,
    --fin = 'line 7 : pointer access across `await´',
}

Test { [[
do
    var int* p, p1;
    event int* e;
    p = await e;
    p1 = p;
    await e;
    escape *p1;
end
]],
    --run = 1,
    fin = 'line 7 : unsafe access to pointer "p1" across `await´',
}

Test { [[
native do
    typedef int tp;
end
var _tp* v;
_a = v;
await 1s;
_b = _a;    // _a pode ter escopo menor e nao reclama de FIN
await FOREVER;
]],
    --fin = 'line 7 : pointer access across `await´',
    _ana = {
        isForever = true,
    },
}

Test { [[
var int v = 10;
var int* x = &v;
event void e;
var int ret;
if 1 then
    ret = *x;
    emit e;
else
    emit e;
    escape *x;
end
escape ret;
]],
    fin = 'line 10 : unsafe access to pointer "x" across `emit´',
}

Test { [[
var int v = 10;
var int* x = &v;
event void e;
var int ret;
if 1 then
    ret = *x;
    emit e;
else
    escape *x;
end
escape ret;
]],
    run = 10,
}

Test { [[
var int v = 10;
var int* x = &v;
event void e;
var int ret;
par do
    ret = *x;
    emit e;
with
    escape *x;
end
]],
    _ana = {acc=2},
    run = 10,
}

Test { [[
var int v = 10;
var int* x = &v;
event void e;
var int ret;
par do
    ret = *x;
    emit e;
with
    par/or do
        ret = *x;
        emit e;
    with
        ret = *x;
        await e;
    with
        par/and do
            ret = *x;
            emit e;
        with
            ret = *x;
            await e;
        end
    end
with
    escape *x;
end
]],
    _ana = {acc=true},
    run = 10,
}

Test { [[
native @plain _SDL_Rect, _SDL_Point;
var _SDL_Point pos;

var _SDL_Rect rect;
    rect.x = pos.x;    // centered position
    rect.y = pos.y;    // centered position
await 1s;
var _SDL_Rect r = rect;
escape 1;
]],
    gcc = 'error: unknown type name ‘SDL_Point’',
}

Test { [[
native @plain _SDL_Rect, _SDL_Point;
var _SDL_Point pos;

var _SDL_Rect rect;
    rect.x = (int)pos.x;    // centered position
    rect.y = (int)pos.y;    // centered position
await 1s;
var _SDL_Rect r = rect;
    r.x = r.x - r.w/2;
    r.y = r.y - r.h/2;
escape 1;
]],
    gcc = 'error: unknown type name ‘SDL_Point’',
}

Test { [[
native do
    int f () {
        return 1;
    }
end
var int[2] v;
v[0] = 0;
v[1] = 1;
v[_f()] = 2;
escape v[1];
]],
    run = 2,
}

-- NATIVE/PRE

Test { [[
native/pre do
    typedef struct {
        int a,b,c;
    } F;
end
native do
    F* fff;
end

input (char* path, char* mode)=>_F* OPEN do
    return _fff;
end

input (_F* f)=>int CLOSE do
    return 1;
end

input (_F* f)=>int SIZE do
    return 1;
end

input (void* ptr, int size, int nmemb, _F* f)=>int READ do
    return 1;
end

escape 1;
]],
    run = 1,
}

Test { [[
native/pre do
    typedef struct {
        char* str;
        u32   length;
        u32   x;
        u32   y;
    } draw_string_t;
end

input (_draw_string_t* ptr)=>void DRAW_STRING do
end

var _draw_string_t v;
    v.str = "Welcome to Ceu/OS!\n";
    v.length = 20;
    v.x = 100;
    v.y = 100;
call DRAW_STRING => &v;

escape 1;
]],
    run = 1,
}

--[=[

PRE = [[
native do
    static inline int idx (@const int* vec, int i) {
        return vec[i];
    }
    static inline int set (int* vec, int i, int val) {
        vec[i] = val;
        return val;
    }
end
@pure _idx;
int[2] va;

]]

Test { PRE .. [[
_set(va,1,1);
escape _idx(va,1);
]],
    run = 1,
}

Test { PRE .. [[
_set(va,0,1);
_set(va,1,2);
escape _idx(va,0) + _idx(va,1);
]],
    run = 3,
}

Test { PRE .. [[
par/and do
    _set(va,0,1);
with
    _set(va,1,2);
end;
escape _idx(va,0) + _idx(va,1);
]],
    _ana = {
        acc = 2,
    },
}
Test { PRE .. [[
par/and do
    _set(va,0,1);
with
    _idx(va,1);
end;
escape _idx(va,0) + _idx(va,1);
]],
    _ana = {
        acc = 1,
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
escape _idx(va,0) + _idx(va,1);
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
escape 1;
]],
    run = 1
}

PRE = [[
@pure _f3, _f5;
native do
int f1 (int* a, int* b) {
    return *a + *b;
}
int f2 (@const int* a, int* b) {
    return *a + *b;
}
int f3 (@const int* a, const int* b) {
    return *a + *b;
}
int f4 (int* a) {
    return *a;
}
int f5 (@const int* a) {
    return *a;
}
end
]]

Test { PRE .. [[
int a = 1;
int b = 2;
escape _f1(&a,&b);
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
escape 0;
]],
    _ana = {
        acc = 1,
    },
}
Test { PRE .. [[
int a;
par/or do
    _f4(&a);
with
    int v = a;
end;
escape 0;
]],
    _ana = {
        acc = 1,
    },
}
Test { PRE .. [[
int a, b;
par/or do
    _f5(&a);
with
    a = 1;
end;
escape 0;
]],
    _ana = {
        acc = 1,
    },
}
Test { PRE .. [[
int a = 10;
par/or do
    _f5(&a);
with
    escape a;
end;
escape 0;
]],
    run = false,
    _ana = {
        --abrt = 1,
    }
}
Test { PRE .. [[
int a;
int* pa;
par/or do
    _f5(pa);
with
    escape a;
end;
escape 0;
]],
    --abrt = 1,
    _ana = {
        acc = 1,
    },
}
Test { PRE .. [[
int a, b;
par/or do
    _f4(&a);
with
    int v = b;
end;
escape 0;
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
escape 0;
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
escape 0;
]],
    run = 0,
}
Test { PRE .. [[
int* pa;
do
    int a;
    pa = &a;
end;
escape 1;
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
escape a;
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
escape 0;
]],
    _ana = {
        acc = 2, -- TODO: scope of v vs pa
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
escape a;
]],
    _ana = {
        acc = 1,
    },
}
Test { PRE .. [[
int a;
int* pa;
par do
    escape _f5(pa);
with
    escape a;
end;
]],
    --abrt = 2,
    _ana = {
        acc = 2, -- TODO: $ret vs anything is DET
    },
}

Test { PRE .. [[
int a=1, b=5;
par/or do
    _f4(&a);
with
    _f4(&b);
end;
escape a+b;
]],
    _ana = {
        acc = 1,
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
escape v1 + v2;
]],
    _ana = {
        acc = 3,
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
escape v1 + v2;
]],
    _ana = {
        acc = 3,     -- TODO: f2 is const
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
escape v1 + v2;
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
escape a+b;
]],
    run = 4,
    _ana = {
        acc = 1,
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
escape a+a;
]],
    _ana = {
        acc = 2,
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
escape a+a;
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
escape v1+v2;
]],
    _ana = {
        acc = 3,
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
escape v1+v2;
]],
    _ana = {
        acc = 1,
    },
}

Test { [[
par/and do
    _printf("END: 1\n");
with
    _assert(1);
end
escape 0;
]],
    _ana = {
        acc = 1,
    },
    run = 1,
}

Test { [[
@safe _printf with _assert;
native do ##include <assert.h> end
par/and do
    _printf("END: 1\n");
with
    _assert(1);
end
escape 0;
]],
    todo = true,
    run = 1,
}
--]=]

Test { [[
native _a;
native do
    int a;
end
par/or do
    _a = 1;
with
    _a = 2;
end
escape _a;
]],
    _ana = {
        acc = 1,
        abrt = 1,
    },
}

Test { [[
@const _HIGH, _LOW;
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
    _ana = {
        acc = 6,
        isForever = true,
    },
}

Test { [[
native _LOW, _HIGH, _digitalWrite();
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
    _ana = {
        acc = 48,        -- TODO: nao conferi
        isForever = true,
    },
    --fin = 'line 4 : call requires `finalize´',
}

Test { [[
native @const _LOW, _HIGH;
native _digitalWrite();
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
    _ana = {
        acc = 48,
        isForever = true,
    },
}

    -- RAW

Test { [[
native do
    int V = 0;
    int fff (int a, int b) {
        V = V + a + b;
        return V;
    }
end
{fff}(1,2);
var int i = {fff}(3,4);
escape i;
]],
    parser = 'line 8 : before `)´ : expected `;´',
}

Test { [[
native do
    int V = 0;
    int fff (int a, int b) {
        V = V + a + b;
        return V;
    }
end
call {fff}(1,2);
var int i = {fff}(3,4);
escape i;
]],
    run = 10,
}

    -- STRINGS

Test { [[
var char[10] a;
a = "oioioi";
escape 1;
]],
    env = 'line 2 : invalid attribution',
}

Test { [[
var char* a;
a = "oioioi";
escape 1;
]],
    run = 1,
}

Test { [[
var int a;
a = "oioioi";
escape 1;
]],
    env = 'line 2 : types mismatch (`int´ <= `char*´)',
}

Test { [[
native _char=1;
var _char* a = "Abcd12" ;
escape 1;
]],
    --env = 'line 2 : invalid attribution (_char* vs char*)',
    run = 1,
}
Test { [[
native _char=1;
var _char* a = (_char*)"Abcd12" ;
escape 1;
]],
    run = 1
}
Test { [[
native _printf();
_printf("END: %s\n", "Abcd12");
escape 0;
]],
    run='Abcd12',
}
Test { [[
native _strncpy(), _printf(), _strlen();
escape _strlen("123");
]], run=3 }
Test { [[
native _printf();
_printf("END: 1%d\n",2); escape 0;]], run=12 }
Test { [[
native _printf();
_printf("END: 1%d%d\n",2,3); escape 0;]], run=123 }

Test { [[
native @nohold _strncpy(), _printf(), _strlen();
native _char = 1;
var _char[10] str;
_strncpy(str, "123", 4);
_printf("END: %d %s\n", (int)_strlen(str), str);
escape 0;
]],
    run = '3 123'
}

Test { [[
native @nohold _strncpy(), _printf(), _strlen(), _strcpy();
native _char = 1;
var _char[6] a; _strcpy(a, "Hello");
var _char[2] b; _strcpy(b, " ");
var _char[7] c; _strcpy(c, "World!");
var _char[30] d;

var int len = 0;
_strcpy(d,a);
_strcpy(&d[_strlen(d)], b);
_strcpy(&d[_strlen(d)], c);
_printf("END: %d %s\n", (int)_strlen(d), d);
escape 0;
]],
    run = '12 Hello World!'
}

Test { [[
native _const_1();
native do
    int const_1 () {
        return 1;
    }
end
escape _const_1();
]],
    run = 1;
}

Test { [[
native _const_1();
native do
    int const_1 () {
        return 1;
    }
end
escape _const_1() + _const_1();
]],
    run = 2;
}

Test { [[
native _inv();
native do
    int inv (int v) {
        return -v;
    }
end
var int a;
a = _inv(_inv(1));
escape a;
]],
    --fin = 'line 8 : call requires `finalize´',
    run = 1,
}

Test { [[
native @pure _inv();
native do
    int inv (int v) {
        return -v;
    }
end
var int a;
a = _inv(_inv(1));
escape a;
]],
    run = 1,
}

Test { [[
native _id();
native do
    int id (int v) {
        return v;
    }
end
var int a;
a = _id(1);
escape a;
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
escape 0;
]],
    _ana = {
        acc = 1,
        abrt = 1,
    },
}
Test { [[
var int[2] v;
var int i=0,j=0;
par/or do
    v[j] = 1;
with
    v[i+1] = 2;
end;
escape 0;
]],
    _ana = {
        acc = 1,
        abrt = 1,
    },
}

-- STRUCTS / SIZEOF

Test { [[
native do
typedef struct {
    u16 a;
    u8 b;
    u8 c;
} s;
end
native _s = 4;
var _s vs;
vs.a = 10;
vs.b = 1;
escape vs.a + vs.b + sizeof(_s);
]],
    run = 15,
}

Test { [[
native do
typedef struct {
    u16 a;
    u8 b;
    u8 c;
} s;
end
native _s = 4;
var _s vs;
vs.a = 10;
vs.b = 1;
escape vs.a + vs.b + sizeof(_s) + sizeof(vs) + sizeof(vs.a);
]],
    run = 21,
}

Test { [[
native _SZ;
native _aaa = (sizeof<void*,u16>) * 2;
native do
    typedef struct {
        void* a;
        u16 b;
    } t1;
    typedef struct {
        t1 v[2];
    } aaa;
    int SZ = sizeof(aaa);
end
escape sizeof<_aaa> + _SZ;
]],
    todo = 'sizeof',
    run = 28,   -- TODO: different packings
}

Test { [[
native do
    typedef struct {
        u16 ack;
        u8 data[16];
    } Payload;
end
native _Payload = 18;
var _Payload final;
var u8* neighs = &(final.data[4]);
escape 1;
]],
    run = 1;
}

Test { [[
native do
typedef struct {
    int a;
    int b;
} s;
end
native _s = 8;
var _s vs;
par/and do
    vs.a = 10;
with
    vs.a = 1;
end;
escape vs.a;
]],
    _ana = {
        acc = 1,
    },
}

Test { [[
native do
typedef struct {
    int a;
    int b;
} s;
end
native _s = 8;
var _s vs;
par/and do
    vs.a = 10;
with
    vs.b = 1;
end;
escape vs.a;
]],
    _ana = {
        acc = 1,     -- TODO: struct
    },
}

Test { [[
native do
    typedef struct {
        int a;
    } mys;
end
native _mys = 4;
var _mys v;
var _mys* pv;
pv = &v;
v.a = 10;
(*pv).a = 20;
pv:a = pv:a + v.a;
escape v.a;
]],
    run = 40,
}

Test { [[
]],
    _ana = {
        reachs = 1,
        isForever = true,
    }
}

Test { [[
native @plain _char=1;
var u8[10] v1;
var _char[10] v2;

loop i in 10 do
    v1[i] = i;
    v2[i] = (_char) (i*2);
end

var int ret = 0;
loop i in 10 do
    ret = ret + (u8)v2[i] - v1[i];
end

escape ret;
]],
    --loop = 1,
    run = 45,
}

Test { [[
native _message_t = 52;
native _t = sizeof<_message_t, u8>;
escape sizeof<_t>;
]],
    todo = 'sizeof',
    run = 53,
}

Test { [[
native _char=1;
var _char a = (_char) 1;
escape (int)a;
]],
    run = 1,
}

-- Exps

Test { [[var int a = ]],
    parser = "line 1 : after `=´ : expected expression",
}

Test { [[escape]],
    parser = "line 1 : after `escape´ : expected expression",
}

Test { [[escape()]],
    parser = "line 1 : after `(´ : expected expression",
}

Test { [[escape 1+;]],
    parser = "line 1 : after `+´ : expected expression",
}

Test { [[if then]],
    parser = "line 1 : after `if´ : expected expression",
}

Test { [[b = ;]],
    parser = "line 1 : after `=´ : expected expression",
}


Test { [[


escape 1

+


;
]],
    parser = "line 5 : after `+´ : expected expression"
}

Test { [[
var int a;
a = do
    var int b;
end
]],
    parser = "line 4 : after `end´ : expected `;´",
}

    -- POINTER ASSIGNMENTS

Test { [[
var int* p;
do
    var int i;
    p = &i;
end
escape 1;
]],
    fin = 'line 4 : attribution to pointer with greater scope',
}
Test { [[
var int* p;
do
    var int i;
    p := &i;
end
escape 1;
]],
    run = 1,
}
Test { [[
var int a := 1;
escape 1;
]],
    fin = 'line 1 : wrong operator',
}
Test { [[
var int a;
a := 1;
escape 1;
]],
    fin = 'line 2 : wrong operator',
}
Test { [[
var int a;
finalize
    a = 1;
with
    nothing;
end
escape 1;
]],
    fin = 'line 3 : attribution does not require `finalize´',
}
Test { [[
var int* a := null;
escape 1;
]],
    fin = 'line 1 : wrong operator',
}
Test { [[
var int* a;
a := null;
escape 1;
]],
    fin = 'line 2 : wrong operator',
}
Test { [[
var int* a;
finalize
    a = null;
with
    nothing;
end
escape 1;
]],
    fin = 'line 3 : attribution does not require `finalize´',
}
Test { [[
function (void)=>void faca do
    var int* a;
    a := null;
end
escape 1;
]],
    fin = 'line 3 : wrong operator',
}
Test { [[
var int a;
var int* pa := &a;
escape 1;
]],
    fin = 'line 2 : wrong operator',
    run = 1,
}
Test { [[
var int a;
var int* pa;
finalize
    pa = &a;
with
    nothing;
end
escape 1;
]],
    fin = 'line 4 : attribution does not require `finalize´',
}
Test { [[
function (void* o1)=>void f do
    var void* tmp := o1;
end
escape 1;
]],
    fin = 'line 2 : wrong operator',
    --fin = 'line 2 : pointer access across `await´',
}

Test { [[
var int* u;
var int[1] i;
await 1s;
u = i;
escape 1;
]],
    run = { ['~>1s']=1 },
}
Test { [[
var int* u;
do
    var int[1] i;
    i[0] = 2;
    u = i;
end
do
    var int[1] i;
    i[0] = 5;
end
escape *u;
]],
    fin = 'line 5 : attribution to pointer with greater scope',
}
Test { [[
input int SDL_KEYUP;
var int key;
key = await SDL_KEYUP;
escape key;
]],
    run = { ['1 ~> SDL_KEYUP']=1 }
}

Test { [[
input int* SDL_KEYUP;
par/or do
    var int* key;
    key = await SDL_KEYUP;
with
    async do
        emit SDL_KEYUP => null;
    end
end
escape 1;
]],
    run = 1.
}

Test { [[
input _SDL_KeyboardEvent* SDL_KEYUP;
every key in SDL_KEYUP do
    if key:keysym.sym == 1 then
    else/if key:keysym.sym == 1 then
    end
end
]],
    _ana = {
        isForever = true,
    },
}

Test { [[
function (int id, void** o1, void** o2)=>int getVS do
    if (*o1) then
        return 1;
    else/if (*o2) then
        var void* tmp = *o1;
        *o1 = *o2;
        *o2 := tmp;
            // tmp is an alias to "o1"
        return 1;
    else
        //*o1 = NULL;
        //*o2 = NULL;
        return 0;
    end
end
escape 1;
]],
    run = 1,
}

    -- CPP / DEFINE / PREPROCESSOR

Test { [[
#define _OBJ_N + 2
var void*[_OBJ_N] objs;
escape 1;
]],
    run = 1,
}

Test { [[
#define _OBJ_N + 2 \
               + 1
var void*[_OBJ_N] objs;
escape 1;
]],
    run = 1,
}

Test { [[
#define OI

a = 1;
]],
    env = 'line 3 : variable/event "a" is not declared',
}

Test { [[
native do
    #define N 1
end
var u8[_N] vec;
vec[0] = 10;
escape vec[_N-1];
]],
    run = 10,
}

Test { [[
native do
    #define N 1
end
var u8[N] vec;
vec[0] = 10;
escape vec[N-1];
]],
    run = 10,
}

Test { [[
native do
    #define N 1
end
var u8[N+1] vec;
vec[1] = 10;
escape vec[1];
]],
    run = 10,
}

Test { [[
#define N 1
var u8[N+1] vec;
vec[1] = 10;
escape vec[1];
]],
    run = 10,
}

Test { [[
native do
    #define N 5
end
var int[_N] vec;
loop i in _N do
    vec[i] = i;
end
var int ret = 0;
loop i in _N do
    ret = ret + vec[i];
end
escape ret;
]],
    --loop = true,
    wrn = true,
    run = 10,
}

Test { [[
#define UART0_BASE 0x20201000
#define UART0_CR ((u32*)(UART0_BASE + 0x30))
*UART0_CR = 0x00000000;
escape 1;
]],
    valgrind = false,
    asr = true,
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
    props = "line 3 : not permitted inside `async´",
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
    props = "line 4 : not permitted inside `async´",
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
    props = "line 2 : not permitted inside `async´",
}

-- DFA

Test { [[
var int a;
]],
    _ana = {
        reachs = 1,
        isForever = true,
    },
}

Test { [[
var int a;
a = do
    var int b;
end;
]],
    _ana = {
        reachs = 1,
        unreachs = 1,
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
escape a;
]],
    _ana = {
        acc = 1,
        abrt = 1,
    },
}

-- BIG // FULL // COMPLETE
Test { [[
input int KEY;
if 1 then escape 50; end
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
                        escape 1;           // finish line
                    end
                    points = points + 1;
                end
            with
                loop do
                    var int key = await KEY;
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
                    emit KEY => read1;
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
event bool a;
pause/if a do
end
escape 1;
]],
    run = 1,
}

Test { [[
input void A;
pause/if A do
end
escape 0;
]],
    --adj = 'line 2 : invalid expression',
    parser = 'line 2 : after `pause/if´ : expected expression',
}

Test { [[
event void a;
var int v = await a;
escape 0;
]],
    --env = 'line 2 : event type must be numeric',
    --env = 'line 2 : invalid attribution',
    env = 'line 2 : arity mismatch',
    --env = 'line 2 : invalid attribution (int vs void)',
}

Test { [[
event void a;
pause/if a do
end
escape 0;
]],
    --env = 'line 2 : event type must be numeric',
    env = 'line 2 : arity mismatch',
    --env = 'line 2 : invalid attribution',
    --env = 'line 2 : invalid attribution (bool vs void)',
}

Test { [[
input int A, B;
event bool a;
par/or do
    loop do
        var int v = await A;
        emit a => v;
    end
with
    pause/if a do
        var int v = await B;
        escape v;
    end
end
]],
    _ana = {
        unreachs = 1,
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
        emit a => v;
    end
with

    pause/if a do
        pause/if a do
            ret = await B;
        end
    end
end
escape ret;
]],
    run = {
        ['1~>B;1~>B'] = 1,
        ['0~>A ; 1~>B'] = 1,
        ['1~>A ; 1~>B ; 0~>A ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 0~>A ; 1~>A ; 2~>B ; 0~>A ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 0~>A ; 1~>A ; 0~>A ; 0~>A ; 3~>B'] = 3,
        ['1~>A ; 1~>B ; 1~>A ; 2~>B ; 0~>A ; 0~>A ; 3~>B'] = 3,
    },
}

Test { [[
input int A, B, Z;
event bool a, b;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a => v;
    end
with
    loop do
        var int v = await B;
        emit b => v;
    end
with
    pause/if a do
        pause/if b do
            ret = await Z;
        end
    end
end
escape ret;
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
        emit a => v;
    end
with
    pause/if a do
        await Z;
        ret = await B;
    end
end
escape ret;
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
event bool a;
var int ret = 0;
par/or do
    emit a => 1;
    await A;
with
    pause/if a do
        finalize with
            ret = 10;
    end
        await Z;
    end
end
escape ret;
]],
    _ana = {
        acc = 1,
    },
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
        emit a => v;
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
escape ret;
]],
    _ana = {
        acc = 1,     -- TODO: 0
    },
    run = {
        ['1~>A ; ~>5s ; 0~>A ; ~>5s'] = 10,
    },
}

Test { [[
input int  A,B,F;
input void Z;
event bool a;
var int ret = 50;
par/or do
    loop do
        var int v = await A;
        emit a => v;
    end
with
    pause/if a do
        ret = await B;
    end
with
    await F;
end
escape ret;
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
var int v = await 1us;
escape v;
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
        emit a => v;
    end
with
    pause/if a do
        ret = await 9us;
    end
end
escape ret;
]],
    run = {
        ['~>1us;0~>A;~>1us;0~>A;~>19us'] = 12,
        --['~>1us;1~>A;~>1s;0~>A;~>19us'] = 11,
        --['~>1us;1~>A;~>5us;0~>A;~>5us;1~>A;~>5us;0~>A;~>9us'] = 6,
    },
}

Test { [[
event bool in_tm;
pause/if in_tm do
    async do
        loop i in 5 do
        end
    end
end
escape 1;
]],
    run = 1,
}

-- TIGHT LOOPS

Test { [[
loop i in 10 do
    i = 0;
end
]],
    env = 'line 2 : read-only variable',
}

Test { [[
loop do end
]],
    tight = 'line 1 : tight loop',
}
Test { [[
loop i do end
]],
    tight = 'line 1 : tight loop',
}
Test { [[
loop i in 10 do end
escape 2;
]],
    run = 2,
}
Test { [[
var int v=1;
loop i in v do end
]],
    tight = 'line 2 : tight loop',
}

-- INFINITE EXECUTION
Test { [[
event void e, f;
par do
    loop do
        par/or do
            emit f;         // 18
        with
            await f;        // 20
        end
        await e;            // 23
    end
with
    loop do
        par/or do
            await f;        // 8
        with
            emit e;         // 11
            await FOREVER;
        end
    end
end
]],
    _ana = {
        isForever = true,
        acc = 3,
    },
    awaits = 0,
    run = 0,
}

Test { [[
event void e, f;
par do
    loop do
        par/or do
            await f;        // 8
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
        await e;            // 23
    end
end
]],
    _ana = {
        isForever = true,
        acc = 3,
    },
    awaits = 0,
    run = 0,
}

Test { [[
event void e, f;
par do
    loop do
        par/or do
            emit e;     // 8
            await FOREVER;
        with
            await f;
        end
    end
with
    loop do
        await e;        // 17
        par/or do
            emit f;     // 20
        with
            await f;    // 22
        end
    end
end
]],
    _ana = {
        isForever = true,
        acc = 2,
    },
    awaits = 0,
    run = 0
}

Test { [[
event void e, k1, k2;
par do
    loop do
        par/or do
            emit e;
            await FOREVER;
        with
            await k1;
        end
        emit k2;
    end
with
    loop do
        await e;
        par/or do
            emit k1;
        with
            await k2;
        end
    end
end
]],
    _ana = {
        isForever = true,
        acc = 1,
    },
    awaits = 1,
    run = 0,
}
Test { [[
event void e, f;
par do
    loop do
        par/or do
            await f;        // 8
        with
            emit e;         // 11
            await FOREVER;
        end
    end
with
    loop do
        par/or do
            await f;        // 20
        with
            emit f;         // 18
        end
        await e;            // 23
    end
end
]],
    _ana = {
        isForever = true,
        acc = 3,
    },
    awaits = 0,
    run = 0,
}

Test { [[
event void e, f;
par do
    loop do
        par/or do
            await f;        // 20
        with
            emit f;         // 18
        end
        await e;            // 23
    end
with
    loop do
        par/or do
            await f;        // 8
        with
            emit e;         // 11
            await FOREVER;
        end
    end
end
]],
    _ana = {
        isForever = true,
        acc = 3,
    },
    awaits = 0,
    run = 0,
}

Test { [[
event void e, f;
par do
    loop do
        await e;        // 17
        par/or do
            await f;    // 22
        with
            emit f;     // 20
        end
    end
with
    loop do
        par/or do
            await f;
        with
            emit e;     // 8
            await FOREVER;
        end
    end
end
]],
    _ana = {
        isForever = true,
        acc = 2,
    },
    awaits = 0,
    run = 0
}

Test { [[
event void e, k1, k2;
par do
    loop do
        await e;
        par/or do
            await k2;
        with
            emit k1;
            await FOREVER;
        end
    end
with
    loop do
        par/or do
            await k1;
        with
            emit e;
            await FOREVER;
        end
        emit k2;
    end
end
]],
    _ana = {
        isForever = true,
        acc = 1,
    },
    awaits = 1,
    run = 0,
}
Test { [[
event void e;
loop do
    par/or do
        await e;
    with
        emit e;
        await FOREVER;
    end
end
]],
    _ana = {
        isForever = true,
        acc = true,
    },
    awaits = 1,
    run = 0,
}
Test { [[
event void e;
loop do
    par/or do
        await e;
        await e;
    with
        emit e;
        emit e;
        await FOREVER;
    end
end
]],
    _ana = {
        isForever = true,
        acc = true,
    },
    awaits = 1,
    run = 0,
}
Test { [[
event void e;
loop do
    watching e do
        emit e;
        await FOREVER;
    end
end
]],
    _ana = {
        isForever = true,
        acc = true,
    },
    awaits = 1,
    run = 0,
}
Test { [[
var int ret = 0;
event void e;
par/or do
    loop do
        await e;
        ret = ret + 1;
    end
with
    every e do
        ret = ret + 1;
    end
with
    emit e;
    emit e;
    emit e;
end
escape ret;
]],
    _ana = { acc=true },
    run = 3;
}

-- CLASSES, ORGS, ORGANISMS

Test { [[
class A with
do
    escape 1;
end
escape 1;
]],
    --adj = 'line 3 : invalid `escape´',
    run = 1,
}

Test { [[
class T with
    var int x;
do
    var int v;
end

native do
    int V = sizeof(CEU_T);
end

native _V;
var T t;
escape _V;
]],
    todo = 'recalculate',
    run = 8,    -- 2/2 (trl0) 0 (x) 4 (y)
}

Test { [[
class T with do end
escape 1;
]],
    run = 1,
}

Test { [[
class T with
    var int x;
do
    var int v;
end

native do
    int V = sizeof(CEU_T);
end
native _V;
escape _V;
]],
    todo = 'recalculate',
    run = 8,
}

Test { [[
class T with
    var int a;
do
end

var _TCEU_T t;
t.a = 1;
escape t.a;
]],
    gcc = 'error: unknown type name ‘TCEU_T’',
    --run = 1,
}

Test { [[
interface I with end

class T with
    var int x;
do
    var int v;
end

native do
    int V = sizeof(CEU_T);
end
native _V;
escape _V;
]],
    todo = 'recalculate',
    run = 8,   -- 1/1 cls / 2 trl / 0 x / 4 v
}

Test { [[
class T with
    var int a, b;
do
end

var T y;

var T x;
    x.a = 10;

input void OS_START;
await OS_START;

escape x.a;
]],
    run = 10,
}

Test { [[
input _SDL_MouseButtonEvent* SDL_MOUSEBUTTONUP;
class UITexture with
    var int pad_y = 0;
do
    var _SDL_MouseButtonEvent* but = await SDL_MOUSEBUTTONUP;
end
await FOREVER;
]],
    --run = 1,
    _ana = {
        isForever = true,
    },
}

Test { [[
class T with
    var int a;
do
end
var T x;
    x.a = 30;

escape x.a;
]],
    run = 30,
}
Test { [[
class T with
    var int a, b;
do
end

var T[2] y;
    y[0].a = 10;
    y[1].a = 20;

var T x;
    x.a = 30;

escape x.a + y[0].a + y[1].a;
]],
    run = 60,
}

Test { [[
class T with
    var int a, b;
do
end

var int i = 0;

var T[2] y with
    i = i + 1;
    this.a = i*10;
end;

var T x;
    x.a = 30;

escape x.a + y[0].a + y[1].a;
]],
    run = 60,
}

Test { [[
native do
    int V = 0;
end
class T with
do
    _V = _V + 1;
end

var T[20000] ts;

escape _V;
]],
    run = 20000,
}

Test { [[
class T with
    var int v;
do
end
escape 0;
]],
    run = 0,
}

Test { [[
class T with
do
    class T1 with var int v; do end
    var int v;
end
escape 0;
]],
    run = 0, -- TODO
    --props = 'line 2 : must be in top-level',
}

Test { [[
class T with
do
    class T1 with do var int v; end
    var int v;
end
escape 0;
]],
    run = 0, -- TODO
    --props = 'line 2 : must be in top-level',
}

Test { [[
class T with
do
end
var T[5] a;
escape 0;
]],
    run = 0,
}

Test { [[
class T with
do
end
event T a;
escape 0;
]],
    env = 'line 4 : invalid event type',
}

Test { [[
class T with
do
end
var T a = 1;
escape 0;
]],
    env = 'line 4 : types mismatch',
}

Test { [[
class T with
do
    var int a;
    var T b;
end
var T aa;
escape 0;
]],
    env = 'line 4 : undeclared type `T´',
}

Test { [[
class T with
do
end
var T a;
escape 0;
]],
    run = 0,
}

Test { [[
class T with
do
end
var T a;
a.v = 0;
escape a.v;
]],
    env = 'line 5 : variable/event "v" is not declared',
}

Test { [[
class T with
    var int a;
do
end
var T aa;
aa.b = 1;
escape 0;
]],
    env = 'line 6 : variable/event "b" is not declared',
}

Test { [[
class T with
do
    var int v;
end
var T a;
a.v = 5;
escape a.v;
]],
    env = 'line 6 : variable/event "v" is not declared',
}

Test { [[
class T with
    var int v;
do
end
var T a;
a.v = 5;
escape a.v;
]],
    run = 5,
}

Test { [[
native do
    int V = 10;
end
class T with
do
    _V = 100;
end
var T a;
escape _V;
]],
    run = 100,
}

Test { [[
class T with
    var int a;
do
    this.a =
        do escape 1; end;
end
var T a;
escape a.a;
]],
    run = 1,
}

Test { [[
input void OS_START;
class T with
    var int v;
do
    await FOREVER;
end
var T a;
a.v = 5;
await OS_START;
escape a.v;
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
escape a.v;
]],
    env = 'line 9 : variable/event "a" is not declared',
}

Test { [[
class T with
    var int v;
    native _f();
do
end
escape 10;
]],
    parser = 'line 2 : after `;´ : expected declaration',
}

Test { [[
class T with
    var int v;
    native _t;
do
end
escape 10;
]],
    parser = 'line 2 : after `;´ : expected declaration',
}

Test { [[
native _V;
native do
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
escape _V;
]],
    run = 345;
}

Test { [[
native _V;
native do
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

input void OS_START;

var T t1;
_V = _V*3;
var T t2;
_V = _V*3;
var T t3;
_V = _V*3;
await OS_START;
escape _V;
]],
    run = 345;
}

Test { [[
native _V;
native do
    int V = 1;
end;
class T with
do
    event void e;
    emit e;
    _V = 10;
end

do
    var T t;
end
escape _V;
]],
    run = 10,
}

Test { [[
class J with
do
end

class T with
do
    var J j;
    await FOREVER;
end

input void OS_START;
event void a;

var T t1;
var T t2;
emit a;
await OS_START;
escape 1;
]],
    run = 1;
}

Test { [[
native do
    int V = 10;
end

class T with
    event void e;
do
    await 1s;
    emit e;
    _V = 1;
end

do
    var T t;
    await t.e;
end
await 1s;
escape _V;
]],
    run = { ['~>2s']=10 },
}
Test { [[
class T with
do
    native do
        int XXX = sizeof(CEU_T);
    end
end
escape _XXX > 0;
]],
    gcc = 'error: ‘CEU_T’ undeclared here (not in a function)',
}

Test { [[
class U with do end;
class T with
do
    native do
        int XXX = sizeof(CEU_U);
    end
end
escape _XXX > 0;
]],
    run = 1,
}

Test { [[
native _V;
native do
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
    await FOREVER;
end

input void OS_START;

var T t1;
_V = _V*3;
var T t2;
_V = _V*3;
var T t3;
_V = _V*3;
await OS_START;
escape _V;
]],
    run = 345;
}
Test { [[
var int a=8;
do
    var int a = 1;
    this.a = this.a + a + 5;
end
escape a;
]],
    wrn = true,
    --env = 'line 4 : invalid access',
    run = 14,
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
input void OS_START;
await OS_START;
escape t.a;
]],
    gcc = 'error: duplicate member ‘a’',
    wrn = true,
    --run = 14,
    run = 8,
    --env = 'line 5 : cannot hide at top-level block',
}

Test { [[
class T with
    var int a;
do
    this.a = 8;
    do
        var int a = 1;
        this.a = this.a + a + 5;
    end
end
var T t;
input void OS_START;
await OS_START;
escape t.a;
]],
    wrn = true,
    run = 14,
}

Test { [[
class T2 with
do
end
class T with
    var T2 x;
do
end
var T a;
escape 1;
]],
    props = 'line 5 : not permitted inside an interface',
}
Test { [[
class T2 with
do
end
class T with
    var T2* x;
do
    var T2 xx;
    this.x = &xx;
end
var T a;
escape 1;
]],
    run = 1,
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
escape a . v + a.x .v + a .v2 + a.x  .  t3 . v3;
]],
    props = 'line 6 : not permitted inside an interface',
}
Test { [[
class T3 with
    var int v3;
do
end
class T2 with
    var T3* t3;
    var int v;
do
    var T3 t33;
    this.t3 = &t33;
end
class T with
    var int v,v2;
    var T2* x;
do
    var T2 xx;
    x = &xx;
end
var T a;
a.v = 5;
a.x:v = 5;
a.v2 = 10;
a.x:t3:v3 = 15;
escape a . v + a.x :v + a .v2 + a.x  :  t3 : v3;
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
    parser = 'line 3 : after `;´ : expected declaration',
}

Test { [[
var int v;
class T with
    var int v=5;
do
end
var T t;
escape t.v;
]],
    run = 5,
}

Test { [[
var int v;
class T with
    var int v=5;
do
end
var T t with
    this.v = 10;
end;
escape t.v;
]],
    run = 10,
}

Test { [[
class Foo with
  event void bar;
do
  // nothing
end

class Baz with
  var Foo* qux;
do
  await (*qux).bar;
end

escape 1;
]],
    run = 1,
}

Test { [[
var int v;
class T with
    var int v=5;
do
    this.v = 100;
end
var T t with
    this.v = 10;
end;
escape t.v;
]],
    run = 100,
}

Test { [[

var int v;
class U with
    var int x = 10;
do
end

class T with
    var int v=5;
    var U u with
        this.x = 20;
    end;
do
    this.v = 100;
end
var T t with
    this.v = 10;
end;
escape t.v + t.u.x;
]],
    props = 'line 10 : not permitted inside an interface',
}

Test { [[

var int v;
class U with
    var int x = 10;
do
end

class T with
    var int v=5;
    var U* u;
do
    var U uu with
        this.x = 20;
    end;
    this.u = &uu;
    this.v = 100;
end
var T t with
    this.v = 10;
end;
escape t.v + t.u:x;
]],
    run = 120,
}

Test { [[
class T with
do
end

var T   t;
var T*  p  = &t;
var T** pp = &p;

escape (p==&t and pp==&p and *pp==&t);
]],
    run = 1,
}

Test { [[
var int* v;
do
    var int i = 1;
    v = &i;
end
escape *v;
]],
    --fin = 'line 4 : attribution requires `finalize´',
    fin = 'line 4 : attribution to pointer with greater scope',
}
Test { [[
var int& v;
do
    var int i = 1;
    v = i;
end
escape v;
]],
    ref = 'line 4 : attribution to reference with greater scope',
    --run = 1,
}

Test { [[
var int i = 0;
class T with
    var int& i;
do
    i = 10;
end
var T t;
escape i;
]],
    ref = 'line 7 : field "i" must be assigned',
    --ref = 'line 5 : invalid attribution (not a reference)',
    --run = 1,
}
Test { [[
var int i = 1;
class T with
    var int& i;
do
    var int v = 10;
    i = v;
end
var T t;
escape i;
]],
    ref = 'line 8 : field "i" must be assigned',
    --ref = 'line 5 : invalid attribution (not a reference)',
    --run = 1,
}
Test { [[
var int i = 1;
class T with
    var int& i;
do
    var int v = 10;
    i = v;
end
var T t;
escape t.i;
]],
    ref = 'line 8 : field "i" must be assigned',
    --ref = 'line 5 : invalid attribution (not a reference)',
    --run = 10,
}
Test { [[
var int i = 0;
class T with
    var int& i;
do
    i = 10;
end
spawn T;
escape i;
]],
    --ref = 'line 5 : invalid attribution (not a reference)',
    ref = 'line 7 : field "i" must be assigned',
    --run = 1,
}
Test { [[
class T with
do
end
spawn T;
escape 10;
]],
    --ref = 'line 7 : field "i" must be assigned',
    run = 10,
}
Test { [[
var int i = 0;
class T with
    var int& i;
do
    var int v = 10;
    i = v;
end
var T*? p = spawn T;
escape p:i;
]],
    ref = 'line 8 : field "i" must be assigned',
    --run = 10,
}
Test { [[
var int i = 0;
class T with
    var int& i;
do
    var int v = 10;
    i = v;
end
var T t with
    this.i = outer.i;
end;
escape i;
]],
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
    run = 10,
}
Test { [[
var int i = 1;
class T with
    var int& i;
    var int v = 10;
do
    v = i;
end
var T t with
    this.i = outer.i;
end;
escape i;
]],
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
    run = 1,
}
Test { [[
input void OS_START;
var int i = 1;
class T with
    var int& i;
    var int v = 10;
do
    await OS_START;
    v = i;
end
var T t with
    this.i = outer.i;
end;
i = 10;
await OS_START;
escape t.v;
]],
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
    run = 10,
}
Test { [[
var int i = 0;
class T with
    var int& i;
do
    var int v = 10;
    i = v;
end
spawn T with
    this.i = outer.i;
end;
escape i;
]],
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
    run = 10,
}

Test { [[
var int i = 1;
class T with
    var int&? i;
do
    var int v = 10;
    i = v;
end

var int ret = 0;

var T t1;
ret = ret + i;  // 1
spawn T;
ret = ret + i;  // 2

var T t2 with
    this.i = outer.i;
end;
ret = ret + i;  // 12

i = 0;
spawn T with
    this.i = i;
end;
ret = ret + i;  // 22

escape ret;
]],
    --ref = 'line 17 : cannot assign to reference bounded inside the class',
    --run = 22,
    asr = ':6] runtime error: invalid tag',
}
Test { [[
var int i = 1;
class T with
    var int&? i;
do
    var int v = 10;
    if i? then
        i = i + v;
    end
end

var int ret = 0;

var T t1;
ret = ret + i;  // 1    1
spawn T;
ret = ret + i;  // 1    2

var T t2 with
    this.i = outer.i;
end;
ret = ret + i;  // 11   13

i = 0;
spawn T with
    this.i = i;
end;
ret = ret + i;  // 10   23

escape ret;
]],
    --ref = 'line 17 : cannot assign to reference bounded inside the class',
    run = 23,
}
Test { [[
var int i = 1;
class T with
    var int&? i;
do
    if i? then
    end
end
var T t with
    this.i = outer.i;
end;
escape 1;
]],
    run = 1,
}
Test { [[
var int i = 1;
class T with
    var int&? i;
    var int  v = 0;
do
    if i? then
        v = 10;
    end
end

var int ret = 0;

var T t1;
ret = ret + i;  // 1
spawn T;
ret = ret + i;  // 2

var T t2 with
    this.i = outer.i;
end;
ret = ret + t2.v;  // 12

i = 0;
spawn T with
    this.i = i;
end;
ret = ret + t2.v;  // 22

escape ret;
]],
    run = 22,
}

Test { [[
var int i = 1;
var int& v = i;

class T with
    var int* p = null;
    var int& v = null;
do
end

var T t with
    this.p = v;
    this.v = v;
end;

escape *(t.p) + *(t.v);
]],
    env = 'line 6 : types mismatch (`int&´ <= `null*´)',
}

Test { [[
var int i = 1;
var int& v = i;

class T with
    var int* p = null;
    var int& v;
do
end

var T t with
    this.p = &v;
    this.v = v;
end;

escape *(t.p) + (t.v);
]],
    run = 2,
}

Test { [[
var int i = 1;
var int& v = i;

class T with
    var int* p = null;
    var int& v;
do
    await 1s;
    //v = 1;
    *p = 1;
end

var T t with
    this.p := &v;
    this.v = v;
end;

escape *(t.p) + (t.v);
]],
    fin = 'line 10 : unsafe access to pointer "p" across `await´',
}

Test { [[
class T with
    var _SDL_Rect* cell_rects = null;
do
    var _SDL_Rect* cell_rect = &this.cell_rects[1];
end
escape 1;
]],
    gcc = 'error: unknown type name ‘SDL_Rect’',
}

Test { [[
native do
    int  vs[] = { 1, 2 };
    int* BGS[] = { &vs[0], &vs[1] };
end
escape *_BGS[1];
]],
    run = 2,
}

Test { [[
native do
    typedef int* t;
end
var int v = 2;
var _t p = &v;
escape *p;
]],
    run = 2,
}

Test { [[
native @plain _t;
native do
    typedef int t;
end
var _t v = 2;
escape *v;
]],
    env = 'line 6 : invalid operand to unary "*"',
}

Test { [[
native @plain _rect;
native do
    typedef struct rect {
        int x, y;
    };
end
var _rect r;
escape *(r.x);
]],
    env = 'line 8 : invalid operand to unary "*"',
}

Test { [[
input void OS_START;
var int v;
class T with
    var int v;
do
    v = 5;
end
var T a;
await OS_START;
v = a.v;
a.v = 4;
escape a.v + v;
]],
    run = 9,
}

Test { [[
input void OS_START;
class T with
    var int v;
do
    this.v = 5;
end
do
    var T a;
    await OS_START;
    var int v = a.v;
    a.v = 4;
    escape a.v + v;
end
]],
    run = 9,
}

Test { [[
input void OS_START, A;
class T with
    var int v;
do
    await OS_START;
    this.v = 5;
end
do
    var T a;
        a.v = 0;
    await A;
    escape a.v;
end
]],
    run = { ['~>A']=5} ,
}

Test { [[
input void OS_START;
class T with
    event void go;
    var int v;
do
    await go;
    v = 5;
end
do
    var T a;
    await OS_START;
    par/and do
        emit a.go;      // 13
    with
        emit a.go;      // 15
    end
    var int v = a.v;
    a.v = 4;
    escape a.v + v;
end
]],
    _ana = {
        acc = 1,
    },
    run = 9,
}

Test { [[
input void OS_START;
class T with
    event int a, go, ok;
    var int aa;
do
    await go;
    emit a => 100;
    aa = 5;
    emit ok => 1;
end
var T aa;
    par/or do
        await OS_START;
        emit aa.go => 1;
    with
        await aa.ok;
    end
escape aa.aa;
]],
    run = 5,
}

Test { [[
input void OS_START;
class T with
    var int v;
do
    v = 5;
end
var T a;
    await OS_START;
var int v = a.v;
a.v = 4;
escape a.v + v;
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
    end
    ret = a;
end
escape ret;
]],
    env = 'line 7 : variable/event "a" is not declared',
    --props = 'line 5 : must be in top-level',
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
escape 0;
]],
    env = 'line 6 : variable/event "a" is not declared',
    --props = 'line 4 : must be in top-level',
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
escape a;
]],
    env = 'line 6 : variable/event "a" is not declared',
    --env = 'line 6 : variable/event "b" is not declared',
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
escape a+b;
]],
    env = 'line 7 : variable/event "a" is not declared',
    --props = 'line 5 : must be in top-level',
    --env = 'line 17 : class "T" is not declared',
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
escape a+b;
]],
    env = 'line 5 : variable/event "a" is not declared',
    --run = 4,
}

Test { [[
class Sm with
do
    var u8 id;
end

class Image_media with
    var Sm sm;
do
end

var Image_media img1;
var Image_media img2;

escape 1;
]],
    props = 'line 7 : not permitted inside an interface',
}
Test { [[
class Sm with
do
    var u8 id;
end

class Image_media with
    var Sm* sm;
do
    var Sm smm;
    this.sm = &smm;
end

var Image_media img1;
var Image_media img2;

escape 1;
]],
    run = 1;
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

escape img1.sm.id + img2.sm.id + img3.sm.id;
]],
    props = 'line 7 : not permitted inside an interface',
}
Test { [[
class Sm with
    var int id;
do
end

class Image_media with
    var Sm* sm;
do
    var Sm smm;
    this.sm = &smm;
end

var Image_media img1;
    img1.sm:id = 10;

var Image_media img2;
    img2.sm:id = 12;

var Image_media img3;
    img3.sm:id = 11;

escape img1.sm:id + img2.sm:id + img3.sm:id;
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

escape img1.sm.id + img2.sm.id + img3.sm.id;
]],
    _ana = {
        reachs = 1,
    },
    props = 'line 7 : not permitted inside an interface',
}
Test { [[
class Sm with
    var int id;
do
end

class Image_media with
    var Sm* sm;
do
    var Sm smm;
    this.sm = &smm;
    par do with with with with end
end

var Image_media img1;
    img1.sm:id = 10;

var Image_media img2;
    img2.sm:id = 12;

var Image_media img3;
    img3.sm:id = 11;

escape img1.sm:id + img2.sm:id + img3.sm:id;
]],
    _ana = {
        reachs = 1,
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
escape p:v;
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
escape t1.v+t2.v;
]],
    run = 3,
}

Test { [[
class T with
    var _char* ptr;
do
end

var _char* ptr=null;
var T t with
    this.ptr = ptr;
end;
escape 1;
]],
    --gcc = 'may be used uninitialized in this function',
    run = 1,
    --fin = 'line 8 : attribution to pointer with greater scope',
}
Test { [[
class T with
    var _char* ptr;
do
end

var T t with
    do
        var _char* ptr=null;
        this.ptr = ptr;
    end
end;
escape 1;
]],
    --fin = 'line 9 : attribution to pointer with greater scope',
    --fin = 'line 9 : attribution requires `finalize´',
    --fin = 'line 9 : attribution to pointer with greater scope',
    run = 1,
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
    _ana = {
        isForever = true,
    },
    loop = true,
}

Test { [[
input void OS_START;
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
await OS_START;
par/or do
    loop i in 3 do
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
escape v;
]],
    run = { ['~>A;~>A;~>A;~>F']=1 },
}

Test { [[
input void OS_START;
input void A,F;
var int v=0;
class T with
    event void e, ok;
do
    await A;
    emit e;
    emit ok;
end
var T a;
await OS_START;
par/or do
    loop i in 3 do
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
escape v;
]],
    run = { ['~>A;~>A;~>A;~>F']=1 },
}

Test { [[
input void OS_START;
input void A,F;
var int v=0;
class T with
    event void e;
do
    loop do
        await A;
        emit e;
    end
end
await OS_START;
var T a;
par/or do
    loop i in 3 do
        await a.e;
        v = v + 1;
    end
with
    await F;
end
escape v;
]],
    run = { ['~>A;~>A;~>A;~>F']=3 },
}

Test { [[
input void OS_START;
input void A,F;
var int v=0;
class T with
    event void e;
do
    loop do
        await A;
        emit e;
    end
end
var T a;
await OS_START;
loop i in 3 do
    await a.e;
    v = v + 1;
end
escape v;
]],
    run = { ['~>A;~>A;~>A']=3 },
}

Test { [[
input void OS_START;
class T with
    event void go, ok;
do
    await go;
    await 1s;
    emit ok;
end
var T aa;
par/and do
    await OS_START;
    emit aa.go;
with
    await aa.ok;
end
escape 10;
]],
    run = { ['~>1s']=10 },
}

Test { [[
input void OS_START;
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
    await OS_START;
with
    await aa.ok;
end
escape 10;
]],
    run = { ['~>1s']=10 },
}

Test { [[
input int F;
class T with
    var int v = await F;
do
end
escape 0;
]],
    props = 'line 3 : not permitted inside an interface',
}

Test { [[
input void OS_START;
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
    await OS_START;
with
    await aa.ok;
end
escape aa.v;
]],
    run = { ['10~>F']=10 },
}

Test { [[
class T with
    event void e;
do
end

input void F, OS_START;
var int ret = 0;

var T a, b;
par/and do
    await a.e;
    ret = 2;
with
    await OS_START;
    emit a.e;
end
escape ret;
]],
    run = 2,
}

Test { [[
class T with
    event void e;
do
end

input void F, OS_START;
var int ret = 0;

var T a, b;
par/or do
    par/and do
        await a.e;
        ret = 2;
    with
        await OS_START;
        emit b.e;
    end
with
    await F;
    ret = 1;
end
escape ret;
]],
    run = { ['~>F']=1 }
}

Test { [[
input void OS_START;
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
            await OS_START;
        with
            await aa.ok;
        end
    end
    ret = ret + 1;
with
    await F;
end
await F;
escape ret;
]],
    run = {
        --['~>F;~>5s;~>F'] = 10,
        ['~>1s;~>F;~>F;~>1s'] = 10,
        --['~>1s;~>F;~>1s;~>F'] = 10,
        --['~>1s;~>2s;~>F'] = 11,
    },
}

Test { [[
input void OS_START;
input void F;
class T1 with
do
end
class T with
do
    var T1 a;
    par/and do
        await FOREVER;
    with
        await FOREVER;
    end
end
var int ret = 10;
var T aa;
par/or do
    par/and do
        await OS_START;
    with
        await FOREVER;
    end
with
    await F;
end
escape ret;
]],
    ana = 'line 10 : trail should terminate',
    run = {
        ['~>F'] = 10,
    },
}
Test { [[
input void OS_START;
input void F;
class T1 with
do
end
class T with
do
    var T1 a;
    par/and do
        await FOREVER;
    with
        await FOREVER;
    end
end
var int ret = 10;
var T aa;
par/or do
    par/and do
        await OS_START;
    with
        await FOREVER;
    end
with
    await F;
end
escape ret;
]],
    wrn = true,
    run = {
        ['~>F'] = 10,
    },
}

Test { [[
input void OS_START;
input void F;
class T1 with
    event void ok;
do
    await 1s;
    emit ok;
    await FOREVER;
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
    await FOREVER;
end
var int ret = 10;
var T aa;
par/or do
    do
        par/and do
            await OS_START;
        with
            await aa.ok;
        end
    end
    ret = ret + 1;
with
    await F;
end
await F;
escape ret;
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
escape ret;
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
escape ret;
]],
    run = {
        ['~>F;~>1s;~>E'] = 5,
        ['~>E;~>1s;~>F'] = 5,
    },
}

Test { [[
input void OS_START;
input void F;
class T with
    event void ok;
do
    input void E;
    par/or do
        await 1s;
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
escape ret;
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
input void OS_START;
input void F;
native _V;
native do
    int V = 0;
end
class T1 with
    event void ok;
do
    await 1s;
    _V = _V + 2;
    emit ok;
    _V = _V + 1000;
end
class T with
    event void ok;
do
    do
        var T1 a;
        await a.ok;
        _V = _V * 2;
    end
    await 1s;
    _V = _V + 1;
end
do
    var T aa;
    await F;
    _V = _V * 2;
end
escape _V;
]],
    run = {
        ['~>F;~>5s;~>F'] = 0,
        ['~>1s;~>F;~>F;~>1s'] = 8,
        ['~>1s;~>F;~>1s;~>F'] = 8,
        ['~>1s;~>1s;~>F'] = 10,
    },
    --run = { ['~>1s']=0 },
}
Test { [[
input void OS_START;
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
escape ret;
]],
    run = {
        ['~>F;~>5s;~>F'] = 10,
        ['~>1s;~>F;~>F;~>1s'] = 10,
        ['~>1s;~>F;~>1s;~>F'] = 10,
        ['~>1s;~>1s;~>F'] = 11,
        ['~>1s;~>E;~>1s;~>F'] = 11,
    },
    --run = { ['~>1s']=0 },
}

Test { [[
input void OS_START;
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
        await OS_START;
    with
        await aa.ok;
    end
    ret = ret + 1;
with
    await F;
end
await F;
escape ret;
]],
    run = {
        ['~>1s;~>F'] = 11,
        ['~>F;~>1s;~>F'] = 10,
    },
}

Test { [[
input void OS_START;
input void F;
class T with
    event void ok;
do
    loop do
        await 1s;
        emit this.ok;       // 8
    end
end
var T aa;
var int ret = 0;
par/or do
    loop do
        par/and do
            await (0)ms;
        with
            await aa.ok;    // 18
        end
        ret = ret + 1;
    end
with
    await F;
end
escape ret;
]],
    _ana = {
        --acc = 1,  -- TODO
    },
    run = { ['~>5s;~>F'] = 5 },
}

Test { [[
input void A;
class T with
    var int v;
do
    await A;
    v = 1;
end
var T a;
await A;
a.v = 2;
escape a.v;
]],
    _ana = {
        --acc = 2,    -- TODO
    },
    run = { ['~>A']=2 },
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
        v = v + 1;      // 9
    end
end
var T aa;
par do
    await aa.ok;
with
    await A;
    if aa.v == 3 then   // 17
        escape aa.v;    // 18
    end
end
]],
    _ana = {
        --acc = 2,      -- TODO
        reachs = 1,
    },
}

Test { [[
input void OS_START;
input void A;
class T with
    event int a, ok;
    var int aa;
do
    par/or do
        await A;
        emit a => 10;
        this.aa = 5;
    with
        aa = await a;
        aa = 7;
    end
    emit ok => 1;
end
var T aa;
par/and do
    await OS_START;
with
    await aa.ok;
end
escape aa.aa;
]],
    run = { ['~>A']=7 },
}

Test { [[
input void OS_START;
input void A;
class T with
    event int a, ok;
    var int aa;
do
    par/or do
        await A;
        emit a => 10;
        this.aa = 5;
    with
        aa = await a;
        aa = 7;
    end
    emit ok => 1;
end
var T aa;
par/and do
    await OS_START;
with
    await aa.ok;
end
escape aa.aa;
]],
    run = { ['~>A']=7 },
    safety = 2,
    _ana = {
        acc = 2,
    },
}

Test { [[
input void OS_START;
class T with
    event int a;
    var int aa;
do
    par/and do
        emit this.a => 10; // 6
        aa = 5;
    with
        await a;        // 9
        aa = 7;
    end
end
var T aa;
await OS_START;
escape aa.aa;
]],
    _ana = {
        acc = 1,
    },
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
escape a;
]],
    wrn = true,
    run = { ['~>B;~>A']=2 },
}

Test { [[
class T with do end
var T a;
var T* p = a;
]],
    env = 'line 3 : types mismatch',
}

Test { [[
class T with do end;
do
    var int ret = 1;
    var T t;
    escape ret;
end
]],
    run = 1,
}

Test { [[
class T with do end;
do
    var T t;
    var int ret = 1;
    escape ret;
end
]],
    run = 1,
}

Test { [[
class T with do end;
do
    var int a = 1;
    var int* pa = &a;
    var T t;
    var int ret = *pa;
    escape ret;
end
]],
    run = 1,
}

Test { [[
native _c, _d;
native do
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
escape p:a + t.a + _c + _d;
]],
    run = 40,
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
escape x;
]],
    run = 9,
}

Test { [[
class T with
do
    var int a = 1;
end
var T[2] ts;
escape 1;
]],
    run = 1,
}
Test { [[
class T with
    var int a;
do
end
var T[2] ts;
par/and do
    ts[0].a = 10;   // 7
with
    ts[1].a = 20;   // 9
end
escape ts[0].a + ts[1].a;
]],
    _ana = {
        acc = 1,
    },
    run = 30,
}
Test { [[
class T with
    var int a;
do
end
var T t1, t2;
par/and do
    t1.a = 10;   // 7
with
    t2.a = 20;   // 9
end
escape t1.a + t2.a;
]],
    run = 30,
}
Test { [[
input void OS_START;
class T with
    var int a;
do
    await OS_START;
    a = 0;
end
var T[2] ts;
await OS_START;
par/and do
    ts[0].a = 10;   // 11
with
    ts[1].a = 20;   // 13
end
escape ts[0].a + ts[1].a;
]],
    _ana = {
        acc = 1,  -- TODO=5?
    },
    run = 30,
}
Test { [[
input void OS_START;
class T with
    var int a;
do
    await OS_START;
    this.a = 0;
end
var T[2] ts;
await OS_START;
par/and do
    ts[0].a = 10;
with
    ts[1].a = 20;
end
escape ts[0].a + ts[1].a;
]],
    _ana = {
        acc = 1,    -- TODO: 5?
    },
    run = 30,
}
Test { [[
input void OS_START;
class T with
    var int a;
do
    await OS_START;
    a = 0;
end
var T t1, t2;
await OS_START;
par/and do
    t1.a = 10;
with
    t2.a = 20;
end
escape t1.a + t2.a;
]],
    _ana = {
        --acc = 8,      -- TODO
    },
    run = 30,
}
Test { [[
input void OS_START;
class T with
    var int a;
do
    await OS_START;
    this.a = 0;
end
var T t1, t2;
await OS_START;
par/and do
    t1.a = 10;
with
    t2.a = 20;
end
escape t1.a + t2.a;
]],
    _ana = {
        --acc = 8,  -- TODO
    },
    run = 30,
}
Test { [[
input void OS_START;
native @nohold _f();
native do
    void f (void* t) {}
end
class T with
do
    await OS_START;
    _f(&this);       // 9
end
var T[2] ts;
await OS_START;
par/and do
    _f(&ts[0]);     // 14
with
    _f(&ts[1]);     // 16
end
escape 10;
]],
    _ana = {
        acc = 2,
        --acc = 6,    -- TODO: not checked
    },
    run = 10,
}
Test { [[
input void OS_START;
native @nohold _f();
native do
    void f (void* t) {}
end
class T with
do
    await OS_START;
    _f(&this);       // 9
end
var T t0,t1;
await OS_START;
par/and do
    _f(&t0);     // 14
with
    _f(&t1);     // 16
end
escape 10;
]],
    _ana = {
        acc = 1,
        --acc = 9,  -- TODO
    },
    run = 10,
}

Test { [[
native do ##include <assert.h> end
native _assert();
input int  BUTTON;
input void F;

class Rect with
    var s16 x;
    var s16 y;
    event void go;
do
    loop do
        par/or do
            loop do
                await 10ms;
                x = x + 1;
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
        emit BUTTON => 0;
        emit 100ms;
    end
    _assert(rs[0].x==20 and rs[0].y==60 and rs[1].x==120 and rs[1].y==300);

    async do
        emit BUTTON => 1;
        emit 100ms;
    end
    _assert(rs[0].x==20 and rs[0].y==70 and rs[1].x==120 and rs[1].y==310);

    async do
        emit BUTTON => 1;
        emit 100ms;
    end
    _assert(rs[0].x==20 and rs[0].y==80 and rs[1].x==110 and rs[1].y==310);

    async do
        emit BUTTON => 1;
        emit 99ms;
    end
    _assert(rs[0].x==20 and rs[0].y==89 and rs[1].x==110 and rs[1].y==301);

    async do
        emit BUTTON => 0;
        emit 1ms;
    end
    _assert(rs[0].x==20 and rs[0].y==89 and rs[1].x==110 and rs[1].y==300);

    async do
        emit 18ms;
    end
    _assert(rs[0].x==19 and rs[0].y==89 and rs[1].x==110 and rs[1].y==299);

    async do
        emit BUTTON => 0;
        emit BUTTON => 1;
        emit 1s;
    end
    _assert(rs[0].x==19 and rs[0].y==-11 and rs[1].x==210 and rs[1].y==299);

end
escape 100;
]],
    awaits = 0,
    run = 100,
}

Test { [[
class T with
    event int a, go, ok;
    var int aa;
do
    par/or do
        emit a => 10;      // 5
        aa = 5;
    with
        await this.a;   // 8
        aa = 7;
    end
end
var T aa;
par/or do
    par/and do
        emit aa.go => 1;
    with
        await aa.ok;
    end
with
    input void OS_START;
    await OS_START;
end
escape aa.aa;
]],
    _ana = {
        acc = 1,
    },
    run = 5,
}

Test { [[
class T with
    event int a, ok, go;
    var int aa;
do
    emit a => 10;
    aa = 5;
end
var T aa;
par/or do
    par/and do
        emit aa.go => 1;
    with
        await aa.ok;
    end
with
    input void OS_START;
    await OS_START;
end
escape aa.aa;
]],
    run = 5,
}

Test { [[
input void OS_START;

native _inc(), _V;
native do
    int V = 0;
    void inc() { V++; }
end

_inc();
event void x;
emit x;
await OS_START;
escape _V;
]],
    run = 1,
}

Test { [[
    input void OS_START;
class T with
    event void a, ok, go, b;
    var int aa, bb;
do

    par/and do
        await a;
        emit b;
    with
        await b;
    end
    aa = 5;
    bb = 4;
    emit ok;
end
var T aa;

native _inc(), _V;
native do
    int V = 0;
    void inc() { V++; }
end

_inc();
par/or do
    await aa.ok;
    _V = _V+1;
with
    await OS_START;
    emit aa.a;
    _V = _V+2;
end
escape _V + aa.aa + aa.bb;
]],
    run = 11,
}

Test { [[
    input void OS_START;
class T with
    event void a, ok, go, b;
    var int aa, bb;
do

    par/and do
        await a;
        emit b;
    with
        await b;
    end
    aa = 5;
    bb = 4;
    emit ok;
end
var T aa;

native _inc(), _V;
native do
    int V = 0;
    void inc() { V++; }
end

_inc();
par/or do
    await aa.ok;
    _V = _V+1;
with
    await OS_START;
    emit aa.a;
    _V = _V+2;
end
escape _V + aa.aa + aa.bb;
]],
    run = 11,
    safety = 2,
    _ana = {
        acc = 3,
    },
}

Test { [[
    input void OS_START;
class T with
    event void a, ok, go, b;
    var int aa, bb;
do

    par/and do
        await a;
        emit b;
    with
        await b;
    end
    aa = 5;
    bb = 4;
    emit ok;
end
var T aa;

var int ret;
par/or do
    await aa.ok;
    ret = 1;
with
    await OS_START;
    emit aa.a;
    ret = 2;
end
escape ret + aa.aa + aa.bb;
]],
    run = 10,
}

Test { [[
input void OS_START;
class T with
    event void e, ok, go;
    var int ee;
do
    await this.go;
    if ee == 1 then
        emit this.e;
    end
    await (0)ms;
    emit ok;
end
var T a1, a2;
var int ret = 0;
await OS_START;

par/or do
    par/and do
        a1.ee = 1;
        emit a1.go;
        await a1.ok;
        ret = 1;        // 20
    with
        a2.ee = 2;
        emit a2.go;
        await a2.ok;
        ret = 1;        // 25
    end
with
    await a2.e;
    ret = 100;
end
escape ret;
]],
    _ana = {
        --acc = 1,
    },
    run = { ['~>1s']=1 },
}
Test { [[
native @nohold _f();
input void OS_START;
class T with
    event void e, ok, go, b;
    var u8 a;
do
    await go;
    a = 1;
    emit ok;
end
var T a, b;
native do
    int f (char* a, char* b) {
        return *a + *b;
    }
end
par/and do
    await OS_START;
    emit a.go;
with
    await a.ok;
with
    await OS_START;
    emit b.go;
with
    await b.ok;
end
escape _f((char*)&a.a,(char*)&b.a);
]],
    run = 2,
}

Test { [[
input void OS_START, B;
class T with
    var int v;
    event void ok, go, b;
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
        await OS_START;
        emit ts[0].go;
    with
        await ts[0].ok;
    end
    ret = ret + 1;
with
    par/and do
        await OS_START;
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
    ret = ret + 1;              // 42
with
    await ts[1].f;
    ret = ret + 1;              // 45
end
escape ret + ts[0].v + ts[1].v;
]],
    _ana = {
        --acc = 47,     -- TODO: not checked
        acc = 8,
    },
    run = { ['~>B']=206, }
}

Test { [[
input int S;
input void F;
class T with
    event void a,ok;
    var int aa;
do
    par/or do
        aa = await S;
        emit this.a;
    with
        await 10s;
        await a;
        aa = 7;
    end
    emit ok;
end
var T aa;
await aa.ok;
await F;
escape aa.aa;
]],
    run = {
        ['11~>S;~>10s;~>F'] = 11,
        ['~>10s;11~>S;~>F'] = 7,
    },
}

Test { [[
input void OS_START;
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
    await OS_START;
    emit ts[0].e;
    ret = ret + 1;
with
    await ts[0].f;
    ret = ret + 1;
with
    await OS_START;
    emit ts[1].e;
    ret = ret + 1;
with
    await ts[1].f;
    ret = ret + 1;
end
escape ret + ts[0].v + ts[1].v;
]],
    _ana = {
        acc = 4,
        --acc = 13,     -- TODO: not checked
    },
    run = { ['~>1s']=205, }
}

Test { [[
input void OS_START;
class T with
    var int v;
do
    v = 1;
end
var T a, b;
await OS_START;
escape a.v + b.v;
]],
    run = 2,
}

Test { [[
input void OS_START;
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
await OS_START;
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
escape ret;
]],
    run = {
        ['~>F;~>5s;~>F'] = 10,
        ['~>1s;~>F;~>F;~>1s'] = 10,
        ['~>1s;~>F;~>1s;~>F'] = 10,
        ['~>1s;~>1s;~>F'] = 11,
    },
}

-- TODO: STACK
Test { [[
native _V;
native do
    int V=1;
end

class T with
    event void a;
do
    loop do
        await a;
        _V = _V + 1;
    end
end

var T t;
emit t.a;
emit t.a;
emit t.a;
escape _V;
]],
    --run = 4,
    run = 1,
}

Test { [[
native _V;
native do
    static int V = 0;
end
do
    do
        do
            finalize with
                _V = 100;
            end
        end
    end
end
escape _V;
]],
    run = 100;
}

Test { [[
native _V;
native do
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
    input void OS_START;
    await OS_START;
end
escape _V;
]],
    run = 100,
}

Test { [[
native _V;
native do
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
escape _V;
]],
    run = 110,      -- TODO: stack change
}

Test { [[
native _V;
native do
    static int V = 0;
end
input void OS_START;
class T with
    // nothing
do
    do
        finalize with
            _V = 100;
        end
        await OS_START;
    end
end
par/or do
    var T t;
    await OS_START;
with
    await OS_START;
end
escape _V;
]],
    _ana = {
        abrt = 1,
    },
    run = 100,
}

Test { [[
native _V;
input void A, F, OS_START;
native do
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
await OS_START;
par/or do
    do                  // 22
        finalize with
            _V = _V*10;
        end
        await t.ok;
    end
with
    await t.e;          // 29
    t.v = t.v * 3;
with
    await F;
    t.v = t.v * 5;
end
escape t.v + _V;        // * reads before
]],
    _ana = {
        abrt = 1,        -- false positive
    },
    run = {
        ['~>F'] = 5,
        ['~>A'] = 12,
    }
}

Test { [[
class U with
    event void ok;
do
    finalize with
        _V = _V + 4;
    end
    await 1ms;
    emit this.ok;
    await FOREVER;
end;
class T with do
    finalize with
        _V = _V + 2;
    end
    var U u;
    await FOREVER;
end;
native do
    int V = 1;
end
finalize with
    _V = 1000;
end
finalize with
    _V = 1000;
end
finalize with
    _V = 1000;
end
par/or do
    await 1s;
with
    do
        var T t;
        var U u;
        par/or do
            await u.ok;
        with
            await u.ok;
        end;
    end
    var T t1;
    var U u1;
    await u1.ok;
    _assert(_V == 11);
end
_assert(_V == 21);
escape _V;
]],
    run = { ['~>1s']=21 },
}
-- XXXX

-- internal binding binding
Test { [[
class T with
    var int& i;
do
    var int v = 10;
    i = v;
end
var T t;
escape t.i;
]],
    ref = 'line 7 : field "i" must be assigned',
    --run = 10,
}

-- internal/constr binding
Test { [[
class T with
    var int& i;
do
    var int v = 10;
    i = v;
end
var int v = 0;
var T t with
    this.i = v;
end;
escape v;
]],
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
    run = 10;
}
-- internal binding
Test { [[
class T with
    var int& i;
do
    var int v = 10;
    i = v;
end
var T t;
escape t.i;
]],
    ref = 'line 7 : field "i" must be assigned',
    --run = 10,
}
-- internal binding w/ default
Test { [[
class T with
    var int&? i;
do
    var int v = 10;
    i = v;
end
var T t;
escape t.i;
]],
    asr = '5] runtime error: invalid tag',
    --run = 10,
}
-- internal binding w/ default
Test { [[
class T with
    var int&? i;
do
    _assert(not i?);
    var int v = 10;
    i = v;
end
var T t;
escape t.i;
]],
    asr = '6] runtime error: invalid tag',
    --run = 10,
}
-- external binding w/ default
Test { [[
class T with
    var int&? i;
do
    _assert(i?);
end
var int i = 10;
var T t with
    this.i = outer.i;
end;
escape t.i;
]],
    run = 10,
}
Test { [[
class T with
    var int&? i;
do
    _assert(not i?);
end
var int i = 10;
var T t;
escape not t.i?;
]],
    run = 1,
}

-- no binding
Test { [[
class T with
    var int& i;
do
end
var T t;
escape 1;
]],
    ref = 'line 5 : field "i" must be assigned',
}

Test { [[
class T with
    var int& i;
do
end

var int i = 1;

var T t1;

var T t2 with
    this.i = outer.i;
end;

escape t1.i;
]],
    ref = 'line 8 : field "i" must be assigned',
}

Test { [[
class T with
    var int& i;
do
end

var int i = 1;

var T t2 with
    this.i = outer.i;
end;

var T t1;

escape t1.i;
]],
    ref = 'line 12 : field "i" must be assigned',
}

Test { [[
class T with
    var int& i;
do
    var int v = 10;
    i = v;
end
var T t;
var int v = 0;
t.i = v;
escape 1;
]],
    ref = 'line 7 : field "i" must be assigned',
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
}

Test { [[
class Integral with
    var   int& v;
    event int  e;
do
    every dv in e do
        v = v + dv;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
interface Global with
    var int& v;
end
var int  um = 1;
var int& v;// = um;
escape 1;//global:v;
]],
    ref = 'line 5 : global references must be bounded on declaration',
}

Test { [[
interface Global with
    var int& v;
end
var int  um = 1;
var int& v = um;
escape 1;//global:v;
]],
    run = 1,
}

Test { [[
interface Global with
    var int& v;
end
var int  um = 1;
var int& v = um;
escape global:v;
]],
    run = 1,
}

Test { [[
interface Global with
    var int& v;
end

class T with
    var int v;
do
    this.v = global:v;
end

var int  um = 111;
var int& v = um;
var T t;
escape t.v;
]],
    run = 111,
}

Test { [[
interface Global with
end
var int&? win;
escape 1;
]],
    run = 1,
}

Test { [[
class T with
    var int v = 10;
do
end

interface Global with
    var T& t;
end

var T t_;
var T& t = t_;
global:t = t;

escape global:t.v;
]],
    run = 10,
}

Test { [[
class T with
    event void e;
do
end
var T t;

class U with
    var T& t;
do
    emit t.e;
end

var U u with
    this.t = t;
end;

escape 1;
]],
    run = 1,
}

Test { [[
class T with
    var int x;
do
end
var T t;

class U with
    var T& t;
do
    t.x = 1;
end

class V with
    var U& u;
do
    u.t.x = 2;
end

var U u with
    this.t = t;
end;

var V v with
    this.u = u;
end;

escape t.x + u.t.x + v.u.t.x;
]],
    run = 6,
}

Test { [[
class T with
    var int x;
do
end
var T t;

class U with
    var T& t;
do
    t.x = 1;
end

class V with
    var U& u;
do
    var U* p = &u;
    p:t.x = 2;
end

var U u with
    this.t = t;
end;

var V v with
    this.u = u;
end;

escape t.x + u.t.x + v.u.t.x;
]],
    run = 6,
}

Test { [[
class Ship with
    var int& v;
do
end

loop do
    var int x = 10;
    var Ship ship1 with
        this.v = x;
    end;
    escape 1;
end
]],
    wrn = true,
    run = 1,
}

Test { [[
class T with
    var int& v;
do
end
var T t with
    var int x;
    this.v = x;
end;
escape 1;
]],
    ref = 'line 7 : attribution to reference with greater scope',
}

Test { [[
class T with
    var int& v;
do
end
var int x = 10;
var T t with
    this.v = x;
end;
x = 11;
escape t.v;
]],
    run = 11;
}

Test { [[
data V with
    var int v;
end

class T with
    var V& v;
do
end

var T t1 with
    var V v_ = V(1);
    this.v = v_;
end;
var T t2 with
    var V v_ = V(2);
    this.v = v_;
end;
var T t3 with
    var V v_ = V(3);
    this.v = v_;
end;

escape t1.v.v + t2.v.v + t3.v.v;
]],
    ref = 'line 12 : attribution to reference with greater scope',
    --run = 6,
}

Test { [[
class T with
    var int& v;
do
end
var int x = 10;
var T t with
    this.v = x;
end;
var int y = 15;
t.v = y;
y = 100;
escape t.v;
]],
    run = 100,
}

-- KILL THEMSELVES

Test { [[
native do ##include <assert.h> end
input void OS_START;

interface Global with
    event void e;
end

event void e;

class T with
do
    await OS_START;
    emit global:e; // TODO: must also check if org trail is active
    native _assert();
    _assert(0);
end

do
    var T t;
    await e;
end
escape 2;
]],
    run = 2,
}
Test { [[
input void OS_START;

native _V, _assert();
native do
    ##include <assert.h>
    int V = 0;
end

interface Global with
    event void e;
end

event void e;

class T with
do
    await OS_START;
    emit global:e; // TODO: must also check if org trail is active
    _V = 1;
    _assert(0);
end

par/or do
    await global:e;
    _V = 2;
with
    var T t;
    await FOREVER;
end

escape _V;
]],
    run = 2,
}

Test { [[
input void OS_START;

native _V, _assert();
native do
    ##include <assert.h>
    int V = 0;
end

interface Global with
    event void e;
end

class T with
do
    emit global:e; // TODO: must also check if org trail is active
    _V = 1;
    _assert(0);
end

event void e;

par/or do
    await global:e;
    _V = 2;
with
    await OS_START;
    do
        var T t;
        await FOREVER;
    end
end
escape _V;
]],
    run = 2;
}

Test { [[
input void OS_START;

native _V, _assert();
native do
    ##include <assert.h>
    int V = 0;
end

interface Global with
    event void e;
end

class T with
do
    emit global:e; // TODO: must also check if org trail is active
    _assert(0);
    _V = 1;
    _assert(0);
end

event void e;

par/or do
    await global:e;
    _V = 2;
with
    await OS_START;
    do
        var T t;
        _assert(0);
        await FOREVER;
    end
end
escape _V;
]],
    run = 2;
}

Test { [[
input void OS_START;

native _X,_V, _assert();
native do
    ##include <assert.h>
    int V = 0;
    int X = 0;
end

interface Global with
    event void e;
end

class T with
do
    _assert(_X==0); // second T does not execute
    _X = _X + 1;
    emit global:e;
    _assert(0);
    _V = 1;
    _assert(0);
end

event void e;

par/or do
    await global:e;
    _V = 2;
with
    await OS_START;
    do
        var T[2] t;
        _assert(0);
        await FOREVER;
    end
end
escape _V+_X;
]],
    run = 3;
}

Test { [[
input void OS_START;

native _V, _assert();
native do
    ##include <assert.h>
    int V = 0;
end

class T with
    var int x;
    event void ok;
do
    await OS_START;
    emit  ok;
    _assert(0);
end

var int ret=1;
do
    var T t with
        this.x = 10;
    end;

    await t.ok;
    ret = t.x;
end
escape ret;
]],
    run = 10;
}

Test { [[
input void OS_START;

native _V, _assert();
native do
    ##include <assert.h>
    int V = 0;
end

class T with
    var int x;
    event void ok;
do
    await OS_START;
    emit  ok;
    _assert(0);
end

class U with
    var int x;
    event void ok;
do
    await OS_START;
    _assert(0);
    emit  ok;
end

var int ret=0;
do
    var T t with
        this.x = 10;
    end;
    var T u;
    await t.ok;
    ret = t.x;
end
escape ret;
]],
    run = 10;
}

Test { [[
class T with
    var int* a1;
do
    var int* a2=null;
    a1 = a2;
end
escape 10;
]],
    run = 10,
}

Test { [[
native @pure _UI_align();
class T with
    var _SDL_rect rect;
do
    do
        var _SDL_Rect r;
        r.x = _N;
    end
end
escape 1;
]],
    --fin = 'line 7 : attribution requires `finalize´',
    gcc = 'error: unknown type name ‘SDL_rect’',
}

Test { [[
native @pure _UI_align();
class T with
    var _SDL_rect rect;
do
    do
        var _SDL_Rect r;
        r.x = _UI_align(r.w, _UI_ALIGN_CENTER);
    end
end
escape 1;
]],
    --fin = 'line 7 : attribution requires `finalize´',
    gcc = 'error: unknown type name ‘SDL_rect’',
}

Test { [[
native @const _UI_ALIGN_CENTER;
native @pure _UI_align();
native do
    typedef struct {
        int x, w;
    } SDL_Rect;
    int UI_ALIGN_CENTER = 1;
    int UI_align (int a, int b) {
        return 0;
    }
end
class T with
    var _SDL_Rect rect;
do
    do
        var _SDL_Rect r;
        r.x = _UI_align(r.w, _UI_ALIGN_CENTER);
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
native @const _UI_ALIGN_CENTER;
native @pure _UI_align();
native do
    typedef struct {
        int x, w;
    } SDL_Rect;
    int UI_ALIGN_CENTER = 1;
    int UI_align (int a, int b, int c) {
        return 0;
    }
end
class T with
    var _SDL_Rect rect;
do
    do
        var _SDL_Rect r;
            r.w = 1;
        r.x = _UI_align(this.rect.w, r.w, _UI_ALIGN_CENTER);
    end
end
escape 1;
]],
    --fin = 'line 17 : attribution requires `finalize´',
    run = 1,
}

Test { [[
native @const _UI_ALIGN_CENTER;
native @pure _UI_align();
native do
    typedef struct {
        int x, w;
    } SDL_Rect;
    int UI_ALIGN_CENTER = 1;
    int UI_align (int a, int b, int c) {
        return 0;
    }
end
class T with
    var _SDL_Rect rect;
do
    do
        var _SDL_Rect r;
        r.x = (int) _UI_align(this.rect.w, r.w, _UI_ALIGN_CENTER);
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
#define N 5
native do
    int V = 0;
end
class T with
do
    _V = _V + 1;
end
var T[N] ts;
escape _V;
]],
    run = 5,
}

Test { [[
#define N 5
native do
    int V = 0;
end
class T with
do
    _V = _V + 1;
end
var T[N+1] ts;
escape _V;
]],
    run = 6,
}

Test { [[
#define N 5
native do
    int V = 0;
end
class T with
do
    _V = _V + 1;
end
var T[N+1] ts;
escape _V;
]],
    run = 6,
}

Test { [[
#define N 5
native do
    int V = 0;
end
class T with
do
    _V = _V + 1;
end
#error oi
var T[N+1] ts;
escape _V;
]],
    lines = 'error oi',
}

Test { [[
input void OS_START;

class T with
do
    await 1us;
end
pool T[] ts;

var T*? t1 = spawn T;
var T*? t2 = spawn T;
await *t2;
var T*? t3 = spawn T;
await *t3;

escape 1;
]],
    run = { ['~>2us']=1 },
}

Test { [[
input void OS_START;

class U with
do
    await 1us;
end

class T with
do
    do U;
end
pool T[] ts;

var T*? t1 = spawn T;
var T*? t2 = spawn T;
await *t2;
var T*? t3 = spawn T;
await *t3;

escape 1;
]],
    run = { ['~>2us']=1 },
}

-- CONSTRUCTOR

Test { [[
var int a with
    nothing;
end;
escape 0;
]],
    env = 'line 1 : invalid type',
}

Test { [[
class T with
    var int a;
    var int b;
do
    b = a * 2;
end

var T t1, t2 with
    this.a = 10;
end;

escape t1.b;
]],
    parser = 'line 8 : after `t2´ : expected `;´',
}

Test { [[
class T with
    var int a;
    var int b;
do
    b = a * 2;
end

var T[2] t with
    this.a = 10;
end;

escape t[0].b + t[1].b;
]],
    run = 40;
}

Test { [[
escape outer;
]],
    env = 'line 1 : types mismatch (`int´ <= `Main´)',
}

Test { [[
_f(outer);
]],
    props = 'line 1 : `outer´ can only be unsed inside constructors',
}

Test { [[
interface I with
end

class U with
    var I* i;
do
end

class T with
    var int ret = 0;
do
    var U u with
        this.i = &outer;
    end;
    this.ret = u.i == &this;
end

var T t;

escape t.ret;
]],
    run = 1,
}

Test { [[
class T with
    var int a;
    var int b;
do
    b = a * 2;
end

var T t with
    await 1s;
end;

escape t.b;
]],
    props = 'line 9 : not permitted inside a constructor',
}

Test { [[
class T with
    var int a;
    var int b;
do
    b = a * 2;
end

var T t with
    this.a = 10;
end;

escape t.b;
]],
    run = 20,
}

Test { [[
class T with
    var int v;
do end;
var T _ with
    this.v = 1;
end;
escape 1;
]],
    run = 1,
}

Test { [[
native do
    void* PTR;
    void* myalloc (void) {
        return NULL;
    }
    void myfree (void* ptr) {
    }
end
native @nohold _myfree();

class T with
    var int x = 10;
do
    finalize
        _PTR = _myalloc();
    with
        _myfree(_PTR);
    end
end
var T t;
escape t.x;
]],
    fin = 'line 15 : cannot finalize a variable defined in another class',
}

Test { [[
native do
    int V;
    void* myalloc (void) {
        return &V;
    }
    void myfree (void* ptr) {
    }
end
native @nohold _myfree();

class T with
    var int x = 10;
do
    var void&? ptr;
    finalize
        ptr = _myalloc();
    with
        _myfree(&ptr);
    end
end
var T t;
escape t.x;
]],
    run = 10,
}

-- TODO: bounded loop on finally

    -- GLOBAL-DO-END

Test { [[
var int tot = 1;                // 1

global do
    tot = tot + 2;              // 3
end

tot = tot * 2;                  // 6

escape tot;
]],
    run = 6
}

Test { [[
var int tot = 1;                // 1

global do
    tot = tot + 2;              // 3
end

class T with
do
    global do
        tot = tot * 2;          // 6
        var int tot2 = 10;
    end
end

tot = tot + tot2;               // 16

global do
    tot = tot + tot2;           // 26
end

escape tot;
]],
    run = 26,
}

Test { [[
var int tot = 1;                // 1
var int tot2;

global do
    tot = tot + 2;              // 3
end

class T with
do
    global do
        tot = tot * 2;          // 6
        tot2 = 10;
    end
end

tot = tot + tot2;               // 16

global do
    tot = tot + tot2;           // 26
end

escape tot;
]],
    run = 26
}

Test { [[
var int tot = 1;                // 1
var int tot2 = 1;                       // 1

global do
    tot = tot + 2;              // 3
end

class T with
do
    class U with
    do
        global do
            tot = tot + 1;      // 4
            tot = tot + tot2;   // 5
        end
    end

    global do
        tot = tot * 2;          // 10
        tot2 = tot2+9;                  // 10
    end

    class V with
    do
        global do
            tot = tot + 5;      // 15
        end
    end
end

tot = tot + tot2;               // 25

global do
    tot = tot + tot2;           // 35
    tot2 = tot2 / 2;                    // 5
end

tot2 = tot2 - 4;                        // 1

escape tot + tot2;              // 36
]],
    run = 36
}


-- SPAWN

Test { [[
class T with do end
spawn T;
escape 1;
]],
    --env = 'line 2 : `spawn´ requires enclosing `do ... end´',
    run = 1,
}

Test { [[
native _V;
native do
    int V = 0;
end
class T with
do
    _V = 10;
end
do
    spawn U;
end
escape _V;
]],
    env = 'line 10 : undeclared type `U´',
}

Test { [[
native _V;
native do
    int V = 0;
end
class T with
do
    _V = 10;
end
do
    spawn T;
end
escape _V;
]],
    run = 10,
}

Test { [[
native _V;
native do
    int V = 0;
end
class T with
    var int a;
do
    _V = this.a;
end
do
    spawn T with
        this.a = 10;
    end;
end
escape _V;
]],
    run = 10,
}

Test { [[
class T with do end
do
    var u8? x = spawn T;
end
]],
    env = 'line 3 : types mismatch',
}

Test { [[
class T with do end
var T* ok = spawn T;
escape ok != null;
]],
    env = 'line 2 : must assign to option pointer',
    --run = 1,
}

Test { [[
class T with do end
function (void)=>void fff do
    spawn T;
end
escape 1;
]],
    props = 'line 3 : not permitted inside `function´',
}

Test { [[
class U with do end
class T with do end
var U*? ok = spawn T;
escape ok != null;
]],
    env = 'line 3 : types mismatch (`U*´ <= `T*´)',
    --run = 1,
}

Test { [[
class T with do end
pool T[0] ts;
var T*? ok = spawn T in ts;
if ok? then
    escape 0;
else
    escape 1;
end
]],
    run = 1,
}

Test { [[
class T with do end
var T*? ok = spawn T;
escape &ok != null;
]],
    asr = '3] runtime error: invalid tag',
    --run = 1,
}

Test { [[
class Body with do end;
var Body*? tail = spawn Body;
await *tail;
escape 1;
]],
    asr = '3] runtime error: invalid tag',
    run = 1,
}

Test { [[
class T with do end
var T*? ok;
var bool ok_;
do
    ok = spawn T;
    ok_ = (ok?);
end
escape ok_+1;
]],
    run = 1,
}

Test { [[
class T with do end
var T*? ok;
do
    ok = spawn T;
end
escape ok?+1;
]],
    --fin = 'line 6 : pointer access across `await´',
    run = 1,
}

Test { [[
class T with do
    await FOREVER;
end
var T*? ok;
native _assert();
do
    loop i in 5 do
        ok = spawn T;
    end
end
escape ok?+1;
]],
    --loop = 1,
    --fin = 'line 11 : pointer access across `await´',
    run = 2,
}
Test { [[
class T with do
    await FOREVER;
end
var T*? ok;
var bool ok_;
native _assert();
do
    loop i in 5 do
        ok = spawn T;
        ok_ = (ok?);
    end
end
escape ok_+1;
]],
    --loop = 1,
    run = 2,
}

Test { [[
class T with do
    await FOREVER;
end
var T*? ok;
var bool ok_;
native _assert();
do
    loop i in 100 do
        ok = spawn T;
    end
    var T*? ok1 = spawn T;
    ok_ = (ok1?);
end
escape ok_+1;
]],
    --loop = 1,
    run = 1,
}
Test { [[
class T with do
    await FOREVER;
end
var T*? ok;
native _assert();
do
    loop i in 100 do
        ok = spawn T;
    end
    ok = spawn T;
end
escape (ok?)+1;
]],
    --loop = 1,
    --fin = 'line 10 : pointer access across `await´',
    run = 1,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
end
var T*? t = spawn T;
escape t:a;
]],
    asr = '7] runtime error: invalid tag',
    --run = 1,
}

Test { [[
input void OS_START;
class T with
    var int a;
do
    this.a = 1;
end
var T*? t = spawn T;
await OS_START;
escape t:a;
]],
    fin = 'line 9 : unsafe access to pointer "t" across `await´',
}

Test { [[
class T with do end
do
    var T*? t;
    t = spawn T;
end
escape 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T*? t;
t = spawn T;
escape 10;
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
var T*? t;
    t = spawn T;
    t = spawn T;
    t = spawn T;
escape 10;
]],
    run = 10;
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
var T*? t;
do
    t = spawn T;
    t = spawn T;
    t = spawn T;
end
escape 10;
]],
    --fin = 'line 13 : invalid block for awoken pointer "t"',
    run = 10,
}

Test { [[
spawn i;
]],
    parser = 'line 1 : after `spawn´ : expected identifier',
}
Test { [[
_f(spawn T);
]],
    parser = 'line 1 : after `(´ : expected `)´',
}

Test { [[
class T with do end
var T*? a;
a = spawn U;
]],
    env = 'line 3 : undeclared type `U´',
}

Test { [[
class T with do end
do
    var T*? t;
    t = spawn T;
end
escape 10;
]],
    run = 10,
}

Test { [[
class T with
do
end

var T*? t = spawn T;
if not t? then
    escape 10;
end

escape 1;
]],
    run = 10,
}

Test { [[
class T with
do
    await FOREVER;
end

var T*? t = spawn T;
if not t? then
    escape 10;
end

escape 1;
]],
    run = 1,
}

Test { [[
class T with
do
end

var T*? t = spawn T;
await *t;
escape 1;
]],
    asr = 'runtime error: invalid tag',
}

-- MEM/MEMORY POOL

Test { [[
class T with
do
end
pool T t;
escape 1;
]],
    env = 'line 4 : missing `pool´ dimension',
    --parser = 'line 4 : after `T´ : expected `[´',
}

Test { [[
class T with do end
pool T[] ts;
var T t;
ts = t;
escape 1;
]],
    env = 'line 4 : types mismatch',
}

Test { [[
class T with
do
end
pool T[] t;
escape 1;
]],
    run = 1,
}

Test { [[
class T with
do
end
pool T[1] t;
escape 1;
]],
    run = 1,
}

Test { [[
class T with
do
end
pool T[1] t;
var T*? ok1 = spawn T in t with end;
var T*? ok2 = spawn T in t;
escape (ok1?) + (ok2?) + 1;
]],
    fin = 'line 7 : unsafe access to pointer "ok1" across `spawn´',
}

Test { [[
class T with
do
end
pool T[1] t;
var T*? ok1 = spawn T in t with end;
var int sum = 1;
if ok1? then
    watching *ok1 do
        var T*? ok2 = spawn T in t;
        sum = sum + (ok1?) + (ok2?);
    end
end
escape sum;
]],
    run = 1,
}

Test { [[
class T with
    var int v = 0;
do
end
var T ts;
loop t in ts do
end
escape 1;
]],
    --fin = 'line 14 : pointer access across `await´',
    exp = 'line 6 : invalid pool',
    --run = 1,
}
Test { [[
class T with
    var int v = 0;
do
end
pool T[1] ts;
var T*?  ok1 = spawn T in ts with
                this.v = 10;
              end;
var int ok2 = 0;// spawn T in ts;
var int ret = 0;
loop (T*)t in ts do
    ret = ret + t:v;
end
escape (ok1?) + ok2 + ret;
]],
    parser = 'line 11 : before `loop´ : expected statement (usually a missing `var´ or C prefix `_´)',
    --fin = 'line 14 : pointer access across `await´',
    --run = 1,
}
Test { [[
class T with
    var int v = 0;
do
end
pool T[1] ts;
var T*?  ok1 = spawn T in ts with
                this.v = 10;
              end;
var int ok2 = 0;// spawn T in ts;
var int ret = 0;
loop t in ts do
    ret = ret + t:v;
end
escape (ok1?) + ok2 + ret + 1;
]],
    --fin = 'line 14 : pointer access across `await´',
    run = 1,
}
Test { [[
class T with
do
end
pool T[] t;
spawn T in t;
escape 1;
]],
    run = 1,
}
Test { [[
class T with
do
end
spawn T;
escape 1;
]],
    run = 1,
}
Test { [[
class T with
do
end
pool T[] t;
spawn T in t;
spawn T;
escape 1;
]],
    run = 1,
}

Test { [[
native do
    int V = 0;
end
class T with
    var int v = 0;
do
    async do end;
end
pool T[] ts;
spawn T in ts with
    this.v = 10;
    _V = _V + 10;
end;
spawn T with
    this.v = 20;
    _V = _V + 20;
end;
var int ret = 0;
loop t in ts do
    ret = ret + t:v;
end
escape ret + _V;
]],
    run = 40,
}

Test { [[
native do
    int V = 0;
end
class T with
    var int v = 0;
do
    async do end;
end
pool T[] ts;
spawn T with
    this.v = 10;
    _V = _V + 10;
end;
spawn T in ts with
    this.v = 20;
    _V = _V + 20;
end;
var int ret = 0;
loop t in ts do
    ret = ret + t:v;
end
escape ret + _V;
]],
    run = 50,
}

Test { [[
native do
    int V = 0;
end
class T with
    var int v = 0;
do
    async do end;
end
pool T[] ts;
spawn T in ts with
    this.v = 10;
    _V = _V + 10;
end;
spawn T in ts with
    this.v = 20;
    _V = _V + 20;
end;
var int ret = 0;
loop t in ts do
    ret = ret + t:v;
end
escape ret + _V;
]],
    run = 60,
}

Test { [[
pool T[0] ts;
class T with
    var int a;
do
    this.a = 1;
end
var T*? t = spawn T in ts;
escape not t?;
]],
    env = 'line 1 : undeclared type `T´',
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
end
pool T[0] ts;
var T*? t = spawn T in ts;
escape not t?;
]],
    run = 1,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] ts;
var T*? a = spawn T in ts;
var int sum = 0;
watching *a do
    var T*? b = spawn T in ts;
    sum = a? and (not b?);
end
escape sum;
]],
    run = 1,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
do
pool T[0] ts;
var T*? t = spawn T in ts;
escape not t?;
end
]],
    run = 1,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] as;
pool T[0] bs;
var T*? a = spawn T in as;
var int sum = 0;
if a? then
    watching *a do
        var T*? b = spawn T in bs;
        sum = a? and (not b?);
    end
end
escape sum;
]],
    run = 1,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] ts;
var T*? a = spawn T in ts;
//free(a);
var int sum = 0;
if a? then
    watching *a do
        var T*? b = spawn T in ts;   // fails (a is freed on end)
        sum = a? and (not b?);
    end
end
escape sum;
]],
    run = 1,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] ts;
var T* a = null;
do
    var T*? aa = spawn T in ts;
        a = aa;
end
var int sum = 0;
if a != null then
    watching *a do
        var T*? b = spawn T in ts;   // fails (a is free on end)
        sum = a!=null and (not b?) and a!=b;
    end
end
escape sum;
]],
    --fin = 'line 15 : pointer access across `await´',
    asr = ':15] runtime error: invalid tag',
    --run = 1,
}
Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[2] ts;
var T* a = null;
do
    var T*? aa = spawn T in ts;
        a = aa;
end
var int sum = 0;
if a != null then
    watching *a do
        var T*? b = spawn T in ts;   // fails (a is free on end)
        sum = a!=null and (b?) and a!=b;
    end
end
escape sum;
]],
    --fin = 'line 15 : pointer access across `await´',
    run = 1,
}
Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] ts;
var T*? a;
do
    var T*? aa = spawn T in ts;
        a = aa;
end
var int sum = 0;
if a? then
    watching *a do
        var T*? b = spawn T in ts;   // fails (a is free on end)
        sum = a? and (not b?);// and a!=b;
    end
end
escape sum;
]],
    --fin = 'line 15 : pointer access across `await´',
    run = 1,
}
Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] ts;
var T* a;
do
    var T*? aa = spawn T in ts;
        a = aa;
end
var T*? b = spawn T in ts;   // fails (a is free on end)
escape (not b?);
]],
    run = 1,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] ts;
var T* a=null, b=null;
var int sum = 0;
do
    do
        var T*? aa = spawn T in ts;
            a = aa;
    end
    sum = a!=null;
    var T*? bb = spawn T in ts;  // fails
        b = bb;
end
if b != null then
    watching *b do
        var T*? c = spawn T in ts;       // fails
        sum = (b==null) and (not c?);// and a!=b and b==c;
    end
end
escape sum;
]],
    asr = ':14] runtime error: invalid tag',
    --fin = 'line 19 : pointer access across `await´',
    --run = 1,
}
Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] ts;
var T*? a, b;
var int sum = 0;
do
    do
        var T*? aa = spawn T in ts;
            a = aa;
    end
    sum = a?;
    var T*? bb = spawn T in ts;  // fails
        b = bb;
    sum = sum and (not b?);
end
var T*? c = spawn T in ts;       // fails
escape sum and (not c?);
]],
    --fin = 'line 19 : pointer access across `await´',
    run = 1,
}
Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] ts;
var T*? a, b;
var bool b_;
do
    do
        var T*? aa = spawn T in ts;
            a = aa;
    end
    var T*? bb = spawn T in ts;  // fails
        b = bb;
    b_ = (b?);
end
var T*? c = spawn T in ts;       // fails
//native @nohold _fprintf(), _stderr;
        //_fprintf(_stderr, "%p %p\n",a, b);
escape b_==false and (not c?);
]],
    run = 1,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] ts;
var T*? a;
var int sum = 0;
do
    var T*? aa = spawn T in ts;
        a = aa;
    sum = a?;
end
var T*? b = spawn T in ts;   // fails
escape sum and (not b?);
]],
    --fin = 'line 13 : pointer access across `await´',
    run = 1,
}
Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
pool T[1] ts;
var T* a;
do
    var T*? aa = spawn T in ts;
        a = aa;
end
var T*? b = spawn T in ts;   // fails
escape (not b?);
]],
    run = 1,
}

Test { [[
native do
    int V = 0;
end
class T with
    var int a;
do
    _V = _V + 1;
    await FOREVER;
end
pool T[1] ts;
do
    loop i in 2 do
        spawn T in ts;
    end
    loop i in 2 do
        spawn T;
    end
end
escape _V;
]],
    run = 3,
}
Test { [[
native do
    int V = 0;
end
class T with
    var int a;
do
    _V = _V + 1;
    await FOREVER;
end
pool T[1] ts;
do
    loop i in 2 do
        spawn T in ts;
    end
    loop i in 2 do
        spawn T;
    end
end
escape _V;
]],
    run = 3,
}

Test { [[
native do
    int V = 0;
end
class T with
    var int a;
do
    _V = _V + 1;
end
do
    pool T[1] ts;
    loop i in 1000 do
        var T*? ok = spawn T in ts;  // 999 fails
        if (not ok?) then
            escape 0;
        end
    end
end
escape _V;
]],
    --loop = 1,
    --run = 1000,
    run = 0;
}
Test { [[
input void A;
native do
    int V = 0;
end
class T with
    var int a;
do
    _V = _V + 1;
    await A;
end
pool T[1] ts;
do
    loop i in 10 do
        spawn T in ts;
    end
end
escape _V;
]],
    --loop = 1,
    run = { ['~>A']=1 },
}
Test { [[
input void A;
native do
    int V = 0;
end
class T with
    var int a;
do
    _V = _V + 1;
    await A;
end
pool T[1] ts;
do
    loop i in 1000 do
        var T*? ok = spawn T in ts;
        if not ok? then
            escape 10;
        end
    end
end
escape _V;
]],
    --loop = 1,
    run = { ['~>A']=10 },
}

Test { [[
interface I with
    var int v;
end

class T with
    var int u,v,x;
do
end

class U with
    var int v;
do
end

pool I[10] is;

spawn T in is;
spawn U in is;

escape sizeof(CEU_T) > sizeof(CEU_U);
]],
    run = 1,
}
Test { [[
interface I with
    var int v;
end

class T with
    var int u,v,x;
do
end

class U with
    var int v;
do
end

class V with
do
    pool I[10] is;
    spawn T in is;
    spawn U in is;
end

pool I[10] is;

spawn T in is;
spawn U in is;
spawn V in is;

escape sizeof(CEU_T) > sizeof(CEU_U);
]],
    run = 1,
}
Test { [[
class T with
    var int a;
    var int b;
do
    b = a * 2;
    await FOREVER;
end

var T*? t =
    spawn T with
        this.a = 10;
    end;

escape t:b;
]],
    run = 20,
}

Test { [[
class T with
do
    par/or do
    with
    end
end
spawn T;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
class T with
do
    await OS_START;
end
spawn T;
await OS_START;
escape 1;
]],
    run = 1,
}

Test { [[
native _V;
native do
    int V=0;
end
input void OS_START;
class T with
do
    par/or do
    with
    end
    _V = _V + 1;
    await OS_START;
    _V = _V + 1;
end
var T*? t1 = spawn T;
var T*? t2 = spawn T;
await OS_START;
escape _V;
]],
    --run = 2,  -- blk before org
    run = 4,    -- org before blk
}

Test { [[
interface IPingu with
end

class WalkerAction with
    var IPingu& pingu;
do
end

class Pingu with
    interface IPingu;
do
    every 10s do
        spawn WalkerAction with
            this.pingu = outer;
        end;
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
interface IPingu with
end

class WalkerAction with
    var IPingu& pingu;
do
end

class Pingu with
    interface IPingu;
do
    do
        pool WalkerAction[] was;
        every 10s do
            spawn WalkerAction in was with
                this.pingu = outer;
            end;
        end
    end
end

escape 1;
]],
    run = 1,
}

-- FREE

Test { [[
class T with do end
var T* a = null;
//free a;
escape 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T*? a = spawn T;
//free a;
escape 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T*? a = spawn T;
//free a;
var T*? b = spawn T;
//free b;
escape 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T*? a = spawn T;
var T*? b = spawn T;
//free a;
//free b;
escape 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T*? a = spawn T;
var T*? b = spawn T;
//free b;
//free a;
escape 10;
]],
    run = 10,
}

Test { [[
native _V;
native do
    int V = 0;
end
class T with
do
    finalize with
        _V = _V + 1;
    end
end

var T*? a = spawn T;
//free a;
escape _V;
]],
    run = 1,
}

Test { [[
native _V;
native do
    int V = 0;
end
class T with
do
    finalize with
        _V = _V + 1;
    end
end

var T*? a = spawn T;
var T*? b = spawn T;
//free b;
//free a;
escape _V;
]],
    run = 2,
}

-- TODO: tests for `free´:
-- remove from tracks
-- invalid pointers
Test { [[
class T with do end
var T a;
//free a;
escape 0;
]],
    todo = 'removed free',
    env = 'line 3 : invalid `free´',
}

Test { [[
class T with
do
    spawn U;
end
class U with
do
    spawn T;
end
var T t;
escape 1;
]],
    env = 'line 3 : undeclared type `U´',
}

Test { [[
class T with do end;
class U with
    pool T[]& ts;
do
end
pool T[] ts1;
pool T[2] ts2;
var U _ with
    this.ts = ts1;
end;
var U _ with
    this.ts = ts2;
end;
escape 1;
]],
    run = 1,
}
Test { [[
native do
    int V = 0;
end
var int i;
var int& r = i;

class T with
do
    _V = _V + 1;
    await FOREVER;
end;

pool T[2] ts;

class U with
    pool T[]& xxx;  // TODO: test also T[K<2], T[K>2]
                    //       should <= be allowed?
do
    spawn T in xxx;
    spawn T in xxx;
    spawn T in xxx;
    _V = _V + 10;
end

spawn T in ts;
var U u with
    this.xxx = outer.ts;
end;

escape _V;
]],
    run = 12,
}

Test { [[
class Body with
    var int& sum;
do
    sum = sum + 1;
end

var int sum = 0;
var Body b with
    this.sum = sum;
end;
sum = 10;

escape b.sum;
]],
    run = 10,
}

Test { [[
class X with do
end;

class Body with
    pool  X[]& bodies;
    var   int&    sum;
    event int     ok;
do
    var X*? nested =
        spawn X in bodies with
        end;
    sum = sum + 1;
    emit this.ok => 1;
end

pool X[1] bodies;
var  int  sum = 1;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    run = 2,
}

-- SPAWN / RECURSIVE

Test { [[
native do
    int V = 0;
end
class T with
do
    _V = _V + 1;
    if _V < 10 then
        spawn T;
    end
end
var T t;
escape _V;
]],
    wrn = 'line 8 : unbounded recursive spawn',
    run = 10,
}

Test { [[
native do
    int V = 0;
end
class T with
do
    _V = _V + 1;
    spawn T;
end
var T t;
escape _V;
]],
    wrn = 'line 7 : unbounded recursive spawn',
    --run = 101,  -- tests force 100 allocations at most
    asr = 'runtime error: stack overflow',
}
Test { [[
native do
    int V = 0;
end
class T with
do
    _V = _V + 1;
    spawn T;
    await FOREVER;
end
var T t;
escape _V;
]],
    wrn = 'line 7 : unbounded recursive spawn',
    run = 101,  -- tests force 100 allocations at most
}
Test { [[
class Body with
    pool  Body[]& bodies;
    var   int&    sum;
    event int     ok;
do
    var Body*? nested =
        spawn Body in bodies with
            this.bodies = bodies;
            this.sum    = sum;
        end;
    if nested? then
        watching *nested do
            await nested:ok;
        end
    end
    sum = sum + 1;
    emit this.ok => 1;
end

pool Body[4] bodies;
var  int     sum = 0;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    wrn = 'line 7 : unbounded recursive spawn',
    run = 5,
}

Test { [[
class Body with
    pool Body[]& bodies;
    var  int&     sum;
do
    var Body*? nested =
        spawn Body in bodies with
            this.bodies = bodies;
            this.sum    = sum;
        end;
    if nested? then
        await *nested;
    end
    sum = sum + 1;
end

pool Body[] bodies;
var  int     sum = 0;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    wrn = 'line 6 : unbounded recursive spawn',
    run = 101,
}

--[[
-- Trying to create an infinite loop with
-- bounded pool + recursive spawn.
-- Is it possible?
--      - no awaits from start to recursive spawn
--      - with nothing else, the Nth spawn will fail
--      - from the fail, the last spawn resumes
--      - in the worst scenario, it finishes and opens a new slot
--      - if the recursive spawn tries another recursive spawn in sequence,
--          this new one will succeed, but the same resoning above holds
--          I'm just duplicating the successes, but not really unbounded yet
--      - I cannot have indirect recursion
--      - So, the only possibility is with a loop enclosing the recursive spawn
--      - But in this case, the language will warn if this loop has no awaits.
--      - It will change the message from "unbounded recursive spawn"
--          to "tight loop", which is correct!
--]]

Test { [[
class Body with
    pool Body[1]& bodies;
    var  int&     sum;
do
    var Body*? nested =
        spawn Body in bodies with
            this.bodies = bodies;
            this.sum    = sum;
        end;
    if nested? then
        await *nested;
    end
    sum = sum + 1;
end

pool Body[1] bodies;
var  int     sum = 0;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    run = 2,
}
Test { [[
class Body with
    pool Body[1]& bodies;
    var  int&     sum;
do
    var Body*? nested =
        spawn Body in bodies with
            this.bodies = bodies;
            this.sum    = sum;
        end;
    sum = sum + 1;
end

pool Body[1] bodies;
var  int     sum = 0;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    run = 2,
}

Test { [[
class Body with
    pool Body[1]& bodies;
    var  int&     sum;
do
    var Body*? nested =
        spawn Body in bodies with
            this.bodies = bodies;
            this.sum    = sum;
        end;
    sum = sum + 1;
end

pool Body[1] bodies;
var  int     sum = 0;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    run = 2,
}

Test { [[
class Body with
    pool Body[1]& bodies;
    var  int&     sum;
do
    spawn Body in bodies with
        this.bodies = bodies;
        this.sum    = sum;
    end;
    sum = sum + 1;
    spawn Body in bodies with
        this.bodies = bodies;
        this.sum    = sum;
    end;
end

pool Body[1] bodies;
var  int     sum = 0;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    run = 3,
}

Test { [[
class Body with
    pool Body[1]& bodies;
    var  int&     sum;
do
    sum = sum + 1;
    loop do
        spawn Body in bodies with
            this.bodies = bodies;
            this.sum    = sum;
        end;
    end
end

pool Body[1] bodies;
var  int     sum = 0;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    tight = 'line 6 : tight loop',
}

Test { [[
class Body with
    pool Body[1]& bodies;
    var  int&     sum;
do
    sum = sum + 1;
    loop do
        var Body*? t = spawn Body in bodies with
            this.bodies = bodies;
            this.sum    = sum;
        end;
        watching *t do
            await FOREVER;
        end
    end
end

pool Body[1] bodies;
var  int     sum = 0;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    tight = 'line 6 : tight loop',
}

Test { [[
class Sum with
    var int* v;
do
    await FOREVER;
end

class Body with
    pool  Body[]& bodies;
    var   Sum&    sum;
do
    *this.sum.v = *this.sum.v + 1;
    spawn Body in this.bodies with
        this.bodies = bodies;
        this.sum    = sum;
    end;
end

var int v = 0;
var Sum sum with
    this.v = &v;
end;

pool Body[7] bodies;
do Body with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape v;
]],
    fin = 'line 11 : unsafe access to pointer "v" across `class´ (tests.lua : 7)',
}
Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

class Sum with
    var int* v;
do
    await FOREVER;
end

class Body with
    pool  Body[]& bodies;
    var   Tree*   n;
    var   Sum&    sum;
do
    watching n do
        if n:NODE then
            *this.sum.v = *this.sum.v + n:NODE.v;
            spawn Body in this.bodies with
                this.bodies = bodies;
                this.n      = n:NODE.left;
                this.sum    = sum;
            end;
        end
    end
end

var int v = 0;
var Sum sum with
    this.v = &v;
end;

pool Body[7] bodies;
do Body with
    this.bodies = bodies;
    this.n      = tree;
    this.sum    = sum;
end;

escape v;
]],
    fin = 'line 29 : unsafe access to pointer "v" across `class´ (tests.lua : 22)',
}
    -- AWAIT/KILL ORG

Test { [[
class T with
    var int a;
do
    this.a = 1;
end
var T a;
var int ret = 0;
par/and do
    await a;
    ret = ret + 1;
with
    kill a;
with
    await a;
    ret = ret * 2;
end
escape ret;
]],
    _ana = { acc=3 },
    run = 2,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
end
var T a;
var int ret = 0;
par/and do
    watching a do
        await FOREVER;
    end
    ret = 10;
with
    kill a;
end
escape ret;
]],
    run = 10,
}

Test { [[
input void OS_START;

class T with
    var int a;
do
end

event T* e;

par/or do
    await OS_START;
    var T a;
    emit e => &a;
    await FOREVER;
with
    var T* pa = await e;
    watching *pa do
        await FOREVER;
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
native @pure _printf();

class T with
    var int a;
do
    await 1s;
end

event T* e;

par do
    var T* pa = await e;
    watching *pa do
        await FOREVER;
    end
    escape -1;
with
    await OS_START;
    do
        var T a;
        emit e => &a;
    end
    await 2s;
    escape 1;
end
]],
    run = { ['~>2s']=1 },
}

Test { [[
class T with
do
end
var T a;
var int* v = await a;
escape 1;
]],
    env = 'line 5 : types mismatch (`int*´ <= `int´)',
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
var T a;
var int ret = 0;
par/and do
    var int v = await a;
    ret = ret + v;
with
    kill a => 10;
with
    var int v = await a;
    ret = ret + v;
end
escape ret;
]],
    _ana = { acc=3 },
    run = 20,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
    await FOREVER;
end
var T a;
var int ret = 10;
par/and do
    var int v;
    watching v in a do
        await FOREVER;
    end
    ret = v;
with
    kill a => 1;
end
escape ret;
]],
    run = 1,
}

Test { [[
native do
    int V = 0;
end
class T with
do
    finalize with
        _V = 10;
    end
    await FOREVER;
end
do
    var T t;
end
escape _V;
]],
    run = 10,
}
Test { [[
native do
    int V = 0;
end
class T with
do
    finalize with
        _V = 10;
    end
    await FOREVER;
end
do
    pool T[] ts;
    var T*? t = spawn T in ts;
end
escape _V;
]],
    run = 10,
}

Test { [[
native do
    int V = 0;
end
class T with
do
    finalize with
        _V = 10;
    end
    await FOREVER;
end
var T*? t = spawn T;
kill *t;
escape _V;
]],
    run = 10,
}

Test { [[
native do
    int V = 0;
end
class T with
do
    finalize with
        _V = 10;
    end
    await FOREVER;
end
var T t;
kill t;
escape _V;
]],
    run = 10,
}

Test { [[
native do
    int V = 0;
end
class T with
do
    finalize with
        _V = 10;
    end
    await FOREVER;
end
var T t;
par/and do
    kill t;
with
    await t;
    _V = _V * 2;
end
escape _V;
]],
    run = 20,
}

Test { [[
class T with
    var int v = 10;
do
    await 1s;
end

input void OS_START;
event T* e;

var int ret = 1;

par/and do
    await OS_START;
    var T*? t = spawn T;
    emit e => t;
    ret = ret + t:v;
with
    var T* t1 = await e;
    ret = ret * 2;
end

escape ret;
]],
    --run = { ['~>1s'] = 13 },
    fin = 'line 16 : unsafe access to pointer "t" across `emit´',
}

Test { [[
class T with
    var int v = 10;
do
    await 1s;
end

input void OS_START;
event T* e;

var int ret = 1;

par/and do
    await OS_START;
    var T*? t = spawn T;
    watching *t do
        emit e => t;
        ret = ret + t:v;
        await *t;
        ret = ret + 1;
    end
with
    var T* t1 = await e;
    ret = ret * 2;
end

escape ret;
]],
    run = { ['~>1s'] = 12 },
}

Test { [[
class T with
    var int v = 10;
do
    await FOREVER;
end

var T*? t = spawn T;
finalize with
    kill *t;
end

escape 10;
]],
    props = 'line 9 : not permitted inside `finalize´',
}

Test { [[
class T with
    var int v = 10;
do
    await FOREVER;
end

input void OS_START;
event T* e;

var int ret = 1;

par/and do
    await OS_START;
    var T*? t = spawn T;
    ret = ret * 2;
    watching *t do
        emit e => t;
        ret = ret + t:v;
        await *t;
        ret = -1;
    end
    ret = ret * 2;
with
    var T* t1 = await e;
    ret = ret + t1:v;
    kill *t1;
    ret = ret + 1;
end

escape ret;
]],
    run = 25,
}

Test { [[
class T with
do
    await FOREVER;
end
var int ret = 0;
loop i do
    var T t1;
    par/or do
        await t1;
    with
        kill t1;
        await FOREVER;
    end

    var T*? t = spawn T;
    par/or do
        await *t;
    with
        kill *t;
        await FOREVER;
    end
    if i == 10 then
        break;
    else
        ret = ret + 1;
    end
end
escape ret;
]],
    wrn = true,
    loop = true,
    --tight = 'line 6 : tight loop',
    run = 10,
}

Test { [[
class T with
do
end
var int ret = 0;
loop i do
    var T t1;
    par/or do
        await t1;
    with
        kill t1;
        await FOREVER;
    end

    var T*? t = spawn T;
    par/or do
        if t? then
            await *t;
        end
    with
        kill *t;
        await FOREVER;
    end
    if i == 10 then
        break;
    else
        ret = ret + 1;
    end
end
escape ret;
]],
    wrn = true,
    loop = true,
    --tight = 'line 6 : tight loop',
    run = 10,
}

Test { [[
class T with
do
    await FOREVER;
end

pool T[] ts;

loop t1 in ts do
    loop t2 in ts do
        kill *t1;
        kill *t2;
    end
end

escape 1;
]],
    fin = 'line 11 : unsafe access to pointer "t2" across `kill´',
}

Test { [[
class T with
do
    await FOREVER;
end

pool T[] ts;

loop t1 in ts do
    loop t2 in ts do
        watching *t2 do
            kill *t1;
            kill *t2;
        end
    end
end

escape 1;
]],
    run = 1,
}

-- DO T

Test { [[
do T;
escape 0;
]],
    env = 'line 1 : undeclared type `T´',
}

Test { [[
class T with
do
end
do T;
escape 0;
]],
    run = 0,
    --env = 'line 4 : variable/event "ok" is not declared',
}

Test { [[
class T with
    event void ok;
do
    emit ok;
end
par/or do
    loop do
        do T;
    end
with
end
escape 1;
]],
    tight = 'line 7 : tight loop',
    run = 1,
}

Test { [[
input void OS_START;
class T with
    event void ok;
do
    emit ok;
end
par do
    do T;
    escape 1;
with
    await OS_START;
    escape 2;
end
]],
    run = 1,
}

Test { [[
input void OS_START;
class T with
    event void ok;
do
    await OS_START;
    emit ok;
end
do T;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
class T with
    event int ok;
do
    await OS_START;
    emit ok => 1;
end
do T;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
class T with
    var int v;
do
    await OS_START;
    escape v;
end
var int v = do T with
    this.v = 10;
end;
escape v;
]],
    run = 10,
}

Test { [[
input void OS_START;
class T with
    var int v;
do
    await OS_START;
    escape v;
end
var int v;
v = do T with
    this.v = 10;
end;
escape v;
]],
    run = 10,
}

Test { [[
input void OS_START;
class T with
    var int v;
do
    await OS_START;
    escape 10;
end
var int* v = do T with
    this.v = 10;
end;
escape *v;
]],
    env = 'line 8 : types mismatch (`int*´ <= `int´)',
}

Test { [[
input void OS_START;
class T with
    var int v;
do
    await OS_START;
    escape v;
end
var int v;
v = do T with
    this.v = 10;
end;
escape v;
]],
    run = 10,
}

Test { [[
input void OS_START;
class T with
    var int v;
do
    await OS_START;
    escape (v,v*2);
end
var int v1, v2;
(v1,v2) = do T with
    this.v = 10;
end;
escape v1+v2;
]],
    parser = 'line 6 : after `v´ : expected `)´',
    --env = 'line 10 : arity mismatch',
    --run = 30,
}

Test { [[
input void MOVE_DONE;

class Mix with
  var int cup_top;
  event void ok;
do
  await MOVE_DONE;
  emit ok;
end

class ShuckTip with
  event void ok;
do
end

par/or do
  do
    var int dilu_start = 0;
    do
      var Mix m with
        this.cup_top = dilu_start;
      end;
      await m.ok;
    end
  end
  do ShuckTip;
with
  async do
    emit MOVE_DONE;
  end
end

escape 1;
]],
    run = 1,
}

Test { [[
class T with do
    await FOREVER;
end
var T*? ok;
native do ##include <assert.h> end
native _assert();
do
    loop i in 100 do
        ok = spawn T;
    end
    _assert(ok?);
    ok = spawn T;
    ok = spawn T;
    _assert(not ok?);
end
do
    loop i in 100 do
        ok = spawn T;
    end
    _assert(not ok?);
end
do
    loop i in 101 do
        ok = spawn T;
    end
    _assert(not ok?);
end
escape (not ok?);
]],
    --loop = 1,
    --fin = 'line 11 : pointer access across `await´',
    run = 1,
}

Test { [[
class T with do
    await FOREVER;
end
native do ##include <assert.h> end
native _assert();
do
    loop i in 100 do
        var T*? ok;
        ok = spawn T;
        _assert(ok?);
    end
    var T*? ok1 = spawn T;
    _assert(not ok1?);
    var T*? ok2 = spawn T;
    _assert(not ok2?);
end
do
    loop i in 100 do
        var T*? ok;
        ok = spawn T;
        _assert(ok?);
    end
end
do
    loop i in 101 do
        var T*? ok;
        ok = spawn T;
        _assert(i<100 or (not ok?));
    end
end
escape 1;
]],
    --loop = 1,
    --run = 1,
    asr = true,
}

Test { [[
class T with do
    await FOREVER;
end
native do ##include <assert.h> end
native _assert();
do
    pool T[] ts;
    loop i in 100 do
        var T*? ok;
        ok = spawn T in ts;
        _assert(not ok?);
    end
    var T*? ok1 = spawn T;
    _assert(not ok1?);
    var T*? ok2 = spawn T;
    _assert(not ok2?);
end
do
    pool T[] ts;
    loop i in 100 do
        var T*? ok;
        ok = spawn T in ts;
        _assert(ok?);
    end
end
do
    pool T[] ts;
    loop i in 101 do
        var T*? ok;
        ok = spawn T in ts;
        if i < 100 then
            _assert(ok?);
        else
            _assert(not ok?);
        end
    end
end
escape 1;
]],
    --loop = 1,
    --run = 1,
    asr = true,
}

Test { [[
native do ##include <assert.h> end
native _V;
native do
    int V = 0;
end
class T with
    var int inc;
do
    finalize with
        _V = _V + this.inc;
    end
    await FOREVER;
end
var int v = 0;
do
    pool T[] ts;
    loop i in 200 do
        var T*? ok =
            spawn T in ts with
                this.inc = 1;
            end;
        if (not ok?) then
            v = v + 1;
        end
    end

    input void OS_START;
    await OS_START;
end
native _assert();
_assert(_V==100 and v==100);
escape _V+v;
]],
    --loop = 1,
    run = 200,
}

Test { [[
do
    var int i = 1;
    every 1s do
        spawn HelloWorld with
            this.id = i;
        end;
        i = i + 1;
    end
end
]],
    env = 'line 4 : undeclared type `HelloWorld´',
}

Test { [[
native _V;
native do
    int V = 0;
end
class T with
do
    await 2s;
    _V = _V + 1;
end
do
    spawn T;
    await 1s;
    spawn T;
    await 1s;
    spawn T;
    await 1s;
    spawn T;
    await 50s;
end
escape _V;
]],
    run = { ['~>100s']=4 },
}

Test { [[
input void OS_START;
native _V;
native do
    int V = 1;
end
class T with
do
    await OS_START;
    _V = 10;
end
do
    spawn T;
    await OS_START;
end
escape _V;
]],
    --run = 1,  -- blk before org
    run = 10,   -- org before blk
}

Test { [[
input void OS_START;
native _V;
native do
    int V = 1;
end
class T with
do
    _V = 10;
end
do
    spawn T;
    await OS_START;
end
escape _V;
]],
    run = 10,
}

Test { [[
class T with do end;
var T a;
var T* b;
b = &a;
escape 1;
]],
    run = 1,
    --env = 'line 4 : invalid attribution',
}

Test { [[
class T with do
    await FOREVER;
end;
var T*? a = spawn T;
var T* b;
b = a;
escape 10;
]],
    run = 10;
}

Test { [[
class T with do end;
var T*? a = spawn T;
var T* b;
b = a;
escape 10;
]],
    asr = '4] runtime error: invalid tag',
}

Test { [[
class T with
    var int v;
do
    await FOREVER;
end

var T* a;
do
    var T*? b = spawn T;
    b:v = 10;
    a = b;
end
escape a:v;
]],
    --fin = 'line 10 : attribution requires `finalize´',
    --fin = 'line 12 : pointer access across `await´',
    run = 10,
}
Test { [[
class T with
    var int v;
do
    await FOREVER;
end

var T* a;
do
    var T*? b = spawn T;
    b:v = 10;
    a = b;
    escape a:v;
end
]],
    --fin = 'line 10 : attribution requires `finalize´',
    run = 10,
}

Test { [[
class T with
    var int v;
do
end

var T* a;
do
    var T*? b = spawn T;
    b:v = 10;
    a = b;
end
await 1s;
escape a:v;
]],
    fin = 'line 13 : unsafe access to pointer "a" across `await´',
}

Test { [[
class T with
    var int v;
do
    await FOREVER;
end

var T* a;
var T aa;
do
    var T*? b = spawn T;
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
escape a:v;
]],
    todo = 'free runs after block fin (correct leak!)',
    run = 10,
}

Test { [[
native _V;
native do
    int V = 1;
end
class T with
    var int v;
do
    finalize with   // enters!
        _V = 10;
    end
    await FOREVER;
end

var T* a;
var T aa;
do
    pool T[] ts;
    var T*? b = spawn T in ts;
    b:v = 10;
        a = b;
end
escape _V;
]],
    run = 10,
}

Test { [[
input void OS_START;
native _V;
native do
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
    pool T[] ts;
    var T*? b = spawn T in ts;
    b:v = 10;
        a = b;
    await OS_START;
end
escape _V;
]],
    run = 10,
}

Test { [[
native _V;
native do
    int V = 5;
end
class T with
    var int v;
do
    finalize with   // enters!
        _V = 10;
    end
    await FOREVER;
end

var T* a;
do
    pool T[] ts;
    var T*? b = spawn T in ts;
    b:v = 10;
        a = b;
end
escape _V;
]],
    run = 10,
}
Test { [[
input void OS_START;
native _V;
native do
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
    pool T[] ts;
    var T*? b = spawn T in ts;
    b:v = 10;
        a = b;
    await OS_START;
end
escape _V;
]],
    run = 10,
}
Test { [[
class T with
    var int* i1;
do
    var int i2;
    i1 = &i2;
end
var T a;
escape 10;
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
escape 10;
]],
    fin = 'line 6 : attribution to pointer with greater scope',
    run = 10,
}

Test { [[
class T with do end
var T* t1;
do
do
    var T t2;
    //finalize
        t1 = &t2;
    //with
        //nothing;
    //end
end
end
escape 10;
]],
    fin = 'line 7 : attribution to pointer with greater scope',
    run = 10,
}

Test { [[
class T with do end
var T*? t;
do
    t = spawn T;
end
escape 10;
]],
    run = 10,
    --fin = 'line 4 : invalid block for awoken pointer "t"',
}

Test { [[
class T with do end
var T*? a = spawn T;
escape 10;
]],
    run = 10,
}

Test { [[
class T with do end
class U with do end
var T*? a;
a = spawn U;
]],
    env = 'line 4 : types mismatch',
}

Test { [[
native _V;
input void OS_START;
native do
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
    var T*? o;
    o = spawn T;
    await OS_START;
    ret = o:a;
end

escape ret + _V;
]],
    --run = 11,
    fin = 'line 22 : unsafe access to pointer "o" across `await´',
}

Test { [[
input void OS_START, F;
native _V;
native do
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
    pool T[] ts;
    var T*? o;
    o = spawn T in ts;
    //await OS_START;
    ret = o:a;
with
    await F;
end

escape ret + _V;
]],
    run = { ['~>F']=11 },
}

Test { [[
input void OS_START, F;
native _V;
native do
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
    var T*? o;
    o = spawn T;
    //await OS_START;
    ret = o:a;
with
    await F;
end

escape ret + _V;    // V still 0
]],
    run = { ['~>F']=10 },
}

Test { [[
class V with
do
end

var V*? v;
v = spawn V;
await 1s;

escape 10;
]],
    run = { ['~>1s']=10, }
}

Test { [[

class V with
do
end

class U with
    var V* v;
do
    var V*? vv = spawn V;
end

class T with
    var U u;
do
end

var T t;
escape 1;
]],
    props = 'line 13 : not permitted inside an interface',
}

Test { [[

class V with
do
end

class U with
    var V* v;
do
    var V*? vv = spawn V;
end

class T with
    var U* u;
do
    var U uu;
    this.u = &uu;
end

var T t;
escape 1;
]],
    run = 1,
}

Test { [[
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
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
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U u;
do
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

var T t;
escape _V;
]],
    props = 'line 26 : not permitted inside an interface',
}
Test { [[
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
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
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U* u;
do
    var U uu;
    u = &uu;
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

var T t;
escape _V;
]],
    run = 1,
}

Test { [[
input void OS_START;
native _f(), _V;
native do
    int V = 1;
end

class V with
do
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V v;
do
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U u;
do
    await FOREVER;
end

do
    var T t;
end

escape _V;
]],
    props = 'line 16 : not permitted inside an interface',
}
Test { [[
input void OS_START;
native _f(), _V;
native do
    int V = 1;
end

class V with
do
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V* v;
do
    var V vv1;
    v = &vv1;
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U* u;
do
    var U uu;
    u = &uu;
    await FOREVER;
end

do
    var T t;
end

escape _V;
]],
    run = 3,
}

Test { [[
input void OS_START;
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
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
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U u;
do
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

do
    var T t;
end

escape _V;
]],
    props = 'line 27 : not permitted inside an interface',
}
Test { [[
input void OS_START;
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
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
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U* u;
do
    var U uu;
    u = &uu;
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

do
    var T t;
end

escape _V;
]],
    run = 3,
}

Test { [[
class V with
do
end
class U with
do
    var V*? vv = spawn V;
end
var U u;
escape 2;
]],
    run = 2,
}

Test { [[
input void OS_START;

class V with
do
end

class U with
do
    var V*? vv = spawn V;
end


var U t;
await OS_START;

native @nohold _tceu_trl, _tceu_trl_, _sizeof();
escape 2;
]],
    run = 2,
}

Test { [[
input void OS_START;
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
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
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U u;
do
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

do
    var T t;
    await OS_START;
end

escape _V;
]],
    props = 'line 27 : not permitted inside an interface',
}
Test { [[
input void OS_START;
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
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
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U* u;
do
    var U uu;
    u = &uu;
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

do
    var T t;
    await OS_START;
end

escape _V;
]],
    run = 3,
}

Test { [[
input void OS_START;
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
    finalize
        v = _f();
    with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V* x;
do
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U u;
do
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

var T t;
do
    await OS_START;
    var V* v = t.u.x;
end

escape _V;
]],
    --fin = 'line 37 : pointer access across `await´',
    props = 'line 27 : not permitted inside an interface',
}
Test { [[
input void OS_START;
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
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
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U* u;
do
    var U uu;
    u = &uu;
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

var T t;
do
    await OS_START;
    var V* v = t.u:v;
end

escape _V;
]],
    --fin = 'line 39 : pointer access across `await´',
    run = 1,
}

Test { [[
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
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
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U u;
do
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

input void OS_START;

var T t;
do
    var U u;
    u.v = t.u.v;
    await OS_START;
end

escape _V;
]],
    --fin = 'line 38 : pointer access across `await´',
    props = 'line 26 : not permitted inside an interface',
    --fin = 'line 38 : organism pointer attribution only inside constructors',
}
Test { [[
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
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
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U u;
do
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

input void OS_START;

var T t;
do
    var U u;
    u.v = t.u.v;
    await OS_START;
end

escape _V;
]],
    --fin = 'line 38 : pointer access across `await´',
    --fin = 'line 38 : attribution to pointer with greater scope',
    props = 'line 26 : not permitted inside an interface',
    --fin = 'line 38 : organism pointer attribution only inside constructors',
}
Test { [[
native _f(), _V;
native do
    int V = 1;
    int* f (){ return NULL; }
end

class V with
do
    var int&? v;
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
    var V*? vv = spawn V;
    await FOREVER;
end

class T with
    var U* u;
do
    var U uu;
    u = &uu;
    //u.v = spawn V;
    var V*? v = spawn V;
    await FOREVER;
end

input void OS_START;

var T t;
do
    var U u;
    u.v = t.u:v;
    await OS_START;
end

escape _V;
]],
    --fin = 'line 40 : pointer access across `await´',
    --fin = 'line 40 : organism pointer attribution only inside constructors',
    run = 2,
}

Test { [[
class V with
do
end

class T with
    var V*? v;
do
    await 1s;
    v = spawn V;
end

var T t;
await 1s;
escape 1;

]],
    --fin = 'line 9 : invalid block for awoken pointer "v"',
    --fin = 'line 9 : pointer access across `await´',
    run = { ['~>1s']=1, }
}

Test { [[
class V with
do
end

input void OS_START;
class U with
    var V*? v;
do
end

class T with
    var U* u;
do
    await OS_START;
    u:v = spawn V;
end

do
    var U u;
    var T t;
        t.u = &u;
    await OS_START;
end

escape 10;
]],
    --run = 10,
    exp = 'line 15 : invalid attribution (no scope)',
}
Test { [[
class V with
do
end

input void A, OS_START;
class U with
    var V*? v;
do
    await A;
end

class T with
    var U* u;
do
    await OS_START;
    u:v = spawn V;
end

do
    var U u;
    var T t;
        t.u = &u;
    await OS_START;
end

escape 10;
]],
    --run = { ['~>A']=10 },
    exp = 'line 16 : invalid attribution',
}

Test { [[
native _V, _assert();
native do
    int V = 1;
end

class V with
do
    _V = 20;
    _V = 10;
end

class U with
    var V*? v;
do
end

class T with
    var U* u;
do
    await 1s;
    u:v = spawn V;
end

do
    var U u;
    do              // 26
        var T t;
        t.u = &u;
        await 2s;
    end
    _assert(_V == 10);
end
_assert(_V == 10);
escape _V;
]],
    --run = { ['~>2s']=10, }       -- TODO: stack change
    exp = 'line 21 : invalid attribution',
}

Test { [[
native do ##include <assert.h> end
native _assert();
native _V;
native do
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
    var T*? a;
    a = spawn T;
    //free a;
    _assert(_V == 10);
    await 1s;
    _assert(_V == 8);
end

escape _V;
]],
    run = { ['~>1s']=8 },
}

Test { [[
native do ##include <assert.h> end
native _assert();
native _V;
native do
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
    pool T[] ts;
    var T*? a;
    a = spawn T in ts;
    //free a;
    _assert(_V == 10);
end
_assert(_V == 9);

escape _V;
]],
    run = 9,
}

Test { [[
native do ##include <assert.h> end
native _assert();
native _X, _Y;
native do
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
    var T*? ptr;
    loop i in 100 do
        if ptr? then
            //free ptr;
        end
        ptr = spawn T;
    end
    _assert(_X == 100 and _Y == 0);
end

_assert(_X == 100 and _Y == 0);
escape 10;
]],
    --loop = true,
    --fin = 'line 24 : invalid block for awoken pointer "ptr"',
    run = 10,
}

Test { [[
native do ##include <assert.h> end
native _assert();
native _X, _Y;
native do
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
    pool T[] ts;
    var T*? ptr;
    loop i in 100 do
        if ptr? then
            //free ptr;
        end
        ptr = spawn T in ts;
    end
    _assert(_X == 100 and _Y == 0);
end

_assert(_X == 100 and _Y == 100);
escape 10;
]],
    --loop = true,
    --fin = 'line 24 : invalid block for awoken pointer "ptr"',
    run = 10,
}

Test { [[
native do ##include <assert.h> end
native _assert();
native _X, _Y;
native do
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
    var T*? ptr;
    loop i in 100 do
        if ptr? then
            //free ptr;
        end
        ptr = spawn T;
    end
    _assert(_X == 100 and _Y == 99);
end

_assert(_X == 100 and _Y == 100);
escape 10;
]],
    todo = 'free',
    --loop = true,
    run = 10,
}

Test { [[
class U with do end;
class T with
    var U* u;
do
end

do
    var U u;
    spawn T with
        this.u = &u;
    end;
end
escape 1;
]],
    --fin = 'line 10 : attribution requires `finalize´',
    --fin = 'line 10 : attribution to pointer with greater scope',
    run = 1,
}

Test { [[
class U with do end;
class T with
    var U& u;
do
end

do
    var U u;
    spawn T with
        this.u = u;
    end;
end
escape 1;
]],
    --fin = 'line 10 : attribution requires `finalize´',
    --run = 1,
    ref = 'line 10 : attribution to reference with greater scope',
}

Test { [[
class U with do end;
class T with
    var U* u;
do
end

    var U u;
    spawn T with
        this.u = &u;
    end;
escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;
class T with
    var U& u;
do
end

    var U u;
    spawn T with
        this.u = u;
    end;
escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;
class T with
    var U* u;
do
    var U* u1 = u;
    await 1s;
end

do
    var U u;
    spawn T with
        this.u = &u;
    end;
end
escape 1;
]],
    --fin = 'line 12 : attribution requires `finalize´',
    --fin = 'line 12 : attribution to pointer with greater scope',
    run = 1,
}

Test { [[
class U with do end;
class T with
    var U* u;
do
    var U* u1 = u;
    await 1s;
end

    var U u;
    spawn T with
        this.u = &u;
    end;
escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;
class T with
    var U* u;
do
    var U* u1 = u;
    await 1s;
    var U* u2 = u;
end

do
    var U u;
    spawn T with
        this.u = &u;
    end;
end
escape 1;
]],
    fin = 'line 7 : unsafe access to pointer "u" across `await´',
}

Test { [[
class Rect with
do
    await FOREVER;
end

var int n = 0;

par/or do
    await 1s;
with
    pool Rect[1000] rs;
    every 40ms do
        loop i in 40 do
            n = n + 1;
            spawn Rect in rs;
        end
    end
end
escape n;
]],
    run = { ['~>1s']=960 },
}

-- TODO: mem out e mem ever
--[=[
Test { [[
var void* ptr;
class T with
do
end
loop i in 100000 do
    ptr = spawn T;
end
escape 10;
]],
    --loop = true,
    run = 10;
}
]=]

Test { [[
native do ##include <assert.h> end
native _V, _assert();
native do
    int V = 0;
end
class T with
    var int v;
do
    finalize with
        do
            loop i in 1 do
                do break; end
            end
            _V = _V + this.v;
        end
    end
    await FOREVER;
end
do
    pool T[] ts;
    var T*? p;
    p = spawn T in ts;
    p:v = 1;
    p = spawn T in ts;
    p:v = 2;
    p = spawn T in ts;
    p:v = 3;
    input void OS_START;
    await OS_START;
end
_assert(_V == 6);
escape _V;
]],
    wrn = true,
    run = 6,
}

Test { [[
class T with
do
end
var T*? t;
t = spawn T;
escape t.v;
]],
    env = 'line 6 : not a struct',
}

Test { [[
class T with
    var int v;
do
    await FOREVER;
end

var T*[10] ts;
var T*? t;
t = spawn T;
t:v = 10;
ts[0] = t;
escape t:v + ts[0]:v;
]],
    run = 20,
}

Test { [[
native _V;
native do
    int V = 0;
end

class T with
do
    _V = _V + 1;
    par/and do
        await 10ms;
    with
        loop i in 5 do
            if i==2 then
                break;
            end
            await 10ms;
        end
    end
    _V = _V + 1;
end

do
    loop i in 10 do
        await 1s;
        spawn T;
    end
    await 5s;
end

escape _V;
]],
    run = { ['~>1min']=20 },
}

Test { [[
class T with
    var int* ptr = null;
do
end
do
    var int* p = null;
    var T*? ui = spawn T with
        this.ptr = p;   // ptr > p
    end;
end
escape 10;
]],
    --fin = 'line 8 : attribution requires `finalize´',
    --fin = 'line 8 : attribution to pointer with greater scope',
    run = 10,
}

Test { [[
class T with
    var void* ptr = null;
do
end
do
    pool T[] ts;
    var void* p = null;
    var T*? ui;
    ui = spawn T in ts with
        this.ptr = p;
    end;
end
escape 10;
]],
    --fin = 'line 10 : attribution to pointer with greater scope',
    run = 10,
}

Test { [[
native _s=0;
native do
    typedef int s;
end

class T with
    var _s* ptr = null;
do
end

do
    var _s* p = null;
    var T*? ui = spawn T with
        this.ptr = p;
    end;
end

escape 10;
]],
    run = 10,
    --fin = 'line 14 : attribution to pointer with greater scope',
    --fin = 'line 14 : attribution requires `finalize´',
}

Test { [[
native _s=0;
native do
    typedef int s;
end

class T with
    var _s* ptr = null;
do
end

var T*? ui;
do
    var _s* p = null;
    do
        ui = spawn T with
            this.ptr = p;
        end;
    end
end

escape 10;
]],
    run = 10,
    --fin = 'line 16 : attribution to pointer with greater scope',
    --fin = 'line 16 : attribution requires `finalize´',
}

Test { [[
native _s=0;
native do
    typedef int s;
end

class T with
    var _s* ptr = null;
do
end

do
    loop i in 10 do
        var _s* p = null;
        spawn T with
            this.ptr = p;
        end;
        await 1s;
    end
end

escape 1;
]],
    run = { ['~>1min']=1 },
    --fin = 'line 15 : attribution to pointer with greater scope',
    --fin = 'line 15 : attribution requires `finalize´',
}
-- TODO: STACK
Test { [[
native do
    int V = 0;
end

class T with
    event void a;
do
    par/or do
        await a;
        _V = _V + 2;
    with
        emit a;
        _V = _V + 20;
    end
    await a;
    _V = _V + 10;
end

var T t;
_V = _V * 2;
emit t.a;
escape _V;
]],
    _ana = { acc=1 },
    --run = 14,
    run = 40,
}

Test { [[
native _s=0;
native do
    typedef int s;
end

class T with
    var _s* ptr = null;
do
    _V = _V + 1;
end

native do ##include <assert.h> end
native _V, _assert();
native do
    int V=0;
end

do
    loop i in 10 do
        var _s* p = null;
        spawn T with
            this.ptr = p;
        end;
        await 1s;
    end
    _assert(_V == 10);
end

escape _V;
]],
    run = { ['~>1min']=10 },
    --fin = 'line 22 : attribution to pointer with greater scope',
    --props = 'line 23 : not permitted inside a constructor',
}

Test { [[
class T with
    var void* ptr;
do
end

var T t with
    finalize
        this.ptr = _malloc(10);
    with
        _free(this.ptr);
    end
end;
]],
    --env = 'line 22 : variable/event "_" is not declared',
    fin = 'line 7 : constructor cannot contain `finalize´',
    --props = 'line 23 : not permitted inside a constructor',
}

Test { [[
class T with
    var void* ptr;
do
end

spawn T with
    finalize
        this.ptr = _malloc(10);
    with
        _free(this.ptr);
    end
end;
]],
    --env = 'line 22 : variable/event "_" is not declared',
    fin = 'line 7 : constructor cannot contain `finalize´',
    --props = 'line 23 : not permitted inside a constructor',
}

Test { [[
native _s=0;
native do
    typedef int s;
end

class T with
    var _s* ptr = null;
do
end

native do ##include <assert.h> end
native _V, _assert();
native do
    int V=0;
end

do
    loop i in 10 do
        var _s* p = null;
        spawn T with
            finalize
                this.ptr = p;
            with
                _V = _V + 1;
            end
        end;
        await 1s;
    end
    _assert(_V == 10);
end

escape _V;
]],
    --env = 'line 22 : variable/event "_" is not declared',
    fin = 'constructor cannot contain `finalize´',
    --props = 'line 23 : not permitted inside a constructor',
}

Test { [[
native _s=0;
native do
    typedef int s;
end

class T with
    var _s* ptr = null;
do
    _V = _V + 1;
end

native do ##include <assert.h> end
native _V, _assert();
native do
    int V=0;
end

var T*? ui;
do
    var _s* p = null;
    loop i in 10 do
        ui = spawn T with
            this.ptr = p;
        end;
        await 1s;
    end
    _assert(_V == 10);
end

escape _V;
]],
    run = { ['~>1min']=10 },
    --fin = 'line 23 : attribution to pointer with greater scope',
}

Test { [[
native _s=0;
native do
    typedef int s;
end

class T with
    var _s* ptr = null;
do
end

native do ##include <assert.h> end
native _V, _assert();
native do
    int V=0;
end

var T*? ui;
do
    var _s* p = null;
    loop i in 10 do
        ui = spawn T with
            finalize
                this.ptr = p;
            with
                _V = _V + 1;
            end
        end;
        await 1s;
    end
    _assert(_V == 0);
end
//_assert(_V == 10);

escape _V;
]],
    --env = 'line 23 : variable/event "_" is not declared',
    fin = 'constructor cannot contain `finalize´',
    --props = 'line 24 : not permitted inside a constructor',
}

Test { [[
native _s=0;
native do
    typedef int s;
end

class T with
    var _s* ptr = null;
do
end

native do ##include <assert.h> end
native _V, _assert();
native do
    int V=0;
end

do
    loop i in 10 do
        var _s* p = null;
        var T*? ui = spawn T with
            finalize
                this.ptr = p;   // p == ptr
            with
                _V = _V + 1;
            end
        end;
        await 1s;
    end
    _assert(_V == 10);
end

escape _V;
]],
    --env = 'line 22 : variable/event "_" is not declared',
    fin = 'constructor cannot contain `finalize´',
    --fin = 'line 21 : invalid `finalize´',
}

Test { [[
class Game with
    event (int,int,int*) go;
do
end

var Game game;
par/or do
    var int a,b;
    var int* c;
    (a, b, c) = await game.go;
with
    nothing;
end
escape 1;
]],
    run = 1;
}

Test { [[
class Game with
    event (int,int,int*) go;
do
end

var Game game;
emit game.go => (1, 1, null);
escape 1;
]],
    run = 1;
}

Test { [[
class Unit with
    event int move;
do
end
var Unit* u;
do
    var Unit unit;
    u = &unit;
    await 1min;
end
emit u:move => 0;
escape 2;
]],
    --fin = 'line 8 : attribution requires `finalize´',
    fin = 'line 8 : attribution to pointer with greater scope',
    --fin = 'line 11 : pointer access across `await´',
}

Test { [[
class Unit with
    event int move;
do
end
var Unit*? u;
do
    pool Unit[] units;
    u = spawn Unit in units;  // deveria falhar aqui!
    await 1min;
end
emit u:move => 0;
escape 2;
]],
    fin = 'line 11 : unsafe access to pointer "u" across `await´',
}

Test { [[
class T with do end;
pool T[] ts;
loop t in ts do
end
escape 1;
]],
    run = 1,
}

-- PAUSE/IF w/ ORGS

Test { [[
input void OS_START;
input int A,B;

class T with
    event int e;
do
    var int v = await A;
    emit e => v;
end

event int a;

var int ret;
par/or do
    pause/if a do
        var T t;
        ret = await t.e;
    end
with
    await OS_START;
    emit a => 1;
    await B;
    emit a => 0;
    await FOREVER;
end
escape ret;
]],
    run = { ['10~>A; 1~>B; 5~>A'] = 5 },
}

Test { [[
input void A,X, OS_START;
event int a;//=0;
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
    await OS_START;
    emit a => 1;
    await X;
    emit a => 0;
    ret = 10;
    await FOREVER;
end
escape ret;
]],
    _ana = {
        reachs = 1,
        --acc = 3,  -- TODO
    },
    run = { ['~>A; ~>X; ~>A']=12 }
}

Test { [[
native _V;
native do
    int V = 0;
end

class T with
    var int c;
do
    finalize with
        _V = _V + c;
    end
    await FOREVER;
end

par/or do
    do
        pool T[] ts;
        loop i do
            spawn T in ts with
                this.c = i;
            end;
            await 1s;
        end
    end
with
    await 5s;
end

escape _V;
]],
    run = { ['~>5s']=15 },
}

Test { [[
native _V;
native do
    int V = 0;
end

class T with
    var int c;
do
    finalize with
        _V = _V + c;
    end
    await FOREVER;
end

input int P;
event int pse;

par/or do
    pause/if pse do
        do
            pool T[] ts;
            loop i do
                spawn T in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse  =>  v;
    end
with
    await 5s;
end

escape _V;
]],
    wrn = true,
    run = { ['~>2s;1~>P;~>2s;0~>P;~>1s']=6 },
}

Test { [[
native _V;
native do
    int V = 0;
end

class T with
    var int c;
do
    finalize with
        _V = _V + c;
    end
    await FOREVER;
end

input int P;
event int pse;

par/or do
    do
        pool T[] ts;
        loop i do
            pause/if pse do
                spawn T in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse  =>  v;
    end
with
    await 5s;
end

escape _V;
]],
    run = { ['~>2s;1~>P;~>2s;0~>P;~>1s']=6 },
}

Test { [[
native _V;
native do
    int V = 0;
end

class T with
    var int c;
do
    finalize with
        _V = _V + c;
    end
    await 5s;
    _V = _V + 10;
end

input int P;
event int pse;

par/or do
    do
        pool T[] ts;
        loop i do
            pause/if pse do
                spawn T in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse  =>  v;
    end
with
    await 5s;   // terminates before first spawn
with
    await 5s;   // terminates before first spawn
end

escape _V;
]],
    run = { ['~>2s;1~>P;~>2s;0~>P;~>2s']=16 },
}
Test { [[
native _V;
native do
    int V = 0;
end

class T with
    var int c;
do
    finalize with
        _V = _V + c;
    end
    await 5s;
    _V = _V + 10;
end

input int P;
event int pse;

par/or do
    pause/if pse do
        do
            pool T[] ts;
            loop i do
                spawn T in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse  =>  v;
    end
with
    await 5s;   // terminates before first spawn
end

escape _V;
]],
    wrn = true,
    run = { ['~>2s;1~>P;~>2s;0~>P;~>1s']=6 },
}

Test { [[
native _V;
native do
    int V = 0;
end

class T with
    var int c;
do
    finalize with
        _V = _V + c;
    end
    await 5s;
    _V = _V + 10;
end

input int P;
event int pse;

par/or do
    do
        pool T[] ts;
        loop i do
            pause/if pse do
                spawn T in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse  =>  v;
    end
with
    await 6s;
end

escape _V;
]],
    run = { ['~>2s;1~>P;~>2s;0~>P;~>2s']=30 },
}

Test { [[
native _V;
native do
    int V = 0;
end

class T with
    var int c;
do
    finalize with
        _V = _V + c;
    end
    await 5s;
    _V = _V + 10;
end

input int P;
event int pse;

par/or do
    pause/if pse do
        do
            pool T[] ts;
            loop i do
                spawn T in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse  =>  v;
    end
with
    await 5s;
end

escape _V;
]],
    wrn = true,
    run = { ['~>2s;1~>P;~>2s;0~>P;~>1s']=6 },
}

Test { [[
event int a;
input void A;
var int v = 0;

class T with
    event int a;
do
    pause/if a do
        await FOREVER;
    end
end

par/or do
    pause/if a do
        await FOREVER;
    end
with
    loop do
        await 1s;
        v = v + 1;
    end
with
    var T t;
    var int pse_ = 0;
    loop do
        await 1s;
        pse_ = not pse_;
        emit a => pse_;
        emit t.a => pse_;
    end
with
    await A;
end
escape v;
]],
    _ana = { acc=0 },
    run = { ['~>10s;~>A']=10 }
}

Test { [[
class T with
    var int v;
do
    await FOREVER;
end
var T*? t = spawn T with
             this.v = 10;
           end;
//free(t);
escape t:v;
]],
    run = 10,
}

-- kill org inside iterator
Test { [[
class T with
    event void e;
do
    await e;
end

pool T[] ts;

var int ret = 1;

spawn T in ts;
async do end;

loop t in ts do
    watching *t do
        ret = ret + 1;
        emit t:e;
        ret = ret + 1;
    end
end

escape ret;
]],
    run = 2,
}

Test { [[
class T with
    var T* t;
    event void e;
do
    watching *t do
        await e;
    end
end

pool T[] ts;

var int ret = 1;

var T*? t1 = spawn T in ts with
                this.t = &this;
            end;
var T*? t2 = spawn T in ts with
                this.t = t1;
            end;

async do end;

loop t in ts do
    watching *t do
        ret = ret + 1;
        emit t:e;
        ret = ret + 1;
    end
end

escape ret;
]],
    run = 2,
}

Test { [[
interface I with
    var int v;
    event void e;
end
class T with
    interface I;
do
    await e;
end
pool T[] ts;
var int ret = 0;
do
    spawn T in ts with
        this.v = 10;
    end;
    async do end;
    loop t in ts do
        watching *t do
            ret = ret + t:v;
            emit t:e;
            ret = ret + t:v;
        end
    end
end
escape ret;
]],
    run = 10,
}

Test { [[
class T with
    event void e;
do
    await e;
end

pool T[] ts;

var int ret = 1;

spawn T in ts;
spawn T in ts;
async do end;

native @pure _printf();
loop t1 in ts do
    loop t2 in ts do
        ret = ret + 1;
    end
end

escape ret;
]],
    run = 5,
}
Test { [[
class T with
    event void e;
do
    await e;
end

pool T[] ts;

var int ret = 1;

spawn T in ts;
spawn T in ts;
async do end;

native @pure _printf();
loop t1 in ts do
    loop t2 in ts do
        ret = ret + 1;
        kill *t2;
    end
end

escape ret;
]],
    run = 3,
}
Test { [[
class T with
    event void e;
do
    await e;
end

pool T[] ts;

var int ret = 1;

spawn T in ts;
spawn T in ts;
async do end;

native @pure _printf();
loop t1 in ts do
    watching *t1 do
        loop t2 in ts do
            watching *t2 do
                ret = ret + 1;
                kill *t1;
            end
        end
    end
end

escape ret;
]],
    run = 3,
}

Test { [[
class T with
    event void e;
do
    await e;
end

pool T[] ts;

var int ret = 1;

spawn T in ts;
spawn T in ts;
async do end;

loop t1 in ts do
    watching *t1 do
        loop t2 in ts do
            ret = ret + 1;
            emit t1:e;
            ret = ret + 1;
        end
    end
end

escape ret;
]],
    run = 3,
}

-- TODO pause hierarquico dentro de um org
-- SDL/samples/sdl4.ceu

-- INTERFACES / IFACES / IFCES

Test { [[
interface A with
    var int a1,a2;
end
interface B with
    var int b1,b2;
end
interface C with
    var int c1,c2;
end
interface I with
    interface A;
    interface B,C;
end
class T with
    interface I;
do
end
var T t with
    this.a1 = 1;
    this.a2 = 2;
    this.b1 = 3;
    this.b2 = 4;
    this.c1 = 5;
    this.c2 = 6;
end;
var I*? i = &t;
escape i:a1+i:a2+i:b1+i:b2+i:c1+i:c2;
]],
    run = 21,
}
Test { [[
interface A with
    var int a1,a2;
end
interface B with
    var int b1,b2;
end
interface C with
    var int c1,c2;
end
interface I with
    interface A;
    interface B,C;
end
class T with
    interface I;
do
end
var T t with
    this.a1 = 1;
    this.a2 = 2;
    this.b1 = 3;
    this.b2 = 4;
    this.c1 = 5;
    this.c2 = 6;
end;
var I* i = &t;
escape i:a1+i:a2+i:b1+i:b2+i:c1+i:c2;
]],
    run = 21,
}
Test { [[
interface I with
    var int a;
end
class T with
do end
do
    pool T[] ts;
    loop i in ts do
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
native _ptr;
native do
    void* ptr;
end
interface I with
    event void e;
end
var J* i = _ptr;
escape 10;
]],
    env = 'line 8 : undeclared type `J´',
}

Test { [[
native _ptr;
native do
    void* ptr;
end
interface I with
    event void e;
end
var I* i = _ptr;
escape 10;
]],
    --env = 'line 8 : invalid attribution',
    todo = 'i=ptr',
    run = 10,
}

Test { [[
native _ptr;
native do
    void* ptr;
end
interface I with
    event int e;
end
var I* i = (I*) _ptr;
escape 10;
]],
    run = 10;
}

-- CAST

Test { [[
native do ##include <assert.h> end
native _assert();

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
var T1* x1 = (T1*) t;
_assert(x1 != null);

t = &t1;
var T2* x2 = (T2*) t;
_assert(x2 == null);

escape 10;
]],
    run = 10;
}

Test { [[
interface I with
end
class T with
    var I* parent;
do
end
class U with
do
    var T move with
        this.parent = &outer;
    end;
end
escape 1;
]],
    run = 1,
}

Test { [[
interface I with
    event int a;
end
escape 10;
]],
    run = 10;
}

Test { [[
interface I with
end
var I[10] a;
]],
    env = 'line 3 : cannot instantiate an interface',
}

Test { [[
interface I with
    var int i;
end

interface J with
    interface I;
end

var I* i;
var J* j = i;

escape 1;
]],
    run = 1,
}


-- GLOBAL

Test { [[
input void OS_START;
interface Global with
    event int a_;
end
event int a_;
class U with
    event int a_;
do
end
class T with
    event int a_;
    var Global* g;
do
    await OS_START;
    emit g:a_  =>  10;
end
var U u;
var Global* g = &u;
var T t;
t.g = &u;
var int v = await g:a_;
escape v;
]],
    todo = 'watching',
    run = 10,
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
escape 1;
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
    var int* c=null;
    global:a = c;
end
escape 1;
]],
    run = 1,
    fin = 'line 6 : attribution to pointer with greater scope',
    --fin = 'line 6 : organism pointer attribution only inside constructors',
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
    await 1s;
    global:a = c;
end
escape 1;
]],
    fin = 'line 6 : attribution to pointer with greater scope',
    --fin = 'line 6 : organism pointer attribution only inside constructors',
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
escape 1;
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
escape 1;
]],
    fin = 'line 7 : attribution to pointer with greater scope',
    --fin = 'line 7 : organism pointer attribution only inside constructors',
}

Test { [[
input void OS_START;
interface Global with
    event int a;
end
event int a;
class T with
    event int a;
do
    await OS_START;
    emit global:a  =>  10;
end
var T t;
var int v = await a;
escape v;
]],
    run = 10,
}
Test { [[
input void OS_START;
interface Global with
    event int a;
    var int aa;
end
event int a;
var int aa;
class T with
    event int a;
    var int aa;
do
    aa = await global:a;
end
var T t;
await OS_START;
emit a  =>  10;
escape t.aa;
]],
    run = 10,
}

Test { [[
class T with
    var int a;
do
    a = global:a;
end
var int a = 10;
var T t;
input void OS_START;
await OS_START;
t.a = t.a + a;
escape t.a;
]],
    env = 'line 4 : interface "Global" is not defined',
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
input void OS_START;
await OS_START;
    t.a = t.a + a;
    escape t.a;
end
]],
    env = 'line 1 : interface "Global" must be implemented by class "Main"',
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
input void OS_START;
await OS_START;
    t.a = t.a + a;
    escape t.a;
end
]],
    run = 20,
}

Test { [[
native @nohold _attr();
native do
    void attr (void* org) {
        IFC_Global_a() = CEU_T_a(org) + 1;
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
input void OS_START;
await OS_START;
    t.a = t.a + a;
    escape t.a + global:a;
end
]],
    todo = 'IFC accs',
    run = 53,
}

Test { [[
native do
    int V = 10;
end

interface Global with
    event void e;
end
event void e;

class T with
do
    emit global:e;
    _V = 1;
end

par/or do
    event void a;
    par/or do
        await 1s;
        do
            var T t;
            emit a;
            _V = 1;
        end
    with
        await global:e;
    with
        await a;
    end
    await 1s;
with
    async do
        emit 1s;
    end
end
escape _V;
]],
    run = 10,
}
Test { [[
interface I with
    event int a;
end
var I t;
escape 10;
]],
    env = 'line 4 : cannot instantiate an interface',
}

Test { [[
interface Global with
    event void e;
end
event void e;

class T with
do
    emit global:e;
end

var int ret = 0;
par/or do
    await 1s;
    do
        var T t;
        await FOREVER;
    end
with
    await global:e;
    ret = 1;
with
    async do
        emit 1s;
    end
end
escape ret;
]],
    run = 1,
}
Test { [[
interface I with
    event int a;
end
var I[10] t;
escape 10;
]],
    env = 'line 4 : cannot instantiate an interface',
}

Test { [[
interface I with
    event int a;
end
var I*? t;
t = spawn I;
escape 10;
]],
    env = 'line 5 : cannot instantiate an interface',
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
escape 10;
]],
    env = 'line 11 : types mismatch',
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
escape 10;
]],
    env = 'line 12 : types mismatch',
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
escape 10;
]],
    env = 'line 12 : types mismatch',
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
escape 10;
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
escape 10;
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
escape 10;
]],
    env = 'line 16 : types mismatch',
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
escape 0;
]],
    env = 'line 6 : types mismatch',
}

Test { [[
input void OS_START;
class T with
    event int a;
    var int aa;
do
    aa = 10;
end

interface I with
    event int a;
    var int aa;
end
interface J with
    event int a;
    var int aa;
end

var I* i;
var T t;
i = &t;
var J* j = i;
escape i:aa + j:aa + t.aa;
]],
    run = 30,
}

Test { [[
input void OS_START;
class T with
    event int a;
    var int aa;
do
    aa = 10;
end

interface I with
    event int a;
    var int aa;
end
interface J with
    event int a;
    var int aa;
end

var I* i;
var T t;
i = &t;
var J* j = i;
await OS_START;
escape i:aa + j:aa + t.aa;
]],
    fin = 'line 23 : unsafe access to pointer "i" across `await´',
}

Test { [[
input void OS_START;
class T with
    var int v;
    var int* x;
    var int a;
do
    a = 10;
    v = 1;
end

interface I with
    var int a;
    var int v;
end
interface J with
    var int a;
end

var I* i;
var T t;
i = &t;
var J* j = i;
escape i:a + j:a + t.a + i:v + t.v;
]],
    run = 32,
}

Test { [[
input void OS_START;
class T with
    var int v;
    var int* x;
    var int a;
do
    a = 10;
    v = 1;
end

interface I with
    var int a;
    var int v;
end
interface J with
    var int a;
end

var I* i;
var T t;
i = &t;
var J* j = i;
await OS_START;
escape i:a + j:a + t.a + i:v + t.v;
]],
    fin = 'line 24 : unsafe access to pointer "i" across `await´',
    --run = 32,
}

Test { [[
class Sm with
do
end
interface Media with
    var Sm sm;
end
escape 10;
]],
    props = 'line 5 : not permitted inside an interface',
}
Test { [[
class Sm with
do
end
interface Media with
    var Sm* sm;
end
escape 10;
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
escape t.a;
]],
    adj = 'line 5 : interface "J" is not declared',
}

Test { [[
interface MenuGamesListener with
    event int ok_rm;
    event int ok_go;
end
class MenuGames with
    interface MenuGamesListener;
do
    var MenuGamesListener* lst = &this;
end
escape 1;
]],
    run = 1,
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
input void OS_START;
await OS_START;
escape t.a;
]],
    run = 10,
}

Test { [[
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
escape t._ins();
]],
    --env = 'line 13 : native function "CEU_T__ins" is not declared',
    env = 'line 13 : variable/event "_ins" is not declared',
}
Test { [[
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
escape i:_ins();
]],
    --env = 'line 13 : native function "CEU_I__ins" is not declared',
    env = 'line 13 : variable/event "_ins" is not declared',
}
Test { [[
class T with do end
class U with
    interface T;
do
end
escape 0;
]],
    adj = 'line 3 : interface "T" is not declared',
}

Test { [[
interface Global with
    var G* g;
end
var G* g;
escape 1;
]],
    env = 'line 2 : undeclared type `G´',
}

Test { [[
interface Global with
    event (G*,int) g;
end
event (G*,int) g;
escape 1;
]],
    --env = 'line 2 : undeclared type `G´',
    --run = 1,
    --gcc = '22:2: error: unknown type name ‘G’',
    gcc = 'error: unknown type name',
}

Test { [[
interface I with
    var _char c;
end
class T with
    interface I;
do
    this.c = 1;
end
var T t;
var I* i = &t;
escape i:c == 1;
]],
    run = 1,
}

-- XXX: T-vs-Opt

Test { [[
input _vldoor_t* T_VERTICAL_DOOR;
class T_VerticalDoor with
    var void* v;
do
end

do
    every door in T_VERTICAL_DOOR do
        spawn T_VerticalDoor with
            this.v = door;
        end;
    end
end
]],
    --env = 'line 11 : invalid attribution (void* vs _vldoor_t*)',
    --fin = 'line 11 : attribution to pointer with greater scope',
    --fin = 'line 9 : invalid block for awoken pointer "door"',
    _ana = {
        isForever = true,
    },
}

Test { [[
input _vldoor_t* T_VERTICAL_DOOR;
class T_VerticalDoor with
    var void* v;
do
end

do
    every door in T_VERTICAL_DOOR do
        spawn T_VerticalDoor with
            this.v = (void*)door;
        end;
    end
end
]],
    --fin = 'line 11 : attribution to pointer with greater scope',
    --fin = 'line 9 : invalid block for awoken pointer "door"',
    _ana = {
        isForever = true,
    },
}

Test { [[
class T with
    var void* v;
do
end

var T t;
t.v = null;
var void* ptr = null;
t.v = ptr;
escape 1;
]],
    --fin = 'line 9 : organism pointer attribution only inside constructors',
    --fin = 'line 9 : attribution to pointer with greater scope',
    run = 1,
}
Test { [[
class T with
    var void* v;
do
end

var T t with
    this.v = null;
end;
var void* ptr = null;
t.v = ptr;
escape 1;
]],
    --fin = 'line 10 : organism pointer attribution only inside constructors',
    --fin = 'line 9 : attribution to pointer with greater scope',
    run = 1,
}

Test { [[
class T with
    var void* v;
do
end

var T t, s;
t.v = null;
t.v = s.v;
escape 1;
]],
    --fin = 'line 8 : organism pointer attribution only inside constructors',
    run = 1,
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

escape 1;
]],
    --fin = 'line 10 : attribution requires `finalize´'
    fin = 'line 10 : attribution to pointer with greater scope',
    --fin = 'line 10 : organism pointer attribution only inside constructors',
}

Test { [[
native do
    void* v;
end
class T with
    var _void& ptr;
do
end
var T t with
    this.ptr = _v;
end;
escape 1;
]],
    run = 1,
}

Test { [[
class T with
    var char * str;
do
    str = "oioi";
    this.str = "oioi";
end
escape 1;
]],
    run = 1,
}

Test { [[
class T with
do
end
var int*& v;
var T*& t;
escape 1;
]],
    run = 1;
}

Test { [[
class T with
do
end
var int&* v;
var T&* t;
escape 1;
]],
    parser = 'line 4 : after `&´ : expected identifier',
}

Test { [[
class T with
    var char* str;
do
end

do
    spawn T with
        var char* s = "str";
        this.str = s;
    end;
end

escape 1;
]],
    run = 1,
}

Test { [[
class T with
    var int* v;
do
    *v = 1;
    await 1s;
    *v = 2;
end
escape 1;
]],
    fin = 'line 6 : unsafe access to pointer "v" across `await´',
}

Test { [[
interface Global with
    var int* a;
end
var int* a;
class T with
    var int* v;
do
end
var T t with
    this.v = global:a;
end;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
interface Global with
    var int* a;
end
var int* a = null;
class T with
    var int* v;
do
end
await OS_START;
var T t with
    this.v = global:a;
end;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
interface Global with
    var int* p;
end
var int i = 1;
var int* p = null;
await OS_START;
p = p;
escape *p;
]],
    fin = 'line 8 : unsafe access to pointer "p" across `await´',
}

Test { [[
input void OS_START;
interface Global with
    var int* p;
end
var int i = 1;
var int* p = null;
await OS_START;
p = &i;
escape *p;
]],
    run = 1,
}

Test { [[
input void OS_START;
class T with
    var int* p;
do
end
var int i = 1;
var T t with
    this.p = null;
end;
await OS_START;
t.p = &i;
escape *t.p;
]],
    fin = 'line 11 : unsafe access to pointer "p" across `await´',
}

Test { [[
native do
    void* V;
end
class T with
    function (void* v)=>void f;
do
    function (void* v)=>void f do
        _V := v;
    end
end
escape 1;
]],
    --fin = 'line 8 : invalid attribution',
    run = 1,
}

Test { [[
class Forwarder with
    var _pkt_t out;
do
end

native @nohold _memcpy();

input _pkt_t* RECEIVE;

every inc in RECEIVE do
    spawn Forwarder with
        _memcpy(&this.out, inc, inc:len);
    end;
end
]],
    _ana = {
        isForever = true,
    },
}

Test { [[
class Unit with
    var _SDL_Texture* tex;
do
end

interface Global with
    pool Unit[] all;
end

pool Unit[] all;

class Nest with
do
    spawn Unit in global:all with
        this.tex := _TEX_STORMTROOPER;
    end;
end
]],
    fin = 'line 15 : wrong operator',
}

-- TODO_TYPECAST

-- IFACES / IFCS / ITERATORS
Test { [[
interface I with end
class T with do end
pool T[] ts;
do
    loop i in ts do
        _f(i);
    end
end
]],
    fin = 'line 6 : call requires `finalize´',
}

Test { [[
interface I with end
class T with do end
pool T[] ts;
var I* p;
do
    loop i in ts do
        p = i;
    end
end
escape 1;
]],
    --fin = 'line 7 : attribution requires `finalize´',
    run = 1,
}

Test { [[
interface Unit with end
class CUnit with do end
pool CUnit[] us;
loop u in us do
end
escape 1;
]],
    run = 1,
}

Test { [[
class Unit with do end
pool Unit[] us;
var int ret = 1;
do
    loop u in us do
        ret = ret + 1;
    end
end
escape ret;
]],
    run = 1,
}

Test { [[
class Unit with do end
pool Unit[] us;
var Unit* p;
do
    loop i in us do
        p = i;
    end
end
escape 10;
]],
    run = 10;
}

Test { [[
class I with do end
pool I[] is;
native @nohold _f();
native do
    void f (void* p) {
    }
end
do
    loop i in is do
        _f(i);
    end
end
escape 10;
]],
    run = 10,
}

Test { [[
class I with do end
pool I[] is;
native _f();
native do
    void f (void* p) {
    }
end
do
    loop i in is do
        _f(i) finalize with nothing; end;
    end
end
escape 10;
]],
    run = 10,
}

Test { [[
interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
    await FOREVER;
end

pool T[] ts;
var int ret = 0;
do
    spawn T in ts with
        this.v = 1;
    end;
    spawn T in ts with
        this.v = 2;
    end;
    spawn T in ts with
        this.v = 3;
    end;

    loop i in ts do
        ret = ret + i:v;
    end
end
escape ret;
]],
    run = 6,
}

Test { [[
interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
    await FOREVER;
end

class U with
    var int z;
    var int v;
do
    await FOREVER;
end

var T t;
var U u;

var I* i1 = &t;
var I* i2 = (I*) &u;

native @pure _f();
native do
    void* f (void* org) {
        return org;
    }
end

var I* i3 = (I*) _f(&t);
var I* i4 = (I*) _f(&u);

var T* i5 = (T*) _f(&t);
var T* i6 = (T*) _f(&u);

escape i1==&t and i2==null and i3==&t and i4==null and i5==&t and i6==null;
]],
    run = 1,
}

Test { [[
interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
    await FOREVER;
end
pool T[] ts;

class U with
    var int z;
    var int v;
do
    await FOREVER;
end

var int ret = 0;
do
    spawn T with
        this.v = 1;
    end;
    spawn U with
        this.v = 2;
    end;
    spawn T in ts with
        this.v = 3;
    end;

    loop i in ts do
        ret = ret + i:v;
    end
end
escape ret;
]],
    run = 3,
}

Test { [[
interface I with
    var int v;
end

class T with
    interface I;
do
    await FOREVER;
end

pool I[] is;

var int ret = 0;

spawn T with
    this.v = 1;
end;

spawn T in is with
    this.v = 3;
end;

loop i in is do
    ret = ret + i:v;
end

escape ret;
]],
    run = 3,
}

Test { [[
interface I with
    var int v;
    event void inc;
end

pool I[] is;

class T with
    interface I;
do
    await FOREVER;
end

class U with
    interface I;
do
    await FOREVER;
end

var int ret = 0;
do
    spawn T with
        this.v = 1;
    end;
    spawn U in is with
        this.v = 2;
    end;
    spawn T in is with
        this.v = 3;
    end;

    loop i in is do
        ret = ret + i:v;
    end
end
escape ret;
]],
    run = 5,
}

Test { [[
interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
end
pool T[] ts;

var int ret = 1;
do
    loop i in ts do
        ret = ret + i:v;
    end
end
escape ret;
]],
    run = 1,
}

Test { [[
interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
end
pool T[] ts;

var int ret = 1;
do
    spawn T in ts with
        this.v = 1;
    end;
    spawn T in ts with
        this.v = 2;
    end;
    spawn T in ts with
        this.v = 3;
    end;

    loop i in ts do
        ret = ret + i:v;
    end
end
escape ret;
]],
    run = 1,
}

-- TODO: STACK
Test { [[
input void A,F;

interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
    await inc;
    this.v = v + 1;
end

pool T[] ts;
var int ret = 1;
do
    spawn T in ts with
        this.v = 1;
    end;
    spawn T in ts with
        this.v = 2;
    end;
    spawn T in ts with
        this.v = 3;
    end;

    loop i in ts do
        ret = ret + i:v;
        watching *i do
            emit i:inc;
            ret = ret + i:v;
        end
    end
end
escape ret;
]],
    --run = 7,
    run = 13,
}
Test { [[
input void A,F;

interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
    await inc;
    this.v = v + 1;
    await FOREVER;
end

pool T[] ts;
var int ret = 1;
do
    spawn T in ts with
        this.v = 1;
    end;
    spawn T in ts with
        this.v = 2;
    end;
    spawn T in ts with
        this.v = 3;
    end;

    loop i in ts do
        ret = ret + i:v;
        watching *i do
            emit i:inc;
            ret = ret + i:v;
        end
    end
end
escape ret;
]],
    --run = 7,
    run = 13,
}
Test { [[
input void A,F;

interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
    await inc;
    this.v = v + 1;
    await FOREVER;
end
pool T[] ts;

var int ret = 0;
do
    par/or do
        await F;
    with
        var int i=1;
        every 1s do
            spawn T in ts with
                this.v = i;
                i = i + 1;
            end;
        end
    with
        loop do
            await 1s;
            loop i in ts do
                watching *i do
                    emit i:inc;
                    ret = ret + i:v;
                end
            end
        end
    end
end
escape ret;
]],
    --run = { ['~>3s;~>F'] = 16 },
    run = { ['~>3s;~>F'] = 13 },
}

Test { [[
class T with
    var int a;
do
end
pool T[] ts;

do
    loop t in ts do
        t:a = 1;
    end
end

escape 10;
]],
    run = 10;
}

-- FUNCTIONS

Test { [[
function (int v)=>int f do
    return v+1;
end
escape f();
]],
    env = 'line 4 : arity mismatch',
}

Test { [[
function (int v)=>int f do
    return v+1;
end
var int* ptr;
escape f(ptr);
]],
    env = 'line 5 : wrong argument #1',
}

Test { [[
function (int v)=>int f do
    return v+1;
end
escape f(1);
]],
    run = 2,
}

Test { [[
function (void) f;
escape 1;
]],
    parser = 'line 1 : after `)´ : expected `=>´',
}

Test { [[
function (void) => void f
escape 1;
]],
    parser = 'line 1 : after `f´ : expected `;´'
}

Test { [[
function (void) => void f;
escape 1;
]],
    run = 1,
}

Test { [[
function void => (void) f;
escape 1;
]],
    parser = 'line 1 : after `function´ : expected param list',
    --parser = 'line 1 : after `=>´ : expected type',
}

Test { [[
function (void) => void f;
escape 1;
]],
    run = 1,
}

Test { [[
function (int) => void f do
    return 1;
end
escape 1;
]],
    env = 'line 1 : missing parameter identifier',
}

Test { [[
function (void) => void f do
    event void i;
    emit i;
    await i;
end
escape 1;
]],
    props = 'line 3 : not permitted inside `function´',
}

Test { [[
function (void) => void f do
    var int a = 1;
end
escape 1;
]],
    run = 1,
}

Test { [[
function (void) => void f do
    return;
end
escape 1;
]],
    run = 1,
}

Test { [[
function (void) => void f do
    return 1;
end
escape 1;
]],
    gcc = 'error: ‘return’ with a value, in function returning void',
}

Test { [[
function (void) => void f do
    return;
end
escape 1;
]],
    run = 1,
}

Test { [[
do
    return 1;
end
escape 1;
]],
    props = 'line 2 : not permitted outside a function',
}

Test { [[
event int a;
a = 1;
escape 1;
]],
    env = 'types mismatch',
}

Test { [[
function (void)=>int f do
    return 1;
end
escape f();
]],
    run = 1,
}

Test { [[
function (void)=>int f do
    return 1;
end
escape call f();
]],
    todo = 'call?',
    run = 1,
}

Test { [[
function (void) => int f;
function (int)  => int f;
escape 1;
]],
    env = 'line 2 : function declaration does not match the one at "tests.lua:1"',
}

Test { [[
function (void) => int f;
function (int)  => int f do end
escape 1;
]],
    env = 'line 2 : function declaration does not match the one at "tests.lua:1"',
}

Test { [[
function (void) => int f;
function (void) => int f do return 1; end
escape 1;
]],
    run = 1,
}

Test { [[
function (void,int) => int f;
escape 1;
]],
    env = 'line 1 : invalid type',
}

Test { [[
function (int) => void f;
escape 1;
]],
    run = 1,
}

Test { [[
function (int,int) => int f;
function (int a, int b) => int f do
    return a + b;
end
escape 1;
]],
    run = 1,
}

Test { [[
function (int,int) => int f;
function (int a, int b) => int f do
    return a + b;
end
escape f(1,2);
]],
    run = 3,
}

Test { [[
function (int x)=>int fff do
    return x + 1;
end

var int x = fff(10);

input void OS_START;
await OS_START;

escape fff(x);
]],
    run = 12,
}
Test { [[
output (int*,char*)=>void LUA_GETGLOBAL;
function @rec (int* l)=>void load do
    loop i do
    end
end
call/rec load(null);

escape 1;
]],
    tight = 'tight loop',
    --run = 1,
}

Test { [[
native do
    ##define ceu_out_call_LUA_GETGLOBAL
end

output (int*,char*)=>void LUA_GETGLOBAL;
function @rec (int* l)=>void load do
    // TODO: load file
    call LUA_GETGLOBAL => (l, "apps");              // [ apps ]
    call LUA_GETGLOBAL => (l, "apps");              // [ apps ]
    loop i do
        var int has = 1;
        if has==0 then
            break;                                  // [ apps ]
        end
        _ceu_out_log("oi");
    end

    /*
    var int len = (call LUA_OBJLEN => (l, -1));     // [ apps ]
    loop i in len do
        call LUA_RAWGETI => (l, -1);                // [ apps | apps[i] ]
    end
    */
end
call/rec load(null);

escape 1;
]],
    tight = 'tight loop',
    run = 1,
}

-- METHODS

Test { [[
class T with
    var int a;
    function (void)=>int f;
do
    var int b;
    function (void)=>int f do
        return b;
    end
    a = 1;
    b = 2;
end

var T t;
escape t.a + t.f();
]],
    run = 3,
}

Test { [[
interface I with
    var int v;
    native _f(), _a;      // TODO: refuse _a
end
escape 10;
]],
    parser = 'line 2 : after `;´ : expected declaration',
    --run = 10,
}

Test { [[
native do
    int V = 0;
end
class T with
do
    var int x;
    this.x = 10;
    _V = this.x;
end
var T t;
escape _V;
]],
    run = 10,
}

Test { [[
class T with do end;

function (void)=>void fff do
    var T* ttt = null;
end

do
    var int xxx = 10;
    fff();
    escape xxx;
end
]],
    run = 10,
}

Test { [[
native do
    int V = 0;
end
class T with
    function (int a, int b)=>int f do
        return a + b;
    end
do
    _V = _V + f(1,2) + this.f(3,4);
end
var T[2] ts;
escape _V;
]],
    parser = 'line 5 : after `f´ : expected `;´',
}

Test { [[
native do
    int V = 0;
end
class T with
do
    function (int a, int b)=>int f do
        return a + b;
    end
    _V = _V + f(1,2) + this.f(3,4);
end
var T[2] ts;
escape _V;
]],
    run = 20,
}

Test { [[
native do
    int V = 0;
end
class T with
do
    var int v=0;
    function (int a, int b)=>void f do
        this.v = this.v + a + b;
    end
    f(1,2);
    this.f(3,4);
    _V = _V + v;
end
var T[2] ts;
escape _V;
]],
    run = 20,
}

Test { [[
class T with
    var int a;
    function (void)=>int f;
do
    var int b;
    function (void)=>int f do
        return this.b;
    end
    a = 1;
    b = 2;
end

var T t;
escape t.a + t.f();
]],
    run = 3,
}
Test { [[
class T with
    var int a;
    function (void)=>int f do
        return this.b;
    end
do
    var int b;
    a = 1;
    b = 2;
end

var T t;
escape t.a + t.f();
]],
    parser = 'line 3 : after `f´ : expected `;´',
}

Test { [[
interface I with
    var int v;
    function (void)=>void f;
end
escape 10;
]],
    run = 10,
}

Test { [[
class T with
    var int v;
    function (int)=>void f;
do
    v = 50;
    this.f(10);

    function (int v)=>int f do
        this.v = this.v + v;
        return this.v;
    end
end

var T t;
input void OS_START;
await OS_START;
escape t.v + t.f(20) + t.v;
]],
    wrn = true,
    env = 'line 8 : function declaration does not match the one at "tests.lua:3"',
}

Test { [[
class T with
    var int v;
    function (int)=>int f;
do
    v = 50;
    this.f(10);

    function (int v)=>int f do
        this.v = this.v + v;
        return this.v;
    end
end

var T t;
input void OS_START;
await OS_START;
escape t.v + t.f(20) + t.v;
]],
    wrn = true,
    run = 220,
}

Test { [[
interface I with
    function (void)=>int f;
    function (void)=>int f1;
end

class T with
    interface I;
do
    function (void)=>int f do
        return this.f1();
    end
    function (void)=>int f1 do
        return 1;
    end
end

var T t;
var I* i = &t;
escape t.f() + i:f();
]],
    tight = 'line 9 : function must be declared with `recursive´',
}

Test { [[
interface I with
    function (void)=>int f1;
    function (void)=>int f;
end

class T with
    interface I;
do
    function (void)=>int f1 do
        return 1;
    end
    function (void)=>int f do
        return this.f1();
    end
end

var T t;
var I* i = &t;
escape t.f() + i:f();
]],
    run = 2,
}

Test { [[
interface I with
    function (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function (int v)=>int g do
        if (v == 1) then
            return 1;
        end
        return v * i:g(v-1);
    end
end

var T t;
var I* i = &t;
t.i = i;
escape i:g(5);
]],
    --run = 120,
    tight = 'line 9 : function must be declared with `recursive´',
}

Test { [[
interface I with
    function @rec (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function (int v)=>int g do
        if (v == 1) then
            return 1;
        end
        return v * i:g(v-1);
    end
end

var T t;
var I* i = &t;
t.i = i;
escape i:g(5);
]],
    --run = 120,
    env = 'line 9 : function declaration does not match the one at "tests.lua:2"',
}

Test { [[
interface I with
    function (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function @rec (int v)=>int g do
        if (v == 1) then
            return 1;
        end
        return v * i:g(v-1);
    end
end

var T t;
var I* i = &t;
t.i = i;
escape i:g(5);
]],
    --run = 120,
    tight = 'line 9 : function must be declared with `recursive´',
}

Test { [[
interface I with
    function @rec (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function @rec (int v)=>int g do
        if (v == 1) then
            return 1;
        end
        return v * i:g(v-1);
    end
end

var T t;
var I* i = &t;
t.i = i;
escape i:g(5);
]],
    --run = 120,
    tight = 'line 13 : `call/rec´ is required for "g"',
}

Test { [[
interface I with
    function @rec (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function @rec (int v)=>int g do
        return 1;
    end
end

var T t;
var I* i = &t;
t.i = i;
escape i:g(5);
]],
    tight = 'line 9 : function may be declared without `recursive´',
    --tight = 'line 17 : `call/rec´ is required for "g"',
}
Test { [[
interface I with
    function @rec (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function @rec (int v)=>int g do
        return 1;
    end
end

var T t;
var I* i = &t;
t.i = i;
escape i:g(5);
]],
    wrn = true,
    tight = 'line 17 : `call/rec´ is required for "g"',
}

Test { [[
interface I with
    function @rec (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function @rec (int v)=>int g do
        return v;
    end
end

var T t;
var I* i = &t;
t.i = i;
escape call/rec i:g(5);
]],
    --fin = 'line 16 : organism pointer attribution only inside constructors',
    --fin = 'line 16 : attribution to pointer with greater scope',
    --tight = 'line 9 : function may be declared without `recursive´',
    wrn = true,
    run = 5,
}

Test { [[
interface I with
    function @rec (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function @rec (int v)=>int g do
        return v;
    end
end

var T t;
var I* i = &t;
t.i = i;
escape call/rec i:g(5);
]],
    --fin = 'line 16 : organism pointer attribution only inside constructors',
    --tight = 'line 9 : function may be declared without `recursive´',
    wrn = true,
    run = 5,
}

Test { [[
interface I with
    function (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function (int v)=>int g do
        return 1;
    end
end

var T t;
var I* i = &t;
t.i = i;
escape i:g(5);
]],
    --fin = 'line 16 : organism pointer attribution only inside constructors',
    --fin = 'line 16 : attribution to pointer with greater scope',
    run = 1,
}

Test { [[
interface I with
    function (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function (int v)=>int g do
        return 1;
    end
end

var T t;
var I* i = &t;
t.i = i;
escape i:g(5);
]],
    --fin = 'line 16 : organism pointer attribution only inside constructors',
    run = 1,
}

Test { [[
interface I with
    function (int)=>int g;
end

class U with
    interface I;
    var I* i;
do
    function (int v)=>int g do
        return 1;
    end
end

class T with
    interface I;
    var I* i;
do
    function (int v)=>int g do
        if (v == 1) then
            return 1;
        end
        return v * i:g(v-1);
    end
end

var T t;
var I* i1 = &t;
t.i = i1;

var U u;
var I* i2 = &u;
t.i = i2;

escape i1:g(5) + i2:g(5);
]],
    --run = 120,
    tight = 'line 18 : function must be declared with `recursive´',
}

Test { [[
interface I with
    function (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function (int v)=>int g do
        if (v == 1) then
            return 1;
        end
        return v * i:g(v-1);
    end
end

class U with
    interface I;
    var I* i;
do
    function (int v)=>int g do
        return 1;
    end
end

var T t;
var I* i1 = &t;
t.i = i1;

var U u;
var I* i2 = &u;
t.i = i2;

escape i1:g(5) + i2:g(5);
]],
    --run = 120,
    tight = 'line 9 : function must be declared with `recursive´',
}


Test { [[
interface I with
    function @rec (int)=>int g;
end

class T with
    interface I;
    var I* i;
do
    function @rec (int v)=>int g do
        if (v == 1) then
            return 1;
        end
        return v * i:g(v-1);
    end
end

var T t;
var I* i = &t;
t.i = i;
escape i:g(5);
]],
    tight = 'line 13 : `call/rec´ is required for "g"',
    --run = 120,
}

Test { [[
native do
    typedef int (*f_t) (int v);
end

class T with
    var int ret1, ret2;
    function (int)=>int f1;
    var _f_t f2;
do
    native do
        int f2 (int v) {
            return v;
        }
    end

    function (int v)=>int f1 do
        return v;
    end

    ret1 = this.f1(1);
    ret2 = this.f2(2);
end

var T t with
    this.f2 = _f2;
end;
escape t.ret1 + t.ret2;
]],
   --fin = 'line 25 : attribution to pointer with greater scope',
    run = 3,
}

Test { [[
native do
    typedef int (*f_t) (int v);
end

class T with
    var int ret1, ret2;
    function (int)=>int f1;
    var _f_t f2;
do
    native do
        int f2 (int v) {
            return v;
        }
    end

    function (int v)=>int f1 do
        return v;
    end

    ret1 = this.f1(1);
    ret2 = this.f2(2);
end

var T t with
    this.f2 = _f2;
end;
escape t.ret1 + t.ret2;
]],
    run = 3,
}

Test { [[
interface I with
    var int v;
    function (void)=>void ins;
end

class T with
    var int v;
do
end

var T t;
    t.v = 10;
var I* i = &t;
escape i:_ins() + t._ins();;
]],
    --env = 'line 14 : native function "CEU_T__ins" is not declared',
    env = 'line 13 : types mismatch (`I*´ <= `T*´)',
}

Test { [[
interface I with
    var int v;
    function (void)=>int ins;
end

class T with
    interface I;
    //var int v;
    //native @nohold _ins();
do
    function (void)=>int ins do
        return v;
    end
end

var T t;
    t.v = 10;
var I* i = &t;
escape i:ins() + t.ins();
]],
    run = 20,
}

Test { [[
interface F with
    function (void)=>void f;
    var int i=10;
end
]],
    env = 'line 3 : invalid attribution',
}

Test { [[
interface F with
    var int i;
    function (int i)=>void f;
end

class T with
    var int i=10;   // 1
    interface F;
do
    this.f(1);
    function (int i)=>void f do
        this.i = this.i + i;
    end
end

var T t1;

var F* f = &t1;
f:f(3);

escape t1.i + f:i;
]],
    wrn = true,
    run = 28,
}

Test { [[
interface F with
    var int i;
    function (int)=>void f;
end

class T with
    interface F;
    var int i=10;   // 2
do
    this.f(1);
    function (int i)=>void f do
        this.i = this.i + i;
    end
end

var T t1;

var F* f = &t1;
f:f(3);

escape t1.i + f:i;
]],
    wrn = true,
    run = 28,
}

Test { [[
native do
    void* V;
end
function (void* v)=>void f do
    _V = v;
end
escape 1;
]],
    fin = 'line 5 : attribution to pointer with greater scope',
    --fin = 'line 5 : invalid attribution',
}

Test { [[
native do
    void* V;
end
function (void* v)=>void f do
end
escape 1;
]],
    -- function can be "@nohold v"
    run = 1,
}

Test { [[
native do
    void* V;
end
class T with
    function (void* v)=>void f;
do
    function (void* v)=>void f do
        _V = v;
    end
end
escape 1;
]],
    --fin = 'line 8 : invalid attribution',
    fin = 'line 8 : attribution to pointer with greater scope',
}

Test { [[
class T with
    var void* v;
    function (void* v)=>void f;
do
    function (void* v)=>void f do
    end
end
var T t;
t.f(null);
escape 1;
]],
    -- function can be "@nohold v"
    wrn = true,
    run = 1,
}

Test { [[
class T with
    var void* a;
    function (void* v)=>void f;
do
    function (void* v)=>void f do
        var void* a = v;
    end
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
class T with
    var void* a;
    function (void)=>void f;
do
    function (void)=>void f do
        var void* v;
        a = v;
    end
end
escape 1;
]],
    -- not from paramter
    fin = 'line 7 : attribution to pointer with greater scope',
}
Test { [[
class T with
    var void* a;
    function (void* v)=>void f;
do
    function (void* v)=>void f do
        a = v;
    end
end
escape 1;
]],
    -- function must be "@hold v"
    fin = 'line 6 : attribution to pointer with greater scope',
    --fin = ' line 6 : parameter must be `hold´',
}
Test { [[
class T with
    var void* a;
    function (void* v)=>void f;
do
    function (void* v)=>void f do
        a := v;
    end
end
escape 1;
]],
    -- function must be "@hold v"
    fin = ' line 6 : parameter must be `hold´',
}
Test { [[
class T with
    var void* a;
    function (@hold void* v)=>void f;
do
    function (@hold void* v)=>void f do
        a := v;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
class T with
    var void* v;
    function (void* v)=>void f;
do
    function (@hold void* v)=>void f do
        this.v = v;
    end
end
escape 1;
]],
    wrn = true,
    env = 'line 5 : function declaration does not match the one at "tests.lua:3"',
}

Test { [[
class T with
    var void* v;
    function (@hold void* v)=>void f;
do
    function (@hold void* v)=>void f do
        this.v := v;
    end
end
var void* v;
var T t;
t.f(null);
t.f(v);
do
    var void* v;
    t.f(v);
end
escape 1;
]],
    wrn = true,
    -- function must be "@hold v" and call must have fin
    fin = 'line 12 : call requires `finalize´',
    --fin = 'line 6 : organism pointer attribution only inside constructors',
}

Test { [[
class T with
    var void* v;
    function (@hold void* v)=>void f;
do
    function (@hold void* v)=>void f do
        this.v := v;
    end
end
var void* v;
var T t;
t.f(null);
t.f(v);
do
    var void* v;
    t.f(v)
        finalize with
            nothing;
        end;
end
escape 1;
]],
    wrn = true,
    -- function must be "@hold v" and call must have fin
    fin = 'line 12 : call requires `finalize´',
    --fin = 'line 6 : organism pointer attribution only inside constructors',
}

Test { [[
native do
    void* V;
end
function (void* v)=>void f do
    _V := v;
end
var void* x;
f((void*)5);
escape _V==(void*)5;
]],
    fin = 'line 5 : parameter must be `hold´',
    --fin = 'line 5 : invalid attribution',
    --run = 1,
}

Test { [[
native do
    void* V;
end
function (@hold void* v)=>void f do
    _V := v;
end
var void* x;
f((void*)5)
    finalize with nothing; end;
escape _V==(void*)5;
]],
    fin = 'line 8 : invalid `finalize´',
}

Test { [[
native do
    int V;
end
function (int v)=>void f do
    _V = v;
end
var void* x;
f(5);
escape _V==5;
]],
    run = 1,
}

Test { [[
interface I with
    function (void)=>void f;
end

class T with
    interface I;
    function @rec (void)=>void f;
do
    function @rec (void)=>void f do
        if 0 then
            call/rec this.f();
        end
    end
end

var T t;
call/rec t.f();

var I* i = &t;
call i:f();

escape 1;
]],
    env = 'line 2 : function declaration does not match the one at "tests.lua:7"',
    --tight = 'line 2 : function must be declared with `recursive´',
}

Test { [[
interface I with
    function @rec (void)=>void f;
end

class T with
    interface I;
    function @rec (void)=>void f;
do
    function @rec (void)=>void f do
        if 0 then
            call/rec this.f();
        end
    end
end

var T t;
call/rec t.f();

var I* i = &t;
call i:f();

escape 1;
]],
    tight = 'line 20 : `call/rec´ is required for "f"',
}

Test { [[
interface I with
    function @rec (void)=>void f;
end

class T with
    interface I;
    function @rec (void)=>void f;
do
    function @rec (void)=>void f do
        if 0 then
            call/rec this.f();
        end
    end
end

var T t;
call/rec t.f();

var I* i = &t;
call/rec i:f();

escape 1;
]],
    run = 1,
}

Test { [[
interface I with
    function @rec (void)=>void f;
end

class T with
    interface I;
    function (void)=>void f; // ignored
do
    function (void)=>void f do
    end
end

var T t;
call t.f();

var I* i = &t;
call/rec i:f();

escape 1;
]],
    wrn = true,
    --tight = 'line 9 : function may be declared without `recursive´',
    run = 1,
}

Test { [[
interface I with
    function @rec (void)=>void f;
end

class T with
    function (void)=>void f;
    interface I;
do
    function (void)=>void f do
    end
end

var T t;
call t.f();

var I* i = &t;
call/rec i:f();

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
function (int v)=>int f;
function (int v)=>int f do
    if v == 0 then
        return 1;
    end
    return v*f(v-1);
end
escape f(5);
]],
    tight = 'line 2 : function must be declared with `recursive´',
    --run = 120,
}
Test { [[
function @rec (int v)=>int f;
function (int v)=>int f do
    if v == 0 then
        return 1;
    end
    return v*f(v-1);
end
escape f(5);
]],
    env = 'line 2 : function declaration does not match the one at "tests.lua:1"',
    --run = 120,
}
Test { [[
function @rec (int v)=>int f;
function @rec (int v)=>int f do
    if v == 0 then
        return 1;
    end
    return v*f(v-1);
end
escape f(5);
]],
    tight = 'line 6 : `call/rec´ is required for "f"',
    --run = 120,
}
Test { [[
call 1;
]],
    parser = 'line 1 : after `1´ : expected <h,min,s,ms,us>',
}

Test { [[
function @rec (int v)=>int f;
function @rec (int v)=>int f do
    if v == 0 then
        return 1;
    end
    return v * (call/rec f(v-1));
end
escape f(5);
]],
    tight = 'line 8 : `call/rec´ is required for "f"',
}
Test { [[
function @rec (int v)=>int f;
function @rec (int v)=>int f do
    if v == 0 then
        return 1;
    end
    return v * call/rec f(v-1);
end
escape call/rec f(5);
]],
    run = 120,
}

Test { [[
interface IWorld with
    function (PinguHolder*) => PinguHolder* get_pingus;
end

class PinguHolder with
do end

class World with
    interface IWorld;
do end

var IWorld*? ptr = spawn World with end;

escape 1;
]],
    env = 'line 2 : undeclared type `PinguHolder´',
}

Test { [[
interface IWorld with
    function (void) => PinguHolder* get_pingus;
end

class PinguHolder with
do end

class World with
    interface IWorld;
do end

var IWorld*? ptr = spawn World with end;

escape 1;
]],
    env = 'line 2 : undeclared type `PinguHolder´',
}

Test { [[
interface IWorld with
    function (PinguHolder*) => void get_pingus;
end

class PinguHolder with
do end

class World with
    interface IWorld;
do end

var IWorld*? ptr = spawn World with end;

escape 1;
]],
    env = 'line 2 : undeclared type `PinguHolder´',
}

Test { [[
class PinguHolder with
do end

interface IWorld with
    function (PinguHolder*) => PinguHolder* get_pingus;
end

class World with
    interface IWorld;
do end

var IWorld*? ptr = spawn World with end;

escape 1;
]],
    gcc = '25: error: ‘CEU_World_get_pingus’ used but never defined',
}

Test { [[
interface IWorld with
    var int x;
end

class World with
    interface IWorld;
do
    await FOREVER;
end

var IWorld*? ptr = spawn World with
                    this.x = 10;
                  end;
escape ptr:x;     // escapes with "10"
]],
    run = 10,
}
Test { [[
interface IWorld with
    var int x;
end

class World with
    interface IWorld;
do
    await FOREVER;
end

var World*? ptr = spawn World with
                    this.x = 10;
                  end;
var IWorld* w = ptr;
escape w:x;     // escapes with "10"
]],
    run = 10,
}
-- ISR / ATOMIC

Test { [[
atomic do
    await 1s;
end
escape 1;
]],
    props = 'line 2 : not permitted inside `atomic´',
}

Test { [[
atomic do
    par/or do
        nothing;
    with
        nothing;
    end
end
escape 1;
]],
    props = 'line 2 : not permitted inside `atomic´',
}

Test { [[
output void O;
atomic do
    emit O;
end
escape 1;
]],
    props = 'line 3 : not permitted inside `atomic´',
}

Test { [[
output int O;
atomic do
    _f();
end
escape 1;
]],
    props = 'line 3 : not permitted inside `atomic´',
}

Test { [[
output int O;
function (void)=>void f;
atomic do
    f();
end
escape 1;
]],
    props = 'line 4 : not permitted inside `atomic´',
}

Test { [[
output int O;
atomic do
    loop do
    end
end
escape 1;
]],
    props = 'line 3 : not permitted inside `atomic´',
    wrn = true,
}

Test { [[
loop do
    atomic do
        break;
    end
end
escape 1;
]],
    props = 'line 3 : not permitted inside `atomic´',
}

Test { [[
function @rec (void)=>void f;
var int a;
function isr [20] do
    a = 1;
end
escape 1;
]],
    gcc = 'error: implicit declaration of function ‘ceu_out_isr’',
}

Test { [[
native do
    int V = 0;
    void ceu_out_isr (int v, void* f) {
        V = V + 1;
    }
end
var int a;
do
    function isr [20] do
        a = 1;
    end
end             // TODO: forcing finalize out_isr(null)
escape _V;
]],
    run = 2,
}

Test { [[
var int[10] v;
v[0] = 2;
function isr [20] do
    v[0] = 1;
end
escape v[0];
]],
    isr = 'line 2 : access to "v" must be atomic',
}

Test { [[
var int[10] v;
atomic do
    v[0] = 2;
end
function isr [20] do
    v[0] = 1;
end
atomic do
    escape v[0];
end
]],
    props = 'line 9 : not permitted inside `atomic´',
}

Test { [[
native do
    void ceu_out_isr (int v, void* f) {
    }
end
var int[10] v;
atomic do
    v[0] = 2;
end
function isr [20] do
    v[0] = 1;
end
var int ret;
atomic do
    ret = v[0];
end
escape ret;
]],
    run = 2,
}

Test { [[
var int v = 2;
function isr [20] do
    v = 1;
end
escape v;
]],
    isr = 'line 1 : access to "v" must be atomic',
}

Test { [[
var int* v;
function isr [20] do
    *v = 1;
end
escape 1;
]],
    isr = 'line 3 : pointer access breaks the static check for `atomic´ sections',
}

Test { [[
function (void)=>int f do
    return 2;
end
var int v = f();
function isr [20] do
    f();
end
escape v;
]],
    isr = 'line 6 : call breaks the static check for `atomic´ sections',
}

Test { [[
function (void)=>int f do
    return 2;
end
var int v = f();
function isr [20] do
    f();
end
escape v;
]],
    wrn = true,
    isr = 'line 4 : access to "f" must be atomic',
}

Test { [[
var int v = _f();
function isr [20] do
    _f();
end
escape v;
]],
    wrn = true,
    isr = 'line 1 : access to "_f" must be atomic',
}

Test { [[
native @pure _f();
native do
    int f (void) {
        return 2;
    }
    void ceu_out_isr (int v, void* f) {
    }
end
var int v = _f();
function isr [20] do
    _f();
end
escape v;
]],
    run = 2,
}

Test { [[
var int v;
v = 2;
function isr [20] do
    v = 1;
end
escape v;
]],
    isr = 'line 2 : access to "v" must be atomic',
}

Test { [[
var int v;
atomic do
    v = 2;
end
function isr [20] do
    this.v = 1;
end
escape v;
]],
    isr = 'line 8 : access to "v" must be atomic',
}

Test { [[
native do
    void ceu_out_isr (int v, void* f) {
    }
end
var int v;
atomic do
    v = 2;
end
function isr [20] do
    this.v = 1;
    v = 1;
end
var int ret;
atomic do
    ret = v;
end
escape ret;
]],
    run = 2,
}

Test { [[
var int v;
atomic do
    v = 2;
end
function isr [20] do
    this.v = 1;
end
escape v;
]],
    isr = 'line 8 : access to "v" must be atomic',
}

Test { [[
var int v;
var int* p;
atomic do
    v = 2;
    p = &v;
end
function isr [20] do
    this.v = 1;
end
escape 1;
]],
    isr = 'line 5 : reference access breaks the static check for `atomic´ sections',
}

Test { [[
var int[10] v;
var int* p;
atomic do
    p = &v;
end
function isr [20] do
    this.v[1] = 1;
end
escape 1;
]],
    env = 'line 4 : invalid operand to unary "&"',
}

Test { [[
class U with do end;

pool U[10]  us;

pool U[1] us1;
spawn U in us1;

escape 1;
]],
    wrn = true,
    run = 1,
}

-- POOLS / 1ST-CLASS

Test { [[
class U with do end;
class T with
    pool U[0] us;
do
end

var T t;

escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;

interface I with
    pool U[10] us;
end

class T with
    interface I;
do
end

var T t;
var I* i = &t;
spawn U in i:us;

escape 1;
]],
    run = 1,
}

Test { [[
interface I with
    var int[10] vs;
end

interface Global with
    interface I;
end
var int[10]  vs;

class T with
    interface I;
do
    global:vs[0] = 1;
end

vs[0] = 1;
global:vs[0] = 1;

var T t;
t.vs[0] = 1;

var I* i = &t;
i:vs[0] = 1;

escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;

interface I with
    pool U[10] us;
end

interface Global with
    interface I;
end
pool U[10]  us;

class T with
    pool U[10] us;
    interface I;
do
    spawn U in global:us;
end

spawn U in us;
spawn U in global:us;

pool U[1] us1;
spawn U in us1;

var T t;
spawn U in t.us;

var I* i = &t;
spawn U in i:us;

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
interface Global with
    var int[10] vs;
    var int     v;
end
var int[10] vs;
var int     v = 0;

loop i in 10 do
    vs[i] = i;
end
var int ret = 0;
loop i in 10 do
    ret = ret + global:vs[i] + global:v;
end
escape ret;
]],
    run = 45,
}

Test { [[
class T with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool T[] ts;
end

pool T[] ts;

spawn T in ts with
    this.v = 10;
end;

var int ret = 0;
loop t in ts do
    ret = ret + t:v;
end

escape ret;
]],
    run = 10,
}

Test { [[
class T with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool T[1] ts;
end

pool T[1] ts;

spawn T in ts with
    this.v = 10;
end;

var int ret = 0;
loop t in ts do
    ret = ret + t:v;
end

escape ret;
]],
    run = 10,
}

Test { [[
class T with
    var int v = 0;
do
end

interface Global with
    pool T[] ts;
end

pool T[] ts;

spawn T in global:ts;

escape 1;
]],
    run = 1,
}

Test { [[
class T with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool T[] ts;
end

pool T[] ts;

spawn T in global:ts with
    this.v = 10;
end;

var int ret = 0;
loop t in global:ts do
    ret = ret + t:v;
end

escape ret;
]],
    run = 10,
}

Test { [[
class T with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool T[] ts;
end

pool T[] ts;

spawn T in global:ts with
    this.v = 10;
end;

var int ret = 0;
loop t in global:ts do
    ret = ret + t:v;
end

escape ret;
]],
    run = 10,
}

Test { [[
class T with
do
end

interface Global with
    pool T[] ts;
end

pool T[] ts;

class U with
    var int v = 0;
do
    spawn T in global:ts with
    end;
end

var U u;
escape 1;
]],
    run = 1,
}
Test { [[
class T with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool T[] ts;
end

pool T[] ts;

class U with
    var int v = 0;
do
    spawn T in global:ts with
        this.v = 10;
    end;
    spawn T in global:ts with
        this.v = 20;
    end;

    loop t in global:ts do
        this.v = this.v + 10;
    end
end

var int ret = 0;

do
    var U u;
    ret = ret + u.v;
end

loop t in global:ts do
    ret = ret + t:v;
end

escape ret;
]],
    run = 50,
}

Test { [[
class T with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool T[1] ts;
end

pool T[1] ts;

class U with
    var int v = 0;
do
    spawn T in global:ts with
        this.v = 10;
    end;
    spawn T in global:ts with
        this.v = 20;
    end;

    loop t in global:ts do
        this.v = this.v + 10;
    end
end

var int ret = 0;

do
    var U u;
    ret = ret + u.v;
end

loop t in global:ts do
    ret = ret + t:v;
end

escape ret;
]],
    run = 20,
}

Test { [[
native do
    int V = 0;
end

class T with
    var int v = 0;
do
    finalize with
        _V = _V + 1;
    end
    await FOREVER;
end

class U with
    var int v = 0;
    pool T[1] ts;
do
    await FOREVER;
end

var int ret = 0;

do
    var U u;
    spawn T in u.ts with
        this.v = 10;
    end;
    spawn T in u.ts with
        this.v = 20;
    end;

    loop t in u.ts do
        ret = ret + t:v;
    end
end

async do end;

escape ret + _V;
]],
    run = 11,
}

Test { [[
native do
    int V = 0;
end

class T with
    var int v = 0;
do
    finalize with
        _V = _V + 1;
    end
    await FOREVER;
end

class U with
    var int v = 0;
    pool T[] ts;
do
    await FOREVER;
end

var int ret = 0;

do
    var U u;
    spawn T in u.ts with
        this.v = 10;
    end;
    spawn T in u.ts with
        this.v = 20;
    end;

    loop t in u.ts do
        ret = ret + t:v;
    end
end

async do end;

escape ret + _V;
]],
    run = 32,
}

Test { [[
class Unit with
do
    spawn Unit in global:units;
end
interface Global with
    pool Unit[] units;
end
pool Unit[] units;
escape 1;
]],
    env = 'line 3 : interface "Global" is not defined',
    --env = 'line 3 : undeclared type `Unit´',
}
Test { [[
interface Global with
    pool Unit[] units;
end
class Unit with
do
    spawn Unit in global:units;
end
pool Unit[] units;
escape 1;
]],
    env = 'line 2 : undeclared type `Unit´',
}
Test { [[
interface U with end;

interface Global with
    pool U[] units;
end
native @nohold _SDL_Has;

class V with
    interface U;
do
end

class Unit with
    interface U;
    var int rect;
do
    loop oth in global:units do
        if oth!=&this then
            spawn V in global:units;
        end
    end
end

pool U[] units;
escape 1;
]],
    run = 1,
}

-- declaration order for clss, ifcs, pools

Test { [[
    class Queue with
      pool QueueForever[] val;
    do
      //
    end
    escape 1;
]],
    env = 'line 2 : undeclared type `QueueForever´',
}
Test { [[
    var Queue q;
    class Queue with
    do
        var Queue q;
    end
    escape 1;
]],
    env = 'line 1 : undeclared type `Queue´',
}
Test { [[
    class Queue with
    do
        var Queue q;
    end
    var Queue q;
    escape 1;
]],
    env = 'line 3 : undeclared type `Queue´',
}
Test { [[
    class Queue with
    do
        var Queue* q;
    end
    var Queue q;
    escape 1;
]],
    run = 1,
}
Test { [[
    class Queue with
      pool QueueForever[] val;
    do
    end

    class QueueForever with
    do
    end

    escape 1;
]],
    env = 'line 2 : undeclared type `QueueForever´',
}
Test { [[
    interface I with
      var int val;
    end
    spawn I;
    escape 1;
]],
    env = 'line 4 : cannot instantiate an interface',
}
Test { [[
    class QueueForever with
      var int val, maxval;
    do
        spawn QueueForever;
    end
    escape 1;
]],
    wrn = 'line 4 : unbounded recursive spawn',
    run = 1,
    --env = 'line 4 : undeclared type `QueueForever´',
}
Test { [[
    class Queue with
      pool QueueForever[] val;
    do
      //
    end

    class QueueForever with
      var Queue& queue;
      var int val, maxval;
    do
      if val < maxval then
        spawn QueueForever in queue.val with
          this.queue = outer.queue;
          this.val = outer.val + 1;
          this.maxval = outer.maxval;
        end;
      end
    end

    var Queue queue;

    watching 1000us do
      spawn QueueForever in queue.val with
        this.queue = queue;
        this.val = 0;
        this.maxval = 1000;
      end;
    end
    escape 0;
]],
    env = 'line 2 : undeclared type `QueueForever´',
}

Test { [[escape(1);]],
    _ana = {
        isForever = false,
    },
    run = 1,
}

-- TRACKING / WATCHING

Test { [[
class T with
    event void e;
do
    await this.e;
    watching this.e do
        nothing;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
class T with
    event int e;
do
    await this.e;
    var int v;
    watching v in this.e do
        nothing;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
class T with
do
end

var T t;

par/or do
every 1s do
    watching t do
    end
end
with
end

escape 1;
]],
    run = 1,
}

Test { [[
class T with
    event void e;
do
    await this.e;
    par/or do
        nothing;
    with
        if true then
            await this.e;
        else
        end
    end
    watching this.e do
        nothing;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
input int I;
var int ret = -5;
watching I do
    await 1s;
    ret = 5;
end
escape ret;
]],
    run = {
        ['100~>I; ~>1s'] = -5,
        ['~>1s; 100~>I'] = 5,
    }
}

Test { [[
input int I;
var int ret = -5;
var int v=0;
watching v in I do
    await 1s;
    ret = 5;
end
escape ret+v;
]],
    run = {
        ['100~>I; ~>1s'] = 95,
        ['~>1s; 100~>I'] = 5,
    }
}

Test { [[
watching (10)ms do
end
escape 1;
]],
    run = {
        ['~>1s'] = 1,
    }
}

Test { [[
input int I;
var int ret = -5;
var int dt = await I;
watching (dt)ms do
    await 1s;
    ret = 5;
end
escape ret;
]],
    run = {
        ['100~>I; ~>1s'] = -5,
        ['1000~>I; ~>1s'] = -5,
        ['1001~>I; ~>1s'] = 5,
    }
}

Test { [[
input int I;
var int ret = -5;
event void e;
par/or do
    loop do
        var int dt = await I;
        if dt == 100 then
            emit e;
        end
    end
with
    watching e do
        await 1s;
        ret = 5;
    end
end
escape ret;
]],
    run = {
        ['100~>I; ~>1s'] = -5,
        ['1000~>I; ~>1s'] = 5,
    }
}

-- TODO: "e" has type "T*"
-- this type is defined inside the application and only makes sense there
-- if it is not the case, simply use void* and the other application casts back 
-- to T*
Test { [[
event T* e;
var int ret = -1;
watching e do
    await 1s;
    ret = 1;
end
escape 1;
]],
    gcc = ' error: unknown type name ‘T’',
    --run = { ['~>1s'] = 1 }
}

Test { [[
class U with
    var int v = 0;
do
    await FOREVER;
end;

interface I with
    pool U[2] us2;
end

class T with
    pool U[2] us1;
    interface I;
do
end

var T t;
spawn U in t.us2 with
    this.v = 1;
end;

var I* i = &t;
spawn U in i:us2 with
    this.v = 2;
end;

var int ret = 0;

loop u in t.us2 do
    ret = ret + u:v;
end

loop u in i:us2 do
    ret = ret + u:v;
end

escape ret;
]],
    fin = 'line 33 : unsafe access to pointer "i" across `spawn´',
}

Test { [[
class U with
    var int v = 0;
do
    await FOREVER;
end;

interface I with
    pool U[2] us2;
end

class T with
    pool U[2] us1;
    interface I;
do
    await FOREVER;
end

var T t;
spawn U in t.us2 with
    this.v = 1;
end;

var I* i = &t;

var int ret = 1;

watching *i do
    spawn U in i:us2 with
        this.v = 2;
    end;

    loop u in t.us2 do
        ret = ret + u:v;
    end

    loop u in i:us2 do
        ret = ret + u:v;
    end
end

escape ret;
]],
    run = 7,
}

Test { [[
class U with
    var int v = 0;
do
    await FOREVER;
end;

interface I with
    pool U[2] us2;
end

class T with
    pool U[2] us1;
    interface I;
do
end

var T t;
spawn U in t.us2 with
    this.v = 1;
end;

var I* i = &t;

var int ret = 1;

watching *i do
    spawn U in i:us2 with
        this.v = 2;
    end;

    loop u in t.us2 do
        ret = ret + u:v;
    end

    loop u in i:us2 do
        ret = ret + u:v;
    end
end

escape ret;
]],
    run = 1,
}

Test { [[
class T with
    var int v = 0;
do
end

event T* e;
var int ret = 0;

par/or do
    var T t with
        this.v = 10;
    end;
    async do end;
    emit e => &t;
with
    var T* p = await e;
    ret = p:v;
end

escape ret;
]],
    run = 10,
}

Test { [[
class T with
    var int v = 0;
do
end

event T* e;
var int ret = 0;

par/or do
    var T t with
        this.v = 10;
    end;
    async do end;
    emit e => &t;
with
    var T* p = await e;
    ret = p:v;
end

escape ret;
]],
    run = 10,
    safety = 2,
}

Test { [[
class T with
    var int v = 0;
do
end

event T* e;
var int ret = 0;

par/or do
    var T t with
        this.v = 10;
    end;
    async do end;
    emit e => &t;
with
    var T* p = await e;
    async do end;
    ret = p:v;
end

escape ret;
]],
    fin = 'line 18 : unsafe access to pointer "p" across `async´'
}

Test { [[
interface I with
    var int v;
end

class T with
    var int v = 0;
do
end

event T* e;
var int ret = 0;

par/or do
    var T t with
        this.v = 10;
    end;
    async do end;
    emit e => &t;
with
    var I* p = await e;
    async do end;
    ret = p:v;
end

escape ret;
]],
    fin = 'line 22 : unsafe access to pointer "p" across `async´',
}

Test { [[
interface I with
    var int v;
end

class T with
    var int v = 0;
do
    await FOREVER;
end

var I*? p = spawn T with
    this.v = 10;
end;
escape p:v;
]],
    run = 10,
    --fin = 'line 22 : invalid access to awoken pointer "p"',
}

Test { [[
native do
    int V = 0;
end
input void OS_START;
class T with
    var int id = 0;
do
    await OS_START;
    _V = _V + 1;
end

pool T[1] ts;
var T*? t = spawn T in ts with
    this.id = 10;
end;

var int ret = 0;
watching *t do
    ret = t:id;
    await FOREVER;
end

escape ret;
]],
    _ana = { acc=true },
    run = 10,
}

Test { [[
input void OS_START;
class T with
    var int id = 0;
do
    await OS_START;
end

pool T[1] ts;
var T*? t = spawn T in ts with
    this.id = 10000;
end;

var int ret = 0;

watching *t do
    ret = t:id;
    await FOREVER;
end

escape ret;
]],
    run = 10000,
}
Test { [[
input void OS_START;
class T with
    var int id = 0;
do
    await OS_START;
end

pool T[2] ts;
var T*? t1 = spawn T in ts with
    this.id = 10000;
end;
var T*? t = spawn T in ts with
    this.id = 10000;
end;

var int ret = 0;

watching *t do
    ret = t:id;
    await FOREVER;
end

escape ret;
]],
    run = 10000,
}
Test { [[
native do
    int V = 0;
end
input void OS_START;
class T with
    var int id = 0;
do
    await OS_START;
    _V = _V + 1;
end

pool T[10000] ts;
var T* t0 = null;
var T* tF = null;
loop i in 10000 do
    var T*? t = spawn T in ts with
        this.id = 10000-i;
    end;
    if t0 == null then
        t0 = t;
    end
    tF = t;
end
_assert(t0!=null and tF!=null);

var int ret1=0, ret2=0;

watching *tF do
    ret2 = tF:id;
    await FOREVER;
end

escape ret1+ret2+_V;
]],
    --run = 10001,
    fin = 'line 19 : unsafe access to pointer "t0" across `spawn´',
}

Test { [[
interface I with
    var int v;
end

class T with
    var int v = 0;
do
end

var I*? p = spawn T with
    p:v = 10;
end;
async do end;

escape p:v;
]],
    fin = 'line 15 : unsafe access to pointer "p" across `async´',
}

Test { [[
class Unit with
    event int move;
do
end
var Unit*? u;
do
    pool Unit[] units;
    u = spawn Unit in units;
end
if u? then
    watching *u do
        emit u:move => 0;
    end
end
escape 2;
]],
    run = 2,
}
Test { [[
class Unit with
    event int move;
do
end
var Unit*? u;
do
    pool Unit[] units;
    u = spawn Unit in units;
    await 1min;
end
watching *u do
    emit u:move => 0;
end
escape 2;
]],
    fin = 'line 11 : unsafe access to pointer "u" across `await´',
}

Test { [[
interface I with
    var int v;
end

class T with
    var I* i = null;
do
    watching *i do
        var int v = i:v;
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
interface I with
    var int v;
end

class T with
    var I* i = null;
do
    await 1s;
    watching *i do
        var int v = i:v;
    end
end

escape 1;
]],
    fin = 'line 9 : unsafe access to pointer "i" across `await´',
}

Test { [[
interface I with
    var int v;
end

class T with
    var I* i = null;
do
    watching *i do
        await 1s;
        var int v = i:v;
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
interface I with
    var int v;
    event void e;
end

var I* i=null;

await 1s;

await i:e;

watching *i do
    await 1s;
    var int v = i:v;
end

escape 1;
]],
    fin = 'line 10 : unsafe access to pointer "i" across `await´',
}
Test { [[
interface I with
    var int v;
    event void e;
end

var I* i=null;

await 1s;

watching *i do
    await 1s;
    var int v = i:v;
end

escape 1;
]],
    fin = 'line 10 : unsafe access to pointer "i" across `await´',
}

Test { [[
interface I with
    var int v;
end

var I* i=null;

par/or do
    watching *i do
        await 1s;
        var int v = i:v;
    end
with
    await 1s;
end

escape 1;
]],
    todo = '*i vai dar segfault',
    run = 1,
}

Test { [[
class T with
do
end
var T t;
watching t do
end
escape 100;
]],
    run = 100,
}

Test { [[
class T with
    var int v = 0;
do
end

event T* e;
var int ret = 1;

par/and do
    async do end;
    var T t with
        this.v = 10;
    end;
    emit e => &t;
    await 1s;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 1 then
                ret = -1;
            end
        end
        await 5s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>5s']=1 },
}

Test { [[
class T with
    var int v = 0;
do
end

event T* e;
var int ret = 1;

par/and do
    async do end;
    var T t with
        this.v = 10;
    end;
    emit e => &t;
    await 1s;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 1 then
                ret = -1;
            end
        end
        await 5s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>5s']=1 },
    safety = 2,
}

Test { [[
class T with
    var int v = 0;
do
end

event T* e;
var int ret = 1;

par/and do
    async do end;
    var T t with
        this.v = 10;
    end;
    emit e => &t;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 1 then
                ret = -1;
            end
        end
        await 5s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>5s']=1 },
}

Test { [[
class T with
    var int v = 0;
do
    await 5s;
end

event T* e;
var int ret = 0;

par/and do
    async do end;
    var T t with
        this.v = 10;
    end;
    emit e => &t;
    await 6s;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 0 then
                ret = -1;
            end
        end
        await 4s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>10s']=10 },
}

Test { [[
class T with
    var int v = 0;
do
    await 4s;
end

event T* e;
var int ret = 0;

par/and do
    async do end;
    var T t with
        this.v = 10;
    end;
    emit e => &t;
    await 6s;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 0 then
                ret = -1;
            end
        end
        await 5s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>10s']=-1 },
}

Test { [[
class T with
    var int v = 0;
do
    await 6s;
end

event T* e;
var int ret = 0;

par/and do
    async do end;
    var T t with
        this.v = 10;
    end;
    emit e => &t;
    await 6s;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 0 then
                ret = -1;
            end
        end
        await 5s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>10s']=10 },
}

Test { [[
class T with
    var int v = 0;
do
end

event T* e;
emit e => null;
escape 1;
]],
    run = 1;
}

Test { [[
class T with
    var int v = 0;
do
    async do end
end

event T* e;
var int ret = 1;

par/and do
    async do end;
    pool T[] ts;
    var T*? t = spawn T in ts with
        this.v = 10;
    end;
    emit e => t;
    await 1s;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 1 then
                ret = -1;
            end
        end
        await 5s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>1s;~>1s;~>1s;~>1s;~>1s']=-1 },
}

Test { [[
class T with
    var int v = 0;
do
    async do end
end

event T* e;
var int ret = 1;

par/and do
    async do end;
    pool T[] ts;
    var T*? t = spawn T in ts with
        this.v = 10;
    end;
    emit e => t;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 0 then
                ret = 1;
            end
        end
        await 5s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>1s;~>1s;~>1s;~>1s;~>1s']=1 },
}

Test { [[
class T with
    var int v = 0;
do
    await 4s;
end

event T* e;
var int ret = 0;

par/and do
    async do end;
    pool T[] ts;
    var T*? t = spawn T in ts with
        this.v = 10;
    end;
    emit e => t;
    await 6s;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 0 then
                ret = -1;
            end
        end
        await 5s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s']=-1 },
}

Test { [[
class T with
    var int v = 0;
do
    await 6s;
end

event T* e;
var int ret = 0;

par/and do
    async do end;
    pool T[] ts;
    var T*? t = spawn T in ts with
        this.v = 10;
    end;
    emit e => t;
    await 6s;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 0 then
                ret = -1;
            end
        end
        await 5s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s']=10 },
}

Test { [[
class T with
    var int v = 0;
do
    await 6s;
end

event T* e;
var int ret = 0;

par/and do
    async do end;
    pool T[] ts;
    var T*? t = spawn T in ts with
        this.v = 10;
    end;
    emit e => t;
with
    var T* p = await e;
    watching *p do
        finalize with
            if ret == 0 then
                ret = -1;
            end
        end
        await 5s;
        ret = p:v;
    end
end

escape ret;
]],
    run = { ['~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s']=-1 },
}

Test { [[
class U with
do
end
native do
    int V = 0;
end
class Item with
    var U* u;
do
    watching *u do
        await FOREVER;
    end
    _V = 1;
end
do
    var U u;
    spawn Item with
        this.u = &u;
    end;
    await 1s;
end
_assert(_V == 1);
escape 1;
]],
    run = { ['~>1s'] = 1 },
    --fin = 'line 18 : attribution to pointer with greater scope',
}
Test { [[
class U with
do
    await FOREVER;
end
native do
    int V = 0;
end
class Item with
    var U* u;
do
    watching *u do
        await FOREVER;
    end
    _V = 1;
end
do
    var U u;
    spawn Item with
        this.u = &u;
    end;
    await 1s;
end
_assert(_V == 1);
escape 1;
]],
    run = { ['~>1s'] = 1 },
    --fin = 'line 19 : attribution to pointer with greater scope',
}

Test { [[
class U with do end;
class T with
    var U* u;
do
    watching *u do
        await FOREVER;
    end
    _V = _V + 1;
end

native do
    int V = 0;
end

do
    var U u;
    spawn T with
        this.u = &u;
    end;
    await 1s;
end
_assert(_V == 1);
escape _V;
]],
    run = { ['~>1s'] = 1 },
    --fin = 'line 17 : attribution to pointer with greater scope',
}
Test { [[
native do
    int V = 0;
end
class U with do end;
class T with
    var U* u;
do
    watching *u do
        await FOREVER;
    end
    _V = 1;
end
do
    var U u;
    spawn T with
        this.u = &u;
    end;
    await 1s;
end
_assert(_V == 1);
escape 1;
]],
    run = { ['~>1s'] = 1 },
    --fin = 'line 16 : attribution to pointer with greater scope',
}
Test { [[
class U with do end;
class T with
    var U* u;
do
    watching *u do
        await FOREVER;
    end
end

do
    var U u;
    spawn T with
        this.u = &u;
    end;
end
escape 1;
]],
    run = 1,
    --fin = 'line 13 : attribution to pointer with greater scope',
}
Test { [[
class U with do end;
class T with
    var U* u;
do
    watching *u do
        await FOREVER;
    end
end

class X with
    pool T[] ts;
do
    await FOREVER;
end

var X x;
do
    var U u;
    spawn T in x.ts with
        this.u = &u;
    end;
end
escape 1;
]],
    run = 1,
    --fin = 'line 20 : attribution to pointer with greater scope',
}
Test { [[
class Run with
    var int& cmds;
do
end

do
    var int cmds;
    spawn Run with
        this.cmds = cmds;
    end;
end

escape 1;
]],
    ref = 'line 9 : attribution to reference with greater scope',
}
Test { [[
class Run with
    var int& cmds;
do
end

do
    pool Run[] rs;
    var int cmds;
    spawn Run in rs with
        this.cmds = cmds;
    end;
end

escape 1;
]],
    run = 1,
}

Test { [[
class Unit with
    event int move;
do
end
var Unit*? u;
pool Unit[] units;
u = spawn Unit in units;
await 2s;
watching *u do
    emit u:move => 0;
end
escape 2;
]],
    fin = 'line 9 : unsafe access to pointer "u" across `await´',
}
Test { [[
class Unit with
    event int move;
do
    await FOREVER;
end
var Unit*? u;
pool Unit[] units;
u = spawn Unit in units;
watching *u do
    emit u:move => 0;
end
escape 2;
]],
    run = 2,
}

Test { [[
class Unit with
    var int pos;
do end;

var Unit* ptr;
do
    var Unit u;
    ptr = &u;
end
ptr:pos = 0;
escape 1;
]],
    fin = 'line 8 : attribution to pointer with greater scope',
}

Test { [[
class Unit with
    var int pos;
do end;

class T with
    event Unit* org;
    event int   ok;
do
    var Unit* u = await org;
    var int pos = 1;
    watching *u do
        pos = u:pos;
    end
    await 1s;
    emit ok => pos;
end

var T t;
await 1s;

do
    var Unit u with
        this.pos = 10;
    end;
    emit t.org => &u;
end

var int v = await t.ok;
escape v;
]],
    run = { ['~>2s']=1 },
}

Test { [[
native do
    int V = 0;
end
input void OS_START,B;
class T with
    event void ok, go, b;
    event void e, f;
    var int v;
do
    v = 10;
    await e;
    emit f;
    v = 100;
    emit ok;
    await FOREVER;
end
var T a;
var T* ptr;
ptr = &a;
watching *ptr do
    var int ret = 0;
    par/and do
        par/and do
            await OS_START;
            emit ptr:go;
        with
            await ptr:ok;
        end
        ret = ret + 1;      // 24
    with
        await B;
        emit ptr:e;
        ret = ret + 1;
    with
        await ptr:f;
        ret = ret + 1;      // 31
    end
    _V = ret + ptr:v + a.v;
    escape ret + ptr:v + a.v;
        // this escape the outer block, which kills ptr,
        // which kills the watching, which escapes again with +1
end
escape _V + 1;
]],
    _ana = {
        --acc = 3,
    },
    run = { ['~>B']=203, }
    --run = { ['~>B']=204, }
}
Test { [[
class Unit with
    var int pos;
do end;

var Unit* ptr;
do
    var Unit u;
    u.pos = 10;
    ptr = &u;
end
do
    var int[100] v;
    loop i in 100 do
        v[i] = i;
    end
end
escape ptr:pos;
]],
    fin = 'line 9 : attribution to pointer with greater scope',
}

Test { [[
native do
    int V = 0;
end
input void OS_START;
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
watching *ptr do
    par/or do
        await OS_START;
        emit a.go;
        if ptr:going then
            await FOREVER;
        end
    with
        await ptr:ok;
    end
    _V = ptr:v + a.v;
    escape ptr:v + a.v;
end
escape _V + 1;
]],
    --run = 21,
    run = 20,
}

Test { [[
class T with
    var int v = 0;
do
    await FOREVER;
end
pool T[1] ts;
var T*? ok1 = spawn T in ts with
                this.v = 10;
              end;
watching *ok1 do
    var int ok2 = 0;// spawn T in ts;
    var int ret = 0;
    loop t in ts do
        ret = ret + t:v;
    end
    escape (ok1?) + ok2 + ret;
end
escape 1;
]],
    run = 11,
}

Test { [[
native do
    int V = 0;
end
class T with
    var int v = 0;
do
    async do end;
end
pool T[1] ts;
var T*? ok1 = spawn T in ts with
                this.v = 10;
              end;
watching *ok1 do
    var int ok2 = 0;// spawn T in ts;
    var int ret = 0;
    loop t in ts do
        ret = ret + t:v;
    end
    _V = (ok1?) + ok2 + ret;
    escape (ok1?) + ok2 + ret;
end
escape _V + 1;  // this one executes because of strong abortion in the watching
]],
    _ana = {
        acc = true,
    },
    run = 11,
}

Test { [[
class T with
    event (int,int) ok_game;
do
    await 1s;
    emit this.ok_game => (1,2);
end
var T t;
var T* i = &t;
var int a,b;
watching *i do
    (a,b) = await i:ok_game;
    emit i:ok_game => (a,b);
end
escape a+b;
]],
    run = { ['~>1s']=3 },
}


Test { [[
input void OS_START;

class T with
do
    event void x;
    par/or do
        await x;
    with
        await OS_START;
        emit x;
    end
end

do
    var T t;
    await OS_START;
end

escape 10;
]],
    run = 10,
}
Test { [[
input void OS_START;

class U with
    event void x;
do
    await x;
end

class T with
    var U* u;
do
    watching *u do
        await OS_START;
        emit u:x;
    end
end

do
    var U u;
    var T t with
        this.u = &u;
    end;
    await OS_START;
end

escape 10;
]],
    wrn = true,
    run = 10,
}

Test { [[
class V with
do
end

input void OS_START;
class U with
    var V*? v;
    event void x;
do
    loop do
        await x;
        v = spawn V;
        break;
    end
end

class T with
    var U* u;
do
    watching *u do
        await OS_START;
        emit u:x;
        _assert(0);
    end
end

do
    var U u;
    var T t with
        this.u = &u;
    end;
    await OS_START;
end

escape 10;
]],
    wrn = true,
    run = 10,
    --fin = 'line 12 : pointer access across `await´',
    --fin = 'line 12 : invalid block for awoken pointer "v"',
}
Test { [[
interface UI with
end

class T with
    interface UI;
do
end

class UIGridItem with
    var UI* ui;
do
    watching *ui do
        await FOREVER;
    end
end

class UIGridPool with
    pool UIGridItem[] all;
do
    await FOREVER;
end

class UIGrid with
    var UIGridPool& uis;
do
end

do
    var UIGridPool pool1;
    var UIGrid g1 with
        this.uis = pool1;
    end;

    var T g2;
    spawn UIGridItem in g1.uis.all with
        this.ui = &g2;
    end;
end

escape 1;
]],
    --fin = 'line 36 : attribution requires `finalize´',
    run = 1,
}
Test { [[
interface UI with
end

class T with
    interface UI;
do
end

class UIGridItem with
    var UI* ui;
do
    watching *ui do
        await FOREVER;
    end
end

class UIGridPool with
    pool UIGridItem[] all;
do
    await FOREVER;
end

class UIGrid with
    var UIGridPool& uis;
do
end

    var UIGridPool pool1;
    var UIGrid g1 with
        this.uis = pool1;
    end;

    var T g2;
    spawn UIGridItem in g1.uis.all with
        this.ui = &g2;
    end;
escape 1;
]],
    --fin = 'line 35 : attribution requires `finalize´',
    run = 1,
}

Test { [[
interface UI with
end

class T with
    interface UI;
do
end

class UIGridItem with
    var UI* ui;
do
    watching *ui do
        await FOREVER;
    end
end

class UIGridPool with
    pool UIGridItem[] all;
do
    await FOREVER;
end

class UIGrid with
    var UIGridPool& uis;
do
end

do
    var UIGridPool pool1;
    var UIGrid g1 with
        this.uis = pool1;
    end;

    var T g2;
    spawn UIGridItem in pool1.all with
        this.ui = &g2;
    end;
end

escape 1;
]],
    run = 1,
}

Test { [[
native do
    int V = 0;
end
input void OS_START;

interface I with
    var int e;
end

class T with
    var int e;
do
    e = 100;
    await FOREVER;
end

var T t;
var I* i = &t;
watching *i do
    await OS_START;
    _V = i:e;
    escape i:e;
end
escape _V + 1;
]],
    run = 100,
    --run = 101,
}

Test { [[
native do
    int V = 0;
end

input void OS_START;

interface I with
    event void e;
    var int ee;
end

class T with
    event void e;
    var int ee;
do
    await e;
    ee = 100;
    await FOREVER;
end

var T t;
var I* i = &t;

watching *i do
    await OS_START;
    emit i:e;
    _V = i:ee;
    escape i:ee;
end
escape _V + 1;
]],
    run = 100,
    --run = 101,
}

Test { [[
native do
    int V = 0;
end

input void OS_START;

interface I with
    event int e, f;
    var int vv;
end

class T with
    event int e, f;
    var int vv;
do
    var int v = await e;
    vv = v;
    emit f => v;
    await FOREVER;
end

var T t1;
var I* i1 = &t1;

watching *i1 do
    var int ret = 0;
    par/and do
        await OS_START;
        emit i1:e => 99;            // 21
    with
        var int v = await i1:f;
        ret = ret + v;
    with
        await OS_START;
    end
    _V = ret;
    escape ret;
end
escape _V+1;
]],
    --run = 100,
    run = 99,
}

Test { [[
native do
    int V = 0;
end

input void OS_START;

interface I with
    event int e, f;
end

class T with
    event int e, f;
do
    var int v = await e;
    emit f => v;
    await FOREVER;
end

var T t1, t2;
var I* i1 = &t1;

watching *i1 do
    var I* i2 = &t2;
    watching *i2 do
        var int ret = 0;
        par/and do
            await OS_START;
            emit i1:e => 99;            // 21
        with
            var int v = await i1:f;
            ret = ret + v;
        with
            await OS_START;
            emit i2:e => 66;            // 27
        with
            var int v = await i2:f;
            ret = ret + v;
        end
        _V = ret;
        escape ret;
    end
end
escape _V + 1;
]],
    _ana = {
        acc = true,
    },
    run = 165,
    --run = 166,
}

Test { [[
native do
    int V = 0;
end

interface I with
    var int v;
    function (int)=>void f;
end

class T with
    var int v;
    function (int)=>void f;
do
    v = 50;
    this.f(10);

    function (int v)=>void f do
        this.v = this.v + v;
    end
    await FOREVER;
end

var T t;
var I* i = &t;
input void OS_START;
watching *i do
    await OS_START;
    i:f(100);
    _V = i:v;
    escape i:v;
end
escape _V+1;
]],
    wrn = true,
    run = 160,
    --run = 161,
}

Test { [[
native do
    int V = 0;
end

interface I with
    var int v;
    function (int)=>void f;
end

class T with
    interface I;
do
    v = 50;
    this.f(10);

    function (int a)=>void f do
        v = v + a;
    end
    await FOREVER;
end

var T t;
var I* i = &t;
input void OS_START;
watching *i do
    await OS_START;
    i:f(100);
    _V = i:v;
    escape i:v;
end
escape _V+1;
]],
    run = 160,
    --run = 161,
}

Test { [[
interface I with
    var int v;
    function (void)=>int get;
    function (int)=>void set;
end

class T with
    interface I;
    var int v = 50;
do
    function (void)=>int get do
        return v;
    end
    function (int v)=>void set do
        this.v= v;
    end
    await FOREVER;
end

var T t;
var I* i = &t;
var int v = i:v;
i:set(100);
escape v + i:get();
]],
    wrn = true,
    run = 150,
}

Test { [[
native do
    int V = 0;
end

interface I with
    var int v;
    function (int)=>void f;
end

class T with
    interface I;
do
    v = 50;
    this.f(10);

    function (int v)=>void f do
        this.v = this.v + v;
    end
    await FOREVER;
end

class U with
    interface I;
do
    v = 50;
    this.f(10);

    function (int v)=>void f do
        this.v = this.v + 2*v;
    end
    await FOREVER;
end

var T t;
var U u;
var I* i = &t;
input void OS_START;
watching *i do
    await OS_START;
    i:f(100);
    var int ret = i:v;

    i=&u;
    i:f(200);
    _V = ret + i:v;
    escape ret + i:v;
end
escape _V+1;
]],
    wrn = true,
    run = 630,
    --run = 631,
}

Test { [[
class T with
    var int v = 0;
do
    this.v = 10;
end

var int ret = 1;
var T*? t = spawn T;
if t? then
    watching *t do
        finalize with
            ret = t:v;
        end
        await FOREVER;
    end
end

escape ret;
]],
    run = 1,
}

Test { [[
class T with
    var int v = 0;
do
    this.v = 10;
end

var T*? t = spawn T;
watching *t do
    await FOREVER;
end

escape t:v;
]],
    fin = 'line 12 : unsafe access to pointer "t" across `await´',
}

Test { [[
class T with
    var int v = 0;
do
    this.v = 10;
end

var T*? t = spawn T;
watching *t do
    await FOREVER;
end

await 1s;

escape t:v;
]],
    fin = 'line 14 : unsafe access to pointer "t" across `await´',
}

Test { [[
input void OS_START;
class T with
    var int id = 0;
do
    await OS_START;
end

pool T[9999] ts;
var T* t0 = null;
loop i in 9999 do
    var T*? t = spawn T with
        this.id = 9999-i;
    end;
    if t0 == null then
        t0 = t;
    end
end

watching *t0 do
    await FOREVER;
end
var int ret = t0:id;

escape ret;
]],
    fin = 'line 14 : unsafe access to pointer "t0" across `spawn´',
    --run = 9999,
}

-- UNTIL

Test { [[
input int A;
var int x = await A until x>10;
escape x;
]],
    run = {
        ['1~>A; 0~>A; 10~>A; 11~>A'] = 11,
    },
}

Test { [[
native do
    int V = 0;
end
input int A;
var int v = 0;
par/or do
    every 10s do
        _V = _V + 1;
    end
with
    await 10s until v;
with
    await 10s;
    v = 1;
    await FOREVER;
end
escape _V;
]],
    _ana = {
        acc = 1,
    },
    run = {
        ['~>1min'] = 2,
    },
}

Test { [[
native do
    int V = 0;
end
input int A;
var int v = 0;
par/or do
    every 10s do
        _V = _V + 1;
    end
with
    await 10s until v;
with
    await 20s;
    v = 1;
    await FOREVER;
end
escape _V;
]],
    _ana = {
        acc = 1,
    },
    run = {
        ['~>1min'] = 3,
    },
}

Test { [[
input int A;
var int v = 0;
par do
    await 10s until v;
    escape 10;
with
    await 10min;
    v = 1;
end
]],
    _ana = {
        acc = 1,
    },
    run = {
        ['~>10min10s'] = 10,
    },
}

Test { [[
input void OS_START;

interface Global with
    var int x;
end

var int x = 10;

class T with
    var int x;
do
    this.x = global:x;
end

var T t;
await OS_START;
escape t.x;
]],
    run = 10,
}

Test { [[
input int F, E;
var int n_shields = 0;
var int ret = 1;
par/or do
    await F;
with
    loop do
        var int v = await E until (n_shields > 0);
        ret = ret + v;
    end
end

escape ret;
]],
    run = { ['1~>E; 1~>E; 1~>F'] = 1 }
}
Test { [[
input void F, E;
var int n_shields = 0;
var int ret = 1;
par/or do
    await F;
with
    loop do
        await E until (n_shields > 0);
        ret = ret + 10;
    end
end

escape ret;
]],
    run = { ['~>E; ~>E; ~>F'] = 1 }
}

Test { [[
interface Controller with
    var float ax;
end
class KeyController with
    interface Controller;
    var int ax = 0;
do
end

var KeyController c;
var Controller*   i;
i = &c;
escape 1;
]],
    wrn = true,
    env = 'line 12 : types mismatch (`Controller*´ <= `KeyController*´)',
}

Test { [[
interface Controller with
    var float ax;
end
class KeyController with
    interface Controller;
    var float ax = 0;
do
end

var KeyController c;
var Controller*   i;
i = &c;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
input (int,int) I;
var int ret = 0;
par/or do
    loop do
        var int a,b;
        (a,b) = await I
                until a == 1;
        ret = ret + a + b;
    end
with
    await 2s;
    await 2s;
with
    async do
        emit I => (1,2);
        emit I => (1,2);
        emit 5s;
    end
end
escape ret;
]],
    run = 6,
}

-- AWAITS // AWAIT MANY // SELECT

--[=[
Test { [[
await (10ms);
escape 1;
]],
    parser = 'line 1 : after `)´ : expected `or´',
}
Test { [[
await (10ms) or (20ms);
escape 1;
]],
    env = 'line 1 : invalid await: multiple timers',
}
Test { [[
await ((10)ms);
escape 1;
]],
    parser = 'line 1 : after `)´ : expected `or´',
}

Test { [[
await (e) or
      (f);
escape 1;
]],
    env = 'line 1 : variable/event "e" is not declared',
}

Test { [[
event void e;
var int f;
await (e) or
      (f);
escape 1;
]],
    env = 'line 3 : event "f" is not declared',
}

Test { [[
event void e;
event int f;
input void OS_START;
await (e) or
      (f) or
      (OS_START);
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
await (10ms) or (OS_START);
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
var int* x = await (10ms) or (OS_START);
escape 1;
]],
    env = 'line 2 : invalid attribution',
}

Test { [[
input void OS_START;
par/or do
    loop do
        await (OS_START) or (OS_START);
    end
with
    await OS_START;
end
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
await (10ms) or (OS_START)
        until 1;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
var int i = await (10ms) or (OS_START)
        until i==1;
escape i;
]],
    run = 1,
}
Test { [[
input void OS_START;
var int i = await (10ms) or (OS_START)
        until i==0;
escape i+1;
]],
    run = {['~>10ms']=1},
}
]=]

--do escape end

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
    _ana = {
        isForever = true,
    },
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
    _ana = {
        isForever = true,
    },
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
    _ana = {
        isForever = true,
    },
    awaits = 0,
    loop = true,
    run = false,
}

Test { [[
input void A;
await A;
loop i in 10 do
end
escape 1;
]],
    awaits = 0,
    --loop = true,
    run = { ['~>A'] = 1 },
}

Test { [[
input void A;
loop do
    await A;
end
await FOREVER;
]],
    _ana = {
        isForever = true,
    },
    awaits = 0,     -- stmts
}

Test { [[
input void A;
loop do
    await A;
end
escape 1;
]],
    _ana = {
        isForever = true,
    },
    awaits = 0,     -- stmts
    run = false,
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
    _ana = {
        isForever = true,
    },
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
    _ana = {
        isForever = true,
    },
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
    _ana = {
        isForever = true,
    },
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
native _f();
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
    _ana = {
        isForever = true,
    },
    gcc = 'error: implicit declaration of function',
    awaits = 3,
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
native _f();
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
    safety = 2,
    _ana = {
        acc = 1,
        isForever = true,
    },
    awaits = 3,
    gcc = 'error: implicit declaration of function',
}
--do escape end

Test { [[
input int A, B;
class T with
    event int e;
do
    await A;
    await A;
end
var T a,b;
native _f();
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
    _ana = {
        isForever = true,
    },
    awaits = 1,
    gcc = 'error: implicit declaration of function',
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
    _ana = {
        isForever = true,
    },
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
    _ana = {
        isForever = true,
    },
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
    _ana = {
        isForever = true,
    },
    run = false,
    awaits = 2,
}

-- TUPLES

Test { [[
var int a, b;
(a,b) = 1;
escape 1;
]],
    env = 'line 2 : arity mismatch',
    --run = 1,
}

Test { [[
input (int) A;
escape 1;
]],
    run = 1,
}

Test { [[
native _int;
input (_int,int) A;
escape 1;
]],
    run = 1;
}

Test { [[
input (int*,int) A;
event (int,int*) a;
escape 1;
]],
    run = 1;
}

Test { [[
input (int,int) A;
event (int,int) a;
escape 1;
]],
    run = 1;
}

Test { [[
input (int,int) LINE;
var int v;
v = await LINE;
escape 1;
]],
    todo = 'arity error',
}

Test { [[
input (int,int) A;
par/or do
    event int a,b;
    (a,b) = await A;
    escape 1;
with
    async do
        emit A => (1,2);
    end
end
escape 1;
]],
    env = 'line 4 : wrong argument #1',
    --env = 'line 4 : invalid attribution',
}

Test { [[
input (int,int*) A;
par/or do
    var int a,b;
    (a,b) = await A;
    escape a + b;
with
    async do
        emit A => (1,2);
    end
end
escape 1;
]],
    env = 'line 4 : wrong argument #2',
}

Test { [[
input (int,int*) A;
par/or do
    var int a,b;
    (a,b) = await A;
    escape a + b;
with
    async do
        var int x = 2;
        emit A=> (1,&x);
    end
end
escape 1;
]],
    env = 'line 4 : wrong argument #2',
}

Test { [[
input (int,int) A;
par/or do
    var int a,b;
    (a,b) = await A;
    escape a + b;
with
    async do
        emit A => (1,2);
    end
end
escape 1;
]],
    run = 3;
}

Test { [[
event (int,int) a;
par/or do
    var int a,b;
    (a,b) = await a;
    escape a + b;
with
    async do
        emit a => (1,2);
    end
end
escape 1;
]],
    wrn = true,
    env = 'line 4 : event "a" is not declared',
}

Test { [[
event (int,int) a;
input void OS_START;
par/or do
    var int c,d;
    (c,d) = await a;
    escape c + d;
with
    await OS_START;
    emit a => (1,2);
end
escape 1;
]],
    run = 3,
}

Test { [[
event (int,int) e;
emit e => (1,2,3);
escape 1;
]],
    env = 'arity mismatch',
    --env = 'line 2 : invalid attribution (void vs int)',
}

-- INCLUDE

Test { [[
native do
    ##include <stdio.h>
    ##include <stdio.h>
end
escape 1;
]],
    run = 1,
}

Test { [[
#include
escape 1;
]],
    lines = 'error: #include expects "FILENAME" or <FILENAME>',
}

Test { [[
#include "MOD1"
#include "http://ceu-lang.org/"
#include "https://github.com/fsantanna/ceu"
#include "^4!_"
escape 1;
]],
    lines = 'fatal error: MOD1: No such file or directory',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
input void A;
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
await A;
escape 1;
]],
    run = { ['~>A']=1 },
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
nothing;
nothing;
nothing;
input void A
]])
Test { [[
nothing;
#include "/tmp/_ceu_MOD1.ceu"
await A;
escape 1;
]],
    parser = '/tmp/_ceu_MOD1.ceu : line 4 : after `A´ : expected `;´',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
input void A;
native do ##include <assert.h> end
_assert(0);
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
await A;
escape 1;
]],
    --run = { ['~>A']=1 },
    run = "ceu_app_go: Assertion `0' failed",
}

INCLUDE('/tmp/_ceu_MOD2.ceu', [[
input void A;
]])
INCLUDE('/tmp/_ceu_MOD1.ceu', [[
#include "/tmp/_ceu_MOD2.ceu"
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
await A;
escape 1;
]],
    run = { ['~>A']=1 },
}

INCLUDE('/tmp/_ceu_MOD2.ceu', [[
input void A;
nothing
]])
INCLUDE('/tmp/_ceu_MOD1.ceu', [[
#include "/tmp/_ceu_MOD2.ceu"
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
await A;
escape 1;
]],
    parser = '/tmp/_ceu_MOD2.ceu : line 2 : after `nothing´ : expected `;´',
}

INCLUDE('/tmp/_ceu_MOD2.ceu', [[
input void A;
]])
INCLUDE('/tmp/_ceu_MOD1.ceu', [[
input void A;
]])
INCLUDE('/tmp/_ceu_MOD0.ceu', [[
#include "/tmp/_ceu_MOD1.ceu"
#include "/tmp/_ceu_MOD2.ceu"
]])
Test { [[
#include "/tmp/_ceu_MOD0.ceu"
await A;
escape 1;
]],
    wrn = true,
    run = { ['~>A']=1 },
}

INCLUDE('/tmp/_ceu_MOD2.ceu', [[
input void A;
]])
INCLUDE('/tmp/_ceu_MOD1.ceu', [[
nothing;
input void A
]])
INCLUDE('/tmp/_ceu_MOD0.ceu', [[
#include "/tmp/_ceu_MOD2.ceu"
#include "/tmp/_ceu_MOD1.ceu"
]])
Test { [[
#include "/tmp/_ceu_MOD0.ceu"
await A;
escape 1;
]],
    parser = '/tmp/_ceu_MOD1.ceu : line 2 : after `A´ : expected `;´',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
native do
    int f () {
        return 10;
    }
end
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
escape _f();
]],
    run = 10,
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
native do
    int f () {
        return 10;
    }
end
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
#include "/tmp/_ceu_MOD1.ceu"
escape _f();
]],
    gcc = 'error: redefinition of',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
#ifndef MOD1
#define MOD1
native do
    int f () {
        return 10;
    }
end
#endif
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
#include "/tmp/_ceu_MOD1.ceu"
escape _f();
]],
    run = 10,
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
interface T with
    var int i;
end
var int i = 0;
]])
Test { [[
//
//
#include "/tmp/_ceu_MOD1.ceu"
interface T with
    var int i;
end
var int i = 10;
escape i;
]],
    env = 'line 4 : top-level identifier "T" already taken',
    --env = 'tests.lua : line 4 : interface/class "T" is already declared',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
interface T with
    var int i;
end
var int i = 0;
]])
Test { [[
//
//
interface T with
    var int i;
end
#include "/tmp/_ceu_MOD1.ceu"
var int i = 10;
escape i;
]],
    env = 'line 1 : top-level identifier "T" already taken',
    --env = '/tmp/_ceu_MOD1.ceu : line 1 : interface/class "T" is already declared',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
interface Global with
    var int i;
end
var int i = 0;
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
interface Global with
    var int i;
end
var int i = 10;
escape i;
]],
    env = 'line 2 : top-level identifier "Global" already taken',
    --env = 'line 2 : interface/class "Global" is already declared',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
#ifndef GLB
#define GLB
interface Global with
    var int i;
end
#endif
var int i = 0;
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
#ifndef GLB
interface Global with
    var int i;
end
#endif
var int i = 10;
escape i;
]],
    wrn = true,
    run = 10,
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
native do
    int f () {
        return 10;
    }
    int A;
    int B;
end
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
escape _f();
]],
    run = 10,
}

Test { [[
native do
    ##include <unistd.h>
end
escape 1;
]],
    run = 1,
}

-- ASYNCS // THREADS

Test { [[
var int  a=10, b=5;
var int& p = b;
async/thread do
end
escape a + b + p;
]],
    run = 20,
}

Test { [[
var int ret =
    async/thread do
    end;
escape (ret == 1);
]],
    run = 1,
}

Test { [[
var int  a=10, b=5;
var int& p = b;
async/thread (a, p) do
    a = a + p;
    sync do
        p = a;
    end
end
escape a + b + p;
]],
    run = 45,
}

Test { [[
var int  a=10, b=5;
var int& p = b;
var int ret =
    async/thread (a, p) do
        a = a + p;
        sync do
            p = a;
        end
    end;
escape (ret==1) + a + b + p;
]],
    run = 46,
}

Test { [[
sync do
    escape 1;
end
]],
    props = 'line 1 : not permitted outside `thread´',
}

Test { [[
async do
    sync do
        nothing;
    end
end
escape 1;
]],
    props = 'line 2 : not permitted outside `thread´',
}

Test { [[
var int x = 0;
par/and do
    x = 1;
with
    var int& p = x;
    p = 2;
    async/thread (p) do
        p = 2;
    end
end
escape x;
]],
    _ana = {
        acc = 4,
    },
    run = 2,
}

Test { [[
var int x = 0;
par/and do
    x = 1;
with
    var int& p = x;
    p = 2;
    async/thread (p) do
        sync do
            p = 2;
        end
    end
end
escape x;
]],
    _ana = {
        acc = 4,
    },
    run = 2,
}

Test { [[
var int  a=10, b=5;
var int& p = b;
async/thread (a, p) do
    a = a + p;
    p = a;
end
escape a + b + p;
]],
    run = 45,
}

Test { [[
var int  a=10, b=5;
var int* p = &b;
async/thread (p) do
    *p = 1;
end
escape 1;
]],
    fin = 'line 3 : unsafe access to pointer "p" across `async/thread´',
}

Test { [[
var int  a=10, b=5;
var int& p = b;
par/and do
    async/thread (a, p) do
        a = a + p;
        p = a;
    end
with
    p = 2;
end
escape a + b + p;
]],
    _ana = {
        acc = 5,
    },
    run = 36,
}

Test { [[
var int  a=10, b=5;
var int& p = b;
async/thread (a, p) do
    sync do
        a = a + p;
        p = a;
    end
end
escape a + b + p;
]],
    run = 45,
}

for i=1, 50 do
    Test { [[
native do
    ##include <unistd.h>
end
var int ret = 1;
var int& p = ret;
par/or do
    async/thread (p) do
        sync do
            p = 2;
        end
    end
with
end
_usleep(]]..i..[[);
escape ret;
]],
        usleep = true,
        run = 1,
    }
end

for i=1, 50 do
    Test { [[
native do
    ##include <unistd.h>
end
var int ret = 0;
var int& p = ret;
par/or do
    async/thread (p) do
        _usleep(]]..i..[[);
        sync do
            p = 2;
        end
    end
with
    ret = 1;
end
_usleep(]]..i..[[+1);
escape ret;
]],
        usleep = true,
        run = 1,
        _ana = { acc=1 },
    }
end

Test { [[
var int  v1=10, v2=5;
var int& p1 = v1;
var int& p2 = v2;

par/and do
    async/thread (v1, p1) do
        sync do
            p1 = v1 + v1;
        end
    end
with
    async/thread (v2, p2) do
        sync do
            p2 = v2 + v2;
        end
    end
end
escape v1+v2;
]],
    run = 30,
}

Test { [[
var int  v1, v2;
var int& p1 = v1;
var int& p2 = v2;

native do
    int calc ()
    {
        int ret, i, j;
        ret = 0;
        for (i=0; i<10; i++) {
            for (j=0; j<10; j++) {
                ret = ret + i + j;
            }
        }
        printf("ret = %d\n", ret);
        return ret;
    }
end

par/and do
    async/thread (p1) do
        var int ret = _calc();
        sync do
            p1 = ret;
        end
    end
with
    async/thread (p2) do
        var int ret = _calc();
        sync do
            p2 = ret;
        end
    end
end
native do ##include <assert.h> end
_assert(v1 == v2);
escape v1;
]],
    run = 900,
}

Test { [[
var int  v1, v2;
var int& p1 = v1;
var int& p2 = v2;

par/and do
    async/thread (p1) do
        var int ret = 0;
        loop i in 10 do
            loop j in 10 do
                ret = ret + i + j;
            end
        end
        sync do
            p1 = ret;
        end
    end
with
    async/thread (p2) do
        var int ret = 0;
        loop i in 10 do
            loop j in 10 do
                ret = ret + i + j;
            end
        end
        sync do
            p2 = ret;
        end
    end
end
native do ##include <assert.h> end
_assert(v1 == v2);
escape v1;
]],
    run = 900,
}

Test { [[
var int  v1, v2;
var int& p1 = v1;
var int& p2 = v2;

native do
    int calc ()
    {
        int ret, i, j;
        ret = 0;
        for (i=0; i<50000; i++) {
            for (j=0; j<50000; j++) {
                ret = ret + i + j;
            }
        }
        printf("ret = %d\n", ret);
        return ret;
    }
end

par/and do
    async/thread (p1) do
        var int ret = _calc();
        sync do
            p1 = ret;
        end
    end
with
    async/thread (p2) do
        var int ret = _calc();
        sync do
            p2 = ret;
        end
    end
end
native do ##include <assert.h> end
_assert(v1 == v2);
escape v1;
]],
    --run = false,
    run = 1066784512,
}

Test { [[
var int  v1, v2;
var int& p1 = v1;
var int& p2 = v2;

par/and do
    async/thread (p1) do
        var int ret = 0;
        loop i in 50000 do
            loop j in 50000 do
                ret = ret + i + j;
            end
        end
        sync do
            p1 = ret;
        end
    end
with
    async/thread (p2) do
        var int ret = 0;
        loop i in 50000 do
            loop j in 50000 do
                ret = ret + i + j;
            end
        end
        sync do
            p2 = ret;
        end
    end
end
native do ##include <assert.h> end
_assert(v1 == v2);
escape v1;
]],
    run = 1066784512,
    --run = false,
-- thr.c
--./a.out  17.41s user 0.00s system 180% cpu 9.629 total
-- me (isTmp=true)
--./a.out  16.80s user 0.02s system 176% cpu 9.525 total
-- me (isTmp=false)
--./a.out  30.36s user 0.04s system 173% cpu 17.476 total
}

Test { [[
class T with
    event int ok;
do
    var int v;
    var int& p = v;
    async/thread (p) do
        var int ret = 0;
        loop i in 50000 do
            loop j in 50000 do
                ret = ret + i + j;
            end
        end
        sync do
            p = ret;
        end
    end
    emit ok => v;
end

var T t1, t2;
var int v1, v2;

par/and do
    v1 = await t1.ok;
with
    v2 = await t2.ok;
end

native do ##include <assert.h> end
_assert(v1 == v2);
escape v1;
]],
    run = 1066784512,
    --run = false,
-- thr.c
--./a.out  17.41s user 0.00s system 180% cpu 9.629 total
-- me (isTmp=true)
--./a.out  16.80s user 0.02s system 176% cpu 9.525 total
-- me (isTmp=false)
--./a.out  30.36s user 0.04s system 173% cpu 17.476 total
}

-- THREADS / EMITS

Test { [[
input int A;
par/or do
    await A;
with
    async/thread do
        emit A=>10;
    end
end;
escape 10;
]],
    _ana = {
        isForever = false,
    },
    --run = 10,
    props = 'not permitted inside `thread´',
    --props = 'line 6 : invalid `emit´',
}
Test { [[
input int A;
par/or do
    await A;
with
    async do
        emit A=>10;
    end
end;
escape 10;
]],
    _ana = {
        isForever = false,
    },
    run = 10,
}

Test { [[
var int a;
var int& pa = a;
async/thread (pa) do
    emit 1min;
    pa = 10;
end;
escape a + 1;
]],
    --run = 11,
    props = 'not permitted inside `thread´',
}
Test { [[
var int a;
var int& pa = a;
async (pa) do
    emit 1min;
    pa = 10;
end;
escape a + 1;
]],
    run = 11,
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
    escape v1 + v2;
with
    async/thread do
        emit 5ms;
        emit(5000)ms;
    end
end
]],
    _ana = {
        isForever = false,
        abrt = 3,
    },
    --run = 5,
    --run = 3,
    --todo = 'nd excpt',
    props = 'not permitted inside `thread´',
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
    escape v1 + v2;
with
    async do
        emit 5ms;
        emit(5000)ms;
    end
end
]],
    _ana = {
        isForever = false,
        abrt = 3,
    },
    run = 5,
    --run = 3,
    --todo = 'nd excpt',
}

Test { [[
input int A;
par do
    async/thread do end
with
    await A;
    escape 1;
end
]],
    run = { ['1~>A']=1 },
}

Test { [[
native do ##include <assert.h> end
native _assert();
input void T;
var int ret = 0;
par/or do
    loop do
        var int late = await 10ms;
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
    async/thread do
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
escape ret;
]],
    --run = 72000,
    props = 'not permitted inside `thread´',
}
Test { [[
native do ##include <assert.h> end
native _assert();
input void T;
var int ret = 0;
par/or do
    loop do
        var int late = await 10ms;
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
escape ret;
]],
    run = 72000,
}

Test { [[
input int P2;
par do
    loop do
        par/or do
            var int p2 = await P2;
            if p2 == 1 then
                escape 0;
            end;
        with
            loop do
                await 200ms;
            end;
        end;
    end;
with
    async/thread do
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 1;
    end;
    await FOREVER;      // TODO: ele acha que o async termina
end;
]],
    --run = 0,
    props = 'not permitted inside `thread´',
}
Test { [[
input int P2;
par do
    loop do
        par/or do
            var int p2 = await P2;
            if p2 == 1 then
                escape 0;
            end;
        with
            loop do
                await 200ms;
            end;
        end;
    end;
with
    async do
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 0;
        emit P2 => 1;
    end;
    await FOREVER;      // TODO: ele acha que o async termina
end;
]],
    run = 0,
}

Test { [[
var int ret = 0;
input void A;
par/and do
    await 1s;
    ret = ret + 1;
with
    async do
        emit 1s;
    end
    ret = ret + 1;
with
    async/thread do
        sync do
        end
    end
    ret = ret + 1;
with
    async do
        emit A;
    end
    ret = ret + 1;
end
escape ret;
]],
    run = { ['~>A;~>1s'] = 4 },
}

-- ASYNC/NONDET

Test { [[
var int[2] v;
var int* p = v;
par/and do
    v[0] = 1;
with
    p[1] = 2;
end
escape v[0] + v[1];
]],
    _ana = {
        acc = 1,
    },
    --fin = 'line 6 : pointer access across `await´',
    run = 3;
}
Test { [[
var int[2] v;
par/and do
    v[0] = 1;
with
    var int* p = v;
    p[1] = 2;
end
escape v[0] + v[1];
]],
    _ana = {
        acc = 2,
    },
    run = 3,
}
Test { [[
var int[2] v;
var int[2] p;
par/and do
    v[0] = 1;
with
    p[1] = 2;
end
escape v[0] + p[1];
]],
    run = 3,
}

Test { [[
var int x = 0;
async do
    x = 2;
end
escape x;
]],
    env = 'line 3 : variable/event "x" is not declared',
}

Test { [[
var int x = 0;
async/thread do
    x = 2;
end
escape x;
]],
    env = 'line 3 : variable/event "x" is not declared',
}

Test { [[
var int x = 0;
par/and do
    x = 1;
with
    async (x) do
        x = 2;
    end
end
escape x;
]],
    _ana = { acc=1 },
    run = 2,
}

Test { [[
var int x = 0;
par/and do
    x = 1;
with
    async/thread (x) do
        x = 2;
    end
end
escape x;
]],
    _ana = { acc=1 },
    run = 2,
}

Test { [[
var int x = 0;
par/and do
    x = 1;
with
    async/thread (x) do
        x = 2;
    end
end
escape x;
]],
    _ana = {
        acc = 1,
    },
    run = 2,
}

Test { [[
var int x = 0;
par/and do
    await 1s;
    x = 1;
with
    var int y = x;
    async/thread (y) do
        y = 2;
    end
    x = x + y;
end
escape x;
]],
    run = { ['~>1s']=3 },
}

Test { [[
var int x = 0;
par/and do
    await 1s;
    x = 1;
with
    var int y = x;
    async/thread (y) do
        y = 2;
    end
    x = x + y;
end
escape x;
]],
    run = { ['~>1s']=3 },
    safety = 2,
    _ana = {
        acc = 3,
    },
}

Test { [[
var int x  = 0;
var int* p = &x;
par/and do
    *p = 1;
with
    var int y = x;
    async/thread (y) do
        y = 2;
    end
    x = x + y;
end
escape x;
]],
    _ana = {
        acc = 3,
    },
    run = 3,
}

Test { [[
var int[10] x;
async/thread (x) do
    x[0] = 2;
end
escape x[0];
]],
    run = 2,
    --gcc = 'error: lvalue required as left operand of assignment',
}

Test { [[
var int[10] x;
par/and do
    async/thread (x) do
        x[0] = x[1] + 2;
    end
with
    x[1] = 5;
end
escape x[0];
]],
    run = 7,
    _ana = {
        acc = 2,
    },
    --gcc = 'error: lvalue required as left operand of assignment',
}

Test { [[
var int v = 1;
async (v) do
    finalize with
        v = 2;
    end
end;
escape v;
]],
    props = 'line 3 : not permitted inside `async´',
}
Test { [[
var int v = 1;
async/thread (v) do
    finalize with
        v = 2;
    end
end;
escape v;
]],
    props = 'line 3 : not permitted inside `thread´',
}

-- END: THREADS / EMITS

-- REFS / &

Test { [[
class T with
    var int x;
do
end
class U with do end;
event T& e;
par/and do
   do
      await 1s;
      var T t;
      emit e => t;
   end
   var U u;
with
   var T& t = await e;
   t.x = 1;
   await 1s;
end
escape 1;
]],
    env = 'line 6 : invalid event type',
}

Test { [[
class T with
    var int x;
do
end
class U with do end;
event (T&,int) e;
par/and do
   do
      await 1s;
      var T t;
      emit e => (t,1);
   end
   var U u;
with
   var T& t;
   var int i;
   (t,i) = await e;
   t.x = 1;
   await 1s;
end
escape 1;
]],
    env = 'line 6 : invalid event type',
    --run = 1,
}

Test { [[
var int& i = 1;
escape 1;
]],
    ref = 'line 1 : invalid attribution',
}

Test { [[
var int* p;
var int& i = *p;
escape 1;
]],
    ref = 'line 2 : invalid attribution',
}

Test { [[
event int e;
var int& i = await e;
escape 1;
]],
    ref = 'line 2 : invalid attribution',
}

Test { [[
event int& e;
var int& i = await e;
escape 1;
]],
    env = 'line 1 : invalid event type',
}

Test { [[
native @plain _t;
native @nohold _f();
native do
    #define f(a)
    typedef int t;
end
class T with
    var _t& t;
do
    await 1s;
    _f(&t);
end
escape 1;
]],
    run = 1,
}

Test { [[
interface I with end;
class T with
    var I* i = null;
do
end

var T t;
await 1s;
_assert(t.i == null);
escape 1;
]],
    run = { ['~>1s'] = 1 },
}

Test { [[
interface I with end;
class T with
    var I* i = null;
do
end

var T t;
var I* i = t.i;
await 1s;
_assert(t.i == null);
escape 1;
]],
    fin = 'line 10 : unsafe access to pointer "i" across `await´',
    --run = { ['~>1s'] = 1 },
}

Test { [[
interface I with end;
class T with
    var I* i = null;
do
end

var T t;
var I* i = t.i;
await 1s;
_assert(i == null);
escape 1;
]],
    fin = 'line 10 : unsafe access to pointer "i" across `await´',
}

Test { [[
class T with do end

class Pool with
    pool T[] all;
do
    await FOREVER;
end

interface Global with
    var Pool* p;
end
var Pool* p = null;

class S with
do
    await 1s;
    spawn T in global:p:all with
    end;
end

escape 1;
]],
    run = 1,
}

Test { [[
native do
    typedef struct t {
        int v;
    } t;
end

class Unit with
    var _t t;
do
end

var Unit u with
    this.t.v  =  30;
end;
escape u.t.v;
]],
    run = 30,
}

Test { [[
class Map with
    event (int,int) go_xy;
do
end

var Map* m;
emit m:go_xy => (1,1);

escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
var int a = 1;
event int& e;
par do
    var int& v = await e;
    v = v + 1;
with
    await OS_START;
    var int b = 10;
    emit e => b;
    escape b;
end
]],
    env = 'line 3 : invalid event type',
    --run = 11,
}

Test { [[
input void OS_START;
var int a = 1;
event (int,int&) e;
par do
    var int& r;
    var int  v;
    (v,r) = await e;
    r = r + v;
with
    await OS_START;
    var int b = 10;
    emit e => (4,b);
    escape b;
end
]],
    env = 'line 3 : invalid event type',
    --run = 14,
}

Test { [[
interface Object with
    var _SDL_Rect rect;
end
class MoveObject with
    var Object* obj = null;
do
    _assert(this.obj != null);
    await 1s;
    obj:rect.x = 1;
end
escape 1;
]],
    fin = 'line 9 : unsafe access to pointer "obj" across `await´',
}

Test { [[
native @plain _int;
interface Object with
    var _int v;
end
class MoveObject with
    var Object& obj;
do
    await 1s;
    obj.v = 1;
end
escape 1;
]],
    run = 1,
}
Test { [[
native @plain _int;
interface Object with
    var _int v;
end
class O with
    interface Object;
do
    this.v = 10;
end
class MoveObject with
    var Object& obj;
do
    await 1s;
    obj.v = 1;
end
var O o;
escape o.v;
]],
    run = 10,
}
Test { [[
class T with
    var int v = 0;
do
end
var T t with
    this.v = 10;
end;
var T& tt = t;
tt.v = 5;
escape t.v;
]],
    run = 5,
}

Test { [[
native @plain _int;
interface Object with
    var _int v;
end
class O with
    interface Object;
do
    this.v = 10;
end
class MoveObject with
    var Object& obj;
do
    await 1s;
    obj.v = 1;
end
var O o;
var MoveObject m with
    this.obj = o;
end;
await 2s;
escape o.v;
]],
    run = { ['~>2s']=1 },
}

-- REQUESTS

Test { [[
input/output [10] (int max)=>char* LINE;
request LINE;
escape 1;
]],
    env = 'line 2 : arity mismatch',
    --env = 'line 2 : missing parameters on `emit´',
}

Test { [[
input/output [10] (int max)=>char* LINE;
request LINE => "oi";
escape 1;
]],
    env = 'line 2 : wrong argument #2',
}

Test { [[
input/output [10] (int max)=>char* LINE;
request LINE => 10;
escape 1;
]],
    props = 'line 2 : invalid `emit´',
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) 1
end
output/input [10] (int max)=>char* LINE;
par/or do
    request LINE => 10;
with
end
escape 1;
]],
    run = 1,
}

Test { [[
input void* A;
do
    var void* p;
    p = await A
        until p==null;
    var void* p1 = p;
end
await FOREVER;
]],
    _ana = {
        isForever = true,
    },
}

Test { [[
output/input [10] (int max)=>char* LINE;
var u8 err;
var char* ret = null;
par/or do
    var char* ret1;
    (err, ret1) = request LINE => 10;
    ret := ret1;
with
    await FOREVER;
end
escape *ret;
]],
    fin = 'line 11 : unsafe access to pointer "ret" across `par/or´',
    --fin = 'line 5 : invalid block for awoken pointer "ret"',
}

Test { [[
output/input [10] (int max)=>char* LINE;
native do
    ##define ceu_out_emit(a,b,c,d) 1
end
var u8 err;
par/or do
    var char* ret;
    (err, ret) = request LINE => 10;
with
end
escape 1;
]],
    run = 1,
}

Test { [[
input/output [10] (int max)=>char* LINE;
request LINE;
escape 1;
]],
    env = 'line 2 : arity mismatch',
    --env = 'line 2 : missing parameters on `emit´',
}

Test { [[
input/output [10] (int max)=>char* LINE;
request LINE => "oi";
escape 1;
]],
    env = 'line 2 : wrong argument #2',
}

Test { [[
input/output [10] (int max)=>char* LINE;
request LINE => 10;
escape 1;
]],
    props = 'line 2 : invalid `emit´',
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) 1
end
output/input [10] (int max)=>char* LINE;
par/or do
    request LINE => 10;
with
end
escape 1;
]],
    run = 1,
}

Test { [[
output/input [10] (int max)=>char* LINE;
var u8 err, ret;
(err, ret) = request LINE => 10;
escape 1;
]],
    env = 'line 3 : wrong argument #3',
    --env = 'line 3 : invalid attribution (u8 vs char*)',
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) 1
end
output/input [10] (int max)=>int LINE;
par/or do
    var u8 err, ret;
    (err, ret) = request LINE => 10;
with
end
escape 1;
]],
    run = 1,
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) 1
end
output/input [10] (int)=>int LINE do
    return 1;     // missing <int "id">
end
par/or do
    var u8 err, ret;
    (err, ret) = request LINE => 10;
with
end
escape 1;
]],
    adj = 'line 4 : missing parameter identifier',
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) 1
end
output/input [10] (int max)=>int LINE do
    return 1;
end
par/or do
    var u8 err, ret;
    (err, ret) = request LINE => 10;
with
end
escape 1;
]],
    props = 'line 4 : invalid `emit´',
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) 1
end
input/output [10] (int max)=>int LINE do
    return 1;
end
par/or do
    var u8 err, ret;
    (err, ret) = request LINE => 10;
with
end
escape 1;
]],
    props = 'line 9 : invalid `emit´',
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) 1
end
input/output [10] (int max)=>int LINE do
    return 1;
end
escape 1;
]],
    run = 1,
}

Test { [[
native do
    ##define ceu_out_emit(a,b,c,d) 1
end
var int ret = 0;
input/output [10] (int max)=>int LINE do
    ret = 1;
end
escape ret;
]],
    env = 'line 6 : variable/event "ret" is not declared',
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [10] (int max)=>int LINE do
        _V = 10;
        return 1;
    end
    await 1s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,10);
        emit 1s;
    end
end
]],
    run = 11,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [10] (int max)=>int LINE do
        _V = max;
    end
    await 1s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,10);
        emit 1s;
    end
end
]],
    run = 11,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [10] (int max)=>int LINE do
        _V = _V + max;
    end
    await 1s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,10);
        emit LINE_REQUEST => (2,20);
        emit LINE_REQUEST => (3,30);
        emit 1s;
    end
end
]],
    run = 61,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
    end
    input/output [2] (int max)=>int LINE do
        await 1s;
    end
    await 1s;
    escape 1;
with
    async do
        emit LINE_REQUEST => (1,10);
        emit LINE_REQUEST => (1,10);
        emit 1s;
    end
end
]],
    run = 1,
}
Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output (int max)=>int LINE do
        await 1s;
        _V = _V + max;
    end
    await 1s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,10);
        emit LINE_REQUEST => (1,10);
        emit 1s;
    end
end
]],
    _ana = {
        acc = 1,
    },
    run = 1,
}
Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [2] (int max)=>int LINE do
        await 1s;
        _V = _V + max;
    end
    await 1s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,10);
        emit LINE_REQUEST => (2,20);
        emit LINE_REQUEST => (3,30);
        emit 1s;
    end
end
]],
    _ana = {
        acc = 1,
    },
    run = 1,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [2] (int max)=>int LINE do
        await 1s;
        _V = _V + max;
    end
    await 2s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,10);
        emit LINE_REQUEST => (2,20);
        emit LINE_REQUEST => (3,30);
        emit 2s;
    end
end
]],
    _ana = {
        acc = 1,
    },
    run = 31,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [2] (int max)=>int LINE do
        await 1s;
        _V = _V + max;
    end
    await 3s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,11);
        emit LINE_REQUEST => (2,22);
        emit LINE_REQUEST => (3,30);
        emit 1s;
        emit LINE_REQUEST => (4,13);
        emit LINE_REQUEST => (5,24);
        emit LINE_REQUEST => (6,30);
        emit 2s;
    end
end
]],
    _ana = {
        acc = 1,
    },
    run = 71,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [1] (int max)=>int LINE do
        await 1s;
        _V = _V + max;
    end
    await 3s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,11);
        emit LINE_REQUEST => (2,22);
        emit LINE_REQUEST => (3,30);
        emit 1s;
        emit LINE_REQUEST => (4,13);
        emit LINE_REQUEST => (5,24);
        emit LINE_REQUEST => (6,30);
        emit 2s;
    end
end
]],
    _ana = {
        acc = 1,
    },
    run = 25,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [0] (int max)=>int LINE do
        await 1s;
        _V = _V + max;
    end
    await 3s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,11);
        emit LINE_REQUEST => (2,22);
        emit LINE_REQUEST => (3,30);
        emit 1s;
        emit LINE_REQUEST => (4,13);
        emit LINE_REQUEST => (5,24);
        emit LINE_REQUEST => (6,30);
        emit 2s;
    end
end
]],
    _ana = {
        acc = 1,
    },
    run = 1,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [10] (int max)=>int LINE do
        await 1s;
        _V = _V + max;
    end
    input void F;
    await F;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,11);
        emit LINE_REQUEST => (2,22);
        emit LINE_CANCEL => 1;
        emit 3s;
        emit F;
    end
end
]],
    run = 23,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [10] (int max)=>int LINE do
        await 1s;
        _V = _V + max;
    end
    input void F;
    await F;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,11);
        emit LINE_REQUEST => (2,22);
        emit LINE_CANCEL => 2;
        emit 3s;
        emit F;
    end
end
]],
    run = 12,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    input/output [10] (int max)=>int LINE do
        await 1s;
        _V = _V + max;
    end
    input void F;
    await F;
    escape _V+1;
with
    async do
        emit LINE_REQUEST => (1,11);
        emit LINE_REQUEST => (2,22);
        emit LINE_CANCEL => 2;
        emit LINE_CANCEL => 1;
        emit 3s;
        emit F;
    end
end
]],
    run = 1,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    output/input (int max)=>int LINE;
    var int v   = 0;
    var int err = 0;
    par/or do
        (err,v) = request LINE=>10;
    with
        await 5s;
        escape 999;
    end
    escape v+err;
with
    async do
        emit LINE_RETURN => (1,1,10);
        emit 5s;
    end
end
]],
    run = 11,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    output/input (int max)=>int LINE;
    var int v   = 0;
    var int err = 0;
    par/or do
        (err,v) = request LINE=>10;
    with
        await 5s;
        escape 999;
    end
    escape v+err;
with
    async do
        emit LINE_RETURN => (2,1,10);
        emit 5s;
    end
end
]],
    run = 999,
}

Test { [[
par do
    native do
        ##define ceu_out_emit(a,b,c,d) 1
        int V = 0;
    end
    output/input (int max)=>int LINE;
    var int v   = 0;
    var int err = 0;
    par/or do
        (err,v) = request LINE=>10;
    with
        await 5s;
        escape 999;
    end
    escape v+err;
with
    async do
        emit LINE_RETURN => (2,1,10);
        emit 4s;
        emit LINE_RETURN => (1,0,-1);
        emit 1s;
    end
end
]],
    run = -1,
}

-- LUA

Test { [==[
[[
    a = 1
]]
var int a = [[a]];
escape a;
]==],
    run = 1,
}

Test { [==[
[[
    --[[oi]]
    a = 1
]]
var int a = [[a]];
escape a;
]==],
    parser = 'line 3 : after `1´ : expected `;´',
}

Test { [==[
[=[
    --[[oi]]
    a = 1
]=]
var int a = [[a]];
escape a;
]==],
    run = 1,
}

Test { [=[
var int v = [["ok" == 'ok']];
escape v;
]=],
    run = 1,
}

Test { [=[
var int v = [[true]];
escape v;
]=],
    run = 1,
}

Test { [=[
var int v = [[false]];
escape v;
]=],
    run = 0,
}

Test { [==[
[[
    print '*** END: 10'
]]
var int v = [[1]];
escape v;
]==],
    run = 10,
}

Test { [==[
[[
    aa $ aa
]]
escape 1;
]==],
    run = '2: \'=\' expected near \'$\'',
}

Test { [=[
var int a = [[1]];
[[
    a = @a+1
]]
var int ret = [[a]];
escape ret;
]=],
    run = 2,
}

Test { [=[
var int a = [[1]];
var int b = 10;
[[
    a = @a+@b
]]
var int ret = [[a]];
escape ret;
]=],
    run = 11,
}

Test { [=[
native @nohold _strcmp();
var char* str = "oioioi";
[[ str = @str ]]
var bool ret = [[ str == 'oioioi' ]];
var char[10] cpy = [[ str ]];
escape ret and (not _strcmp(str,cpy));
]=],
    run = 1,
}

Test { [=[
native @nohold _strcmp(), _strcpy();
var char[10] str;
_strcpy(str,"oioioi");
[[ str = @str ]]
var bool ret = [[ str == 'oioioi' ]];
var char[10] cpy;
var char* ptr = cpy;
ptr = [[ str ]];
escape ret and (not _strcmp(str,cpy));
]=],
    run = 1,
}

Test { [=[
native @nohold _strcmp();
[[ str = '1234567890' ]]
var char[2] cpy = [[ str ]];
escape (not _strcmp(cpy,"1"));
]=],
    run = 1,
}

Test { [=[
native @nohold _strcmp();
[[ str = '1234567890' ]]
var char[2] cpy;
var char[20] cpy_;
var char* ptr = cpy;
ptr = [[ str ]];
escape (not _strcmp(cpy,"1234567890"));
]=],
    run = 1,
}

Test { [=[
var int a = [[1]];
var int b = 10;
[[
    @a = @a+@b
    a = @a
]]
var int ret = [[a]];
escape ret;
]=],
    todo = 'error: assign to @a',
    run = 11,
}

Test { [=[
native @nohold _strcmp();

[[
-- this is lua code
v_from_lua = 100
]]

var int v_from_ceu = [[v_from_lua]];

[[
str_from_lua = 'string from lua'
]]
var char[100] str_from_ceu = [[str_from_lua]];
_assert(not _strcmp(str_from_ceu, "string from lua"));

[[
print(@v_from_ceu)
v_from_lua = v_from_lua + @v_from_ceu
]]

//v_from_ceu = [[nil]];

var int ret = [[v_from_lua]];
escape ret;
]=],
    run = 200,
}

Test { [=[
var int a;
var void* ptr1 = &a;
[[ ptr = @ptr1 ]];
var void* ptr2 = [[ ptr ]];
escape ptr2==&a;
]=],
    run = 1,
}

-- ALGEBRAIC DATATYPES (ADTS)

-- ADTs used in most examples below
DATA = [[
// C-like struct
data Pair with
    var int x;
    var int y;
end

// "Nullable pointer"
data Opt with
    tag NIL;
or
    tag PTR with
        var void* v;
    end
end

// List (recursive type)
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

























// 50 lines
]]

-- STATIC ADTs

--[==[
-- HERE:
]==]

-- data type identifiers must start with an uppercase
Test { [[
data t with
    var int x;
end
escape 1;
]],
    -- TODO: better error message
    parser = 'line 1 : after `data´ : expected `;´'
}
Test { [[
data T with
    var int x;
end
escape 1;
]],
    run = 1,
}

-- data type identifiers cannot clash with interface/classe identifiers
Test { [[
data T with
    var int x;
end
interface T with
end
escape 1;
]],
    env = 'line 4 : top-level identifier "T" already taken',
}
Test { [[
interface T with
end
data T with
    var int x;
end
escape 1;
]],
    env = 'line 3 : top-level identifier "T" already taken',
}
Test { [[
data T with
    var int x;
end
data T with
    var int y;
end
escape 1;
]],
    env = 'top-level identifier "T" already taken',
}
Test { [[
class T with
do
end
interface T with
end
escape 1;
]],
    env = 'top-level identifier "T" already taken',
}

Test { [[
data D with
    var int x;
end
class C with
    var D d = D(200);
do
end
var C c;
escape c.d.x;
]],
    run = 200,
}

-- tags inside union data types must be all uppercase
Test { [[
data Opt with
    tag Nil;
or
    tag Ptr with
        var void* v;
    end
end
escape 1;
]],
    -- TODO: better error message
    parser = 'line 2 : after `N´ : expected `with´',
}
Test { [[
data Opt with
    tag NIL;
or
    tag PTR with
        var void* v;
    end
end
escape 1;
]],
    run = 1,
}

-- recursive ADTs must have a base case
Test { [[
data List with
    tag CONS with
        var int   head;
        var List* tail;
    end
end
escape 1;
]],
    adt = 'line 1 : invalid recursive base case : no parameters allowed',
}
-- the base case must appear first
Test { [[
data List with
    tag CONS with
        var int   head;
        var List* tail;
    end
or
    tag NIL;
end
escape 1;
]],
    adt = 'line 1 : invalid recursive base case : no parameters allowed',
}
-- the base must not have fields
Test { [[
data List with
    tag NIL with
        var int x;
    end
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end
escape 1;
]],
    adt = 'line 1 : invalid recursive base case : no parameters allowed',
}

-- MISC

Test { [[
data Ball with
    var int x, y;
    var int radius;
end

var Ball ball = Ball(130,130,8);
escape ball.x + ball.y + ball.radius;
]],
    run = 268,
}

Test { [[
data Ball with
    var float x;
    var float y;
    var float radius;
end

var Ball ball = Ball(130,130,8);

native do
    int add (s16 a, s16 b, s16 c) {
        return a + b + c;
    }
end

escape _add(ball.x, ball.y, ball.radius);
]],
    run = 268,
}

Test { [[
native do
    int add (int a, int b, int c) {
        return a + b + c;
    }
end

var int sum = 0;
do
    data Ball1 with
        var float x;
        var float y;
        var float radius;
    end
    var Ball1 ball = Ball1(130,130,8);
    sum = sum + _add(ball.x, ball.y, ball.radius);
end

do
    data Ball2 with
        var float x;
        var float y;
        var float radius;
    end
    var Ball2 ball = Ball2(130,130,8);
    sum = sum + _add(ball.x, ball.y, ball.radius);
end

escape sum;
]],
    run = 536,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int  head;
        var List tail;
    end
end
escape 1;
]],
    env = 'line 6 : undeclared type `List´',
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end
var List* l = List.CONS(1,
                List.CONS(2,
                    List.NIL()));
escape l:CONS.tail:CONS.head;
]],
    adt = 'line 9 : invalid constructor : recursive data must use `new´',
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end
var List l = new List.CONS(1,
                List.CONS(2,
                    List.NIL()));
escape l.CONS.tail:CONS.head;
]],
    adt = 'line 9 : invalid recursive data declaration : variable "l" must be a pointer or pool',
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end
var List* l = List.CONS(1,
                List.CONS(2,
                    List.NIL()));
escape l:CONS.tail:CONS.head;
]],
    adt = 'line 9 : invalid constructor : recursive data must use `new´',
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end
var List* l = new List.CONS(1,
                    List.CONS(2,
                        List.NIL()));
escape l:CONS.tail:CONS.head;
]],
    adt = 'line 9 : invalid attribution : must assign to recursive field',
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end
pool List[10] l;
l = List.CONS(1,
        List.CONS(2,
            List.NIL()));
escape l:CONS.tail:CONS.head;
]],
    adt = 'line 10 : invalid constructor : recursive data must use `new´',
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end
pool List[10] lll;
escape lll:NIL;
]],
    run = 1,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end
pool List[10] lll;
lll = new List.CONS(1, List.NIL());
escape lll:CONS.head;
]],
    run = 1,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end
pool List[10] lll;
lll = new List.CONS(1,
            List.CONS(2,
                List.NIL()));
escape lll:CONS.tail:CONS.head;
]],
    run = 2,
}

Test { [[
data Stack with
    tag EMPTY;
or
    tag NONEMPTY with
        var Stack* nxt;
    end
end

pool Stack[] xxx;
xxx = new Stack.NONEMPTY(
        Stack.NONEMPTY(xxx));

escape 1;
]],
    env = 'line 11 : invalid constructor : recursive field "NONEMPTY" must be new data',
}

Test { [[
data Split with
    tag HORIZONTAL;
or
    tag VERTICAL;
end

data Grid with
    tag EMPTY;
or
    tag SPLIT with
        var Split dir;
        var Grid* one;
        var Grid* two;
    end
end

pool Grid[] g;
g = new Grid.SPLIT(Split.HORIZONTAL(), Grid.EMPTY(), Grid.EMPTY());

escape g:SPLIT.one:EMPTY + g:SPLIT.two:EMPTY + g:SPLIT.dir.HORIZONTAL;
]],
    run = 3,
}

Test { [[
data Split with
    tag HORIZONTAL;
or
    tag VERTICAL;
end

data Grid with
    var Split dir;
end

var Grid g1 = Grid(Split.HORIZONTAL());
var Grid g2 = Grid(Split.VERTICAL());

escape g1.dir.HORIZONTAL + g2.dir.VERTICAL;
]],
    run = 2,
}

Test { [[
data Split with
    tag HORIZONTAL;
or
    tag VERTICAL;
end

data Grid with
    tag NIL;
or
    tag SPLIT with
        var Split dir;
        var Grid* g1;
        var Grid* g2;
    end
end

pool Grid[5] g;
g = new Grid.SPLIT(
            Split.HORIZONTAL(),
            Grid.SPLIT(
                Split.VERTICAL(),
                Grid.NIL(),
                Grid.NIL()));

escape 1;
]],
    env = 'line 18 : arity mismatch',
}

Test { [[
data Split with
    tag HORIZONTAL;
or
    tag VERTICAL;
end

data Grid with
    tag NIL;
or
    tag SPLIT with
        var Split dir;
        var Grid* g1;
        var Grid* g2;
    end
end

pool Grid[5] g;
g = new Grid.SPLIT(
            Split.HORIZONTAL(),
            Grid.SPLIT(
                Split.VERTICAL(),
                Grid.NIL(),
                Grid.NIL()),
            Grid.NIL());

escape 1;
]],
    run = 1,
}

Test { [[
data Split with
    tag HORIZONTAL;
or
    tag VERTICAL;
end

data Grid with
    tag NIL;
or
    tag SPLIT with
        var Split dir;
        var Grid* g1;
        var Grid* g2;
    end
end

pool Grid[] g;
g = new Grid.SPLIT(
            Split.HORIZONTAL(),
            Grid.NIL(),
            Grid.NIL());

escape 1;
]],
    run = 1,
}

-- USE DATATYPES DEFINED ABOVE ("DATA")

-- simple test
Test { DATA..[[
escape 1;
]],
    run = 1,
}

-- constructors
Test { DATA..[[
var Pair p1 = Pair(1,2);        /* struct, no tags */
var Opt  o1 = Opt.NIL();        /* unions, explicit tag */
var Opt  o2 = Opt.PTR(&p1);
pool List[] l1;
l1 = new List.NIL();       /* recursive union */
pool List[] l2;
l2 = new List.CONS(1, l1);
escape 1;
]],
    env = 'line 57 : invalid constructor : recursive field "CONS" must be new data',
    -- TODO-ADT-REC-STATIC-CONSTRS
    --run = 1,
}

-- recursive fields are pointers
Test { DATA..[[
pool List[] l1;
l1 = new List.NIL();
pool List[] l2;
l2 = new List.CONS(1, l1);     /* should be &l1 */
escape 1;
]],
    env = 'line 54 : invalid constructor : recursive field "CONS" must be new data',
}

-- constructors must specify the ADT identifier
Test { DATA..[[
var Pair p1 = (1,2);    /* vs Pair(1,2) */
escape 1;
]],
    -- TODO: better error message
    parser = 'line 51 : after `1´ : expected `)´',
    --run = 1,
}
Test { DATA..[[
pool List[] l1;
l1 = new NIL();    /* vs List.NIL() */
escape 1;
]],
    env = 'line 52 : data "NIL" is not declared',
    --run = 1,
}

-- ADT/constructor has to be defined
Test { DATA..[[
var Pair p1 = Unknown(1,2);
escape 1;
]],
    env = 'line 51 : data "Unknown" is not declared',
}
Test { DATA..[[
var Opt  o1 = Unknown.NIL();
escape 1;
]],
    env = 'line 51 : data "Unknown" is not declared',
}

-- tag has to be defined
Test { DATA..[[
var Opt o1 = Opt.UNKNOWN();
escape 1;
]],
    env = 'line 51 : tag "UNKNOWN" is not declared',
}

-- constructors have call syntax
Test { DATA..[[
var List l1 = List.NIL; /* vs List.NIL() */
escape 1;
]],
    parser = 'line 51 : after `NIL´ : expected `(´',
    --run = 1,
}

-- constructors must respect parameters
Test { DATA..[[
var Pair p1 = Pair();           /* expected (x,y) */
escape 1;
]],
    env = 'line 51 : arity mismatch',
}
Test { DATA..[[
var Pair p1 = Pair(1,null);     /* expected (int,int) */
escape 1;
]],
    env = 'line 51 : wrong argument #2',
}
Test { DATA..[[
var Opt o1 = Opt.NIL(1);       /* expected (void) */
escape 1;
]],
    env = 'line 51 : arity mismatch',
}

-- constructors are not expressions...
Test { DATA..[[
escape Opt.NIL();
]],
    parser = 'line 51 : after `escape´ : expected expression',
}
Test { DATA..[[
var List l;
var int v = (l==Opt.NIL());
escape v;
]],
    parser = 'line 52 : after `==´ : expected expression',
}

-- ...but have to be assigned to a variable
Test { DATA..[[
var Opt o;
o = Opt.NIL();
escape 1;
]],
    run = 1,
}
Test { DATA..[[
pool List[] l;
l = new List.NIL();
escape 1;
]],
    run = 1,
}

-- TODO: uninitialized variables?
-- (default values)
-- structs: undefined
-- enums: undefined
-- recursive enums: base case

-- Destructors:
--  - like C
--      - use field names ("dot" notation)
--      - no support for pattern matching
--      - but type safe
--          - tags are checked

-- distinction "constructor" vs "tag check"
Test { DATA..[[
pool List[] l;
l = new List.NIL();   /* call syntax: constructor */
var bool no_ = l:NIL;     /* no-call syntax: check tag */
escape no_;
]],
    run = 1,
}
Test { DATA..[[
pool List[] l;
l = new List.NIL();   /* call syntax: constructor */
var bool no_ = l:CONS;    /* no-call syntax: check tag */
escape no_;
]],
    run = 0,
}

-- destructor == field access
Test { DATA..[[
var Pair p1 = Pair(1,2);
escape p1.x + p1.y;
]],
    run = 3,
}
-- tag NIL has no fields
Test { DATA..[[
pool List[] l;
escape l:NIL.v;
]],
    env = 'line 52 : field "v" is not declared',
}
-- tag Opt.PTR has no field "x"
Test { DATA..[[
var Opt o;
escape o.PTR.x;
]],
    env = 'line 52 : field "x" is not declared',
}

-- mixes Pair/Opt/List and also construcor/tag-check/destructor
Test { DATA..[[
var Pair p1 = Pair(1,2);
var Opt  o1 = Opt.NIL();
var Opt  o2 = Opt.PTR(&p1);
pool List[] l1;
l1 = new List.NIL();
pool List[] l2;
l2 = new List.CONS(1, List.NIL());
pool List[] l3;
l3 = new List.CONS(1, List.CONS(2, List.NIL()));

var int ret = 0;                                // 0

ret = ret + p1.x + p1.y;                        // 3
ret = ret + o1.NIL;                             // 4
ret = ret + (o2.PTR.v==&p1);                    // 5
ret = ret + l1:NIL;                             // 6
ret = ret + l2:CONS.head + l2:CONS.tail:NIL;    // 8
ret = ret + l3:CONS.head + l3:CONS.tail:CONS.head + l3:CONS.tail:CONS.tail:NIL;   // 12

escape ret;
]],
    run = 12,
}

-- destructors are checked at runtime
--      v = l.CONS.head
-- becomes
--      assert(l.CONS)
--      v = l.CONS.head
Test { DATA..[[
pool List[] l;
l = new List.NIL();
escape l:CONS.head;         // runtime error
]],
    asr = true,
    --run = 1,
}
Test { DATA..[[
pool List[] l;
l = new List.CONS(2, List.NIL());
escape l:CONS.head;
]],
    run = 2,
}

-- mixes everything:
Test { DATA..[[
var Pair p  = Pair(1,2);
var Opt  o1 = Opt.NIL();
var Opt  o2 = Opt.PTR(&p);
pool List[] l1;
l1 = new List.NIL();
pool List[] l2;
l2 = new List.CONS(1, List.NIL());
pool List[] l3;
l3 = new List.CONS(1, List.CONS(2, List.NIL()));

var int ret = 0;            // 0

var int x = p.x;
var int y = p.y;
_assert(x+y == 3);
ret = ret + 3;              // 3

if o1.NIL then
    ret = ret + 1;          // 4
else/if o1.PTR then
    _assert(0);             // never reachable
end

if o2.NIL then
    _assert(0);             // never reachable
else/if o2.PTR then
    ret = ret + 1;          // 5
    _assert(o2.PTR.v==&p);
end

if l1:NIL then
    ret = ret + 1;          // 6
else/if l1:CONS then
    _assert(0);             // never reachable
end

if l2:NIL then
    _assert(0);             // never reachable
else/if l2:CONS then
    _assert(l2:CONS.head == 1);
    ret = ret + 1;          // 7
    if l2:CONS.tail:NIL then
        ret = ret + 1;      // 8
    else/if l2:CONS.tail:CONS then
        _assert(0);         // never reachable
    end
    ret = ret + 1;          // 9
end

if l3:NIL then
    _assert(0);             // never reachable
else/if l3:CONS then
    _assert(l3:CONS.head == 1);
    ret = ret + 1;          // 10
    if l3:CONS.tail:NIL then
        _assert(0);         // never reachable
    else/if l3:CONS.tail:CONS then
        _assert(l3:CONS.tail:CONS.head == 2);
        ret = ret + 2;      // 12
        if l3:CONS.tail:CONS.tail:NIL then
            ret = ret + 1;  // 13
        else/if l3:CONS.tail:CONS.tail:CONS then
            _assert(0);     // never reachable
        end
        ret = ret + 1;      // 14
    end
    ret = ret + 1;          // 15
end

escape ret;
]],
    run = 15,
}

-- POINTERS
-- TODO: more discussion
--  - not an lvalue if rvalue not a constructor:
--      ptr:CONS.tail = new ...             // ok
--      ptr:CONS.tail = l:...               // no
--      ptr:CONS.tail = ptr:CONS.tail:...   // ok
--          same prefix

-- cannot cross await statements
Test { DATA..[[
pool List[] l;
l = new List.CONS(1, List.NIL());
var List* p = l:CONS.tail;
await 1s;
escape p:CONS.head;
]],
    --adt = 'line 52 : cannot mix recursive data sources',
    fin = 'line 55 : unsafe access to pointer "p" across `await´',
}

-- COPY / MUTATION
--  - intentional feature
--  - ADTs are substitutes for enum/struct/union
--  - must be "as efficient" and with similar semantics
-- TODO: more discussion

-- linking a list: 2-1-NIL
Test { DATA..[[
pool List[] l1;
l1 = new List.NIL();
pool List[] l2;
l2 = new List.CONS(1, l1);
pool List[] l3;
l3 = new List.CONS(2, l2);
escape l3:CONS.head + l3:CONS.tail:CONS.head + l3:CONS.tail:CONS.tail:NIL;
]],
    --run = 4,
    env = 'line 54 : invalid constructor : recursive field "CONS" must be new data',
    -- TODO-ADT-REC-STATIC-CONSTRS
}
Test { DATA..[[
pool List[] l3;
l3 = new List.CONS(2, List.CONS(1, List.NIL()));
escape l3:CONS.head + l3:CONS.tail:CONS.head + l3:CONS.tail:CONS.tail:NIL;
]],
    run = 4,
}
-- breaking a list: 2-1-NIL => 2-NIL
Test { DATA..[[
pool List[] l1;
pool List[] l3;
l1 = new List.NIL();
l3 = new List.CONS(2, List.CONS(1, List.NIL()));
l3:CONS.tail = l1;
escape l3:CONS.head + l3:CONS.tail:NIL;
]],
    adt = 'line 55 : cannot mix recursive data sources',
    run = 3,
}

-- circular list: 1-1-1-...
Test { DATA..[[
pool List[] l1;
pool List[] l2;
l1 = new List.NIL();
l2 = new List.CONS(1, List.NIL());
l1 = l2;
escape l1:CONS + (l1:CONS.head==1);
]],
    adt = 'line 55 : cannot mix recursive data sources',
    run = 2,
}
Test { DATA..[[
pool List[] l1, l2;
l1 = new List.NIL();
l2 = new List.CONS(1, List.NIL());
l1 = l2;
escape l1:CONS + (l1:CONS.head==1) + (l1:CONS.tail:CONS.tail:CONS.head==1);
]],
    adt = 'line 54 : cannot mix recursive data sources',
    run = 3,
}

-- circular list: 1-2-1-2-...
Test { DATA..[[
pool List[] l1, l2;
l1 = new List.CONS(1, List.NIL());
l2 = new List.CONS(2, List.NIL());
l1:CONS.tail = l2;
escape (l1:CONS.head==1) + (l1:CONS.tail:CONS.head==2) +
       (l2:CONS.head==2) + (l2:CONS.tail:CONS.head==1) +
       (l1:CONS.tail:CONS.tail:CONS.tail:CONS.head==2);
]],
    adt = 'line 54 : cannot mix recursive data sources',
    run = 5,
}

-- another circular list
Test { DATA..[[
pool List[] l1, l2;
l1 = new List.CONS(1, List.NIL());
l2 = new List.CONS(2, List.NIL());
l1:CONS.tail = l2;
l2:CONS.tail = l1;

escape l1:CONS.head + l1:CONS.tail:CONS.head + l2:CONS.head + l2:CONS.tail:CONS.head;
]],
    adt = 'line 54 : cannot mix recursive data sources',
    run = 6,
}

-- not circular
Test { DATA..[[
pool List[] l1, l2;
l1 = new List.NIL();
l2 = new List.CONS(1, List.NIL());
l1 = l2:CONS.tail;
escape l1:NIL;
]],
    adt = 'line 54 : cannot mix recursive data sources',
    run = 1,
}

-- DYNAMIC ADTs:
--  - can only describe directed-rooted-tree
--      - no double linked lists, no circular ADTs
--  - different types for static/dynamic ADTs
--  - they can never be mixed
--  - TODO:
--      - now explicit (List vs List)
--      - in the future distinguish/create automatically/implicitly
--          - declare only List
--              - implicitly expand to List/List

-- TODO: non-recursive dynamic ADTs
--  - does it even make sense?

-- dynamic ADTs require a pool
Test { DATA..[[
pool List[] l;     // all instances reside here
escape 1;
]],
    run = 1,
}

-- the pool variable is overloaded:
--  - represents the pool
--  - represents the root of the tree
Test { DATA..[[
pool List[] l;     // l is the pool
escape l:NIL;       // l is a pointer to the root
]],
    run = 1,
}
Test { DATA..[[
pool List[] l;     // l is the pool
escape (*l).NIL;    // equivalent to above
]],
    run = 1,
}
-- the pointer must be dereferenced
Test { DATA..[[
pool List[] l;     // l is the pool
escape l.NIL;       // "l" is not a struct
]],
    env = 'line 52 : invalid access (List[] vs List)',
}
Test { DATA..[[
pool List[] l;     // l is the pool
escape l.CONS.head; // "l" is not a struct
]],
    env = 'line 52 : invalid access (List[] vs List)',
}
Test { DATA..[[
pool List[] l;             // l is the pool
escape l:CONS.tail.CONS;    // "l:CONS.tail" is not a struct
]],
    env = 'line 52 : not a struct',
}

-- the pool is initialized to the base case of the ADT
-- (this is why the base case cannot have fields and
--  must appear first in the ADT declaration)
Test { DATA..[[
pool List[] l;
escape l:CONS;      // runtime error
]],
    asr = true,
}

-- dynamic ADTs have automatic memory management
--  - similar to organisms
Test { DATA..[[
var int ret = 0;
do
    pool List[] l;
    ret = l:NIL;
end
// all instances in "l" have been collected
escape ret;
]],
    run = 1,
}

-- TODO: escape analysis for instances going to outer scopes
-- TODO: mixing static/static, dynamic/dynamic, static/dynamic

-- Dynamic constructors:
--  - must use "new"
--  - the pool is inferred from the l-value
Test { DATA..[[
pool List[] l;
l = new List.NIL();
escape l:NIL;
]],
    run = 1,
}
Test { DATA..[[
pool List[] l;
l = new List.CONS(2, List.NIL());
escape l:CONS.head;
]],
    run = 2,
}
Test { DATA..[[
pool List[] l;
l = new List.CONS(1, List.CONS(2, List.NIL()));
escape l:CONS.head + l:CONS.tail:CONS.head + l:CONS.tail:CONS.tail:NIL;
]],
    run = 4,
}
-- wrong tag
Test { DATA..[[
pool List[] l;
l = new List.NIL();
escape l:CONS;
]],
    asr = true,
}
-- no "new"
Test { DATA..[[
pool List[] l;
l = List.CONS(2, List.NIL());
escape l:CONS.head;
]],
    adt = 'line 52 : invalid constructor : recursive data must use `new´',
    --env = 'line 52 : invalid call parameter #2 (List vs List*)',
}
-- cannot assign "l" directly (in the pool declaration)
Test { DATA..[[
pool List[] l = new List.CONS(2, List.NIL());
escape l.CONS.head;
]],
    parser = 'line 51 : after `l´ : expected `;´',
}
-- no dereference
Test { DATA..[[
pool List[] l;
l = new List.NIL();
escape l.NIL;
]],
    env = 'line 53 : invalid access (List[] vs List)',
}
Test { DATA..[[
pool List[] l;
l = new List.CONS(2, List.NIL());
escape l.CONS.head;
]],
    env = 'line 53 : invalid access (List[] vs List)',
}

-- static vs heap pools
--      pool List[] l;      // instances go to the heap
-- vs
--      pool List[10] l;    // 10 instances at most
-- (same as for organisms)

-- allocation fails (0 space)
-- fallback to base case (which is statically allocated in the initialization)
-- (this is also why the base case cannot have fields and
--  must appear first in the ADT declaration)
-- (
Test { DATA..[[
pool List[0] l;
l = new List.CONS(2, List.NIL());
escape l:NIL;
]],
    run = 1,
}
Test { DATA..[[
pool List[0] l;
l = new List.CONS(2, List.NIL());
escape l:CONS.head;     // runtime error
]],
    asr = true,
}
-- 2nd allocation fails (1 space)
Test { DATA..[[
pool List[1] l;
l = new List.CONS(2, List.CONS(1, List.NIL()));
_assert(l:CONS.tail:NIL);
escape l:CONS.head;
]],
    run = 2,
}
-- 3rd allocation fails (2 space)
Test { DATA..[[
pool List[2] l;
l = new List.CONS(1, List.CONS(2, List.CONS(3, List.NIL())));
_assert(l:CONS.tail:CONS.tail:NIL);
escape l:CONS.head + l:CONS.tail:CONS.head + l:CONS.tail:CONS.tail:NIL;
]],
    run = 4,
}

-- dereference test for static pools
-- (nothing new here)
Test { DATA..[[
pool List[0] l;
l = new List.CONS(2, List.NIL());
escape l.NIL;
]],
    env = 'line 53 : invalid access (List[] vs List)',
    --run = 1,
}

Test { [[
data T with
    tag NIL;
or
    tag NXT with
        var int v;
        var T*  nxt;
    end
end
pool T[] ts;
do
    ts = new T.NIL();
end
escape ts:NIL;
]],
    run = 1,
}

-- Mutation in dynamic ADTs:
--  - "dropped" subtrees are automatically reclaimed:
--      l = new ...
-- becomes
--      tmp = new ...   // "new" happens before!
--      free(l)         // "free" happens after!
--      l = tmp
--  (this is why dynamic ADTs have to be a directed rooted trees)

-- 1-NIL => 2-NIL
-- 1-NIL can be safely reclaimed
Test { DATA..[[
pool List[1] l;
l = new List.CONS(1, List.NIL());
l = new List.CONS(2, List.NIL());    // this fails (new before free)!
escape l:CONS.head;
]],
    asr = true,
}

Test { DATA..[[
pool List[1] l;
l = new List.CONS(1, List.NIL());
l:CONS.tail = new List.CONS(2, List.NIL()); // fails
escape l:CONS.tail:NIL;
]],
    run = 1,
    --asr = true,
}

-- 1-2-NIL
Test { DATA..[[
pool List[2] l;
l = new List.CONS(1, List.NIL());
l:CONS.tail = new List.CONS(2, List.NIL()); // fails
escape l:CONS.tail:CONS.head;
]],
    run = 2,
}

-- 1-NIL => 2-NIL
-- 1-NIL can be safely reclaimed
Test { DATA..[[
pool List[2] l;
l = new List.CONS(1, List.NIL());
l = new List.CONS(2, List.NIL());    // no allocation fail
escape l:CONS.head;
]],
    run = 2,
}

-- 1-2-3-NIL => 1-2-NIL (3 fails)
-- 4-5-6-NIL => NIL     (all fail)
Test { DATA..[[
pool List[2] l;
l = new List.CONS(1, List.CONS(2, List.CONS(3, List.NIL())));   // 3 fails
_ceu_out_assert(l:CONS.tail:CONS.tail:NIL, "1");
l = new List.CONS(4, List.CONS(5, List.CONS(6, List.NIL())));   // 6 fails
_ceu_out_assert(l:CONS.tail:CONS.tail:NIL, "2");
escape l:CONS.tail:CONS.head;
]],
    run = 5,
}

-- 1-2-3-NIL => 1-2-NIL (3 fails)
-- (clear all)
-- 4-5-6-NIL => 4-5-NIL (6 fails)
Test { DATA..[[
pool List[2] l;
l = new List.CONS(1, List.CONS(2, List.CONS(3, List.NIL())));   // 3 fails
_assert(l:CONS.tail:CONS.tail:NIL);
l = new List.NIL();                                                // clear all
l = new List.CONS(4, List.CONS(5, List.CONS(6, List.NIL())));   // 6 fails
_assert(l:CONS.tail:CONS.tail:NIL);
escape l:CONS.head + l:CONS.tail:CONS.head + (l:CONS.tail:CONS.tail:NIL);
]],
    run = 10,
}

-- Mutation in subtrees:
--  - ok: child attributed to parent
--      - parent subtree is dropped, child substitutes it
--  - no: parent attributed to child
--      - creates a cycle / makes child orphan
--      - TODO (could "swap" ?)
--  - RULE: either r-val is constructor or
--                 l-val is prefix of r-val

-- ok: child is constructor (with no previous parent)
-- NIL
-- 1-NIL
-- 1-2-NIL
Test { DATA..[[
pool List[2] l;
l = new List.CONS(1, List.NIL());
l:CONS.tail = new List.CONS(2, List.NIL());
escape l:CONS.head + l:CONS.tail:CONS.head;
]],
    run = 3,
}
-- ok: tail is child of l
-- NIL
-- 1-2-NIL
-- 1-NIL
Test { DATA..[[
pool List[2] lll;
lll = new List.CONS(1, List.CONS(2, List.NIL()));
lll = lll:CONS.tail;    // parent=child
escape lll:CONS.head;
]],
    run = 2,
}
Test { DATA..[[
pool List[2] lll;
lll = new List.CONS(1, List.CONS(2, List.NIL()));
lll = lll:CONS.tail;
lll:CONS.tail = new List.CONS(3, List.NIL());
escape 1;
]],
    run = 1,
}
Test { DATA..[[
pool List[2] lll;
lll = new List.CONS(1, List.CONS(2, List.NIL()));
lll = lll:CONS.tail;    // parent=child
lll:CONS.tail = new List.CONS(3, List.CONS(4, List.NIL()));    // 4 fails
escape lll:CONS.head + lll:CONS.tail:CONS.head + lll:CONS.tail:CONS.tail:NIL;
]],
    run = 6,
}
Test { DATA..[[
pool List[2] l;
l = new List.CONS(1, List.CONS(2, List.NIL()));
l = l:CONS.tail;    // parent=child
l:CONS.tail = new List.CONS(3, List.CONS(4, List.NIL()));    // 4 fails
escape l:CONS.head + l:CONS.tail:CONS.head + l:CONS.tail:CONS.tail:NIL;
]],
    run = 6,
}

-- no: l is parent of tail
-- NIL
-- 1-2-NIL
-- 1-2-^1   (no)
Test { DATA..[[
pool List[2] l;
l = new List.CONS(1, List.CONS(2, List.NIL()));
l:CONS.tail = l;    // child=parent
escape 1;
]],
    adt = 'line 53 : cannot assign parent to child',
}

-- OPTION TYPES

Test { [[
data OptionInt with
    tag NIL;
or
    tag SOME with
        var int v;
    end
end

data OptionPtr with
    tag NIL;
or
    tag SOME with
        var int* v;
    end
end

var int ret = 0;            // 0

var OptionInt i = OptionInt.NIL();
var OptionPtr p = OptionPtr.NIL();
ret = ret + i.NIL + p.NIL;  // 2

i = OptionInt.SOME(3);
ret = ret + i.SOME.v;       // 5

p = OptionPtr.SOME(&ret);
*p.SOME.v = *p.SOME.v + 2;    // 7

var int v = 10;
p = OptionPtr.SOME(&v);
*p.SOME.v = *p.SOME.v + 1;

ret = ret + v;              // 18
escape ret;
]],
    run = 18,
}

Test { [[
var int? i;
escape 1;
]],
    run = 1,
}

Test { [[
var int? i = 1;
escape i;
]],
    run = 1,
}

Test { [[
var int? i;
escape 1;
]],
    run = 1,
}

Test { [[
var int? i;
escape not i?;
]],
    run = 1,
}

Test { [[
var int? i;
escape not i?;
]],
    run = 1,
}

Test { [[
var int v = 10;
var int&? i;
escape not i?;
]],
    --ref = 'line 3 : reference must be bounded before use',
    run = 1,
}

Test { [[
var int v = 10;
var int&? i;
escape not i?;
]],
    run = 1,
}

Test { [[
var int v = 10;
var int&? i;
escape not i?;
]],
    run = 1,
}

Test { [[
var int v = 10;
var int&? i = v;
escape i;
]],
    run = 10,
}

Test { [[
var int v1 = 0;
var int v2 = 1;
var int&? i = v1;
i = v2;
escape v1;
]],
    run = 1,
}

Test { [[
var int v = 10;
var int& i = v;
escape v + i;
]],
    run = 20,
}

Test { [[
var int v = 10;
var int&? i = v;
escape v + i;
]],
    run = 20,
}

Test { [[
var int v1 = 10;
var int v2 =  1;
var int&? i = v1;
i = v2;
i = 10;
var int ret = i;
escape v1 + v2 + ret;
]],
    run = 21,
}

Test { [[
class T with
    var int&? i;
do
    var int v = 10;
    this.i = v;
end
var T t;
escape t.i;
]],
    asr = ':5] runtime error: invalid tag',
    --run = 10,
}
Test { [[
class T with
    var int&? i;
do
    var int v = 10;
    this.i = v;
end
var int i = 0;
var T t with
    this.i = i;
end;
escape t.i;
]],
    --asr = ':5] runtime error: invalid tag',
    run = 10,
}
Test { [[
var int v = 10;
class T with
    var int&? i;
do
    var int v = 10;
end
var T t with
    this.i = v;
end;
v = v / 2;
escape t.i? + t.i + 1;
]],
    run = 7,
}
Test { [[
class T with
    var int&? i;
do
    var int v = 10;
end
var T t;
escape t.i? + 1;
]],
    run = 1,
}
Test { [[
class T with
    var int&? i;
do
    var int v = 10;
end
var T t;
escape t.i;
]],
    asr = true,
}
Test { [[
class T with
    var int&? i;
do
    var int v = 10;
end
var int v = 1;
var T t with
    this.i = v;
end;
v = 11;
escape t.i;
]],
    run = 11,
}

Test { [[
native @nohold _g();
var _SDL_Texture&? t_enemy_0, t_enemy_1;
finalize
    t_enemy_1 = _f();
with
    _g(&t_enemy_1);
end
escape 1;
]],
    gcc = 'error: unknown type name ‘SDL_Texture’',
}

Test { [[
native do
    typedef struct {
        int x;
    } t;
    int id (int v) {
        return v;
    }
end
native @pure _id();

var _t t;
    t.x = 11;

var _t&? t_ = t;

var int ret = t_.x;
t_.x = 100;

escape ret + _id(t_.x) + t.x;
]],
    run = 211,
}

Test { [[
class T with
    var int&? v;
do
end
var T t;
escape 1;
]],
    run = 1,
}

Test { [[
native do
    void* myalloc (void) {
        return NULL;
    }
    void myfree (void* v) {
    }
end
native @nohold _myfree();

var void&? v;
finalize
    v = _myalloc();
with
    _myfree(&v);
end

escape 1;
]],
    asr = true,
}

Test { [[
native do
    void* myalloc (void) {
        return NULL;
    }
    void myfree (void* v) {
    }
end
native @nohold _myfree();

var void&? v;
finalize
    v = _myalloc();
with
    if v? then
        _myfree(&v);
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
native do
    ##define UNSAFE_POINTER_TO_REFERENCE(ptr) ptr
end
native @nohold _UNSAFE_POINTER_TO_REFERENCE();

native do
    int v2 = 10;
    int* V1 = NULL;
    int* V2 = &v2;
    int* fff (int i) {
        if (i == 1) {
            return NULL;
        } else {
            return V2;
        }
    }
end

var int&? v1;
    finalize
        v1 = _fff(1);
    with
        nothing;
    end

var int&? v2;
    finalize
        v2 = _fff(2);
    with
        nothing;
    end

var int&? v3;
    finalize
        v3 = _UNSAFE_POINTER_TO_REFERENCE(_V1);
    with
        nothing;
    end

var int&? v4;
    finalize
        v4 = _UNSAFE_POINTER_TO_REFERENCE(_V2);
    with
        nothing;
    end

escape (not v1?) + (not v3?) + v2? + v4? + (&v2==_V2) + (&v4==_V2) + v2 + v4;
]],
    run = 26,
}

Test { [[
data SDL_Color with
    var int v;
end
interface UI with
    var SDL_Color? bg_clr;
end
escape 1;
]],
    run = 1,
}

Test { [[
data SDL_Color with
    var int v;
end
var SDL_Color clr = SDL_Color(10);
var SDL_Color? bg_clr = clr;
escape bg_clr.v;
]],
    run = 10,
}
Test { [[
data SDL_Color with
    var int v;
end
var SDL_Color? bg_clr = SDL_Color(10);
escape bg_clr.v;
]],
    run = 10,
}

Test { [[
data SDL_Color with
    var int v;
end
class UI with
    var SDL_Color? bg_clr;
do
end
var UI ui with
    this.bg_clr = SDL_Color(10);
end;
escape ui.bg_clr.v;
]],
    run = 10,
}

Test { [[
native do
    ##define fff(id) id
end
data SDL_Color with
    var int v;
end
class UI with
    var SDL_Color? bg_clr;
do
end
var UI ui with
    this.bg_clr = SDL_Color(10);
end;
escape _fff(ui.bg_clr).v;
]],
    run = 10,
}

Test { [[
data OptionInt with
    tag NIL;
or
    tag SOME with
        var int v;
    end
end

data OptionPtr with
    tag NIL;
or
    tag SOME with
        var int* v;
    end
end

var int ret = 0;    // 0

var int?  i;
var int&? p;
ret = ret + (not i?) + (not p?);  // 2

i = 3;
ret = ret + i;      // 5

// first
p = ret;
p = p + 2;          // 7
_assert(ret == 7);

// second
var int v = 10;
p = v;              // 10
p = p + 1;          // 11

ret = ret + v;      // 21
escape ret;
]],
    run = 21,
}

-- cannot compare ADTs
Test { DATA..[[
var Pair p1 = Pair(1,2);
var Pair p2 = Pair(1,2);
escape p1==p2;
]],
    env = 'line 53 : invalid operation for data',
    --run = 1,
}
Test { DATA..[[
pool List[] l1, l2;
l2 = new List.NIL();
escape l1==l2;
]],
    env = 'line 53 : invalid operands to binary "=="',
    --run = 1,
}

-- cannot mix recursive ADTs
Test { DATA..[[
pool List[] l1, l2;
l1 = new List.CONS(1, List.NIL());
l2 = new List.CONS(2, List.NIL());
l1:CONS.tail = l2;
escape l1:CONS.tail:CONS.head;
]],
    adt = 'line 54 : cannot mix recursive data sources',
}
Test { DATA..[[
pool List[] l1;
l1 = new List.CONS(1, List.NIL());
do
    pool List[] l2;
    l2 = new List.CONS(2, List.NIL());
    l1:CONS.tail = l2;
end
escape l1:CONS.tail:CONS.head;
]],
    adt = 'line 56 : cannot mix recursive data sources',
    --fin = 'line 54 : attribution to pointer with greater scope',
}
Test { DATA..[[
pool List[] l1;
l1 = new List.CONS(1, List.NIL());
pool List[2] l2;
l2 = new List.CONS(2, List.NIL());
l1:CONS.tail = l2;
escape l1:CONS.tail:CONS.head;
]],
    adt = 'line 55 : cannot mix recursive data sources',
}
Test { DATA..[[
pool List[2] l1;
pool List[2] l2;
l1 = new List.CONS(1, List.NIL());
l2 = new List.CONS(2, List.NIL());
l1:CONS.tail = l2;
escape l1:CONS.tail:CONS.head;
]],
    adt = 'line 55 : cannot mix recursive data sources',
}

Test { DATA..[[
var int ret = 0;                // 0

pool List[5] l;

// change head [2]
l = new List.CONS(1, List.NIL());
ret = ret + l:CONS.head;        // 2
_assert(ret == 1);

// add 2 [1, 2]
l:CONS.tail = new List.CONS(1, List.NIL());
ret = ret + l:CONS.head;        // 3
ret = ret + l:CONS.head + l:CONS.tail:CONS.head;
                                // 6
_assert(ret == 6);

// change tail [1, 2, 4]
l:CONS.tail:CONS.tail = new List.CONS(4, List.NIL());
                                // 10

pool List[] l3;
l3 = new List.CONS(3, List.NIL());
l:CONS.tail:CONS.tail = l3;
_assert(l:CONS.tail:CONS.head == 3);
_assert(l:CONS.tail:CONS.tail:CONS.head == 4);
ret = ret + l:CONS.tail:CONS.head + l:CONS.tail:CONS.tail:CONS.head;
                                // 17

// drop middle [1, 3, 4]
l:CONS.tail = l:CONS.tail:CONS.tail;
ret = ret + l:CONS.tail:CONS.head;
                                // 20

// fill the list [1, 3, 4, 5, 6] (7 fails)
l:CONS.tail:CONS.tail:CONS.tail =
    new List.CONS(5, List.CONS(6, List.CONS(7, List.NIL())));

escape ret;
]],
    adt = 'line 73 : cannot mix recursive data sources',
    run = -1,
}

Test { [[
interface IGUI_Component with
    var _void&? nat;
end

class EnterLeave with
    var IGUI_Component& gui;
do
    var _void* g = &gui.nat;
end
escape 1;
]],
    run = 1,
}

Test { [[
class T with
    var int? x;
do
end

class U with
    var T& t;
do
end

var T t with
    this.x = 10;
end;

var U u with
    this.t = t;
end;

escape u.t.x;
]],
    run = 10,
}

Test { [[
class T with
    var int? x;
do
end

class U with
    var T& t;
    var int ret;
do
    this.ret = t.x;
end

var T t with
    this.x = 10;
end;

var U u with
    this.t = t;
end;

escape u.t.x + u.ret;
]],
    run = 20,
}

Test { [[
class T with
    var int&? x;
do
end

class U with
    var T& t;
    var int ret;
do
    this.ret = t.x;
end

var int z = 10;

var T t with
    this.x = z;
end;

var U u with
    this.t = t;
end;

escape u.t.x + u.ret;
]],
    run = 20,
}

Test { [[
interface I with
    var int? x;
end

class T with
    interface I;
do
end

class U with
    var T& t;
do
end

var T t with
    this.x = 10;
end;

var U u with
    this.t = t;
end;

escape u.t.x;
]],
    run = 10,
}

Test { [[
interface I with
    var int? v;
end

class U with
    interface I;
do
end

var U u with
    this.v = 10;
end;
var I* i = &u;

escape i:v;
]],
    run = 10,
}

Test { [[
class T with
    var int? x;
do
end

interface I with
    var T& t;
end

class U with
    interface I;
do
end

var T t with
    this.x = 10;
end;

var U u with
    this.t = t;
end;
var I* i = &u;

escape ((*i).t).x;
]],
    run = 10,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] list;

list = new List.CONS(10, List.NIL());
var List* l = list;

watching *l do
    await 1s;
end

escape 0;
]],
    env = 'line 15 : invalid operand to unary "*"',
    --env = 'line 15 : data must be a pointer',
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] list;

list = new List.CONS(10, List.NIL());

pool List[]& lll;
lll = list;

escape lll:CONS.head;
]],
    run = 10,
}
Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] list;

list = new List.CONS(10, List.NIL());

pool List*[] lll;
lll = list;

escape lll:CONS.head;
]],
    run = 10,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] list;

list = new List.CONS(10, List.NIL());
pool List*[] l ;
l = list;

l:CONS.tail = new List.CONS(9, List.NIL());
l = l:CONS.tail;

l:CONS.tail = new List.CONS(8, List.NIL());
l = l:CONS.tail;

escape l:CONS +
        list:CONS.head +
        list:CONS.tail:CONS.head +
        list:CONS.tail:CONS.tail:CONS.head;
]],
    run = 28,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] list;

list = new List.CONS(10, List.NIL());
pool List*[] l;
l = list;

l:CONS.tail = new List.CONS(9, List.NIL());
l = l:CONS.tail;

watching l do
    await 1s;

    l:CONS.tail = new List.CONS(8, List.NIL());
    l = l:CONS.tail;

    escape l:CONS.head +
            list:CONS.head +
            list:CONS.tail:CONS.head +
            list:CONS.tail:CONS.tail:CONS.head;
end

escape 0;
]],
    run = { ['~>1s'] = 35 },
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[10] list;

list = new List.CONS(10, List.NIL());
pool List*[] lll;
lll = list;

lll:CONS.tail = new List.CONS(9, List.NIL());
lll = lll:CONS.tail;

par do
    watching lll do
        await 1s;

        lll:CONS.tail = new List.CONS(8, List.NIL());
        lll = lll:CONS.tail;

        escape lll:CONS.head +
                list:CONS.head +
                list:CONS.tail:CONS.head +
                list:CONS.tail:CONS.tail:CONS.head;
    end
    escape 1;
with
    list = new List.NIL();
    await FOREVER;
end
]],
    _ana = {acc=true},
    run = 1,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] list;

list = new List.CONS(10, List.NIL());
pool List*[] lll;
lll = list;

lll:CONS.tail = new List.CONS(9, List.NIL());
lll = lll:CONS.tail;

par do
    watching lll do
        await 1s;

        lll:CONS.tail = new List.CONS(8, List.NIL());
        lll = lll:CONS.tail;

        escape lll:CONS.head +
                list:CONS.head +
                list:CONS.tail:CONS.head +
                list:CONS.tail:CONS.tail:CONS.head;
    end
    escape 1;
with
    list = new List.NIL();
    await FOREVER;
end
]],
    _ana = {acc=true},
    run = 1,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

var List l;
escape 1;
]],
    adt = 'line 10 : invalid recursive data declaration : variable "l" must be a pointer or pool',
}

-- ADTS / RECURSE / TRAVERSE

-- crashes with org->ret
Test { [[
class T with
do
    await FOREVER;
end

event T* e;

input void OS_START;

par do
    do
        par/or do
            await OS_START;
            pool T[1] ts;
            var T*? ptr = spawn T in ts;
            emit e => ptr;
        with
            var T* t = await e;
        end
    end
    do
        var int[100] is;
        loop i in 100 do
            is[i] = i;
        end
    end
    await 1s;
    escape 1;
with
    var T* t = await e;
    var int ret = await *t;     // crash!
    escape ret;
end
]],
    run = { ['~>1s']=1 },
}

Test { [[
data Widget with
    tag NIL;
or
    tag ROW with
        var Widget* w1;
    end
end

pool Widget[] widgets;
traverse widget in widgets do
    watching widget do
        var int v1 = traverse widget:ROW.w1;
    end
end

escape 1;
]],
    _ana = {acc=true},
    wrn = true,
    run = 1,
}

-- leaks memory because of lost "free" in IN__STK
Test { [[
data T with
    tag NIL;
or
    tag NXT with
        var int v;
        var T*  nxt;
    end
end

pool T[] ts;

ts = new T.NXT(10, T.NXT(9, T.NIL()));

par/or do
    await ts;           // 2. but continuation is aborted
with
    ts = new T.NIL();   // 1. free is on continuation
end

escape 1;
]],
    _ana = { acc=true },
    run = 1,
}

Test { [[
data T with
    tag NIL;
or
    tag NXT with
        var int v;
        var T*  nxt;
    end
end

pool T[] ts;

ts = new T.NXT(10, T.NXT(9, T.NIL()));

var int ret = 10;

par/or do
    watching ts do
        await FOREVER;
    end
    ret = ret * 2;
with
    watching ts:NXT.nxt do
        await FOREVER;
    end
    ret = 0;
with
    watching ts:NXT.nxt:NXT.nxt do
        await FOREVER;
    end
    ret = ret - 1;  // awakes first from NIL
    await FOREVER;
with
    ts = new T.NIL();
    ret = 0;
end

escape ret;
]],
    _ana = { acc=true },
    run = 18,
}

Test { [[
class Body with
    pool  Body[]& bodies;
    var   int&    sum;
    event int     ok;
do
    finalize with end;

    var Body*? nested =
        spawn Body in bodies with
            this.bodies = bodies;
            this.sum    = sum;
        end;
    if nested? then
        watching *nested do
            await nested:ok;
        end
    end
    await 1s;
    sum = sum + 1;
    emit this.ok => 1;
end


pool Body[] bodies;
var  int     sum = 0;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;
await b;

escape sum;
]],
    wrn = 'line 9 : unbounded recursive spawn',
    run = { ['~>200s'] = 101 },
}
Test { [[
class Body with
    pool  Body[2]& bodies;
    var   int&    sum;
    event int     ok;
do
    finalize with end;

    var Body*? nested =
        spawn Body in bodies with
            this.bodies = bodies;
            this.sum    = sum;
        end;
    if nested? then
        watching *nested do
            await nested:ok;
        end
    end
    await 1s;
    sum = sum + 1;
    emit this.ok => 1;
end


pool Body[2] bodies;
var  int     sum = 0;

var Body b with
    this.bodies = bodies;
    this.sum    = sum;
end;
await b;

escape sum;
]],
    run = { ['~>10s'] = 3 },
}

Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

class Body with
    pool  Body[]& bodies;
    var   Tree*   n;
    var   int&    sum;
    event int     ok;
do
    watching n do
        var int i = this.sum;
        if n:NODE then
            var Body*? left =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:NODE.left;
                    this.sum    = sum;
                end;
            if left? then
                watching *left do
                    await left:ok;
                end
            end

            this.sum = this.sum + i + n:NODE.v;

            var Body*? right =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:NODE.right;
                    this.sum    = sum;
                end;
            if right? then
                watching *right do
                    await right:ok;
                end
            end

            //do/spawn Body in this.bodies with
                //this.n = n:NODE.left;
            //end;
        end
    end
    await 1s;
    emit this.ok => 1;
end

var int sum = 0;

pool Body[7] bodies;
do Body with
    this.bodies = bodies;
    this.n      = tree;
    this.sum    = sum;
end;

escape sum;

/*
var int sum = 0;
traverse n in tree do
    var int i = sum;
    if n:NODE then
        traverse n:NODE.left;
        sum = i + n:NODE.v;
        traverse n:NODE.right;
    end
end
escape sum;
*/
]],
    wrn = 'line 26 : unbounded recursive spawn',
    run = { ['~>10s'] = 9 },
}
Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

class Body with
    pool  Body[7]& bodies;
    var   Tree*    n;
    var   int&     sum;
    event int      ok;
do
    watching n do
        var int i = this.sum;
        if n:NODE then
            var Body*? left =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:NODE.left;
                    this.sum    = sum;
                end;
            if left? then
                watching *left do
                    await left:ok;
                end
            end

            this.sum = this.sum + i + n:NODE.v;

            var Body*? right =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:NODE.right;
                    this.sum    = sum;
                end;
            if right? then
                watching *right do
                    await right:ok;
                end
            end

            //do/spawn Body in this.bodies with
                //this.n = n:NODE.left;
            //end;
        end
    end
    await 1s;
    emit this.ok => 1;
end

var int sum = 0;

pool Body[7] bodies;
do Body with
    this.bodies = bodies;
    this.n      = tree;
    this.sum    = sum;
end;

escape sum;

/*
var int sum = 0;
traverse n in tree do
    var int i = sum;
    if n:NODE then
        traverse n:NODE.left;
        sum = i + n:NODE.v;
        traverse n:NODE.right;
    end
end
escape sum;
*/
]],
    run = { ['~>10s'] = 9 },
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[3] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

class Body with
    pool  Body[]& bodies;
    var   List*   n;
do
    if n:NIL then
    end
    watching n do
        if n:CONS then
            spawn Body in this.bodies with
                this.bodies = bodies;
                this.n      = n:CONS.tail;
            end;
        end
    end
end

pool Body[3] bodies;
do Body with
    this.bodies = bodies;
    this.n      = list;
end;

escape 1;
]],
    fin = 'line 19 : unsafe access to pointer "n" across `class´ (tests.lua : 15)',
}
Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[3] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

var int sum = 0;

traverse n in list do
    if n:NIL then
        sum = sum * 2;
    end
    watching n do
        if n:CONS then
            sum = sum + n:CONS.head;
            traverse n:CONS.tail;
        end
    end
end

escape sum;
]],
    wrn = 'line 42 : unbounded recursive spawn',
    _ana = { acc=true },
    run = 12,
}



Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int  v = 0;
var int* ptr = &v;

traverse t in tree do
    *ptr = *ptr + 1;
    if t:NODE then
        traverse t:NODE.left;
        traverse t:NODE.right;
    end
end

escape v;
]],
    fin = 'line 20 : unsafe access to pointer "ptr" across `class´',
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[3] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

native do
    int V = 0;
end

/*
traverse n in list do
    _V = _V + 1;
    if n:CONS then
        _V = _V + n:CONS.head;
        traverse n:CONS.tail;
    end
end
*/

class Body with
    pool  Body[3]& bodies;
    var   List*    n;
do
    if n:NIL then
        _V = _V * 2;
    end
    watching n do
        _V = _V + 1;
        if n:CONS then
            _V = _V + n:CONS.head;

            var Body*? tail =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:CONS.tail;
                end;
            if tail? then
                await *tail;
            end
        end
    end
end

pool Body[3] bodies;
do Body with
    this.bodies = bodies;
    this.n      = list;
end;

escape _V;
]],
    fin = 'line 33 : unsafe access to pointer "n" across `class´',
}

Test { [[
data List with
    tag NIL_;
or
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[4] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

native do
    int V = 0;
end

/*
traverse n in list do
    _V = _V + 1;
    if n:CONS then
        _V = _V + n:CONS.head;
        traverse n:CONS.tail;
    end
end
*/

class Body with
    pool  Body[4]& bodies;
    var   List*    n;
do
    watching n do
        if n:NIL then
            _V = _V * 2;
        else/if n:CONS then
            _V = _V + 1;
            _V = _V + n:CONS.head;

            var Body*? tail =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:CONS.tail;
                end;
            if tail? then
                await *tail;
            end
        end
    end
end

pool Body[4] bodies;
do Body with
    this.bodies = bodies;
    this.n      = list;
end;

escape _V;
]],
    _ana = { acc=true },
    run = 18,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

native do
    int V = 0;
end

traverse n in list do
    _V = _V + 1;
    if n:CONS then
        _V = _V + n:CONS.head;
        traverse n:CONS.tail;
    end
end

/*
class Body with
    pool  Body[]& bodies;
    var   List*   n;
do
    watching n do
        _V = _V + 1;
        if n:CONS then
            _V = _V + n:CONS.head;

            var Body*? tail =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:CONS.tail;
                end;
            if tail? then
                await *tail;
            end
        end
    end
end

pool Body[3] bodies;
do Body with
    this.bodies = bodies;
    this.n      = list;
end;
*/

escape _V;
]],
    _ana = { acc=true },
    wrn = 'line 23 : unbounded recursive spawn',
    run = 10,
}
Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[3] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

native do
    int V = 0;
end

traverse n in list do
    _V = _V + 1;
    if n:CONS then
        _V = _V + n:CONS.head;
        traverse n:CONS.tail;
    end
end

/*
class Body with
    pool  Body[]& bodies;
    var   List*   n;
do
    watching n do
        _V = _V + 1;
        if n:CONS then
            _V = _V + n:CONS.head;

            var Body*? tail =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:CONS.tail;
                end;
            if tail? then
                await *tail;
            end
        end
    end
end

pool Body[3] bodies;
do Body with
    this.bodies = bodies;
    this.n      = list;
end;
*/

escape _V;
]],
    _ana = { acc=true },
    run = 10,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[3] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

var int sum = 0;

traverse n in list do
    sum = sum + 1;
    watching n do
        await 1s;
        if n:CONS then
            sum = sum + n:CONS.head;
            traverse n:CONS.tail;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 10 },
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[3] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

var int sum = 0;

traverse n in list do
    sum = sum + 1;
    //watching n do
        await 1s;
        if n:CONS then
            sum = sum + n:CONS.head;
            traverse n:CONS.tail;
        end
    //end
end

escape sum;
]],
    run = { ['~>10s'] = 10 },
}

Test { [[
native do
##ifdef CEU_ORGS_NEWS_MALLOC
##error "malloc found"
##endif
end

data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[3] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

var int sum = 0;
traverse n in list do
    sum = sum + 1;
    watching n do
        await 1s;
        if n:CONS then
            sum = sum + n:CONS.head;
            traverse n:CONS.tail;
            sum = sum + n:CONS.head;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 16 },
}

Test { [[
native do
##ifdef CEU_ORGS_NEWS_MALLOC
##error "malloc found"
##endif
end

data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

class T with
do
    pool List[3] list;
    list = new List.CONS(1,
                List.CONS(2,
                    List.CONS(3, List.NIL())));

    var int sum = 0;
    traverse n in list do
        sum = sum + 1;
        watching n do
            await 1s;
            if n:CONS then
                sum = sum + n:CONS.head;
                traverse n:CONS.tail;
                sum = sum + n:CONS.head;
            end
        end
    end
    escape sum;
end

var int sum = do T;

escape sum;
]],
    run = { ['~>10s'] = 16 },
}

Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 0;

traverse n in tree do
    sum = sum + 1;
    watching n do
        if n:NODE then
            traverse n:NODE.left;
            sum = sum + n:NODE.v;
            traverse n:NODE.right;
        end
    end
end

escape sum;
]],
    wrn = 'line 22/24 : unbounded recursive spawn',
    run = 13,
}Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 0;

traverse n in tree do
    sum = sum + 1;
    watching n do
        if n:NODE then
            traverse n:NODE.left;
            sum = sum + n:NODE.v;
            traverse n:NODE.right;
        end
    end
end

escape sum;
]],
    run = 13,
}

Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 0;

traverse n in tree do
    sum = sum + 1;
    watching n do
        if n:NODE then
            await 1s;
            traverse n:NODE.left;
            sum = sum + n:NODE.v;
            traverse n:NODE.right;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 13 },
}

Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 1;

traverse n in tree do
    watching n do
        if n:NODE then
            traverse n:NODE.left;
            sum = sum * n:NODE.v + n:NODE.v;
            traverse n:NODE.right;
        end
    end
end

escape sum;
]],
    wrn = 'line 22/24 : unbounded recursive spawn',
    run = { ['~>10s'] = 18 },
}
Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 1;

traverse n in tree do
    watching n do
        if n:NODE then
            traverse n:NODE.left;
            sum = sum * n:NODE.v + n:NODE.v;
            traverse n:NODE.right;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 18 },
}

Test { [[
data T with
    tag NIL;
or
    tag NXT with
        var int v;
        var T*  nxt;
    end
end

pool T[] ts;

var void* p1 = (void*)this;

traverse t in ts do
    _assert(p1 == (void*)this);
    if t:NXT then
        traverse t:NXT.nxt;
    end
end

escape 1;
]],
    fin = 'line 15 : unsafe access to pointer "p1" across `class´ (tests.lua : 14)',
}
Test { [[
data T with
    tag NIL;
or
    tag NXT with
        var int v;
        var T*  nxt;
    end
end

pool T[] ts;

native do
    ##define PTR2REF(x) x
end
var void&? p1;
finalize
    p1 = _PTR2REF(this);
with
    nothing;
end

traverse t in ts do
    _assert(&p1 == (void*)this);
    if t:NXT then
        traverse t:NXT.nxt;
    end
end

escape 1;
]],
    wrn = 'line 17 : unbounded recursive spawn',
    run = 1,
}
Test { [[
data T with
    tag NIL;
or
    tag NXT with
        var int v;
        var T*  nxt;
    end
end

pool T[1] ts;

native do
    ##define PTR2REF(x) x
end
var void&? p1;
finalize
    p1 = _PTR2REF(this);
with
    nothing;
end

traverse t in ts do
    _assert(&p1 == (void*)this);
    if t:NXT then
        traverse t:NXT.nxt;
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
data T with
    tag NIL;
or
    tag NXT with
        var int v;
        var T*  nxt;
    end
end

pool T[] ts;

native do
    ##define PTR2REF(x) x
end
var void&? p1;
finalize
    p1 = _PTR2REF(this);
with
    nothing;
end

var int v2 = 2;
var int v3 = 3;

class X with
    var int v1, v2, v3;
do end

traverse t in ts do
    _assert(&p1 == (void*)this);
    var int v1 = 1;
    var int v3 = 0;
    var X x with
        this.v1 = v1;
        this.v2 = v2;
        this.v3 = outer.v3;
    end;
    _assert(x.v1 + x.v2 + x.v3 == 6);
    if t:NXT then
        traverse t:NXT.nxt;
    end
end

escape 1;
]],
    wrn = 'line 17 : unbounded recursive spawn',
    run = 1,
}
Test { [[
data T with
    tag NIL;
or
    tag NXT with
        var int v;
        var T*  nxt;
    end
end

pool T[1] ts;

native do
    ##define PTR2REF(x) x
end
var void&? p1;
finalize
    p1 = _PTR2REF(this);
with
    nothing;
end

var int v2 = 2;
var int v3 = 3;

class X with
    var int v1, v2, v3;
do end

traverse t in ts do
    _assert(&p1 == (void*)this);
    var int v1 = 1;
    var int v3 = 0;
    var X x with
        this.v1 = v1;
        this.v2 = v2;
        this.v3 = outer.v3;
    end;
    _assert(x.v1 + x.v2 + x.v3 == 6);
    if t:NXT then
        traverse t:NXT.nxt;
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 1;

traverse n in tree do
    await 1s;
    watching n do
        if n:NODE then
            traverse n:NODE.left;
            sum = sum * n:NODE.v + n:NODE.v;
            traverse n:NODE.right;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 18 },
}

Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 1;

do
    traverse n in tree do
        await 1s;
        watching n do
            if n:NODE then
                traverse n:NODE.left;
                sum = sum * n:NODE.v + n:NODE.v;
                traverse n:NODE.right;
            end
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 18 },
}

Test { [[
data Tree with
    tag NIL;
or
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 1;

par/and do
    traverse n in tree do
        watching n do
            if n:NODE then
                await 1s;
                traverse n:NODE.left;
                sum = sum * n:NODE.v + n:NODE.v;
                traverse n:NODE.right;
                await 1s;
            end
        end
    end
    sum = sum - 1;
with
    await 1s;
    _ceu_out_assert(sum == 1, "1");
    await 1s;
    _ceu_out_assert(sum == 4, "2");
    await 1s;
    _ceu_out_assert(sum == 5, "3");
    tree = new Tree.NIL();
    _ceu_out_assert(sum == 4, "4");
end

escape sum;
]],
    run = { ['~>20s'] = 4 },
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

var int sum = 0;

traverse n in list do
    sum = sum + 1;
    if n:CONS then
        sum = sum + n:CONS.head;
        loop i in 1 do
            traverse n:CONS.tail;
        end
    end
end

escape sum;
]],
    wrn = 'line 24 : unbounded recursive spawn',
    run = 10,
}
Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[3] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

var int sum = 0;

traverse n in list do
    sum = sum + 1;
    if n:CONS then
        sum = sum + n:CONS.head;
        loop i in 1 do
            traverse n:CONS.tail;
        end
    end
end

escape sum;
]],
    run = 10,
}

Test { [[
loop do
    traverse null;
end
escape 1;
]],
    adj = 'line 2 : missing enclosing `traverse´ block',
}

Test { [[
traverse t in ts do
    loop do
        traverse/1 null;
    end
end
escape 1;
]],
    adj = 'line 3 : missing enclosing `traverse´ block',
}

Test { [[
data Widget with
    tag EMPTY;
or
    tag SEQ with
        var Widget* w1;
        var Widget* w2;
    end
end

pool Widget[] widgets;
widgets = new Widget.SEQ(
            Widget.EMPTY(),
            Widget.EMPTY());

var int ret = 0;

traverse widget in widgets with
    var int param = 1;
do
    ret = ret + param;

    watching widget do
        if widget:EMPTY then
            nothing;

        else/if widget:SEQ then
            traverse widget:SEQ.w1 with
                this.param = param + 1;
            end;
            traverse widget:SEQ.w2 with
                this.param = param + 1;
            end;

        else
            _ceu_out_assert(0, "not implemented");
        end
    end
end

escape ret;
]],
    adt = 'line 23 : ineffective use of tag "EMPTY" due to enclosing `watching´',
}
Test { [[
data Widget with
    tag EMPTY;
or
    tag SEQ with
        var Widget* w1;
        var Widget* w2;
    end
end

pool Widget[] widgets;
widgets = new Widget.SEQ(
            Widget.EMPTY(),
            Widget.EMPTY());

var int ret = 0;

traverse widget in widgets with
    var int param = 1;
do
    ret = ret + param;

    watching widget do
        if widget:SEQ then
            traverse widget:SEQ.w1 with
                this.param = param + 1;
            end;
            traverse widget:SEQ.w2 with
                this.param = param + 1;
            end;

        else
            _ceu_out_assert(0, "not implemented");
        end
    end
end

escape ret;
]],
    _ana = { acc=true },
    wrn = 'line 27/30 : unbounded recursive spawn',
    run = 5,
}
Test { [[
data Widget with
    tag EMPTY;
or
    tag SEQ with
        var Widget* w1;
        var Widget* w2;
    end
end

pool Widget[10] widgets;
widgets = new Widget.SEQ(
            Widget.EMPTY(),
            Widget.EMPTY());

var int ret = 0;

traverse widget in widgets with
    var int param = 1;
do
    ret = ret + param;

    watching widget do
        if widget:SEQ then
            traverse widget:SEQ.w1 with
                this.param = param + 1;
            end;
            traverse widget:SEQ.w2 with
                this.param = param + 1;
            end;

        else
            _ceu_out_assert(0, "not implemented");
        end
    end
end

escape ret;
]],
    _ana = { acc=true },
    wrn = 'line 27/30 : unbounded recursive spawn',
    run = 5,
}

Test { [[
data Widget with
    tag EMPTY;
or
    tag SEQ with
        var Widget* w1;
        var Widget* w2;
    end
end

pool Widget[] widgets;
widgets = new Widget.SEQ(
            Widget.EMPTY(),
            Widget.EMPTY());

var int ret = 0;

traverse widget in widgets with
    var int param = 1;
do
    ret = ret + param;

    watching widget do
        if widget:SEQ then
            traverse widget:SEQ.w1 with
                this.param = param + 1;
            end;
            traverse widget:SEQ.w2 with
                this.param = param + 1;
            end;

        else
            _ceu_out_assert(0, "not implemented");
        end
    end
end

escape ret;
]],
    _ana = { acc=true },
    wrn = 'line 27/30 : unbounded recursive spawn',
    run = 5,
}
Test { [[
data Widget with
    tag EMPTY;
or
    tag SEQ with
        var Widget* w1;
        var Widget* w2;
    end
end

pool Widget[10] widgets;
widgets = new Widget.SEQ(
            Widget.EMPTY(),
            Widget.EMPTY());

var int ret = 0;

traverse widget in widgets with
    var int param = 1;
do
    ret = ret + param;

    watching widget do
        if widget:SEQ then
            traverse widget:SEQ.w1 with
                this.param = param + 1;
            end;
            traverse widget:SEQ.w2 with
                this.param = param + 1;
            end;

        else
            _ceu_out_assert(0, "not implemented");
        end
    end
end

escape ret;
]],
    _ana = { acc=true },
    run = 5,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] l;
l = new List.CONS(1,
            List.CONS(2,
                List.CONS(3,
                    List.CONS(4,
                        List.CONS(5,
                            List.NIL())))));

var int ret = 0;

par/or do
    await l:CONS.tail:CONS.tail;
    ret = 100;
with
    l:CONS.tail:CONS.tail = new List.NIL();
    ret = 10;
end

escape ret;
]],
    _ana = {acc=true},
    run = 100,
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] l;
l = new List.CONS(1,
            List.CONS(2,
                List.CONS(3,
                    List.CONS(4,
                        List.CONS(5,
                            List.NIL())))));

var int ret = 0;

par/or do
    await l:CONS.tail:CONS.tail;
    ret = ret + l:CONS.tail:CONS.tail:CONS.head;    // 0+4
    _ceu_out_assert(ret == 4, "1");
    l:CONS.tail:CONS.tail = l:CONS.tail:CONS.tail:CONS.tail;
    ret = ret + l:CONS.tail:CONS.tail:CONS.head;    // 0+4+5
    _ceu_out_assert(ret == 9, "2");

    await l:CONS.tail:CONS.tail;
    ret = ret + l:CONS.tail:CONS.tail:NIL;          // 0+4+5+5+1
    _ceu_out_assert(ret == 15, "4");
    await FOREVER;
with
    await l:CONS.tail:CONS.tail;
    _ceu_out_assert(ret == 9, "3");
    ret = ret + l:CONS.tail:CONS.tail:CONS.head;    // 0+4+5+5
    l:CONS.tail:CONS.tail = new List.NIL();

    _ceu_out_assert(ret == 15, "5");
    await l:CONS.tail:CONS.tail;
    // never reached
    _ceu_out_assert(ret == 15, "6");
    await FOREVER;
with
    await l:CONS.tail:CONS.tail;
    ret = ret + l:CONS.tail:CONS.tail:NIL;          // 0+4+5+5+1+1

    await l:CONS.tail:CONS.tail;
    _ceu_out_assert(ret == 16, "7");
    await FOREVER;
with
    l:CONS.tail:CONS.tail = l:CONS.tail:CONS.tail:CONS.tail;
    ret = ret * 2;  // (0+4+5+5+1+1) * 2
    l:CONS.tail:CONS.tail = new List.CONS(10, List.NIL());
end

escape ret;
]],
    _ana = {acc=true},
    run = 32,
}

Test { [[
input void OS_START;

data Widget with
    tag NIL;
or
    tag V with
        var int v;
    end
or
    tag ROW with
        var Widget* w1;
        var Widget* w2;
    end
end

par/or do
    await 21s;
with
    pool Widget[] widgets;
    widgets = new Widget.ROW(
                    Widget.V(10),
                    Widget.V(20));

    var int ret =
        traverse widget in widgets do
            watching widget do
                if widget:V then
                    await (widget:V.v)s;
                    escape widget:V.v;

                else/if widget:ROW then
                    var int v1, v2;
                    par/and do
                        v1 = traverse widget:ROW.w1;
                    with
                        v2 = traverse widget:ROW.w2;
                    end
                    escape v1 + v2;

                else
                    _ceu_out_assert(0, "not implemented");
                end
            end
            escape 0;
        end;
    escape ret;
end

escape 0;
]],
    _ana = {acc=true},
    wrn = true,
    run = {['~>21s;'] = 30},
}

Test { [[
input void OS_START;

data Widget with
    tag NIL_;
or
    tag NIL;
or
    tag EMPTY;
or
    tag ROW with
        var Widget* w1;
        var Widget* w2;
    end
end

par/or do
    await OS_START;
with
    pool Widget[] widgets;
    widgets = new Widget.ROW(
                    Widget.EMPTY(),
                    Widget.EMPTY());

    traverse widget in widgets do
        watching widget do
            if widget:NIL then
                await FOREVER;
            else/if widget:EMPTY then
                await FOREVER;

            else/if widget:ROW then
                loop do
                    par/or do
                        var int ret = traverse widget:ROW.w1;
                        if ret == 0 then
                            await FOREVER;
                        end
                    with
                        var int ret = traverse widget:ROW.w2;
                        if ret == 0 then
                            await FOREVER;
                        end
                    end
                end

            else
                _ceu_out_assert(0, "not implemented");
            end
        end
    end
end

escape 1;
]],
    _ana = {acc=true},
    wrn = true,
    run = 1,
}

Test { [[
input void OS_START;

data List with
    tag NIL;
or
    tag EMPTY;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] l;
l = new List.CONS(1, List.EMPTY());

par/or do
    traverse e in l do
        watching e do
            if e:EMPTY then
                await FOREVER;

            else/if e:CONS then
                loop do
                    traverse e:CONS.tail;
                    _ceu_out_assert(0, "0");
                end
            else
                _ceu_out_assert(0, "1");
            end
        end
    end
with
    await OS_START;
end

escape 1;
]],
    _ana = {acc=true},
    wrn = true,
    run = 1,
}

Test { [[
input void OS_START;

data Widget with
    tag NIL;
or
    tag EMPTY;
or
    tag SEQ with
        var Widget* w1;
        var Widget* w2;
    end
end

var int ret = 0;

par/or do
    pool Widget[] widgets;
    widgets = new Widget.SEQ(
                Widget.EMPTY(),
                Widget.EMPTY());

    traverse widget in widgets with
        var int param = 1;
    do
        ret = ret + param;

        watching widget do
            if widget:EMPTY then
                await FOREVER;

            else/if widget:SEQ then
                loop do
                    par/or do
                        traverse widget:SEQ.w1 with
                            this.param = param + 1;
                        end;
if widget:SEQ.w1:NIL then
    await FOREVER;
end
                    with
                        traverse widget:SEQ.w2 with
                            this.param = param + 1;
                        end;
if widget:SEQ.w2:NIL then
    await FOREVER;
end
                    end
                end

            else
                _ceu_out_assert(0, "not implemented");
            end
        end
    end
with
    await OS_START;
end

escape ret;
]],
    _ana = { acc=true },
    wrn = 'line 57 : unbounded recursive spawn',
    run = 5,
}
Test { [[
input void OS_START;

data Widget with
    tag NIL;
or
    tag EMPTY;
or
    tag SEQ with
        var Widget* w1;
        var Widget* w2;
    end
end

var int ret = 0;

par/or do
    pool Widget[10] widgets;
    widgets = new Widget.SEQ(
                Widget.EMPTY(),
                Widget.EMPTY());

    traverse widget in widgets with
        var int param = 1;
    do
        ret = ret + param;

        watching widget do
            if widget:EMPTY then
                await FOREVER;

            else/if widget:SEQ then
                loop do
                    par/or do
                        traverse widget:SEQ.w1 with
                            this.param = param + 1;
                        end;
if widget:SEQ.w1:NIL then
    await FOREVER;
end
                    with
                        traverse widget:SEQ.w2 with
                            this.param = param + 1;
                        end;
if widget:SEQ.w2:NIL then
    await FOREVER;
end
                    end
                end

            else
                _ceu_out_assert(0, "not implemented");
            end
        end
    end
with
    await OS_START;
end

escape ret;
]],
    _ana = { acc=true },
    run = 5,
}

Test { [[
input void OS_START;

data Widget with
    tag NIL;
or
    tag EMPTY;
or
    tag SEQ with
        var Widget* w1;
        var Widget* w2;
    end
end

pool Widget[] widgets;
widgets = new Widget.SEQ(
            Widget.EMPTY(),
            Widget.EMPTY());

var int ret = 0;

par/or do
    traverse widget in widgets with
        var int param = 1;
    do
        ret = ret + param;
native @pure _printf();
_printf("[%d] %p = %d/%d->%d\n", widget:EMPTY, widget, ret,param,ret);

        watching widget do
            if widget:EMPTY then
                await FOREVER;

            else/if widget:SEQ then
                loop do
                    par/or do
                        traverse widget:SEQ.w1 with
                            this.param = param + 1;
                        end;
if widget:SEQ.w1:NIL then
_ceu_out_assert(0, "ok\n");
    await FOREVER;
end
                    with
                        traverse widget:SEQ.w2 with
                            this.param = param + 1;
                        end;
if widget:SEQ.w2:NIL then
_ceu_out_assert(0, "ok\n");
    await FOREVER;
end
                    end
                end

            else
                _ceu_out_assert(0, "not implemented");
            end
        end
    end
with
    await OS_START;
end

escape ret;
]],
    _ana = { acc=true },
    wrn = 'line 57 : unbounded recursive spawn',
    run = 5,
}
Test { [[
input void OS_START;

data Widget with
    tag NIL;
or
    tag EMPTY;
or
    tag SEQ with
        var Widget* w1;
        var Widget* w2;
    end
end

pool Widget[10] widgets;
widgets = new Widget.SEQ(
            Widget.EMPTY(),
            Widget.EMPTY());

var int ret = 0;

par/or do
    traverse widget in widgets with
        var int param = 1;
    do
        ret = ret + param;
native @pure _printf();
_printf("[%d] %p = %d/%d->%d\n", widget:EMPTY, widget, ret,param,ret);

        watching widget do
            if widget:EMPTY then
                await FOREVER;

            else/if widget:SEQ then
                loop do
                    par/or do
                        traverse widget:SEQ.w1 with
                            this.param = param + 1;
                        end;
if widget:SEQ.w1:NIL then
_ceu_out_assert(0, "ok\n");
    await FOREVER;
end
                    with
                        traverse widget:SEQ.w2 with
                            this.param = param + 1;
                        end;
if widget:SEQ.w2:NIL then
_ceu_out_assert(0, "ok\n");
    await FOREVER;
end
                    end
                end

            else
                _ceu_out_assert(0, "not implemented");
            end
        end
    end
with
    await OS_START;
end

escape ret;
]],
    _ana = { acc=true },
    run = 5,
}

Test { [[
data Command with
    tag NOTHING;
or
    tag FORWARD with
        var int pixels;
    end
or
    tag SEQUENCE with
        var Command* one;
        var Command* two;
    end
end

pool Command[] cmds;

cmds = new Command.SEQUENCE(
            Command.FORWARD(100),
            Command.FORWARD(500));

par/or do
    traverse cmd in cmds do
        watching cmd do
            if cmd:FORWARD then
                await FOREVER;

            else/if cmd:SEQUENCE then
                traverse cmd:SEQUENCE.one;

            else
            end
        end
    end
with
    await 100s;
end

escape 10;
]],
    --tight = 'tight loop',
    _ana = { acc=true },
    wrn = true,
    run = { ['~>100s']=10 },
}

Test { [[
input int SDL_DT;

data Command with
    tag NOTHING;
or
    tag FORWARD with
        var int pixels;
    end
or
    tag SEQUENCE with
        var Command* one;
        var Command* two;
    end
end

// TODO: aceitar estatico
pool Command[] cmds;

cmds = new Command.SEQUENCE(
            Command.FORWARD(100),
            Command.FORWARD(500));

par/or do
    await 100s;
with
    traverse cmd in cmds do
        watching cmd do
            if cmd:FORWARD then
                await FOREVER;

            else/if cmd:SEQUENCE then
                traverse cmd:SEQUENCE.one;
                _ceu_out_assert(0, "bug found"); // cmds has to die entirely before children
                traverse cmd:SEQUENCE.two;
            end
        end
    end
end

escape 10;
]],
    --tight = 'tight loop',
    _ana = { acc=true },
    wrn = true,
    run = { ['~>100s']=10 },
}
Test { [[
input int SDL_DT;

data Command with
    tag NOTHING;
or
    tag FORWARD with
        var int pixels;
    end
or
    tag SEQUENCE with
        var Command* one;
        var Command* two;
    end
end

// TODO: aceitar estatico
pool Command[] cmds;

cmds = new Command.SEQUENCE(
            Command.FORWARD(100),
            Command.FORWARD(500));

par/or do
    await 100s;
with
    traverse cmd in cmds do
        watching cmd do
            if cmd:FORWARD then
                await FOREVER;

            else/if cmd:SEQUENCE then
                traverse cmd:SEQUENCE.one;
                traverse cmd:SEQUENCE.two;
            end
        end
    end
end

escape 10;
]],
    --tight = 'tight loop',
    _ana = { acc=true },
    wrn = true,
    run = { ['~>100s']=10 },
}

Test { [[
data Command with
    tag NOTHING;
or
    tag LEFT;
or
    tag REPEAT with
        var Command* command;
    end
end

pool Command[] cmds;

cmds = new Command.REPEAT(
            Command.LEFT());

native @pure _printf();

class TurtleTurn with
do
    _printf("ME %p\n", &this);
    await 1us;
end

traverse cmd in cmds do
    watching cmd do
        if cmd:LEFT then
            do TurtleTurn;

        else/if cmd:REPEAT then
            traverse cmd:REPEAT.command;
            traverse cmd:REPEAT.command;

        else
            _ceu_out_assert(0, "not implemented");
        end
    end
end

escape 10;
]],
    --tight = 'tight loop',
    _ana = { acc=true },
    wrn = true,
    run = { ['~>2us']=10 },
}

Test { [[
input int SDL_DT;

data Command with
    tag NOTHING;
or
    tag AWAIT with
        var int ms;
    end
or
    tag RIGHT with
        var int angle;
    end
or
    tag LEFT with
        var int angle;
    end
or
    tag FORWARD with
        var int pixels;
    end
or
    tag BACKWARD with
        var int pixels;
    end
or
    tag SEQUENCE with
        var Command* one;
        var Command* two;
    end
or
    tag REPEAT with
        var int      times;
        var Command* command;
    end
end

// TODO: aceitar estatico
pool Command[] cmds;

cmds = new Command.REPEAT(2,
            Command.SEQUENCE(
                Command.AWAIT(500),
                Command.SEQUENCE(
                    Command.RIGHT(45),
                    Command.SEQUENCE(
                        Command.FORWARD(100),
                        Command.SEQUENCE(
                            Command.LEFT(90),
                            Command.SEQUENCE(
                                Command.FORWARD(100),
                                Command.SEQUENCE(
                                    Command.RIGHT(45),
                                    Command.SEQUENCE(
                                        Command.BACKWARD(100),
                                        Command.AWAIT(500)))))))));

class Turtle with
    var int angle;
    var int pos_x, pos_y;
do
    await FOREVER;
end

class TurtleTurn with
    var Turtle& turtle;
    var int     angle;
    var int     isRight;
do
    var int inc;
    if isRight then
        if this.angle < 0 then
            angle = -angle;
            inc = 1;
        else
            inc = -1;
        end
    else
        if this.angle < 0 then
            angle = -angle;
            inc = -1;
        else
            inc = 1;
        end
    end
    loop i in angle do
        await 10ms;
        turtle.angle = turtle.angle + inc;
    end
end

class TurtleMove with
    var Turtle& turtle;
    var int     pixels;
    var int     isForward;
do
    var int inc;
    if isForward then
        inc =  1;
    else
        inc = -1;
    end
    _ceu_out_assert(this.pixels > 0, "pixels");

    var float sum = 0;
    var float x = turtle.pos_x;
    var float y = turtle.pos_y;
    loop do
        await 10ms;
        var int dt = 10;
        if sum >= this.pixels then
            break;
        end
        var float mul = 80 * dt * 0.001 * this.inc;
        var float dx  = mul * (turtle.angle/(180.0));
        var float dy  = mul * (turtle.angle/(180.0));
        sum = sum + (dx) + (dy);
        x = x + dx;
        y = y + dy;
        turtle.pos_x = x;
        turtle.pos_y = y;
    end

end

par/or do
    await 100s;
with
    var Turtle turtle;

    traverse cmd in cmds do
        watching cmd do
            if cmd:AWAIT then
                await (cmd:AWAIT.ms) ms;

            else/if cmd:RIGHT or cmd:LEFT then
                var int angle;
                if cmd:RIGHT then
                    angle = cmd:RIGHT.angle;
                else
                    angle = cmd:LEFT.angle;
                end
                do TurtleTurn with
                    this.turtle  = turtle;
                    this.angle   = angle;
                    this.isRight = cmd:RIGHT;
                end;

            else/if cmd:FORWARD or cmd:BACKWARD then
                var int pixels;
                if cmd:FORWARD then
                    pixels = cmd:FORWARD.pixels;
                else
                    pixels = cmd:BACKWARD.pixels;
                end
                do TurtleMove with
                    this.turtle    = turtle;
                    this.pixels    = pixels;
                    this.isForward = cmd:FORWARD;
                end;

            else/if cmd:SEQUENCE then
                traverse cmd:SEQUENCE.one;
                traverse cmd:SEQUENCE.two;

            else/if cmd:REPEAT then
                loop i in cmd:REPEAT.times do
                    traverse cmd:REPEAT.command;
                end

            else
                _ceu_out_assert(0, "not implemented");
            end
        end
    end
end

escape 10;
]],
    --tight = 'tight loop',
    _ana = { acc=true },
    wrn = true,
    run = { ['~>100s']=10 },
}

-- creates a loop when reusing address of organisms being killed
Test { [[
data Command with
    tag NOTHING;
or
    tag AWAIT with
        var int ms;
    end
or
    tag SEQUENCE with
        var Command* one;
        var Command* two;
    end
or
    tag REPEAT with
        var int      times;
        var Command* command;
    end
end

pool Command[] cmds;

cmds = new Command.REPEAT(2,
            Command.SEQUENCE(
                Command.AWAIT(100),
                Command.SEQUENCE(
                    Command.AWAIT(100),
                    Command.AWAIT(500))));

var int ret = 0;

traverse cmd in cmds do
    watching cmd do
        if cmd:AWAIT then
            await (cmd:AWAIT.ms) ms;
            ret = ret + 1;

        else/if cmd:SEQUENCE then
            ret = ret + 2;
            traverse cmd:SEQUENCE.one;
            traverse cmd:SEQUENCE.two;

        else/if cmd:REPEAT then
            loop i in cmd:REPEAT.times do
                ret = ret + 3;
                traverse cmd:REPEAT.command;
            end

        else
            _ceu_out_assert(0, "not implemented");
        end
    end
end

escape ret;
]],
    wrn = true,
    _ana = {acc=true},
    run = { ['~>100s']=20 },
}

Test { [[
native @nohold _free();
var void&? ptr;
finalize
    ptr = _malloc(10000);
with
    _free(&ptr);
end

data Command with
    tag NOTHING;
or
    tag AWAIT with
        var int ms;
    end
or
    tag SEQUENCE with
        var Command* one;
        var Command* two;
    end
or
    tag REPEAT with
        var int      times;
        var Command* command;
    end
end

// TODO: aceitar estatico
pool Command[] cmds;

cmds = new Command.REPEAT(2,
            Command.SEQUENCE(
                Command.AWAIT(100),
                Command.SEQUENCE(
                    Command.AWAIT(300),
                    Command.AWAIT(500))));

var int ret = 0;

traverse cmd in cmds do
    watching cmd do
        if cmd:AWAIT then
            await (cmd:AWAIT.ms) ms;
            ret = ret + 1;

        else/if cmd:SEQUENCE then
            ret = ret + 2;
            traverse cmd:SEQUENCE.one;
            traverse cmd:SEQUENCE.two;

        else/if cmd:REPEAT then
            loop i in cmd:REPEAT.times do
                ret = ret + 3;
                traverse cmd:REPEAT.command;
            end

        else
            _ceu_out_assert(0, "not implemented");
        end
    end
end

escape ret;
]],
    wrn = true,
    _ana = {acc=true},
    run = { ['~>100s']=20 },
}

Test { [[
data List with
    tag NIL;
or
    tag HOLD;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[] ls;
ls = new List.CONS(1,
            List.CONS(2,
                List.HOLD()));

var int ret = 0;

native @pure _printf();

traverse l in ls do
    ret = ret + 1;
    watching l do
        if l:HOLD then
            finalize with
                ret = ret + 1;
            end
            await FOREVER;
        else
            par/or do
                traverse l:CONS.tail;
            with
                await 1s;
            end
        end
    end
end

escape ret;
]],
    wrn = 'line 23 : unbounded recursive spawn',
    run = { ['~>5s']=4 },
}
Test { [[
data List with
    tag NIL;
or
    tag HOLD;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[10] ls;
ls = new List.CONS(1,
            List.CONS(2,
                List.HOLD()));

var int ret = 0;

native @pure _printf();

traverse l in ls do
    ret = ret + 1;
    watching l do
        if l:HOLD then
            finalize with
                ret = ret + 1;
            end
            await FOREVER;
        else
            par/or do
                traverse l:CONS.tail;
            with
                await 1s;
            end
        end
    end
end

escape ret;
]],
    run = { ['~>5s']=4 },
}

Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[10] list;

loop i in 10 do
    traverse l in list do
        if l:NIL then
            list = new List.CONS(i, List.NIL());
        else/if l:CONS then
            if l:CONS.tail:NIL then
                l:CONS.tail = new List.CONS(i, List.NIL());
            else
                traverse l:CONS.tail;
            end
        end
    end
end

var int sum = 0;

traverse l in list do
    if l:CONS then
        sum = sum + l:CONS.head;
        traverse l:CONS.tail;
    end
end

escape sum;
]],
    run = 45,
}

-- innefective NIL inside watching
Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[3] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

native do
    int V = 0;
end

class Body with
    pool  Body[]& bodies;
    var   List*   n;
do
    watching n do
        if n:NIL then
            _V = _V * 2;
        else/if n:CONS then
            _V = _V + 1;
            _V = _V + n:CONS.head;

            var Body*? tail =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:CONS.tail;
                end;
            if tail? then
                await *tail;
            end
        end
    end
end

pool Body[3] bodies;
do Body with
    this.bodies = bodies;
    this.n      = list;
end;

escape _V;
]],
    adt = 'line 24 : ineffective use of tag "NIL" due to enclosing `watching´',
}
Test { [[
data List with
    tag NIL_;
or
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[4] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

native do
    int V = 0;
end

class Body with
    pool  Body[]& bodies;
    var   List*   n;
do
    watching n do
        if n:NIL then
            _V = _V * 2;
        else/if n:CONS then
            _V = _V + 1;
            _V = _V + n:CONS.head;

            var Body*? tail =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:CONS.tail;
                end;
            if tail? then
                await *tail;
            end
        end
    end
end

pool Body[4] bodies;
do Body with
    this.bodies = bodies;
    this.n      = list;
end;

escape _V;
]],
    wrn = 'line 42 : unbounded recursive spawn',
    _ana = { acc=true },
    run = 18,
}
-- innefective NIL inside watching
Test { [[
data List with
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[3] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

native do
    int V = 0;
end

traverse n in list do
    _V = _V + 1;
    watching n do
        if n:NIL then
            _V = _V * 2;
        else/if n:CONS then
            _V = _V + n:CONS.head;
            traverse n:CONS.tail;
        end
    end
    await 1s;
end

escape _V;
]],
    adt = 'line 22 : ineffective use of tag "NIL" due to enclosing `watching´',
}

Test { [[
data List with
    tag NIL_;
or
    tag NIL;
or
    tag CONS with
        var int   head;
        var List* tail;
    end
end

pool List[4] list;
list = new List.CONS(1,
            List.CONS(2,
                List.CONS(3, List.NIL())));

native do
    int V = 0;
end

traverse n in list do
    _V = _V + 1;
    watching n do
        if n:NIL then
            _V = _V * 2;
        else/if n:CONS then
            _V = _V + n:CONS.head;
            traverse n:CONS.tail;
        end
    end
    await 1s;
end

escape _V;
]],
    wrn = 'line 42 : unbounded recursive spawn',
    _ana = { acc=true },
    run = { ['~>10s']=20 },
}

Test { [[
data L with
    tag NIL;
or
    tag VAL with
        var L* l;
    end
end

pool L[] ls;

var int v = 10;
var int* p = &v;

traverse l in ls do
    *p = 1;
    if l:VAL then
        traverse l:VAL.l;
    end
end

escape v;
]],
    fin = 'line 15 : unsafe access to pointer "p" across `class´',
}

Test { [[
class A with
    var int v = 10;
    var int* p;
do
    this.p = &v;
end

class B with
    var A& a;
do
    escape *(a.p);
end

escape 1;
]],
    run = 1,
}

Test { [[
class A with
    var int v = 10;
    var int* p;
do
    this.p = &v;
end

class B with
    var A& a;
do
    await 1s;
    escape *(a.p);
end

escape 1;
]],
    fin = 'line 12 : unsafe access to pointer "p" across `await´',
}

-- ADTS ALIASING

Test { [[
data List with
    tag NIL;
or
    tag X with
        var List* nxt;
    end
end
pool List[] lll;     // l is the pool
escape lll:NIL;       // l is a pointer to the root
]],
    run = 1,
}

Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[] cmds1;
pool Command[]& cmds2;
escape 1;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[] cmds1;
pool Command[]& cmds2;
cmds2 = cmds1;
escape 1;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[] cmds1;
cmds1 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));

pool Command[]& cmds2;
cmds2 = cmds1;

escape cmds2:NEXT.nxt:NEXT.nxt:NOTHING;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[]& cmds2;
cmds2 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));

escape 1;
]],
    ref = 'line 10 : invalid attribution (not a reference)',
    --ref = 'line 10 : reference must be bounded before use',
}

Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[2] cmds1;
pool Command[2]& cmds2;
cmds2 = cmds1;

cmds1 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));
cmds2 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));
escape cmds1:NEXT;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[2] cmds1;

cmds1 = new Command.NEXT(
                Command.NEXT(
                    Command.NEXT(
                        Command.NOTHING())));
escape cmds1:NEXT.nxt:NEXT.nxt:NOTHING;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[2] cmds1;

cmds1 = new Command.NEXT(Command.NOTHING());
cmds1:NEXT.nxt = new Command.NEXT(Command.NOTHING());
cmds1:NEXT.nxt:NEXT.nxt = new Command.NEXT(Command.NOTHING());
escape cmds1:NEXT.nxt:NEXT.nxt:NOTHING;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[1] cmds1;

cmds1 = new Command.NEXT(Command.NOTHING());
cmds1 = new Command.NEXT(Command.NOTHING());
escape cmds1:NEXT.nxt:NOTHING;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[2] cmds1;

cmds1 = new Command.NEXT(Command.NOTHING());
cmds1 = new Command.NEXT(
                Command.NEXT(
                    Command.NOTHING()));
escape cmds1:NEXT.nxt:NEXT.nxt:NOTHING;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[2] cmds1;
pool Command[2]& cmds2;
cmds2 = cmds1;

cmds1 = new Command.NEXT(Command.NOTHING());
cmds2:NEXT.nxt = new Command.NEXT(Command.NOTHING());
escape cmds1:NEXT.nxt:NEXT.nxt:NOTHING;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[2] cmds1;
pool Command[2]& cmds2;
cmds2 = cmds1;

cmds1 = new Command.NEXT(Command.NOTHING());
cmds2:NEXT.nxt = new Command.NEXT(
                        Command.NEXT(
                            Command.NOTHING()));
escape cmds1:NEXT.nxt:NEXT.nxt:NOTHING;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[3] cmds1;
pool Command[3]& cmds2;
cmds2 = cmds1;

cmds1 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));
cmds2:NEXT.nxt:NEXT.nxt = new Command.NEXT(
                            Command.NEXT(
                                Command.NOTHING()));
escape cmds1:NEXT.nxt:NEXT.nxt:NEXT.nxt:NOTHING;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[10] cmds1;

pool Command[10]& cmds2;
cmds2 = cmds1;

cmds1 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));
cmds2 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));

escape cmds1:NEXT.nxt:NEXT.nxt:NOTHING;
]],
    run = 1,
}
Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[] cmds1;

pool Command[]& cmds2;
cmds2 = cmds1;

cmds1 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));
cmds2 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));

escape cmds1:NEXT.nxt:NEXT.nxt:NOTHING;
]],
    run = 1,
}

Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

pool Command[] cmds1;

pool Command[]& cmds2;
cmds2 = cmds1;

cmds1 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));
cmds2 = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));

var int sum = 0;

traverse cmd in cmds1 do
    if cmd:NEXT then
        sum = sum + 1;
        traverse cmd:NEXT.nxt;
    end
end
traverse cmd in cmds2 do
    if cmd:NEXT then
        sum = sum + 1;
        traverse cmd:NEXT.nxt;
    end
end

escape sum;
]],
    wrn = true,
    run = 4,
}

Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

class Run with
    pool Command[]& cmds1;
do
    cmds1 = new Command.NEXT(
                Command.NEXT(
                    Command.NOTHING()));
    var int sum = 0;
    traverse cmd111 in cmds1 do
        if cmd111:NEXT then
            sum = sum + 1;
            traverse cmd111:NEXT.nxt;
        end
    end
    escape sum;
end

pool Command[] cmds;

traverse cmd222 in cmds do
end

var int ret = do Run with
    this.cmds1 = cmds;
end;

escape ret;
]],
    wrn = true,
    run = 2,
}

Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

    pool Command[] cmds;
    traverse cmd in cmds do
    end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Command with
    tag NOTHING;
or
    tag NEXT with
        var Command* nxt;
    end
end

class Run with
    pool Command[]& cmds;
do
    var int sum = 0;
    traverse cmd in cmds do
        if cmd:NEXT then
            sum = sum + 1;
            traverse cmd:NEXT.nxt;
        end
    end
    escape sum;
end

pool Command[] cmds;
cmds = new Command.NEXT(
            Command.NEXT(
                Command.NOTHING()));

var int ret = do Run with
    this.cmds = cmds;
end;

escape ret;
]],
    wrn = true,
    run = 2,
}

Test { [[
data Command with
    tag NOTHING;
or
    tag AWAIT;
or
    tag PAROR with
        var Command* one;
    end
end

pool Command[] cmds;

cmds = new Command.PAROR(
            Command.PAROR(
                Command.AWAIT()));

class Run with
    pool Command[]& cmds;
do
    traverse cmd in cmds do
        if cmd:AWAIT then
            await 1ms;

        else/if cmd:PAROR then
            par/or do
                traverse cmd:PAROR.one;
            with
            end
        end
    end
end

var Run r with
    this.cmds   = cmds;
end;

escape 1;
]],
    wrn = true,
    run = { ['~>10s']=1 },
}
--[=[

Test { [[
data List with
    tag NIL;
with
    tag CONS with
        var int  head;
        var List tail;
    end
end
var List l = List.CONS(1, List.CONS(2, List.CONS(3, List.NIL())));

var int sum = 0;

loop/1 i in &l do
    if i:CONS then
        sum = sum + i:CONS.head;
        traverse i:CONS.tail;
    end
end

escape sum;
]],
    asr = 'runtime error: loop overflow',
}

Test { [[
data List with
    tag NIL;
with
    tag CONS with
        var int  head;
        var List tail;
    end
end
var List l = List.CONS(1, List.CONS(2, List.CONS(3, List.NIL())));

var int sum = 0;

loop/3 i in &l do
    if i:CONS then
        sum = sum + i:CONS.head;
        traverse i:CONS.tail;
    end
end

escape sum;
]],
    run = 6,
}

Test { [[
data List with
    tag NIL;
with
    tag CONS with
        var int  head;
        var List tail;
    end
end
var List l = List.CONS(1, List.CONS(2, List.CONS(3, List.NIL())));

var int sum = 0;

loop i in &l do
    if i:CONS then
        sum = sum + i:CONS.head;
        traverse i:CONS.tail;
    end
end

escape sum;
]],
    run = 6,
}

Test { [[
data Tree with
    tag NIL;
with
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

var Tree t =
    Tree.NODE(1,
        Tree.NODE(2, Tree.NIL(), Tree.NIL()),
        Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 0;

    finalize with end;

loop i in &t do
    if i:NODE then
        traverse i:NODE.left;
        sum = sum + i:NODE.v;
        traverse i:NODE.right;
    end
end

escape sum;
]],
    run = 6,
}

Test { [[
data List with
    tag NIL;
with
    tag CONS with
        var int  head;
        var List tail;
    end
end

pool List[3] l;
l = new List.CONS(1, List.CONS(2, List.CONS(3, List.NIL())));

var int sum = 0;

loop i in l do
    if i:CONS then
        sum = sum + i:CONS.head;
        traverse i:CONS.tail;
    end
end

escape sum;
]],
    run = 6,
}

Test { [[
data Tree with
    tag NIL;
with
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] t;
t = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 0;

loop i in t do
    if i:NODE then
        traverse i:NODE.left;
        sum = sum + i:NODE.v;
        traverse i:NODE.right;
    end
end

escape sum;
]],
    run = 6,
}

]=]

-- TODO: continue ADT implementation

--[=[
-- XXX
-- TODO: avoid cycles/side-shares
error 'TODO: data that uses data'
error 'TODO: data that uses data that uses 1st data again (cycle)'
error 'TODO: detect tight loops == detect deletes in the DAG'
error 'TODO: change middle w/ l3 w/ deeper scope'
error 'TODO: List& l = ...  // for temporary parts (tests w/ no reassign)'

-- NONE of below is implemented (or will ever be?)
-- anonymous fields
Test { [[
data Pair = (int, int);
data Opt  = NIL(void) | PTR(void*);
data List = NIL  (void)
           | CONS (int, List&);
escape 1;
]],
    todo = 'implement? trying only w/ named fields for now',
}

-- named fields w/ initializers
Test { [[
data Pair with
    var int x = 0;
    var int y = 0;
end

data Opt with
    tag NIL;
with
    tag PTR with
        var void* v = null;
    end
end

data List with
    tag NIL;
with
    tag CONS with
        var int   head = 0;
        var List& tail = List.nil();
    end
end

var List l;

escape 1;
]],
    todo = 'implement?',
}

-- constructors may specify the field names
Test { DATA..[[
var Pair p1 = Pair(x=1,x=2);
var Opt  o1 = Opt.NIL();
var Opt  o2 = Opt.PTR(v=&p1);
var List l1 = List.NIL();
var List l2 = List.CONS(head=1, tail=l1);
var List l3 = List.CONS(head=1, tail=List.CONS(head=2, tail=List.NIL()));

escape 1;
]],
    todo = 'implement?',
    run = 1,
}

-- anonymous destructors / pattern matching
Test { DATA..[[
var Pair p1 = Pair(1,2);
var Opt  o1 = Opt.NIL();
var Opt  o2 = Opt.PTR(&p1);
var List l1 = List.NIL();
var List l2 = List.CONS(1, l1);
var List l3 = List.CONS(1, List.CONS(2, List.NIL()));

var int ret = 0;

var int x, y;
(x,y) = p;
_assert(x+y == 3);
ret = ret + 3;              // 3

switch o1 with
    case Opt.NIL() do
        ret = ret + 1;      // 4
        _assert(1);
    end
    case Opt.PTR(void* v) do
        _assert(0);
    end
end

switch o2 with
    case Opt.NIL() do
        _assert(0);
    end
    case Opt.PTR(void* v) do
        ret = ret + 1;      // 5
        _assert(v==&p1);
    end
end

switch l1 with
    case List.NIL() do
        ret = ret + 1;      // 6
        _assert(1);
    end
    case List.CONS(int head, List& tail) do
        _assert(0);
    end
end

switch l2 with
    case List.NIL() do
        _assert(0);
    end
    case List.CONS(int head1, List& tail1) do
        _assert(head1 == 1);
        ret = ret + 1;      // 7
        switch *tail1 with
            case List.NIL() do
                ret = ret + 1;      // 8
                _assert(1);
            end
            case List.CONS(int head2, List& tail2) do
                _assert(0);
            end
        end
        ret = ret + 1;      // 9
        _assert(1);
    end
end

switch l3 with
    case List.NIL() do
        _assert(0);
    end
    case List.CONS(int head1, List& tail1) do
        _assert(head1 == 1);
        ret = ret + 1;      // 10
        switch *tail1 with
            case List.NIL() do
                _assert(0);
            end
            case List.CONS(int head2, List& tail2) do
                _assert(head2 == 2);
                ret = ret + 2;      // 12
                switch *tail2 with
                    case List.NIL() do
                        _assert(1);
                        ret = ret + 1;      // 13
                    end
                    case List.CONS(int head3, List& tail3) do
                        _assert(0);
                    end
                end
                _assert(1);
                ret = ret + 1;      // 14
            end
        end
        _assert(1);
        ret = ret + 1;      // 15
    end
end

escape ret;
]],
    run = 15,
    todo = 'implement? trying only w/ named fields for now',
}
--]=]

-- TIMEMACHINE

local t = {
    [1] = [[
#define TM_QUEUE
]],
    [2] = [[
#define TM_QUEUE
#define TM_QUEUE_WCLOCK_REUSE
]],
    [3] = [[
#define TM_SNAP
]],
    [4] = [[
#define TM_SNAP
#define TM_QUEUE
]],
    [5] = [[
#define TM_SNAP
#define TM_QUEUE
#define TM_QUEUE_WCLOCK_REUSE
]],
    [6] = [[
#define TM_DIFF
]],
    [7] = [[
#define TM_SNAP
#define TM_DIFF
]],
}

for i=1, #t do
    local defs = t[i]

-- TODO: test OS_PAUSE/OS_RESUME

-- SEEK
Test { [[
native do
    int CEU_TIMEMACHINE_ON = 0;
end

class App with
    var int v = 0;
do
    every 1s do
        this.v = this.v + 1;
    end
end
var App app;

input int DT;

]]..defs..[[

#define TM_INPUT_DT     DT
#define TM_QUEUE_N      1000000
#if defined(TM_QUEUE) || defined(TM_DIFF)
#define TM_SNAP_MS      2000
#endif
#define TM_SNAP_N       1000
#define TM_DIFF_N       1000000

native do
    ##define CEU_FPS 20
end

#include "timemachine.ceu"

#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
end
var IOTimeMachine io;
#endif

var TimeMachine tm with
    this.app = app;
#ifdef TM_QUEUE
    this.io  = io;
#endif
end;

par/or do
    await 3s_;
    emit tm.go_on;
    await 1s_;

    ///////////////////////////////

    emit tm.go_seek => tm.time_total;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 3);

    emit tm.go_seek => 0;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    emit tm.go_seek => 500;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    emit tm.go_seek => 1000;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);

    emit tm.go_seek => 1500;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);

    emit tm.go_seek => 2000;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 2);

    emit tm.go_seek => 2500;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 2);

    emit tm.go_seek => 3000;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 3);

    emit tm.go_seek => 2500;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 2);

    emit tm.go_seek => 2000;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 2);

    emit tm.go_seek => 1500;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);

    emit tm.go_seek => 1000;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);

    emit tm.go_seek => 500;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    emit tm.go_seek => 0;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    escape 1;

with
    input int DT;
    async (tm) do
        loop do
            if not _CEU_TIMEMACHINE_ON then
                emit 50ms;
                emit DT => 50;
            end

            // TODO: forces this async to be slower
            input void SLOW;
            loop do
                if not tm.locked then
                    break;
                end
                emit SLOW;
            end
            emit 50ms_;
        end
    end
end

escape app.v;
]],
    timemachine = true,
    _ana = {
        acc = true,
    },
    run = 1,
}

-- FORWARD
Test { [[
native do
    int CEU_TIMEMACHINE_ON = 0;
end

class App with
    var int v = 0;
do
    every 1s do
        this.v = this.v + 1;
    end
end
var App app;

input int DT;

]]..defs..[[

#define TM_INPUT_DT     DT
#define TM_QUEUE_N      1000000
#if defined(TM_QUEUE) || defined(TM_DIFF)
#define TM_SNAP_MS      2000
#endif
#define TM_SNAP_N       1000
#define TM_DIFF_N       1000000

native do
    ##define CEU_FPS 20
end

#include "timemachine.ceu"

#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
end
var IOTimeMachine io;
#endif

var TimeMachine tm with
    this.app = app;
#ifdef TM_QUEUE
    this.io  = io;
#endif
end;

par/or do
    await 3s_;
    emit tm.go_on;
    await 1s_;

    ///////////////////////////////

    emit tm.go_seek => tm.time_total;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 3);

    ///////////////////////////////

    emit tm.go_seek => 0;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    emit tm.go_forward => 1;
    _assert(app.v == 0);

    await 1ms_;
    await 1000ms_;
    _assert(app.v == 1);
    await 1000ms_;
    _assert(app.v == 2);
    await 1000ms_;
    _assert(app.v == 3);

    ///////////////////////////////

    emit tm.go_seek => 0;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    emit tm.go_forward => 1;
    _assert(app.v == 0);

    await 1ms_;
    loop i in 20 do
        await 50ms_;
    end
    _assert(app.v == 1);
    loop i in 20 do
        await 50ms_;
    end
    _assert(app.v == 2);
    loop i in 20 do
        await 50ms_;
    end
    _assert(app.v == 3);

    ///////////////////////////////

    emit tm.go_seek => 0;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    emit tm.go_forward => 2;
    _assert(app.v == 0);

    await 1ms_;
    loop i in 10 do
        await 50ms_;
    end
    _assert(app.v == 1);
    loop i in 10 do
        await 50ms_;
    end
    _assert(app.v == 2);
    loop i in 10 do
        await 50ms_;
    end
    _assert(app.v == 3);

    ///////////////////////////////

    emit tm.go_seek => 0;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    emit tm.go_forward => 5;
    _assert(app.v == 0);

    await 1ms_;
    await 200ms_;
    _assert(app.v == 1);
    await 200ms_;
    _assert(app.v == 2);
    await 200ms_;
    _assert(app.v == 3);

    ///////////////////////////////

    emit tm.go_seek => 0;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    emit tm.go_forward => -2;
    _assert(app.v == 0);

    await 1ms_;
    await 2000ms_;
    _assert(app.v == 1);
    await 2000ms_;
    _assert(app.v == 2);
    await 2000ms_;
    _assert(app.v == 3);

    ///////////////////////////////

    emit tm.go_seek => 0;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    emit tm.go_forward => -5;
    _assert(app.v == 0);

    await 1ms_;
    loop i in 100 do
        await 50ms_;
    end
    _assert(app.v == 1);
    loop i in 100 do
        await 50ms_;
    end
    _assert(app.v == 2);
    loop i in 100 do
        await 50ms_;
    end
    _assert(app.v == 3);

with
    input int DT;
    async (tm) do
        loop do
            if not _CEU_TIMEMACHINE_ON then
                emit 50ms;
                emit DT => 50;
            end

            // TODO: forces this async to be slower
            input void SLOW;
            loop do
                if not tm.locked then
                    break;
                end
                emit SLOW;
            end
            emit 50ms_;
        end
    end
end

escape app.v;
]],
    timemachine = true,
    _ana = {
        acc = true,
    },
    run = 3,
}

-- BACKWARD
Test { [[
native do
    int CEU_TIMEMACHINE_ON = 0;
end

class App with
    var int v = 0;
do
    every 1s do
        this.v = this.v + 1;
    end
end
var App app;

input int DT;

]]..defs..[[

#define TM_INPUT_DT         DT
#define TM_QUEUE_N          1000000
#if defined(TM_QUEUE) || defined(TM_DIFF)
#define TM_SNAP_MS          2000
#endif
#define TM_SNAP_N           1000
#define TM_DIFF_N           1000000
#define TM_BACKWARD_TICK    30

native do
    ##define CEU_FPS 100
end

#include "timemachine.ceu"

#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
end
var IOTimeMachine io;
#endif

var TimeMachine tm with
    this.app = app;
#ifdef TM_QUEUE
    this.io  = io;
#endif
end;

par/or do
    await 3s_;
    emit tm.go_on;
    await 1s_;

    ///////////////////////////////

    emit tm.go_seek => tm.time_total;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 3);

    emit tm.go_backward => 1;
    _assert(app.v == 3);

    await 1000ms_;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 2);
    await 1000ms_;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);
    await 1000ms_;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    ///////////////////////////////

    emit tm.go_seek => tm.time_total;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 3);

    emit tm.go_backward => 1;
    _assert(app.v == 3);

    loop i in 20 do
        await 50ms_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 2);
    loop i in 20 do
        await 50ms_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);
    loop i in 20 do
        await 50ms_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    ///////////////////////////////

    emit tm.go_seek => tm.time_total;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 3);

    emit tm.go_backward => 2;
    _assert(app.v == 3);

    loop i in 10 do
        await 50ms_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 2);
    loop i in 10 do
        await 50ms_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);
    loop i in 10 do
        await 50ms_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    ///////////////////////////////

    emit tm.go_seek => tm.time_total;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 3);

    emit tm.go_backward => 5;
    _assert(app.v == 3);

    await 200ms_;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 2);
    await 200ms_;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);
    await 200ms_;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    ///////////////////////////////

    emit tm.go_seek => tm.time_total;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 3);

    emit tm.go_backward => -2;
    _assert(app.v == 3);

    await 2000ms_;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 2);
    await 2000ms_;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);
    await 2000ms_;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    ///////////////////////////////

    emit tm.go_seek => tm.time_total;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 3);

    emit tm.go_backward => -5;
    _assert(app.v == 3);

    loop i in 100 do
        await 50ms_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 2);
    loop i in 100 do
        await 50ms_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);
    loop i in 100 do
        await 50ms_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    app.v = app.v + 1;
with
    input int DT;
    async (tm) do
        loop do
            if not _CEU_TIMEMACHINE_ON then
                emit 10ms;
                emit DT => 10;
            end

            // TODO: forces this async to be slower
            input void SLOW;
            loop do
                if not tm.locked then
                    break;
                end
                emit SLOW;
            end
            emit 10ms_;
        end
    end
end

escape app.v;
]],
    timemachine = true,
    _ana = {
        acc = true,
    },
    run = 1,
}

-- FORWARD / BACKWARD
Test { [[
native do
    int CEU_TIMEMACHINE_ON = 0;
end

class App with
    var int v = 0;
do
    every 1s do
        this.v = this.v + 1;
    end
end
var App app;

input int DT;

]]..defs..[[

#define TM_INPUT_DT     DT
#define TM_QUEUE_N      1000000
#if defined(TM_QUEUE) || defined(TM_DIFF)
#define TM_SNAP_MS      2000
#endif
#define TM_SNAP_N       1000
#define TM_DIFF_N       1000000

native do
    ##define CEU_FPS 100
end

#include "timemachine.ceu"

#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
end
var IOTimeMachine io;
#endif

var TimeMachine tm with
    this.app = app;
#ifdef TM_QUEUE
    this.io  = io;
#endif
end;

par/or do
    await 3s_;
    _assert(app.v == 3);
    emit tm.go_on;

    await 1s_;
    emit tm.go_seek => 0;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 0);

    await 1s_;
    emit tm.go_forward => 2;
    _assert(app.v == 0);

    await 1s400ms_;
    _assert(app.v == 2);

    emit tm.go_seek => tm.time_total;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 3);

    emit tm.go_backward => 2;
    _assert(app.v == 3);

    await 1s1ms_;
    TM_AWAIT_SEEK(tm);
    _assert(app.v == 1);
with
    input int DT;
    async (tm) do
        loop do
            if not _CEU_TIMEMACHINE_ON then
                emit 10ms;
                emit DT => 10;
            end

            // TODO: forces this async to be slower
            input void SLOW;
            loop do
                if not tm.locked then
                    break;
                end
                emit SLOW;
            end
            emit 10ms_;
        end
    end
end

escape app.v;
]],
    timemachine = true,
    _ana = {
        acc = true,
    },
    run = 1,
}

Test { [[
native do
    int CEU_TIMEMACHINE_ON = 0;
end

input int* KEY;
class App with
    var int v = 0;
do
    par do
        every 1s do
            this.v = this.v + 1;
        end
    with
        every key in KEY do
            this.v = this.v * 2;
            this.v = this.v + *key;
        end
    end
end
var App app;

input int  DT;

]]..defs..[[

#define TM_INPUT_DT     DT
#define TM_QUEUE_N      1000000
#if defined(TM_QUEUE) || defined(TM_DIFF)
#define TM_SNAP_MS      2000
#endif
#define TM_SNAP_N       1000
#define TM_DIFF_N       1000000

native do
    ##define CEU_FPS 100
end

#include "timemachine.ceu"

#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
    par do
        loop do
            // starts off
            watching this.go_on do
                every key in KEY do
                    _queue_put(_CEU_IN_KEY,
                               sizeof(int), (byte*)key
#ifdef TM_SNAP
                                ,0
#endif
                              )
                        finalize with
                            nothing;
                        end;
                end
            end
            await this.go_off;
        end
    with
        every qu in this.go_queue do
            var int v = *((int*)qu:buf);
            if qu:evt == _CEU_IN_KEY then
                async(v) do
                    emit KEY => &v;
                end
            else
                _assert(0);
            end
        end
    end
end
var IOTimeMachine io;
#endif

var TimeMachine tm with
    this.app = app;
#ifdef TM_QUEUE
    this.io  = io;
#endif
end;

par/or do
    async do
        loop i in 300 do
            emit 10ms;
            emit DT => 10;
        end
        var int v = 1;
        emit KEY => &v;
        loop i in 300 do
            emit 10ms;
            emit DT => 10;
        end
        v = 2;
        emit KEY => &v;
        loop i in 300 do
            emit 10ms;
            emit DT => 10;
        end
    end
    _assert(app.v == 25);

    emit tm.go_on;
    await 1s_;

    emit tm.go_seek => 0;
    TM_AWAIT_SEEK(tm);

    emit tm.go_forward => 1;
    await 3s1ms_;
    _assert(app.v == 7);
    await 2s_;
    _assert(app.v == 9);
    await 1s_;
    _assert(app.v == 22);
    await 3s_;
    _assert(app.v == 25);
with
    input int DT;
    async (tm) do
        loop do
            // TODO: forces this async to be slower
            input void SLOW;
            loop do
                if not tm.locked then
                    break;
                end
                emit SLOW;
            end
            emit 10ms_;
        end
    end
end

escape app.v;
]],
    timemachine = true,
    _ana = {
        acc = true,
    },
    run = 25,
}

end

do return end

-------------------------------------------------------------------------------
-- BUGS & INCOMPLETNESS
-------------------------------------------------------------------------------

-- async dentro de pause
-- async thread spawn falhou, e ai?

-- TODO: bug: what if the "o" expression contains other pointers?
-- (below: pi)
Test { [[
class T with
do
end

var T[10] ts;
var int   i = 0;
var int* pi = &i;
await ts[*pi];
escape 1;
]],
    fin = 'line 8 : pointer access across `await´',
}
-- should disallow passing pointers through internal events
Test { [[
input void OS_START;
event int* e;
var int ret = 0;
par/or do
    do
        var int x = 2;
        par/or do
            await OS_START;
            emit e => &x;
        with
            await e;
        end
    end
    do
        var int x = 1;
        await 1s;
        ret = x;
    end
with
    var int* v = await e;
    ret = *v;
end
escape ret;
]],
    run = 2,
}

-- use of global before its initialization
Test { [[
interface Global with
    var int& v;
end

class T with
    var int v;
do
    this.v = global:v;
end
var T t;

var int  um = 111;
var int& v = um;
escape t.v;
]],
    run = 111,
}

-- XXX: T-vs-Opt
Test { [[
class T with
do
end
var T*&? t;
finalize
    t = _malloc(10 * sizeof(T**));
with
    nothing;
end
native @nohold _free();
finalize with
    _free(t);
end
escape 10;
]],
    run = 10;
}

Test { [[
input void A, B, Z;
event void a;
var int ret = 1;
var _t* a;
native _f();
native _t = 0;
par/or do
    _f(a)               // 8
        finalize with
            ret = 1;    // DET: nested blks
        end;
with
    var _t* b;
    _f(b)               // 14
        finalize with
            ret = 2;    // DET: nested blocks
        end;
end
escape ret;
]],
    _ana = {
        acc = 2,
    },
    run = false,
}

Test { [[
input void OS_START;
event int a, x, y;
var int ret = 0;
par do
    par/or do
        await y;
        escape 1;   // 12
    with
        await x;
        escape 2;   // 15
    end;
with
    await OS_START;
    emit x => 1;       // in seq
    emit y => 1;       // in seq
end
]],
    _ana = {
        acc = 0,
    },
    run = 2;
}

Test { [[
input void OS_START;
native _V;
native do
    int V = 1;
end
class T with
do
    par/or do
        await OS_START;
    with
        await OS_START;    // valgrind error
    end
    _V = 10;
end
do
    spawn T;
    await 1s;
end
escape _V;
]],
    run = { ['~>1s']=10 },
}

Test { [[
input int  A;
input void Z;
event int a;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a => v;
    end
with
    pause/if a do
        ret = await 9us;
    end
end
escape ret;
]],
    run = {
        ['~>1us;0~>A;~>1us;0~>A;~>19us'] = 12,
        ['~>1us;1~>A;~>1s;0~>A;~>19us'] = 11,
        --['~>1us;1~>A;~>5us;0~>A;~>5us;1~>A;~>5us;0~>A;~>9us'] = 6,
-- BUG: set_min nao eh chamado apos o pause
    },
}

Test { [[
input void A,F;

interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
    await inc;
    this.v = v + 1;
end

var int ret = 0;
do
    par/or do
        await F;
    with
        var int i=1;
        every 1s do
            spawn T with
                this.v = i;
                i = i + 1;
            end;
        end
    with
        every 1s do
            loop i in I* do
                emit i:inc;         // mata o org enquanto o percorre iterador
                ret = ret + i:v;
            end
        end
    end
end
escape ret;
]],
-- BUG: erro de valgrind
    run = { ['~>3s;~>F'] = 11 },
}

-- BUG: should be: field must be assigned
Test { [[
var int v = 10;
var int& i;

par do
    await 1s;
    i = v;
with
    escape i;
end
]],
    run = 99,
}

error 'testar pause/if org.e'
error 'testar spawn/spawn que se mata'

--do escape end

-- ok: under tests but supposed to work

--ERROR: #ps
Test { [[
input (int,int,int) EVT;
var int a,b;
(a,b) = await EVT;
escape 1;
]],
    run = 1,
}
-- ERROR: defs.h before host code
-- makes sense: how an external component would know about a
-- type defined in Ceu?
Test { [[
native do
    typedef int t;
end
input (_t,int) EVT;
escape 1;
]],
    run = 1,
}

-- ERROR: parse (typecast)
Test { [[
if ( _transaction ) then
    _coap_send_transaction(_transaction);
end
]],
    run = 1,
}

Test { [[
input void OS_START;
event (int,void*) ptr;
var int* p;
var int i;
par/or do
    (i,p) = await ptr;
with
    do
        var int b = 1;
        await OS_START;
        emit ptr => (1, &b);
    end
end
escape 1;
]],
    run = 1,
    -- e depois outro exemplo com fin apropriado
    -- BUG: precisa transformar emit x=>1 em p=1;emit x
}

Test { [[
native do
    int V = 0;
end

class T with
do
    _V = 10;
    finalize with
        _V = 100;   // TODO: deveria executar qd "var T t" sai de escopo
    end
end

var T t;
_assert(_V == 10);
escape _V;
]],
    run = 100,
}

Test { [[
function () => void f;
escape 1;
]],
    run = 1,
}

-- TODO: fails on valgrind, fails on OS
-- put back to XXXX
Test { [[
native _V;
input void A, F, OS_START;
native do
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
await OS_START;
var int ret;
do
    var T t;
    par/or do
        do                  // 24
            finalize with
                _V = _V*10;
            end
            await t.ok;
        end
    with
        await t.e;          // 31
        t.v = t.v * 3;
    with
        await F;
        t.v = t.v * 5;
    end
    ret = t.v;
end
escape ret + _V;        // * reads after
]],
    _ana = {
        abrt = 1,        -- false positive
    },
    run = {
        ['~>F'] = 6,
        ['~>A'] = 13,
    }
}

-- TODO_TYPECAST (search and replace)
Test { [[
class T with
do
end
// TODO: "typecast" esconde "call", finalization nao acha que eh call
var T** t := (T**)_malloc(10 * sizeof(T**));
native @nohold _free();
finalize with
    _free(t);
end
escape 10;
]],
    run = 10;
}

-- varlist to iter
Test { [[
interface I with
    var int v;
end
class T with
    interface I;
do
end
pool T[1] ts;
var T a with
    a.v = 15;
end
var int ret = 0;
ret = ret + spawn T[ts] with
                this.v = 10;
            end;
ret = ret + spawn T[ts];
loop i in (I*)(ts in a) do
    ret = ret + i:v;
end
escape 26;
]],
    run = 1,
}

Test { [[
class T with
    var void* ptr = null;
do
end
var T* ui;
do
    pool T[] ts;
    var void* p = null;
    ui = spawn T in ts with // ui > ts (should require fin)
        this.ptr = p;
    end;
end
escape 10;
]],
    run = 1,
}

--[=[
-- POSSIBLE PROBLEMS FOR UNITIALIZED VAR

Test { [[
var int r;
var int* pr = &r;
async(pr) do
    var int i = 100;
    *pr = i;
end;
escape r;
]],
    run=100
}

Test { [[
var int a;
par/or do
    await 1s;
    a = 1;
with
end
escape a;
]],
    run = 10,
}

Test { [[
var int[2] v ;
_f(v)
escape v == &v[0] ;
]],
    run = 1,
}

Test { [[
native @nohold _strncpy(), _printf(), _strlen();
native _char = 1;
var _char[10] str;
_strncpy(str, "123", 4);
_printf("END: %d %s\n", (int)_strlen(str), str);
escape 0;
]],
    run = '3 123'
}

Test { [[
var int a;
a = do
    var int b;
end;
]],

Test { [[
class T with
    var int* a1;
do
    var int* a2 = a1;
end
escape 10;
]],
    run = 10,
}

}

]=]

-------------------------------------------------------------------------------

-- TODO: should require finalization
Test { [[
class T with
    var _int to;
do
end

var _int to = 1;

var T move with
    this.to = to;  // TODO: := ??
end;

escape move.to;
]],
    run = 1,
}

-- TODO: I[100]
Test { [[
interface I with
    var int v;
end

class T with
    interface I;
do
    await FOREVER;
end

pool I[100] is;

var int ret = 0;

spawn T with
    this.v = 1;
end;

spawn T in is with
    this.v = 3;
end;

loop i in is do
    ret = ret + i:v;
end

escape ret;
]],
    run = 3,
}

-- TODO: spawn wrong type
Test { [[
interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
    await FOREVER;
end
pool I[] is;

class U with
    var int z;
    var int v;
do
    await FOREVER;
end

var int ret = 0;
do
    spawn T with
        this.v = 1;
    end;
    spawn U in is with
        this.v = 2;
    end;
    spawn T in is with
        this.v = 3;
    end;

    loop i in is do
        ret = ret + i:v;
    end
end
escape ret;
]],
    run = 5,
}

-- U[10] vs U[] mismatch
Test { [[
class U with do end;

interface I with
    pool U[10] us;
end

interface Global with
    interface I;
end
pool U[]  us;

class T with
    pool U[10] us;
    interface I;
do
    spawn U in global:us;
end

spawn U in us;
spawn U in global:us;

pool U[1] us1;
spawn U in us1;

var T t;
spawn U in t.us;

var I* i = &t;
spawn U in i:us;

escape 1;
]],
    wrn = true,
    run = 1,
}

-- TODO: invalid pointer access
Test { [[
var int* ptr = null;
loop i in 100 do
    await 1s;
    var int* p;
    if (ptr != null) then
        p = ptr;
    end
    ptr = p;
end
escape 10;
]],
    --loop = true,
    fin = 'line 5 : invalid pointer "ptr"',
}

-- TODO: t.v // T.v
Test { [[
class T with
    var int v;
do
    v = 1;
end
var T t;
t.v = 10;
escape t.v;
]],
    run = 10,
}

-- global vs assert??
Test { [[
interface Global with
    event void e;
end
event void e;
par/or do
    emit global:e;
with
    _assert(0);
end
escape 1;
]],
    run = 1,
}

-- this vs _iter??
Test { [[
interface I with
    var int v;
end

class T with
    interface I;
do
    this.v = 1;
end
pool T[] ts;

par/or do
    spawn T in ts with
    end;
with
    loop i in ts do
    end
end

escape 1;
]],
    run = 1,
}

-- TODO: spawn vs watching impossible
Test { [[
class T with
do
end

par/and do
    pool T[] ts;
    var T* t = spawn T in ts with
    end;
with
    var T* p;
    watching p do
    end
end

escape 1;
]],
    run = 1,
}

-- TODO: explicit interface implementations only
Test { [[
interface I with
    var int v;
end

class T with
    var int u,v,x;
do
end

class U with
    var int v;
do
end

class V with
    var int v;
do
    pool I[10] is;
    spawn T in is;
    spawn U in is;
end

pool I[10] is;

spawn T in is;
spawn U in is;
spawn V in is;

escape sizeof(CEU_T) > sizeof(CEU_U);
]],
    run = 1,
}

-- TODO: not "awake once" for await-until
Test { [[
input void OS_START;
event int v;
par do
    var int x;
    x = await v until x == 10;
    escape 10;
with
    await OS_START;
    emit v => 0;
    emit v => 1;
    emit v => 10;
    await FOREVER;
end
]],
    run = 10;
}

-------------------------------------------------------------------------------
Test { [[
input void    START,   STOP;
input _pkt_t* RECEIVE, SENDACK;

native @nohold _memcpy(), _send_dequeue(), _pkt_setRoute(), _pkt_setContents(), 
_receive();

class Forwarder with
   var _pkt_t pkt;
   event void ok;
do
   loop do
      var bool enq;
      enq = _send_enqueue(&pkt)
            finalize with
               _send_dequeue(&pkt);
            end;
      if not enq then
         await (_rand()%100)ms;
         continue;
      end
      var _pkt_t* done;
      done = await SENDACK
             until (done == &pkt);
      break;
   end
   emit this.ok;
end

class Client with
do
   loop seq do
      par/and do
         await 1min;
      with
         do Forwarder with
            _pkt_setRoute(&this.pkt, seq);
            _pkt_setContents(&this.pkt, seq);
         end;
      end
   end
end

loop do
   await START;
   par/or do
      await STOP;
   with
      pool Forwarder[10] forwarders;
      var  Client   [10] clients;

      var _pkt_t* pkt;
      every pkt in RECEIVE do
         if pkt:left == 0 then
            _receive(pkt);
         else
            pkt:left = pkt:left - 1;
            spawn Forwarder with
               _memcpy(&this.pkt, pkt, pkt:len);
            end;
         end
      end
   end
end
]],
    run = 0,
}

Test { [[
input int* A;
par/or do
    var int* snd = await A;
    *snd = *snd;
    await FOREVER;
with
    var int* snd =
        await A
            until *snd == 1;
    escape *snd;
with
    async do
        var int i = 2;
        emit A => &i;
        i = 1;
        emit A => &i;
    end
end
escape 0;
]],
    _ana = {
        acc = 4,
    },
    run = 1;
}
do return end

Test { [[
class Rect with
do
    await FOREVER;
end

if false then
    interface Bird with end
    var Bird* ptr = null;
    watching ptr do end
else
    pool Rect[257] rs;
    loop i in 257 do
        spawn Rect in rs;
    end
end

escape 10;
]],
    run = 10,
}
do return end

Test { [[
class T with do end;
pool T[] ts;
loop t in ts do
    await 1s;
end
escape 1;
]],
    props = 'line 4 : `every´ cannot contain `await´',
}

Test { [[
interface I with
end
class T with
    interface I;
do end
do
    pool T[] ts;
    loop i in ts do
        await 1s;
    end
end
escape 1;
]],
    props = 'line 9 : `every´ cannot contain `await´',
}

Test { [[
interface I with
    var int v;
end

var I* i=null;

par/or do
    await 1s;
with
    watching i do
        await 1s;
        var int v = i:v;
    end
end

escape 1;
]],
    run = 1,
}

--BUG de "&" para org across await

-- TODO: (_XXX) eh um cast => msg melhor!
Test { [[
if (_XXX) then
end
]],
    run = 1,
}

-- PROCURAR XXX e recolocar tudo ate o ok la

Test { [[
input (int a)=>int F do
    return a + 1;
end
var int ret = call F=>1;
escape ret;
]],
    run = 2,
}

Test { [[
input (int c)=>int WRITE do
    return c + 1;
end
var byte b = 1;
var int ret = call WRITE => b;
escape ret;
]],
    run = 2,
}

Test { [[
input (int a, int b)=>int F do
    return a + b;
end
var int ret = call F=>(1,2);
escape ret;
]],
    run = 3,
}

Test { [[
native/pre do
    typedef int lua_State;
    void lua_pushnil (lua_State* l) {}
end

input (_lua_State* l)=>void PUSHNIL do
    _lua_pushnil(l);
end
escape 1;
]],
    run = 1,
}

Test { [[
input (char* str, int len, int x, int y)=>int DRAW_STRING do
    return x + y + len;
end

var int ret = call DRAW_STRING => ("Welcome to Ceu/OS!\n", 20, 100, 100);

escape ret;
]],
    run = 220,
}

Test { [[
input (void)=>void* MALLOC;
var void* ptr = (call MALLOC);
]],
    fin = 'line 2 : destination pointer must be declared with the `[]´ buffer modifier',
}

Test { [[
input (void)=>void* MALLOC;
var void[] ptr = (call MALLOC);
]],
    fin = 'line 2 : attribution requires `finalize´',
}

Test { [[
input (void)=>void* MALLOC;
var void[] ptr;
finalize
    ptr = (call MALLOC);
with
end
escape 1;
]],
    code = 'line 1 : missing function body',
}

Test { [[
input (int,int)=>void* MALLOC;
var void[] ptr;
finalize
    ptr = (call MALLOC=>(1,1));
with
end
escape 1;
]],
    code = 'line 1 : missing function body',
}

Test { [[
input (int,int)=>int MALLOC;
var int v;
finalize
    v = (call MALLOC=>(1,1));
with
end
escape 1;
]],
    fin = 'line 4 : attribution does not require `finalize´',
}

Test { [[
input (int a, int b, void* ptr)=>void* MALLOC do
    if a+b == 11 then
        return ptr;
    else
        return null;
    end
end

var int i;
var void[] ptr;
finalize
    ptr = (call MALLOC=>(10,1, &i));
with
end
escape ptr==&i;
]],
    run = 1,
}
Test { [[
input (int a, int b, void* ptr)=>void* MALLOC do
    if a+b == 11 then
        return ptr;
    else
        return null;
    end
end

var int i;
var void[] ptr;
finalize
    ptr = (call MALLOC=>(1,1, &i));
with
end
escape ptr==null;
]],
    run = 1,
}

Test { [[
input (void)=>void* MALLOC;
native _f();
do
    var void* a;
    finalize
        a = (call MALLOC);
    with
        do await FOREVER; end;
    end
end
]],
    fin = 'line 6 : destination pointer must be declared with the `[]´ buffer modifier',
}

Test { [[
input (void* v)=>void F do
    _V = v;
end
escape 1;
]],
    fin = 'line 2 : attribution to pointer with greater scope',
}

Test { [[
input (void* v)=>void F do
    _V := v;
end
escape 1;
]],
    fin = 'line 2 : parameter must be `hold´',
}

Test { [[
native do
    void* V;
end
input (@hold void* v)=>void F do
    _V := v;
end
escape 1;
]],
    run = 1,
}

Test { [[
input (char* buf)=>void F do
end;
var char* buf;
call F => (buf);
escape 1;
]],
    run = 1,
}

Test { [[
input (char* buf, int i)=>void F do
end;
var char* buf;
call F => (buf, 1);
escape 1;
]],
    run = 1,
}

Test { [[
input (void)=>void F do
end;
var char* buf;
call F;
escape 1;
]],
    run = 1,
}

Test { [[
input (char* buf)=>void F do
end;
var char* buf;
call F => buf;
escape 1;
]],
    run = 1,
}

Test { [[
input (@hold char* buf)=>void F do
end;
var char* buf;
call F => buf;
escape 1;
]],
    fin = 'line 2 : call requires `finalize´',
}

Test { [[
var char[255] buf;
_enqueue(buf);
escape 1;
]],
    fin = 'line 2 : call requires `finalize´',
}

Test { [[
native _f();
do
    var int* p1 = null;
    do
        var int* p2 = null;
        _f(p1, p2);
    end
end
escape 1;
]],
    wrn = true,
    fin = 'line 6 : call requires `finalize´',
    -- multiple scopes
}

Test { [[
native _f();
native _v;
native do
    int v = 1;
    int f (int v) {
        return v + 1;
    }
end
escape _f(_v);
]],
    --fin = 'line 3 : call requires `finalize´',
    run = 2,
    --fin = 'line 9 : attribution requires `finalize´',
}
Test { [[
native @pure _f();
native _v;
native do
    int v = 1;
    int f (int v) {
        return v + 1;
    }
end
escape _f(_v);
]],
    --fin = 'line 3 : call requires `finalize´',
    run = 2,
}


Test { [[
native @pure _f();
native do
    int* f (int a) {
        return NULL;
    }
end
var int* v = _f(0);
escape v == null;
]],
    run = 1,
}

Test { [[
native @pure _f();
native do
    int V = 10;
    int f (int v) {
        return v;
    }
end
native @const _V;
escape _f(_V);
]],
    run = 10;
}

Test { [[
native _f();
native do
    int f (int* v) {
        return 1;
    }
end
var int v;
escape _f(&v) == 1;
]],
    fin = 'line 8 : call requires `finalize´',
}

Test { [[
native @nohold _f();
native do
    int f (int* v) {
        return 1;
    }
end
var int v;
escape _f(&v) == 1;
]],
    run = 1,
}

Test { [[
native _V;
native @nohold _f();
native do
    int V=1;
    int f (int* v) {
        return 1;
    }
end
var int v;
escape _f(&v) == _V;
]],
    run = 1,
}

Test { [[
input (int* p1, int* p2)=>void F;
do
    var int* p1 = null;
    do
        var int* p2 = null;
        call F => (p1, p2);
    end
end
escape 1;
]],
    fin = 'line 6 : invalid call (multiple scopes)',
}
do return end

-- TODO: finalize not required
Test { [[
native do
    #define ceu_out_call_VVV(x) x
end

output (int n)=>int VVV;
var int v;
finalize
    v = (call VVV => 10);
with
    nothing;
end
escape v;
]],
    run = 10,
}

-- TODO: finalize required
Test { [[
native do
    #define ceu_out_call_MALLOC(x) NULL
end

output (int n)=>void* MALLOC;
var char* buf;
buf = (call MALLOC => 10);
escape 1;
]],
    run = 1,
}

-- TODO: finalize required
Test { [[
native do
    #define ceu_out_call_SEND(x) 0
end

output (char* buf)=>void SEND;
var char[255] buf;
call SEND => buf;
escape 1;
]],
    run = 1,
}

-- TODO: finalize required
Test { [[
native/pre do
    typedef struct {
        int a,b,c;
    } F;
end
native do
    F* f;
    #define ceu_out_call_OPEN(x) f
end
output (char* path, char* mode)=>_F* OPEN;

// Default device
var _F[] f;
    f = (call OPEN => ("/boot/rpi-boot.cfg", "r"));
escape 1;
]],
    run = 1,
}

Test { [[
output (char* path, char* mode)=>_F* OPEN;
output (_F* f)=>int CLOSE;
output (_F* f)=>int SIZE;
output (void* ptr, int size, int nmemb, _F* f)=>int READ;

// Default device
var _F[] f;
finalize
    f = (call OPEN => ("/boot/rpi-boot.cfg", "r"));
with
    call CLOSE => f;
end

if f == null then
    await FOREVER;
end

var int flen = (call SIZE => f);
//char *buf = (char *)malloc(flen+1);
var char[255] buf;
buf[flen] = 0;
call READ => (buf, 1, flen, f);

#define GPFSEL1 ((uint*)0x20200004)
#define GPSET0  ((uint*)0x2020001C)
#define GPCLR0  ((uint*)0x20200028)
var uint ra;
ra = *GPFSEL1;
ra = ra & ~(7<<18);
ra = ra | 1<<18;
*GPFSEL1 = ra;

var char* orig = "multiboot";

loop do
    loop i in 9 do
        if buf[i] != orig[i] then
            await FOREVER;
        end
        *GPCLR0 = 1<<16;
        await 1s;
        *GPSET0 = 1<<16;
        await 1s;
    end
end
]],
    run = 1,
    --todo = 'finalize is lost!',
}

Test { [[
var int[10] vec1;

class T with
    var int*& vec2;
do
    this.vec2[0] = 10;
end

vec1[0] = 0;

var T t with
    this.vec2 = outer.vec1;
end;

escape vec1[0];
]],
    run = 10,
}

-------------------------------------------------------------------------------

do return end

-- TODO: BUG: type of bg_clr changes
--          should yield error
--          because it stops implementing UI
Test { [[
interface UI with
    var   int&?   bg_clr;
end
class UIGridItem with
   var UI* ui;
do
    watching ui do
        await FOREVER;
    end
end
class UIGrid with
    interface UI;
    var   int&?    bg_clr = nil;
    pool UIGridItem[] uis;
do
end

var UIGrid g1;
var UIGrid g2;
spawn UIGridItem in g1.uis with
    this.ui = &g2;
end;

escape 1;
]],
    run = 1,
}
do return end
Test { [[
interface UI with
end
class UIGridItem with
   var UI* ui;
do
    watching ui do
        await FOREVER;
    end
end
class UIGrid with
    interface UI;
    pool UIGridItem[] uis;
do
end

do
    var UIGrid g1;
    var UIGrid g2;
    spawn UIGridItem in g1.uis with
        this.ui = &g2;
    end;
end

escape 1;
]],
    run = 1,
}
do return end

Test { [[
native do
    typedef struct {
        int v;
    } tp;
end
class T with
    var _tp&? i = nil;
do
end
var T t;
escape t.i==nil;
]],
    run = 1,
}

Test { [[
native do
    typedef struct {
        int v;
    } tp;
    tp V = { 10 };
end
class T with
    var _tp&? i = nil;
do
end
var T t with
    this.i = &_V;
end;
escape t.i.v;
]],
    run = 10,
}

Test { [[
_assert(0);
escape 1;
]],
    asr = true,
}

-- BUG: do T quando ok acontece na mesma reacao
Test { [[
class Body with
    pool  Body[]& bodies;
    var   int&    sum;
    event int     ok;
do
    finalize with end;

    var Body* nested =
        spawn Body in bodies with
            this.bodies = bodies;
            this.sum    = sum;
        end;
    if nested != null then
        watching nested do
            await nested:ok;
        end
        sum = sum + 1;
    end
    emit this.ok => 1;
end

pool Body[2] bodies;
var  int     sum = 0;

    finalize with end;

do Body with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    wrn = 'line 7 : unbounded recursive spawn',
    run = 6,
}

-- BUG: do T quando ok acontece na mesma reacao
Test { [[
data Tree with
    tag NIL;
with
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] tree;
tree = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

class Body with
    pool  Body[]& bodies;
    var   Tree*   n;
    var   int&    sum;
    event int     ok;
do
    //watching n do
        var int i = this.sum;
        if n:NODE then
            var Body* left =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:NODE.left;
                    this.sum    = sum;
                end;
            //watching left do
                await left:ok;
            //end

            this.sum = this.sum + i + n:NODE.v;

            var Body* right =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = n:NODE.right;
                    this.sum    = sum;
                end;
            //watching right do
                await right:ok;
            //end

            //do/spawn Body in this.bodies with
                //this.n = n:NODE.left;
            //end;
        end
    //end
    emit this.ok => 1;
end

var int sum = 0;

pool Body[7] bodies;
do Body with
    this.bodies = bodies;
    this.n      = tree;
    this.sum    = sum;
end;

escape sum;

/*
var int sum = 0;
loop n in tree do
    var int i = sum;
    if n:NODE then
        traverse n:NODE.left;
        sum = i + n:NODE.v;
        traverse n:NODE.right;
    end
end
escape sum;
*/
]],
    wrn = 'line 26 : unbounded recursive spawn',
    run = 999,
}

-- BUG: loop between declaration and watching
Test { [[
class T with
    event void e;
do
    await FOREVER;
end

pool T[] ts;

var T*? t = spawn T in ts;

loop do
    watching *t do
        kill *t;
    end
    await 1s;
    if false then
        break;
    end
end

escape 1;
]],
    run = { ['~>1s']=10 },
}

Test { [[
class T with
    event void e;
do
    await e;
end

pool T[] ts;

var int ret = 1;

spawn T in ts;
spawn T in ts;
async do end;

native @pure _printf();
loop t1 in ts do
    //watching *t1 do
        loop t2 in ts do
            watching *t1 do
                ret = ret + 1;
                emit t1:e;
                ret = ret + 1;
            end
        end
    //end
end

escape ret;
]],
    run = 3,
}

---------------------

-- TODO: RECURSE

-- TODO: locals inside iter
Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;
var int ii  = 0;

var _tp* vs = &_VS;
loop/3 v in vs do
    if v != null then
        var int i = ii;
        ii = ii + 1;
        traverse v:nxt;
        ret = ret + v:v + i;
    end
end

escape ret;
]],
    run = 9,
}
-- TODO: locals inside iter
Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;
var int ii  = 0;

var _tp* vs = &_VS;
loop/3 v in vs do
    var int i = ii;
    ii = ii + 1;
    if v != null then
        traverse v:nxt;
        ret = ret + v:v + i;
    end
end

escape ret;
]],
    run = 9,
}

-- TODO: unbounded iter
Test { [[
native do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;

var _tp* vs = &_VS;
loop v in vs do
    if v == null then
        break;
    else
        ret = ret + v:v;
        traverse v:nxt;
    end
end

escape ret;
]],
    wrn = true,
    run = 1,
}

-- TODO: precisa do watching
Test { [[
data Tree with
    tag NIL;
with
    tag NODE with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool Tree[3] t;
t = new Tree.NODE(1,
            Tree.NODE(2, Tree.NIL(), Tree.NIL()),
            Tree.NODE(3, Tree.NIL(), Tree.NIL()));

var int sum = 0;

par/or do
    loop i in t do
        if i:NODE then
            traverse i:NODE.left;
            await 1s;
            sum = sum + i:NODE.v;
            traverse i:NODE.right;
            await 1s;
        end
    end
with
    // 1->2->l
    _assert(sum == 0);
    await 1s;
    _assert(sum == 2);
    // 1->*->d
    await 1s;
    await 1s;
    _assert(sum == 3);
    // *->3->l
    await 1s;
    _assert(sum == 6);
    // *->*->r
    await 1s;
    await 1s;
    sum = 0;
end

escape sum;
]],
    _ana = { acc=true },
    run = { ['~>10s']=6 },
}

-- BUG: cannot contain await nao se aplica a par/or com caminho sem await
Test { [[
input void A,F;

interface I with
    var int v;
    event void inc;
end

class T with
    interface I;
do
    await inc;
    this.v = v + 1;
    await FOREVER;
end
pool T[] ts;

var int ret = 0;
do
    par/or do
        await F;
    with
        var int i=1;
        every 1s do
            spawn T in ts with
                this.v = i;
                i = i + 1;
            end;
        end
    with
        every 1s do
            loop i in ts do
                watching *i do
                    emit i:inc;
                    ret = ret + i:v;
                end
            end
        end
    end
end
escape ret;
]],
    run = { ['~>3s;~>F'] = 13 },
}

-- TODO: como capturar o retorno de um org que termina de imediato?
-- R: option type
Test { [[
class T with
do
    escape 1;
end
var T*? t = spawn T;
var int ret = -1;
if t? then
    ret = await *t;
end
escape ret;
]],
    run = 1,
}
