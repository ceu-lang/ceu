-- acertar acesso concorrente em srp.lua
-- remover testes para PAR e ON

-- needChk, quase nunca necessario
-- desabilitar p/ ver o melhor resultado
-- se o par/obj nao emit ou emite somente
-- eventos definidos dentro (e fora da ifc), need=false
-- ana.lua pode melhorar ja que teste so eh necessario
-- para a parte tight [true]=true

-- ceu_evt_param em ceu_call p/ passar p/ o prox

--[===[

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
return ret;
]],
    ana = {
        acc = 2,
    },
    run = false,
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
    emit x => 1;       // in seq
    emit y => 1;       // in seq
end
]],
    ana = {
        acc = 0,
    },
    run = 2;
}

Test { [[
input void START;
native _V;
native do
    int V = 1;
end
class T with
do
    par/or do
        await START;
    with
        await START;    // valgrind error
    end
    _V = 10;
end
do
    spawn T;
    await 1s;
end
return _V;
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
return ret;
]],
    run = {
        ['~>1us;0~>A;~>1us;0~>A;~>19us'] = 12,
        ['~>1us;1~>A;~>1s;0~>A;~>19us'] = 11,
        --['~>1us;1~>A;~>5us;0~>A;~>5us;1~>A;~>5us;0~>A;~>9us'] = 6,
-- BUG: set_min nao eh chamado apos o pause
    },
}

error 'testar pause/if org.e'
error 'testar new/spawn que se mata'

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
    env = 'ERR : line 5 : undeclared class',
}


--do return end

Test { [[
class T with
do
end
var T** t := _malloc(10 * sizeof(T**));
return 10;
]],
    run = 10;
}

Test { [[
class T with
    var int a;
do
    this.a = do return 1; end;
end
var T a;
return a.a;
]],
    run = 1,
}

Test { [[
event (int,int) e;
emit e => (1,2,3);
return 1;
]],
    env = 'line 2 : invalid attribution',
}

Test { [[
event (int,void*) ptr;
var void* p;
var int i;
do
    (i,p) = await ptr;
end
return 1;
]],
    run = 1,
}
do return end

Test { [[
input (int,int,int*) A;
async do
    emit A =>
        (1, 1, null);
end
return 1;
]],
    run = 1;
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
return 1;
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
return 1;
]],
    run = 1;
}

do return end

-- TODO
Test { [[
input (int,int) A;
par do
    var int a, b;
    every (a,b) = A do
        return a+b;
    end
with
    async do
        emit A => (1,3);
    end
end
]],
    run = 4;
}

-- OK: under tests but supposed to work

Test { [[
import;
]],
    ast = 'ERR : tests.lua : line 1 : after `import´ : expected module'
}

Test { [[
import MOD1;
import http://ceu-lang.org/;
import https://github.com/fsantanna/ceu;
import ^4!_;
]],
    ast = 'ERR : tests.lua : line 1 : module "MOD1" not found'
}

_G['/tmp/_ceu_MOD1.ceu'] = [[
input void A;
]]
Test { [[
import /tmp/_ceu_MOD1.ceu ;
await A;
return 1;
]],
    run = { ['~>A']=1 },
}

_G['/tmp/_ceu_MOD1.ceu'] = [[
nothing;
nothing;
nothing;
input void A
]]
Test { [[
nothing;
import /tmp/_ceu_MOD1.ceu ;
await A;
return 1;
]],
    ast = 'ERR : /tmp/_ceu_MOD1.ceu : line 4 : after `A´ : expected `;´',
}

_G['/tmp/_ceu_MOD1.ceu'] = [[
input void A;
_assert(0);
]]
Test { [[
import /tmp/_ceu_MOD1.ceu ;
await A;
return 1;
]],
    run = { ['~>A']=1 },
}

_G['/tmp/_ceu_MOD2.ceu'] = [[
input void A;
]]
_G['/tmp/_ceu_MOD1.ceu'] = [[
import /tmp/_ceu_MOD2.ceu;
]]
Test { [[
import /tmp/_ceu_MOD1.ceu ;
await A;
return 1;
]],
    run = { ['~>A']=1 },
}

_G['/tmp/_ceu_MOD2.ceu'] = [[
input void A;
nothing
]]
_G['/tmp/_ceu_MOD1.ceu'] = [[
import /tmp/_ceu_MOD2.ceu;
]]
Test { [[
import /tmp/_ceu_MOD1.ceu ;
await A;
return 1;
]],
    ast = 'ERR : /tmp/_ceu_MOD2.ceu : line 2 : after `nothing´ : expected `;´',
}

_G['/tmp/_ceu_MOD2.ceu'] = [[
input void A;
]]
_G['/tmp/_ceu_MOD1.ceu'] = [[
input void A;
]]
_G['/tmp/_ceu_MOD0.ceu'] = [[
import /tmp/_ceu_MOD1.ceu ;
import /tmp/_ceu_MOD2.ceu ;
]]
Test { [[
import /tmp/_ceu_MOD0.ceu ;
await A;
return 1;
]],
    run = { ['~>A']=1 },
}

_G['/tmp/_ceu_MOD2.ceu'] = [[
input void A;
]]
_G['/tmp/_ceu_MOD1.ceu'] = [[
nothing;
input void A
]]
_G['/tmp/_ceu_MOD0.ceu'] = [[
import /tmp/_ceu_MOD2.ceu ;
import /tmp/_ceu_MOD1.ceu ;
]]
Test { [[
import /tmp/_ceu_MOD0.ceu ;
await A;
return 1;
]],
    ast = 'ERR : /tmp/_ceu_MOD1.ceu : line 2 : after `A´ : expected `;´',
}

_G['/tmp/_ceu_MOD1.ceu'] = [[
native do
    int f () {
        return 10;
    }
end
]]
Test { [[
import /tmp/_ceu_MOD1.ceu ;
return _f();
]],
    run = 10,
}

_G['/tmp/_ceu_MOD1.ceu'] = [[
native do
    int f () {
        return 10;
    }
end
]]
Test { [[
import /tmp/_ceu_MOD1.ceu ;
import /tmp/_ceu_MOD1.ceu ;
return _f();
]],
    run = 10,
}

_G['/tmp/_ceu_MOD1.ceu'] = [[
interface T with
    var int i;
end
var int i = 0;
]]
Test { [[
//
//
import /tmp/_ceu_MOD1.ceu ;
interface T with
    var int i;
end
var int i = 10;
return i;
]],
    env = 'ERR : tests.lua : line 4 : interface/class "T" is already declared',
}

_G['/tmp/_ceu_MOD1.ceu'] = [[
interface Global with
    var int i;
end
var int i = 0;
]]
Test { [[
import /tmp/_ceu_MOD1.ceu ;
interface Global with
    var int i;
end
var int i = 10;
return i;
]],
    run = 10,
}

do return end

_G['/tmp/_ceu_MOD1.ceu'] = [[
native do
    int f () {
        return 10
    }
    int A;
    int B;
end
]]
Test { [[
import /tmp/_ceu_MOD1.ceu ;
return _f();
]],
    run = false     -- TODO: catch gcc error
}

do return end
--]===]

-- OK: well tested

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
    ast = "line 1 : after `return´ : expected expression"
}

Test { [[
do do do do do do do do do do do do do do do do do do do do
end end end end end end end end end end end end end end end end end end end end
return 1;
]],
    run = 1
}

Test { [[
do do
end end
return 1;
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
return 1;
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
return 1;
]],
    adj = 'line 5 : max depth of 0xFF',
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
    ast = "line 1 : before `nt´ : expected statement",
}
Test { [[nt sizeof;]],
    ast = "line 1 : before `nt´ : expected statement",
}
Test { [[var int sizeof;]],
    ast = "line 1 : after `int´ : expected identifier",
}
Test { [[return sizeof(int);]], run=4 }
Test { [[return 1<2>3;]], run=0 }

Test { [[var int a;]],
    ana = {
        reachs = 1,
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
        reachs = 1,
        isForever = true,
    }
}
Test { [[var int a=1;var int a=0; return a;]],
    --env = 'line 1 : variable/event "a" is already declared at line 1',
    run = 0,
}
Test { [[do var int a=1; end var int a=0; return a;]],
    run = 0,
}
Test { [[var int a=1,a=0; return a;]],
    --env = 'line 1 : variable/event "a" is already declared at line 1',
    run = 0,
}
Test { [[var int a; a = b = 1]],
    ast = "line 1 : after `b´ : expected `;´",
}
Test { [[var int a = b; return 0;]],
    env = 'variable/event "b" is not declared',
}
Test { [[return 1;2;]],
    ast = "line 1 : before `;´ : expected statement",
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
        reachs = 1,
        isForever = true,
    }
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
return 1;
]],
    run = 1,
}

Test { [[
native _abc = 0;
event void a;
var _abc a;
]],
    --env = 'line 3 : variable/event "a" is already declared at line 2',
    env = 'line 3 : cannot instantiate type "_abc"',
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
    env = 'line 1 : malformed number',
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
        reachs = 1,
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
        unreachs = 1,
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
        unreachs = 2,
    },
    run = 1,
}
Test { [[if (2) then  else return 0; end;]],
    ana = {
        reachs = 1,
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
        reachs = 1,
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

Test { [[input int A=1;]], ast="line 1 : after `A´ : expected `;´" }
Test { [[
input int A;
A=1;
return 1;
]],
    ast = 'line 1 : after `;´ : expected statement',
}

Test { [[input  int A;]],
    ana = {
        reachs = 1,
        isForever = true,
    },
}
Test { [[input int A,A; return 0;]],
    --env = 'event "A" is already declared',
    run = 0,
}
Test { [[
input int A,B,Z;
]],
    ana = {
        reachs = 1,
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
        emit A=>10;
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
        emit A => 10;
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
        emit A => 10;
    end;
end;
return A;
]],
    ast = "line 9 : after `return´ : expected expression",
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
return v;
]],
    ana = {
        isForever = false,
    },
    run = 10,
}

Test { [[
input int A;
var int v = await A;
return v;
]],
    run = {
        ['101~>A'] = 101,
        ['303~>A'] = 303,
    },
}

Test { [[var int a = a+1; return a;]],
    --env = 'variable/event "a" is not declared',
    todo = 'TODO: deveria dar erro!',
    run = 1,
}

Test { [[var int a; a = emit a => 1; return a;]],
    ast = 'line 1 : after `=´ : expected expression',
    --ast = "line 1 : after `emit´ : expected event",
    --trig_wo = 1,
}

Test { [[var int a; emit a => 1; return a;]],
    env = 'line 1 : event "a" is not declared',
    --trig_wo = 1,
}
Test { [[event int a=0; emit a => 1; return a;]],
    ast = 'line 1 : after `a´ : expected `;´',
    --trig_wo = 1,
}
Test { [[
event int a;
emit a => 1;
return a;
]],
    val = 'line 3 : invalid expression',
    --run = 1,
    --trig_wo = 1,
}

Test { [[
input void START;
event void e;
every START do
    loop i, 10 do
        emit e;
    end
    do break; end
end
return 10;
]],
    --loop = 1,
    run = 10,
}

Test { [[
var int a=10;
do
    var int b=1;
end
return a;
]],
    run = 10,
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
        excpt = 1,
        --unreachs = 1,
    },
    run = 2,
}

Test { [[
input void START;
event void a, b, c, d;
native _assert();
var int v=0;
par do
    loop do
        await START;
        v = 0;
        emit a;
        v = 1;
        return v;
    end
with
    loop do
        await a;
        v = 2;
    end
end
]],
    run = 1,
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
return x;
]],
    run = { ['1~>E; 2~>E;0~>E']=2 }
}

Test { [[
input void START;
event void a, b, c, d;
native _assert();
var int v=0;
par do
    loop do
        await START;
        emit a;         // killed
        _assert(0);
    end
with
    loop do
        await a;
        return 1;       // kills emit a
    end                 // unreach
end
]],
    ana = {
        unreachs = 1,
        excpt = 1,
    },
    run = 1,
}

Test { [[
input void START;
event void a,b;
par do
    await START;
    emit a;
    return 10;
with
    await a;
    emit b;
    return 100;
end
]],
    run = 100;
}

    -- OUTPUT

Test { [[
output xxx A;
return(1);
]],
    ast = "line 1 : after `output´ : expected type",
}
Test { [[
output int A;
emit A => 1;
return(1);
]],
    run=1
}
Test { [[
output int A;
if emit A => 1 then
    return 0;
end
return(1);
]],
    ast = 'line 2 : after `if´ : expected expression',
}
Test { [[
native do
    #define ceu_out_event(a,b,c) 1
end
output int A;
if emit A => 1 then
    return 0;
end
return(1);
]],
    ast = 'line 5 : after `if´ : expected expression',
}

Test { [[
output t A;
emit A => 1;
return(1);
]],
    ast = 'line 1 : after `output´ : expected type',
}
Test { [[
output t A;
emit A => 1;
return(1);
]],
    ast = 'line 1 : after `output´ : expected type',
}
Test { [[
output _t* A;
emit A => 1;
return(1);
]],
    env = 'line 2 : non-matching types on `emit´',
}
Test { [[
output int A;
var _t v;
emit A => v;
return(1);
]],
    --env = 'line 2 : undeclared type `_t´',
    --env = 'line 3 : non-matching types on `emit´',
    run = false,    -- unknown type name
}
Test { [[
output int A;
native do
    typedef int t;
end
var _t v;
emit A => v;
return(1);
]],
    --env = 'line 2 : undeclared type `_t´',
    --env = 'line 3 : non-matching types on `emit´',
    run = 1,
}
Test { [[
output int A;
var int a;
emit A => &a;
return(1);
]],
    env = 'line 3 : non-matching types on `emit´',
}
Test { [[
output int A;
var int a;
if emit A => &a then
    return 0;
end
return(1);
]],
    ast = 'line 3 : after `if´ : expected expression',
    --env = 'line 3 : non-matching types on `emit´',
}
Test { [[
output _char A;
]],
    env = "line 1 : invalid event type",
}

Test { [[
native do
    /******/
    int end = 1;
    /******/
end
native _end;
return _end;
]],
    run = 1
}

Test { [[
native do
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
    int Fb (int data) {
        return data - 1;
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
return a + b;
]],
    --run = 6,
    ast = 'line 26 : after `=´ : expected expression',
}

Test { [[
native _char = 1;
output void A;
native do
    void A (int v) {}
end
var _cahr v = emit A => 1;
return 0;
]],
    ast = 'line 6 : after `=´ : expected expression',
    --env = 'line 6 : undeclared type `_cahr´',
}
Test { [[
native _char = 1;
output void A;
var _char v = emit A => ;
return v;
]],
    ast = 'line 3 : after `=´ : expected expression',
    --env = 'line 3 : invalid attribution',
}
Test { [[
output void A;
native do
    void A (int v) {}
end
native _char = 1;
var _char v = emit A => 1;
return 0;
]],
    ast = 'line 6 : after `=´ : expected expression',
    --env = 'line 6 : non-matching types on `emit´',
}

Test { [[
native do
    void A (int v) {}
end
emit A => 1;
return 0;
]],
    env = 'event "A" is not declared',
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
        acc = 1,
        abrt = 3,
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
    ana = {
        abrt = 3,
    },
    run = 1,
}

    -- WALL-CLOCK TIME / WCLOCK

Test { [[await 0ms; return 0;]],
    val = 'line 1 : constant is out of range',
}
Test { [[
input void A;
await A;
return 0;
]],
    run = { ['~>10ms; ~>A'] = 0 }
}

Test { [[await -1ms; return 0;]],
    --ast = "line 1 : after `await´ : expected event",
    ast = 'line 1 : after `1´ : expected `;´',
}

Test { [[await 1; return 0;]],
    ast = 'line 1 : after `1´ : expected <h,min,s,ms,us>',
}
Test { [[await -1; return 0;]],
    env = 'line 1 : event "?" is not declared',
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
    ast = "line 1 : before `;´ : expected event",
}
Test { [[await FOREVER; return 0;]],
    ast = "line 1 : before `;´ : expected event",
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
    props = 'line 3 : `return´ without block',
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
return ret;
]],
    ana = {
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
return ret;
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
return ret;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return ret;
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
return ret;
]],
    ana = {
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
return 0;
]],
    ana = {
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
        reachs = 1,
        isForever = true,
    },
}

Test { [[
par do
    await 1s;
    await 1s;
    return 1;   // 4
with
    await 2s;
    return 2;   // 7
end
]],
    ana = {
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
return a;
]],
    ana = {
        abrt = 2,
    },
    run = { ['~>5s; ~>F']=14 },
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
        unreachs = 1,
        abrt = 1,
    },
    run = 1,
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
event int aa;
var int a;
par/and do
    a = do
        return 1;
    end;
with
    await aa;
end;
return 0;
]],
    ana = {
        --unreachs = 2,
        --isForever = true,
    },
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
    code = 'line 4 : invalid expression',
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
        unreachs = 1,
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
        unreachs = 1,
        abrt = 1,
    },
    run = 1,
}
Test { [[
par do
with
    return 1;
end
]],
    run = 1,
    ana = {
        abrt = 1,
    },
}
Test { [[
par do
    await 10ms;
with
    return 1;
end
]],
    ana = {
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
        --unreachs = 1,
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
    run = 1,
    ana = {
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
    ast = "line 16 : after `;´ : expected `with´",
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
break;
]],
    props = 'line 1 : break without loop',
}

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
        unreachs = 1,    -- re-loop
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
        unreachs = 2,
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
return 0;
]],
    ana = {
        isForever = true,
        unreachs = 2,
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
return 1;
]],
    ana = {
        unreachs = 1,
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
end;        // unreachs
return 1;   // unreachs
]],
    ana = {
        unreachs = 2,
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
        return 1;
    end;
end;        // unreachs
return 1;   // unreachs
]],
    ana = {
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
        unreachs = 1,
    },
    loop = 'tight loop',
}

Test { [[break; return 1;]],
    ast="line 1 : before `;´ : expected statement"
}
Test { [[break; break;]],
    ast="line 1 : before `;´ : expected statement"
}
Test { [[loop do break; end; return 1;]],
    ana = {
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
return ret;
]],
    ana = {
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
    ana = {
        isForever = true,
        unreachs = 1,
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
        unreachs = 1,
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
        unreachs = 2,
        isForever = true,
    },
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
return 1;
]],
    run = 1,
}

Test { [[
input void A;
var int ret;
every A do
    ret = ret + 1;
    if ret == 3 then
        return ret;
    end
end
]],
    run = { ['~>A;~>A;~>A']=3 }
}

Test { [[
var int ret;
every 1s do
    await 1s;
    ret = ret + 1;
    if ret == 10 then
        return ret;
    end
end
]],
    props = 'line 3 : `every´ cannot contain `await´',
}

Test { [[
var int ret;
every 1s do
    ret = ret + 1;
    if ret == 10 then
        return ret;
    end
end
]],
    run = { ['~>10s']=10 }
}

Test { [[
var int ret;
var int dt;
every dt = 1s do
    ret = ret + dt;
    if ret == 10000000 then
        return ret;
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
    ana = { isForever=true },
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
    loop = 'tight loop',
    ana = {
        isForever = true,
        --unreachs = 1,
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
    var int v = await E;
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
        unreachs = 1,
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
return 0;
]],
    loop='tight loop',
    ana = {
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
return 0;
]],
    loop='tight loop',
    ana = {
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
return 0;
]],
    loop='tight loop',
    ana = {
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
return 0;
]],
    loop='tight loop',
    ana = {
        abrt = 1,
        isForever = true,
        unreachs = 1,
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
return a;
]],
    ana = {
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
    ana = {
        isForever = true,
        acc = 2,        -- 6/16  10/16
        abrt = 3,
    },
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
        acc = 1,
        unreachs = 1,
    },
    run = 1,
}

Test { [[
input int A;
var int sum = 0;
par/or do
    loop i, 1 do    // 4
        await A;
    end
    sum = 0;
with
    sum = 1;        // 9
end
return sum;
]],
    ana = {
        abrt = 1,
        --unreachs = 2,
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
    sum = 0;    // 9
with
    await A;
    await A;
    sum = 1;    // 13
end
return ret;
]],
    ana = {
        acc = 1,
        abrt = 5,    -- TODO: not checked
    },
    run = { ['~>A; ~>A; ~>A']=2 },
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
    loop i, 1 do    // 4
        await A;
        async do
            var int a = 1;
        end
    end
    sum = 0;
with
    sum = 1;        // 12
end
return sum;
]],
    ana = {
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
    loop i, 10 do       // 5
        await A;
        async do
            var int a = 1;
        end
    end
    sum = 0;            // 11
with
    loop i, 2 do        // 13
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
    --loop = true,
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
    --loop = true,
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
    --loop = true,
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
    --loop = true,
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
    --loop = true,
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
event int a;
var int ret = 0;
par/or do
    await START;
    emit a  =>  1;
with
    ret = await a;
end
return ret;
]],
    run = 1,
    ana = {
        excpt = 1,
    },
}

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
        acc = 1,
    },
    run = 2,
}

Test { [[
input void START;
var int ret;
event void a,b;
par/and do
    await START;
    emit a;         // 6
with
    par/or do
        await START;
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
return ret;
]],
    ana = {
        acc = 1,
        abrt = 3,
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
    ret = 1;    // 18: acc
with
    await d;
    ret = 2;    // 21: acc
end
return ret;
]],
    ana = {
        acc = 1,
    },
    run = 2,
}

Test { [[
event int c;
emit c => 10;
await c;
return 0;
]],
    ana = {
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
return c;
]],
    val = 'line 4 : invalid expression',
    --trig_wo = 2,
}

Test { [[
event int c;
emit c => 10;
emit c => 10;
return 10;
]],
    run = 10,
    --trig_wo = 2,
}

Test { [[
event int b;
var   int a;
a = 1;
emit b => a;
return a;
]],
    run = 1,
    --trig_wo = 1,
}

-- ParOr

Test { [[
input void START;
event int a;
var int aa = 3;
par do
    await START;
    emit a => aa;      // 6
    return aa;
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
input void START;
event int a;
var int aa = 3;
par do
    await START;
    emit a => aa;
    return aa;
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
return ret;
]],
    env = 'line 10 : invalid emit',
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
return ret;
]],
    ana = {
        abrt = 1,
        --unreachs = 1,
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
return a;
]],
    ana = {
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
        return 0;               // 8
    with
        var int v = await A;
        return v;               // 11
    end;
return a;
]],
    ana = {
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
            return v;           // 6
        end;
        return 0;
    with
        var int v = await A;
        return v;               // 11
    end;
return a;
]],
    ana = {
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
        --unreachs = 1,
        acc  = 2,
        abrt  = 6,
    },
    run = { ['1~>A']=1 },
}

Test { [[
input void START;
event void e;
var int v;
par/or do           // 4
    await START;
    emit e;         // 6
    v = 1;
with
    await e;        // 9
    emit e;
    v = 2;
end
return v;
]],
    ana = {
        excpt = 1,
    },
    run = 2,
}

Test { [[
input int A,B;
var int a,v;
a = par do
    if 1 then
        v = await A;    // 5
    else
        await B;
        return v;
    end;
    return 0;           // 10
with
    var int v = await A;
    return v;           // 13
end;
return a;
]],
    ana = {
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
        return v;       // 6
    else
        await B;
        return v;
    end;
    return 0;
with
    var int v = await A;
    return v;           // 14
end;
return a;
]],
    ana = {
        unreachs = 1,
        acc = 1,
        abrt = 3,
    },
    run = { ['1~>A']=1 },
}

Test { [[
input void START;
event void a, b, c, d;
native _assert();
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
        return v;       // 35
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
        acc = 29,         -- TODO: not checked
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
return a;
]],
    ana = {
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
    return 1;
with
    await B;
    par/or do
    with
    end;
    return 2;
end;
]],
    ana = {
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
    return 1;
with
    await B;
    par/or do
        return 2;
    with
    end;
    return 3;
end;
]],
    ana = {
        --unreachs = 1,
        abrt = 8,      -- TODO: not checked
        acc = 2,
    },
}

Test { [[
event void a, b;
input void START,A;
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
    await START;
    emit a;
    await A;
    emit b;
end
return ret;
]],
    run = { ['~>A']=2 },
}

-- TODO: STACK
Test { [[
event void a, b;
input void START;
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
    await START;
    emit a;
    emit b;
end
return ret;
]],
    ana = { acc=1 },
    run = 1,
}

-- TODO: STACK
-- internal glb awaits
Test { [[
input void START;
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
    await START;
    emit a;
    emit a;
end
]],
    ana = {
        isForever = true,
        acc = 3,
        abrt  = 3,
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
        emit x => 1;   // 7
        emit y => 1;   // 8
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
    emit x => 1;       // 20
    emit y => 1;       // 21
end
]],
    ana = {
        acc = 3,
        abrt = 5,   -- TODO: not checked
    },
    run = 2;
}

Test { [[
input void START;
event void a, b;
par do
    par do
        await a;    // 5
        return 1;   // 6
    with
        await b;
        return 2;   // 9
    end
with
    await START;    // 12
    emit b;
with
    await START;    // 15
    emit a;
end
]],
    run = 2,
    ana = {
        acc = 1,
        abrt = 5,
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
return a + b + c + d;
]],
    ana = {
        acc = 2,
        abrt = 5,   -- TODO: not checked
    },
    run = { ['0~>A;5~>B']=6 },
    --run = { ['0~>A;5~>B']=8 },
    --todo = 'nd excpt',
}

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
        acc = 2,
        abrt = 5,   -- TODO: not checked
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
        acc = 1,
        abrt = 3,
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
        abrt = 1,
        --unreachs = 1,
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
    ana = {
        abrt = 3,
        acc = 1,
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
    ana = {
        abrt = 1,
    },
    run = 10,
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
    ana = {
        abrt = 3,
    },
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
    ana = {
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
    return a;
with
    var int b = await 10ms;
    return b;
end;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a + b;
]],
    ana = {
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
return a + b;
]],
    ana = {
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
return a + b;
]],
    ana = {
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
return a + b;
]],
    ana = {
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
return a + b;
]],
    ana = {
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
    return a;
with
    b = await (10000)us;
    return b;
end;
]],
    ana = {
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
return a+b;
]],
    ana = {
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
return a+b;
]],
    ana = {
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
    return a;
with
    b = await (5)us;
    await 5us;
    return b;
end;
]],
    ana = {
        acc = 1,
        abrt = 4,
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
return v1 + v2;
]],
    ana = {
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
return v1 + v2 + v3;
]],
    ana = {
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
    ana = {
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
    ana = {
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
return v;
]],
    ana = {
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
return v;
]],
    run = 1,
    --run = 2,
    ana = {
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
    ana = {
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
return a;
]],
    ana = {
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
    ana = {
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
    ana = {
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
    ana = {
        abrt = 1,
        isForever = true,
        acc = 1,
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
        acc = 1,
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
    ana = {
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
return a+b+c;
]],
    ana = {
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
        abrt = 9,
        acc = 3,
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
return 0;
]],
    val = 'line 1 : constant is out of range',
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
        acc = 1,
        abrt = 3,
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
    ana = {
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
    emit a => 10;
with
    ret = await a;
end;
return ret;
]],
    ana = {
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
return ret;
]],
    ana = {
        acc = 1,
        abrt = 1,
    },
    run = 1,
}

Test { [[
input void START;
event int a;
var int ret = 1;
par/and do
    await START;
    emit a => 10;
with
    ret = await a;
end;
return ret;
]],
    ana = {
        --acc = 1,
    },
    run = 10,
}
Test { [[
event int a;
par/and do
    await a;
with
    emit a => 1;
end;
return 10;
]],
    ana = {
        acc = 1,
    },
    run = 0,
}

Test { [[
input int A;
event int b, c;
par do
    await A;
    emit b => 1;
    await c;        // 6
    return 10;      // 7
with
    await b;
    await A;
    emit c => 10;      // 11
end;
]],
    ana = {
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
    return 10;      // 7
with
    await b;
    await A;
    emit c => 10;      // 11
    // unreachable
    await c;
    // unreachable
    return 0;       // 15
end;
]],
    ana = {
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
    ana = {
        isForever = true,
        acc = 1,
        abrt = 3,
    },
}
Test { [[
event int a;
par/or do
    return 1;       // TODO: [false]=true
with
    emit a => 1;       // TODO: elimina o [false]
    // unreachable
end;
// unreachable
await a;
// unreachable
return 0;
]],
    ana = {
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
return 0;
]],
    ana = {
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
    return 1;
with
    emit a => 1;
    // unreachable
end;
]],
    ana = {
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
    return 0;
with
    return 2;
end;
]],
    ana = {
        --unreachs = 1,
        acc = 1,
        abrt = 3,
        --trig_wo = 1,
    },
    run = false,    -- TODO: stack change
    --run = 2,
}
Test { [[
event int a;
par/or do
    emit a => 1;
with
end;
await a;
return 0;
]],
    ana = {
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
return v1+v2;
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
return v1+v2;
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
return v1+v2;
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
return v1+v2;
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
return v1+v2;
]],
    ana = {
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
return v1+v2+v3;
]],
    ana = {
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
return v1+v2+v3;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return ret;
]],
    ana = {
        --unreachs = 2,
        abrt = 4,
        acc = 1,
    },
    --run = 3,
    run = 9,
}

-- 1st to escape and terminate
Test { [[
event int a;
var int ret=9;
par/or do
    var int aa = await a;
    ret = aa + 1;
with
    par/or do
        emit a => 2;
    with
        ret = 3;
    end;
end;
return ret;
]],
    ana = {
        --unreachs = 2,
        abrt = 4,
        acc = 1,
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
    return a;
end;
return a;
]],
    ana = {
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
return 0;
]],
    ana = {
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
    ana = {
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
        acc = 1,
        abrt = 1,
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
        acc = 1,
        abrt = 3,
    },
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
    ana = {
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
return v;
]],
    ana = {
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
return v;
]],
    ana = {
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
return v;
]],
    ana = {
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
var int cc = 1;
par/and do
    await START;
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
return cc;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return dt;
]],
    ana = {
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
return dt;
]],
    ana = {
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
return dt;
]],
    ana = {
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
return dt;
]],
    ana = {
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
    return 1;
with
    dt = await 10us;
    await A;
    dt = await 10us;
    return 2;
end;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return dt;
]],
    ana = {
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
return dt;
]],
    ana = {
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
return dt;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return dt;
]],
    ana = {
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
return dt;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return x;
]],
    ana = {
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
return x;
]],
    ana = {
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
return x;
]],
    ana = {
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
    return 1;
with
    await A;
    return 2;
end;
]],
    ana = {
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
    return 1;
with
    await A;
    return 2;
end;
]],
    ana = {
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
    return 1;           // 15
with
    await A;            // 17
    return 2;           // 18
end;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
    ana = {
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
    ana = {
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
    ana = {
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
return a;
]],
    ana = {
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
    ana = {
        isForever = true,
        acc = 5,
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
        acc = 1,
        abrt = 3,
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
        acc = 1,
        abrt = 3,
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return 0;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    --todo = 'wclk_any=0',
    ana = {
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
return a;
]],
    todo = 'wclk_any=0',
    ana = {
        acc = 3,
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
return x;
]],
    ana = {
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
    ana = {
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
    ana = {
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
return x;
]],
    ana = {
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
return ret;
]],
    ana = {
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
    ana = {
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
    ana = {
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
return dd + ee;
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
    return aa;
end;
]],
    ana = {
        --nd_esc = 1,
        abrt = 1,
        --unreachs = 1,
        --trig_wo = 1,
        acc = 1,
    },
}

Test { [[
event int a;
var int v,aa;
loop do
    par do
        v = aa;
    with
        await a;
    end;
end;
]],
    ana = {
        isForever = true,
        unreachs = 1,
        reachs = 1,
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
    emit b => 1;
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
        emit a => 1;
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
        --unreachs = 1,
        reachs = 1,
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
    emit a => 3;
end;
return b+b;
]],
    ana = {
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
return 0;
]],
    ana = {
        abrt = 5,
        --unreachs = 2,
        acc = 1,
        --trig_wo = 1,
    },
}

Test { [[
input void START;
event int b;
var int i;
par/or do
    await START;
    emit b => 1;
    i = 2;
with
    await b;
    i = 1;
end;
return i;
]],
    ana = {
        --nd_esc = 1,
        unreachs = 0,
    },
    run = 1,
}
Test { [[
input void START;
event int b,c;
var int cc;
par/or do
    await START;
    emit b => 1;
    cc = await c;
with
    await b;
    cc = 5;
    emit c => 5;
end;
return cc;
]],
    ana = {
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
    var int b = await B;
    a = a + b;
    if a == 5 then
        return 10;
    end;
end;
return 0;   // TODO
]],
    ana = {
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
var int aa;
loop do
    var int v = await A;
    if v==2 then
        return aa;
    end;
    emit a => v;
    aa = v;
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
var int aa;
loop do
    var int v = await A;
    if v==2 then
        return aa;
    else
        if v==4 then
            break;
        end;
    end;
    emit a => v;
    aa = v;
end;
return aa-1;
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
var int ret = 0;
par/or do await A; with await B; end;
par/or do
    ret=await A;
with
    ret=await B;
end;
return ret;
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
return v;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return v;
]],
    ana = {
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
return v;
]],
    ana = {
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
return v;
]],
    ana = {
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
return v;
]],
    ana = {
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
return v;
]],
    ana = {
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
return v;
]],
    ana = {
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
return v;
]],
    ana = {
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
        return v;
    end;
with
    var int v = await A;
    return v;
end;
]],
    ana = {
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
        unreachs = 1,
    },
}
Test { [[
par/or do
with
end
return 1;
]],
    ana = {
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
    return 1;
with
    await B;
    return a;
end;
]],
    ana = {
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
    return 1;
with
    par/or do
        await a;
    with
        await B;
    with
        await Z;
    end;
    return aa;
end;
]],
    ana = {
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
    return 10;
with
    par/or do
        await a;    // 10
    with
    with
        await Z;
    end;
    return aa;
end;
]],
    ana = {
        acc = 1,
        abrt = 3,
        --unreachs = 2,    -- +1 native unreachs
    },
    --run = 1,
    run = 10,
}
Test { [[
input void START;
event int a;
par do
    await START;
    emit a => 1;
with
    var int aa = await a;
    return aa;
end;
]],
    ana = {
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
return aa;
]],
    ana = {
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
return aa;
]],
    ana = {
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
return aa;
]],
    ana = {
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
var int aa;
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
return aa;
]],
    ana = {
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
    return aa;  // 5
with
    par/and do  // 7
        aa = await a;
    with
    end;
    return aa;
end;
]],
    ana = {
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
    return aa;
with
    par/and do
        aa = await a;
    with
    with
        await Z;
    end;
    return aa;
end
]],
    ana = {
        acc = 1,
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
    return aa;
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
    return a;
with
    par/and do
        await aa;
    with
        await B;
    with
        await Z;
    end;
    return a;
end;
]],
    ana = {
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
return 1;
]],
    ana = {
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
return 1;
]],
    ana = {
        abrt = 3,
        unreachs = 2,
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
        return 1;
    with
        await A;
    end;
end;
return 2;   // executes last
]],
    ana = {
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
            return 1;   // 7
        with
            await A;    // 9
            // unreachable
        end;
    end;
end;
return 2;   // executes last
]],
    ana = {
        unreachs = 1,
        abrt = 4,
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
    ana = {
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
return 1;
]],
    ana = {
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
    return aa;
end;
return aa;
]],
    ana = {
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
    return aa;
with
    await B;
    par/or do
        await a;
    with
    end;
    return aa;
end;
]],
    ana = {
        --unreachs = 1,
        abrt = 4,
        acc = 2,
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
        acc = 1,
        abrt = 3,
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
        acc = 2,
        abrt = 3,
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
        abrt = 9,
        acc = 3,
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
        acc = 1,
        abrt = 3,
    },
}

Test { [[
event int a;
var int aa;
par/or do
    await a;
with
    emit a => 1;
    aa = 1;
end;
return aa;
]],
    ana = {
        abrt = 1,
        --unreachs = 1,
        acc = 1,
        --trig_wo = 1,
    },
    run = 1,
}
Test { [[
event int a;
par/or do
    emit a => 1;
with
    emit a => 1;
end;
return 1;
]],
    ana = {
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
return aa+bb;
]],
    ana = {
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
return a+b;
]],
    ana = {
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
    return aa;
with
    emit a => 1;
    return aa;
with
    emit a => 1;
    return aa;
end;
return v;
]],
    ana = {
        acc = 8, -- TODO: not checked
        abrt = 9,
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
    return a;
with
    await A;
    return a;
end;
]],
    ana = {
        abrt = 3,
        acc = 1,
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
return 1;
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
return ret;
]],
    ana = {
        acc = 1,
        --nd_esc = 1,
    },
    run = { ['1~>A;2~>A;3~>A']=3 },
}
Test { [[
input void START;
event int a;
par do
    await START;
    emit a => 1;
    return 1;
with
    var int aa = await a;
    aa = aa + 1;
    return aa;      // 10
with
    await a;        // 12
    await FOREVER;
end;
]],
    ana = {
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
return aa;
]],
    ana = {
        --nd_esc = 1,
        --unreachs = 1,
        acc = 2,
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
    ana = {
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
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
    ana = {
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
return a+b+c+d;
]],
    ana = {
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
return aa+bb+cc;
]],
    ana = {
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
return 10;
]],
    ana = {
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
return 0;
]],
    ana = {
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
return 0;
]],
    ana = {
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
    ana = {
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
return 1;
]],
    ana = {
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
    return ret;
end
return ret;
]],
    ana = {
        unreachs = 1,
        abrt = 3,
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
return a;
]],
    ana = {
        abrt = 6,
    },
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
return v;
]],
    ana = {
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
return v1 + v2;
]],
    ana = {
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
return v;
]],
    ana = {
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
    ast = 'line 4 : before `;´ : expected statement',
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
return 0;
]],
    ana = {
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
return v1+v2+v3;
]],
    ana = {
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
return v1+v2+v3+v4+v5+v6;
]],
    ana = {
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
return v1+v2+v3+v4+v5+v6;
]],
    ana = {
        unreachs = 2,
        abrt = 6,
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
return v1+v2+v3+v4+v5+v6;
]],
    ana = {
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
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return b;
]],
    ana = {
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
return b;
]],
    ana = {
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
                return v;
            end;
            a = a + 1;
        end;
    a = a + 2 + b;
end;
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
return a;
]],
    ana = {
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
    ana = {
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
return v;
]],
    ana = {
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
    return v;
with
    var int v = await A;
    return v;
end;
]],
    ana = {
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
return v;
]],
    ana = {
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
        unreachs = 1,
        abrt = 2,
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
    ana = {
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
    return b;
end;
]],
    ana = {
        unreachs = 1,
    },
    run = {
        ['2~>Z ; 1~>A ; 1~>D'] = 2,
    }
}

Test { [[
input int A,Z;
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
return ret;
]],
    ana = {
        unreachs = 1,
    },
    run = { ['~>A;~>A;~>Z']=2 },
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
        unreachs = 1,
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
    ast = "line 3 : after `par´ : expected `do´",
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
return 2;
]],
    ana = {
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
    ana = {
        isForever = true,
        unreachs = 3,
    },
}

Test { [[
event int a;
emit a => 8;
return 8;
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
    ana = {
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
    ana = {
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
return v;
]],
    ana = {
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
    return v;
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
    return c;
end;
]],
    ana = {
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
    return v;
with
    v = await a;
    return v;       // 15
with
    var int bb = await b;
    return bb;       // 18
end;
]],
    ana = {
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
        return v;
    with
        await B;
        emit b => 1;
        return v;
    end;
with
    var int aa = await a;
    return aa;
with
    var int bb = await b;
    return bb;
end;
]],
    ana = {
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
    ana = {
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
    ana = {
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
    return cc;
end;
]],
    ana = {
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
    ana = {
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
return aa;
]],
    ana = {
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
return aa;
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
    return 1;
end;
]],
    ana = {
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
return 0;
]],
    ana = {
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
return 0;
]],
    ana = {
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
return 0;
]],
    ana = {
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
return aa;
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
return aa;
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
return 0;
]],
    ana = {
        --isForever = true,
        unreachs = 2,
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
    emit a => 1;
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
        acc = 1,
        --isForever = true,
        --unreachs = 2,
    },
    run = { ['1~>B;~>B']=10 },
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
return aa;
]],
    ana = {
        acc = 1,
    },
    run = { ['1~>B;~>B']=10 },
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
return aa;
]],
    ana = {
        acc = 1,
    },
    run = { ['1~>B;~>B']=10 },
}

Test { [[
input int A;
event int a,b;
par/and do
    await A;
    emit a => 1;
    await A;
    emit b => 1;
with
    await a;
    await b;
    return 1;
end;
return 0;
]],
    ana = {
        --nd_esc = 1,
        unreachs = 2,
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
var int aa;
par/and do
    await START;
    emit a => 1;
with
    par/or do
    with
    end;
    aa = await a;
end;
return aa;
]],
    ana = {
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
return 1;
]],
    ana = {
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
input void START, A;
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
    await START;
    emit b;
    emit b;
    await A;
    emit a;
    return v;
end;
]],
    ana = {
        unreachs = 1,
    },
    run = { ['~>A']=1 },
}

Test { [[
input void START;
var int v = 0;
event int a, b;
par/or do
    loop do
        var int aa = await a;
        emit b => aa;
        v = v + 1;
    end
with
    await START;
    emit a => 1;
    return v;
end;
]],
    run = 1,
    ana = {
        unreachs = 1,
    },
}

Test { [[
input void START, F;
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
    await START;
    emit a => 1;
    await A;
    emit a => 1;
    await A;
    emit a => 0;
    return v+x;
end;
return 10;
]],
    --nd_esc = 1,
    --run = { ['~>A;~>A'] = 1 },
    run = { ['~>A;~>A'] = 4 },
    ana = {
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
    return v1 + v2;
end;
]],
    props = "line 8 : invalid access from async",
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
        acc = 1,
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
    props = "line 8 : invalid access from async",
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
            var int p2 = await P2;
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
    ana = {
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
return aa+bb;
]],
    run = { ['~>A;~>B']=4 },
}

Test { [[
input int F;
event int draw, occurring, sleeping;
var int x, vis;
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
    ana = {
        unreachs = 1,
        acc = 3,
        abrt = 1,
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
        emit b => 1;
        v = 4;
    end;
with
    loop do
        await b;
        v = 3;
    end;
with
    await START;
    emit a => 1;
    return v;
end;
// unreachable
return 0;
]],
    ana = {
        unreachs = 1,
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
return v1 + v2;
]],
    run = 21,
}

-- TODO: STACK
Test { [[
input void START,A;
event int a;
var int aa=0;
par/or do
    loop do
        aa = await a;
        aa = aa + 1;
    end;
with
    await START;
    emit a => 1;
    emit a => aa;
    emit a => aa;
    emit a => aa;
    emit a => aa;
    emit a => aa;
end;
return aa;
]],
    --run = 7,
    run = 2,
}

Test { [[
input void START,A;
event int a;
var int aa;
par/or do
    loop do
        aa=await a;
        aa = aa + 1;
    end;
with
    await START;
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
return aa;
]],
    run = { ['~>A;~>A;~>A;~>A;~>A'] = 7, },
}

Test { [[
input void START, A;
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
    await START;
    emit a => 1;
    bb = 0;
end;
return bb;
]],
    ana = {
        --nd_esc = 1,
        unreachs = 1,
    },
    run = 0,
}

Test { [[
input void START;
event int a;
var int aa;
par/or do
    await START;
    emit a => 0;
with
    aa = await a;
    aa= aa+1;
    emit a => aa;
    await FOREVER;
end;
return aa;
]],
    run = 1,
}

Test { [[
input void START;
event int a,b;
var int aa;
par/or do
    await START;
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
return aa;
]],
    run = 2,
}

Test { [[
input void START;
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
    return cc;
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
    return v1+v2;
end;
]],
    ana = {
        --nd_esc = 1,
        unreachs = 3,
        --trig_wo = 1,  -- unreachs
    },
    run = 0,
}

Test { [[
input void START, A;
event int a;
par do
    loop do
        await START;
        emit a => 0;
        await A;
    emit a => 1;
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
return a;
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
return a;
]],
    ana = {
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
    return i;
end;
]],
    run = { ['1~>A;1~>A;1~>A;1~>A;1~>A;1~>F'] = 5 },
}

Test { [[
input int F;
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
    return c;
end;
]],
    ana = {
        abrt = 2,
    },
    run = { ['~>1100ms ; ~>F'] = 66 }   -- TODO: stack change
}

Test { [[
input void START;
event int a, b, c;
var int x = 0;
var int y = 0;
par/or do
    await START;
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
return x + y;
]],
    ana = {
        unreachs = 4,
        abrt = 1,
    },
    run = 6,    -- TODO: stack change (6 or 3)
}

Test { [[
input int F;
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
    return c;
end;
]],
    ana = {
        abrt = 2,
    },
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
event int a;
var int b;
par/and do
    await START;
    emit a => 1;
    b = 1;
with
    var int aa = await a;
    b = aa + 1;
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
    emit a => 1;
    b = 1;
with
    var int aa =await a;
    b = aa + 1;
end;
return b;
]],
    ana = {
        unreachs = 1,
    --nd_esc = 1,
    },
    run = 2,
}

Test { [[
input void START;
event int a;
par do
    var int aa = await a;
    emit a => 1;
    return aa;
with
    await START;
    emit a => 2;
    return 0;
end;
]],
    ana = {
        --nd_esc = 1,
    unreachs = 1,
    --trig_wo = 1,
    },
    run = 2,
}

Test { [[
input void START;
event int a, b;
var int aa;
par/or do
    loop do
        await a;
        emit b => 1;
    end;
with
    await START;
    emit a => 1;
with
    await b;
    emit a => 2;
    aa = 2;
end;
return aa;
]],
    ana = {
        --nd_esc = 2,
        unreachs = 3,
        --trig_wo = 1,
    },
    run = 2,
}

-- TODO: STACK
Test { [[
input void START;
event int a;
var int x = 0;
par do
    await START;
    emit a => 1;
    emit a => 2;
    return x;
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
input void START, A;
event int a;
var int x = 0;
par do
    await START;
    emit a => 1;
    await A;
    emit a => 2;
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
    emit a  =>  1;
    return x;
with
    loop do
        await a;
        x = x + 1;
    end
end
]],
    ana = {
        acc = 1,
        --abrt = 1,
        unreachs = 0,
    },
}
Test { [[
input void START;
event void a;
var int x = 0;
par/or do
    await START;
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
return x;
]],
    ana = {
        abrt = 1,
        acc = 1,
        unreachs = 2,
    },
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
    ana = {
        --acc = 1,
        acc = 6,     -- TODO: not checked
        --trig_wo = 2,
        unreachs = 2,
        isForever = true,
    },
}

-- TODO: STACK
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
                await x;    // 12
                ret = 1;    // 13
            with
                await y;    // 15
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
input void START;
event int a, x, y;
var int ret = 0;
par do
    par/and do
        await START;
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
    await START;
    ret = ret + 1;
    emit a => 1;
    ret = ret * 2;
    emit x => 0;               // 7
    ret = ret + 1;
    emit y => 0;               // 25
    ret = ret * 2;
    return ret;
end;
]],
    ana = {
        abrt = 1,
        acc = 4,
        --acc = 1,
        --trig_wo = 2,
        unreachs = 1,
    },
    run = false,        -- TODO: stack change (ND)
    --run = 18,
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
    ana = {
        acc = 6,
        --trig_wo = 2,
        unreachs = 2,
        isForever = true,
    },
}

-- TODO: STACK
Test { [[
input void START;
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
    await START;
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
    return aa+xx+yy+zz+ww;
end;
]],
    ana = {
        abrt = 1,        -- false positive
        --trig_wo = 2,
        unreachs = 2,
    },
    --run = { ['1~>F']=7 },
    run = { ['1~>F']=5 },
}

    -- SCOPE / BLOCK

Test { [[do end;]],
    ana = {
        reachs = 1,
        isForever = true,
    },
}
Test { [[do var int a; end;]],
    ana = {
        reachs = 1,
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
        acc = 1,
        abrt = 1,
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
return 0;
]],
    ast = 'line 1 : after `event´ : expected type',
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
return a;
]],
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
return ret;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return aa;
]],
    ana = {
    abrt = 1,
        --nd_esc = 2,
        unreachs = 3,
        acc = 1,
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
return ret;
]],
    ana = {
        --nd_esc = 1,
    unreachs = 2,
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
    props = 'line 2 : not permitted inside `finalize´',
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
    props = "line 7 : not permitted inside `finalize´",
}

Test { [[
native _f();
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
    props = "line 7 : not permitted inside `finalize´",
}

Test { [[
native _f();
do
    var int* a;
    finalize
        a = _f();
    with
        do return 0; end;
    end
end
]],
    props = "line 7 : not permitted inside `finalize´",
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
    loop = 'line 1 : tight loop',    -- TODO: par/and
    props = "line 8 : not permitted inside `finalize´",
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
    env = 'line 6 : variable/event "a" is not declared',
}

Test { [[
native _f();
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
    props = "line 8 : not permitted inside `finalize´",
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
return(a);
]],
    --env = 'line 8 : native variable/function "_f" is not declared',
    run = 10,
}

Test { [[
native _f();
_f() finalize with nothing;
    end;
return 1;
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
return v;
]],
    run = 8,
}

Test { [[
native _f();
native do void f () {} end

var void* p;
_f(p) finalize with nothing;
    end;
return 1;
]],
    run = 1,
}

Test { [[
native _f();
native do void f () {} end

var void* p;
_f(p!=null) finalize with nothing;
    end;
return 1;
]],
    fin = 'line 5 : invalid `finalize´',
    run = 1,
}

Test { [[
native _f();
do
    var int* p1;
    do
        var int* p2;
        _f(p1, p2);
    end
end
return 1;
]],
    fin = 'line 6 : call requires `finalize´',
    -- multiple scopes
}

Test { [[
native _f();
native _v;
_f(_v);
return 0;
]],
    fin = 'line 3 : call requires `finalize´',
}

Test { [[
native _f();
native do
    V = 10;
    int f (int v) {
        return v;
    }
end
native constant _V;
return _f(_V);
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
return _f(&v) == 1;
]],
    fin = 'line 8 : call requires `finalize´',
}

Test { [[
native nohold _f();
native do
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
native _V;
native nohold _f();
native do
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
return ret;
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
return ret;
]],
    ana = {
        acc = 3,
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
    ana = {
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
return ret;
]],
    run = { ['~>B']=17, ['~>A']=605 },
}

Test { [[
input void START;
await START;
par/or do
    await START;
with
    await START;
end
return 1;
]],
    run = 0,
}

Test { [[
input void START;
await START;
do
    finalize with
        var int ret = 1;
    end
    await START;
end
return 1;
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
return ret;
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
                ret = ret + 4;  // executed after `return´ assigns to outer `ret´
    end
            return ret * 2;
        end
    end
end;
return ret;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return ret;
]],
    ana = {
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
return v;
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
native nohold _f();
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

Test { [[
finalize with
end
return 1;
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
return ret + _V;
]],
    run = 16,
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
    --abrt = 1,
    run = 2,
    ana = {
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
return a;
]],
    props = 'invalid access from async',
    ana = {
        --acc = 1,
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
    emit A => a;
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
    --env = "line 4 : invalid input `emit´",
    ast = 'line 4 : after `=´ : expected expression',
}

Test { [[
event int a;
async do
    emit a => 1;
end;
return 0;
]],
    props = 'line 3 : invalid access from async',
}
Test { [[
event int a;
async do
    await a;
end;
return 0;
]],
    props = 'line 3 : invalid access from async',
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
    emit X => 1;
end;
emit X => 1;
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
native _a;
native do
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
return _a+_b;
]],
    todo = 'async is not simulated',
    ana = {
        acc = 1,
    },
}

Test { [[
constant _a;
deterministic _b with _c;
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
return _a+_b+_c;
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
return _a + _b;
]],
    ana = {
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
return _a + a;
]],
    ana = {
        abrt = 1,
    },
    run = 1,
}

Test { [[
native _a;
native do
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
    ana = {
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
return _a+_b+_c;
]],
    todo = 'nd in async',
    ana = {
        acc = 3,
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
        --unreachs = 1,       -- TODO: loop iter
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
        unreachs = 3,
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
        emit A => 1;
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
        emit A => 4;
    end;
with
end;
return 1;
]],
    ana = {
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
        --unreachs = 1,       -- TODO: async
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
native _char = 1;
var int i;
var int* pi;
var _char c=10;
var _char* pc;
i = c;
c = i;
i = (int) c;
c = (_char) i;
return c;
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
native _char=1;
var _char* ptr1;
var int* ptr2=(void*)0xFF;
ptr1 = ptr2;
ptr2 = ptr1;
return (int)ptr2;
]],
    --env = 'line 4 : invalid attribution',
    run = 255,
}
Test { [[
native _char=1;
var _char* ptr1;
var int* ptr2;
ptr1 = (_char*)ptr2;
ptr2 = (int*)ptr1;
return 1;
]],
    run = 1,
}
Test { [[
native _char=1;
var int* ptr1;
var _char* ptr2;
ptr1 = (int*) ptr2;
ptr2 = (_char*) ptr1;
return 1;
]],
    run = 1,
}

Test { [[
native _FILE=0;
var int* ptr1;
var _FILE* ptr2;
ptr1 = ptr2;
ptr2 = ptr1;
return 1;
]],
    run = 1,
    --env = 'line 4 : invalid attribution',
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
    ana = {
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
return b;
]],
    ana = {
        abrt = 1,
        acc = 1,
    },
    run = 1,
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
native nohold _f();
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
return a + b;
]],
    run = 2,
    ana = {
        acc = 1,
    },
}

Test { [[
native nohold _f();
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
return a + b;
]],
    run = 2,
    ana = {
        acc = 7,
    },
}

Test { [[
native nohold _f();
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
return a + b;
]],
    run = 1,
    ana = {
        abrt = 6,
        acc = 7,
    },
}

Test { [[
pure _f;
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
return a + b;
]],
    todo = true,
    run = 2,
    ana = {
        acc = 2,
    },
}

Test { [[
pure _f;
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
return a + b;
]],
    todo = true,
    run = 1,
    ana = {
        acc = 2,
    },
}

Test { [[
var int b = 10;
var int* a = (int*) &b;
var int* c = &b;
return *a + *c;
]],
    run = 20;
}

Test { [[
native _f();
native do
    int* f () {
        int a = 10;
        return &a;
    }
end
var int* p = _f();
return *p;
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
native _f();
native do
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
native pure _f();    // its is actually impure
native do
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
native _f();
native do
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
native _f();
native do
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
native _char = 1;
var _char* p;
*(p:a) = (_char)1;
return 1;
]],
    run = false,
}

Test { [[
input void START;
var int h = 10;
var int* p = &h;
do
    var int x = 0;
    await START;
    var int z = 0;
end
return *p;
]],
    run = 10;
}

    -- ARRAYS

Test { [[input int[1] E; return 0;]],
    ast = "line 1 : after `int´ : expected identifier",
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
    ast = 'line 1 : after `<BOF>´ : expected statement',
}

Test { [[
var void[10] a;
]],
    env = 'line 1 : cannot instantiate type "void"',
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
return i + vec[9].c + vec[3].v[5];
]],
    run = 220,
}

Test { [[var int[2] v; await v;     return 0;]],
        env='event "v" is not declared' }
Test { [[var int[2] v; emit v;    return 0;]],
        env='event "v" is not declared' }
Test { [[var int[2] v; await v[0];  return 0;]],
        env='line 1 : event "?" is not declared'}
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
native nohold _f();
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
return a[0] + b;
]],
    run = 3,
}

Test { [[
native nohold _f();
native do
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
    ana = {
        abrt = 1,
    },
    run = 2,
}

Test { [[
var u8[255] vec;
event void  e;
return 1;
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
return 1;
]],
    env = 'line 1 : too many events',
}

Test { [[
var int a = 1;
return a;
]],
    run = 1,
}

    -- NATIVE C FUNCS BLOCK RAW

Test { [[
return {1};
]],
    run = 1,
}

Test { [[
{ int V = 10; };
return _V;
]],
    run = 10,
}

Test { [[
var void* p;
finalize
    p = { NULL };
with
    nothing;
end
return p==null;
]],
    run = 1,
}

Test { [[
var void* p;
p := { NULL };
return p==null;
]],
    run = 1,
}

Test { [[
_f()
]],
    ast = 'line 1 : after `)´ : expected `;´',
}

Test { [[
native _printf();
do
    _printf("oi\n");
end
return 10;
]],
    run = 10;
}

Test { [[
native _V;
native do
    int V[2][2] = { {1, 2}, {3, 4} };
end

_V[0][1] = 5;
return _V[1][0] + _V[0][1];
]],
    run = 8,
}

Test { [[
native _END;
native do
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
native do
end
return 1;
]],
    run = 1,
}

Test { [[
native do
    char* a = "end";
end
return 1;
]],
    run = 1,
}

Test { [[
native do
    /*** END ***/
    char* a = "end";
    /*** END ***/
end
return 1;
]],
    run = 1,
}

Test { [[
native do
    int A () {}
end
A = 1;
return 1;
]],
    ast = 'line 3 : after `end´ : expected statement'
}

Test { [[
native do
    void A (int v) {}
end
return 0;
]],
    run = 0;
}

Test { [[
native do
    int A (int v) {}
end
return 0;
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
return 0;
]],
    env = 'line 5 : native function "_A" is not declared',
}

Test { [[
native _A();
native do
    void A (int v) {}
end
_A();
return 0;
]],
    run = false,
}

Test { [[
native _A();
native do
    void A () {}
end
var int v = _A();
return v;
]],
    run = false,
}

Test { [[emit A => 10; return 0;]],
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
return ret;
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
return _ID(10);
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
return v;
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
return 1;
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
return ret;
]],
    run = false,
}

Test { [[
native do
    void VD (int v) {
    }
end
var void v = _VD(10);
return v;
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
return _NEG(10);
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
return v;
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
return v;
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
return v;
]],
    ana = {
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
return c;
]],
    run = {
        ['10~>A ; 20~>A'] = 10,
        ['3~>A ; 0~>A'] = 3,
    }
}

Test { [[
native nohold _f1(), _f2();
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
return _f2(&v[0],&v[1]) + _f1(v) + _f1(&v[0]);
]],
    run = 39,
}

--[=[

PRE = [[
native do
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
        acc = 2,
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
native do
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
return 0;
]],
    ana = {
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
return 0;
]],
    ana = {
        acc = 1,
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
        --abrt = 1,
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
    --abrt = 1,
    ana = {
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
return a;
]],
    ana = {
        acc = 1,
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
    --abrt = 2,
    ana = {
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
return a+b;
]],
    ana = {
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
return v1 + v2;
]],
    ana = {
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
return v1 + v2;
]],
    ana = {
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
return a+a;
]],
    ana = {
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
return v1+v2;
]],
    ana = {
        acc = 1,
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
        acc = 1,
    },
    run = false,
}

Test { [[
deterministic _printf with _assert;
native do #include <assert.h> end
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
native _a;
native do
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
        acc = 1,
        abrt = 1,
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
    ana = {
        acc = 24,        -- TODO: nao conferi
        isForever = true,
    },
    fin = 'line 4 : call requires `finalize´',
}

Test { [[
native constant _LOW, _HIGH;
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
    ana = {
        acc = 12,
        isForever = true,
    },
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
    ana = {
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
    ana = {
        reachs = 1,
        acc = 3,
        isForever = true,
    },
}

Test { [[
native _F();
deterministic _F with F,G;
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
    ana = {
        acc = 1,
        isForever = true,
    },
}

Test { [[
native _F();
output int* F,G;
deterministic _F with F,G;
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
    ana = {
        acc = 4,
        isForever = true,
    },
}

Test { [[
native _F();
pure _F;
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
    ana = {
        acc = 4,
        isForever = true,
    },
}

Test { [[
native _F();
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
        reachs = 1,
        isForever = true,
    },
}

    -- STRINGS

Test { [[
native _char=1;
var _char* a = "Abcd12" ;
return 1;
]],
    run = 1
}
Test { [[
native _printf();
_printf("END: %s\n", "Abcd12");
return 0;
]],
    run='Abcd12',
}
Test { [[
native _strncpy(), _printf(), _strlen();
return _strlen("123");
]], run=3 }
Test { [[
native _printf();
_printf("END: 1%d\n",2); return 0;]], run=12 }
Test { [[
native _printf();
_printf("END: 1%d%d\n",2,3); return 0;]], run=123 }

Test { [[
native nohold _strncpy(), _printf(), _strlen();
native _char = 1;
var _char[10] str;
_strncpy(str, "123", 4);
_printf("END: %d %s\n", _strlen(str), str);
return 0;
]],
    run = '3 123'
}

Test { [[
native nohold _strncpy(), _printf(), _strlen(), _strcpy();
native _char = 1;
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
native _const_1();
native do
    int const_1 () {
        return 1;
    }
end
return _const_1();
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
return _const_1() + _const_1();
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
return a;
]],
    fin = 'line 8 : call requires `finalize´',
}

Test { [[
native pure _inv();
native do
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
native _id();
native do
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
        acc = 1,
        abrt = 1,
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
return vs.a + vs.b + sizeof(_s);
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
return vs.a + vs.b + sizeof(_s) + sizeof(vs) + sizeof(vs.a);
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
return sizeof<_aaa> + _SZ;
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
return 1;
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
return vs.a;
]],
    ana = {
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
return vs.a;
]],
    ana = {
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
return v.a;
]],
    run = 40,
}

Test { [[
]],
    ana = {
        reachs = 1,
        isForever = true,
    }
}

Test { [[
native _char=1;
var u8[10] v1;
var _char[10] v2;

loop i, 10 do
    v1[i] = i;
    v2[i] = (_char) (i*2);
end

var int ret = 0;
loop i, 10 do
    ret = ret + (u8)v2[i] - v1[i];
end

return ret;
]],
    --loop = 1,
    run = 45,
}

Test { [[
native _message_t = 52;
native _t = sizeof<_message_t, u8>;
return sizeof<_t>;
]],
    todo = 'sizeof',
    run = 53,
}

Test { [[
native _char=1;
var _char a = (_char) 1;
return (int)a;
]],
    run = 1,
}

-- Exps

Test { [[var int a = ]],
    ast = "line 1 : after `=´ : expected expression",
}

Test { [[return]],
    ast = "line 1 : after `return´ : expected expression",
}

Test { [[return()]],
    ast = "line 1 : after `(´ : expected expression",
}

Test { [[return 1+;]],
    ast = "line 1 : before `+´ : expected `;´",
}

Test { [[if then]],
    ast = "line 1 : after `if´ : expected expression",
}

Test { [[b = ;]],
    ast = "line 1 : after `=´ : expected expression",
}


Test { [[


return 1

+


;
]],
    ast = "line 5 : before `+´ : expected `;´"
}

Test { [[
var int a;
a = do
    var int b;
end
]],
    ast = "line 4 : after `end´ : expected `;´",
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
    ana = {
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
    ana = {
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
return a;
]],
    ana = {
        acc = 1,
        abrt = 1,
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
input void A;
pause/if A do
end
return 0;
]],
    ast = 'line 2 : after `pause/if´ : expected expression',
}

Test { [[
event void a;
pause/if a do
end
return 0;
]],
    --env = 'line 2 : event type must be numeric',
    env = 'line 2 : invalid attribution',
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
        emit a => v;
    end
with
    pause/if a do
        var int v = await B;
        return v;
    end
end
]],
    ana = {
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
return ret;
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
event int a, b;
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
        emit a => v;
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
return ret;
]],
    ana = {
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
return ret;
]],
    ana = {
        acc = 1,     -- TODO: 0
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
        emit a => v;
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
var int v = await 1us;
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
        emit a => v;
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
        --['~>1us;1~>A;~>1s;0~>A;~>19us'] = 11,
        --['~>1us;1~>A;~>5us;0~>A;~>5us;1~>A;~>5us;0~>A;~>9us'] = 6,
    },
}

-- TIGHT LOOPS

Test { [[
loop i, 10 do
    i = 0;
end
]],
    env = 'line 2 : read-only variable',
}

Test { [[
native _ret_val, _ret_end;
_ret_val = 1;
_ret_end = 1;
event void e, f;
par do
    loop do
        par/or do
            emit f;         // 18
        with
            await f;        // 20
        end
_ret_val = _ret_val + 5;
        await e;            // 23
    end
with
    loop do
        par/or do
            await f;        // 8
_ret_val = _ret_val + 11;
        with
            emit e;         // 11
            await FOREVER;
        end
    end
end
]],
    ana = {
        isForever = true,
        acc = 3,
    },
    awaits = 0,
    run = 6,
}

Test { [[
native _ret_val, _ret_end;
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
        acc = 3,
    },
    awaits = 0,
    run = 6,
}

Test { [[
native _ret_val, _ret_end;
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
        acc = 2,
    },
    awaits = 0,
    run = 6
}

Test { [[
event void e, k1, k2;
native _ret_val, _ret_end;
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
        acc = 1,
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

native do
    int V = sizeof(CEU_T);
end

native _V;
var T t;
return _V;
]],
    todo = 'recalculate',
    run = 8,    -- 2/2 (trl0) 0 (x) 4 (y)
}

Test { [[
class [10] T with do end
return 1;
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
return _V;
]],
    todo = 'recalculate',
    run = 8,
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
return _V;
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

input void START;
await START;

return x.a;
]],
    run = 10,
}

Test { [[
class T with
    var int a;
do
end
var T x;
    x.a = 30;

return x.a;
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

return x.a + y[0].a + y[1].a;
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

return x.a + y[0].a + y[1].a;
]],
    run = 60,
}

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
    --props = 'line 2 : must be in top-level',
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
    --props = 'line 2 : must be in top-level',
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
    env = 'line 4 : invalid event type',
}

Test { [[
class T with
do
end
var T a = 1;
return 0;
]],
    env = 'line 4 : invalid attribution',
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
    env = 'line 4 : invalid declaration',
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
    env = 'line 5 : variable/event "v" is not declared',
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
    env = 'line 6 : variable/event "b" is not declared',
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
    env = 'line 6 : variable/event "v" is not declared',
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
input void START;
class T with
    var int v;
do
    await FOREVER;
end
var T a;
a.v = 5;
await START;
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
    env = 'line 9 : variable/event "a" is not declared',
}

Test { [[
class T with
    var int v;
    native _f(), _t=10;   // TODO: refuse _t
do
end
return 10;
]],
    run = 10,
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
return _V;
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

input void START;

var T t1;
_V = _V*3;
var T t2;
_V = _V*3;
var T t3;
_V = _V*3;
await START;
return _V;
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
return _V;
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

input void START;
event void a;

var T t1;
var T t2;
emit a;
await START;
return 1;
]],
    run = 1;
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

input void START;

var T t1;
_V = _V*3;
var T t2;
_V = _V*3;
var T t3;
_V = _V*3;
await START;
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
    env = 'line 4 : invalid access',
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
input void START;
await START;
return t.a;
]],
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
return 1;
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
    ast = 'line 3 : before `;´ : expected identifier',
}

Test { [[
var int v;
class T with
    var int v=5;
do
end
var T t;
return t.v;
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
return t.v;
]],
    run = 10,
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
return t.v;
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
return t.v + t.u.x;
]],
    run = 120,
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
input void START, A;
class T with
    var int v;
do
    await START;
    this.v = 5;
end
do
    var T a;
        a.v = 0;
    await A;
    return a.v;
end
]],
    run = { ['~>A']=5} ,
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
        acc = 1,
    },
    run = 9,
}

Test { [[
input void START;
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
        await START;
        emit aa.go => 1;
    with
        await aa.ok;
    end
return aa.aa;
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
return 0;
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
return a;
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
return a+b;
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
return a+b;
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

return 1;
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
input int F;
class T with
    var int v = await F;
do
end
return 0;
]],
    props = 'line 3 : not permitted inside an interface',
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
        await START;
    with
        await FOREVER;
    end
with
    await F;
end
return ret;
]],
    run = {
        ['~>F'] = 10,
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
return _V;
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
    --run = { ['~>1s']=0 },
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
return ret;
]],
    ana = {
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
return a.v;
]],
    ana = {
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
        return aa.v;    // 18
    end
end
]],
    ana = {
        --acc = 2,      -- TODO
        reachs = 1,
    },
}

Test { [[
input void START;
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
    await START;
with
    await aa.ok;
end
return aa.aa;
]],
    run = { ['~>A']=7 },
}

Test { [[
input void START;
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
await START;
return aa.aa;
]],
    ana = {
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
return a;
]],
    run = { ['~>B;~>A']=2 },
}

Test { [[
class T with do end
var T a;
var T* p = a;
]],
    env = 'line 3 : invalid attribution',
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
class T with
do
    var int a = 1;
end
var T[2] ts;
return 1;
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
return ts[0].a + ts[1].a;
]],
    ana = {
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
return t1.a + t2.a;
]],
    run = 30,
}
Test { [[
input void START;
class T with
    var int a;
do
    await START;
    a = 0;
end
var T[2] ts;
await START;
par/and do
    ts[0].a = 10;   // 11
with
    ts[1].a = 20;   // 13
end
return ts[0].a + ts[1].a;
]],
    ana = {
        acc = 1,  -- TODO=5?
    },
    run = 30,
}
Test { [[
input void START;
class T with
    var int a;
do
    await START;
    this.a = 0;
end
var T[2] ts;
await START;
par/and do
    ts[0].a = 10;
with
    ts[1].a = 20;
end
return ts[0].a + ts[1].a;
]],
    ana = {
        acc = 1,    -- TODO: 5?
    },
    run = 30,
}
Test { [[
input void START;
class T with
    var int a;
do
    await START;
    a = 0;
end
var T t1, t2;
await START;
par/and do
    t1.a = 10;
with
    t2.a = 20;
end
return t1.a + t2.a;
]],
    ana = {
        --acc = 8,      -- TODO
    },
    run = 30,
}
Test { [[
input void START;
class T with
    var int a;
do
    await START;
    this.a = 0;
end
var T t1, t2;
await START;
par/and do
    t1.a = 10;
with
    t2.a = 20;
end
return t1.a + t2.a;
]],
    ana = {
        --acc = 8,  -- TODO
    },
    run = 30,
}
Test { [[
input void START;
native nohold _f();
native do
    void f (void* t) {}
end
class T with
do
    await START;
    _f(&this);       // 9
end
var T[2] ts;
await START;
par/and do
    _f(&ts[0]);     // 14
with
    _f(&ts[1]);     // 16
end
return 10;
]],
    ana = {
        acc = 2,
        --acc = 6,    -- TODO: not checked
    },
    run = 10,
}
Test { [[
input void START;
native nohold _f();
native do
    void f (void* t) {}
end
class T with
do
    await START;
    _f(&this);       // 9
end
var T t0,t1;
await START;
par/and do
    _f(&t0);     // 14
with
    _f(&t1);     // 16
end
return 10;
]],
    ana = {
        acc = 1,
        --acc = 9,  -- TODO
    },
    run = 10,
}

Test { [[
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
return 100;
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
    input void START;
    await START;
end
return aa.aa;
]],
    ana = {
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
    input void START;
    await START;
end
return aa.aa;
]],
    run = 5,
}

Test { [[
input void START;

native _inc(), _V;
native do
    int V = 0;
    void inc() { V++; }
end

_inc();
event void x;
emit x;
await START;
return _V;
]],
    run = 1,
}

Test { [[
    input void START;
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
    await START;
    emit aa.a;
    _V = _V+2;
end
return _V + aa.aa + aa.bb;
]],
    run = 11,
}

Test { [[
    input void START;
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
    await START;
    emit aa.a;
    ret = 2;
end
return ret + aa.aa + aa.bb;
]],
    run = 10,
}

Test { [[
input void START;
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
await START;

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
return ret;
]],
    ana = {
        --acc = 1,
    },
    run = { ['~>1s']=1 },
}
Test { [[
native nohold _f();
input void START;
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
    event void ok, go, b;
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
    ret = ret + 1;      // 24
with
        await B;
    emit ptr:e;
    ret = ret + 1;
with
    await ptr:f;
    ret = ret + 1;      // 31
end
return ret + ptr:v + a.v;
]],
    ana = {
        --acc = 3,
    },
    run = { ['~>B']=203, }
}

Test { [[
input void START, B;
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
    ret = ret + 1;              // 42
with
    await ts[1].f;
    ret = ret + 1;              // 45
end
return ret + ts[0].v + ts[1].v;
]],
    ana = {
        --acc = 47,     -- TODO: not checked
        acc = 8,
    },
    run = { ['~>B']=206, }
}

Test { [[
input int S,F;
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
return aa.aa;
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
    ana = {
        acc = 4,
        --acc = 13,     -- TODO: not checked
    },
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
return _V;
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
return _V;
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
    input void START;
    await START;
end
return _V;
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
return _V;
]],
    run = 110,      -- TODO: stack change
}

Test { [[
native _V;
native do
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
    ana = {
        abrt = 1,
    },
    run = 100,
}

Test { [[
native _V;
input void A, F, START;
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
await START;
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
return t.v + _V;        // * reads before
]],
    ana = {
        abrt = 1,        -- false positive
    },
    run = {
        ['~>F'] = 5,
        ['~>A'] = 12,
    }
}

Test { [[
native _V;
input void A, F, START;
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
await START;
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
return ret + _V;        // * reads after
]],
    ana = {
        abrt = 1,        -- false positive
    },
    run = {
        ['~>F'] = 6,
        ['~>A'] = 13,
    }
}

-- KILL THEMSELVES

Test { [[
input void START;

interface Global with
    event void e;
end

event void e;

class T with
do
    await START;
    emit global:e; // TODO: must also check if org trail is active
    native _assert();
    _assert(0);
end

do
    var T t;
    await e;
end
return 2;
]],
    run = 2,
}
Test { [[
input void START;

native _V, _assert();
native do
    #include <assert.h>
    int V = 0;
end

interface Global with
    event void e;
end

event void e;

class T with
do
    await START;
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

return _V;
]],
    run = 2,
}

Test { [[
input void START;

native _V, _assert();
native do
    #include <assert.h>
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
    await START;
    do
        var T t;
        await FOREVER;
    end
end
return _V;
]],
    run = 2;
}

Test { [[
input void START;

native _V, _assert();
native do
    #include <assert.h>
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
    await START;
    do
        var T t;
        _assert(0);
        await FOREVER;
    end
end
return _V;
]],
    run = 2;
}

Test { [[
input void START;

native _X,_V, _assert();
native do
    #include <assert.h>
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
    await START;
    do
        var T[2] t;
        _assert(0);
        await FOREVER;
    end
end
return _V+_X;
]],
    run = 3;
}

Test { [[
input void START;

native _V, _assert();
native do
    #include <assert.h>
    int V = 0;
end

class T with
    var int x;
    event void ok;
do
    await START;
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
return ret;
]],
    run = 10;
}

Test { [[
input void START;

native _V, _assert();
native do
    #include <assert.h>
    int V = 0;
end

class T with
    var int x;
    event void ok;
do
    await START;
    emit  ok;
    _assert(0);
end

class U with
    var int x;
    event void ok;
do
    await START;
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
return ret;
]],
    run = 10;
}

-- NEW / FREE

Test { [[
class T with
    var int a;
do
    this.a = 1;
end
var T* t = new T;
return t:a;
]],
    run = 1,
}

Test { [[
input void START;
class T with
    var int a;
do
    this.a = 1;
end
var T* t = new T;
await START;
return t:a;
]],
    run = 1,
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
input void START;
class T with
    var int a;
do
    this.a = 1;
end
var T* t = new T;
await START;
return t:a;
]],
    run = 1,
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
    ast = 'line 1 : after `<BOF>´ : expected statement',
}
Test { [[
_f(new T);
]],
    ast = 'line 1 : after `(´ : expected `)´',
}

Test { [[
class T with do end
var T* a;
a = new U;
]],
    env = 'line 3 : class "U" is not declared'
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

-- MEM/MEMORY POOL

Test { [[
class [0] T with
    var int a;
do
    this.a = 1;
end
var T* t = new T;
return t == null;
]],
    run = 1,
}

Test { [[
class [1] T with
    var int a;
do
    this.a = 1;
end
var T* a = new T;
var T* b = new T;
return a!=null and b==null;
]],
    run = 1,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
end
var T* t = new [0] T;
return t == null;
]],
    run = 1,
}

Test { [[
class T with
    var int a;
do
    this.a = 1;
end
var T* a = new [1] T;
var T* b = new [0] T;
return a!=null and b==null;
]],
    run = 1,
}

Test { [[
class [1] T with
    var int a;
do
    this.a = 1;
end
var T* a = new T;
free(a);
var T* b = new T;
return a!=null and b!=null;
]],
    run = 1,
}

Test { [[
class [1] T with
    var int a;
do
    this.a = 1;
end
var T* a;
do
    var T* aa = new T;
    finalize
        a = aa;
    with
        nothing;
    end
end
var T* b = new T;
return a!=null and b!=null;
]],
    run = 1,
}

Test { [[
class [1] T with
    var int a;
do
    this.a = 1;
end
var T* a;
do
    var T* aa = new T;
    finalize
        a = aa;
    with
        nothing;
    end
end
var T* b = new T;
return a!=null and b!=null;
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
end
do
    loop i, 1000 do
        var int ok = spawn [1] T;
        if not ok then
            return 0;
        end
    end
end
return _V;
]],
    --loop = 1,
    run = 1000,
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
do
    loop i, 10 do
        spawn [1] T;
    end
end
return _V;
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
do
    loop i, 1000 do
        var int ok = spawn [1] T;
        if not ok then
            return 10;
        end
    end
end
return _V;
]],
    --loop = 1,
    run = { ['~>A']=10 },
}

-- CONSTRUCTOR

Test { [[
var int a with
    nothing;
end;
return 0;
]],
    ast = 'line 1 : after `a´ : expected `;´',
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

return t1.b;
]],
    ast = 'line 8 : after `t2´ : expected `;´',
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

return t[0].b + t[1].b;
]],
    run = 40;
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

return t.b;
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

return t.b;
]],
    run = 20,
}

Test { [[
class T with
    var int a;
    var int b;
do
    b = a * 2;
end

var T* t =
    new T with
        this.a = 10;
    end;

return t:b;
]],
    run = 20,
}

Test { [[
native _V;
native do
    int V=0;
end
input void START;
class T with
do
    par/or do
    with
    end
    _V = _V + 1;
    await START;
    _V = _V + 1;
end
var T* t1 = new T;
var T* t2 = new T;
await START;
return _V;
]],
    --run = 2,  -- blk before org
    run = 4,    -- org before blk
}

-- FREE

Test { [[
class T with do end
var T* a = null;
free a;
return 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T* a = new T;
free a;
return 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T* a = new T;
free a;
var T* b = new T;
free b;
return 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T* a = new T;
var T* b = new T;
free a;
free b;
return 10;
]],
    run = 10,
}

Test { [[
class T with do end
var T* a = new T;
var T* b = new T;
free b;
free a;
return 10;
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

var T* a = new T;
free a;
return _V;
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

var T* a = new T;
var T* b = new T;
free b;
free a;
return _V;
]],
    run = 2,
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
    env = 'line 3 : invalid `free´',
}

-- SPAWN

Test { [[
class T with do end
spawn T;
]],
    env = 'line 2 : `spawn´ requires enclosing `do ... end´',
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
return _V;
]],
    env = 'line 10 : class "U" is not declared',
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
return _V;
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
return _V;
]],
    run = 10,
}

Test { [[
class T with do end
do
    var u8* x = spawn T;
end
]],
    env = 'line 3 : invalid attribution',
}

Test { [[
class T with do end
var u8 ok;
do
    ok = spawn T;
end
return ok;
]],
    run = 1,
}

Test { [[
class T with do
    await FOREVER;
end
var u8 ok;
native _assert();
do
    loop i, 5 do
        ok = spawn T;
    end
end
return ok;
]],
    --loop = 1,
    run = 1,
}

Test { [[
class T with do
    await FOREVER;
end
var u8 ok;
native _assert();
do
    loop i, 100 do
        ok = spawn T;
    end
    ok = spawn T;
end
return ok+1;
]],
    --loop = 1,
    run = 1,
}

Test { [[
class T with do
    await FOREVER;
end
var u8 ok;
native _assert();
do
    loop i, 100 do
        ok = spawn T;
    end
    _assert(ok == 1);
    ok = spawn T;
    ok = spawn T;
    _assert(ok == 0);
end
native __ceu_dyns_;
_assert(__ceu_dyns_ == 0);
do
    loop i, 100 do
        ok = spawn T;
    end
    _assert(ok == 1);
end
do
    loop i, 101 do
        ok = spawn T;
    end
    _assert(ok == 0);
end
return ok;
]],
    --loop = 1,
    run = 0,
}

Test { [[
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
    loop i, 200 do
        var int ok =
            spawn T with
                this.inc = 1;
            end;
        if not ok then
            v = v + 1;
        end
    end

    input void START;
    await START;
end
native _assert();
_assert(_V==100 and v==100);
return _V+v;
]],
    --loop = 1,
    run = 200,
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
return _V;
]],
    run = { ['~>100s']=4 },
}

Test { [[
input void START;
native _V;
native do
    int V = 1;
end
class T with
do
    await START;
    _V = 10;
end
do
    spawn T;
    await START;
end
return _V;
]],
    --run = 1,  -- blk before org
    run = 10,   -- org before blk
}

Test { [[
input void START;
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
    await START;
end
return _V;
]],
    run = 10,
}

Test { [[
class T with do end;
var T a;
var T* b;
b = &a;
return 1;
]],
    run = 1,
    --env = 'line 4 : invalid attribution',
}

Test { [[
class T with do end;
var T* a = new T;
var T* b;
b = a;
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
    fin = 'line 10 : attribution requires `finalize´',
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
    var T* b = new T;
    b:v = 10;
    finalize
        a = b;      // no more :=
    with
        nothing;
    end
end
return _V;
]],
    run = 10,
}

Test { [[
input void START;
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
    var T* b = new T;
    b:v = 10;
    finalize
        a = b;
    with
        nothing;
    end
    await START;
end
return _V;
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
    var T* b = new T;
    b:v = 10;
    finalize
        a = b;      // no more :=
    with
        nothing;
    end
end
return _V;
]],
    run = 10,
}
Test { [[
input void START;
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
    var T* b = new T;
    b:v = 10;
    finalize
        a = b;      // no more :=
    with
        nothing;
    end
    await START;
end
return _V;
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
    fin = 'line 6 : attribution requires `finalize´',
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
    env = 'line 4 : invalid attribution',
}

Test { [[
native _V;
input void START;
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

class V with
do
end

class U with
    var V* v;
do
    var V* vv = new V;
end

class T with
    var U u;
do
end

var T t;
return 1;
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
    //u.v = new V;
    var V* v = new V;
    await FOREVER;
end

var T t;
return _V;
]],
    run = 1,
}

Test { [[
input void START;
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
    var V* vv = new V;
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

return _V;
]],
    run = 3,
}

Test { [[
input void START;
native _f(), _V;
native do
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
    //u.v = new V;
    var V* v = new V;
    await FOREVER;
end

do
    var T t;
end

return _V;
]],
    run = 3,
}

Test { [[
input void START;

class V with
do
end

class U with
do
    var V* vv = new V;
end


var U t;
await START;

native nohold _tceu_trl, _tceu_trl_, _sizeof();
return 2;
]],
    run = 2,
}

Test { [[
input void START;
native _f(), _V;
native do
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
    //u.v = new V;
    var V* v = new V;
    await FOREVER;
end

do
    var T t;
    await START;
end

return _V;
]],
    run = 3,
}

Test { [[
input void START;
native _f(), _V;
native do
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
    //u.v = new V;
    var V* v = new V;
    await FOREVER;
end

var T t;
do
    await START;
    var V* v = t.u.v;   // no more :=
end

return _V;
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
    //u.v = new V;
    var V* v = new V;
    await FOREVER;
end

input void START;

var T t;
do
    var U u;
    u.v = t.u.v;
    await START;
end

return _V;
]],
    run = 2,
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
class V with
do
end

input void START;
class U with
    var V* v;
    event void x;
do
    loop do
        await x;
        v = new V;
        break;
    end
end

class T with
    var U* u;
do
    await START;
    //u:v = new V;
    emit u:x;
end

do
    var U u;
    var T t;
        t.u = &u;
    await START;
end

return 10;
]],
    run = 10,
}
Test { [[
class V with
do
end

input void START;
class U with
    var V* v;
do
end

class T with
    var U* u;
do
    await START;
    u:v = new V;
end

do
    var U u;
    var T t;
        t.u = &u;
    await START;
end

return 10;
]],
    --run = 10,
    env = 'line 15 : invalid attribution',
}
Test { [[
class V with
do
end

input void A, START;
class U with
    var V* v;
do
    await A;
end

class T with
    var U* u;
do
    await START;
    u:v = new V;
end

do
    var U u;
    var T t;
        t.u = &u;
    await START;
end

return 10;
]],
    --run = { ['~>A']=10 },
    env = 'line 16 : invalid attribution',
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
    do              // 26
        var T t;
        t.u = &u;
        await 2s;
    end
    _assert(_V == 10);
end
_assert(_V == 10);
return _V;
]],
    --run = { ['~>2s']=10, }       -- TODO: stack change
    env = 'line 21 : invalid attribution',
}

Test { [[
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
    --loop = true,
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
    --loop = true,
    run = 10;
}
]=]

Test { [[
native _V, _assert();
native do
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
    p:v = 2;
    p = new T;
    p:v = 3;
    input void START;
    await START;
end
_assert(_V == 6);
return _V;
]],
    run = 6,
}

Test { [[
class T with
do
end
var T* t;
t = new T;
return t.v;
]],
    env = 'line 6 : not a struct',
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
        loop i, 5 do
            if i==2 then
                break;
            end
            await 10ms;
        end
    end
    _V = _V + 1;
end

do
    loop i, 10 do
        await 1s;
        spawn T;
    end
    await 5s;
end

return _V;
]],
    run = { ['~>1min']=20 },
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
    var T* ui = new T with
        this.ptr = p;
    end;
end

return 10;
]],
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

var T* ui;
do
    var _s* p = null;
    do
        ui = new T with
            this.ptr = p;
        end;
    end
end

return 10;
]],
    fin = 'line 16 : attribution requires `finalize´',
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
    loop i, 10 do
        var _s* p = null;
        spawn T with
            this.ptr = p;
        end;
        await 1s;
    end
end

return 0;
]],
    fin = 'line 15 : attribution requires `finalize´',
}
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
return _V;
]],
    ana = { acc=1 },
    run = 14,
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

native _V, _assert();
native do
    int V=0;
end

do
    loop i, 10 do
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

return _V;
]],
    fin = 'only empty finalizers inside constructors',
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

native _V, _assert();
native do
    int V=0;
end

var T* ui;
do
    var _s* p = null;
    loop i, 10 do
        ui = new T with
            this.ptr = p;
        end;
        await 1s;
    end
    _assert(_V == 10);
end

return _V;
]],
    fin = 'line 21 : attribution requires `finalize´',
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

native _V, _assert();
native do
    int V=0;
end

var T* ui;
do
    var _s* p = null;
    loop i, 10 do
        ui = new T with
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

return _V;
]],
    fin = 'only empty finalizers inside constructors',
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

native _V, _assert();
native do
    int V=0;
end

do
    loop i, 10 do
        var _s* p = null;
        var T* ui = new T with
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

return _V;
]],
    fin = 'only empty finalizers inside constructors',
    --fin = 'line 21 : invalid `finalize´',
}

-- PAUSE/IF w/ ORGS

Test { [[
input void START;
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
    await START;
    emit a => 1;
    await B;
    emit a => 0;
    await FOREVER;
end
return ret;
]],
    run = { ['10~>A; ~>B; 5~>A'] = 5 },
}

Test { [[
input void A,X, START;
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
    await START;
    emit a => 1;
    await X;
    emit a => 0;
    ret = 10;
    await FOREVER;
end
return ret;
]],
    ana = {
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
        loop i do
            spawn T with
                this.c = i;
            end;
            await 1s;
        end
    end
with
    await 5s;
end

return _V;
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
            loop i do
                spawn T with
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

return _V;
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
    await FOREVER;
end

input int P;
event int pse;

par/or do
    do
        loop i do
            pause/if pse do
                spawn T with
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

return _V;
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
        loop i do
            pause/if pse do
                spawn T with
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

return _V;
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
            loop i do
                spawn T with
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

return _V;
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
        loop i do
            pause/if pse do
                spawn T with
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

return _V;
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
            loop i do
                spawn T with
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

return _V;
]],
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
    var int pse? = 0;
    loop do
        await 1s;
        pse? = not pse?;
        emit a => pse?;
        emit t.a => pse?;
    end
with
    await A;
end
return v;
]],
    ana = { acc=0 },
    run = { ['~>10s;~>A']=10 }
}

-- TODO pause hierarquico dentro de um org
-- SDL/samples/sdl4.ceu

-- INTERFACES / IFACES / IFCES

Test { [[
native _ptr;
native do
    void* ptr;
end
interface I with
    event void e;
end
var J* i = _ptr;
return 10;
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
return 10;
]],
    env = 'line 8 : invalid attribution',
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
return 10;
]],
    run = 10;
}

-- CAST

Test { [[
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

return 10;
]],
    run = 10;
}

Test { [[
input void START;

interface I with
    var int e;
end

class T with
    var int e;
do
    e = 100;
end

var T t;
var I* i = &t;

await START;
return i:e;
]],
    run = 100,
}

Test { [[
input void START;

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
end

var T t;
var I* i = &t;

await START;
emit i:e;
return i:ee;
]],
    run = 100,
}

Test { [[
input void START;

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
end

var T t1;
var I* i1 = &t1;

var int ret = 0;
par/and do
    await START;
    emit i1:e => 99;            // 21
with
    var int v = await i1:f;
    ret = ret + v;
with
    await START;
end
return ret;
]],
    run = 99,
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
    emit f => v;
end

var T t1, t2;
var I* i1 = &t1;
var I* i2 = &t2;

var int ret = 0;
par/and do
    await START;
    emit i1:e => 99;            // 21
with
    var int v = await i1:f;
    ret = ret + v;
with
    await START;
    emit i2:e => 66;            // 27
with
    var int v = await i2:f;
    ret = ret + v;
end
return ret;
]],
    ana = {
        acc = 1,
    },
    run = 165,
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
    env = 'line 3 : cannot instantiate an interface',
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
    emit g:a?  =>  10;
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
    fin = 'line 10 : attribution requires `finalize´'
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
    fin = 'line 6 : attribution requires `finalize´',
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
    fin = 'line 7 : attribution requires `finalize´'
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
    emit global:a  =>  10;
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
await START;
emit a  =>  10;
return t.aa;
]],
    run = 10,
}

Test { [[
interface I with
    var int v;
    native _f(), _a;      // TODO: refuse _a
end
return 10;
]],
    run = 10,
}

Test { [[
class T with
    var int v;
    native nohold _f();
do
    v = 50;
    this._f(10);

    native do
        int CEU_T__f (CEU_T* t, int v) {
            t->v += v;
            return t->v;
        }
    end
end

var T t;
input void START;
await START;
return t.v + t._f(20) + t.v;
]],
    run = 220,
}

Test { [[
interface I with
    var int v;
    native nohold _f();
end

class T with
    var int v;
    native nohold _f();
do
    v = 50;
    this._f(10);

    native do
        void CEU_T__f (CEU_T* t, int v) {
            t->v += v;
        }
    end
end

var T t;
var I* i = &t;
input void START;
await START;
i:_f(100);
return i:v;
]],
    run = 160,
}

Test { [[
interface I with
    var int v;
    native nohold _get();
    native nohold _set();
end

class T with
    var int v = 50;
    native nohold _get();
    native nohold _set();
do
    native do
        int CEU_T__get (CEU_T* t) {
            return t->v;
        }
        void CEU_T__set (CEU_T* t, int v) {
            t->v= v;
        }
    end
end

var T t;
var I* i = &t;
var int v = i:v;
i:_set(100);
return v + i:_get();
]],
    run = 150,
}

Test { [[
interface I with
    var int v;
    native nohold _f();
end

class T with
    var int v;
    native nohold _f();
do
    v = 50;
    this._f(10);

    native do
        void CEU_T__f (CEU_T* t, int v) {
            t->v += v;
        }
    end
end

class U with
    var int v;
    native nohold _f();
do
    v = 50;
    this._f(10);

    native do
        void CEU_U__f (CEU_U* t, int v) {
            t->v += 2*v;
        }
    end
end

var T t;
var U u;
var I* i = &t;
input void START;
await START;
i:_f(100);
var int ret = i:v;

i=&u;
i:_f(200);

return ret + i:v;
]],
    run = 630,
}

Test { [[
class T with
    var int a;
do
    a = global:a;
end
var int a = 10;
var T t;
input void START;
await START;
t.a = t.a + a;
return t.a;
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
input void START;
await START;
    t.a = t.a + a;
    return t.a;
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
input void START;
await START;
    t.a = t.a + a;
    return t.a;
end
]],
    run = 20,
}

Test { [[
native nohold _attr();
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
input void START;
await START;
    t.a = t.a + a;
    return t.a + global:a;
end
]],
    todo = 'IFC accs',
    run = 53,
}

Test { [[
interface I with
    event int a;
end
var I t;
return 10;
]],
    env = 'line 4 : cannot instantiate an interface',
}

Test { [[
interface I with
    event int a;
end
var I[10] t;
return 10;
]],
    env = 'line 4 : cannot instantiate an interface',
}

Test { [[
interface I with
    event int a;
end
var I* t;
t = new I;
return 10;
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
return 10;
]],
    env = 'line 11 : invalid attribution',
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
    env = 'line 12 : invalid attribution',
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
    env = 'line 12 : invalid attribution',
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
    env = 'line 16 : invalid attribution',
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
    env = 'line 20 : invalid attribution',
}

Test { [[
input void START;
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
await START;
return i:aa + j:aa + t.aa;
]],
    run = 30,
}

Test { [[
input void START;
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
    env = 'line 5 : class "J" is not declared',
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
input void START;
await START;
return t.a;
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
return t._ins();
]],
    env = 'line 13 : native function "CEU_T__ins" is not declared',
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
return i:_ins();
]],
    env = 'line 13 : native function "CEU_I__ins" is not declared',
}
Test { [[
interface I with
    var int v;
    native nohold _ins();
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
    env = 'line 14 : native function "CEU_T__ins" is not declared',
}

Test { [[
interface I with
    var int v;
    native nohold _ins();
end

class T with
    var int v;
    native nohold _ins();
do
native do
    int CEU_T__ins (CEU_T* t) {
        return t->v;
    }
end
end

var T t;
    t.v = 10;
var I* i = &t;
return i:_ins() + t._ins();
]],
    run = 20,
}

Test { [[
interface F with
    native nohold _f();
    var int i=10;
end
]],
    env = 'line 3 : invalid attribution',
}

Test { [[
interface F with
    native nohold _f();
    var int i;
end

class T with
    var int i=10;   // 1
    interface F;
do
    this._f(1);
native do
    void CEU_T__f (CEU_T* t, int i) {
        t->i += i;
    }
end
end

var T t1;

var F* f = &t1;
f:_f(3);

return t1.i + f:i;
]],
    run = 28,
}

Test { [[
interface F with
    native nohold _f();
    var int i;
end

class T with
    interface F;
    var int i=10;   // 2
do
    this._f(1);
native do
    void CEU_T__f (CEU_T* t, int i) {
        t->i += i;
    }
end

end

var T t1;

var F* f = &t1;
f:_f(3);

return t1.i + f:i;
]],
    run = 28,
}

Test { [[
class T with do end
class U with
    interface T;
do
end
return 0;
]],
    env = 'line 3 : `T´ is not an interface',
}

-- IFACES / IFCS / ITERATORS
Test { [[
interface I with
end
do
    loop i, I* do
        _f(i);
    end
end
]],
    fin = 'line 5 : call requires `finalize´',
}

Test { [[
interface I with
end
var I* p;
do
    loop i, I* do
        p = i;
    end
end
]],
    fin = 'line 6 : attribution requires `finalize´',
}

Test { [[
interface I with
end
var I* p;
do
    loop i, I* do
        p := i;
    end
end
return 10;
]],
    run = 10;
}

Test { [[
interface I with
end
native nohold _f();
native do
    void f (void* p) {
    }
end
do
    loop i, I* do
        _f(i);
    end
end
return 10;
]],
    run = 10,
}

Test { [[
interface I with
end
native _f();
native do
    void f (void* p) {
    }
end
do
    loop i, I* do
        _f(i) finalize with nothing; end;
    end
end
return 10;
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

var int ret = 0;
do
    spawn T with
        this.v = 1;
    end;
    spawn T with
        this.v = 2;
    end;
    spawn T with
        this.v = 3;
    end;

    loop i, I* do
        ret = ret + i:v;
    end
end
return ret;
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

native pure _f();
native do
    void* f (void* org) {
        return org;
    }
end

var I* i3 = (I*) _f(&t);
var I* i4 = (I*) _f(&u);

var T* i5 = (T*) _f(&t);
var T* i6 = (T*) _f(&u);

return i1==&t and i2==null and i3==&t and i4==null and i5==&t and i6==null;
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
    spawn T with
        this.v = 3;
    end;

    loop i, I* do
        ret = ret + i:v;
    end
end
return ret;
]],
    run = 4,
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

var int ret = 1;
do
    loop i, I* do
        ret = ret + i:v;
    end
end
return ret;
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

native nohold _fprintf(), _stderr;

var int ret = 1;
do
    spawn T with
        this.v = 1;
    end;
    spawn T with
        this.v = 2;
    end;
    spawn T with
        this.v = 3;
    end;

    loop i, I* do
_fprintf(_stderr, "oioioi %p\n", i);
        ret = ret + i:v;
    end
end
return ret;
]],
    run = 1,
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

var int ret = 1;
do
    spawn T with
        this.v = 1;
    end;
    spawn T with
        this.v = 2;
    end;
    spawn T with
        this.v = 3;
    end;

    loop i, I* do
        emit i:inc;
        ret = ret + i:v;
    end
end
return ret;
]],
    run = 10,
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
            loop i, I* do
                emit i:inc;
                ret = ret + i:v;
            end
        end
    end
end
return ret;
]],
    run = { ['~>3s;~>F'] = 9 },
}

-- RET_VAL / RET_END

Test { [[
native _ret_val, _ret_end;
class T with
do
    _ret_val = 10;
    _ret_end = 1;
end
var T a;
await FOREVER;
]],
    ana = {
        isForever = true,
    },
    run = 10,
}

Test { [[
input int A;
native _ret_val, _ret_end;
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
    emit A => 1;
end
await FOREVER;
]],
    ana = {
        isForever = true,
    },
    awaits = 1,
    run = 1,
}

Test { [[
input int A;
native _ret_val, _ret_end;
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
    emit A => 1;
end
await FOREVER;
]],
    ana = {
        isForever = true,
    },
    awaits = 1,
    run = 10,
}

Test { [[
input int A;
native _ret_val, _ret_end;
_ret_val = 10;
class T with
    event int i, x;
    var int ii;
do
    par do
        loop do
            ii = await A;
            ii = ii + 1;
            emit i => ii;
        end
    with
        loop do
            var int v = await x;
            ii = v+1;
            emit i => ii;
        end
    end
end
var T a,b;
par do
    loop do
        var int v = await a.i;
        emit a.x => v;
        _ret_val = _ret_val + a.ii;      // 24
        _ret_end = 1;                   // 25
    end
with
    loop do
        var int v = await b.i;
        emit b.x => v+1;
        _ret_val = _ret_val + b.ii*2;    // 31
        _ret_end = 1;                   // 32
    end
with
    async do
        emit A => 2;
    end
    await FOREVER;
end
]],
    ana = {
        isForever = true,
        acc = 4,
    },
    awaits = 2,
    run = 24,
}

Test { [[
input int A;
native _ret_val, _ret_end;
class T with
    event int i;
do
    loop do
        var int ii = await A;
        emit i => ii+1;
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
        emit A => 2;
    end
    await FOREVER;
end
]],
    ana = {
        isForever = true,
        --acc = 4,
    },
    awaits = 1,
    run = 6,
}

Test { [[
input void A;
native _ret_val, _ret_end;
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
    ana = {
        isForever = true,
        acc = 3,
        abrt = 1,
    },
    run = { ['~>A']=1 },
}

Test { [[
input void START;
event void a;
native _ret_val, _ret_end;
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
    ana = {
        isForever = true,
        acc = 3,
        abrt = 1,
    },
    run = 1,
}

Test { [[
input void A;
native _assert();
native _ret_end, _ret_val;
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
    ana = {
        isForever = true,
        acc = 7,
    },
    awaits = 1,
    run = { ['~>A']=4 };
}

Test { [[
input void A;
native _ret_val, _ret_end;
_ret_val = 0;
loop do
    await A;
    _ret_val = _ret_val+1;
    if _ret_val == 2 then
        _ret_end = 1;
    end
end
]],
    ana = {
        isForever = true,
    },
    awaits = 1,
    run = { ['~>A; ~>A']=2 },
}

-- UNTIL

Test { [[
input int A;
var int x = await A until x>10;
return x;
]],
    run = {
        ['1~>A; 0~>A; 10~>A; 11~>A'] = 11,
    },
}

Test { [[
input int A;
var int v = 0;
par do
    await 10s until v;
    return 10;
with
    await 10min;
    v = 1;
end
]],
    ana = {
        acc = 1,
    },
    run = {
        ['~>10min10s'] = 10,
    },
}

Test { [[
input void START;

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
await START;
return t.x;
]],
    run = 10,
}

-- AWAITS // AWAIT MANY // SELECT

Test { [[
await (10ms);
return 1;
]],
    ast = 'line 1 : after `)´ : expected `or´',
}
Test { [[
await (10ms) or (20ms);
return 1;
]],
    env = 'line 1 : invalid await: multiple timers',
}
Test { [[
await ((10)ms);
return 1;
]],
    ast = 'line 1 : after `)´ : expected `or´',
}

Test { [[
await (e) or
      (f);
return 1;
]],
    env = 'line 1 : variable/event "e" is not declared',
}

Test { [[
event void e;
var int f;
await (e) or
      (f);
return 1;
]],
    env = 'line 3 : event "f" is not declared',
}

--[=[
Test { [[
event void e;
event int f;
input void START;
await (e) or
      (f) or
      (START);
return 1;
]],
    run = 1,
}

Test { [[
input void START;
await (10ms) or (START);
return 1;
]],
    run = 1,
}

Test { [[
input void START;
var int* x = await (10ms) or (START);
return 1;
]],
    env = 'line 2 : invalid attribution',
}

Test { [[
input void START;
par/or do
    loop do
        await (START) or (START);
    end
with
    await START;
end
return 1;
]],
    run = 1,
}

Test { [[
input void START;
await (10ms) or (START)
        until 1;
return 1;
]],
    run = 1,
}

Test { [[
input void START;
var int i = await (10ms) or (START)
        until i==1;
return i;
]],
    run = 1,
}
Test { [[
input void START;
var int i = await (10ms) or (START)
        until i==0;
return i+1;
]],
    run = {['~>10ms']=1},
}
]=]

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
    ana = {
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
    ana = {
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
    ana = {
        isForever = true,
    },
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
    --loop = true,
    run = false,
}

Test { [[
input void A;
loop do
    await A;
end
await FOREVER;
]],
    ana = {
        isForever = true,
    },
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
    ana = {
        isForever = true,
    },
    awaits = 0,     -- stmts
    run = false,
}

Test { [[
input void A,B;
native _ret_val, _ret_end, _assert();
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
    ana = {
        isForever = true,
    },
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
    ana = {
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
    ana = {
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
    ana = {
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
    ana = {
        isForever = true,
    },
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
    ana = {
        isForever = true,
    },
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
    ana = {
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
    ana = {
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
    ana = {
        isForever = true,
    },
    run = false,
    awaits = 2,
}

-- TUPLES

Test { [[
var int a, b;
(a,b) = 1;
return 1;
]],
    ast = 'line 2 : invalid attribution',
}

Test { [[
input (int) A;
return 1;
]],
    run = 1,
}

Test { [[
native _int;
input (_int,int) A;
return 1;
]],
    run = 1;
}

Test { [[
input (int*,int) A;
event (int,int*) a;
return 1;
]],
    run = 1;
}

Test { [[
input (int,int) A;
event (int,int) a;
return 1;
]],
    run = 1;
}

Test { [[
input (int,int) A;
par/or do
    event int a,b;
    (a,b) = await A;
    return 1;
with
    async do
        emit A => (1,2);
    end
end
return 1;
]],
    code = 'line 4 : invalid expression',
}

Test { [[
input (int,int*) A;
par/or do
    var int a,b;
    (a,b) = await A;
    return a + b;
with
    async do
        emit A => (1,2);
    end
end
return 1;
]],
    env = 'line 4 : invalid attribution',
}

Test { [[
input (int,int*) A;
par/or do
    var int a,b;
    (a,b) = await A;
    return a + b;
with
    async do
        var int x = 2;
        emit A=> (1,&x);
    end
end
return 1;
]],
    env = 'line 4 : invalid attribution',
}

Test { [[
input (int,int) A;
par/or do
    var int a,b;
    (a,b) = await A;
    return a + b;
with
    async do
        emit A => (1,2);
    end
end
return 1;
]],
    run = 3;
}

Test { [[
event (int,int) a;
par/or do
    var int a,b;
    (a,b) = await a;
    return a + b;
with
    async do
        emit a => (1,2);
    end
end
return 1;
]],
    env = 'line 4 : event "a" is not declared',
}

Test { [[
event (int,int) a;
input void START;
par/or do
    var int c,d;
    (c,d) = await a;
    return c + d;
with
    await START;
    emit a => (1,2);
end
return 1;
]],
    run = 3,
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
        acc = 18,
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
        acc = 21,
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
        reachs = 1,
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
        reachs = 1,
    },
    tot = 12,
}
]==]
