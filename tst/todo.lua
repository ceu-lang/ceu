----------------------------
-- TODO
----------------------------
do return end

-->> KILL
Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
var Tx a;
var int rrr = 0;
par/and do
    var int v = await a;
    rrr = rrr + v;
with
    kill a => 10;
with
    var int v = await a;
    rrr = rrr + v;
end
escape rrr;
]],
    _ana = { acc=true },
    run = 20,
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
var Tx a;
var int ret = 10;
par/and do
    var int v =
    watching a do
        await FOREVER;
    end;
    ret = v;
with
    kill a => 1;
end
escape ret;
]],
    run = 1,
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    do finalize with
        _V = 10;
    end
    await FOREVER;
end
var Tx&&? t = spawn Tx;
kill *t!;
escape _V;
]],
    run = 10,
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    do finalize with
        _V = 10;
    end
    await FOREVER;
end
var Tx t;
kill t;
escape _V;
]],
    run = 10,
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    do finalize with
        _V = 10;
    end
    await FOREVER;
end
var Tx t;
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
class Tx with
    var int v = 10;
do
    await FOREVER;
end

var Tx&&? t = spawn Tx;
do finalize with
    kill *t!;
end

escape 10;
]],
    props = 'line 9 : not permitted inside `finalize´',
}

Test { [[
class Tx with
    var int v = 10;
do
    await FOREVER;
end

input void OS_START;
event Tx&& e;

var int ret = 1;

par/and do
    await OS_START;
    var Tx&&? t = spawn Tx;
    ret = ret * 2;
    watching *t! do
        emit e(t!);
        ret = ret + t!:v;
        await *t!;
        ret = -1;
    end
    ret = ret * 2;
with
    var Tx&& t1 = await e;
    ret = ret + t1:v;
    kill *t1;
    ret = ret + 1;
end

escape ret;
]],
    tmp = 'line 8 : invalid event type',
    --env = 'line 17 : wrong argument : cannot pass pointers',
    --run = 25,
}

Test { [[
class Tx with
do
    await FOREVER;
end
var int ret = 0;
loop i do
    var Tx t1;
    par/or do
        await t1;
    with
        kill t1;
        await FOREVER;
    end

    var Tx&&? t = spawn Tx;
    par/or do
        await *t!;
    with
        kill *t!;
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
class Tx with
do
end
var int ret = 0;
loop i do
    var Tx t1;
    par/or do
        await t1;
    with
        kill t1;
        await FOREVER;
    end

    var Tx&&? t = spawn Tx;
    par/or do
        if t? then
            await *t!;
        end
    with
        kill *t!;
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
class Tx with
do
    await FOREVER;
end

pool[] Tx ts;

loop t1 in ts do
    loop t2 in ts do
        kill *t1;
        kill *t2;
    end
end

escape 1;
]],
    fin = 'line 10 : unsafe access to pointer "t1" across `loop´ (/tmp/tmp.ceu : 9)',
    --fin = 'line 11 : unsafe access to pointer "t2" across `kill´',
}

Test { [[
class Tx with
do
    await FOREVER;
end

pool[] Tx ts;

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
    fin = ' line 11 : unsafe access to pointer "t1" across `loop´ (/tmp/tmp.ceu : 9)',
}

Test { [[
class Tx with
do
    await FOREVER;
end

pool[] Tx ts;

loop t1 in ts do
    watching *t1 do
        loop t2 in ts do
            watching *t2 do
                kill *t1;
                kill *t2;
            end
        end
    end
end

escape 1;
]],
    props = 'line 8 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = 1,
}

Test { [[
input void OS_START;
event void a;
class Tx with do
    await FOREVER;
end
do
    var Tx t;
    par/or do
        await t;
native _assert;
        _assert(0);
    with
        await OS_START;
    end
    kill t;
end
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;

class Tx with
do
    await FOREVER;
end

var Tx t;
par/or do
    await t;
with
    kill t;
native _assert;
    _assert(0);
end

escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    event void e;
do
    await e;
end

pool[] Tx ts;

var int ret = 1;

spawn Tx in ts;
spawn Tx in ts;
async do end;

loop t1 in ts do
    loop t2 in ts do
        ret = ret + 1;
        kill *t2;
    end
end

escape ret;
]],
    props = 'line 15 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = 3,
}
Test { [[
class Tx with
    event void e;
do
    await e;
end

pool[] Tx ts;

var int ret = 1;

spawn Tx in ts;
spawn Tx in ts;
async do end;

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
    props = 'line 15 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = 3,
}

-- BUG: loop between declaration and watching
Test { [[
class Tx with
    event void e;
do
    await FOREVER;
end

pool[] Tx ts;

var Tx*? t = spawn Tx in ts;

loop do
    watching *t! do
        kill *t!;
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
--<< KILL

-->> CLASS POINTERS
Test { [[
class Tx with
    var int v = 10;
do
end

var Tx t;

code/tight Fx (void)->Tx&& do
    escape &&t;
end

var Tx&& p = call Fx();

escape p:v;
]],
    run = 10,
}
Test { [[
class Tx with
    var int v = 10;
do
end

var Tx t;

code/tight Fx (void)->Tx&& do
    var Tx&& p = &&t;
    escape p;
end

var Tx&& p = call Fx();

escape p:v;
]],
    run = 10,
}
Test { [[
class Tx with
    var int v = 10;
do
end

var Tx t;

code/tight Fx (void)->Tx&& do
    var Tx&& p = &&t;
    escape p;
end

var Tx&& p = call Fx();
await 1s;

escape p:v;
]],
    fin = 'line 16 : unsafe access to pointer "p" across `await´ (/tmp/tmp.ceu : 14)',
}
--<< CLASS POINTERS

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (dynamic var& Aa a, var int xxx) => int do
    escape a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (dynamic var& Aa.Bb b, var int yyy) => int do
    //escape b.b + (call Ff(&b as Aa, 11)) + yyy;
    escape b.b + yyy;
end

var  Aa    a = val Aa(1);
var  Aa.Bb b = val Aa.Bb(2,3);
var& Aa    c = &b;

var int v1 = await/static Ff(&a,1);     // 1+1
var int v2 = await/static Ff(&b,2);     // 3+2
var int v3 = await/static Ff(&c,3);     // 1+3  // err 3+3

escape v1+v2+v3;
]],
    run = 11,
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var& int ret, dynamic var& Aa a, var int xxx) => void do
    ret = ret + a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var& int ret, dynamic var& Aa.Bb b, var int yyy) => void do
    ret = ret + b.b + yyy;
end

var  Aa    a = val Aa(1);
var  Aa.Bb b = val Aa.Bb(2,3);
var& Aa    c = &b;

var int ret = 0;
spawn/static Ff(&ret,&a,1);     // 1+1
spawn/static Ff(&ret,&b,2);     // 3+2
spawn/static Ff(&ret,&c,3);     // 1+3  // err 3+3

escape ret;
]],
    run = 11,
}

Test { [[
data Dd with
    event void ok;      // copy event??
end
var Dd dd = val Dd(_);
var Dd ee = dd;
escape 1;
]],
    run = 'error',
}

Test { [[
data Dd with
    vector[] int x;
end
escape 0;
]],
    dcls = 'line 2 : invalid declaration : not implemented (plain vectors)',
}

Test { [[
data Dd;
data Dd.Ee;

code/tight/dynamic Ff (dynamic var& Dd d) => int do
    escape 10;      // should call this
end
code/tight/dynamic Ff (dynamic var& Dd.Ee e) => int do
    escape 100;     // not this
end

code/tight/dynamic Gg (dynamic var& Dd d) => int do
    escape call/dynamic Ff(&d);
end

var Dd.Ee e = val Dd.Ee();

escape call/dynamic Gg(&e);
]],
    wrn = true,
    run = 10,       -- todo: fragile base problem
}


--[===[
-- TODO: SKIP-01
-->> OPTION / VECTOR

Test { [[
vector[1] int? v;
escape 1;
]],
    wrn = true,
    run = 1,
    --env = 'line 1 : invalid type modifier : `?[]´',
    --adj = 'line 1 : not implemented : `?´ must be last modifier',
}
Test { [[
vector[1] int? v;
escape 1;
]],
    dcls = 'line 1 : vector "v" declared but not used',
    --env = 'line 1 : invalid type modifier : `[]?´',
}
Test { [[
vector[1] int? v;
escape 1;
]],
    wrn = true,
    tmp = 'line 1 : `data´ fields do not support vectors yet',
    --env = 'line 1 : invalid type modifier : `[]?´',
}

Test { [[
data SDL_Color with
    var int v;
end
var SDL_Color clr = val SDL_Color(10);
var SDL_Color? bg_clr = clr;
escape bg_clr!.v;
]],
    run = 10,
}
Test { [[
data SDL_Color with
    var int v;
end
var SDL_Color? bg_clr = val SDL_Color(10);
escape bg_clr!.v;
]],
    run = 10,
}

--<< OPTION / VECTOR
--]===]
-- TODO: SKIP

-- TODO: SKIP-02
--[===[

-->>> INTERFACE / BLOCKI / INPUT / OUTPUT / INPUT/OUTPUT / OUTPUT/INPUT

Test { [[
class Tx with
    output:
        var int o;
do
end
var Tx t with
    this.o  = 1;
end;
escape 1;
]],
    mode = 'line 7 : cannot write to field with mode `output´',
}

Test { [[
class Tx with
    output:
        var int o;
do
end
var Tx t;
t.o = 1;
escape 1;
]],
    mode = 'line 7 : cannot write to field with mode `output´',
}

Test { [[
class Tx with
    input:
        var int i;
do
    i  = 1;
end
escape 1;
]],
    mode = 'line 5 : cannot write to field with mode `input´',
}
Test { [[
class Tx with
    input:
        var int i;
do
    this.i  = 1;
end
escape 1;
]],
    mode = 'line 5 : cannot write to field with mode `input´',
}

Test { [[
code/await Fx (var& int i, var& int io) => (var& int o, var& int oi) => void
do
    var int o_ = 1;
    o  = &o_;
    io = 1;
    oi = &io;
    await FOREVER;
end

watching Fx => (&o, &oi) do

var Tx t with
    this.i  = 1;
    this.io = 1;
    this.oi = 1;
end;
t.i  = 1;
t.io = 1;
t.oi = 1;
escape t.o+t.io+t.oi;
]],
    run = 3,
}
Test { [[
class Tx with
    input:
        var int i;

    output:
        var int o;

    input/output:
        var int io;

    output/input:
        var int oi;
do
    this.o  = 1;
    this.io = 1;
    this.oi = 1;
end
var Tx t with
    this.i  = 1;
    this.io = 1;
    this.oi = 1;
end;
t.i  = 1;
t.io = 1;
t.oi = 1;
escape t.o+t.io+t.oi;
]],
    run = 3,
}

Test { [[
class Tx with
    input/output:
        var& int io;
do
    var int io_ = 1;
    io = &io_;
end
escape 1;
]],
    tmp = 'line 6 : invalid attribution : variable "io" is already bound',
}
Test { [[
class Tx with
    input/output:
        var& int io;
do
    var int io_ = 1;
    this.io = &io_;
end
escape 1;
]],
    tmp = 'line 6 : invalid attribution : variable "io" is already bound',
}

Test { [[
class Tx with
    output/input:
        var& int oi;
do
    var int oi_=0;
    oi = &oi_;
end

var int oi = 1;
var Tx t with
    this.oi = &oi;
end;
escape 1;
]],
    tmp = 'line 11 : invalid attribution : variable "oi" is already bound',
}
Test { [[
class Tx with
    output/input:
        var& int oi;
do
    var int oi_=0;
    this.oi = &oi_;
end

var int oi = 1;
var Tx t with
    this.oi = &oi;
end;
escape 1;
]],
    tmp = 'line 11 : invalid attribution : variable "oi" is already bound',
}

Test { [[
class Tx with
    input:
        var& int i;

    output:
        var& int o;

    input/output:
        var& int io;

    output/input:
        var& int oi;
do
    var int o_  = 1;
    var int io_ = 1;
    var int oi_ = 1;

    o  = &o_;
    oi = &oi_;

    o  = 1;
    io = 1;
    oi = 1;

    if io_ and o and io and oi then end;
    if this.o and this.io and this.oi then end;
end

var int i  = 1;
var int io = 1;
var int oi = 1;
var Tx t with
    this.i  = &i;
    this.io = &io;
end;
t.i  = 1;
t.io = 1;
t.oi = 1;
escape t.o+t.io+t.oi;
]],
    run = 3,
}
Test { [[
class Tx with
    input:
        var& int i;

    output:
        var& int o;

    input/output:
        var& int io;

    output/input:
        var& int oi;
do
    var int o_  = 1; if o_ then end;
    var int io_ = 1; if io_ then end;
    var int oi_ = 1;

    this.o  = &o_;
    this.oi = &oi_;

    this.o  = 1;
    this.io = 1;
    this.oi = 1;
end

var int i  = 1;
var int io = 1;
var int oi = 1;
var Tx t with
    this.i  = &i;
    this.io = &io;
end;
t.i  = 1;
t.io = 1;
t.oi = 1;
escape t.o+t.io+t.oi;
]],
    run = 3,
}

Test { [[
class Tx with
    input:
        var int i=1;

    output:
        var int o=1;

    input/output:
        var int io=1;

    output/input:
        var int oi=1;
do
end
var Tx t with
end;
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    input/output:
        var int io;
do
end
var Tx t with
end;
escape 1;
]],
    tmp = 'line 7 : missing initialization for field "io" (declared in /tmp/tmp.ceu:3)',
}

Test { [[
class Tx with
    input:
        var int i;
do
end
var Tx t with
end;
escape 1;
]],
    tmp = 'line 7 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
}

Test { [[
class Tx with
    input:
        var int i;

    output:
        var int o;

    input/output:
        var int io;

    output/input:
        var int oi;
do
    this.o  = 1;
    this.oi = 1;
end
var Tx t with
    this.i  = 1;
    this.io = 1;
end;
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    input:
        var& int i;
do
end
var Tx t with
end;
escape 1;
]],
    tmp = 'line 7 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
}

Test { [[
class Tx with
    input:
        var& int io;
do
end
var Tx t with
end;
escape 1;
]],
    tmp = 'line 7 : missing initialization for field "io" (declared in /tmp/tmp.ceu:3)',
}

Test { [[
class Tx with
    output:
        var& int o;
do
end
escape 1;
]],
    tmp = 'line 3 : uninitialized variable "o" crossing compound statement (/tmp/tmp.ceu:1)',
}

Test { [[
class Tx with
    output/input:
        var& int oi;
do
end
escape 1;
]],
    tmp = 'line 3 : uninitialized variable "oi" crossing compound statement (/tmp/tmp.ceu:1)',
}

Test { [[
class Tx with
    input:
        var& int i;

    output:
        var& int o;

    input/output:
        var& int io;

    output/input:
        var& int oi;
do
    var int o_ = 1;
    o  = &o_;
    oi = &o_;
end
var int i=0;
var Tx t with
    this.i  = &i;
    this.io = &i;
end;
escape 1;
]],
    run = 1,
}
Test { [[
class Tx with
    input:
        var& int i;

    output:
        var& int o;

    input/output:
        var& int io;

    output/input:
        var& int oi;
do
    var int o_ = 1;
    this.o  = &o_;
    this.oi = &o_;
end
var int i=0;
var Tx t with
    this.i  = &i;
    this.io = &i;
end;
escape 1;
]],
    run = 1,
}

Test { [[
class SDL with
    input:
        var int w;
do
    var int x = w;
    if x!=0 then end
end
escape 1;
]],
    run = 1,
}

Test { [[
class SDL with
    input:
        var int w;
do
native _f;
    _f(this.w);
end
escape 1;
]],
    cc = 'implicit declaration of function ‘f’',
}

Test { [[
class Tx with
    input:
        var int v;
    code/tight Build (var int v)=>Tx;
do
    code/tight Build (var int v)=>Tx do
        this.v = v;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    var int i;
do
end
var Tx t with
    var int i  = this.i;
end;
escape 1;
]],
    tmp = 'line 6 : invalid access to uninitialized variable "i" (declared at /tmp/tmp.ceu:2)',
    --mode = ' line 6 : cannot read field inside the constructor',
}

Test { [[
interface I with
output:
    var& int v;
end

class Bridger with
    var& I i;
do
    var& int v = &this.i.v;
    if v!=0 then end;
end
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    output:
        vector&[] byte name;
do
    vector[] byte name_ = [].."oi";
    this.name = &name_;
    await FOREVER;
end

var Tx t;
native/nohold _strlen;
native _char;
escape _strlen(&&t.name as _char&&);
]],
    run = 2,
}

Test { [[
interface I with
    output:
        vector&[] byte name;
end

class Tx with
    interface I;
do
    vector[] byte name_ = [].."oi";
    this.name = &name_;
    await FOREVER;
end

class U with
    var& Tx t;
do
    vector&[] byte name = &this.t.name;
end

var Tx t;
var U u with
    this.t = &t;
end;

native/nohold _strlen;
native _char;
escape _strlen(&&t.name as _char&&);
]],
    run = 2,
}

Test { [[
output/input/tight LUA_GETGLOBAL  (var int&&, var byte&&)=>void;
code/tight/recursive Load (var int&& l)=>void do
    loop i do
    end
end
call/recursive Load(null);

escape 1;
]],
    wrn = true,
    tight = 'tight loop',
    --run = 1,
}

Test { [[
native _ceu_out_log;
native/pos do
    ##define ceu_out_call_LUA_GETGLOBAL
end

output/input/tight LUA_GETGLOBAL  (var int&&, var byte&&)=>void;
code/tight/recursive Load (var int&& l)=>void do
    // TODO: load file
    call LUA_GETGLOBAL((l, "apps"));              // [ apps ]
    call LUA_GETGLOBAL((l, "apps"));              // [ apps ]
    loop i do
        var int has = 1;
        if has==0 then
            break;                                  // [ apps ]
        end
        _ceu_out_log("oi");
    end

    /*
    var int len = (call LUA_OBJLEN((l, -1)));     // [ apps ]
    loop i in [0->len[ do
        call LUA_RAWGETI((l, -1));                // [ apps | apps[i] ]
    end
    */
end
call/recursive Load(null);

escape 1;
]],
    tight_ = 'line 11 : invalid tight `loop´ :',
    --tight = 'tight loop',
    run = 1,
}

--<<< INTERFACE / BLOCKI / INPUT / OUTPUT / INPUT/OUTPUT / OUTPUT/INPUT

-- TODO: SKIP
--]===]

-- TODO: SKIP-03
--[===[

-->>> CLASSES, ORGS, ORGANISMS

Test { [[
class J with
do
end

class Tx with
do
    var J j;
    await FOREVER;
end

input void OS_START;
event void a;

var Tx t1;
var Tx t2;
emit a;
await OS_START;
escape 1;
]],
    run = 1;
}

Test { [[
class Tx with
    var int x=0;
do
    this.x = await 999ms;
end
var Tx t;
await 1s;
escape t.x;
]],
    run = {['~>1s']=1000},
}

Test { [[
native/pos do
    int V = 10;
end

class Tx with
    event void e;
do
    await 1s;
    emit e;
native _V;
    _V = 1;
end

do
    var Tx t;
    await t.e;
end
await 1s;
escape _V;
]],
    run = { ['~>2s']=10 },
}
Test { [[
class Tx with
do
    native/pos do
        int XXX = sizeof(CEU_T);
    end
end
escape _XXX > 0;
]],
    cc = 'error: ‘CEU_T’ undeclared here (not in a function)',
}

Test { [[
class U with do end;
class Tx with
do
    native/pos do
        int XXX = sizeof(CEU_U);
    end
end
escape _XXX > 0;
]],
    run = 1,
}

Test { [[
native _V;
native/pos do
    int V = 1;
end

class J with
do
    _V = _V * 2;
end

class Tx with
do
    var J j;
    _V = _V + 1;
    await FOREVER;
end

input void OS_START;

var Tx t1;
_V = _V*3;
var Tx t2;
_V = _V*3;
var Tx t3;
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
    a = a + a + 5;
end
escape a;
]],
    wrn = true,
    --env = 'line 4 : invalid access',
    run = 14,
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 8;
    var int a = 1;
    this.a = this.a + a + 5;
end
var Tx t;
input void OS_START;
await OS_START;
escape t.a;
]],
    cc = 'error: duplicate member ‘a’',
    wrn = true,
    --run = 14,
    run = 8,
    --env = 'line 5 : cannot hide at top-level block',
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 8;
    do
        var int a = 1;
        this.a = this.a + a + 5;
    end
end
var Tx t;
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
class Tx with
    var T2 x;
do
end
var Tx a;
escape 1;
]],
    props = 'line 5 : not permitted inside an interface',
}
Test { [[
class T2 with
do
end
class Tx with
    var T2&&? x;
do
    var T2 xx;
    this.x = &&xx;
end
var Tx a;
escape 1;
]],
    run = 1,
}

Test { [[
class Test with
do
end

var Test&&? a = null; // leads to segfault

escape 1;
]],
    run = 1,
}

Test { [[
class T3 with
    var int v3=0;
do
end
class T2 with
    var T3 t3;
    var int v=0;
do
end
class Tx with
    var int v=0,v2=0;
    var T2 x;
do
end
var Tx a;
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
    var int v3=0;
do
    await FOREVER;
end
class T2 with
    var T3&&? t3;
    var int v=0;
do
    var T3 t33;
    this.t3 = &&t33;
    await FOREVER;
end
class Tx with
    var int v=0,v2=0;
    var T2&&? x;
do
    var T2 xx;
    x = &&xx;
    await FOREVER;
end
var Tx a;
a.v = 5;
a.x!:v = 5;
a.v2 = 10;
a.x!:t3!:v3 = 15;
escape a . v + a.x! :v + a .v2 + a.x!  :  t3! : v3;
]],
    run = 35,
}

Test { [[
var int v;
class Tx with
    var int v;
    v = 5;
do
end
]],
    parser = 'line 3 : after `;´ : expected `var´ or `vector´ or `pool´ or `event´ or `code/tight´ or `code/await´ or `interface´ or `input/output´ or `output/input´ or `input´ or `output´ or `do´',
}

Test { [[
var int v=0;
class Tx with
    var int v=5;
do
end
var Tx t;
escape t.v;
]],
    run = 5,
}
Test { [[
//var int v;
class Tx with
    var int v;
do
end
var Tx t;
escape t.v;
]],
    tmp = 'line 6 : missing initialization for field "v" (declared in /tmp/tmp.ceu:3)',
}
Test { [[
//var int v;
class Tx with
    var int v;
do
end
var Tx t with
    this.v = 1;
end;
var Tx x;
escape t.v + x.v;
]],
    tmp = 'line 9 : missing initialization for field "v" (declared in /tmp/tmp.ceu:3)',
}

Test { [[
var int v = 0;
class Tx with
    var int v=5;
do
end
var Tx t with
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
  var Foo&& qux;
do
  await (*qux).bar;
end

escape 1;
]],
    run = 1,
}

Test { [[
var int v = 0;
class Tx with
    var int v=5;
do
    this.v = 100;
end
var Tx t with
    this.v = 10;
end;
escape t.v;
]],
    run = 100,
}

Test { [[

var int v = 0;
class U with
    var int x = 10;
do
end

class Tx with
    var int v=5;
    var U u with
        this.x = 20;
    end;
do
    this.v = 100;
end
var Tx t with
    this.v = 10;
end;
escape t.v + t.u.x;
]],
    props = 'line 10 : not permitted inside an interface',
}

Test { [[
var int v = 0;
class U with
    var int x = 10;
do
end

class Tx with
    var int v=5;
    var U&& u;
do
    var U uu with
        this.x = 20;
    end;
    this.u = &&uu;
    this.v = 100;
end
var Tx t with
    this.v = 10;
end;
escape t.v + t.u:x;
]],
    tmp = 'line 18 : missing initialization for field "u" (declared in /tmp/tmp.ceu:9)',
}
Test { [[
class U with
    var int x = 10;
do
    await FOREVER;
end
var U&&? u;
var U uu with
    this.x = 20;
end;
u = &&uu;
escape u!:x;
]],
    run = 20,
}
Test { [[
class U with
    var int x = 10;
do
    await FOREVER;
end
var U&&? u;
var U uu with
    this.x = 20;
end;
u = &&uu;
escape u!:x;
]],
    run = 20,
}
Test { [[
class U with
    var int x = 10;
do
end
var U&&? u;
var U uu with
    this.x = 20;
end;
u = &&uu;
escape not u?;
]],
    run = 1,
}
Test { [[
var int v = 0;
class U with
    var int x = 10;
do
    await FOREVER;
end

class Tx with
    var int v=5;
    var U&&? u;
do
    var U uu with
        this.x = 20;
    end;
    this.u = &&uu;
    this.v = 100;
    await FOREVER;
end
var Tx t with
    this.v = 10;
end;
escape t.v + t.u!:x;
]],
    run = 120,
}

Test { [[
class Tx with
do
end

var Tx   t;
var Tx&&  p  = &&t;
var Tx&& && pp = &&p;

escape (p==&&t and pp==&&p and *pp==&&t);
]],
    run = 1,
}

Test { [[
var int&& v;
do
    var int i = 1;
    v = &&i;
end
escape *v;
]],
    --fin = 'line 4 : attribution requires `finalize´',
    --fin = 'line 4 : attribution to pointer with greater scope',
    --fins = 'line 1 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:2)',
    scopes = 'line 4 : invalid pointer assignment : expected `finalize´',
}
Test { [[
var& int v;
do
    var int i = 1;
    v = &i;
end
escape v;
]],
    scopes = 'line 4 : invalid binding : incompatible scopes',
    --ref = 'line 4 : attribution to reference with greater scope',
    --ref = 'line 1 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:2)',
    --run = 1,
}

Test { [[
var int i = 0;
class Tx with
    var& int i;
do
    i = 10;
end
var Tx t;
escape i;
]],
    tmp = 'line 7 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
    --ref = 'line 7 : field "i" must be assigned',
    --ref = 'line 5 : invalid attribution (not a reference)',
    --run = 1,
}
Test { [[
var int i = 1;
class Tx with
    var& int i;
do
    var int v = 10;
    i = v;
end
var Tx t;
escape i;
]],
    tmp = 'line 8 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
    --ref = 'line 8 : field "i" must be assigned',
    --ref = 'line 5 : invalid attribution (not a reference)',
    --run = 1,
}
Test { [[
var int i = 1;
class Tx with
    var& int i;
do
    var int v = 10;
    i = v;
end
var Tx t;
escape t.i;
]],
    tmp = 'line 8 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
    --ref = 'line 8 : field "i" must be assigned',
    --ref = 'line 5 : invalid attribution (not a reference)',
    --run = 10,
}
Test { [[
var int i = 0;
class Tx with
    var& int i;
do
    i = 10;
end
spawn Tx;
escape i;
]],
    tmp = 'line 7 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
    --ref = 'line 5 : invalid attribution (not a reference)',
    --ref = 'line 7 : field "i" must be assigned',
    --run = 1,
}
Test { [[
class Tx with
do
end
spawn Tx;
escape 10;
]],
    --ref = 'line 7 : field "i" must be assigned',
    run = 10,
}
Test { [[
var int i = 0;
class Tx with
    var& int i;
do
    var int v = 10;
    i = v;
end
var Tx&&? p = spawn Tx;
escape p!:i;
]],
    tmp = 'line 8 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
    --ref = 'line 8 : field "i" must be assigned',
    --run = 10,
}
Test { [[
var int i = 0;
class Tx with
    var& int i;
do
    var int v = 10;
    i = v;
end
var Tx t with
    this.i = &outer.i;
end;
escape i;
]],
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
    run = 10,
}
Test { [[
var int i = 1;
class Tx with
    var& int i;
    var int v = 10;
do
    v = i;
end
var Tx t with
    this.i = &outer.i;
end;
escape i;
]],
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
    run = 1,
}
Test { [[
input void OS_START;
var int i = 1;
class Tx with
    var& int i;
    var int v = 10;
do
    await OS_START;
    v = i;
end
var Tx t with
    this.i = &outer.i;
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
class Tx with
    var& int i;
do
    var int v = 10;
    i = v;
end
spawn Tx with
    this.i = &outer.i;
end;
escape i;
]],
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
    run = 10,
}

Test { [[
var int i = 1;
class Tx with
    var& int? i;
do
    var int v = 10;
    i! = v;
end

var int ret = 0;

var Tx t1;
ret = ret + i;  // 1
spawn Tx;
ret = ret + i;  // 2

var Tx t2 with
    this.i = &outer.i;
end;
ret = ret + i;  // 12

i = 0;
spawn Tx with
    this.i = &i;
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
class Tx with
    var& int? i;
do
    var int v = 10;
    if i? then
        i! = i! + v;
    end
end

var int ret = 0;

var Tx t1;
ret = ret + i;  // 1    1
spawn Tx;
ret = ret + i;  // 1    2

var Tx t2 with
    this.i = &outer.i;
end;
ret = ret + i;  // 11   13

i = 0;
spawn Tx with
    this.i = &i;
end;
ret = ret + i;  // 10   23

escape ret;
]],
    --ref = 'line 17 : cannot assign to reference bounded inside the class',
    run = 23,
}
Test { [[
var int i = 1;
class Tx with
    var& int? i;
do
    if i? then
    end
end
var Tx t with
    this.i = &outer.i;
end;
escape 1;
]],
    run = 1,
}
Test { [[
var int i = 1;
class Tx with
    var& int? i;
    var int  v = 0;
do
    if i? then
        v = 10;
    end
end

var int ret = 0;

var Tx t1;
ret = ret + i;  // 1
spawn Tx;
ret = ret + i;  // 2

var Tx t2 with
    this.i = &outer.i;
end;
ret = ret + t2.v;  // 12

i = 0;
spawn Tx with
    this.i = &i;
end;
ret = ret + t2.v;  // 22

escape ret;
]],
    run = 22,
}

Test { [[
var int i = 1;
var& int v = i;

class Tx with
    var int&& p = null;
    var& int v = null;
do
end

var Tx t with
    this.p = v;
    this.v = &v;
end;

escape *(t.p) + *(t.v);
]],
    tmp = 'line 6 : types mismatch (`int&´ <= `null&&´)',
}

Test { [[
var int i = 1;
var& int v = &i;

class Tx with
    var int&& p = null;
    var& int v;
do
end

var Tx t with
    this.p = &&v;
    this.v = &v;
end;

escape *(t.p) + (t.v);
]],
    run = 2,
}

Test { [[
var int i = 1;
var& int v = &i;

class Tx with
    var int&& p = null;
    var& int v;
do
    await 1s;
    //v = 1;
    *p = 1;
end

var Tx t with
    this.p := &&v;
    this.v = &v;
end;

escape *(t.p) + (t.v);
]],
    fin = 'line 10 : unsafe access to pointer "p" across `await´',
}

Test { [[
class Tx with
    var _SDL_Rect&& cell_rects = null;
do
    var _SDL_Rect&& cell_rect = &&this.cell_rects[1];
end
escape 1;
]],
    cc = 'error: unknown type name ‘SDL_Rect’',
}

Test { [[
native _BGS;
native/pos do
    int  vs[] = { 1, 2 };
    int* BGS[] = { &vs[0], &vs[1] };
end
escape *_BGS[1];
]],
    run = 2,
}

Test { [[
native _t;
native/pre do
    typedef int* t;
end
var int v = 2;
var _t p;
do p = &&v; finalize(v) with end
escape *p;
]],
    run = 2,
}

Test { [[
native/plain _t;
native/pre do
    typedef int t;
end
var _t v = 2;
escape *v;
]],
    names = 'line 6 : invalid operand to `*´ : expected pointer type',
    --env = 'line 6 : invalid operand to unary "*"',
}

Test { [[
native/plain _rect;
native/pre do
    typedef struct rect {
        int* x, y;
    } rect;
end
var int v = 10;
var _rect r = _rect(&&v);
escape *(r.x);
]],
    names = 'line 9 : invalid operand to `*´ : expected pointer type',
}
Test { [[
native _rect;
native/pre do
    typedef struct rect {
        int* x, y;
    } rect;
end
var int v = 10;
var _rect r = _rect(&&v);
escape *(r.x);
]],
    scopes = 'line 8 : invalid `call´ : expected `finalize´ for variable "v"',
    --fin = 'line 8 : call requires `finalize´',
}
Test { [[
native _rect;
var int v = 10;
var _rect r;
do
    r = _rect(&&v);
finalize with
    nothing;
end
escape 0;
]],
    scopes = 'line 5 : invalid assignment : expected binding for "_rect"',
}
Test { [[
native/plain _rect;
var int v = 10;
var _rect r;
do
    r = _rect(&&v);
finalize
    with nothing; end
escape *(r.x);
]],
    names = 'line 8 : invalid operand to `*´ : expected pointer type : got "_rect"',
}
Test { [[
native/plain _rect;
native/pre do
    typedef struct rect {
        int* x, y;
    } rect;
end
var int v = 10;
var _rect r;
do
    r = _rect(&&v);
finalize(v)
    with nothing; end
escape *(r.x as int&&);
]],
    run = 10,
}
Test { [[
native/plain _rect;
native/pure ___ceu_nothing;
native _V;
native/pre do
    typedef struct rect {
        int* x, y;
    } rect;
    int V = 0;
end
do
    var int v = 10;
    var _rect r;
do r = _rect(&&v); finalize(v) with _V=v; end;
    ___ceu_nothing(&&r);
end
escape _V;
]],
    run = 10,
}

Test { [[
native/plain _t;
var _t t = _;
escape *(t.x);
]],
    names = 'line 3 : invalid operand to `*´ : expected pointer type : got "_t"',
}

Test { [[
native _t;
var _t t = _;
await 1s;
escape *(t.x);
]],
    wrn = true,
    inits = 'line 4 : invalid pointer access : crossed `await´ (/tmp/tmp.ceu:3)',
}

Test { [[
native _t;
var&? _t t;
do
    t = &_t(null);
finalize with
    nothing;
end;
await 1s;
escape *(t.x);
]],
    names = 'line 9 : invalid operand to `.´ : expected plain type : got "_t?"',
    --run = {['~>1s']=10},
}

Test { [[
native/pre do
    typedef struct t {
        int* x;
    } t;
end
native _t;
var int v = 10;
var&? _t t;
do
    t = &_t(&&v);
finalize(t,v) with
    nothing;
end;
await 1s;
escape *(t!.x);
]],
    run = {['~>1s']=10},
}

Test { [[
input void OS_START;
var int v=0;
class Tx with
    var int v=0;
do
    v = 5;
end
var Tx a;
await OS_START;
v = a.v;
a.v = 4;
escape a.v + v;
]],
    run = 9,
}

Test { [[
input void OS_START;
class Tx with
    var int v=0;
do
    this.v = 5;
end
do
    var Tx a;
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
class Tx with
    var int v=0;
do
    await OS_START;
    this.v = 5;
end
do
    var Tx a;
        a.v = 0;
    await A;
    escape a.v;
end
]],
    run = { ['~>A']=5} ,
}

Test { [[
var int sum = 0;
class C with
do
end

par/or do
    loop do
        do
            par/or do
                await FOREVER;
            with
                sum = sum + 1;
                await 1s;
            end
        end
        do
            var C c;
            await 1s;
        end
        // go back to do-end first trail
    end
with
    await 2s;
end
escape sum;
]],
    _ana = {acc=true},
    run = { ['~>10s']=2 },
}

Test { [[
input void OS_START;
class Tx with
    event void go;
    var int v=0;
do
    await go;
    v = 5;
end
do
    var Tx a;
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
class Tx with
    event int a, go, ok;
    var int aa=0;
do
    await go;
    emit a(100);
    aa = 5;
    emit ok(1);
end
var Tx aa;
    par/or do
        await OS_START;
        emit aa.go(1);
    with
        await aa.ok;
    end
escape aa.aa;
]],
    run = 5,
}

-- EMIT / SELF-ABORT
Test { [[
input void KILL;

native/pos do
    int V = 0;
end

class OrgA with
    event void evtA;
    event void evtB;
do
    loop do
        watching evtA do
            loop do
                loop i in [0 -> 3[ do
                    await 1s;
                end
                emit evtB;
native _assert;
                _assert(0);
            end
        end
native _V;
        _V = 10;
    end
end

class OrgB with
do
    var OrgA a;
    
    loop do
        await a.evtB;
        emit a.evtA;
        //_assert(0);
    end
end

var OrgB b;

await KILL;

escape _V;
]],
    run = { ['~>3s;~>KILL']=10 },
}
Test { [[
input void OS_START;
class Tx with
    var int v=0;
do
    v = 5;
end
var Tx a;
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
        class Tx with
        do
            a = 1;
        end
        var Tx v;
    end
    ret = a;
end
escape ret;
]],
    dcls = 'line 7 : internal identifier "a" is not declared',
    --props = 'line 5 : must be in top-level',
}

Test { [[
do
    var int a;
    do
        class Tx with
        do
            a = 1;
        end
    end
end
var Tx v;
emit v.go;
escape 0;
]],
    dcls = 'line 6 : internal identifier "a" is not declared',
    --props = 'line 4 : must be in top-level',
}

Test { [[
var int a;
do
    do
        class Tx with
        do
            a = 1;
            b = 1;
        end
    end
end
var int b;
var Tx v;
emit v.go;
escape a;
]],
    dcls = 'line 6 : internal identifier "a" is not declared',
    --dcls = 'line 6 : internal identifier "b" is not declared',
}

Test { [[
var int a;
var int b;
do
    do
        class Tx with
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
        var Tx v;
        emit v.go;
    end
end
escape a+b;
]],
    dcls = 'line 7 : internal identifier "a" is not declared',
    --props = 'line 5 : must be in top-level',
    --env = 'line 17 : class "Tx" is not declared',
}

Test { [[
var int a;
var int b;
class Tx with
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
        var Tx v;
        emit v.go;
    end
end
escape a+b;
]],
    dcls = 'line 5 : internal identifier "a" is not declared',
    --run = 4,
}

Test { [[
class Sm with
do
    var u8 id = 0;
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
    var u8 id=0;
    if id then end;
end

class Image_media with
    var Sm&& sm=null;
do
    var Sm smm;
    this.sm = &&smm;
end

var Image_media img1;
var Image_media img2;

escape 1;
]],
    run = 1;
}
Test { [[
class Sm with
    var int id=0;
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
    var int id=0;
do
end

class Image_media with
    var Sm&& sm=null;
do
    var Sm smm;
    this.sm = &&smm;
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
    var int id=0;
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
    var int id=0;
do
end

class Image_media with
    var Sm&& sm=null;
do
    var Sm smm;
    this.sm = &&smm;
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
class Tx with
    var int v=0;
do
end

var Tx t;
    t.v = 10;
var Tx&& p = &&t;
escape p:v;
]],
    run = 10,
}

Test { [[
class Tx with
    var int v=0;
do
end

var Tx t1, t2;
t1.v = 1;
t2.v = 2;
escape t1.v+t2.v;
]],
    run = 3,
}

Test { [[
class Tx with
native _char;
    var _char&& ptr;
do
end

var _char&& ptr=null;
var Tx t with
    this.ptr = ptr;
end;
escape 1;
]],
    --gcc = 'may be used uninitialized in this function',
    run = 1,
    --fin = 'line 8 : attribution to pointer with greater scope',
}
Test { [[
class Tx with
native _char;
    var _char&& ptr=null;
do
end

var Tx t with
    do
        var _char&& ptr=null;
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
class Tx with
    event void go;
do
end
var Tx aa;
loop do
    emit aa.go;
end
]],
    run = false,
    _ana = {
        isForever = true,
    },
    loop = true,
}

Test { [[
input void OS_START;
input void A,B;
var int v = 0;
class Tx with
    event void e, ok, go;
do
    await A;
    emit e;
    emit ok;
end
var Tx a;
await OS_START;
par/or do
    loop i in [0 -> 3[ do
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
    await B;
end
escape v;
]],
    run = { ['~>A;~>A;~>A;~>B']=1 },
}

Test { [[
input void OS_START;
input void A,B;
var int v=0;
class Tx with
    event void e, ok;
do
    await A;
    emit e;
    emit ok;
end
var Tx a;
await OS_START;
par/or do
    loop i in [0 -> 3[ do
        par/and do
            await a.e;
            v = v + 1;
        with
            await a.ok;
        end
    end
with
    await B;
end
escape v;
]],
    run = { ['~>A;~>A;~>A;~>B']=1 },
}

Test { [[
input void OS_START;
class Tx with
do
    await FOREVER;
end
await OS_START;
var Tx a;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
input void A,B;
var int v=0;
class Tx with
    event void e;
do
    loop do
        await A;
        emit e;
    end
end
await OS_START;
var Tx a;
par/or do
    loop i in [0 -> 3[ do
        await a.e;
        v = v + 1;
    end
with
    await B;
end
escape v;
]],
    run = { ['~>A;~>A;~>A;~>B']=3 },
}

Test { [[
input void OS_START;
input void A,B;
var int v=0;
class Tx with
    event void e;
do
    loop do
        await A;
        emit e;
    end
end
var Tx a;
await OS_START;
loop i in [0 -> 3[ do
    await a.e;
    v = v + 1;
end
escape v;
]],
    run = { ['~>A;~>A;~>A']=3 },
}

Test { [[
input void OS_START;
class Tx with
    event void go, ok;
do
    await go;
    await 1s;
    emit ok;
end
var Tx aa;
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
class Tx with
    event void go, ok;
do
    await 1s;
    emit ok;
end
end
var Tx aa;
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
input int B;
class Tx with
    var int v = await B;
do
end
escape 0;
]],
    props = 'line 3 : not permitted inside an interface',
}

Test { [[
input void OS_START;
input int B;
do
    class Tx with
        event void ok;
        var int v=0;
    do
        v = await B;
        emit ok;
    end
end
var Tx aa;
par/and do
    await OS_START;
with
    await aa.ok;
end
escape aa.v;
]],
    run = { ['10~>B']=10 },
}

Test { [[
class Tx with
    event void e;
do
end

input void B, OS_START;
var int ret = 0;

var Tx a, b;
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
class Tx with
    event void e;
do
end

input void B, OS_START;
var int ret = 0;

var Tx a, b;
par/or do
    par/and do
        await a.e;
        ret = 2;
    with
        await OS_START;
        emit b.e;
    end
with
    await B;
    ret = 1;
end
escape ret;
]],
    run = { ['~>B']=1 }
}

Test { [[
input void OS_START;
input void B;
class T1 with
    event void ok;
do
    loop do
        await 1s;
        emit this.ok;
    end
end
class Tx with
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
        var Tx aa;
        par/and do
            await OS_START;
        with
            await aa.ok;
        end
    end
    ret = ret + 1;
with
    await B;
end
await B;
escape ret;
]],
    run = {
        --['~>B;~>5s;~>B'] = 10,
        ['~>1s;~>B;~>B;~>1s'] = 10,
        --['~>1s;~>B;~>1s;~>B'] = 10,
        --['~>1s;~>2s;~>B'] = 11,
    },
}

Test { [[
input void OS_START;
input void B;
class T1 with
do
end
class Tx with
do
    var T1 a;
    par/and do
        await FOREVER;
    with
        await FOREVER;
    end
end
var int ret = 10;
var Tx aa;
par/or do
    par/and do
        await OS_START;
    with
        await FOREVER;
    end
with
    await B;
end
escape ret;
]],
    ana = 'line 10 : trail should terminate',
    run = {
        ['~>B'] = 10,
    },
}
Test { [[
input void OS_START;
input void B;
class T1 with
do
end
class Tx with
do
    var T1 a;
    par/and do
        await FOREVER;
    with
        await FOREVER;
    end
end
var int ret = 10;
var Tx aa;
par/or do
    par/and do
        await OS_START;
    with
        await FOREVER;
    end
with
    await B;
end
escape ret;
]],
    wrn = true,
    run = {
        ['~>B'] = 10,
    },
}

Test { [[
input void OS_START;
input void B;
class T1 with
    event void ok;
do
    await 1s;
    emit ok;
    await FOREVER;
end
class Tx with
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
var Tx aa;
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
    await B;
end
await B;
escape ret;
]],
    run = {
        ['~>B;~>5s;~>B'] = 10,
        ['~>1s;~>B;~>B;~>1s'] = 10,
        ['~>1s;~>B;~>1s;~>B'] = 10,
        ['~>1s;~>1s;~>B'] = 11,
    },
}

Test { [[
input void E,B;

class Tx with
do
    await E;
end
var int ret = 10;
par/or do
    var Tx aa;
    await FOREVER;
with
    await B;
    ret = 5;
end
escape ret;
]],
    run = {
        ['~>B;~>E'] = 5,
        ['~>E;~>B'] = 5,
    },
}

Test { [[
input void E,B;

class Tx with
do
    par/or do
        await E;
    with
        await 1s;
    end
end
var int ret = 10;
par/or do
    var Tx aa;
    await FOREVER;
with
    await B;
    ret = 5;
end
escape ret;
]],
    run = {
        ['~>B;~>1s;~>E'] = 5,
        ['~>E;~>1s;~>B'] = 5,
    },
}

Test { [[
input void OS_START;
input void B;
class Tx with
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
        var Tx aa;
        await aa.ok;
    end
    ret = ret + 1;
with
    await B;
end
await B;
escape ret;
]],
    run = {
        --['~>B;~>5s;~>B'] = 10,
        ['~>1s;~>B;~>B;~>1s'] = 10,
        --['~>1s;~>B;~>1s;~>B'] = 10,
        --['~>1s;~>1s;~>B'] = 11,
        --['~>1s;~>E;~>1s;~>B'] = 11,
    },
}

Test { [[
input void OS_START;
input void B;
native _V;
native/pos do
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
class Tx with
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
    var Tx aa;
    await B;
    _V = _V * 2;
end
escape _V;
]],
    run = {
        ['~>B;~>5s;~>B'] = 0,
        ['~>1s;~>B;~>B;~>1s'] = 8,
        ['~>1s;~>B;~>1s;~>B'] = 8,
        ['~>1s;~>1s;~>B'] = 10,
    },
    --run = { ['~>1s']=0 },
}
Test { [[
input void OS_START;
input void B;
class T1 with
    event void ok;
do
    await 1s;
    emit ok;
end
class Tx with
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
        var Tx aa;
        await aa.ok;
    end
    ret = ret + 1;
with
    await B;
end
await B;
escape ret;
]],
    run = {
        ['~>B;~>5s;~>B'] = 10,
        ['~>1s;~>B;~>B;~>1s'] = 10,
        ['~>1s;~>B;~>1s;~>B'] = 10,
        ['~>1s;~>1s;~>B'] = 11,
        ['~>1s;~>E;~>1s;~>B'] = 11,
    },
    --run = { ['~>1s']=0 },
}

Test { [[
input void OS_START;
input void B;
class Tx with
    event void ok;
do
    await 1s;
    emit ok;
end
var Tx aa;
var int ret = 10;
par/or do
    par/and do
        await OS_START;
    with
        await aa.ok;
    end
    ret = ret + 1;
with
    await B;
end
await B;
escape ret;
]],
    run = {
        ['~>1s;~>B'] = 11,
        ['~>B;~>1s;~>B'] = 10,
    },
}

Test { [[
input void OS_START;
input void B;
class Tx with
    event void ok;
do
    loop do
        await 1s;
        emit this.ok;       // 8
    end
end
var Tx aa;
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
    await B;
end
escape ret;
]],
    _ana = {
        --acc = 1,  -- TODO
    },
    run = { ['~>5s;~>B'] = 5 },
}

Test { [[
input void A;
class Tx with
    var int v=0;
do
    await A;
    v = 1;
end
var Tx a;
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
class Tx with
    var int v=0;
    event void ok;
do
    v = 0;
    loop do
        await A;
        v = v + 1;      // 9
    end
end
var Tx aa;
par do
    await aa.ok;
with
    await A;
    if aa.v == 3 then   // 17
        escape aa.v;    // 18
    end
end
]],
    run = false,
    _ana = {
        --acc = 2,      -- TODO
        reachs = 1,
    },
}

Test { [[
input void OS_START;
input void A;
class Tx with
    event int a, ok;
    var int aa=0;
do
    par/or do
        await A;
        emit a(10);
        this.aa = 5;
    with
        aa = await a;
        aa = 7;
    end
    emit ok(1);
end
var Tx aa;
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
class Tx with
    event int a, ok;
    var int aa=0;
do
    par/or do
        await A;
        emit a(10);
        this.aa = 5;
    with
        aa = await a;
        aa = 7;
    end
    emit ok(1);
end
var Tx aa;
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
class Tx with
    event int a;
    var int aa=0;
do
    par/and do
        emit this.a(10); // 6
        aa = 5;
    with
        await a;        // 9
        aa = 7;
    end
end
var Tx aa;
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
    if a!=0 then end;
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
class Tx with do end
var Tx a;
var Tx&& p = a;
]],
    tmp = 'line 3 : types mismatch',
}

Test { [[
class Tx with do end;
do
    var int ret = 1;
    var Tx t;
    escape ret;
end
]],
    run = 1,
}

Test { [[
class Tx with do end;
do
    var Tx t;
    var int ret = 1;
    escape ret;
end
]],
    run = 1,
}

Test { [[
class Tx with do end;
do
    var int a = 1;
    var int&& pa = &&a;
    var Tx t;
    var int ret = *pa;
    escape ret;
end
]],
    run = 1,
}

Test { [[
native _c, _d;
native/pos do
    int c, d;
end

class Tx with
    var int a=0;
do
end

var int i;
i = 10;
var int&& pi = &&i;

var Tx t;
t.a = 10;
var Tx&& p = &&t;
_c = t.a;
_d = p:a;
escape p:a + t.a + _c + _d;
]],
    run = 40,
}

Test { [[
input void A, B;

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
    await A;
with
    async do
        emit B;
        emit 10ms;
        emit A;
    end
end
escape x as int;
]],
    run = 9,
}

Test { [[
class Tx with
    var int a;
do
end

var int i = 1;
vector[2] Tx y with
    this.a = 10*i;
    i = i + 1;
end;

var Tx x with
    this.a = 30;
end;

escape x.a + y[0].a + y[1].a;
]],
    run = 60,
}

Test { [[
class Tx with
    var int a;
do
end

var int i = 0;

vector[2] Tx y with
    i = i + 1;
    this.a = i*10;
end;

var Tx x with
    this.a = 30;
end;

escape x.a + y[0].a + y[1].a;
]],
    run = 60,
}

Test { [[
native/pos do
    int V = 0;
end
native _V;

class Tx with
do
    _V = _V + 1;
end

var Tx ts;

escape _V;
]],
    run = 1,
}

Test { [[
native/pos do
    int V = 0;
end
native _V;
class Tx with
do
    _V = _V + 1;
end

vector[20000] Tx ts;

escape _V;
]],
    run = 20000,
}

Test { [[
class Tx with
do
    class T1 with var int v=0; do end
    var int v=0;
    if v!=0 then end;
end
escape 0;
]],
    run = 0, -- TODO
    --props = 'line 2 : must be in top-level',
}

Test { [[
class Tx with
do
end
vector[5] Tx a;
escape 0;
]],
    run = 0,
}

Test { [[
native/const _U8_MAX;
class Tx with do end;
vector[_U8_MAX] Tx ts;

escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
do
    var int a = 1;
    if a!=0 then end;
end
vector[2] Tx ts;
escape 1;
]],
    run = 1,
}
Test { [[
class Tx with
    var int a=0;
do
end
vector[2] Tx ts;
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
class Tx with
    var int a=0;
do
end
var Tx t1, t2;
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
class Tx with
    var int a=0;
do
    await OS_START;
    a = 0;
end
vector[2] Tx ts;
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
class Tx with
    var int a=0;
do
    await OS_START;
    this.a = 0;
end
vector[2] Tx ts;
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
class Tx with
    var int a=0;
do
    await OS_START;
    a = 0;
end
var Tx t1, t2;
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
class Tx with
    var int a=0;
do
    await OS_START;
    this.a = 0;
end
var Tx t1, t2;
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
native/nohold _f;
native/pos do
    void f (void* t) {}
end
class Tx with
do
    await OS_START;
    _f(&&this);       // 9
end
vector[2] Tx ts;
await OS_START;
par/and do
    _f(&&ts[0]);     // 14
with
    _f(&&ts[1]);     // 16
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
native/nohold _f;
native/pos do
    void f (void* t) {}
end
class Tx with
do
    await OS_START;
    _f(&&this);       // 9
end
var Tx t0,t1;
await OS_START;
par/and do
    _f(&&t0);     // 14
with
    _f(&&t1);     // 16
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
native/pos do ##include <assert.h> end
native _assert;
native _assert;
input int  BUTTON;
input void B;

class Rect with
    var s16 x=0;
    var s16 y=0;
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

vector[2] Rect rs;
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
    await B;
with
    async do
        emit 100ms;
    end
native _assert;
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
escape 100;
]],
    awaits = 0,
    run = 100,
}

Test { [[
class Tx with
    event int a, go, ok;
    var int aa=0;
do
    par/or do
        emit a(10);      // 5
        aa = 5;
    with
        await this.a;   // 8
        aa = 7;
    end
end
var Tx aa;
par/or do
    par/and do
        emit aa.go(1);
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
class Tx with
    event int a, ok, go;
    var int aa=0;
do
    emit a(10);
    aa = 5;
end
var Tx aa;
par/or do
    par/and do
        emit aa.go(1);
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

native _inc, _V;
native/pos do
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

native _inc, _V;
native/pos do
    int V = 0;
    void inc() { V++; }
end

class Tx with
    event void a, ok, go, b;
    var int aa=0, bb=0;
do
    par/and do
        await a;            // 3.
        emit b;             // 4.
    with
        await b;            // 5.
    end
    aa = 5;                 // 6. V=1, aa=5
    bb = 4;                 // 7. V=1, aa=5, bb=4
    emit ok;                // 8.
end

var Tx aa;

_inc();                     // 1. V=1
par/or do
    await aa.ok;            // 9.
    _V = _V+1;              // 10. V=2, aa=5, bb=4
with
    await OS_START;
    emit aa.a;              // 2.
    _V = _V+2;
end
escape _V + aa.aa + aa.bb;
]],
    run = 11,
}

Test { [[
    input void OS_START;
class Tx with
    event void a, ok, go, b;
    var int aa=0, bb=0;
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
var Tx aa;

native _inc, _V;
native/pos do
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
class Tx with
    event void a, ok, go, b;
    var int aa=0, bb=0;
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
var Tx aa;

var int ret=0;
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
class Tx with
    event void e, ok, go;
    var int ee=0;
do
    await this.go;
    if ee == 1 then
        emit this.e;
    end
    await (0)ms;
    emit ok;
end
var Tx a1, a2;
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
native/nohold _f;
input void OS_START;
class Tx with
    event void e, ok, go, b;
    var u8 a=0;
do
    await go;
    a = 1;
    emit ok;
end
var Tx a, b;
native/pos do
    int f (byte* a, byte* b) {
        escape *a + *b;
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
escape _f((&&a.a) as byte&&,(&&b.a) as byte&&);
]],
    run = 2,
}

Test { [[
input void OS_START;
class Tx with
    event void e, f;
do
    await e;
    emit f;
end
vector[2] Tx ts;
par/and do
    await OS_START;
    emit ts[0].e;
    emit ts[1].e;
with
    await ts[1].f;
end
escape 10;
]],
    run = 10,
}

Test { [[
input void OS_START, B;
class Tx with
    var int v=0;
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
vector[2] Tx ts;
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
input void B;
class Tx with
    event void a,ok;
    var int aa=0;
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
var Tx aa;
await aa.ok;
await B;
escape aa.aa;
]],
    run = {
        ['11~>S;~>10s;~>B'] = 11,
        ['~>10s;11~>S;~>B'] = 7,
    },
}

Test { [[
input void OS_START;

class Tx with
    event void ok;
do
    await OS_START;
    emit ok;
end

var int ret = 10;
var Tx t;
await t.ok;

escape ret;
]],
    run = 10,
}

Test { [[
input void OS_START;

class Tx with
    event void ok;
do
    await OS_START;
    emit ok;
end

pool[] Tx ts;
var Tx&&? t1 = spawn Tx in ts;

await t1!:ok;

escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;

class Tx with
    event void ok;
do
    await OS_START;
    emit ok;
end

pool[] Tx ts;
var Tx&&? t1 = spawn Tx in ts;
var Tx&&? t2 = spawn Tx in ts;

par/and do
    await t1!:ok;
with
    await t2!:ok;
end

escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;

class Tx with
do
    await OS_START;
end

pool[] Tx ts;
var Tx&&? t1 = spawn Tx in ts;
var Tx&&? t2 = spawn Tx in ts;

par/and do
    await *t1!;
with
    await *t2!;
end

escape 1;
]],
    _ana = {
        acc = 0,
    },
    run = 1,
}
Test { [[
input void OS_START;

class Tx with
    event void ok;
do
    await OS_START;
    emit ok;
end

var Tx t1, t2;

par/and do
    await t1.ok;
with
    await t2.ok;
end

escape 1;
]],
    _ana = {
        acc = 0,
    },
    run = 1,
}
Test { [[
input void OS_START;

class Tx with
    event void ok;
do
    await OS_START;
    emit ok;
end

vector[2] Tx ts;

par/and do
    await ts[0].ok;
with
    await ts[1].ok;
end

escape 1;
]],
    _ana = {
        acc = 0,
    },
    run = 1,
}

Test { [[
input void OS_START;
class Tx with
    var int v=0;
    event void e, f, ok;
do
    v = 10;
    await e;
    await (0)s;
    emit f;
    v = 100;
    emit ok;
end
vector[2] Tx ts;
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
class Tx with
    var int v=0;
do
    v = 1;
end
var Tx a, b;
await OS_START;
escape a.v + b.v;
]],
    run = 2,
}

Test { [[
input void OS_START;
input void B;
class T1 with
    event void ok;
do
    await 1s;
    emit ok;
end
class Tx with
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
        var Tx aa;
        await aa.ok;
    end
    ret = ret + 1;
with
    await B;
end
await B;
escape ret;
]],
    run = {
        ['~>B;~>5s;~>B'] = 10,
        ['~>1s;~>B;~>B;~>1s'] = 10,
        ['~>1s;~>B;~>1s;~>B'] = 10,
        ['~>1s;~>1s;~>B'] = 11,
    },
}

Test { [[
native _V;
native/pos do
    int V=1;
end

class Tx with
    event void a;
do
    loop do
        await a;
        _V = _V + 1;
    end
end

var Tx t;
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
native/pos do
    static int V = 0;
end
do
    do
        do
            do finalize with
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
native/pos do
    static int V = 0;
end
input void B;
class Tx with
    // nothing
do
    do
        do finalize with
            _V = 100;
        end
        await B;
    end
end
do
    var Tx t;
    input void OS_START;
    await OS_START;
end
escape _V;
]],
    run = 100,
}

Test { [[
native _V;
native/pos do
    static int V = 1;
end
input void B;
class Tx with
do
    _V = 10;
    do
        do finalize with
            _V = _V + 100;
        end
        await B;
    end
end
par/or do
    var Tx t;
    await B;
with
    // nothing;
end
escape _V;
]],
    run = 110,      -- TODO: stack change
}

Test { [[
native _V;
native/pos do
    static int V = 0;
end
input void OS_START;
class Tx with
    // nothing
do
    do
        do finalize with
            _V = 100;
        end
        await OS_START;
    end
end
par/or do
    var Tx t;
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
input void A, B, OS_START;
native/pos do
    int V = 0;
end
class Tx with
    event void e, ok;
    var int v=0;
do
    do finalize with
        _V = _V + 1;        // * writes after
    end
    v = 1;
    await A;
    v = v + 3;
    emit e;
    emit ok;
end
var Tx t;
await OS_START;
par/or do
    do                  // 22
        do finalize with
            _V = _V*10;
        end
        await t.ok;
    end
with
    await t.e;          // 29
    t.v = t.v * 3;
with
    await B;
    t.v = t.v * 5;
end
escape t.v + _V;        // * reads before
]],
    _ana = {
        abrt = 1,        -- false positive
    },
    run = {
        ['~>B'] = 5,
        ['~>A'] = 12,
    }
}

-- internal binding binding
Test { [[
class Tx with
    var& int i;
do
    var int v = 10;
    i = v;
end
var Tx t;
escape t.i;
]],
    tmp = 'line 7 : missing initialization for field "i" (declared in /tmp/tmp.ceu:2)',
    --ref = 'line 7 : field "i" must be assigned',
    --run = 10,
}

-- internal/constr binding
Test { [[
class Tx with
    var& int i;
do
    var int v = 10;
    i = v;
end
var int v = 0;
var Tx t with
    this.i = &v;
end;
escape v;
]],
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
    run = 10;
}
-- internal binding
Test { [[
class Tx with
    var& int i;
do
    var int v = 10;
    i = v;
end
var Tx t;
escape t.i;
]],
    tmp = 'line 7 : missing initialization for field "i" (declared in /tmp/tmp.ceu:2)',
    --ref = 'line 7 : field "i" must be assigned',
    --run = 10,
}
-- internal binding w/ default
Test { [[
class Tx with
    var& int? i;
do
    var int v = 10;
    i! = v;
end
var Tx t;
escape t.i!;
]],
    asr = '5] runtime error: invalid tag',
    --run = 10,
}
-- internal binding w/ default
Test { [[
class Tx with
    var& int? i;
do
native _assert;
    _assert(not i?);
    var int v = 10;
    i! = v;
end
var Tx t;
escape t.i!;
]],
    asr = '6] runtime error: invalid tag',
    --run = 10,
}
-- external binding w/ default
Test { [[
class Tx with
    var& int? i;
do
native _assert;
    _assert(i?);
end
var int i = 10;
var Tx t with
    this.i = &outer.i;
end;
escape t.i!;
]],
    run = 10,
}
Test { [[
class Tx with
    var& int? i;
do
native _assert;
    _assert(not i?);
end
var int i = 10;
var Tx t;
escape not t.i?;
]],
    run = 1,
}

-- no binding
Test { [[
class Tx with
    var& int i;
do
end
var Tx t;
escape 1;
]],
    tmp = 'line 5 : missing initialization for field "i" (declared in /tmp/tmp.ceu:2)',
    --ref = 'line 5 : field "i" must be assigned',
}

Test { [[
class Tx with
    var& int i;
do
end

var int i = 1;

var Tx t1;

var Tx t2 with
    this.i = &outer.i;
end;

escape t1.i;
]],
    tmp = 'line 8 : missing initialization for field "i" (declared in /tmp/tmp.ceu:2)',
    --ref = 'line 8 : field "i" must be assigned',
}

Test { [[
class Tx with
    var& int i;
do
end

var int i = 1;

var Tx t2 with
    this.i = &outer.i;
end;

var Tx t1;

escape t1.i;
]],
    tmp = 'line 12 : missing initialization for field "i" (declared in /tmp/tmp.ceu:2)',
    --ref = 'line 12 : field "i" must be assigned',
}

Test { [[
class Tx with
    var& int i;
do
    var int v = 10;
    i = v;
end
var Tx t;
var int v = 0;
t.i = v;
escape 1;
]],
    tmp = 'line 7 : missing initialization for field "i" (declared in /tmp/tmp.ceu:2)',
    --ref = 'line 9 : cannot assign to reference bounded inside the class',
}

Test { [[
class Integral with
    var&   int v;
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
input (_WorldObjs__LaserExit&&, _FileReader&&) LASEREXIT_NEW;
class LaserExitFactory with
do
    every me_ in LASEREXIT_NEW do
        spawn LaserExit with
            this.me = &_XXX_PTR2REF(me_);
        end;
    end
end

var LaserExitFactory x;
]],
    tmp = 'line 4 : arity mismatch',
}

Test { [[
interface Global with
    var& int v;
end
var int  um = 1;
var& int v;// = um;
escape global:v;
]],
    tmp = 'line 6 : invalid access to uninitialized variable "v" (declared at /tmp/tmp.ceu:2)',
    --ref = 'line 5 : missing initialization for global variable "v"',
    --ref = 'line 5 : global references must be bounded on declaration',
}

Test { [[
interface Global with
    var& int v;
end
var int  um = 1;
var& int v = &um;
escape 1;//global:v;
]],
    run = 1,
}

Test { [[
interface Global with
    var& int v;
end
var int  um = 1;
var& int v = &um;
escape global:v;
]],
    run = 1,
}

Test { [[
interface Global with
    var& int v;
end

var int  um = 111;
var& int v = &um;

class Tx with
    var int v=0;
do
    this.v = global:v;
end

var Tx t;
escape t.v;
]],
    run = 111,
}

Test { [[
interface Global with
end
var& int? win;
if win? then end;
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    var int v = 10;
do
end

interface Global with
    var& Tx t;
end

var Tx t_;
var& Tx t = &t_;

escape global:t.v;
]],
    run = 10,
}
Test { [[
class Tx with
    var int v = 10;
do
end

interface Global with
    var& Tx t;
end

var Tx t_;
var& Tx t = &t_;
global:t = &t;

escape global:t.v;
]],
    tmp = 'line 12 : invalid attribution : variable "t" is already bound',
}

Test { [[
class Tx with
    event void e;
do
end
var Tx t;

class U with
    var& Tx t;
do
    emit t.e;
end

var U u with
    this.t = &t;
end;

escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    var int x=0;
do
end
var Tx t;

class U with
    var& Tx t;
do
    t.x = 1;
end

class V with
    var& U u;
do
    u.t.x = 2;
end

var U u with
    this.t = &t;
end;

var V v with
    this.u = &u;
end;

escape t.x + u.t.x + v.u.t.x;
]],
    run = 6,
}

Test { [[
class Tx with
    var int x=0;
do
end
var Tx t;

class U with
    var& Tx t;
do
    t.x = 1;
end

class V with
    var& U u;
do
    var U&& p = &&u;
    p:t.x = 2;
end

var U u with
    this.t = &t;
end;

var V v with
    this.u = &u;
end;

escape t.x + u.t.x + v.u.t.x;
]],
    run = 6,
}

Test { [[
class Ship with
    var& int v;
do
end

loop do
    var int x = 10;
    var Ship ship1 with
        this.v = &x;
    end;
    escape 1;
end
]],
    wrn = true,
    run = 1,
}

Test { [[
class Tx with
    var& int v;
do
end
var Tx t with
    var int x;
    this.v = &x;
end;
escape 1;
]],
    tmp = 'line 7 : invalid access to uninitialized variable "x" (declared at /tmp/tmp.ceu:6)',
}
Test { [[
class Tx with
    var& int v;
do
end
var Tx t with
    var int x=0;
    this.v = &x;
end;
escape 1;
]],
    tmp = 'line 7 : invalid attribution : variable "x" has narrower scope than its destination',
}

Test { [[
class Test with
    var& u8 v;
do
    var int x = v;
end

var& u8 v;

do Test with
    this.v = &v;
end;

escape 1;
]],
    tmp = 'line 10 : invalid access to uninitialized variable "v" (declared at /tmp/tmp.ceu:7)',
    --ref = 'line 7 : uninitialized variable "v"',
    --run = 1,
}
Test { [[
class Test with
    vector&[10] u8 v;
do
    v = [] .. v .. [4];
end

vector&[10] u8 v; // error: '&' must be deleted

do Test with
    this.v = &v;
end;

escape 1;
]],
    tmp = 'line 10 : invalid access to uninitialized variable "v" (declared at /tmp/tmp.ceu:7)',
    --ref = 'line 7 : uninitialized variable "v"',
    --run = 1,
}
Test { [[
class Tx with
    var& int v;
do
end
var int x = 10;
var Tx t with
    this.v = &x;
end;
x = 11;
escape t.v;
]],
    run = 11;
}

Test { [[
data Vv with
    var int v;
end

class Tx with
    var& Vv v;
do
end

var Tx t1 with
    var Vv v_ = Vv(1);
    this.v = &v_;
end;
var Tx t2 with
    var Vv v_ = Vv(2);
    this.v = &v_;
end;
var Tx t3 with
    var Vv v_ = Vv(3);
    this.v = &v_;
end;

escape t1.v.v + t2.v.v + t3.v.v;
]],
    tmp = 'line 12 : invalid attribution : variable "v_" has narrower scope than its destination',
    --ref = 'line 12 : attribution to reference with greater scope',
    --run = 6,
}

Test { [[
class Tx with
    var& int v;
do
end
var int x = 10;
var Tx t with
    this.v = &x;
end;
var int y = 15;
t.v = y;
y = 100;
escape t.v + x + y;
]],
    run = 130,
}

-- KILL THEMSELVES

Test { [[
native/pos do ##include <assert.h> end
input void OS_START;

interface Global with
    event void e;
end

event void e;

class Tx with
do
    await OS_START;
    emit global:e; // TODO: must also check if org trail is active
    native _assert;
    _assert(0);
end

do
    var Tx t;
    await e;
end
escape 2;
]],
    run = 2,
}
Test { [[
input void OS_START;

native _V, _assert;
native/pos do
    ##include <assert.h>
    int V = 0;
end

interface Global with
    event void e;
end

event void e;

class Tx with
do
    await OS_START;
    emit global:e;
    _V = 1;
    _assert(0);
end

par/or do
    await global:e;
    _V = 2;
with
    var Tx t;
    await FOREVER;
end

escape _V;
]],
    run = 2,
}

Test { [[
input void OS_START;

native _V, _assert;
native/pos do
    ##include <assert.h>
    int V = 0;
end

interface Global with
    event void e;
end

class Tx with
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
        var Tx t;
        await FOREVER;
    end
end
escape _V;
]],
    run = 2;
}

Test { [[
input void OS_START;

native _V, _assert;
native/pos do
    ##include <assert.h>
    int V = 0;
end

interface Global with
    event void e;
end

class Tx with
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
        var Tx t;
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

native _X,_V, _assert;
native/pos do
    ##include <assert.h>
    int V = 0;
    int X = 0;
end

interface Global with
    event void e;
end

class Tx with
do
    _assert(_X==0); // second Tx does not execute
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
        vector[2] Tx t;
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

native _V, _assert;
native/pos do
    ##include <assert.h>
    int V = 0;
end

class Tx with
    var int x;
    event void ok;
do
    await OS_START;
    emit  ok;
    _assert(0);
end

var int ret=1;
do
    var Tx t with
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

native _V, _assert;
native/pos do
    ##include <assert.h>
    int V = 0;
end

class Tx with
    var int x=0;
    event void ok;
do
    await OS_START;
    emit  ok;
    _assert(0);
end

class U with
    var int x=0;
    event void ok;
do
    await OS_START;
    _assert(0);
    emit  ok;
end

var int ret=0;
do
    var Tx t with
        this.x = 10;
    end;
    var Tx u;
    await t.ok;
    ret = t.x;
end
escape ret;
]],
    run = 10;
}

Test { [[
class Tx with
    var int&& a1=null;
do
    var int&& a2=null;
    a1 = a2;
end
escape 10;
]],
    run = 10,
}

Test { [[
native/pure _UI_align;
class Tx with
    var _SDL_rect rect;
do
    do
        native/plain _SDL_Rect;
        var _SDL_Rect r=_SDL_Rect();
        r.x = _N;
    end
end
escape 1;
]],
    --fin = 'line 7 : attribution requires `finalize´',
    cc = 'error: unknown type name ‘SDL_rect’',
}

Test { [[
native/pure _UI_align;
class Tx with
    var _SDL_rect rect;
do
    do
        native/plain _SDL_Rect;
        var _SDL_Rect r=_SDL_Rect();
        r.x = _UI_align(r.w, _UI_ALIGN_CENTER);
    end
end
escape 1;
]],
    --fin = 'line 7 : attribution requires `finalize´',
    cc = 'error: unknown type name ‘SDL_rect’',
}

Test { [[
native/const _UI_ALIGN_CENTER;
native/pure _UI_align;
native/pre do
    typedef struct {
        int x, w;
    } SDL_Rect;
    int UI_ALIGN_CENTER = 1;
    int UI_align (int a, int b) {
        escape 0;
    }
end
class Tx with
    var _SDL_Rect rect;
do
    do
        native/plain _SDL_Rect;
        var _SDL_Rect r=_SDL_Rect();
        r.x = _UI_align(r.w, _UI_ALIGN_CENTER);
    end
    rect.x = 1;
end
escape 1;
]],
    run = 1,
}

Test { [[
native/const _UI_ALIGN_CENTER;
native/pure _UI_align;
native/pre do
    typedef struct {
        int x, w;
    } SDL_Rect;
    int UI_ALIGN_CENTER = 1;
    int UI_align (int a, int b, int c) {
        escape 0;
    }
end
class Tx with
    var _SDL_Rect rect;
do
    do
        native/plain _SDL_Rect;
        var _SDL_Rect r=_SDL_Rect();
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
native/const _UI_ALIGN_CENTER;
native/pure _UI_align;
native/pre do
    typedef struct {
        int x, w;
    } SDL_Rect;
    int UI_ALIGN_CENTER = 1;
    int UI_align (int a, int b, int c) {
        escape 0;
    }
end
class Tx with
    var _SDL_Rect rect;
do
    do
        native/plain _SDL_Rect;
        var _SDL_Rect r=_SDL_Rect();
        r.x = (_UI_align(this.rect.w, r.w, _UI_ALIGN_CENTER) as int);
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
#define N 5
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
end
vector[N] Tx ts;
escape _V;
]],
    run = 5,
}

Test { [[
#define N 5
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
end
vector[N+1] Tx ts;
escape _V;
]],
    run = 6,
}

Test { [[
#define N 5
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
end
vector[N+1] Tx ts;
escape _V;
]],
    run = 6,
}

Test { [[
#define N 5
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
end
#error oi
vector[N+1] Tx ts;
escape _V;
]],
    opts_pre = true,
    pre = 'error oi',
}

Test { [[
input void OS_START;

class Tx with
do
    await OS_START;
end
var Tx t;
await t;

escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    var int size;
    code/tight Run (var int size)=>Tx;
do
    code/tight Run (var int size)=>Tx do
        this.size = size;
    end
    await 1s;
    escape this.size;
end

class U with
do
    do
        var int n = 0;
        do
            var Tx t = Tx.run(4);
            n = await t;
        end
    end
    do
        native/plain _char;
        vector[8] _char v = [];
        var Tx t = Tx.run(2);
        par/or do
            await FOREVER;
        with
            var int n = await t;
native _assert;
            _assert(n == 2);
        end
    end
    escape 0;
end

do U;

escape 1;
]],
    run = { ['~>2s']=1 },
}
Test { [[
class Tx with
    var int size;
    code/tight Run (var int size)=>Tx;
do
    code/tight Run (var int size)=>Tx do
        this.size = size;
    end
    await 1s;
    escape this.size;
end

class U with
do
    do
        var int n = do Tx.run(4);
    end
    do
        native/plain _char;
        vector[8] _char v = [];
        var Tx t = Tx.run(2);
        par/or do
            await FOREVER;
        with
            var int n = await t;
native _assert;
            _assert(n == 2);
        end
    end
    escape 0;
end

do U;

escape 1;
]],
    run = { ['~>2s']=1 },
}


Test { [[
class Tx with
    var int size;
    code/tight Run (var int size)=>Tx;
do
    code/tight Run (var int size)=>Tx do
        this.size = size;
    end
    await 1s;
    escape this.size;
end

class U with
do
    do
        vector[7] byte buf;
        var int n = do Tx.run(4);
    end
    do
        vector[] byte buf;
        var int n = do Tx.run(2);
native _assert;
        _assert(n == 2);
    end

    escape 0;
end

do U;

escape 1;
]],
    run = { ['~>2s']=1 },
}

-- CONSTRUCTOR

Test { [[
var int a with
    nothing;
end;
escape 0;
]],
    parser = 'line 1 : after `a´ : expected `=´ or `,´ or `;´',
    --env = 'line 1 : invalid type',
}

Test { [[
class Tx with
    var int a;
    var int b;
do
    b = a * 2;
end

var Tx t1, t2 with
    this.a = 10;
end;

escape t1.b;
]],
    parser = 'line 8 : after `t2´ : expected `=´ or `,´ or `;´',
}

Test { [[
class Tx with
    var int a;
    var int b=0;
do
    b = a * 2;
end

vector[2] Tx t with
    this.a = 10;
end;

escape t[0].b + t[1].b;
]],
    run = 40;
}

Test { [[
native _f;
_f(outer);
]],
    todo = 'remove',
    props = 'line 1 : `outer´ can only be unsed inside constructors',
}

Test { [[
interface I with
end

class U with
    var I&& i;
do
end

class Tx with
    var int ret = 0;
do
    var U u with
        this.i = &&outer;
    end;
    this.ret = u.i == &&this;
end

var Tx t;

escape t.ret;
]],
    run = 1,
}

Test { [[
class Tx with
    var int a=0;
    var int b=0;
do
    b = a * 2;
end

var Tx t with
    await 1s;
end;

escape t.b;
]],
    props = 'line 9 : not permitted inside a constructor',
}

Test { [[
class Tx with
    var int a;
    var int b=0;
do
    b = a * 2;
end

var Tx t with
    this.a = 10;
end;

escape t.b;
]],
    run = 20,
}

Test { [[
class Tx with
    var int v;
do end;
var Tx _ with
    this.v = 1;
end;
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    void* Ptr;
    void* myalloc (void) {
        escape NULL;
    }
    void myfree (void* ptr) {
    }
end
native/nohold _myfree;

class Tx with
    var int x = 10;
do
native _myalloc;
    do _PTR = _myalloc();
    finalize with
        _myfree(_PTR);
    end
end
var Tx t;
escape t.x;
]],
    fin = 'line 15 : cannot finalize a variable defined in another class',
}

Test { [[
native/pos do
    int V;
    void* myalloc (void) {
        escape &V;
    }
    void myfree (void* ptr) {
    }
end
native/nohold _myfree;

class Tx with
    var int x = 10;
do
    var& void? ptr;
native _myalloc;
    do    ptr = &_myalloc();
    finalize with
        _myfree(&&ptr);
    end
end
var Tx t;
escape t.x;
]],
    exps = 'line 18 : invalid operand to unary "&&" : option type',
}

Test { [[
native/pos do
    int V;
    void* myalloc (void) {
        escape &V;
    }
    void myfree (void* ptr) {
    }
end
native/nohold _myfree;

class Tx with
    var int x = 10;
do
    var& void? ptr;
native _myalloc;
        do ptr = &_myalloc();
    finalize with
        _myfree(&&ptr!);
    end
end
var Tx t;
escape t.x;
]],
    run = 10,
}

-- TODO: bounded loop on finally

-->>> GLOBAL-DO-END / DO-PRE

Test { [[
var int tot = 1;                // 1

pre do
    tot = tot + 2;              // 3
end

tot = tot * 2;                  // 6

escape tot;
]],
    dcls = 'line 4 : internal identifier "tot" is not declared',
}

Test { [[
pre do
    var int tot = 1;                // 1

    tot = tot + 2;              // 3
end

tot = tot * 2;                  // 6

escape tot;
]],
    run = 6
}

Test { [[
pre do
    var int tot = 1;                // 1

    tot = tot + 2;              // 3
end

class Tx with
do
    pre do
        tot = tot * 2;          // 6
        var int tot2 = 10;
    end
end

tot = tot + tot2;               // 16

pre do
    tot = tot + tot2;           // 26
end

escape tot;
]],
    run = 26,
}

Test { [[
pre do
var int tot = 1;                // 1
var int tot2;

    tot = tot + 2;              // 3
end

class Tx with
do
pre do
        tot = tot * 2;          // 6
        tot2 = 10;
    end
end

tot = tot + tot2;               // 16

pre do
    tot = tot + tot2;           // 26
end

escape tot;
]],
    run = 26
}

Test { [[
pre do
var int tot = 1;                // 1
var int tot2 = 1;                       // 1

    tot = tot + 2;              // 3
end

class Tx with
do
    class U with
    do
pre do
            tot = tot + 1;      // 4
            tot = tot + tot2;   // 5
        end
    end

pre do
        tot = tot * 2;          // 10
        tot2 = tot2+9;                  // 10
    end

    class V with
    do
pre do
            tot = tot + 5;      // 15
        end
    end
end

tot = tot + tot2;               // 30

pre do
    tot = tot + tot2;           // 25
    tot2 = tot2 / 2;                    // 5
end

tot2 = tot2 - 4;                        // 1

escape tot + tot2;              // 31
]],
    run = 31
}

--<<< GLOBAL-DO-END / DO-PRE

-->>> SPAWN

Test { [[
class Tx with do end
spawn Tx;
escape 1;
]],
    --env = 'line 2 : `spawn´ requires enclosing `do ... end´',
    run = 1,
}

Test { [[
native _V;
native/pos do
    int V = 0;
end
class Tx with
do
    _V = 10;
end
do
    spawn U;
end
escape _V;
]],
    tmp = 'line 10 : undeclared type `U´',
}

Test { [[
native _V;
native/pos do
    int V = 0;
end
class Tx with
do
    _V = 10;
end
do
    spawn Tx;
end
escape _V;
]],
    run = 10,
}

Test { [[
native _V;
native/pos do
    int V = 0;
end
class Tx with
    var int a;
do
    _V = this.a;
end
do
    spawn Tx with
        this.a = 10;
    end;
end
escape _V;
]],
    run = 10,
}

Test { [[
class Tx with do end
do
    var u8? x = spawn Tx;
end
]],
    tmp = 'line 3 : types mismatch',
}

Test { [[
class Tx with do end
code/tight Fff (void)=>void do
    spawn Tx;
end
escape 1;
]],
    props = 'line 3 : not permitted inside `function´',
}

Test { [[
class Tx with
    var int v=0;
do
end

input int E;

par/or do
    var int yyy=0;
    every xxx in E do
        spawn Tx with
            yyy = 1;
            xxx = 1;
        end;
    end;
with
end

escape 1;
]],
    run = 1,
}

Test { [[
event void e;

class Tx with do end;

par/or do
    every e do
        spawn Tx;
    end
with
    emit e;
end

escape 1;
]],
    _ana = {acc=1},
    run = 1, -- had stack overflow
}

Test { [[
event void x,e,f,g;
var int ret = 0;
class Tx with do end;
par/or do
    every x do
        loop i in [0 -> 1000[ do
            emit e;
        end
    end
with
    every e do
        emit f;
    end
with
    every f do
        emit g;
    end
with
    every g do
        ret = ret + 1;
        spawn Tx;
    end
with
    emit x;
end
escape ret;
]],
    _ana = {acc=1},
    run = 1000, -- had stack overflow
}

Test { [[
class Groundpiece with
do
end

event void x;
event void a;
event void b;
event void c;
var int ret = 0;

par/or do
    every x do
        emit b;
        ret = 10;
    end
with
    every b do
        emit a;
    end
with
    every c do
        spawn Groundpiece;
    end
with
    emit x;
end

input void OS_START;
await OS_START;
escape ret;
]],
    _ana = {acc=true},
    run = 10,
}

--<<< SPAWN

-- MEM/MEMORY POOL

Test { [[
class Tx with
do
end
pool Tx t;
escape 1;
]],
    parser = 'line 4 : after `pool´ : expected `&´ or `[´',
    --env = 'line 4 : missing `pool´ dimension',
    --parser = 'line 4 : after `Tx´ : expected `[´',
}

Test { [[
class Org with
do
end

var int n = 5;
pool[n] Org a;

escape 1;
]],
    consts = 'line 6 : dimension must be constant',
}

Test { [[
class Tx with do end
pool[] Tx ts;
var Tx t;
ts = t;
escape 1;
]],
    tmp = 'line 4 : types mismatch',
}

Test { [[
class Tx with
do
end
pool[] Tx t;
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
do
end
pool[1] Tx t;
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with do end
pool[0] Tx ts;
var Tx&&? ok = spawn Tx in ts;
if ok? then
    escape 0;
else
    escape 1;
end
]],
    run = 1,
}

Test { [[
class Tx with
do
end
pool[1] Tx t;
var Tx&&? ok1 = spawn Tx in t with end;
var Tx&&? ok2 = spawn Tx in t;
escape (ok1?) + (ok2?) + 1;
]],
    run = 1,
    --fin = 'line 7 : unsafe access to pointer "ok1" across `spawn´',
}

Test { [[
class Tx with
do
end
pool[1] Tx t;
var Tx&&? ok1 = spawn Tx in t with end;
var int sum = 1;
if ok1? then
    watching *(ok1!) do
        var Tx&&? ok2 = spawn Tx in t;
        sum = sum + (ok1?) + (ok2?);
    end
end
escape sum;
]],
    run = 1,
}
-- TODO: SKIP
--]===]

--[===[ -- TODO: SKIP-04

-- nao suporto
-- spawn Tx() => (x1) in ts;
-- eh para suportar?
Test { [[
input void OS_START;

code/await Ux (void)=>void
do
    await 1us;
end

code/await Tx (void)=>(var&? int x)=>void
do
    var int v = 10;
    x = &v;
    await Ux();
end

pool[] Tx ts;

spawn Tx() in ts;

var&? int x1;
spawn Tx() => (x1) in ts;
await x1;

var&? int x2;
spawn Tx() => (x2) in ts;
await x1;

escape 1;
]],
    run = { ['~>2us']=1 },
}

Test { [[
pool[0] Tx ts;
class Tx with
    var int a;
do
    this.a = 1;
end
var Tx&&? t = spawn Tx in ts;
escape not t?;
]],
    tmp = 'line 1 : undeclared type `Tx´',
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
end
pool[0] Tx ts;
var Tx&&? t = spawn Tx in ts;
escape not t?;
]],
    run = 1,
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&&? a = spawn Tx in ts;
var int sum = 0;
watching *(a!) do
    var Tx&&? b = spawn Tx in ts;
    sum = a? and (not b?);
end
escape sum;
]],
    run = 1,
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&&? a = spawn Tx in ts;
var int sum = 0;
watching *(a!) do
    var Tx&&? b = spawn Tx in ts;
    sum = a? and (not b?);
end
escape sum;
]],
    run = 1,
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
do
pool[0] Tx ts;
var Tx&&? t = spawn Tx in ts;
escape not t?;
end
]],
    run = 1,
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx aas;
pool[0] Tx bs;
var Tx&&? a = spawn Tx in aas;
var int sum = 0;
if a? then
    watching *a! do
        var Tx&&? b = spawn Tx in bs;
        sum = a? and (not b?);
    end
end
escape sum;
]],
    run = 1,
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&&? a = spawn Tx in ts;
//free(a);
var int sum = 0;
if a? then
    watching *a! do
        var Tx&&? b = spawn Tx in ts;   // fails (a is freed on end)
        sum = a? and (not b?);
    end
end
escape sum;
]],
    run = 1,
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&& a = null;
do
    var Tx&&? aa = spawn Tx in ts;
        a = aa!;
end
var int sum = 0;
if a != null then
    watching *a do
        var Tx&&? b = spawn Tx in ts;   // fails (a is free on end)
        sum = a!=null and (not b?) and a!=b!;
    end
end
escape sum;
]],
    fin = 'line 14 : unsafe access to pointer "a" across `spawn´ (/tmp/tmp.ceu : 10)',
    --fin = 'line 15 : pointer access across `await´',
    --asr = ':15] runtime error: invalid tag',
    --run = 1,
}
Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[2] Tx ts;
var Tx&& a = null;
do
    var Tx&&? aa = spawn Tx in ts;
        a = aa!;
end
watching *a do
end
escape 0;
]],
    fin = 'line 13 : unsafe access to pointer "a" across `spawn´ (/tmp/tmp.ceu : 10)',
    --fin = 'line 15 : pointer access across `await´',
    --run = 1,
}
Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[2] Tx ts;
var Tx&& a = null;
do
    var Tx&&? aa = spawn Tx in ts;
        a = aa!;
end
var int sum = 0;
if a != null then
    watching *a do
        var Tx&&? b = spawn Tx in ts;   // fails (a is free on end)
        sum = a!=null and (b?) and a!=b!;
    end
end
escape sum;
]],
    fin = 'line 14 : unsafe access to pointer "a" across `spawn´ (/tmp/tmp.ceu : 10)',
    --fin = 'line 15 : pointer access across `await´',
    --run = 1,
}
Test { [[
class Tx with
do
end
do
    var Tx&&? aa = spawn Tx;
end
par/or do
with
end
escape 1;
]],
    --fin = 'line 15 : pointer access across `await´',
    run = 1,
}
Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&&? a;
do
    var Tx&&? aa = spawn Tx in ts;
        a = aa;
end
var int sum = 0;
if a? then
    watching *a! do
        var Tx&&? b = spawn Tx in ts;   // fails (a is free on end)
        sum = a? and (not b?);// and a! !=b;
    end
end
escape sum;
]],
    --fin = 'line 15 : pointer access across `await´',
    run = 1,
}
Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&& a=null;
do
    var Tx&&? aa = spawn Tx in ts;
        a = aa!;
end
var Tx&&? b = spawn Tx in ts;   // fails (a is free on end)
escape (not b?);
]],
    run = 1,
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&& a=null, b=null;
var int sum = 0;
do
    do
        var Tx&&? aa = spawn Tx in ts;
            a = aa!;
    end
    sum = a!=null;
    var Tx&&? bb = spawn Tx in ts;  // fails
        b = bb!;
end
if b != null then
    watching *b do
        var Tx&&? c = spawn Tx in ts;       // fails
        sum = (b==null) and (not c?);// and a!=b and b==c;
    end
end
escape sum;
]],
    fin = 'line 15 : unsafe access to pointer "a" across `spawn´ (/tmp/tmp.ceu : 12)',
    --asr = ':14] runtime error: invalid tag',
    --fin = 'line 19 : pointer access across `await´',
    --run = 1,
}
Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&&? a, b;
var int sum = 0;
do
    do
        var Tx&&? aa = spawn Tx in ts;
            a = aa!;
    end
    sum = a?;
    var Tx&&? bb = spawn Tx in ts;  // fails
        b = bb;
    sum = sum and (not b?);
end
var Tx&&? c = spawn Tx in ts;       // fails
escape sum and (not c?);
]],
    --fin = 'line 19 : pointer access across `await´',
    run = 1,
}
Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&&? a, b;
var bool b_=true;
do
    do
        var Tx&&? aa = spawn Tx in ts;
            a = aa!;
    end
    var Tx&&? bb = spawn Tx in ts;  // fails
    b_ = (bb?);
end
var Tx&&? c = spawn Tx in ts;       // fails
//native/nohold _fprintf(), _stderr;
        //_fprintf(_stderr, "%p %p\n",a, b);
escape b_==false and (not c?);
]],
    run = 1,
}

Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&&? a;
var int sum = 0;
do
    var Tx&&? aa = spawn Tx in ts;
        a = aa!;
    sum = a?;
end
var Tx&&? b = spawn Tx in ts;   // fails
escape sum and (not b?);
]],
    --fin = 'line 13 : pointer access across `await´',
    run = 1,
}
Test { [[
class Tx with
    var int a=0;
do
    this.a = 1;
    await FOREVER;
end
pool[1] Tx ts;
var Tx&& a=null;
do
    var Tx&&? aa = spawn Tx in ts;
        a = aa!;
end
var Tx&&? b = spawn Tx in ts;   // fails
escape (not b?);
]],
    run = 1,
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
    await FOREVER;
end
pool[1] Tx ts;
do
    loop i in [0 -> 2[ do
        spawn Tx in ts;
    end
    loop i in [0 -> 2[ do
        spawn Tx;
    end
end
escape _V;
]],
    run = 3,
}
Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
    await FOREVER;
end
pool[1] Tx ts;
do
    loop i in [0 -> 2[ do
        spawn Tx in ts;
    end
    loop i in [0 -> 2[ do
        spawn Tx;
    end
end
escape _V;
]],
    run = 3,
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
end
do
    pool[1] Tx ts;
    loop i in [0 -> 1000[ do
        var Tx&&? ok = spawn Tx in ts;  // 999 fails
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
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
    await A;
end
pool[1] Tx ts;
do
    loop i in [0 -> 10[ do
        spawn Tx in ts;
    end
end
escape _V;
]],
    --loop = 1,
    run = { ['~>A']=1 },
}
Test { [[
input void A;
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
    await A;
end
pool[1] Tx ts;
do
    loop i in [0 -> 1000[ do
        var Tx&&? ok = spawn Tx in ts;
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
class U with
    var int v=0;
do
end

pool[10] U us;

spawn U in us;

escape 1;
]],
    run = 1,
}
Test { [[
interface I with
    var int v;
end

class U with
    var int v=0;
do
end

pool[10] I iss;

spawn U in iss;

escape 1;
]],
    run = 1,
}
Test { [[
interface I with
    var int v;
end

class Tx with
    var int u=0,v=0,x=0;
do
end

class U with
    var int v=0;
do
end

pool[10] I iss;

spawn Tx in iss;
spawn U in iss;

escape sizeof(CEU_T) >= sizeof(CEU_U);
]],
    run = 1,
}
Test { [[
class Tx with
    var int v=0;
do
end

class U with
do
end

pool[1] Tx ts;

spawn U in ts;

escape 1;
]],
    tmp = 'line 12 : invalid `spawn´ : types mismatch (`Tx´ <= `U´)',
}
Test { [[
interface I with
    var int v;
end

class V with
do
end

pool[1] I iss;

spawn V in iss;

escape 1;
]],
    tmp = 'line 11 : invalid `spawn´ : types mismatch (`I´ <= `V´)',
}
Test { [[
interface I with
    var int v;
end

class Tx with
do
end

class U with
    var int v=0;
do
end

class V with
do
    pool[1] I iss;
end

pool[1] I iss;

spawn Tx in iss;
spawn U in iss;
spawn V in iss;

escape 1;
]],
    tmp = 'line 21 : invalid `spawn´ : types mismatch (`I´ <= `Tx´)',
}
Test { [[
interface I with
    var int v;
end

class Tx with
do
end

class U with
    var int v=0;
do
end

class V with
do
    pool[1] I iss;
end

pool[1] I iss;

spawn U in iss;
spawn V in iss;

escape 1;
]],
    tmp = 'line 22 : invalid `spawn´ : types mismatch (`I´ <= `V´)',
}
Test { [[
interface I with
    var int v;
end

class Tx with do end

pool[1] I iss;

spawn Tx in iss;

escape 1;
]],
    tmp = 'line 9 : invalid `spawn´ : types mismatch (`I´ <= `Tx´)',
}

Test { [[
interface I with
    var int v;
end

class Tx with
    var int u=0,v=0,x=0;
do
end

class U with
    var int v=0;
do
end

class V with
do
    pool[10] I iss;
    spawn Tx in iss;
    spawn U in iss;
end

pool[10] I iss;

spawn Tx in iss;
spawn U in iss;
spawn V in iss;

escape sizeof(CEU_T) >= sizeof(CEU_U);
]],
    tmp = 'line 26 : invalid `spawn´ : types mismatch (`I´ <= `V´)',
}
Test { [[
interface I with
    var int v;
end

class Tx with
    var int u=0,v=0,x=0;
do
end

class U with
    var int v=0;
do
end

class V with
do
    pool[10] I iss;
    spawn Tx in iss;
    spawn U in iss;
end

pool[10] I iss;

spawn Tx in iss;
spawn U in iss;
spawn V;

escape sizeof(CEU_T) >= sizeof(CEU_U);
]],
    run = 1,
}
Test { [[
class Tx with
    var int a;
    var int b=0;
do
    b = a * 2;
    await FOREVER;
end

var Tx&&? t =
    spawn Tx with
        this.a = 10;
    end;

escape t!:b;
]],
    run = 20,
}

-- fails w/o RET_DEAD check after ceu_app_go for PAR
Test { [[
input void OS_START;
native/pos do
    tceu_trl* V;
end
class Tx with
do
    _V = &&__ceu_org:trls[1];
    await OS_START;
    par/or do
    with
native _assert;
        _assert(0);
    end
end
do
    var Tx t;
    await t;
end
//_V:lbl = _CEU_LBL__STACKED;
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
do
    par/or do
    with
native _assert;
        _assert(0);
    end
end
spawn Tx;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
class Tx with
do
    await OS_START;
end
spawn Tx;
await OS_START;
escape 1;
]],
    run = 1,
}

Test { [[
native _V;
native/pos do
    int V=0;
end
input void OS_START;
class Tx with
do
    par/or do
    with
    end
    _V = _V + 1;
    await OS_START;
    _V = _V + 1;
end
var Tx&&? t1 = spawn Tx;
var Tx&&? t2 = spawn Tx;
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
    var& IPingu pingu;
do
end

class Pingu with
    interface IPingu;
do
    every 10s do
        spawn WalkerAction with
            this.pingu = &outer;
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
    var& IPingu pingu;
do
end

class Pingu with
    interface IPingu;
do
    do
        pool[] WalkerAction was;
        every 10s do
            spawn WalkerAction in was with
                this.pingu = &outer;
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
class Tx with do end
var Tx&& a = null;
//free a;
escape 10;
]],
    run = 10,
}

Test { [[
class Tx with do end
var Tx&&? a = spawn Tx;
//free a;
escape 10;
]],
    run = 10,
}

Test { [[
class Tx with do end
var Tx&&? a = spawn Tx;
//free a;
var Tx&&? b = spawn Tx;
//free b;
escape 10;
]],
    run = 10,
}

Test { [[
class Tx with do end
var Tx&&? a = spawn Tx;
var Tx&&? b = spawn Tx;
//free a;
//free b;
escape 10;
]],
    run = 10,
}

Test { [[
class Tx with do end
var Tx&&? a = spawn Tx;
var Tx&&? b = spawn Tx;
//free b;
//free a;
escape 10;
]],
    run = 10,
}

Test { [[
native _V;
native/pos do
    int V = 0;
end
class Tx with
do
    do finalize with
        _V = _V + 1;
    end
end

var Tx&&? a = spawn Tx;
//free a;
escape _V;
]],
    run = 1,
}

Test { [[
native _V;
native/pos do
    int V = 0;
end
class Tx with
do
    do finalize with
        _V = _V + 1;
    end
end

var Tx&&? a = spawn Tx;
var Tx&&? b = spawn Tx;
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
class Tx with do end
var Tx a;
//free a;
escape 0;
]],
    todo = 'removed free',
    tmp = 'line 3 : invalid `free´',
}

Test { [[
class Tx with
do
    spawn U;
end
class U with
do
    spawn Tx;
end
var Tx t;
escape 1;
]],
    tmp = 'line 3 : undeclared type `U´',
}

Test { [[
class Tx with do end;
class U with
    pool&[] Tx ts;
do
end
pool[] Tx ts1;
pool[2] Tx ts2;
var U _ with
    this.ts = &ts1;
end;
var U _ with
    this.ts = &ts2;
end;
escape 1;
]],
    run = 1,
}
Test { [[
native/pos do
    int V = 0;
end
var int i=0;
var& int r = &i;

class Tx with
do
    _V = _V + 1;
    await FOREVER;
end;

pool[2] Tx ts;

class U with
    pool&[] Tx xxx;  // TODO: test also Tx[K<2], Tx[K>2]
                    //       should <= be allowed?
do
    spawn Tx in xxx;
    spawn Tx in xxx;
    spawn Tx in xxx;
    _V = _V + 10;
end

spawn Tx in ts;
var U u with
    this.xxx = &outer.ts;
end;

escape _V;
]],
    run = 12,
}

Test { [[
class Body with
    var& int sum;
do
    sum = sum + 1;
end

var int sum = 0;
var Body b with
    this.sum = &sum;
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
    pool&[]  X bodies;
    var&   int    sum;
    event int     ok;
do
    var X&&? nested =
        spawn X in bodies with
        end;
    sum = sum + 1;
    emit this.ok(1);
end

pool[1] X bodies;
var  int  sum = 1;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

escape sum;
]],
    run = 2,
}
Test { [[
class X with do
end;

class Body with
    pool&[]  X bodies;
    var&   int    sum;
    event int     ok;
do
    var X&&? nested =
        spawn X in bodies with
        end;
    sum = sum + 1;
    emit this.ok(1);
end

pool[1] X bodies;
var  int  sum = 1;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

class Tx with do end;
spawn Tx;

escape sum;
]],
    run = 2,
}

Test { [[
class X with do
end;

native/pos do
    ##ifdef CEU_ORGS_NEWS_POOL
    ##error bug found
    ##endif
end

class Body with
    pool&[]  X bodies;
    var&   int    sum;
    event int     ok;
do
    var X&&? nested =
        spawn X in bodies with
        end;
    sum = sum + 1;
    emit this.ok(1);
end

pool[] X bodies;
var  int  sum = 1;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

class Tx with do end;
spawn Tx;

escape sum;
]],
    run = 2,
}

Test { [[
class Job with
    var u8 id = 0;
    event void nextRequest;
do
    // do job
    await 1s;
end

pool[10] Job jobs;
pool&[10] Job jobs_alias = &jobs;

var Job&& ptr = null;
loop j in jobs do
    ptr = j;
    if true then break; end
end // ok, no compile error

ptr = null;
loop j in jobs_alias do
    ptr = j;
    if true then break; end
end // compile error occurs

escape 1;
]],
    run = 1,
}

-- problems w/o ceu_sys_stack_clear_org
Test { [[
input void OS_START;

class Tx with
do
    await 1us;
end

do
    var Tx t;
    await t;
end
do
native _char;
    vector[1000] _char v = [];
    native/nohold _memset;
    _memset(&&v, 0, 1000);
end

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

class Tx with
do
    do U;
end

do
    var Tx t1;
    var Tx t2;
    await t2;
end
do
native _char;
    vector[1000] _char v = [];
    native/nohold _memset;
    _memset(&&v, 0, 1000);
    var Tx t3;
    await t3;
end

escape 1;
]],
    run = { ['~>2us']=1 },
}

Test { [[
class U with
    event void ok;
do
    do finalize with
        _V = _V + 4;
    end
    await 1ms;
    emit this.ok;
    await FOREVER;
end;
class Tx with do
    do finalize with
        _V = _V + 2;
    end
    var U u;
    await FOREVER;
end;
native/pos do
    int V = 1;
end
do finalize with
    _V = 1000;
end
do finalize with
    _V = 1000;
end
do finalize with
    _V = 1000;
end
par/or do
    await 1s;
with
    do
        var Tx t;
        var U u;
        par/or do
            await u.ok;
        with
            await u.ok;
        end;
    end
    var Tx t1;
    var U u1;
    await u1.ok;
native _assert;
    _assert(_V == 11);
end
_assert(_V == 21);
escape _V;
]],
    run = { ['~>1s']=21 },
}

-- SPAWN / RECURSIVE

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
    if _V < 10 then
        spawn Tx;
    end
end
var Tx t;
escape _V;
]],
    wrn = 'line 8 : unbounded recursive spawn',
    run = 10,
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    _V = _V + 1;
    spawn Tx;
    await FOREVER;
end
var Tx t;
escape _V;
]],
    wrn = 'line 7 : unbounded recursive spawn',
    run = 101,  -- tests force 100 allocations at most
}
Test { [[
class Body with
    pool&[]  Body bodies;
    var&   int    sum;
    event int     ok;
do
    var Body&&? nested =
        spawn Body in bodies with
            this.bodies = &bodies;
            this.sum    = &sum;
        end;
    if nested? then
        watching *nested! do
            await nested!:ok;
        end
    end
    sum = sum + 1;
    emit this.ok(1);
end

pool[4] Body bodies;
var  int     sum = 0;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

escape sum;
]],
    wrn = 'line 7 : unbounded recursive spawn',
    run = 5,
}

Test { [[
class Body with
    pool&[] Body bodies;
    var&  int     sum;
do
    var Body&&? nested =
        spawn Body in bodies with
            this.bodies = &bodies;
            this.sum    = &sum;
        end;
    if nested? then
        await *nested!;
    end
    sum = sum + 1;
end

pool[] Body bodies;
var  int     sum = 0;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
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
    pool&[1] Body bodies;
    var&  int     sum;
do
    var Body&&? nested =
        spawn Body in bodies with
            this.bodies = &bodies;
            this.sum    = &sum;
        end;
    if nested? then
        await *nested!;
    end
    sum = sum + 1;
end

pool[1] Body bodies;
var  int     sum = 0;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

escape sum;
]],
    run = 2,
}
Test { [[
class Body with
    pool&[1] Body bodies;
    var&  int     sum;
do
    var Body&&? nested =
        spawn Body in bodies with
            this.bodies = &bodies;
            this.sum    = &sum;
        end;
    sum = sum + 1;
end

pool[1] Body bodies;
var  int     sum = 0;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

escape sum;
]],
    run = 2,
}

Test { [[
class Body with
    pool&[1] Body bodies;
    var&  int     sum;
do
    var Body&&? nested =
        spawn Body in bodies with
            this.bodies = &bodies;
            this.sum    = &sum;
        end;
    sum = sum + 1;
end

pool[1] Body bodies;
var  int     sum = 0;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

escape sum;
]],
    run = 2,
}

Test { [[
class Body with
    pool&[1] Body bodies;
    var&  int     sum;
do
    spawn Body in bodies with
        this.bodies = &bodies;
        this.sum    = &sum;
    end;
    sum = sum + 1;
    spawn Body in bodies with
        this.bodies = &bodies;
        this.sum    = &sum;
    end;
end

pool[1] Body bodies;
var  int     sum = 0;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

escape sum;
]],
    run = 3,
}

Test { [[
class Body with
    pool&[1] Body bodies;
    var&  int     sum;
do
    sum = sum + 1;
    loop do
        spawn Body in bodies with
            this.bodies = &bodies;
            this.sum    = &sum;
        end;
    end
end

pool[1] Body bodies;
var  int     sum = 0;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

escape sum;
]],
    tight = 'line 6 : tight loop',
}

Test { [[
class Body with
    pool&[1] Body bodies;
    var&  int     sum;
do
    sum = sum + 1;
    loop do
        var Body&&? t = spawn Body in bodies with
            this.bodies = &bodies;
            this.sum    = &sum;
        end;
        watching *t! do
            await FOREVER;
        end
    end
end

pool[1] Body bodies;
var  int     sum = 0;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

escape sum;
]],
    tight = 'line 6 : tight loop',
}

Test { [[
class Sum with
    var int&& v;
do
    await FOREVER;
end

class Body with
    pool&[]  Body bodies;
    var&   Sum    sum;
do
    *this.sum.v = *this.sum.v + 1;
    spawn Body in this.bodies with
        this.bodies = &bodies;
        this.sum    = &sum;
    end;
end

var int v = 0;
var Sum sum with
    this.v = &&v;
end;

pool[7] Body bodies;
do Body with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

escape v;
]],
    fin = 'line 11 : unsafe access to pointer "v" across `class´ (/tmp/tmp.ceu : 7)',
    --wrn = true,
    --run = 8,
}
Test { [[
class Sum with
    var int&& v;
do
    await FOREVER;
end

class Body with
    pool&[]  Body bodies;
    var&   Sum    sum;
do
    await 1s;
    *this.sum.v = *this.sum.v + 1;
    spawn Body in this.bodies with
        this.bodies = &bodies;
        this.sum    = &sum;
    end;
end

var int v = 0;
var Sum sum with
    this.v = &&v;
end;

pool[7] Body bodies;
do Body with
    this.bodies = &bodies;
    this.sum    = &sum;
end;

escape v;
]],
    fin = 'line 12 : unsafe access to pointer "v" across `class´ (/tmp/tmp.ceu : 7)',
}

Test { [[
input void OS_START;

class Tx with
    var int a=0;
do
end

event Tx&& e;

par/or do
    await OS_START;
    var Tx a;
    emit e(&&a);
    await FOREVER;
with
    var Tx&& pa = await e;
    watching *pa do
        await FOREVER;
    end
end

escape 1;
]],
    tmp = 'line 8 : invalid event type',
    --env = 'line 13 : wrong argument : cannot pass pointers',
    --run = 1,
}

Test { [[
input void OS_START;

class Tx with
    var int a=0;
do
    await 1s;
end

event Tx&& e;

par do
    var Tx&& pa = await e;
    watching *pa do
        await FOREVER;
    end
    escape -1;
with
    await OS_START;
    do
        var Tx a;
        emit e(&&a);
    end
    await 2s;
    escape 1;
end
]],
    tmp = 'line 9 : invalid event type',
    --env = 'line 21 : wrong argument : cannot pass pointers',
    --run = { ['~>2s']=1 },
}

Test { [[
class Tx with
do
end
var Tx a;
var int&& v = await a;
escape 1;
]],
    tmp = 'line 5 : types mismatch (`int&&´ <= `int´)',
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    do finalize with
        _V = 10;
    end
    await FOREVER;
end
do
    var Tx t;
end
escape _V;
]],
    run = 10,
}
Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    do finalize with
        _V = 10;
    end
    await FOREVER;
end
do
    pool[] Tx ts;
    var Tx&&? t = spawn Tx in ts;
end
escape _V;
]],
    run = 10,
}

Test { [[
class Tx with
    var int v = 10;
do
    await 1s;
end

input void OS_START;
event Tx&& e;

var int ret = 2;

par/and do
    await OS_START;
    var Tx&&? t = spawn Tx;
    emit e(t!);
    ret = ret + t!:v;
with
    var Tx&& t1 = await e;
    ret = ret * 2;
end

escape ret;
]],
    tmp = 'line 8 : invalid event type',
    --env = 'line 15 : wrong argument : cannot pass pointers',
    --run = { ['~>1s'] = 14 },
    --fin = 'line 16 : unsafe access to pointer "t" across `emit´',
}

Test { [[
class Tx with
    var int v = 10;
do
    await 1s;
end

input void OS_START;
event Tx&& e;

var int ret = 1;

par/and do
    await OS_START;
    var Tx&&? t = spawn Tx;
    watching *t! do
        emit e(t!);
        ret = ret + t!:v;
        await *t!;
        ret = ret + 1;
    end
with
    var Tx&& t1 = await e;
    ret = ret * 2;
end

escape ret;
]],
    tmp = 'line 8 : invalid event type',
    --env = 'line 16 : wrong argument : cannot pass pointers',
    --run = { ['~>1s'] = 12 },
}

Test { [[
input void OS_START;
event void a;
class Tx with do end
do
    var Tx t;
    par/or do
        await a;
native _assert;
        _assert(0);
    with
        await OS_START;
    end
    emit a;
end
escape 1;
]],
    run = 1,
}

-- outer organism dies, nested organism has to awake block
Test { [[
native/pos do
    int V = 1;
end

class S with
do
    await FOREVER;
end

class Tx with
    var S&& s;
do
    watching *s do
        every 1s do
            _V = _V + 1;
        end
    end
end

par/or do
    var S s;
    var Tx&&? t =
        spawn Tx with
            this.s = &&s;
        end;
    await *t!;
with
end

await 5s;

escape _V;
]],
    run = { ['~>10s']=1 },
}

Test { [[
input void OS_START;

class OrgC with
do
    await FOREVER;
end

event void signal;
var int ret = 0;

par/or do
    loop do
        watching signal do
            do OrgC;
        end
        ret = ret + 1;
    end
with
    await OS_START;
    emit signal;
end

escape ret;
]],
    wrn = true,
    loop = true,
    run = 1,
}

Test { [[
class Tx with
do
end

do Tx;

vector[31245] Tx ts;

escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
do
end

do Tx;

vector[31246] Tx ts;

escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
do
end

do Tx;

vector[65500] Tx ts;

escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
do
end

do Tx;

vector[65532] Tx ts;

escape 1;
]],
    valgrind = false,   -- TODO: why?
    run = 1,
}

Test { [[
class Tx with
do
end

do Tx;

vector[65533] Tx ts;

escape 1;
]],
    run = ':4] runtime error: too many dying organisms',
}

-->>> SPAWN-DO SUGAR

Test { [[
spawn do
end
escape 1;
]],
    ana = 'line 1 : `spawn´ body must never terminate',
}
Test { [[
spawn do
    await FOREVER;
end
escape 1;
]],
    run = 1,
}

Test { [[
var int xxx=0;
spawn do
    xxx = 1;
    await FOREVER;
end
escape xxx;
]],
    _ana = {acc=1},
    run = 1,
}

Test { [[
var int x;
spawn do
    x = 1;
end
escape x;
]],
    --ref = 'line 1 : uninitialized variable "x" crossing compound statement (/tmp/tmp.ceu:2)',
    run = 1,
}

Test { [[
var int x =
    spawn do
        escape 1;
    end;
escape x;
]],
    parser = 'line 2 : after `spawn´ : expected abstraction identifier',
}

Test { [[
input void OS_START;
var int x = 1;
spawn do
    every 1s do
        x = 1;
    end
end
await OS_START;
escape x;
]],
    run = 1,
}

Test { [[
input void OS_START;
var int x = 1;
spawn do
    loop do
        await 1s;
        if 1 == 1 then
            break;
        end
    end
end
await OS_START;
escape x;
]],
    ana = 'line 3 : `spawn´ body must never terminate',
}

Test { [[
input void OS_START;
var int x = 0;
spawn do
    await OS_START;
    x = 1;
end
await OS_START;
escape x;
]],
    ana = 'line 3 : `spawn´ body must never terminate',
}

Test { [[
input void OS_START;
var int x = 0;
spawn do
    await OS_START;
    x = 1;
    await FOREVER;
end
await OS_START;
escape x;
]],
    _ana = {acc=1},
    run = 1,
}

Test { [[
var int xxx=0;
spawn do
    xxx = 1;
    await FOREVER;
end
escape xxx;
]],
    _ana = {acc=1},
    run = 1,
}

Test { [[
class Tx with
    var int xxx=0;
do
    var int aaa = 0;
    spawn do
        this.aaa = 10;
        this.xxx = this.aaa;
        await FOREVER;
    end
    escape aaa;
end
var int ret = do Tx;
escape ret;
]],
    _ana = {acc=1},
    run = 10,
}

--<<< SPAWN-DO SUGAR

-->>> DO-Tx SUGAR

Test { [[
do Tx;
escape 0;
]],
    parser = 'line 1 : after `do´ : expected statement',
}

Test { [[
do call Tx;
escape 0;
]],
    parser = 'line 1 : after `Tx´ : expected `(´',
}

Test { [[
await Tx;
escape 0;
]],
    parser = 'line 1 : after `Tx´ : expected `(´',
}

Test { [[
await Tx();
escape 0;
]],
    dcls = 'line 1 : abstraction "Tx" is not declared',
}

Test { [[
class Tx with
do
end
do Tx;
escape 0;
]],
    run = 0,
    --dcls = 'line 4 : internal identifier "ok" is not declared',
}

Test { [[
class Tx with
    event void ok;
do
    emit ok;
end
par/or do
    loop do
        do Tx;
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
class Tx with
    event void ok;
do
    emit ok;
end
par do
    do Tx;
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
class Tx with
    event void ok;
do
    await OS_START;
    emit ok;
end
do Tx;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
class Tx with
    event int ok;
do
    await OS_START;
    emit ok(1);
end
do Tx;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
class Tx with
do
    await OS_START;
    escape 1;
end
var int ddd = do Tx;
escape ddd;
]],
    run = 1,
}
Test { [[
class Tx with
do
    escape 1;
end
var int ddd = do Tx;
escape ddd;
]],
    run = 1,
}

Test { [[
input void OS_START;
class Tx with
    var int v;
do
    await OS_START;
    escape v;
end
var int v = do Tx with
    this.v = 10;
end;
escape v;
]],
    run = 10,
}

Test { [[
input void OS_START;
class Tx with
    var int vv;
do
    await OS_START;
    escape vv;
end
var int a;
a = do Tx with
    this.vv = 10;
end;
escape a;
]],
    run = 10,
}

Test { [[
input void OS_START;
class Tx with
    var int v;
do
    await OS_START;
    escape 10;
end
var int&& v = do Tx with
    this.v = 10;
end;
escape *v;
]],
    tmp = 'line 8 : types mismatch (`int&&´ <= `int´)',
}

Test { [[
input void OS_START;
class Tx with
    var int v;
do
    await OS_START;
    escape v;
end
var int v;
v = do Tx with
    this.v = 10;
end;
escape v;
]],
    run = 10,
}

Test { [[
input void OS_START;
class Tx with
    var int v;
do
    await OS_START;
    escape (v,v*2);
end
var int v1, v2;
(v1,v2) = do Tx with
    this.v = 10;
end;
escape v1+v2;
]],
    parser = 'line 6 : after `v´ : expected `[´ or `:´ or `.´ or `?´ or `!´ or `is´ or `as´ or binary operator or `)´',
    --env = 'line 10 : arity mismatch',
    --run = 30,
}

Test { [[
input void OS_START;

class Mix with
  var int cup_top;
  event void ok;
do
    await OS_START;
    emit ok;
end

class ShuckTip with
do
    await FOREVER;
end

do
    var int dilu_start = 0;
    do
        var Mix m with
            this.cup_top = dilu_start;
        end;
        await m.ok;
    end
end
do
    var ShuckTip s;
end

escape 1;
]],
    run = 1,
}
Test { [[
input void OS_START;

class Mix with
  var int cup_top;
  event void ok;
do
  await OS_START;
  emit ok;
end

class ShuckTip with
do
end

do
    var int dilu_start = 0;
    do
        var Mix m with
            this.cup_top = dilu_start;
        end;
        await m.ok;
    end
end
do
    var ShuckTip s;
    await s;
end

escape 1;
]],
    run = 1,
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
class Tx with do
    await FOREVER;
end
var Tx&&? ok;
native/pos do ##include <assert.h> end
native _assert;
do
    loop i in [0 -> 100[ do
        ok = spawn Tx;
    end
    _assert(ok?);
    ok = spawn Tx;
    ok = spawn Tx;
    _assert(not ok?);
end
do
    loop i in [0 -> 100[ do
        ok = spawn Tx;
    end
    _assert(not ok?);
end
do
    loop i in [0 -> 101[ do
        ok = spawn Tx;
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
class Tx with do
    await FOREVER;
end
native/pos do ##include <assert.h> end
native _assert;
do
    loop i in [0 -> 100[ do
        var Tx&&? ok;
        ok = spawn Tx;
        _assert(ok?);
    end
    var Tx&&? ok1 = spawn Tx;
    _assert(not ok1?);
    var Tx&&? ok2 = spawn Tx;
    _assert(not ok2?);
end
do
    loop i in [0 -> 100[ do
        var Tx&&? ok;
        ok = spawn Tx;
        _assert(ok?);
    end
end
do
    loop i in [0 -> 101[ do
        var Tx&&? ok;
        ok = spawn Tx;
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
class Tx with do
    await FOREVER;
end
native/pos do ##include <assert.h> end
native _assert;
do
    pool[] Tx ts;
    loop i in [0 -> 100[ do
        var Tx&&? ok;
        ok = spawn Tx in ts;
        _assert(not ok?);
    end
    var Tx&&? ok1 = spawn Tx;
    _assert(not ok1?);
    var Tx&&? ok2 = spawn Tx;
    _assert(not ok2?);
end
do
    pool[] Tx ts;
    loop i in [0 -> 100[ do
        var Tx&&? ok;
        ok = spawn Tx in ts;
        _assert(ok?);
    end
end
do
    pool[] Tx ts;
    loop i in [0 -> 101[ do
        var Tx&&? ok;
        ok = spawn Tx in ts;
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
native/pos do ##include <assert.h> end
native _V;
native/pos do
    int V = 0;
end
class Tx with
    var int inc;
do
    do finalize with
        _V = _V + this.inc;
    end
    await FOREVER;
end
var int v = 0;
do
    pool[] Tx ts;
    loop i in [0 -> 200[ do
        var Tx&&? ok =
            spawn Tx in ts with
                this.inc = 1;
            end;
        if (not ok?) then
            v = v + 1;
        end
    end

    input void OS_START;
    await OS_START;
end
native _assert;
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
        spawn HelloWorld(i);
        i = i + 1;
    end
end
]],
    dcls = 'line 4 : abstraction "HelloWorld" is not declared',
}

Test { [[
native _V;
native/pos do
    int V = 0;
end
class Tx with
do
    await 2s;
    _V = _V + 1;
end
do
    spawn Tx;
    await 1s;
    spawn Tx;
    await 1s;
    spawn Tx;
    await 1s;
    spawn Tx;
    await 50s;
end
escape _V;
]],
    run = { ['~>100s']=4 },
}

Test { [[
input void OS_START;
native _V;
native/pos do
    int V = 1;
end
class Tx with
do
    await OS_START;
    _V = 10;
end
do
    spawn Tx;
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
native/pos do
    int V = 1;
end
class Tx with
do
    _V = 10;
end
do
    spawn Tx;
    await OS_START;
end
escape _V;
]],
    run = 10,
}

Test { [[
class Tx with do end;
var Tx a;
var Tx&& b;
b = &&a;
escape 1;
]],
    run = 1,
    --env = 'line 4 : invalid attribution',
}

Test { [[
class Tx with do
    await FOREVER;
end;
var Tx&&? a = spawn Tx;
var Tx&& b;
b = a!;
escape 10;
]],
    run = 10;
}

Test { [[
class Tx with do end;
var Tx&&? a = spawn Tx;
var Tx&& b;
b = a!;
escape 10;
]],
    asr = '4] runtime error: invalid tag',
}

Test { [[
class Tx with
    var int v=0;
do
    await FOREVER;
end

var Tx&& a=null;
do
    var Tx&&? b = spawn Tx;
    b!:v = 10;
    a = b!;
end
escape a:v;
]],
    --fin = 'line 10 : attribution requires `finalize´',
    --fin = 'line 12 : pointer access across `await´',
    --run = 10,
    fin = 'line 13 : unsafe access to pointer "a" across `spawn´ (/tmp/tmp.ceu : 9)',
}
Test { [[
class Tx with
    var int v=0;
do
    await FOREVER;
end

var Tx&&? a;
do
    var Tx&&? b = spawn Tx;
    b!:v = 10;
    a = b!;
end
escape a!:v;
]],
    --fin = 'line 10 : attribution requires `finalize´',
    --fin = 'line 12 : pointer access across `await´',
    run = 10,
}
Test { [[
class Tx with
    var int v=0;
do
    await FOREVER;
end

var Tx&&? a;
do
    var Tx&&? b = spawn Tx;
    b!:v = 10;
    a = b!;
    escape a!:v;
end
]],
    --fin = 'line 10 : attribution requires `finalize´',
    run = 10,
}

Test { [[
class Tx with
    var int v=0;
do
end

var Tx&& a=null;
do
    var Tx&&? b = spawn Tx;
    b!:v = 10;
    a = b!;
end
await 1s;
escape a:v;
]],
    fin = 'line 13 : unsafe access to pointer "a" across `spawn´ (/tmp/tmp.ceu : 8)'
}

Test { [[
class Tx with
    var int v=0;
do
    await FOREVER;
end

var Tx&& a=null;
var Tx aa;
do
    var Tx&&? b = spawn Tx;
    b!:v = 10;
        a = b!;
end
escape a:v;
]],
    fin = 'line 14 : unsafe access to pointer "a" across `spawn´ (/tmp/tmp.ceu : 10)',
}

Test { [[
native _V;
native/pos do
    int V = 1;
end
class Tx with
    var int v=0;
do
    do finalize with   // enters!
        _V = 10;
    end
    await FOREVER;
end

var Tx&& a=null;
var Tx aa;
do
    pool[] Tx ts;
    var Tx&&? b = spawn Tx in ts;
    b!:v = 10;
        a = b!;
end
escape _V;
]],
    run = 10,
}

Test { [[
input void OS_START;
native _V;
native/pos do
    int V = 0;
end
class Tx with
    var int v=0;
do
    do finalize with
        _V = 10;
    end
    await FOREVER;
end

var Tx&& a=null;
var Tx aa;
do
    pool[] Tx ts;
    var Tx&&? b = spawn Tx in ts;
    b!:v = 10;
        a = b!;
    await OS_START;
end
escape _V;
]],
    run = 10,
}

Test { [[
native _V;
native/pos do
    int V = 5;
end
class Tx with
    var int v=0;
do
    do finalize with   // enters!
        _V = 10;
    end
    await FOREVER;
end

var Tx&& a=null;
do
    pool[] Tx ts;
    var Tx&&? b = spawn Tx in ts;
    b!:v = 10;
        a = b!;
end
escape _V;
]],
    run = 10,
}
Test { [[
input void OS_START;
native _V;
native/pos do
    int V = 5;
end
class Tx with
    var int v=0;
do
    do finalize with
        _V = 10;
    end
    await FOREVER;
end

var Tx&& a=null;
do
    pool[] Tx ts;
    var Tx&&? b = spawn Tx in ts;
    b!:v = 10;
        a = b!;
    await OS_START;
end
escape _V;
]],
    run = 10,
}
Test { [[
class Tx with
    var int&& i1=null;
do
    var int i2=0;
    i1 = &&i2;
end
var Tx a;
escape 10;
]],
    run = 10,
}

Test { [[
class Tx with do end
var Tx&& t1=null;
do
do
    var Tx t2;
    t1 = &&t2;
end
end
escape 10;
]],
    fin = 'line 6 : attribution to pointer with greater scope',
    run = 10,
}

Test { [[
class Tx with do end
var Tx&& t1=null;
do
do
    var Tx t2;
    //finalize
        t1 = &&t2;
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
class Tx with do end
var Tx&&? t;
do
    t = spawn Tx;
end
escape 10;
]],
    run = 10,
    --fin = 'line 4 : invalid block for awoken pointer "t"',
}

Test { [[
class Tx with do end
var Tx&&? a = spawn Tx;
escape 10;
]],
    run = 10,
}

Test { [[
class Tx with do end
class U with do end
var Tx&&? a;
a = spawn U;
]],
    tmp = 'line 4 : types mismatch',
}

Test { [[
native _V;
input void OS_START;
native/pos do
    int V = 0;
end

class Tx with
    var int a=0;
do
    do finalize with
        _V = 1;
    end
    a = 10;
end

var int ret = 0;

do
    var Tx&&? o;
    o = spawn Tx;
    await OS_START;
    ret = o!:a;
end

escape ret + _V;
]],
    run = '22] runtime error: invalid tag',
    --run = 11,
    --fin = 'line 22 : unsafe access to pointer "o" across `await´',
}

Test { [[
input void OS_START, B;
native _V;
native/pos do
    int V = 0;
end

class Tx with
    var int a=0;
do
    do finalize with
        _V = 1;
    end
    a = 10;
    await 1s;
end

var int ret = 0;

par/or do
    pool[] Tx ts;
    var Tx&&? o;
    o = spawn Tx in ts;
    //await OS_START;
    ret = o!:a;
with
    await B;
end

escape ret + _V;
]],
    run = { ['~>B']=11 },
}

Test { [[
class Tx with
do
    await FOREVER;
end

par/or do
    spawn Tx;
with
native _assert;
    _assert(0);
end

escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START, B;
native _V;
native/pos do
    int V = 0;
end

class Tx with
    var int a=0;
do
    do finalize with
        _V = 1;
    end
    a = 10;
    await 1s;
end

var int ret = 0;

par/or do
    var Tx&&? o;
    o = spawn Tx;
    //await OS_START;
    ret = o!:a;
with
    await B;
end

escape ret + _V;    // V still 0
]],
    run = { ['~>B']=10 },
}

Test { [[
class V with
do
end

var V&&? v;
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

do
    var V&&? vv = spawn V;
end

class Tx with
    var U u;
do
end

var Tx t;
escape 1;
]],
    props = 'line 13 : not permitted inside an interface',
}

Test { [[

class V with
do
end

class U with
 
do
    var V&&? vv = spawn V;
end

class Tx with
    var U&& u=null;
do
    var U uu;
    this.u = &&uu;
end

var Tx t;
escape 1;
]],
    run = 1,
}

Test { [[
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
        do v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U u;
do
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

var Tx t;
escape _V;
]],
    props = 'line 26 : not permitted inside an interface',
}
Test { [[
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
    if v? then end;
        do v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U&& u=null;
do
    var U uu;
    u = &&uu;
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

var Tx t;
escape _V;
]],
    run = 1,
}

Test { [[
input void OS_START;
native _f, _V;
native/pos do
    int V = 1;
end

class V with
do
    do finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V v;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U u;
do
    await FOREVER;
end

do
    var Tx t;
end

escape _V;
]],
    props = 'line 16 : not permitted inside an interface',
}
Test { [[
input void OS_START;
native _f, _V;
native/pos do
    int V = 1;
end

class V with
do
    do finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V vv1;
    v = &&vv1;
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U&& u=null;
do
    var U uu;
    u = &&uu;
    await FOREVER;
end

do
    var Tx t;
end

escape _V;
]],
    run = 3,
}

Test { [[
input void OS_START;
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
        do v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U u;
do
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

do
    var Tx t;
end

escape _V;
]],
    props = 'line 27 : not permitted inside an interface',
}
Test { [[
input void OS_START;
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
    if v? then end
        do v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U&& u=null;
do
    var U uu;
    u = &&uu;
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

do
    var Tx t;
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
    var V&&? vv = spawn V;
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
    var V&&? vv = spawn V;
end


var U t;
await OS_START;

native/nohold _tceu_trl, _tceu_trl_, _sizeof;
escape 2;
]],
    run = 2,
}

Test { [[
input void OS_START;
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
do        v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U u;
do
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

do
    var Tx t;
    await OS_START;
end

escape _V;
]],
    props = 'line 27 : not permitted inside an interface',
}
Test { [[
input void OS_START;
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
    if v? then end
        do v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U&& u=null;
do
    var U uu;
    u = &&uu;
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

do
    var Tx t;
    await OS_START;
end

escape _V;
]],
    run = 3,
}

Test { [[
input void OS_START;
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
        do v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& x=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U u;
do
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

var Tx t;
do
    await OS_START;
    var V&& v = t.u.x;
end

escape _V;
]],
    --fin = 'line 37 : pointer access across `await´',
    props = 'line 27 : not permitted inside an interface',
}
Test { [[
input void OS_START;
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
    if v? then end;
        do v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U&& u=null;
do
    var U uu;
    u = &&uu;
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

var Tx t;
do
    await OS_START;
    var V&& v = t.u:v;
    if v==null then end;
end

escape _V;
]],
    --fin = 'line 39 : pointer access across `await´',
    run = 1,
}

Test { [[
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
        do v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U u;
do
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

input void OS_START;

var Tx t;
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
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
        do v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U u;
do
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

input void OS_START;

var Tx t;
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
native _f, _V;
native/pos do
    int V = 1;
    int* f (){ escape NULL; }
end

class V with
do
    var& int? v;
    if v? then end;
        do v = &_f();
    finalize with
        _V = _V+1;
    end
    await FOREVER;
end

class U with
    var V&& v=null;
do
    var V&&? vv = spawn V;
    await FOREVER;
end

class Tx with
    var U&& u=null;
do
    var U uu;
    u = &&uu;
    //u.v = spawn V;
    var V&&? v = spawn V;
    await FOREVER;
end

input void OS_START;

var Tx t;
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

class Tx with
    var V&&? v;
do
    await 1s;
    v = spawn V;
end

var Tx t;
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
    var V&&? v;
do
end

class Tx with
    var U&& u=null;
do
    await OS_START;
    u:v = spawn V;
end

do
    var U u;
    var Tx t;
        t.u = &&u;
    await OS_START;
end

escape 10;
]],
    --run = 10,
    tmp = 'line 15 : invalid attribution (no scope)',
}
Test { [[
class V with
do
end

input void A, OS_START;
class U with
    var V&&? v;
do
    await A;
end

class Tx with
    var U&& u=null;
do
    await OS_START;
    u:v = spawn V;
end

do
    var U u;
    var Tx t;
        t.u = &&u;
    await OS_START;
end

escape 10;
]],
    --run = { ['~>A']=10 },
    tmp = 'line 16 : invalid attribution',
}

Test { [[
native _V, _assert;
native/pos do
    int V = 1;
end

class V with
do
    _V = 20;
    _V = 10;
end

class U with
    var V&&? v;
do
end

class Tx with
    var U&& u=null;
do
    await 1s;
    u:v = spawn V;
end

do
    var U u;
    do              // 26
        var Tx t;
        t.u = &&u;
        await 2s;
    end
    _assert(_V == 10);
end
_assert(_V == 10);
escape _V;
]],
    --run = { ['~>2s']=10, }       -- TODO: stack change
    tmp = 'line 21 : invalid attribution',
}

Test { [[
native/pos do ##include <assert.h> end
native _assert;
native _V;
native/pos do
    int V = 10;
end
class Tx with
do
    do finalize with
        _V = _V - 1;
    end
    await 500ms;
    _V = _V - 1;
end

do
    var Tx&&? a;
    a = spawn Tx;
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
native/pos do ##include <assert.h> end
native _assert;
native _V;
native/pos do
    int V = 10;
end
class Tx with
do
    do finalize with
        _V = _V - 1;
    end
    await 500ms;
    _V = _V - 1;
end

do
    pool[] Tx ts;
    var Tx&&? a;
    a = spawn Tx in ts;
    //free a;
    _assert(_V == 10);
end
_assert(_V == 9);

escape _V;
]],
    run = 9,
}

Test { [[
native/pos do ##include <assert.h> end
native _assert;
native _X, _Y;
native/pos do
    int X = 0;
    int Y = 0;
end

class Tx with
do
    do finalize with
        _Y = _Y + 1;
    end
    _X = _X + 1;
    await FOREVER;
end

do
    var Tx&&? ptr;
    loop i in [0 -> 100[ do
        if ptr? then
            //free ptr;
        end
        ptr = spawn Tx;
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
native/pos do ##include <assert.h> end
native _assert;
native _X, _Y;
native/pos do
    int X = 0;
    int Y = 0;
end

class Tx with
do
    do finalize with
        _Y = _Y + 1;
    end
    _X = _X + 1;
    await FOREVER;
end

do
    pool[] Tx ts;
    var Tx&&? ptr;
    loop i in [0 -> 100[ do
        if ptr? then
            //free ptr;
        end
        ptr = spawn Tx in ts;
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
native/pos do ##include <assert.h> end
native _assert;
native _X, _Y;
native/pos do
    int X = 0;
    int Y = 0;
end

class Tx with
do
    do finalize with
        _Y = _Y + 1;
    end
    _X = _X + 1;
    await FOREVER;
end

do
    var Tx&&? ptr;
    loop i in [0 -> 100[ do
        if ptr? then
            //free ptr;
        end
        ptr = spawn Tx;
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
class Tx with
    var U&& u;
do
end

do
    var U u;
    spawn Tx with
        this.u = &&u;
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
class Tx with
    var& U u;
do
end

do
    var U u;
    spawn Tx with
        this.u = &u;
    end;
end
escape 1;
]],
    --fin = 'line 10 : attribution requires `finalize´',
    --run = 1,
    --ref = 'line 10 : attribution to reference with greater scope',
    tmp = 'line 10 : invalid attribution : variable "u" has narrower scope than its destination',
}

Test { [[
class U with do end;
class Tx with
    var U&& u;
do
end

    var U u;
    spawn Tx with
        this.u = &&u;
    end;
escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;
class Tx with
    var& U u;
do
end

    var U u;
    spawn Tx with
        this.u = &u;
    end;
escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;
class Tx with
    var U&& u;
do
    var U&& u1 = u;
    if u1==null then end;
    await 1s;
end

do
    var U u;
    spawn Tx with
        this.u = &&u;
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
class Tx with
    var U&& u;
do
    var U&& u1 = u;
    if u1==null then end;
    await 1s;
end

    var U u;
    spawn Tx with
        this.u = &&u;
    end;
escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;
class Tx with
    var U&& u;
do
    var U&& u1 = u;
    await 1s;
    var U&& u2 = u;
end

do
    var U u;
    spawn Tx with
        this.u = &&u;
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
    pool[1000] Rect rs;
    every 40ms do
        loop i in [0 -> 40[ do
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
var void&& ptr;
class Tx with
do
end
loop i in [0 -> 100000[ do
    ptr = spawn Tx;
end
escape 10;
]],
    --loop = true,
    run = 10;
}
]=]

Test { [[
native/pos do ##include <assert.h> end
native _V, _assert;
native/pos do
    int V = 0;
end
class Tx with
    var int v=0;
do
    do finalize with
        do
            loop i in [0 -> 1[ do
                do break; end
            end
            _V = _V + this.v;
        end
    end
    await FOREVER;
end
do
    pool[] Tx ts;
    var Tx&&? p;
    p = spawn Tx in ts;
    p!:v = 1;
    p = spawn Tx in ts;
    p!:v = 2;
    p = spawn Tx in ts;
    p!:v = 3;
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
class Tx with
do
end
var Tx&&? t;
t = spawn Tx;
escape t!.v;
]],
    tmp = 'line 6 : not a struct',
}

Test { [[
native/plain _void;
class Tx with
    var int v=0;
do
    await FOREVER;
end

vector[10] _void&& ts = [];
var Tx&&? t;
t = spawn Tx;
t!:v = 10;
ts[0] = (t!) as void&&;
escape t!:v + (ts[0] as Tx&&):v;
]],
    fin = 'line 12 : unsafe access to pointer "ts" across `spawn´ (/tmp/tmp.ceu : 10)',
}

Test { [[
native/pre do
    typedef void* void_;
end
native/plain _void_;
class Tx with
    var int v=0;
do
    await FOREVER;
end

vector[10] _void_ ts = [];
var Tx&&? t;
t = spawn Tx;
t!:v = 10;
ts[0] = (t!) as void&&;
escape t!:v + (ts[0] as Tx&&):v;
]],
    run = 20,
}

Test { [[
native _V;
native/pos do
    int V = 0;
end

class Tx with
do
    _V = _V + 1;
    par/and do
        await 10ms;
    with
        loop i in [0 -> 5[ do
            if i==2 then
                break;
            end
            await 10ms;
        end
    end
    _V = _V + 1;
end

do
    loop i in [0 -> 10[ do
        await 1s;
        spawn Tx;
    end
    await 5s;
end

escape _V;
]],
    run = { ['~>1min']=20 },
}

Test { [[
class Tx with
    var int&& ptr = null;
do
end
do
    var int&& p = null;
    var Tx&&? ui = spawn Tx with
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
class Tx with
    var void&& ptr = null;
do
end
do
    pool[] Tx ts;
    var void&& p = null;
    var Tx&&? ui;
    ui = spawn Tx in ts with
        this.ptr = p;
    end;
end
escape 10;
]],
    --fin = 'line 10 : attribution to pointer with greater scope',
    run = 10,
}

Test { [[
native _s;
native/pre do
    typedef int s;
end

class Tx with
    var _s&& ptr = null;
do
end

do
    var _s&& p = null;
    var Tx&&? ui = spawn Tx with
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
native _s;
native/pre do
    typedef int s;
end

class Tx with
    var _s&& ptr = null;
do
end

var Tx&&? ui;
do
    var _s&& p = null;
    do
        ui = spawn Tx with
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
native _s;
native/pre do
    typedef int s;
end

class Tx with
    var _s&& ptr = null;
do
end

do
    loop i in [0 -> 10[ do
        var _s&& p = null;
        spawn Tx with
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
native/pos do
    int V = 0;
end

class Tx with
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

var Tx t;
_V = _V * 2;
emit t.a;
escape _V;
]],
    _ana = { acc=1 },
    --run = 14,
    run = 40,
}

Test { [[
native _s;
native/pre do
    typedef int s;
end

class Tx with
    var _s&& ptr = null;
do
    _V = _V + 1;
end

native/pos do ##include <assert.h> end
native _V, _assert;
native/pos do
    int V=0;
end

do
    loop i in [0 -> 10[ do
        var _s&& p = null;
        spawn Tx with
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
class Tx with
    var void&& ptr;
do
end

var Tx t with
        do this.ptr = _malloc(10);
    finalize with
        _free();
    end
end;
]],
    --dcls = 'line 22 : internal identifier "_" is not declared',
    fin = 'line 7 : constructor cannot contain `finalize´',
    --props = 'line 23 : not permitted inside a constructor',
}

Test { [[
class Tx with
    var void&& ptr;
do
end

spawn Tx with
        do this.ptr = _malloc(10);
    finalize with
        _free();
    end
end;
]],
    --dcls = 'line 22 : internal identifier "_" is not declared',
    fin = 'line 7 : constructor cannot contain `finalize´',
    --props = 'line 23 : not permitted inside a constructor',
}

Test { [[
native _s;
native/pre do
    typedef int s;
end

class Tx with
    var _s&& ptr = null;
do
end

native/pos do ##include <assert.h> end
native _V, _assert;
native/pos do
    int V=0;
end

do
    loop i in [0 -> 10[ do
        var _s&& p = null;
        spawn Tx with
                do this.ptr = p;
            finalize with
                _V = _V + 1;
            end
        end;
        await 1s;
    end
    _assert(_V == 10);
end

escape _V;
]],
    --dcls = 'line 22 : internal identifier "_" is not declared',
    fin = 'constructor cannot contain `finalize´',
    --props = 'line 23 : not permitted inside a constructor',
}

Test { [[
native _s, _V;
    var _s&& p = null;
    loop i in [0 -> 10[ do
        var _s&& p1 = p;
        await 1s;
    end

escape _V;
]],
    inits = 'line 4 : invalid pointer access : crossed `loop´ (/tmp/tmp.ceu:3)',
    --run = { ['~>1min']=10 },
    --fin = 'line 3 : unsafe access to pointer "p" across `loop´ (/tmp/tmp.ceu : 2)',
}

Test { [[
native _s, _V;
native/pre do
    typedef int s;
end

class Tx with
    var _s&& ptr = null;
do
    _V = _V + 1;
end

native/pos do ##include <assert.h> end
native _V, _assert;
native/pos do
    int V=0;
end

var Tx&&? ui;
do
    loop i in [0 -> 10[ do
        var _s&& p = null;
        ui = spawn Tx with
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
native _s;
native/pre do
    typedef int s;
end

class Tx with
    var _s&& ptr = null;
do
end

native/pos do ##include <assert.h> end
native _V, _assert;
native/pos do
    int V=0;
end

var Tx&&? ui;
do
    var _s&& p = null;
    loop i in [0 -> 10[ do
        ui = spawn Tx with
                do this.ptr = p;
            finalize with
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
    --dcls = 'line 23 : internal identifier "_" is not declared',
    fin = 'constructor cannot contain `finalize´',
    --props = 'line 24 : not permitted inside a constructor',
}

Test { [[
native _s;
native/pre do
    typedef int s;
end

class Tx with
    var _s&& ptr = null;
do
end

native/pos do ##include <assert.h> end
native _V, _assert;
native/pos do
    int V=0;
end

do
    loop i in [0 -> 10[ do
        var _s&& p = null;
        var Tx&&? ui = spawn Tx with
                do this.ptr = p;   // p == ptr
            finalize with
                _V = _V + 1;
            end
        end;
        await 1s;
    end
    _assert(_V == 10);
end

escape _V;
]],
    --dcls = 'line 22 : internal identifier "_" is not declared',
    fin = 'constructor cannot contain `finalize´',
    --fin = 'line 21 : invalid `finalize´',
}

Test { [[
class Game with
    event (int,int) go;
do
end

var Game game;
par/or do
    var int a,b;
    (a, b) = await game.go;
    if a and b then end;
with
    nothing;
end
escape 1;
]],
    run = 1;
}

Test { [[
class Game with
    event (int,int,int&&) go;
do
end

var Game game;
emit game.go(1, 1, null);
escape 1;
]],
    tmp = 'line 2 : invalid event type',
    --env = 'line 7 : wrong argument #3 : cannot pass pointers',
    --run = 1;
}

Test { [[
class Unit with
    event int move;
do
end
var Unit&& u=null;
do
    var Unit unit;
    u = &&unit;
    await 1min;
end
emit u:move(0);
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
var Unit&&? u;
do
    pool[] Unit units;
    u = spawn Unit in units;  // deveria falhar aqui!
    await 1min;
end
emit u!:move(0);
escape 2;
]],
    run = {['~>1min']='12] runtime error: invalid tag'},
    --fin = 'line 11 : unsafe access to pointer "u" across `await´',
}

Test { [[
class Tx with do end;
pool[] Tx ts;
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

class Tx with
    event int e;
do
    var int v = await A;
    emit e(v);
end

event int a;

var int ret=0;
par/or do
    pause/if a do
        var Tx t;
        ret = await t.e;
    end
with
    await OS_START;
    emit a(1);
    await B;
    emit a(0);
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

class Tx with
    event void v, ok, go;
do
    await A;
    emit v;
    emit ok;
end

par/or do
    pause/if a do
        vector[2] Tx ts;
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
    emit a(1);
    await X;
    emit a(0);
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
native/pos do
    int V = 0;
end

class Tx with
    var int c;
do
    do finalize with
        _V = _V + c;
    end
    await FOREVER;
end

par/or do
    do
        pool[] Tx ts;
        loop i do
            spawn Tx in ts with
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
native/pos do
    int V = 0;
end

class Tx with
    var int c;
do
    do finalize with
        _V = _V + c;
    end
    await FOREVER;
end

input int P;
event int pse;

par/or do
    pause/if pse do
        do
            pool[] Tx ts;
            loop i do
                spawn Tx in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse(v);
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
native/pos do
    int V = 0;
end

class Tx with
    var int c;
do
    do finalize with
        _V = _V + c;
    end
    await FOREVER;
end

input int P;
event int pse;

par/or do
    do
        pool[] Tx ts;
        loop i do
            pause/if pse do
                spawn Tx in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse(v);
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
native/pos do
    int V = 0;
end

class Tx with
    var int c;
do
    do finalize with
        _V = _V + c;
    end
    await 5s;
    _V = _V + 10;
end

input int P;
event int pse;

par/or do
    do
        pool[] Tx ts;
        loop i do
            pause/if pse do
                spawn Tx in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse(v);
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
native/pos do
    int V = 0;
end

class Tx with
    var int c;
do
    do finalize with
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
            pool[] Tx ts;
            loop i do
                spawn Tx in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse(v);
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
native/pos do
    int V = 0;
end

class Tx with
    var int c;
do
    do finalize with
        _V = _V + c;
    end
    await 5s;
    _V = _V + 10;
end

input int P;
event int pse;

par/or do
    do
        pool[] Tx ts;
        loop i do
            pause/if pse do
                spawn Tx in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse(v);
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
native/pos do
    int V = 0;
end

class Tx with
    var int c;
do
    do finalize with
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
            pool[] Tx ts;
            loop i do
                spawn Tx in ts with
                    this.c = i;
                end;
                await 1s;
            end
        end
    end
with
    loop do
        var int v = await P;
        emit pse(v);
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

class Tx with
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
    var Tx t;
    var int pse_ = 0;
    loop do
        await 1s;
        pse_ = not pse_;
        emit a(pse_);
        emit t.a(pse_);
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
class Tx with
    var int v;
do
    await FOREVER;
end
var Tx&&? t = spawn Tx with
             this.v = 10;
           end;
//free(t);
escape t!:v;
]],
    run = 10,
}

-- kill org inside iterator
Test { [[
class Tx with
    event void e;
do
    await e;
end

pool[] Tx ts;

var int ret = 1;

spawn Tx in ts;
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
    props = 'line 14 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = 2,
}

Test { [[
class Tx with
    var Tx&& t;
    event void e;
do
    watching *t do
        await e;
    end
end

pool[] Tx ts;

var int ret = 1;

var Tx&&? t1 = spawn Tx in ts with
                this.t = &&this;
            end;
var Tx&&? t2 = spawn Tx in ts with
                this.t = t1!;
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
    props = 'line 23 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = 2,
}

Test { [[
interface I with
    var int v;
    event void e;
end
class Tx with
    interface I;
do
    await e;
end
pool[] Tx ts;
var int ret = 0;
do
    spawn Tx in ts with
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
    props = 'line 17 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = 10,
}

Test { [[
class Tx with
    event void e;
do
    await e;
end

pool[] Tx ts;

var int ret = 1;

spawn Tx in ts;
spawn Tx in ts;
async do end;

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
class Tx with
    event void e;
do
    await e;
end

pool[] Tx ts;

var int ret = 1;

spawn Tx in ts;
spawn Tx in ts;
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
    props = 'line 15 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = 3,
}

-- TODO pause hierarquico dentro de um org
-- SDL/samples/sdl4.ceu

-- INTERFACES / IFACES / IFCES

if COMPLETE then
    for i=120, 150 do
        local str = {}
        for j=1, i do
            str[#str+1] = [[
class Class]]..j..[[ with
    interface I;
do
    x = 10;
end
    ]]
        end
        str = table.concat(str)

        Test { [[
interface I with
    var int x;
end
]]..str..[[

var Class]]..i..[[ instance;
var I&& target = &&instance;
escape target:x;
]],
            run = 10,
        }
    end
end

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
class Tx with
    interface I;
do
    await FOREVER;
end
var Tx t with
    this.a1 = 1;
    this.a2 = 2;
    this.b1 = 3;
    this.b2 = 4;
    this.c1 = 5;
    this.c2 = 6;
end;
var I&&? i = &&t;
escape i!:a1+i!:a2+i!:b1+i!:b2+i!:c1+i!:c2;
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
class Tx with
    interface I;
do
end
var Tx t with
    this.a1 = 1;
    this.a2 = 2;
    this.b1 = 3;
    this.b2 = 4;
    this.c1 = 5;
    this.c2 = 6;
end;
var I&& i = &&t;
escape i:a1+i:a2+i:b1+i:b2+i:c1+i:c2;
]],
    run = 21,
}
Test { [[
interface I with
    var int a;
end
class Tx with
do end
do
    pool[] Tx ts;
    loop i in ts do
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
native _ptr;
native/pos do
    void* ptr;
end
interface I with
    event void e;
end
var J&& i = _ptr;
escape 10;
]],
    tmp = 'line 8 : undeclared type `J´',
}

Test { [[
native _ptr;
native/pos do
    void* ptr;
end
interface I with
    event void e;
end
var I&& i = _ptr;
escape 10;
]],
    --env = 'line 8 : invalid attribution',
    todo = 'i=ptr',
    run = 10,
}

Test { [[
native _ptr;
native/pos do
    void* ptr;
end
interface I with
    event int e;
end
var I&& i = _ptr as I&&;
escape 10;
]],
    run = 10;
}

-- CAST

Test { [[
native/pos do ##include <assert.h> end
native _assert;

interface Tx with
end

class T1 with
do
end

class T2 with
do
end

var T1 t1;
var T2 t2;
var Tx&& t;

t = &&t1;
var T1&& x1 = ( t as T1&&);
_assert(x1 != null);

t = &&t1;
var T2&& x2 = ( t as T2&&);
_assert(x2 == null);

escape 10;
]],
    run = 10;
}

Test { [[
interface I with
end
class Tx with
    var I&& parent;
do
end
class U with
do
    var Tx move with
        this.parent = &&outer;
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
vector[10] I a;
]],
    tmp = 'line 3 : cannot instantiate an interface',
}

Test { [[
interface I with
    var int i;
end

interface J with
    interface I;
end

var I&& i = null;
var J&& j = i;

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
class Tx with
    event int a_;
    var Global&& g;
do
    await OS_START;
    emit g:a_(10);
end
var U u;
var Global&& g = &&u;
var Tx t;
t.g = &&u;
var int v = await g:a_;
escape v;
]],
    todo = 'watching',
    run = 10,
}

Test { [[
interface Global with
    var int&& a;
end
var int&& a=null;
var int&& b=null;
b = global:a;
do
    var int&& c;
    c = global:a;
    if c == null then end;
end
escape 1;
]],
    run = 1,
}
Test { [[
interface Global with
    var int&& a;
end
var int&& a=null;
var int&& b=null;
global:a = b;       // don't use global
do
    var int&& c=null;
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
    var int&& a;
end
var int&& a=null;
var int&& b=null;
global:a = b;       // don't use global
do
    var int&& c=null;
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
    var int&& a;
end
var int&& a = null;
class Tx with
do
    var int&& b;
    b = global:a;
end
escape 1;
]],
    fin = 'line 8 : unsafe access to pointer "a" across `class´ (/tmp/tmp.ceu : 5)',
    --run = 1,
}
Test { [[
interface Global with
    var int&& a;
end
var int&& a = null;
class Tx with
do
    var int&& b=null;
    global:a = b;
end
escape 1;
]],
    fin = 'line 8 : attribution to pointer with greater scope',
    --fin = 'line 7 : unsafe access to pointer "a" across `class´ (/tmp/tmp.ceu : 4)',
    --fin = 'line 7 : organism pointer attribution only inside constructors',
}

Test { [[
input void OS_START;
interface Global with
    event int a;
end
event int a;
class Tx with
    event int a;
do
    await OS_START;
    emit global:a(10);
end
var Tx t;
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
var int aa = 0;
class Tx with
    event int a;
    var int aa=0;
do
    aa = await global:a;
end
var Tx t;
await OS_START;
emit a(10);
escape t.aa;
]],
    run = 10,
}

Test { [[
interface Global with
    var int v;
end
var int v;

class Tx with
    var int v = 1;
do
    this.v = global:v;
end
var Tx t;

escape t.v;
]],
    tmp = 'line 4 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:6)',
    --ref = 'line 9 : invalid access to uninitialized variable "v" (declared at /tmp/tmp.ceu:2)',
}

Test { [[
interface Global with
    var int v;
end
var int v;

class Tx with
    var int v = 1;
do
    //this.v = global:v;
end
var Tx t;

escape v;
]],
    tmp = 'line 4 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:6)',
    --ref = 'line 13 : invalid access to uninitialized variable "v" (declared at /tmp/tmp.ceu:4)',
}

Test { [[
interface Global with
    var int v;
end
var int v;

class Tx with
    var int v = 1;
do
    //this.v = global:v;
end
var Tx t;

escape t.v;
]],
    tmp = 'line 4 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:6)',
    --run = 1,
}

Test { [[
interface Global with
    var int v;
end
var int v=0;

class Tx with
    var int v = 1;
do
    //this.v = global:v;
end
var Tx t;

escape t.v;
]],
    run = 1,
}

Test { [[
interface Global with
    var int v;
end

class Tx with
    var int v = 1;
do
    //this.v = global:v;
end
var Tx t;

var int v=0;
escape t.v;
]],
    run = 1,
}

-- use of global before its initialization
Test { [[
interface Global with
    var& int vvv;
end

class Tx with
    var int v = 1;
do
    this.v = global:vvv;
end
var Tx t;

var int  um = 111;
var& int vvv = &um;
escape t.v;
]],
    tmp = 'line 8 : invalid access to uninitialized variable "vvv" (declared at /tmp/tmp.ceu:2)',
}

Test { [[
class Tx with
    var int a=0;
do
    a = global:a;
end
var int a = 10;
var Tx t;
input void OS_START;
await OS_START;
t.a = t.a + a;
escape t.a;
]],
    tmp = 'line 4 : interface "Global" is not defined',
}

Test { [[
interface Global with
    var int a;
end
class Tx with
    var int a=0;
do
    a = global:a;
end
do
    var int a = 10;
    var Tx t;
input void OS_START;
await OS_START;
    t.a = t.a + a;
    escape t.a;
end
]],
    tmp = 'line 1 : interface "Global" must be implemented by class "Main"',
}

Test { [[
interface Global with
    var int a;
end
var int a = 10;
class Tx with
    var int a=0;
do
    a = global:a;
end
do
    var Tx t;
input void OS_START;
await OS_START;
    t.a = t.a + a;
    escape t.a;
end
]],
    run = 20,
}

Test { [[
native/nohold _attr;
native/pos do
    void attr (void* org) {
        IFC_Global_a() = CEU_T_a(org) + 1;
    }
end

interface Global with
    var int a;
end
class Tx with
    var int a=0;
do
    a = global:a;
    _attr(this);
    a = a + global:a + this.a;
end
var int a = 10;
do
    var Tx t;
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
native/pos do
    int fff (CEU_T* t, int v) {
        escape CEU_T_fff(NULL, t, v);
    }
    int iii (CEU_III* i, int v) {
        escape CEU_III__fff(i)(NULL, i, v);
    }
    int vvv (CEU_III* i) {
        escape *CEU_III__vvv(i);
    }
end
native/pure _fff, _iii, _vvv;

interface III with
    var int vvv;
    code/tight Fff (var int)=>int;
end

class Tx with
    var int vvv;
    code/tight Fff (var int)=>int;
do
    code/tight Fff (var int v)=>int do
        escape this.vvv + v;
    end
    await FOREVER;
end

var Tx t with
    this.vvv = 100;
end;

var III&& i = &&t;

escape t.fff(10) + _fff(&&t, 10) + _iii(i, 10) + _vvv(i);
]],
    run = 430,
}

Test { [[
native/pos do
    int V = 10;
end

interface Global with
    event void e;
end
event void e;

class Tx with
do
    emit global:e;
    _V = 1;
end

par/or do
    event void a;
    par/or do
        await 1s;
        do
            var Tx t;
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
    tmp = 'line 4 : cannot instantiate an interface',
}

Test { [[
interface Global with
    event void e;
end
event void e;

class Tx with
do
    emit global:e;
end

var int ret = 0;
par/or do
    await 1s;
    do
        var Tx t;
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
vector[10] I t;
escape 10;
]],
    tmp = 'line 4 : cannot instantiate an interface',
}

Test { [[
interface I with
    event int a;
end
var I&&? t;
t = spawn I;
escape 10;
]],
    tmp = 'line 5 : cannot instantiate an interface',
}

Test { [[
class Tx with
do
end

interface I with
    event int a;
end

var I&& i;
var Tx t;
i = &&t;
escape 10;
]],
    tmp = 'line 11 : types mismatch',
}

Test { [[
class Tx with
    event void a;
do
end

interface I with
    event int a;
end

var I&& i;
var Tx t;
i = &&t;
escape 10;
]],
    tmp = 'line 12 : types mismatch',
}

Test { [[
class Tx with
    event int a;
do
end

interface I with
    event int a;
end

var I&& i;
var Tx t;
i = t;
escape 10;
]],
    tmp = 'line 12 : types mismatch',
}

Test { [[
class Tx with
    event int a;
do
end

interface I with
    event int a;
end

var I&& i;
var Tx t;
i = &&t;
escape 10;
]],
    run = 10,
    --ref = 'line 10 : uninitialized variable "i" crossing compound statement (/tmp/tmp.ceu:11)',
}

Test { [[
class Tx with
    event int a;
do
end

interface I with
    event int a;
end

var Tx t;
var I&& i;
i = &&t;
escape 10;
]],
    run = 10;
}

Test { [[
class Tx with
    event int a;
do
end

interface I with
    event int a;
end
interface J with
    event int a;
end

var Tx t;
var I&& i;
i = &&t;
var J&& j = i;
escape 10;
]],
    run = 10;
}

Test { [[
class Tx with
    event int a;
do
end

interface I with
    event int a;
end
interface J with
    event u8 a;
end

var I&& i;
var Tx t;
i = &&t;
var J&& j = i;
escape 10;
]],
    tmp = 'line 16 : types mismatch',
}

Test { [[
class Tx with
    var int v;
    var int&& x;
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

var I&& i;
var Tx t;
i = &&t;
var J&& j = i;
escape 0;
]],
    tmp = 'line 6 : types mismatch',
}

Test { [[
input void OS_START;
class Tx with
    event int a;
    var int aa=0;
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

var Tx t;
var I&& i;
i = &&t;
var J&& j = i;
escape i:aa + j:aa + t.aa;
]],
    run = 30,
}

Test { [[
input void OS_START;
class Tx with
    event int a;
    var int aa=0;
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

var Tx t;
var I&& i;
i = &&t;
var J&& j = i;
await OS_START;
escape i:aa + j:aa + t.aa;
]],
    fin = 'line 23 : unsafe access to pointer "i" across `await´',
}

Test { [[
input void OS_START;
class Tx with
    var int v=0;
    var int&& x=null;
    var int a=0;
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

var Tx t;
var I&& i;
i = &&t;
var J&& j = i;
escape i:a + j:a + t.a + i:v + t.v;
]],
    run = 32,
}

Test { [[
input void OS_START;
class Tx with
    var int v=0;
    var int&& x=null;
    var int a=0;
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

var Tx t;
var I&& i;
i = &&t;
var J&& j = i;
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
    var Sm&& sm;
end
escape 10;
]],
    run = 10;
}

Test { [[
interface I with
    var int a;
end
class Tx with
    interface J;
do
    a = 10;
end
var Tx t;
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
    var MenuGamesListener&& lst = &&this;
    if lst==null then end;
end
escape 1;
]],
    run = 1,
}

Test { [[
interface I with
    var int a;
end
class Tx with
    interface I;
    var int a=0;
do
    a = 10;
end
var Tx t;
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

class Tx with
    var int v;
do
end

var Tx t;
    t.v = 10;
var I&& i = &&t;
escape t._ins();
]],
    --env = 'line 13 : native function "CEU_T__ins" is not declared',
    dcls = 'line 13 : internal identifier "_ins" is not declared',
}
Test { [[
interface I with
    var int v;
end

class Tx with
    var int v;
do
end

var Tx t;
    t.v = 10;
var I&& i = &&t;
escape i:_ins();
]],
    --env = 'line 13 : native function "CEU_I__ins" is not declared',
    dcls = 'line 13 : internal identifier "_ins" is not declared',
}
Test { [[
class Tx with do end
class U with
    interface Tx;
do
end
escape 0;
]],
    adj = 'line 3 : interface "Tx" is not declared',
}

Test { [[
interface Global with
    var Gx&& g;
end
var Gx&& g;
escape 1;
]],
    tmp = 'line 2 : undeclared type `Gx´',
}

Test { [[
interface Global with
    event (Gx&&,int) g;
end
event (Gx&&,int) g;
escape 1;
]],
    tmp = 'line 2 : invalid event type'
    --env = 'line 2 : undeclared type `Gx´',
    --run = 1,
    --gcc = '22:2: error: unknown type name ‘Gx’',
    --gcc = 'error: unknown type name',
}

Test { [[
interface I with
native _char;
    var _char c;
end
class Tx with
    interface I;
    var _char c=0;
do
    this.c = 1;
end
var Tx t;
var I&& i = &&t;
escape i:c == 1;
]],
    run = 1,
}

-- XXX: Tx-vs-Opt

Test { [[
input _vldoor_t&& T_VERTICAL_DOOR;
class T_VerticalDoor with
    var void&& v;
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
    --env = 'line 11 : invalid attribution (void&& vs _vldoor_t&&)',
    --fin = 'line 11 : attribution to pointer with greater scope',
    --fin = 'line 9 : invalid block for awoken pointer "door"',
    run = false,
    _ana = {
        isForever = true,
    },
}

Test { [[
input _vldoor_t&& T_VERTICAL_DOOR;
class T_VerticalDoor with
    var void&& v;
do
end

do
    every door in T_VERTICAL_DOOR do
        spawn T_VerticalDoor with
            this.v = door as void&&;
        end;
    end
end
]],
    --fin = 'line 11 : attribution to pointer with greater scope',
    --fin = 'line 9 : invalid block for awoken pointer "door"',
    run = false,
    _ana = {
        isForever = true,
    },
}

Test { [[
class Tx with
    var void&& v=null;
do
end

var Tx t;
t.v = null;
var void&& ptr = null;
t.v = ptr;
escape 1;
]],
    --fin = 'line 9 : organism pointer attribution only inside constructors',
    --fin = 'line 9 : attribution to pointer with greater scope',
    run = 1,
}
Test { [[
class Tx with
    var void&& v;
do
end

var Tx t with
    this.v = null;
end;
var void&& ptr = null;
t.v = ptr;
escape 1;
]],
    --fin = 'line 10 : organism pointer attribution only inside constructors',
    --fin = 'line 9 : attribution to pointer with greater scope',
    run = 1,
}

Test { [[
class Tx with
    var void&& v=null;
do
end

var Tx t, s;
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
    var I&& t;
end

var I&& t = null;

class Tx with
do
    global:t = &&this;
end

escape 1;
]],
    --fin = 'line 10 : attribution requires `finalize´'
    fin = 'line 12 : attribution to pointer with greater scope',
    --fin = 'line 10 : organism pointer attribution only inside constructors',
}

Test { [[
native/pos do
    void* v;
end
class Tx with
    var& _void ptr;
do
end
var Tx t with
    this.ptr = &_v;
end;
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    var byte && str;
do
    str = "oioi";
    this.str = "oioi";
end
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
do
end
var int&& p1=null;
var& int&&  v=&p1;
var Tx&& p=null;
var& Tx&&  t=&p;
escape 1;
]],
    run = 1;
}

Test { [[
class Tx with
do
end
var& int && v;
var& Tx && t;
escape 1;
]],
    tmp = 'line 4 : invalid type modifier : `&&&´',
}

Test { [[
class Tx with
    var byte&& str;
do
end

do
    spawn Tx with
        var byte&& s = "str";
        this.str = s;
    end;
end

escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    var int&& v;
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
    var int&& a;
end
var int&& a = null;
class Tx with
    var int&& v;
do
end
var Tx t with
    this.v = global:a;
end;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
interface Global with
    var int&& a;
end
var int&& a = null;
class Tx with
    var int&& v;
do
end
await OS_START;
var Tx t with
    this.v = global:a;
end;
escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
interface Global with
    var int&& p;
end
var int i = 1;
var int&& p = null;
await OS_START;
p = p;
escape *p;
]],
    fin = 'line 8 : unsafe access to pointer "p" across `await´',
}

Test { [[
input void OS_START;
interface Global with
    var int&& p;
end
var int i = 1;
var int&& p = null;
await OS_START;
p = &&i;
escape *p;
]],
    run = 1,
}

Test { [[
input void OS_START;
class Tx with
    var int&& p;
do
end
var int i = 1;
var Tx t with
    this.p = null;
end;
await OS_START;
t.p = &&i;
escape *t.p;
]],
    run = 1,
    --fin = 'line 11 : unsafe access to pointer "p" across `await´',
}

Test { [[
native/pos do
    void* V;
end
class Tx with
    code/tight Fx (var void&& v)=>void;
do
    code/tight Fx (var void&& v)=>void do
        _V = v;
    end
end
escape 1;
]],
    --fin = 'line 8 : invalid attribution',
    run = 1,
}

Test { [[
native/plain _pkt_t;
class Forwarder with
    var _pkt_t out = _pkt_t();
do
end

native/nohold _memcpy;

input _pkt_t&& RECEIVE;

every inc in RECEIVE do
    spawn Forwarder with
        _memcpy(&&this.out, inc, inc:len);
    end;
end
]],
    run = false,
    _ana = {
        isForever = true,
    },
}

Test { [[
class Unit with
    var _SDL_Texture&& tex;
do
end

interface Global with
    pool[] Unit all;
end

pool[] Unit all;

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
interface I with
    var int v;
end
class Tx with
    var& I parent;
    pool[1] I iss;
do
    if &&parent==null then end;
    await 1s;
end
escape 1;
]],
    run = 1,
}

Test { [[
interface I with end
class Tx with do end
pool[] Tx ts;
do
    loop i in ts do
native _f;
        _f(i);
    end
end
]],
    fin = 'line 6 : call requires `finalize´',
}

Test { [[
interface I with end
class Tx with do end
pool[] Tx ts;
var I&& p=null;
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
pool[] CUnit us;
loop u in us do
end
escape 1;
]],
    run = 1,
}

Test { [[
class Unit with do end
pool[] Unit us;
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
pool[] Unit us;
var Unit&& p=null;
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
pool[] I iss;
native/nohold _f;
native/pos do
    void f (void* p) {
    }
end
do
    loop i in iss do
        _f(i);
    end
end
escape 10;
]],
    run = 10,
}

Test { [[
class I with do end
pool[] I iss;
native _f;
native/pos do
    void f (void* p) {
    }
end
do
    loop i in iss do
        do _f(i); finalize with nothing; end;
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

class Tx with
    interface I;
do
    await FOREVER;
end

pool[] Tx ts;
var int ret = 0;
do
    spawn Tx in ts with
        this.v = 1;
    end;
    spawn Tx in ts with
        this.v = 2;
    end;
    spawn Tx in ts with
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

class Tx with
    interface I;
    var int v=0;
do
    await FOREVER;
end

class U with
    var int v=0;
do
    await FOREVER;
end

var Tx t;
var U u;

var I&& i1 = &&t;
var I&& i2 = (&&u as I&&);

native/pure _f;
native/pos do
    void* f (void* org) {
        escape org;
    }
end

var I&& i3 = ( _f(&&t) as I&&);
var I&& i4 = ( _f(&&u) as I&&);

var Tx&& i5 = ( _f(&&t) as Tx&&);
var Tx&& i6 = ( _f(&&u) as Tx&&);

escape i1==&&t and i2==null and i3==&&t and i4==null and i5==&&t and i6==null;
]],
    run = 1,
}
Test { [[
interface I with
    var int v;
    event void inc;
end

class Tx with
    interface I;
do
    await FOREVER;
end
pool[] Tx ts;

class U with
    var int v;
do
    await FOREVER;
end

var int ret = 0;
do
    spawn Tx with
        this.v = 1;
    end;
    spawn U with
        this.v = 2;
    end;
    spawn Tx in ts with
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

class Tx with
    interface I;
do
    await FOREVER;
end

pool[] I iss;

var int ret = 0;

spawn Tx with
    this.v = 1;
end;

spawn Tx in iss with
    this.v = 3;
end;

loop i in iss do
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

pool[] I iss;

class Tx with
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
    spawn Tx with
        this.v = 1;
    end;
    spawn U in iss with
        this.v = 2;
    end;
    spawn Tx in iss with
        this.v = 3;
    end;

    loop i in iss do
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

class Tx with
    interface I;
do
end
pool[] Tx ts;

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

class Tx with
    interface I;
do
end
pool[] Tx ts;

var int ret = 1;
do
    spawn Tx in ts with
        this.v = 1;
    end;
    spawn Tx in ts with
        this.v = 2;
    end;
    spawn Tx in ts with
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
input void A,B;

interface I with
    var int v;
    event void inc;
end

class Tx with
    interface I;
do
    await inc;
    this.v = v + 1;
end

pool[] Tx ts;
var int ret = 1;
do
    spawn Tx in ts with
        this.v = 1;
    end;
    spawn Tx in ts with
        this.v = 2;
    end;
    spawn Tx in ts with
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
    props = 'line 28 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = 7,
    --run = 13,
}
Test { [[
input void A,B;

interface I with
    var int v;
    event void inc;
end

class Tx with
    interface I;
do
    await inc;
    this.v = v + 1;
    await FOREVER;
end

pool[] Tx ts;
var int ret = 1;
do
    spawn Tx in ts with
        this.v = 1;
    end;
    spawn Tx in ts with
        this.v = 2;
    end;
    spawn Tx in ts with
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
    props = 'line 29 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = 7,
    --run = 13,
}
Test { [[
input void A,B;

interface I with
    var int v;
    event void inc;
end

class Tx with
    interface I;
do
    await inc;
    this.v = v + 1;
    await FOREVER;
end
pool[] Tx ts;

var int ret = 0;
do
    par/or do
        await B;
    with
        var int i=1;
        every 1s do
            spawn Tx in ts with
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
    props = 'line 32 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = { ['~>3s;~>B'] = 16 },
    --run = { ['~>3s;~>B'] = 13 },
}

Test { [[
class Tx with
    var int a;
do
end
pool[] Tx ts;

do
    loop t in ts do
        t:a = 1;
    end
end

escape 10;
]],
    run = 10;
}

Test { [[
class Tx with
    event void e;
do
    await FOREVER;
end

event void f;

var Tx t;

par do
    par/or do
        await t.e;
    with
        await 1s;
        emit t.e;
    end
    emit f;
    escape -1;
with
    await f;
    escape 10;
end
]],
    run = { ['~>10s'] = 10 },
}

Test { [[
native/pos do
    int f() { escape 1; }
end
class Tx with do end
spawn Tx with
native _int;
            var& _int? intro_story_str;
native _f;
                do intro_story_str = &_f();
            finalize with
            end
    end;
escape 1;
]],
    cc = '24: note: expected ‘int *’ but argument is of type ‘int’',
    --run = 1,
}

Test { [[
native/pos do
    int V = 10;
    int* getV (void) {
        escape &V;
    }
end

var& int? v;
    do v = &_getV();
finalize with
    nothing;
end

class Tx with
    var& int v;
do
    v = 20;
end
do Tx with
    this.v = &v;
end;

escape v!;
]],
    tmp = 'line 21 : invalid operand to unary "&" : cannot be aliased',
}
Test { [[
input int&& SPRITE_DELETE;
class Sprite with
    var& int me;
do
    par/or do
        await SPRITE_DELETE until &&this.me==null;
    with
    end
end
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
par/or do
input int&& SPRITE_DELETE;
var int&& me = await SPRITE_DELETE
               until me == null;
with
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
class Tx with do end
vector[1] Tx ts = [];
escape 1;
]],
    tmp = 'line 2 : invalid attribution : destination is not a vector',
}
Test { [[
class Tx with do end
pool[10] Tx ts;
escape $$ts;
]],
    tmp = 'line 3 : invalid operand to unary "$$" : vector expected',
}

Test { [[
class Tx with do end
pool[10] Tx ts;
escape $ts;
]],
    tmp = 'line 3 : invalid operand to unary "$" : vector expected',
}

Test { [[
class Tx with
    vector&[] int v1;
    vector[] int  v2;
do
    if &&v1==null then end;
end
escape 1;
]],
    run = 1,
    --props = 'line 3 : not permitted inside an interface',
}
Test { [[
class Tx with
    vector[] int  v2;
do
    await FOREVER;
end
var Tx t with
    this.v2 = [1,2,3];
end;
escape t.v2[0]+t.v2[2];
]],
    run = 4,
}

Test { [[
input int&& SDL_KEYDOWN_;
event bool in_tm;

pause/if in_tm do
    class Input with
    do
        await SDL_KEYDOWN_ ;
    end
end

escape 1;
]],
    run = 1,
}

-->>> METHODS

Test { [[
class Tx with
    var int a;
    code/tight Fx (void)=>int;
do
    var int b;
    code/tight Fx (void)=>int do
        escape b;
    end
    a = 1;
    b = 2;
end

var Tx t;
escape t.a + t.f();
]],
    tmp = 'line 7 : invalid access to uninitialized variable "b" (declared at /tmp/tmp.ceu:5)',
}
Test { [[
class Tx with
    var int a=0;
    code/tight Fx (void)=>int;
do
    var int b=0;
    code/tight Fx (void)=>int do
        escape b;
    end
    a = 1;
    b = 2;
end

var Tx t;
escape t.a + t.f();
]],
    run = 3,
}

Test { [[
interface I with
    var int v;
    native _f, _a;      // TODO: refuse _a
end
escape 10;
]],
    parser = 'line 2 : after `;´ : expected `var´ or `vector´ or `pool´ or `event´ or `code/tight´ or `code/await´ or `interface´ or `input/output´ or `output/input´ or `input´ or `output´ or `end´',
    --run = 10,
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    var int x;
    this.x = 10;
    _V = this.x;
end
var Tx t;
escape _V;
]],
    run = 10,
}

Test { [[
class Tx with do end;

code/tight Fff (void)=>void do
    var Tx&& ttt = null;
    if ttt==null then end;
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
native/pos do
    int V = 0;
end
class Tx with
    code/tight Fx (var int a, var  int b)=>int do
        escape a + b;
    end
do
    _V = _V + f(1,2) + this.f(3,4);
end
vector[2] Tx ts;
escape _V;
]],
    parser = 'line 5 : after `int´ : expected type modifier or `;´',
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    code/tight Fx (var int a, var  int b)=>int do
        escape a + b;
    end
    _V = _V + f(1,2) + this.f(3,4);
end
vector[2] Tx ts;
escape _V;
]],
    run = 20,
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
do
    var int v=0;
    code/tight Fx (var int a, var  int b)=>void do
        this.v = this.v + a + b;
    end
    f(1,2);
    this.f(3,4);
    _V = _V + v;
end
vector[2] Tx ts;
escape _V;
]],
    run = 20,
}

Test { [[
class Tx with
    var int a=0;
    code/tight Fx (void)=>int;
do
    var int b=0;
    code/tight Fx (void)=>int do
        escape this.b;
    end
    a = 1;
    b = 2;
end

var Tx t;
escape t.a + t.f();
]],
    run = 3,
}
Test { [[
class Tx with
    var int a=0;
    code/tight Fx (void)=>int do
        escape this.b;
    end
do
    var int b;
    a = 1;
    b = 2;
end

var Tx t;
escape t.a + t.f();
]],
    parser = 'line 3 : after `int´ : expected type modifier or `;´',
}

Test { [[
interface I with
    var int v;
    code/tight Fx (void)=>void;
end
escape 10;
]],
    run = 10,
}

Test { [[
class Tx with
    var int v=0;
    code/tight Fx (var int)=>void;
do
    v = 50;
    this.f(10);

    code/tight Fx (var int v)=>int do
        this.v = this.v + v;
        escape this.v;
    end
end

var Tx t;
input void OS_START;
await OS_START;
escape t.v + t.f(20) + t.v;
]],
    wrn = true,
    tmp = 'line 8 : function declaration does not match the one at "/tmp/tmp.ceu:3"',
}

Test { [[
class Tx with
    var int v=0;
    code/tight Fx (var int)=>int;
do
    v = 50;
    this.f(10);

    code/tight Fx (var int v)=>int do
        this.v = this.v + v;
        escape this.v;
    end
end

var Tx t;
input void OS_START;
await OS_START;
escape t.v + t.f(20) + t.v;
]],
    wrn = true,
    run = 220,
}

Test { [[
interface I with
    code/tight Fx (void)=>int;
    code/tight Fa (void)=>int;
end

class Tx with
    interface I;
do
    code/tight Fx (void)=>int do
        escape this.f1();
    end
    code/tight Fa (void)=>int do
        escape 1;
    end
end

var Tx t;
var I&& i = &&t;
escape t.f() + i:f();
]],
    tight = 'line 2 : function must be annotated as `@rec´ (recursive)',
}

Test { [[
interface I with
    code/tight Fa (void)=>int;
    code/tight Fx (void)=>int;
end

class Tx with
    interface I;
do
    code/tight Fa (void)=>int do
        escape 1;
    end
    code/tight Fx (void)=>int do
        escape this.f1();
    end
end

var Tx t;
var I&& i = &&t;
escape t.f() + i:f();
]],
    run = 2,
}

Test { [[
interface I with
    code/tight Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight Gx (var int v)=>int do
        if (v == 1) then
            escape 1;
        end
        escape v * i:g(v-1);
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape i:g(5);
]],
    --run = 120,
    tight = 'line 9 : function must be annotated as `@rec´ (recursive)',
}

Test { [[
interface I with
    code/tight/recursive Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i;
do
    code/tight Gx (var int v)=>int do
        if (v == 1) then
            escape 1;
        end
        escape v * i:g(v-1);
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape i:g(5);
]],
    --run = 120,
    tmp = 'line 9 : function declaration does not match the one at "/tmp/tmp.ceu:2"',
}

Test { [[
interface I with
    code/tight Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i;
do
    code/tight/recursive Gx (var int v)=>int do
        if (v == 1) then
            escape 1;
        end
        escape v * i:g(v-1);
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape i:g(5);
]],
    --run = 120,
    tmp = 'line 9 : function declaration does not match the one at "/tmp/tmp.ceu:2"',
}

Test { [[
interface I with
    code/tight Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight Gx (var int v)=>int do
        if (v == 1) then
            escape 1;
        end
        escape v * i:g(v-1);
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape i:g(5);
]],
    --run = 120,
    tight = 'line 9 : function must be annotated as `@rec´ (recursive)',
}

Test { [[
interface I with
    code/tight/recursive Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight/recursive Gx (var int v)=>int do
        if (v == 1) then
            escape 1;
        end
        escape v * (call/recursive i:g(v-1));
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape call/recursive i:g(5);
]],
    run = 120,
}

Test { [[
interface I with
    code/tight/recursive Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight/recursive Gx (var int v)=>int do
        if (v == 1) then
            escape 1;
        end
        escape v * i:g(v-1);
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape i:g(5);
]],
    --run = 120,
    tight = 'line 13 : `call/recursive´ is required for "g"',
}

Test { [[
interface I with
    code/tight/recursive Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight/recursive Gx (var int v)=>int do
        escape 1;
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape i:g(5);
]],
    tight = 'line 9 : function may be declared without `recursive´',
    --tight = 'line 17 : `call/recursive´ is required for "g"',
}
Test { [[
interface I with
    code/tight/recursive Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight/recursive Gx (var int v)=>int do
        escape 1;
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape i:g(5);
]],
    wrn = true,
    tight = 'line 17 : `call/recursive´ is required for "g"',
}

Test { [[
interface I with
    code/tight/recursive Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight/recursive Gx (var int v)=>int do
        escape v;
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape call/recursive i:g(5);
]],
    --fin = 'line 16 : organism pointer attribution only inside constructors',
    --fin = 'line 16 : attribution to pointer with greater scope',
    --tight = 'line 9 : function may be declared without `recursive´',
    wrn = true,
    run = 5,
}

Test { [[
interface I with
    code/tight/recursive Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight/recursive Gx (var int v)=>int do
        escape v;
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape call/recursive i:g(5);
]],
    --fin = 'line 16 : organism pointer attribution only inside constructors',
    --tight = 'line 9 : function may be declared without `recursive´',
    wrn = true,
    run = 5,
}

Test { [[
interface I with
    code/tight Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight Gx (var int v)=>int do
        escape v;
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape i:g(5);
]],
    --fin = 'line 16 : organism pointer attribution only inside constructors',
    --fin = 'line 16 : attribution to pointer with greater scope',
    run = 5,
}

Test { [[
interface I with
    code/tight Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight Gx (var int v)=>int do
        escape v;
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape i:g(5);
]],
    --fin = 'line 16 : organism pointer attribution only inside constructors',
    run = 5,
}

Test { [[
interface I with
    code/tight Gx (var int)=>int;
end

class U with
    interface I;
    var I&& i=null;
do
    code/tight Gx (var int v)=>int do
        escape 1;
    end
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight Gx (var int v)=>int do
        if (v == 1) then
            escape 1;
        end
        escape v * i:g(v-1);
    end
end

var Tx t;
var I&& i1 = &&t;
t.i = i1;

var U u;
var I&& i2 = &&u;
t.i = i2;

escape i1:g(5) + i2:g(5);
]],
    --run = 120,
    tight = 'line 18 : function must be annotated as `@rec´ (recursive)',
}

Test { [[
interface I with
    code/tight Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight/recursive Gx (var int v)=>int do
        if (v == 1) then
            escape 1;
        end
        escape v * i:g(v-1);
    end
end

escape 1;
]],
    --run = 120,
    tmp = 'line 9 : function declaration does not match the one at "/tmp/tmp.ceu:2"',
}

Test { [[
interface I with
    code/tight Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight Gx (var int v)=>int do
        if (v == 1) then
            escape 1;
        end
        escape v * i:g(v-1);
    end
end

class U with
    interface I;
    var I&& i=null;
do
    code/tight Gx (var int v)=>int do
        escape 1;
    end
end

var Tx t;
var I&& i1 = &&t;
t.i = i1;

var U u;
var I&& i2 = &&u;
t.i = i2;

escape i1:g(5) + i2:g(5);
]],
    --run = 120,
    tight = 'line 9 : function must be annotated as `@rec´ (recursive)',
}


Test { [[
interface I with
    code/tight/recursive Gx (var int)=>int;
end

class Tx with
    interface I;
    var I&& i=null;
do
    code/tight/recursive Gx (var int v)=>int do
        if (v == 1) then
            escape 1;
        end
        escape v * i:g(v-1);
    end
end

var Tx t;
var I&& i = &&t;
t.i = i;
escape i:g(5);
]],
    tight = 'line 13 : `call/recursive´ is required for "g"',
    --run = 120,
}

Test { [[
native/pre do
    typedef int (*f_t) (int v);
end

class Tx with
    var int ret1=0, ret2=0;
    code/tight Fa (var int)=>int;
    var _f_t f2;
do
    native/pos do
        int f2 (int v) {
            escape v;
        }
    end

    code/tight Fa (var int v)=>int do
        escape v;
    end

    ret1 = this.f1(1);
    ret2 = this.f2(2);
end

var Tx t with
    this.f2 = _f2;
end;
escape t.ret1 + t.ret2;
]],
   --fin = 'line 25 : attribution to pointer with greater scope',
    run = 3,
}

Test { [[
native/pre do
    typedef int (*f_t) (int v);
end

class Tx with
    var int ret1=0, ret2=0;
    code/tight Fa (var int)=>int;
    var _f_t f2;
do
    native/pos do
        int f2 (int v) {
            escape v;
        }
    end

    code/tight Fa (var int v)=>int do
        escape v;
    end

    ret1 = this.f1(1);
    ret2 = this.f2(2);
end

var Tx t with
    this.f2 = _f2;
end;
escape t.ret1 + t.ret2;
]],
    run = 3,
}

Test { [[
interface I with
    var int v;
    code/tight Ins (void)=>void;
end

class Tx with
    var int v=0;
do
end

var Tx t;
    t.v = 10;
var I&& i = &&t;
escape i:_ins() + t._ins();;
]],
    --env = 'line 14 : native function "CEU_T__ins" is not declared',
    tmp = 'line 13 : types mismatch (`I&&´ <= `Tx&&´)',
}

Test { [[
interface I with
    var int v;
    code/tight Ins (void)=>int;
end

class Tx with
    interface I;
    var int v=0;
    //native/nohold _ins;
do
    code/tight Ins (void)=>int do
        escape v;
    end
end

var Tx t;
    t.v = 10;
var I&& i = &&t;
escape i:ins() + t.ins();
]],
    run = 20,
}

Test { [[
interface Fx with
    code/tight Fx (void)=>void;
    var int i=10;
end
]],
    tmp = 'line 3 : invalid attribution',
}

Test { [[
interface Fx with
    var int i;
    code/tight Fx (var int i)=>void;
end

class Tx with
    var int i=10;   // 1
    interface Fx;
do
    this.f(1);
    code/tight Fx (var int i)=>void do
        this.i = this.i + i;
    end
end

var Tx t1;

var Fx&& f = &&t1;
f:f(3);

escape t1.i + f:i;
]],
    wrn = true,
    run = 28,
}

Test { [[
interface Fx with
    var int i;
    code/tight Fx (var int)=>void;
end

class Tx with
    interface Fx;
    var int i=10;   // 2
do
    this.f(1);
    code/tight Fx (var int i)=>void do
        this.i = this.i + i;
    end
end

var Tx t1;

var Fx&& f = &&t1;
f:f(3);

escape t1.i + f:i;
]],
    wrn = true,
    run = 28,
}

Test { [[
native _V;
native/pos do
    void* V;
end
code/tight Fx (var void&& v)=>void do
    _V = v;
end
escape 1;
]],
    wrn = true,
    scopes = 'line 6 : invalid pointer assignment : expected `finalize´',
    --fin = 'line 5 : attribution to pointer with greater scope',
    --fin = 'line 5 : invalid attribution',
}

Test { [[
native/pos do
    void* V;
end
code/tight Fx (var void&& v)=>void do
    if v!=null then end;
end
escape 1;
]],
    wrn = true,
    -- function can be "@nohold v"
    run = 1,
}

Test { [[
native/pos do
    void* V;
end
class Tx with
    code/tight Fx (var void&& v)=>void;
do
    code/tight Fx (var void&& v)=>void do
native _V;
        _V = v;
    end
end
escape 1;
]],
    wrn = true,
    --fin = 'line 8 : invalid attribution',
    fin = 'line 8 : attribution to pointer with greater scope',
}

Test { [[
class Tx with
    var void&& v=null;
    code/tight Fx (var void&& v)=>void;
do
    code/tight Fx (var void&& v)=>void do
        if v!=0 then end;
    end
end
var Tx t;
t.f(null);
escape 1;
]],
    -- function can be "@nohold v"
    wrn = true,
    run = 1,
}

Test { [[
class Tx with
    var void&& a=null;
    code/tight Fx (var void&& v)=>void;
do
    code/tight Fx (var void&& v)=>void do
        var void&& a = v;
        if a!=0 then end;
    end
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
class Tx with
    var void&& a=null;
    code/tight Fx (void)=>void;
do
    code/tight Fx (void)=>void do
        var void&& v=null;
        a = v;
    end
end
escape 1;
]],
    -- not from paramter
    fin = 'line 7 : attribution to pointer with greater scope',
}
Test { [[
class Tx with
    var void&& a=null;
    code/tight Fx (var void&& v)=>void;
do
    code/tight Fx (var void&& v)=>void do
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
class Tx with
    var void&& a=null;
    code/tight Fx (var void&& v)=>void;
do
    code/tight Fx (var void&& v)=>void do
        a := v;
    end
end
escape 1;
]],
    -- function must be "@hold v"
    fin = ' line 6 : parameter must be `hold´',
}
Test { [[
class Tx with
    var void&& a=null;
    code/tight Fx (var/hold void&& v)=>void;
do
    code/tight Fx (var/hold void&& v)=>void do
        a := v;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    var void&& v=null;
    code/tight Fx (var void&& v)=>void;
do
    code/tight Fx (var/hold void&& v)=>void do
        this.v = v;
    end
end
escape 1;
]],
    wrn = true,
    tmp = 'line 5 : function declaration does not match the one at "/tmp/tmp.ceu:3"',
}

Test { [[
class Tx with
    var void&& v=null;
    code/tight Fx (var/hold void&& v)=>void;
do
    code/tight Fx (var/hold void&& v)=>void do
        this.v := v;
    end
end
var void&& v=null;
var Tx t;
t.f(null);
t.f(v);
do
    var void&& v=null;
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
class Tx with
    var void&& v=null;
    code/tight Fx (var/hold void&& v)=>void;
do
    code/tight Fx (var/hold void&& v)=>void do
        this.v := v;
    end
end
var void&& v=null;
var Tx t;
t.f(null);
t.f(v);
do
    var void&& v=null;
    do t.f(v);
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
native/pos do
    void* V;
end
native _V;
code/tight Fx (var void&& v)=>void do
    _V := v;
end
var void&& x=null;
call Fx(5 as void&&);
escape (_V==(5 as void&&)) as int;
]],
    todo = 'line 5 : parameter must be `hold´',
    --fin = 'line 5 : invalid attribution',
    --run = 1,
}

Test { [[
native/pos do
    void* V;
end
native _V;
code/tight Fx (var/hold void&& v)=>void do
    _V := v;
end
var void&& x=null;
do call Fx(5 as void&&);
    finalize with nothing; end;
escape (_V==(5 as void&&)) as int;
]],
    todo = 'line 8 : invalid `finalize´',
}

Test { [[
interface I with
    code/tight Fx (void)=>void;
end

class Tx with
    interface I;
    code/tight/recursive Fx (void)=>void;
do
    code/tight/recursive Fx (void)=>void do
        if false then
            call/recursive this.Fx();
        end
    end
end

var Tx t;
call/recursive t.Fx();

var I&& i = &&t;
call i:Fx();

escape 1;
]],
    tmp = 'line 2 : function declaration does not match the one at "/tmp/tmp.ceu:7"',
    --tight = 'line 2 : function must be declared with `recursive´',
}

Test { [[
interface I with
    code/tight/recursive Fx (void)=>void;
end

class Tx with
    interface I;
    code/tight/recursive Fx (void)=>void;
do
    code/tight/recursive Fx (void)=>void do
        if false then
            call/recursive this.Fx();
        end
    end
end

var Tx t;
call/recursive t.Fx();

var I&& i = &&t;
call i:Fx();

escape 1;
]],
    tight = 'line 20 : `call/recursive´ is required for "Fx"',
}

Test { [[
interface I with
    code/tight/recursive Fx (void)=>void;
end

class Tx with
    interface I;
    code/tight/recursive Fx (void)=>void;
do
    code/tight/recursive Fx (void)=>void do
        if false then
            call/recursive this.Fx();
        end
    end
end

var Tx t;
call/recursive t.Fx();

var I&& i = &&t;
call/recursive i:Fx();

escape 1;
]],
    run = 1,
}

Test { [[
interface I with
    code/tight/recursive Fx (void)=>void;
end

class Tx with
    interface I;
    code/tight Fx (void)=>void; // ignored
do
    code/tight Fx (void)=>void do
    end
end

var Tx t;
call t.Fx();

var I&& i = &&t;
call/recursive i:Fx();

escape 1;
]],
    tmp = 'line 2 : function declaration does not match the one at "/tmp/tmp.ceu:7"',
}

Test { [[
interface I with
    code/tight Fx (void)=>void;
end

class Tx with
    interface I;
    code/tight Fx (void)=>void; // ignored
do
    code/tight Fx (void)=>void do
    end
end

var Tx t;
call t.Fx();

var I&& i = &&t;
call/recursive i:Fx();

escape 1;
]],
    tight = 'line 17 : `call/recursive´ is not required for "Fx"',
}

Test { [[
interface I with
    code/tight Fx (void)=>void;
end

class Tx with
    interface I;
    code/tight Fx (void)=>void; // ignored
do
    code/tight Fx (void)=>void do
    end
end

var Tx t;
call t.Fx();

var I&& i = &&t;
i:Fx();

escape 1;
]],
    wrn = true,
    --tight = 'line 9 : function may be declared without `recursive´',
    run = 1,
}

Test { [[
interface I with
    code/tight/recursive Fx (void)=>void;
end

class Tx with
    interface I;
    code/tight/recursive Fx (void)=>void; // ignored
do
    code/tight/recursive Fx (void)=>void do
    end
end

var Tx t;
call/recursive t.Fx();

var I&& i = &&t;
call/recursive i:Fx();

escape 1;
]],
    wrn = true,
    --tight = 'line 9 : function may be declared without `recursive´',
    run = 1,
}

Test { [[
interface I with
    code/tight/recursive Fx (void)=>void;
end

class Tx with
    code/tight/recursive Fx (void)=>void;
    interface I;
do
    code/tight/recursive Fx (void)=>void do
    end
end

var Tx t;
call/recursive t.Fx();

var I&& i = &&t;
call/recursive i:Fx();

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Fx (var int v)=>int;
code/tight Fx (var int v)=>int do
    if v == 0 then
        escape 1;
    end
    escape v*call Fx(v-1);
end
escape call Fx(5);
]],
    tight = 'line 2 : function must be annotated as `@rec´ (recursive)',
    --run = 120,
}

Test { [[
interface I with
    code/tight Fx (void)=>void;
end

class Tx with
    interface I;
do
    code/tight Fx (void)=>void do
    end
end

var Tx t;
var& I i = &t;

code/tight Gx (void)=>void do
    i.Fx();
end

code/tight H (void)=>void do
    this.g();
end

escape 1;
]],
    run = 1,
}
Test { [[
interface I with
    code/tight Fx (void)=>void;
end

class Tx with
    interface I;
do
    code/tight Fx (void)=>void do
    end
end

var Tx t;
var& I i = &t;

code/tight Gx (void)=>void do
    i.Fx();
end

code/tight H (void)=>void do
    this.g();
end

class U with
    interface I;
    code/tight Gx (void)=>void;
do
    code/tight Fx (void)=>void do
        this.g();
    end
    code/tight Gx (void)=>void do
    end
end

escape 1;
]],
    tight = 'line 2 : function must be annotated as `@rec´ (recursive)',
}
Test { [[
interface I with
    code/tight/recursive Fx (void)=>void;
end

class Tx with
    interface I;
do
    code/tight/recursive Fx (void)=>void do
    end
end

var Tx t;
var& I i = &t;

code/tight Gx (void)=>void do
    call/recursive i.Fx();
end

code/tight H (void)=>void do
    this.g();
end

class U with
    interface I;
    code/tight Gx (void)=>void;
do
    code/tight/recursive Fx (void)=>void do
        this.g();
    end
    code/tight Gx (void)=>void do
    end
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
interface IWorld with
    code/tight Get_pingus (var PinguHolder&&) => PinguHolder&&;
end

class PinguHolder with
do end

class World with
    interface IWorld;
do end

var IWorld&&? ptr = spawn World with end;

escape 1;
]],
    tmp = 'line 2 : undeclared type `PinguHolder´',
}

Test { [[
interface IWorld with
    code/tight Get_pingus (void) => PinguHolder&&;
end

class PinguHolder with
do end

class World with
    interface IWorld;
do end

var IWorld&&? ptr = spawn World with end;

escape 1;
]],
    tmp = 'line 2 : undeclared type `PinguHolder´',
}

Test { [[
interface IWorld with
    code/tight Get_pingus (var PinguHolder&&) => void;
end

class PinguHolder with
do end

class World with
    interface IWorld;
do end

var IWorld&&? ptr = spawn World with end;

escape 1;
]],
    tmp = 'line 2 : undeclared type `PinguHolder´',
}

Test { [[
class PinguHolder with
do end

interface IWorld with
    code/tight Get_pingus (var PinguHolder&&) => PinguHolder&&;
end

class World with
    interface IWorld;
do end

var IWorld&&? ptr = spawn World with end;

escape 1;
]],
    cc = "undefined reference to `CEU_World_get_pingus'",
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

var IWorld&&? ptr = spawn World with
                    this.x = 10;
                  end;
escape ptr!:x;     // escapes with "10"
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

var World&&? ptr = spawn World with
                    this.x = 10;
                  end;
var IWorld&& w = ptr!;
escape w:x;     // escapes with "10"
]],
    run = 10,
}

Test { [[
code/tight Fx (void)=>int&& do
    escape 1;
end
escape 10;
]],
    wrn = true,
    --env = 'line 2 : invalid escape value : types mismatch (`int&&´ <= `int´)',
    stmts = 'line 2 : invalid `escape´ : types mismatch : "int&&" <= "int"',
}

-- TODO: dropped support for returning alias, is this a problem?

Test { [[
var int x = 10;

code/tight Fx (void)=>int& do
    escape &this.x;
end

escape call Fx();
]],
    parser = 'line 3 : after `int´ : expected type modifier or `;´ or `do´',
    --run = 10,
}
Test { [[
class Tx with
    code/tight Fx (void)=>int&;
do
    var int x = 10;
    code/tight Fx (void)=>int& do
        escape &this.x;
    end
end

var Tx t;

escape t.Fx();
]],
    parser = 'line 2 : after `int´ : expected type modifier or `;´',
    --run = 10,
}

Test { [[
var int x = 10;

code/tight Fx (void)=>int& do
    escape &&this.x;
end

escape call Fx();
]],
    parser = 'line 3 : after `int´ : expected type modifier or `;´ or `do´',
    --env = 'line 4 : invalid escape value : types mismatch (`int&´ <= `int&&´)',
}
Test { [[
class Tx with
    code/tight Fx (void)=>int&&;
do
    var int x = 10;
    code/tight Fx (void)=>int&& do
        escape &this.x;
    end
end

var Tx t;

escape t.Fx();
]],
    tmp = 'line 6 : invalid escape value : types mismatch (`int&&´ <= `int&´)',
}

Test { [[
class Test with
    code/tight FillBuffer (vector&[] u8 buf)=>void;
do
    code/tight FillBuffer (vector&[] u8 buf)=>void do
        buf = [] .. buf .. [3];
    end
end

vector[10] u8 buffer;

var Test t;
t.fillBuffer(&buffer);

escape buffer[0];
]],
    run = 3,
}

Test { [[
class Test with
    code/tight FillBuffer (vector[]&& u8 buf)=>void;
do
    code/tight FillBuffer (vector[]&& u8 buf)=>void do
        *buf = [] .. *buf .. [3];
    end
end

vector[10] u8 buffer;

var Test t;
t.fillBuffer(&&buffer);

escape buffer[0];
]],
    --run = 3,
    todo = 'no pointers to vectors',
}

Test { [[
class Tx with
    var int v = 10;
do
end

code/tight Fx (var& Tx t)=>int do
    escape t.v * 2;
end

var Tx t;
var& int ret = call Fx(t);

    var Tx u with
        this.v = 20;
    end;
    ret = ret + call Fx(&u);

escape ret;
]],
    run = 60,
}

Test { [[
class Tx with
    var int v = 10;
do
end

code/tight Fx (var& Tx t)=>int do
    escape t.v * 2;
end

var Tx t;
var& int ret = call Fx(t);

do
    var Tx u with
        this.v = 20;
    end;
    ret = ret + call Fx(&u);
end

escape ret;
]],
    --ref = 'line 17 : attribution to reference with greater scope',
    run = 60,
}

Test { [[
class Tx with
    var int v = 10;
do
end

code/tight Fx (var Tx&& t)=>int do
    escape t:v * 2;
end

var Tx t;
var int ret = call Fx(&&t);

do
    var Tx u with
        this.v = 20;
    end;
    ret = ret + call Fx(&&u);
end

escape ret;
]],
    run = 60,
}

Test { [[
interface Human with
    code/tight Walk (void)=>int;
    code/tight Breath (void)=>int;
    var int n;
end

class CommonThings with
    code/tight Walk (var& Human h)=>int;
    code/tight Breath (var& Human h)=>int;
do
    code/tight Walk (var& Human h)=>int do
        escape h.n;
    end
    code/tight Breath (var& Human h)=>int do
        escape h.n;
    end
    await FOREVER;
end

class Man with
    interface Human;
    var& CommonThings ct;
    var int n = 100;
do
    code/tight Walk (void)=>int do
        escape 200; // override
    end
    code/tight Breath (void)=>int do
        escape this.ct.breath(&this); // delegate
    end
end

var CommonThings ct;
var Man m with
    this.ct = &ct;
end;
escape m.walk() + m.breath();
]],
    run = 300,
}

Test { [[
native/pos do
    typedef struct t {
        void* ceu;
    } t;
end
native/plain _t;
var _t t = _t();
var _t&& ptr = &&t;
var int v = 10;
var int x = &v;
ptr:ceu = &v;
escape *((ptr:ceu as int&&));
]],
    stmts = 'line 10 : invalid binding : expected declaration with `&´',
    --env = 'line 10 : invalid attribution : l-value cannot hold an alias',
    --ref = 'line 9 : invalid attribution : l-value already bounded',
    --run = 10,
}
Test { [[
native/pos do
    typedef struct t {
        void* ceu;
    } t;
end
native/plain _t;
var _t t = _t();
var _t&& ptr = &&t;
var int v = 10;
ptr:ceu = &v;
escape *((ptr:ceu as int&&));
]],
    stmts = 'line 10 : invalid binding : unexpected context for operator `.´',
    --stmts = 'line 10 : invalid binding : expected declaration with `&´',
    --env = 'line 10 : invalid attribution : l-value cannot hold an alias',
    --ref = 'line 9 : invalid attribution : l-value already bounded',
    --run = 10,
}

Test { [[
native/pos do
    typedef struct t {
        void* xxx;
    } t;
end

class C with
    var int v = 10;
do
end
var C c;

native _t;
var _t   t;
var _t&& ptr = &&t;

ptr:xxx = &c;

escape (ptr:xxx as C&&):v;
]],
    --run = 10,
    stmts = 'TODO',
    --env = 'line 16 : invalid attribution : l-value cannot hold an alias',
    --ref = 'line 16 : invalid attribution : l-value already bounded',
}

Test { [[
native/pos do
    typedef struct t {
        void* xxx;
    } t;
end

class C with
    var int v = 10;
    event int e;
do
end
var C c;

native _t;
var _t   t;
var _t&& ptr = &&t;

ptr:xxx = &c;

emit (ptr:xxx as C&&):e (1);

escape (ptr:xxx as C&&):v;
]],
    stmts = 'TODO',
    --env = 'line 17 : invalid attribution : l-value cannot hold an alias',
    --run = 10,
}
Test { [[
class Dir with
    var int value;
do
end
interface IPingu with
    code/tight Get (void)=>Dir&;
end
class Pingu with
    interface IPingu;
do
    var Dir dir with
        this.value = 10;
    end;
    code/tight Get (void)=>Dir& do
        escape &&dir;
    end
end
var Pingu p;
escape p.get().value;
]],
    parser = 'line 6 : after `Dir´ : expected type modifier or `;´',
    --env = 'line 15 : invalid escape value : types mismatch (`Dir&´ <= `Dir&&´)',
}

Test { [[
class Dir with
    var int value;
do
end
interface IPingu with
    code/tight Get (void)=>Dir&;
end
class Pingu with
    interface IPingu;
do
    var Dir dir with
        this.value = 10;
    end;
    code/tight Get (void)=>Dir& do
        escape &dir;
    end
end
var Pingu p;
escape p.get().value;
]],
    parser = 'line 6 : after `Dir´ : expected type modifier or `;´',
    --run = 10,
}

Test { [[
class Tx with do end

pool[] Tx ts;

class U with
    var& int ts;
do
end

var U u;

escape 1;
]],
    tmp = 'line 10 : missing initialization for field "ts" (declared in /tmp/tmp.ceu:6)',
}

Test { [[
class Tx with do end

pool[] Tx ts;

class U with
    pool&[] Tx ts;
do
    var Tx&&? t =
        spawn Tx in ts with
        end;
end

var U u;

escape 1;
]],
    tmp = 'line 13 : missing initialization for field "ts" (declared in /tmp/tmp.ceu:6)',
}

Test { [[
interface I with end;

class Tx with
    interface I;
    code/tight Fx (void)=>I&&;
do
    code/tight Fx (void)=>I&& do
        var I&& i = &&this;
        escape i;
    end
end

var Tx t;
var I&& p = t.Fx();
escape p==&&t;
]],
    run = 1,
}

Test { [[
class Tx with
    code/tight Fx (void)=>int&&;
do
    var int x = 1;
    code/tight Fx (void)=>int&& do
        escape &&this.x;
    end
end

var Tx t;
escape *(t.Fx());
]],
    run = 1,
}

Test { [[
interface I with end;

class Tx with
    interface I;
    code/tight Fx (void)=>I&&;
do
    code/tight Fx (void)=>I&& do
        escape &&this;
    end
end

var Tx t;
t.Fx();
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    var int xxx2=0;
    code/tight Fff (var int xxx3)=>void;
do
    code/tight Fff (var int xxx3)=>void do
        this.xxx2 = xxx3;
    end
    this.xxx2 = 1;
end

var int xxx1 = 10;
var Tx ttt;
ttt.fff(xxx1);
escape ttt.xxx2;
]],
    run = 10,
}
Test { [[
class Tx with
    var int xxx2=0;
    code/tight Fff (var& int xxx3)=>void;
do
    code/tight Fff (var& int xxx3)=>void do
        var& int xxx4 = &xxx3;
        this.xxx2 = xxx4;
    end
    this.xxx2 = 1;
end

var int xxx1 = 10;
var Tx ttt;
ttt.fff(&xxx1);
escape ttt.xxx2;
]],
    run = 10,
}

Test { [[
class U with do end

class Tx with
    code/tight Fx (var int x)=>Tx;
    var int x = 0;
do
    code/tight Fx (var int x)=>Tx do
        this.x = 1;
    end
end

var Tx t = U.Fx(1);
escape t.x;
]],
    adj = 'line 12 : invalid constructor',
}

Test { [[
class Tx with
    code/tight Fx (var int x)=>Tx;
do
    var int x = 0;

    code/tight Fx (var int x)=>Tx do
        this.x = 1;
    end
end

var Tx t;
t = Tx.Fx(1);
escape t.x;
]],
    parser = 'line 12 : after `Tx´ : expected `(´',
    --parser = 'line 12 : after `.´ : expected tag identifier',
    --parser = 'line 12 : before `.´ : expected expression',
    --run = 2,
}

Test { [[
class Tx with
    code/tight Fff (var int x)=>Tx;
    var int x = 0;
do
    code/tight Fff (var int x)=>Tx do
        this.x = x;
    end
end

var Tx ttt = Tx.fff(2);
escape ttt.x;
]],
    run = 2,
}

Test { [[
class Tx with
    code/tight Fff (var int x)=>Tx;
    var int x = 0;
do
    code/tight Fff (var int x)=>Tx do
        this.x = x;
    end
end

var Tx ttt = Tx.fff(2) with
end;
escape ttt.x;
]],
    run = 2,
}
Test { [[
class Tx with
    code/tight Fff (var int x)=>Tx;
    var int x = 0;
do
    code/tight Fff (var int x)=>Tx do
        this.x = x;
    end
end

var Tx ttt = Tx.fff(2) with
    this.x = 1;
end;
escape ttt.x;
]],
    run = 1,
}

Test { [[
class Tx with
    code/tight Fff (var int x)=>Tx;
    var int x = 0;
do
    code/tight Fff (var int x)=>Tx do
        this.x = x;
    end
    this.x = 1;
end

var Tx ttt = Tx.fff(2);
escape ttt.x;
]],
    run = 1,
}

Test { [[
class Tx with
    code/tight Fa (var int x)=>Tx;
    code/tight Fb (var int x)=>Tx;
    var int x = 0;
do
    code/tight Fa (var int x)=>Tx do
        this.x = x;
    end
    code/tight Fb (var int x)=>Tx do
        this.f1(x);
    end
end

var Tx ttt = Tx.f2(2);
escape ttt.x;
]],
    run = 2,
}

Test { [[
class Tx with
    code/tight Fa (var int x)=>Tx;
    code/tight Fb (var int x)=>Tx;
    var int x = 0;
do
    code/tight Fa (var int x)=>Tx do
        this.x = x;
    end
    code/tight Fb (var int x)=>Tx do
        this.f1(x);
    end
    await FOREVER;
end

pool[] Tx ts;
spawn Tx.f2(2) in ts;

var int ret = 0;
loop t in ts do
    ret = ret + t:x;
end

escape ret;
]],
    run = 2,
}

Test { [[
class Tx with
    code/tight Fa (var int x)=>Tx;
    code/tight Fb (var int x)=>Tx;
    var int x = 0;
do
    code/tight Fa (var int x)=>Tx do
        this.x = x;
    end
    code/tight Fb (var int x)=>Tx do
        this.f1(x);
    end
    escape this.x;
end

var int ret = do Tx.f2(2);
escape ret;
]],
    run = 2,
}

Test { [[
class Tx with
    var& int x;
    code/tight Fff (var& int x)=>Tx;
do
    code/tight Fff (var& int x)=>Tx do
        this.x = x;
    end
    this.x = 1;
end

var int x = 10;
var Tx ttt = Tx.fff(&x);
escape x;
]],
    tmp = 'line 6 : invalid attribution : missing alias operator `&´ on the right',
}

Test { [[
class Tx with
    var& int x;
    code/tight Fff (var& int x)=>Tx;
do
    code/tight Fff (var& int x)=>Tx do
    end
end
escape 1;
]],
    tmp = 'line 5 : missing initialization for field "x" (declared in /tmp/tmp.ceu:2)',
}

Test { [[
class Tx with
    var& int x;
    code/tight Fff (var& int x)=>Tx;
do
    this.x = 1;
    code/tight Fff (var& int x)=>Tx do
    end
end
escape 1;
]],
    tmp = 'line 6 : missing initialization for field "x" (declared in /tmp/tmp.ceu:2)',
}

Test { [[
class Tx with
    var int xxx2;
    code/tight Fff (var& int xxx3)=>Tx;
do
    code/tight Fff (var& int xxx3)=>Tx do
        this.xxx2 = xxx3;
    end
    this.xxx2 = 1;
end

var int xxx1 = 10;
var Tx ttt = Tx.fff(&xxx1);
escape ttt.xxx2;
]],
    run = 1,
}

Test { [[
class Tx with
    var& int xxx2;
    code/tight Fff (var& int xxx3)=>Tx;
do
    code/tight Fff (var& int xxx3)=>Tx do
        this.xxx2 = &xxx3;
    end
    this.xxx2 = 1;
end

var int xxx1 = 10;
var Tx ttt = Tx.fff(&xxx1);
escape xxx1;
]],
    run = 1,
}

Test { [[
class Tx with
    var& int vvv;
do
end
var Tx t;
escape 1;
]],
    tmp = 'line 5 : missing initialization for field "vvv" (declared in /tmp/tmp.ceu:2)',
}
Test { [[
var& int vvv;
escape vvv;
]],
    inits = 'line 1 : uninitialized variable "vvv" : reached read access (/tmp/tmp.ceu:2)',
    --ref = 'line 2 : invalid access to uninitialized variable "vvv" (declared at /tmp/tmp.ceu:1)',
}
Test { [[
class TimeDisplay with
    code/tight Build (var& int vvv)=>TimeDisplay;
do
    var int x = 0;
    var& int vvv = &x;

    code/tight Build (var& int vvv)=>TimeDisplay do
        this.vvv = &vvv;
    end
end
escape 1;
]],
    tmp = 'line 8 : invalid attribution : variable "vvv" is already bound',
}

Test { [[
class TimeDisplay with
    code/tight Build (var& int vvv)=>TimeDisplay;
do
    var int x = 0;
    var& int vvv;

    code/tight Build (var& int vvv)=>TimeDisplay do
        //this.vvv = &vvv;
        if vvv then end;
    end

    vvv = &x;
    if vvv then end;
end
escape 1;
]],
    run = 1,
}

--<<< METHODS

-->>> CLASS-FINALIZE-OPTION

Test { [[
native/pos do
    int V = 10;
    int* getV (void) {
        escape &V;
    }
end

var& int? v;
    do v = &_getV();
finalize with
    nothing;
end

class Tx with
    var& int? v;
do
    v! = 20;
end
do Tx with
    this.v = &v!;
end;

escape v!;
]],
    run = 20,
}
Test { [[
native/pos do
    int V = 10;
    int* getV (void) {
        escape &V;
    }
end

var& int? v;
    do v = &_getV();
finalize with
    nothing;
end

class Tx with
    var& int? v;
do
    v! = 20;
end
do Tx with
    this.v = &v!;
end;

escape v!;
]],
    run = 20,
}
Test { [[
native/pos do
    int V = 10;
    int* getV (void) {
        escape &V;
    }
end

var& int? v;
    do v = &_getV();
finalize with
    nothing;
end

class Tx with
    var& int v;
do
    v = 20;
end
do Tx with
    this.v = &v;
end;

escape v!;
]],
    tmp = 'line 21 : invalid operand to unary "&" : cannot be aliased',
}
Test { [[
native/pos do
    int V = 10;
    int* getV (void) {
        escape &V;
    }
end

var& int? v;
    do v = &_getV();
finalize with
    nothing;
end

class Tx with
    var& int v;
do
    v = 20;
end
do Tx with
    this.v = &v!;
end;

escape v!;
]],
    run = 20,
}
Test { [[
native/pos do
    int V = 10;
    int* getV (void) {
        escape &V;
    }
end

var& _int? v;
    do v = &_getV();
finalize with
    nothing;
end

class Tx with
    var& _int v;
do
    v = 20;
end
do Tx with
    this.v = &v;
end;

escape v!;
]],
    tmp = 'line 21 : invalid operand to unary "&" : cannot be aliased',
}

Test { [[
native _new_Int;
native/pos do
    int* new_Int() {
        escape NULL;
    }
end
    code/tight Parse_file (void) => void do
            var& int? intro_story_str;
            if intro_story_str? then end;
                do intro_story_str = &_new_Int();
            finalize with
                nothing;    /* deleted below */
            end
    end
escape 1;
]],
    inits = 'line 8 : uninitialized variable "intro_story_str" : reached read access (/tmp/tmp.ceu:9)',
    wrn = true,
    --run = 1,
}

Test { [[
native/pure _new_String;
class String with
do
    var& _std__string? ss = &_new_String();
end
escape 1;
]],
    fin = 'line 4 : attribution to pointer with greater scope',
    run = 1,
}

--<<< CLASS-FINALIZE-OPTION

-->>> CLASS-VECTORS-FOR-POINTERS-TO-ORGS

Test { [[
class Tx with
    vector[10] int vs;
do
    this.vs = [1];
end

var Tx t;
t.vs[0] = t.vs[0] + 2;

escape t.vs[0];
]],
    --props = 'line 2 : not permitted inside an interface : vectors',
    run = 3,
}

Test { [[
class Tx with
    vector&[10] int vs;
do
    this.vs = [1];
end

vector[10] int vs;
var Tx t with
    this.vs = &vs;
end;
t.vs[0] = t.vs[0] + 2;

escape t.vs[0];
]],
    run = 3,
}

Test { [[
interface I with
    var& int v;
end

class Tx with
    interface I;
do
    this.v = 1;
end

var int v;
var Tx t with
    this.v = &v;
end;
v = 1;
t.v = t.v + 2;

var I&& i = &&t;
i:v = i:v * 3;

escape t.v;
]],
    tmp = '/tmp/tmp.ceu : line 13 : invalid access to uninitialized variable "v" (declared at /tmp/tmp.ceu:11)',
    --run = 1,
    --ref = 'line 11 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:12)',
}

Test { [[
interface I with
    var& int v;
end

class Tx with
    interface I;
do
    this.v = 1;
end

var int v=10;
var Tx t with
    this.v = &v;
end;
t.v = t.v + 2;

var I&& i = &&t;
i:v = i:v * 3;

escape t.v;
]],
    run = 9,
}

Test { [[
vector&[10] int rs;
vector[10] int  vs = [1];
rs = &vs;
vs[0] = vs[0] + 2;

rs[0] = rs[0] * 3;

escape vs[0];
]],
    run = 9,
}
Test { [[
interface I with
    vector&[10] int vs;
end

class Tx with
    interface I;
do
end

vector[10] int vs;
var Tx t with
    this.vs = &vs;
end;

var I&& i = &&t;

i:vs = [ 0 ];
i:vs[0] = 3;

escape i:vs[0];
]],
    run = 3,
}
Test { [[
interface I with
    vector&[10] int vs;
end

class Tx with
    interface I;
do
end

vector[10] int vs;
var Tx t with
    this.vs = &vs;
end;

var I&& i = &&t;

i:vs[0] = 3;

escape 1;
]],
    run = '17] runtime error: access out of bounds',
    -- TODO: not 20, 17!
}
Test { [[
interface I with
    vector&[10] int vs;
end

class Tx with
    interface I;
do
    this.vs = [1];
end

vector[10] int vs;
var Tx t with
    this.vs = &vs;
end;
t.vs[0] = t.vs[0] + 2;

var I&& i = &&t;

i:vs[0] = i:vs[0] * 3;

escape t.vs[0];
]],
    run = 9,
}
Test { [[
class Tx with
do
end
vector[] Tx&&  ts;
escape 1;
]],
    run = 1,
}
Test { [[
class Tx with
do
end
vector[] Tx&& ts;
var int x = $ts;
escape x+$ts+1;
]],
    run = 1,
}
Test { [[
class Tx with
do
end
vector[] Tx&& ts;
var Tx t;
ts = [] .. ts .. [t];
escape $ts+1;
]],
    stmts = 'line 6 : wrong argument #1 : types mismatch (`Tx&&´ <= `Tx´)',
}
Test { [[
class Tx with
do
end
vector[] Tx&& ts;
var Tx t;
ts = [] .. ts .. [&&t];
escape $ts+1;
]],
    run = 2,
}

Test { [[
class Tx with
do
end
vector[] Tx&& ts;
var Tx t;
ts = [] .. ts .. [&&t];
var Tx&& p = ts[0];
escape p == &&t;
]],
    run = 1,
}

Test { [[
class Tx with
do
end
vector[] Tx&& ts;
var Tx t;
ts = [] .. ts .. [&&t];
var Tx&& p = ts[1];
escape p == &&t;
]],
    run = '7] runtime error: access out of bounds',
}

Test { [[
class Tx with
do
end
vector[] Tx&& ts;
var Tx t;
ts = [] .. ts .. [&&t];
await 1s;
var Tx&& p = ts[0];
escape p == &&t;
]],
    fin = 'line 8 : unsafe access to pointer "ts" across `await´ (/tmp/tmp.ceu : 7)',
}

Test { [[
class Tx with
    var int v = 10;
do
    await FOREVER;
end

var Tx t;
var Tx&&? p = &&t;

escape t.v + p!:v;
]],
    run = 20,
}
Test { [[
class Tx with
    var int v = 10;
do
end

var Tx t;
var Tx&&? p = &&t;

escape t.v + p!:v;
]],
    run = '9] runtime error: invalid tag',
}
Test { [[
class Tx with
    var int v = 10;
do
    await 1s;
end

var Tx t;
var Tx&&? p = &&t;

await 500ms;

escape t.v + p!:v;
]],
    run = { ['~>1s'] = 20 },
}
Test { [[
class Tx with
    var int v = 10;
do
end

var Tx t;
var Tx&&? p = &&t;

await 500ms;

escape t.v + p!:v;
]],
    run = { ['~>1s'] = '12] runtime error: invalid tag', },
}

Test { [[
class Tx with
    var int v = 10;
do
    await 1s;
end

var Tx t;
var Tx&&? ppp = &&t;

await 1s;

escape t.v + ppp!:v;
]],
    run = { ['~>1s']='13] runtime error: invalid tag' },
}

Test { [[
class Tx with
    var int v = 10;
do
    await 1s;
end

var Tx t;
var Tx&&? p = &&t;

await 500ms;

escape t.v + p!:v;
]],
    run = { ['~>1s'] = 20 },
}

Test { [[
class U with
    var int v = 10;
do
    await FOREVER;
end
class Tx with
    var int v = 10;
do
    await 1s;
end

var U u;
var Tx t;
var U&&? p = &&u;

await 1s;

escape t.v + p!:v;
]],
    run = { ['~>1s']=20 },
}

Test { [[
class Tx with
do
end
//vector[] Tx   ts;
vector[] Tx&&  ts1;
vector[] Tx&&? ts2;
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
do
end
vector[] Tx&&? ts;
var Tx t;
ts = [] .. [&&t];
escape $ts;
]],
    run = 1,
}

Test { [[
class Tx with
do
end
vector[] Tx&&? ts;

var Tx t;
ts = [] .. [&&t];

escape ts[0] == &&t;
]],
    tmp = 'line 9 : invalid operands to binary "=="',
}

Test { [[
class Tx with
do
    await FOREVER;
end
vector[] Tx&&? ts;
var Tx t;
ts = [] .. [&&t];
escape ts[0]! == &&t;
]],
    run = 1,
}

Test { [[
class Tx with
do
end
vector[] Tx&&? ts;
var Tx t;
ts = [] .. [&&t];
escape ts[0]! == &&t;
]],
    run = '7] runtime error: invalid tag',
}

Test { [[
class Tx with
do
end
vector[] Tx&&? ts;
var Tx t;
ts = [] .. [&&t] .. [&&t];
escape ts[1]! == &&t;
]],
    run = '7] runtime error: invalid tag',
}

Test { [[
class Tx with
do
end
vector[] Tx&&? ts;
var Tx t1,t2;
ts = [] .. [&&t1];
ts[0]! = &&t2;
escape ts[0]! == &&t2;
]],
    run = '7] runtime error: invalid tag',
}

Test { [[
class Tx with
do
    await 1s;
end
vector[] Tx&&? ts;
var Tx t;
ts = [] .. [&&t];
await 1s;
escape ts[0]! == &&t;
]],
    run = { ['~>1s']='10] runtime error: invalid tag' },
}

Test { [[
interface I with
end
class Tx with
do
end

var Tx t;
vector[] I&&? iss;
iss = [&&t];

escape iss[0]? + 1;
]],
    run = { ['~>1s'] = 1 },
}

Test { [[
interface I with
end
class Tx with
do
end
class U with
do
    await FOREVER;
end
class V with
do
    await 1s;
end

var Tx t;
var U u;
var V v;

vector[] I&&? iss;
iss = [&&t, &&u, &&v];

var int ret = 0;

ret = ret + iss[0]? + iss[1]? + iss[2]?;
await 1s;
ret = ret + iss[0]? + iss[1]? + iss[2]?;

escape ret;
]],
    run = { ['~>1s'] = 3 },
}

Test { [[
input void OS_START;
class Tx with
do
    native/pure _printf;
    _printf("%p\n", &&this);
    await FOREVER;
end

var Tx&&? t;
par/or do
    do
        pool[] Tx ts;
        t = spawn Tx in ts;
        await OS_START;
    end
    await FOREVER;
with
    await *t!;
end
escape 1;

]],
    _ana = {acc=true},
    run = 1,
}

Test { [[
input void OS_START;
class Tx with
do
    await FOREVER;
end

var Tx&&? t;
par/and do
    do
        pool[] Tx ts;
        t = spawn Tx in ts;
        await OS_START;
    end
with
    await *t!;
end
escape t?==false;
]],
    _ana = {acc=true},
    run = 1,
}

Test { [[
input void OS_START;
class Tx with
do
    await FOREVER;
end

vector[] Tx&&? v;
par/and do
    do
        pool[] Tx ts;
        var Tx&&? ptr = spawn Tx in ts;
        v = [] .. v .. [ptr];
        await OS_START;
    end
with
    await *v[0]!;
end
escape v[0]?==false;
]],
    _ana = {acc=true},
    run = 1,
}

Test { [[
class U with do end;

class Tx with
    vector&[] U&&  us;
    code/tight Build (vector&[] U&& us)=>Tx;
do
    code/tight Build (vector&[] U&& us)=>Tx do
        this.us = &us;
    end
end

vector[] U&& us;
var Tx t = Tx.build(&us);

escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;

class Tx with
    vector&[] U&&  us;
    code/tight Build (vector&[] U&& us)=>Tx;
do
    code/tight Build (vector&[] U&& us)=>Tx do
        this.us = &us;
    end
end

vector[] U&& us = [null];

await 1s;

var& Tx t = Tx.build(us);
var U&& u = us[0];

escape u==null;
]],
    fin = 'line 16 : unsafe access to pointer "us" across `await´ (/tmp/tmp.ceu : 14)',
}
Test { [[
class U with do end;

class Tx with
    vector&[] U&&? us;
    code/tight Build (vector&[] U&&? us)=>Tx;
do
    code/tight Build (vector&[] U&&? us)=>Tx do
        this.us = &us;
    end
end

var U u1;
vector[] U&&? us = [&&u1];

await 1s;

var Tx t = Tx.build(&us);
var U&&? u2 = us[0];

escape u2?+1;
]],
    run = { ['~>2s']=1 },
}
Test { [[
class U with
    event bool go;
do
    await FOREVER;
end;

class Tx with
    vector&[] U&&? us;
    code/tight Build (vector&[] U&&? us)=>Tx;
do
    code/tight Build (vector&[] U&&? us)=>Tx do
        this.us = &us;
    end
end

var U u1;
vector[] U&&? us = [&&u1];

await 1s;

var Tx t = Tx.build(&us);
emit us[0]!:go(true);

escape us[0]?+1;
]],
    run = { ['~>2s']=2 },
}
Test { [[
class U with
    event bool go;
do
    await FOREVER;
end;

class Tx with
    vector&[] U&&? us;
    code/tight Build (vector&[] U&&? us)=>Tx;
do
    code/tight Build (vector&[] U&&? us)=>Tx do
        this.us = &us;
    end
end

var U u1;
vector[] U&&? us = [&&u1];
vector&[] U&&? xx = &us;

await 1s;

var Tx t = Tx.build(&us);
emit xx[0]!:go(true);

escape us[0]?+1;
]],
    run = { ['~>2s']=2 },
}

Test { [[
class Tx with
    var& int i;
    code/tight Build (var& int i)=>Tx;
do
    code/tight Build (var& int i)=>Tx do
        this.i = &i;
    end
    escape this.i;
end

var int i = 10;
var int ret = do Tx.build(&this.i);
escape ret;
]],
    run = 10,
}
Test { [[
native/pos do
    ##define ID(x) x
end
native/pure _ID;
class Tx with
    var& int i;
    code/tight Build (var& int i)=>Tx;
do
    code/tight Build (var& int i)=>Tx do
        this.i = &i;
    end
    escape this.i;
end

var int i = 10;
var int ret = do Tx.build(&_ID(&&this.i));
escape ret;
]],
    run = 10,
}

--<<< CLASS-VECTORS-FOR-POINTERS-TO-ORGS

-->>> DONT CARE, NONE

Test { [[
var int a = _;
loop _ in [0->10[ do
end

do/_
    //escape/_;
end

await 1ms/_;

escape 1;
]],
    wrn = true,
    run = 1,
}

--<<< DONT CARE, NONE

-->>> REENTRANT

if REENTRANT then

Test { [[
input int E,C;

par do
    async do
        emit E(10);
    end
    await FOREVER;
with
    var int ret = 0;
    par/and do
        var int v = await E;
        var int x = 1000;
        do _ceu_sys_go(__ceu_app, _CEU_IN_F, &&x);
            finalize with nothing; end;
        ret = ret + v;
    with
        var int v = await E;
        ret = ret + v;
    end
    escape ret;
end
]],
    wrn = true,
    _ana = {acc=true},
    run = 20,
}

end

--<<< REENTRANT

--do return end
--]===]
-- TODO: SKIP

-- TODO: SKIP-05
--[===[

Test { [[
class U with do end;

pool[10] U  us;

pool[1] U us1;
spawn U in us1;

escape 1;
]],
    wrn = true,
    run = 1,
}

-- TODO: bad message
Test { [[
interface UI with
end

class UIGridItem with
    var UI&&  ui;
do
end

class UIGrid with
    interface UI;
    pool[]  UIGridItem uis;
do
    code/tight Go (void)=>void do
        loop item in this.uis do
native _f;
            _f(item:ui);
        end
    end
end
escape 1;
]],
    wrn = true,
    fin = 'line 15 : unsafe access to pointer "ui" across `class´ (/tmp/tmp.ceu : 9)',
}

-- POOLS / 1ST-CLASS

Test { [[
class U with do end;
class Tx with
    pool[0] U us;
do
end

var Tx t;

escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;

interface I with
    pool[10] U us;
end

class Tx with
    interface I;
do
end

var Tx t;
var I&& i = &&t;
spawn U in i:us;

escape 1;
]],
    run = 1,
}

Test { [[
native/plain _int;

interface I with
    vector[10] _int vs;
end

interface Global with
    interface I;
end
vector[10] _int  vs = [];

class Tx with
    interface I;
do
    global:vs[0] = 1;
end

vs[0] = 1;
global:vs[0] = 1;

var Tx t;
t.vs[0] = 1;

var I&& i = &&t;
i:vs[0] = 1;

escape 1;
]],
    tmp = 'line 21 : missing initialization for field "vs" (declared in /tmp/tmp.ceu:4)',
}

Test { [[
native/plain _int;

interface I with
    vector[10] _int vs;
end

interface Global with
    interface I;
end
vector[10] _int  vs = [];

class Tx with
    interface I;
do
    global:vs[0] = 1;
end

vs[0] = 1;
global:vs[0] = 1;

var Tx t with
    this.vs = [];
end;
t.vs[0] = 1;

var I&& i = &&t;
i:vs[0] = 1;

escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;

interface I with
    pool[10] U us;
end

interface Global with
    interface I;
end
pool[10] U  us;

class Tx with
    pool[10] U us;
    interface I;
do
    spawn U in global:us;
end

spawn U in us;
spawn U in global:us;

pool[1] U us1;
spawn U in us1;

var Tx t;
spawn U in t.us;

var I&& i = &&t;
spawn U in i:us;

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
interface Global with
    vector[10] _int vs;
    var int     v;
end
vector[10] _int vs = [];
var int     v = 0;

loop i in [0 -> 10[ do
    vs[i] = i;
end
var int ret = 0;
loop i in [0 -> 10[ do
    ret = ret + global:vs[i] + global:v;
end
escape ret;
]],
    run = 45,
}

Test { [[
class Tx with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool[] Tx ts;
end

pool[] Tx ts;

spawn Tx in ts with
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
class Tx with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool[1] Tx ts;
end

pool[1] Tx ts;

spawn Tx in ts with
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
class Tx with
    var int v = 0;
do
end

interface Global with
    pool[] Tx ts;
end

pool[] Tx ts;

spawn Tx in global:ts;

escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool[] Tx ts;
end

pool[] Tx ts;

spawn Tx in global:ts with
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
class Tx with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool[] Tx ts;
end

pool[] Tx ts;

spawn Tx in global:ts with
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
class Tx with
do
end

interface Global with
    pool[] Tx ts;
end

pool[] Tx ts;

class U with
    var int v = 0;
do
    spawn Tx in global:ts with
    end;
end

var U u;
escape 1;
]],
    run = 1,
}
Test { [[
class Tx with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool[] Tx ts;
end

pool[] Tx ts;

class U with
    var int v = 0;
do
    spawn Tx in global:ts with
        this.v = 10;
    end;
    spawn Tx in global:ts with
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
class Tx with
    var int v = 0;
do
    async do end;
end

interface Global with
    pool[1] Tx ts;
end

pool[1] Tx ts;

class U with
    var int v = 0;
do
    spawn Tx in global:ts with
        this.v = 10;
    end;
    spawn Tx in global:ts with
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
native/pos do
    int V = 0;
end

class Tx with
    var int v = 0;
do
    do finalize with
native _V;
        _V = _V + 1;
    end
    await FOREVER;
end

class U with
    var int v = 0;
    pool[1] Tx ts;
do
    await FOREVER;
end

var int ret = 0;

do
    var U u;
    spawn Tx in u.ts with
        this.v = 10;
    end;
    spawn Tx in u.ts with
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
native/pos do
    int V = 0;
end

class Tx with
    var int v = 0;
do
    do finalize with
native _V;
        _V = _V + 1;
    end
    await FOREVER;
end

class U with
    var int v = 0;
    pool[] Tx ts;
do
    await FOREVER;
end

var int ret = 0;

do
    var U u;
    spawn Tx in u.ts with
        this.v = 10;
    end;
    spawn Tx in u.ts with
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
    pool[] Unit units;
end
pool[] Unit units;
escape 1;
]],
    tmp = 'line 3 : interface "Global" is not defined',
    --env = 'line 3 : undeclared type `Unit´',
}
Test { [[
interface Global with
    pool[] Unit units;
end
class Unit with
do
    spawn Unit in global:units;
end
pool[] Unit units;
escape 1;
]],
    tmp = 'line 2 : undeclared type `Unit´',
}
Test { [[
interface U with end;

interface Global with
    pool[] U units;
end
native/nohold _SDL_Has;

class V with
    interface U;
do
end

class Unit with
    interface U;
    var int rect;
do
    loop oth in global:units do
        if oth!=&&this then
            spawn V in global:units;
        end
    end
end

pool[] U units;
escape 1;
]],
    props = 'line 17 : pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)',
    --run = 1,
}

-- declaration order for clss, ifcs, pools

Test { [[
    class Queue with
      pool[] QueueForever val;
    do
      //
    end
    escape 1;
]],
    tmp = 'line 2 : undeclared type `QueueForever´',
}
Test { [[
    var Queue q;
    class Queue with
    do
        var Queue q;
    end
    escape 1;
]],
    tmp = 'line 1 : undeclared type `Queue´',
}
Test { [[
    class Queue with
    do
        var Queue q;
    end
    var Queue q;
    escape 1;
]],
    tmp = 'line 3 : undeclared type `Queue´',
}
Test { [[
    class Queue with
    do
        var Queue&& q=null;
        if q!=0 then end;
    end
    var Queue q;
    escape 1;
]],
    run = 1,
}
Test { [[
    class Queue with
      pool[] QueueForever val;
    do
    end

    class QueueForever with
    do
    end

    escape 1;
]],
    tmp = 'line 2 : undeclared type `QueueForever´',
}
Test { [[
    interface I with
      var int val;
    end
    spawn I;
    escape 1;
]],
    tmp = 'line 4 : cannot instantiate an interface',
}
Test { [[
    class QueueForever with
      var int val=0, maxval=0;
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
      pool[] QueueForever val;
    do
      //
    end

    class QueueForever with
      var& Queue queue;
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
    tmp = 'line 2 : undeclared type `QueueForever´',
}

Test { [[escape(1);]],
    _ana = {
        isForever = false,
    },
    run = 1,
}

-- test case for bad stack clear
Test { [[
class Intro with
do
    await 20ms;
end

do Intro;

class Body with do
    await 10ms;
end

class BTreeTraverse with
do
    pool[0] Body bodies;
    do Body;
    await 10ms;
end

do BTreeTraverse;

escape 1;
]],
    run = {['~>1s']=1},
}

-- TRACKING / WATCHING

Test { [[
data Data with
    var int v;
end

code/await Code (var& Data d, var  int ini) => int
do
    d.v = ini;
    every 1s do
        d.v = d.v + 1;
    end
end

var Data d = val Data(0);

var int a =
    watching Code(&d, 10) do
        var int ret = 0;
        watching 5s do
            every 1s do
                ret = ret + d.v;
            end
        end
        escape ret;
    end;

escape a;
]],
    run = {['~>10s']=50 },
}

Test { [[
data Data with
    var& int v;
end

code/await Code (var& Data d, var  int ini) => int
do
    var int v = ini;
    d.v = &v;
    every 1s do
        v = v + 1;
    end
end

var Data d = val Data(0);

var int a =
    watching Code(&d, 10) do
        var int ret = 0;
        watching 5s do
            every 1s do
                ret = ret + d.v;
            end
        end
        escape ret;
    end;

escape a;
]],
    todo = '&&',
    run = {['~>10s']=50 },
}

Test { [[
class Tx with
    event int e;
do
    await 1s;
    escape 10;
end

var Tx t;
var int n =
    watching t do
        await FOREVER;
    end;

escape n;
]],
    run = { ['~>1001ms'] = 10 },
}

Test { [[
input void E;
class Tx with
    event int e;
do
    await E;
    escape 10;
end

var Tx t;
var int n =
    watching t do
        await 500ms;
        escape 1;
    end;

escape n;
]],
    run = { ['~>1001ms'] = 1 },
}

Test { [[
class Tx with
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
class Tx with
    event int e;
do
    await this.e;
    var int v;
    watching this.e do
        if v!=0 then end;
        nothing;
    end
end
escape 1;
]],
    tmp = 'line 7 : invalid access to uninitialized variable "v" (declared at /tmp/tmp.ceu:5)',
}

Test { [[
class Tx with
    event int e;
do
    await this.e;
    var int v =
        watching this.e do
            if v!=0 then end;
            nothing;
        end;
end
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
do
end

var Tx t;

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
class Tx with
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

-- TODO: "e" has type "Tx*"
-- this type is defined inside the application and only makes sense there
-- if it is not the case, simply use void* and the other application casts back 
-- to Tx*
Test { [[
data Tx;
event Tx&& e;
var int ret = -1;
watching e do
    await 1s;
    ret = 1;
end
escape 1;
]],
    dcls = 'line 2 : invalid event type : must be primitive',
    --env = 'line 1 : invalid event type',
    --gcc = ' error: unknown type name ‘Tx’',
    --run = { ['~>1s'] = 1 }
}

Test { [[
class U with
    var int v = 0;
do
    await FOREVER;
end;

interface I with
    pool[2] U us2;
end

class Tx with
    pool[2] U us1;
    interface I;
do
end

var Tx t;
spawn U in t.us2 with
    this.v = 1;
end;

var I&& i = &&t;
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
    pool[2] U us2;
end

class Tx with
    pool[2] U us1;
    interface I;
do
    await FOREVER;
end

var Tx t;
spawn U in t.us2 with
    this.v = 1;
end;

var I&& i = &&t;

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
    pool[2] U us2;
end

class Tx with
    pool[2] U us1;
    interface I;
do
end

var Tx t;
spawn U in t.us2 with
    this.v = 1;
end;

var I&& i = &&t;

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
class Tx with
    var int v = 0;
do
end

event Tx&& e;
var int ret = 0;

par/or do
    var Tx t with
        this.v = 10;
    end;
    async do end;
    emit e(&&t);
with
    var Tx&& p = await e;
    ret = p:v;
end

escape ret;
]],
    tmp = 'line 6 : invalid event type',
    --env = 'line 14 : wrong argument : cannot pass pointers',
    --run = 10,
}

Test { [[
class Tx with
    var int v = 0;
do
end

event Tx&& e;
var int ret = 0;

par/or do
    var Tx t with
        this.v = 10;
    end;
    async do end;
    emit e(&&t);
with
    var Tx&& p = await e;
    ret = p:v;
end

escape ret;
]],
    tmp = 'line 6 : invalid event type',
    --env = 'line 14 : wrong argument : cannot pass pointers',
    --run = 10,
    safety = 2,
}

Test { [[
class Tx with
    var int v = 0;
do
end

event Tx&& e;
var int ret = 0;

par/or do
    var Tx t with
        this.v = 10;
    end;
    async do end;
    emit e(&&t);
with
    var Tx&& p = await e;
    async do end;
    ret = p:v;
end

escape ret;
]],
    tmp = 'line 6 : invalid event type',
    --env = 'line 14 : wrong argument : cannot pass pointers',
    --fin = 'line 18 : unsafe access to pointer "p" across `async´'
}

Test { [[
interface I with
    var int v;
end

class Tx with
    var int v = 0;
do
end

event Tx&& e;
var int ret = 0;

par/or do
    var Tx t with
        this.v = 10;
    end;
    async do end;
    emit e(&&t);
with
    var I&& p = await e;
    async do end;
    ret = p:v;
end

escape ret;
]],
    tmp = 'line 10 : invalid event type',
    --env = 'line 18 : wrong argument : cannot pass pointers',
    --fin = 'line 22 : unsafe access to pointer "p" across `async´',
}

Test { [[
interface I with
    var int v;
end

class Tx with
    var int v = 0;
do
    await FOREVER;
end

var I&&? p = spawn Tx with
    this.v = 10;
end;
escape p!:v;
]],
    run = 10,
    --fin = 'line 22 : invalid access to awoken pointer "p"',
}

Test { [[
native/pos do
    int V = 0;
end
input void OS_START;
class Tx with
    var int id = 0;
do
    await OS_START;
native _V;
    _V = _V + 1;
end

pool[1] Tx ts;
var Tx&&? t = spawn Tx in ts with
    this.id = 10;
end;

var int ret = 0;
watching *t! do
    ret = t!:id;
    await FOREVER;
end

escape ret;
]],
    _ana = { acc=true },
    run = 10,
}

Test { [[
input void OS_START;
class Tx with
    var int id = 0;
do
    await OS_START;
end

pool[1] Tx ts;
var Tx&&? t = spawn Tx in ts with
    this.id = 10000;
end;

var int ret = 0;

watching *t! do
    ret = t!:id;
    await FOREVER;
end

escape ret;
]],
    run = 10000,
}
Test { [[
input void OS_START;
class Tx with
    var int id = 0;
do
    await OS_START;
end

pool[2] Tx ts;
var Tx&&? t1 = spawn Tx in ts with
    this.id = 10000;
end;
var Tx&&? t = spawn Tx in ts with
    this.id = 10000;
end;

var int ret = 0;

watching *t! do
    ret = t!:id;
    await FOREVER;
end

escape ret;
]],
    run = 10000,
}
Test { [[
native/pos do
    int V = 0;
end
input void OS_START;
class Tx with
    var int id = 0;
do
    await OS_START;
native _V;
    _V = _V + 1;
end

pool[10000] Tx ts;
var Tx&& t0 = null;
var Tx&& tF = null;
loop i in [0 -> 10000[ do
    var Tx&&? t = spawn Tx in ts with
        this.id = 10000-i;
    end;
    if t0 == null then
        t0 = t!;
    end
    tF = t!;
end
native _assert;
_assert(t0!=null and tF!=null);

var int ret1=0, ret2=0;

watching *tF do
    ret2 = tF:id;
    await FOREVER;
end

escape ret1+ret2+_V;
]],
    --run = 10001,
    --fin = 'line 19 : unsafe access to pointer "t0" across `spawn´',
    fin = 'line 19 : unsafe access to pointer "t0" across `loop´',
}

Test { [[
native/pos do
    int V = 0;
end
input void OS_START;
class Tx with
    var int id = 0;
do
    await OS_START;
native _V;
    _V = _V + 1;
end

pool[10000] Tx ts;
var Tx&& tF = null;
loop i in [0 -> 10000[ do
var Tx&& t0 = null;
    var Tx&&? t = spawn Tx in ts with
        this.id = 10000-i;
    end;
    if t0 == null then
        t0 = t!;
    end
    tF = t!;
end
native _assert;
_assert(tF!=null);

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

class Tx with
    var int v = 10;
do
    await FOREVER;
end

var I&&? p = spawn Tx;
escape p!:v;
]],
    run = 10,
}

Test { [[
interface I with
    var int v;
end

class Tx with
    var int v = 0;
do
end

var I&&? p = spawn Tx with
    p!:v = 10;
end;
async do end;

escape p!:v;
]],
    run = '15] runtime error: invalid tag',
    --run = 1,
    --fin = 'line 15 : unsafe access to pointer "p" across `async´',
}

Test { [[
class Unit with
    event int move;
do
end
var Unit&&? u;
do
    pool[] Unit units;
    u = spawn Unit in units;
end
if u? then
    watching *u! do
        emit u!:move(0);
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
var Unit&&? u;
do
    pool[] Unit units;
    u = spawn Unit in units;
    await 1min;
end
watching *u! do
    emit u!:move(0);
end
escape 2;
]],
    run = { ['~>1min']='12] runtime error: invalid tag', },
    --fin = 'line 11 : unsafe access to pointer "u" across `await´',
}

Test { [[
interface I with
    var int v;
end

class Tx with
    var I&& i = null;
do
    watching *i do
        var int v = i:v;
        if v!=0 then end
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

class Tx with
    var I&& i = null;
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

class Tx with
    var I&& i = null;
do
    watching *i do
        await 1s;
        var int v = i:v;
        if v!=0 then end
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

var I&& i=null;

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

var I&& i=null;

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

var I&& i=null;

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
class Tx with
do
end
var Tx t;
watching t do
end
escape 100;
]],
    run = 100,
}

Test { [[
class Tx with
    var int v = 0;
do
end

event Tx&& e;
var int ret = 1;

par/and do
    async do end;
    var Tx t with
        this.v = 10;
    end;
    emit e(&&t);
    await 1s;
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 6 : invalid event type',
    --env = 'line 14 : wrong argument : cannot pass pointers',
    --run = { ['~>5s']=1 },
}

Test { [[
class Tx with
    var int v = 0;
do
end

event Tx&& e;
var int ret = 1;

par/and do
    async do end;
    var Tx t with
        this.v = 10;
    end;
    emit e(&&t);
    await 1s;
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 6 : invalid event type',
    --env = 'line 14 : wrong argument : cannot pass pointers',
    --run = { ['~>5s']=1 },
    safety = 2,
}

Test { [[
class Tx with
    var int v = 0;
do
end

event Tx&& e;
var int ret = 1;

par/and do
    async do end;
    var Tx t with
        this.v = 10;
    end;
    emit e(&&t);
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 6 : invalid event type',
    --env = 'line 14 : wrong argument : cannot pass pointers',
    --run = { ['~>5s']=1 },
}

Test { [[
class Tx with
    var int v = 0;
do
    await 5s;
end

event Tx&& e;
var int ret = 0;

par/and do
    async do end;
    var Tx t with
        this.v = 10;
    end;
    emit e(&&t);
    await 6s;
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 7 : invalid event type',
    --env = 'line 15 : wrong argument : cannot pass pointers',
    --run = { ['~>10s']=10 },
}

Test { [[
class Tx with
    var int v = 0;
do
    await 4s;
end

event Tx&& e;
var int ret = 0;

par/and do
    async do end;
    var Tx t with
        this.v = 10;
    end;
    emit e(&&t);
    await 6s;
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 7 : invalid event type',
    --env = 'line 15 : wrong argument : cannot pass pointers',
    --run = { ['~>10s']=-1 },
}

Test { [[
class Tx with
    var int v = 0;
do
    await 6s;
end

event Tx&& e;
var int ret = 0;

par/and do
    async do end;
    var Tx t with
        this.v = 10;
    end;
    emit e(&&t);
    await 6s;
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 7 : invalid event type',
    --env = 'line 15 : wrong argument : cannot pass pointers',
    --run = { ['~>10s']=10 },
}

Test { [[
class Tx with
    var int v = 0;
do
end

event Tx&& e;
emit e(null);
escape 1;
]],
    tmp = 'line 6 : invalid event type',
    --env = 'line 7 : wrong argument : cannot pass pointers',
    --run = 1;
}

Test { [[
class Tx with
    var int v = 0;
do
    async do end
end

event Tx&& e;
var int ret = 1;

par/and do
    async do end;
    pool[] Tx ts;
    var Tx&&? t = spawn Tx in ts with
        this.v = 10;
    end;
    emit e(t!);
    await 1s;
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 7 : invalid event type',
    --env = 'line 16 : wrong argument : cannot pass pointers',
    --run = { ['~>1s;~>1s;~>1s;~>1s;~>1s']=-1 },
}

Test { [[
class Tx with
    var int v = 0;
do
    async do end
end

event Tx&& e;
var int ret = 1;

par/and do
    async do end;
    pool[] Tx ts;
    var Tx&&? t = spawn Tx in ts with
        this.v = 10;
    end;
    emit e(t!);
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 7 : invalid event type',
    --env = 'line 16 : wrong argument : cannot pass pointers',
    --run = { ['~>1s;~>1s;~>1s;~>1s;~>1s']=1 },
}

Test { [[
class Tx with
    var int v = 0;
do
    await 4s;
end

event Tx&& e;
var int ret = 0;

par/and do
    async do end;
    pool[] Tx ts;
    var Tx&&? t = spawn Tx in ts with
        this.v = 10;
    end;
    emit e(t!);
    await 6s;
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 7 : invalid event type',
    --env = 'line 16 : wrong argument : cannot pass pointers',
    --run = { ['~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s']=-1 },
}

Test { [[
class Tx with
    var int v = 0;
do
    await 6s;
end

event Tx&& e;
var int ret = 0;

par/and do
    async do end;
    pool[] Tx ts;
    var Tx&&? t = spawn Tx in ts with
        this.v = 10;
    end;
    emit e(t!);
    await 6s;
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 7 : invalid event type',
    --env = 'line 16 : wrong argument : cannot pass pointers',
    --run = { ['~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s']=10 },
}

Test { [[
class Tx with
    var int v = 0;
do
    await 6s;
end

event Tx&& e;
var int ret = 0;

par/and do
    async do end;
    pool[] Tx ts;
    var Tx&&? t = spawn Tx in ts with
        this.v = 10;
    end;
    emit e(t!);
with
    var Tx&& p = await e;
    watching *p do
        do finalize with
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
    tmp = 'line 7 : invalid event type',
    --env = 'line 16 : wrong argument : cannot pass pointers',
    --run = { ['~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s;~>1s']=-1 },
}

Test { [[
class U with
do
end
native/pos do
    int V = 0;
end
class Item with
    var U&& u;
do
    watching *u do
        await FOREVER;
    end
native _V;
    _V = 1;
end
do
    var U u;
    spawn Item with
        this.u = &&u;
    end;
    await 1s;
end
native _assert;
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
native/pos do
    int V = 1;
end
class Item with
    var U&& u;
do
    watching *u do
        await FOREVER;
    end
native _V;
    _V = _V+1;
end
do
    var U u;
    spawn Item with
        this.u = &&u;
    end;
    await 1s;
end
native _assert;
_assert(_V == 2);
escape 1;
]],
    run = { ['~>1s'] = 1 },
    --fin = 'line 19 : attribution to pointer with greater scope',
}
Test { [[
class U with
do
    await FOREVER;
end
native/pos do
    int V = 1;
end
class Item with
    var U&& u;
do
    watching *u do
        await FOREVER;
    end
native _V;
    _V = _V+1;
end
do
    var U u;
    spawn Item with
        this.u = &&u;
    end;
    await 1s;
end
escape _V;
]],
    run = { ['~>1s'] = 2 },
    --fin = 'line 19 : attribution to pointer with greater scope',
}

Test { [[
class U with do end;
class Tx with
    var U&& u;
do
    watching *u do
        await FOREVER;
    end
native _V;
    _V = _V + 1;
end

native/pos do
    int V = 0;
end

do
    var U u;
    spawn Tx with
        this.u = &&u;
    end;
    await 1s;
end
native _assert;
_assert(_V == 1);
escape _V;
]],
    run = { ['~>1s'] = 1 },
    --fin = 'line 17 : attribution to pointer with greater scope',
}
Test { [[
native/pos do
    int V = 0;
end
class U with do end;
class Tx with
    var U&& u;
do
    watching *u do
        await FOREVER;
    end
native _V;
    _V = 1;
end
do
    var U u;
    spawn Tx with
        this.u = &&u;
    end;
    await 1s;
end
native _assert;
_assert(_V == 1);
escape 1;
]],
    run = { ['~>1s'] = 1 },
    --fin = 'line 16 : attribution to pointer with greater scope',
}
Test { [[
class U with do end;
class Tx with
    var U&& u;
do
    watching *u do
        await FOREVER;
    end
end

do
    var U u;
    spawn Tx with
        this.u = &&u;
    end;
end
escape 1;
]],
    run = 1,
    --fin = 'line 13 : attribution to pointer with greater scope',
}
Test { [[
class U with do end;
class Tx with
    var U&& u;
do
    watching *u do
        await FOREVER;
    end
end

class X with
    pool[] Tx ts;
do
    await FOREVER;
end

var X x;
do
    var U u;
    spawn Tx in x.ts with
        this.u = &&u;
    end;
end
escape 1;
]],
    run = 1,
    --fin = 'line 20 : attribution to pointer with greater scope',
}
Test { [[
class Run with
    var& int cmds;
do
end

do
    var int cmds=0;
    spawn Run with
        this.cmds = &cmds;
    end;
end

escape 1;
]],
    tmp = 'line 9 : invalid attribution : variable "cmds" has narrower scope than its destination',
    --ref = 'line 9 : attribution to reference with greater scope',
}
Test { [[
class Run with
    var& int cmds;
do
end

do
    pool[] Run rs;
    var int cmds=0;
    spawn Run in rs with
        this.cmds = &cmds;
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
var Unit&&? u;
pool[] Unit units;
u = spawn Unit in units;
await 2s;
watching *u! do
    emit u!:move(0);
end
escape 2;
]],
    run = { ['~>1min']='10] runtime error: invalid tag' },
    --fin = 'line 9 : unsafe access to pointer "u" across `await´',
}
Test { [[
class Unit with
    event int move;
do
    await FOREVER;
end
var Unit&&? u;
pool[] Unit units;
u = spawn Unit in units;
watching *u! do
    emit u!:move(0);
end
escape 2;
]],
    run = 2,
}

Test { [[
class Unit with
    var int pos=0;
do end;

var Unit&& ptr=null;
do
    var Unit u;
    ptr = &&u;
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

class Tx with
    event Unit&& org;
    event int   ok;
do
    var Unit&& u = await org;
    var int pos = 1;
    watching *u do
        pos = u:pos;
    end
    await 1s;
    emit ok(pos);
end

var Tx t;
await 1s;

do
    var Unit u with
        this.pos = 10;
    end;
    emit t.org(&&u);
end

var int v = await t.ok;
escape v;
]],
    tmp = 'line 6 : invalid event type',
    --env = 'line 25 : wrong argument : cannot pass pointers',
    --run = { ['~>2s']=1 },
}

Test { [[
native/pos do
    int V = 0;
end
input void OS_START,B;
class Tx with
    event void ok, go, b;
    event void e, f;
    var int v=0;
do
    v = 10;
    await e;
                            // (4)
    emit f;
                            // (6)
    v = 100;
    emit ok;
    await FOREVER;
end
var Tx a;                    // (1) v=10
var Tx&& ptr;
ptr = &&a;
watching *ptr do
    var int ret = 0;
    par/and do
        par/and do
            await OS_START;
            emit ptr:go;    // (2)
        with
            await ptr:ok;
                            // (7)
        end
        ret = ret + 1;      // ret=2
    with
        await B;
                            // (3)
        emit ptr:e;
        ret = ret + 1;
    with
        await ptr:f;
                            // (5)
        ret = ret + 1;      // ret=1
    end
native _V;
    _V = ret + ptr:v + a.v;     // _V=104
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
    var int pos=0;
do end;

var Unit&& ptr=null;
do
    var Unit u;
    u.pos = 10;
    ptr = &&u;
end
do
    vector[100] int v;
    loop i in [0 -> 100[ do
        v[i] = i;
    end
end
escape ptr:pos;
]],
    fin = 'line 9 : attribution to pointer with greater scope',
}

Test { [[
native/pos do
    int V = 0;
end
input void OS_START;
class Tx with
    event void ok, go;
    var int v=0, going=0;
do
    await go;
    going = 1;
    v = 10;
    emit ok;
end
var Tx a;
var Tx&& ptr;
ptr = &&a;
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
native _V;
    _V = ptr:v + a.v;
    escape ptr:v + a.v;
end
escape _V + 1;
]],
    --run = 21,
    run = 20,
}

Test { [[
class Tx with
    var int v = 0;
do
    await FOREVER;
end
pool[1] Tx ts;
var Tx&&? ok1 = spawn Tx in ts with
                this.v = 10;
              end;
watching *ok1! do
    var int ok2 = 0;// spawn Tx in ts;
    var int ret = 0;
    loop t in ts do
        ret = ret + t:v;
    end
    escape (ok1?) + ok2 + ret;
end
escape 1;
]],
    run = 11,
    --run = 1,
}

Test { [[
native/pos do
    int V = 0;
end
class Tx with
    var int v = 0;
do
    async do end;
end
pool[1] Tx ts;
var Tx&&? ok1 = spawn Tx in ts with
                this.v = 10;
              end;
watching *ok1! do
    var int ok2 = 0;// spawn Tx in ts;
    var int ret = 0;
    loop t in ts do
        ret = ret + t:v;
    end
native _V;
    _V = (ok1?) + ok2 + ret;
    escape (ok1?) + ok2 + ret;
end
escape _V + 1;  // this one executes because of strong abortion in the watching
]],
    _ana = {
        acc = true,
    },
    run = 11,
    --run = 12,
}

Test { [[
class Tx with
    event (int,int) ok_game;
do
    await 1s;
    emit this.ok_game(1,2);
end
var Tx t;
var Tx&& i = &&t;
var int a,b;
watching *i do
    (a,b) = await i:ok_game;
    emit i:ok_game(a,b);
end
escape a+b;
]],
    run = { ['~>1s']=3 },
}


Test { [[
input void OS_START;

class Tx with
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
    var Tx t;
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

class Tx with
    var U&& u;
do
    watching *u do
        await OS_START;
        emit u:x;
    end
end

do
    var U u;
    var Tx t with
        this.u = &&u;
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
    var V&&? v;
    event void x;
do
    loop do
        await x;
        v = spawn V;
        break;
    end
end

class Tx with
    var U&& u;
do
    watching *u do
        await OS_START;
        emit u:x;
native _assert;
        _assert(0);
    end
end

do
    var U u;
    var Tx t with
        this.u = &&u;
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

class Tx with
    interface UI;
do
end

class UIGridItem with
    var UI&& ui;
do
    watching *ui do
        await FOREVER;
    end
end

class UIGridPool with
    pool[] UIGridItem all;
do
    await FOREVER;
end

class UIGrid with
    var& UIGridPool uis;
do
end

do
    var UIGridPool pool1;
    var UIGrid g1 with
        this.uis = &pool1;
    end;

    var Tx g2;
    spawn UIGridItem in g1.uis.all with
        this.ui = &&g2;
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

class Tx with
    interface UI;
do
end

class UIGridItem with
    var UI&& ui;
do
    watching *ui do
        await FOREVER;
    end
end

class UIGridPool with
    pool[] UIGridItem all;
do
    await FOREVER;
end

class UIGrid with
    var& UIGridPool uis;
do
end

    var UIGridPool pool1;
    var UIGrid g1 with
        this.uis = &pool1;
    end;

    var Tx g2;
    spawn UIGridItem in g1.uis.all with
        this.ui = &&g2;
    end;
escape 1;
]],
    --fin = 'line 35 : attribution requires `finalize´',
    run = 1,
}

Test { [[
interface Screen with
    var& _GUIScreen? me;
end

interface IWorldmapScreen with
    interface Screen;
end

class WorldmapScreen with
    interface IWorldmapScreen;
do
end

var WorldmapScreen&&? ws = spawn WorldmapScreen with
    this.me = &_new_GUIScreen();
end;

escape 1;
]],
    fin = 'line 15 : attribution requires `finalize´',
}
Test { [[
interface UI with
end

class Tx with
    interface UI;
do
end

class UIGridItem with
    var UI&& ui;
do
    watching *ui do
        await FOREVER;
    end
end

class UIGridPool with
    pool[] UIGridItem all;
do
    await FOREVER;
end

class UIGrid with
    var& UIGridPool uis;
do
end

do
    var UIGridPool pool1;
    var UIGrid g1 with
        this.uis = &pool1;
    end;

    var Tx g2;
    spawn UIGridItem in pool1.all with
        this.ui = &&g2;
    end;
end

escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    int V = 0;
end
input void OS_START;

interface I with
    var int e;
end

class Tx with
    var int e=0;
do
    e = 100;
    await FOREVER;
end

var Tx t;
var I&& i = &&t;
watching *i do
    await OS_START;
native _V;
    _V = i:e;
    escape i:e;
end
escape _V + 1;
]],
    run = 100,
    --run = 101,
}

Test { [[
native/pos do
    int V = 0;
end

input void OS_START;

interface I with
    event void e;
    var int ee;
end

class Tx with
    event void e;
    var int ee=0;
do
    await e;
    ee = 100;
    await FOREVER;
end

var Tx t;
var I&& i = &&t;

watching *i do
    await OS_START;
    emit i:e;
native _V;
    _V = i:ee;
    escape i:ee;
end
escape _V + 1;
]],
    run = 100,
    --run = 101,
}

Test { [[
native/pos do
    int V = 0;
end

input void OS_START;

interface I with
    event int e, f;
    var int vv;
end

class Tx with
    event int e, f;
    var int vv=0;
do
    var int v = await e;
    vv = v;
    emit f(v);
    await FOREVER;
end

var Tx t1;
var I&& i1 = &&t1;

watching *i1 do
    var int ret = 0;
    par/and do
        await OS_START;
        emit i1:e(99);            // 21
    with
        var int v = await i1:f;
        ret = ret + v;
    with
        await OS_START;
    end
native _V;
    _V = ret;
    escape ret;
end
escape _V+1;
]],
    --run = 100,
    run = 99,
}

Test { [[
native/pos do
    int V = 0;
end

input void OS_START;

interface I with
    event int e, f;
end

class Tx with
    event int e, f;
do
    var int v = await e;
    emit f(v);
    await FOREVER;
end

var Tx t1, t2;
var I&& i1 = &&t1;

watching *i1 do
    var I&& i2 = &&t2;
    watching *i2 do
        var int ret = 0;
        par/and do
            await OS_START;
            emit i1:e(99);            // 21
        with
            var int v = await i1:f;
            ret = ret + v;
        with
            await OS_START;
            emit i2:e(66);            // 27
        with
            var int v = await i2:f;
            ret = ret + v;
        end
native _V;
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
native/pos do
    int V = 0;
end

interface I with
    var int v;
    code/tight Fx (var int)=>void;
end

class Tx with
    var int v=0;
    code/tight Fx (var int)=>void;
do
    v = 50;
    this.Fx(10);

    code/tight Fx (var int v)=>void do
        this.v = this.v + v;
    end
    await FOREVER;
end

var Tx t;
var I&& i = &&t;
input void OS_START;
watching *i do
    await OS_START;
    i:Fx(100);
native _V;
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
native/pos do
    int V = 0;
end

interface I with
    var int v;
    code/tight Fx (var int)=>void;
end

class Tx with
    interface I;
    var int v=0;
do
    v = 50;
    this.Fx(10);

    code/tight Fx (var int a)=>void do
        v = v + a;
    end
    await FOREVER;
end

var Tx t;
var I&& i = &&t;
input void OS_START;
watching *i do
    await OS_START;
    i:Fx(100);
native _V;
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
    code/tight Get (void)=>int;
    code/tight Set (var int)=>void;
end

class Tx with
    interface I;
    var int v = 50;
do
    code/tight Get (void)=>int do
        escape v;
    end
    code/tight Set (var int v)=>void do
        this.v= v;
    end
    await FOREVER;
end

var Tx t;
var I&& i = &&t;
var int v = i:v;
i:set(100);
escape v + i:get();
]],
    wrn = true,
    run = 150,
}

Test { [[
native/pos do
    int V = 0;
end

interface I with
    var int v;
    code/tight Fx (var int)=>void;
end

class Tx with
    interface I;
    var int v=0;
do
    v = 50;
    this.Fx(10);

    code/tight Fx (var int v)=>void do
        this.v = this.v + v;
    end
    await FOREVER;
end

class U with
    interface I;
    var int v=0;
do
    v = 50;
    this.Fx(10);

    code/tight Fx (var int v)=>void do
        this.v = this.v + 2*v;
    end
    await FOREVER;
end

var Tx t;
var U u;
var I&& i = &&t;
input void OS_START;
watching *i do
    await OS_START;
    i:Fx(100);
    var int ret = i:v;

    i=&&u;
    i:Fx(200);
native _V;
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
class Tx with
    var int v = 0;
do
    this.v = 10;
end

var int ret = 1;
var Tx&&? t = spawn Tx;
if t? then
    watching *t! do
        do finalize with
            ret = t!:v;
        end
        await FOREVER;
    end
end

escape ret;
]],
    run = 1,
}

Test { [[
class Tx with
    var int v = 0;
do
    this.v = 10;
end

var Tx&&? t = spawn Tx;
watching *t! do
    await FOREVER;
end

escape t!:v;
]],
    run = '8] runtime error: invalid tag',
    --fin = 'line 12 : unsafe access to pointer "t" across `await´',
}

Test { [[
class Tx with
    var int v = 0;
do
    this.v = 10;
end

var Tx&&? t = spawn Tx;
watching *t! do
    await FOREVER;
end

await 1s;

escape t!:v;
]],
    run = '8] runtime error: invalid tag',
    --fin = 'line 14 : unsafe access to pointer "t" across `await´',
}

Test { [[
input void OS_START;
class Tx with
    var int id = 0;
do
    await OS_START;
end

pool[9999] Tx ts;
var Tx&& t0 = null;
loop i in [0 -> 9999[ do
    var Tx&&? t = spawn Tx with
        this.id = 9999-i;
    end;
    if t0 == null then
        t0 = t!;
    end
end

watching *t0 do
    await FOREVER;
end
var int ret = t0:id;

escape ret;
]],
    fin = 'line 14 : unsafe access to pointer "t0" across `loop´ (/tmp/tmp.ceu : 10)',
    --run = 9999,
}

Test { [[
input void OS_START;
class Tx with
    var int id = 0;
do
    await OS_START;
end

pool[9999] Tx ts;
loop i in [0 -> 9999[ do
    var Tx&& t0 = null;
    var Tx&&? t = spawn Tx with
        this.id = 9999-i;
    end;
    if t0 == null then
        t0 = t!;
    end
end

escape 1;
]],
    fin = 'line 14 : unsafe access to pointer "t0" across `spawn´',
    --run = 9999,
}

Test { [[
class Tx with
    var int v = 10;
do
    await 1s;
end

var Tx t1;
var Tx&&? ptr = &&t1;
await 1s;
var Tx t2;
ptr = &&t2;
await 200ms;

escape ptr!:v;
]],
    run = { ['~>10s']=10 },
}

-- UNTIL

Test { [[
native/pos do
    int V = 0;
end
input int A;
var int v = 0;
native _V;
par/or do
    every 10s do
        _V = _V + 1;
    end
with
    loop do
        await 10s;
        if v as bool then
            break;
        end
    end
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
native/pos do
    int V = 0;
end
input int A;
var int v = 0;
native _V;
par/or do
    every 10s do
        _V = _V + 1;
    end
with
    loop do
        await 10s;
        if v as bool then
            break;
        end
    end
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
    loop do
        await 10s;
        if v as bool then
            break;
        end
    end
    escape 10;
with
    await 10min;
    v = 1;
with
    async do
        emit 10min10s;
    end
end
]],
    _ana = {
        acc = 1,
    },
    run = 10,
}

Test { [[
input void OS_START;

interface Global with
    var int x;
end

var int x = 10;

class Tx with
    var int x=0;
do
    this.x = global:x;
end

var Tx t;
await OS_START;
escape t.x;
]],
    run = 10,
}

Test { [[
input int A, E;
var int n_shields = 0;
var int ret = 1;
par/or do
    await A;
with
    loop do
        var int v = await E until (n_shields > 0);
        ret = ret + v;
    end
end

escape ret;
]],
    run = { ['1~>E; 1~>E; 1~>A'] = 1 }
}
Test { [[
input void A, E;
var int n_shields = 0;
var int ret = 1;
par/or do
    await A;
with
    loop do
        await E until (n_shields > 0);
        ret = ret + 10;
    end
end

escape ret;
]],
    run = { ['~>E; ~>E; ~>A'] = 1 }
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
var Controller&&   i;
i = &&c;
escape 1;
]],
    wrn = true,
    tmp = 'line 12 : types mismatch (`Controller&&´ <= `KeyController&&´)',
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
var Controller&&   i;
i = &&c;
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
        emit I(1,2);
        emit I(1,2);
        emit 5s;
    end
end
escape ret;
]],
    run = 6,
}

Test { [[
input void A, B;
loop do
    if true then
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
    if true then
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
    if true then
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
loop i in [0 -> 10[ do
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
    run = false,
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
input void A,B, X;
loop do
    par/or do
        loop do
            await A;
        end
        await X;
    with
        await X;
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
input void A,B, X;
loop do
    par/or do
        loop do
            await A;
        end
    with
        await X;
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
class Tx with
    event void e;
do
    await A;
    await A;
end
var Tx a,b;
native _f;
var int c=0;
par do
    loop do
        _f();
        await A;
        if false then
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
    cc = 'error: implicit declaration of function',
    awaits = 3,
}
Test { [[
input void A, B;
class Tx with
    event void e;
do
    await A;
    await A;
end
var Tx a,b;
native _f;
var int c=0;
par do
    loop do
        _f();
        await A;
        if false then
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
    cc = 'error: implicit declaration of function',
}
--do return end

Test { [[
input int A, B;
class Tx with
    event int e;
do
    await A;
    await A;
end
var Tx a,b;
native _f;
var int c=0;
par do
    loop do
        _f();
        var int x = await A;
        if false then
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
    cc = 'error: implicit declaration of function',
}

Test { [[
input void A, B, X;
loop do
    par/or do
        await A;
    with
        await B;
    end
    await X;
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
class Tx with
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
class Tx with
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
    var Tx a;
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
var int a=_, b=_;
(a) = 1;
escape 1;
]],
    wrn = true,
    --parser = 'line 2 : before `=´ : expected `,´',
    --env = 'line 2 : arity mismatch',
    run = 1,
}

Test { [[
var int a, b;
(a,b) = 1;
escape 1;
]],
    parser = 'line 2 : after `=´ : expected `request´ or `await´ or `watching´ or `(´',
    --parser = 'line 2 : before `=´ : expected `,´',
    --env = 'line 2 : arity mismatch',
    --run = 1,
}

Test { [[
input (int) A;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
native _int;
input (_int,int) A;
escape 1;
]],
    wrn = true,
    run = 1;
}

Test { [[
input (int&&,int) A;
//event (int,int&&) a;
escape 1;
]],
    wrn = true,
    run = 1;
}

Test { [[
input (int,int) A;
event (int,int) a;
escape 1;
]],
    wrn = true,
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
        emit A(1,2);
    end
end
escape 1;
]],
    stmts = 'line 4 : invalid variable : unexpected context for event "a"',
    --env = 'line 4 : wrong argument #1',
    --env = 'line 4 : invalid attribution',
}

Test { [[
input (int,int&&) A;
par/or do
    var int a,b;
    (a,b) = await A;
    escape a + b;
with
    async do
        //emit A(1,null);
    end
end
escape 1;
]],
    stmts = 'line 4 : invalid assignment : types mismatch : "(int,int)" <= "(int,int&&)"',
}

Test { [[
input (int,int&&) A;
par/or do
    var int a,b;
    //(a,b) = await A;
    escape a + b;
with
    async do
        emit A(1,2);
    end
end
escape 1;
]],
    stmts = 'line 8 : invalid `emit´ : types mismatch : "(int,int&&)" <= "(int,int)"',
}

Test { [[
input (int,int) A;
par/or do
    var int a,b;
    (a,b) = await A;
    escape a + b;
with
    async do
        emit A(1,2);
    end
end
escape 1;
]],
    run = 3;
}

Test { [[
event (int,int) a;
par/or do
    var int a=_,b=_;
    //(a,b) = await a;
    escape a + b;
with
    async (a) do
        emit a(1,2);
    end
end
escape 1;
]],
    wrn = true,
    --env = 'line 4 : event "a" is not declared',
    stmts = 'line 7 : invalid variable : unexpected context for event "a"',
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
    emit a(1,2);
end
escape 1;
]],
    run = 3,
}

Test { [[
event (int,int) e;
emit e(1,2,3);
escape 1;
]],
    stmts = 'line 2 : invalid `emit´ : types mismatch : "(int,int)" <= "(int,int,int)"',
}

-->>> INCLUDE/PRE

Test { [[
#if 0
escape 0;
#else
escape 1;
#endif
]],
    opts = {
        pre        = true,
        pre_input  = '/tmp/tmp.ceu',
        pre_output = '/tmp/tmp.ceu.cpp',
    },
    run = 1,
}

Test { [[
#oiii
escape 0;
]],
    opts = {
        pre        = true,
        pre_input  = '/tmp/tmp.ceu',
        pre_output = '/tmp/tmp.ceu.cpp',
    },
    pre = '1:2: error: invalid preprocessing directive #oiii',
}

Test { [[
native/pos do
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
    opts_pre = true,
    pre = 'error: #include expects "FILENAME" or <FILENAME>',
}

Test { [[
#include "MOD1"
#include "http://ceu-lang.org/"
#include "https://github.com/fsantanna/ceu"
#include "^4!_"
escape 1;
]],
    opts_pre = true,
    pre = 'fatal error: MOD1: No such file or directory',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
input void A;
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
await A;
escape 1;
]],
    opts_pre = true,
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
    opts_pre = true,
    parser = '/tmp/_ceu_MOD1.ceu : line 4 : after `A´ : expected `,´ or `;´',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
input void A;
native/pos do ##include <assert.h> end
native _assert;
_assert(0);
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
await A;
escape 1;
]],
    opts_pre = true,
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
    opts_pre = true,
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
    opts_pre = true,
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
    opts_pre = true,
    dcls = '/tmp/_ceu_MOD2.ceu : line 1 : declaration of "A" hides previous declaration (/tmp/_ceu_MOD1.ceu : line 1)',
    --dcls = '/tmp/_ceu_MOD2.ceu : line 1 : identifier "A" is already declared (/tmp/_ceu_MOD1.ceu : line 1)',
    --wrn = true,
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
    opts_pre = true,
    parser = '/tmp/_ceu_MOD1.ceu : line 2 : after `A´ : expected `,´ or `;´',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
native/pos do
    int f () {
        escape 10;
    }
end
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
native _f;
escape _f();
]],
    opts_pre = true,
    run = 10,
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
native/pos do
    int f () {
        escape 10;
    }
end
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
#include "/tmp/_ceu_MOD1.ceu"
native _f;
escape _f();
]],
    opts_pre = true,
    cc = 'error: redefinition of',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
#ifndef MOD1
#define MOD1
native/pos do
    int f () {
        escape 10;
    }
end
#endif
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
#include "/tmp/_ceu_MOD1.ceu"
native _f;
escape _f();
]],
    opts_pre = true,
    run = 10,
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
interface Tx with
    var int i;
end
var int i = 0;
]])
Test { [[
//
//
#include "/tmp/_ceu_MOD1.ceu"
interface Tx with
    var int i;
end
var int i = 10;
escape i;
]],
    opts_pre = true,
    tmp = 'line 4 : top-level identifier "Tx" already taken',
    --env = '/tmp/tmp.ceu : line 4 : interface/class "Tx" is already declared',
}

INCLUDE('/tmp/_ceu_MOD1.ceu', [[
interface Tx with
    var int i;
end
var int i = 0;
]])
Test { [[
//
//
interface Tx with
    var int i;
end
#include "/tmp/_ceu_MOD1.ceu"
var int i = 10;
escape i;
]],
    opts_pre = true,
    tmp = 'line 1 : top-level identifier "Tx" already taken',
    --env = '/tmp/_ceu_MOD1.ceu : line 1 : interface/class "Tx" is already declared',
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
    tmp = 'line 2 : top-level identifier "Global" already taken',
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
native/pos do
    int f () {
        escape 10;
    }
    int A;
    int B;
end
]])
Test { [[
#include "/tmp/_ceu_MOD1.ceu"
native _f;
escape _f();
]],
    run = 10,
}

Test { [[
native/pos do
    ##include <unistd.h>
end
escape 1;
]],
    run = 1,
}

-- CLASSES/THREADS

Test { [[
class Tx with
    event int ok;
do
    var int v=0;
    var& int p = &v;
    async/thread (p) do
        var int ret = 0;
        loop i in [0 -> 50000[ do
            loop j in [0 -> 50000[ do
                ret = ret + i + j;
            end
        end
        atomic do
            p = ret;
        end
    end
    emit ok(v);
end

var Tx t1, t2;
var int v1=0, v2=0;

par/and do
    v1 = await t1.ok;
with
    v2 = await t2.ok;
end

native/pos do ##include <assert.h> end
native _assert;
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

-- CLASSES/REFS / &

Test { [[
class Tx with
    var int x=0;
do
end
class U with do end;
event Tx& e;
par/and do
   do
      await 1s;
      var Tx t;
      emit e(t);
   end
   var U u;
with
   var& Tx t = await e;
   t.x = 1;
   await 1s;
end
escape 1;
]],
    parser = 'line 6 : after `Tx´ : expected type modifier or internal identifier',
    --env = 'line 6 : invalid event type',
}

Test { [[
class Tx with
    var int x=0;
do
end
class U with do end;
event (Tx&,int) e;
par/and do
   do
      await 1s;
      var Tx t;
      emit e(t,1);
   end
   var U u;
with
   var& Tx t;
   var int i;
   (t,i) = await e;
   t.x = 1;
   await 1s;
end
escape 1;
]],
    parser = 'line 6 : after `Tx´ : expected type modifier or `,´ or `)´',
    --parser = 'line 6 : after `Tx´ : expected `,´',
    --env = 'line 6 : invalid event type',
    --run = 1,
}

Test { [[
var& int i = 1;
escape 1;
]],
    inits = 'line 1 : invalid binding : expected operator `&´ in the right side',
    --ref = 'line 1 : invalid attribution',
}

Test { [[
var int&& p=null;
var& int i = *p;
escape 1;
]],
    inits = 'line 2 : invalid binding : expected operator `&´ in the right side',
    --ref = 'line 2 : invalid attribution',
}

Test { [[
event int e;
var& int i = await e;
escape 1;
]],
    inits = 'line 2 : invalid binding : unexpected statement in the right side',
    --ref = 'line 2 : invalid attribution',
}

Test { [[
event int& e;
var& int i = await e;
escape 1;
]],
    parser = 'line 1 : after `int´ : expected type modifier or internal identifier',
}

Test { [[
native/plain _t;
native/nohold _f;
native/pre do
    #define f(a)
    typedef int t;
end
class Tx with
    var& _t t;
do
    await 1s;
    _f(&&t);
end
escape 1;
]],
    run = 1,
}

Test { [[
interface I with end;
class Tx with
    var I&& i = null;
do
end

var Tx t;
await 1s;
native _assert;
_assert(t.i == null);
escape 1;
]],
    run = { ['~>1s'] = 1 },
}

Test { [[
interface I with end;
class Tx with
    var I&& i = null;
do
end

var Tx t;
var I&& i = t.i;
await 1s;
native _assert;
_assert(t.i == null);
escape 1;
]],
    fin = 'line 10 : unsafe access to pointer "i" across `await´',
    --run = { ['~>1s'] = 1 },
}

Test { [[
interface I with end;
class Tx with
    var I&& i = null;
do
end

var Tx t;
var I&& i = t.i;
await 1s;
native _assert;
_assert(i == null);
escape 1;
]],
    fin = 'line 10 : unsafe access to pointer "i" across `await´',
}

Test { [[
class Tx with do end

class Pool with
    pool[] Tx all;
do
    await FOREVER;
end

interface Global with
    var Pool&& p;
end
var Pool&& p = null;

class S with
do
    await 1s;
    spawn Tx in global:p:all with
    end;
end

escape 1;
]],
    fin = 'line 17 : unsafe access to pointer "p" across `class´',
}

Test { [[
native/plain _t;
native/pre do
    typedef struct t {
        int v;
    } t;
end

class Unit with
    var _t t;
do
end

var Unit u with
    this.t = _t(30);
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

var Map m1;
var Map&& m=&&m1;
emit m:go_xy(1,1);

escape 1;
]],
    run = 1,
}

Test { [[
input void OS_START;
var int a = 1;
event int& e;
par do
    var& int v = await e;
    v = v + 1;
with
    await OS_START;
    var int b = 10;
    emit e(b);
    escape b;
end
]],
    parser = 'line 3 : after `int´ : expected type modifier or internal identifier',
    --env = 'line 3 : invalid event type',
    --run = 11,
}

Test { [[
input void OS_START;
var int a = 1;
event (int,int&) e;
par do
    var& int r;
    var int  v;
    (v,r) = await e;
    r = r + v;
with
    await OS_START;
    var int b = 10;
    emit e(4,b);
    escape b;
end
]],
    parser = 'line 3 : after `int´ : expected type modifier or `,´ or `)´',
    --run = 14,
}

Test { [[
interface Object with
    var _SDL_Rect rect;
end
class MoveObject with
    var Object&& obj = null;
do
native _assert;
    _assert(this.obj != null);
    await 1s;
    obj:rect.x = 1;
end
escape 1;
]],
    fin = 'line 9 : unsafe access to pointer "obj" across `await´',
}

Test { [[
native/plain _int;
interface Object with
    var _int v;
end
class MoveObject with
    var& Object obj;
do
    await 1s;
    obj.v = 1;
end
escape 1;
]],
    run = 1,
}
Test { [[
native/plain _int;
interface Object with
    var _int v;
end
class MoveObject with
    var& Object obj;
do
    await 1s;
    obj.v = 1;
end
class X with
    interface Object;
    var _int v=0;
do
end
var X xxx;
var MoveObject m with
    this.obj = &xxx;
end;
escape 1;
]],
    run = 1,
}
Test { [[
native/plain _int;
interface Object with
    var _int v;
end
class O with
    var _int v=0;
    interface Object;
do
    this.v = 10;
end
class MoveObject with
    var& Object obj;
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
class Tx with
    var int v = 0;
do
end
var Tx t with
    this.v = 10;
end;
var& Tx tt = &t;
tt.v = 5;
escape t.v;
]],
    run = 5,
}

Test { [[
native/plain _int;
interface Object with
    var _int v;
end
class O with
    var _int v=0;
    interface Object;
do
    this.v = 10;
end
class MoveObject with
    var _int v=0;
    var& Object obj;
do
    await 1s;
    obj.v = 1;
end
var O o;
var MoveObject m with
    this.obj = &o;
end;
await 2s;
escape o.v;
]],
    run = { ['~>2s']=1 },
}

Test { [[
class Parser with
    event int  evtByte;
    event void evtStop;
do end;

class Frame with
    code/tight RawWriteByte (var int)=>void;
do
    code/tight RawWriteByte (var int v)=>void do if v!=0 then end end;
end;

class Receiver with
    var& Parser up;
    var& Frame rx;
    event void evtReady;
do
    par do
        every pB in up.evtByte do
            rx.rawWriteByte(pB);
        end
    with
        every up.evtStop do
            emit evtReady;
        end
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
class U with do end;

class Tx with
    var U&& u;
do
    watching *u do
    end
end

var U&& u = null;
var Tx t with
    this.u = u;
end;

escape 1;
]],
    valgrind = false,
    run = 'SEGFAULT',
}

Test { [[
code/await Fx (event int e)=>void do
end
escape 0;
]],
    parser = 'line 1 : after `event´ : expected `&´',
}
Test { [[
code/await Fx (event& int e)=>void do
    await e;
end
escape 0;
]],
    wrn = true,
    run = 'TODO',
}
--<<< CLASSES, ORGS, ORGANISMS

-->>> REQUESTS

Test { [[
output/input/await X (var int max)=>void;
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
input/output/await X (var int max)=>void do
    if max then end;
    escape;
end
escape 1;
]],
    run = 1,
}

Test { [[
input/output/await [10] LINE (var int max)=>byte&&;
request LINE;
escape 1;
]],
    tmp = 'line 2 : arity mismatch',
    --env = 'line 2 : missing parameters on `emit´',
}

Test { [[
input/output/await [10] LINE (var int max)=>byte&&;
request LINE => "oi";
escape 1;
]],
    tmp = 'line 2 : wrong argument #2',
}

Test { [[
input/output/await [10] LINE (var int max)=>byte&&;
request LINE => 10;
escape 1;
]],
    props = 'line 2 : invalid `emit´',
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
output/input/await [10] LINE (var int max)=>byte&&;
par/or do
    request LINE => 10;
with
end
escape 1;
]],
    run = 1,
}

Test { [[
input void&& A;
do
    var void&& p;
    p = await A
        until p==null;
    var void&& p1 = p;
end
await FOREVER;
]],
    run = false,
    _ana = {
        isForever = true,
    },
}

Test { [[
var byte&&? ret = null;
escape (ret! == null) as int;
]],
    run = 1,
}

Test { [[
input (u8, byte&&) LINE;
par do
    var byte&&? ret;
    var u8 err;
    (err, ret) = await LINE;
    if err!=0 then end;
    escape (not ret?) as int;
with
    async do
        emit LINE(1,null);
    end
end
]],
    run = 1,
}

Test { [[
var int v = 1;
var& int? x;
if false then
    x = &v;
else
    x = &v;
end
escape x!;
]],
    run = 1,
}

Test { [[
var int? v;
if true then
    v = 1;
end
escape v!;
]],
    run = 1,
}

Test { [[
output/input/await [10] LINE (var int max)=>byte&&;
var byte&& ret = null;
par/or do
    var byte&&? ret1;
    var u8 err;
    (err, ret1) = request LINE => 10;
    ret = ret1!;
with
    await FOREVER;
end
escape *ret;
]],
    fin = 'line 11 : unsafe access to pointer "ret" across `await´',
    --fin = 'line 5 : invalid block for awoken pointer "ret"',
}

Test { [[
output/input/await [10] LINE (var int max)=>byte&&;
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
par/or do
    var byte&& ret;
    var u8 err;
    (err, ret) = request LINE => 10;
with
end
escape 1;
]],
    tmp = 'line 8 : payload "ret" must be an option type',
}

Test { [[
output/input/await [10] LINE (var int max)=>byte&&;
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
par/or do
    var byte&&? ret;
    var u8 err;
    (err, ret) = request LINE => 10;
    if err!=0 and ret? then end;
with
end
escape 1;
]],
    run = 1,
}

Test { [[
input/output/await [10] LINE (var int max)=>byte&&;
request LINE;
escape 1;
]],
    tmp = 'line 2 : arity mismatch',
    --env = 'line 2 : missing parameters on `emit´',
}

Test { [[
input/output/await [10] LINE (var int max)=>byte&&;
request LINE => "oi";
escape 1;
]],
    tmp = 'line 2 : wrong argument #2',
}

Test { [[
input/output/await [10] LINE (var int max)=>byte&&;
request LINE => 10;
escape 1;
]],
    props = 'line 2 : invalid `emit´',
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
output/input/await [10] LINE (var int max)=>byte&&;
par/or do
    request LINE => 10;
with
end
escape 1;
]],
    run = 1,
}

Test { [[
input int LINE;
var int? ret;
ret = await LINE;
escape ret!;
]],
    run = { ['10~>LINE'] = 10 },
    --env = 'line 4 : wrong argument #2',
}

Test { [[
input (int, byte&&) LINE;
var int err;
var u8? ret;
(err, ret) = await LINE;
escape 1;
]],
    --env = 'line 4 : wrong argument #2',
    stmts = 'line 4 : invalid assignment : types mismatch : "(int,u8?)" <= "(int,byte&&)"',
}

Test { [[
output/input/await [10] LINE (var int max)=>byte&&;
var u8 err;
var u8? ret;
(err, ret) = request LINE => 10;
escape 1;
]],
    tmp = 'line 4 : wrong argument #3',
    --env = 'line 3 : invalid attribution (u8 vs byte&&)',
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
output/input/await [10] LINE (var int max)=>int;
par/or do
    var u8 err;
    var int? ret;
    (err, ret) = request LINE => 10;
    if err and ret? then end;
with
end
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
output/input/await [10] LINE (var int)=>int do
    escape 1;     // missing <int "id">
end
par/or do
    var u8 err, ret;
    (err, ret) = request LINE => 10;
with
end
escape 1;
]],
    parser = 'line 4 : after `int´ : expected type modifier or `;´',
    --adj = 'line 4 : missing parameter identifier',
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
output/input/await [10] LINE (var int max)=>int do
    escape 1;
end
par/or do
    var u8 err;
    var u8? ret;
    (err, ret) = request LINE => 10;
with
end
escape 1;
]],
    props = 'line 4 : invalid `emit´',
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
input/output/await [10] LINE (var int max)=>int do
    escape 1;
end
par/or do
    var u8 err;
    var u8? ret;
    (err, ret) = request LINE => 10;
with
end
escape 1;
]],
    props = 'line 10 : invalid `emit´',
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
input/output/await [10] LINE (var int max)=>int do
    escape 1;
end
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
var int ret = 0;
input/output/await [10] LINE (var int max)=>int do
    ret = 1;
end
escape ret;
]],
    wrn = true,
    dcls = 'line 6 : internal identifier "ret" is not declared',
}

Test { [[
native _V;
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [10] LINE (var int max)=>int do
        _V = 10;
        escape 1;
    end
    await 1s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,10);
        emit 1s;
    end
end
]],
    wrn = true,
    run = 11,
}

Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [10] LINE (var int max)=>int do
native _V;
        _V = max;
    end
    await 1s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,10);
        emit 1s;
    end
end
]],
    run = 11,
}

Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [10] LINE (var int max)=>int do
native _V;
        _V = _V + max;
    end
    await 1s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,10);
        emit LINE_REQUEST(2,20);
        emit LINE_REQUEST(3,30);
        emit 1s;
    end
end
]],
    run = 61,
}

Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
    end
    input/output/await [2] LINE (var int max)=>int do
        await 1s;
    end
    await 1s;
    escape 1;
with
    async do
        emit LINE_REQUEST(1,10);
        emit LINE_REQUEST(1,10);
        emit 1s;
    end
end
]],
    run = 1,
}
Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await LINE (var int max)=>int do
        await 1s;
native _V;
        _V = _V + max;
    end
    await 1s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,10);
        emit LINE_REQUEST(1,10);
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
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [2] LINE (var int max)=>int do
        await 1s;
native _V;
        _V = _V + max;
    end
    await 1s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,10);
        emit LINE_REQUEST(2,20);
        emit LINE_REQUEST(3,30);
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
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [2] LINE (var int max)=>int do
        await 1s;
native _V;
        _V = _V + max;
    end
    await 2s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,10);
        emit LINE_REQUEST(2,20);
        emit LINE_REQUEST(3,30);
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
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [2] LINE (var int max)=>int do
        await 1s;
native _V;
        _V = _V + max;
    end
    await 3s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,11);
        emit LINE_REQUEST(2,22);
        emit LINE_REQUEST(3,30);
        emit 1s;
        emit LINE_REQUEST(4,13);
        emit LINE_REQUEST(5,24);
        emit LINE_REQUEST(6,30);
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
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [1] LINE (var int max)=>int do
        await 1s;
native _V;
        _V = _V + max;
    end
    await 3s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,11);
        emit LINE_REQUEST(2,22);
        emit LINE_REQUEST(3,30);
        emit 1s;
        emit LINE_REQUEST(4,13);
        emit LINE_REQUEST(5,24);
        emit LINE_REQUEST(6,30);
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
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [0] LINE (var int max)=>int do
        await 1s;
native _V;
        _V = _V + max;
    end
    await 3s;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,11);
        emit LINE_REQUEST(2,22);
        emit LINE_REQUEST(3,30);
        emit 1s;
        emit LINE_REQUEST(4,13);
        emit LINE_REQUEST(5,24);
        emit LINE_REQUEST(6,30);
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
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [10] LINE (var int max)=>int do
        await 1s;
native _V;
        _V = _V + max;
    end
    input void A;
    await A;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,11);
        emit LINE_REQUEST(2,22);
        emit LINE_CANCEL(1);
        emit 3s;
        emit A;
    end
end
]],
    run = 23,
}

Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [10] LINE (var int max)=>int do
        await 1s;
native _V;
        _V = _V + max;
    end
    input void A;
    await A;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,11);
        emit LINE_REQUEST(2,22);
        emit LINE_CANCEL(2);
        emit 3s;
        emit A;
    end
end
]],
    run = 12,
}

Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
        int V = 0;
    end
    input/output/await [10] LINE (var int max)=>int do
        await 1s;
native _V;
        _V = _V + max;
    end
    input void A;
    await A;
    escape _V+1;
with
    async do
        emit LINE_REQUEST(1,11);
        emit LINE_REQUEST(2,22);
        emit LINE_CANCEL(2);
        emit LINE_CANCEL(1);
        emit 3s;
        emit A;
    end
end
]],
    run = 1,
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
    int V = 0;
end
output/input/await LINE (var int max)=>int;
var int? v   = 0;
var int err = 0;
(err,v) = request LINE=>10;
escape err;
]],
    run = 1,
}

Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,0)
        int V = 0;
    end
    output/input/await LINE (var int max)=>int;
    var int? v  = 0;
    var int err = 0;
    (err,v) = request LINE=>10;
    escape v!+err;
with
    async do
        emit LINE_RETURN(1,1,10);
    end
end
]],
    run = 1,
}

Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,0)
        int V = 0;
    end
    output/input/await LINE (var int max)=>int;
    var int? v;
    var int err = 0;
    (err,v) = request LINE=>10;
    escape v!+err;
with
    async do
        emit LINE_RETURN(1,1,10);
    end
end
]],
    run = '10] runtime error: invalid tag',
}

Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,0)
        int V = 0;
    end
    output/input/await LINE (var int max)=>int;
    var int? v  = 0;
    var int err = 0;
    par/or do
        (err,v) = request LINE=>10;
    with
        await 5s;
        escape 999;
    end
    escape v!+err;
with
    async do
        emit LINE_RETURN(1,1,10);
        emit 5s;
    end
end
]],
    run = 1,
}

Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,0)
        int V = 0;
    end
    output/input/await LINE (var int max)=>int;
    var int? v  = 0;
    var int err = 0;
    par/or do
        (err,v) = request LINE=>10;
    with
        await 5s;
        escape 999;
    end
    escape v!+err;
with
    async do
        emit LINE_RETURN(2,1,10);
        emit 5s;
    end
end
]],
    run = 999,
}

Test { [[
par do
    native/pos do
        ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,0)
        int V = 0;
    end
    output/input/await LINE (var int max)=>int;
    var int? v  = 0;
    var int err = 0;
    par/or do
        (err,v) = request LINE=>10;
    with
        await 5s;
        escape 999;
    end
    escape v!+err;
with
    async do
        emit LINE_RETURN(2,1,10);
        emit 4s;
        emit LINE_RETURN(1,0,-1);
        emit 1s;
    end
end
]],
    run = -1,
}

Test { [[
output byte[] OUT;
vector[] byte xxx = [] .. "1234567890";
emit OUT([]..xxx);
escape 1;
]],
    parser = 'line 1 : after `byte´ : expected type modifier or external identifier',
    --env = 'line 1 : invalid event type',
}

Test { [[
output byte[]&& && OUT;
]],
    parser = 'line 1 : after `byte´ : expected type modifier or external identifier',
    --env = 'line 1 : invalid event type',
}
Test { [[
output byte[]& && OUT;
]],
    parser = 'line 1 : after `byte´ : expected type modifier or external identifier',
    --env = 'line 1 : invalid event type',
}
Test { [[
class Tx with do end
output Tx OUT;
]],
    tmp = 'line 2 : invalid event type',
}
Test { [[
class Tx with do end
output Tx&& OUT;
]],
    tmp = 'line 2 : invalid event type',
}

-- TODO: dropped support for i/o vectors

Test { [[
input byte[] IN;
var int ret = 0;
par/and do
    vector[] byte&& vec = await IN;
    ret = $vec;
with
    async do
        vector[] byte vec = [1,2,3,4,5];
        emit IN(&&vec);
    end
end
escape $vec;
]],
    parser = 'line 1 : after `byte´ : expected type modifier or external identifier',
    --env = 'line 1 : invalid event type',
}

Test { [[
native/pos do
    ##define ceu_out_emit_OUT(x) (x->_1->nxt)
end
output int[]&& OUT;
vector[] int xxx = [1,2,3,4,5];
var int ret = emit OUT(&&xxx);
escape ret;
]],
    run = 5,
    todo = 'TODO: dropped support for vector i/o',
}

Test { [[
native/pos do
    ##define ceu_out_emit_OUT(x) (x->_1->nxt)
end
output byte[]&& OUT;
vector[] byte xxx = [] .. "1234567890";
var int ret = emit OUT(&&xxx);
escape ret;
]],
    run = 10,
    todo = 'TODO: dropped support for vector i/o',
}

Test { [[
input byte[]&& IN;
var int ret = 0;
par/and do
    vector[] byte&& vec = await IN;
    ret = $*vec;
with
    async do
        vector[] byte vec = [1,2,3,4,5];
        emit IN(&&vec);
    end
end
escape ret;
]],
    run = 5,
    todo = 'TODO: dropped support for vector i/o',
}

Test { [[
native/pos do
    ##define ceu_out_emit_OUT(x) (x->_2->nxt + x->has_vector)
end
output (int,int[]&&,int) OUT;
vector[] int xxx = [1,2,3,4,5];
var int ret = emit OUT(0,&&xxx,1);
escape ret;
]],
    tmp = 'line 4 : invalid event type : vector only as the last argument',
    todo = 'TODO: dropped support for vector i/o',
}

Test { [[
native/pos do
    ##define ceu_out_emit_OUT(x) (x->_3->nxt + x->vector_offset)
end
output (int,int,int[]&&) OUT;
vector[] int xxx = [1,2,3,4,5];
var int ret = emit OUT(0,1,&&xxx);
escape ret;
]],
    opts = '--tuple-vector',
    run = 21,
    todo = 'TODO: dropped support for vector i/o',
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) ceu_out_event_F(a,b,c,d)
    int ceu_out_event_F (tceu_app* app, int id_out, int len, byte* data) {
        u8 vector_offset = (((u8*)data)[0]);
        tceu_vector** v = (tceu_vector**)(data + vector_offset);
        escape (*v)->nxt;
    }
end
output (int,int,int[]&&) OUT;
vector[] int xxx = [1,2,3,4,5];
var int ret = emit OUT(0,1,&&xxx);
escape ret;
]],
    opts = '--tuple-vector',
    run = 5,
    todo = 'TODO: dropped support for vector i/o',
}

Test { [[
output/input/await SERIAL_CHAR (void)=>byte;
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,0)
end

input void OS_START;
output/input/await SERIAL_CHAR (void)=>byte;

par/or do
    var int err;
    var byte? v;
    (err,v) = request SERIAL_CHAR;
    if err and v? then end;
with
end

escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,0)
end
input/output/await SERIAL_CHAR (void)=>byte do
    escape 'a';
end
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) ceu_out_event_F(a,b,c,d)
    int V = 0;
    int ceu_out_event_F (tceu_app* app, int id_out, int len, byte* data) {
        {
            u8 vector_offset = (((u8*)data)[0]);
            if (vector_offset > 0) {
                tceu_vector* v = *((tceu_vector**)(data + vector_offset));
                V = v->nxt;
            }
        }
        escape 1;
    }
end

input/output/await PING_PONG (var int x)=>byte[]&& do
    vector[] byte ret = [].."Pong ";
    native/nohold _printf;
native _char;
    _printf("%s\n", (_char&&)&&ret);
    escape &&ret;
end
async do
    emit PING_PONG_REQUEST(0,1);
end
native _V;
escape _V;
]],
    run = 5,
    opts = '--tuple-vector',
    todo = 'TODO: dropped support for vector i/o',
}

Test { [[
output/input/await PING_PONG (var int x)=>byte[]&&;
vector[] byte&&? ret;
par/and do
    var int i,err;
    (i,err,ret) = await PING_PONG_RETURN;
    native/nohold _printf;
native _char;
    _printf("%s\n", (_char&&)ret!);
    if i and err then end;
with
    async do
        vector[] byte str = [].."END: 10 0";
        emit PING_PONG_RETURN(0,0,&&str);
    end
end
escape 1;
]],
    run = 10,
    todo = 'TODO: dropped support for vector i/o',
}

Test { [[
native/plain _info;
native/pre do
    int V = 0;
    typedef struct info {
        int8_t i1;
        uint16_t i2;
    } info;
end

native/pos do
    ##define ceu_out_emit(a,b,c,d) ceu_sys_output_handler(a,b,c,d)
    int ceu_sys_output_handler(tceu_app* app, int evt_id, int evt_sz, void* evt_buf) {
        tceu__int__u8__info_h* k;
        switch (evt_id) {
            case CEU_OUT_TEST_RETURN:
                k = (tceu__int__u8__info_h*)evt_buf;
                V = V + k->_2;
            break;
        }
        escape 1;
    }
end

input/output/await [10] TEST (var u16 t)=>_info&& do
    var _info i = _info(42,89);
    escape &&i;
end

async do
    emit TEST_REQUEST(0,0);
end

native _V;
escape _V;
]],
    run = 5,
}
Test { [[
native/plain _info;
native/pre do
    int V = 0;
    typedef struct info {
        int8_t i1;
        uint16_t i2;
    } info;
end

native/pos do
    ##define ceu_out_emit(a,b,c,d) ceu_sys_output_handler(a,b,c,d)
    int ceu_sys_output_handler(tceu_app* app, int evt_id, int evt_sz, void* evt_buf) {
        tceu__int__u8__info_h* k;
        switch (evt_id) {
            case CEU_OUT_TEST_RETURN:
                k = (tceu__int__u8__info_h*)evt_buf;
printf("RET %p %d\n", evt_buf, k->_2);
                V = V + k->_2;
            break;
        }
        escape 1;
    }
end

input/output/await [10] TEST (var u16 t)=>_info&& do
    var _info i = _info(42,89);
    await 1s;
    escape &&i;
end

async do
    emit TEST_REQUEST(0,0);
end

await 2s;

native _V;
escape _V;
]],
    run = {['~>1s;~>2s']=2},
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,0)
    int V = 0;
end

class Test with
    var u8 k;
do
    await FOREVER;
end

interface Global with
    var Test&&? ptr;
end

var Test t with
    this.k = 5;
end;
var Test&&? ptr = &&t;

input/output/await RESOURCE [10] (void)=>void do
native _V;
    _V = global:ptr!:k;
end

async do
    emit RESOURCE_REQUEST(0);
end

escape _V;
]],
    run = 5,
}

--<<< REQUESTS
--]===]
-- TODO: SKIP



-->>> DATA / RECURSIVE

-- recursive ADTs must have a base case
Test { [[
data Opt;
data Opt.OptPTR with
    var void&& v;
end
escape 1;
]],
    wrn = true,
    adt = 'line 1 : invalid recursive base case : no parameters allowed',
}

-- the base case must appear first
Test { [[
data Opt;
data Opt.OptPTR with
    var void&& v;
end
data Opt.OptNIL;
escape 1;
]],
    wrn = true,
    adt = 'line 1 : invalid recursive base case : no parameters allowed',
}

-- the base must not have fields
Test { [[
data Opt;
data Opt.OptNIL with
    var int x;
end
data Opt.OptPTR with
    var void&& v;
end
escape 1;
]],
    wrn = true,
    adt = 'line 1 : invalid recursive base case : no parameters allowed',
}

Test { [[
data Opt;
data Opt.Nothing;

data Opt1;
data Opt1.Nothing;

escape 1;
]],
    wrn = true,
    --dcls = 'line 5 : identifier "Nothing" is already declared (/tmp/tmp.ceu : line 2)',
    --dcls = 'line 5 : declaration of "Nothing" hides previous declaration (/tmp/tmp.ceu : line 2)',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end
escape 1;
]],
    wrn = true,
    run = 1,
    --env = 'line 6 : undeclared type `List´',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end
var List l = val List.Cons(1,
               List.Cons(2,
                   List.Nil()));
escape 1;//((l as List.Cons).tail) as List.Cons).@head@;
]],
    adt = 'line 9 : invalid constructor : recursive data must use `new´',
    --env = 'line 9 : types mismatch (`List´ <= `List&&´)',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end
var List l = new List.Cons(1,
                  List.Cons(2,
                   List.Nil()));
escape 1;//(((l as List.Cons).tail) as List.Cons).@head@;
]],
    --exps = 'line 7 : invalid constructor : unexpected context for variable "l"',
    --env = 'line 9 : types mismatch (`List´ <= `List&&´)',
    --adt = 'line 9 : invalid attribution : must assign to recursive field',
    adt = 'line 7 : invalid attribution : not a pool',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end
var List&& l = val List.Cons(1,
                List.Cons(2,
                    List.Nil()));
escape 1;//((l as List.Cons).tail) as List.Cons).@head@;
]],
    --env = 'line 9 : types mismatch (`List&&´ <= `List´)',
    adt = 'line 7 : invalid constructor : recursive data must use `new´',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

var List&& l = new List.Cons(1,
                   List.Cons(2,
                    List.Nil()));
escape 0;//((l as List.Cons).tail) as List.Cons).@head@;
]],
    --env = 'line 9 : types mismatch (`List&&´ <= `List´)',
    --adt = 'line 9 : invalid constructor : recursive data must use `new´',
    --adt = 'line 9 : invalid attribution : must assign to recursive field',
    adt = 'line 8 : invalid attribution : not a pool',
    --exps = 'line 8 : invalid constructor : unexpected context for variable "l"',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[10] List l;
l = val List.Cons(1,
        List.Cons(2,
            List.Nil()));

escape 0;//((l as List.Cons).tail) as List.Cons).@head@;
]],
    stmts = 'line 9 : invalid constructor : unexpected context for pool "l"',
    --adt = 'line 9 : invalid constructor : recursive data must use `new´',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[10] List lll;
escape (lll is List.Nil) as int;
]],
    wrn = true,
    run = 1,
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[10] List lll;
escape ((lll is List.Cons) as int) + 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
native/pos do
    ##ifndef CEU_ADTS_NEWS_POOL
    ##error bug found
    ##endif
end

data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[10] List lll = new List.Cons(1, List.Nil());
escape (lll as List.Cons).head;
]],
    wrn = true,
    run = 1,
}

Test { [[
native/pos do
    ##ifndef CEU_ADTS_NEWS_POOL
    ##error bug found
    ##endif
end

data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[10] List lll = new List.Cons(1, List.Nil());
escape lll.head;
]],
    names = 'line 15 : invalid member access : "lll" has no member "head" : `data´ "List" (/tmp/tmp.ceu:7)',
    --env = 'TODO: no head in lll',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[10] List lll;
lll = new List.Cons(1,
            List.Cons(2,
                List.Nil()));
escape ((lll as List.Cons).tail as List.Cons).head;
]],
    run = 2,
}

Test { [[
data Stack;
data Stack.Empty;
data Stack.NonEmpty with
    var Stack&& nxt;
end

pool[] Stack xxx = new Stack.NonEmpty(
                    Stack.NonEmpty(xxx));

escape 1;
]],
    stmts = 'line 8 : invalid constructor : argument #1 : unexpected context for pool "xxx"',
    wrn = true,
    --env = 'line 10 : invalid constructor : recursive field "NONEMPTY" must be new data',
}

Test { [[
data Split;
data Split.Horizontal;
data Split.Vertical  ;

data Grid;
data Grid.Empty;
data Grid.Split with
    var Split dir;
    var Grid  one;
    var Grid  two;
end

pool[] Grid g;
g = new Grid.Split(Split.Horizontal(), Grid.Empty(), Grid.Empty());

escape (((g as Grid.Split).one is Grid.Empty) as int) + (((g as Grid.Split).two is Grid.Empty) as int) + (((g as Grid.Split).dir is Split.Horizontal) as int);
]],
    wrn = true,
    run = 3,
}

Test { [[
data Split;
data Split.Horizontal;
data Split.Vertical  ;

data Grid with
    var Split dir;
end

var Grid g1 = val Grid(Split.Horizontal());
var Grid g2 = val Grid(Split.Vertical());

escape ((g1.dir is Split.Horizontal) as int) + ((g2.dir is Split.Vertical) as int);
]],
    run = 2,
}

Test { [[
data Split;
data Split.Horizontal;
data Split.Vertical  ;

data Grid;
data Grid.Empty;
data Grid.Split with
    var Split dir;
    var Grid  one;
    var Grid  two;
end

pool[5] Grid g = new Grid.Split(
                    Split.Horizontal(),
                    Grid.Split(
                        Split.Vertical(),
                        Grid.Empty(),
                        Grid.Empty()));

escape 1;
]],
    exps = 'line 13 : invalid constructor : expected 3 argument(s)',
}

Test { [[
data Split;
data Split.Horizontal;
data Split.Vertical  ;

data Grid;
data GridEmpty;
data GridSplit with
    var Split dir;
    var Grid  one;
    var Grid  two;
end

pool[5] Grid g;
g = new GridSplit(
            Split.Horizontal(),
            GridSplit(
                Split.Vertical(),
                GridEmpty(),
                GridEmpty()),
            GridEmpty());

escape 1;
]],
    exps = 'line 16 : invalid constructor : argument #2 : types mismatch : "Grid" <= "GridEmpty"',
}

Test { [[
data Split;
data Split.Horizontal;
data Split.Vertical  ;

data Grid;
data Grid.Empty;
data Grid.Split with
    var Split dir;
    var Grid  one;
    var Grid  two;
end

pool[5] Grid g;
g = new Grid.Split(
            Split.Horizontal(),
            Grid.Split(
                Split.Vertical(),
                Grid.Empty(),
                Grid.Empty()),
            Grid.Empty());

escape 1;
]],
    run = 1,
}

Test { [[
data Split;
data Split.Horizontal;
data Split.Vertical  ;

data Grid;
data Grid.Empty;
data Grid.Split with
    var Split dir;
    var Grid  one;
    var Grid  two;
end

pool[] Grid g = new Grid.Split(
                    Split.Horizontal(),
                    Grid.Empty(),
                    Grid.Empty());

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Dx;
data Dx.Nil;
data Dx.Rec with
    var Dx r1;
    var Dx r2;
end

pool[] Dx ds = new Dx.Rec(
                    Dx.Rec(Dx.Nil(),Dx.Nil()),
                    Dx.Nil());

par/or do
    await (ds as Dx.Rec).r1;
with
    (ds as Dx.Rec).r1 = new Dx.Nil();
end

escape 1;
]],
    _ana = {acc=true},
    run = 1,
}

Test { [[
data Tree;
data Tree.Nil;
data Tree.Node with
    var int   v;
    var Tree  left;
    var Tree  right;
end

pool[3] Tree tree;
tree = new Tree.Node(1,
            Tree.Node(2, Tree.Nil(), Tree.Nil()),
            Tree.Node(3, Tree.Nil(), Tree.Nil()));

class Sum with
    var int&& v;
do
    await FOREVER;
end

class Body with
    pool&[]  Body bodies;
    var   Tree&&   n;
    var&   Sum    sum;
do
    watching *n do
        if *n is Tree.Node then
            *this.sum.v = *this.sum.v + (*n as Tree.Node).v;
            spawn Body in this.bodies with
                this.bodies = &bodies;
                this.n      = && (*n as Tree.Node).left;
                this.sum    = &sum;
            end;
        end
    end
end

var int v = 0;
var Sum sum with
    this.v = &&v;
end;

pool[7] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&tree;
    this.sum    = &sum;
end;

escape v;
]],
    fin = 'line 29 : unsafe access to pointer "v" across `class´ (/tmp/tmp.ceu : 22)',
}

--<<< DATA / RECURSIVE

-- USE DATATYPES DEFINED ABOVE ("DATA")

-- simple test
Test { DATA..[[
escape 1;
]],
    wrn = true,
    run = 1,
}

-- constructors
Test { DATA..[[
var Pair p1 = val Pair(1,2);        /* struct, no tags */
var Opt  o1 = val Opt.Nothing();        /* unions, explicit tag */
var Opt  o2 = val Opt.Ptr(&&p1);
pool[] List l1;
l1 = new List.Nil();       /* recursive union */
pool[] List l2 = new List.Cons(1, l1);
escape 1;
]],
    stmts = 'line 56 : invalid constructor : argument #2 : unexpected context for pool "l1"',
    --env = 'line 56 : invalid constructor : recursive field "Cons" must be new data',
    -- TODO-ADT-Rec-STATIC-CONSTRS
    --run = 1,
}

-- recursive fields are pointers
Test { DATA..[[
pool[] List l1 = new List.Nil();
pool[] List l2;
l2 = new List.Cons(1, l1);     /* should be &&l1 */
escape 1;
]],
    wrn = true,
    --env = 'line 53 : invalid constructor : recursive field "Cons" must be new data',
    stmts = 'line 53 : invalid constructor : argument #2 : unexpected context for pool "l1"',
}

-- constructors must specify the ADT identifier
Test { DATA..[[
var Pair p1 = (1,2);    /* vs Pair(1,2) */
escape 1;
]],
    -- TODO: better error message
    parser = 'line 51 : after `1´ : expected `is´ or `as´ or binary operator or `)´',
    --run = 1,
}
Test { DATA..[[
pool[] List l1 = new List.Nil();    /* vs List.Nil() */
escape 1;
]],
    wrn = true,
    run = 1,
}

-- ADT/constructor has to be defined
Test { DATA..[[
var Pair p1 = val Unknown(1,2);
escape 1;
]],
    dcls = 'line 51 : abstraction "Unknown" is not declared',
}
Test { DATA..[[
var Opt  o1 = val UnknownNIL();
escape 1;
]],
    dcls = 'line 51 : abstraction "UnknownNIL" is not declared',
    --env = 'line 51 : data not."Unknown" declared',
}

-- tag has to be defined
Test { DATA..[[
var Opt o1 = val Unknown();
escape 1;
]],
    dcls = 'line 51 : abstraction "Unknown" is not declared',
}

-- constructors have call syntax
Test { DATA..[[
var List l1 = val List.Nil; /* vs List.Nil() */
escape 1;
]],
    parser = 'line 51 : after `List.Nil´ : expected `(´',
    --run = 1,
}

-- constructors must respect parameters
Test { DATA..[[
var Pair p1 = val Pair();           /* expected (x,y) */
escape 1;
]],
    wrn = true,
    --env = 'line 51 : arity mismatch',
    exps = 'line 51 : invalid constructor : expected 2 argument(s)',
}
Test { DATA..[[
var Pair p1 = val Pair(1,null);     /* expected (int,int) */
escape 1;
]],
    wrn = true,
    --env = 'line 51 : wrong argument #2',
    exps = 'line 51 : invalid constructor : argument #2 : types mismatch : "int" <= "null&&"',
}
Test { DATA..[[
var Opt o1 = val Opt.Nothing(1);       /* expected (void) */
escape 1;
]],
    wrn = true,
    --env = 'line 51 : arity mismatch',
    exps = 'line 51 : invalid constructor : expected 0 argument(s)',
}

-- constructors are not expressions...
Test { DATA..[[
escape call List();
]],
    wrn = true,
    exps = 'line 51 : invalid call : unexpected context for data "List"',
    --exps = 'line 51 : invalid call : "Nil" is not a `code´ abstraction',
    --ast = 'line 51 : invalid call',
    --env = 'TODO: not a code',
    --parser = 'line 51 : after `escape´ : expected expression',
}
Test { DATA..[[
escape call List.Nil();
]],
    wrn = true,
    parser = 'line 51 : after `call´ : expected name expression',
    --exps = 'line 51 : invalid call : unexpected context for data "List.Nil"',
    --exps = 'line 51 : invalid call : "Nil" is not a `code´ abstraction',
    --ast = 'line 51 : invalid call',
    --env = 'TODO: not a code',
    --parser = 'line 51 : after `escape´ : expected expression',
}
Test { DATA..[[
var List l;
var int v = (l==call List());
escape v;
]],
    wrn = true,
    --ast = 'line 52 : invalid call',
    exps = 'line 52 : invalid call : unexpected context for data "List"',
    --exps = 'line 52 : invalid call : "Nil" is not a `code´ abstraction',
    --env = 'TODO: not a code',
    --parser = 'line 52 : after `==´ : expected expression',
}

-- ...but have to be assigned to a variable
Test { DATA..[[
var Opt o;
o = val Opt.Nothing();
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { DATA..[[
pool[] List l;
l = new List.Nil();
escape 1;
]],
    wrn = true,
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
pool[] List l = new List.Nil();   /* call syntax: constructor */
var bool no_ = (l is List.Nil);     /* no-call syntax: check tag */
escape no_ as int;
]],
    wrn = true,
    run = 1,
}
Test { DATA..[[
pool[] List l;
l = new List.Nil();   /* call syntax: constructor */
var bool no_ = l is List.Cons;    /* no-call syntax: check tag */
escape no_ as int;
]],
    wrn = true,
    run = 0,
}

-- destructor == field access
Test { DATA..[[
var Pair p1 = val Pair(1,2);
escape p1.x + p1.y;
]],
    wrn = true,
    run = 3,
}
-- tag Nil has no fields
Test { DATA..[[
pool[] List l;
escape (l as List.Nil).v;
]],
    wrn = true,
    names = 'line 52 : invalid member access : "l" has no member "v" : `data´ "List.Nil" (/tmp/tmp.ceu:16)',
    --env = 'line 52 : field "v" is not declared',
}
-- tag Opt.Ptr has no field "x"
Test { DATA..[[
var Opt o;
escape (o as Opt.Ptr).x;
]],
    wrn = true,
    names = 'line 52 : invalid member access : "o" has no member "x" : `data´ "Opt.Ptr" (/tmp/tmp.ceu:10)',
}

-- mixes Pair/Opt/List and also construcor/tag-check/destructor
Test { DATA..[[
pool[] List l1 = new List.Nil();
pool[] List l2 = new List.Cons(1, List.Nil());
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { DATA..[[
var Pair p1 = val Pair(1,2);
var Opt  o1 = val Opt.Nothing();
var Opt  o2 = val Opt.Ptr(&&p1);
pool[] List l1 = new List.Nil();
pool[] List l2;
l2 = new List.Cons(1, List.Nil());
pool[] List l3 = new List.Cons(1, List.Cons(2, List.Nil()));

var int ret = 0;                                // 0

ret = ret + p1.x + p1.y;                        // 3
ret = ret + ((o1 is Opt.Nothing) as int);                             // 4
ret = ret + (((o2 as Opt.Ptr).v==&&p1)as int);                    // 5
ret = ret + ((l1 is List.Nil) as int);                             // 6
ret = ret + (l2 as List.Cons).head + (((l2 as List.Cons).tail is List.Nil) as int);    // 8
ret = ret + (l3 as List.Cons).head + ((l3 as List.Cons).tail as List.Cons).head + ((((l3 as List.Cons).tail as List.Cons).tail is List.Nil) as int);   // 12

escape ret;
]],
    run = 12,
}

-- destructors are checked at runtime
--      v = ((l as List.Cons).head)
-- becomes
--      assert(l.Cons)
--      v = ((l as List.Cons).head)
Test { DATA..[[
pool[] List l;
l = new List.Nil();
escape (l as List.Cons).head;         // runtime error
]],
    wrn = true,
    asr = true,
    --run = 1,
}
Test { DATA..[[
pool[] List l = new List.Cons(2, List.Nil());
escape (l as List.Cons).head;
]],
    wrn = true,
    run = 2,
}

-- mixes everything:
Test { DATA..[[
var Pair p  = val Pair(1,2);
var Opt  o1 = val Opt.Nothing();
var Opt  o2 = val Opt.Ptr(&&p);
pool[] List l1;
l1 = new List.Nil();
pool[] List l2 = new List.Cons(1, List.Nil());
pool[] List l3;
l3 = new List.Cons(1, List.Cons(2, List.Nil()));

var int ret = 0;            // 0

var int x = p.x;
var int y = p.y;
native _assert;
_assert(x+y == 3);
ret = ret + 3;              // 3

if o1 is Opt.Nothing then
    ret = ret + 1;          // 4
else/if o1 is Opt.Ptr then
    _assert(0);             // never reachable
end

if o2 is Opt.Nothing then
    _assert(0);             // never reachable
else/if o2 is Opt.Ptr then
    ret = ret + 1;          // 5
    _assert((o2 as Opt.Ptr).v==&&p);
end

if l1 is List.Nil then
    ret = ret + 1;          // 6
else/if l1 is List.Cons then
    _assert(0);             // never reachable
end

if l2 is List.Nil then
    _assert(0);             // never reachable
else/if l2 is List.Cons then
    _assert((l2 as List.Cons).head == 1);
    ret = ret + 1;          // 7
    if (l2 as List.Cons).tail is List.Nil then
        ret = ret + 1;      // 8
    else/if (l2 as List.Cons).tail is List.Cons then
        _assert(0);         // never reachable
    end
    ret = ret + 1;          // 9
end

if l3 is List.Nil then
    _assert(0);             // never reachable
else/if l3 is List.Cons then
    _assert((l3 as List.Cons).head == 1);
    ret = ret + 1;          // 10
    if (l3 as List.Cons).tail is List.Nil then
        _assert(0);         // never reachable
    else/if (l3 as List.Cons).tail is List.Cons then
        _assert(((l3 as List.Cons).tail as List.Cons).head == 2);
        ret = ret + 2;      // 12
        if ((l3 as List.Cons).tail as List.Cons).tail is List.Nil then
            ret = ret + 1;  // 13
        else/if ((l3 as List.Cons).tail as List.Cons).tail is List.Cons then
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
--      ptr as List.Cons).@tail@ = new ...             // ok
--      ptr as List.Cons).@tail@ = l....               // no
--      ptr as List.Cons).@tail@ = ptr as List.Cons).@tail@....   // ok
--          same prefix

-- cannot cross await statements
Test { DATA..[[
pool[] List l = new List.Cons(1, List.Nil());
var List&& p = (l as List.Cons).tail;
await 1s;
escape (*p as List.Cons).head;
]],
    wrn = true,
    stmts = 'line 52 : invalid assignment : types mismatch : "List&&" <= "List"',
    --adt = 'line 52 : invalid attribution : mutation : cannot mix data sources',
    --fin = 'line 54 : unsafe access to pointer "p" across `await´',
    --adt = 'line 52 : invalid attribution : value is not a reference',
}
Test { DATA..[[
do/_
    pool[] List l = new List.Cons(1, List.Nil());
    var List&& p = &&(l as List.Cons).tail;
    await 1s;
    escape (*p as List.Cons).head;
end
]],
    wrn = true,
    --adt = 'line 52 : mutation : cannot mix data sources',
    inits = 'line 55 : invalid pointer access : crossed `await´ (/tmp/tmp.ceu:54)',
    --fin = 'line 54 : unsafe access to pointer "p" across `await´',
    --adt = 'line 52 : invalid attribution : value is not a reference',
}
Test { DATA..[[
pool[] List l = new List.Cons(1, List.Nil());
var List&& p = &&(l as List.Cons).tail;
await 1s;
escape (*p as List.Cons).head;
]],
    wrn = true,
    --adt = 'line 52 : mutation : cannot mix data sources',
    inits = 'line 54 : invalid pointer access : crossed `await´ (/tmp/tmp.ceu:53)',
    --fin = 'line 54 : unsafe access to pointer "p" across `await´',
    --adt = 'line 52 : invalid attribution : value is not a reference',
}
Test { DATA..[[
pool[] List l = new List.Cons(1, List.Nil());
var List&& p = &&(l as List.Cons).tail;
await 1s;
escape (*p as List.Cons).head;
]],
    wrn = true,
    --adt = 'line 52 : cannot mix recursive data sources',
    inits = 'line 54 : invalid pointer access : crossed `await´ (/tmp/tmp.ceu:53)',
    --fin = 'line 54 : unsafe access to pointer "p" across `await´',
}

-- COPY / MUTATION
--  - intentional feature
--  - ADTs are substitutes for enum/struct/union
--  - must be "as efficient" and with similar semantics
-- TODO: more discussion

-- linking a list: 2-1-Nil
Test { DATA..[[
pool[] List l1;
l1 = new List.Nil();
pool[] List l2 = new List.Cons(1, l1);
pool[] List l3;
l3 = new List.Cons(2, l2);
escape (l3 as List.Cons).head + ((l3 as List.Cons).tail as List.Cons).head + ((((l3 as List.Cons).tail as List.Cons).tail is List.Nil) as int);
]],
    wrn = true,
    --run = 4,
    --env = 'line 53 : invalid constructor : recursive field "Cons" must be new data',
    stmts = 'line 53 : invalid constructor : argument #2 : unexpected context for pool "l1"',
    -- TODO-ADT-Rec-STATIC-CONSTRS
}
Test { DATA..[[
pool[] List l3 = new List.Cons(2, List.Cons(1, List.Nil()));
escape (l3 as List.Cons).head + ((l3 as List.Cons).tail as List.Cons).head + ((((l3 as List.Cons).tail as List.Cons).tail is List.Nil) as int);
]],
    wrn = true,
    run = 4,
}
Test { DATA..[[
pool[] List l3 = new List.Cons(2, List.Cons(1, List.Nil()));
escape (l3 as List.Cons).head + ((l3 as List.Cons).tail as List.Cons).head + ((((l3 as List.Cons).tail as List.Cons).tail is List.Nil) as int);
]],
    wrn = true,
    run = 4,
}
-- breaking a list: 2-1-Nil => 2-Nil
Test { DATA..[[
pool[] List l1;
l1 = new List.Nil();
pool[] List l3 = new List.Cons(2, List.Cons(1, List.Nil()));
(l3 as List.Cons).tail = l1;
escape (l3 as List.Cons).head + (((l3 as List.Cons).tail is List.Nil) as int);
]],
    wrn = true,
    --adt = 'line 54 : invalid attribution : value is not a reference',
    --adt = 'line 54 : invalid attribution : new reference only to pointer or alias',
    --adt = 'line 54 : invalid attribution : mutation : cannot mix data sources',
    stmts = 'line 54 : invalid assignment : unexpected context for pool "l1"',
    run = 3,
}
Test { DATA..[[
pool[] List l1;
l1 = new List.Nil();
pool[] List l3 = new List.Cons(2, List.Cons(1, List.Nil()));
(l3 as List.Cons).tail = &&l1;
escape (l3 as List.Cons).head + (((l3 as List.Cons).tail is List.Nil) as int);
]],
    wrn = true,
    stmts = 'line 54 : invalid assignment : types mismatch : "List" <= "List&&"',
    --exps = 'line 54 : unexpected context for pool "l1"',
    --adt = 'line 54 : invalid attribution : destination is not a reference',
    --adt = 'line 54 : cannot mix recursive data sources',
    run = 3,
}

-- circular list: 1-1-1-...
Test { DATA..[[
pool[] List l1;
pool[] List l2;
l1 = new List.Nil();
l2 = new List.Cons(1, List.Nil());
l1 = l2;
escape ((l1 is List.Cons)as int) + (l1 as List.Cons).head==1;
]],
    wrn = true,
    --adt = 'line 55 : invalid attribution : value is not a reference',
    --adt = 'line 55 : invalid attribution : mutation : cannot mix data sources',
    stmts = 'line 55 : invalid assignment : unexpected context for pool "l2"',
    run = 2,
}
Test { DATA..[[
pool[] List l1;
pool[] List l2;
l1 = new List.Nil();
l2 = new List.Cons(1, List.Nil());
l1 = &&l2;
escape ((l1 is List.Cons)as int) + (l1 as List.Cons).head==1;
]],
    wrn = true,
    stmts = 'line 55 : invalid assignment : types mismatch : "List" <= "List&&"',
    --adt = 'line 55 : invalid attribution : destination is not a reference',
    --exps = 'line 55 : unexpected context for pool "l2"',
    --adt = 'line 55 : invalid attribution : new reference only to pointer or alias',
    --adt = 'line 55 : cannot mix recursive data sources',
    run = 2,
}
Test { DATA..[[
pool[] List l1 = new List.Nil(),
            l2 = new List.Cons(1, List.Nil());
l1 = l2;
escape ((l1 is List.Cons)as int) + (((l1 as List.Cons).head==1)as int) + (((((l1 as List.Cons).tail as List.Cons).tail as List.Cons).head==1)as int);
]],
    stmts = 'line 53 : invalid assignment : unexpected context for pool "l2"',
    wrn = true,
    --adt = 'line 53 : invalid attribution : value is not a reference',
    --adt = 'line 53 : invalid attribution : mutation : cannot mix data sources',
    --run = 3,
}

-- circular list: 1-2-1-2-...
Test { DATA..[[
pool[] List l1 = new List.Cons(1, List.Nil()),
            l2 = new List.Cons(2, List.Nil());
((l1 as List.Cons).tail) = l2;
escape ((((l1 as List.Cons).head)==1)as int) + (((((l1 as List.Cons).tail) as List.Cons).head==2)as int) +
       ((((l2 as List.Cons).head)==2)as int) + (((((l2 as List.Cons).tail) as List.Cons).head==1)as int) +
       (((((((l1 as List.Cons).tail) as List.Cons).tail as List.Cons).tail as List.Cons).head==2)as int);
]],
    wrn = true,
    --adt = 'line 53 : invalid attribution : value is not a reference',
    --adt = 'line 53 : invalid attribution : mutation : cannot mix data sources',
    stmts = 'line 53 : invalid assignment : unexpected context for pool "l2"',
    run = 5,
}

Test { DATA..[[
pool[] List l1 = new List.Cons(1, List.Nil()),
            l2 = new List.Cons(2, List.Nil());
((l1 as List.Cons).tail) = &&l2;
escape ((((l1 as List.Cons).head)==1) as int) + (((((l1 as List.Cons).tail) as List.Cons).head==2) as int) +
       ((((l2 as List.Cons).head)==2) as int) + (((((l2 as List.Cons).tail) as List.Cons).head==1) as int) +
       (((((((l1 as List.Cons).tail) as List.Cons).tail as List.Cons).tail as List.Cons).head==2) as int);
]],
    wrn = true,
    stmts = 'line 53 : invalid assignment : types mismatch : "List" <= "List&&"',
    --exps = 'line 53 : unexpected context for pool "l2"',
    --adt = 'line 53 : invalid attribution : destination is not a reference',
    --adt = 'line 53 : cannot mix recursive data sources',
    run = 5,
}

-- another circular list
Test { DATA..[[
pool[] List l1, l2;
l1 = new List.Cons(1, List.Nil());
l2 = new List.Cons(2, List.Nil());
((l1 as List.Cons).tail) = l2;
((l2 as List.Cons).tail) = l1;

escape ((l1 as List.Cons).head) + (((l1 as List.Cons).tail) as List.Cons).head + ((l2 as List.Cons).head) + (((l2 as List.Cons).tail) as List.Cons).head;
]],
    wrn = true,
    --adt = 'line 54 : invalid attribution : value is not a reference',
    --adt = 'line 54 : invalid attribution : new reference only to root',
    --adt = 'line 54 : invalid attribution : mutation : cannot mix data sources',
    stmts = 'line 54 : invalid assignment : unexpected context for pool "l2"',
    run = 6,
}

-- not circular
Test { DATA..[[
pool[] List l1, l2;
l1 = new List.Nil();
l2 = new List.Cons(1, List.Nil());
l1 = ((l2 as List.Cons).tail);
escape (l1 is List.Nil) as int;
]],
    wrn = true,
    --adt = 'line 54 : invalid attribution : value is not a reference',
    --adt = 'line 54 : invalid attribution : new reference only to pointer or alias',
    adt = 'line 54 : invalid attribution : mutation : cannot mix data sources',
    run = 1,
}

-- not circular
Test { DATA..[[
pool[] List l1, l2;
l1 = new List.Nil();
l2 = new List.Cons(1, List.Nil());
l1 = &&((l2 as List.Cons).tail);
escape l1 is List.Nil;
]],
    wrn = true,
    --adt = 'line 54 : invalid attribution : destination is not a reference',
    --adt = 'line 54 : invalid attribution : new reference only to pointer or alias',
    --adt = 'line 54 : cannot mix recursive data sources',
    --run = 1,
    stmts = 'line 54 : invalid assignment : types mismatch : "List" <= "List&&"',
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
pool[] List l;     // all instances reside here
escape 1;
]],
    wrn = true,
    run = 1,
}

-- the pool variable is overloaded:
--  - represents the pool
--  - represents the root of the tree
Test { DATA..[[
pool[] List l;     // l is the pool
escape (l is List.Nil) as int;       // l is a pointer to the root
]],
    wrn = true,
    run = 1,
}
Test { DATA..[[
pool[] List l;     // l is the pool
escape ((l) is List.Nil) as int;    // equivalent to above
]],
    wrn = true,
    run = 1,
}
-- the pointer must be dereferenced
Test { DATA..[[
pool[] List l;     // l is the pool
escape (*l is List.Nil) as int;       // "l" is not a struct
]],
    wrn = true,
    --exps = 'line 52 : invalid operand to `*´ : unexpected context for pool "l"',
    names = 'line 52 : invalid operand to `*´ : expected pointer type',
    --env = 'line 52 : invalid access (List[] vs List)',
}
Test { DATA..[[
pool[] List l;     // l is the pool
escape ((l as List.Cons):head); // "l" is not a struct
]],
    wrn = true,
    --env = 'line 52 : invalid operand to unary "*"',
    names = 'line 52 : invalid operand to `*´ : expected pointer type : got "List.Cons"',
    --env = 'line 52 : invalid access (List[] vs List)',
}
Test { DATA..[[
pool[] List l;             // l is the pool
escape *((l as List.Cons).tail) is List.Cons;    // "((l as List.Cons).tail)" is not a struct
]],
    wrn = true,
    --env = 'line 52 : invalid operand to unary "*"',
    names = 'line 52 : invalid operand to `*´ : expected pointer type',
    --env = 'line 52 : not a struct',
}

-- the pool is initialized to the base case of the ADT
-- (this is why the base case cannot have fields and
--  must appear first in the ADT declaration)
Test { DATA..[[
pool[] List l;
escape (l is List.Cons) as int;      // runtime error
]],
    wrn = true,
    asr = true,
}

-- dynamic ADTs have automatic memory management
--  - similar to organisms
Test { DATA..[[
var int ret = 0;
do
    pool[] List lll;
    ret = (lll is List.Nil) as int;
end
// all instances in "lll" have been collected
escape ret;
]],
    wrn = true,
    run = 1,
}

-- TODO: escape analysis for instances going to outer scopes
-- TODO: mixing static/static, dynamic/dynamic, static/dynamic

-- Dynamic constructors:
--  - must use "new"
--  - the pool is inferred from the l-value
Test { DATA..[[
pool[] List l;
l = new List.Nil();
escape (l is List.Nil) as int;
]],
    wrn = true,
    run = 1,
}
Test { DATA..[[
pool[] List l = new List.Cons(2, List.Nil());
escape ((l as List.Cons).head);
]],
    wrn = true,
    run = 2,
}
Test { DATA..[[
pool[] List l = new List.Cons(1, List.Cons(2, List.Nil()));
escape ((l as List.Cons).head) + (((l as List.Cons).tail) as List.Cons).head + (((((l as List.Cons).tail) as List.Cons).tail is List.Nil) as int);
]],
    wrn = true,
    run = 4,
}
-- wrong tag
Test { DATA..[[
pool[] List l;
l = new List.Nil();
escape (l is List.Cons) as int;
]],
    wrn = true,
    asr = true,
}
-- no "new"
Test { DATA..[[
pool[] List l;
l = val List.Cons(2, List.Nil());
escape ((l as List.Cons).head);
]],
    wrn = true,
    --adt = 'line 52 : invalid constructor : recursive data must use `new´',
    stmts = 'line 52 : invalid constructor : unexpected context for pool "l"',
    --env = 'line 52 : invalid call parameter #2 (List vs List&&)',
}
-- cannot assign "l" directly (in the pool declaration)
Test { DATA..[[
pool[] List l = new List.Cons(2, List.Nil());
escape ((l as List.Cons).head);
]],
    wrn = true,
    run = 2,
}
-- no dereference
Test { DATA..[[
pool[] List l;
l = new List.Nil();
escape (l is List.Nil) as int;
]],
    wrn = true,
    --env = 'line 53 : invalid access (List[] vs List)',
    run = 1,
}
Test { DATA..[[
pool[] List l;
l = new List.Cons(2, List.Nil());
escape ((l as List.Cons).head);
]],
    wrn = true,
    --env = 'line 53 : invalid access (List[] vs List)',
    run = 2,
}

-- static vs heap pools
--      pool[] List l;      // instances go to the heap
-- vs
--      pool[10] List l;    // 10 instances at most
-- (same as for organisms)

-- allocation fails (0 space)
-- fallback to base case (which is statically allocated in the initialization)
-- (this is also why the base case cannot have fields and
--  must appear first in the ADT declaration)
-- (
Test { DATA..[[
pool[0] List l = new List.Cons(2, List.Nil());
escape (l is List.Nil) as int;
]],
    wrn = true,
    run = 1,
}
Test { DATA..[[
pool[0] List l;
l = new List.Cons(2, List.Nil());
escape ((l as List.Cons).head);     // runtime error
]],
    wrn = true,
    asr = true,
}
-- 2nd allocation fails (1 space)
Test { DATA..[[
pool[1] List l = new List.Cons(2, List.Cons(1, List.Nil()));
native _assert;
_assert(((l as List.Cons).tail) is List.Nil);
escape ((l as List.Cons).head);
]],
    wrn = true,
    run = 2,
}
-- 3rd allocation fails (2 space)
Test { DATA..[[
pool[2] List l = new List.Cons(1, List.Cons(2, List.Cons(3, List.Nil())));
native _assert;
_assert((((l as List.Cons).tail) as List.Cons).tail is List.Nil);
escape ((l as List.Cons).head) + (((l as List.Cons).tail) as List.Cons).head + ((((((l as List.Cons).tail) as List.Cons).tail) is List.Nil) as int);
]],
    wrn = true,
    run = 4,
}

-- dereference test for static pools
-- (nothing new here)
Test { DATA..[[
pool[0] List l;
l = new List.Cons(2, List.Nil());
escape (l is List.Nil) as int;
]],
    wrn = true,
    --env = 'line 53 : invalid access (List[] vs List)',
    run = 1,
}

Test { [[
data Tx;
data Tx.Nil;
data Tx.Nxt with
    var int v;
    var Tx&&  nxt;
end
pool[] Tx ts;
do
    ts = new Tx.Nil();
end
escape (ts is Tx.Nil) as int;
]],
    wrn = true,
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

-- 1-Nil => 2-Nil
-- 1-Nil can be safely reclaimed
Test { DATA..[[
pool[1] List l = new List.Cons(1, List.Nil());
l = new List.Cons(2, List.Nil());    // this fails (new before free)!
escape ((l as List.Cons).head);
]],
    wrn = true,
    asr = true,
}

Test { DATA..[[
pool[1] List l;
l = new List.Cons(1, List.Nil());
((l as List.Cons).tail) = new List.Cons(2, List.Nil()); // fails
escape (((l as List.Cons).tail) is List.Nil) as int;
]],
    wrn = true,
    run = 1,
    --asr = true,
}

-- 1-2-Nil
Test { DATA..[[
pool[2] List l = new List.Cons(1, List.Nil());
((l as List.Cons).tail) = new List.Cons(2, List.Nil()); // fails
escape (((l as List.Cons).tail) as List.Cons).head;
]],
    wrn = true,
    run = 2,
}

-- 1-Nil => 2-Nil
-- 1-Nil can be safely reclaimed
Test { DATA..[[
pool[2] List l;
l = new List.Cons(1, List.Nil());
l = new List.Cons(2, List.Nil());    // no allocation fail
escape ((l as List.Cons).head);
]],
    wrn = true,
    run = 2,
}

-- 1-2-3-Nil => 1-2-Nil (3 fails)
-- 4-5-6-Nil => Nil     (all fail)
Test { DATA..[[
native _ceu_callback_assert_msg;
pool[2] List l = new List.Cons(1, List.Cons(2, List.Cons(3, List.Nil())));   // 3 fails
_ceu_callback_assert_msg((((l as List.Cons).tail) as List.Cons).tail is List.Nil, "1");
l = new List.Nil();
l = new List.Cons(4, List.Cons(5, List.Cons(6, List.Nil())));   // 6 fails
_ceu_callback_assert_msg((((l as List.Cons).tail) as List.Cons).tail is List.Nil, "2");
escape (((l as List.Cons).tail) as List.Cons).head;
]],
    wrn = true,
    run = 5,
}

Test { DATA..[[
pool[2] List l = new List.Cons(1, List.Cons(2, List.Cons(3, List.Nil())));   // 3 fails
native _ceu_callback_assert_msg;
_ceu_callback_assert_msg((((l as List.Cons).tail) as List.Cons).tail is List.Nil, "1");
l = new List.Cons(4, List.Cons(5, List.Cons(6, List.Nil())));   // all fail
escape (l is List.Nil) as int;
]],
    wrn = true,
    run = 1,
}

-- 1-2-3-Nil => 1-2-Nil (3 fails)
-- (clear all)
-- 4-5-6-Nil => 4-5-Nil (6 fails)
Test { DATA..[[
pool[2] List l;
l = new List.Cons(1, List.Cons(2, List.Cons(3, List.Nil())));   // 3 fails
native _assert;
_assert((((l as List.Cons).tail) as List.Cons).tail is List.Nil);
l = new List.Nil();                                                // clear all
l = new List.Cons(4, List.Cons(5, List.Cons(6, List.Nil())));   // 6 fails
_assert((((l as List.Cons).tail) as List.Cons).tail is List.Nil);
escape ((l as List.Cons).head) + (((l as List.Cons).tail) as List.Cons).head + ((((((l as List.Cons).tail) as List.Cons).tail is List.Nil)) as int);
]],
    wrn = true,
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
-- Nil
-- 1-Nil
-- 1-2-Nil
Test { DATA..[[
pool[2] List l = new List.Cons(1, List.Nil());
((l as List.Cons).tail) = new List.Cons(2, List.Nil());
escape ((l as List.Cons).head) + (((l as List.Cons).tail) as List.Cons).head;
]],
    wrn = true,
    run = 3,
}
-- ok: tail is child of l
-- Nil
-- 1-2-Nil
-- 1-Nil
Test { DATA..[[
pool[2] List lll;
lll = new List.Cons(1, List.Cons(2, List.Nil()));
lll = (lll as List.Cons).tail;    // parent=child
escape (lll as List.Cons).head;
]],
    wrn = true,
    run = 2,
}
Test { DATA..[[
pool[2] List lll = new List.Cons(1, List.Cons(2, List.Nil()));
lll = (lll as List.Cons).tail;
(lll as List.Cons).tail = new List.Cons(3, List.Nil());
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { DATA..[[
pool[2] List lll;
lll = new List.Cons(1, List.Cons(2, List.Nil()));
lll = (lll as List.Cons).tail;    // parent=child
(lll as List.Cons).tail = new List.Cons(3, List.Cons(4, List.Nil()));    // 4 fails
escape (lll as List.Cons).head + (((lll as List.Cons).tail) as List.Cons).head + (((((lll as List.Cons).tail) as List.Cons).tail is List.Nil) as int);
]],
    wrn = true,
    run = 6,
}
Test { DATA..[[
pool[2] List l = new List.Cons(1, List.Cons(2, List.Nil()));
l = ((l as List.Cons).tail);    // parent=child
((l as List.Cons).tail) = new List.Cons(3, List.Cons(4, List.Nil()));    // 4 fails
escape ((l as List.Cons).head) + (((l as List.Cons).tail) as List.Cons).head + (((((l as List.Cons).tail) as List.Cons).tail is List.Nil) as int);
]],
    wrn = true,
    run = 6,
}

-- no: l is parent of tail
-- Nil
-- 1-2-Nil
-- 1-2-^1   (no)
Test { DATA..[[
pool[2] List l;
l = new List.Cons(1, List.Cons(2, List.Nil()));
((l as List.Cons).tail) = l;    // child=parent
escape 1;
]],
    wrn = true,
    --adt = 'line 53 : cannot assign parent to child',
    stmts = 'line 53 : invalid assignment : unexpected context for pool "l"',
}

Test { [[
data OptionInt;
data OptionInt.Nil1;
data OptionInt.Some1 with
    var int v;
end

data OptionPtr;
data OptionPtr.Nil2;
data OptionPtr.Some2 with
    var int&& v;
end

var int ret = 0;            // 0

var OptionInt i = val OptionInt.Nil1();
var OptionPtr p = val OptionPtr.Nil2();
ret = ret + ((i is OptionInt.Nil1)as int) + ((p is OptionPtr.Nil2)as int);  // 2

i = val OptionInt.Some1(3);
ret = ret + (i as OptionInt.Some1).v;       // 5

p = val OptionPtr.Some2(&&ret);
*(p as OptionPtr.Some2).v = *(p as OptionPtr.Some2).v + 2;    // 7

var int v = 10;
p = val OptionPtr.Some2(&&v);
*(p as OptionPtr.Some2).v = *(p as OptionPtr.Some2).v + 1;

ret = ret + v;              // 18
escape ret;
]],
    run = 18,
}

-->> OPTION / DATA

Test { [[
data OptionInt;
data OptionInt.Nil1;
data OptionInt.Some1 with
    var int v;
end

data OptionPtr;
data OptionPtr.Nil2;
data OptionPtr.Some2 with
    var int&& v;
end

var int ret = 0;    // 0

var int?  i;
var& int? p;
ret = ret + ((not i?)as int) + 1;  // 2

i = 3;
ret = ret + i!;      // 5

// first
p = &ret;
p! = p! + 2;          // 7
native _assert;
_assert(ret == 7);

// second
var int v = 10;
p! = v;              // 10
p! = p! + 1;          // 11

ret = ret + v;      // 21
escape ret;
]],
    wrn = true,
    run = 21,
}

Test { [[
class Tx with
    var& int? i;
do
    var int v = 10;
    this.i! = v;
end
var Tx t;
escape t.i!;
]],
    asr = ':5] runtime error: invalid tag',
    --run = 10,
}
Test { [[
class Tx with
    var& int? i;
do
    var int v = 10;
    this.i! = v;
end
var int i = 0;
var Tx t with
    this.i = &i;
end;
escape t.i!;
]],
    --code = 'line 5 : invalid operand in assignment',
    --asr = ':5] runtime error: invalid tag',
    run = 10,
}
Test { [[
var int v = 10;
class Tx with
    var& int? i;
do
    var int v = 10;
    if v!=0 then end;
end
var Tx t with
    this.i = &v;
end;
v = v / 2;
escape t.i? + t.i! + 1;
]],
    run = 7,
}
Test { [[
class Tx with
    var& int? i;
do
    var int v = 10;
    if v!=0 then end;
end
var Tx t;
escape t.i? + 1;
]],
    run = 1,
}
Test { [[
class Tx with
    var& int? i;
do
    var int v = 10;
    if v!=0 then end;
end
var Tx t;
escape t.i!;
]],
    asr = true,
}
Test { [[
class Tx with
    var& int? i;
do
    var int v = 10;
    if v!=0 then end;
end
var int v = 1;
var Tx t with
    this.i = &v;
end;
v = 11;
escape t.i!;
]],
    run = 11,
}

Test { [[
class Tx with
    var& int? v;
do
    if v? then end;
end
var Tx t;
escape 1;
]],
    run = 1,
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
    this.bg_clr = val SDL_Color(10);
end;
escape ui.bg_clr!.v;
]],
    run = 10,
}

Test { [[
native/pos do
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
    this.bg_clr = val SDL_Color(10);
end;
native _fff;
escape _fff(ui.bg_clr!).v;
]],
    run = 10,
}

Test { [[
native/pos do
    int V = 10;
    int* getV (void) {
        escape &V;
    }
end

var& int? v;
    do v = &_getV();
finalize with
    nothing;
end

class Tx with
    var& int? v;
do
    v! = 20;
end
do Tx with
    this.v = &v;
end;

escape v!;
]],
    tmp = 'line 21 : invalid operand to unary "&" : cannot be aliased',
}

Test { [[
native/pos do
    int V = 10;
    int* getV (void) {
        escape &V;
    }
end

var& int? v;
    do v = &_getV();
finalize with
    nothing;
end

class Tx with
    var& int? v;
do
    v! = 20;
end
do Tx with
    this.v = &v!;
end;

escape v!;
]],
    run = 20,
}

--<< OPTION / DATA

-- cannot compare ADTs
Test { DATA..[[
var Pair p1 = val Pair(1,2);
var Pair p2 = val Pair(1,2);
escape (p1==p2) as int;
]],
    wrn = true,
    --env = 'line 53 : invalid operation for data',
    exps = 'line 53 : invalid operands to `==´ : unexpected `data´ value',
    --run = 1,
}
Test { DATA..[[
pool[] List l1, l2;
l2 = new List.Nil();
escape l1==l2;
]],
    wrn = true,
    exps = 'line 53 : invalid operand to `==´ : unexpected context for pool "l1"',
    --env = 'line 53 : invalid operands to binary "=="',
    --run = 1,
}

-- cannot mix recursive ADTs
Test { DATA..[[
pool[] List l1, l2;
l1 = new List.Cons(1, List.Nil());
l2 = new List.Cons(2, List.Nil());
((l1 as List.Cons).tail) = l2;
escape (((l1 as List.Cons).tail) as List.Cons).head;
]],
    wrn = true,
    --adt = 'line 54 : invalid attribution : mutation : cannot mix data sources',
    stmts = 'line 54 : invalid assignment : unexpected context for pool "l2"',
}
Test { DATA..[[
pool[] List l1 = new List.Cons(1, List.Nil());
do
    pool[] List l2;
    l2 = new List.Cons(2, List.Nil());
    ((l1 as List.Cons).tail) = &&l2;
end
escape (((l1 as List.Cons).tail) as List.Cons).head;
]],
    wrn = true,
    stmts = 'line 55 : invalid assignment : types mismatch : "List" <= "List&&"',
    --adt = 'line 55 : invalid attribution : destination is not a reference',
    --adt = 'line 55 : cannot mix recursive data sources',
    --fin = 'line 54 : attribution to pointer with greater scope',
}
Test { DATA..[[
pool[] List l1;
l1 = new List.Cons(1, List.Nil());
pool[2] List l2 = new List.Cons(2, List.Nil());
((l1 as List.Cons).tail) = l2;
escape (((l1 as List.Cons).tail) as List.Cons).head;
]],
    wrn = true,
    --adt = 'line 54 : invalid attribution : mutation : cannot mix data sources',
    stmts = 'line 54 : invalid assignment : unexpected context for pool "l2"',
}
Test { DATA..[[
pool[2] List l1;
pool[2] List l2;
l1 = new List.Cons(1, List.Nil());
l2 = new List.Cons(2, List.Nil());
((l1 as List.Cons).tail) = l2;
escape (((l1 as List.Cons).tail) as List.Cons).head;
]],
    wrn = true,
    --adt = 'line 55 : invalid attribution : mutation : cannot mix data sources',
    stmts = 'line 55 : invalid assignment : unexpected context for pool "l2"',
}

Test { DATA..[[
var int ret = 0;                // 0

pool[5] List l;

// change head [2]
l = new List.Cons(1, List.Nil());
ret = ret + ((l as List.Cons).head);        // 2
native _assert;
_assert(ret == 1);

// add 2 [1, 2]
((l as List.Cons).tail) = new List.Cons(1, List.Nil());
ret = ret + ((l as List.Cons).head);        // 3
ret = ret + ((l as List.Cons).head) + (((l as List.Cons).tail) as List.Cons).head;
                                // 6
_assert(ret == 6);

// change tail [1, 2, 4]
(((l as List.Cons).tail) as List.Cons).tail = new List.Cons(4, List.Nil());
                                // 10

pool[] List l3 = new List.Cons(3, List.Nil());
(((l as List.Cons).tail) as List.Cons).tail = &&l3;
_assert((((l as List.Cons).tail) as List.Cons).head == 3);
_assert(((((l as List.Cons).tail) as List.Cons).tail as List.Cons).head == 4);
ret = ret + (((l as List.Cons).tail) as List.Cons).head + ((((l as List.Cons).tail) as List.Cons).tail as List.Cons).head;
                                // 17

// drop middle [1, 3, 4]
((l as List.Cons).tail) = (((l as List.Cons).tail) as List.Cons).tail;
ret = ret + (((l as List.Cons).tail) as List.Cons).head;
                                // 20

// fill the list [1, 3, 4, 5, 6] (7 fails)
((((l as List.Cons).tail) as List.Cons).tail as List.Cons).tail =
    new List.Cons(5, List.Cons(6, List.Cons(7, List.Nil())));

escape ret;
]],
    wrn = true,
    stmts = 'line 73 : invalid assignment : types mismatch : "List" <= "List&&"',
    --adt = 'line 72 : invalid attribution : destination is not a reference',
    --adt = 'line 72 : invalid attribution : new reference only to root',
    --adt = 'line 72 : cannot mix recursive data sources',
    run = -1,
}

Test { [[
interface IGUI_Component with
    var& _void? nat;
end

class EnterLeave with
    var& IGUI_Component gui;
do
    var _void&& g = &&(gui.nat!);
    if g!=0 then end;
end
escape 1;
]],
    run = 1,
}

Test { [[
class Tx with
    var int? x;
do
end

class U with
    var& Tx t;
do
end

var Tx t with
    this.x = 10;
end;

var U u with
    this.t = &t;
end;

escape u.t.x!;
]],
    run = 10,
}

Test { [[
class Tx with
    var int? x;
do
end

class U with
    var& Tx t;
    var int ret=0;
do
    this.ret = t.x!;
end

var Tx t with
    this.x = 10;
end;

var U u with
    this.t = &t;
end;

escape u.t.x! + u.ret;
]],
    run = 20,
}

Test { [[
class Tx with
    var& int? x;
do
end

class U with
    var& Tx t;
    var int ret=0;
do
    this.ret = t.x!;
end

var int z = 10;

var Tx t with
    this.x = &z;
end;

var U u with
    this.t = &t;
end;

escape u.t.x! + u.ret;
]],
    run = 20,
}

Test { [[
interface I with
    var int? x;
end

class Tx with
    interface I;
do
end

class U with
    var& Tx t;
do
end

var Tx t with
    this.x = 10;
end;

var U u with
    this.t = &t;
end;

escape u.t.x!;
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
var I&& i = &&u;

escape i:v!;
]],
    run = 10,
}

Test { [[
class Tx with
    var int? x;
do
end

interface I with
    var& Tx t;
end

class U with
    interface I;
do
end

var Tx t with
    this.x = 10;
end;

var U u with
    this.t = &t;
end;
var I&& i = &&u;

escape ((*i).t).x!;
]],
    run = 10,
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;
var List&& lll = &&list;

escape 1;
]],
    wrn = true,
    run = 1,
    --env = 'line 15 : invalid operand to unary "&&"',
    --env = 'line 15 : data must be a pointer',
}
Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;
var List&& lll = list;

escape 1;
]],
    wrn = true,
    --adt = 'line 11 : invalid attribution : mutation : cannot mix data sources',
    stmts = 'line 9 : invalid assignment : unexpected context for pool "list"',
    --run = 1,
    --env = 'line 15 : invalid operand to unary "&&"',
    --env = 'line 15 : data must be a pointer',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list

= new List.Cons(10, List.Nil());
var List&& l = list;

watching l do
    await 1s;
end

escape 0;
]],
    stmts = 'line 11 : invalid assignment : unexpected context for pool "list"',
    --env = 'line 15 : not a struct',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Nil());

pool&[] List lll = &list;

escape (lll as List.Cons).head;
]],
    run = 10,
}
Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Nil());

pool[] List&& lll = &&list;

escape (lll as List.Cons).head;
]],
    run = 10,
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Nil());
pool[] List&& l = &&list;

((l as List.Cons).tail) = new List.Cons(9, List.Nil());
l = ((l as List.Cons).tail);

((l as List.Cons).tail) = new List.Cons(8, List.Nil());
l = ((l as List.Cons).tail);

escape ((*l is List.Cons) as int) +
        (list as List.Cons).head +
        ((list as List.Cons).tail as List.Cons).head +
        ((((list as List.Cons).tail as List.Cons).tail) as List.Cons).head;
]],
    stmts = 'line 14 : invalid assignment : types mismatch : "List&&" <= "List"',
    --adt = 'line 16 : invalid attribution : mutation : destination cannot be a pointer',
}

-- mutation in the root of &&
--  also, the other way around is unsafe
--   which is a problem
Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Nil());

pool[] List&& l1 = &&list;
pool&[] List  l2 = &list;

list = new List.Nil();

escape ((*l1 is List.Cons) as int)+((l2 is List.Cons) as int)+((list is List.Cons) as int)+1;
]],
    --run = 1,
    fin = 'line 19 : unsafe access to pointer "l1" across `assignment´ (/tmp/tmp.ceu : 17)',
}

-- mutation in the root of &&
--  also, the other way around is unsafe
--   which is a problem
Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Nil());
pool[] List&& lll = &&list;

var int ret = 0;

watching *lll do
    *lll = (lll as List.Cons).tail;
    //ret = (*lll as List.Cons) +
            //(list as List.Cons).head +
            //(list as List.Cons).tail is List.Nil;
end

escape ret;
]],
    adt = 'line 18 : invalid attribution : mutation : cannot mutate root of a reference',
    --run = '17] runtime error: invalid tag',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Cons(20, List.Nil()));
pool[] List&& lll = &&list;

var int ret = 0;
watching *lll do
    (lll as List.Cons).tail = (((lll as List.Cons).tail) as List.Cons).tail;
    ret = ((*lll is List.Cons) as int) +
            (list as List.Cons).head +
            (((list as List.Cons).tail is List.Nil) as int);
end
escape ret;
]],
    _ana = {acc=true},
    run = 12,
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Nil());
pool[] List&& lll = &&list; // TODO fat pointer

*lll = (lll as List.Cons).tail;

escape ((*lll is List.Cons) as int) + ((list is List.Cons) as int) + 1;
]],
    adt = 'line 15 : invalid attribution : mutation : cannot mutate from pointers',
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Nil());
pool[] List&& lll = &&list;

*lll = (lll as List.Cons).tail;

escape 0;
//escape (*lll as List.Cons) +
        //(list as List.Cons).head +
        //(list as List.Cons).tail is List.Nil;
]],
    --run = 10,
    adt = 'line 15 : invalid attribution : mutation : cannot mutate root of a reference',
}
Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Nil());
pool[] List&& lll = &&list;

(lll as List.Cons).tail = new List.Cons(9, List.Nil());
*lll = (lll as List.Cons).tail;

(lll as List.Cons).tail = new List.Cons(8, List.Nil());
*lll = (lll as List.Cons).tail;

escape ((*lll is List.Cons) as int) +
        (list as List.Cons).head +
        (((list as List.Cons).tail is List.Nil) as int);
]],
    adt = 'line 16 : invalid attribution : mutation : cannot mutate root of a reference',
}
Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Nil());
pool[] List&& l = &&list;

var int ret = 0;

watching *l do
    ((l as List.Cons).tail) = new List.Cons(9, List.Nil());
    l = &&((l as List.Cons).tail);

    ((l as List.Cons).tail) = new List.Cons(8, List.Nil());
    l = &&((l as List.Cons).tail);

    ret = ((*l is List.Cons) as int) +
            (list as List.Cons).head +
            ((list as List.Cons).tail as List.Cons).head +
            ((((list as List.Cons).tail as List.Cons).tail) as List.Cons).head;
end
escape ret;
]],
    _ana = {acc=true},
    run = 28,
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list;

list = new List.Cons(10, List.Nil());
pool[] List&& l = &&list;

watching *l do
    ((l as List.Cons).tail) = new List.Cons(9, List.Nil());
    l = &&((l as List.Cons).tail);

    await 1s;

    ((l as List.Cons).tail) = new List.Cons(8, List.Nil());
    l = &&((l as List.Cons).tail);

    escape ((l as List.Cons).head) +
            (list as List.Cons).head +
            ((list as List.Cons).tail as List.Cons).head +
            ((((list as List.Cons).tail as List.Cons).tail) as List.Cons).head;
end

escape 0;
]],
    _ana = {acc=true},
    run = { ['~>1s'] = 35 },
}

-- fails if inner is killed before outer
Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[10] List list;

list = new List.Cons(10, List.Nil());
pool[] List&& lll = &&list;

watching *lll do
    (lll as List.Cons).tail = new List.Cons(9, List.Nil());
    lll = &&(lll as List.Cons).tail;

    par do
        watching *lll do
            await 1s;

            (lll as List.Cons).tail = new List.Cons(8, List.Nil());
            lll = &&(lll as List.Cons).tail;

            escape (lll as List.Cons).head +
                    (list as List.Cons).head +
                    ((list as List.Cons).tail as List.Cons).head +
                    (((list as List.Cons).tail as List.Cons).tail as List.Cons).head;
        end
        escape 1;
    with
        list = new List.Nil();
        await FOREVER;
    end
end
escape -1;
]],
    _ana = {acc=true},
    run = -1,
}

Test { [[
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
end

pool[] List list = new List.Cons(10, List.Nil());
pool[] List&& lll = &&list;

watching *lll do
    (lll as List.Cons).tail = new List.Cons(9, List.Nil());
    lll = &&(lll as List.Cons).tail;

    par do
        await 1s;

        (lll as List.Cons).tail = new List.Cons(8, List.Nil());
        lll = &&(lll as List.Cons).tail;

        escape (lll as List.Cons).head +
                (list as List.Cons).head +
                ((list as List.Cons).tail as List.Cons).head +
                (((list as List.Cons).tail as List.Cons).tail as List.Cons).head;
    with
        list = new List.Nil();
        await FOREVER;
    end
end
escape -1;
]],
    _ana = {acc=true},
    run = -1,
}

-->>> DATA + VECTORS + REFERENCES
Test { [[
data Test with
    var u8 v;
end
var Test a = val Test(1);
var Test b = val Test(2);
var Test c = val Test(3);
vector[3] Test vs = [ a, b, c ];
escape (vs[0].v + vs[1].v + vs[2].v) as int;
]],
    run = 6,
}

Test { [[
data Test with
    var& u8 v;
end

var u8 v = 7;
var Test t=val Test(&v);
v = 10;
escape t.v as int;
]],
    run = 10,
}

Test { [[
data Test with
    var& u8 v;
end
var u8 v = 7;
var Test t = val Test(&v);
v = 10;
escape t.v as int;
]],
    run = 10,
}

Test { [[
data Test with
    var& u8 v;
end

var u8 v = 7;
vector[3] Test vs;
var Test t = val Test(&v);
vs = [] .. vs .. [t];

v = 10;
t.v = 88;
vs[0].v = 36;
escape v as int;
]],
    run = 36,
}

Test { [[
  vector[3] u8 bytes;

bytes = [] .. bytes .. [5];

escape bytes[0] as int;
]],
    run = 5,
}
Test { [[
data Frame with
  vector[3] u8 bytes;
end

var Frame f1 = val Frame(_);
f1.bytes = [] .. f1.bytes .. [5];

escape f1.bytes[0] as int;
]],
    --env = 'line 2 : `data´ fields do not support vectors yet',
    run = 5,
}
Test { [[
data Frame;
    data Frame.Xx;
    data Frame.Yy with
        vector[3] u8 bytes;
    end

escape 1;
]],
    wrn = true,
    --env = 'line 5 : `data´ fields do not support vectors yet',
    run = 1,
}
Test { [[
native _u8;
data Frame with
  vector[3] _u8 bytes;
end

vector[10] Frame frames;
var Frame f1 = val Frame(_);

f1.bytes[0] = 5;

frames = [] .. frames .. [f1];

escape frames[0].bytes[0];
]],
    run = 5,
    --ref = 'line 8 : invalid access to uninitialized variable "f1" (declared at /tmp/tmp.ceu:6)'
}

Test { [[
data Tx with
    var& int i;
end
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
data Tx with
    vector&[] byte str;
end
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
var Dx d = val Dx(&&s as _char&& as _char_ptr);
]],
    parser = 'line 1 : after `&&´ : expected type modifier or `,´ or `)´',
    --parser = 'line 1 : after `s´ : expected `[´ or `:´ or `.´ or `!´ or `(´ or `?´ or binary operator or `,´ or `)´',
}
Test { [[
native/pre do
    typedef byte* char_ptr;
end
native/nohold _strlen;
native/plain _char_ptr;
data Dx with
    var _char_ptr str;
end
vector[] byte s = [].. "oi";
native _char;
var Dx d = val Dx(((&&s[0]) as _char&&) as _char_ptr);
escape _strlen(d.str as _char&&);
]],
    run = 2,
}
Test { [[
data Dx with
    vector&[] byte str;
end
vector[] byte s = [].. "oi";
var Dx d = val Dx(&s);
escape $d.str as int;
]],
    run = 2,
}

Test { [[
data Test with
    var& u8 b;
end

var u8 b = 7;
vector[3] Test v;
var Test t = val Test(&b);
v = [] .. v .. [t];

// reassignments
b = 10;
t.b = 88;
v[0].b = 36; // invalid attribution : missing alias operator `&´

escape b as int;
]],
    run = 36,
}

Test { [[
data SDL_Rect with
    var int x;
end
vector[] SDL_Rect cell_rects;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data SDL_Rect with
    var int x;
end
var SDL_Rect r1 = val SDL_Rect(10);
vector[] SDL_Rect cell_rects = [r1];
escape cell_rects[0].x;
]],
    run = 10,
}

Test { [[
data SDL_Rect with
    var int x;
end
vector[1] SDL_Rect rcs;
var SDL_Rect ri;
ri = val SDL_Rect(10);
rcs[0] = ri;
escape rcs[0].x;
]],
    run = '7] runtime error: access out of bounds',
}

Test { [[
data SDL_Rect with
    var int x;
end
var SDL_Rect ri;
ri = val SDL_Rect(10);
vector[1] SDL_Rect rcs = [ri];
escape rcs[0].x;
]],
    run = 10,
}

Test { [[
native/pure _f;
native/pos do
    int f (int* rect) {
        escape *rect;
    }
end

data SDL_Rect with
    var int x;
end
var SDL_Rect ri;
ri = val SDL_Rect(10);
vector[1] SDL_Rect rcs = [ri];
escape _f((&&rcs[0]) as int&&);
]],
    run = 10,
}

--<<< DATA + VECTORS

-- DATA / RECURSE / TRAVERSE

-- crashes with org->ret
Test { [[
class Tx with
do
    await FOREVER;
end

event Tx&& e;

input void OS_START;

par do
    do
        par/or do
            await OS_START;
            pool[1] Tx ts;
            var Tx&&? ptr = spawn Tx in ts;
            emit e(ptr!);
        with
            var Tx&& t = await e;
        end
    end
    do
native _int;
        vector[100] _int iss = [];
        loop i in [0 -> 100[ do
            iss[i] = i;
        end
    end
    await 1s;
    escape 1;
with
    var Tx&& t = await e;
    var int ret = await *t;     // crash!
    escape ret;
end
]],
    dcls = 'line 6 : invalid event type',
    --env = 'line 16 : wrong argument : cannot pass pointers',
    --run = { ['~>1s']=1 },
}

Test { [[
data Widget;
    data Widget.Nil;
    data Widget.Row with
        var Widget w1;
    end

pool[] Widget widgets;
traverse widget in &&widgets do
    watching *widget do
        var int v1 = traverse &&(*widget as Row).w1;
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
data Tx;
    data Tx.Nil;
    data Tx.Nxt with
        var int v;
        var Tx   nxt;
    end

pool[] Tx ts = new Tx.Nxt(10, Tx.Nxt(9, Tx.Nil()));

par/or do
    await ts;           // 2. but continuation is aborted
with
    ts = new Tx.Nil();   // 1. free is on continuation
end

escape 1;
]],
    _ana = { acc=true },
    run = 1,
}

Test { [[
data Tx;
    data Tx.Nil;
    data Tx.Nxt with
        var int v;
        var Tx   nxt;
    end

pool[] Tx ts;

ts = new Tx.Nxt(10, Tx.Nxt(9, Tx.Nil()));

var int ret = 10;

par/or do
    watching ts do
        await FOREVER;
    end
    ret = ret * 2;
with
    watching (ts as Tx.Nxt).nxt do
        await FOREVER;
    end
    ret = 0;
with
    watching ((ts as Tx.Nxt).nxt as Tx.Nxt).nxt do
        await FOREVER;
    end
    ret = ret - 1;  // awakes first from Nil
    await FOREVER;
with
    ts = new Tx.Nil();
    ret = 0;
end

escape ret;
]],
    _ana = { acc=true },
    run = 18,
}

Test { [[
class Body with
    pool&[]  Body bodies;
    var&   int    sum;
    event int     ok;
do
    do finalize with end;

    var Body&&? nested =
        spawn Body in bodies with
            this.bodies = &bodies;
            this.sum    = &sum;
        end;
    if nested? then
        watching *nested! do
            await nested!:ok;
        end
    end
    await 1s;
    sum = sum + 1;
    emit this.ok(1);
end


pool[100] Body bodies;
var  int     sum = 0;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;
await b;

escape sum;
]],
    wrn = 'line 9 : unbounded recursive spawn',
    run = { ['~>200s'] = 101 },
}
Test { [[
class Body with
    pool&[]  Body bodies;
    var&   int    sum;
    event int     ok;
do
    do finalize with end;

    var Body&&? nested =
        spawn Body in bodies with
            this.bodies = &bodies;
            this.sum    = &sum;
        end;
    if nested? then
        watching *nested! do
            await nested!:ok;
        end
    end
    await 1s;
    sum = sum + 1;
    emit this.ok(1);
end


pool[] Body bodies;
var  int     sum = 0;

var Body b with
    this.bodies = &bodies;
    this.sum    = &sum;
end;
await b;

escape sum;
]],
    wrn = 'line 9 : unbounded recursive spawn',
    run = { ['~>200s'] = 101 },
}
Test { [[
class Body with
    pool&[3]  Body bodies;
    var&   int    sum;
    event int     ok;
do
    do finalize with end;

    var Body&&? nested =
        spawn Body in bodies with
            this.bodies = &bodies;
            this.sum    = &sum;
        end;
    if nested? then
        watching *nested! do
            await nested!:ok;
        end
    end
    await 1s;
    sum = sum + 1;
    emit this.ok(1);
end


pool[3] Body bodies;
var  int     sum = 0;

var Body&&? b = spawn Body in bodies with
    this.bodies = &bodies;
    this.sum    =& sum;
end;
await *b!;

escape sum;
]],
    _ana = {acc=true},
    run = { ['~>10s'] = 3 },
}

Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var Tree left;
    end
var Tree&& n;
if false then
    await *n;
end
escape 1;
]],
    wrn = true,
    --ref = 'line 10 : invalid access to uninitialized variable "n" (declared at /tmp/tmp.ceu:8)',
    --run = 1,
    inits = 'line 6 : uninitialized variable "n" : reached `await´ (/tmp/tmp.ceu:8)',
}
Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var Tree left;
    end
class Body with
    var Tree&& n;
do
    if false then
        await *(this.n);
    end
end
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree;
tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

class Body with
    pool&[]  Body bodies;
    var   Tree&&   n;
    var&   int    sum;
    event int     ok;
do
    watching *n do
        var int i = this.sum;
        if i!=0 then end;
        if (*n is Node) then
            var Body&&? left =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n as Node).left;
                    this.sum    = &sum;
                end;
            if left? then
                watching *left! do
                    await left!:ok;
                end
            end

            this.sum = this.sum + 1;

            var Body&&? right =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n as Node).right;
                    this.sum    = &sum;
                end;
            if right? then
                watching *right! do
                    await right!:ok;
                end
            end
        end
    end
    await 1s;
    emit this.ok(1);
end

var int sum = 0;

pool[7] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&tree;
    this.sum    = &sum;
end;

escape sum;
]],
    _ana = {acc=true},
    wrn = 'line 26 : unbounded recursive spawn',
    run = { ['~>10s'] = 3 },
}
Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree;
tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

class Body with
    pool&[]  Body bodies;
    var   Tree&&   n;
    var&   int    sum;
    event int     ok;
do
    watching *n do
        var int i = this.sum;
        if (*n is Node) then
            var Body&&? left =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n as Node).left;
                    this.sum    = &sum;
                end;
            if left? then
                watching *left! do
                    await left!:ok;
                end
            end

            this.sum = this.sum + i + (*n as Node).v;

            var Body&&? right =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n as Node).right;
                    this.sum    = &sum;
                end;
            if right? then
                watching *right! do
                    await right!:ok;
                end
            end
        end
    end
    await 1s;
    emit this.ok(1);
end

var int sum = 0;

pool[7] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&tree;
    this.sum    = &sum;
end;

escape sum;
]],
    wrn = 'line 26 : unbounded recursive spawn',
    run = { ['~>10s'] = 9 },
}
Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

class Body with
    pool&[7]  Body bodies;
    var   Tree&&    n;
    var&   int     sum;
    event int      ok;
do
    watching *n do
        var int i = this.sum;
        if (*n is Node) then
            var Body&&? left =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n as Node).left;
                    this.sum    = &sum;
                end;
            if left? then
                watching *left! do
                    await left!:ok;
                end
            end

            this.sum = this.sum + i + (*n as Node).v;

            var Body&&? right =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n as Node).right;
                    this.sum    = &sum;
                end;
            if right? then
                watching *right! do
                    await right!:ok;
                end
            end

            //do/spawn Body in this.bodies with
                //this.n = (*n as Node).left;
            //end;
        end
    end
    await 1s;
    emit this.ok(1);
end

var int sum = 0;

pool[7] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&tree;
    this.sum    = &sum;
end;

escape sum;
]],
    run = { ['~>10s'] = 9 },
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list
    = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

class Body with
    pool&[]  Body bodies;
    var   List&&   n;
do
    await 1s;
    if (*n is List.Nil) then
    end
    watching *n do
        if (*n is List.Cons) then
            spawn Body in this.bodies with
                this.bodies = &bodies;
                this.n      = &&(*n is List.Cons).tail;
            end;
        end
    end
end

pool[3] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&list;
end;

escape 1;
]],
    fin = 'line 20 : unsafe access to pointer "n" across `await´ (/tmp/tmp.ceu : 19)',
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list
    = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

class Body with
    pool&[]  Body bodies;
    var   List&&   n;
do
    if (*n is List.Nil) then
    end
    watching *n do
        if (*n is List.Cons) then
            spawn Body in this.bodies with
                this.bodies = &bodies;
                this.n      = &&(*n is List.Cons).tail;
            end;
        end
    end
end

pool[3] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&list;
end;

escape 1;
]],
    wrn = true,
    run = 1,
    --fin = 'line 19 : unsafe access to pointer "n" across `class´ (/tmp/tmp.ceu : 15)',
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    if (*n is List.Cons) then
        sum = sum + (*n is List.Cons).head;
        traverse &&(*n is List.Cons).tail;
    end
end

escape sum;
]],
    run = 10,
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    if (*n is List.Cons) then
        sum = sum + (*n is List.Cons).head;
        await 1s;
        traverse &&(*n is List.Cons).tail;
    end
end

escape sum;
]],
    fin = 'line 22 : unsafe access to pointer "n" across `await´ (/tmp/tmp.ceu : 21)',
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    await 1s;
    if (*n is List.Cons) then
        sum = sum + (*n is List.Cons).head;
        traverse &&(*n is List.Cons).tail;
    end
end

escape sum;
]],
    fin = 'line 20 : unsafe access to pointer "n" across `await´ (/tmp/tmp.ceu : 19)',
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    if (*n is List.Cons) then
        sum = sum + (*n is List.Cons).head;
        watching *n do
            await 1s;
            traverse &&(*n is List.Cons).tail;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 10 },
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    //watching *n do
        //await 1s;
        if (*n is List.Cons) then
            sum = sum + (*n is List.Cons).head;
            traverse &&(*n is List.Cons).tail;
        end
    //end
end

escape sum;
]],
    run = { ['~>10s'] = 10 },
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    //watching *n do
        await 1s;
        if (*n is List.Cons) then
            sum = sum + (*n is List.Cons).head;
            traverse &&(*n is List.Cons).tail;
        end
    //end
end

escape sum;
]],
    fin = 'line 21 : unsafe access to pointer "n" across `await´ (/tmp/tmp.ceu : 20)',
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list
    = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    if (*n is List.Nil) then
        sum = sum * 2;
    end
    watching *n do
        if (*n is List.Cons) then
            sum = sum + (*n is List.Cons).head;
            traverse &&(*n is List.Cons).tail;
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
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree =
    new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int  v = 0;
var int&& ptr = &&v;

traverse t in &&tree do
    *ptr = *ptr + 1;
    if (*t is Node) then
        traverse &&(*t as Node).left;
        traverse &&(*t as Node).right;
    end
end

escape v;
]],
    fin = 'line 23 : unsafe access to pointer "t" across `spawn´ (/tmp/tmp.ceu : 22)',
    --run = 7,
}

Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree =
    new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int  v = 0;
var int&& ptr = &&v;

traverse t in &&tree do
    *ptr = *ptr + 1;
    if (*t is Node) then
        watching *t do
            traverse &&(*t as Node).left;
            traverse &&(*t as Node).right;
        end
    end
end

escape v;
]],
    --fin = 'line 20 : unsafe access to pointer "ptr" across `class´',
    run = 7,
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

native/pos do
    int V = 0;
end

/*
traverse n in &&list do
    _V = _V + 1;
    if (*n is List.Cons) then
        _V = _V + (*n is List.Cons).head;
        traverse &&(*n is List.Cons).tail;
    end
end
*/

class Body with
    pool&[3]  Body bodies;
    var   List&&    n;
do
    if (*n is List.Nil) then
native _V;
        _V = _V * 2;
    end
    watching *n do
        _V = _V + 1;
        if (*n is List.Cons) then
            _V = _V + (*n is List.Cons).head;

            var Body&&? tail =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n is List.Cons).tail;
                end;
            if tail? then
                await *tail!;
            end
        end
    end
end

pool[3] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&list;
end;

escape _V;
]],
    --fin = 'line 33 : unsafe access to pointer "n" across `class´',
    _ana = {acc=true},
    run = 18,
}

Test { [[
data List;
    data Nil_;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[4] List list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

native/pos do
    int V = 0;
end

/*
traverse n in &&list do
    _V = _V + 1;
    if (*n is List.Cons) then
        _V = _V + (*n is List.Cons).head;
        traverse &&(*n is List.Cons).tail;
    end
end
*/

class Body with
    pool&[4]  Body bodies;
    var   List&&    n;
do
    watching *n do
        if (*n is List.Nil) then
native _V;
            _V = _V * 2;
        else/if (*n is List.Cons) then
            _V = _V + 1;
            _V = _V + (*n is List.Cons).head;

            var Body&&? tail =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n is List.Cons).tail;
                end;
            if tail? then
                await *tail!;
            end
        end
    end
end

pool[4] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&list;
end;

escape _V;
]],
    _ana = { acc=true },
    run = 18,
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

native/pos do
    int V = 0;
end

traverse n in &&list do
native _V;
    _V = _V + 1;
    if (*n is List.Cons) then
        _V = _V + (*n is List.Cons).head;
        traverse &&(*n is List.Cons).tail;
    end
end

/*
class Body with
    pool&[]  Body bodies;
    var   List&&   n;
do
    watching *n do
        _V = _V + 1;
        if (*n is List.Cons) then
            _V = _V + (*n is List.Cons).head;

            var Body&&? tail =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n is List.Cons).tail;
                end;
            if tail? then
                await *tail!;
            end
        end
    end
end

pool[3] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&list;
end;
*/

escape _V;
]],
    _ana = { acc=true },
    wrn = 'line 23 : unbounded recursive spawn',
    run = 10,
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

native/pos do
    int V = 0;
end

traverse n in &&list do
native _V;
    _V = _V + 1;
    if (*n is List.Cons) then
        _V = _V + (*n is List.Cons).head;
        traverse &&(*n is List.Cons).tail;
    end
end

/*
class Body with
    pool&[]  Body bodies;
    var   List&&   n;
do
    watching *n do
        _V = _V + 1;
        if (*n is List.Cons) then
            _V = _V + (*n is List.Cons).head;

            var Body&&? tail =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n is List.Cons).tail;
                end;
            if tail? then
                await *tail!;
            end
        end
    end
end

pool[3] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&list;
end;
*/

escape _V;
]],
    _ana = { acc=true },
    run = 10,
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    watching *n do
        await 1s;
        if (*n is List.Cons) then
            sum = sum + (*n is List.Cons).head;
            traverse &&(*n is List.Cons).tail;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 10 },
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    //watching *n do
        await 1s;
        if (*n is List.Cons) then
            sum = sum + (*n is List.Cons).head;
            traverse &&(*n is List.Cons).tail;
        end
    //end
end

escape sum;
]],
    --run = { ['~>10s'] = 10 },
    fin = 'line 21 : unsafe access to pointer "n" across `await´ (/tmp/tmp.ceu : 20)',
}

Test { [[
native/pos do
##ifdef CEU_ORGS_NEWS_MALLOC
##error "malloc found"
##endif
end

data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;
traverse n in &&list do
    sum = sum + 1;
    watching *n do
        await 1s;
        if (*n is List.Cons) then
            sum = sum + (*n is List.Cons).head;
            traverse &&(*n is List.Cons).tail;
            sum = sum + (*n is List.Cons).head;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 16 },
}

Test { [[
native/pos do
##ifdef CEU_ORGS_NEWS_MALLOC
##error "malloc found"
##endif
end

data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

class Tx with
do
    pool[3] List list;
    list = new List.Cons(1,
                List.Cons(2,
                    List.Cons(3, List.Nil())));

    var int sum = 0;
    traverse n in &&list do
        sum = sum + 1;
        watching *n do
            await 1s;
            if (*n is List.Cons) then
                sum = sum + (*n is List.Cons).head;
                traverse &&(*n is List.Cons).tail;
                sum = sum + (*n is List.Cons).head;
            end
        end
    end
    escape sum;
end

var int sum = do Tx;

escape sum;
]],
    run = { ['~>10s'] = 16 },
}

Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[] Tree tree;
tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int sum = 0;

traverse n in &&tree do
    sum = sum + 1;
    watching *n do
        if (*n is Node) then
            traverse &&(*n as Node).left;
            sum = sum + (*n as Node).v;
            traverse &&(*n as Node).right;
        end
    end
end

escape sum;
]],
    wrn = 'line 22/24 : unbounded recursive spawn',
    run = 13,
}

Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int sum = 0;

traverse n in &&tree do
    sum = sum + 1;
    watching *n do
        if (*n is Node) then
            traverse &&(*n as Node).left;
            sum = sum + (*n as Node).v;
            traverse &&(*n as Node).right;
        end
    end
end

escape sum;
]],
    run = 13,
}

Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int sum = 0;

traverse n in &&tree do
    sum = sum + 1;
    watching *n do
        if (*n is Node) then
            await 1s;
            traverse &&(*n as Node).left;
            sum = sum + (*n as Node).v;
            traverse &&(*n as Node).right;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 13 },
}

Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[] Tree tree;
tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int sum = 1;

traverse n in &&tree do
    watching *n do
        if (*n is Node) then
            traverse &&(*n as Node).left;
            sum = sum * (*n as Node).v + (*n as Node).v;
            traverse &&(*n as Node).right;
        end
    end
end

escape sum;
]],
    wrn = 'line 22/24 : unbounded recursive spawn',
    run = { ['~>10s'] = 18 },
}
Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree;
tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int sum = 1;

traverse n in &&tree do
    watching *n do
        if (*n is Node) then
            traverse &&(*n as Node).left;
            sum = sum * (*n as Node).v + (*n as Node).v;
            traverse &&(*n as Node).right;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 18 },
}

Test { [[
data Tx;
    data Tx.Nil;
    data Tx.Nxt with
        var int v;
        var Tx   nxt;
    end

pool[] Tx ts;

var void&& p1 = this as void&&;

traverse t in &&ts do
native _assert;
    _assert(p1 == (this as void&&));
    if (*t is Nxt) then
        traverse &&(*t as Nxt).nxt;
    end
end

escape 1;
]],
    --fin = 'line 15 : unsafe access to pointer "p1" across `class´ (/tmp/tmp.ceu : 14)',
    cc = '12:5: error: cannot convert to a pointer type',
    wrn = true,
    run = 1,
}
Test { [[
data Tx;
    data Tx.Nil;
    data Tx.Nxt with
        var int v;
        var Tx   nxt;
    end

pool[] Tx ts;

var void&& p1 = (&&this) as void&&;

traverse t in &&ts do
native _assert;
    _assert(p1 == ((&&this) as void&&));
    if (*t is Nxt) then
        traverse &&((*t) as Nxt).nxt;
    end
end

escape 1;
]],
    --fin = 'line 15 : unsafe access to pointer "p1" across `class´ (/tmp/tmp.ceu : 14)',
    wrn = true,
    run = 1,
}
Test { [[
data Tx;
    data Tx.Nil;
    data Tx.Nxt with
        var int v;
        var Tx   nxt;
    end

pool[] Tx ts;

native/pos do
    ##define PTR2REF(x) &x
end
var& void? p1;
    do p1 = &_PTR2REF(this);
finalize with
    nothing;
end

traverse t in &&ts do
native _assert;
    _assert(&&p1! == (&&this as void&&));
    if (*t is Nxt) then
        traverse &&(*t as Nxt).nxt;
    end
end

escape 1;
]],
    wrn = 'line 17 : unbounded recursive spawn',
    run = 1,
}
Test { [[
data Tx;
    data Tx.Nil;
    data Tx.Nxt with
        var int v;
        var Tx   nxt;
    end

pool[1] Tx ts;

native/pos do
    ##define PTR2REF(x) &x
end
var& void? p1;
    do p1 = &_PTR2REF(this);
finalize with
    nothing;
end

traverse t in &&ts do
native _assert;
    _assert(&&p1! == (&&this as void&&));
    if (*t is Nxt) then
        traverse &&(*t as Nxt).nxt;
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
data Tx;
    data Tx.Nil;
    data Tx.Nxt with
        var int v;
        var Tx   nxt;
    end

pool[] Tx ts;

native/pos do
    ##define PTR2REF(x) &x
end
var& void? p1;
    do p1 = &_PTR2REF(this);
finalize with
    nothing;
end

var int v2 = 2;
var int v3 = 3;

class X with
    var int v1, v2, v3;
do end

traverse t in &&ts do
native _assert;
    _assert(&&p1! == (&&this as void&&));
    var int v1 = 1;
    var int v3 = 0;
    var X x with
        this.v1 = v1;
        this.v2 = v2;
        this.v3 = outer.v3;
    end;
    _assert(x.v1 + x.v2 + x.v3 == 6);
    if (*t is Nxt) then
        traverse &&(*t as Nxt).nxt;
    end
end

escape 1;
]],
    wrn = 'line 17 : unbounded recursive spawn',
    run = 1,
}
Test { [[
data Tx;
    data Tx.Nil;
    data Tx.Nxt with
        var int v;
        var Tx   nxt;
    end

pool[1] Tx ts;

native/pos do
    ##define PTR2REF(x) &x
end
var& void? p1;
    do p1 = &_PTR2REF(this);
finalize with
    nothing;
end

var int v2 = 2;
var int v3 = 3;

class X with
    var int v1, v2, v3;
do end

traverse t in &&ts do
native _assert;
    _assert(&&p1! == (&&this as void&&));
    var int v1 = 1;
    var int v3 = 0;
    var X x with
        this.v1 = v1;
        this.v2 = v2;
        this.v3 = outer.v3;
    end;
    _assert(x.v1 + x.v2 + x.v3 == 6);
    if (*t is Nxt) then
        traverse &&(*t as Nxt).nxt;
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int sum = 1;

traverse n in &&tree do
    watching *n do
        await 1s;
        if (*n is Node) then
            traverse &&(*n as Node).left;
            sum = sum * (*n as Node).v + (*n as Node).v;
            traverse &&(*n as Node).right;
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 18 },
}

Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int sum = 1;

traverse n in &&tree do
    await 1s;
    watching *n do
        if (*n is Node) then
            traverse &&(*n as Node).left;
            sum = sum * (*n as Node).v + (*n as Node).v;
            traverse &&(*n as Node).right;
        end
    end
end

escape sum;
]],
    fin = 'line 19 : unsafe access to pointer "n" across `await´ (/tmp/tmp.ceu : 18)',
}

Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree;
tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int sum = 1;

do
    traverse n in &&tree do
        watching *n do
            await 1s;
            if (*n is Node) then
                traverse &&(*n as Node).left;
                sum = sum * (*n as Node).v + (*n as Node).v;
                traverse &&(*n as Node).right;
            end
        end
    end
end

escape sum;
]],
    run = { ['~>10s'] = 18 },
}

Test { [[
data Tree;
    data Tree.Nil;
    data Tree.Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end

pool[3] Tree tree = new Node(1,
            Node(2, Tree.Nil(), Tree.Nil()),
            Node(3, Tree.Nil(), Tree.Nil()));

var int sum = 1;

par/and do
    traverse n in &&tree do
        watching *n do
            if (*n is Node) then
                await 1s;
                traverse &&(*n as Node).left;
                sum = sum * (*n as Node).v + (*n as Node).v;
                traverse &&(*n as Node).right;
                await 1s;
            end
        end
    end
    sum = sum - 1;
with
    await 1s;
native _ceu_callback_assert_msg;
    _ceu_callback_assert_msg(sum == 1, "1");
    await 1s;
    _ceu_callback_assert_msg(sum == 4, "2");
    await 1s;
    _ceu_callback_assert_msg(sum == 5, "3");
    tree = new Tree.Nil();
    _ceu_callback_assert_msg(sum == 4, "4");
end

escape sum;
]],
    _ana = {acc=true},
    run = { ['~>20s'] = 4 },
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    if (*n is List.Cons) then
        sum = sum + (*n is List.Cons).head;
        loop i in [0 -> 1[ do
            traverse &&(*n is List.Cons).tail;
        end
    end
end

escape sum;
]],
    fin = 'line 22 : unsafe access to pointer "n" across `loop´ (/tmp/tmp.ceu : 21)',
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    if (*n is List.Cons) then
        sum = sum + (*n is List.Cons).head;
        //loop i in [0 -> 1[ do
            traverse &&(*n is List.Cons).tail;
        //end
    end
end

escape sum;
]],
    wrn = 'line 24 : unbounded recursive spawn',
    run = 10,
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list
    = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

traverse n in &&list do
    sum = sum + 1;
    if (*n is List.Cons) then
        sum = sum + (*n is List.Cons).head;
        //loop i in [0 -> 1[ do
            traverse &&(*n is List.Cons).tail;
        //end
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
data Widget;
    data Widget.Empty;
    data Widget.Seq with
        var Widget  w1;
        var Widget  w2;
    end

pool[] Widget widgets;
widgets = new Seq(
            Empty(),
            Empty());

var int ret = 0;

traverse widget in &&widgets with
    var int param = 1;
do
    ret = ret + param;

    watching *widget do
        if (*widget is Empty) then
            nothing;

        else/if (*widget is Seq) then
            traverse &&(*widget as Seq).w1 with
                this.param = param + 1;
            end;
            traverse &&(*widget as Seq).w2 with
                this.param = param + 1;
            end;

        else
native _ceu_callback_assert_msg;
            _ceu_callback_assert_msg(0, "not implemented");
        end
    end
end

escape ret;
]],
    adt = 'line 23 : ineffective use of data "Empty" due to enclosing `watching´',
}
Test { [[
data Widget;
    data Widget.Empty;
    data Widget.Seq with
        var Widget  w1;
        var Widget  w2;
    end

pool[] Widget widgets;
widgets = new Seq(
            Empty(),
            Empty());

var int ret = 0;

traverse widget in &&widgets with
    var int param = 1;
do
    ret = ret + param;

    watching *widget do
        if (*widget is Seq) then
            traverse &&(*widget as Seq).w1 with
                this.param = param + 1;
            end;
            traverse &&(*widget as Seq).w2 with
                this.param = param + 1;
            end;

        else
native _ceu_callback_assert_msg;
            _ceu_callback_assert_msg(0, "not implemented");
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
data Widget;
    data Widget.Empty;
    data Widget.Seq with
        var Widget  w1;
        var Widget  w2;
    end

pool[10] Widget widgets;
widgets = new Seq(
            Empty(),
            Empty());

var int ret = 0;

traverse widget in &&widgets with
    var int param = 1;
do
    ret = ret + param;

    watching *widget do
        if (*widget is Seq) then
            traverse &&(*widget as Seq).w1 with
                this.param = param + 1;
            end;
            traverse &&(*widget as Seq).w2 with
                this.param = param + 1;
            end;

        else
native _ceu_callback_assert_msg;
            _ceu_callback_assert_msg(0, "not implemented");
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
data Widget;
    data Widget.Empty;
    data Widget.Seq with
        var Widget  w1;
        var Widget  w2;
    end

pool[] Widget widgets
    = new Seq(
            Empty(),
            Empty());

var int ret = 0;

traverse widget in &&widgets with
    var int param = 1;
do
    ret = ret + param;

    watching *widget do
        if (*widget is Seq) then
            traverse &&(*widget as Seq).w1 with
                this.param = param + 1;
            end;
            traverse &&(*widget as Seq).w2 with
                this.param = param + 1;
            end;

        else
native _ceu_callback_assert_msg;
            _ceu_callback_assert_msg(0, "not implemented");
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
data Widget;
    data Widget.Empty;
    data Widget.Seq with
        var Widget  w1;
        var Widget  w2;
    end

pool[10] Widget widgets = new Seq(
            Empty(),
            Empty());

var int ret = 0;

traverse widget in &&widgets with
    var int param = 1;
do
    ret = ret + param;

    watching *widget do
        if (*widget is Seq) then
            traverse &&(*widget as Seq).w1 with
                this.param = param + 1;
            end;
            traverse &&(*widget as Seq).w2 with
                this.param = param + 1;
            end;

        else
native _ceu_callback_assert_msg;
            _ceu_callback_assert_msg(0, "not implemented");
        end
    end
end

escape ret;
]],
    _ana = { acc=true },
    run = 5,
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[] List l = new List.Cons(1,
            List.Cons(2,
                List.Cons(3,
                    List.Cons(4,
                        List.Cons(5,
                            List.Nil())))));

var int ret = 0;

par/or do
    await (((l as List.Cons).tail) as List.Cons).tail;
    ret = 100;
with
    (((l as List.Cons).tail) as List.Cons).tail = new List.Nil();
    ret = 10;
end

escape ret;
]],
    _ana = {acc=true},
    run = 100,
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[] List l;
l = new List.Cons(1,
            List.Cons(2,
                List.Cons(3,
                    List.Cons(4,
                        List.Cons(5,
                            List.Nil())))));

var int ret = 0;

native _ceu_callback_assert_msg;
par/or do
    await (((l as List.Cons).tail) as List.Cons).tail;
    ret = ret + ((((l as List.Cons).tail) as List.Cons).tail as List.Cons).head;    // 0+4
    _ceu_callback_assert_msg(ret == 4, "1");
    (((l as List.Cons).tail) as List.Cons).tail = ((((l as List.Cons).tail) as List.Cons).tail as List.Cons).tail;
    ret = ret + ((((l as List.Cons).tail) as List.Cons).tail as List.Cons).head;    // 0+4+5
    _ceu_callback_assert_msg(ret == 9, "2");

    await (((l as List.Cons).tail) as List.Cons).tail;
    ret = ret + (((((l as List.Cons).tail) as List.Cons).tail is List.Nil)as int);          // 0+4+5+5+1
    _ceu_callback_assert_msg(ret == 15, "4");
    await FOREVER;
with
    await (((l as List.Cons).tail) as List.Cons).tail;
    _ceu_callback_assert_msg(ret == 9, "3");
    ret = ret + ((((l as List.Cons).tail) as List.Cons).tail as List.Cons).head;    // 0+4+5+5
    (((l as List.Cons).tail) as List.Cons).tail = new List.Nil();

    _ceu_callback_assert_msg(ret == 15, "5");
    await (((l as List.Cons).tail) as List.Cons).tail;
    // never reached
    _ceu_callback_assert_msg(ret == 15, "6");
    await FOREVER;
with
    await (((l as List.Cons).tail) as List.Cons).tail;
    ret = ret + (((((l as List.Cons).tail) as List.Cons).tail is List.Nil)as int);          // 0+4+5+5+1+1

    await (((l as List.Cons).tail) as List.Cons).tail;
    _ceu_callback_assert_msg(ret == 16, "7");
    await FOREVER;
with
    (((l as List.Cons).tail) as List.Cons).tail = ((((l as List.Cons).tail) as List.Cons).tail as List.Cons).tail;
    ret = ret * 2;  // (0+4+5+5+1+1) * 2
    (((l as List.Cons).tail) as List.Cons).tail = new List.Cons(10, List.Nil());
end

escape ret;
]],
    _ana = {acc=true},
    run = 32,
}

Test { [[
input void OS_START;

data Widget;
    data Wiget.Nil;
    data Widget.Vv with
        var int v;
    end
    data Widget.Row with
        var Widget  w1;
        var Widget  w2;
    end

par/or do
    await 21s;
with
    pool[] Widget widgets = new Row(
                    Vv(10),
                    Vv(20));

    var int ret = do/_
        traverse widget in &&widgets do
            watching *widget do
                if (*widget is Vv) then
                    await ((*widget as Vv).v)s;
                    escape (*widget as Vv).v;

                else/if (*widget is Row) then
                    var int v1=0, v2=0;
                    par/and do
                        v1 = traverse &&(*widget as Row).w1;
                    with
                        v2 = traverse &&(*widget as Row).w2;
                    end
                    escape v1 + v2;

                else
native _ceu_callback_assert_msg;
                    _ceu_callback_assert_msg(0, "not implemented");
                end
            end
            escape 0;
end
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

data Widget;
    data Nil_;
    data Wiget.Nil;
    data Wiget.Empty;
    data Widget.Row with
        var Widget  w1;
        var Widget  w2;
    end

par/or do
    await OS_START;
with
    pool[] Widget widgets;
    widgets = new Row(
                    Empty(),
                    Empty());

    traverse widget in &&widgets do
        watching *widget do
            if (*widget is List.Nil) then
                await FOREVER;
            else/if (*widget is Empty) then
                escape 1;

            else/if (*widget is Row) then
                loop i in [0 -> 3[ do
                    par/or do
                        var int ret = traverse &&(*widget as Row).w1;
                        if ret == 0 then
                            await FOREVER;
                        end
                    with
                        var int ret = traverse &&(*widget as Row).w2;
                        if ret == 0 then
                            await FOREVER;
                        end
                    end
                end

            else
native _ceu_callback_assert_msg;
                _ceu_callback_assert_msg(0, "not implemented");
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

data List;
    data List.Nil;
    data List.Empty;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[] List l = new List.Cons(1, Empty());

par/or do
    traverse e in &&l do
        watching *e do
            if (*e is Empty) then
                await FOREVER;

            else/if (*e is List.Cons) then
                loop do
                    traverse &&(*e as List.Cons).tail;
native _ceu_callback_assert_msg;
                    _ceu_callback_assert_msg(0, "0");
                end
            else
                _ceu_callback_assert_msg(0, "1");
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

data Widget;
    data Widget.Nil;
    data Widget.Empty;
    data Widget.Seq with
        var Widget  w1;
        var Widget  w2;
    end

var int ret = 0;

par/or do
    pool[] Widget widgets;
    widgets = new Seq(
                Empty(),
                Empty());

    traverse widget in &&widgets with
        var int param = 1;
    do
        ret = ret + param;

        watching *widget do
            if (*widget is Empty) then
                await FOREVER;

            else/if (*widget is Seq) then
                loop do
                    par/or do
                        traverse &&(*widget as Seq).w1 with
                            this.param = param + 1;
                        end;
if ((*widget is Seq).w1 is List.Nil) then
    await FOREVER;
end
                    with
                        traverse &&(*widget as Seq).w2 with
                            this.param = param + 1;
                        end;
if ((*widget is Seq).w2 is List.Nil) then
    await FOREVER;
end
                    end
                end

            else
native _ceu_callback_assert_msg;
                _ceu_callback_assert_msg(0, "not implemented");
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

data Widget;
    data Widget.Nil;
    data Widget.Empty;
    data Widget.Seq with
        var Widget  w1;
        var Widget  w2;
    end

var int ret = 0;

par/or do
    pool[10] Widget widgets = new Seq(
                Empty(),
                Empty());

    traverse widget in &&widgets with
        var int param = 1;
    do
        ret = ret + param;

        watching *widget do
            if (*widget is Empty) then
                await FOREVER;

            else/if (*widget is Seq) then
                loop do
                    par/or do
                        traverse &&(*widget as Seq).w1 with
                            this.param = param + 1;
                        end;
if ((*widget is Seq).w1 is List.Nil) then
    await FOREVER;
end
                    with
                        traverse &&(*widget as Seq).w2 with
                            this.param = param + 1;
                        end;
if ((*widget is Seq).w2 is List.Nil) then
    await FOREVER;
end
                    end
                end

            else
native _ceu_callback_assert_msg;
                _ceu_callback_assert_msg(0, "not implemented");
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

data Widget;
    data Widget.Nil;
    data Widget.Empty;
    data Widget.Seq with
        var Widget  w1;
        var Widget  w2;
    end

pool[] Widget widgets;
widgets = new Seq(
            Empty(),
            Empty());

var int ret = 0;

par/or do
    traverse widget in &&widgets with
        var int param = 1;
    do
        ret = ret + param;

        watching *widget do
            if (*widget is Empty) then
                await FOREVER;

            else/if (*widget is Seq) then
                loop do
                    par/or do
                        traverse &&(*widget as Seq).w1 with
                            this.param = param + 1;
                        end;
if ((*widget is Seq).w1 is List.Nil) then
native _ceu_callback_assert_msg;
_ceu_callback_assert_msg(0, "ok\n");
    await FOREVER;
end
                    with
                        traverse &&(*widget as Seq).w2 with
                            this.param = param + 1;
                        end;
if ((*widget is Seq).w2 is List.Nil) then
_ceu_callback_assert_msg(0, "ok\n");
    await FOREVER;
end
                    end
                end

            else
                _ceu_callback_assert_msg(0, "not implemented");
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

data Widget;
    data Widget.Nil;
    data Widget.Empty;
    data Widget.Seq with
        var Widget  w1;
        var Widget  w2;
    end

pool[10] Widget widgets = new Seq(
            Empty(),
            Empty());

var int ret = 0;

par/or do
    traverse widget in &&widgets with
        var int param = 1;
    do
        ret = ret + param;

        watching *widget do
            if (*widget is Empty) then
                await FOREVER;

            else/if (*widget is Seq) then
                loop do
                    par/or do
                        traverse &&(*widget as Seq).w1 with
                            this.param = param + 1;
                        end;
if ((*widget is Seq).w1 is List.Nil) then
native _ceu_callback_assert_msg;
_ceu_callback_assert_msg(0, "ok\n");
    await FOREVER;
end
                    with
                        traverse &&(*widget as Seq).w2 with
                            this.param = param + 1;
                        end;
if ((*widget is Seq).w2 is List.Nil) then
_ceu_callback_assert_msg(0, "ok\n");
    await FOREVER;
end
                    end
                end

            else
                _ceu_callback_assert_msg(0, "not implemented");
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
data Command;
    data Command.Nothing;
    data Command.Forward with
        var int pixels;
    end
    data Command.Sequence with
        var Command  one;
        var Command  two;
    end

pool[] Command cmds;

cmds = new Command.Sequence(
            Forward(100),
            Forward(500));

par/or do
    traverse cmd in &&cmds do
do finalize with
end
        watching *cmd do
            if (*cmd is Forward) then
                await FOREVER;

            else/if (*cmd is Command.Sequence) then
                traverse &&(*cmd as Command.Sequence).one;

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
data Command;
    data Command.Nothing;
    data Command.Sequence with
        var Command  one;
    end

pool[] Command cmds = new Command.Sequence(Command.Nothing());

par/or do
    traverse cmd in &&cmds do
        if (*cmd is Nothing) then
            await FOREVER;
        else/if (*cmd is Command.Sequence) then
            traverse &&(*cmd as Command.Sequence).one;
        end
    end
with
end

escape 10;
]],
    wrn = true,
    run = 10,
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Forward with
        var int pixels;
    end
    data Command.Sequence with
        var Command  one;
        var Command  two;
    end

pool[] Command cmds;

cmds = new Command.Sequence(
            Forward(100),
            Forward(500));

par/or do
    traverse cmd in &&cmds do
        watching *cmd do
            if (*cmd is Forward) then
                await FOREVER;

            else/if (*cmd is Command.Sequence) then
                traverse &&(*cmd as Command.Sequence).one;

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

data Command;
    data Command.Nothing;
    data Command.Forward with
        var int pixels;
    end
    data Command.Sequence with
        var Command  one;
        var Command  two;
    end

// TODO: aceitar estatico
pool[] Command cmds = new Command.Sequence(
            Forward(100),
            Forward(500));

par/or do
    await 100s;
with
    traverse cmd in &&cmds do
        watching *cmd do
            if (*cmd is Forward) then
                await FOREVER;

            else/if (*cmd is Command.Sequence) then
                traverse &&(*cmd as Command.Sequence).one;
native _ceu_callback_assert_msg;
                _ceu_callback_assert_msg(0, "bug found"); // cmds has to die entirely before children
                traverse &&(*cmd as Command.Sequence).two;
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

data Command;
    data Command.Nothing;
    data Command.Forward with
        var int pixels;
    end
    data Command.Sequence with
        var Command  one;
        var Command  two;
    end

// TODO: aceitar estatico
pool[] Command cmds;

cmds = new Command.Sequence(
            Forward(100),
            Forward(500));

par/or do
    await 100s;
with
    traverse cmd in &&cmds do
        watching *cmd do
            if (*cmd is Forward) then
                await FOREVER;

            else/if (*cmd is Command.Sequence) then
                traverse &&(*cmd as Command.Sequence).one;
                traverse &&(*cmd as Command.Sequence).two;
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
data Command;
    data Command.Nothing;
    data Left;
    data Command.Repeat with
        var Command  command;
    end

pool[] Command cmds = new Repeat(
            Left());

class TurtleTurn with
do
    await 1us;
end

traverse cmd in &&cmds do
    watching *cmd do
        if (*cmd is Left) then
            do TurtleTurn;

        else/if (*cmd is Repeat) then
            traverse &&(*cmd as Repeat).command;
            traverse &&(*cmd as Repeat).command;

        else
native _ceu_callback_assert_msg;
            _ceu_callback_assert_msg(0, "not implemented");
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

data Command;
    data Command.Nothing;
    data Command.Await with
        var int ms;
    end
    data Command.Right with
        var int angle;
    end
    data Command.Left with
        var int angle;
    end
    data Command.Forward with
        var int pixels;
    end
    data Command.Backward with
        var int pixels;
    end
    data Command.Sequence with
        var Command  one;
        var Command  two;
    end
    data Command.Repeat with
        var int      times;
        var Command  command;
    end

// TODO: aceitar estatico
pool[] Command cmds;

cmds = new Repeat(2,
            Command.Sequence(
                Await(500),
                Command.Sequence(
                    Right(45),
                    Command.Sequence(
                        Forward(100),
                        Command.Sequence(
                            Left(90),
                            Command.Sequence(
                                Forward(100),
                                Command.Sequence(
                                    Right(45),
                                    Command.Sequence(
                                        Backward(100),
                                        Await(500)))))))));

class Turtle with
    var int angle=0;
    var int pos_x=0, pos_y=0;
do
    await FOREVER;
end

class TurtleTurn with
    var& Turtle turtle;
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
    loop i in [0->angle[ do
        await 10ms;
        turtle.angle = turtle.angle + inc;
    end
end

class TurtleMove with
    var& Turtle turtle;
    var int     pixels;
    var int     isForward;
do
    var int inc;
    if isForward then
        inc =  1;
    else
        inc = -1;
    end
native _ceu_callback_assert_msg;
    _ceu_callback_assert_msg(this.pixels > 0, "pixels");

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

    traverse cmd in &&cmds do
        watching *cmd do
            if (*cmd is Await) then
                await ((*cmd as Await).ms) ms;

            else/if (*cmd is Right) or (*cmd is Left) then
                var int angle;
                if (*cmd is Right) then
                    angle = (*cmd as Right).angle;
                else
                    angle = (*cmd as Left).angle;
                end
                do TurtleTurn with
                    this.turtle  = &turtle;
                    this.angle   = angle;
                    this.isRight = (*cmd is Right);
                end;

            else/if (*cmd is Forward) or (*cmd is Backward) then
                var int pixels;
                if (*cmd is Forward) then
                    pixels = (*cmd as Forward).pixels;
                else
                    pixels = (*cmd as Backward).pixels;
                end
                do TurtleMove with
                    this.turtle    = &turtle;
                    this.pixels    = pixels;
                    this.isForward = (*cmd is Forward);
                end;

            else/if (*cmd is Command.Sequence) then
                traverse &&(*cmd as Command.Sequence).one;
                traverse &&(*cmd as Command.Sequence).two;

            else/if (*cmd is Repeat) then
                loop i in (*cmd as Repeat).times do
                    traverse &&(*cmd as Repeat).command;
                end

            else
                _ceu_callback_assert_msg(0, "not implemented");
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
data Command;
    data Command.Nothing;
    data Command.Await with
        var int ms;
    end
    data Command.Sequence with
        var Command  one;
        var Command  two;
    end
    data Command.Repeat with
        var int      times;
        var Command  command;
    end

pool[] Command cmds;

cmds = new Repeat(2,
            Command.Sequence(
                Await(100),
                Command.Sequence(
                    Await(100),
                    Await(500))));

var int ret = 0;

traverse cmd in &&cmds do
    watching *cmd do
        if (*cmd is Await) then
            await ((*cmd as Await).ms) ms;
            ret = ret + 1;

        else/if (*cmd is Command.Sequence) then
            ret = ret + 2;
            traverse &&(*cmd as Command.Sequence).one;
            traverse &&(*cmd as Command.Sequence).two;

        else/if (*cmd is Repeat) then
            loop i in [0->(*cmd as Repeat).times[ do
                ret = ret + 3;
                traverse &&(*cmd as Repeat).command;
            end

        else
native _ceu_callback_assert_msg;
            _ceu_callback_assert_msg(0, "not implemented");
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
native/nohold _free;
var& void? ptr;
    do ptr = &_malloc(10000);
finalize with
    _free(&&ptr!);
end

data Command;
    data Command.Nothing;
    data Command.Await with
        var int ms;
    end
    data Command.Sequence with
        var Command  one;
        var Command  two;
    end
    data Command.Repeat with
        var int      times;
        var Command  command;
    end

// TODO: aceitar estatico
pool[] Command cmds = new Repeat(2,
            Command.Sequence(
                Await(100),
                Command.Sequence(
                    Await(300),
                    Await(500))));

var int ret = 0;

traverse cmd in &&cmds do
    watching *cmd do
        if (*cmd is Await) then
            await ((*cmd as Await).ms) ms;
            ret = ret + 1;

        else/if (*cmd is Command.Sequence) then
            ret = ret + 2;
            traverse &&(*cmd as Command.Sequence).one;
            traverse &&(*cmd as Command.Sequence).two;

        else/if (*cmd is Repeat) then
            loop i in [0->(*cmd as Repeat).times[ do
                ret = ret + 3;
                traverse &&(*cmd as Repeat).command;
            end

        else
native _ceu_callback_assert_msg;
            _ceu_callback_assert_msg(0, "not implemented");
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
data List;
    data List.Nil;
    data List.Cons with
        var List tail;
    end

pool[] List ls;
ls = new List.Cons(List.Nil());

traverse l in &&ls do
    if (*l is List.Nil) then
        await FOREVER;
    else
        watching *l do
            par/or do
                traverse &&((l as List.Cons).tail);
            with
                await 1s;
            end
        end
    end
end

escape 1;
]],
    wrn = 'line 23 : unbounded recursive spawn',
    run = { ['~>5s']=1 },
}
Test { [[
data List;
    data List.Nil;
    data List.Hold;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[] List ls;
ls = new List.Cons(1,
            List.Cons(2,
                Hold()));

var int ret = 0;

traverse l in &&ls do
    ret = ret + 1;
    watching *l do
        if (*l is Hold) then
            do finalize with
                ret = ret + 1;
            end
            await FOREVER;
        else
            par/or do
                traverse &&((l as List.Cons).tail);
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
data List;
    data List.Nil;
    data List.Hold;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[] List ls;
ls = new List.Cons(1,
            List.Cons(2,
                Hold()));

var int ret = 0;

do
    traverse l in &&ls do
        ret = ret + 1;
        watching *l do
            if (*l is Hold) then
                do finalize with
                    ret = ret + 1;
                end
                await FOREVER;
            else
                par/or do
                    traverse &&((l as List.Cons).tail);
                with
                    await 1s;
                end
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
data List;
    data List.Nil;
    data List.Hold;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[10] List ls = new List.Cons(1,
            List.Cons(2,
                Hold()));

var int ret = 0;

traverse l in &&ls do
    ret = ret + 1;
    watching *l do
        if *l is Hold then
            do finalize with
                ret = ret + 1;
            end
            await FOREVER;
        else
            par/or do
                traverse &&((l as List.Cons).tail);
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
data List;
    data List.Nil;
    data List.Hold;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[10] List ls = new List.Cons(1,
            List.Cons(2,
                Hold()));

var int ret = 0;

do
    traverse l in &&ls do
        ret = ret + 1;
        watching *l do
            if *l is Hold then
                do finalize with
                    ret = ret + 1;
                end
                await FOREVER;
            else
                par/or do
                    traverse &&((l as List.Cons).tail);
                with
                    await 1s;
                end
            end
        end
    end
end

escape ret;
]],
    run = { ['~>5s']=4 },
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[10] List list;

var int i = 10;
traverse l in &&list do
    list = new List.Cons(i, List.Nil());
end

escape 1;
]],
    run = 1,
}
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[10] List list;

loop i in [0 -> 10[ do
    traverse l in &&list do
        if (*l is List.Nil) then
            list = new List.Cons(i, List.Nil());
        else/if (*l as List.Cons) then
            if ((l as List.Cons).tail) is List.Nil then
                ((l as List.Cons).tail) = new List.Cons(i, List.Nil());
            else
                traverse &&((l as List.Cons).tail);
            end
        end
    end
end

var int sum = 0;

traverse l in &&list do
    if (*l as List.Cons) then
        sum = sum + ((l as List.Cons).head);
        traverse &&((l as List.Cons).tail);
    end
end

escape sum;
]],
    run = 45,
}

-- innefective Nil inside watching
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

native/pos do
    int V = 0;
end

class Body with
    pool&[]  Body bodies;
    var   List&&   n;
do
    watching *n do
        if (*n is List.Nil) then
native _V;
            _V = _V * 2;
        else/if (*n is List.Cons) then
            _V = _V + 1;
            _V = _V + (*n is List.Cons).head;

            var Body&&? tail =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = &&(*n is List.Cons).tail;
                end;
            if tail? then
                await *tail!;
            end
        end
    end
end

pool[3] Body bodies;
do Body with
    this.bodies = bodies;
    this.n      = &&list;
end;

escape _V;
]],
    adt = 'line 24 : ineffective use of data "Nil" due to enclosing `watching´',
}
Test { [[
data List;
    data Nil_;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[4] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

native/pos do
    int V = 0;
end

class Body with
    pool&[]  Body bodies;
    var   List&&   n;
do
    watching *n do
        if (*n is List.Nil) then
native _V;
            _V = _V * 2;
        else/if (*n is List.Cons) then
            _V = _V + 1;
            _V = _V + (*n is List.Cons).head;

            var Body&&? tail =
                spawn Body in this.bodies with
                    this.bodies = &bodies;
                    this.n      = &&(*n is List.Cons).tail;
                end;
            if tail? then
                await *tail!;
            end
        end
    end
end

pool[4] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&list;
end;

escape _V;
]],
    wrn = 'line 42 : unbounded recursive spawn',
    _ana = { acc=true },
    run = 18,
}
-- innefective Nil inside watching
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

native/pos do
    int V = 0;
end

traverse n in &&list do
native _V;
    _V = _V + 1;
    watching *n do
        if (*n is List.Nil) then
            _V = _V * 2;
        else/if (*n is List.Cons) then
            _V = _V + (*n is List.Cons).head;
            traverse &&(*n is List.Cons).tail;
        end
    end
    await 1s;
end

escape _V;
]],
    adt = 'line 22 : ineffective use of data "Nil" due to enclosing `watching´',
}

Test { [[
data List;
    data List.Nil_;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[4] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

native/pos do
    int V = 0;
end

traverse n in &&list do
native _V;
    _V = _V + 1;
    watching *n do
        if (*n is List.Nil) then
            _V = _V * 2;
        else/if (*n is List.Cons) then
            _V = _V + (*n is List.Cons).head;
            traverse &&(*n is List.Cons).tail;
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
data List;
    data List.Nil;
    data List.Val with
        var List  l;
    end

pool[] List ls;

var int v = 10;
var int&& p = &&v;

traverse l in &&ls do
    await 1s;
    *p = 1;
    if *l is Val then
        traverse &&(*l as Val).l;
    end
end

escape v;
]],
    fin = 'line 16 : unsafe access to pointer "p" across `await´',
}

Test { [[
class A with
    var int v = 10;
    var int&& p;
do
    this.p = &&v;
end

class B with
    var& A a;
do
    escape *(a.p);
end

escape 1;
]],
    fin = 'line 11 : unsafe access to pointer "p" across `class´ (/tmp/tmp.ceu : 8)',
    --run = 1,
}

Test { [[
class A with
    var int v = 10;
    var int&& p;
do
    this.p = &&v;
end

class B with
    var& A a;
do
    await 1s;
    escape *(a.p);
end

escape 1;
]],
    fin = 'line 12 : unsafe access to pointer "p" across `class´',
}

Test { [[
data Stmt;
    data Stmt.Nil;
    data Stmt.Seq with
        var Stmt s1;
    end

pool[2] Stmt stmts = new Stmt.Nil();

var int ddd = do/_
    traverse stmt in &&stmts do
        escape 10;
end
    end;

escape ddd;
]],
    wrn = true,
    run = 10,
}

Test { [[
data Stmt;
    data Stmt.Nil;
    data Stmt.Seq with
        var Stmt s1;
    end

pool[] Stmt stmts = new Stmt.Nil();

var int v1 = 10;

var int ret = do/_
    traverse stmt in &&stmts with
        var int v2 = v1;
    do
        escape v1+v2;
end
    end;

escape ret;
]],
    wrn = true,
    run = 20,
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list = new
    List.Cons(1,
        List.Cons(2,
            List.Cons(3,
                List.Nil())));

var int s1 = do/_
    traverse l in &&list do
        if (*l is List.Nil) then
            escape 0;
        else
            watching *l do
                var int sum_tail = traverse &&((l as List.Cons).tail);
                escape sum_tail + ((l as List.Cons).head);
            end
        end
end
    end;

escape s1;
]],
    run = 6,
}

Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list = new
    List.Cons(1,
        List.Cons(2,
            List.Cons(3,
                List.Nil())));

var int s2 = 0;
var int s1 = do/_
    traverse l in &&list do
        if (*l is List.Nil) then
            escape 0;
        else
            watching *l do
                var int sum_tail = traverse &&((l as List.Cons).tail);
                s2 = s2 + ((l as List.Cons).head);
                escape sum_tail + ((l as List.Cons).head);
            end
        end
end
    end;

escape s1 + s2;
]],
    run = 12,
}

Test { [[
data Tx with
    data List.Nil;
or
    data Command.Next with
        var Tx  next;
    end
end

class C with
    var int v;
do
    pool[] Tx ts; // = new Tx.Next(Tx.Nil());
    var int ret = do/_
        traverse t in ts do
            escape this.v;
end
        end;
    escape ret;
end

var int v =
    do C with
        this.v = 10;
    end;

escape v;
]],
    todo = true,
    run = 10,
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Await with
        var int ms;
    end
    data Command.Stream_Root with
        var Command  run;
        var Command  now;
        var Command  nxt;
    end
    data Command.Stream_Next with
        var Command  one;
        var Command  two;
    end
    data Stream_End;

pool[100] Command cmds = new
    Stream_Root(
        Await(1000),
        Stream_End(),
        Stream_End());

                (cmds as Stream_Root).nxt = new Stream_End();

    traverse cmd in &&cmds do
        watching *cmd do
            if (*cmd is Await) then
                await ((*cmd as Await).ms) ms;

            else/if (*cmd is Stream_Root) then
                (cmds as Stream_Root).nxt = new Stream_End();
            end
        end
    end

escape 1;
]],
    _ana = {acc=true},
    run = 1,
}

Test { [[
native/plain _SDL_Renderer;
native/nohold _f;
class Turtle with
    var& _SDL_Renderer ren;
do
    every 1s do
        _f(&&ren);
    end
end
escape 1;
]],
    cc = '5: error: implicit declaration of function ‘f’',
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Stream_Root with
        var Command  run;
        var Command  now;
        var Command  nxt;
    end
    data Command.Stream_Next with
        var Command  one;
        var Command  two;
    end
    data Stream_End;

pool[] Command cmds;
((cmds as Stream_Root).now as Stream_Next).one = (cmds as Stream_Root).nxt;
(cmds as Stream_Root).run = ((cmds as Stream_Root).nxt as Stream_Next).two;
traverse cmd in &&cmds do
    ((*cmd as Stream_Root).now as Stream_Next).one = (*cmd as Stream_Root).nxt;
    (*cmd as Stream_Root).run = ((*cmd as Stream_Root).nxt as Stream_Next).two;
    ((cmds as Stream_Root).now as Stream_Next).one = (cmds as Stream_Root).nxt;
    (cmds as Stream_Root).run = ((cmds as Stream_Root).nxt as Stream_Next).two;
end
((cmds as Stream_Root).now as Stream_Next).one = (cmds as Stream_Root).now;
escape 1;
]],
    adt = 'line 27 : cannot assign parent to child',
}

Test { [[
data Val with
    var int v;
end

data Exp;
    data Exp.Nil;
    data Exp.Val with
        var Val v;
    end
    data Exp.Add with
        var Exp e1;
        var Exp e2;
    end

data Stmt;
    data Stmt.Nil;
    data Stmt.Seq with
        var Stmt s1;
        var Stmt s2;
    end
    data Stmt.Print with
        var Exp e;
    end

pool[] Stmt stmts =
    new Seq(
            Print(
                Add(
                    Val(Val(10)),
                    Val(Val(5)))),
            Exp.Nil());

traverse stmt in stmts do
    if *stmt is Seq then
        traverse &&(*stmt as Seq).s1;
    else/if *stmt is Print then
        var int v = traverse &&(*stmt as Print).e;
    end
end

escape 1;
]],
    adt = 'line 43 : invalid attribution : reference : types mismatch (`Stmt´ <= `Exp´)',
}

-- par/or kills (2) which should be aborted
Test { [[
data Exp;
    data Exp.Nil;
    data Exp.Vv with
        var int e;
    end
    data Exp.Add with
        var Exp e1;
        var Exp e2;
    end

var int ret = 0;

pool[] Exp exps = new
    Add(Exp.Nil(), Vv(20));

traverse e in &&exps do
    watching *e do
        if *e is Add then
            ret = ret + 1;
            par/or do
                traverse &&(*e as Add).e2;
            with
                traverse &&(*e as Add).e1;
            end
            await 5s;
        else/if *e is Vv then
            every 1s do
                ret = ret + (*e as Vv).e;
            end
        end
    end
end

escape ret;
]],
    _ana = {acc=true},
    wrn = true,
    run = { ['~>10s'] = 1 },
}

Test { [[
data Exp;
    data Exp.Nil;
    data Exp.Sub with
        var Exp e2;
    end

data Stmt;
    data Stmt.Nil;
    data Stmt.Seq with
        var Stmt s1;
        var Exp e;
    end

    pool[] Stmt stmts;
    traverse stmt in &&stmts do
        watching *stmt do
        end
    end
escape 1;
]],
    _ana = {acc=true},
    wrn = true,
    run = 1,
}

-- << DATA / RECURSE / TRAVERSE

-->> TRAVERSE / NUMERIC

Test { [[
var int tot = 4;
var int ret = do/_
    traverse idx in [] do
        if idx == tot then
            escape idx;
        else
            var int ret = traverse idx+1;
            escape idx + ret;
        end
end
    end;

escape ret;
]],
    wrn = true,
    run = 10,
}

Test { [[
var int tot = 4;
var int ret = do/_
    traverse idx in [3] do
        if idx == tot then
            escape idx;
        else
            var int ret = traverse idx+1;
            escape idx + ret;
        end
end
    end;

escape ret;
]],
    run = 3,
}

Test { [[
loop v in [0 -> 10[ do
    traverse 1;
end
]],
    adj = 'line 2 : missing enclosing `traverse´ block',
}

Test { [[
traverse v in [10] do
    traverse 1;
end
escape 1;
]],
    run = 1,
}

--<< TRAVERSE / NUMERIC

-->> TRAVERSE / NESTED-RECURSIVE-DATA
Test { [[
data List;
    data List.Nil;
    data List.Cons with
        var int   head;
        var List  tail;
    end

pool[3] List list;
list = new List.Cons(1,
            List.Cons(2,
                List.Cons(3, List.Nil())));

var int sum = 0;

pool[] List&& lll = &&(list as List.Cons).tail;

traverse n in lll do
    sum = sum + 1;
    if (*n is List.Cons) then
        sum = sum + (*n is List.Cons).head;
        traverse &&(*n is List.Cons).tail;
    end
end

escape sum;
]],
    wrn = true,
    run = 8,
}

Test { [[
data Xx;
    data Xx.Nil;
    data Xx.Nil;

escape 1;
]],
    dcls = 'line 3 : declaration of "Xx.Nil" hides previous declaration (/tmp/tmp.ceu : line 2)',
    --dcls = 'line 3 : identifier "Nil" is already declared (/tmp/tmp.ceu : line 2)',
    --env = 'line 4 : duplicated data : "Nil"',
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Sequence with
        var Command  one;
        var Command  two;
    end

data CommandQueue;
    data CommandQueue.Nothing;
    data Nxt with
        var Command       cmd;
        var CommandQueue  nxt;
    end

escape 1;
]],
    wrn = true,
    --run = 1,
    --env = 'line 13 : duplicated data : "Nothing"',
    --dcls = 'line 9 : declaration of "Command.Nothing" hides previous declaration (/tmp/tmp.ceu : line 2)',
    --dcls = 'line 9 : identifier "Nothing" is already declared (/tmp/tmp.ceu : line 2)',
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Sequence with
        var Command  one;
        var Command  two;
    end

data CommandQueue;
    data CommandQueue.Nil;
    data Nxt with
        var Command       cmd;
        var CommandQueue  nxt;
    end

pool[10] CommandQueue cq1 = new Command.Nothing();
pool[10] CommandQueue cq2 = new CommandQueue.Nil();

pool[10] CommandQueue cq3 = new
    Nxt(
        Command.Sequence(
            Command.Nothing(),
            Command.Nothing()),
        CommandQueue.Nil());

escape 1;
]],
    run = 1,
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Sequence with
        var Command  one;
        var Command  two;
    end

data CommandQueue;
    data CommandQueue.Nil;
    data Nxt with
        var Command       cmd;
        var CommandQueue  nxt;
    end

pool[10] CommandQueue cq1 = new CommandQueue.Nil();

pool[10] CommandQueue cq2 = new
    Nxt(
        Command.Sequence(
            Command.Nothing(),
            Command.Nothing()),
        CommandQueue.Nil());

escape ((cq1 is CommandQueue.Nil)as int) + ((((cq2 as Nxt).cmd as Command.Sequence).one is Command.Nothing)as int);
]],
    run = 2,
}
--<< TRAVERSE / NESTED-RECURSIVE-DATA

-- DATA ALIASING

Test { [[
data List;
    data List.Nil;
    data Xx with
        var List  nxt;
    end
pool[] List lll;     // l is the pool
escape (lll is List.Nil) as int;       // l is a pointer to the root
]],
    wrn = true,
    run = 1,
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[] Command cmds1;
pool&[] Command cmds2;
escape 1;
]],
    wrn = true,
    --ref = 'line 10 : uninitialized variable "cmds2" crossing compound statement (/tmp/tmp.ceu:1)',
    inits = 'line 8 : uninitialized pool "cmds2" : reached `escape´ (/tmp/tmp.ceu:9)',
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[] Command cmds1;
pool&[] Command cmds2=&cmds1;
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[] Command cmds1;
pool&[] Command cmds2;
cmds2 = &cmds1;
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[] Command cmds1;
cmds1 = new Command.Next(
            Command.Next(
                Command.Nothing()));

pool&[] Command cmds2 = &cmds1;

escape ((((cmds2 as Command.Next).nxt as Command.Next).nxt is Command.Nothing)) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool&[] Command cmds2
    = &new Command.Next(
            Command.Next(
                Command.Nothing()));

escape 1;
]],
    parser = 'line 8 : after `&´ : expected `call/recursive´ or `call´ or name expression',
    --parser = 'line 10 : after `new´ : expected `;´'
    --ref = 'line 9 : invalid attribution (not a reference)',
    --ref = 'line 10 : reference must be bounded before use',
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[2] Command cmds1;
pool&[2] Command cmds2
        = &cmds1;

cmds1 = new Command.Next(
            Command.Next(
                Command.Nothing()));
cmds1 = new Command.Nothing();
cmds2 = new Command.Next(
            Command.Next(
                Command.Nothing()));
escape (cmds1 is Command.Next) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[2] Command cmds1;
pool&[2] Command cmds2
        = &cmds1;

cmds1 = new Command.Next(
            Command.Next(
                Command.Nothing()));
cmds2 = new Command.Next(
            Command.Next(
                Command.Nothing()));
escape (cmds1 is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[2] Command cmds1;

cmds1 = new Command.Next(
                Command.Next(
                    Command.Next(
                        Command.Nothing())));
escape (((cmds1 as Command.Next).nxt as Command.Next).nxt is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[2] Command cmds1;

cmds1 = new Command.Next(Command.Nothing());
(cmds1 as Command.Next).nxt = new Command.Next(Command.Nothing());
((cmds1 as Command.Next).nxt as Command.Next).nxt = new Command.Next(Command.Nothing());
escape (((cmds1 as Command.Next).nxt as Command.Next).nxt is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[1] Command cmds1;

cmds1 = new Command.Next(Command.Nothing());
cmds1 = new Command.Nothing();
cmds1 = new Command.Next(Command.Nothing());
escape ((cmds1 as Command.Next).nxt is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[1] Command cmds1;

cmds1 = new Command.Next(Command.Nothing());
cmds1 = new Command.Next(Command.Nothing());
escape (cmds1 is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[2] Command cmds1 = new Command.Next(Command.Nothing());
cmds1 = new Command.Nothing();
cmds1 = new Command.Next(
                Command.Next(
                    Command.Nothing()));
escape (((cmds1 as Command.Next).nxt as Command.Next).nxt is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[2] Command cmds1 = new Command.Next(Command.Nothing());
cmds1 = new Command.Next(
                Command.Next(
                    Command.Nothing()));
escape( (cmds1 as Command.Next).nxt is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[2] Command cmds1;
pool&[2] Command cmds2 = &cmds1;

cmds1 = new Command.Next(Command.Nothing());
(cmds2 as Command.Next).nxt = new Command.Next(Command.Nothing());
escape (((cmds1 as Command.Next).nxt as Command.Next).nxt is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[2] Command cmds1;
pool&[2] Command cmds2 = &cmds1;

cmds1 = new Command.Next(Command.Nothing());
(cmds2 as Command.Next).nxt = new Command.Next(
                        Command.Next(
                            Command.Nothing()));
escape (((cmds1 as Command.Next).nxt as Command.Next).nxt is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[3] Command cmds1;
pool&[3] Command cmds2;
cmds2 = &cmds1;

cmds1 = new Command.Next(
            Command.Next(
                Command.Nothing()));
((cmds2 as Command.Next).nxt as Command.Next).nxt = new Command.Next(
                            Command.Next(
                                Command.Nothing()));
escape ((((cmds1 as Command.Next).nxt as Command.Next).nxt as Command.Next).nxt is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[10] Command cmds1;

pool&[10] Command cmds2;
cmds2 = &cmds1;

cmds1 = new Command.Next(
            Command.Next(
                Command.Nothing()));
cmds2 = new Command.Next(
            Command.Next(
                Command.Nothing()));

escape (((cmds1 as Command.Next).nxt as Command.Next).nxt is Command.Nothing) as int;
]],
    run = 1,
}
Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[] Command cmds1;

pool&[] Command cmds2 = &cmds1;

cmds1 = new Command.Next(
            Command.Next(
                Command.Nothing()));
cmds2 = new Command.Next(
            Command.Next(
                Command.Nothing()));

escape (((cmds1 as Command.Next).nxt as Command.Next).nxt is Command.Nothing) as int;
]],
    run = 1,
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

pool[] Command cmds1;

pool&[] Command cmds2;
cmds2 = &cmds1;

cmds1 = new Command.Next(
            Command.Next(
                Command.Nothing()));
cmds2 = new Command.Next(
            Command.Next(
                Command.Nothing()));

var int sum = 0;

traverse cmd in &&cmds1 do
    if (*cmd is Command.Next) then
        sum = sum + 1;
        traverse &&(*cmd as Command.Next).nxt;
    end
end
traverse cmd in &&cmds2 do
    if (*cmd is Command.Next) then
        sum = sum + 1;
        traverse &&(*cmd as Command.Next).nxt;
    end
end

escape sum;
]],
    wrn = true,
    run = 4,
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

class Run with
    pool&[] Command cmds1;
do
    cmds1 = new Command.Next(
                Command.Next(
                    Command.Nothing()));
    var int sum = 0;
    traverse cmd111 in &&cmds1 do
        if *cmd111 is Command.Next then
            sum = sum + 1;
            traverse &&(*cmd111 as Command.Next).nxt;
        end
    end
    escape sum;
end

pool[] Command cmds;

traverse cmd222 in &&cmds do
end

var int ddd = do Run with
    this.cmds1 = &cmds;
end;

escape ddd;
]],
    wrn = true,
    run = 2,
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

    pool[] Command cmds;
    traverse cmd in &&cmds do
    end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Next with
        var Command  nxt;
    end

class Run with
    pool&[] Command cmds;
do
    var int sum = 0;
    traverse cmd in &&cmds do
        if (*cmd is Command.Next) then
            sum = sum + 1;
            traverse &&(*cmd as Command.Next).nxt;
        end
    end
    escape sum;
end

pool[] Command cmds = new Command.Next(
            Command.Next(
                Command.Nothing()));

var int ret = do Run with
    this.cmds = &cmds;
end;

escape ret;
]],
    wrn = true,
    run = 2,
}

Test { [[
data Command;
    data Command.Nothing;
    data Command.Await;
    data Command.ParOr with
        var Command  one;
    end

pool[] Command cmds;

cmds = new ParOr(
            ParOr(
                Await()));

class Run with
    pool&[] Command cmds;
do
    traverse cmd in &&cmds do
        if (*cmd is Await) then
            await 1ms;

        else/if (*cmd is ParOr) then
            par/or do
                traverse &&(*cmd as ParOr).one;
            with
            end
        end
    end
end

var Run r with
    this.cmds   = &cmds;
end;

escape 1;
]],
    wrn = true,
    run = { ['~>10s']=1 },
}

Test { [[
data Dummy;
  data Dummy.Nil;
  data Dummy.Rec with
    var Dummy  rec;
  end

native/pos do
    byte vec[3] = {5,5,5};
end

pool[] Dummy ds;

var int xxx = 0;

input void OS_START;

traverse d in &&ds with
    var int idx = 0;
do
    if idx < 3 then
        par/and do
            await OS_START;
            _vec[xxx] = idx;
            xxx = xxx + 1;
        with
            traverse d with
                this.idx = idx + 1;
            end;
        end
    end
end

escape (_vec[0]==0) + (_vec[1]==1) + (_vec[2]==2);
]],
    wrn = true,
    run = 3,
}

Test { [[
data NoRec;
    data NoRec.Nil;
    data NoRec.Seq with
        var int x;
    end

pool&[] NoRec norec;

traverse t in this.norec do
end

escape 1;
]],
    tmp = 'line 8 : invalid pool : non-recursive data',
}

Test { [[
data BTree;
    data BTree.Nil;
    data BTree.Seq with
        var BTree  nxt;
    end

class BTreeTraverse with
    pool&[3] BTree btree;
    var int x;
do
    var int a = this.x;
    pool&[3] BTree btree2 = &this.btree;
    traverse t in &&this.btree do
        var int a = this.x;
        if a!=0 then end;
    end
    escape 1;
end

escape 1;
]],
    run = 1,
}

Test { [[
data BTree;
    data BTree.Nil;
    data BTree.Seq with
        var BTree  nxt;
    end

pool[3] BTree bs = new Seq(Seq(BTree.Nil()));

class BTreeTraverse with
    pool&[3] BTree btree;
do
    var int ret = 0;
    traverse t in &&this.btree do
        if t is Seq then
            ret = ret + 1;
            traverse &&(*t as Seq).nxt;
        end
    end
    escape ret;
end

var int ret = do BTreeTraverse with
                    this.btree = &bs;
              end;

escape ret;
]],
    run = 2,
}

--[=[

Test { [[
data List;
    data Nil;
with
    data List.Cons with
        var int  head;
        var List tail;
    end
end
var List l = List.Cons(1, List.Cons(2, List.Cons(3, Nil())));

var int sum = 0;

loop/1 i in &&l do
    if i:Cons then
        sum = sum + i:Cons.head;
        traverse &&i:Cons.tail;
    end
end

escape sum;
]],
    asr = 'runtime error: loop overflow',
}

Test { [[
data List;
    data Nil;
with
    data List.Cons with
        var int  head;
        var List tail;
    end
end
var List l = List.Cons(1, List.Cons(2, List.Cons(3, Nil())));

var int sum = 0;

loop/3 i in &&l do
    if i:Cons then
        sum = sum + i:Cons.head;
        traverse &&i:Cons.tail;
    end
end

escape sum;
]],
    run = 6,
}

Test { [[
data List;
    data Nil;
with
    data List.Cons with
        var int  head;
        var List tail;
    end
end
var List l = List.Cons(1, List.Cons(2, List.Cons(3, Nil())));

var int sum = 0;

loop i in &&l do
    if i:Cons then
        sum = sum + i:Cons.head;
        traverse &&i:Cons.tail;
    end
end

escape sum;
]],
    run = 6,
}

Test { [[
data Tree;
    data Nil;
with
    data Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end
end

var Tree t =
    Node(1,
        Node(2, Nil(), Nil()),
        Node(3, Nil(), Nil()));

var int sum = 0;

    finalize with end;

loop i in &&t do
    if (*i is Node) then
        traverse &&(*i as Node).left;
        sum = sum + (*i as Node).v;
        traverse &&(*i as Node).right;
    end
end

escape sum;
]],
    run = 6,
}

Test { [[
data List;
    data Nil;
with
    data List.Cons with
        var int  head;
        var List tail;
    end
end

pool[3] List l;
l = new List.Cons(1, List.Cons(2, List.Cons(3, Nil())));

var int sum = 0;

loop i in l do
    if i:Cons then
        sum = sum + i:Cons.head;
        traverse &&i:Cons.tail;
    end
end

escape sum;
]],
    run = 6,
}

Test { [[
data Tree;
    data Nil;
with
    data Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end
end

pool[3] Tree t;
t = new Node(1,
            Node(2, Nil(), Nil()),
            Node(3, Nil(), Nil()));

var int sum = 0;

loop i in t do
    if (*i is Node) then
        traverse &&(*i as Node).left;
        sum = sum + (*i as Node).v;
        traverse &&(*i as Node).right;
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
data Opt  = Nil(void) | Ptr(void*);
data List = Nil  (void)
           | Cons (int, List&);
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
    data Nil;
with
    data Ptr with
        var void* v = null;
    end
end

data List;
    data Nil;
with
    data List.Cons with
        var int   head = 0;
        var& List tail = List.nil();
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
var Opt  o1 = Opt.Nil();
var Opt  o2 = Opt.Ptr(v=&p1);
var List l1 = Nil();
var List l2 = List.Cons(head=1, tail=l1);
var List l3 = List.Cons(head=1, (tail as List.Cons).head)=2, tail=Nil()));

escape 1;
]],
    todo = 'implement?',
    run = 1,
}

-- anonymous destructors / pattern matching
Test { DATA..[[
var Pair p1 = Pair(1,2);
var Opt  o1 = Opt.Nil();
var Opt  o2 = Opt.Ptr(&p1);
var List l1 = Nil();
var List l2 = List.Cons(1, l1);
var List l3 = List.Cons(1, List.Cons(2, Nil()));

var int ret = 0;

var int x, y;
(x,y) = p;
_assert(x+y == 3);
ret = ret + 3;              // 3

switch o1 with
    case Opt.Nil() do
        ret = ret + 1;      // 4
        _assert(1);
    end
    case Opt.Ptr(void* v) do
        _assert(0);
    end
end

switch o2 with
    case Opt.Nil() do
        _assert(0);
    end
    case Opt.Ptr(void* v) do
        ret = ret + 1;      // 5
        _assert(v==&p1);
    end
end

switch l1 with
    case Nil() do
        ret = ret + 1;      // 6
        _assert(1);
    end
    case List.Cons(int head, List& tail) do
        _assert(0);
    end
end

switch l2 with
    case Nil() do
        _assert(0);
    end
    case List.Cons(int head1, List& tail1) do
        _assert(head1 == 1);
        ret = ret + 1;      // 7
        switch *tail1 with
            case Nil() do
                ret = ret + 1;      // 8
                _assert(1);
            end
            case List.Cons(int head2, List& tail2) do
                _assert(0);
            end
        end
        ret = ret + 1;      // 9
        _assert(1);
    end
end

switch l3 with
    case Nil() do
        _assert(0);
    end
    case List.Cons(int head1, List& tail1) do
        _assert(head1 == 1);
        ret = ret + 1;      // 10
        switch *tail1 with
            case Nil() do
                _assert(0);
            end
            case List.Cons(int head2, List& tail2) do
                _assert(head2 == 2);
                ret = ret + 2;      // 12
                switch *tail2 with
                    case Nil() do
                        _assert(1);
                        ret = ret + 1;      // 13
                    end
                    case List.Cons(int head3, List& tail3) do
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


-->>> TIMEMACHINE

Test { [[
native/pos do
    int CEU_TIMEMACHINE_ON = 0;
end

code/await TM_App (void) -> (var int v) -> FOREVER do
do
    v = 0;
    every 1s do
        v = v + 1;
    end
end

var& TM_App tm_app = spawn TM_App();

input int DT;

#define TM_QUEUE

#define TM_INPUT_DT     DT
#define TM_QUEUE_N      1000000
#if defined(TM_QUEUE) || defined(TM_DIFF)
#define TM_SNAP_MS      2000
#endif
#define TM_SNAP_N       1000
#define TM_DIFF_N       1000000

native/pre do
    ##define CEU_FPS 20
end

#include "tm/backend.ceu"

#if 0
#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
end
var IOTimeMachine io;
#endif
#endif

var& TimeMachine tm = spawn TimeMachine(&tm_app
#if 0
#ifdef TM_QUEUE
                                        , &io
#endif
#endif
                                       );

par/or do
    await 3s/_;
    emit tm.go_on;
    await 1s/_;

    ///////////////////////////////

    emit tm.go_seek(tm.time_total);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_seek(500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_seek(1000);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);

    emit tm.go_seek(1500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);

    emit tm.go_seek(2000);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);

    emit tm.go_seek(2500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);

    emit tm.go_seek(3000);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_seek(2500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);

    emit tm.go_seek(2000);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);

    emit tm.go_seek(1500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);

    emit tm.go_seek(1000);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);

    emit tm.go_seek(500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    escape 1;

with
    input int DT;
    async (tm) do
        loop do
            if not _CEU_TIMEMACHINE_ON then
                emit 50ms;
                emit DT(50);
            end

            // TODO: forces this async to be slower
            input void SLOW;
            loop do
                if not tm.locked then
                    break;
                end
                emit SLOW;
            end
            emit 50ms/_;
        end
    end
end

escape tm_app.v;
]],
    opts_pre = true,
    timemachine = true,
    _ana = {
        acc = true,
    },
    run = 1,
}

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
native/pos do
    int CEU_TIMEMACHINE_ON = 0;
end

code/await TM_App (void) -> (var int v) -> FOREVER do
do
    v = 0;
    every 1s do
        v = v + 1;
    end
end

var& TM_App tm_app = spawn TM_App();

input int DT;

]]..defs..[[

#define TM_INPUT_DT     DT
#define TM_QUEUE_N      1000000
#if defined(TM_QUEUE) || defined(TM_DIFF)
#define TM_SNAP_MS      2000
#endif
#define TM_SNAP_N       1000
#define TM_DIFF_N       1000000

native/pre do
    ##define CEU_FPS 20
end

#include "tm/backend.ceu"

#if 0
#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
end
var IOTimeMachine io;
#endif
#endif

var& TimeMachine tm = spawn TimeMachine(&tm_app
#if 0
#ifdef TM_QUEUE
                                        , &io
#endif
#endif
                                       );

par/or do
    await 3s/_;
    emit tm.go_on;
    await 1s/_;

    ///////////////////////////////

    emit tm.go_seek(tm.time_total);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_seek(500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_seek(1000);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);

    emit tm.go_seek(1500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);

    emit tm.go_seek(2000);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);

    emit tm.go_seek(2500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);

    emit tm.go_seek(3000);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_seek(2500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);

    emit tm.go_seek(2000);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);

    emit tm.go_seek(1500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);

    emit tm.go_seek(1000);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);

    emit tm.go_seek(500);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    escape 1;

with
    input int DT;
    async (tm) do
        loop do
            if not _CEU_TIMEMACHINE_ON then
                emit 50ms;
                emit DT(50);
            end

            // TODO: forces this async to be slower
            input void SLOW;
            loop do
                if not tm.locked then
                    break;
                end
                emit SLOW;
            end
            emit 50ms/_;
        end
    end
end

escape tm_app.v;
]],
    timemachine = true,
    complete = (i>1),   -- runs i=1 for sure
    _ana = {
        acc = true,
    },
    run = 1,
}

-- Forward
Test { [[
native/pos do
    int CEU_TIMEMACHINE_ON = 0;
end

class TM_App with
    var int v = 0;
do
    every 1s do
        this.v = this.v + 1;
    end
end
var TM_App tm_app;

input int DT;

]]..defs..[[

#define TM_INPUT_DT     DT
#define TM_QUEUE_N      1000000
#if defined(TM_QUEUE) || defined(TM_DIFF)
#define TM_SNAP_MS      2000
#endif
#define TM_SNAP_N       1000
#define TM_DIFF_N       1000000

native/pre do
    ##define CEU_FPS 20
end

#include "tm/backend.ceu"

#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
end
var IOTimeMachine io;
#endif

var TimeMachine tm with
    this.app = &tm_app;
#ifdef TM_QUEUE
    this.io  = &io;
#endif
end;

par/or do
    await 3s/_;
    emit tm.go_on;
    await 1s/_;

    ///////////////////////////////

    emit tm.go_seek(tm.time_total);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    ///////////////////////////////

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_forward(1);
    _assert(tm_app.v == 0);

    await 1ms/_;
    await 1000ms/_;
    _assert(tm_app.v == 1);
    await 1000ms/_;
    _assert(tm_app.v == 2);
    await 1000ms/_;
    _assert(tm_app.v == 3);

    ///////////////////////////////

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_forward(1);
    _assert(tm_app.v == 0);

    await 1ms/_;
    loop i in [0 -> 20[ do
        await 50ms/_;
    end
    _assert(tm_app.v == 1);
    loop i in [0 -> 20[ do
        await 50ms/_;
    end
    _assert(tm_app.v == 2);
    loop i in [0 -> 20[ do
        await 50ms/_;
    end
    _assert(tm_app.v == 3);

    ///////////////////////////////

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_forward(2);
    _assert(tm_app.v == 0);

    await 1ms/_;
    loop i in [0 -> 10[ do
        await 50ms/_;
    end
    _assert(tm_app.v == 1);
    loop i in [0 -> 10[ do
        await 50ms/_;
    end
    _assert(tm_app.v == 2);
    loop i in [0 -> 10[ do
        await 50ms/_;
    end
    _assert(tm_app.v == 3);

    ///////////////////////////////

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_forward(5);
    _assert(tm_app.v == 0);

    await 1ms/_;
    await 200ms/_;
    _assert(tm_app.v == 1);
    await 200ms/_;
    _assert(tm_app.v == 2);
    await 200ms/_;
    _assert(tm_app.v == 3);

    ///////////////////////////////

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_forward(-2);
    _assert(tm_app.v == 0);

    await 1ms/_;
    await 2000ms/_;
    _assert(tm_app.v == 1);
    await 2000ms/_;
    _assert(tm_app.v == 2);
    await 2000ms/_;
    _assert(tm_app.v == 3);

    ///////////////////////////////

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    emit tm.go_forward(-5);
    _assert(tm_app.v == 0);

    await 1ms/_;
    loop i in [0 -> 100[ do
        await 50ms/_;
    end
    _assert(tm_app.v == 1);
    loop i in [0 -> 100[ do
        await 50ms/_;
    end
    _assert(tm_app.v == 2);
    loop i in [0 -> 100[ do
        await 50ms/_;
    end
    _assert(tm_app.v == 3);

with
    input int DT;
    async (tm) do
        loop do
            if not _CEU_TIMEMACHINE_ON then
                emit 50ms;
                emit DT(50);
            end

            // TODO: forces this async to be slower
            input void SLOW;
            loop do
                if not tm.locked then
                    break;
                end
                emit SLOW;
            end
            emit 50ms/_;
        end
    end
end

escape tm_app.v;
]],
    timemachine = true,
    complete = (i>1),   -- runs i=1 for sure
    _ana = {
        acc = true,
    },
    run = 3,
}

-- Backward
Test { [[
native/pos do
    int CEU_TIMEMACHINE_ON = 0;
end

class TM_App with
    var int v = 0;
do
    every 1s do
        this.v = this.v + 1;
    end
end
var TM_App tm_app;

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

native/pre do
    ##define CEU_FPS 100
end

#include "tm/backend.ceu"

#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
end
var IOTimeMachine io;
#endif

var TimeMachine tm with
    this.app = &tm_app;
#ifdef TM_QUEUE
    this.io  = &io;
#endif
end;

par/or do
    await 3s/_;
    emit tm.go_on;
    await 1s/_;

    ///////////////////////////////

    emit tm.go_seek(tm.time_total);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_backward(1);
    _assert(tm_app.v == 3);

    await 1000ms/_;
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);
    await 1000ms/_;
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);
    await 1000ms/_;
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    ///////////////////////////////

    emit tm.go_seek(tm.time_total);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_backward(1);
    _assert(tm_app.v == 3);

    loop i in [0 -> 20[ do
        await 50ms/_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);
    loop i in [0 -> 20[ do
        await 50ms/_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);
    loop i in [0 -> 20[ do
        await 50ms/_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    ///////////////////////////////

    emit tm.go_seek(tm.time_total);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_backward(2);
    _assert(tm_app.v == 3);

    loop i in [0 -> 10[ do
        await 50ms/_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);
    loop i in [0 -> 10[ do
        await 50ms/_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);
    loop i in [0 -> 10[ do
        await 50ms/_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    ///////////////////////////////

    emit tm.go_seek(tm.time_total);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_backward(5);
    _assert(tm_app.v == 3);

    await 200ms/_;
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);
    await 200ms/_;
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);
    await 200ms/_;
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    ///////////////////////////////

    emit tm.go_seek(tm.time_total);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_backward(-2);
    _assert(tm_app.v == 3);

    await 2000ms/_;
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);
    await 2000ms/_;
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);
    await 2000ms/_;
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    ///////////////////////////////

    emit tm.go_seek(tm.time_total);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_backward(-5);
    _assert(tm_app.v == 3);

    loop i in [0 -> 100[ do
        await 50ms/_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 2);
    loop i in [0 -> 100[ do
        await 50ms/_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);
    loop i in [0 -> 100[ do
        await 50ms/_;
    end
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    tm_app.v = tm_app.v + 1;
with
    input int DT;
    async (tm) do
        loop do
            if not _CEU_TIMEMACHINE_ON then
                emit 10ms;
                emit DT(10);
            end

            // TODO: forces this async to be slower
            input void SLOW;
            loop do
                if not tm.locked then
                    break;
                end
                emit SLOW;
            end
            emit 10ms/_;
        end
    end
end

escape tm_app.v;
]],
    timemachine = true,
    complete = (i>1),   -- runs i=1 for sure
    _ana = {
        acc = true,
    },
    run = 1,
}

-- Forward / Backward
Test { [[
native/pos do
    int CEU_TIMEMACHINE_ON = 0;
end

class TM_App with
    var int v = 0;
do
    every 1s do
        this.v = this.v + 1;
    end
end
var TM_App tm_app;

input int DT;

]]..defs..[[

#define TM_INPUT_DT     DT
#define TM_QUEUE_N      1000000
#if defined(TM_QUEUE) || defined(TM_DIFF)
#define TM_SNAP_MS      2000
#endif
#define TM_SNAP_N       1000
#define TM_DIFF_N       1000000

native/pre do
    ##define CEU_FPS 100
end

#include "tm/backend.ceu"

#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
end
var IOTimeMachine io;
#endif

var TimeMachine tm with
    this.app = &tm_app;
#ifdef TM_QUEUE
    this.io  = &io;
#endif
end;

par/or do
    await 3s/_;
    _assert(tm_app.v == 3);
    emit tm.go_on;

    await 1s/_;
    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 0);

    await 1s/_;
    emit tm.go_forward(2);
    _assert(tm_app.v == 0);

    await 1s400ms/_;
    _assert(tm_app.v == 2);

    emit tm.go_seek(tm.time_total);
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 3);

    emit tm.go_backward(2);
    _assert(tm_app.v == 3);

    await 1s1ms/_;
    TM_AWAIT_SEEK(tm);
    _assert(tm_app.v == 1);
with
    input int DT;
    async (tm) do
        loop do
            if not _CEU_TIMEMACHINE_ON then
                emit 10ms;
                emit DT(10);
            end

            // TODO: forces this async to be slower
            input void SLOW;
            loop do
                if not tm.locked then
                    break;
                end
                emit SLOW;
            end
            emit 10ms/_;
        end
    end
end

escape tm_app.v;
]],
    timemachine = true,
    complete = (i>1),   -- runs i=1 for sure
    _ana = {
        acc = true,
    },
    run = 1,
}

Test { [[
native/pos do
    int CEU_TIMEMACHINE_ON = 0;
end

input int&& KEY;
class TM_App with
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
var TM_App tm_app;

input int  DT;

]]..defs..[[

#define TM_INPUT_DT     DT
#define TM_QUEUE_N      1000000
#if defined(TM_QUEUE) || defined(TM_DIFF)
#define TM_SNAP_MS      2000
#endif
#define TM_SNAP_N       1000
#define TM_DIFF_N       1000000

native/pre do
    ##define CEU_FPS 100
end

#include "tm/backend.ceu"

#ifdef TM_QUEUE
class IOTimeMachine with
    interface IIOTimeMachine;
do
    par do
        loop do
            // starts off
            watching this.go_on do
                every key in KEY do
                    do _queue_put(_CEU_IN_KEY,
                               sizeof(int), key as byte&&
#ifdef TM_SNAP
                                ,0
#endif
                              );
                        finalize with
                            nothing;
                        end;
                end
            end
            await this.go_off;
        end
    with
        every this.go_queue do
            var int v = *(_QU:buf);
            if _QU:evt == _CEU_IN_KEY then
                async(v) do
                    emit KEY(&&v);
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
    this.app = &tm_app;
#ifdef TM_QUEUE
    this.io  = &io;
#endif
end;

par/or do
    async do
        loop i in [0 -> 300[ do
            emit 10ms;
            emit DT(10);
        end
        var int v = 1;
        emit KEY(&&v);
        loop i in [0 -> 300[ do
            emit 10ms;
            emit DT(10);
        end
        v = 2;
        emit KEY(&&v);
        loop i in [0 -> 300[ do
            emit 10ms;
            emit DT(10);
        end
    end
    _assert(tm_app.v == 25);

    emit tm.go_on;
    await 1s/_;

    emit tm.go_seek(0);
    TM_AWAIT_SEEK(tm);

    emit tm.go_forward(1);
    await 3s1ms/_;
    _assert(tm_app.v == 7);
    await 2s/_;
    _assert(tm_app.v == 9);
    await 1s/_;
    _assert(tm_app.v == 22);
    await 3s/_;
    _assert(tm_app.v == 25);
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
            emit 10ms/_;
        end
    end
end

escape tm_app.v;
]],
    timemachine = true,
    complete = (i>1),   -- runs i=1 for sure
    _ana = {
        acc = true,
    },
    run = 25,
}

end

--<<< TIMEMACHINE
do return end

-------------------------------------------------------------------------------
-- BUGS & INCOMPLETNESS
-------------------------------------------------------------------------------
--[=[
Test { [[
code/tight Ff (void) => FOREVER do
end
]],
    run = 'error',
}

Test { [[
code/delayed Ff (void) => FOREVER do
    escape 0;
end
]],
    run = 'error',
}

Test { [[
code/delayed Ff (void) => FOREVER do
    do finalize with
        _ceu_dbg_assert(0);
    end
    escape;
end
par/or do
    await Ff();
with
end
escape 1;
]],
    run = 1,
}

Test { [[
code/delayed Ff (void) => FOREVER do
    do finalize with
        _ceu_dbg_assert(0);
    end
    escape;
end
par/or do
    await Ff();
with
end
escape 1;
]],
    run = 'error',
}
--]=]

--[=====[

-- TODO: should accept
Test { [[
native _char;
vector[3] _char buf_ = [];
escape sizeof(buf_);
]],
    todo = 'should accept sizeof(static-vector)',
    run = 0,
}

-- BUG: bad message, I want to say that you cannot copy vectors in a single stmt
Test { [[
class Test with
    code/tight FillBuffer (vector[]&& u8 buf)=>void;
do
    code/tight FillBuffer (vector[]&& u8 buf)=>void do
        vector[] u8 b = *buf;
        b = b .. [3];
    end
end

vector[10] u8 buffer;

var Test t;
t.fillBuffer(&&buffer);

escape buffer[0];
]],
    stmts = 'line 5 : types mismatch (`u8[]´ <= `u8[]´)',
}

-- BUG: doesn't check dimension of pointer to vector
Test { [[
code/tight FillBuffer (vector[20]&& u8 buf)=>void do
    *buf = *buf .. [3];
end
vector[10] u8 buffer;
fillBuffer(&&buffer);
escape buffer[0];
]],
    stmts = 'line 5 : wrong argument #1 : types mismatch (`u8[]&&´ <= `u8[]&&´) : dimension mismatch',
}

--cbuffer "attr to greater scope"
Test { [[
    code/tight/recursive Update_surface (void)=>void do
        var _CollisionMap&& colmap = _XXX_PURE(global:world!:get_colmap());

        this.me.colmap_serial = colmap:get_serial();

        this.me.canvas.lock();

        var u8&& cbuffer = (_XXX_PURE(this.me.canvas.get_data()) as u8&&);
]],
}

Test { [[
interface Global with
    var int i;
end
var int i = 1;

class Tx with
    code/tight Get (void)=>int;
do
    code/tight Get (void)=>int do
        escape global:i;
    end
end

var Tx t;

escape t.get();
]],
    run = 1,
}

Test { [[
class WorldObjFactory with
    var _PingusLevel&& plf;
do
    native/pos do
        ##define std__vector_FileReader std::vector<FileReader>
    end
    loop i in [0->this.plf:get_objects().size()[ do
        traverse _ in [] with
            var _FileReader&& reader = &&this.plf:get_objects().at(i);
        do
        end
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
native/plain _rect;
native/pre do
    typedef struct rect {
        int* x, y;
    } rect;
end
var int v = 10;
var _rect r = _rect(null);
r.x = &&v;      // BUG: finalize?
escape *(r.x);
]],
    run = 10,
}

Test { [[
data Dx with
    var int x;
end

data Ee with
    data Nothing;
or
    data Xx with
        var& Dx d;
    end
end

    var Dx d = val Dx(1);
var Ee e = Ee.Xx(&d);
    e.Xx.d = &d;     // BUG: error?

escape e.Xx.d.x;
]],
    run = 1,
}

-- TODO: bug
Test { [[
data LLRB with
    data Nil;
or
    data Node with
        var LLRB left;
        var LLRB right;
    end
end

var& LLRB h;
h.Node.right = h.Node.left;

escape 1;
]],
    run = 1,
}

-- TODO: bug
Test { [[
data LLRB with
    data Nil;
or
    data Node with
        var LLRB left;
    end
end

pool[] LLRB llrb;
traverse e in llrb do
    e:Node.left = traverse e:Node.left;
end

escape 1;
]],
    run = 1,
}

-----------------------

Test { [[
class Tx with
    var int xxx2=0;
    code/tight Fff (var int xxx3)=>void;
do
    code/tight Fff (var int xxx3)=>void do
        var int xxx4 = xxx3;
        this.xxx2 = xxx4;
    end
    this.xxx2 = 1;
end

var int xxx1 = 10;
var Tx ttt;
ttt.fff(&xxx1);
escape ttt.xxx2;
]],
    run = 1,
}
Test { [[
class TimeDisplay with
    code/tight Build (var& int vvv)=>TimeDisplay;
do
    var int x = 0;
    var& int vvv;

    code/tight Build (var& int vvv)=>TimeDisplay do
        this.vvv = &vvv;
    end

    vvv = &x;
end
escape 1;
]],
    run = 1,
}

Test { [[
class TimeDisplay with
    code/tight Build (var& int vvv)=>TimeDisplay;
do
    var& int vvv;

    code/tight Build (var& int vvv)=>TimeDisplay do
        this.vvv = &vvv;
    end
end
escape 1;
]],
    run = 1,
}

--[=[
---

    var byte&&                  name    = null;

    code/tight Name (var @hold byte&& name)=>Surface;

---

class Credits with
    var _Pathname&& filename;
do
    finalize with
        call {StatManager::instance()->set_bool}("credits-seen", true);
    end

    // read credit information from filename
    {
        static std::vector<std::string> credits;
        static int end_offset = -static_cast<float>(Display::get_height())/2 - 50; // screen height + grace time

        {
            std::ifstream in(THIS(CEU_Credits)->filename->get_sys_path());
            if (!in) {
                log_error("couldn't open %1%", THIS(CEU_Credits)->filename);

                std::ostringstream out;
                out << "couldn't open " << THIS(CEU_Credits)->filename;
]=]
-------------------------------------------------------------------------------

-- BUG: deveria ser outer.rect.
-- tenho que verificar essas atribuicoes this.x=this.x
        --var SpriteR _ = SpriteR.build_name(&this.rect,
                                           --"core/buttons/hbuttonbgb");

-- BUG: u8 vs int
Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) __ceu_nothing_int(d,1)
end
output/input/await LINE [10] (var int max)=>int;
par/or do
    var u8 err;
    var u8? ret;
    (err, ret) = request LINE => 10;
with
end
escape 1;
]],
    run = 1,
}

Test { [[
emit/await/refs
class SDL with
    input:
        vector[] byte title;
        var int w,h;

    output:
        var& _SDL_Window   win;
        var& _SDL_Renderer ren;

    input/output:
        var int io;

    output/input:
        var int oi;
do
    var& _SDL_Window? win_;
        do win_ = &_SDL_CreateWindow("SDL 1", _SDL_WINDOWPOS_CENTERED,
                                           _SDL_WINDOWPOS_CENTERED,
                                           800, 480,
                                           _SDL_WINDOW_SHOWN);
    finalize with
        _SDL_DestroyWindow(&&win_!);
    end
    this.win = &win_!;

    _SDL_GetWindowSize(&&win, &&w, &&h);

    var& _SDL_Renderer? ren_;
        do ren_ = &_SDL_CreateRenderer(&&win, -1, 0);
    finalize with
        _SDL_DestroyRenderer(&&ren_!);
    end
    this.ren = &ren_!;

    await FOREVER;
end
var SDL _;
]],
    run = 1,
}

-- BUG: deallocates byte: ifc/body locs should not terminate
Test { [[
class Tx with
    output:
        vector&[] byte name;
do
    vector[] byte name_ = [].."oi";
    this.name = &name_;
    // bug: deallocates byte[]
end

var Tx t;
native/nohold _strlen;
escape _strlen((byte&&)&&t.name);
]],
    run = 2,
}

--
--no output vectors in interfaces

--
--every (x,_) in e do

--
--event in e      // class ifc
--if e then ...   // nested blk in body
--end
--_printf(e);

--
-- bug: arity mismatch on constructor/creation
Test { [[
class Tx with
    var& void p;
    code/tight Build (var& void p)=>Tx;
do
    code/tight Build (var& void p)=>Tx do
        this.p = &p;
    end
    escape *(&&this.p as int&&);
end

var int v = 10;
var int ret = do Tx.build(&v);
escape ret;
]],
    run = 10,
}

Test { [[
data Dx with
    vector&[] byte str;
end
vector[] byte s = [].. "oi";
var Dx d = val Dx(s);    // BUG: nao detecta erro de tipo
escape $d.str;
]],
    run = 2,
}

-- bug: force nominal type system
Test { [[
interface I with
end

class V with
do
    pool[1] I is;
end

escape 1;
]],
    run = 1,
}

-- async dentro de pause
-- async thread spawn falhou, e ai?

Test { [[
native _u8;
data Test with
  vector[10] _u8 vvv;
end
native _V;
var Test t = Test([_V]);    // should not accept [_V] here
t.vvv[9] = 10;
escape t.vvv[9];
]],
    run = 10,
}

-- BUG-EVERY-SPAWN
-- t1 creates t2, which already reacts to e
Test { [[
native/pos do
    int V = 0;
end

class Gx with
    event void e;
do
    await FOREVER;
end

interface I with
    var& Gx g;
end

pool[] I is;

class Tx with
    var& Gx g;
    pool&[] I is;
do
    every g.e do
native _V;
        _V = _V + 1;
        spawn Tx in is with
            this.g = &outer.g;
            this.is = &outer.is;
        end;
    end
end

var Gx g;
spawn Tx in is with
    this.g = &g;
    this.is = &is;
end;
emit g.e;

escape _V;
]],
    run = 1,
}

-- BUG: must enforce alias
Test { [[
data Ball with
    var int x;
end

data Leaf with
    data Nothing;
or
    data Tween with
        var& Ball ball;
    end
end

class LeafHandler with
    var& Leaf leaf;
do
    var& Ball ball = &leaf.Tween.ball;
    escape ball.x;
end

var Ball ball = val Ball(10);
var Leaf leaf = Leaf.Tween(ball);   // must be alias

var int x = do LeafHandler with
                this.leaf = &outer.leaf;
            end;

escape x;
]],
    todo = 'bug',
    run = 1,
}
---------------------------------------------------
-- BUG: should be type error, Tx&& <= Tx[]
Test { [[
data Tree;
    data Nil;
or
    data Node with
        var int   v;
        var Tree  left;
        var Tree  right;
    end
end

pool[3] Tree tree;
tree = new Node(1,
            Node(2, Nil(), Nil()),
            Node(3, Nil(), Nil()));

class Sum with
    var int&& v;
do
    await FOREVER;
end

class Body with
    pool&[]  Body bodies;
    var   Tree&&   n;
    var&   Sum    sum;
do
    watching *n do
        if (*n is Node) then
            *this.sum.v = *this.sum.v + (*n as Node).v;
            spawn Body in this.bodies with
                this.bodies = &bodies;
                this.n      = &&(*n as Node).left;
                this.sum    = &sum;
            end;
        end
    end
end

var int v = 0;
var Sum sum with
    this.v = &&v;
end;

pool[7] Body bodies;
do Body with
    this.bodies = &bodies;
    this.n      = &&tree;
    this.sum    = &sum;
end;

escape v;
]],
    todo = 'bug',
    fin = 'line 29 : unsafe access to pointer "v" across `class´ (/tmp/tmp.ceu : 22)',
}
Test { [[
data List;
    data Nil;
    data List.Cons with
        var int  head;
        var List tail;
    end
end

var List l;
escape 1;
]],
    todo = 'List is recursive',
    run = 1,
}

Test { [[
class Tx with
    vector[] byte xxx;
do
    await FOREVER;
end

var Tx t with
    this.xxx = [].."oioi";
end;

escape $t.xxx;
]],
    run = 4,
}

-- TODO: vectors in the class interface
Test { [[
native/pure _strlen;
class Tx with
    vector[] byte str;
do
    escape _strlen(&&this.str);
end
var int n = do Tx with
                this.str = [] .. "1234";
            end;
escape n;
]],
    run = 1,
}

-- BUG: same id
-- BUG: unassigned var (should be int?)
Test { [[
var int a = 10;
do
    var int a = a;
    escape a;
end
]],
    wrn = true,
    run = 10,
}

Test { [[
data Stmt;
    data Nil;
or
    data Stmt.Seq with
        var Stmt s1;
    end
end

pool[] Stmt stmts = new Stmt.Nil();

var int v1 = 10;

var int ret =
    traverse stmt in stmts with
        var int v1 = v1+1;
    do
        escape v1;
    end;

escape ret;
]],
    wrn = true,
    run = 11,
}

-- BUG: across
-- BUG: unassigned pointer (should be int*?)
Test { [[
var int* x;
await 1s;
escape *x;
]],
    todo = true,
    run = 1,
}

Test { [[
var& void v;
escape 1;
]],
    run = 1,
    -- TODO: should fail as below
    --env = 'line 1 : cannot instantiate type "void"',
}

-- TODO: bug: what if the "o" expression contains other pointers?
-- (below: pi)
Test { [[
class Tx with
do
end

vector[10] Tx ts;
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
            emit e(&x);
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

-- XXX: Tx-vs-Opt
Test { [[
class Tx with
do
end
var& Tx*? t;
    do t = _malloc(10 * sizeof(Tx**));
finalize with
    nothing;
end
native/nohold _free;
do finalize with
    _free(t!);
end
escape 10;
]],
    run = 10;
}

Test { [[
input void A, B, Z;
event void a;
var int ret = 1;
native _t;
var _t* a;
native _f;
par/or do
    do _f(a);               // 8
        finalize with
            ret = 1;    // DET: nested blks
        end;
with
    var _t* b;
    do _f(b);               // 14
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
    emit x(1);       // in seq
    emit y(1);       // in seq
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
native/pos do
    int V = 1;
end
class Tx with
do
    par/or do
        await OS_START;
    with
        await OS_START;    // valgrind error
    end
    _V = 10;
end
do
    spawn Tx;
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
        emit a(v);
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
input void A,B;

interface I with
    var int v;
    event void inc;
end

class Tx with
    interface I;
do
    await inc;
    this.v = v + 1;
end

var int ret = 0;
do
    par/or do
        await B;
    with
        var int i=1;
        every 1s do
            spawn Tx with
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
    run = { ['~>3s;~>B'] = 11 },
}

-- BUG: should be: field must be assigned
Test { [[
var int v = 10;
var& int i;

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

--do return end

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
native/pre do
    typedef int t;
end
native _t ;
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
        emit ptr(1, &b);
    end
end
escape 1;
]],
    run = 1,
    -- e depois outro exemplo com fin apropriado
    -- BUG: precisa transformar emit x(1 em p=1);emit x
}

Test { [[
native/pos do
    int V = 0;
end

class Tx with
do
    _V = 10;
    do finalize with
        _V = 100;   // TODO: deveria executar qd "var Tx t" sai de escopo
    end
end

var Tx t;
_assert(_V == 10);
escape _V;
]],
    run = 100,
}

Test { [[
code/tight Fx () => void;
escape 1;
]],
    run = 1,
}

-- TODO: fails on valgrind, fails on OS
-- put back to XXXX
Test { [[
native _V;
input void A, B, OS_START;
native/pos do
    int V = 0;
end
class Tx with
    event void e, ok;
    var int v;
do
    do finalize with
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
    var Tx t;
    par/or do
        do                  // 24
            do finalize with
                _V = _V*10;
            end
            await t.ok;
        end
    with
        await t.e;          // 31
        t.v = t.v * 3;
    with
        await B;
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
        ['~>B'] = 6,
        ['~>A'] = 13,
    }
}

-- TODO_TYPECAST (search and replace)
Test { [[
class Tx with
do
end
// TODO: "typecast" esconde "call", finalization nao acha que eh call
var Tx** t := (Tx**)_malloc(10 * sizeof(Tx**));
native/nohold _free;
do finalize with
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
class Tx with
    interface I;
do
end
pool[1] Tx ts;
var Tx a with
    a.v = 15;
end
var int ret = 0;
ret = ret + spawn Tx[ts] with
                this.v = 10;
            end;
ret = ret + spawn Tx[ts];
loop i in (I*)(ts in a) do
    ret = ret + i:v;
end
escape 26;
]],
    run = 1,
}

Test { [[
class Tx with
    var void* ptr = null;
do
end
var Tx* ui;
do
    pool[] Tx ts;
    var void* p = null;
    ui = spawn Tx in ts with // ui > ts (should require fin)
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
vector[2] int v ;
_f(v)
escape v == &v[0] ;
]],
    run = 1,
}

Test { [[
native/nohold _strncpy(), _printf(), _strlen();
native _char = 1;
vector[10] _char str;
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
class Tx with
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
class Tx with
native _int;
    var _int to;
do
end

var _int to = 1;

var Tx move with
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

class Tx with
    interface I;
do
    await FOREVER;
end

pool[100] I is;

var int ret = 0;

spawn Tx with
    this.v = 1;
end;

spawn Tx in is with
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

class Tx with
    interface I;
do
    await FOREVER;
end
pool[] I is;

class U with
    var int z;
    var int v;
do
    await FOREVER;
end

var int ret = 0;
do
    spawn Tx with
        this.v = 1;
    end;
    spawn U in is with
        this.v = 2;
    end;
    spawn Tx in is with
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
    pool[10] U us;
end

interface Global with
    interface I;
end
pool[] U  us;

class Tx with
    pool[10] U us;
    interface I;
do
    spawn U in global:us;
end

spawn U in us;
spawn U in global:us;

pool[1] U us1;
spawn U in us1;

var Tx t;
spawn U in t.us;

var I* i = &t;
spawn U in i:us;

escape 1;
]],
    wrn = true,
    run = 1,
}

-- TODO: t.v // Tx.v
Test { [[
class Tx with
    var int v;
do
    v = 1;
end
var Tx t;
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

class Tx with
    interface I;
do
    this.v = 1;
end
pool[] Tx ts;

par/or do
    spawn Tx in ts with
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
class Tx with
do
end

par/and do
    pool[] Tx ts;
    var Tx* t = spawn Tx in ts with
    end;
with
    var Tx* p;
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

class Tx with
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
    pool[10] I is;
    spawn Tx in is;
    spawn U in is;
end

pool[10] I is;

spawn Tx in is;
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
    emit v(0);
    emit v(1);
    emit v(10);
    await FOREVER;
end
]],
    run = 10;
}

-------------------------------------------------------------------------------
Test { [[
input void    START,   STOP;
input _pkt_t* RECEIVE, SENDACK;

native/nohold _memcpy(), _send_dequeue(), _pkt_setRoute(), _pkt_setContents(), 
_receive();

class Forwarder with
   var _pkt_t pkt;
   event void ok;
do
   loop do
      var bool enq;
      do enq = _send_enqueue(&pkt);
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
      pool[10] Forwarder forwarders;
      vector[10]  Client    clients;

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
        emit A(&i);
        i = 1;
        emit A(&i);
    end
end
escape 0;
]],
    _ana = {
        acc = 4,
    },
    run = 1;
}

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
    pool[257] Rect rs;
    loop i in [0 -> 257[ do
        spawn Rect in rs;
    end
end

escape 10;
]],
    run = 10,
}

Test { [[
class Tx with do end;
pool[] Tx ts;
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
class Tx with
    interface I;
do end
do
    pool[] Tx ts;
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
input/output/tight B  (var int a)=>int do
    escape a + 1;
end
var int ret = call B(1);
escape ret;
]],
    run = 2,
}

Test { [[
input/output/tight WRITE  (var int c)=>int do
    escape c + 1;
end
var byte b = 1;
var int ret = call WRITE(b);
escape ret;
]],
    run = 2,
}

Test { [[
input/output/tight B  (var int a, var  int b)=>int do
    escape a + b;
end
var int ret = call B(1,2);
escape ret;
]],
    run = 3,
}

Test { [[
native/pre do
    typedef int lua_State;
    void lua_pushnil (lua_State* l) {}
end

input/output/tight PUSHNIL  (var _lua_State* l)=>void do
    _lua_pushnil(l);
end
escape 1;
]],
    run = 1,
}

Test { [[
input/output/tight DRAW_STRING  (var byte* str, var int len, var int x, var  int y)=>int do
    escape x + y + len;
end

var int ret = call DRAW_STRING(("Welcome to Ceu/OS!\n", 20, 100, 100));

escape ret;
]],
    run = 220,
}

Test { [[
input/output/tight MALLOC  (void)=>void*;
var void* ptr = (call MALLOC);
]],
    fin = 'line 2 : destination pointer must be declared with the `[]´ buffer modifier',
}

Test { [[
input/output/tight MALLOC  (void)=>void*;
vector[] void ptr = (call MALLOC);
]],
    fin = 'line 2 : attribution requires `finalize´',
}

Test { [[
input/output/tight MALLOC  (void)=>void*;
vector[] void ptr;
    do ptr = (call MALLOC);
finalize with
end
escape 1;
]],
    code = 'line 1 : missing function body',
}

Test { [[
input/output/tight MALLOC  (var int, var int)=>void*;
vector[] void ptr;
    do ptr = (call MALLOC(1,1));
finalize with
end
escape 1;
]],
    code = 'line 1 : missing function body',
}

Test { [[
input/output/tight MALLOC  (var int, var int)=>int;
var int v;
    do v = (call MALLOC(1,1));
finalize with
end
escape 1;
]],
    fin = 'line 4 : attribution does not require `finalize´',
}

Test { [[
input/output/tight MALLOC  (var int a, var int b, var  void* ptr)=>void* do
    if a+b == 11 then
        escape ptr;
    else
        escape null;
    end
end

var int i;
vector[] void ptr;
    do ptr = (call MALLOC(10,1, &i));
finalize with
end
escape ptr==&i;
]],
    run = 1,
}
Test { [[
input/output/tight MALLOC  (var int a, var int b, var  void* ptr)=>void* do
    if a+b == 11 then
        escape ptr;
    else
        escape null;
    end
end

var int i;
vector[] void ptr;
    do ptr = (call MALLOC(1,1, &i));
finalize with
end
escape ptr==null;
]],
    run = 1,
}

Test { [[
input/output/tight MALLOC  (void)=>void*;
native _f;
do
    var void* a;
        do a = (call MALLOC);
    finalize with
        do await FOREVER; end;
    end
end
]],
    fin = 'line 6 : destination pointer must be declared with the `[]´ buffer modifier',
}

Test { [[
input/output/tight B  (var void* v)=>void do
    _V = v;
end
escape 1;
]],
    fin = 'line 2 : attribution to pointer with greater scope',
}

Test { [[
input/output/tight B  (var void* v)=>void do
    _V := v;
end
escape 1;
]],
    todo = 'line 2 : parameter must be `hold´',
}

Test { [[
native/pos do
    void* V;
end
input/output/tight B  (var/hold void* v)=>void do
    _V = v;
end
escape 1;
]],
    run = 1,
}

Test { [[
input/output/tight B  (var byte* buf)=>void do
end;
var byte* buf;
call B((buf));
escape 1;
]],
    run = 1,
}

Test { [[
input/output/tight B  (var byte* buf, var  int i)=>void do
end;
var byte* buf;
call B((buf, 1));
escape 1;
]],
    run = 1,
}

Test { [[
input/output/tight B  (void)=>void do
end;
var byte* buf;
call B;
escape 1;
]],
    run = 1,
}

Test { [[
input/output/tight B  (var byte* buf)=>void do
end;
var byte* buf;
call B(buf);
escape 1;
]],
    run = 1,
}

Test { [[
input/output/tight B  (var/hold byte* buf)=>void do
end;
var byte* buf;
call B(buf);
escape 1;
]],
    fin = 'line 2 : call requires `finalize´',
}

Test { [[
native _f;
native _v;
native/pos do
    int v = 1;
    int f (int v) {
        escape v + 1;
    }
end
escape _f(_v);
]],
    --fin = 'line 3 : call requires `finalize´',
    run = 2,
    --fin = 'line 9 : attribution requires `finalize´',
}
Test { [[
native/pure _f;
native _v;
native/pos do
    int v = 1;
    int f (int v) {
        escape v + 1;
    }
end
escape _f(_v);
]],
    --fin = 'line 3 : call requires `finalize´',
    run = 2,
}


Test { [[
native/pure _f;
native/pos do
    int* f (int a) {
        escape NULL;
    }
end
var int* v = _f(0);
escape v == null;
]],
    run = 1,
}

Test { [[
native/pure _f;
native/pos do
    int V = 10;
    int f (int v) {
        escape v;
    }
end
native/const _V;
escape _f(_V);
]],
    run = 10;
}

Test { [[
native/nohold _f;
native/pos do
    int f (int* v) {
        escape 1;
    }
end
var int v;
escape _f(&v) == 1;
]],
    run = 1,
}

Test { [[
native _V;
native/nohold _f;
native/pos do
    int V=1;
    int f (int* v) {
        escape 1;
    }
end
var int v;
escape _f(&v) == _V;
]],
    run = 1,
}

Test { [[
input/output/tight B  (var int* p1, var  int* p2)=>void;
do
    var int* p1 = null;
    do
        var int* p2 = null;
        call B((p1, p2));
    end
end
escape 1;
]],
    fin = 'line 6 : invalid call (multiple scopes)',
}

-- TODO: finalize not required
Test { [[
native/pos do
    #define ceu_out_call_VVV(x) x
end

output/input/tight VVV  (var int n)=>int;
var int v;
    do v = (call VVV(10));
finalize with
    nothing;
end
escape v;
]],
    run = 10,
}

-- TODO: finalize required
Test { [[
native/pos do
    #define ceu_out_call_MALLOC(x) NULL
end

output/input/tight MALLOC  (var int n)=>void*;
var byte* buf;
buf = (call MALLOC(10));
escape 1;
]],
    run = 1,
}

-- TODO: finalize required
Test { [[
native/pos do
    #define ceu_out_call_SEND(x) 0
end

output/input/tight SEND  (var byte* buf)=>void;
vector[255] byte buf;
call SEND(buf);
escape 1;
]],
    run = 1,
}

-- TODO: finalize required
Test { [[
native/pre do
    typedef struct {
        int a,b,c;
    } Fx;
end
native/pos do
    Fx* f;
    #define ceu_out_call_OPEN(x) f
end
output/input/tight OPEN  (var byte* path, var  byte* mode)=>_Fx*;

// Default device
vector[] _Fx f;
    f = (call OPEN(("/boot/rpi-boot.cfg", "r")));
escape 1;
]],
    run = 1,
}

Test { [[
output/input/tight OPEN  (var byte* path, var  byte* mode)=>_Fx*;
output/input/tight CLOSE  (var _Fx* f)=>int;
output/input/tight SIZE  (var _Fx* f)=>int;
output/input/tight READ  (var void* ptr, var int size, var int nmemb, var  _Fx* f)=>int;

// Default device
vector[] _Fx f;
    do f = (call OPEN(("/boot/rpi-boot.cfg", "r")));
finalize with
    call CLOSE(f);
end

if f == null then
    await FOREVER;
end

var int flen = (call SIZE(f));
//byte *buf = (byte *)malloc(flen+1);
vector[255] byte buf;
buf[flen] = 0;
call READ((buf, 1, flen, f));

#define GPFSEL1 ((uint*)0x20200004)
#define GPSET0  ((uint*)0x2020001C)
#define GPCLR0  ((uint*)0x20200028)
var uint ra;
ra = *GPFSEL1;
ra = ra & ~(7<<18);
ra = ra | 1<<18;
*GPFSEL1 = ra;

var byte* orig = "multiboot";

loop do
    loop i in [0 -> 9[ do
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
vector[10] int vec1;

class Tx with
    var& int* vec2;
do
    this.vec2[0] = 10;
end

vec1[0] = 0;

var Tx t with
    this.vec2 = outer.vec1;
end;

escape vec1[0];
]],
    run = 10,
}

-------------------------------------------------------------------------------

-- BUG: new inside constructor (requires stack manipulation?)
Test { [[
data Command;
    data Nothing;
or
    data Command.Sequence with
        var Command* one;
        var Command* two;
    end
end

class TCommand with
    pool[] Command cs;
do
end

var TCommand cmds with
    this.cs = new Nothing();
end;

escape 1;
]],
    run = 1,
}

-- TODO: BUG: type of bg_clr changes
--          should yield error
--          because it stops implementing UI
Test { [[
interface UI with
    var&   int?   bg_clr;
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
    var&   int?    bg_clr = nil;
    pool[] UIGridItem uis;
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
    pool[] UIGridItem uis;
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

Test { [[
native/pre do
    typedef struct {
        int v;
    } tp;
end
class Tx with
    var& _tp? i = nil;
do
end
var Tx t;
escape t.i!==nil;
]],
    run = 1,
}

Test { [[
native/pre do
    typedef struct {
        int v;
    } tp;
    tp V = { 10 };
end
class Tx with
    var& _tp? i = nil;
do
end
var Tx t with
    this.i = &_V;
end;
escape t.i!.v;
]],
    run = 10,
}

Test { [[
_assert(0);
escape 1;
]],
    asr = true,
}

-- BUG: do Tx quando ok acontece na mesma reacao
Test { [[
class Body with
    pool&[]  Body bodies;
    var&   int    sum;
    event int     ok;
do
    do finalize with end;

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
    emit this.ok(1);
end

pool[2] Body bodies;
var  int     sum = 0;

    do finalize with end;

do Body with
    this.bodies = bodies;
    this.sum    = sum;
end;

escape sum;
]],
    wrn = 'line 7 : unbounded recursive spawn',
    run = 6,
}

-- BUG: do Tx quando ok acontece na mesma reacao
Test { [[
data Tree;
    data Nil;
with
    data Node with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool[3] Tree tree;
tree = new Node(1,
            Node(2, Nil(), Nil()),
            Node(3, Nil(), Nil()));

class Body with
    pool&[]  Body bodies;
    var   Tree*   n;
    var&   int    sum;
    event int     ok;
do
    //watching n do
        var int i = this.sum;
        if (*n is Node) then
            var Body* left =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = (*n as Node).left;
                    this.sum    = sum;
                end;
            //watching left do
                await left:ok;
            //end

            this.sum = this.sum + i + (*n as Node).v;

            var Body* right =
                spawn Body in this.bodies with
                    this.bodies = bodies;
                    this.n      = (*n as Node).right;
                    this.sum    = sum;
                end;
            //watching right do
                await right:ok;
            //end

            //do/spawn Body in this.bodies with
                //this.n = (*n as Node).left;
            //end;
        end
    //end
    emit this.ok(1);
end

var int sum = 0;

pool[7] Body bodies;
do Body with
    this.bodies = bodies;
    this.n      = &&tree;
    this.sum    = sum;
end;

escape sum;

/*
var int sum = 0;
loop n in &&tree do
    var int i = sum;
    if (*n is Node) then
        traverse &(*n as Node).left;
        sum = i + (*n as Node).v;
        traverse &(*n as Node).right;
    end
end
escape sum;
*/
]],
    wrn = 'line 26 : unbounded recursive spawn',
    run = 999,
}

Test { [[
class Tx with
    event void e;
do
    await e;
end

pool[] Tx ts;

var int ret = 1;

spawn Tx in ts;
spawn Tx in ts;
async do end;

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

-- TODO: precisa do watching
Test { [[
data Tree;
    data Nil;
with
    data Node with
        var int   v;
        var Tree* left;
        var Tree* right;
    end
end

pool[3] Tree t;
t = new Node(1,
            Node(2, Nil(), Nil()),
            Node(3, Nil(), Nil()));

var int sum = 0;

par/or do
    loop i in t do
        if (*i is Node) then
            traverse &(*i as Node).left;
            await 1s;
            sum = sum + (*i as Node).v;
            traverse &(*i as Node).right;
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

-- BUG: parser cannot handle 65k lines
local str = {}
for i=1, 65536 do
    str[#str+1] = [[
class Class]]..i..[[ with
    interface I;
do
    x = 10;
end
]]
end
str = table.concat(str)

Test { [[
interface I with
    var int x;
end
]]..str..[[

var Class128 instance;
var I* target = &instance;
escape target:x;
]],
    todo = 'crashes',
    complete = true,
    run = 1,
}

-- BUG: cannot contain await nao se aplica a par/or com caminho sem await
Test { [[
input void A,B;

interface I with
    var int v;
    event void inc;
end

class Tx with
    interface I;
do
    await inc;
    this.v = v + 1;
    await FOREVER;
end
pool[] Tx ts;

var int ret = 0;
do
    par/or do
        await B;
    with
        var int i=1;
        every 1s do
            spawn Tx in ts with
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
    run = { ['~>3s;~>B'] = 13 },
}

-- TODO: como capturar o retorno de um org que termina de imediato?
-- R: option type
Test { [[
class Tx with
do
    escape 1;
end
var Tx*? t = spawn Tx;
var int ret = -1;
if t? then
    ret = await *t!;
end
escape ret;
]],
    run = 1,
}

-- TODO: TRAVERSE C POINTERS
Test { [[
native/pos do
    typedef struct tp {
        int v;
        struct tp* nxt;
    } tp;
    tp V1 = { 1, NULL };
    tp V2 = { 2, &V1  };
    tp VS = { 3, &V2  };
end

var int ret = 0;
loop/1 v in [0->_VS[ do      // think its numeric
    if v == null then
        break;
    else
        ret = ret + v:v;
        traverse v:nxt;
    end
end

escape 1;
]],
    exps = 'line 13 : invalid operands to binary "=="',
    --run = 1,
}

Test { [[
native/pos do
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
native/pos do
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
native/pos do
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
native/pos do
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
native/pos do
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
native/pos do
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
native/pos do
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
native/pos do
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

Test { [[
native/pos do
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
Test { [[
native/pos do
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

Test { [[
native/pos do
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

Test { [[
var int a := 1;
escape 1;
]],
    todo = 'line 1 : wrong operator',
}
Test { [[
var int a;
a := 1;
escape 1;
]],
    todo = 'line 2 : wrong operator',
}
Test { [[
var int&& a := null;
escape 1;
]],
    todo = 'line 1 : wrong operator',
}
Test { [[
var int&& a;
a := null;
escape 1;
]],
    todo = 'line 2 : wrong operator',
}
Test { [[
code/tight Faca (void)=>void do
    var int&& a;
    a := null;
end
escape 1;
]],
    wrn = true,
    todo = 'line 3 : wrong operator',
}
Test { [[
var int a=0;
var int&& pa := &&a;
escape 1;
]],
    todo = 'line 2 : wrong operator',
    run = 1,
}
Test { [[
code/tight Fx (var void&& o1)=>void do
    var void&& tmp := o1;
end
escape 1;
]],
    wrn = true,
    todo = 'line 2 : wrong operator',
    --fin = 'line 2 : pointer access across `await´',
}
--]=====]

