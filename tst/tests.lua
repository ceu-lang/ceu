local function INCLUDE (fname, src)
    local f = assert(io.open(fname,'w'))
    f:write(src)
    f:close()
end

----------------------------------------------------------------------------
-- NO: testing
----------------------------------------------------------------------------

--[=====[

-- BUG #89
Test { [[
code/await Ff (none) -> (var& int x) -> NEVER do
    code/tight Gg (none) -> none;
    call Gg();

    var int y = 10;
    x = &y;

    code/tight Gg (none) -> none do
        outer.x = 10;
    end

    await FOREVER;
end
spawn Ff();
escape 1;
]],
    run = 1,
}

-- BUG #89
Test { [[
code/await Ff (none) -> (var& int x) -> NEVER do
    code/tight Gg (none) -> none do
        outer.x = 10;
    end
    call Gg();

    var int y = 10;
    x = &y;
    await FOREVER;
end
spawn Ff();
escape 1;
]],
    --inits = 'line 1 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:3)',
    run = 1,
}

-- BUG #96
Test { [[
var int x = do()
    var bool x = false;
    escape 10;
end;
escape x;
]],
    run = 10,
}

-- BUG #96
Test { [[
var int x = do()
    code/await Ff (none) -> none do end
    var&? Ff x;
    escape 10;
end;
escape x;
]],
    wrn = true,
    run = 10,
}

-- BUG #97: tight loop
Test { [[
event none a;
loop do
    par/and do
        every a do
            break;
        end
    with
        emit a;
    end
end
]],
    run = 1,
}

-- BUG #98
Test { [[
var int ret = 1;
var u8 i;
loop i in [0->0[ do
    ret = ret + 1;
end
escape ret;
]],
    run = 1,
}
-- BUG #98
Test { [[
var int ret = 1;
var u8 i;
loop i in ]0<-0] do
    ret = ret + 1;
end
escape ret;
]],
    run = 1,
}
-- BUG #98
Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
var usize i;
loop i in [0->0[ do
    spawn Ff();
end
escape 1;
]],
    run = 1,
}

-- BUG #99
Test { [=[
var int xxx = 0;
[[
    @xxx = 123;
]]
escape xxx;
]=],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    run = 3,
}

-- BUG #101
Test { [[
code/await Ff (none) -> (event none ok) -> none do
    await async do end;
    if false then
        emit ok;
    end
end

var&? Ff f = spawn Ff();
await f!.ok;

escape 1;
]],
    --todo = 'on error, await never awakes // 1. force watching // 2. raise exception',
    run = 1,
}

-- BUG #105
Test { [[
data Dd with
    var int x;
end
code/tight Ff (none) -> Dd do
    var Dd d = val Dd(10);
    escape d;
end
if (call Ff()).x then
    if call Ff().x then
        escape 10;
    else
        escape 0;
    end
else
    escape 0;
end
]],
    run = 10,
}

-- BUG #106
Test { [[
code/await Ff (var int x) -> int do
    await 1s;
    escape x+10;
end

var&? Ff f = spawn Ff(1);
escape f!.x;
]],
    run = 0,
}

-- BUG #107
Test { [[
code/await Ff (var int x=10) -> (var int y=20) -> int do
    escape x + y;
end
var int ret = await Ff(_);
escape ret;
]],
    wrn = true,
    run = 1,
}

-- BUG #108
Test { [[
event int? e;
par do
    var int? v = await e;
    escape v!;
with
    emit e(10);
end
]],
    run = 10,
}

-- BUG #(static calls)
Test { [[
data Aa with
    var int a;
end

code/tight/dynamic Ff (var&/dynamic Aa a, var int xxx) -> int do
    escape a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/tight/dynamic Ff (var&/dynamic Aa.Bb b, var int yyy) -> int do
    escape b.b + (call/static Ff(&b as Aa,11)) + yyy;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

escape (call/dynamic Ff(&b,22)) + (call/dynamic Ff(&a,33));
]],
    run = 72,
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var&/dynamic Aa a, var/dynamic int xxx) -> int do
    escape a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var&/dynamic Aa.Bb b, var/dynamic int yyy) -> int do
    var int v = await/static Ff(&b as Aa,11);
    escape b.b + v + yyy;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

var int v1 = await/dynamic Ff(&b,22);
var int v2 = await/dynamic Ff(&a,33);

escape v1 + v2;
]],
    props_ = 'line 5 : invalid `dynamic` declaration : parameter #2 : expected `data` in hierarchy',
    --run = 1,
    --dcls = 'line 5 : invalid `dynamic` declaration : parameter #2 : unexpected plain `data`',
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var&/dynamic Aa a, var int xxx) -> int do
    escape a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var&/dynamic Aa.Bb b, var int yyy) -> int do
    var int v = await/static Ff(&b as Aa,11);
    escape b.b + v + yyy;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

var int v1 = await/dynamic Ff(&b,22);
var int v2 = await/dynamic Ff(&a,33);

escape v1 + v2;
]],
    run = 72,
}

-- BUG: #(awake dying trails)
Test { [[
event none f;
watching f do
    event none e;
    watching e do
        do finalize with
            emit e;
        end
        emit f;
    end
    {ceu_assert(0,"bug found");}
end
await 1s;
escape 10;
]],
    run = {['~>1s']=10},
    _opts = { ceu_features_exception='true' },
}

Test { [[
data Exception.Sub;
var Exception? f;
catch f do
    var Exception.Sub? e;
    catch e do
        do finalize with
            var Exception.Sub e_ = val Exception.Sub(_);
            throw e_;
        end
        var Exception e_ = val Exception(_);
        throw e_;
    end
    {ceu_assert(0,"bug found");}
end
await 1s;
escape 10;
]],
    run = {['~>1s']=10},
    _opts = { ceu_features_exception='true' },
}

-- BUG: #117
Test { [[
var byte&& str = "#9" as byte&&;
{ceu_assert(0,"err");}
escape 1;
]],
    _opts = { ceu_features_trace='true' },
    run = '2] -> runtime error: err',
    --todo = '"9" is inside a string, it shouldnt count',
}

-- var/nohold int x;
-- var/dynamic int x;
-------------------------------------------------------------------------------

--[==[
flag para dar erro c/ Lua Exception

-- reuse Exception that failed and was once set, now it continues set
[[ THIS.publication.payload = 'oi' ]]
var Exception.Freechains.Malformed? e;
catch e do
    await Publication_Check();
end
_ceu_assert(e?, "bug found");

[[ THIS.publication.payload = '' ]]
//var Exception.Freechains.Malformed? f;
catch e do
    await Publication_Check();
end
_ceu_assert(not e?, "bug found");

Test { [[
escape sizeof(32);
]],
    run = 1,
}

Test { [=[
await async/thread do
    var Exception e = val Exception(_);
    throw e;
end
escape 1;
]=],
    _opts = { ceu_features_exception='true', ceu_features_dynamic='true', ceu_features_thread='true', ceu_features_trace='true', },
    wrn = true,
    run = '3] -> runtime error: unspecified message',
}
Test { [=[
await async/thread do
    [[ error 'oi' ]]
end
escape 1;
]=],
    _opts = { ceu_features_exception='true', ceu_features_dynamic='true', ceu_features_thread='true', ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
    wrn = true,
    run = '2] -> runtime error: [string " error \'oi\' "]:1: oi',
}
]==]

do return end -- OK
--]=====]

----------------------------------------------------------------------------
-- OK: well tested
----------------------------------------------------------------------------

Test { [[]], run='Aborted' }
Test { [[]],
    run = '1] -> runtime error: reached end of `do`',
    _opts = { ceu_features_trace='true' },
}
Test { [[escape (1);]], run=1 }
Test { [[escape 1;]], run=1 }

Test { [[escape 1; // escape 1;]], run=1 }
Test { [[escape /* */ 1;]], run=1 }
Test { [[escape /*

*/ 1;]], run=1 }
Test { [[escape /**/* **/ 1;]], run=1 }
Test { [[escape /**/* */ 1;]],
    parser = 'line 1 : after `escape` : expected internal identifier',
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
    --ast = 'line 5 : max depth of 0xFF',
    run = 1
}

-->>> EXPS / EXPRESSIONS

Test { [[escape 0;]], run=0 }
Test { [[escape 9999;]], run=9999 }
Test { [[escape -1;]], run=-1 }
Test { [[escape --1;]], run=1 }
Test { [[escape - -1;]], run=1 }
Test { [[escape -9999;]], run=-9999 }
Test { [[escape 'A';]],
    parser = 'line 1 : after `escape` : expected expression or `;`',
}
Test { [[escape {'A'};]], run=65, }
Test { [[escape (((1)));]], run=1 }
Test { [[
escape 1 + null;
]],
    dcls = 'line 1 : invalid operand to `+` : expected numeric type',
}
Test { [[
escape 1 or false;
]],
    dcls = 'line 1 : invalid operand to `or` : expected boolean type',
}

Test { [[escape (1 >= 0) as int;]], run=1 }
Test { [[escape 1+2*3;]], run=7 }
Test { [[escape(4/2*3);]], run=6 }
Test { [[escape 2-1;]], run=1 }

Test { [[escape 1 as integer;]],
    run = 1,
}

Test { [[escape 1==2;]], stmts='line 1 : invalid `escape` : types mismatch : "int" <= "bool"', }
Test { [[escape (1!=2) as integer;]], run=1 }
Test { [[escape 0  or  10;]],
    dcls = 'line 1 : invalid operand to `or` : expected boolean type',
}
Test { [[escape (0 as bool)  or  (10 as bool) as int;]],
    parser = 'line 1 : after `)` : expected `[` or `:` or `.` or `!` or `?` or `(` or binary operator or `;`',
    --run = 1,
}
Test { [[escape ((0 as bool)  or  (10 as bool)) as integer;]],
    run = 1,
}
Test { [[escape ((0 as bool) and (10 as bool)) as int;]], run=0 }
Test { [[escape (10==true) as int;]],
    dcls = 'line 1 : invalid operands to `==` : incompatible types : "int" vs "bool"',
}
Test { [[escape (10!=0) as int;]], run=1 }
Test { [[escape (true and true) as integer;]], run=1 }
Test { [[escape (2>1 and 10!=0) as int;]], run=1 }
Test { [[escape ((1<=2) as int) + 3;]], run=4 }
Test { [[escape ((1<=2) as integer) + ((1<2) as int) + 2/1 - 2%3;]], run=2 }
Test { [[
escape ((1^1==0) as int) + ((1^0==1) as int)+ ((0^0==0) as int);
]],
    run = 3,
}
-- TODO: linux gcc only?
--Test { [[escape (~(~0b1010 & 0XF) | 0b0011 ^ 0B0010) & 0xF;]], run=11 }
Test { [[nt a;]],
    --parser = "line 1 : after `nt` : expected `(` or `[` or `:` or `.` or `?` or `!` or `is` or `as` or binary operator or `=` or `:=` or `;`",
    --parser = 'line 1 : after `nt` : expected `[` or `:` or `.` or `!` or `as` or `=` or `:=` or `(`',
    parser = 'line 1 : after `nt` : expected `[` or `:` or `.` or `!` or `as` or `=` or `?` or `(` or `is` or binary operator or `;`',
}
Test { [[nt sizeof;]],
    --parser = "line 1 : after `nt` : expected `(` or `[` or `:` or `.` or `?` or `!` or `is` or `as` or binary operator or `=` or `:=` or `;`",
    parser = 'line 1 : after `nt` : expected `[` or `:` or `.` or `!` or `as` or `=` or `?` or `(` or `is` or binary operator or `;`',
    --parser = 'line 1 : after `nt` : expected `[` or `:` or `.` or `!` or `as` or `=` or `:=` or `(`',
    --parser = 'line 1 : after `nt` : expected `[` or `:` or `.` or `!` or `=` or `(`',
}
Test { [[var integer sizeof;]],
    parser = "line 1 : after `integer` : expected type modifier or internal identifier",
}
Test { [[escape sizeof(integer);]], stmts='line 1 : invalid `escape` : types mismatch : "int" <= "usize"' }
Test { [[escape sizeof(int) as int;]], run=4 }
Test { [[escape 1<2>3;]],
    dcls = 'line 1 : invalid operand to `>` : expected numeric type',
}
Test { [[escape (((1<2) as int)<3) as int;]], run=1 }

Test { [[
escape 0x1 + 0X1 + 001;
]],
    run = 3,
}

Test { [[
escape 077;
]],
    run = 77,
}

Test { [[
escape 0x1 + 0X1 + 0a01;
]],
    adjs = 'line 1 : malformed number',
}

Test { [[
escape 1.;
]],
    stmts = 'line 1 : invalid `escape` : types mismatch : "int" <= "real"',
    --run = 1,
}

Test { [[
var integer x = 1;
escape x;
]],
    run = 1,
}

Test { [[
var real x = 1.5;
escape (x + 0.5) as int;
]],
    run = 2,
}

Test { [[
var uint x = 1.5;
escape x + (0.5 as uint);
]],
    stmts = ' line 1 : invalid assignment : types mismatch : "uint" <= "real"',
}

Test { [[
var uint x = (1.5 as uint);
escape (x + (0.5 as uint)) as integer;
]],
    run = 1,
}

Test { [[
var byte x = (1.5 as byte);
escape (x + (0.5 as byte)) as int;
]],
    run = 1,
}

Test { [[
var byte x = 255;
escape ( x + (0.5 as byte) )as int;
]],
    run = 255,
}

Test { [[
var ssize n = 10;
    if n == 0 then
        escape 0;
    else
        escape n as integer;
    end
]],
    run = 10,
}

Test { [[
var usize u = 10;
var ssize s = u;
escape s as int;
]],
    run = 10,
}

Test { [[
var ssize s = sizeof(u32);
escape s as int;
]],
    run = 4,
}

Test { [[
var ssize s = 10;
var usize u = s;
escape u as int;
]],
    stmts = 'line 2 : invalid assignment : types mismatch : "usize" <= "ssize"',
}

Test { [[
var uint x = 1.5;
escape x + 0.5;
]],
    dcls = 'line 2 : invalid operands to `+` : incompatible numeric types : "uint" vs "real"',
}

Test { [[
escape *1;
]],
    --parser = 'line 1 : after `*` : expected location',
    --dcls = 'line 1 : invalid operand to `*` : expected location',
    dcls = 'line 1 : invalid operand to `*` : expected pointer type',
    --dcls = 'line 1 : invalid operand to `*` : unexpected context for value "1"',
}

Test { [[
escape &&1;
]],
    --parser = 'line 1 : after `&&` : expected location',
    --dcls = 'line 1 : invalid operand to `&&` : unexpected context for value "1"',
    dcls = 'line 1 : expected native type',
    --dcls = 'line 1 : invalid operand to `&&` : expected location',
    --dcls = 'line 1 : invalid expression : operand to `&&` must be a name',
}

Test { [[
var integer x = 1;
escape &&x == &&x as int ();
]],
    parser = 'line 2 : after `x` : expected `[` or `:` or `.` or `!` or `?` or `(` or binary operator or `;`',
    --run = 1,
}

Test { [[
var integer x = 1;
escape *&&x;
]],
    --parser = 'line 2 : after `*` : expected location',
    --dcls = 'line 2 : invalid operand to `*` : expected location',
    --dcls = 'line 2 : invalid operand to `*` : unexpected context for value "x"',
    run = 1,
}

Test { [[
var int x = 1;
escape *&&*&&x;
]],
    --parser = 'line 2 : after `*` : expected location',
    --dcls = 'line 2 : invalid operand to `*` : expected location',
    dcls = 'line 2 : expected native type',
    --run = 1,
}

Test { [[
escape not 1;
]],
    dcls = 'line 1 : invalid operand to `not` : expected boolean type',
}
Test { [[
escape (not false) as int;
]],
    run = 1,
}

Test { [[
var real esp = 2 * 3.1415;
escape esp as int;
]],
    run = 6,
}

Test { [[
escape (1<<1) + (8>>2);
]],
    run = 4,
}

Test { [[
var int x = 0;
escape x.x;
]],
    dcls = 'line 2 : invalid member access',
}
--<<< EXPS / EXPRESSIONS

-->>> NATIVE

Test { [[
_f();
escape 0;
]],
    dcls = 'line 1 : native identifier "_f" is not declared',
}

Test { [[
native _f, _f;
escape 0;
]],
    dcls = 'line 1 : declaration of "_f" hides previous declaration (/tmp/tmp.ceu : line 1)',
}

Test { [[
native _f, _f;
escape 0;
]],
    dcls = ' line 1 : declaration of "_f" hides previous declaration (/tmp/tmp.ceu : line 1)',
}

Test { [[
native _f;
native _f;
escape 0;
]],
    dcls = 'line 2 : declaration of "_f" hides previous declaration (/tmp/tmp.ceu : line 1)',
}

Test { [[
native _f;
native/end;
native _g;
escape 0;
]],
    dcls = 'line 3 : native declarations are disabled',
}

Test { [[
native/pre do
    ##include <stdio.h>
end
native/pre do
    ##include <stdio.h>
end
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    ##include <stdio.h>
end
native/pos do
    ##include <stdio.h>
end
escape 1;
]],
    run = 1,
}

Test { [[
native _void;
var _void&& p = _;
var int x = p:get();
escape 1;
]],
    wrn = true,
    cc = '3:25: error: dereferencing ‘void *’ pointer',
}

Test { [[
native _t;
native/pre do
    typedef int t;
end
var _t x = 10;
escape x;
]],
    run = 10,
}

Test { [[
native _t;
native/pos do
    typedef int t;
end
var _t x = 10;
escape x;
]],
    cc = '5:1: error: unknown type name ‘t’',
}

Test { [[
input none A;
native _get_A_id;
native/pre do
    int get_A_id (void) {
        return CEU_INPUT_A;
    }
end
escape _get_A_id();
]],
    wrn = true,
    cc = '16: error: ‘CEU_INPUT_A’ undeclared (first use in this function)',
}

Test { [[
input none A;
native _get_A_id;
native/pos do
    int get_A_id (void) {
        return CEU_INPUT_A;
    }
end
escape _get_A_id();
]],
    wrn = true,
    run = 15,
}

Test { [[
native _V, _f;
escape _f(_V);
]],
    cc = '2:27: error: ‘V’ undeclared (first use in this function)',
}

Test { [[
var int x = 0;
code/tight Ff (none) -> int do
    outer.x = outer.x() - 1;
    escape x;
end
escape call Ff();
]],
    --run = 1,
    dcls = 'line 3 : invalid call : expected native type',
}

Test { [[
escape 1 + ({1.1 == 1} as int);
]],
    run = 1,
}

Test { [[
native/pre do
##if 1
    int X = 10;
##else
##error oi
##endif
end

{
    ##if 1
        X++;
    ##else
        ##error oi
    ##endif
}

native _X;
_X = _X + {
##if 1
    1
##else
    0
##endif
};

escape _X;
]],
    run = 12,
}

Test { [[
native/pre do
    void f (void* timer) {
        send();
    }
end
escape 1;
]],
    cc = '9: error: implicit declaration of function ‘send’',
}

Test { [[
native/pre do
    void f (void* timer) {
        send();
    }
end
]],
    cc = '9: error: implicit declaration of function ‘send’',
}

--<<< NATIVE

Test { [[var int a;]],
    dcls = 'line 1 : variable "a" declared but not used',
}

Test { [[var int a;]],
    wrn = true,
    --inits = 'uninitialized variable "a" : reached yielding statement (/tmp/tmp.ceu:1)',
    --inits = 'uninitialized variable "a" : reached `end of file` (/tmp/tmp.ceu:1)',
    run = false,
}

Test { [[var int a=0;]],
    ana = 'line 1 : missing `escape` statement for the block',
}

Test { [[var int a=0;]],
    run = false,
    wrn = true,
    _ana = {
        reachs = 1,
        isForever = true,
    }
}

Test { [[
native _x;
native/pos do
    int x = 1;
end
escape (_x);
]],
    run = 1,
}
Test { [[
escape (1+1).v;
]],
    --parser = 'line 1 : after `)` : expected `(` or `is` or `as` or binary operator or `;`',
    dcls = 'line 1 : invalid operand to `.` : expected native or data type',
}

Test { [[
var int a, b;
a=0; b=0;
escape 10;
]],
    parser = 'line 1 : after `a` : expected `=` or `;`',
    run = 10,
}

Test { [[a = 1; escape a;]],
    dcls = 'internal identifier "a" is not declared',
}
Test { [[var int a; a = 1; escape a;]],
    run = 1,
}
Test { [[var int a = 1; escape a;]],
    run = 1,
}
Test { [[var integer a = 1; escape (a);]],
    run = 1,
}
Test { [[var int a = 1;]],
    run = false,
    wrn = true,
    _ana = {
        reachs = 1,
        isForever = true,
    }
}
Test { [[var integer a=1;var integer a=0; escape a;]],
    dcls = 'line 1 : declaration of "a" hides previous declaration',
}
Test { [[var int a=1;var int a=0; escape a;]],
    --dcls = 'line 1 : internal identifier "a" is already declared at line 1',
    wrn = true,
    run = 0,
}
Test { [[var int b=2; var int a=1; b=a; var int a=0; escape b+a;]],
    wrn = true,
    --dcls = 'line 1 : internal identifier "a" is already declared at line 1',
    run = 1,
}
Test { [[do var int a=1; end var int a=0; escape a;]],
    tmp = 'error: variable ‘__ceu_a_1’ set but not used',
    --run = 0,
}
Test { [[var int a=1; var int a=0; escape a;]],
    wrn = true,
    --dcls = 'line 1 : internal identifier "a" is already declared at line 1',
    run = 0,
}
Test { [[var int a; a = b = 1]],
    --parser = "line 1 : after `b` : expected `(` or `[` or `:` or `.` or `?` or `!` or `is` or `as` or binary operator or `;`",
    parser = 'line 1 : after `b` : expected `[` or `:` or `.` or `!` or `as` or `..` or `?` or `(` or `is` or binary operator or `;`',
}
Test { [[var int a = b; escape 0;]],
    dcls = 'internal identifier "b" is not declared',
}
Test { [[escape 1;2;]],
    parser = "line 1 : after `;` : expected end of file",
}
Test { [[escape 1;2]],
    parser = "line 1 : after `;` : expected end of file",
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
    run = false,
    wrn = true,
    _ana = {
        reachs = 1,
        isForever = true,
    }
}

-- PRECEDENCE (TODO)
Test { [[
var int v;
v = false;
]],
    stmts = 'line 2 : invalid assignment : types mismatch : "int" <= "bool"',
}
Test { [[
var int v1 = ((1 + 1) as bool) and (0 as bool);    // 0
escape 0;
]],
    stmts = 'line 1 : invalid assignment : types mismatch : "int" <= "bool"',
}

Test { [[
native do
end
]],
    parser = 'line 1 : after `native` : expected `/pre` or `/pos` or `/` or native identifier',
}

Test { [[
native/pos do
    ##include <assert.h>
end
native _assert;
var bool v1 = ((1 + 1) as bool) and (0 as bool);    // 0
_assert(v1 == false);

var bool v2 = ((1 + 1) as bool) or  (0 as bool);    // 1
_assert(v2 == true);

var bool v3 = false and false or true;   // 1
_assert(v3 == true);

var bool v4 = 0 == 0 | 1;     // 0
_assert(v4 == false);

var bool v5 = 0 == 0 & 0;     // 1
_assert(v5 == true);

escape 1;
]],
    run = 1,
}

Test { [[
inputintMY_EVT;
ifv==0thenbreak;end
]],
    --parser = 'line 1 : after `inputintMY_EVT` : expected `[` or `:` or `.` or `!` or `=` or `(`',
    --parser = 'line 2 : after `ifv` : `[` or `:` or `.` or `!` or `as` or `=` or `:=` or `(`',
    parser = 'line 2 : after `==` : expected expression',
    --parser = 'line 2 : after `0` : expected `(` or `[` or `:` or `.` or `?` or `!` or `is` or `as` or binary operator or `=` or `:=` or `;`',
}
Test { [[
inputintMY_EVT;
escape 1;
]],
    --parser = 'line 1 : after `inputintMY_EVT` : expected `[` or `:` or `.` or `!` or `=` or `(`',
    dcls = 'line 1 : internal identifier "inputintMY_EVT" is not declared',
}

Test { [[
// input event identifiers must be all in uppercase
// 'MY_EVT' is an event of ints
native_printf();
escape 0;
]],
    dcls = 'line 3 : internal identifier "native_printf" is not declared',
}

Test { [[
native_printf();
loopdo await250ms;_printf("Hello World!\n");end
]],
    --parser = 'line 2 : after `loopdo` : expected `[` or `:` or `.` or `!` or `=` or `(`',
    parser = 'line 2 : after `loopdo` : expected `[` or `:` or `.` or `!` or `as` or `=` or `?` or `(` or `is` or binary operator or `;`',
    --parser = 'line 2 : after `loopdo` : expected `(` or `[` or `:` or `.` or `?` or `!` or `is` or `as` or binary operator or `=` or `:=` or `;`',
}

Test { [[
input none A, A;
]],
    parser = 'line 1 : after `A` : expected `do` or `;`',
    --dcls = 'line 1 : declaration of "A" hides previous declaration (/tmp/tmp.ceu : line 1)',
}
Test { [[
input none A; input none A;
]],
    dcls = 'line 1 : declaration of "A" hides previous declaration (/tmp/tmp.ceu : line 1)',
}
Test { [[
input none A;
output none A;
]],
    dcls = 'line 2 : declaration of "A" hides previous declaration (/tmp/tmp.ceu : line 1)',
}

-->> TYPE / BOOL

Test { [[
input none A;
var bool a? = 1;
a? = 2;
escape a?;
]],
    parser = 'line 2 : after `a` : expected `=` or `;`',
    --run = 2,
}

Test { [[
input none A;
var bool a = 1;
a = 2;
escape a;
]],
    dcls = 'line 1 : external "A" declared but not used',
    --run = 2,
}

Test { [[
input none A;
var bool a;
a = 2;
escape a;
]],
    wrn = true,
    stmts = 'line 3 : invalid assignment : types mismatch : "bool" <= "int"',
}

Test { [[
input none A;
var bool a = 1;
escape a;
]],
    wrn = true,
    stmts = 'line 2 : invalid assignment : types mismatch : "bool" <= "int"',
}

Test { [[
input none A;
var bool a = (1 as bool);
a = (2 as bool);
escape a as int;
]],
    wrn = true,
    run = 1,
}

Test { [[
output none O;
await O;
escape 1;
]],
    stmts = 'line 2 : invalid `await` : expected `input` external identifier',
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

Test { [[
input none A;
var yes/no a? = 1;
a? = 2;
escape a?;
]],
    parser = 'line 2 : after `a` : expected `=` or `;`',
    --run = 2,
}

Test { [[
input none A;
var on/off a = 1;
a = 2;
escape a;
]],
    dcls = 'line 1 : external "A" declared but not used',
    --run = 2,
}

Test { [[
input none A;
var on/off a;
a = 2;
escape a;
]],
    wrn = true,
    stmts = 'line 3 : invalid assignment : types mismatch : "bool" <= "int"',
}

Test { [[
input none A;
var yes/no a = 1;
escape a;
]],
    wrn = true,
    stmts = 'line 2 : invalid assignment : types mismatch : "bool" <= "int"',
}

Test { [[
input none A;
var yes/no a = (1 as bool);
a = (2 as on/off);
escape a as int;
]],
    wrn = true,
    run = 1,
}

Test { [[
output none O;
await O;
escape 1;
]],
    stmts = 'line 2 : invalid `await` : expected `input` external identifier',
}

Test { [[
var yes/no v = on;
v = no;
if v then
    escape 1;
else
    escape 2;
end
]],
    run = 2,
}

Test { [[
var on/off v = off;
v = yes;
if v then
    escape 1;
else
    escape 2;
end
]],
    run = 1,
}

--<< TYPE / BOOL


Test { [[
var u8 u = 10;
var byte b = u;
escape b;
]],
    run = 10,
}

-- TYPE / NATIVE / ANNOTATIONS

Test { [[
escape 1;
native/pos do end
]],
    run = 1,
}

Test { [[
native/pos do
    int _ = 3;
end
native/const __;

var integer _ = 1;
var integer _ = 2;

escape __;
]],
    parser = 'line 6 : after `integer` : expected type modifier or internal identifier',
    --parser = 'line 6 : after `=` : expected class identifier',
    --env = 'line 6 : invalid access to `_`',
    --dcls = 'line 6 : internal identifier "_" is not declared',
    --run = 3,
}
Test { [[
native/pos do
    int _ = 3;
end
native/const __;
native/const _;      // `_` is special (not C)

var int _ = 1;
var int _ = 2;

escape __;
]],
    parser = 'line 5 : after `const` : expected native identifier',
    --run = 3,
}
Test { [[
native/pos do
    int _ = 3;
end
native/const __;

var int _;
var int _;
do
    var byte _;
end

escape (int) __;
]],
    parser = 'line 6 : after `int` : expected type modifier or internal identifier',
    --parser = 'line 6 : after `_` : expected `with`',
    --run = 3,
}

Test { [[
native _f,_int;
native/pos do
    int f () { return 1; }
end
var _int x = _f() as /plain;
escape x;
]],
    wrn = true,
    run = 1,
}
Test { [[
native _int;
native/pure _f;
native/pos do
    int f () { return 1; }
end
var _int x = _f();
escape x;
]],
    wrn = true,
    run = 1,
}
Test { [[
native _int, _f;
native/pos do
    int f () { return 1; }
end
var _int x = (_f as /pure)();
escape x;
]],
    wrn = true,
    run = 1,
}
Test { [[
native _f;
native/pos do
    none* V;
    int f (none* v) { return 1; }
end
var none&& ptr = null;
var int x = (_f as/nohold)(ptr);
escape x;
]],
    wrn = true,
    run = 1,
}
Test { [[
native _f;
native/pos do
    none* V;
    int f (none* v) { return 1; }
end
var none&& ptr = null;
var int x = (_f as/pure)(ptr);
escape x;
]],
    wrn = true,
    run = 1,
}

Test { [[
var none&& ptr = _;

native/nohold _free1;
_free1(ptr);

native _free2;
(_free2 as /nohold)(ptr);

native/pure _strchr1;
var none&& found1 = _strchr1(ptr);

native _strchr2;
var _char&& found2 = (_strchr2 as /pure)(ptr);

native _tp, _f;
var _tp v = _f() as /plain;
]],
    wrn = true,
    cc = '16:1: error: unknown type name ‘tp’',
}

Test { [[
native/pos do
    ##ifndef CEU_EXTS
    ##error bug found
    ##endif
end
escape 1;
]],
    todo = 'defines',
    run = 1,
    cc = 'error: #error bug found',
}

Test { [[
native/pos do
    ##ifndef CEU_EXTS
    ##error bug found
    ##endif
    ##ifdef CEU_WCLOCKS
    ##error bug found
    ##endif
    ##ifdef CEU_INTS
    ##error bug found
    ##endif
    ##ifdef CEU_THREADS
    ##error bug found
    ##endif
    ##ifdef CEU_ORGS
    ##error bug found
    ##endif
    ##ifdef CEU_IFCS
    ##error bug found
    ##endif
    ##ifdef CEU_CLEAR
    ##error bug found
    ##endif
    ##ifdef CEU_PSES
    ##error bug found
    ##endif
    ##ifndef CEU_RET
    ##error bug found
    ##endif
    ##ifdef CEU_LUA
    ##error bug found
    ##endif
    ##ifdef CEU_VECTOR
    ##error bug found
    ##endif
end

input none A;
var int a = 1;
a = 2;
escape a;
]],
    todo = 'defines',
    wrn = true,
    run = 2,
}

Test { [[
input none A;
var usize a = 1;
a = 2;
escape a as int;
]],
    wrn = true,
    run = 2,
}

Test { [[
input none A;
var byte a = 1;
a = 2;
escape a as int;
]],
    wrn = true,
    run = 2,
}

Test { [[
escape a && b;
]],
    parser = 'line 1 : after `a` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `;`',
}

Test { [[
native _ISPOINTER, _MINDIST, _TILESHIFT;

                            if (_ISPOINTER(check) && ((check:x+_MINDIST) >>
                                _TILESHIFT) == tilex ) then
                                escape 0;
end
]],
    parser = 'line 3 : after `)` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `)`',
    --dcls = 'line 3 : internal identifier "check" is not declared',
}

    -- IF

Test { [[if 1 then escape 1; end; escape 0;]],
    stmts = 'line 1 : invalid `if` condition : expected boolean type',
}
Test { [[if true then escape 1; end; escape 0;]],
    _ana = {
        isForever = false,
    },
    run = 1,
}
Test { [[if false then escape 0; end  escape 1;]],
    run = 1,
}
Test { [[if false then escape 0; else escape 1; end]],
    _ana = {
        isForever = false,
    },
    run = 1,
}
Test { [[if (false) then escape 0; else escape 1; end;]],
    run = 1,
}
Test { [[if (true) then escape (1); end]],
    _ana = {
        reachs = 1,
    },
    run = 1,
}
Test { [[
if (false) then
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
Test { [[
if (true) then
else
    escape 0;
end;
]],
    run = '1] -> runtime error: reached end of `do`',
    _ana = {
        reachs = 1,
    },
    _opts = { ceu_features_trace='true' },
    --run = '1] runtime error: missing `escape` statement',
}

-- IF vs Seq priority
Test { [[if true then var int a=0; if a!=0 then end; escape 2; else escape 3; end;]],
    run = 2,
}

Test { [[
if false then
    escape 1;
else
    if true then
        escape 1;
    end
end;]],
    _ana = {
        reachs = 1,
    },
    run = 1,
}
Test { [[
if false then
    escape 1;
else
    if false then
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
if b!=0 then
    escape 1;
else
    escape 2;
end;
]],
    run = 2,
}
Test { [[
var int a;
if false then
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
var int c = 0;
if false then
    a = 1;
    a = 1;
else
    a = 2;
    c = a;
end;
escape a+c;
]],
    run = 4,
    --ref = 'line 5 : invalid extra access to variable "a" inside the initializing `if-then-else`',
}
Test { [[
var int a;
var int c = 0;
if false then
    a = 1;
    c = a;
else
    a = 2;
    c = a;
end;
escape a+c;
]],
    run = 4,
}
Test { [[
var integer a;
var integer c = 0;
if false then
    c = a;
    a = 1;
else
    a = 2;
    c = a;
end;
escape a+c;
]],
    inits = 'line 1 : uninitialized variable "a" : reached read access (/tmp/tmp.ceu:4)',
    --ref = 'line 4 : invalid access to uninitialized variable "a"',
}
Test { [[
var int a;
if true then
    a = 1;
    if true then
        a = 2;
    end;
end;
escape a;
]],
    inits = 'line 1 : uninitialized variable "a" : reached end of `if` (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "a" : reached read access (/tmp/tmp.ceu:8)',
    --ref = 'line 5 : missing initialization for variable "a" in the other branch of the `if-then-else`',
}
Test { [[
var int a;
if true then
    if true then
        a = 2;
    else
        a = 0;
    end;
else
    a = 10;
end;
escape a;
]],
    run = 2,
}
Test { [[
var int a;
if true then
    a = 1;
    if true then
        a = 2;
    else
        a = 0;
    end;
else
    a = 10;
end;
escape a;
]],
    run = 2,
}
Test { [[
var int a;
var int b = a;
a = 1;
]],
    inits = 'line 1 : uninitialized variable "a" : reached read access (/tmp/tmp.ceu:2)',
}

Test { [[
var int a;
if true then
    a = 2;
end;
a = 1;
escape a;
]],
    inits = 'line 1 : uninitialized variable "a" : reached end of `if` (/tmp/tmp.ceu:2)',
    --run = 1,
}
Test { [[
var int a;
if true then
    a = 2;
else/if true then
else
    a = 1;
end;
a = 1;
escape a;
]],
    inits = 'line 1 : uninitialized variable "a" : reached end of `if` (/tmp/tmp.ceu:2)',
    --run = 1,
}
Test { [[
var int a;
if true then
    a = 2;
else/if true then
    a = 1;
else
end;
a = 1;
escape a;
]],
    inits = 'line 1 : uninitialized variable "a" : reached end of `if` (/tmp/tmp.ceu:2)',
    --run = 1,
}
Test { [[
var int a;
if true then
    a = 2;
else/if true then
    if true then
        a = 1;
    end
else
end;
a = 1;
escape a;
]],
    inits = 'line 1 : uninitialized variable "a" : reached end of `if` (/tmp/tmp.ceu:5)',
    --run = 1,
}
Test { [[
var int a;
if true then
else
    a = 2;
end;
a = 1;
escape a;
]],
    inits = 'line 1 : uninitialized variable "a" : reached end of `if` (/tmp/tmp.ceu:2)',
    --run = 1,
}
Test { [[
var int a;
if true then
else
end;
a = 1;
escape a;
]],
    run = 1,
}
Test { [[
var int a;
if true then
    a = 1;
    if true then
        a = 2;
    else
        a = 0;
    end;
end;
escape a;
]],
    inits = 'line 1 : uninitialized variable "a" : reached end of `if` (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "a" : reached read access (/tmp/tmp.ceu:10)',
    --inits = 'line 3 : missing initialization for variable "a" in the other branch of the `if-then-else` (/tmp/tmp.ceu:2)',
}
Test { [[
var int a;
if false then
    escape 1;
else
    a=1;a=2; escape 3;
end;
]],
    --inits = 'line 1 : uninitialized variable "a" : reached end of `if` (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "a" : reached `escape` (/tmp/tmp.ceu:3)',
    --ref = 'line 5 : invalid extra access to variable "a" inside the initializing `if-then-else` (/tmp/tmp.ceu:2)',
    run = 3,
}
Test { [[
var int a;
if false then
    a=1;a=2; escape 3;
else
    escape 1;
end;
]],
    --inits = 'line 1 : uninitialized variable "a" : reached end of `if` (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "a" : reached `escape` (/tmp/tmp.ceu:5)',
    --ref = 'line 5 : invalid extra access to variable "a" inside the initializing `if-then-else` (/tmp/tmp.ceu:2)',
    run = 1,
}
Test { [[
var int a=1;
if false then
    escape 1;
else
    a=1;a=2; escape 3;
end;
]],
    run = 3,
}
Test { [[
var int a;
if false then
    a = 1;
    escape 1;
else
    a=2; escape 3;
end;
]],
    run = 3,
}
Test { [[
var int a = 0;
if (false) then
    a = 1;
end
escape a;
]],
    run = 0,
}

Test { [[
var int x;
if false then
    escape 1;
end
x = 10;
escape x;
]],
    --run = 10,
    --inits = 'line 1 : uninitialized variable "x" : reached `escape` (/tmp/tmp.ceu:3)',
    inits = 'line 1 : uninitialized variable "x" : reached end of `if` (/tmp/tmp.ceu:2)',
}

Test { [[
var int x;
if false then
    escape 1;
else
    escape x;
end
x = 10;
escape x;
]],
    inits = 'line 1 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:5)',
    --inits = 'line 1 : uninitialized variable "x" : reached `escape` (/tmp/tmp.ceu:3)',
}

    -- EVENTS

Test { [[input int A=1;
]],
    parser="line 1 : after `A` : expected `do` or `;`"
}

Test { [[input int A=1;]],
    parser="line 1 : after `A` : expected `do` or `;`"
}

Test { [[
input int A;


A=1;
]],
    parser = 'line 1 : after `;` : expected statement',
    --parser = 'line 4 : after `A` : expected `(`',
}

Test { [[
input int A;
A=1;
escape 1;
]],
    --adj = 'line 2 : invalid expression',
    parser = 'line 1 : after `;` : expected statement',
    --parser = 'line 2 : after `A` : expected `(`',
    --parser = 'line 1 : after `;` : expected statement (usually a missing `var` or C prefix `_`)',
}

Test { [[input  int A;]],
    wrn = true,
    run = false,
    _ana = {
        reachs = 1,
        isForever = true,
    },
}
Test { [[input int A; input int A; escape 0;]],
    dcls = 'line 1 : declaration of "A" hides previous declaration (/tmp/tmp.ceu : line 1)',
    --dcls = 'line 1 : identifier "A" is already declared (/tmp/tmp.ceu : line 1)',
    --dcls = 'external "A" is already declared',
    run = 0,
}
Test { [[
input int A; input int B; input int Z;
]],
    wrn = true,
    run = false,
    _ana = {
        reachs = 1,
        isForever = true,
    },
}

Test { [[await A; escape 0;]],
    dcls = 'external identifier "A" is not declared',
}

Test { [[
var int ret=0;
par/and do
    ret = 1;
with
    ret = 2;
end
escape ret;
]],
    run = 2,
}
Test { [[
var int ret=0;
par/or do
    ret = 1;
with
    ret = 2;
end
escape ret;
]],
    run = 1,
}
Test { [[
async do
end
escape 1;
]],
    parser = 'line 1 : after `begin of file` : expected statement',
}
Test { [[
input none A;
par/or do
    await A;
with
    await async do
        emit A;
    end
end
escape 1;
]],
    run = 1,
}
Test { [[
input none A;
par/or do
    await A;
with
    await async do
        emit A;
    end
    await FOREVER;
end
escape 1;
]],
    run = 1,
}
Test { [[
input none A;
await A;
escape 1;
]],
    run = { ['~>A']=1 },
}
Test { [[
input none A;
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
input none A;
var int ret = 0;
par/or do
    await A;
    ret = 10;
with
    await async do
        emit A;
    end
    await FOREVER;
end;
escape ret;
]],
    run = 10,
}
Test { [[
input int A;
par/or do
    await A;
with
    await async do
        emit A(10);
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
await async do
    loop _ in [0 -> 50[ do
        emit 100ms;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
input int A;
var int v;
v = await A until 1;
escape v;
]],
    stmts = 'line 3 : invalid expression : `until` condition must be of boolean type',
}
Test { [[
input int A;
var bool v;
v = await A;
escape v as int;
]],
    stmts = 'line 3 : invalid assignment : types mismatch : "(bool)" <= "(int)"',
}

Test { [[
input int A;
var int ret=0;
par/or do
    ret = await A;
with
    await async do
        emit A(10);
    end;
end
escape ret;
]],
    run = 10
}

Test { [[
input int A;
var int ret;
par/or do
    ret = await A;
with
    await async do
        emit A(10);
    end;
end
escape ret;
]],
    inits = 'line 2 : uninitialized variable "ret" : reached end of `par/or` (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "ret" : reached yielding statement (/tmp/tmp.ceu:3)',
}

Test { [[
input int A;
par/and do
    await A;
with
    await async do
        emit A(10);
    end;
end;
escape A;
]],
    parser = "line 9 : after `escape` : expected expression",
    --parser = 'line 9 : after `A` : expected `(`',
    --adj = 'line 9 : invalid expression',
}

Test { [[
input int A;
var int v=0;
par/and do
    v = await A;
with
    await async do
        emit A(10);
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
    inits = 'line 1 : uninitialized variable "a" : reached read access (/tmp/tmp.ceu:1)',
    --dcls = 'internal identifier "a" is not declared',
    --todo = 'TODO: deveria dar erro!',
    --run = 100,
}

Test { [[var int a; a = emit a(1; escape a);]],
    --parser = 'line 1 : after `=` : expected expression',
    parser = "line 1 : after `emit` : expected number or `(` or external identifier",
    --trig_wo = 1,
}

Test { [[var int a; emit a(1); escape a;]],
    stmts = 'line 1 : invalid `emit` : unexpected context for variable "a"',
    --env = 'line 1 : identifier "a" is not an event (/tmp/tmp.ceu : line 1)',
    --trig_wo = 1,
}

Test { [[
input none A;
par/and do
    var int i;
    loop i in [0->21845[ do
        await A;
    end
with
    await async do
        var int i;
        loop i in [0->21845[ do
            emit A;
        end
    end
end
escape 1;
]],
    run = 1,
}

    -- WALL-CLOCK TIME / WCLOCK

Test { [[
input none A;
await A;
escape 0;
]],
    run = { ['~>10ms; ~>A'] = 0 }
}

Test { [[await -1ms; escape 0;]],
    --ast = "line 1 : after `await` : expected event",
    --parser = 'line 1 : after `1` : expected `;`',
    --parser = 'line 1 : after `1` : expected `(` or `[` or `:` or `.` or `?` or `!` or `is` or `as` or binary operator or `until` or `;`',
    --parser = 'line 1 : after `await` : expected `async` or `async/thread` or number or `(` or abstraction identifier or external identifier or location or `{` or `pause` or `resume` or `FOREVER`',
    parser = 'line 1 : after `await` : expected `async` or `async/thread` or number or `(` or location or `{` or abstraction identifier or external identifier or `pause` or `resume` or `FOREVER`',
}

Test { [[await 1; escape 0;]],
    parser = 'line 1 : after `1` : expected `h` or `min` or `s` or `ms` or `us`',
}
Test { [[await -1; escape 0;]],
    --parser = 'line 1 : after `await` : expected `async` or `async/thread` or number or `(` or abstraction identifier or external identifier or location or `{` or `pause` or `resume` or `FOREVER`',
    parser = 'line 1 : after `await` : expected `async` or `async/thread` or number or `(` or location or `{` or abstraction identifier or external identifier or `pause` or `resume` or `FOREVER`',
    --env = 'line 1 : event "?" is not declared',
}

Test { [[
par/or do
    await 1s;
with
    await async do
        emit 1s;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
par do
    var int v = await 1us;
    escape v;
with
    await async do
        emit 2us;
    end
end
]],
    run = 1,
}

Test { [[var s32 a=await 10s; escape (a==8000000) as int;]],
    _ana = {
        isForever = false,
    },
    run = {
        ['~>10s'] = 0,
        ['~>9s ; ~>9s'] = 1,
    },
}

Test { [[await FOREVER;]],
    run = false,
    _ana = {
        isForever = true,
    },
}

-- tests var.isTmp
Test { [[
native ___ceu_a_1;
var int a = await 999ms;
escape a + ___ceu_a_1;
]],
    todo = 'var.is_tmp',
    run = { ['~>1s']=2000 },
}

Test { [[await FOREVER; await FOREVER;]],
    parser = "line 1 : after `;` : expected end of file",
}
Test { [[await FOREVER; escape 0;]],
    parser = "line 1 : after `;` : expected end of file",
}

Test { [[emit 1ms; escape 0;]],
    props_ = 'line 1 : invalid `emit` : expected enclosing `async` or `async/isr`',
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
await async do
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
await async do
    emit 1min;
    escape 10;
end;
escape a + 1;
]],
    --dcls = 'line 1 : internal identifier "_ret" is not declared',
    --props = 'line 4 : not permitted inside `async`',
    --props = 'line 4 : not permitted across `async` declaration',
    dcls = 'line 4 : invalid `escape` : no matching enclosing `do`',
}

Test { [[
var int a;
await async (a) do
    a = 1;
end;
escape a + 1;
]],
    --inits = 'line 1 : uninitialized variable "a" : reached `async` (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "a" : reached yielding statement (/tmp/tmp.ceu:2)',
    run = 2,
}

Test { [[
var int a;
var& int pa = &a;
await async (pa) do
    emit 1min;
    pa = 10;
end;
escape a + 1;
]],
    inits = 'line 1 : uninitialized variable "a" : reached read access (/tmp/tmp.ceu:2)',
}

Test { [[
var int a = 0;
var& int pa = &a;
await async (pa) do
    emit 1min;
    pa = 10;
end;
escape a + 1;
]],
    run = 11,
}

Test { [[
var int diff = 290 - 48;
await (1.1)ms;
escape 1;
]],
    stmts = 'line 2 : invalid expression : expected integer type',
}
Test { [[
var int diff = 290 - 48;
await (1.1 as int)ms;
escape 1;
]],
    run = {['~>2ms']=1},
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
input int A; input int B;
await A;
var int v = await B;
escape v;
]],
    run = {
        ['3~>A ; 1~>B'] = 1,
        --['1~>B ; 2~>A ; 3~>B'] = 3,
    }
}

Test { [[
var bool a;
a = await 10ms;
escape a as int;
]],
    stmts = 'line 2 : invalid assignment : types mismatch : "bool" <= "int"',
}
Test { [[
var bool a = await 10ms;
escape a;
]],
    stmts = 'line 1 : invalid assignment : types mismatch : "bool" <= "int"',
}
Test { [[
par do
    var int a = await 10us;
    escape a;
with
    await async do
        emit 11us;
    end
end
]],
    run = 1,
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
    run = false,
    _ana = {
        unreachs = 2,
        isForever = true,
    },
}

Test { [[
var int ret=0;
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
    ret = 1;
with
    ret = 2;
end
escape ret;
]],
    run = 1,
    --inits = 'line 1 : uninitialized variable "ret" : reached yielding statement (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "ret" : reached `par/or` (/tmp/tmp.ceu:2)',
    --ref = 'line 1 : uninitialized variable "ret" crossing compound statement (/tmp/tmp.ceu:2)',
}

Test { [[
var int ret;
par do
    ret = 1;
    escape ret;
with
    ret = 2;
    escape ret;
end
]],
    run = 1,
    --inits = 'line 1 : uninitialized variable "ret" : reached yielding statement (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "ret" : reached `par/or` (/tmp/tmp.ceu:2)',
    --ref = 'line 1 : uninitialized variable "ret" crossing compound statement (/tmp/tmp.ceu:2)',
}

Test { [[
var int ret;
par/and do
    ret = 1;
with
    ret = 2;
end
escape ret;
]],
    run = 2,
    --inits = 'line 1 : uninitialized variable "ret" : reached yielding statement (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "ret" : reached `par/or` (/tmp/tmp.ceu:2)',
    --ref = 'line 1 : uninitialized variable "ret" crossing compound statement (/tmp/tmp.ceu:2)',
}

Test { [[
var int ret=0;
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
var int ret=0;
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
var int ret=0;
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
var int ret=0;
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
input none B;
var int ret = 0;
par/or do
    await 2s;   // 4
    ret = 10;
    await B;    // 6
with
    await 1s;   // 8
    ret = 1;
    await B;    // 10
end
escape ret;
]],
    _ana = {
        acc = 1,  -- false positive
        abrt = 3,
    },
    run = { ['~>1s; ~>B']=1 },
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
    run = false,
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
    run = false,
    _ana = {
        isForever = true,
    }
}

Test { [[
input none HELLO;
input none WORLD;
par do      // par/and, par/or would behave the same
    loop do
        await HELLO;
        _printf("Hello!\n");
    end
with
    loop do
        await WORLD;
        _printf("World!\n");
    end
end

escape 0;
]],
    parser = 'line 13 : after `end` : expected `;` or end of file',
}

Test { [[
par do
    await FOREVER;
with
    await FOREVER;
end
]],
    run = false,
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
    run = false,
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
    input none A;
    var int v1=4; var int v2=4;
    par/or do
        await A;
        v1 = 1;
    with
        await A;
        v2 = 2;
    end
    escape v1 + v2;
]],
    run = { ['~>A']=5 },
    --run = 3,
    --todo = 'nd excpt',
}

Test { [[
par do
    var int v1=4; var int v2=4;
    par/or do
        await 10ms;
        v1 = 1;
    with
        await 10ms;
        v2 = 2;
    end
    escape v1 + v2;
with
    await async do
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
input int A; input int B;
var int ret;
if true then
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
if true then
    v = await A;
else
    v = 0;
end;
escape v;
]],
    run = {
        ['1~>A ; 0~>A'] = 1,
    },
}

Test { [[
input int A;
var int v;
if true then
    v = await A;
end;
escape v;
]],
    inits = 'line 2 : uninitialized variable "v" : reached end of `if` (/tmp/tmp.ceu:3)',
    --ref = 'line 4 : missing initialization for variable "v" in the other branch of the `if-then-else` (/tmp/tmp.ceu:3)',
}

Test { [[
input int A;
var int v = 0;
if false then
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

-->>> DO/_, SETBLOCK, ESCAPE

Test { [[
do/
    escape/A 1;
end
]],
    parser = 'line 1 : after `do` : expected internal identifier',
}

Test { [[
do/A
    escape/ 1;
end
]],
    parser = 'line 1 : after `do` : expected internal identifier',
}

Test { [[
do/a
    escape/ 1;
end
]],
    parser = 'line 2 : after `escape` : expected internal identifier',
}

Test { [[
do/a
    escape/a 1;
end
]],
    dcls = 'line 1 : internal identifier "a" is not declared',
}

Test { [[
var int a;
do/a
    escape/a 1;
end
]],
    dcls = 'line 3 : invalid `escape` : unexpected expression',
}

Test { [[
var int x = do/x
    escape/x;
end;
]],
    dcls = 'line 2 : invalid `escape` : expected expression',
}

Test { [[
var int a;
do/a
end
a = 1;
escape a;
]],
    run = 1,
}

Test { [[
var int a;
do/a
    escape/a;
end
a = 1;
escape a;
]],
    run = 1,
    --inits = 'line 1 : uninitialized variable "a" : reached `escape` (/tmp/tmp.ceu:3)',
}

Test { [[
var int a;
do/a
    escape;
end
]],
    dcls = 'line 3 : invalid `escape` : expected expression',
}

Test { [[
var int a = 0;
do/a
    escape 1;
end
]],
    run = 1,
}

Test { [[
do
    escape;
end;
escape 1;
]],
    run = 1,
}
Test { [[
var int a = 0;
do/a
    escape/a;
end;
escape 1;
]],
    run = 1,
}
Test { [[
var bool a = do/a
    escape/a 1;
end;
escape 1;
]],
    stmts = 'line 2 : invalid `escape` : types mismatch : "bool" <= "int"',
}

Test { [[
var bool a = do/a
    escape/a 1 as bool;
end;
escape 1;
]],
    run = 1,
}

Test { [[
var bool a = do/a
    escape/a;
end;
escape 1;
]],
    dcls = 'line 2 : invalid `escape` : expected expression',
}

Test { [[
var int a = do/a
    escape/a 1;
end;
escape 1;
]],
    run = 1,
}

Test { [[
var int a = do
end;
escape a;
]],
    --inits = 'line 1 : uninitialized variable "a" : reached end of `do` (/tmp/tmp.ceu:1)',
    run = '1] -> runtime error: reached end of `do`',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int a = do
    var int a = do/a
        escape/a 10;
    end;
    escape a;
end;
escape a-1;
]],
    wrn = true,
    run = 9,
}

Test { [[
var int a = do/a
    var int a = do/a
        escape/a 1;
    end;
    escape a;
end;
escape a+1;
]],
    wrn = true,
    run = 1
}

Test { [[
var int b = 0;
var int a = do/b
    var int a = do/a
        escape/a 1;
    end;
    escape a;
end;
escape a;
]],
    wrn = true,
    run = 1
}

Test { [[
var int a = do/a
    var int z = do/z
        escape/a 1;
    end;
    escape/a 10;
end;
escape a;
]],
    wrn = true,
    run = 1
}

Test { [[
var int a = do/a
    var int z = do/z
        escape/a 1;
    end;
    escape/z a;
end;
escape a;
]],
    dcls = 'line 5 : invalid `escape` : no matching enclosing `do`',
}

Test { [[
var u8&& ptr =
    par do
        //_idle();
        await FOREVER;
    with
        await 1s;
        escape null;
    end;
escape ptr == null;
]],
    parser = 'line 1 : after `=` : expected expression',
}
Test { [[
var u8&& ptr = do
    await 1s;
    escape null;
end;
escape 1;
]],
    run = {['~>1s']=1},
}
Test { [[
var u8&& ptr = do
    par do
        //_idle();
        await FOREVER;
    with
        await 1s;
        escape null;
    end
end;
escape (ptr == null) as int;
]],
    run = {['~>1s']=1},
}
Test { [[
var int ret =
    do/_
        if true then
            escape 1;
        end
        escape 0;
    end;
escape ret;
]],
    run = 1,
}

Test { [[
var int a = do end;
]],
    --parser = 'line 1 : after `do` : expected `/`',
    todo = 'forever'
}

Test { [[
a = do/a end;
]],
    dcls = 'line 1 : internal identifier "a" is not declared',
}

Test { [[
var int a = do/a end;
]],
    run = '1] -> runtime error: reached end of `do`',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int err = 99;
err = do ()
    var int err = 10;
    escape 1;
end;
escape err;
]],
    run = 1,
}
Test { [[
var int err = 99;
err = do ()
    var int err = 10;
    if true then
        escape 1;
    end
end;
escape err;
]],
    run = 1,
}

Test { [[
var int err = 99;
err = do ()
    do/_ escape 1; end
end;
escape err;
]],
    run = 1,
}
--<<< DO/_, SETBLOCK, ESCAPE

-->>> SPAWN / BLOCK

Test { [[
var int ret = 0;
spawn do
    ret = 1;
    await FOREVER;
end
escape ret;
]],
    run = 1,
}

Test { [[
native _CEU_APP;
spawn do
end
escape _CEU_APP.root.__mem.trails_n;
]],
    run = 3,
}
Test { [[
native _CEU_APP;
do finalize with
end
spawn do
end
escape _CEU_APP.root.__mem.trails_n;
]],
    run = 3,
}
Test { [[
native _CEU_APP;
do finalize with
    nothing;
end
spawn do
end
escape _CEU_APP.root.__mem.trails_n;
]],
    run = 5,
}
--<<< SPAWN / BLOCK

-->> DO / VISIBLE

Test { [[
var int a = 0;
do ()
    a = 1;
end
escape a;
]],
    dcls = 'line 3 : internal identifier "a" is not declared',
}

Test { [[
var int a = 0;
do (a)
    a = 1;
end
escape a;
]],
    run = 1
}

Test { [[
var int a = 0;
do
    a = 1;
end
escape a;
]],
    run = 1
}

Test { [[
var int a = 0;
do ()
    outer.a = 1;
end
escape a;
]],
    run = 1,
}

Test { [[
do/_
    var int a = 0;
    do ()
        outer.a = 1;
    end
    escape a;
end
]],
    run = 1,
}

Test { [[
do/_
    var int a = 0;
    var int b = 1;
    spawn (b) do
        every 1s do
            outer.a = outer.a + b;
        end
    end
    await 10s;
    escape a;
end
]],
    run = { ['~>10s']=10 },
}

Test { [[
var bool x = do ()
    escape true;
end;
escape x as int;
]],
    run = 1,
}

Test { [[
var bool x = do ()
    par do
        escape true;
    with
    end
end;
escape x as int;
]],
    run = 1,
}

Test { [[
native/pre do
    typedef struct t {
        int x;
    } t;
    t x;
end
native _x;
_x.x = do ()
    par do
        escape 1;
    with
    end
end;
escape _x.x;
]],
    run = 1,
}

Test { [[
data Dd with
    var int x = 10;
end
var Dd x = _;
x.x = do ()
    par do
        escape 1;
    with
    end
end;
escape x.x;
]],
    run = 1,
}

--<< DO / VISIBLE

Test { [[
input none A; input none B;
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
    await async do end
with
    await A;
    escape 1;
end
]],
    run = { ['1~>A']=1 },
}

Test { [[
par do
    await async do end
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
input none A; input none B;
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

-- testa ParOr que da clean em ParOr que ja terminou
Test { [[
input int A; input int B; input int C;
par/or do
    await A;
with
    await B;
end;

var int a=0;
par/or do
    a = 255+255+3;
with
    await C;
end;
escape a;
]],
    _ana = {
        --unreachs = 1,
        abrt = 1,
    },
    run = { ['1~>A;1~>C']=513, ['2~>B;0~>C']=513 },
}

Test { [[
input int A; input int B; input int C;
par/or do
    await A;
with
    await B;
end;

var int a;
par/or do
    a = 255+255+3;
with
    await C;
end;
escape a;
]],
    inits = 'line 8 : uninitialized variable "a" : reached end of `par/or` (/tmp/tmp.ceu:9)',
    --inits = 'line 8 : uninitialized variable "a" : reached yielding statement (/tmp/tmp.ceu:9)',
    --ref = 'line 8 : uninitialized variable "a" crossing compound statement (/tmp/tmp.ceu:9)',
}

Test { [[
input int A; input int B; input int C;
var int a=0;
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
    await C;
end;
escape a;
]],
    run = {
        ['1~>B; ~>20us; 1~>C'] = 1,
        ['~>20us; 5~>B; 2~>C'] = 10,
    }
}
Test { [[
var int a =
    do/_
        escape 1;
    end;
escape a;
]],
    run = 1,
}

Test { [[
native/const _V;
native/pos do
    int V = 0;
end
_V = 0;
escape _V;
]],
    stmts = 'line 5 : invalid assignment : read-only variable "_V"',
}
Test { [[
var int b = b;
escape 0;
]],
    inits = 'line 1 : uninitialized variable "b" : reached read access (/tmp/tmp.ceu:1)',
    --run = 1,
}
Test { [[
var int a = do escape a; end;
escape 0;
]],
    inits = 'line 1 : invalid access to variable "a" : assignment in enclosing `do` (/tmp/tmp.ceu:1)',
    --run = 1,
}
Test { [[
native _V;
native/pos do
    int V = 0;
end
    _V = do escape _V+1; end;
escape _V;
]],
    --inits = 'line 6 : invalid access to native "_V" : assignment in enclosing `do` (/tmp/tmp.ceu:5)',
    run = 1,
}
Test { [[
native _V;
native/pos do
    int V = 0;
end
_V = do
    escape 1;
end;
escape _V;
]],
    run = 1,
}
Test { [[
native _V;
native/pos do
    int V = 1;
end
var int v = do
    escape _V;
end;
escape v;
]],
    run = 1,
}

Test { [[
native/plain _t;
native/pos do
    typedef struct {
        int v;
    } t;
end
var _t t = _;
t.v = do
    escape t.v;
end;
escape t.v;
]],
    wrn = true,
    inits = 'line 9 : invalid access to variable "t" : assignment in enclosing `do` (/tmp/tmp.ceu:8)',
}

Test { [[
native/plain _t;
native/pos do
    typedef struct {
        int v;
    } t;
end
var _t t = _;
escape 0;
]],
    wrn = true,
    cc = 'error: unknown type name ‘t’',
}

Test { [[
native/plain _t;
native/pre do
    typedef struct {
        int v;
    } t;
end
var _t t = _;
t.v = do
    escape 1;
end;
escape t.v;
]],
    wrn = true,
    run = 1,
}

Test { [[
native/plain _t;
native/pre do
    typedef struct {
        int v;
    } t;
end
var int v = do
    var _t t = _;
    t.v = 1;
    escape t.v;
end;
escape v;
]],
    wrn = true,
    run = 1,
}

Test { [[
native/plain _char_const_ptr;
native/pre do
    typedef char* char_const_ptr;
end
var _char_const_ptr file = "xxx";
escape 1;
]],
    run = 1,
}

Test { [[
native/plain _u8;
var _u8&& cbuffer = {1}.get_data();
]],
    scopes = 'line 2 : invalid assignment : expected binding for "_{}"',
}

Test { [[
native/plain _xxx;
native/pre do
    typedef int xxx;
    ##define ff(x) x
end
var _xxx x = {ff}(1);
escape x;
]],
    run = 1,
}

Test { [[
var int a =
    do/_
        escape a;
    end;
escape a;
]],
    inits = 'line 3 : invalid access to variable "a" : assignment in enclosing `do` (/tmp/tmp.ceu:1)',
    --ref = 'line 3 : invalid access to uninitialized variable "a" (declared at /tmp/tmp.ceu:1)',
}
Test { [[
var int a =
    do/_
        a = 1;
        escape a;
    end;
escape a;
]],
    inits = 'line 3 : invalid access to variable "a" : assignment in enclosing `do` (/tmp/tmp.ceu:1)',
    --ref = 'line 4 : invalid access to uninitialized variable "a" (declared at /tmp/tmp.ceu:1)',
    --run = 1,
}
Test { [[
var int a =
    do/_
        par do
            escape 1;
        with
        end;
    end;
escape a;
]],
    run = 1,
}

Test { [[
var int a = do/_ par do
                escape a;
            with
end
            end;
escape a;
]],
    inits = 'line 2 : invalid access to variable "a" : assignment in enclosing `do` (/tmp/tmp.ceu:1)',
    --ref = 'line 2 : invalid access to uninitialized variable "a" (declared at /tmp/tmp.ceu:1)',
}

Test { [[
var int a = do/_
    par do
        escape 1;
    with
    end;
end;
escape a;
]],
    run = 1,
}

Test { [[
var int a = do/_
    par/or do
        escape 111;
    with
    end;
    escape 0;
end;
escape a;
]],
    run = 111,
}

Test { [[
input int A; input int B; input int C;
var int a = do/_
        par/or do
            par do
                var int v=0;
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
            await C;
        end;
        escape 0;
    end;
escape a;
]],
    wrn = true,
    run = {
        ['1~>B; ~>20ms; 1~>C'] = 1,
        ['~>20ms; 5~>B; 2~>C'] = 10000,
    }
}

Test { [[
input int A; input int B; input int C;
var int a = do/_
        par/or do
            par do
                var int v=0;
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
            await C;
        end;
        escape 0;
    end;
escape a;
]],
    wrn = true,
    run = {
        ['1~>B; ~>20ms; 1~>C'] = 1,
        ['~>20ms; 5~>B; 2~>C'] = 10000,
    },
    safety = 2,
    _ana = {
        acc = 2,
    },
}

Test { [[
input int A; input int B; input int C;
var int a = do/_
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
            await C;
        end;
        escape 0;
    end;
escape a;
]],
    -- TODO: melhor seria: unexpected statement
    parser = "line 16 : after `;` : expected `with`",
    --unreachs = 1,
    run = {
        ['1~>B; ~>20ms; 1~>C'] = 1,
        ['~>20ms; 5~>B; 2~>C'] = 10,
    }
}

-- testa ParOr que da clean em await vivo
Test { [[
input int A; input int B; input int C;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
with
    await C;
end;
escape 100;
]],
    run = { ['1~>A;1~>C']=100 }
}

Test { [[
input int A;
var int b = _;
await A;
b = 1;
escape b;
]],
    --inits = 'line 2 : uninitialized variable "b"',
    run = { ['1~>A']=1 },
}

Test { [[
input int A;
var int b = _;
await A;
b = 1;
escape b;
]],
    wrn = true,
    run = { ['1~>A']=1 },
}

Test { [[
input int A;
var int b;
await A;
b = 1;
escape b;
]],
    --inits = 'line 2 : uninitialized variable "b" : reached yielding statement (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "b" : reached `await` (/tmp/tmp.ceu:3)',
    run = { ['1~>A']=1 },
}

Test { [[
input int A;
var int b;
if true then
    await A;
    b = 10;
else
    if true then
        await A;
        b = 1;
    else
        await A;
        b = 0;
    end;
end;
escape b;
]],
    --inits = 'line 2 : uninitialized variable "b" : reached `await` (/tmp/tmp.ceu:4)',
    --inits = 'line 2 : uninitialized variable "b" : reached yielding statement (/tmp/tmp.ceu:4)',
    run = { ['1~>A']=10 },
}

Test { [[
input int A;
var int b = do
    if true then
        await A;
        escape 1;
    else
        if true then
            await A;
            escape 1;
        else
            await A;
            escape 0;
        end;
    end;
end;
escape b;
]],
    run = {
        ['0~>A ; 0~>A'] = 1,
    },
}

Test { [[
input int A;
var int b =
    do
        if true then
            await A;
            escape 1;
        else
            if true then
                await A;
                escape 1;
            else
                await A;
            end;
        end;
    end;
escape b;
]],
    tmp = 'TODO: missing escape',
    --ref = 'line 9 : missing initialization for variable "b" in the other branch of the `if-then-else` (/tmp/tmp.ceu:7)'
}

-->>> LOOP

Test { [[
loop i in 10 do
end
escape 1;
]],
    parser = 'line 1 : after `in` : expected `[` or `]`',
    --env = 'TODO: not a pool',
}

Test { [[
var int ret = 0;
var int i;
loop i in [0 -> 10[ do
//native _printf;
//_printf(">>> %d\n", i);
    ret = ret + 1;
end
escape ret;
]],
    run = 10,
}

Test { [[
var int ret = 0;
var int i;
loop i in [0 -> 256-1[ do
    ret = ret + 1;
end
escape ret;
]],
    run = 255,
}

Test { [[
var int ret = 0;
var int i;
loop i in [1 -> 4] do
    ret = ret + i;
end
escape ret;
]],
    run = 10,
}

Test { [[
var int ret = 0;
var int i;
loop i in [1->4], 2 do
    ret = ret + i;
end
escape ret;
]],
    run = 4,
}

Test { [[
var int ret = 0;
var int i;
loop i in [1->4], -2 do
    ret = ret + i;
end
escape ret;
]],
    --run = '2] -> runtime error: invalid `loop` step : expected positive number',
    codes = 'line 3 : invalid `loop` step : expected positive number : got "-2"',
}

Test { [[
var int ret = 0;
var int step = -2;
var int i;
loop i in [1->4], step do
    ret = ret + i;
end
escape ret;
]],
    run = '4] -> runtime error: invalid `loop` step : expected positive number',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int ret = 1;
var int i;
loop i in [4->1] do
    ret = ret + i;
end
escape ret;
]],
    run = 1,
}

Test { [[
var int ret = 1;
var int i;
loop i in ]-3->4[ do
    ret = ret + i;
end
escape ret;
]],
    run = 4,
}

Test { [[
var int ret = 1;
var int i;
loop i in ]-3 <- 3] do
    ret = ret + i;
end
escape ret;
]],
    run = 4,
}

Test { [[
var int sum = 0;
var int i;
loop i in [_->0] do
    if i == 10 then
        break;
    end
    sum = sum + 1;
end
escape sum;
]],
    parser = 'line 3 : after `_` : expected `<-`',
}
Test { [[
var int sum = 0;
var int i;
loop i in [0<-_] do
    if i == 10 then
        break;
    end
    sum = sum + 1;
end
escape sum;
]],
    parser = 'line 3 : after `<-` : expected expression',
}

Test { [[
loop do end
escape 0;
]],
    tight_ = 'line 1 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
var int sum = 0;
var int i;
loop i in [0->_] do
    if i == 10 then
        break;
    end
    sum = sum + 1;
end
escape sum;
]],
    tight_ = 'line 3 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
var int sum = 0;
var int i;
loop i in [0->_] do
    if i == 10 then
        break;
    end
    sum = sum + 1;
end
escape sum;
]],
    wrn = true,
    run = 10,
}

Test { [[
var int ret = 0;
var int i;
loop i in [1 <- 4], -1 do
    ret = ret + i;
end
escape ret;
]],
    --run = '2] -> runtime error: invalid `loop` step : expected positive number',
    codes = 'line 3 : invalid `loop` step : expected positive number : got "-1"',
}

Test { [[
var int ret = 0;
var int i;
loop i in [1 <- 4] do
    ret = ret + i;
end
escape ret;
]],
    run = 10,
}

Test { [[
var int ret = 0;
var int i;
loop i in [1<-4], 1 do
    ret = ret + i;
end
escape ret;
]],
    run = 10,
}

Test { [[
var int ret = 0;
var int i;
loop i in [1<-4], 2 do
    ret = ret + i;
end
escape ret;
]],
    run = 6,
}
Test { [[
var int ret = 1;
var int i;
loop i in [4<-1] do
    ret = ret + i;
end
escape ret;
]],
    run = 1,
}

Test { [[
var int ret = 1;
var int i;
loop i in [-10 <- -3[ do
    ret = ret + i;
end
escape -ret;
]],
    run = 48,
}

Test { [[
var int sum = 0;
var int i;
loop i in [_<-0] do
    if i == -10 then
        break;
    end
    sum = sum + 1;
end
escape sum;
]],
    wrn = true,
    run = 10,
}

Test { [[
var int i;
loop i in [-1 <- 0] do
end
escape 1;
]],
    run = 1,
}

Test { [[
var int n = 10;
var int sum = 0;
var int i;
loop i in [0->n[ do
    sum = sum + 1;
end
escape n;
]],
    tight_ = 'line 4 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
var int n = 10;
var int sum = 0;
var int i;
loop i in [0->n[ do
    sum = sum + 1;
end
escape n;
]],
    wrn = true,
    run = 10,
}

Test { [[
var int sum = 0;
var int i;
loop i do
    if i == 10 then
        break;
    end
    sum = sum + 1;
end
escape sum;
]],
    wrn = true,
    run = 10,
}

Test { [[
break;
]],
    dcls = 'line 1 : invalid `break` : expected matching enclosing `loop`',
    --props = 'line 1 : `break` without loop',
}
Test { [[
continue;
]],
    dcls = 'line 1 : invalid `continue` : expected matching enclosing `loop`',
}

Test { [[
loop do
    do
        break;
    end;
end;
escape 1;
]],
    wrn = true,
    _ana = {
        unreachs = 1,    -- re-loop
    },
    run = 1,
}
Test { [[
loop do
    do/_
        escape 1;
    end;
end;
escape 0;
]],
    wrn = true,
    _ana = {
        unreachs = 2,
    },
    run = 1,
}

Test { [[
loop do
    loop do
        escape 1;
    end;
end;
escape 0;
]],
    wrn = true,
    _ana = {
        unreachs = 3,
    },
    run = 1,
}

Test { [[
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
    tight_ = 'line 1 : invalid tight `loop` : unbounded number of non-awaiting iterations',
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
input int A; input int B;
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
input none A; input none B;
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
    await async do
        break;
    end;
end;
escape 1;
]],
    props_ = 'line 3 : invalid `break` : unexpected enclosing `async`',
    --props = '`break` without loop',
}

Test { [[
input int A;
var int v = 0;
var int a = 0;
loop do
    a = 0;
    v = await A;
end;
]],
    run = false,
    _ana = {
        isForever = true,
    },
}

Test { [[
var int a;
loop do a=1; end;
escape a;
]],
    tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    --inits = 'line 1 : uninitialized variable "a" : reached `loop` (/tmp/tmp.ceu:2)',
    --ref = 'line 1 : uninitialized variable "a" crossing compound statement (/tmp/tmp.ceu:2)',
}

Test { [[
var int a=0;
loop do a=1; end;
escape a;
]],
    --_ana = {
        --isForever = true,
        --unreachs = 1,
    --},
    tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[break; escape 1;]],
    parser="line 1 : after `;` : expected end of file"
}
Test { [[break; break;]],
    parser="line 1 : after `;` : expected end of file"
}
Test { [[loop do break; end; escape 1;]],
    _ana = {
        unreachs=1,
    },
    run=1
}
Test { [[
var int ret=0;
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
var int a=0;
loop do
    loop do
        a = 1;
    end;
end;
]],
    wrn = true,
    run = false,
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
    tight_ = 'line 1 : invalid tight `loop` : unbounded number of non-awaiting iterations',
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
    run = false,
    _ana = {
        unreachs = 2,
        isForever = true,
    },
}

Test { [[
var int i;
loop i in [0 -> -1] do
end
escape 1;
]],
    --loop = true,
    wrn = true,
    run = 1,
    -- TODO: with consts -1 would be constant
}
Test { [[
var int i;
loop i in [0 -> 0] do
end
escape 1;
]],
    run = 1,
}

Test { [[
input none A;
loop do
    loop do
        await A;
    end
end
]],
    run = false,
    _ana = { isForever=true },
}

Test { [[
input none A;
loop do
var int i;
    loop i in [0->1[ do
        await A;
    end
end
]],
    run = false,
    _ana = { isForever=true },
}

Test { [[
var int i;
loop/1 i in [0->_[ do
    break;
end
escape 1;
]],
    run = 1,
}

Test { [[
loop do
    var int v = 10;
var int i;
    loop i in [0->v[ do
        await 1s;
        escape 2;
    end
end
escape 0;
]],
    run = { ['~>1s']=2 },
    --tight_ = 'line 3 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
loop do
var int i;
    loop i in [0->_[ do
        await 1s;
        escape 2;
    end
end
escape 0;
]],
    run = { ['~>1s']=2 },
    --tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
input none A;
var int v = 1;
loop do
var int i;
    loop i in [0->v[ do
        await A;
        escape 2;
    end
end
escape 1;
]],
    wrn = true,
    run = { ['~>A']=2 },
}

Test { [[
loop i in [1.1 -> 10], 1 do
end
escape 1;
]],
    dcls = 'line 1 : internal identifier "i" is not declared',
}

Test { [[
var real i;
var int ret = 0;
loop i in [1.1 -> 2], 0.1 do
    ret = ret + 1;
end
escape ret;
]],
    run = 9,
}

Test { [[
var real step = 0.9;
var real i;
loop i in [1.1 -> 10], step do
end
escape i as int;
]],
    run = 10,
}

Test { [[
var r64 i;
var int ret = 0;
loop i in [1.3 <- 2], 0.2 do
    ret = ret + 1;
end
escape ((i<1.3) as int) + ret;
]],
    run = 5,
}

Test { [[
var real i;
var int ret = 0;
loop i in [1.1 <- 2], 0.9 do
    ret = ret + 1;
end
escape ret + (i as int);
]],
    run = 2,
}

Test { [[
var int ret = 0;
loop _ in [0 -> 50[ do
    ret = ret + 1;
end
escape ret;
]],
    run = 50,
}

Test { [[
var bool x;
loop x do
    await 1s;
end
]],
    stmts = 'line 2 : invalid `loop` : expected numeric variable',
}

Test { [[
var real x=1.1;
var int ret = 1;
loop/10 _ in ]x -> 2[ do
    ret = ret + 1;
end
escape ret;
]],
    stmts = 'line 3 : invalid control variable : types mismatch : "int" <= "real"',
}

Test { [[
var real x=1.1;
var int ret = 1;
loop/10 _ in ]2 -> x[ do
    ret = ret + 1;
end
escape ret;
]],
    stmts = 'line 3 : invalid control variable : types mismatch : "int" <= "real"',
}

Test { [[
var real x=1.1;
var int ret = 1;
loop/10 _ in ]2 -> 3[, 0.1 do
    ret = ret + 1;
end
escape ret;
]],
    stmts = 'line 3 : invalid control variable : types mismatch : "int" <= "real"',
}

Test { [[
var real x=1.1;
var real i;
var int ret = 1;
loop/10 i in ]0 <- x[ do
    ret = ret + 1;
end
escape ret;
]],
    run = 1,
}

Test { [[
var real i;
var real x=1.1;
var int ret = 1;
loop/10 i in ]x -> 10[ do
    ret = ret + 1;
    x = 10;
end
escape ret;
]],
    run = 8,
}

Test { [[
var real x=5.1;
var int ret = 1;
var real i;
loop/10 i in ]3 <- x[, 2 do
    ret = ret + 1;
end
escape ret;
]],
    run = 1,
}

Test { [[
var real x=2.1;
var int ret = 1;
var real i;
loop/10 i in ]0 <- x[, 2 do
    ret = ret + 1;
end
escape ret;
]],
    run = 1,
}

Test { [[
var int ret = 0;
loop/10 _ in [0 <- 3[, 2 do
    ret = ret + 1;
end
escape ret;
]],
    run = 1,
}

Test { [[
var int ret = 0;
var uint i;
loop i in [0 <- 1[, 2 do
    ret = ret + 1;
end
escape ret;
]],
    wrn = true,
    run = '3] -> runtime error: control variable overflow',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int ret = 0;
var uint i;
loop i in [0 <- 3[, 2 do
    ret = ret + 1;
end
escape ret;
]],
    wrn = true,
    run = '3] -> runtime error: control variable overflow',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int ret = 0;
var byte x = 254;
var byte i;
loop i in [x -> 255], 2 do
    ret = ret + 1;
end
escape ret;
]],
    wrn = true,
    run = '4] -> runtime error: control variable overflow',
    _opts = { ceu_features_trace='true' },
}

Test { [[
loop _ in [0 -> 1], 0.1 do
end
escape 1;
]],
    stmts = 'line 1 : invalid control variable : types mismatch : "int" <= "real"',
}

Test { [[
var int i;
loop i in [10 -> {100}[ do
    escape i;
end
escape 0;
]],
    run = 10,
}

Test { [[
var uint x = 0;
var uint i;
loop i in [0 -> x[ do
    escape 0;
end
escape 1;
]],
    run = '3] -> runtime error: `loop` limit underflow/overflow',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var u8 x = 255;
var u8 i;
loop i in ]x <- 2[ do
    escape 0;
end
escape 1;
]],
    run = '3] -> runtime error: `loop` limit underflow/overflow',
    _opts = { ceu_features_trace='true' },
}
-- LOOP / BOUNDED

Test { [[
native _V;
native/pos do
    int V;
end
loop/_V do
end
escape 1;
]],
    consts = 'line 5 : invalid `loop` : limit must be an integer constant',
    --tight = 'line 4 : `loop` bound must be constant',
}
Test { [[
native/const _V;
native/pos do
    int V;
end
loop/_V do
end
escape 1;
]],
    cc = '5:1: error: variable-sized object may not be initialized',
}
Test { [[
loop/10 do
end
escape 1;
]],
    run = 'runtime error: `loop` overflow',
    _opts = { ceu_features_trace='true' },
    --run = 1,
}

Test { [[
var int i;
loop/10000000 i in [0->0[ do
end
escape 1;
]],
    run = 1,
}
Test { [[
var int ret = 0;
loop/3 do
    ret = ret + 1;
end
escape ret;
]],
    run = 'runtime error: `loop` overflow',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int i;
loop/10 i in [0->10[ do
end
escape 1;
]],
    run = 1,
}
Test { [[
var int a = 0;
var int i;
loop/a i do
end
escape 1;
]],
    consts = 'line 3 : invalid `loop` : limit must be an integer constant',
    --tight = '`loop` bound must be constant',
}
Test { [[
var int i;
loop/10 i do
end
escape 1;
]],
    run = '2] -> runtime error: `loop` overflow',
    _opts = { ceu_features_trace='true' },
}

Test { [[
#include "c.ceu"
escape _strlen("oioi");
]],
    wrn = true,
    opts_pre = true,
    run = 4,
}

Test { [[
native/const _A;
native/pos do
    ##define A 10
end
#define A 10

var int ret = 0;
var int lim = 10 + 10 + _A + A;
var int i;
loop/(10+10+_A+A) i in [0->lim[ do
    ret = ret + 1;
end
escape ret;
]],
    opts_pre = true,
    run = 40;
}

Test { [[
var int k = 5;
var int i;
loop/1 i in [0->k[ do
    var int x = i + 2;
end
escape 1;
]],
    run = '3] -> runtime error: `loop` overflow',
    _opts = { ceu_features_trace='true' },
}

Test { [[
//native _printf;
var int k = 5;
var int i;
loop/10 i in [0->k[ do
    var int x = i + 2;
    //_printf("%d\n", x);
end
escape 1;
]],
    run = 1,
}

Test { [[
input int E;
var int x=0;
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
input none B;
var int a = 0;
loop do
    par/or do       // 4
        await 2s;
    with
        a = a + 1;          // 7
        await B;
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
    run = { ['~>5s; ~>B']=14 },
}

Test { [[
input none B;
var int a = 0;
loop do
    par/or do       // 4
        await 2s;
    with
        a = a + 1;          // 7
        await B;
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
    run = { ['~>5s; ~>B']=14 },
    safety = 2,
}

Test { [[
var int a=0;
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
    run = false,
    _ana = {
        isForever = true,
        --acc = 1,
        abrt = 2,
    },
}

Test { [[
input int A;
loop do
    await A;
    await 2s;
end;
]],
    run = false,
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
    run = false,
    _ana = {
        isForever = true,
    },
}

-->>> EVERY

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
input none A;
var int ret = 0;
every A do
    ret = ret + 1;
    if ret == 3 then
        escape ret;
    end
end
]],
    run = { ['~>A; ~>A; ~>A'] = 3 },
    --props_ = 'line 6 : invalid `escape` : unexpected enclosing `every`',
    --props = 'line 6 : not permitted inside `every`',
}

Test { [[
input int E;
var int x;
every x in E do
end
escape 1;
]],
    --dcls = 'line 3 : implicit declaration of "x" hides previous declaration',
    run = false,
}
Test { [[
input int E;
every x in E do
end
escape 1;
]],
    dcls = 'line 2 : internal identifier "x" is not declared',
    --run = 0,
}

Test { [[
input none A;
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
    props_ = 'line 3 : invalid `await` : unexpected enclosing `every`',
    --props = 'line 3 : `every` cannot contain `await`',
}

Test { [[
input none X;
var int x;
every x in X do
    x = 1;
end
]],
    stmts = 'line 3 : invalid assignment : types mismatch : "(int)" <= "()"',
}
Test { [[
input none X;
var int x; var int y;
every (x,y) in X do
    x = 1;
end
]],
    stmts = 'line 3 : invalid assignment : types mismatch : "(int,int)" <= "()"',
}
Test { [[
input int X;
var int x; var int y;
every (x,y) in X do
    x = 1;
end
]],
    stmts = 'line 3 : invalid assignment : types mismatch : "(int,int)" <= "(int)"',
}
Test { [[
input (int,int) X;
var int x;
every x in X do
    x = 1;
end
]],
    stmts = 'line 3 : invalid assignment : types mismatch : "(int)" <= "(int,int)"',
}

Test { [[
input (int,int) B;
var int ret = 0;
par/or do
    every (_,_) in B do
    end
with
    var int x;
    every (x,_) in B do
        ret = ret + x;
    end
with
    var int x;
    every (_,x) in B do
        ret = ret + x;
    end
with
    await B;
    await B;
with
    await async do
        emit B(1,2);
        emit B(10,20);
    end
end
escape ret;
]],
    run = 33,
}

Test { [[
native/plain _RF24NetworkHeader;
input _RF24NetworkHeader&& NETWORK;
var _RF24NetworkHeader&& x;
every (x) in NETWORK do
end
]],
    wrn = true,
    cc = 'error: unknown type name ‘RF24NetworkHeader’',
}
Test { [[
native/plain _RF24NetworkHeader;
input _RF24NetworkHeader&& NETWORK;
every (_) in NETWORK do
end
]],
    wrn = true,
    cc = 'error: unknown type name ‘RF24NetworkHeader’',
}
Test { [[
var int ret = 0;
watching 10s do
    var bool x = true;
    every 1s do
        x = not x;
        if x then
            continue;
        end
        ret = ret + 1;
    end
end
escape ret;
]],
    run = { ['~>10s']=5 },
}

Test { [[
loop do
    watching 2s do
        if false then
            continue;
        end
    end
    break;
end
escape 1;
]],
    wrn = true,
    run = 1,
}

--<<< EVERY

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
    dcls = 'line 4 : declaration of "dt" hides previous declaration',
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
input (int,int) A;
par do
    var int a; var int  b;
    (a,b) = await A;
    if (a as bool) and (b as bool) then end
with
    await A;
    escape 1;
with
    await async do
        emit A(1,1);
    end
end
]],
    run = 1;
}

Test { [[
input (int,int) A;
par do
    var int a; var int  b;
    (a,b) = await A;
    if (a as bool) and (b as bool) then end
with
    escape 1;
end
]],
    run = 1;
}

Test { [[
input (int,int) A;
await async do
    emit A(1,3);
end
escape 1;
]],
    run = 1;
}

Test { [[
input (int,int) A;
par do
    loop do
        var int a; var int  b;
        (a,b) = await A;
        escape a+b;
    end
with
    await async do
        emit A(1,3);
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
        var int a; var int  b;
        (a,b) = await A;
        escape a+b;
    end
with
    await async do
        emit A(1,3);
    end
end
]],
    run = false,
    ana = 'line 3 : `loop` iteration is not reachable',
    --run = 4;
}

Test { [[
input (int,int) A;
par do
    var int a; var int  b;
    every (a,b) in A do
        escape a+b;
    end
with
    await async do
        emit A(1,3);
    end
end
]],
    run = 4,
    --props_ = 'line 5 : invalid `escape` : unexpected enclosing `every`',
    --dcls = 'line 4 : implicit declaration of "a" hides previous declaration',
}
Test { [[
input (int,int) A;
var int a;
a = await A;
]],
    stmts = 'line 3 : invalid assignment : types mismatch : "(int)" <= "(int,int)"',
}
Test { [[
input (int) A;
var int a;
a = await A;
escape a;
]],
    run = {['1~>A']=1},
}
Test { [[
input (int) A;
var int a;
(a) = await A;
escape a;
]],
    run = {['1~>A']=1},
}
Test { [[
input int A;
var int a;
(a) = await A;
escape a;
]],
    run = { ['1~>A']=1 },
}
Test { [[
input int A;
var int a; var int b;
(a,b) = await A;
]],
    stmts = 'line 3 : invalid assignment : types mismatch',
}

Test { [[
input (int,int) B;
input int A;
var int a; var int b;
(a,b) = await A;
await B;
]],
    stmts = 'line 4 : invalid assignment : types mismatch : "(int,int)" <= "(int)"',
}

Test { [[
input (int,int) A;
par do
    var int a; var int b;
    every (a,b) in A do
        escape a+b;
    end
with
    await async do
        emit A(1,3);
    end
end
]],
    run = 4,
    --props_ = 'line 5 : invalid `escape` : unexpected enclosing `every`',
    --props = 'line 4 : not permitted inside `every`',
}
Test { [[
input (int,int) A;
par do
    loop do
        var int a; var int b;
        (a,b) = await A;
        escape a+b;
    end
with
    await async do
        emit A(1,3);
    end
end
]],
    run = false,
    ana = 'line 3 : `loop` iteration is not reachable',
}
Test { [[
input (int,int) A;
par do
    var int a; var int  b;
    loop do
        (a,b) = await A;
        escape a+b;
    end
with
    await async do
        emit A(1,3);
    end
end
]],
    run = 4,
    --inits = 'line 3 : uninitialized variable "a" : reached `loop` (/tmp/tmp.ceu:4)',
    --ref = 'line 3 : uninitialized variable "a" crossing compound statement (/tmp/tmp.ceu:4)',
}

Test { [[
input (int,int) A;
par do
    loop do
        var int a; var int  b;
        (a,b) = await A;
        escape a+b;
    end
with
    await async do
        emit A(1,3);
    end
end
]],
    wrn = true,
    run = 4;
}

Test { [[
every 1s do
    every 1s do
    end
end
escape 0;
]],
    props_ = 'line 2 : invalid `every` : unexpected enclosing `every`',
}

Test { [[
input none A; input none C;
var int ret = 0;
par/or do
    every A do
        ret = ret + 1;
    end
with
    await C;
end
escape ret;
]],
    run = { ['~>A;~>A;~>A;~>C;~>A']=3 },
}

Test { [[
loop do
    every 1s do
        break;
    end
    escape 1;
end
]],
    run = { ['~>1s']=1 },
    --props_ = 'line 3 : invalid `break` : unexpected enclosing `every`',
    --props = 'line 2 : not permitted inside `every`',
}
Test { [[
every 1s do
    break;
end
escape 1;
]],
    run = { ['~>1s']=1 },
    --dcls = 'line 2 : invalid `break` : expected matching enclosing `loop`',
    --props = 'line 2 : not permitted inside `every`',
}
Test { [[
loop do
    every 1s do
        continue;
    end
end
]],
    run = false,
    --props_ = 'line 3 : invalid `continue` : unexpected enclosing `every`',
    --props = 'line 2 : not permitted inside `every`',
}
Test { [[
every 1s do
    continue;
end
]],
    run = false,
    --dcls = 'line 2 : invalid `continue` : expected matching enclosing `loop`',
    --props = 'line 2 : not permitted inside `every`',
}

Test { [[
every 1s do
    escape 1;
end
]],
    run = { ['~>1s']=1 },
    --props_ = 'line 2 : invalid `escape` : unexpected enclosing `every`',
    --props = 'line 2 : not permitted inside `every`',
}

Test { [[
every 1s do
    loop do
        if true then
            break;
        end
    end
end
]],
    tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
par do
    var int ok = do
        escape 111;
    end;
with
    await 2s;
    escape 222;
end
]],
    run = { ['~>10s'] = 222 },
}
Test { [[
par do
    every 1s do
        var int ok = do
            escape 111;
        end;
    end
with
    await 2s;
    escape 222;
end
]],
    run = { ['~>10s'] = 222 },
}

-->>> CONTINUE

Test { [[
var int ret = 1;
var int i;
loop i in [0->10[ do
    if true then
        continue;
    end
    ret = ret + 1;
    if false then
        continue;
    end
end
escape ret;
]],
    run = 1,
}

Test { [[
loop do
    if false then
        continue;
    else
        nothing;
    end
end
]],
    todo = 'line 3 : invalid `continue`',
}

Test { [[
loop do
    do continue; end
end
]],
    todo = 'line 2 : invalid `continue`',
}

Test { [[
loop do
    do
        if false then
            continue;
        end
    end
end
]],
    todo = 'line 4 : invalid `continue`',
}

Test { [[
loop do
    if false then
        continue;
    end
    await 1s;
end
]],
    --tight = 'tight loop',
    run = false,
    _ana = {
        isForever = true,
        --unreachs = 1,
    },
}

Test { [[
var int ret = 0;
var int i;
loop i in [0->10[ do
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
    if true then
        continue;
    end
end
]],
    run = false,
    --dcls = 'line 3 : invalid `continue` : expected matching enclosing `loop`',
    _ana = {
        isForever = true,
    },
}

Test { [[
par/or do
    loop do
        if false then
            continue;
        end
        var int dim = 0;
        var int x = dim;
        if x!=0 then end
        do break; end
    end
with
end
escape 1;
]],
    wrn = true,
    loop = true,
    run = 1,
}

Test { [[
var int x = 0;
var int i;
loop i in [0->10[ do
    x = x + 1;
    par/and do
        await FOREVER;
    with
        continue/i;
    end
end
escape x;
]],
    run = 10,
}

Test { [[
var int x = 0;
var int i;
loop i in [0->10[ do
var int j;
    loop j in [0->10[ do
        x = x + 1;
        par/and do
            await FOREVER;
        with
            continue/i;
        end
    end
end
escape x;
]],
    run = 10,
}

Test { [[
var int x = 0;
var int i;
loop i in [0->10[ do
var int j;
    loop j in [0->10[ do
        x = x + 1;
        par/and do
            await FOREVER;
        with
            continue/j;
        end
    end
end
escape x;
]],
    run = 100,
}

Test { [[
var int x = 0;
var int i;
loop i in [0 -> 10[ do
    x = x + 1;
    par/and do
        await FOREVER;
    with
        break/i;
    end
end
escape x;
]],
    run = 1,
}

Test { [[
var int x = 0;
var int i;
loop i in [0->10[ do
var int j;
    loop j in [0->10[ do
        x = x + 1;
        par/and do
            await FOREVER;
        with
            break/i;
        end
    end
end
escape x;
]],
    run = 1,
}

Test { [[
var int x = 0;
var int i;
loop i in [0->10[ do
var int j;
    loop j in [0->10[ do
        x = x + 1;
        par/and do
            await FOREVER;
        with
            break/j;
        end
    end
end
escape x;
]],
    run = 10,
}

--<<< CONTINUE

-- EX.05
Test { [[
input int A;
loop do
    await A;
end;
]],
    run = false,
    _ana = {
        isForever = true,
    },
}
Test{ [[
input int E;
var int a=0;
loop do
    a = await E;
end;
]],
    run = false,
    _ana = {
        isForever = true,
    },
}
Test{ [[
input int E;
loop do
    var int v = await E;
    if v!=0 then
    else
    end;
end;
]],
    run = false,
    _ana = {
        isForever = true,
    },
}
Test { [[
var int a=0;
loop do
    if false then
        a = 0;
    else
        a = 1;
    end;
end;
escape a;
]],
    tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}
Test { [[
var int a=0;
loop do
    if false then
        a = 0;
    else
        a = 1;
    end;
end;
escape a;
]],
    --tight = 'tight loop',
    wrn = true,
    run = false,
    _ana = {
        isForever = true,
        unreachs = 1,
    },
}
Test { [[
loop do
    if false then
        break;
    end;
end;
escape 0;
]],
    tight_ = 'line 1 : invalid tight `loop` : unbounded number of non-awaiting iterations',
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
    wrn = true,
    run = false,
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
    wrn = true,
    loop='tight loop',
    run = false,
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
    tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    --run = false,
    --loop='tight loop',
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
    tight_ = 'line 4 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    run = false,
    loop='tight loop',
    _ana = {
        abrt = 1,
        isForever = true,
        unreachs = 1,
    },
}

Test { [[
input int A;
if false then
    loop do await A; end;
else
    loop do await A; end;
end;
escape 0;   // TODO
]],
    run = false,
    _ana = {
        unreachs = 1,
        isForever = true,
    },
}
Test { [[
input int A;
if false then
    loop do await A; end;
else
    loop do await A; end;
end;
]],
    run = false,
    _ana = {
        isForever = true,
    },
}
Test { [[
input int A;
loop do
    if false then
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
    if false then
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
input int C; input int  A;
loop do
    var int v = await C;
    if v!=0 then
        await A;
    else
        break;
    end;
end;
escape 1;
]],
    run = {
        ['0~>C'] = 1,
        ['1~>C;0~>A;0~>C'] = 1,
    }
}

Test { [[
input int A;
var int a=0;
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
    run = false,
    _ana = {
        abrt = 1,
        acc = 1,
    },
}

Test { [[
input int A;
var int a=0;
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
    run = false,
    _ana = {
        isForever = true,
        acc = 2,        -- 6/16  10/16
        abrt = 3,
    },
}

Test { [[
input int A;
var int a=0;
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
    run = false,
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
var int i;
    loop i in [0->1+1[ do
        await A;
    end
    sum = 0;
with
    sum = 1;
end
escape sum;
]],
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
var int i;
    loop i in [0->1[ do    // 4
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
input none A;
var int sum = 0;
var int ret = 0;
par/or do
var int i;
    loop i in [0->2[ do
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
input none A;
var int sum = 0;
var int ret = 0;
par/or do
var int i;
    loop i in [0->3[ do
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
var int i;
    loop i in [0->1[ do    // 4
        await A;
        await async do
            var int a = 1;
            if a!=0 then end
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
var int i;
    loop i in [0->10[ do       // 5
        await A;
        await async do
            var int a = 1;
            if a!=0 then end
        end
    end
    sum = 0;            // 11
with
var int i;
    loop i in [0 -> 2[ do        // 13
        await async do
            var int a = 1;
            if a!=0 then end
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
var int i;
    loop i in [0 -> 10[ do       // 5
        await A;
        await async do
            var int a = 1;
            if a!=0 then end
        end
    end
    sum = 0;            // 11
with
var int i;
    loop i in [0 -> 2[ do        // 13
        await async do
            var int a = 1;
            if a!=0 then end
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
var int i;
loop i in [0 -> 100[ do
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
var int i;
loop i in [0 -> 100[ do
    sum = sum - (i+1);
end
escape sum+1;
]],
    --loop = true,
    run = 1,
}
Test { [[
var int sum = 5050;
var int v = 0;
var int i;
loop i in [0 -> 100[ do
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
input none A;
var int sum = 0;
var int v = 0;
var int i;
loop i in [0 -> 101[ do
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
var int i;
loop i in [0 -> 0[ do
    sum = sum - i;
end
escape sum;
]],
    --loop = true,
    --adj = 'line 2 : constant should not be `0`',
    run = 4,
}
Test { [[
input none A; input none  B;
var int sum = 0;
var int i;
loop i in [0 -> 10[ do
    await A;
    sum = sum + 1;
end
escape sum;
]],
    run = {['~>A;~>B;~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;~>A;']=10},
}

Test { [[
var int v = 10;
var int&& x = &&v;
var int i;
loop i in [0 -> 10[ do
    *x = *x + 1;
end
escape v;
]],
    run = 20,
}

Test { [[
native _ceu_assert;

var u32 t = 0;

loop _ in [1 -> 1000000[ do
    t = t + 1;
    var[] u32 ms = [t];

    var u32 v1 = ms[0];
    ms = ms .. [t];
    var u32 v2 = ms[0];

    _ceu_assert(v1 == v2, "bug found");
end

escape 1;
]],
    wrn = true,
    opts_pre = true,
    run = 1,
    _opts = { ceu_features_dynamic='true' },
}

--<<< LOOP

Test { [[
input int A; input int B;
var int ret=0;
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
input int A; input int B;
var int ret=0;
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
input int A; input int B; input int Z; input int X; input int C;
var int ret=0;
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
        ret = await X;          // 16 (false w/10,9)
    end;
with
    ret = await C;
end;
escape ret;
]],
    run = { ['1~>C'] = 1 }
}

Test { [[
input int A; input int B; input int Z; input int X; input int C;
var int ret=0;
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
        ret = await X;          // 16 (false w/10,9)
    end;
with
    ret = await C;
end;
escape ret;
]],
    run = { ['1~>C'] = 1 },
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
input int C;
var int a = 0;
par do
    a = a + 1;
    await FOREVER;
with
    await C;
    escape a;
end;
]],
    _ana = {
        isForever = false,
    },
    run = { ['~>1min; ~>1min ; 0~>C'] = 1 },
}

Test { [[
input int C;
var int a = 0;
par do
    a = a + 1;
    await FOREVER;
with
    await C;
    escape a;
end;
]],
    safety = 2,
    _ana = {
        isForever = false,
        acc = 1,
    },
    run = { ['~>1min; ~>1min ; 0~>C'] = 1 },
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
input int A; input int C;
var int a=0; var int f=0;
par/and do
    a = await A;
with
    f = await C;
end;
escape a+f;
]],
    run = { ['1~>A;5~>A;1~>C'] = 2 },
}

Test { [[
input int A; input int C;
var int a=0; var int f=0;
par/or do
    par do
        a = await A;
    with
        await FOREVER;
    end
with
    f = await C;
end;
escape a+f;
]],
    run = { ['1~>A;5~>A;1~>C'] = 2 },
}

-->> AWAIT / ID_any

Test { [[
input int A;
_ = await A;
escape 0;
]],
    parser = 'line 1 : after `;` : expected statement',
}

Test { [[
input (int,int) B;
var int x1=0; var int  x2=0;
par/and do
    (_,_) = await B;
    (x1,_) = await B;
    (_,x2) = await B;
with
    await async do
        emit B(10,10);
        emit B(1,10);
        emit B(10,2);
    end
end
escape x1+x2;
]],
    run = 3,
}

--<< AWAIT / ID_any

-->> AWAIT / UNTIL

Test { [[
input int A;
var int x;
x = await A until x>10;
escape x;
]],
    run = {
        ['1~>A; 0~>A; 10~>A; 11~>A'] = 11,
    },
}
Test { [[
input int A;
var int x = await A until x>10;
escape x;
]],
    run = {
        ['1~>A; 0~>A; 10~>A; 11~>A'] = 11,
    },
}

--<< AWAIT / UNTIL

-->>> INTERNAL EVENTS

Test { [[
event none e;
var int i;
loop i in [0->256[ do
    emit e;
end
escape 1;
]],
    wrn = true,
    --run = 'too many internal reactions',
    run = 1,
}

Test { [[
native _abc; // TODO: = 0;
event none a;
var _abc b;
]],
    dcls = 'line 2 : event "a" declared but not used',
}

Test { [[
event none e;
escape 0  or  e;
]],
    dcls = 'line 2 : invalid operand to `or` : unexpected context for event "e"',
}
Test { [[
event none e;
escape sizeof(e);
]],
    dcls = 'line 2 : invalid operand to `sizeof` : unexpected context for event "e"',
}
Test { [[
event none e;
escape not e;
]],
    dcls = 'line 2 : invalid operand to `not` : unexpected context for event "e"',
}
Test { [[
event int e;
escape e?;
]],
    dcls = 'line 2 : invalid operand to `?` : unexpected context for event "e"',
}
Test { [[
event int e;
escape e|e;
]],
    dcls = 'line 2 : invalid operand to `|` : unexpected context for event "e"',
}
Test { [[
event none e;
escape -e;
]],
    dcls = 'line 2 : invalid operand to `-` : unexpected context for event "e"',
}

Test { [[
native _abc; // TODO: = 0;
event none a;
var _abc b;
]],
    wrn = true,
    --inits = 'line 3 : uninitialized variable "b"',
    cc = false,
}

Test { [[
native _abc; // TODO: = 0;
event none a;
var _abc b = _;
]],
    wrn = true,
    tmp = 'line 3 : cannot instantiate type "_abc"',
}

Test { [[
event u8&& a;  // allowed by compiler

var u8 k = 5;

emit a(&&k); // leads to compiler error
]],
    dcls = 'line 1 : invalid event type : cannot use `&&`'
}

Test { [[
var int x;
event (int,int) e;
escape 1;
]],
    wrn = true,
    --inits = 'line 1 : uninitialized variable "x" : reached `escape` (/tmp/tmp.ceu:3)',
    run = 1,
}

Test { [[
var int x=0;
event (int,int) e;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
event int c;
emit c(10);
await c;
escape 0;
]],
    run = false,
    _ana = {
        --unreachs = 1,
        --isForever = true,
    },
    --trig_wo = 1,
}

-- EX.06: 2 triggers
Test { [[
event int c;
emit c(10);
emit c(10);
escape c;
]],
    stmts = 'line 4 : invalid `escape` : unexpected context for event "c"',
    --env = 'line 4 : types mismatch (`int` <= `none`)',
    --trig_wo = 2,
}

Test { [[
event int c;
emit c(10);
emit c(10);
escape 10;
]],
    run = 10,
    --trig_wo = 2,
}

Test { [[
event int b;
var   int a;
a = 1;
emit b(a);
escape a;
]],
    run = 1,
    --trig_wo = 1,
}

Test { [[
event int a;
var int ret = 0;
par/and do
    ret = await a;
with
    emit a(1);
end
escape ret;
]],
    run = 1,
}

Test { [[
event int a;
var int ret = 0;
par/or do
    ret = await a;
with
    emit a(1);
end
escape ret;
]],
    run = 1,
}

-- works with INPUT__STK, doesn't work with single-pass scheduler
-- ceu_bcast_mark vs ceu_bcast_exec
Test { [[
event int a;
var int ret = 0;
par/or do
    ret = await a;
with
    emit a(1);
end
par/or do
    await FOREVER;
with
    await FOREVER;
with
    await 1s;
    emit a(2);
with
    ret = await a;
end
escape ret;
]],
    run = { ['~>1s']=2 },
}

-- requires trl->stk for CEU_INPUT__STK
Test { [[
event none a; event none  b;
par do
    await a;
    emit b;
with
    await a;
    escape 99;
with
    await b;
    escape 1;
with
    emit a;
end
]],
    run = 1,
}

-->>> OS_START / ANY

Test { [[
input none ANY;
await ANY;
escape 1;
]],
    todo = 'ANY',
    run = { ['~>1s']=1 },
}

Test { [[
input none OS_START;
input none A; input none  B;
input none ANY;
var int ret = 0;
await OS_START;
par/or do
    await B;
with
    every ANY do
        ret = ret + 1;
    end
end
escape ret;
]],
    todo = 'ANY',
    wrn = true,
    run = { ['~>1s;~>A;~>B']=5 },
}

Test { [[
input none ANY;
var int ret = 0;
par/or do
    every ANY do
        ret = ret + 1;
    end
with
    every 1ms do
    end
with
    await 1ms;
end
escape ret;
]],
    todo = 'ANY',
    run = { ['~>1s']=1001 },
}

Test { [[
input none OS_START;
var int v = 1;
loop do
var int i;
    loop i in [0->v[ do
        await OS_START;
        escape 2;
    end
end
escape 1;
]],
    wrn = true,
    ana = 'line 4 : `loop` iteration is not reachable',
    --ana = 'line 4 : statement is not reachable',    -- TODO: should be line 7
    run = 2,
}

Test { [[
input none OS_START;
event int a;
var int ret = 0;
par/or do
    await OS_START;
    emit a(1);
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
input none OS_START;
var int ret=0;
event none a; event none b;
par/and do
    await OS_START;
    emit a;
with
    await OS_START;
    emit b;
end
escape 1;
]],
    run = 1,
}

Test { [[
input none OS_START;
var int ret=0;
event none a; event none b;
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
input none OS_START;
var int ret=0;
event none a; event none b;
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
input none OS_START;
var int ret=0;
event none a; event none b; event none c; event none d;
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
input none OS_START;
event real x;
var real ret = 0;
par/and do
    ret = await x;
with
    await OS_START;
    emit x(1.1);
end
escape (ret>1.0 and ret<1.2) as int;
]],
    run = 1,
}

Test { [[
input real X;
var real ret=0;
par/and do
    ret = await X;
with
    await async do
        emit X(1.1);
    end
end
escape( ret>1.0 and ret<1.2 )as int;
]],
    run = 1,
}

-- RESEARCH-5
Test { [[
input none OS_START;
event int e;
par do
    await OS_START;
    emit e(1);
    escape 10;
with
    await e;
    emit e(2);
    escape 20;
with
    var int v = await e;
    escape v;   // 1
end
]],
    _ana = {acc=true},
    --run = 2,
    run = 20,
}
Test { [[
input none OS_START;
event int e;
par do
    await OS_START;
    emit e(1);
    escape -1;
with
    await e;
    emit e(2);
    await FOREVER;
with
    var int v = await e;
    escape v;   // 1
end
]],
    _ana = {acc=true},
    --run = 2,
    run = 1,
}

-- the inner "emit e" is aborted and the outer "emit e"
-- awakes the last "await e"
Test { [[
input none OS_START;

event int e;

var int ret = 0;

par/or do
    await OS_START;
    emit e(2);
    escape -1;
with
    par/or do
        await e;
        emit e(3);
        escape 20;
    with
        var int v = await e;
        ret = ret + v;          // 0+3
    end
    await FOREVER;
with
    var int v = await e;
    ret = ret * v;              // 3*[2,3]
end

escape ret;
]],
    --_ana = {acc=3},
    _ana = {acc=true},
    --run = 6,
    --run = 9,
    run = 20,
}

Test { [[
input none OS_START;

event int e;

var int ret = 0;

par/or do
    await OS_START;
    emit e(2);
    escape 99;
with
    par/or do
        await e;
        emit e(3);
        await FOREVER;
    with
        var int v = await e;
        ret = ret + v;          // 0+3
    end
    await FOREVER;
with
    var int v = await e;
    ret = ret * v;              // 3*[2,3]
end

escape ret;
]],
    --_ana = {acc=3},
    _ana = {acc=true},
    --run = 6,
    --run = 9,
    run = 4,
}

-- "emit e" on the stack has to die
-- RESEARCH-1:
Test { [[
input none OS_START;

event int&& e;
var int ret = 0;

par/or do
    do
        var int i = 10;
        par/or do
            await OS_START;
            emit e(&&i);           // stacked
        with
            var int&& pi = await e;
            ret = *pi;
        end                         // has to remove from stack
    end
    do
        var int i = 20;
        await 1s;
        i = i + 1;
    end
with
    var int&& i = await e;           // to anone awaking here
    escape *i;
end
escape ret;
]],
    dcls = 'line 3 : invalid event type : cannot use `&&`',
    --env = 'line 11 : wrong argument : cannot pass pointers',
    --run = { ['~>1s']=10 },
}

Test { [[
event none e;
input none OS_START;

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
        escape 222;   // should continue after the awake below
    end
with
    await e;
    escape 111;       // should escape before the one above
end
]],
    run = 111,
}

--<<< OS_START / ANY

Test { [[
native _f;
native/pos do
    int f;
end
input int A;
_f = await A;
escape _f;
]],
    run = {['1~>A']=1},
}

Test { [[
event none e;
var int i;
loop i in [0 -> 1000[ do
    emit e;
end
escape 1;
]],
    run = 1, -- had stack overflow
}
Test { [[
event none e;
var int ret = 0;
par/or do
    every e do
        ret = ret + 1;
    end
with
var int i;
    loop i in [0 -> 2[ do
        emit e;
    end
end
escape ret;
]],
    _ana = {acc=1},
    run = 2,
}

Test { [[
event none e;
var int ret = 0;
par/or do
    every e do
        ret = ret + 1;
    end
with
var int i;
    loop i in [0 -> 1000[ do
        emit e;
    end
end
escape ret;
]],
    _ana = {acc=1},
    run = 1000, -- had stack overflow
}

Test { [[
input none OS_START;
event (int,int) e;
par do
    do
        par/or do
            await OS_START;
            emit e(1,2);
        with
            await e;
        end
    end
    do
        emit e(3,4);
    end
with
    var int a; var int b;
    (a,b) = await e;
    escape a+b;
end
]],
    --run = 7,
    run = 3,
}

-- different semantics w/ longjmp
Test { [[
input none OS_START;
event none e; event none f;
par do
    par/or do
        await OS_START;
        emit e;
    with
        await f;
    end
    await 1s;
    escape 1;
with
    await e;
    emit f;     // this continuation dies b/c the whole stack
    escape 2;   // for emit-e dies
end
]],
    run = {['~>1s']=2},
}

Test { [[
native/plain _char_ptr_ext;
native/pure _strlen;
native/pre do
    typedef char* char_ptr_ext;
end
event _char_ptr_ext e;
var int ret = 0;
par/and do
    var _char_ptr_ext ptr = await e;
    ret = _strlen(ptr);
with
    emit e("ola");
end
escape ret;
]],
    run = 3,
}

Test { [[
event (none) e;
var int i = 0;
var int j;
loop j in [1->1] do
   par/and do
        await e;
        i = i + 1;
   with
        emit e;
   end
end
escape 1;
]],
    run = 1,
}

--<<< INTERNAL EVENTS

-- ParOr

Test { [[
event int a;
loop do
    await a;
end;
escape 0;
]],
    run = false,
    --tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    --run = 4,
}

Test { [[
input none OS_START;
event int a;
var int aa = 3;
par do
    await OS_START;
    emit a(aa);      // 6
    escape aa;
with
    loop do
        var int v = await a;
        aa = v+1;
    end;
end;
]],
    wrn = true,
    run = 4,
}

Test { [[
var int ret = 0;
par/or do
    var int late;
    every late in 9us do
        ret = late;
    end
with
    await 10us;
end
escape ret;
]],
    run = { ['~>10us']=1 };
}

Test { [[
input none OS_START;
event int a;
var int aa = 3;
par do
    await OS_START;
    emit a(aa);      // 6
    escape aa;
with
    var int v;
    every v in a do
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
input none OS_START;
event int a;
var int aa = 3;
par do
    await OS_START;
    emit a(aa);
    escape aa;
with
    loop do
        var int v = await a;
        aa = v+1;
    end;
end;
]],
    wrn = true,
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
    --env = 'line 10 : missing parameters on `emit`',
    stmts = 'line 10 : invalid `emit` : types mismatch : "(int)" <= "()"',
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
emit a(1);
escape ret;
]],
    _ana = {
        abrt = 1,
        --unreachs = 1,
    },
    run = 5,
}

Test { [[
native _abc;
native/pre do
    typedef u8  abc;
end
event none a;
var _abc b=0;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
native _abc;// TODO = 0;
event none a;
var _abc a = _;
]],
    wrn = true,
    --dcls = 'line 3 : internal identifier "a" is already declared at line 2',
    tmp = 'line 3 : cannot instantiate type "_abc"',
}

Test { [[event int a=0; emit a(1); escape a;]],
    stmts = 'line 1 : invalid assignment : unexpected context for event "a"',
    --parser = 'line 1 : after `a` : expected `;`',
    --trig_wo = 1,
}
Test { [[
event int a;
emit a(1);
escape a;
]],
    stmts = 'line 3 : invalid `escape` : unexpected context for event "a"',
    --run = 1,
    --trig_wo = 1,
}

Test { [[
event none e;
emit e;
escape 10;
]],
    wrn = true,
    run = 10,
}

Test { [[
var int a=10;
do
    var int b=1;
    if b!=0 then end;
end
escape a;
]],
    run = 10,
}

-- TODO: XXX
Test { [[
input none OS_START;
do
    var int v = 0;
    if v!=0 then end;
end
event none e;
var int ret = 0;
par/or do
    await OS_START;
    emit e;
    ret = 1;
with
    await e;
    ret = 2;
end
escape ret;
]],
    _ana = {
        excpt = 1,
        --unreachs = 1,
    },
    run = 2,
}

Test { [[
input none OS_START;
var int ret = 0;
par/and do
    await OS_START;
with
    event none e;
    par/or do
        await OS_START;
        emit e;
        ret = 1;
    with
        await e;
        ret = 2;
    end
end
escape ret;
]],
    todo = 'OS_START',
    run = 2,
}

Test { [[
input none OS_START;
do
    var int v = 0;
    if v!=0 then end;
end
event none e;
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
input none OS_START;
do
    var int v = 0;
    if v!=0 then end;
end
event none e;
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
input none OS_START;
event none a; event none b;
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

Test { [[
event int aa;
var int a=0;
par/and do
    a = do/_
        escape 1;
    end;
with
    await aa;
end;
escape 0;
]],
    run = false,
    _ana = {
        --unreachs = 2,
        --isForever = true,
    },
}

Test { [[
event int a;
a = do/_
    escape 1;
end;
escape 0;
]],
    stmts = 'line 2 : invalid assignment : unexpected context for event "a"',
    --env = 'line 4 : types mismatch (`none` <= `int`)',
}

Test { [[
event int a;
par/and do
    a = do/_
        escape 1;
    end;
with
    await a;
end;
escape 0;
]],
    stmts = 'line 3 : invalid assignment : unexpected context for event "a"',
    --env = 'line 4 : types mismatch (`none` <= `int`)',
}

Test { [[
input none OS_START;
event none a;
loop do
    if true then
        par do
            await a;
            break;
        with
            await OS_START;
            emit a;
            _ceu_assert(0, "err");
        end
    else
        await OS_START;
    end
end
await 1s;
escape 1;
]],
    run = {['~>1s']=1},
}
Test { [[
input none OS_START;
event none e;
every OS_START do
var int i;
    loop i in [0->10[ do
        emit e;
    end
    do break; end
end
escape 10;
]],
    props = 'line 7 : not permitted inside `every`',
}

Test { [[
input none A;
event none e;
loop do
    await A;
var int i;
    loop i in [0->10[ do
        emit e;
    end
    do break; end
end
escape 10;
]],
    ana = 'line 3 : `loop` iteration is not reachable',
    run = { ['~>A']=10 },
}

Test { [[
input none A;
event none a; event none  b; event none  c; event none  d;
native _assert;
var int v=0;
par do
    loop do
        await A;
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
    run = { ['~>A']=1 },
}

Test { [[
input none A;
event none a; event none  b; event none  c; event none  d;
native _assert;
var int v=0;
par do
    loop do
        await A;
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
    run = { ['~>A']=1 },
    _ana = {
        acc = 3,
    },
}

Test { [[
native/pos do ##include <assert.h> end
input none A;
event none a;
native _assert;
var int v=0;
par do
    loop do
        await A;
        emit a;         // killed
        _assert(0);
    end
with
    //loop do
        await a;
        escape 1;       // kills emit a
    //end                 // unreach
end
]],
    _ana = {
        unreachs = 1,
        excpt = 1,
    },
    run = { ['~>A']=1 },
}

Test { [[
event none inc;
loop do
    await inc;
    nothing;
end
every inc do
    nothing;
end
]],
    run = false,
    --tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    _ana = { isForever=true },
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
    tight_ = 'line 5 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    loop='tight loop',
    _ana = {
        isForever = true,
        unreachs = 2,
    },
}

Test { [[
input none A;
event none a; event none b;
par/and do
    await a;
with
    await A;
    emit b;
    emit a;
end
escape 5;
]],
    run = { ['~>A']=5 },
}
--<<< INTERNAL EVENTS

Test { [[
input int A;
var int a = 0;
par/or do
    if true then
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
input int A; input int B;
var int a = do/_ par do
        await A;
        if true then
            await B;
            // unreachable
        end;
        escape 0;               // 8
    with
        var int v = await A;
        escape v;               // 11
end
    end;
escape a;
]],
    run = false,
    _ana = {
        --unreachs = 1,
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input int A;
var int a;
a = do/_ par do
        if true then
            var int v = await A;
            escape v;           // 6
        end;
        escape 0;
    with
        var int v = await A;
        escape v;               // 11
end
    end;
escape a;
]],
    run = {['6~>A']=6},
    _ana = {acc=true},
    --ref = 'line 6 : missing initialization for variable "a" in the other branch of the `if-then-else` (/tmp/tmp.ceu:4)',
}
Test { [[
input int A;
var int a;
a = do/_ par do
        if true then
            var int v = await A;
            escape v;           // 6
        else
            escape 0;
        end;
    with
        var int v = await A;
        escape v;               // 11
end
    end;
escape a;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 4,
    },
}

Test { [[
input int A;
var int a;
a = do/_ par do
    await A;                    // 4
    if true then
        var int v = await A;
        // unreachable
        escape v;               // 8
    else
        escape 0;                   // 10
    end;
with
    var int v = await A;
    escape v;                   // 13
end
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
input none OS_START;
event none e;
var int v=0;
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
input none OS_START;
event none e;
var int v=0;
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
input int A; input int B;
var int a; var int v=0;
a = do/_ par do
    if true then
        v = await A;    // 5
        escape 0;           // 10
    else
        await B;
        escape v;
    end;
with
    var int v = await A;
    escape v;           // 13
end
end;
escape a;
]],
    wrn = true,
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input int A; input int B;
var int a; var int v=0;
a = do/_ par do
    if true then
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
end
end;
escape a;
]],
    wrn = true,
    _ana = {
        unreachs = 1,
        acc = 1,
        abrt = 3,
    },
    run = { ['1~>A']=1 },
}

Test { [[
input none OS_START;
event none c; event none d;
par do
    await OS_START;
    emit c;
    escape 10;       // 35
with
    every c do
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
native/pos do
    ##include <assert.h>
end
input none OS_START;
event none a; event none  b; event none  c; event none  d;
native _assert;
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
    wrn = true,
    _ana = {
        acc = true,
        unreachs = 1,
        abrt = 1,
    },
    run = 4,
}

Test { [[
input int A;
var int a = 1;
par/or do
    if true then
        a = await A;
    end;
with
    if not true then
        a = await A;
    end;
end;
escape a;
]],
    _ana = {
        acc  = 1,
        abrt  = 3,
    },
    run = 1,
}

Test { [[
input int B;
//event int a;
var int aa=0;
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
    run = false,
    _ana = {
        --unreachs = 1,
        abrt = 6,      -- TODO: not checked
        acc = 1,
    },
}
Test { [[
input int B;
//event int a;
var int aa=0;
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
    run = false,
    _ana = {
        --unreachs = 1,
        abrt = 8,      -- TODO: not checked
        acc = 2,
    },
}

Test { [[
event none a; event none  b;
input none OS_START; input none A;
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
    wrn = true,
    run = { ['~>A']=2 },
}

-- the second E cannot awake
Test { [[
input none E;
event none e;
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
event none a; event none  b;
input none OS_START;
var int ret = 0 ;

par/or do
    every a do
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
    run = 2,
    --run = 1,
}

-- TODO: STACK
-- internal glb awaits
Test { [[
input none OS_START;
//event none a;
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
input none OS_START;
event int x; event int  y;
var int ret = 0;
par do
    par/and do
        await OS_START;
        emit x(1);   // 7
        emit y(1);   // 8
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
    emit x(1);       // 20
    emit y(1);       // 21
end
]],
    _ana = {
        acc = 3,
        abrt = 5,   -- TODO: not checked
    },
    run = 2;
}

Test { [[
input none OS_START;
event none a; event none  b;
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
native _V;
native/pos do
    int V = 10;
end
event none a;
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
native _V;
native/pos do
    int V = 10;
end
event none a;
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

-- BUG: scope of emit args is dead
Test { [[
input none OS_START;
event int e;
var int ret = 1;
par/or do
    do
        var int x = 2;
        par/or do
            await OS_START;
            emit e(x);
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
    --run = { ['~>2s']=10 },
    run = { ['~>2s']=2 },
}

Test { [[
input int A;
var int a=0; var int  b=0;
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
input int A; input int B;
var int a=0; var int b=0; var int c=0; var int d=0;
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

Test { [[
input int A; input int B;
var int a=0; var int b=0; var int ret=0;
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
input int A; input int B;
var int a=0; var int b=0;
par/or do
    if true then
        a = await A;
    else
        b = await B;
    end;
with
    if true then
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
    run = 1,
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
input int A; input int B; input int Z;
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
input int A; input int B;
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
input int A; input int B;
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
input int A; input int B; input int Z;
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
input int A; input int B; input int Z;
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
var int a=1;
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
var int a=0; var int b=0;
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
var int a=0; var int b=0;
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
var int a=0; var int b=0;
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
var int a=0; var int b=0;
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
var int a=100; var int b=100;
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
var int a=0; var int b=0;
par do
    a = await 10ms;
    escape a;
with
    b = await (10000)us;
    escape b;
end;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
var int a=0; var int b=0;
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
var int a=0; var int b=0;
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
var int a=0; var int b=0;
par do
    a = await 10us;
    escape a;
with
    b = await (5)us;
    await 5us;
    escape b;
end;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 4,
    },
}
Test { [[
var int a=0; var int b=0;
par do
    a = await 10us;
    escape a;
with
    b = await (5)us;
    await 10us;
    escape b;
end;
]],
    run = false,
    _ana = {
        acc = 1,     -- TODO: =0 (await(5) cannot be 0)
        abrt = 4,
    },
}

Test { [[
input none A;
var int v1=0; var int  v2=0;
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
input none A;
var int v1=0; var int  v2=0; var int  v3=0;
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
        await async do
        end
    end
end
]],
    run = false,
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
        await async do
        end
    end
end
]],
    run = false,
    _ana = {
        isForever = true,
        unreachs = 1,
    }
}

Test { [[
var int v=0;
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
    run = false,
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
var int a=0;
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
escape 1;
]],
    run = false,
}
Test { [[
input none A; input none B;
var int a=0;
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
    run = false,
    _ana = {
        isForever = true,
    },
}
Test { [[
input int A;
var int a=0;
loop do
    par/or do
        loop do
            await (10)us;
            await 10ms;
            if true then
                a = 1;      // 9
                break;
            else
                a = 0;
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
    run = false,
    _ana = {
        isForever = true,
    },
}
Test { [[
input int A;
var int a=1;
loop do
    par/or do
        loop do
            await (10)us;
            await 10ms;
            if true then
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
    run = false,
    _ana = {
        acc = 1,
        isForever = true,
    },
}
Test { [[
input int A;
var int a=0;
loop do
    par/or do
        loop do
            await 10ms;
            await (10)us;
            if true then
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
    run = false,
    _ana = {
        isForever = true,
    },
}
Test { [[
var int v=0;
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
var int a=0;
loop do
    par/or do
        loop do             // 4
            await (10)us;
            await 10ms;
            if true then
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
    run = false,
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
    if true then
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
    run = false,
    _ana = {
        isForever = true
    },
}
Test { [[
var int a=0;
par/or do
    loop do             // 3
        await 10ms;
        await (10)us;
        if true then
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
    run = false,
    _ana = {
        abrt = 1,
        isForever = true,
    },
}
Test { [[
var int a=0;
loop do
    par/or do
        loop do
            await 10ms;
            await (10)us;
            if true then
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
    run = false,
    _ana = {
        abrt = 1,
        isForever = true,
        acc = 1,
    },
}
Test { [[
var int a=0;
loop do
    par/or do
        loop do
            await (10)us;
            await 10ms;
            if true then
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
    run = false,
    _ana = {
        abrt = 1,
        isForever = true,
        acc = 1,
    },
}
Test { [[
var int a=0; var int b=0;
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
var int a=0; var int b=0;
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
var int a=0; var int b=0;
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
var int a=0; var int b=0; var int c=0;
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
    run = false,
    _ana = {
        acc = 3,
        abrt = 9,
    },
}
Test { [[
var int a=0; var int b=0; var int c=0;
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
var int a=0; var int b=0; var int c=0;
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
var int a=0; var int b=0; var int c=0;
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
    run = false,
    _ana = {
        abrt = 9,
        acc = 3,
    },
}
Test { [[
var int a=0; var int b=0;
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
Test { [[await 0ms; escape 0;]],
    consts = 'line 1 : invalid wall-clock time : constant is out of range',
}
Test { [[
await 35min;
escape 0;
]],
    consts = 'line 1 : invalid wall-clock time : constant is out of range',
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
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
var int v1=0; var int v2=0;
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
    run = false,
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
    run = false,
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
    run = false,
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
    run = false,
    _ana = {
        isForever = true,
    },
}

Test { [[
loop do
    await 10ms;
end;
]],
    run = false,
    _ana = {
        isForever = true,
    },
}

Test { [[
input int A;
await async do
    emit A;
end
escape 1;
]],
    stmts = 'line 3 : invalid `emit` : types mismatch : "(int)" <= "()"',
    --env = 'line 3 : arity mismatch',
    --env = 'line 3 : missing parameters on `emit`',
}

Test { [[
input none C;
var int a=0;
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
    await C;
    escape a;
end;
]],
    run = { ['~>10s;~>C']=10 }
}

Test { [[
input none C;
do/_
    var int a=0; var int  b=0; var int  c=0;
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
        await C;
        escape a + b + c;
    end;
end;
]],
    run = {
        ['~>999ms; ~>C'] = 108,
        ['~>5s; ~>C'] = 555,
        ['~>C'] = 0,
    }
}

Test { [[
input none C;
do/_
    var int a=0; var int  b=0; var int  c=0;
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
        await C;
        escape a + b + c;
    end;
end;
]],
    run = {
        ['~>999ms; ~>C'] = 108,
        ['~>5s; ~>C'] = 555,
        ['~>C'] = 0,
    },
    safety = 2,
    _ana = {
        acc = 3,
    },
}

    -- TIME LATE

Test { [[
var int a; var int  b;
(a,b) = await 1s;
escape 1;
]],
    parser = 'line 2 : after `await` : expected external identifier',
    --parser = 'line 2 : after `1` : expected number or `/_`',
    --stmts = 'line 2 : invalid assignment : types mismatch',
    --env = 'line 2 : arity mismatch',
    --gcc = 'error: ‘tceu__s32’ has no member named ‘_2’',
    --run = 1,
}

Test { [[
input int C;
var int late = 0;
var int v=0;
par do
    loop do
        v = await 1ms;
        late = late + v;
    end;
with
    await C;
    escape late;
end;
]],
    run = {
        ['~>1ms; ~>1ms; ~>1ms; ~>1ms; ~>1ms; 1~>C'] = 0,
        ['~>1ms; ~>1ms; ~>1ms; ~>10ms; 1~>C'] = 45000,
        ['~>1ms; ~>1ms; ~>2ms; 1~>C'] = 1000,
        ['~>2ms; 1~>C'] = 1000,
        ['~>2ms; ~>2ms; 1~>C'] = 2000,
        ['~>4ms; 1~>C'] = 6000,
        ['1~>C'] = 0,
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
var int v=0;
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
var int a=0;
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
var int a=0;
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
input int A; input int  C;
var int a=0;
par/or do
    a = await 10min;
with
    a = await A;
end;
await C;
escape a;
]],
    run = {
        ['1~>A  ; 1~>C'] = 1,
        ['~>10min ; 1~>C'] = 0,
        ['~>10min ; 1~>A ; 1~>C'] = 0,
        ['1~>A  ; ~>10min; 1~>C'] = 1,
    }
}

Test { [[
native/pos do ##include <assert.h> end
native _assert;
input none A;
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
        var int t=0;
        par/or do
            t = await 1s;
        with
            loop do
                await A;
                i = i + 1;
            end
        end
        if t!=0 then end;
    end
with
    await async do
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
    end
end
escape ret;
]],
    run = 72000,
}

Test { [[
input none OS_START;
event int a;
var int ret = 1;
par/or do
    await OS_START;
    emit a(10);
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
    emit a(10);
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
input none OS_START;
event int a;
var int ret = 1;
par/and do
    await OS_START;
    emit a(10);
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
    emit a(1);
end;
escape 10;
]],
    _ana = {
        acc = 1,
    },
    run = 10,
    --run = 0,
}

Test { [[
input int A;
event int b; event int  c;
par do
    await A;
    emit b(1);
    await c;        // 6
    escape 10;      // 7
with
    await b;
    await A;
    emit c(10);      // 11
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
event int b; event int  c;
par do
    await A;
    emit b(1);
    await c;        // 6
    escape 10;      // 7
with
    await b;
    await A;
    emit c(10);      // 11
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
    run = false,
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
    emit a(1);       // TODO: elimina o [false]
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
    emit a(1);
    // unreachable
end;
// unreachable
await a;
// unreachable
escape 0;
]],
    run = false,
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
    emit a(1);
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
    emit a(1);
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
    emit a(1);
with
end;
await a;
escape 0;
]],
    run = false,
    _ana = {
        --unreachs = 2,
        abrt = 3,
        --isForever = true,
    },
    --trig_wo = 1,
}

Test { [[
var int v1=2; var int v2=3;
par/or do
with
end
escape v1+v2;
]],
    run = 5,
}
Test { [[
var int v1; var int v2;
par/or do
with
end
v1=2;
v2=3;
escape v1+v2;
]],
    run = 5,
    --inits = 'line 1 : uninitialized variable "v1" : reached yielding statement (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "v1" : reached `par/or` (/tmp/tmp.ceu:2)',
    --ref = 'line 1 : uninitialized variable "v1" crossing compound statement (/tmp/tmp.ceu:2)',
}
Test { [[
par/or do
with
end
var int v1; var int v2;
v1=2;
v2=3;
escape v1+v2;
]],
    run = 5,
}
Test { [[
var int v1=0; var int v2=0;
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
var int v1=0; var int v2=0;
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
var int v1=0; var int v2=0;
par/or do
    emit a(2);
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
var int v1=0; var int v2=0; var int v3=0;
par/or do
    emit a(2);
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
var int v1=0; var int v2=0; var int v3=0;
par/or do
    emit a(2);
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
        emit a(2);
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
        emit a(2);
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
    --run = 9,
    run = 4,
}

Test { [[
input int A;
var int a=0;
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
var int a=0;
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
var int a=0;
par/or do
    await A;
    a = 10;
with
    await A;
    var int v = a;
    if v!=0 then end;
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
var int a=0;
par/or do
    await A;
    a = 10;
with
    await A;
    a = 11;
end;
escape a;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input int A;
var int a=0;
par/or do
    await A;
    a = 10;
with
    await A;
    escape a;
end;
escape a;
]],
    run = false,
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
        if true then
            break;  // 8
        end;
    end;
end;
escape 0;
]],
    _ana = {
        abrt = 5,
    },
    run = false,
}

Test { [[
input int A;
loop do
    loop do
        par/or do
            await 1s;
        with
            if false then
                await A;
                break;
            end;
        end;
        await FOREVER;
    end;
end;
]],
    run = false,
    _ana = {
        abrt = 1,
        unreachs = 1,
        isForever = true,
    },
}

Test { [[
input int A; input int B;

loop do
    par/or do
        await B;
    with
        await A;
        if true then
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
    run = false,
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
input none A; input none B;
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
input none A; input none B;
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
input int A; input int B;
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
input int A; input int  Z;
var int v=0;
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
input int A; input int B; input int Z;
var int v=0;
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
input int A; input int B; input int Z;
var int v=0;
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
input int A; input int B;
var int v=0;
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
input int A; input int B;
var int v=0;
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
input int A; input int  B;
var int v=0;
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
var int v=0;
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
var int a=0;
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
input int A; input int B;
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
input none OS_START;
event int b; event int c;
var int cc = 1;
par/and do
    await OS_START;
    emit b(1);
    emit c(1);
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
var int a=0;
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
var int a=0;
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
var int a=0;
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
input none A;
var int a=0;
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
var int dt=0;
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
var int dt=0;
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
var int dt=0;
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
var int dt=0;
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
var int dt=0;
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
input int A; input int B;
var int ret=0;
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
input int A; input int B;
var int ret=0;
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
var int dt=0;
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
input int A; input int B;
var int dt=0;
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
input int A; input int B;
var int dt=0;
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
input int A; input int B;
var int dt=0;
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
input int A; input int  B;
var int dt=0;
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
var int dt=0;
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
var int dt=0;
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
input int A; input int B;
var int ret=0;
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
event int a; event int  b;
var int x=0;
par/or do
    await a;                // 4
    await 10ms;             // 5
    x = 0;
with
    var int bb = await b;   // 8
    emit a(bb);              // 9
    await 10ms;
    x = 1;
with
    emit b(1);       // 13
    x = 2;
    await FOREVER;
end;
escape x;
]],
    run = false,
    _ana = {
        abrt = 3,
        acc  = 2,    -- TODO: timer kills timer
        unreachs = 0,    -- TODO: timer kills timer
    },
    --run = { ['~>10ms']=0 },
}

Test { [[
event int a; event int  b;
var int x=0;
var int bb=0;
par/or do
    await a;
    await 10ms;
    x = 0;
with
    bb = await b;
    await 10ms;
    x = 1;
with
    emit b(1);
    emit a(bb);
    x = 2;
    await FOREVER;
end;
escape x;
]],
    run = false,
    _ana = {
        abrt = 3,
        acc = 3,     -- TODO: timer kills timer
        unreachs = 0,    -- TODO: timer kills timer
    },
    --run = { ['~>10ms']=0 },   -- TODO: intl timer
}

Test { [[
event int a; event int  b;
var int x=0;
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
    wrn = true,
    _ana = {
        abrt = 5,
        acc = 1,
        --unreachs = 4,
    },
    run = 1,
}

Test { [[
input int A; input int B;
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
    run = false,
    _ana = {
        abrt = 3,
        acc = 1,
    },
}

Test { [[
input int A; input int B;
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
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input int A; input int B; input int  Z;
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
    run = false,
    _ana = {
        abrt = 4,
        acc = 1,
    },
}

Test { [[
input int A; input int B;
var int a = 0;
par/or do
    par/or do
        await A;
    with
        await B;
    end;
    await 10ms;
    var int v = a;
    if v!=0 then end;
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
input int A; input int B;
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
    run = false,
    _ana = {
        abrt = 3,
        acc = 1,
    },
}

Test { [[
input int A; input int B;
var int a = 0;
par/or do
    par/and do
        await A;
    with
        await B;
        await 10ms;
    end;
    var int v = a;
    if v!=0 then end;
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
input int A; input int B;
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
    if v!=0 then end
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
input int A; input int B;
var int a=0;
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
    run = false,
    _ana = {
        abrt = 4,
        acc = 1,
    },
}

Test { [[
var int a=0;
par/or do
    await 10ms;
    var int v = a;
with
    await 10ms;
    a = 1;
end;
escape a;
]],
    run = false,
    _ana = {
        abrt = 3,
        acc = 1,
    },
}

Test { [[
input int A;
var int v=0;
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
    run = false,
    _ana = {
        isForever = true,
        acc = 1,
    },
}

Test { [[
input int A; input int B;
var int v=0;
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
    run = false,
    _ana = {
        isForever = true,
        acc = 1,       -- fiz na mao!
    },
}
-- bom exemplo de explosao de estados!!!
Test { [[
input int A; input int B;
var int v=0;
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
    run = false,
    _ana = {
        isForever = true,
        acc = 1,       -- nao fiz na mao!!!
    },
}

-- EX.04: join
Test { [[
input int A; input int B;
var int a=0;
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
var int a=0;
par/and do
    if a!=0 then
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
    run = false,
    _ana = {
        --acc = 1,
        acc = 3,
    },
}
Test { [[
input int A;
var int a=0;
if a!=0 then
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
    run = false,
    _ana = {
        --acc = 1,
        acc = 3,
    },
}
Test { [[
input int A;
var int a=0;
par do
    loop do
        if a!=0 then           // 5
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
    run = false,
    _ana = {
        isForever = true,
        acc = 5,
    },
}
Test { [[
var int v = do/_ par do
            escape 0;
        with
            escape 0;
end
        end;
if v!=0 then
    escape 1;
else
    if 1==1 then
        escape 1;
    else
        escape 0;
    end;
end;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
var int a=0;
var int v = do/_ par do
            escape 0;
        with
            escape 0;
end
        end;
if v!=0 then
    a = 1;
else
    a = 1;
end;
escape a;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
var int v = do/_ par do
            escape 1;
        with
            escape 2;
end
        end;
escape v;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

Test { [[
var int a=0;
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
    run = false,
    _ana = {
        acc = 1,
        abrt = 1,
    },
}
Test { [[
var int a=0;
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
    run = false,
    _ana = {
        abrt = 4,
        acc = 1,
    },
}
Test { [[
input int A;
var int a=0;
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
    run = false,
    _ana = {
        abrt = 4,
        acc = 1,
    },
}
Test { [[
input int A;
var int a=0;
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
    run = false,
    _ana = {
        abrt = 4,
        acc = 1,
    },
}
Test { [[
input int A;
var int a=0;
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
    run = false,
    _ana = {
        abrt = 4,
        acc = 1,
    },
}

Test { [[
var int a=0;
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
    run = false,
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
escape 1;
]],
    _ana = {
        abrt = 4,   -- TODO: break is inside par/or (should be 3)
    },
    run = 1,
}

Test { [[
var int a=0;
par/or do
    loop do
        await 10ms;     // 4
        if (true) then
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
    run = false,
    _ana = {
        abrt = 4,   -- TODO: break is inside par/or (should be 3)
        acc = 1,
    },
}

Test { [[
var int a=0;
par/or do
    loop do
        await 11ms;
        if (true) then
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
    run = false,
    _ana = {
        abrt = 4,
        acc = 1,
    },
}

Test { [[
input int A;
var int a=0;
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
    run = false,
    _ana = {
        abrt = 3,
        acc = 1,
    },
}

Test { [[
input int A;
var int a=0;
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
    run = false,
    _ana = {
        abrt = 3,
        acc = 1,
    },
}

Test { [[
input int A;
var int a=0;
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
var int a=0;
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
var int a=0;
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
input none A;
var int a=0;
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
var int x=0;
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
    run = false,
    _ana = {
        abrt = 5,
        acc = 1,
    },
}

Test { [[
var int x=0;
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
    run = false,
    _ana = {
        isForever = true,
        acc = 1,
    },
}

Test { [[
var int x=0;
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
    run = false,
    _ana = {
        isForever = true,
        acc = 1,
    },
}

Test { [[
event none a;
var int x=0;
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
    run = false,
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
        emit a(1);
    with
        await a;
    end;
end;
]],
    run = false,
    _ana = {
        isForever = true,
    },
}

Test { [[
event none a;
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
    run = false,
}

Test { [[
input none A;
event none a;
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
event none a;
loop do
    par/and do
        emit a;
    with
        await a;
    end
end
]],
    tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    _ana = {
        loop = true,
    },
}

Test { [[
event int a;
par do
    loop do
        par/or do
            emit a(1);
        with
            await a;
        end;
    end;
with
    var int aa = await a;
    emit a(aa);
end;
]],
    tight_ = 'line 3 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    _ana = {
        abrt = 1,
        acc = 2,
        isForever = true,
    },
    loop = 'line 3 : tight loop',
}

Test { [[
input int A;
event int a; event int  i; event int  j;
var int dd=0; var int  ee=0;
par/and do
    await A;
    emit a(1);
with
    dd = await a;
    emit i(5);
with
    ee = await a;
    emit j(6);
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
var int aa=0;
par do
    emit a(1);
    aa = 1;
with
    escape aa;
end;
]],
    run = false,
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
var int v=0; var int aa=1;
loop do
    par do
        v = aa;
    with
        await a;
    end;
end;
]],
    run = false,
    _ana = {
        isForever = true,
        unreachs = 1,
        reachs = 1,
    },
}
Test { [[
input int A;
event int b;
var int a=1; var int v=0;
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
    wrn = true,
    run = false,
    _ana = {
        isForever = true,
    },
}
Test { [[
input int A; input int B;
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
input none OS_START;
event int a;
var int b=0;
par/or do
    b = await a;
with
    await OS_START;
    emit a(3);
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
var int b=0;
par/or do
    b = await a;        // 4
with
    emit a(3);           // 6
with
    var int a = b;
end;
escape 0;
]],
    wrn = true,
    run = false,
    _ana = {
        abrt = 5,
        --unreachs = 2,
        acc = 1,
        --trig_wo = 1,
    },
}

Test { [[
input none OS_START;
event int b;
var int i=0;
par/or do
    await OS_START;
    emit b(1);
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
input none OS_START;
event int b; event int c;
var int cc=0;
par/or do
    await OS_START;
    emit b(1);
    cc = await c;
with
    await b;
    cc = 5;
    emit c(5);
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
-- TODO: ret=0 should not be required because the loop cannot escape w/o assigning to v
Test { [[
input int A;
var int ret=0;
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
input int A; input int B;
var int ret = do/_ loop do
        await A;
        par/or do
            await A;
        with
            var int v = await B;
            escape v;
        end;
    end end;
escape ret;
]],
    run = {
        ['1~>A ; 5~>B'] = 5,
        ['1~>A ; 1~>A ; 3~>B ; 1~>A ; 5~>B'] = 5,
    }
}

Test { [[
input int A; input int B;
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
    parser = 'line 2 : after `=` : expected expression',
    run = {
        ['1~>A ; 5~>B'] = 5,
        ['1~>A ; 1~>A ; 3~>B ; 1~>A ; 5~>B'] = 5,
    }
}

Test { [[
input int A;
event int a;
var int aa=0;
loop do
    var int v = await A;
    if v==2 then
        escape aa;
    end;
    emit a(v);
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
var int aa=0;
loop do
    var int v = await A;
    if v==2 then
        escape aa;
    else
        if v==4 then
            break;
        end;
    end;
    emit a(v);
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
input int A; input int B;
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
input int A; input int B;
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
input int A; input int B;
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
input int A; input int B;
var int ret=0;
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
input int A; input int B;
var int v=0;
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
input int A; input int B; input int Z;
var int ret=0;
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
input int A; input int B; input int Z;
var int v=0;
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
input int A; input int B; input int Z;
var int v=0;
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
input int A; input int B; input int Z;
var int v=0;
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
input int A; input int B;
var int v=0;
par/or do
    if true then
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
input int A; input int B;
var int v=0;
par/or do
    if true then
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
input int A; input int B; input int Z;
var int v=0;
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
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
input int A; input int B; input int Z;
var int v=0;
par/or do
    if true then
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
input int A; input int B;
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
input int A; input int B;
var int v=0;
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
input int A; input int B; input int Z;
var int a = 0;
par do
    loop do
        if a!=0 then
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
input int A; input int B;
if 11!=0 then
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
input int A; input int B;
loop do
    await A;
end;
if true then       // TODO: unreach
    await A;
else
    await B;
end;
escape 1;
]],
    run = false,
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
    run = false,
    _ana = {
        isForever = true
    },
}
Test { [[
input int A; input int B;
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
    run = false,
    _ana = {
        isForever = true,
    },
}
Test { [[
input int A; input int B; input int Z;
var int v=0;
loop do
    v = await A;
    if v!=0 then
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
input int A; input int B; input int Z; input int X; input int E; input int EE; input int GG; input int H; input int I; input int J; input int K; input int L;
var int v=0;
par/or do
    await A;
with
    await B;
end;
await Z;
await X;
await E;
await EE;
var int g = await GG;
if g!=0 then
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
        ['0~>A ; 0~>Z ; 0~>X ; 0~>E ; 0~>EE ; 0~>GG ; 0~>I ; 0~>J ; 0~>K ; 10~>L'] = 10,
        ['0~>B ; 0~>Z ; 0~>X ; 0~>E ; 0~>EE ; 1~>GG ; 0~>H ; 0~>J ; 0~>K ; 11~>L'] = 11,
    },
}

-- NONDET

Test { [[
var int a=0;
par do
    a = 1;
    escape 1;
with
    escape a;
end;
]],
    run = false,
    _ana = {
        abrt = 3,
    acc = 2,
    },
}
Test { [[
input int B;
var int a=0;
par do
    await B;
    a = 1;
    escape 1;
with
    await B;
    escape a;
end;
]],
    run = false,
    _ana = {
        acc = 2,
        abrt = 3,
    },
}
Test { [[
input int B; input int Z;
event int a;
var int aa=0;
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
    run = false,
    _ana = {
        --unreachs = 1,
        abrt = 3,
        acc = 2,
    },
}
Test { [[
input int Z;
event int a;
var int aa=0;
par do
    emit a(1);       // 5
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
input none OS_START;
event int a;
par do
    await OS_START;
    emit a(1);
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
input int B;
event int a;
var int aa=0;
par/or do
    await B;
    emit a(5);
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
input int B;
event int a;
var int aa=0;
par/or do
    await B;
    emit a(5);
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
var int aa=0;
par/or do
    await B;        // 5
    emit a(5);
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
input int B; input int Z;
event int a;
var int aa=5;
par/or do
    await B;
    emit a(5);
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
    emit a(0);
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
    emit a(1);
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
    emit a(1);
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
input int B; input int Z;
event int a;
var int aa=0;
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
input int B; input int Z;
event int aa;
var int a=0;
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
input none A;
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
var int aa=0;
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
    run = false,
    _ana = {
        --unreachs = 1,
        abrt = 4,
        acc  = 1,
    },
}
Test { [[
input int B;
event int a;
var int aa=0;
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
    run = false,
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
    run = false,
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
    inits = 'line 1 : uninitialized variable "a" : reached read access (/tmp/tmp.ceu:3)',
    --inits = 'line 1 : uninitialized variable "a" : reached yielding statement (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "a" : reached `par` (/tmp/tmp.ceu:2)',
    --ref = 'line 1 : uninitialized variable "a" crossing compound statement (/tmp/tmp.ceu:2)',
}
Test { [[
var int a=0;
par do
    escape a;
with
    a = 1;
    escape a;
end;
]],
    run = false,
    _ana = {
        acc = 2,
        abrt = 3,
    },
}
Test { [[
var int a=0;
par do
    a = 1;
    escape a;
with
    escape a;
end;
]],
    run = false,
    _ana = {
        abrt = 3,
        acc = 2,
    },
}
Test { [[
var int a=0;
par/or do
    a = 1;
with
    a = 1;
end;
escape a;
]],
    run = false,
    _ana = {
        abrt = 3,
        acc = 1,
    },
}
Test { [[
var int a=0;
par/or do
    a = 1;
with
    a = 1;
with
    a = 1;
end;
escape a;
]],
    run = false,
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
    run = false,
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
    emit a(1);
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
    --run = 1,
    run = 10,
}
Test { [[
event int a;
par/or do
    emit a(1);
with
    emit a(1);
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
event int a; event int b;
var int aa=2; var int bb=2;
par/or do
    emit a(1);
    aa = 2;
with
    emit b(1);
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
var int a=0; var int  b=0;
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
var int aa=0;
var int v = do/_ par do
    emit a(1);
    aa = 1;
    escape aa;
with
    emit a(1);
    escape aa;
with
    emit a(1);
    escape aa;
end
end;
escape v;
]],
    run = false,
    _ana = {
        acc = 8, -- TODO: not checked
        abrt = 9,
        --trig_wo = 3,
    },
}
Test { [[
var int v;
v = do/_ par do
    escape 1;
with
    escape 1;
with
    escape 1;
end
end;
escape v;
]],
    run = false,
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
    run = false,
    _ana = {
        abrt = 3,
        acc = 1,
    },
}
Test { [[
input int A;
var int a=0;
par do
    await A;
    escape a;
with
    await A;
    a = 1;
    escape a;
end;
]],
    run = false,
    _ana = {
        abrt = 3,
        acc = 2,
    },
}
Test { [[
input int A;
event int a;
await A;
emit a(1);
await A;
emit a(1);
escape 1;
]],
--~A;1~>a;~A;1~>a]],
    --trig_wo = 2,
    run = {
        ['0~>A ; 10~>A'] = 1,
    },
}
Test { [[
input none OS_START;
input int A;
event int a;
var int ret=0;
par/or do
    loop do
        var int v = await A;
        emit a(v);
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
input none OS_START;
event int a;
par do
    await OS_START;
    emit a(1);
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
var int aa=0;
par/or do
    emit a(1);
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
    wrn = true,
    run = false,
    _ana = {
        --nd_esc = 1,
        --unreachs = 1,
        acc = 2,
        abrt = 2,
    },
}
Test { [[
event int a;
var int aa=0;
par/or do
    emit a(1);
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
    wrn = true,
    safety = 2,
    run = false,
    _ana = {
        --nd_esc = 1,
        --unreachs = 1,
        acc = 5,
        abrt = 2,
    },
}
Test { [[
input int A;
var int v=0;
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
    run = false,
    _ana = {
        isForever = true,
        acc = 1,
    },
}
Test { [[
input int A;
var int v=0;
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
    run = false,
    _ana = {
        isForever = true,
        acc = 1,
    },
}
Test { [[
input int A; input int  B;
var int a=0;
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
    if v!=0 then end;
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
input int A; input int  B;
var int a=0;
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
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}
Test { [[
input int A; input int  B;
var int a=0;
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
input int A; input int  B; input int  Z;
var int v=0;
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
var int v = 0;
par/or do
    par/or do
        v = 1;
    with
        v = 2;
    end
    v = 3;
    await FOREVER;
with
    v = 4;
end;
escape v;
]],
    _ana = { acc=true },
    run = 4,
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
var int a=0; var int  b=0; var int  c=0; var int  d=0;
event int aa; event int  bb; event int  cc; event int  dd;
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
        emit bb(1);
        b=1;
    with
        emit aa(2);
        a=2;
    with
        emit cc(3);
        c=3;
    end;
    emit dd(4);
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
event int a; event int  b; event int  c;
var int aa=0; var int  bb=0; var int  cc=0;
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
        emit a(10);
        aa=10;
    with
        emit b(20);
        bb=20;
    with
        emit c(30);
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
event int a; event int  b; event int  c;
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
    emit a(1);
with
    emit a(1);
    await a;
end;
escape 0;
]],
    run = false,
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
    emit a(1);
    await a;
with
    emit a(1);
end;
escape 0;
]],
    run = false,
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
    emit a(1);
with
    emit a(1);
    await a;
end;
]],
    run = false,
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
input int A; input int  B;
var int v=0;
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
    run = false,
    _ana = {
        isForever = true,
    },
}

Test { [[
var int x=0;
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
    run = false,
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
var int b=0;
par do
    escape 3;
with
    b = 1;
    escape b+2;
end;
]],
    run = false,
    _ana = {
        abrt = 3,
        acc = 1,
    },
}

Test { [[
input int A;
var int v=0;
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
var int v1=0; var int  v2=0;
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
var int v=0;
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
    --ast = "line 4 : after `;` : expected `end`",
    parser = 'line 4 : after `;` : expected `end`',
}

Test { [[
input int A;
var int v1=0; var int v2=0;
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
var int v1=0; var int  v2=0;
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
var int v1=0; var int  v2=0; var int  v3=0;
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
var int v1=0; var int v2=0; var int v3=0; var int v4=0; var int v5=0; var int v6=0;
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
var int v1=0; var int v2=0; var int v3=0; var int v4=0; var int v5=0; var int v6=0;
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
input none A;
var int v1=0; var int v2=0; var int v3=0; var int v4=0; var int v5=0; var int v6=0;
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
var int v1=0; var int v2=0; var int v3=0; var int v4=0; var int v5=0; var int v6=0;
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
var int v1=0; var int v2=0; var int v3=0; var int v4=0; var int v5=0; var int v6=0;
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
    run = false,
    _ana = {
        unreachs = 3,
        acc = 1,
        abrt = 3,
    },
}

Test { [[
input int A; input int B;
var int v=0;
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
input int A; input int B; input int Z; input int X;
var int a = 0;
a = do/_ par do
    par/and do
        await A;
    with
        await B;
    end;
    escape a+1;
with
    await Z;
    escape a;
end
end;
a = a + 1;
await X;
escape a;
]],
    inits = 'line 9 : invalid access to variable "a" : assignment in enclosing `do` (/tmp/tmp.ceu:3)',
    --ref = 'line 9 : invalid access to uninitialized variable "a" (declared at /tmp/tmp.ceu:2)',
    --run = { ['0~>A;0~>B;0~>Z;0~>X'] = 2 }
}

Test { [[
input int A; input int B; input int Z; input int X;
var int a = 0;
a = do par do
    par/and do
        await A;
    with
        await B;
    end;
    escape 0+1;
with
    await Z;
    escape 0;
end
end;
a = a + 1;
await X;
escape a;
]],
    --ref = 'line 9 : invalid access to uninitialized variable "a" (declared at /tmp/tmp.ceu:2)',
    run = { ['0~>A;0~>B;0~>Z;0~>X'] = 2 }
}

Test { [[
input int A; input int B; input int Z; input int X;
var int a = 0;
a = do par do
    par/and do
        await A;
    with
        await B;
    end;
    escape 1;
with
    await Z;
    escape 0;
end
end;
a = a + 1;
await X;
escape a;
]],
    run = { ['0~>A;0~>B;0~>Z;0~>X'] = 2 },
    safety = 2,
    _ana = {
        acc = true,
    },
}

Test { [[
input int A; input int B; input int Z; input int X;
var int a = 0;
a = do par do
    par do
        await A;
        escape 0;
    with
        await B;
        escape 0;
    end;
with
    await Z;
    escape 0;
end
end;
a = a + 1;
await X;
escape a;
]],
    run = { ['0~>A;0~>B;0~>Z;0~>X'] = 1 }
}

Test { [[
input int A; input int B; input int Z; input int X;
var int a = 0;
a = do par do
    par do
        await A;
        escape 0;
    with
        await B;
        escape 0;
    end;
    // unreachable
with
    await Z;
    escape 0;
end
end;
a = a + 1;
await X;
escape a;
]],
    run = { ['0~>A;0~>B;0~>Z;0~>X'] = 1 }
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
var int b=0;
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
    var int b = do/_ loop do
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
        end;
    a = a + 2 + b;
end
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
    var int b = do/_ loop do
            par/or do
                await B;
            with
                var int v = await B;
                escape v;
            end;
            a = a + 1;
        end;
end;
    a = a + 2 + b;
end
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
var int b=0;
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
var int a=0; var int  b=0; var int  c=0; var int  d=0; var int  e=0; var int  f=0;
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
var int v=0;
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
var int v=0;
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
var int v=0;
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
    wrn = true,
    run = false,
    _ana = {
        unreachs = 2,
        acc = 1,
        abrt = 2,
    },
}

Test { [[
input int A; input int B;
var int v=0;
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
var int b=0; var int c=0; var int d=0;
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
var int b=0; var int c=0; var int d=0;
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
input int A; input int Z; input int X;
var int b=0;
par/or do
    b = 0;
    loop do
        var int v=0;
        par/and do
            await A;
        with
            v = await A;
        end;
        b = 1 + v;
    end;
with
    await Z;
    await X;
    escape b;
end;
]],
    _ana = {
        unreachs = 1,
    },
    run = {
        ['2~>Z ; 1~>A ; 1~>X'] = 2,
    }
}

Test { [[
input none OS_START;
await OS_START;
var int ret = 0;
var int i;
loop i in [0 -> 5[ do
    par/and do
    with
        ret = ret + i;
    end
end
escape ret;
]],
    run = 10,
}

Test { [[
input none A; input none Z;
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
input none X; input none Z;
var int b=0;
par/or do
    b = 0;
    loop do
        var int v=0;
        par/and do
        with
            v = await A;
        end;
        b = 1 + v;
    end;
with
    await Z;
    await X;
    escape b;
end;
]],
    _ana = {
        unreachs = 1,
    },
    run = { ['1~>A;~>Z;2~>A;~>X']=3 },
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
    parser = 'line 3 : after `=` : expected expression',
}

Test { [[
input int A;
var int c = 2;
var int d = do par do
    with
        escape c;
end
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
event int a; event int b;
par/or do
    emit a(2);
with
    emit b(5);
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
var int counter=0;
event int c;
par/and do
    loop do
        await A;
        counter = counter + 1;
    end;
with
    every c do
        // unreachable
        if counter == 200 then
            counter = 0;
        end;
    end;
end;
// unreachable
]],
    run = false,
    _ana = {
        isForever = true,
        unreachs = 3,
    },
}

Test { [[
input int A;
var int counter=0;
event int c;
par/and do
    loop do
        await A;
        counter = counter + 1;
    end;
with
    every c do
        // unreachable
        if counter == 200 then
            counter = 0;
        end;
    end;
end;
// unreachable
]],
    safety = 2,
    run = false,
    _ana = {
        isForever = true,
        unreachs = 3,
        acc = 3,
    },
}

Test { [[
event int a;
emit a(8);
escape 8;
]],
    run = 8,
    --trig_wo = 1,
}

Test { [[
event int a;
par/and do
    emit a(9);
with
    every a do
    end;
end;
]],
    run = false,
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
    emit a(9);
with
    loop do
        await a;
    end;
end;
]],
    wrn = true,
    run = false,
    _ana = {
        acc = 1,
        isForever = true,
        unreachs = 1,
    },
}

Test { [[
event int a; event int b;
    loop do
        par/or do
            await a;
        with
            await b;
        end;
    end;
escape 0;
]],
    tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}
Test { [[
event int a; event int b;
    loop do
        par/and do
            await a;
        with
            await b;
        end;
    end;
escape 0;
]],
    tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
input int A;
event int a; event int b;
var int v=0;
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
escape v;
]],
    wrn = true,
    _ana = {
        abrt = 2,
    },
    run = {
        ['1~>A ; 1~>A'] = 1,
    }
}

Test { [[
input int X; input int  E;
event int a; event int  b;
var int c=0;
par/or do
    await X;
    par/or do
        emit a(8);
    with
        emit b(5);
    end;
    var int v = await X;
    escape v;
with
    c = 0;
    loop do
        var int aa=0; var int bb=0;
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
    wrn = true,
    _ana = {
        abrt = 2,
        unreachs = 1,
        acc = 0,
        --trig_wo = 1,
    },
    run = {
        ['1~>X ; 1~>E'] = 8,    -- TODO: stack change (8 or 5)
    }
}

Test { [[
input int X; input int  E;
event int a; event int  b;
var int c=0;
par/or do
    await X;
    par/or do
        emit a(8);
    with
        emit b(5);
    end;
    var int v = await X;
    escape v;
with
    c = 0;
    loop do
        var int aa=0; var int bb=0;
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
    wrn = true,
    safety = 2,
    _ana = {
        abrt = 2,
        unreachs = 1,
        acc = 3,
        --trig_wo = 1,
    },
    run = {
        ['1~>X ; 1~>E'] = 8,    -- TODO: stack change (8 or 5)
    },
}

Test { [[
var int v;
par/and do
    v = 1;
with
    v = 2;
end;
escape v;
]],
    run = 2.
    --inits = 'line 1 : uninitialized variable "v" : reached `par/and` (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "v" : reached yielding statement (/tmp/tmp.ceu:2)',
    --ref = 'line 1 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:2)'
}

Test { [[
var int v;
par/and do
    v = 1;
with
end;
escape v;
]],
    inits = 'line 1 : uninitialized variable "v" : reached end of `par/and` (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "v" : reached yielding statement (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "v" : reached `par/and` (/tmp/tmp.ceu:2)',
    --ref = 'line 1 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:2)',
}

Test { [[
var int a;
loop do
    if false then
        a = 1;
    else
        do break; end
        a = 2;
    end
end
escape a;
]],
    wrn = true,
    inits = 'line 1 : uninitialized variable "a" : reached read access (/tmp/tmp.ceu:10)',
    --inits = 'line 1 : uninitialized variable "a" : reached `break` (/tmp/tmp.ceu:6)',
    --inits = 'line 1 : uninitialized variable "a" : reached yielding statement (/tmp/tmp.ceu:6)',
    --inits = 'line 1 : uninitialized variable "a" : reached `loop` (/tmp/tmp.ceu:2)',
    --ref = 'line 1 : uninitialized variable "a" crossing compound statement (/tmp/tmp.ceu:2)',
}

Test { [[
var int v;
par/or do
with
    v = 1;
end;
escape v;
]],
    --inits = 'line 1 : uninitialized variable "v" : reached yielding statement (/tmp/tmp.ceu:2)',
    inits = 'line 1 : uninitialized variable "v" : reached end of `par/or` (/tmp/tmp.ceu:2)',
    --ref = 'line 1 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:2)',
}

Test { [[
input int A; input int B;
event int a; event int b;
var int v;
par/or do
    par/and do
        var int v = await A;
        emit a(v);
    with
        await B;
        emit b(1);
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
    wrn = true,
    inits = 'line 3 : uninitialized variable "v" : reached read access (/tmp/tmp.ceu:12)',
    --inits = 'line 3 : uninitialized variable "v" : reached yielding statement (/tmp/tmp.ceu:4)',
    --inits = 'line 3 : uninitialized variable "v" : reached `par/or` (/tmp/tmp.ceu:4)',
    --ref = 'line 3 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:4)',
}

Test { [[
input int A; input int B;
event int a; event int b;
var int v=0;
par/or do
    par/and do
        var int v = await A;
        emit a(v);
    with
        await B;
        emit b(1);
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
    wrn = true,
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
input int A; input int B;
event int a; event int b;
var int v=0;
par/or do
    par/and do
        var int v = await A;
        emit a(v);
    with
        await B;
        emit b(1);
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
    wrn = true,
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
input int A; input int  B;
event int a; event int b;
var int v=0;
par/or do
    par/and do
        var int a = await A;
        v = a;
        escape v;
    with
        await B;
        emit b(1);
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
    wrn = true,
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
input int A; input int  B;
var int a=0;
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
    run = false,
    _ana = {
        isForever = true,
        acc = 1,
        unreachs = 1,
    },
}

-- EX.07: o `and` executa 2 vezes
Test { [[
input int X;
event int a;
loop do
    var int v = await X;
    emit a(v);
end;
]],
    run = false,
    _ana = {
        isForever = true,
        --trig_wo = 1,
    },
}

Test { [[
input int A; input int  X; input int  E;
event int a; event int  b; event int  c;
var int cc=0;                   // 0: cc=0
par/or do
    loop do
        var int v = await A;
        emit a(v);
    end;
with
    var int bb = 0;             // 0: cc=0/bb=0
    loop do
        var int v = await X;    // 1: v=1
        bb = v + bb;            // 1: bb=2
        emit b(bb);
    end;
with
    cc = 0;
    loop do
        var int aa=0; var int bb=0;
        par/or do
            aa = await a;
        with
            bb = await b;       // bb=2
        end;
        cc = aa+bb;             // cc=3
        emit c(cc);
    end;
with
    await E;
    escape cc;
end;
]],
    wrn = true,
    _ana = {
        unreachs = 1,
    },
    --trig_wo = 1,
    run = {
        ['1~>X ; 1~>X ; 3~>A ; 1~>X ; 8~>A ; 1~>E'] = 8,
    }
}

    -- Exemplo apresentacao RSSF
Test { [[
input int A; input int  Z;
event int b; event int  d; event int  e;
par/and do
    loop do
        await A;
        emit b(0);
        var int v = await Z;
        emit d(v);
    end;
with
    loop do
        var int dd = await d;
        emit e(dd);
    end;
end;
]],
    wrn = true,
    run = false,
    _ana = {
        isForever = true,
        unreachs = 1,
        --trig_wo = 2,
    },
}

    -- SLIDESHOW
Test { [[
input int A; input int Z; input int X;
var int i=0;
par/or do
    await A;
    escape i;
with
    i = 1;
    loop do
        var int o = do par do
                await Z;
                await Z;
                var int c = await Z;
                escape c;
            with
                var int d = await X;
                escape d;
end
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
0~>Z ; 0~>Z ; 2~>X ;  // 1
0~>Z ; 1~>X ;         // 2
0~>Z ; 0~>Z ; 0~>Z ;  // 3
0~>Z ; 0~>Z ; 0~>Z ;  // 4
0~>Z ; 0~>Z ; 2~>X ;  // 3
1~>X ;                // 4
1~>X ;                // 5
1~>A ;                // 5
]] ] = 5
    }
}

Test { [[
input int A; input int  B; input int  Z; input int  X;
var int v=0;
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
        await X;
    end;
end;
escape v;
]],
    run = {
        ['0~>B ; 0~>B ; 1~>A ; 2~>Z'] = 1,
        ['0~>B ; 0~>B ; 1~>X ; 2~>A'] = 2,
    }
}
Test { [[
input int A;
var int a=0;
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
    run = false,
    _ana = {
        unreachs = 1,
        acc = 1,
        abrt = 1,
    },
}
Test { [[
input int A;
event int a;
var int aa=0;
par/and do
    await A;
    emit a(1);
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
var int aa=0;
par/and do
    await A;
    emit a(1);
with
    aa = await a;
    emit a(aa);
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
    emit a(1);
with
    await a;
    await a;
    escape 1;
end;
]],
    run = false,
    _ana = {
        --isForever = true,
        unreachs = 2,
    },
}
-- EX.03: trig/await + await
Test { [[
input int A;
event int a; event int  b;
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
escape 0;
]],
    run = false,
    _ana = {
        --isForever = true,
        unreachs = 4,
        abrt = 3,
    },
}

-- EX.03: trig/await + await
Test { [[
input int A;
event int a; event int b;
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
escape 0;
]],
    run = false,
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
    emit a(1);
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
    run = false,
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
    emit a(1);
    aa=1;
    emit a(3);
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
var int aa=0;
par/or do
    await A;
    emit a(1);
    emit a(3);
    aa = 3;
with
    await a;
    aa = await a;
    aa = aa + 1;
end;
escape aa;
]],
    --run = { ['1~>A;1~>A']=3 }
    run = { ['1~>A;1~>A']=4 }
}

Test { [[
input int A; input int  B;
var int v=0;
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
    emit a(8);
with
    await a;
    await a;
    // unreachable
end;
// unreachable
escape 0;
]],
    run = false,
    _ana = {
        --isForever = true,
        unreachs = 2,
    },
}
Test { [[
input none OS_START;
input int A; input int B;
event int a;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    await B;
    emit a(1);
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
input int A; input int  B; input int  Z;
event int a;
var int aa=0;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    await B;
    emit a(10);
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
input int A; input int  B; input int  Z;
event int a;
var int aa=0;
par/and do
    par/or do
        await A;
    with
        await B;
    end;
    await B;
    emit a(10);
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
input none A;
event int a; event int b;
par/and do
    await A;
    emit a(1);
    await A;
    emit b(1);
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
input int A; input int  B; input int  Z; input int  X; input int  E;
var int d=0;
par/or do
    await A;
with
    await B;
end;
await Z;
par/and do
    d = await X;
with
    await E;
end;
escape d;
]],
    run = {
        ['1~>A ; 0~>Z ; 9~>X ; 10~>E'] = 9,
        ['0~>B ; 0~>Z ; 9~>E ; 10~>X'] = 10,
    },
}
Test { [[
input none OS_START;
event int a;
var int aa=0;
par/and do
    await OS_START;
    emit a(1);
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
    emit a(1);
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
input none OS_START; input none  A;
var int v = 0;
event none a; event none b;
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
    wrn = true,
    _ana = {
        unreachs = 1,
    },
    run = { ['~>A']=1 },
}

Test { [[
input none OS_START;
var int v = 0;
event int a; event int  b;
par/or do
    loop do
        var int aa = await a;
        emit b(aa);
        v = v + 1;
    end
with
    await OS_START;
    emit a(1);
    escape v;
end;
]],
    wrn = true,
    run = 1,
    _ana = {
        unreachs = 1,
    },
}

Test { [[
input none OS_START; input none  Z;
event none a; event none  b;
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
    await Z;
end;
escape 1;
]],
    wrn = true,
    run = { ['~>Z'] = 1 },
}

Test { [[
input none OS_START;
event int a; event int  b;
par/or do
    loop do
        par/or do
            var int aa = await a;
            emit b(aa);
        with
            var int bb = await b;
            if bb != 0 then end;
        end;
    end;
with
    await OS_START;
    emit a(1);
end;
escape 10;
]],
    wrn = true,
    run = 10,
}

Test { [[
input none OS_START; input none A;
var int v = 0;
var int x = 0;
event int a; event int  b;
par/or do
    loop do
        par/or do
            var int aa = await a;
            emit b(aa);
            v = v + 1;
        with
            loop do
                var int bb = await b;
                if bb != 0 then
                    break;
                end;
            end;
        end;
        x = x + 1;
    end;
with
    await OS_START;
    emit a(1);
    await A;
    emit a(1);
    await A;
    emit a(0);
    escape v+x;
end;
escape 10;
]],
    wrn = true,
    --nd_esc = 1,
    --run = { ['~>A;~>A'] = 1 },
    run = { ['~>A;~>A'] = 4 },
    run = false,
    _ana = {
        unreachs = 1,
    },
}

Test { [[
var int v1=0;
await async do
    var int v = v1 + 1;
end;
escape 0;
]],
    dcls = 'line 3 : internal identifier "v1" is not declared',
}

Test { [[
input int A; input int B; input int Z;
var int v1=0; var int v2=0;
par do
    loop do
        par/or do
            await B;
            await async do
                var int v = v1 + 1;
            end;
        with
            await B;
            await async do
                var int v = v2 + 1;
            end;
        with
            await A;
        end;
    end;
with
    await Z;
    v1 = 1;
    v2 = 1;
    escape v1 + v2;
end;
]],
    dcls = 'line 8 : internal identifier "v1" is not declared',
}

Test { [[
var int v=2;
await async (v) do
    var int a = v;
    if a!=0 then end;
end;
escape v;
]],
    run = 2,
}

Test { [[
var int v=2;
var int x=v;
var& int px = &x;
await async (px, v) do
    px = v + 1;
end;
escape x + v;
]],
    run = 5,
}

Test { [[
var int a = 0;
await async (a) do
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
await async (a) do
    a = 1;
    do
    end
end
escape a;
]],
    run = 1,
}

Test { [[
input none Z;
var int v=2;
var int ret = 0;
par/or do
    await async (ret,v) do        // nd
        ret = v + 1;
    end;
with
    v = 3;                  // nd
    await Z;
end
escape ret + v;
]],
    _ana = {
        acc = 1,
    },
    run = 7,
}

Test { [[
input int A; input int B; input int Z;
var int v1=0; var int v2=0;
par do
    loop do
        par/or do
            await B;
            await async (v1) do
                var int v = v1 + 1;
                if v!=0 then end
            end;
        with
            await B;
            await async (v2) do
                var int v = v2 + 1;
                if v!=0 then end
            end;
        with
            await A;
        end;
    end;
with
    await Z;
    v1 = 1;
    v2 = 1;
    escape v1 + v2;
end;
]],
    run = { ['1~>Z']=2 },
}

Test { [[
input int A; input int B; input int Z;
var int v1=0; var int v2=0;
par do
    loop do
        par/or do
            await B;
            await async do
                var int v = v1 + 1;
            end;
        with
            await B;
            await async do
                var int v = v2 + 1;
            end;
        with
            await A;
        end;
    end;
with
    await Z;
    v1 = 1;
    v2 = 1;
    escape v1 + v2;
end;
]],
    dcls = 'line 8 : internal identifier "v1" is not declared',
}

Test { [[
input none A; input none Z;
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
    await Z;
    escape v;
end;
]],
    run = {
        ['~>A; ~>A; ~>25ms; ~>Z'] = 2,
    }
}

Test { [[
input int P2;
par do
    loop do
        par/or do
            var int p2 = await P2;
            if p2 == 1 then
                escape 1;
            end;
        with
            loop do
                await 200ms;
            end;
        end;
    end;
with
    await async do
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
    run = 1,
}

    -- MISC

Test { [[
var int v=0;
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
    run = false,
    _ana = {
        --acc = 3,
        acc = 12,           -- TODO: not checked
        isForever = true,
    },
}

Test { [[
input none A; input none  B;
var int aa=0; var int  bb=0;
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
input int Z;
event int draw; event int  occurring; event int  sleeping;
var int x=0; var int  vis=0;
par do
    await Z;
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
            var int s=0;
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
    wrn = true,
    _ana = {
        unreachs = 1,
        acc = 3,
        abrt = 1,
    },
    run = { ['~>1000ms;1~>Z'] = 1 }
}

Test { [[
input int Z;
event int draw; event int  occurring; event int  sleeping;
var int x=0; var int  vis=0;
par do
    await Z;
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
            var int s=0;
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
    wrn = true,
    safety = 2,
    _ana = {
        unreachs = 1,
        acc = 6,
        abrt = 1,
    },
    run = { ['~>1000ms;1~>Z'] = 1 }
}

Test { [[
input none OS_START;
event int a; event int  b;
var int v=0;
par/or do
    every a do
        //await a;
        emit b(1);
        v = 4;
    end;
with
    every b do
        //await b;
        v = 3;
    end;
with
    await OS_START;
    emit a(1);
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
input none OS_START;
await OS_START;

native _pinMode, _digitalWrite;
native/pos do
##define pinMode(a,b)
##define digitalWrite(a,b)
end
_pinMode(13, 1);
_digitalWrite(13, 1);
do/_ escape 1; end

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
var int ret = 0;
input none STOP;
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
input none OS_START;
event int a;
var int v1=0; var int  v2=0;
par/and do
    par/or do
        await OS_START;
        emit a(10);
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
input none OS_START;
event int a;
var int aa=0;
par/or do
    loop do
        aa = await a;
        aa = aa + 1;
    end;
with
    await OS_START;
    emit a(1);
    emit a(aa);
    emit a(aa);
    emit a(aa);
    emit a(aa);
    emit a(aa);
end;
escape aa;
]],
    run = 7,
    --run = 2,
    wrn = true,
}

Test { [[
input none OS_START; input none A;
event int a;
var int aa=0;
par/or do
    loop do
        aa=await a;
        aa = aa + 1;
    end;
with
    await OS_START;
    emit a(1);
    await A;
    emit a(aa);
    await A;
    emit a(aa);
    await A;
    emit a(aa);
    await A;
    emit a(aa);
    await A;
    emit a(aa);
end;
escape aa;
]],
    wrn = true,
    run = { ['~>A;~>A;~>A;~>A;~>A'] = 7, },
}

Test { [[
input none OS_START; input none  A;
event int a; event int  b;
var int bb=0;
par/or do
    var int x;
    every x in b do
        bb=x;
        bb = bb + 1;
    end;
with
    await a;
    emit b(1);
    await A;
    emit b(bb);
    await A;
    emit b(bb);
    await A;
    emit b(bb);
    await A;
    emit b(bb);
    await A;
    emit b(bb);
    await A;
    emit b(bb);
with
    await OS_START;
    emit a(1);
    bb = 10;
end;
escape bb;
]],
    _ana = {
        --nd_esc = 1,
        unreachs = 1,
    },
    run = 10,
}

Test { [[
input none OS_START;
event int a;
var int aa=0;
par/or do
    await OS_START;
    emit a(0);
with
    aa = await a;
    aa= aa+1;
    emit a(aa);
    await FOREVER;
end;
escape aa;
]],
    run = 1,
}

Test { [[
input none OS_START;
event int a; event int b;
var int aa=0;
par/or do
    await OS_START;
    emit a(0);
with
    aa=await a;
    aa=aa+1;
    emit b(aa);
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
input int A; input int  Z;
event int c;
var int cc = 0;
par do
    loop do
        await A;
        emit c(cc);
    end;
with
    loop do
        cc = await c;
        cc = cc + 1;
    end;
with
    await Z;
    escape cc;
end;
]],
    wrn = true,
    run = { ['1~>A;1~>A;1~>A;1~>Z'] = 3 },
}

Test { [[
input none OS_START;
input int A; input int  Z;
event int c;
var int cc = 0;
par do
    loop do
        await A;
        emit c(cc);
    end;
with
    var int x;
    every x in c do
        cc = x;
        cc = cc + 1;
    end;
with
    await Z;
    escape cc;
end;
]],
    run = { ['1~>A;1~>A;1~>A;1~>Z'] = 3 },
    safety = 2,
    _ana = {
        acc = 4,
    },
}

Test { [[
input none OS_START;
event int a;
par do
    loop do
        await OS_START;
        emit a(0);
        emit a(1);
        await 10s;
    end;
with
    var int v1=0; var int v2=0;
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
event int a;
    var int v1; var int v2;
    v1 = await a;
    v2 = await a;
]],
    run = false,
    --inits = 'line 2 : uninitialized variable "v2" : reached yielding statement (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "v2" : reached `await` (/tmp/tmp.ceu:3)',
}

Test { [[
input none OS_START; input none  A;
event int a;
par do
    loop do
        await OS_START;
        emit a(0);
        await A;
    emit a(1);
        await 10s;
    end;
with
    var int v1=_; var int v2=_;
    v1 = await a;
    v2 = await a;
    escape v1 + v2;
end;
]],
    wrn = true,
    _ana = {
        --nd_esc = 1,
        unreachs = 2,
    },
    run = { ['~>A']=1 },
}

Test { [[
input int A;
event int c;
var int a=0;
par/or do
    var int x;
    every x in c do
        a = x;
    end;
with
    await A;
    emit c(1);
    a = 1;
end;
escape a;
]],
    wrn = true,
    run = { ['10~>A'] = 1 },
}

Test { [[
event int b; event int  c;
var int a=0;
par/or do
    var int cc;
    every cc in c do
        //var int cc = await c;        // 4
        emit b(cc+1);     // 5
        a = cc+1;
    end;
with
    var int bb;
    every bb in b do
        //var int bb = await b;        // 10
        a = bb + 1;
    end;
with
    emit c(1);           // 14
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
input int A; input int  Z;
var int i = 0;
event int a; event int  b;
par do
    par do
        loop do
            var int v = await A;
            emit a(v);
        end;
    with
        loop do
            var int aa = await a;
            emit b(aa);
            var int aa = await a;
            emit b(aa);
        end;
    with
        loop do
            var int bb = await b;
            emit a(bb);
            i = i + 1;
        end;
    end;
with
    await Z;
    escape i;
end;
]],
    wrn = true,
    run = { ['1~>A;1~>A;1~>A;1~>A;1~>A;1~>Z'] = 5 },
}

Test { [[
input none Z;
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
            emit x(xx);
        with
            yy = yy + 1;
            emit y(yy);
        end;
    end;
with
    loop do
        par/or do
            var int xxx = await x;
            a = a + xxx;
        with
            var int yyy = await y;
            b = b + yyy;
        end;
        c = a + b;
    end;
with
    await Z;
    escape c;
end;
]],
    wrn = true,
    _ana = {
        abrt = 2,
    },
    run = { ['~>1100ms ; ~>Z'] = 66 }   -- TODO: stack change
}

Test { [[
input none Z;
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
            emit x(xx);
        with
            yy = yy + 1;
            emit y(yy);
        end;
    end;
with
    loop do
        par/or do
            var int xxx = await x;
            a = a + xxx;
        with
            var int yyy = await y;
            b = b + yyy;
        end;
        c = a + b;
    end;
with
    await Z;
    escape c;
end;
]],
    wrn = true,
    safety = 2,
    _ana = {
        acc = 1,
        abrt = 2,
    },
    run = { ['~>1100ms ; ~>Z'] = 66 }   -- TODO: stack change
}

Test { [[
input none OS_START;
event int a; event int  b; event int  c;
var int x = 0;
var int y = 0;
par/or do
    await OS_START;
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
input none Z;
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
            emit x(xx);
        with
            yy=yy+1;
            emit y(yy);
        end;
        c = c + 1;
    end;
with
    loop do
        par/or do
            var int xxx = await x;
            a = xxx + a;
        with
            var int yyy = await y;
            b = yyy + b;
        end;
        c = a + b + c;
    end;
with
    await Z;
    escape c;
end;
]],
    wrn = true,
    _ana = {
        abrt = 2,
    },
    run = {
        ['~>99ms;  ~>Z'] = 0,
        ['~>199ms; ~>Z'] = 2,
        ['~>299ms; ~>Z'] = 6,
        ['~>300ms; ~>Z'] = 13,
        ['~>330ms; ~>Z'] = 13,
        ['~>430ms; ~>Z'] = 24,
        ['~>501ms; ~>Z'] = 40,
    }
}

Test { [[
input none OS_START;
event int a;
var int b=0;
par/and do
    await OS_START;
    emit a(1);
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
input none OS_START;
event int a;
var int b=0;
par/or do
    await OS_START;
    emit a(1);
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
input none OS_START;
event int a;
par do
    var int aa = await a;
    emit a(1);
    escape aa;
with
    await OS_START;
    emit a(2);
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
input none OS_START;
event int a; event int  b;
var int aa=0;
par/or do
    every a do
        //await a;
        emit b(1);
    end;
with
    await OS_START;
    emit a(1);
with
    await b;
    emit a(2);
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
input none OS_START;
event int a;
var int x = 0;
par do
    await OS_START;
    emit a(1);
    emit a(2);
    escape x;
with
    every a do
        x = x + 1;
    end
end
]],
    run = 2,
    --run = 1,
}
Test { [[
input none OS_START;
event int a;
var int x = 0;
par do
    await OS_START;
    emit a(1);
    emit a(2);
    escape x;
with
    every a do
        //await a;
        x = x + 1;
    end
end
]],
    run = 2,
    --run = 1,
    safety = 2,
    _ana = {
        acc = 1,
    },
}
Test { [[
input none OS_START; input none  A;
event int a;
var int x = 0;
par do
    await OS_START;
    emit a(1);
    await A;
    emit a(2);
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
input none OS_START; input none  A;
event int a;
var int x = 0;
par do
    await OS_START;
    emit a(1);
    await A;
    emit a(2);
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
    emit a(1);
    escape x;
with
    every a do
        //await a;
        x = x + 1;
    end
end
]],
    run = false,
    _ana = {
        acc = 1,
        --abrt = 1,
        unreachs = 0,
    },
}
Test { [[
input none OS_START;
event none a;
var int x = 0;
par/or do
    await OS_START;
    emit a(1);
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
    stmts = 'line 6 : invalid `emit` : types mismatch : "()" <= "(int)"',
}

-- TODO: STACK
Test { [[
input none OS_START;
event int a;
var int x = 0;
par/or do
    await OS_START;
    emit a(1);
    // unreachable
with
    await a;
    x = x + 1;
    await a;        // 11
    x = x + 1;
with
    await a;
    emit a(1);         // 15
    // unreachable
end
escape x;
]],
    _ana = {
        abrt = 1,
        acc = 1,
        unreachs = 2,
    },
    run = 2,
    --run = 1,
}

Test { [[
event int a; event int  x; event int  y; event int  vis;
par/or do
    par/and do
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
    emit a(1);
    emit x(0);
    emit y(0);
    emit vis(1);
    await FOREVER;
end;
]],
    wrn = true,
    run = false,
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
input none OS_START;
event none x; event none  y;
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
    wrn = true,
    _ana = {
        abrt = 1,
        acc = 5,
        --acc = 4,
        --trig_wo = 2,
        unreachs = 1,
    },
    run = 10,
    --run = 1,
}

Test { [[
input none OS_START;
event int a; event int  x; event int  y;
var int ret = 0;
par do
    par/and do
        await OS_START;
        emit x(1);           // 7
        emit y(1);           // 8
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
    emit a(1);
    ret = ret * 2;
    emit x(0);               // 7
    ret = ret + 1;
    emit y(0);               // 25
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
event int a; event int  x; event int  y; event int  vis;
par/or do
    par/and do
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
    emit a(1);
    emit x(0);
    emit y(0);
    emit vis(1);
    await FOREVER;
end;
]],
    wrn = true,
    run = false,
    _ana = {
        acc = 6,
        --trig_wo = 2,
        unreachs = 2,
        isForever = true,
    },
}

-- TODO: STACK
Test { [[
input none OS_START;
input int Z;
event int x; event int  w; event int  y; event int  z; event int  a; event int  vis;
var int xx=0; var int  ww=0; var int  yy=0; var int  zz=0; var int  aa=0; var int  vvis=0;
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
    emit a(aa);
    yy=1;
    emit y(yy);
    zz=1;
    emit z(zz);
    vvis=1;
    emit vis(vvis);
with
    await Z;
    escape aa+xx+yy+zz+ww;
end;
]],
    wrn = true,
    _ana = {
        abrt = 1,        -- false positive
        --trig_wo = 2,
        unreachs = 2,
    },
    run = { ['1~>Z']=7 },
    --run = { ['1~>Z']=5 },
}

    -- SCOPE / BLOCK

Test { [[do end;]],
    run = false,
    _ana = {
        reachs = 1,
        isForever = true,
    },
}
Test { [[do var int a=0; end;]],
    run = false,
    _ana = {
        reachs = 1,
        isForever = true,
    },
}
Test { [[
do/_
    var int a=0;
    if a!=0 then end;
    escape 1;
end;
]],
    run = 1
}

Test { [[
do/_
    var int a = 1;
    do
        var int a = 0;
        if a!=0 then end;
    end;
    escape a;
end;
]],
    wrn = true,
    run = 1,
}

Test { [[
input none A; input none  B;
do/_
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
do/_
    var int a = 1;
    var int b = 0;
    do/_
        escape a + b;
    end;
end;
]],
    run = 1,
}

Test { [[
input none A; input none  B;
do/_
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
input none A; input none  B;
var int a=0;
par/or do
    await A;
    var int a;
    a = 1;
    await A;
    if a!=0 then end;
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
    var int b=0;
    par/or do
        do b=1; end;
    with
        do b=2; end;
    end;
end;
escape 0;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 1,
    },
}

Test { [[
input none A; input none  B;
var int i=0;
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
    parser = 'line 1 : after `event` : expected `&` or `(` or type',
}

Test { [[
var int ret=0;
event int a;
par/or do
    do
        var int a = 0;
        par/or do
            par/or do
                emit a(40);
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
input none A;
    a = await A;
end;
escape a;
]],
    wrn = true,
    stmts = 'line 8 : invalid `emit` : unexpected context for variable "a"',
    --env = 'line 8 : identifier "a" is not an event (/tmp/tmp.ceu : line 5)',
    --dcls = 'line 23 : invalid use of `event`',
}

Test { [[
var int ret = 0;
event none a; event none b;
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
event none a;
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
var int ret=0;
var int aa=0;
par/or do
    do
        event int aa;
        par/or do
            par/or do
                emit aa(1);  // 9
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
    wrn = true,
    _ana = {
    abrt = 1,
        --nd_esc = 2,
        unreachs = 3,
        acc = 1,
    },
    run = { ['10~>A']=10 },
}

Test { [[
input none OS_START;
var int ret=0;
par/or do
    event int a;
    par/or do
        await OS_START;
        emit a(5);
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

-->>> ALIASES / REFERENCES / REFS / &

Test { [[
var int a = 1;
var& int b = &a;
a = 2;
b = b+a;
escape a+b;
]],
    run = 8,
}
Test { [[
var int a = 1;
var& int b = &a;
b = &a;
a = 2;
escape b;
]],
    --inits = 'line 3 : invalid binding : variable "b" is already bound',-- (/tmp/tmp.ceu:2)',
    --ref = 'line 3 : invalid attribution : variable "b" is already bound',
    run = 2,
}
Test { [[
var int a = 1;
var& int b;
if true then
    b = &a;
else
    b = &a;
end
escape b;
]],
    run = 1,
}
Test { [[
var int a = 1;
var& int b;
if true then
    b = &a;
    b = &a;
else
    b = &a;
end
escape b;
]],
    --inits = 'line 5 : invalid binding : variable "b" is already bound',-- (/tmp/tmp.ceu:4,/tmp/tmp.ceu:7)',
    --ref = 'line 3 : invalid attribution : variable "b" is already bound',
    run = 1,
}
Test { [[
var int a = 1;
var& int b;
if true then
    b = &a;
else
    b = &a;
    b = &a;
end
escape b;
]],
    -- TODO: /tmp/tmp.ceu:6
    --inits = 'line 7 : invalid binding : variable "b" is already bound',-- (/tmp/tmp.ceu:4,/tmp/tmp.ceu:6)',
    --ref = 'line 3 : invalid attribution : variable "b" is already bound',
    run = 1,
}
Test { [[
var int a = 1;
var& int b;
if true then
    b = &a;
else
    b = &a;
end
b = &a;
escape b;
]],
    --inits = 'line 8 : invalid binding : variable "b" is already bound',-- (/tmp/tmp.ceu:4,/tmp/tmp.ceu:6)',
    --ref = 'line 3 : invalid attribution : variable "b" is already bound',
    run = 1,
}
Test { [[
var int a = 1;
var& int b = a;
a = 2;
escape b;
]],
    inits = 'line 2 : invalid binding : expected operator `&` in the right side',
    --ref = 'line 2 : invalid attribution : missing alias operator `&` on the right',
}

Test { [[
var int a = 1;
var int b = 10;
var& int c;
if a==1 then
    c = &a;
else
    c = &b;
end
c = 100;
escape a+b;
]],
    run = 110,
}
Test { [[
var int a = 1;
var int b = 10;
var& int c;
if a==0 then
    c = &a;
else
    c = &b;
end
c = 100;
escape a+b;
]],
    run = 101,
}
Test { [[
var int a = 1;
var int b = 10;
var& int c;
if a==1 then
    c = &a;
    c = 100;
else
    c = &b;
end
escape a+b;
]],
    run = 110,
    --ref = 'line 6 : invalid extra access to variable "c" inside the initializing `if-then-else` (/tmp/tmp.ceu:4)',
}
Test { [[
var int a = 1;
var int b = 10;
var& int c;
if a==1 then
    c = &a;
else
    c = &b;
    c = 100;
end
escape a+b;
]],
    run = 11,
    --ref = 'line 8 : invalid extra access to variable "c" inside the initializing `if-then-else` (/tmp/tmp.ceu:4)',
}

Test { [[
native _V;
native/pos do
    int V = 10;
end
var& int v = &_V;
escape v;
]],
    dcls = 'line 5 : invalid operand to `&` : expected native call',
    --stmts = 'line 5 : invalid binding : unexpected native identifier',
    --gcc = 'error: assignment makes pointer from integer without a cast',
    --run = 10;
}

Test { [[
native _f, _int;
var&? _int v1 = &_f() finalize (v1) with end;
var&? _int v2 = &{f()};
escape v1! + v2!;
]],
    dcls = 'line 3 : invalid operand to `&` : expected native call',
    --dcls = 'line 3 : invalid operand to `&` : unexpected context for native "_{}"',
    --stmts = 'line 3 : invalid binding : unexpected native identifier',
}

Test { [[
native _f, _int;
var&? _int v1 = &_f() finalize (v1) with end;
var&? _int v2 = &{f()} finalize (v2) with end;
escape v1! + v2!;
]],
    fins = 'line 3 : invalid operand to `&` : expected native call',
}

Test { [[
native _V, _f;
native/pos do
    int V = 0;
    none f (int* v) {
        *v = 10;
    }
end
_f(&&_V);
escape _V;
]],
    run = 10,
}

Test { [[
var int a = 1;
var& int b = &&a;
a = 2;
escape b;
]],
    stmts = 'line 2 : invalid assignment : types mismatch : "int" <= "int&&"',
    --env = 'line 2 : types mismatch (`int&` <= `int&&`)',
    --run = 2,
}
Test { [[
var int x = 10;
var& int y = &&x;
escape y;
]],
    --env = 'line 2 : types mismatch (`int&` <= `int&&`)',
    stmts = 'line 2 : invalid assignment : types mismatch : "int" <= "int&&"',
}

Test { [[
native _V;
native/pos do
    int V = 10;
end
var& int v;
v = &_V;
escape v;
]],
    dcls = 'line 6 : invalid operand to `&` : expected native call',
    --dcls = 'line 6 : invalid operand to `&` : unexpected context for native "_V"',
    --stmts = 'line 6 : invalid binding : unexpected native identifier',
    --gcc = 'error: assignment makes pointer from integer without a cast',
    --env = 'line 5 : invalid attribution (int& vs _&&)',
    --run = 10;
}

Test { [[
native _Tx;
native/pos do
    int f (int v) {
        return v + 1;
    }
    typedef struct {
        int (*f) (int);
    } tp;
    tp Tx = { f };
end
var int v = 1;
var& int ref = &v;
escape _Tx.f(v);
]],
    run = 2,
}

Test { [[
var int a = 1;
var& int b;
escape b;
]],
    --ref = 'line 3 : reference must be bounded before use',
    --ref = 'line 3 : invalid access to uninitialized variable "b"',
    inits = 'line 2 : uninitialized variable "b" : reached read access (/tmp/tmp.ceu:3)',
    --run = 2,
}
Test { [[
var int a = 1;
var& int b;
b = &a;
a = 2;
escape b;
]],
    run = 2,
}
Test { [[
native _V;
native/pos do
    int V = 10;
end
var& int v;
v = &_V;
escape v;
]],
    dcls = 'line 6 : invalid operand to `&` : expected native call',
    --dcls = 'line 6 : invalid operand to `&` : unexpected context for native "_V"',
    --stmts = 'line 6 : invalid binding : unexpected native identifier',
    --gcc = 'error: assignment makes pointer from integer without a cast',
    --run = 10;
}

Test { [[
var& int a;
var int&& b = null;
a = b;
await 1s;
var int&& c = a;
escape 1;
]],
    stmts = 'line 3 : invalid assignment : types mismatch : "int" <= "int&&"',
    --env = 'line 3 : types mismatch (`int&` <= `int&&`)',
    --run = { ['~>1s']=1 },
}
Test { [[
native _V;
escape 0;
]],
    dcls = 'line 1 : native "_V" declared but not used',
}
Test { [[
var int vv = 10;
var& int v;
v = &&vv;
escape *v;
]],
    dcls = 'line 4 : invalid operand to `*` : expected pointer type',
    --env = 'line 6 : types mismatch (`int&` <= `int&&`)'
}
Test { [[
native/pos do
    int V = 10;
end
var int vv = 10;
var& int v;
v = &vv;
await 1s;
do
    var int vvv = 1;
    //native/nohold ___ceu_nothing;
    //___ceu_nothing(&&vvv);
end
escape v;
]],
    run = { ['~>1s']=10 };
}

Test { [[
var int a=1; var int  b=2;
var& int v;
if true then
else
    v = &b;
end
v = 5;
escape a + b + v;
]],
    inits = 'line 2 : uninitialized variable "v" : reached end of `if` (/tmp/tmp.ceu:3)',
    --ref = 'line 5 : reference must be bounded in the other if-else branch',
    --ref = 'line 5 : missing initialization for variable "v" in the other branch of the `if-then-else` (/tmp/tmp.ceu:3)',
}
Test { [[
var int a=1; var int  b=2;
var& int v;
if true then
    v = &a;
else
end
v = 5;
escape a + b + v;
]],
    inits = '/tmp/tmp.ceu : line 2 : uninitialized variable "v" : reached end of `if` (/tmp/tmp.ceu:3)',
    --ref = 'line 4 : missing initialization for variable "v" in the other branch of the `if-then-else` (/tmp/tmp.ceu:3)',
}
Test { [[
var int a=1; var int  b=2;
var& int v;
if true then
    v = &a;
else
    v = &b;
end
var& int x;
if false then
    x = &a;
else
    x = &b;
end
v = 5;
x = 1;
escape a + b + x + v;
]],
    run = 12,
}

Test { [[
native _V1, _V2;
native/pos do
    int V1 = 10;
    int V2 = 5;
end
var& int v;
if true then
    v = &_V1;
else
    v = &_V2;
end
v = 1;
escape _V1+_V2;
]],
    dcls = 'line 8 : invalid operand to `&` : expected native call',
    --dcls = 'line 8 : invalid operand to `&` : unexpected context for native "_V1"',
    --stmts = 'line 8 : invalid binding : unexpected native identifier',
    --gcc = 'error: assignment makes pointer from integer without a cast',
    --run = 6,
}

Test { [[
var int a=1; var int  b=2; var int  c=3;
var& int x;
if false then
    x = &a;
else/if true then
    x = &b;
else
    x = &c;
end
x = 10;
escape a + b + x + c;
]],
    run = 24,
}

Test { [[
var int a=1; var int  b=2; var int  c=3;
var& int v;
if true then
    v = &a;
else
    v = &b;
end
var& int x;
if false then
    x = &a;
else/if true then
    x = &b;
else
    x = &c;
end
v = 5;
x = 1;
escape a + b + x + v;
]],
    run = 12,
}

Test { [[
var int a=1; var int  b=2; var int  c=3;
var& int v;
if true then
    v = &a;
else
    v = &b;
end
var& int x;
if false then
    x = &a;
else
    if true then
        x = &b;
    else
        x = &c;
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
    var& int i = &v;
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
var& int i;
loop do
    i = &v;
    i = i + 1;
    break;
end
escape v;
]],
    wrn = true,
    --ref = 'reference declaration and first binding cannot be separated by loops',
    --ref = 'line 2 : uninitialized variable "i" crossing compound statement (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "i" : reached yielding statement (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "i" : reached `loop` (/tmp/tmp.ceu:3)',
    inits = 'line 4 : invalid binding : crossing `loop` (/tmp/tmp.ceu:3)',
}

Test { [[
var& int v;
if true then
    var int x=0;
    v = &x;
else
    var int x=0;
    v = &x;
end
escape 1;
]],
    scopes = 'line 4 : invalid binding : incompatible scopes',
}
Test { [[
var& int v;
var int x=10;
var int y=100;
if x > y then
    v = &x;
else
    v = &y;
end
escape v;
]],
    run = 100,
}

Test { [[
do
    sfc = &_TTF_RenderText_Blended();
finalize () with
    _SDL_FreeSurface(&&(sfc!));
end
]],
    parser = 'line 3 : after `(` : expected location',
}

Test { [[
do
    nothing;
finalize with
    nothing;
end
escape 0;
]],
    scopes = 'line 2 : invalid `finalize` : unexpected `nothing`',
}

Test { [[
var& int v;
//do
    var int x;
    v = &x;
//end
escape 1;
]],
    inits = 'line 3 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:4)',
    --ref = 'line 1 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:2)',
    --ref = 'line 4 : invalid access to uninitialized variable "x" (declared at /tmp/tmp.ceu:3)',
}

Test { [[
var& int v;
do
    var int x=1;
    v = &x;
end
escape 1;
]],
    scopes = 'line 4 : invalid binding : incompatible scopes',
    --ref = 'line 4 : invalid attribution : variable "x" has narrower scope than its destination',
    --ref = 'line 1 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:2)',
    --run = 1,
}

Test { [[
var& int v;
    var int x=1;
    v = &x;
escape v;
]],
    run = 1,
}

-->>> FINALLY / FINALIZE

Test { [[
native _Cnt;
    native/pure _Radio_getPayload;
    native/plain _message_t;
    var _message_t msg={};
    loop do
        await 1s;
        var _Cnt&& snd = _Radio_getPayload(&&msg, sizeof(_Cnt));
    end
]],
    --fin = 'line 5 : pointer access across `await`',
    cc = '1: error: unknown type name ‘message_t’',
    _ana = {
        isForever = true,
    },
}
Test { [[
native _Cnt;
    native/plain _message_t;
    native/pure _Radio_getPayload;
    var _message_t msg={};
    loop do
        await 1s;
        var _Cnt&& snd = _Radio_getPayload(&&msg, sizeof(_Cnt));
    end
]],
    cc = '1: error: unknown type name ‘message_t’',
    _ana = {
        isForever = true,
    },
}
Test { [[
do
do finalize with nothing; end
end
escape 1;
]],
    run = 1,
}

Test { [[
do finalize with
    do/_ escape 1; end;
end
escape 0;
]],
    props_ = 'line 2 : invalid `escape` : unexpected enclosing `finalize`',
}

Test { [[
native _malloc;
var int&& ptr = _malloc();
]],
    scopes = 'line 2 : invalid assignment : expected binding for "_malloc"',
    --fin = 'line 1 : must assign to a option reference (declared with `&?`)',
}

Test { [[
native _f;
var int&& a;
do
    a = _f;
finalize with
    do await FOREVER; end;
end
]],
    scopes = 'line 3 : invalid `finalize` : nothing to finalize',
    --scopes = 'line 5 : invalid `finalize` : expected `varlist`',
}

Test { [[
native _f;
var int&& a = null;
do
    _f = a;
finalize (_f) with
    do await FOREVER; end;
end
]],
    scopes = 'line 5 : invalid `finalize` : unmatching identifiers : expected "a" (vs. /tmp/tmp.ceu:4)',
}

Test { [[
var int&& aaa = null;
do
    var int&& bbb = null;
    do
        aaa = bbb;
    finalize (bbb) with
        aaa = (&&aaa as int&&);
    end
end
escape (aaa==(&&aaa as int&&)) as int;
]],
    run = 1,
}

Test { [[
native _f;
native/pos do
    int* f;
end
do
    var int&& a = null;
    do
        _f = a;
    finalize (a) with
        _f = &&_f as int&&;
    end
end
escape (_f == (&&_f as int&&)) as int;
]],
    run = 1,
}

Test { [[
loop do
    do
    var int&& a;
        var int&& b = null;
            a = b;
    end
end
]],
    tight_ = 'line 1 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    --tight = 'line 1 : tight loop', -- TODO: par/and
    --props = "line 8 : not permitted inside `finalize`",
    --fin = 'line 6 : attribution does not require `finalize`',
    --fin = 'line 6 : attribution to pointer with greater scope',
}

Test { [[
var int v = 10;
var int&& ptr = &&v;
await 1s;
escape *ptr;
]],
    ptrs = 'line 4 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:3)',
    --inits = 'line 4 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:3)',
    --fin = 'line 4 : unsafe access to pointer "ptr" across `await`',
}

Test { [[
var int&& a;
var int&& b = null;
a = b;
await 1s;
var int&& c = a;
escape 1;
]],
    ptrs = 'line 5 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:4)',
    --fin = 'line 5 : unsafe access to pointer "a" across `await`',
}

Test { [[
var int&& a;
var int&& b = null;
a = b;
await 1s;
var int&& c = a;
escape 1;
]],
    ptrs = 'line 5 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:4)',
    --fin = 'line 5 : unsafe access to pointer "a" across `await`',
}

Test { [[
var int v = 1;
var int&& x = &&v;
var int i;
loop i in [0 -> 10[ do
    *x = *x + 1;
    await 1s;
end
escape v;
]],
    run = { ['~>10s']=11 },
    --inits = 'line 5 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:4)',
    --fin = 'line 4 : unsafe access to pointer "x" across `loop` (/tmp/tmp.ceu : 3)',
}

Test { [[
event none e;
var int v = 1;
var int&& x = &&v;
var int i;
loop i in [0 -> 10[ do
    *x = *x + 1;
    emit e;
end
escape v;
]],
    run = 11,
    --inits = 'line 5 : invalid pointer access : crossed `loop` (/tmp/tmp.ceu:4)',
    --fin = 'line 5 : unsafe access to pointer "x" across `loop` (/tmp/tmp.ceu : 4)',
}

Test { [[
var int v = 1;
var int&& x = &&v;
var int i;
loop i in [0 -> *x[ do
    await 1s;
    v = v + 1;
end
escape v;
]],
    run = { ['~>20s']=2 },
    --tight_ = 'line 3 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
var int v = 1;
var int&& x = &&v;
var int i;
loop i in [0 -> *x[ do
    await 1s;
    v = v + 1;
end
escape v;
]],
    wrn = true,
    run = { ['~>1s']=2 },
}

Test { [[
loop do
    do
        var int&& a;
        var int&& b = null;
        do a = b;
        finalize (a) with
            do break; end;
        end
    end
end
]],
    wrn = true,
    scopes = 'line 5 : invalid `finalize` : nothing to finalize',
    --loop = 'line 1 : tight loop', -- TODO: par/and
    --props = "line 8 : not permitted inside `finalize`",
    --fin = 'line 6 : attribution does not require `finalize`',
    --fin = 'line 6 : attribution to pointer with greater scope',
}

Test { [[
loop do
    do
        var int&& a;
        var int&& b = null;
        do a = b;
        finalize (a) with
            do break; end;
        end
    end
end
]],
    tight_ = 'line 1 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    --scopes = 'line 5 : invalid `finalize` : nothing to finalize',
    --loop = 'line 1 : tight loop', -- TODO: par/and
    --props = "line 8 : not permitted inside `finalize`",
    --fin = 'line 6 : attribution does not require `finalize`',
    --fin = 'line 6 : attribution to pointer with greater scope',
}

Test { [[
loop do
    do
    var int&& a;
        var int&& b = null;
        do
            a = b;
        finalize (a) with
            do break; end;
        end
    end
end
]],
    --loop = 'line 1 : tight loop', -- TODO: par/and
    --props = "line 8 : not permitted inside `finalize`",
    --fin = 'line 6 : attribution does not require `finalize`',
    --scopes = 'line 5 : invalid `finalize` : nothing to finalize',
    tight_ = 'line 1 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}
Test { [[
loop do
    do
    var int&& a;
        var int&& b = null;
        do
            a = b;
        finalize (a) with
            do break; end;
        end
    end
end
]],
    --loop = 'line 1 : tight loop', -- TODO: par/and
    --props = "line 8 : not permitted inside `finalize`",
    --fin = 'line 6 : attribution does not require `finalize`',
    wrn = true,
    scopes = 'line 5 : invalid `finalize` : nothing to finalize',
}

Test { [[
var int ret = 0;
do
    var int b;
    do finalize with
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
    dcls = 'line 6 : internal identifier "a" is not declared',
}

Test { [[
var int ret =
do/_
    escape 1;
end;
escape ret;
]],
    run = 1,
}

Test { [[
native _v;
var int a;
do _v(&&a);
finalize with
    nothing;
end
escape(a);
]],
    --ref = 'line 2 : invalid access to uninitialized variable "a"',
    inits = 'line 2 : uninitialized variable "a" : reached read access (/tmp/tmp.ceu:3)',
}

Test { [[
native _f;
native/pos do
    none f (int* a) {
        *a = 10;
    }
    typedef none (*t)(int*);
end
native _t;
var _t v = _f;
await 1s;
var int a=0;
do v(&&a);
finalize with nothing; end;
escape(a);
]],
    --dcls = 'line 12 : invalid call : unexpected context for variable "v"',
    --env = 'line 8 : native variable/function "_f" is not declared',
    --fin = 'line 8 : attribution to pointer with greater scope',
    --inits = 'line 12 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:10)',
    ptrs = 'line 12 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:10)',
    --run = { ['~>1s']=10 },
}

Test { [[
do/_ v(&&a); finalize with nothing; end;
]],
    parser = 'line 1 : after `;` : expected statement',
}
Test { [[
native _f;
native/pos do
    none f (int* a) {
        *a = 10;
    }
    typedef none (*t)(int*);
end
native _t;
var _t v = _f;
await 1s;
var int a=0;
do v(&&a); finalize with nothing; end;
escape(a);
]],
    --dcls = 'line 12 : invalid call : unexpected context for variable "v"',
    --env = 'line 8 : native variable/function "_f" is not declared',
    --fin = 'line 8 : attribution to pointer with greater scope',
    --inits = 'line 12 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:10)',
    ptrs = 'line 12 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:10)',
}
Test { [[
native _f;
var int a = 0;
_f(&&a);
escape 0;
]],
    scopes = 'line 3 : invalid `call` : expected `finalize` for variable "a"',
}

Test { [[
native _f;
native/pre do
    none f (int* a) {
        *a = 10;
    }
    typedef none (*t)(int*);
end
native _t;
var _t v = _f;
    //native/nohold ___ceu_nothing;
    //___ceu_nothing(v);
await 1s;
do/_
    var int a=0;
    do
        _f(&&a);
    finalize (a) with
        nothing;
    end;
    escape(a);
end
]],
    --env = 'line 8 : native variable/function "_f" is not declared',
    --fin = 'line 8 : attribution to pointer with greater scope',
    --fin = 'line 11 : pointer access across `await`',
    run = { ['~>1s']=10 },
}

Test { [[
native _f;
native/pre do
    none f (int* a) {
        *a = 10;
    }
    typedef none (*t)(int*);
end
native _t;
var _t v = _f;
    //native/nohold ___ceu_nothing;
    //___ceu_nothing(v);
await 1s;
var int a=0;
do _f(&&a); finalize (a) with nothing; end;
escape(a);
]],
    --env = 'line 8 : native variable/function "_f" is not declared',
    --fin = 'line 8 : attribution to pointer with greater scope',
    --fin = 'line 11 : pointer access across `await`',
    run = { ['~>1s']=10 },
}

Test { [[
native _f;
native/pre do
    none f (int* a) {
        *a = 10;
    }
    typedef none (*t)(int*);
end
native _t;
var _t v = _f;
var int a=0;
do v(&&a); finalize (a) with nothing; end;
escape(a);
]],
    --dcls = 'line 11 : invalid call : unexpected context for variable "v"',
    --env = 'line 8 : native variable/function "_f" is not declared',
    run = 10,
}

Test { [[
native _f;
native/pre do
    none f (int* a) {
        *a = 10;
    }
    typedef none (*t)(int*);
end
native _t;
var _t v = _f;
var int a=0;
do _f(&&a); finalize (a) with nothing; end;
escape(a);
]],
    --env = 'line 8 : native variable/function "_f" is not declared',
    run = 10,
}

Test { [[
do
    emit e;
finalize with
    nothing;
end
escape i;
]],
    parser = 'line 2 : after `;` : expected statement',
    --env = 'line 11 : wrong argument #2 : cannot pass pointers',
    --fin = 'line 6 : invalid block for awoken pointer "p"',
    --run = 1,
}

Test { [[
var int a = 0;
do
finalize (a) with
end
]],
    scopes = 'line 2 : invalid `finalize` : unexpected `varlist`',
}

Test { [[
native _t, _new;
var&? _t conn_;
do
    conn_ = &_new();
finalize with
end
escape 1;
]],
    scopes = 'line 3 : invalid `finalize` : expected `varlist`',
}

Test { [[
native _int, _f;
var int v = 2;
var&? _int p = &_f(&&v)
                finalize (v) with
                    v = 5;
                end;
escape p!;
]],
    scopes = 'line 4 : invalid `finalize` : unmatching identifiers : expected "p" (vs. /tmp/tmp.ceu:3)',
    --run = 5,
}

Test { [[
var int&& ptr = null;
var int i;
loop i in [0 -> 100[ do
    await 1s;
    var int&& p = null;
    if (ptr != null) then
        p = ptr;
    end
    ptr = p;
end
escape 10;
]],
    --loop = true,
    --fin = 'line 5 : invalid pointer "ptr"',
    --inits = 'line 6 : invalid pointer access : crossed `loop` (/tmp/tmp.ceu:3)',
    ptrs = 'line 6 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:4)',
}

Test { [[
native _f;
do
    var int&& p1 = null;
    do
        var int&& p2 = null;
        _f(p1, p2);
    end
end
escape 1;
]],
    wrn = true,
    scopes = 'line 6 : invalid `call` : expected `finalize` for variable "p1"',
    --fin = 'line 6 : call requires `finalize`',
    -- multiple scopes
}

Test { [[
native _f;
native/pos do
    int f (int* v) {
        escape 1;
    }
end
var int v = _;
escape _f(&&v);
]],
    wrn = true,
    scopes = 'line 8 : invalid `call` : expected `finalize` for variable "v"',
    --fin = 'line 8 : call requires `finalize`',
}

Test { [[
var int ret = 0;

do finalize with
    nothing;
end

par/and do
    await 1s;
    ret = ret + 111;
with
    await 1s;
    ret = ret + 222;
end

escape ret;
]],
    run = { ['~>10s']=333 },
}

Test { [[
input none OS_STOP;
var int ret = 0;

par/or do

    input none OS_START;

    await OS_START;

    do finalize with
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
native _void, _alloc, _hold;
var&? _void tcp = &_alloc(1)
        finalize (tcp) with
        end;
_hold(tcp!);

escape 0;
]],
    scopes = 'line 5 : invalid `call` : expected `finalize` for variable "tcp"',
}

Test { [[
native _V, _void_ptr, _alloc, _hold;
native/nohold _dealloc, _unhold;
native/pre do
    typedef void* void_ptr;
    int V = 2;
    int* P = &V;
    void** alloc () {
        V++;
        return (void**)&P;
    }
    void dealloc (void* x) {
        ceu_assert(x == &V, "bug found");
        V*=2;
    }
    void hold (void* x) {
        ceu_assert(x == &V, "bug found");
        V*=2;
    }
    void unhold (void* x) {
        ceu_assert(x == &V, "bug found");
        V++;
    }
end

do
    var&? _void_ptr tcp = &_alloc()
            finalize (tcp) with
                _dealloc(tcp!);
            end;
    do
        _hold(tcp!);
    finalize (tcp) with
        _unhold(tcp!);
    end
end

escape _V;
]],
    run = 14,
}

Test { [[
native _V, _void, _alloc, _hold;
native/nohold _dealloc, _unhold;
native/pre do
    int V = 2;
    none* alloc () {
        V++;
        return &V;
    }
    none dealloc (none* x) {
        V*=2;
    }
    none hold (none* x) {
        V*=2;
    }
    none unhold (none* x) {
        V++;
    }
end

do
    var&? _void tcp = &_alloc()
            finalize (tcp) with
                _dealloc(&&tcp!);
            end;
    do
        _hold(&&tcp!);
    finalize (tcp) with
        _unhold(&&tcp!);
    end
end

escape _V;
]],
    run = 14,
}

Test { [[
native _V, _void, _alloc, _hold;
native/nohold _dealloc, _unhold;
native/pre do
    int V = 2;
    none* alloc () {
        V++;
        return &V;
    }
    none dealloc (none* x) {
        V*=2;
    }
    none hold (none* x) {
        V*=2;
    }
    none unhold (none* x) {
        V++;
    }
end

do
    var& _void tcp = &_alloc()
            finalize (tcp) with
                _dealloc(&&tcp);
            end;
    do
        _hold(&&tcp);
    finalize (tcp) with
        _unhold(&&tcp);
    end
end

escape _V;
]],
    run = 14,
}
Test { [[
native _void, _alloc;
native/pre do
    none* alloc () {
        return NULL;
    }
end

var& _void tcp = &_alloc()
        finalize (tcp) with
        end;
escape 0;
]],
    run = '8] -> runtime error: call failed',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int ret = 0;
var int i;
loop i do
    ret = 1;
    do finalize with
        ret = ret * 2;
    end
    break;
end
ret = ret + 1;
escape ret;
]],
    run = 3,
}

Test { [[
native _f;
native/plain _u8;
var[2] _u8 vec = _;
do
    _f(&&vec[0]);
finalize (vec) with
end
escape 1;
]],
    cc = '5:1: error: implicit declaration of function ‘f’',
}
--<<< FINALLY / FINALIZE

-->>> LOCK

Test { [[
var Lock l1 = _;
var int ret =
    do
        var int v = 0;
        par do
            watching 5s do
                lock l1 do
                    every 1s do
                        v = v + 1;
                    end
                end
            end
        with
            await l1.ok_unlocked;
        with
            native _ceu_assert;
            _ceu_assert(l1.is_locked, "bug found");
            lock l1 do
                escape v;
            end
        end
    end;
_ceu_assert(not l1.is_locked, "bug found");
escape ret;
]],
    run = { ['~>10s']=4 },
}

Test { [[
native _ceu_assert;
var Lock l1 = _;
var int ret =
    do
        var int v = 0;
        par do
            watching 5s do
                lock l1 do
                    every 1s do
                        v = v + 1;
                    end
                end
            end
        with
            await l1.ok_unlocked;
        with
            _ceu_assert(l1.is_locked, "bug found");
            lock l1 do
                watching 5s do
                    every 1s do
                        v = v + 1;
                    end
                end
            end
        with
            _ceu_assert(l1.is_locked, "bug found");
            lock l1 do
                escape v;
            end
        end
    end;
_ceu_assert(not l1.is_locked, "bug found");
escape ret;
]],
    run = { ['~>10s']=8 },
}

--<<< LOCK

Test { [[
native _t;
native/pos do
    typedef struct t {
        int* ptr;
    } t;
    int* f (int* ptr) {
        escape ptr;
    }
end
var int v = 10;
var _t t;
escape (t.ptr);
]],
    inits = 'line 11 : uninitialized variable "t" : reached read access (/tmp/tmp.ceu:12)',
    --ref = 'line 12 : invalid access to uninitialized variable "t" (declared at /tmp/tmp.ceu:11)',
    --run = 10,
}

Test { [[
native _V;
var int x;
_V = &x;
escape 0;
]],
    stmts = 'line 3 : invalid binding : unexpected context for native "_V"',
}

Test { [[
var int x;
var _char p = &x;
escape 0;
]],
    stmts = 'line 2 : invalid binding : expected declaration with `&`',
}

Test { [[
var s8 x;
var& u8 p = &x;
escape 0;
]],
    stmts = 'line 2 : invalid binding : types mismatch : "u8" <= "s8"',
}

Test { [[
native _t;
native/pure _f;
native/pos do
    typedef struct t {
        int* ptr;
    } t;
    int* f (int* ptr) {
        escape ptr;
    }
end
var int v = 10;
var _t t;
t.ptr = &_f(&&v);
escape (t.ptr);
]],
    stmts = 'line 13 : invalid binding : unexpected context for operator `.`',
    --stmts = 'line 13 : invalid binding : expected declaration with `&`',
    --ref = 'line 12 : invalid access to uninitialized variable "t" (declared at /tmp/tmp.ceu:11)',
    --run = 10,
}

Test { [[
native _t;
native/pure _f;
native/pos do
    typedef struct t {
        int* ptr;
    } t;
    int* f (int* ptr) {
        escape ptr;
    }
end
var int v = 10;
var& _t t;
t.ptr = &_f(&&v);
escape (t.ptr);
]],
    stmts = 'line 13 : invalid binding : unexpected context for operator `.`',
    --stmts = 'line 13 : invalid binding : expected declaration with `&`',
    --ref = 'line 12 : invalid access to uninitialized variable "t" (declared at /tmp/tmp.ceu:11)',
    --run = 10,
}

Test { [[
var int x;
do
    x = 1;
end
escape x;
]],
    --ref = 'line 1 : uninitialized variable "x" crossing compound statement (/tmp/tmp.ceu:2)',
    run = 1,
}

Test { [[
event none aaa;
event& none bbb = &aaa;
escape 1;
]],
    run = 1,
}

Test { [[
event none  a;
event& none b = &a;
b = &b;
escape 1;
]],
    --inits = 'line 3 : invalid binding : event "b" is already bound',-- (/tmp/tmp.ceu:2)',
    run = 1,
    --run = { ['~>1s'] = 1 },
}

Test { [[
event none a;
event& none b = &a;
par/and do
    await a;
with
    await b;
with
    emit b;
end
escape 1;
]],
    run = 1,
}
Test { [[
event int a;
event& int b = &a;
var int ret = 0;
par/and do
    ret = await a;
with
    await b;
with
    emit b(10);
end
escape ret;
]],
    run = 10,
}

Test { [[
event none  a;
event& none b = &a;

par/or do
    await 1s;
    emit a;
with
    await b;
end

par/or do
    await 1s;
    emit b;
with
    await a;
end

escape 1;
]],
    run = { ['~>2s'] = 1 },
}

Test { [[
var int* v;
escape 1;
]],
    parser = 'after `int` : expected type modifier or internal identifier',
}
Test { [[
var& int v;
escape 1;
]],
    dcls = 'line 1 : variable "v" declared but not used',
}
Test { [[
var& int&& v;
escape 1;
]],
    wrn = true,
    --inits = 'line 1 : uninitialized variable "v"',
    dcls = 'line 1 : invalid declaration : unexpected `&&` : cannot alias a pointer',
}
Test { [[
var& int  v;
escape 1;
]],
    wrn = true,
    --inits = 'line 1 : uninitialized variable "v"',
    run = 1,
}
Test { [[
var int i;
var& int a = &i;
escape i;
]],
    inits = 'line 1 : uninitialized variable "i" : reached read access (/tmp/tmp.ceu:2)',
}
Test { [[
var int i = 1;
var& int a = &i;
escape a;
]],
    run = 1,
}
Test { [[
var int&& p = null;
var& int&&  v = &p;
escape 1;
]],
    todo = 'removed support for pointer alias',
    run = 1,
}
Test { [[
var& int&  v;
escape 1;
]],
    parser = 'line 1 : after `int` : expected type modifier or internal identifier',
    --env = 'line 1 : invalid type modifier : `&&`',
}

-- REFS: none&
Test { [[
var int v = 10;
var& none p = &v;
escape *((&&p) as int&&);
]],
    --parser = 'line 3 : after `(` : expected location',
    run = 10,
}
Test { [[
var int v = 10;
var& none p = &v;
var none&& p1 = &&p;
escape *((p1 as int&&));
]],
    run = 10,
}

Test { [[
native/pre do
    typedef struct {
        int x;
    } t;
end
native/plain _t;
var _t t = { (t){11} };
var& _t t_ = &t;
escape t_.x;
]],
    run = 11,
}

Test { [[
var int&& x = null;
var& int&& y = &x;
escape 0;
]],
    dcls = 'line 2 : invalid declaration : unexpected `&&` : cannot alias a pointer',
}

-->> ALIAS / ESCAPE / DO

Test { [[
var int? x = do
    escape 1;
end;
escape x!;
]],
    run = 1,
}

Test { [[
var int? x = do
    if true then
        escape 1;
    end
end;
escape x!;
]],
    run = 1,
}

Test { [[
var int? x = do
    if false then
        escape 1;
    end
end;
escape (x? as int) + 1;
]],
    run = 1,
}

Test { [[
var& int x = do
    var int y = 10;
    escape &y;          // err scope
end;
escape x;
]],
    --stmts = 'line 1 : invalid binding : expected `&?` modifier',
    scopes = 'line 3 : invalid binding : incompatible scopes',
}

Test { [[
var int x=0;
var&? int xxx = &x;
escape 2;
]],
    --dcls = 'line 2 : invalid declaration : option alias : expected native or `code/await` type',
    run = 2,
}

Test { [[
var&? int xxx = do
    var int y = 10;
    escape &y;
end;
escape (xxx? as int) + 1;
]],
    scopes = 'line 3 : invalid binding : incompatible scopes',
    --dcls = 'line 1 : invalid declaration : option alias : expected native or `code/await` type',
    --run = 1,
}

Test { [[
var int? x = do
end;
escape (x? as int) + 1;
]],
    run = 1,
}

--<< ALIAS / ESCAPE / DO

-- TODO: support aliases to constants

Test { [[
data Dd with
    var int x = 10;
end
code/tight Ff (none) -> Dd do
    var Dd d = _;
    escape d;
end
escape call Ff().x;
]],
    run = 10,
    todo = 'support indexing calls',
}

Test { [[
var& int x = &1;
escape x;
]],
    --stmts = 'line 1 : invalid binding : unexpected context for value "1"',
    stmts = 'line 1 : invalid binding : expected native type',
    --run = 1,
    --todo = 'support aliases to constants',
}

Test { [[
data Dd with
    var int x;
end
code/await Ff (var& Dd x) -> int do
    escape x.x + 1;
end
escape await Ff(&Dd(1));
]],
    parser = 'line 7 : after `escape` : expected expression or `;`',
    --todo = 'support aliases to data',
    --run = 1,
}

-->> ALIAS / OPTION / NIL

Test { [[
var int x = 10;
var int y = 20;
var& int v = &x;
loop do
    v = &y;
    break;
end
escape v;
]],
    run = 20,
}

Test { [[
var int x = 10;
var int y = 20;
var& int v = &x;
loop do
    v = &y;
    break;
end
escape v;
]],
    run = 20,
}

Test { [[
var int x = 10;
var int y = 20;
var& int v;
loop do
    v = &y;
    break;
end
escape v;
]],
    inits = 'line 5 : invalid binding : crossing `loop` (/tmp/tmp.ceu:4)',
}

Test { [[
code/await Ff (none) -> none do end
var&? Ff v;
escape (v? as int) + 1;
]],
    run = 1,
}

Test { [[
var&? int v;
escape (v? as int) + 1;
]],
    run = 1,
}

Test { [[
var int x = 10;
var&? int v = &x;
escape (v? as int) + 1;
]],
    run = 2,
}

Test { [[
var int x = 10;
var int y = 20;
var&? int v;
loop do
    v = &y;
    break;
end
escape v!;
]],
    run = 20,
}

Test { [[
var& int v = _;
escape 0;
]],
    stmts = 'line 1 : invalid binding : expected option alias',
    --inits = 'line 1 : invalid binding : expected operator `&` in the right side',
}

Test { [[
var int x = 10;
var&? int v = &x;
v = _;
escape (v? as int) + 1;
]],
    run = 1,
}

--<< ALIAS / OPTION / NIL

-->> OPTION / ALIAS / ID_any

Test { [[
code/tight Ff (var&? int i) -> int do
    if i? then
        escape i!;
    else
        escape 99;
    end
end
var int x = 1;
escape call Ff(_) + call Ff(&x);
]],
    wrn = true,
    run = 100,
}

Test { [[
code/tight Gg (var&? int i) -> int do
    if i? then
        escape i!;
    else
        escape 99;
    end
end
code/tight Ff (var&? int i) -> int do
    escape call Gg(&i);
end
var int x = 1;
escape call Ff(_) + call Ff(&x);
]],
    wrn = true,
    run = 100,
}

Test { [[
par do
with
    escape 1;
end
]],
    run = 1,
}

Test { [[
var int ret = do
    par do
    with
        escape 1;
    end
end;
escape ret;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> int do
    var int ret = do
        par do
        with
            escape 1;
        end
    end;
    escape ret;
end
var int ret = await Ff();
escape ret;
]],
    run = 1,
}

Test { [[
code/await Ff (var&? int i) -> int do
    if i? then
        escape i!;
    else
        escape 99;
    end
end
var int x = 1;
var int v1 = await Ff(_);
var int v2 = await Ff(&x);
escape v1 + v2;
]],
    wrn = true,
    run = 100,
}

Test { [[
code/await Ff (var& int i) -> int do
    escape 1;
end
var int v1 = await Ff(_);
escape v1;
]],
    wrn = true,
    dcls = 'line 4 : invalid call : invalid binding : argument #1 : expected location',
}

Test { [[
code/await Ff (var&? int i) -> int do
    escape i!;
end
var int v1 = await Ff(_);
escape v1;
]],
    --wrn = true,
    run = 'Aborted (core dumped)',
}

Test { [[
code/await Gg (var&? int i) -> int do
    if i? then
        escape i!;
    else
        escape 99;
    end
end
code/await Ff (var&? int i) -> int do
    var int ret = await Gg(&i);
    escape ret;
end
var int x = 1;
var int v1 = await Ff(_);
var int v2 = await Ff(&x);
escape v1 + v2;
]],
    --wrn = true,
    run = 100,
}

--<< OPTION / ALIAS / ID_any

--<<< ALIASES / REFERENCES / REFS / &

Test { [[
native _f;
do _f(); finalize with nothing;
    end;
escape 1;
]],
    scopes = 'line 2 : invalid `finalize` : nothing to finalize',
    --fin = 'line 2 : invalid `finalize`',
}

Test { [[
var int v = 0;
do
    do finalize with
        v = v * 2;
    end
    v = v + 1;
    do finalize with
        v = v + 3;
    end
end
escape v;
]],
    run = 8,
}

Test { [[
native _f;
native/pos do none f (none* p) {} end

var none&& p=null;
do
    _f(p);
finalize (p) with
    nothing;
end;
escape 1;
]],
    run = 1,
}

Test { [[
native _f;
native/pos do none f () {} end

var none&& p = null;
do _f(p!=null); finalize with nothing;
    end;
escape 1;
]],
    scopes = 'line 5 : invalid `finalize` : nothing to finalize',
    --fin = 'line 5 : invalid `finalize`',
    --run = 1,
}

Test { [[
native _f;
do
    var int&& p1 = null;
    do
        var int&& p2 = null;
        _f(p1, p2);
    end
end
escape 1;
]],
    scopes = 'line 6 : invalid `call` : expected `finalize` for variable "p1"',
}
Test { [[
native _f;
do
    var int&& p1 = null;
    do
        var int&& p2 = null;
        do
            _f(p1, p2);
        finalize with
        end
    end
end
escape 1;
]],
    scopes = 'line 7 : invalid `finalize` : incompatible scopes',
    --fin = 'line 6 : invalid call (multiple scopes)',
}
Test { [[
native _enqueue, _V;
var byte&& buf = _V;
_enqueue(buf);
escape 1;
]],
    scopes = 'line 3 : invalid `call` : expected `finalize` for variable "buf"',
    --fin = 'line 2 : call requires `finalize`',
}

Test { [[
native _f;
native _v;
native/pos do
    int v = 1;
    int f (int v) {
        return v + 1;
    }
end
escape _f(_v);
]],
    --fin = 'line 3 : call requires `finalize`',
    run = 2,
    --fin = 'line 9 : attribution requires `finalize`',
}
Test { [[
native/pure _f;
native _v;
native/pos do
    int v = 1;
    int f (int v) {
        return v + 1;
    }
end
escape _f(_v);
]],
    --fin = 'line 3 : call requires `finalize`',
    run = 2,
}


Test { [[
native/pure _f;
native/pos do
    int* f (int a) {
        return NULL;
    }
end
var int&& v = _f(0);
escape (v == null) as int;
]],
    run = 1,
}

Test { [[
native/pure _f;
native/pos do
    int V = 10;
    int f (int v) {
        return v;
    }
end
native/const _V;
escape _f(_V);
]],
    run = 10;
}

Test { [[
native _f;
native/pos do
    int f (int* v) {
        return 1;
    }
end
var int v=0;
escape (_f(&&v) == 1 )as int;
]],
    scopes = 'line 8 : invalid `call` : expected `finalize` for variable "v"',
    --fin = 'line 8 : call requires `finalize`',
}

Test { [[
native/nohold _f;
native/pos do
    int f (int* v) {
        return 1;
    }
end
var int v=0;
escape (_f(&&v) == 1 )as int;
]],
    run = 1,
}

Test { [[
native _V;
native/nohold _f;
native/pos do
    int V=1;
    int f (int* v) {
        return 1;
    }
end
var int v=0;
escape (_f(&&v) == _V) as int;
]],
    run = 1,
}

Test { [[
var int ret = 0;
var int&& pa=null;
do
    var int v=0;
    if v!=0 then end;
    if true then
        do finalize with
            ret = ret + 1;
    end
    else
        do finalize with
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
var int&& pa=null;
do
    var int v=0;
    pa = &&v;
end
escape ret;
]],
    --run = 1,
    --fin = 'line 7 : attribution does not require `finalize`',
    scopes = 'line 5 : invalid pointer assignment : expected `finalize`',
}
Test { [[
var int ret = 0;
var int&& pa=null;
do
    var u8 v=0;
    do
        pa = (&&v as int&&);
    finalize (pa) with
        ret = ret + 1;
    end
end
escape ret;
]],
    scopes = 'line 7 : invalid `finalize` : unmatching identifiers : expected "v" (vs. /tmp/tmp.ceu:6)',
    --fin = 'line 7 : attribution does not require `finalize`',
}
Test { [[
var int ret = 0;
var int&& pa=null;
do
    var u8 v=0;
    do
        pa = (&&v as int&&);
    finalize (v) with
        ret = ret + 1;
    end
end
escape ret;
]],
    run = 1,
    --fin = 'line 7 : attribution does not require `finalize`',
}
Test { [[
var int ret = 0;
var int&& pa=null;
do
    var int v=0;
    do
        pa = &&v;
    finalize (v) with
        ret = ret + 1;
    end
end
escape ret;
]],
    run = 1,
    --fin = 'line 7 : attribution does not require `finalize`',
}
Test { [[
var int ret = 0;
do
var int&& pa=null;
    var int v=0;
    if true then
        do pa = &&v;
        finalize (v) with
            ret = ret + 1;
    end
    else
        do pa = &&v;
        finalize (v) with
            ret = ret + 2;
    end
    end
end
escape ret;
]],
    --run = 1,
    scopes = 'line 6 : invalid `finalize` : nothing to finalize',
    --fin = 'line 7 : attribution does not require `finalize`',
}
Test { [[
var int ret = 0;
var int&& pa=null;
do
    var int v=0;
    if true then
            pa = &&v;
    else
            pa = &&v;
    end
end
escape ret;
]],
    --run = 1,
    scopes = 'line 6 : invalid pointer assignment : expected `finalize`',
    --fin = 'line 6 : attribution to pointer with greater scope',
}

Test { [[
var int ret = 0;
var int&& pa=null;
do
    var int v=0;
    if true then
        do
            pa = &&v;
        finalize (v) with
            ret = ret + 1;
        end
    else
        do
            pa = &&v;
        finalize (v) with
        end
    end
end
escape ret;
]],
    run = 1,
    --fin = 'line 6 : attribution to pointer with greater scope',
}

Test { [[
var int r = 0;
do
    await 1s;
    do
    finalize with
        do
            var int b = 111;
            r = b;
        end;
    end
end
escape r;
]],
    run = { ['~>1s']=111 },
}

Test { [[
var int ret = 0;
do
    await 1s;
    do finalize with
        var int a = 1;
    end
end
escape ret;
]],
    run = { ['~>1s']=0 },
}

Test { [[
do
    do finalize with
        if true then
        end;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
var int ret=0;
do
    var int a = 1;
    do finalize with
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
var int ret=0;
do
    var int a = 1;
    do finalize with
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
    var int a=0;
    do finalize with
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
var int a=0;
par/or do
    do finalize with
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
var int a=0;
par/or do
    do
        var int a;
        do finalize with
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
var int ret=0;
par/or do
    do
        await 1s;
        do finalize with
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
input none A;
var int ret = 1;
loop do
    par/or do
        do
            await A;
            do finalize with
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
input none A;
var int ret = 1;
loop do
    par/or do
        do
            await A;
            do finalize with
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
input none A;
var int ret = 1;
loop do
    par/or do
        do
            await A;
            do finalize with
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
    run = false,
    ana = 'line 4 : at least one trail should terminate',
}

Test { [[
input none A;
var int ret = 1;
loop do
    par/or do
        do
            do finalize with
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
input none A; input none  B;
var int ret = 1;
par/or do
    do
        do finalize with
            ret = 1;
    end
        await A;
    end
with
    do
        await B;
        do finalize with
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
input none A; input none  B;
var int ret = 1;
par/or do
    do
        do finalize with
            ret = 1;
    end
        await A;
    end
with
    do
        await B;
        do finalize with
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
input none A; input none  B; input none  Z;
var int ret = 1;
par/or do
    do
        await A;
        do finalize with
            ret = 1;
    end
    end
with
    do
        await B;
        do finalize with
            ret = 2;
    end
    end
with
    do
        await Z;
        do finalize with
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
input none A; input none  B;
event none a;
var int ret = 1;
par/or do
    do
        await A;
        do finalize with
            do
                emit a;
                ret = ret * 2;
    end
            end;
    end
with
    do
        await B;
        do finalize with
            ret = ret + 5;
    end
    end
with
    every a do
        ret = ret + 1;
    end
end
escape ret;
]],
    props = 'line 9 : not permitted inside `finalize`',
}

Test { [[
input none A; input none  B;
event none a;
var int ret = 1;
par/or do
    do
        do finalize with
            ret = ret * 2;      // 7
    end
        await A;
        emit a;
    end
with
    do
        do finalize with
            ret = ret + 5;      // 15
    end
        await B;
    end
with
    every a do
        //await a;
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
input none A; input none  B;
event none a;
var int ret = 1;
par/or do
    do
        do finalize with
            ret = ret * 2;      // 7
    end
        await A;
        emit a;
    end
with
    do
        do finalize with
            ret = ret + 5;      // 15
    end
        await B;
    end
with
    every a do
        //await a;
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
input none A;
var int ret = 1;
par/or do
    do
        ret = ret + 1;
        do
            await A;
            do finalize with
                ret = ret * 3;
    end
        end
        do finalize with
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
input none A;
var int ret = 1;
par/or do
    do
        ret = ret + 1;
        do
            await A;
            do finalize with
                ret = ret * 3;
            end
        end
        do finalize with
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
input none A; input none  B;
var int ret = 1;
par/or do
    do
        do finalize with
            ret = ret + 5;
        end
        ret = ret + 1;
        do
            do finalize with
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
native/pre do
    int V = 0;
end
par/or do
    do finalize with
        {V++;}
    end
with
end

par/and do
    do finalize with
        {V++;}
    end
with
    do finalize with
        {V++;}
    end
    await 1s;
with
    await 500ms;
    escape {V};
end

escape 1;
]],
    run = {['~>1s']=2},
}

Test { [[
input none OS_START;
await OS_START;
watching 1s do
    par/or do
        await OS_START;
    with
        await OS_START;
    end
    escape 10;
end
escape 1;
]],
    run = {['~>1s']=1},
}

Test { [[
input none OS_START;
await OS_START;
watching 1s do
    do finalize with
        var int ret = 1;
    end
    await OS_START;
    escape 10;
end
escape 1;
]],
    run = {['~>1s']=1},
}

Test { [[
input none A; input none B;
var int ret = 0;
loop do
    do
        do finalize with
            ret = ret + 4;
        end
        par/or do
            do
                do finalize with
                    ret = ret + 3;
                end
                await B;
                do
                    do finalize with
                        ret = ret + 2;
                    end
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
        do finalize with
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
        do finalize with
            ret = ret + 4;
    end
    end
end
escape ret;
]],
    run = false,
     ana = 'line 6 : statement is not reachable',
}

Test { [[
var int ret = 0;
loop do
    do
        ret = ret + 1;
        do finalize with
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
        do finalize with
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
        do finalize with
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
var int ret = do/_
    var int ret1 = 0;
    loop do
        do/_
            await 1s;
            ret1 = ret1 + 1;
            do/_ escape ret1 * 2; end
            do finalize with
                ret1 = ret1 + 4;  // executed after `escape` assigns to outer `ret1`
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
var int ret = do/_
    var int ret2 = 0;
    loop do
        do/_
            await 1s;
            ret2 = ret2 + 1;
            do finalize with
                ret2 = ret2 + 4;  // executed after `escape` assigns to outer `ret`
    end
            escape ret2 * 2;
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
        do finalize with
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
            do finalize with
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
            do finalize with
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
input none A; input none  B;
event none e;
var int v = 1;
par/or do
    do
        do finalize with
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
    await B;
    v = v * 5;
end
escape v;
]],
    run = {
        ['~>B'] = 12,
        ['~>A'] = 10,
    }
}

Test { [[
native/pre do
    none f (int* a) {
        *a = 10;
    }
    typedef none (*t)(int*);
end
native _t;
native/nohold _f;
var _t v = _f;
var int ret=0;
do
    var int a=0;
    do
        _f(&&a);
    //finalize with
        //nothing;
    end;
    ret = a;
end
escape(ret);
]],
    run = 10,
}
Test { [[
native _t, _A;
native _f;
native/pre do
    int* A = NULL;;
    none f (int* a) {
        A = a;
    }
    typedef none (*t)(int*);
end
var int ret = 0;
if _A!=0 then
    ret = ret + *(_A as int&&);
end
do
    var int a = 10;;
    var _t v = _f;
    do _f(&&a);
        finalize (a) with
            do
                ret = ret + a;
                _A = null;
        end
            end;
    if _A!=0 then
        a = a + *(_A as int&&);
    end
end
if _A!=0 then
    ret = ret + *(_A as int&&);
end
escape(ret);
]],
    run = 20,
}
Test { [[
input none OS_START;
native _t, _A;
native _f;
native/pre do
    int* A = NULL;;
    none f (int* a) {
        A = a;
    }
    typedef none (*t)(int*);
end
var int ret = 0;
if _A!=0 then
    ret = ret + *(_A as int&&);
end
par/or do
        var int a = 10;;
        var _t v = _f;
        do _f(&&a);
            finalize (a) with
                do
                    ret = ret + a;
                    _A = null;
            end
                end;
        if _A!=0 then
            a = a + *(_A as int&&);
        end
        await FOREVER;
with
    await OS_START;
end
if _A!=0 then
    ret = ret + *(_A as int&&);
end
escape(ret);
]],
    --fin = 'line 32 : pointer access across `await`',
    run = 20,
}
Test { [[
var int v = 1;
par/or do
    nothing;
with
    v = *(null as int&&);
end
escape v;
]],
    --parser = 'line 5 : after `(` : expected location',
    --dcls = 'line 5 : invalid operand to `*` : expected location',
    run = 1,
}

Test { [[
do finalize with
end
escape 1;
]],
    run = 1,
}

Test { [[
native _f, _V;
native/pos do
    int V;
    none f (int* x) {
        V = *x;
    }
end
var int ret = 10;
do
    var int x = 5;
    do _f(&&x); finalize (x) with
        _V = _V + 1;
    end;
end
escape ret + _V;
]],
    run = 16,
}

Test { [[
event none&& e;
var none&& v = await e;
escape 1;
]],
    dcls = 'line 1 : invalid event type : cannot use `&&`',
}

Test { [[
event int e;
var int v = await e;
escape 1;
]],
    run = false,
}

Test { [[
event int e;
var int v = await e;
await e;
escape 1;
]],
    --fin = 'line 3 : cannot `await` again on this block',
    run = false,
}

Test { [[
input int&& E;
var int&& v = await E;
await E;
escape *v;
]],
    --inits = 'line 4 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:3)',
    ptrs = 'line 4 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:3)',
    --fin = 'line 4 : unsafe access to pointer "v" across `await`',
    --fin = 'line 3 : cannot `await` again on this block',
    --run = 0,
}

Test { [[
var int&& p=null;
do
    input int&& E;
    p = await E;
end
escape 1;
]],
    run = false,
    --fin = 'line 4 : invalid block for awoken pointer "p"',
}

Test { [[
var int&& p1=null;
do/_
    var int&& p=null;
    //input int&& E;
    //p = await E;
    p1 = p;
    //await E;
    escape *p1;
end
escape 1;
]],
    --fin = 'line 6 : attribution requires `finalize`',
    --fin = 'line 8 : pointer access across `await`',
    --fin = 'line 6 : attribution to pointer with greater scope',
    scopes = 'line 6 : invalid pointer assignment : expected `finalize`',
}

Test { [[
var int&& p1=null;
do/_
    var int&& p;
    input int&& E;
    p = await E;
    p1 = p;
    await E;
    escape *p1;
end
escape 1;
]],
    --fin = 'line 6 : attribution requires `finalize`',
    --fin = 'line 8 : pointer access across `await`',
    --fin = 'line 6 : attribution to pointer with greater scope',
    --inits = 'line 6 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:5)',
    ptrs = 'line 6 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:5)',
    --scopes = 'line 6 : invalid pointer assignment : expected `finalize`',
}

Test { [[
native _f;
var int&& p1 = null;
do/_
    var int&& p;
    input int&& E;
    p = await E;
    _f(p);
    await E;
    //escape *p1;
end
escape 1;
]],
    scopes = 'line 7 : invalid `call` : expected `finalize` for variable "p"',
    --fin = 'line 6 : call requires `finalize`',
}

Test { [[
native _f;
var int&& p1 = null;
do/_
    var int&& p;
    input int&& E;
    p = await E;
    _f(p);
    await E;
    escape *p1;
end
escape 1;
]],
    --inits = 'line 9 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:6)',
    ptrs = 'line 9 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:6)',
    --fin = 'line 6 : call requires `finalize`',
}

Test { [[
var int&& p=null;
do
    input int&& E;
    p = await E;
end
await 1s;
escape 1;
]],
    run = false,
    --fin = 'line 4 : invalid block for pointer across `await`',
}

Test { [[
var int&& p = null;
par/or do
with
    p = null;
end
escape 0;
]],
    --inits = 'line 4 : invalid pointer access : crossed `par/or` (/tmp/tmp.ceu:2)',
    ptrs = 'line 4 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:2)',
    --fin = 'line 8 : pointer access across `await`',
    --fin = 'line 6 : invalid block for pointer across `await`',
    --fin = 'line 6 : cannot `await` again on this block',
    --run = { ['~>1s']=10 },
}
Test { [[
var int x = 10;
var int&& p = &&x;
par/or do
    await 1s;
with
    input int&& E;
    //p = await E;
    await E;
end
escape x;
]],
    --fin = 'line 8 : pointer access across `await`',
    --fin = 'line 6 : invalid block for pointer across `await`',
    --fin = 'line 6 : cannot `await` again on this block',
    run = { ['~>1s']=10 },
}

Test { [[
input int&& A;
var int v=0;
par/or do
    do
        var int&& p = await A;
        v = *p;
    end
    await A;
with
    await async do
        var int v = 10;
        emit A(&&v);
        emit A(null);
    end
end
escape v;
]],
    wrn = true,
    run = 10,
}

Test { [[
input int&& A;
var int v=0;
par/or do
    do
        var int&& p = await A;
        v = *p;
    end
    await A;
with
    await async do
        var int v = 10;
        emit A(&&v);
        emit A(null);
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
var int v;
var int&& p1 = &&v;
var int&& p2 = ((&&v) as none&&);
]],
    stmts = 'line 3 : invalid assignment : types mismatch : "int&&" <= "none&&"',
    --env = 'line 12 : wrong argument #1',
    --wrn = true,
    --run = 10,
}

Test { [[
input int&& A;
var int v=0;
par/or do
    do
        var int&& p = await A;
        v = *p;
    end
    await A;
with
    await async do
        var int v = 10;
        emit A((&&v) as none&&);
        emit A(null);
    end
end
escape v;
]],
    stmts = 'line 12 : invalid `emit` : types mismatch : "(int&&)" <= "(none&&)"',
    --env = 'line 12 : wrong argument #1',
    --wrn = true,
    --run = 10,
}

Test { [[
var int ret=0;
input none OS_START;
var int p=
do
    input int E;
    par do
        var int p1;
        do
            p1 = await E;
        finalize with
            ret = p1;
            p1 = ret;
            escape p1;
        end
    with
        await OS_START;
        var int i = 1;
        await async (i) do
            emit E(i);
        end
    end
end;
escape ret + p;
]],
    scopes = 'line 9 : invalid `finalize` : unexpected `await`',
    --adj = 'line 7 : invalid `finalize`',
    --fin = 'line 8 : attribution does not require `finalize`',
    --fin = 'line 8 : invalid block for awoken pointer "p"',
    --fin = 'line 14 : cannot `await` again on this block',
}

Test { [[
var int ret=0;
input none OS_START;
var int&& p=
do
    input int&& E;
    par do
        var int&& p1;
        do
            p1 = await E;
        finalize with
            ret = *p1;
            p1 = &&ret;
            escape p1;
        end
    with
        await OS_START;
        var int i = 1;
        await async (i) do
            emit E(&&i);
        end
    end
end;
escape ret + *p;
]],
    scopes = 'line 13 : invalid `escape` : incompatible scopes',
    --adj = 'line 7 : invalid `finalize`',
    --fin = 'line 8 : attribution does not require `finalize`',
    --fin = 'line 8 : invalid block for awoken pointer "p"',
    --fin = 'line 14 : cannot `await` again on this block',
}

Test { [[
var int&& p=null;
var int ret=0;
input none OS_START;
do
    input int&& E;
    par/and do
        do
            p = await E;
        finalize with
            ret = *p;
            p = &&ret;
        end
    with
        await OS_START;
        var int i = 1;
        await async (i) do
            emit E(&&i);
        end
    end
end
escape ret + *p;
]],
    --inits = 'line 8 : invalid pointer access : crossed `par/and` (/tmp/tmp.ceu:6)',
    ptrs = 'line 8 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:6)',
    --adj = 'line 7 : invalid `finalize`',
    --fin = 'line 8 : attribution does not require `finalize`',
    --fin = 'line 8 : invalid block for awoken pointer "p"',
    --fin = 'line 14 : cannot `await` again on this block',
}

Test { [[
var int&& p = null;
await async do end
escape *p;
]],
    --inits = 'line 3 : invalid pointer access : crossed `async` (/tmp/tmp.ceu:2)',
    ptrs = 'line 3 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:2)',
}
Test { [[
var int ret = 0;
var int&& p = &&ret;
do
    input int&& E;
    par/and do
        p = await E;
    with
    end
end
escape ret + *p;
]],
    --inits = 'line 6 : invalid pointer access : crossed `par/and` (/tmp/tmp.ceu:5)',
    ptrs = 'line 6 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:5)',
    --env = 'line 11 : wrong argument : cannot pass pointers',
    --fin = 'line 16 : unsafe access to pointer "p" across `async` (/tmp/tmp.ceu : 11)',
    --fin = 'line 14 : unsafe access to pointer "p" across `par/and`',
    --fin = 'line 8 : invalid block for awoken pointer "p"',
    --fin = 'line 14 : cannot `await` again on this block',
}

Test { [[
native _assert;
var none&& p = _;
var int i = _;
input none OS_START;
do/_
    var int r = _;
    do
        input (int,none&&) PTR;
        par/or do
            do
                (i,p) = await PTR;
            finalize with
                r = i;
            end
        with
            await OS_START;
            await async do
                emit PTR(1, null);
            end
        end
    end
    _assert(r == 1);
    escape r;
end
]],
    todo = 'escape PTR',
    wrn = true,
    --parser = 'line 10 : after `i` : expected `(` or `[` or `:` or `.` or `?` or `!` or `is` or `as` or binary operator or `)`',
    --adj = 'line 9 : invalid `finalize`',
    run = 1,
    -- TODO: impossible to place the finally in the correct parameter?
}

Test { [[
var int ret = 0;
input none OS_START;
do
    input int&& E;
    par/and do
var int&& p = null;
        p = await E;
        ret = *p;
    with
        await OS_START;
        await async do
            var int i = 1;
            emit E(&&i);
        end
    end
end
escape ret;
]],
    --env = 'line 12 : wrong argument : cannot pass pointers',
    --fin = 'line 7 : invalid block for awoken pointer "p"',
    --fin = 'line 7 : wrong operator',
    run = 1,
}

Test { [[
var int ret = 0;
input none OS_START;
do
    input int&& E;
    par/and do
var int&& p = null;
        p = await E;
        ret = *p;
    with
        await OS_START;
        await async do
            var int i = 1;
            emit E(&&i);
        end
    end
end
escape ret;
]],
    --env = 'line 12 : wrong argument : cannot pass pointers',
    --fin = 'line 7 : invalid block for awoken pointer "p"',
    --fin = 'line 7 : wrong operator',
    --run = 1,
    safety = 2,
    run = false,
    _ana = {
        acc = 1,
    },
}

Test { [[
input none OS_START;
var int ret=0;
event (bool,int) ok;
par/or do
    await OS_START;
    emit ok(true,10);
with
    var bool b;
    (b,ret) = await ok;
    if b then end;
end
escape ret;
]],
    run = 10,
}

Test { [[
input none OS_START;
input (int,none&&) PTR;
var int i=0;
par/or do
var none&& p=null;
    (i,p) = await PTR;
with
    await OS_START;
    await async do
        emit PTR(1, null);
    end
end
escape i;
]],
    --env = 'line 9 : wrong argument #2 : cannot pass pointers',
    --fin = 'line 6 : invalid block for awoken pointer "p"',
    --fin = 'line 6 : attribution to pointer with greater scope',
    run = 1,
}
Test { [[
input none OS_START;
input (int,none&&) PTR;
var int i=0;
par/or do
    var none&& p1;
    (i,p1) = await PTR;
    var none&& p=null;
        p = p1;
with
    await OS_START;
    await async do
        emit PTR(1, null);
    end
end
escape i;
]],
    --env = 'line 11 : wrong argument #2 : cannot pass pointers',
    --fin = 'line 6 : invalid block for awoken pointer "p"',
    run = 1,
}

Test { [[
input (int,none&&) PTR;
var none&& p;
var int i;
(i,p) = await PTR;
await 1s;
escape i;
]],
    --fin = 'line 5 : cannot `await` again on this block',
    run = false,
}

Test { [[
input none OS_START;
input (int,none&&) PTR;
var int i = 0;
par/or do
    var none&& p1;
    (i,p1) = await PTR;
var none&& p = null;
    p = p1;
with
    await OS_START;
    await async do
        emit PTR(1, null);
    end
end
await 1s;
escape i;
]],
    --env = 'line 11 : wrong argument #2 : cannot pass pointers',
    run = false,
    --fin = 'line 6 : invalid block for awoken pointer "p"',
}

Test { [[
var int i = 0;
input none OS_START;
do
    input (int,none&&) PTR;
    par/or do
var none&& p = null;
        (i,p) = await PTR;
    with
        await OS_START;
        await async do
            emit PTR(1, null);
        end
    end
end
escape i;
]],
    --env = 'line 10 : wrong argument #2 : cannot pass pointers',
    --fin = 'line 7 : wrong operator',
    --fin = 'line 7 : attribution does not require `finalize`',
    run = 1,
}

Test { [[
var int i = 0;
input none OS_START;
do
    input (int,none&&) PTR;
    par/or do
        var none&& p1;
        (i,p1) = await PTR;
var none&& p = null;
        p = p1;
    with
        await OS_START;
        await async do
            emit PTR(1, null);
        end
    end
end
escape i;
]],
    --fin = 'line 7 : wrong operator',
    --fin = 'line 7 : attribution does not require `finalize`',
    --env = 'line 12 : wrong argument #2 : cannot pass pointers',
    run = 1,
}

Test { [[
input (int,int,int&&) A;
await async do
    emit A(1, 1, null);
end
escape 1;
]],
    run = 1;
}

Test { [[
native _ptr;
do
    _ptr.x = null;
finalize with
end
escape 1;
]],
    scopes = 'line 2 : invalid `finalize` : nothing to finalize',
}

Test { [[
native _ptr;
native/pre do
    typedef struct t {
        int* x;
    } t;
    t ptr;
end
    _ptr.x = null;
escape 1;
]],
    run = 1,
}

Test { [[
native _malloc;
var none&& ptr = _malloc(100);
escape 1;
]],
    scopes = 'line 2 : invalid assignment : expected binding for "_malloc"',
}
Test { [[
native _ptr, _malloc;
native/pos do
    none* ptr;
end
_ptr = _malloc(100);
escape 1;
]],
    scopes = 'line 5 : invalid assignment : expected binding for "_malloc"',
    --run = 1,
}
Test { [[
native _ptr, _malloc;
native/nohold _free;
native/pos do
    none* ptr;
end
do
    _ptr = _malloc(100);
finalize (_ptr) with
    _free(_ptr);
end
escape 1;
]],
    scopes = 'line 7 : invalid assignment : expected binding for "_malloc"',
    --run = 1,
}

Test { [[
loop do
    do finalize with
        break;
    end
end
escape 1;
]],
    wrn = true,
    props_ = 'line 3 : invalid `break` : unexpected enclosing `finalize`',
    --props = 'line 3 : not permitted inside `finalize`',
}

Test { [[
do finalize with
    escape 1;
end
escape 1;
]],
    props_ = 'line 2 : invalid `escape` : unexpected enclosing `finalize`',
    --props = 'line 2 : not permitted inside `finalize`',
}

Test { [[
do finalize with
    loop do
        if true then
            break;
        end
    end
end
escape 1;
]],
    tight_ = 'line 2 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    --tight = 'line 2 : tight loop',
    --run = 1,
}

Test { [[
do finalize with
    var int ok = do/_
        escape 1;
    end;
end
escape 1;
]],
    props_ = 'line 3 : invalid `escape` : unexpected enclosing `finalize`',
}

Test { [[
var int ret = 0;
do finalize with
    var int ok = do
        escape 1;
    end;
    ret = ok;
end
escape 1;
]],
    run = 1,
}

    -- ASYNCHRONOUS

Test { [[
input none A;
var int ret=0;
var& int pret = &ret;
par/or do
   await async(pret) do
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
input none A;
var int ret=0;
var& int pret = &ret;
par/or do
   await async(pret) do
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
await async do
    escape 1;
end;
escape 0;
]],
    --props = 'line 2 : not permitted inside `async`',
    --props = 'line 2 : not permitted across `async` declaration',
    dcls = 'line 2 : invalid `escape` : no matching enclosing `do`',
}

Test { [[
var int a = async do
    escape 1;
end;
escape a;
]],
    parser = 'line 1 : after `=` : expected expression',
}

Test { [[
var int a; var int b;
await async (b) do
    a = 1;
end;
escape a;
]],
    dcls = 'line 3 : internal identifier "a" is not declared',
    --run = 1,
}

Test { [[
var int a;
await async do
    a = 1;
end;
escape a;
]],
    dcls = 'line 3 : internal identifier "a" is not declared',
    --run = 1,
}

Test { [[
par/and do
    await async do
        escape 1;
    end;
with
    escape 2;
end;
]],
    dcls = 'line 3 : invalid `escape` : no matching enclosing `do`',
    --props = 'line 3 : not permitted across `async` declaration',
    --props = 'line 3 : not permitted inside `async`',
}

Test { [[
par/and do
    await async do
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
    await async do
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
    await async do
        a = 1;
    end;
with
    a = 2;
end;
escape a;
]],
    dcls = 'line 4 : internal identifier "a" is not declared',
    _ana = {
        --acc = 1,
    },
}

Test { [[
await async do
    escape 1+2;
end;
]],
    --props = 'line 2 : not permitted inside `async`',
    --props = 'line 2 : not permitted across `async` declaration',
    dcls = 'line 2 : invalid `escape` : no matching enclosing `do`',
}

Test { [[
var int a = 1;
var& int pa = &a;
await async (a) do
    var int a = do
        escape 1;
    end;
    escape a;
end;
escape a;
]],
    wrn = true,
    props = 'line 7 : not permitted across `async` declaration',
    --props = 'line 5 : not permitted inside `async`',
    dcls = 'line 7 : invalid `escape` : no matching enclosing `do`',
}

Test { [[
input none X;
await async do
    emit X;
end;
escape 0;
]],
    run=0
}

Test { [[
input int A;
var int a;
await async do
    a = 1;
    emit A(a);
end;
escape a;
]],
    dcls = 'line 4 : internal identifier "a" is not declared',
    --run=1
}

Test { [[
input none A;
var int a;
await async do
    a = emit A;
end;
escape a;
]],
    --env = "line 4 : invalid attribution",
    dcls = 'line 4 : internal identifier "a" is not declared',
    --parser = 'line 4 : after `=` : expected expression',
}

Test { [[
input none A;
await async do
    var int a;
    a = emit A;
end;
escape 1;
]],
    stmts = 'line 4 : invalid assignment : `input`',
}
Test { [[
input none A;
await async do
    emit A(1);
end;
escape 1;
]],
    stmts = 'line 3 : invalid `emit` : types mismatch : "()" <= "(int)"',
}

Test { [[
event int a;
await async do
    emit a(1);
end;
escape 0;
]],
    dcls = 'line 3 : internal identifier "a" is not declared',
}
Test { [[
event int a;
await async do
    await a;
end;
escape 0;
]],
    dcls = 'line 3 : internal identifier "a" is not declared',
}
Test { [[
await async do
    await 1ms;
end;
escape 0;
]],
    props_ = 'line 2 : invalid `await` : unexpected enclosing `async`',
}
Test { [[
input int X;
await async do
    emit X(1);
end;
emit X(1);
escape 0;
]],
    stmts = 'line 5 : invalid `emit` : unexpected context for external `input` "X"',
}
Test { [[
await async do
    await async do
    end;
end;
]],
    props_ = 'line 2 : invalid `async` : unexpected enclosing `async`',
    --props='not permitted inside `async`'
}
Test { [[
await async do
    par/or do
    with
    end;
end;
]],
    props_ = 'line 2 : invalid `par/or` : unexpected enclosing `async`',
    --props='not permitted inside `async`'
}

Test { [[
loop do
    await async do
        break;
    end;
end;
escape 0;
]],
    props_ = 'line 3 : invalid `break` : unexpected enclosing `async`',
    --props='`break` without loop'
}

Test { [[
native _a;
native/pos do
    int a;
end
await async do
    _a = 1;
end
escape _a;
]],
    run = 1,
}

Test { [[
native _a;
native/pos do
    int a, b;
end
par/and do
    await async do
        _a = 1;
    end
with
    await async do
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
deterministic _b with _c;

native/pos do
    int a = 1;
    int b;
    int c;
end
par/and do
    await async do
        _b = 1;
    end
with
    await async do
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
native/pos do
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
native _a;
native/pos do
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
native/pos do
    int a = 1;
end
var int a=0;
deterministic a with _a;
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
native/pos do
    int a = 1;
    int b;
    int c;
end
par/and do
    await async do
        _b = 1;
    end
with
    await async do
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
var int r=0;
await async(r) do
    var int i = 100;
    r = i;
end;
escape r;
]],
    run=100
}

Test { [[
var int ret=0;
await async (ret) do
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
input int B;
var int ret = 0;
var int f = 0;
par/or do
    ret = do/_
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
    f = await B;
end;
escape ret+f;
]],
    run = {
        ['10~>B'] = 10,
        ['~>1s'] = 5050,
    }
}

Test { [[
input int B;
var int ret = 0;
var int f=0;
par/and do
    await async(ret) do
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
    f = await B;
end;
escape ret+f;
]],
    run = { ['10~>B']=5060 }
}

Test { [[
input int B;
var int ret = 0;
var int f=0;
par/and do
    await async(ret) do
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
    f = await B;
end;
escape ret+f;
]],
    run = { ['10~>B']=5060 },
    safety = 2,
}

Test { [[
input int B;
var int ret = 0;
var int f=0;
par/or do
    await async(ret) do
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
    f = await B;
end;
escape ret+f;
]],
    run = { ['10~>B']=10 }
}

Test { [[
input int B;
par do
    await B;
    escape 1;
with
    await async do
        loop do
            if false then
                break;
            end;
        end;
    end;
    escape 0;
end;
]],
    run = { ['1~>B'] = 1 },
}

Test { [[
input int B;
par/or do
    await B;
with
    await async do
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
var int ret=0;
await async (ret) do
    var int i = 100;
    i = i - 1;
    ret = i;
end;
escape ret;
]],
    run = 99,
}

Test { [[
var int ret=0;
await async(ret) do
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
var int ret=0;
await async(ret) do
    var int i = 0;
    if i!=0 then
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
var int i=0;
var& int pi=&i;
await async (pi) do
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
    dcls = 'line 7 : invalid operand to `not` : expected boolean type',
    wrn = true,
}

Test { [[
var int i=0;
var& int pi=&i;
await async (pi) do
    var int i = 10;
    loop do
        i = i - 1;
        if not (i as bool) then
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
var int i=0;
var& int pi = &i;
await async (pi) do
    var int i = 10;
    loop do
        i = i - 1;
        if not (i as bool) then
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
var& int pi = &i;
await async (pi) do
    loop do
        i = i - 1;
        if not (i as bool) then
            pi = i;
            break;
        end;
    end;
end;
escape i;
]],
    dcls = 'line 5 : internal identifier "i" is not declared',
}

Test { [[
var int sum=0;
var& int p = &sum;
await async (p) do
    var int i = 10;
    var int sum = 0;
    loop do
        sum = sum + i;
        i = i - 1;
        if not (i as bool) then
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
    await async do
        emit A(1);
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
input int A; input int  B;
var int a = 0;
par/or do
    await async do
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
    await async do
        emit A(4);
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
input none A;
var int ret = 0;
par/or do
    loop do
        await async do
            emit A;
        end
        ret = ret + 1;
    end
with
    par/and do
        var int v = async do
            var int v;
var int i;
            loop i in [0 -> 5[ do
                v = v + i;
            end
            escape v;
        end;
        ret = ret + v;
    with
        var int v = async do
            var int v;
var int i;
            loop i in [0 -> 5[ do
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
input int&& GO;
var   int&& qu_;
qu_ = await GO;
]],
    run = false,
}

Test { [[
input int&& GO;
var   int&& qu_;
every qu_ in GO do
    var int qu = * qu_;
end
]],
    run = false,
}

Test { [[
native _tceu_queue;
input none&& E;
input _tceu_queue&& GO;
var _tceu_queue&& qu_;
every qu_ in GO do
    var _tceu_queue qu = * qu_;
    await async(qu) do
        emit E(qu.param.ptr);
    end
end
]],
    --inits = 'line 7 : invalid pointer access : crossed `async` (/tmp/tmp.ceu:7)',
    ptrs = 'line 7 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:7)',
    --fin = 'line 5 : unsafe access to pointer "qu" across `async`',
    --_ana = { isForever=true },
    --run = 1,
}

Test { [[
input none&& E;
native/plain _tceu_queue;
input _tceu_queue&& GO;
var _tceu_queue&& qu_;
every qu_ in GO do
    var _tceu_queue qu = * qu_;
    await async(qu) do
        emit E(qu.param.ptr);
    end
end
]],
    props_ = 'line 7 : invalid `async` : unexpected enclosing `every`',
}

Test { [[
input none&& E;
native/plain _tceu_queue;
input _tceu_queue&& GO;
loop do
    var _tceu_queue&& qu_;
    qu_ = await GO;
    var _tceu_queue qu = * qu_;
    await async(qu) do
        emit E(qu.param.ptr);
    end
end
]],
    cc = '1: error: unknown type name ‘tceu_queue’',
    _ana = {
        isForever = true,
    },
}

-- HIDDEN
Test { [[
var int a = 1;
var int&& b = &&a;
do
var int a = 0;
if a!=0 then end;
end
escape *b;
]],
    wrn = true,
    run = 1,
}

-- INPUT / OUTPUT / CALL

Test { [[
input none A;
input none A;
escape 1;
]],
    dcls = 'line 2 : declaration of "A" hides previous declaration (/tmp/tmp.ceu : line 1)',
    --dcls = 'line 2 : identifier "A" is already declared (/tmp/tmp.ceu : line 1)',
}

Test { [[
input none A;
input int A;
escape 1;
]],
    dcls = 'line 2 : invalid declaration : types mismatch : "(int)" <= "()"',
    --dcls = 'line 2 : declaration of "A" hides previous declaration (/tmp/tmp.ceu : line 1)',
    --dcls = 'line 2 : identifier "A" is already declared (/tmp/tmp.ceu : line 1)',
}

Test { [[
input none TEST;
output none TEST;
escape 1;
]],
    wrn = true,
    dcls = 'line 2 : declaration of "TEST" hides previous declaration (/tmp/tmp.ceu : line 1)',
}

--if not OS then

-->>> OUTPUT

Test { [[
output int A;
input  int A;
escape(1);
]],
    dcls = 'line 2 : declaration of "A" hides previous declaration (/tmp/tmp.ceu : line 1)',
}
Test { [[
output xxx A;
escape(1);
]],
    parser = 'line 1 : after `output` : expected `(` or `&` or type',
}
Test { [[
native/pos do
    ##define ceu_callback_native(e,b,c)
    /*__ceu_nothing(d)*/
end
output int A;
emit A(111);
escape(1);
]],
    run=1
}
Test { [[
output int A;
if emit A(1) then
    escape 0;
end
escape(1);
]],
    parser = 'line 2 : after `if` : expected expression',
}
Test { [[
native/pos do
    #define ceu_out_emit(a,b,c,d) 1
end
output int A;
if emit A(1) then
    escape 0;
end
escape(1);
]],
    parser = 'line 5 : after `if` : expected expression',
}

Test { [[
output t A;
emit A(1);
escape(1);
]],
    parser = 'after `output` : expected `(` or `&` or type',
}
Test { [[
output t A;
emit A(1);
escape(1);
]],
    parser = 'after `output` : expected `(` or `&` or type',
}
Test { [[
native _t;
output _t&& A;
emit A(1);
escape(1);
]],
    stmts = 'line 3 : invalid `emit` : types mismatch : "(_t&&)" <= "(int)"',
    --env = 'line 2 : wrong argument #1',
}
Test { [[
native _t;
output int A;
var _t v=1;
emit A(v);
escape(1);
]],
    --env = 'line 2 : undeclared type `_t`',
    --env = 'line 3 : non-matching types on `emit`',
    cc = 'error: unknown type name',
}
Test { [[
native _t;
native/pos do
    ##define ceu_callback_native(a,b,c)
    /* __ceu_nothing(d) */
end
output int A;
native/pre do
    typedef int t;
end
var _t v=1;
emit A(v);
escape(1);
]],
    --env = 'line 2 : undeclared type `_t`',
    --env = 'line 3 : non-matching types on `emit`',
    run = 1,
}
Test { [[
output int A;
var int a;
emit A(&&a);
escape(1);
]],
    stmts = 'line 3 : invalid `emit` : types mismatch : "(int)" <= "(int&&)"',
    --env = 'line 3 : wrong argument #1',
}
Test { [[
output int A;
var int a;
if emit A(&&a) then
    escape 0;
end
escape(1);
]],
    parser = 'line 3 : after `if` : expected expression',
    --env = 'line 3 : non-matching types on `emit`',
}
Test { [[
native _char;
output _char A;
escape 1;
]],
    wrn = true,
    run = 1,
    --env = "line 1 : invalid event type",
}

Test { [[
native/pos do
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        if (cmd != CEU_CALLBACK_OUTPUT) {
            is_handled = 0;
        } else {
            is_handled = 1;
            if (p1.num == CEU_OUTPUT_O) {
                *(*((int**)p2.ptr)) = 10;
            } else {
                *((int*)p2.ptr) = 5;
            }
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }

output (&int) O;
var int xxx = _;
emit O(&xxx);
escape xxx;
]],
    run = 10,
}

Test { [[
output (none) O;
output (int) O;
emit O();
escape 1;
]],
    dcls = 'line 2 : invalid declaration : types mismatch : "(int)" <= "()"',
}
Test { [[
output (none) O;
output (int p) O do
    p = 10;
end
emit O(1);
escape 1;
]],
    dcls = 'line 2 : invalid declaration : types mismatch : "(int)" <= "()"',
}
Test { [[
output (int) O;
output (int p) O do
    p = 10;
end
emit O(1);
escape 1;
]],
    run = 1,
}
Test { [[
output (int p) O do
    p = 10;
end
output (int) O;
emit O(1);
escape 1;
]],
    run = 1,
}
Test { [[
output (int) O;
output (int p) O do
    p = 10;
end
output (int) O;
emit O(1);
escape 1;
]],
    run = 1,
}
Test { [[
output (int p) O do
    p = 10;
end
output (int p) O do
    p = 10;
end
escape 1;
]],
    dcls = 'line 4 : declaration of "O" hides previous declaration (/tmp/tmp.ceu : line 1)',
}

Test { [[
output none O do
end
output (none) O;
emit O();
escape 1;
]],
    run = 1,
}
Test { [[
output none O do
    escape;
end
output (none) O;
emit O();
escape 1;
]],
    run = 1,
}
Test { [[
output (&int p) O do
    p = 10;
end
output (&int) O;
var int i = 1;
emit O(&i);
escape i;
]],
    run = 10,
}

Test { [[
output (&int p) O do
    if true then
        escape;
    end
    p = 10;
end
var int i = 1;
emit O(&i);
escape i;
]],
    run = 1,
}
Test { [[
output (&int p) O do
    if false then
        escape;
    end
    p = 10;
end
var int i = 1;
emit O(&i);
escape i;
]],
    run = 10,
}

Test { [[
output (int? v, &int ret) O do
    if v? then
        ret = v!;
    else
        ret = 99;
    end
end
var int ret = 1;
emit O(100, &ret);
escape ret;
]],
    run = 100,
}

Test { [[
output &none O do
end
emit O();
escape 1;
]],
    adjs = 'line 1 : invalid type',
}

Test { [[
output none O do
    {ceu_assert(0, "oioioi");}
end
emit O();
escape 99;
]],
    run = '4] -> runtime error: oioioi',
    _opts = { ceu_features_trace='true' },
}
Test { [[
output () O do
end
emit O();
escape 1;
]],
    parser = 'line 1 : after `(` : expected `&` or type',
}
Test { [[
output (none) O do
end
emit O();
escape 1;
]],
    run = 1,
}
Test { [[
output (&none) O do
end
emit O();
escape 1;
]],
    adjs = 'line 1 : invalid type',
}
Test { [[
output (none x) O do
end
emit O();
escape 1;
]],
    adjs = 'line 1 : invalid type',
}
Test { [[
output (&none x) O do
end
emit O();
escape 1;
]],
    adjs = 'line 1 : invalid type',
}
Test { [[
output (int? v, &int ret) O do
    if v? then
        ret = v!;
    else
        ret = 99;
    end
end
var int ret = 1;
emit O(_, &ret);
escape ret;
]],
    run = 99,
}

Test { [[
var int x = 1;
output (&int p, int v) O do
    p = 10 + v + outer.x;
end
output (&int,int) O;
var int i = 1;
emit O(&i,100);
escape i;
]],
    run = 111,
}
Test { [[
var int x = 1;
output (&int p, int v) O do
    var int i = 1;
    p = 10 + v + outer.x + i;
end
var int i = 1;
emit O(&i,100);
escape i;
]],
    run = 112,
}
Test { [[
var int x = 1;
output (&int p, int v) O do
    var int i = 1;
    p = 10 + v + outer.x + i;
end
output (&int,int) O;
var int i = 1;
emit O(&i,100);
escape i;
]],
    run = 112,
}
Test { [[
var int x = 1;
output (&int p, int v) O do
    p = 10 + (v - outer.x);
end
output (&int,int) O;
var int i = 1;
emit O(&i,100);
escape i;
]],
    run = 109,
}
Test { [[
output (&int p) O do
    p = 10;
end

output (&int) O;
var int xxx = _;
emit O(&xxx);
escape xxx;
]],
    run = 10,
}

Test { [[
output (none) A do
    var int i;
    loop i in [0 -> 7] do
    end
end
emit A();
escape 10;
]],
    run = 10,
}

Test { [[
native/pos do
    static tceu_data_Dd DD = { 1 };
end
data Dd with
    var int x;
end
output Dd O;
var Dd d = _;
emit O({DD} as Dd);
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        if (cmd != CEU_CALLBACK_OUTPUT) {
            is_handled = 0;
        } else {
            is_handled = 1;
            if (p1.num == CEU_OUTPUT_O) {
                *(*((int**)p2.ptr)) = 10;
            } else {
                *((int*)p2.ptr) = 5;
            }
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }

output &int O;
var int xxx = _;
emit O(&xxx);
escape xxx;
]],
    run = 10,
}

Test { [[
native/pos do
    static tceu_data_Dd DD = { 1 };
end
data Dd with
    var int x;
end
output Dd O;
var Dd d = _;
emit O({DD} as Dd);
escape 1;
]],
    run = 1,
}

Test { [[
native _V1, _V2;
native/pos do
    int V1, V2;
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        if (cmd != CEU_CALLBACK_OUTPUT) {
            is_handled = 0;
        } else {
            is_handled = 1;
            if (p1.num == CEU_OUTPUT_O) {
                tceu_output_O* o = (tceu_output_O*) p2.ptr;
                V1 = (o->_1.is_set == 0);
                V2 = (o->_2.is_set == 1) + (o->_2.value);
            }
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }

output (int?,int?) O;
emit O(_,10);
escape _V1 + _V2;
]],
    run = 12,
}

Test { [[
output u8? O;
var u8? v;
emit O(v);
escape 1;
]],
    run = 1,
}

Test { [[
var bool spi_is_busy;
spawn async/isr [20] do
    spi_is_busy = false;
end
escape 1;
]],
    dcls = 'is not declared',
    _opts = { ceu_features_isr='true' },
}

Test { [[
var bool spi_is_busy;

output none SPI_TRANSACTION_END do
    spi_is_busy = false;
    {
        SREG = SPI_interruptSave;
    }
end
]],
    dcls = 'is not declared',
    run = 1,
}

Test { [[
var bool spi_is_busy = false;

output none SPI_TRANSACTION_END do
    outer.spi_is_busy = false;
    {
        SREG = SPI_interruptSave;
    }
end
]],
    wrn = true,
    cc = 'undeclared',
}


Test { [[
code/tight Inc(var& int ret) -> none do
    ret = ret + 1;
end
output &int INC;
output (&int v) INC do
    call Inc(&v);
end
var int ret = 10;
emit INC(&ret);
escape ret;
]],
    wrn = true,
    run = 11,
}

--<<< OUTPUT

Test { [[
native/pre do
    typedef struct {
        int a;
        int b;
    } t;
end
native _t;
var _t v;
v.a = 1;
v.b = 2;
escape v.a + v.b;
]],
    inits = 'line 8 : uninitialized variable "v" : reached read access (/tmp/tmp.ceu:9)',
}
Test { [[
native/pre do
    typedef struct {
        int a;
        int b;
    } t;
end
native _t;
var _t v = _;
v.a = 1;
v.b = 2;
escape v.a + v.b;
]],
    run = 3,
    --inits = 'line 8 : uninitialized variable "v"',
}
Test { [[
native/pre do
    typedef struct {
        int a;
        int b;
    } t;
end
native _t;
var _t v = _;
v.a = 1;
v.b = 2;
escape v.a + v.b;
]],
    wrn = true,
    run = 3,
}
Test { [[
native _t;
var _t v = _t(1,2);
escape 0;
]],
    scopes = 'line 2 : invalid assignment : expected binding for "_t"',
}

Test { [[
native/pre do
    typedef struct t {
        int a;
        int b;
    } t;
end
native/plain _t;
var _t v = { (struct t){1,2} };
escape v.a + v.b;
]],
    run = 3,
}

Test { [[
native/pre do
    ##include <assert.h>
    typedef struct t {
        int a;
        int b;
    } t;
end
native/pos do
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        if (cmd != CEU_CALLBACK_OUTPUT) {
            is_handled = 0;
        } else {
            is_handled = 1;
            if (p1.num == CEU_OUTPUT_A) {
                t* x = ((tceu_output_A*)p2.ptr)->_1;
                ceu_callback_ret.num = x->a + x->b;
            } else {
                ceu_callback_ret.num = *((int*)p2.ptr);
            }
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }

native/plain _t;
output _t&& A;
output int B;
var int a; var int  b;

var _t v = { (struct t){1,-1} };
a = emit A(&&v);
b = emit B(5);
escape a + b;
]],
    run = 5,
    --parser = 'line 26 : after `=` : expected expression',
}

Test { [[
native/pre do
    ##include <assert.h>
    typedef struct t {
        int a;
        int b;
    } t;
end
native/pos do
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        if (cmd != CEU_CALLBACK_OUTPUT) {
            is_handled = 0;
        } else {
            is_handled = 1;
            if (p1.num == CEU_OUTPUT_A) {
                t* x = ((tceu_output_A*)p2.ptr)->_1;
                ceu_callback_ret.num = x->a + x->b;
            } else {
                ceu_callback_ret.num = *((int*)p2.ptr);
            }
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }

native/plain _t;
output _t&& A;
output int B;
var int a; var int  b;

var _t v = { (struct t){1,-1} };
a = emit A(&&v);
b = emit B(5);
escape a + b;
]],
    run = 5,
    --parser = 'line 26 : after `=` : expected expression',
}

Test { [[
native/pre do
    ##include <assert.h>
    typedef struct t {
        int a;
        int b;
    } t;
end
native/pos do
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        if (cmd != CEU_CALLBACK_OUTPUT) {
            is_handled = 0;
        } else {
            is_handled = 1;
            if (p1.num == CEU_OUTPUT_A) {
                t x = ((tceu_output_A*)p2.ptr)->_1;
                ceu_callback_ret.num = x.a + x.b;
            } else {
                ceu_callback_ret.num = *((int*)p2.ptr);
            }
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }
native/plain _t;
output _t A;
output int B;
var int a; var int  b;

var _t v = { (struct t){1,-1} };
a = emit A(v);
b = emit B(5);
escape a + b;
]],
    run = 5,
    --parser = 'line 26 : after `=` : expected expression',
}

Test { [[
native _cahr;
output none A;
native/pos do
    none A (int v) {}
end
var _cahr v = emit A(1);
escape 0;
]],
    stmts = 'line 6 : invalid `emit` : types mismatch : "()" <= "(int)"',
    --env = 'line 6 : arity mismatch',
    --env = 'line 6 : non-matching types on `emit`',
    --parser = 'line 6 : after `=` : expected expression',
    --env = 'line 6 : undeclared type `_cahr`',
}
Test { [[
native _char;
output none A;
var _char v = emit A(;
escape v;
]],
    parser = 'line 3 : after `(` : expected expression',
    --parser = 'line 3 : before `->` : expected `;`',
    --env = 'line 3 : invalid attribution',
}
Test { [[
output none A;
native/pos do
    none A (int v) {}
end
native _char;
var _char v = emit A(1);
escape 0;
]],
    --parser = 'line 6 : after `=` : expected expression',
    --env = 'line 6 : non-matching types on `emit`',
    --env = 'line 6 : arity mismatch',
    stmts = 'line 6 : invalid `emit` : types mismatch : "()" <= "(int)"',
}

Test { [[
native/pos do
    none A (int v) {}
end
emit A(1);
escape 0;
]],
    dcls = 'external identifier "A" is not declared',
}

Test { [[
native/pos do
    #define ceu_out_emit(a,b,c,d)  __ceu_nothing(d)
end
output none A; output none B;
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
native/pos do
    #define ceu_out_emit(a,b,c,d)  __ceu_nothing(d)
end
deterministic A with B;
output none A; output none B;
par/or do
    emit A;
with
    emit B;
end
escape 1;
]],
    dcls = 'line 4 : external identifier "A" is not declared',
}

Test { [[
native/pos do
    #define ceu_out_emit(a,b,c,d)  __ceu_nothing(d)
end
output none A; output none B;
deterministic A with B;
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
native/pos do
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        if (cmd != CEU_CALLBACK_OUTPUT) {
            is_handled = 0;
        } else {
            is_handled = 1;

            tceu_output_RADIO_SEND* v = (tceu_output_RADIO_SEND*) p2.ptr;
            *(v->_1) = 1;
            *(v->_2) = 2;
            ceu_callback_ret.num = 0;
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }

output (int&&,  int&&) RADIO_SEND;
var int a=1; var int b=1;
emit RADIO_SEND(&&a,&&b);

escape a + b;
]],
    run = 3,
}

Test { [[
native/pos do
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        if (cmd != CEU_CALLBACK_OUTPUT) {
            is_handled = 0;
        } else {
            is_handled = 1;

            tceu_output_RADIO_SEND* v = (tceu_output_RADIO_SEND*) p2.ptr;
            *(v->_1) = (p1.num == CEU_OUTPUT_RADIO_SEND);
            *(v->_2) = 2;
            ceu_callback_ret.num = 0;
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }

output (int&&,  int&&) RADIO_SEND;
var int a=1; var int b=1;
emit RADIO_SEND(&&a,&&b);

escape a + b;
]],
    run = 3,
}

Test { [[
native _Fx;
output int Z;
native/pos do
    none Z() {};
end
par do
    _Fx();
with
    emit Z(1);
end
]],
    cc = '1: error: implicit declaration of function ‘Fx’',
    _ana = {
        reachs = 1,
        acc = 1,
        isForever = true,
    },
}

Test { [[
native _Fx;
output int Z; output int W;
native/pos do
    none Z() {};
end
par do
    _Fx();
with
    emit Z(1);
with
    emit W(0);
end
]],
    cc = '1: error: implicit declaration of function ‘Fx’',
    _ana = {
        reachs = 1,
        acc = 3,
        isForever = true,
    },
}

Test { [[
native _Fx;
deterministic _Fx with Z,W;
output int Z; output int W;
native/pos do
    none Z() {};
end
par do
    _Fx();
with
    emit Z(1);
with
    emit W(0);
end
]],
    todo = true,
    _ana = {
        acc = 1,
        isForever = true,
    },
}

Test { [[
native _Fx;
output int&& Z,W;
deterministic _Fx with Z,W;
int a = 1;
int&& b;
native/pos do
    none Z (int v) {};
end
par do
    _Fx(&&a);
with
    emit Z(b);
with
    emit W(&&a);
end
]],
    todo = true,
    _ana = {
        acc = 4,
        isForever = true,
    },
}

Test { [[
native _Fx;
@pure _Fx;
output int&& Z,W;
int a = 1;
int&& b;
native/pos do
    none Z (int v) {};
end
par do
    _Fx(&&a);
with
    emit Z(b);
with
    emit W(&&a);
end
]],
    todo = true,
    _ana = {
        acc = 4,
        isForever = true,
    },
}

Test { [[
native _Fx;
deterministic Z with W;
output none Z; output noneW;
par do
    emit Z;
with
    emit W;
end
]],
    todo = true,
    _ana = {
        reachs = 1,
        isForever = true,
    },
}

Test { [[
output Z  (var int)->int;
escape call Z(1);
]],
    parser = 'line 1 : after `output` : expected `(` or `&` or type',
    --parser = 'line 2 : after `call` : expected expression',
    --parser = 'line 2 : after `Z` : expected `;`',
    --parser = 'line 2 : after `Z` : expected `(`',
}

Test { [[
output int E;
emit E(1,2);
escape 1;
]],
    stmts = 'line 2 : invalid `emit` : types mismatch : "(int)" <= "(int,int)"',
    --env = 'line 2 : arity mismatch',
}

Test { [[
event (int) e;
emit e(1,2);
escape 1;
]],
    stmts = 'line 2 : invalid `emit` : types mismatch : "(int)" <= "(int,int)"',
}

Test { [[
event (int) e;
emit e;
escape 1;
]],
    stmts = 'line 2 : invalid `emit` : types mismatch : "(int)" <= "()"',
}

Test { [[
output int E;
emit E;
escape 1;
]],
    stmts = 'line 2 : invalid `emit` : types mismatch : "(int)" <= "()"',
    --env = 'line 2 : arity mismatch',
}

Test { [[
output (int,int) E;
emit E(1);
escape 1;
]],
    stmts = 'line 2 : invalid `emit` : types mismatch : "(int,int)" <= "(int)"',
    --env = 'line 2 : arity mismatch',
}

Test { [[
event (int,int) e;
emit e(1);
escape 1;
]],
    stmts = 'line 2 : invalid `emit` : types mismatch : "(int,int)" <= "(int)"',
}

Test { [[
var int ret = (call Z(2));
]],
    dcls = 'line 1 : external identifier "Z" is not declared',
}

Test { [[
native/pos do
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        if (cmd != CEU_CALLBACK_OUTPUT) {
            is_handled = 0;
        } else {
            is_handled = 1;
            ceu_callback_ret.num = (p1.num == CEU_OUTPUT_Z && p2.ptr==NULL);
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }

output none Z;
var int ret = (emit Z);
escape ret;
]],
    run = 1,
}

Test { [[
native/pos do
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        if (cmd != CEU_CALLBACK_OUTPUT) {
            is_handled = 0;
        } else {
            is_handled = 1;
            ceu_callback_ret.num = 1;
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }

output none Z;
var int ret = (emit Z);
escape ret;
]],
    run = 1,
}

Test { [[
native/pos do
    ##define ceu_out_emit(a,b,c,d) Z(a,b,d)
    int Z (tceu_app* app, tceu_nevt evt, int* p) {
        return (evt == CEU_OUTPUT_Z) + *p;
    }
end
output int Z;
par/and do
    emit Z(1);
with
    emit Z(1);
end
escape 1;
]],
    _ana = {
        acc = 1,
    },
    run = 1,
}

Test { [[
input (none,int) A;
escape 1;
]],
    dcls = 'line 1 : invalid declaration : unexpected type `none`',
}
Test { [[
input (int,none) A;
escape 1;
]],
    dcls = 'line 1 : invalid declaration : unexpected type `none`',
}
Test { [[
output (none,int) A;
escape 1;
]],
    dcls = 'line 1 : invalid declaration : unexpected type `none`',
}
Test { [[
output (int,none) A;
escape 1;
]],
    dcls = 'line 1 : invalid declaration : unexpected type `none`',
}

--end -- OS (INPUT/OUTPUT)

-->>> OS_START

Test { [[
var int&&&& x = null;
escape 1;
]],
    run = 1,
}

Test { [[
native _char,_assert;
native/pure _strcmp;
input (int,_char&&&&) OS_START;
var int argc;
var _char&&&& argv;
(argc, argv) = await OS_START;
_assert(_strcmp(argv[1],"arg")==0);
escape argc;
]],
    --ana = 'line 3 : `loop` iteration is not reachable',
    todo = 'argv',
    wrn = true,
    run = 2,
    args = 'arg',
}

Test { [[
native _char,_assert;
native/pure _strcmp;
input (int,_char&&&&) OS_START;
var int argc;
var _char&&&& argv;
(argc, argv) = await OS_START;
_assert(argv[1][0] == {'a'});
escape argc;
]],
    --ana = 'line 3 : `loop` iteration is not reachable',
    todo = 'argv',
    wrn = true,
    run = 2,
    args = 'arg',
}

Test { [[
input none OS_START;
event none e;
await OS_START;
emit e;
escape 10;
]],
    --ana = 'line 3 : `loop` iteration is not reachable',
    wrn = true,
    run = 10,
}

Test { [[
input none OS_START;
event none e;
loop do
    await OS_START;
var int i;
    loop i in [0 -> 10[ do
        emit e;
    end
    do break; end
end
escape 10;
]],
    --ana = 'line 3 : `loop` iteration is not reachable',
    wrn = true,
    run = 10,
}

--<<< OS_START

Test { [[
input (int) X;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
input (int);
]],
    parser = 'line 1 : after `)` : expected external identifier',
}
Test { [[
input (xxx);
]],
    parser = 'line 1 : after `(` : expected type',
}
Test { [[
input ();
]],
    parser = 'line 1 : after `(` : expected type',
}
Test { [[
input (u8);
]],
    parser = 'line 1 : after `)` : expected external identifier',
}

Test { [[
input (xxx tilex) X;;
]],
    parser = 'line 1 : after `(` : expected type',
}

Test { [[

input (int tilex, int tiley, bool vertical, int lock, int door, usize&& position) DOOR_SPAWN;

    var int tilex;
    var int tiley;
    var bool vertical;
    var int lock;
    var int door;
    var usize&& position;
    every (tilex,tiley,vertical,lock,door,position) in DOOR_SPAWN do
    end
]],
    parser = 'line 2 : after `int` : expected type modifier or `,` or `)`',
}

    -- POINTERS & ARRAYS

-- int_int
Test { [[var int&&p; escape p/10;]],
    dcls = 'line 1 : invalid operand to `/` : expected numeric type'
}
Test { [[var int&&p; escape p|10;]],
    dcls = 'line 1 : invalid operand to `|` : expected integer type',
}
Test { [[var int&&p; escape p>>10;]],
    dcls = 'line 1 : invalid operand to `>>` : expected integer type',
}
Test { [[var int&&p; escape p^10;]],
    dcls = 'line 1 : invalid operand to `^` : expected numeric type',
}
Test { [[var int&&p; escape ~p;]],
    dcls = 'line 1 : invalid operand to `~` : expected integer type',
}

-- same
Test { [[var int&&p; var int a; escape p==a;]],
    dcls = 'line 1 : invalid operands to `==` : incompatible types : "int&&" vs "int"',
}
Test { [[var int&&p; var int a; escape p!=a;]],
    dcls = 'line 1 : invalid operands to `!=` : incompatible types : "int&&" vs "int"',
}
Test { [[var int&&p; var int a; escape p>a;]],
    dcls = 'line 1 : invalid operand to `>` : expected numeric type',
}

-- any
Test { [[var int&&p=null; escape p or 10;]],
    dcls = 'line 1 : invalid operand to `or` : expected boolean type',
}
Test { [[var int&&p=null; escape (p!=null or true) as int;]], run=1 }
Test { [[var int&&p=null; escape (p!=null and false) as int;]],  run=0 }
Test { [[var int&&p=null; escape( not (p!=null)) as int;]], run=1 }

-- arith
Test { [[var int&&p; escape p+p;]],
    dcls = 'line 1 : invalid operand to `+` : expected numeric type',
}--TODO: "+"'}
Test { [[var int&&p; escape p+10;]],
    dcls = 'line 1 : invalid operand to `+` : expected numeric type',
}
Test { [[var int&&p; escape p+10 and 0;]],
    dcls = 'line 1 : invalid operand to `+` : expected numeric type',
}

-- ptr
Test { [[var int a; escape *a;]],
    dcls = 'line 1 : invalid operand to `*` : expected pointer type',
}
Test { [[var int a; var int&&pa; (pa+10)=&&a; escape a;]],
    parser = 'line 1 : after `)` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `;`',
    --parser = 'line 1 : after `)` : expected `(`',
    --parser = 'line 1 : after `pa` : expected `[` or `:` or `.` or `!` or `as` or `)` or `,`',
    --dcls = 'line 1 : invalid operand to `+` : expected numeric type',
}
Test { [[var int a; var int&&pa; a=1; pa=&&a; *pa=3; escape a;]], run=3 }

Test { [[
native _V;
*({(u32*)0x100}) = _V;
escape 1;
]],
    cc = 'error: ‘V’ undeclared (first use in this function)',
}

Test { [[
native _V;
*(0x100 as u32&&) = _V;
escape 1;
]],
    parser = 'line 2 : after `)` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `;`',
    --parser = 'line 2 : after `(` : expected location',
    --gcc = 'error: ‘V’ undeclared (first use in this function)',
}

Test { [[var int  a;  var int&& pa=a; escape a;]],
    stmts = 'line 1 : invalid assignment : types mismatch : "int&&" <= "int"',
    --env = 'types mismatch'
}
Test { [[var int&& pa; var int a=pa;  escape a;]],
    stmts = 'line 1 : invalid assignment : types mismatch : "int" <= "int&&"',
    --env = 'types mismatch',
}
Test { [[
var int a;
var int&& pa = do
    escape a;
end;
escape a;
]],
    stmts = 'line 3 : invalid `escape` : types mismatch : "int&&" <= "int"',
    --env='types mismatch'
}
Test { [[
var int&& pa;
var int a = do
    escape pa;
end;
escape a;
]],
    --env='types mismatch'
    stmts = 'line 3 : invalid `escape` : types mismatch : "int" <= "int&&"',
}

Test { [[
var int&& a;
a = null;
if a then
    escape 1;
else
    escape -1;
end;
]],
    stmts = 'line 3 : invalid `if` condition : expected boolean type',
}

Test { [[
var int&& a;
a = null;
if true then
    await 1s;
else
end;
a = null;
escape 1;
]],
    --inits = 'line 7 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:4)',
    ptrs = 'line 7 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:4)',
}

Test { [[
var int&& a;
a = null;
if a!=null then
    escape 1;
else
    escape -1;
end;
]],
    run = -1,
}

Test { [[
native _char;
var int i;
//var int&& pi;
var _char c=10;
//var _char&& pc;
i = c;
c = i;
i = (c as int);
c = (i as _char);
escape c;
]],
    --env = 'line 6 : invalid attribution',
    run = 10,
}

Test { [[
native _char;
var int i;
//var int&& pi;
var _char c=0;
//var _char&& pc;
i = (c as int);
c = (i as _char);
escape 10;
]],
    run = 10
}

Test { [[
var int&& ptr1=null;
var none&& ptr2=null;
if true then
    ptr2 = ptr1;
else
    ptr2 = ptr2;
end;
escape 1;
]],
    --gcc = 'may be used uninitialized in this function',
    --fin = 'line 6 : pointer access across `await`',
    run = 1,
}

Test { [[
var int&& ptr1 = null;
var none&& ptr2 = null;
if true then
    ptr2 = ptr1 as none&&;
else
    ptr2 = ptr2;
end;
escape 1;
]],
    --fin = 'line 6 : pointer access across `await`',
    run = 1,
}

Test { [[
var int&& ptr1;
var none&& ptr2=null;
ptr1 = ptr2 as int&&;
ptr2 = ptr1 as none&&;
escape 1;
]],
    run = 1,
}

Test { [[
var none&& ptr1;
var int&& ptr2=null;
ptr1 = ptr2;
ptr2 = ptr1;
escape 1;
]],
    stmts = 'line 4 : invalid assignment : types mismatch : "int&&" <= "none&&"',
    --env = 'line 4 : types mismatch (`int&&` <= `none&&`)',
    run = 1,
}

Test { [[
native _char;
var _char&& ptr1;
var int&& ptr2=0xFF as none&&;
ptr1 = ptr2;
ptr2 = ptr1;
escape ptr2 as int;
]],
    stmts = 'line 3 : invalid assignment : types mismatch : "int&&" <= "none&&"',
    --env = 'line 3 : types mismatch (`int&&` <= `none&&`)',
    --env = 'line 4 : invalid attribution',
    --run = 255,
    --gcc = 'error: assignment from incompatible pointer type'
}
Test { [[
native _char;
var _char&& ptr1;
var int&& ptr2=0xFF as none&&;
ptr1 = (ptr2 as _char&&);
ptr2 =  ptr1 as int&&;
escape (ptr2 as int);
]],
    stmts = 'line 3 : invalid assignment : types mismatch : "int&&" <= "none&&"',
    --env = 'line 3 : types mismatch (`int&&` <= `none&&`)',
    --env = 'line 4 : invalid attribution',
    --run = 255,
    --gcc = 'error: cast from pointer to integer of different size',
}
Test { [[
native _char;
var _char&& ptr1;
var int&& ptr2=null;
ptr1 = (ptr2 as _char&&);
ptr2 = ptr1 as int&&;
escape 1;
]],
    run = 1,
}
Test { [[
native _char;
var int&& ptr1;
var _char&& ptr2=null;
ptr1 =  ptr2 as int&&;
ptr2 = ( ptr1 as _char&&);
escape 1;
]],
    run = 1,
}

Test { [[
native _FILE;
native/pre do
    ##include <stdio.h>
end
var int&& ptr1;
var _FILE&& ptr2=null;
ptr1 = ptr2;
ptr2 = ptr1;
escape 1;
]],
    --env = 'line 4 : invalid attribution (int&& vs _FILE&&)',
    cc = 'error: assignment from incompatible pointer type',
    --run = 1,
    --env = 'line 4 : invalid attribution',
}

Test { [[
native _FILE;
native/pre do
    ##include <stdio.h>
end
var int&& ptr1;
var _FILE&& ptr2=null;
ptr1 = ptr2 as int&&;
ptr2 = ptr1 as _FILE&&;
escape 1;
]],
    run = 1,
    --env = 'line 4 : invalid attribution',
}

Test { [[
var int a = 1;
var int&& b = &&a;
*b = 2;
escape a;
]],
    run = 2,
}

Test { [[
var int a=0;
par/or do
    a = 1;
with
var int&& pa=null;
    pa = &&a;
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
var& int a = &b;
par/or do
    b = 1;
with
    a = 0;
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
par/and do
    b = 1;
with
var int&& a = &&c;
deterministic b with a, c;
    *a = 3;
end
escape b+c;
]],
    run = 4,
}

Test { [[
native/nohold _f;
native/pos do
    none f (int* v) {
        *v = 1;
    }
end
var int a=1; var int  b=1;
par/and do
    _f(&&b);
with
    _f(&&a);
end
escape a + b;
]],
    run = 2,
    _ana = {
        acc = 1,
    },
}

Test { [[
native/nohold _f;
native/pos do
    none f (int* v) {
        *v = 1;
    }
end
var int a=1; var int  b=1;
par/and do
    a = 1;              // 10
with
    _f(&&b);             // 12
with
    _f(&&a);             // 14
with
var int&& pb = &&b;
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
native/nohold _f;
native/pos do
    none f (int* v) {
        *v = 1;
    }
end
var int a=1; var int  b=0;
par/or do
    a = 1;
with
    _f(&&b);
with
    _f(&&a);
with
var int&& pb = &&b;
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
native/pos do
    none f (int* v) {
        *v = 1;
    }
end
var int a=1; var int  b=1;
var int&& pb = &&b;
par/and do
    a = 1;
with
    _f(&&b);
with
    _f(&&a);
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
native/pos do
    none f (int* v) {
        *v = 1;
    }
end
var int a=1; var int  b=1;
var int&& pb = &&b;
par/or do
    a = 1;
with
    _f(&&b);
with
    _f(&&a);
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
var int&& a = ((&&b) as int&&);
var int&& c = &&b;
escape *a + *c;
]],
    run = 20;
}

Test { [[
native _f, _p;
native/pos do
    ##define f(p)
end
par/or do
    do
        _f(_p);
    finalize with
        _f(null);
    end;
with
    await FOREVER;
end
escape 1;
]],
    scopes = 'line 6 : invalid `finalize` : nothing to finalize',
    --fin = 'line 5 : invalid `finalize`',
    --run = 1,
}

Test { [[
native _fff, _p;
native/pos do
    ##define fff(p)
end
par/or do
    _fff(_p);
with
    await FOREVER;
end
escape 1;
]],
    run = 1,
}

Test { [[
native _char;
var _char&& p=null;
*(p:a) = (1 as _char);
escape 1;
]],
    --env = 'line 3 : invalid operand to unary "*"',
    cc = 'error: request for member',
}

Test { [[
input none OS_START;
var int h = 10;
var& int p = &h;
do
    var int x = 0;
    await OS_START;
    var int z = 0;
    if x!=0 and z!=0 then end;
end
escape p;
]],
    run = 10;
}

-->>> NATIVE/POINTERS/VECTORS

Test { [[input int[1] E; escape 0;]],
    --run = 0,
    --env = 'invalid event type',
    parser = 'line 1 : after `int` : expected type modifier or external identifier',
}
Test { [[var[2] int v; escape v;]],
    stmts = 'line 1 : invalid `escape` : unexpected context for vector "v"',
    --env = 'types mismatch'
}
Test { [[native _u8; var[2] _u8 v=_; escape (&&v==&&v) as int;]],
    _opts = { cc_args='-DCEU_TESTS' },
    wrn = true,
    run = 1,
    --dcls = 'line 1 : invalid operand to `&&` : unexpected context for vector "v"',
    --env = 'line 1 : types mismatch (`int` <= `_u8[]&&`)',
    --env = 'invalid operand to unary "&&"',
}
Test { [[native _u8; var _u8[2] v; escape &&v;]],
    parser = 'line 1 : after `_u8` : expected type modifier or internal identifier',
}

Test { [[
native _int;
var[10] _int x = _;
escape sizeof(x) as int;
]],
    wrn = true,
    run = 40,
}

Test { [[
N;
]],
    --adj = 'line 1 : invalid expression',
    --parser = 'line 1 : after `<BOF>` : expected statement',
    parser = 'line 1 : after `begin of file` : expected statement',
    --parser = 'after `N` : expected `(`',
}

Test { [[
none[10] a;
]],
    parser = 'line 1 : after `begin of file` : expected statement',
}

Test { [[
var[10] none a;
]],
    wrn = true,
    dcls = 'line 1 : invalid declaration : vector cannot be of type `none`',
}

Test { [[
native _int;
var[2] _int v = _;
v[0] = 5;
escape v[0];
]],
    wrn = true,
    run = 5
}

Test { [[
native _int;
var[2] _int v = _;
v[0] = 1;
v[1] = 1;
escape v[0] + v[1];
]],
    wrn = true,
    run = 2,
}

Test { [[
native _int;
var[2] _int v = _;
var int i;
v[0] = 0;
v[1] = 5;
v[0] = 0;
i = 0;
escape v[i+1];
]],
    wrn = true,
    run = 5
}

Test { [[
var[1] none b;
]],
    wrn = true,
    dcls = 'line 1 : invalid declaration : vector cannot be of type `none`',
}

Test { [[
native/pre do
    typedef struct {
        int v[10];
        int c;
    } Tx;
end
native _Tx ;

var[10] _Tx vec = _;
var int i = 110;

vec[3].v[5] = 10;
vec[9].c = 100;
escape i + vec[9].c + vec[3].v[5];
]],
    wrn = true,
    run = 220,
}

Test { [[
native _int;
var[1] _int v;
escape 1;
]],
    wrn = true,
    run = 1,
    --cval = 'line 1 : invalid dimension',
    --inits = 'line 2 : uninitialized vector "v" : reached `escape` (/tmp/tmp.ceu:3)',
}
Test { [[
native _int;
var[1] _int v = _;
escape 1;
]],
    wrn = true,
    run = 1,
    --cval = 'line 1 : invalid dimension',
    --ref = 'line 1 : uninitialized variable "v" crossing compound statement (/tmp/tmp.ceu:1)',
}
Test { [[
native _u8, _V;
var[10] _u8 v = [_V];
escape v[0];
]],
    stmts = 'line 2 : invalid constructor : expected internal type : got "_u8"',
    --tmp = 'invalid attribution : external vectors accept only empty initialization `[]`',
}

Test { [[
native _u8;
var[10] _u8 vvv = _;
vvv[9] = 1;
escape vvv[9];
]],
    wrn = true,
    run = 1,
}

Test { [[
native _u8;
var[10] _u8 v;
escape v[0];
]],
    inits = 'line 2 : uninitialized vector "v" : reached read access (/tmp/tmp.ceu:3)',
    --ref = 'line 2 : invalid access to uninitialized variable "v" (declared at /tmp/tmp.ceu:1)',
}

Test { [[var[2] int v; await v;     escape 0;]],
    --env='event "v" is not declared'
    stmts = 'line 1 : invalid `await` : unexpected context for vector "v"',
}
Test { [[var[2] int v; emit v;    escape 0;]],
    stmts = 'line 1 : invalid `emit` : unexpected context for vector "v"',
    --env = 'line 1 : identifier "v" is not an event (/tmp/tmp.ceu : line 1)',
}
Test { [[var[0] int[2] v; await v;  escape 0;]],
        --env='line 1 : event "?" is not declared'
        parser = 'line 1 : after `int` : expected type modifier or internal identifier',
}
Test { [[var[0] int[2] v; emit v; escape 0;]],
        --env='event "?" is not declared'
        parser = 'line 1 : after `int` : expected type modifier or internal identifier',
}
Test { [[
native _int;
var[2] _int v;
v=v;
escape 0;
]],
    stmts = 'line 3 : invalid assignment : unexpected context for vector "v"',
    --env='types mismatch'
}
Test { [[var[1] int v; escape v;]],
    stmts = 'line 1 : invalid `escape` : unexpected context for vector "v"',
    --env='cannot index a non array'
}
Test { [[native _int; var[2] _int v; escape v[v];]],
    dcls = 'line 1 : invalid index : unexpected context for vector "v"',
    --env='invalid array index'
}

Test { [[
var[2] int v ;
escape v == &&v[0] ;
]],
    dcls = 'line 2 : invalid operand to `==` : unexpected context for vector "v"',
    --dcls = 'line 2 : invalid expression : operand to `&&` must be a name',
    --env = 'line 2 : invalid operands to binary "=="',
    --run = 1,
}
Test { [[
native _int;
var[2] _int v ;
escape v == &&v[0] ;
]],
    dcls = 'line 3 : invalid operand to `==` : unexpected context for vector "v"',
    --dcls = 'line 3 : invalid operand to `==` : expected the same type',
    --env = 'line 2 : invalid operands to binary "=="',
    --run = 1,
}

Test { [[
native/plain _int;
native/nohold _f;
native/pos do
    none f (int* p) {
        *p = 1;
    }
end
var[2] _int a = _;
var int b=0;
par/and do
    b = 2;
with
    _f(&&a[0]);
end
escape a[0] + b;
]],
    wrn = true,
    run = 3,
}

Test { [[
native/nohold _f;
native/pos do
    none f (int* p) {
        *p = 1;
    }
end
native/plain _int;
var[2] _int a = _;
a[0] = 0;
a[1] = 0;
var int b=0;
par/and do
    b = 2;
with
    _f(&&a[0]);
end
escape a[0] + b;
]],
    wrn = true,
    _ana = {
        abrt = 1,
    },
    --env = 'line 14 : wrong argument #1 : cannot pass plain vectors to native calls',
    --code = 'line 14 : invalid value : vectors are not copyable',
    run = 3,
}

Test { [[
native/nohold _f;
native/pos do
    none f (int* p) {
        *p = 1;
    }
end
native/plain _int;
var[2] _int a = _;
a[0] = 0;
a[1] = 0;
var int b=0;
par/or do
    b = 2;
with
    _f(&&a[0]);
end
escape a[0] + b;
]],
    wrn = true,
    _ana = {
        abrt = 1,
    },
    run = 2,
}

local evts = ''
for i=1, 256 do
    evts = evts .. 'event int e'..i..';\n'
end
Test { [[
]]..evts..[[
escape 1;
]],
    wrn = true,
    tmp = 'line 1 : too many events',
}

Test { [[
var int a = 1;
escape a;
]],
    run = 1,
}

Test { [[
input (byte, u32) HTTP_GET;
var byte p2Buff;
var u32 len;
(p2Buff, len) = await HTTP_GET;
var[0] byte c = p2Buff; // doesn't work
escape 1;
]],
    stmts = 'line 5 : invalid assignment : unexpected context for vector "c"',
}

Test { [[
input (byte&&, u32) HTTP_GET;
var byte&& p2Buff;
var u32 len;
(p2Buff, len) = await HTTP_GET;
var[0] byte c = p2Buff; // doesn't work
escape 1;
]],
    --env = 'line 5 : cannot index pointers to internal types',
    stmts = 'line 5 : invalid assignment : unexpected context for vector "c"',
}

Test { [[
native/pure _f;
native/pos do
    int f (int* v) {
        return v[0];
    }
end
native _int;
var[2] _int v = _;
v[0] = 10;
escape _f(&&v[0]);
]],
    wrn = true,
    run = 10,
}

Test { [[
native _ceu_uv_read_start, _assert;
input none UV_READ;
native/plain _char, _uv_buf_t, _uv_stream_t;
native/nohold _uv_buf_init, _uv_read_stop;
var[3] _char buf_ = _;
var _uv_buf_t buf = _uv_buf_init(&&buf_[0], 1);
var _uv_stream_t client = _uv_stream_t();
var int ret;
do
    ret = _ceu_uv_read_start((&&client) as _uv_stream_t&&, &&buf);
finalize (client, buf) with
    _uv_read_stop((&&client) as _uv_stream_t&&);
end;
_assert(ret == 0);
escape 0;
]],
    wrn = true,
    cc = 'implicit declaration of function ‘uv_buf_init’',
}

Test { [[
native/pure _strlen;

native _char;
var[255] _char str;
str = "oioioi";

escape _strlen(&&str[0]);
]],
    stmts = 'line 5 : invalid assignment : unexpected context for vector "str"',
}

Test { [[
native/plain _int;
var[2] _int v = _;
par/and do
    v[0] = 1;
with
var _int&& p = &&v[0];
    p[1] = 2;
end
escape v[0] + v[1];
]],
    wrn = true,
    _ana = {
        acc = 1,
    },
    --fin = 'line 6 : pointer access across `await`',
    run = 3;
}
Test { [[
native/plain _int;
var[2] _int v = _;
par/and do
    v[0] = 1;
with
    var _int&& p = &&v[0];
    p[1] = 2;
end
escape v[0] + v[1];
]],
    wrn = true,
    _ana = {
        acc = 1,
    },
    run = 3,
}
Test { [[
var[2] int v = [0,0];
var[2] int p = [0,0];
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
native/plain _int_ptr;
native/pure _X;
native/pre do
    typedef int* int_ptr;
    ##define X(x) x
end
var int x = 10;
var _int_ptr p = _X(&&x);
escape *p;
]],
    run = 10,
}

Test { [[
var int x = 1;
escape *(&&x);
]],
    run = 1,
    --parser = 'line 2 : after `(` : expected location',
}

--<<< NATIVE/POINTERS/VECTORS

    -- NATIVE C FUNCS BLOCK RAW

Test { [[
native _char;
var _char c = 1;
escape c;
]],
    run = 1,
}

Test { [[
native/plain _int;
var _int a=1; var int  b=1;
a = b;
await 1s;
escape (a==b) as int;
]],
    run = { ['~>1s'] = 1 },
}

Test { [[
var int a=1; var int  b=1;
a = b;
await 1s;
escape (a==b) as int;
]],
    run = { ['~>1s'] = 1 },
}

Test { [[
escape {1};
]],
    run = 1,
}

Test { [[
native _V;
{ int V = 10; };
escape _V;
]],
    run = 10,
}

Test { [[
{
    static int v;
    if (0) {
    } else {
        v = 1;
    }
};
escape {v};
]],
    run = 1,
}

Test { [[
var& none? p;
do p = &{ NULL };
finalize with
    nothing;
end
escape p! ==null;
]],
    dcls = 'line 2 : invalid operand to `&` : expected native call',
    --dcls = 'line 6 : invalid operands to `==` : incompatible types : "none" vs "null&&"',
    --env = 'line 7 : invalid operands to binary "=="',
    --run = 1,
}

Test { [[
var& none? p;
p = { NULL };
escape 1;
//escape p==null;
]],
    inits = 'line 2 : invalid binding : expected operator `&` in the right side',
    --tmp = 'line 2 : invalid attribution : missing `!` (in the left) or `&` (in the right)',
    --ref = 'line 2 : invalid attribution : missing alias operator `&`',
    --fin = 'line 2 : attribution requires `finalize`',
}

Test { [[
_f()
]],
    parser = 'line 1 : after `)` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `;`',
    --parser = 'line 1 : after `)` : expected `;`',
    --parser = 'line 1 : after `)` : expected `[` or `:` or `.` or `?` or `!` or `is` or `as` or binary operator or `=` or `:=` or `;`',
}

Test { [[
native _V;
native/pos do
    int V[2][2] = { {1, 2}, {3, 4} };
end

_V[0][1] = 5;
escape _V[1][0] + _V[0][1];
]],
    run = 8,
}

Test { [[
native _END;
native/pos do
    int END = 1;
end
if 0 ==  _END-1 then
    escape 1;
else
    escape 0;
end
]],
    run = 1,
}

Test { [[
native/pos do
end
escape 1;
]],
    run = 1,
}

Test { [[
native/pre do
end
native/end;
escape 1;
]],
    run = 1,
}

Test { [[
native/pre do
end native/end;
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
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
native/const _A, _B;
native/pos do
    ##define A 0
    ##define B 1
end
escape _A | _B;
]],
    run = 1,
}

Test { [[
native/pos do
    byte* a = (byte*)"end";
end
escape 1;
]],
    --parser = 'line 2 : after `"` : expected `"`',
    run = 1,
}

Test { [[
native/pos do
    /*** END ***/
    byte* a = (byte*)"end";
    /*** END ***/
end
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    int A () {}
end
A = 1;
escape 1;
]],
    --adj = 'line 4 : invalid expression',
    --parser = 'line 3 : after `end` : expected statement'
    parser = 'line 3 : after `end` : expected `;` or statement',
    --parser = 'line 4 : after `A` : expected `(`',
}

Test { [[
native/pos do
    none A (int v) {}
end
escape 0;
]],
    run = 0;
}

Test { [[
native/pos do
    int A (int v) { return 1; }
end
escape 0;
]],
    --env = 'A : incompatible with function definition',
    run = 0,
}

Test { [[
native _A;
native/pos do
    none A (int v) {}
end
_A();
escape 0;
]],
    --env = 'line 5 : native function "_A" is not declared',
    --run  = 1,
    cc = 'error: too few arguments to function ‘A’',
}

Test { [[
native _A;
native/pos do
    none A (int v) { }
end
_A(1);
escape 0;
]],
    run = 0,
}

Test { [[
native _A;
native/pos do
    void A () {}
end
var int v = _A();
escape v;
]],
    --cc = '1: error: invalid use of none expression',
    cc = 'error: void value not ignored as it ought to be',
}

Test { [[emit A(10); escape 0;]],
    dcls = 'external identifier "A" is not declared'
}

Test { [[
native _Const;
native/pos do
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
native _ID;
native/pos do
    int ID (int v) {
        return v;
    }
end
escape _ID(10);
]],
    run = 10,
}

Test { [[
native _ID;
native/pos do
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
native _VD;
native/pos do
    void VD (int v) {
    }
end
_VD(10);
escape 1;
]],
    run = 1
}

Test { [[
native _VD;
native/pos do
    void VD (int v) {
    }
end
var int ret = _VD(10);
escape ret;
]],
    --cc = '1: error: invalid use of none expression',
    cc = 'error: void value not ignored as it ought to be',
}

Test { [[
native _VD;
native/pos do
    void VD (int v) {
    }
end
var none v = _VD(10);
escape 0;
]],
    dcls = 'line 6 : invalid declaration : variable cannot be of type `none`',
}

Test { [[
native _NEG;
native/pos do
    int NEG (int v) {
        return -v;
    }
end
escape _NEG(10);
]],
    run = -10,
}

Test { [[
native _NEG;
native/pos do
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
native _ID;
native/pos do
    int ID (int v) {
        return v;
    }
end
input int A;
var int v=0;
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
native _ID;
native/pos do
    int ID (int v) {
        return v;
    }
end
input int A;
var int v=0;
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
native _Z1;
native/pos do int Z1 (int a) { return a; } end
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
native/nohold _f1, _f2;
native/pos do
    int f1 (u8* v) {
        return v[0]+v[1];
    }
    int f2 (u8* v1, u8* v2) {
        return *v1+*v2;
    }
end
native _u8;
var[2] _u8 v = _;
v[0] = 8;
v[1] = 5;
escape _f2(&&v[0],&&v[1]) + _f1(&&v[0]) + _f1(&&v[0]);
]],
    wrn = true,
    run = 39,
}

Test { [[
native/pos do
    none* V;
end
var none&& v = null;
native _V;
_V = v;
escape 1;
]],
    scopes = 'line 6 : invalid pointer assignment : expected `finalize`',
}

Test { [[
native/pos do
    none* V;
end
var none&& v = null;
native _V;
do _V = v; finalize(v) with end
escape 1;
]],
    run = 1,
}

Test { [[
native/pos do
    none* V;
end
var none&& v=null;
native _V;
do
    _V = v;
finalize (v)
with end
await 1s;
escape (_V==null) as int;
]],
    run = false,
    --fin = 'line 7 : pointer access across `await`',
}

Test { [[
do/_
    var int&& p=_; var int&& p1=_;
    input int&& E;
    p = await E;
    p1 = p;
    await E;
    escape *p1;
end
]],
    wrn = true,
    --run = 1,
    --inits = 'line 5 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:4)',
    ptrs = 'line 5 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:4)',
    --fin = 'line 7 : unsafe access to pointer "p1" across `await`',
}

Test { [[
native _tp, _a, _b;
native/pos do
    typedef int tp;
end
var _tp&& v=null;
do
    _a = v;
finalize (v) with
end
await 1s;
_b = _a;    // _a pode ter escopo menor e nao reclama de FIN
await FOREVER;
]],
    --fin = 'line 7 : pointer access across `await`',
    cc = '1: error: unknown type name ‘tp’',
    _ana = {
        isForever = true,
    },
}

Test { [[
var int v = 10;
var int&& x = &&v;
event none e;
var int ret=0;
if true then
    ret = *x;
    emit e;
else
    emit e;
    escape *x;
end
escape ret;
]],
    --inits = 'line 10 : invalid pointer access : crossed `emit` (/tmp/tmp.ceu:9)',
    ptrs = 'line 10 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:9)',
    --fin = 'line 10 : unsafe access to pointer "x" across `emit`',
}

Test { [[
var int v = 10;
var int&& x = &&v;
event none e;
var int ret=0;
if true then
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
var& int x = &v;
event none e;
var int ret=0;
par do
    ret = x;
    emit e;
with
    escape x;
end
]],
    _ana = {acc=2},
    run = 10,
}

Test { [[
var int v = 10;
var& int x = &v;
event none e;
var int ret=0;
par do
    ret = x;
    emit e;
with
    par/or do
        ret = x;
        emit e;
    with
        ret = x;
        await e;
    with
        par/and do
            ret = x;
            emit e;
        with
            ret = x;
            await e;
        end
    end
with
    escape x;
end
]],
    _ana = {acc=true},
    run = 10,
}

Test { [[
native/plain _SDL_Rect, _SDL_Point;
var _SDL_Point p;

var _SDL_Rect rect = _SDL_Rect(p.x, p.y);
await 1s;
var _SDL_Rect r = rect;
escape 1;
]],
    inits = 'line 2 : uninitialized variable "p" : reached read access (/tmp/tmp.ceu:4)',
    --ref = 'line 4 : invalid access to uninitialized variable "p" (declared at /tmp/tmp.ceu:2)',
}
Test { [[
native/plain _SDL_Rect, _SDL_Point;
var _SDL_Point p = _SDL_Point(1,1);

var _SDL_Rect rect = _SDL_Rect(p.x, p.y);
await 1s;
var _SDL_Rect r = rect;
escape 1;
]],
    cc = 'error: unknown type name ‘SDL_Point’',
}

Test { [[
native/plain _SDL_Rect, _SDL_Point;
var _SDL_Point p = _SDL_Point(1,1);

var _SDL_Rect rect = _SDL_Rect(p.x, p.y);
await 1s;
var _SDL_Rect r = rect;
    r.x = r.x - r.w/2;
    r.y = r.y - r.h/2;
escape 1;
]],
    cc = 'error: unknown type name ‘SDL_Point’',
}

Test { [[
native _int, _f;
native/pos do
    int f () {
        return 1;
    }
end
var[2] _int v = _;
v[0] = 0;
v[1] = 1;
v[_f()] = 2;
escape v[1];
]],
    wrn = true,
    run = 2,
}

Test { [[
var int xxx = 10;
escape ((__ceu_app:data as _CEU_Main&&)):xxx;
]],
    parser = 'line 2 : after `:` : expected internal identifier or native identifier',
}
Test { [[
native __ceu_app, _CEU_Main;
var int xxx = 10;
escape ((__ceu_app:_data as _CEU_Main&&)):xxx;
]],
    todo = 'C access to internal data',
    run = 10,
    --parser = 'line 3 : after `)` : expected `(` or binary operator or `is` or `as` or `;`',
}
Test { [[
native __ceu_app, _CEU_Main;
var int xxx = 10;
escape (__ceu_app:_data as _CEU_Main&&):xxx;
]],
    todo = 'C access to internal data',
    run = 10,
    --parser = 'line 3 : after `)` : expected `(` or `?` or `is` or `as` or binary operator or `;`',
}
Test { [[
//native __ceu_app, _CEU_Main;
var int xxx = 10;
escape ({(CEU_Main*)(_ceu_app->_data)}):xxx;
]],
    todo = 'C access to internal data',
    run = 10,
}
-- NATIVE/PRE

--[=[

PRE = [[
native/pos do
    static inline int idx (@const int* vec, int i) {
        escape vec[i];
    }
    static inline int set (int* vec, int i, int val) {
        vec[i] = val;
        escape val;
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
    run = false,
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
    run = false,
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
int&& pa, pb;

par/or do
    pa = &&a;
with
    pb = &&b;
end;
escape 1;
]],
    run = 1
}

PRE = [[
@pure _f3, _f5;
native/pos do
int f1 (int* a, int* b) {
    escape *a + *b;
}
int f2 (@const int* a, int* b) {
    escape *a + *b;
}
int f3 (@const int* a, const int* b) {
    escape *a + *b;
}
int f4 (int* a) {
    escape *a;
}
int f5 (@const int* a) {
    escape *a;
}
end
]]

Test { PRE .. [[
int a = 1;
int b = 2;
escape _f1(&&a,&&b);
]],
    run = 3,
}

Test { PRE .. [[
int&& pa;
par/or do
    _f4(pa);
with
    int v = 1;
end;
escape 0;
]],
    run = false,
    _ana = {
        acc = 1,
    },
}
Test { PRE .. [[
int a;
par/or do
    _f4(&&a);
with
    int v = a;
end;
escape 0;
]],
    run = false,
    _ana = {
        acc = 1,
    },
}
Test { PRE .. [[
int a, b;
par/or do
    _f5(&&a);
with
    a = 1;
end;
escape 0;
]],
    run = false,
    _ana = {
        acc = 1,
    },
}
Test { PRE .. [[
int a = 10;
par/or do
    _f5(&&a);
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
int&& pa;
par/or do
    _f5(pa);
with
    escape a;
end;
escape 0;
]],
    --abrt = 1,
    run = false,
    _ana = {
        acc = 1,
    },
}
Test { PRE .. [[
int a, b;
par/or do
    _f4(&&a);
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
    _f5(&&a);
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
    _f5(&&a);
with
    int v = b;
end;
escape 0;
]],
    run = 0,
}
Test { PRE .. [[
int&& pa;
do
    int a;
    pa = &&a;
end;
escape 1;
]],
    run = 1,     -- TODO: check_depth
    --env = 'invalid attribution',
}
Test { PRE .. [[
int a=1;
do
    int&& pa = &&a;
    *pa = 2;
end;
escape a;
]],
    run = 2,
}

Test { PRE .. [[
int a;
int&& pa;
par/or do
    _f4(pa);
with
    int v = a;
end;
escape 0;
]],
    run = false,
    _ana = {
        acc = 2, -- TODO: scope of v vs pa
    },
}
Test { PRE .. [[
int a;
int&& pa;
par/or do
    _f5(pa);
with
    a = 1;
end;
escape a;
]],
    run = false,
    _ana = {
        acc = 1,
    },
}
Test { PRE .. [[
int a;
int&& pa;
par do
    escape _f5(pa);
with
    escape a;
end;
]],
    --abrt = 2,
    run = false,
    _ana = {
        acc = 2, -- TODO: $ret vs anything is DET
    },
}

Test { PRE .. [[
int a=1, b=5;
par/or do
    _f4(&&a);
with
    _f4(&&b);
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
    v1 = _f1(&&a,&&b);
with
    v2 = _f1(&&a,&&b);
end;
escape v1 + v2;
]],
    run = false,
    _ana = {
        acc = 3,
    },
}

Test { PRE .. [[
int a = 1;
int b = 2;
int v1, v2;
par/and do
    v1 = _f2(&&a,&&b);
with
    v2 = _f2(&&a,&&b);
end;
escape v1 + v2;
]],
    run = false,
    _ana = {
        acc = 3,     -- TODO: f2 is const
    },
}

Test { PRE .. [[
int a = 1;
int b = 2;
int v1, v2;
par/and do
    v1 = _f3(&&a,&&b);
with
    v2 = _f3(&&a,&&b);
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
    v1 = _f4(&&a);
with
    v2 = _f4(&&b);
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
    v1 = _f4(&&a);
with
    v2 = _f4(&&a);
end;
escape a+a;
]],
    run = false,
    _ana = {
        acc = 2,
    },
}

Test { PRE .. [[
int a = 2;
int b = 2;
int v1, v2;
par/and do
    v1 = _f5(&&a);
with
    v2 = _f5(&&a);
end;
escape a+a;
]],
    run = 4,
}

Test { PRE .. [[
int a;
int&& pa = &&a;
a = 2;
int v1,v2;
par/and do
    v1 = _f4(&&a);
with
    v2 = _f4(pa);
end;
escape v1+v2;
]],
    run = false,
    _ana = {
        acc = 3,
    },
}

Test { PRE .. [[
int a;
int&& pa = &&a;
a = 2;
int v1,v2;
par/and do
    v1 = _f5(&&a);
with
    v2 = _f5(pa);
end;
escape v1+v2;
]],
    run = false,
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
deterministic _printf with _assert;
native/pos do ##include <assert.h> end
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
native/pos do
    int a;
end
par/or do
    _a = 1;
with
    _a = 2;
end
escape _a;
]],
    run = false,
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
native _LOW, _HIGH, _digitalWrite;
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
    cc = '1: error: implicit declaration of function ‘digitalWrite’',
    _ana = {
        acc = true,
        isForever = true,
    },
    --fin = 'line 4 : call requires `finalize`',
}

Test { [[
native/const _LOW, _HIGH;
native _digitalWrite;
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
    cc = '1: error: implicit declaration of function ‘digitalWrite’',
    _ana = {
        acc = true,
        isForever = true,
    },
}

    -- RAW

Test { [[
{fff}(1,2);
]],
    parser = 'line 1 : after `1` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `)`',
}

Test { [[
native/pos do
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
    --parser = 'line 8 : after `)` : expected `[` or `:` or `.` or `?` or `!` or `is` or `as` or binary operator or `=` or `:=`',
}

Test { [[
native/pos do
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

-->> NATIVE / RAW / INTERPOLATION

Test { [[
native _V;
native/pre do
    int V = 10;
end
var int v = 100;
{
    V += @v;
};
escape _V;
]],
    run = 110,
}
Test { [[
native _V;
native/pre do
    int V = 10;
end
var int v = 100;
{
    V += @v;
};
escape _V + {@v};
]],
    run = 210,
}

Test { [[
native _V;
native/pre do
    int V = 10;
end
var int v = 100;
{
    int x[10] = {};
    V += @v;
};
escape _V + {@v};
]],
    run = 210,
}

Test { [[
native _V;
native/pre do
    int V = 10;
end
var int v = 100;
{
    int x[10] = { @v };
    V += x[@0];
};
escape _V + {@v};
]],
    run = 210,
}

Test { [=[
var bool ok = { '@@' == 64 } as bool;
escape ok as int;
]=],
    run = 1,
}
--<< NATIVE / RAW / INTERPOLATION

    -- STRINGS

Test { [[
var byte&& a;
a = "oioioi" as byte&&;
escape 1;
]],
    run = 1,
}

Test { [[
var int a;
a = "oioioi";
escape 1;
]],
    stmts = 'line 2 : invalid assignment : types mismatch : "int" <= "_char&&"',
    --env = 'line 2 : types mismatch (`int` <= `_char&&`)',
}

Test { [[
native _char;
var _char&& a = "Abcd12" ;
escape 1;
]],
    --env = 'line 2 : invalid attribution (_char&& vs byte&&)',
    run = 1,
}
Test { [[
native _char;
var _char&& a = ("Abcd12"  as _char&&);
escape 1;
]],
    run = 1
}
Test { [[
native _printf;
_printf("END: %s\n", "Abcd12");
escape 0;
]],
    todo = 'END for tests is not used anymore',
    run='Abcd12',
}
Test { [[
native _strlen;
escape _strlen("123");
]], run=3,
}
Test { [[
native _printf;
_printf("END: 1%d 0\n",2); escape 0;]],
    todo = 'END for tests is not used anymore',
    run=12,
}
Test { [[
native _printf;
_printf("END: 1%d%d 0\n",2,3); escape 0;]],
    todo = 'END for tests is not used anymore',
    run=123,
}

Test { [[
native/nohold _strncpy, _printf, _strlen;
native _char ;
var[10] _char str = _;
_strncpy(&&str[0], "123", 4);
_printf("END: %d %s\n", _strlen(&&str[0]) as int, &&str[0]);
escape 0;
]],
    wrn = true,
    todo = 'END for tests is not used anymore',
    run = '3 123'
}

Test { [[
native/nohold _printf, _strlen, _strcpy;
native _char;
var[6] _char a=_; _strcpy(&&a[0], "Hello");
var[2] _char b=_; _strcpy(&&b[0], " ");
var[7] _char c=_; _strcpy(&&c[0], "World!");
var[30] _char d=_;

var int len = 0;
_strcpy(&&d[0],&&a[0]);
_strcpy(&&d[_strlen(&&d[0])], &&b[0]);
_strcpy(&&d[_strlen(&&d[0])], &&c[0]);
_printf("END: %d %s\n", _strlen(&&d[0]) as int, &&d[0]);
escape 0;
]],
    wrn = true,
    todo = 'END for tests is not used anymore',
    run = '12 Hello World!'
}

Test { [[
native _const_1;
native/pos do
    int const_1 () {
        return 1;
    }
end
escape _const_1();
]],
    run = 1;
}

Test { [[
native _const_1;
native/pos do
    int const_1 () {
        return 1;
    }
end
escape _const_1() + _const_1();
]],
    run = 2;
}

Test { [[
native _inv;
native/pos do
    int inv (int v) {
        return -v;
    }
end
var int a;
a = _inv(_inv(1));
escape a;
]],
    --fin = 'line 8 : call requires `finalize`',
    run = 1,
}

Test { [[
native/pure _inv;
native/pos do
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
native _id;
native/pos do
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

-- STRUCTS / SIZEOF

Test { [[
native/pre do
typedef struct s {
    u16 a;
    u8 b;
    u8 c;
} s;
end
native/plain _s;
var _s vs = { (struct s){10,1,0} };
escape vs.a + vs.b + sizeof(_s);
]],
    run = 15,
}

Test { [[
native/pre do
typedef struct s {
    u16 a;
    u8 b;
    u8 c;
} s;
end
native/plain _s;
var _s vs = { (struct s){10,1,0} };
escape vs.a + vs.b + sizeof(_s) + sizeof(vs) + sizeof(vs.a);
]],
    run = 21,
}

Test { [[
native _SZ;
native _aaa = (sizeof<none&&,u16>) * 2;
native/pos do
    typedef struct {
        none&& a;
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
native/pre do
    typedef struct {
        u16 ack;
        u8 data[16];
    } Payload;
end
native _Payload ;
var _Payload final;
var u8&& neighs = &&(final._data[4]);
escape 1;
]],
    inits = 'line 8 : uninitialized variable "final" : reached read access (/tmp/tmp.ceu:9)',
    --ref = 'line 9 : invalid access to uninitialized variable "final" (declared at /tmp/tmp.ceu:8)',
}
Test { [[
native/pre do
    typedef struct Payload {
        u16 ack;
        u8 data[16];
    } Payload;
end
native/plain _Payload;
var _Payload final = { (struct Payload){0,{}} };
var u8&& neighs = &&(final._data[4]);
escape 1;
]],
    run = 1;
}

Test { [[
native/pos do
typedef struct {
    int a;
    int b;
} s;
end
native/plain _s;
var _s vs = _s(0,0);
par/and do
    vs.a = 10;
with
    vs.a = 1;
end;
escape vs.a;
]],
    cc = '1: error: unknown type name ‘s’',
    _ana = {
        acc = 1,
    },
}

Test { [[
native/pos do
typedef struct {
    int a;
    int b;
} s;
end
native/plain _s;
var _s vs = _s(0,0);
par/and do
    vs.a = 10;
with
    vs.b = 1;
end;
escape vs.a;
]],
    cc = '1: error: unknown type name ‘s’',
    _ana = {
        acc = 1,     -- TODO: struct
    },
}

Test { [[
native/pre do
    typedef struct mys {
        int a;
    } mys;
end
native/plain _mys;
var _mys v = { (struct mys){ 0 } };
var _mys&& pv;
pv = &&v;
v.a = 10;
(*pv).a = 20;
pv:a = pv:a + v.a;
escape v.a;
]],
    run = 40,
}

Test { [[
]],
    run = false,
    _ana = {
        reachs = 1,
        isForever = true,
    }
}

Test { [[
native _message_t ;
native _t = sizeof<_message_t, u8>;
escape sizeof<_t>;
]],
    todo = 'sizeof',
    run = 53,
}

Test { [[
native _char;
var _char a = (1 as _char);
escape a as int;
]],
    run = 1,
}

-- Exps

Test { [[var int a = ]],
    parser = "line 1 : after `=` : expected expression",
}

Test { [[escape]],
    parser = "line 1 : after `escape` : expected expression",
}

Test { [[escape()]],
    --parser = "line 1 : after `(` : expected expression",
    parser = "line 1 : after `(` : expected expression",
}

Test { [[escape 1+;]],
    parser = "line 1 : after `+` : expected expression",
}

Test { [[if then]],
    parser = "line 1 : after `if` : expected expression",
}

Test { [[b = ;]],
    parser = "line 1 : after `=` : expected expression",
}


Test { [[


escape 1

+


;
]],
    parser = "line 5 : after `+` : expected expression"
}

Test { [[
var int a;
a = do/_
    var int b;
end
]],
    parser = "line 4 : after `end` : expected `;`",
}

    -- POINTER ASSIGNMENTS

Test { [[
var int&& x;
*x = 1;
escape 1;
]],
    inits = 'line 1 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:2)',
    --ref = 'line 2 : invalid access to uninitialized variable "x" (declared at /tmp/tmp.ceu:1)',
}

Test { [[
var int&& p;
do
    var int i;
    p = &&i;
end
escape 1;
]],
    inits = 'line 3 : uninitialized variable "i" : reached read access (/tmp/tmp.ceu:4)',
    --ref = 'line 1 : uninitialized variable "p" crossing compound statement (/tmp/tmp.ceu:2)',
    --fin = 'line 4 : attribution to pointer with greater scope',
}
Test { [[
var int&& p=null;
do
    var int i=0;
    do p = &&i; finalize (i) with end
end
escape 1;
]],
    run = 1,
}
Test { [[
var int a;
do a = 1;
finalize with
    nothing;
end
escape 1;
]],
    scopes = 'line 2 : invalid `finalize` : nothing to finalize',
    --fin = 'line 3 : attribution does not require `finalize`',
}
Test { [[
var int&& a;
do a = null;
finalize with
    nothing;
end
escape 1;
]],
    scopes = 'line 2 : invalid `finalize` : nothing to finalize',
    --fin = 'line 3 : attribution does not require `finalize`',
}
Test { [[
var int a=0;
var int&& pa;
do pa = &&a;
finalize with
    nothing;
end
escape 1;
]],
    scopes = 'line 3 : invalid `finalize` : nothing to finalize',
    --fin = 'line 4 : attribution does not require `finalize`',
}

Test { [[
native _int;
var _int&& u;
var[1] _int i;
await 1s;
u = i;
escape 1;
]],
    stmts = 'line 5 : invalid assignment : unexpected context for vector "i"',
    --env = 'line 4 : types mismatch (`_int&&` <= `_int[]`)',
    --run = { ['~>1s']=1 },
}
Test { [[
native _int;
var _int ptr = null;
await 1s;
escape (ptr == null) as int;
]],
    wrn = true,
    --inits = 'line 4 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:3)',
    ptrs = 'line 4 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:3)',
    --fin = 'line 4 : unsafe access to pointer "i" across `await` (/tmp/tmp.ceu : 3)',
}
Test { [[
native _int;
var[1] _int i=_;
await 1s;
var _int&& u = _;
u = &&i[0];
escape 1;
]],
    wrn = true,
    --inits = 'line 5 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:3)',
    ptrs = 'line 5 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:3)',
    --fin = 'line 4 : unsafe access to pointer "i" across `await` (/tmp/tmp.ceu : 3)',
}
Test { [[
native/plain _int;
var[1] _int i=_;
await 1s;
var _int&& u = _;
u = &&i[0];
if u==null then end;
escape 1;
]],
    wrn = true,
    run = { ['~>1s']=1 },
}
Test { [[
var int&& u;
var[1] int i;
await 1s;
u = i;
escape 1;
]],
    stmts = 'line 4 : invalid assignment : unexpected context for vector "i"',
    --env = 'line 4 : types mismatch (`int&&` <= `int[]`)',
    --run = { ['~>1s']=1 },
}
Test { [[
native _int;
var _int&& u;
do
    var[1] _int i;
    i[0] = 2;
    u = i;
end
do
    var[1] _int i;
    i[0] = 5;
end
escape *u;
]],
    stmts = 'line 6 : invalid assignment : unexpected context for vector "i"',
    --env = 'line 5 : types mismatch (`_int&&` <= `_int[]`)',
}
Test { [[
native _int;
var _int&& u;
do
    var[1] _int i;
    i[0] = 2;
    u = &&i[0];
end
do
    var[1] _int i;
    i[0] = 5;
end
escape *u;
]],
    inits = 'line 4 : uninitialized vector "i" : reached read access (/tmp/tmp.ceu:5)',
    --ref = 'line 1 : uninitialized variable "u" crossing compound statement (/tmp/tmp.ceu:2)',
    --fin = 'line 5 : attribution to pointer with greater scope',
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
input int&& SDL_KEYUP;
par/or do
    var int&& key;
    key = await SDL_KEYUP;
    if key==null then end;
with
    await async do
        emit SDL_KEYUP(null);
    end
end
escape 1;
]],
    run = 1.
}

Test { [[
native _SDL_KeyboardEvent;
input _SDL_KeyboardEvent&& SDL_KEYUP;
var _SDL_KeyboardEvent&& key;
every key in SDL_KEYUP do
    if key:keysym.sym == 1 then
    else/if key:keysym.sym == 1 then
    end
end
]],
    cc = false,
    _ana = {
        isForever = true,
    },
}

-->>> CPP / DEFINE / PREPROCESSOR

Test { [[
#define OI

a = 1;
]],
    dcls = 'line 3 : internal identifier "a" is not declared',
}

Test { [[
native/const _N;
native/pre do
    #define N 1
end
native _u8;
var[_N] _u8 vec = _;
vec[0] = 10;
escape vec[_N-1];
]],
    wrn = true,
    run = 10,
}

Test { [[
native/pre do
    #define N 1
end
native _u8;
var[N] _u8 vec = _;
vec[0] = 10;
escape vec[N-1];
]],
    wrn = true,
    opts_pre = true,
    run = 10,
}

Test { [[
native/pre do
    #define N 1
end
native _u8;
var[N+1] _u8 vec = _;
vec[1] = 10;
escape vec[1];
]],
    wrn = true,
    opts_pre = true,
    run = 10,
}

Test { [[
#define N 1
native _u8;
var[N+1] _u8 vec = _;
vec[1] = 10;
escape vec[1];
]],
    wrn = true,
    opts_pre = true,
    run = 10,
}

Test { [[
var[5] int vec = _;
var int i;
var int i;
escape 1;
]],
    opts_pre = true,
    --loop = true,
    wrn = true,
    run = 1,
}

Test { [[
native/const _N;
native/pre do
    #define N 5
end
native/plain _int;
var[_N] _int vec = _;
var int i;
loop i in [0 -> _N[ do
    vec[i] = i;
end
var int ret = 0;
var int i;
loop i in [0 -> _N[ do
    ret = ret + vec[i];
end
escape ret;
]],
    opts_pre = true,
    --loop = true,
    wrn = true,
    run = 10,
}

Test { [[
#define UART0_BASE 0x20201000
#define UART0_CR ((UART0_BASE + 0x30) as u32&&)
*UART0_CR = 0x00000000;
escape 1;
]],
    opts_pre = true,
    --parser = 'line 3 : after `(` : expected location',
    parser = 'line 3 : after `)` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `;`',
}

Test { [[
#define UART0_BASE 0x20201000
#define UART0_CR ((u32*)(UART0_BASE + 0x30))
*{UART0_CR} = 0x00000000;
escape 1;
]],
    todo = 'segfault',
    opts_pre = true,
    valgrind = false,
    asr = true,
}

Test { [[
native/pre do
    void f (char* str) {}
end
native _f;
_f("#99\n");
{ceu_assert(0,"err");}
escape 1;
]],
    _opts = { ceu_features_trace='true' },
    run = '99] -> runtime error: err',
}

--<<< CPP / DEFINE / PREPROCESSOR

-- ASYNC

Test { [[
input none A;
par/or do
    await async do
        emit A;
    end
    escape -1;
with
    await A;
end
await async do
end
escape 1;
]],
    run = 1,
}

Test { [[
input none A;
await async do
    await A;
end
escape 1;
]],
    props_ = 'line 3 : invalid `await` : unexpected enclosing `async`',
}

Test { [[
await async do

    par/or do
        var int a=0;
    with
        var int b=0;
    end
end
]],
    props_ = 'line 3 : invalid `par/or` : unexpected enclosing `async`',
    --props = "line 3 : not permitted inside `async`",
}
Test { [[
await async do


    par/and do
        var int a=0;
    with
        var int b=0;
    end
end
]],
    props_ = 'line 4 : invalid `par/and` : unexpected enclosing `async`',
    --props = "line 4 : not permitted inside `async`",
}
Test { [[
await async do
    par do
        var int a=0;
    with
        var int b=0;
    end
end
]],
    props_ = 'line 2 : invalid `par` : unexpected enclosing `async`',
    --props = "line 2 : not permitted inside `async`",
}

-- DFA

Test { [[
var int a=0;
]],
    run = false,
    _ana = {
        reachs = 1,
        isForever = true,
    },
}

Test { [[
var int a;
a = do/_
    var int b=0;
end;
]],
    run = false,
    _ana = {
        reachs = 1,
        unreachs = 1,
        isForever = true,
    },
}

Test { [[
var int a=0;
par/or do
    a = 1;
with
    a = 2;
end;
escape a;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 1,
    },
}

-- BIG // FULL // COMPLETE
Test { [[
input int KEY;
if true then escape 50; end
par do
    var int pct=0; var int  dt=0; var int  step=0; var int  ship=0; var int  points=0;
    var int win = 0;
    loop do
        if win!=0 then
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
        win = do/_ par do
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
end
            end;
        par/or do
            await 1s;
            await KEY;
        with
            if win==0 then
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
                await async (read1) do
                    emit KEY(read1);
                end
            end
        end
    end
end
]],
    run = 50,
}

-- TIGHT LOOPS

Test { [[
var int i;
loop i in [0 -> 10[ do
    i = 0;
end
]],
    stmts = 'line 3 : invalid assignment : read-only variable "i"',
    --env = 'line 2 : read-only variable',
}

Test { [[
loop do end
]],
    tight_ = 'line 1 : invalid tight `loop` :',
    --tight = 'line 1 : tight loop',
}
Test { [[
var int i;
loop i do end
]],
    tight_ = 'line 2 : invalid tight `loop` :',
    --tight = 'line 1 : tight loop',
}
Test { [[
var int i;
loop i in [0 -> 10[ do end
escape 2;
]],
    run = 2,
}
Test { [[
var int v=1;
var int i;
loop i in [0->v[ do end
]],
    tight_ = 'line 3 : invalid tight `loop` :',
    --tight = 'line 2 : tight loop',
}

Test { [[
loop do
    loop do
        break;
    end
end
escape 1;
]],
    tight_ = 'line 1 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
var int i;
loop i in [0->1] do
    loop do
        break/i;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
var int i;
loop i in [0->1] do
    loop do
        break;
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
loop do
    par/and do
    with
    end
end
escape 1;
]],
    tight_ = 'line 1 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
loop do
    var int name = do
        await 1s;
        escape 1;
    end;
    if name == 1 then
        break;
    end
end
escape 1;
]],
    run = { ['~>1s']=1 },
}
Test { [[
loop do
    var int name = do
        escape 1;
    end;
    if name == 1 then
        break;
    end
end
escape 1;
]],
    tight_ = 'line 1 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}
-- INFINITE LOOP/EXECUTION
Test { [[
event none e; event none  f;
watching 1s do
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
end
escape 1;
]],
    wrn = true,
    _ana = {
        isForever = true,
        acc = 3,
    },
    awaits = 0,
    run = {['~>1s']=1},
}

Test { [[
event none e; event none  f;
watching 1s do
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
end
escape 1;
]],
    wrn = true,
    _ana = {
        isForever = true,
        acc = 3,
    },
    awaits = 0,
    run = {['~>1s']=1},
}

Test { [[
event none e; event none  f;
watching 1s do
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
end
escape 1;
]],
    wrn = true,
    _ana = {
        isForever = true,
        acc = 2,
    },
    awaits = 0,
    run = {['~>1s']=1},
}

Test { [[
event none e; event none  k1; event none  k2;
watching 1s do
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
end
escape 1;
]],
    wrn = true,
    _ana = {
        isForever = true,
        acc = 1,
    },
    awaits = 1,
    run = {['~>1s']=1},
}
Test { [[
event none e; event none  f;
watching 1s do
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
end
escape 1;
]],
    wrn = true,
    _ana = {
        isForever = true,
        acc = 3,
    },
    awaits = 0,
    run = {['~>1s']=1},
}

Test { [[
event none e; event none  f;
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
    wrn = true,
    _ana = {
        isForever = true,
        acc = 3,
    },
    awaits = 0,
    run = false,
}

Test { [[
event none e; event none  f;
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
    wrn = true,
    _ana = {
        isForever = true,
        acc = 2,
    },
    awaits = 0,
    run = false,
}

Test { [[
event none e; event none  k1; event none  k2;
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
    wrn = true,
    _ana = {
        isForever = true,
        acc = 1,
    },
    awaits = 1,
    run = false,
}
Test { [[
event none e;
loop do
    par/or do
        await e;
    with
        emit e;
        await FOREVER;
    end
end
]],
    wrn = true,
    _ana = {
        isForever = true,
        acc = true,
    },
    awaits = 1,
    run = false,
}
Test { [[
event none e;
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
    wrn = true,
    _ana = {
        isForever = true,
        acc = true,
    },
    awaits = 1,
    run = false,
}
Test { [[
var int ret = 0;
event none e;
par/or do
    every e do
        //await e;
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
    --run = 3;
    run = 6;
}

-->>> PAUSE

Test { [[
event bool a;
pause/if a do
end
escape 1;
]],
    _opts = { ceu_features_pause='true' },
    run = 1,
}

Test { [[
var bool a;
pause/if a do
end
escape 1;
]],
    _opts = { ceu_features_pause='true' },
    stmts = 'line 2 : invalid `pause/if` : unexpected context for variable "a"',
}

Test { [[
input none A;
pause/if A do
end
escape 0;
]],
    _opts = { ceu_features_pause='true' },
    stmts = 'line 2 : invalid `pause/if` : expected event of type `bool`',
}

Test { [[
input bool A;
pause/if A do
end
escape 1;
]],
    _opts = { ceu_features_pause='true' },
    run = 1,
}

Test { [[
event none a;
var int v = await a;
escape 0;
]],
    _opts = { ceu_features_pause='true' },
    --env = 'line 2 : event type must be numeric',
    --env = 'line 2 : invalid attribution',
    --env = 'line 2 : arity mismatch',
    stmts = 'line 2 : invalid assignment : types mismatch : "(int)" <= "()"',
    --env = 'line 2 : invalid attribution (int vs none)',
}

Test { [[
event none a;
pause/if a do
end
escape 0;
]],
    _opts = { ceu_features_pause='true' },
    stmts = 'line 2 : invalid `pause/if` : expected event of type `bool`',
    --env = 'line 2 : event type must be numeric',
    --env = 'line 2 : arity mismatch',
    --env = 'line 2 : invalid attribution',
    --env = 'line 2 : invalid attribution (bool vs none)',
}

Test { [[
input int A; input int  B;
event bool a;
par/or do
    loop do
        var int v = await A;
        emit a(v);
    end
with
    pause/if a do
        var int v = await B;
        escape v;
    end
end
]],
    _opts = { ceu_features_pause='true' },
    stmts = 'line 6 : invalid `emit` : types mismatch : "(bool)" <= "(int)"',
}

Test { [[
event bool a;
    pause/if a do
    end
]],
    props_ = 'line 2 : `pause/if` support is disabled',
}

Test { [[
input int A; input int  B;
event bool a;
par/or do
    loop do
        var int v = await A;
        emit a(v as bool);
    end
with
    pause/if a do
        var int v = await B;
        escape v;
    end
end
]],
    _opts = { ceu_features_pause='true' },
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

Test { [[
input bool A;
input int  B;
pause/if A do
    var int v = await B;
    escape v;
end
]],
    _opts = { ceu_features_pause='true' },
    _ana = {
        unreachs = 1,
    },
    run = {
        ['1~>B'] = 1,
        ['false~>A ; 1~>B'] = 1,
        ['true~>A ; 1~>B ; false~>A ; 3~>B'] = 3,
        ['true~>A ; true~>A ; 1~>B ; false~>A ; 3~>B'] = 3,
        ['true~>A ; 1~>B ; 1~>B ; false~>A ; 3~>B'] = 3,
        ['true~>A ; 1~>B ; false~>A ; true~>A ; 2~>B ; false~>A ; 3~>B'] = 3,
        ['true~>A ; 1~>B ; false~>A ; true~>A ; false~>A ; 3~>B'] = 3,
        ['true~>A ; 1~>B ; true~>A ; 2~>B ; false~>A ; 3~>B'] = 3,
    },
}

-- TODO: nesting with same event
Test { [[
input int A; input int B;
event bool a;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a(v);
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
    _opts = { ceu_features_pause='true' },
    stmts = 'line 7 : invalid `emit` : types mismatch : "(bool)" <= "(int)"',
}

Test { [[
input bool A;
input int  B;
var int ret = 0;
    pause/if A do
        pause/if A do
            ret = await B;
        end
    end
escape ret;
]],
    _opts = { ceu_features_pause='true' },
    run = {
        ['1~>B;1~>B'] = 1,
        ['false~>A ; 1~>B'] = 1,
        ['true~>A ; 1~>B ; false~>A ; false~>A ; 3~>B'] = 3,
        ['true~>A ; 1~>B ; false~>A ; true~>A ; 2~>B ; false~>A ; false~>A ; 3~>B'] = 3,
        ['true~>A ; 1~>B ; false~>A ; true~>A ; false~>A ; false~>A ; 3~>B'] = 3,
        ['true~>A ; 1~>B ; true~>A ; 2~>B ; false~>A ; false~>A ; 3~>B'] = 3,
    },
}

Test { [[
input int A; input int  B; input int  Z;
event bool a; event bool b;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a(v as bool);
    end
with
    loop do
        var int v = await B;
        emit b(v as bool);
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
    _opts = { ceu_features_pause='true' },
    run = {
        ['1~>Z'] = 1,
        ['1~>A ; 10~>Z ; 1~>B ; 10~>Z ; 0~>B ; 10~>Z ; 0~>A ; 5~>Z'] = 5,
        ['1~>A ; 1~>B ; 0~>B ; 10~>Z ; 0~>A ; 1~>B ; 5~>Z ; 0~>B ; 100~>Z'] = 100,
    },
}

Test { [[
input int  A;
input int  B;
input none Z;
event bool a;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a(v as bool);
    end
with
    pause/if a do
        await Z;
        ret = await B;
    end
end
escape ret;
]],
    _opts = { ceu_features_pause='true' },
    run = {
        ['~>Z ; 1~>B'] = 1,
        ['0~>A ; 1~>B ; ~>Z ; 2~>B'] = 2,
        ['~>Z ; 1~>A ; 1~>B ; 0~>A ; 3~>B'] = 3,
        ['~>Z ; 1~>A ; 1~>B ; 1~>A ; 2~>B ; 0~>A ; 3~>B'] = 3,
    },
}

Test { [[
input int  A;
input none Z;
event bool a;
var int ret = 0;
par/or do
    emit a(true);
    await A;
with
    pause/if a do
        do finalize with
            ret = 10;
    end
        await Z;
    end
end
escape ret;
]],
    _opts = { ceu_features_pause='true' },
    _ana = {
        acc = 1,
    },
    run = {
        ['1~>A'] = 10,
    },
}

Test { [[
input int  A;
event bool a;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a(v as bool);
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
    _opts = { ceu_features_pause='true' },
    _ana = {
        acc = 1,     -- TODO: 0
    },
    run = {
        ['1~>A ; ~>5s ; 0~>A ; ~>5s'] = 10,
    },
}

Test { [[
input int  A; input int B; input int C;
event bool a;
var int ret = 50;
par/or do
    loop do
        var int v = await A;
        emit a(v as bool);
    end
with
    pause/if a do
        ret = await B;
    end
with
    await C;
end
escape ret;
]],
    _opts = { ceu_features_pause='true' },
    run = {
        ['1~>A ; 10~>B ; 1~>C'] = 50,
    },
}

Test { [[
input none C;
par/or do
    await C;
with
    await 1us;
end
var int v = await 1us;
escape v;
]],
    run = { ['~>1us; ~>C; ~>4us; ~>C']=3 }
}

Test { [[
input int  A;
event bool a;
var int ret = 0;
par/or do
    loop do
        var int v = await A;
        emit a(v as bool);
    end
with
    pause/if a do
        ret = await 9us;
    end
end
escape ret;
]],
    _opts = { ceu_features_pause='true' },
    run = {
        ['~>1us;0~>A;~>1us;0~>A;~>19us'] = 12,
        --['~>1us;1~>A;~>1s;0~>A;~>19us'] = 11,
        --['~>1us;1~>A;~>5us;0~>A;~>5us;1~>A;~>5us;0~>A;~>9us'] = 6,
    },
}

Test { [[
event bool in_tm;
pause/if in_tm do
    await async do
var int i;
        loop i in [0 -> 5[ do
        end
    end
end
escape 1;
]],
    _opts = { ceu_features_pause='true' },
    run = 1,
}

Test { [[
event bool e;

par/or do
    par/and do
        pause/if e do
            await 1s;
        end
    with
        emit e(true);
    end
    escape -1;
with
    await 2s;
    escape 1;
end
]],
    _opts = { ceu_features_pause='true' },
    _ana = {acc=true},
    run = {['~>2s']=1},
}

Test { [[
event bool e;

par/or do
    par/and do
        pause/if e do
            await 1s;
        end
    with
        emit e(true);
        emit e(false);
    end
    escape -1;
with
    await 2s;
    escape 1;
end
]],
    _opts = { ceu_features_pause='true' },
    _ana = {acc=true},
    run = {['~>2s']=-1},
}

Test { [[
input int E;
event bool e;
var int ret = 0;
par/or do
    pause/if e do
        par do
            every 1s do
                ret = ret + 1;
            end
        with
            loop do
                await pause;
                ret = ret + 1;
                await resume;
                ret = ret + 2;
            end
        end
    end
with
    var int v;
    every v in E do
        emit e(v as bool);
    end
with
    await async do
        emit 10s;       // 10
        emit E(0);      // 10
        emit 10s;       // 20
        emit E(1);      // 21
        emit 10s;       // 21
        emit E(1);      // 21
        emit E(1);      // 21
        emit E(0);      // 23
        emit E(0);      // 23
        emit 10s;       // 33
        emit E(1);      // 34
        emit E(0);      // 36
        emit 10s;       // 46
    end
end
escape ret;
]],
    _opts = { ceu_features_pause='true' },
    wrn = true,
    run = 46,
}

Test { [[
input int E;
event bool e;
var int ret = 0;
par/or do
    pause/if e do
        par do
            every 1s do
                ret = ret + 1;
            end
        with
            do finalize with
                nothing;
            pause with
                ret = ret + 1;
            resume with
                ret = ret + 2;
            end
            await FOREVER;
        end
    end
with
    var int v;
    every v in E do
        emit e(v as bool);
    end
with
    await async do
        emit 10s;       // 10
        emit E(0);      // 10
        emit 10s;       // 20
        emit E(1);      // 21
        emit 10s;       // 21
        emit E(1);      // 21
        emit E(1);      // 21
        emit E(0);      // 23
        emit E(0);      // 23
        emit 10s;       // 33
        emit E(1);      // 34
        emit E(0);      // 36
        emit 10s;       // 46
    end
end
escape ret;
]],
    _opts = { ceu_features_pause='true' },
    -- todo: this examples uses trails[4], trails[6], but not trails[5]
    wrn = true,
    run = 46,
}

--<<< PAUSE

-->>> VECTORS / STRINGS

Test { [[
var u8 v;
escape ($$v) as int;
]],
    dcls = 'line 2 : invalid operand to `$$` : unexpected context for variable "v"',
    --env = 'line 2 : invalid operand to unary "$$" : vector expected',
}
Test { [[
var u8 v;
escape ($v) as int;
]],
    dcls = 'line 2 : invalid operand to `$` : unexpected context for variable "v"',
}

Test { [[
var[10] u8 vec;
escape ($$vec + $vec) as int;
]],
    run = 10,
}

Test { [[
var[] u8 vec;
escape ($$vec + $vec + 1) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
var[] int c;
escape [];
]],
    parser = 'line 2 : after `escape` : expected expression',
    --env = 'line 2 : invalid attribution : destination is not a vector',
    --env = 'line 2 : types mismatch (`int` <= `any[]`)',
}

Test { [[
var[] int c;
escape [1]..[]..c;
]],
    parser = 'line 2 : after `escape` : expected expression',
    --env = 'line 2 : invalid attribution : destination is not a vector',
    --env = 'line 2 : types mismatch (`int` <= `int[]`)',
}

Test { [[
var[10] u8 vec = [ [1,2,3] ];
escape 1;
]],
    parser = 'line 1 : after `[` : expected `]`',
    --parser = 'line 1 : after `[` : expected `]`',
    --env = 'line 1 : wrong argument #1 : arity mismatch',
    --env = 'line 1 : types mismatch (`u8[]` <= `int[][]`)',
    --env = 'line 1 : wrong argument #1 : types mismatch (`u8` <= `int[]..`)',
}
Test { [[
var[10] u8 vec = (1,2,3);
escape 1;
]],
    --parser = 'line 1 : after `1` : expected `[` or `:` or `.` or `!` or `?` or `is` or `as` or binary operator',
    parser = 'line 1 : after `1` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `)` or `..`',
}
Test { [[
var[10] u8 vec = (1);
escape 1;
]],
    --env = 'line 1 : types mismatch (`u8[]` <= `int`)',
    stmts = 'line 1 : invalid assignment : unexpected context for vector "vec"',
}
Test { [[
native _int;
var[1] _int&& vec = [];
escape 1;
]],
    stmts = 'line 2 : invalid constructor : expected internal type : got "_int&&"',
}

Test { [[
native _int;
var[1] _int vec = [];
escape 1;
]],
    stmts = 'line 2 : invalid constructor : expected internal type : got "_int"',
}

Test { [[
event none e;
var[10] u8 vec = [ e ];
escape 1;
]],
    stmts = 'line 2 : invalid expression list : item #1 : unexpected context for event "e"',
}

Test { [[
var int x;
var[10] u8 vec = [ &&x ];
escape 1;
]],
    --env = 'line 2 : wrong argument #1 : types mismatch (`u8` <= `int&&`)',
    stmts = 'line 2 : invalid constructor : item #1 : invalid expression list : item #1 : types mismatch : "u8" <= "int&&"',
}

Test { [[
var[] int v = [] ..;
escape 1;
]],
    --parser = 'line 1 : after `..` : expected item',
    --parser = 'line 1 : after `..` : invalid constructor syntax',
    parser = 'line 1 : after `..` : expected expression or `[`',
}

Test { [[
var[] int&& v1;
var[] int  v2 = []..v1;
escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 2 : invalid constructor : item #2 : types mismatch : "int" <= "int&&"',
    --env = 'line 2 : wrong argument #2 : types mismatch (`int` <= `int&&`)',
}

Test { [[
var[10] u8 vec = [1,2,3];
escape $$vec + $vec + vec[0] + vec[1] + vec[2];
]],
    dcls = 'line 2 : invalid operands to `+` : incompatible numeric types : "usize" vs "u8"',
}
Test { [[
var[10] u8 vec = [1,2,3];
escape ((($$vec) as int) + (($vec) as int) + vec[0] + vec[1] + vec[2]) as int;
]],
    run = 19,
}

Test { [[
var[10] u8 vec = [1,2,3];
vec[0] = 4;
vec[1] = 5;
vec[2] = 6;
escape ((($$vec) as int) + (($vec )as int) + vec[0] + vec[1] + vec[2]) as int;
]],
    run = 28,
}

Test { [[
var[10] int vec = [1,2,3];
vec[0] = 4;
vec[1] = 5;
vec[2] = 6;
escape (($$vec )as int) + (($vec) as int) + vec[0] + vec[1] + vec[2];
]],
    run = 28,
}

Test { [[
var[10] u8 vec;
vec[0] = 1;
escape 1;
]],
    run = '2] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var[10] u8 vec;
escape vec[0] as int;
]],
    run = '2] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var[] int vec = [1];
escape vec[0];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
var[] u8 vec = [1,2,3];
escape ((($$vec) as int) + (($vec) as int) + vec[0] + vec[1] + vec[2]) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 12,
    --run = 6,
}

Test { [[
var[10] u8 vec = [1,2,3];
$$vec = 0;
escape vec[0] as int;
]],
    parser = 'line 2 : after `vec` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `;`',
    --parser = 'line 1 : after `;` : expected statement',
    --env = 'line 2 : invalid attribution',
}
Test { [[
var[10] u8 vec = [1,2,3];
$vec = 0;
escape vec[0] as int;
]],
    run = '3] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var[2] int vec;
$vec = 1;
escape 1;
]],
    run = '2] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var[] byte bs;
native/nohold _ceu_vector_setlen;
_ceu_vector_setlen(&&bs,1,0);
escape 1 + (($bs) as int);
]],
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true' },
    run = '3] -> runtime error: access out of bounds',
}

Test { [[
native/nohold _ceu_vector_setlen;
var[] byte bs;
_ceu_vector_setlen(&&bs, 1, 1);
_ceu_vector_setlen(&&bs, 1, 0);
escape 1 + (($bs) as int);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 2,
}

Test { [[
native/nohold _ceu_vector_setlen;
var[10] byte bs;
_ceu_vector_setlen(&&bs, 10, 1);
escape ($bs) as int;
]],
    run = 10,
}

Test { [[
native/nohold _ceu_vector_setlen;
var[10] byte bs;
_ceu_vector_setlen(&&bs, 11, 1);
escape 0;
]],
    run = '3] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var[10] u8 v1 = [1,2,3];
var[20] u8 v2 = v1;
escape v2[0] + v2[1] + v2[2];
]],
    stmts = 'line 2 : invalid assignment : unexpected context for vector "v2"',
    --env = 'line 2 : types mismatch (`u8[]` <= `u8[]`)',
}

Test { [[
var[] byte v1; var[] byte v2; var[] byte v3;
v1 = v2;
v1 = v2..v3;
escape $v1+1;
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 2 : invalid assignment : unexpected context for vector "v1"',
    --parser = 'line 3 : after `v2` : expected `[` or `:` or `!` or `(` or `?` or `is` or `as` or binary operator or `;`',
    --parser = 'line 3 : after `v2` : expected `[` or `:` or `!` or `(` or `?` or binary operator or `is` or `as` or `;`',
}

Test { [[
var[10] u8 v1 = [1,2,3];
v1 = v1 .. [4];
escape v1[3] as int;
]],
    run = 4,
}

Test { [[
var[10] u8 v1 = [1,2,3];
v1 = v1..v1;    // only first can be v1
escape v1[3];
]],
    stmts = 'line 2 : invalid constructor : item #2 : unexpected destination as source',
}

Test { [[
var[10] u8 v1 = [1,2,3];
v1 = v1;    // not a vector constructor
escape v1[3];
]],
    stmts = 'line 2 : invalid assignment : unexpected context for vector "v1"',
}

Test { [[
var[10] u8 v1 = [1,2,3];
v1 = []..v1;    // cant concat itself
escape v1[3];
]],
    stmts = 'line 2 : invalid constructor : item #2 : unexpected destination as source',
}

Test { [[
var[10] u8 v1 = [1,2,3];
var[20] u8 v2 = []..v1;
escape (v2[0] + v2[1] + v2[2]) as int;
]],
    run = 6,
}
Test { [[
var[20] u8 v1 = [1,2,3];
var[10] u8 v2 = []..v1;
escape (v2[0] + v2[1] + v2[2]) as int;
]],
    run = 6,
}
Test { [[
var[] u8 v1   = [1,2,3];
var[10] u8 v2 = []..v1;
escape (v2[0] + v2[1] + v2[2]) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 6,
}
Test { [[
var[10] byte v1 = [1,2,3];
var[] byte   v2 = []..v1;
escape v2[0] + v2[1] + v2[2];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 6,
}
Test { [[
var[3] byte v1 = [1,2,3];
var[2] byte v2 = []..v1;
escape v2[0] + v2[1] + v2[2];
]],
    run = '2] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var[2] int v ;
escape v == &&v[0] ;
]],
    --dcls = 'line 2 : invalid operand to `==` : expected the same type',
    --env = 'line 2 : invalid operand to unary "&&" : vector elements are not addressable',
    --dcls = 'line 2 : invalid expression : operand to `&&` must be a name',
    dcls = 'line 2 : invalid operand to `==` : unexpected context for vector "v"',
}

Test { [[
var[2] int a = [1,2];
escape a[0];
]],
    run = 1,
}

Test { [[
native/nohold _f;
native/pos do
    none f (int* v) {
        v[0]++;
        v[1]++;
    }
end
var[2] int a = [1,2];
native _int;
_f((&&a[0]) as _int&&);
escape a[0] + a[1];
]],
    run = 5,
}

Test { [[
var[5] byte foo = [1, 2, 3, 4, 5];
var int tot = 0;
var int i;
loop i in [0 -> ($foo) as int[ do
    tot = tot + foo[i];
end
escape tot;
]],
    tight_ = 'line 4 : invalid tight `loop` : unbounded number of non-awaiting iterations',
    --tight = 'line 3 : tight loop',
}
Test { [[
var[5] byte foo = [1, 2, 3, 4, 5];
var int tot = 0;
var int i;
loop i in [0 -> ($foo) as int[ do
    tot = tot + foo[i];
end
escape tot;
]],
    loop = true,
    wrn = true,
    run = 15,
}

Test { [[
var[5] byte foo = [1, 2, 3, 4, 5];
var int tot = 0;
var int i;
loop i in [0 -> ($$foo) as int[ do
    tot = tot + foo[i];
end
escape tot;
]],
    run = 15,
}

Test { [[
var[] byte foo = [1, 2, 3, 4, 5];
var int tot = 0;
var int i;
loop i in [0 -> ($$foo) as int[ do
    tot = tot + foo[i];
end
escape tot+1;
]],
    _opts = { ceu_features_dynamic='true' },
    tight_ = 'line 4 : invalid tight `loop` : unbounded number of non-awaiting iterations',
}

Test { [[
var[] byte foo = [1, 2, 3, 4, 5];
var int tot = 0;
var int i;
loop i in [0 -> ($$foo) as int[ do
    tot = tot + foo[i];
end
escape tot+1;
]],
    _opts = { ceu_features_dynamic='true' },
    wrn = true,
    --run = 1,
    run = 16,
}

Test { [[
escape 1..2;
]],
    --parser = 'line 1 : after `..` : invalid constructor syntax',
    --parser = 'line 1 : after `1` : expected `[` or `:` or `!` or `?` or `is` or `as` or binary operator or `;`',
    parser = 'line 1 : after `1` : expected `[` or `:` or `!` or `?` or `(` or `is` or `as` or binary operator or `;`',
}
Test { [[
escape 1 .. 2;
]],
    --parser = 'line 1 : after `..` : invalid constructor syntax',
    --parser = 'line 1 : after `1` : expected `;`',
    --parser = 'line 1 : after `1` : expected `[` or `:` or `!` or `?` or `is` or `as` or binary operator or `;`',
    parser = 'line 1 : after `1` : expected `[` or `:` or `!` or `?` or `(` or `is` or `as` or binary operator or `;`',
}
Test { [[
var[] int x = [1]..2;
escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 1 : invalid constructor : unexpected context for value "2"',
    --stmts = 'line 1 : invalid constructor : expected location',
    --env = 'line 1 : wrong argument #2 : source is not a vector',
}

Test { [[
escape [1]..[2];
]],
    parser = 'line 1 : after `escape` : expected expression',
    --env = 'line 1 : invalid attribution : destination is not a vector',
}

Test { [[
escape [1]..[&&this];
]],
    --env = 'line 1 : invalid attribution : destination is not a vector',
    parser = 'line 1 : after `escape` : expected expression',
}

Test { [[
var[] int v1;
var[] int v2;
v1 = [1] .. v2;
v1 = [] .. v2 .. [1];
escape v1[0];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1;
}

Test { [[
var[] int v1 = [1]..[2]..[3];
escape v1[0]+v1[1]+v1[2];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 6;
}

Test { [[
var[9] int v1 = [1,2,3];
var[9] int v2 = [7,8,9];
v1 = v1 .. [4,5,6] .. v2;
var int ret = 0;
var int i;
loop i in [0 -> 9[ do
    ret = ret + v1[i];
    //{printf("%d = %d\n", @i, @v1[i]);}
end
escape ret;
]],
    run = 45;
    _opts = { ceu_features_trace='true' },
}

Test { [[
var[] int v1 = [1,2,3];
var[] int v2 = [7,8,9];
v1 = v1 .. [4,5,6] .. v2;
var int ret = 0;
var int i;
loop i in [0 -> 9[ do
    ret = ret + v1[i];
end
escape ret;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 45;
}

Test { [[
var[] int v = [1,2,3];
v = v .. v;
escape ($v + v[5]) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 2 : invalid constructor : item #2 : unexpected destination as source',
    --run = 9,
}

Test { [[
var[] int v = [1,2,3];
v = [1] .. v;
escape ($v + v[1]) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 2 : invalid constructor : item #2 : unexpected destination as source',
    --run = 3,
}

Test { [[
var[] int v = [1,2,3];
var[] int v1 = []..v;
v = [1] .. v1;
escape ($v + v[1]) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 5,
    --run = 3,
}

Test { [[
var[] int v;
$v = 0;
escape ($v + 1) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
var [] int vec = [1,2,3];
var int ret = 0;
var usize i;
loop i in [0 -> $vec[ do
    ret = ret + vec[i];
    if i == 1 then
        break;
    end
end
escape ret;
]],
    _opts = { ceu_features_dynamic='true' },
    wrn = true,
    run = 3,
}

Test { [[
every 1s do
    var[] byte xxx = [];
end
escape 0;
]],
    _opts = { ceu_features_dynamic='true' },
    run = false,
}

-->> VECTOR / _CHAR*

Test { [[
native/pos do
    char* f (none) {
        return "ola";
    }
    typedef struct {
        char* (*f) (none);
    } tp;
    tp Tx = { f };
end
var[] byte str = [] .. "oi";
escape (str[1]=={'i'}) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
native/pos do
    char* f (none) {
        return "ola";
    }
    typedef struct {
        char* (*f) (none);
    } tp;
    tp Tx = { f };
end
native _char, _Tx;
var[] byte str = [] .. (_Tx.f() as _char&&);
escape (str[2]=={'a'}) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
native/pos do
    char* f (none) {
        return "ola";
    }
    typedef struct {
        char* (*f) (none);
    } tp;
    tp Tx = { f };
end
native _char, _Tx;
var[] byte str = [] .. (_Tx.f() as _char&&) .. "oi";
escape (str[5]=={'i'}) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
native/pos do
    char* f (none) {
        return "ola";
    }
    typedef struct {
        char* (*f) (none);
    } tp;
    tp Tx = { f };
end
native _char, _Tx;
var[] byte str = [] .. (_Tx.f() as _char&&);
$str = $str - 1;
str = str .. "oi";
escape (str[4]=={'i'}) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[var[2] u8 v; escape (&&v==&&v) as int;]],
    _opts = { cc_args='-DCEU_TESTS' },
    run = 1,
    --dcls = 'line 1 : invalid operand to `&&` : unexpected context for vector "v"',
    --env = 'line 1 : types mismatch (`int` <= `u8[]&&`)',
    --env = 'invalid operand to unary "&&"',
}

-- TODO: dropped support for returning alias, is this a problem?

Test { [[
native/pos do
    ##define ID(x) x
end
native/pure _ID, _strlen;
native _char;
var[] byte str = [] .. "abc";
$str = $str - 1;
str = str .. (_ID("def") as _char&&);
var byte&& str2 = _ID((&&str[0]));
escape _strlen((&&str[0]) as _char&&) + _strlen(str2 as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 12,
}

Test { [[
var[] byte str;
var[] byte str;
escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    wrn = true,
    run = 1,
}

Test { [[
var[] int x;
escape (&&x[0] == &&x[0]) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
var[] byte str1;
escape (&&str1[0] == &&str1[0]) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
    --run = '2] -> runtime error: access out of bounds',
}

Test { [[
var[] byte str1 = [].."";
escape (&&str1[0] == &&str1[0]) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
    --run = '2] -> runtime error: access out of bounds',
}

Test { [[
native/pure _strcmp;
var[] byte str1 = [].."";
var[] byte str2 = [].."";
native _char;
escape (_strcmp((&&str1[0]) as _char&&,"")==0 and _strcmp((&&str2[0]) as _char&&,"")==0) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
native/pure _strcmp;
var[0] byte str1;
var[1] byte str2;
native _char;
escape (_strcmp((&&str1[0]) as _char&&,"")==0 and _strcmp((&&str2[0]) as _char&&,"")==0) as int;
]],
    run = 1,
    --run = '5] -> runtime error: access out of bounds',
}

Test { [[
native/pure _strcmp;
var[] byte str1 = [0];
var[] byte str2 = [0];
native _char;
escape (_strcmp((&&str1[0]) as _char&&,"")==0 and _strcmp((&&str2[0]) as _char&&,"")==0) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
var[] u8 str = [].."Ola Mundo!";
]],
    _opts = { ceu_features_dynamic='true' },
    --stmts = 'line 1 : invalid constructor : item #2 : types mismatch : "u8" <= "byte"',
    stmts = 'line 1 : invalid constructor : unexpected context for value ""Ola Mundo!""',
}

Test { [[
var[3] u8 bytes;

bytes = bytes .. [5];

escape bytes[0] as int;
]],
    run = 5,
}

Test { [[
native/nohold _ceu_vector_buf_set;
var[] byte v = [1,2,0,4,5];
var byte c = 3;
_ceu_vector_buf_set(&&v,2, &&c, 1);
escape v[2] + (($v) as int);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 8,
}

Test { [[
var[] int v;
escape v > 0;
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 2 : invalid operand to `>` : unexpected context for vector "v"',
}
Test { [[
var[] int v;
escape v?;
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 2 : invalid operand to `?` : unexpected context for vector "v"',
}
Test { [[
var[] int v;
escape v!;
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 2 : invalid operand to `!` : unexpected context for vector "v"',
}
Test { [[
var[] int v;
escape ~v;
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 2 : invalid operand to `~` : unexpected context for vector "v"',
}

Test { [[
var[] int v;
v[true] = 1;
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 2 : invalid index : expected integer type',
}

Test { [[
var int[1][1] v;
escape 1;
]],
    --adj = 'line 1 : not implemented : multiple `[]`',
    --env = 'line 1 : invalid type modifier : `[][]`',
    --parser = 'line 1 : after `var` : expected `&` or `[`',
    parser = 'line 1 : after `int` : expected type modifier or internal identifier',
}
Test { [[
var[1][1] int v;
escape 1;
]],
    --adj = 'line 1 : not implemented : multiple `[]`',
    --env = 'line 1 : invalid type modifier : `[][]`',
    --parser = 'line 1 : after `]` : expected type',
    parser = 'line 1 : after `]` : expected `/dynamic` or `/nohold` or type',
}

Test { [[
var[2] int v;
v[0] = 1;
var int ret=0;
par/or do
    ret = v[0];
with
    ret = v[1];
end;
escape ret;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 3,
    },
}

Test { [[
var[] int v;
escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    wrn = true,
    run = 1,
}

Test { [[
native _enqueue;
var[255] byte buf;
_enqueue(&&buf[0]);
escape 1;
]],
    scopes = 'line 3 : invalid `call` : expected `finalize` for variable "buf"',
    --fin = 'line 2 : call requires `finalize`',
}

Test { [[
native _enqueue;
var[255] byte buf;
_enqueue(buf);
escape 1;
]],
    stmts = 'line 3 : invalid expression list : item #1 : unexpected context for vector "buf"',
    --env = 'line 2 : wrong argument #1 : cannot pass plain vectors to native calls',
    --fin = 'line 2 : call requires `finalize`',
}
Test { [[
native/pure _enqueue;
native/pos do
    ##define enqueue(x)
end
var[255] byte buf;
_enqueue(&&buf);
escape 1;
]],
    run = 1,
    --dcls = 'line 3 : invalid operand to `&&` : unexpected context for vector "buf"',
    --fin = 'line 2 : call requires `finalize`',
}

Test { [[
native/pure _strlen;

native _char;
var[255] _char str;
str = [].."oioioi";

escape _strlen(&&str[0]);
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 5 : invalid constructor : unexpected context for value ""oioioi""',
    --stmts = 'line 5 : invalid constructor : expected internal type : got "_char"',
    --dcls = 'line 5 : invalid use of `vector` "str"',
    --cc = '4:34: error: assignment to expression with array type',
}

Test { [[
var byte b = 1;
var byte c = 2;
b = (c as byte);
escape b;
]],
    run = 2,
}
Test { [[
var int i = do/_
    var[5] byte abcd;
    escape 1;
end;
escape i;
]],
    wrn = true,
    run = 1,
}

Test { [[var[0] int v; escape 0;]],
    wrn = true,
    run = 0,
    --env='invalid dimension'
}

Test { [[
var[255] u8 vec;
event none  e;
escape 1;
]],
    wrn = true,
    --mem = 'too many events',    -- TODO
    run = 1,
}

Test { [[
var[] byte str = [] .. (1 as int);
escape $str as int;
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 1 : invalid constructor : item #2 : expected "_char&&"',
}

Test { [[
code/tight Ff (none) -> _char&& do
    escape "oi";
end
var[] byte str = [] .. (call Ff());
escape $str as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 3,
}
Test { [[
code/tight Ff (none) -> bool do
    escape true;
end
var[] byte str = [] .. (call Ff());
escape $str as int;
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 4 : invalid constructor : item #2 : expected "_char&&"',
}

--<< VECTORS

-- STRINGS

Test { [[
native/nohold _strlen;
var[] byte v = [{'a'},{'b'},{'c'},{'\0'}];
native _char;
escape _strlen((&&v[0]) as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 3,
}
Test { [[
native/nohold _strlen;
var[] byte v = [{'a'},{'b'},{'c'},{'\0'}];
native _char;
escape _strlen((&&v[0]) as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 3,
}

Test { [[
native/pure _strlen;
native/nohold _garbage;
native/pos do
    none garbage (byte* v) {
        int i = 0;
        for (; i<11; i++) {
            v[i] = i;
        }
    }
end

var[10] byte v = [0];
native _char;
_garbage((&&v[0]));
v = [{'a'},{'b'},{'c'},{'\0'}];
escape _strlen((&&v[0]) as _char&&);
]],
    wrn = true,
    run = 3,
}

Test { [[
_f([1]);
escape 1;
]],
    --env = 'line 1 : wrong argument #1 : cannot pass plain vectors to native calls',
    --parser = 'line 1 : after `(` : expected `)`',
    parser = 'line 1 : after `(` : expected expression',
    --run = 1,
}
Test { [[
_f([1]..[2]);
escape 1;
]],
    --env = 'line 1 : wrong argument #1 : cannot pass plain vectors to native calls',
    --parser = 'line 1 : after `(` : expected `)`',
    parser = 'line 1 : after `(` : expected expression',
    --run = 1,
}
Test { [[
var[] int v;
_f([1]..v);
escape 1;
]],
    --env = 'line 2 : wrong argument #1 : cannot pass plain vectors to native calls',
    parser = 'line 2 : after `(` : expected expression',
    --parser = 'line 2 : after `(` : expected `)`',
    --run = 1,
}
Test { [[
var[] int v;
_f(v..[1]);
escape 1;
]],
    --parser = 'line 2 : after `..` : invalid constructor syntax',
    parser = 'line 2 : after `v` : expected `[` or `:` or `!` or `?` or `(` or `is` or `as` or binary operator or `,` or `)`',
    --run = 1,
}

Test { [[
native/nohold _strlen;
var[] byte v = [].."abc";
native _char;
escape _strlen(v as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 4 : invalid operand to `as` : unexpected context for vector "v"',
    --env = 'line 2 : types mismatch (`byte[]` <= `_char&&`)',
    --run = 3,
}
Test { [[
native/nohold _strlen;
var[] byte v = [].."abc";
native _char;
escape _strlen((&&v[0]) as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 3,
}
Test { [[
native/nohold _strlen;
var[] byte v = [].."abc";
$v = $v - 1;
v = v .. "def";
native _char;
escape _strlen((&&v[0]) as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 6,
}

Test { [[
var int nnn = 10;
var[nnn] u8 xxx;
xxx[0] = 10;
escape 1;
]],
    run = ':3] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int nnn = 10;
var[nnn] byte xxx;
native/nohold _ceu_vector_setlen;
_ceu_vector_setlen(&&xxx,nnn,1);
xxx[0] = 10;
xxx[9] = 1;
escape xxx[0]+xxx[9];
]],
    run = 11,
}

Test { [[
var int nnn = 10;
var[nnn] byte xxx;
native/nohold _ceu_vector_setlen;
_ceu_vector_setlen(&&xxx,nnn+1,1);
escape 1;
]],
    run = '4] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int n = 10;
var[n] byte us;
$us = 20;
escape 1;
]],
    run = ':3] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int n = 10;
var[n] byte us;
native/nohold _ceu_vector_setlen;
_ceu_vector_setlen(&&us,n,1);
escape $us as int;
]],
    run = 10,
}

Test { [[
var int n = 10;
var[] byte us;
$us = n;
escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true' },
    run = ':3] -> runtime error: access out of bounds',
}

Test { [[
var int n = 10;
var[] byte us;
native/nohold _ceu_vector_setlen;
_ceu_vector_setlen(&&us,n,1);
escape $us as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 10,
}

Test { [[
var int n = 10;
var[n] byte us = [0,1,2,3,4,5,6,7,8,9];
us[n] = 10;
escape us[0]+us[9];
]],
    run = ':3] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
native _CEU_APP;
var int n = 10;
var[n] byte us = [0,1,2,3,4,5,6,7,8,9];
us[n-1] = 1;
escape _CEU_APP.root.__mem.trails_n;
]],
    run = 3,
}
Test { [[
native _CEU_APP;
var int n = 10;
var[10] byte us = [0,1,2,3,4,5,6,7,8,9];
us[n-1] = 1;
escape _CEU_APP.root.__mem.trails_n;
]],
    run = 1,
}

Test { [[
var int n = 10;
var[n] byte us = [0,1,2,3,4,5,6,7,8,9];
us[n-1] = 1;
escape us[0]+us[9];
]],
    run = 1,
}


Test { [[
var[1.5] u8 us = [];
]],
    consts = 'line 1 : invalid declaration : vector dimension must be an integer',
    --env = 'line 2 : dimension must be constant',
}

Test { [[
native _u8;
native/const _U8_MAX;
var[_U8_MAX] _u8 us = _;
escape 1;
]],
    wrn = true,
    run = 1,
    --env = 'line 2 : dimension must be constant',
}

Test { [[
native _u8;
native/const _U8_MAX;
var int n = 10;
var[_U8_MAX] _u8 us = _;
us[_U8_MAX-1] = 10;
us[0] = 1;
escape (us[0]+us[_U8_MAX-1]) as int;
]],
    wrn = true,
    run = 11,
}

Test { [[
native _u8;
native/const _U8_MAX;
var int n = 10;
var[_U8_MAX] u8 us = _;
us[_U8_MAX-1] = 10;
us[0] = 1;
escape (us[0]+us[_U8_MAX-1]) as int;
]],
    wrn = true,
    run = '5] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
native _t_vec;
native/pre do
    typedef int t_vec[10];
end
var _t_vec us = _;
us[9] = 10;
us[0] =  1;
escape us[0]+us[9];
]],
    wrn = true,
    run = 11,
}

Test { [[
native _u8;
native/const _N;
native/pre do
    int N = 10;
end
var[_N] _u8 xxx = _;
escape 1;
]],
    wrn = true,
    cc = '6:5: error: variably modified ‘xxx',
}

Test { [[
#define HASH_BYTES 32
var[HASH_BYTES+sizeof(u32)] byte bs;
escape ($$bs) as int;
]],
    opts_pre = true,
    run = 36,
}

Test { [[
var int n = 32;
var[n] byte bs;
escape ($$bs) as int;
]],
    run = 32,
}

Test { [=[
var int r1 = [1,2,3];
escape 1;
]=],
    stmts = 'line 1 : invalid constructor : unexpected context for variable "r1"',
}

Test { [[
native _char;
var[10] _char a;
a = [].."oioioi";
escape 1;
]],
    stmts = 'line 3 : invalid constructor : unexpected context for value ""oioioi""',
    --stmts = 'line 3 : invalid constructor : expected internal type : got "_char"',
    --cc = '2:32: error: assignment to expression with array type',
    --env = 'line 2 : types mismatch (`_char[]` <= `_char&&`)',
    --env = 'line 2 : invalid attribution',
}

Test { [[
var[2] int v;
par/or do
    v[0] = 1;
with
    v[1] = 2;
end;
escape 0;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 1,
    },
}
Test { [[
var[2] int v;
var int i=0; var int j=0;
par/or do
    v[j] = 1;
with
    v[i+1] = 2;
end;
escape 0;
]],
    run = false,
    _ana = {
        acc = 1,
        abrt = 1,
    },
}

Test { [[
var[10] byte v2 = [];
if false then
    escape 1;
end
escape v2[0][0];
]],
    dcls = 'line 5 : invalid vector : unexpected context for variable "v2"',
    --dcls = 'line 5 : invalid vector : expected location',
}

Test { [[
var[10] byte v2 = [45];

var int ret = (v2[0] as int);

escape ret;
]],
    --loop = 1,
    run = 45,
}

Test { [[
native/plain _char;
native/plain _u8;
var[10] _u8 v1 = _;
var[10] byte v2 = [];

var int i;
loop i in [0 -> 10[ do
    v1[i] = i;
    v2 = v2..[((i*2) as byte)];
end

var int ret = 0;
var int i;
loop i in [0 -> 10[ do
    ret = ret + (v2[i] as int) - v1[i];
end

escape ret;
]],
    wrn = true,
    --loop = 1,
    run = 45,
}

Test { [[
var u8 cnt;
var[3] u8 v;

v = [] .. v .. [17];
v = [] .. v .. [9];

cnt = #v;
_printf("oi\n");
escape cnt;
]],
    parser = 'line 7 : after `=` : expected expression',
}

Test { [[
#define _OBJ_N + 2
var[_OBJ_N] none&& objs;
escape 1;
]],
    opts_pre = true,
    wrn = true,
    run = 1,
}

Test { [[
#define _OBJ_N + 2 \
               + 1
var[_OBJ_N] none&& objs;
escape 1;
]],
    opts_pre = true,
    wrn = true,
    run = 1,
}

Test { [[
var int i;
loop i in [0 -> 10[ do
    await 1s;
    var[] byte string = [] .. "Alo mundo!\n";
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    run = { ['~>20s']=1 },
}

Test { [[
native/pre do
    typedef char* char_ptr;
end
native _char_ptr, _char;
native/pure _strlen;
var _char_ptr x = "oioi";
var _char&& y = x;
var[] byte str = [] .. (x as _char&&);
$str = $str - 1;
str = str .. (y as _char&&);
escape _strlen(&&str[0] as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 8,
}

Test { [[
native/pre do
    ##define ID(x) x
    typedef char* char_ptr;
end
native/pure _ID, _strlen;
native _char_ptr, _char;
var _char_ptr x = "oioi";
var _char&& y = x;
var[] byte str = [] .. (_ID(x) as _char&&);
$str = $str - 1;
str = str .. (_ID(y) as _char&&);
escape _strlen(&&str[0] as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 8,
}

-->> VECTOR / ALIAS

Test { [[
var[10] u8 v1 = [1,2,3];
var&[10] u8 v2 = &v1;
v1 = v2..[];    // v1=v2 must be the same
escape 0;
]],
    stmts = 'line 3 : invalid constructor : item #1 : expected destination as source',
}

Test { [[
var[10] u8 v1 = [1,2,3];
var&[10] u8 v2 = &v1;
v1 = []..v2;    // v1=v2 same address
escape 0;
]],
    run = '3] -> runtime error: source is the same as destination',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var[10] byte vec = [1,2,3];
var&[] byte  ref = &vec;
escape (($$ref) as int) + (($ref) as int) + ref[0] + ref[1] + ref[2];
]],
    run = 19,
}

Test { [[
var int n = 10;
var[n] byte vec = [1,2,3];
var&[] byte ref = &vec;
escape ($ref + $$ref) as int;
]],
    run = 13,
}
Test { [[
var int n = 10;
var[n] byte vec = [1,2,3];
var&[n] byte ref = &vec;
]],
    consts = 'line 3 : invalid declaration : vector dimension must be an integer constant',
}

Test { [[
var int n = 10;
var[] byte vec = [1,2,3];
var&[n] byte ref = &vec;
]],
    _opts = { ceu_features_dynamic='true' },
    consts = 'line 3 : invalid declaration : vector dimension must be an integer constant',
}

Test { [[
var[10] byte  vec = [1,2,3];
var&[11] byte ref = &vec;
escape( ($$ref) as int) + (($ref) as int) + ref[0] + ref[1] + ref[2];
]],
    run = 1,
    stmts = 'line 2 : invalid binding : dimension mismatch',
    --env = 'line 2 : types mismatch (`u8[]&` <= `u8[]&`) : dimension mismatch',
}

Test { [[
var[10] byte vec = [1,2,3];
var&[9] byte ref = &vec;
escape (($$ref) as int) + (($ref) as int) + ref[0] + ref[1] + ref[2];
]],
    stmts = 'line 2 : invalid binding : dimension mismatch',
    --env = 'line 2 : types mismatch (`u8[]&` <= `u8[]&`) : dimension mismatch',
}

Test { [[
native/nohold _f;
native/pos do
    none f (int* v) {
        v[0]++;
        v[1]++;
    }
end
var[2] int a  = [1,2];
var&[2] int b = &a;
native _int;
_f((&&b[0]) as _int&&);
escape b[0] + b[1];
]],
    run = 5,
}

Test { [[
var[] byte bs = [ 1, 2, 3 ];
var int idx = 1;
var& int i = &idx;
escape bs[i];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 2,
}

Test { [[
native/pos do
    byte* f (none) {
        return (byte*)"ola";
    }
end
var[] byte  str;
var&[] byte ref = &str;
native _char;
ref = [] .. ({f}() as _char&&);
$ref = $ref - 1;
ref = ref .. "oi";
native/pure _strlen;
escape _strlen((&&str[0]) as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 5,
}

Test { [[
native/nohold _f;
native/pos do
    none f (int* v) {
        v[0]++;
        v[1]++;
    }
end
var[2] int a  = [1,2];
var&[2] int b = &a;
_f((&&b[0]));
escape b[0] + b[1];
]],
    --env = 'line 10 : invalid type cast',
    run = 5,
}

Test { [[
native/nohold _f;
native/pos do
    none f (int* v) {
        v[0]++;
        v[1]++;
    }
end
var[2] int a  = [1,2];
var&[2] int b = &a;
_f((&&b[0]) as int&&);
escape b[0] + b[1];
]],
    --env = 'line 10 : invalid type cast',
    run = 5,
}

Test { [[
native/const _X;
native/pos do
    ##define X 1
end
var&[-_X] int iis;
escape 1;
]],
    wrn = true,
    --inits = 'line 5 : uninitialized vector "iis" : reached `escape` (/tmp/tmp.ceu:6)',
    run = 1,
}

Test { [[
native/const _X;
native/pre do
    ##define X 2
end
var[-_X] int vvs;
var&[-_X] int iis = &vvs;
escape 1;
]],
    cc = '5:5: error: size of array ‘vvs_',
}

Test { [[
native/const _X;
native/pre do
    ##define X -1
end
var[-_X] int vvs;
var&[-_X] int iis = &vvs;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
var&[] int v;
escape 1;
]],
    --inits = 'line 1 : uninitialized vector "v" : reached `escape` (/tmp/tmp.ceu:2)',
    wrn = true,
    run = 1,
}
Test { [[
var[] int vv;
var&[] int v = &vv;;
escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    wrn = true,
    run = 1,
}

Test { [[
var[] byte c = [1];
var&[] byte b = &c;
escape b[0];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
native _u8;
native/const _N;
native/pre do
    int N = 10;
end
var&[_N] _u8 xxxx = _;
escape 1;
]],
    stmts = 'line 6 : invalid binding : expected option alias',
    --inits = 'line 6 : invalid binding : expected operator `&` in the right side',
    --inits = 'line 6 : invalid binding : unexpected statement in the right side',
    --gcc = '6:26: error: variably modified ‘xxxx’ at file scope',
}

Test { [[
var[] int xs;
var& int x = &xs[0];
escape 0;
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 2 : invalid binding : types mismatch : "Var" <= "Vec"',
}

--<< VECTOR / ALIAS

Test { [[
var int x=1; var int  y=2; var int  z=3;
var[10] int&& v = [ &&x, &&y, &&z ];
escape *v[0] + *v[1] + *v[2];
]],
    run = 6,
}

-->> VECTOR / RING

Test { [[
var[3] int vec = [];
vec = vec .. [1];
vec = vec .. [2];
vec = vec .. [3];
escape vec[$vec-1] - vec[0];
]],
    run = 2,
}

Test { [[
var[3*] int vec = [];
vec = vec .. [1];
vec = vec .. [2];
vec = vec .. [3];
escape vec[$vec-1] - vec[0];
]],
    run = 2,
}

Test { [[
var[3*] int vec = [ 1, 2, 3 ];
$vec = 1;
escape vec[0];
]],
    run = 3,
}

Test { [[
var[3*] int vec = [ 1, 2, 3 ];
$vec = $vec - 1;
escape vec[0];
]],
    run = 2,
}

Test { [[
var int n = 3;
var[n*] int vec = [];
vec = vec .. [1];
vec = vec .. [2];
vec = vec .. [3];
escape vec[$vec-1] - vec[0];
]],
    run = 2,
}

Test { [[
var int n = 3;
var[n*] int vec = [ 1, 2, 3 ];
$vec = 1;
escape vec[0];
]],
    run = 3,
}

Test { [[
var int n = 3;
var[n*] int vec = [ 1, 2, 3 ];
$vec = $vec - 1;
escape vec[0];
]],
    run = 2,
}

Test { [[
var[*] int vec = [ 1, 2, 3 ];
$vec = $vec - 1;
escape vec[0];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 2,
    --parser = 'line 1 : after `*` : expected expression',
}

Test { [[
do
    var[10] byte str = [].."1234567890";
end
do/_
    var[5*] byte str = [].."12345";
    escape {strlen(@(&&str[0] as _char&&))};
end
]],
    run = '2] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
do
    var[11] byte str = [].."1234567890";
end
do/_
    var[5*] byte str = [].."12345";
    escape {strlen(@(&&str[0] as _char&&))};
end
]],
    run = '5] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
do
    var[11] byte str = [].."1234567890";
end
do/_
    var[6*] byte str = [].."12345";
    escape {strlen(@(&&str[0] as _char&&))};
end
]],
    run = 5,
}

Test { [[
do
    var[11] byte str = [].."1234567890";
end
do/_
    var[5*] byte str = [].."1234";
    escape {strlen(@(&&str[0] as _char&&))};
end
]],
    run = 4,
}

Test { [[
do
    var[11] byte str = [].."1234567890";
end
do/_
    var int n = 5;
    var[n*] byte str = [].."12345";
    escape {strlen(@(&&str[0] as _char&&))};
end
]],
    run = '6] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
do
    var[11] byte str = [].."1234567890";
end
do/_
    var int n = 6;
    var[n*] byte str = [].."12345";
    escape {strlen(@(&&str[0] as _char&&))};
end
]],
    run = 5,
}

Test { [[
pool[5*] Ff fs;
]],
    parser = 'line 1 : after `*` : expected expression',
}

Test { [[
lua[5*] do end;
]],
    parser = 'line 1 : after `*` : expected expression',
}

Test { [[
native/nohold _ceu_vector_buf_set;
var[] byte v = [1,2,0,4,5];
var byte c = 3;
_ceu_vector_buf_set(&&v,2, &&c, 4);
escape v[2] + (($v) as int);
]],
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true' },
    run = '4] -> runtime error: access out of bounds',
}

Test { [[
native/nohold _ceu_vector_buf_set;
var[] int v = [1,2,0,4,5];
var int c = 3;
_ceu_vector_buf_set(&&v,2, &&c as byte&&, 4*sizeof(int));
escape v[2] + (($v) as int);
]],
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true' },
    run = '4] -> runtime error: access out of bounds',
}

Test { [[
native/nohold _ceu_vector_buf_set, _ceu_vector_setlen;
var[5]  byte v1 = [1,2,3,4,5];
var[5*] byte v2 = [0,0,11,10,0];
$v2 = $v2 - 3;
var int ret = v2[0];
_ceu_vector_setlen(&&v2, 5, 1);
_ceu_vector_buf_set(&&v2,0, &&v1[0], 5);
escape ret + v2[0] + v2[4];
]],
    run = 16,
}

Test { [[
native/nohold _ceu_vector_buf_set, _ceu_vector_setlen;
var[5]  int v1 = [1,2,3,4,5];
var[5*] int v2 = [0,0,0,10,0];
$v2 = $v2 - 3;
var int ret = v2[0];
_ceu_vector_setlen(&&v2, 5, 1);
_ceu_vector_buf_set(&&v2,0, &&v1[0] as byte&&, 5*sizeof(int));
escape ret + v2[0] + v2[4];
]],
    run = 16,
}

Test { [[
var[5*] int vec = [10];
vec = vec..[11];
$vec = $vec - 1;
vec = vec..[12];
$vec = $vec - 1;
escape vec[0];
]],
    run = 12,
}

Test { [[
var int n = 5;
native/nohold _ceu_vector_buf_set, _ceu_vector_setlen;
var[n]  byte v1 = [1,2,3,4,5];
var[n*] byte v2 = [0,0,11,10,0];
$v2 = $v2 - 3;
var int ret = v2[0];
_ceu_vector_setlen(&&v2, 5, 1);
_ceu_vector_buf_set(&&v2,0, &&v1[0], 5);
escape ret + v2[0] + v2[4];
]],
    run = 16,
}

Test { [[
var int n = 5;
native/nohold _ceu_vector_buf_set, _ceu_vector_setlen;
var[n]  int v1 = [1,2,3,4,5];
var[n*] int v2 = [0,0,0,10,0];
$v2 = $v2 - 3;
var int ret = v2[0];
_ceu_vector_setlen(&&v2, 5, 1);
_ceu_vector_buf_set(&&v2,0, &&v1[0] as byte&&, 5*sizeof(int));
escape ret + v2[0] + v2[4];
]],
    run = 16,
}

Test { [[
var int n = 5;
var[n*] int vec = [10];
vec = vec..[11];
$vec = $vec - 1;
vec = vec..[12];
$vec = $vec - 1;
escape vec[0];
]],
    run = 12,
}

Test { [[
var[10] int v1 = [1,2,3];
var[1] int v2 = []..v1;
escape 0;
]],
    run = '2] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}
Test { [[
var[3*] int v1 = [1,2,3];
$v1 = $v1 - 1;
var[10] int v2 = []..v1;
escape v2[0] + v2[1] + ($v2 as int);
]],
    run = 7,
}

Test { [[
var[3*] int v1 = [1,2,3];
$v1 = $v1 - 1;
v1 = v1..[4];
//{printf("%d %d %d\n", @v1[0], @v1[1], @v1[2]);}
var[10] int v2 = []..v1;
//{printf("%d %d %d\n", @v2[0], @v2[1], @v2[2]);}
escape v2[0] + v2[2] + ($v2 as int);
]],
    run = 9,
}

Test { [[
var int n = 3;
var[n*] int v1 = [1,2,3];
$v1 = $v1 - 1;
var[10] int v2 = []..v1;
escape v2[0] + v2[1] + ($v2 as int);
]],
    run = 7,
}

Test { [[
var int n = 3;
var[n*] int v1 = [1,2,3];
$v1 = $v1 - 1;
v1 = v1..[4];
var[10] int v2 = []..v1;
escape v2[0] + v2[2] + ($v2 as int);
]],
    run = 9,
}

Test { [[
var[1024*] int src;
var int i;
loop i in [1->1000] do
    src = src .. [i];
end
$src = 0;
loop i in [1001->1100] do
    src = src .. [i];
end
var[] int dst = []..src;
escape ((dst[0] + dst[$dst-1]) == 2101) as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}
Test { [[
var[1024*] int src;
var int i;
loop i in [1->1000] do
    src = src .. [i];
end
$src = 0;
var[] int dst = []..src;
escape ($dst as int) + 1;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}
Test { [[
var[1024*] int dst;
var int i;
loop i in [1->1000] do
    dst = dst .. [i];
end
$dst = 0;

var[] int src;
loop i in [1->50] do
    src = src .. [i];
end

dst = []..src;

escape dst[0] + dst[$dst-1] + ($dst as int) + 1;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 102,
}
Test { [[
var[1024*] int dst;
var int i;
loop i in [1->1020] do
    dst = dst .. [i];
end
$dst = 0;

var[50] int src;
loop i in [1->25] do
    src = src .. [i];
end
$src = 0;
loop i in [1->50] do
    src = src .. [i];
end

dst = []..src;

escape dst[0] + dst[$dst-1] + ($dst as int) + 1;
]],
    run = 102,
}

Test { [[
var[50*] byte xxx = [].."1234567890123456789012345678901234567890";
$xxx = 0;
xxx = [].."123456789012345678901234567890123";
escape xxx[0] - {'0'};
]],
    run = 1,
}

Test { [[
var[*] byte xxx = [1,2,3];
escape $xxx as int;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 3,
}

Test { [[
var[0*] byte xxx = [1,2,3];
escape $xxx as int;
]],
    run = '1] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var[*] byte xxx = [1,2,3];
xxx = xxx..[1,2,3,4,5,6,7,8,9,0];
$xxx = 3;
escape xxx[0]+xxx[1]+xxx[2];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 17,
}

Test { [[
var[*] byte xxx = [1,2,3];
var int i;
loop i in [1->1000] do
    xxx = xxx..[1,2,3,4,5,6,7,8,9,0];
end
$xxx = 3;
escape xxx[0]+xxx[1]+xxx[2];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 17,
}

Test { [[
var[*] byte xxx;
var int i;
loop i in [1->1000] do
    $xxx = 0;
    xxx = xxx..[1,2,3,4,5,6,7,8];
    xxx = xxx..[9,0,1,2,3];
end
$xxx = 3;
escape xxx[0]+xxx[1]+xxx[2];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 6,
}

Test { [[
var[*] byte xxx = [0,1,2,3,4,5,6,7,8,9];
$xxx = $xxx-5;
xxx = xxx..[0];

var int ret = xxx[0];       // 5

xxx = xxx .. [0,1,2,3,4,5,6,7,8,9]; // [5,6,7,8,9,0,1,2,3,...]
var int i;
loop i in [1->10000] do
    xxx = xxx .. [0,1,2,3,4,5,6,7,8,9];
end

ret = ret + xxx[0];         // +5 = 10
ret = ret + xxx[$xxx-1];    // +9 = 19

escape ret;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 19,
}

Test { [[
var[*] byte xxx = [0,1,2,3,4,5,6,7,8,9];
$xxx = $xxx-5;
xxx = xxx..[10,11,12,13,14];
xxx = xxx..[15];

/*
var int i;
loop i in [0 -> 11[ do
    {printf(">>> %d\n", CEU_APP.root.xxx_16.buf[@i]);}
end
*/

escape xxx[$xxx-1] + xxx[$xxx-2];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 29,
}

--<< VECTOR / RING

--<<< VECTORS / STRINGS

-->>> OPTION TYPES

Test { [[
var int? i;
if i? then end;
escape 1;
]],
    run = 1,
}

Test { [[
var int? i = 1;
escape i!;
]],
    run = 1,
}

Test { [[
var int? i;
escape (not i?) as int;
]],
    run = 1,
}

Test { [[
var int? i;
escape (not i?) as int;
]],
    run = 1,
}

Test { [[
var int v = 10;
var& int? i;
escape (not i?) as int;
]],
    inits = 'line 2 : uninitialized variable "i" : reached read access (/tmp/tmp.ceu:3)',
    --ref = 'line 3 : reference must be bounded before use',
    run = 1,
}

Test { [[
var int v = 10;
var& int? i;
escape (not i?) as int;
]],
    inits = 'line 2 : uninitialized variable "i" : reached read access (/tmp/tmp.ceu:3)',
    --run = 1,
}

Test { [[
var int v = 10;
var& int? i;
escape (not i?) as int;
]],
    inits = 'line 2 : uninitialized variable "i" : reached read access (/tmp/tmp.ceu:3)',
    --run = 1,
}

Test { [[
var int v = 10;
var& int? i = &v;
escape i!;
]],
    stmts = 'line 2 : invalid binding : types mismatch : "int?" <= "int"',
    --run = 10,
}

Test { [[
var int? v = 10;
var& int? i = &v;
escape i!;
]],
    run = 10,
}

Test { [[
var int? v1 = 0;
var int v2 = 1;
var& int? i = &v1;
i! = v2;
escape v1!;
]],
    run = 1,
    --code = 'line 4 : invalid operand in assignment',
}

Test { [[
var int? v1 = 0;
var int v2 = 1;
var& int? i = &v1;
i = v2;
escape v1!;
]],
    tmp = 'line 4 : invalid attribution : missing `!` (in the left) or `&` (in the right)',
}
Test { [[
var int? v1 = 0;
var int? v2 = 1;
var& int? i = &v1;
i = &v2;
escape i!;
]],
    run = 1,
    --inits = 'line 4 : invalid binding : variable "i" is already bound',-- (/tmp/tmp.ceu:3)',
    --ref = 'line 4 : invalid attribution : variable "i" is already bound',
    --ref = 'line 4 : invalid attribution : l-value already bounded',
}

Test { [[
var int? v1 = 0;
var int v2 = 1;
var& int? i = &v1;
i! = v2;
escape v1!;
]],
    run = 1,
}

Test { [[
var int v = 10;
var& int i = &v;
escape v + i;
]],
    run = 20,
}

Test { [[
var int? v = 10;
var& int? i = &v;
escape v! + i!;
]],
    run = 20,
}

Test { [[
var int? v1 = 10;
var int v2 =  1;
var& int? i = &v1;
i! = v2;
i! = 10;
var int ret = i!;
escape v1! + v2 + ret;
]],
    run = 21,
}

Test { [[
var int v = 10;
loop do
    var& int? i = &v;
    i = i + 1;
    break;
end
escape v;
]],
    wrn = true,
    --env = 'line 4 : invalid operands to binary "+"',
    dcls = 'line 4 : invalid operand to `+` : expected numeric type',
}

Test { [[
var int v = 10;
escape v!;
]],
    dcls = 'line 2 : invalid operand to `!` : expected option type',
}

Test { [[
var int? v = 10;
var& int? i;
i = &v;
i = &v;
escape i!;
]],
    run = 10;
    --inits = 'line 4 : invalid binding : variable "i" is already bound',-- (/tmp/tmp.ceu:3)',
    --ref = 'line 4 : invalid attribution : variable "i" is already bound',
}

Test { [[
var int? v = 10;
var& int? i;
loop do
    i = &v;
    i! = i! + 1;
    break;
end
escape v!;
]],
    --inits = 'line 2 : uninitialized variable "i" : reached `loop` (/tmp/tmp.ceu:3)',
    inits = 'line 4 : invalid binding : crossing `loop` (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "i" : reached yielding statement (/tmp/tmp.ceu:3)',
    --ref = 'line 4 : invalid attribution : variable "i" is already bound',
}
Test { [[
var int? v = 10;
var& int? i;
i! = &v;
escape i!;
]],
    --stmts = 'line 3 : invalid binding : expected declaration with `&`',
    stmts = 'line 3 : invalid binding : unexpected context for operator `!`',
    --inits = 'line 2 : uninitialized variable "i" : reached read access (/tmp/tmp.ceu:3)',
    --ref = 'line 3 : invalid attribution : cannot bind with operator `!`',
}

Test { [[
var int? v = 10;
var& int? i;
loop do
    i! = &v;
    i! = i! + 1;
    if true then
        break;
    else
        await 1s;
    end
end
escape v!;
]],
    --stmts = 'line 4 : invalid binding : expected declaration with `&`',
    stmts = 'line 4 : invalid binding : unexpected context for operator `!`',
    --inits = 'line 2 : uninitialized variable "i" : reached `loop` (/tmp/tmp.ceu:3)',
    --ref = 'line 4 : invalid attribution : variable "i" is already bound',
    --run = 11,
    --ref = 'reference declaration and first binding cannot be separated by loops',
    --ref = 'line 2 : uninitialized variable "i" crossing compound statement (/tmp/tmp.ceu:3)',
}

Test { [[
event int e;
var int x;
do
    x = await e;
finalize (x) with
    nothing;
end
escape 0;
]],
    scopes = 'line 4 : invalid `finalize` : unexpected `await`',
}

Test { [[
var int? x;
escape x!;
]],
    run = '2] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
var int? v1 = 10;
var int? v2 = v1;
escape v2!;
]],
    --stmts = 'line 2 : invalid assignment : expected operator `!`',
    run = 10;
}

Test { [[
var int? v1 = 10;
var int? v2;
var int ret = (v1? as int) + v1!;
v1 = v2;
escape ret+(v1? as int)+1;
]],
    todo = 'v1 = v2 would fail now',
    run = 12;
}

Test { [[
var int? i = 10;
var& int? ai = &i;
escape ai!;
]],
    run = 10,
}
Test { [[
var int? i;
var& int? ai = &i;
i = 10;
escape ai!;
]],
    run = 10,
}
Test { [[
var int? i;
var& int? ai = &i;
escape 1 + (ai? as int);
]],
    run = 1,
}

Test { [[
var int? i;
escape i as int;
]],
    dcls = 'line 2 : invalid operand to `as` : unexpected option type',
}
Test { [[
var int? i;
escape i is int;
]],
    --dcls = 'line 2 : invalid operand to `is` : unexpected option type',
    dcls = 'line 2 : invalid operand to `is` : expected plain `data` type : got "int?"',
}
Test { [[
var int? i = 10;
escape (i! as int) as int;
]],
    run = 10,
}
Test { [[
var int? i = 10;
escape (i! as int);
]],
    run = 10,
}

Test { [[
escape 1?;
]],
    --parser = 'ERR : /tmp/tmp.ceu : line 1 : after `1` : expected `is` or `as` or binary operator or `;`',
    dcls = 'line 1 : invalid operand to `?` : unexpected context for value "1"',
}
Test { [[
var int i;
escape i?;
]],
    dcls = 'line 2 : invalid operand to `?` : expected option type',
}
Test { [[
var int? i = 1;
escape i? as int;
]],
    run=1,
}
Test { [[
var int? i;
escape (i? as int)+1;
]],
    run=1,
}

Test { [[
var int?&& v;
escape 1;
]],
    parser = 'line 1 : after `?` : expected internal identifier',
    --env = 'line 1 : invalid type modifier : `?&&`',
    --adj = 'line 1 : not implemented : `?` must be last modifier',
}
Test { [[
var& int? v;
escape 1;
]],
    wrn = true,
    run = 1,
    --inits = 'line 1 : uninitialized variable "v" : reached `escape` (/tmp/tmp.ceu:2)',
    --env = 'line 1 : invalid type modifier : `?&`',
    --adj = 'line 1 : not implemented : `?` must be last modifier',
}
Test { [[
var int? k;
var& int? v = &k;
escape 1 + (v? as int);
]],
    run = 1,
}
Test { [[
var int? k;
var& int? v = &k;
v = 10;
escape k!;
]],
    run = 10,
}
Test { [[
var int? k;
k = 10;
var& int? v = &k;
escape v!;
]],
    run = 10,
}
Test { [[
var int?? v;
escape 1;
]],
    parser = 'line 1 : after `?` : expected internal identifier',
    --env = 'line 1 : invalid type modifier : `??`',
    --adj = 'line 1 : not implemented : `?` must be last modifier',
}

-->> OPTION / NATIVE

Test { [[
native _SDL_Texture;
native/nohold _g;
var& _SDL_Texture? t_enemy_1;
native _f;
do
    t_enemy_1 = &_f();
finalize(t_enemy_1) with
    _g(&&t_enemy_1!);
end
escape 1;
]],
    wrn = true,
    stmts = 'line 6 : invalid binding : expected `native` type',
    --scopes = 'line 6 : invalid binding : expected option alias `&?` as destination : got "_SDL_Texture?"',
}

Test { [[
native _SDL_Texture;
native/nohold _g;
var& _SDL_Texture t_enemy_1;
native _f;
do
    t_enemy_1 = &_f();
finalize(t_enemy_1) with
    _g(&&t_enemy_1);
end
escape 1;
]],
    wrn = true,
    cc = '1: error: unknown type name ‘SDL_Texture’',
    --scopes = 'line 6 : invalid binding : expected option alias `&?` as destination : got "_SDL_Texture"',
}

Test { [[
native _SDL_Texture;
native/nohold _g;
var&? _SDL_Texture t_enemy_1;
native _f;
do
    t_enemy_1 = &_f();
finalize(t_enemy_1) with
    _g(&&t_enemy_1!);
end
escape 1;
]],
    wrn = true,
    cc = 'error: unknown type name ‘SDL_Texture’',
}

Test { [[
native _SDL_Texture;
native/nohold _g;
var&? _SDL_Texture t_enemy_0; var&? _SDL_Texture t_enemy_1;
native _f;
    do t_enemy_1 = &_f();
finalize (t_enemy_1) with
    _g(&&t_enemy_1!);
end
escape 1;
]],
    wrn = true,
    cc = 'error: unknown type name ‘SDL_Texture’',
    --inits = 'line 3 : uninitialized variable "t_enemy_0" : reached `escape` (/tmp/tmp.ceu:9)',
    --inits = 'line 3 : uninitialized variable "t_enemy_0" : reached end of `par/or` (/tmp/tmp.ceu:5)',
}

Test { [[
native/plain _t;
var _t ttt = { (t){11} };
var& _t? kkk = &ttt;
escape 0;
]],
    stmts = 'line 3 : invalid binding : types mismatch : "_t?" <= "_t"',
    --run = 211,
}

Test { [[
native/pre do
    typedef struct {
        int x;
    } t;
    int id (int v) {
        return v;
    }
end
native/pure _id;

native/plain _t;
var _t? ttt = { (t){11} };

var& _t? kkk = &ttt;

var int ret = kkk!.x;
kkk!.x = 100;

escape ret + _id(kkk!.x) + ttt!.x;
]],
    run = 211,
}

Test { [[
native _void, _myalloc;
native/pre do
    none* myalloc (none) {
        return NULL;
    }
    none myfree (none* v) {
    }
end
native/nohold _myfree;

var&? _void vvv;
do
    vvv = &_myalloc();
finalize(vvv) with
    _myfree(&&vvv!);
end

escape 1;
]],
    run = '15] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
native _void_ptr;
native/pre do
    typedef void* void_ptr;
end
var _void_ptr x = null;
var& _void_ptr v = &x;
v = null;
escape (x == null) as int;
]],
    run = 1,
}

Test { [[
native _void_ptr;
native/pre do
    typedef void* void_ptr;
end
var _void_ptr? x = null;
var& _void_ptr? v = &x;
v! = null;
escape (x! == null) as int;
]],
    --dcls = 'line 5 : invalid declaration : expected `&`',
    run = 1,
}
Test { [[
native _void;
native _f;
var&? _void x = &_f()
    finalize (x) with
        nothing;
    end;
x = null;
escape 0;
]],
    stmts = 'line 7 : invalid assignment : read-only variable "x"',
}

Test { [[
native _void, _f;
var&? _void x = &_f()
    finalize (x) with
        nothing;
    end;
x! = null;
escape 0;
]],
    stmts = 'line 6 : invalid assignment : read-only variable "x"',
}

Test { [[
native _void, _f;
var&? _void x = &_f()
    finalize (x) with
        nothing;
    end;
var&? _void v = &x;
v! = null;
escape (x! == null) as int;
]],
    stmts = 'line 7 : invalid assignment : read-only variable "v"',
}

Test { [[
native _void, _myalloc;
native/pre do
    void* myalloc (void) {
        return NULL;
    }
    void myfree (void* v) {
    }
end
native/nohold _myfree;

var&? _void v;
do
    v = &_myalloc();
finalize(v) with
    if v? then
        _myfree(&&v!);
    end
end

escape 1;
]],
    run = 1,
}

Test { [[
var&? int v1;
native _fff;
do
    v1 = &_fff(1);
finalize(v1) with
    nothing;
end
]],
    --dcls = 'line 1 : invalid declaration : option alias : expected native or `code/await` type',
    stmts = 'line 4 : invalid binding : expected `native` type',
    --cc = 'error: implicit declaration of function ‘fff’',
    --stmts = 'line 4 : invalid binding : types mismatch : "int?" <= "_"',
}

Test { [[
native _int;
var&? _int v1;
native _fff;
do
    v1 = &_fff(1);
finalize(v1) with
    nothing;
end
]],
    cc = 'error: implicit declaration of function ‘fff’',
    --stmts = 'line 4 : invalid binding : types mismatch : "int?" <= "_"',
}

Test { [[
native/nohold _UNSAFE_POINTER_TO_REFERENCE;
native _int, _fff;
native/pre do
    ##define UNSAFE_POINTER_TO_REFERENCE(ptr) ptr
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

var&? _int v1;
        do v1 = &_fff(1);
    finalize(v1) with
        nothing;
    end

var&? _int v2;
        do v2 = &_fff(2);
    finalize(v2) with
        nothing;
    end

var&? _int v3;
native _V1, _V2;
        do v3 = &_UNSAFE_POINTER_TO_REFERENCE(_V1);
    finalize(v3) with
        nothing;
    end

var&? _int v4;
        do v4 = &_UNSAFE_POINTER_TO_REFERENCE(_V2);
    finalize(v4) with
        nothing;
    end

escape ((not v1?)as int) + ((not v3?) as int) + (v2? as int) + (v4? as int) + ((&&v2! ==_V2)as int) + ((&&v4! ==_V2) as int) + (v2!) + (v4!);
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
    parser = 'line 4 : after `interface` : expected `[` or `:` or `.` or `!` or `as` or `=` or `?` or `(` or `is` or binary operator or `;`',
    run = 1,
}

Test { [[
data SDL_Color with
    var int v;
end
var SDL_Color clr = val SDL_Color(10);
var SDL_Color? bg_clr = clr;
escape bg_clr.v;
]],
    dcls = 'line 6 : invalid operand to `.` : expected plain type : got "SDL_Color?"',
    --dcls = 'line 6 : invalid member access : "bg_clr" must be of plain type',
    --env = 'line 6 : invalid `.` operation : cannot be an option type',
}

Test { [[
native _SDL_Surface, _TTF_RenderText_Blended, _SDL_FreeSurface;
var& _SDL_Surface sfc;
every 1s do
    do
        sfc = &_TTF_RenderText_Blended();
    finalize (sfc) with
        _SDL_FreeSurface(&&sfc);
    end
end
escape 1;
]],
    inits = 'line 5 : invalid binding : crossing `loop` (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "sfc" : reached `loop` (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "sfc" : reached yielding statement (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "sfc" : reached `await` (/tmp/tmp.ceu:3)',
    --ref = 'line 4 : invalid attribution : variable "sfc" is already bound',
    --ref = 'line 4 : reference declaration and first binding cannot be separated by loops',
    --ref = 'line 1 : uninitialized variable "sfc" crossing compound statement (/tmp/tmp.ceu:2)',
}

Test { [[
native _fff, _int;
native/pre do
    int V = 10;
    int* fff (int v) {
        V += v;
        escape &V;
    }
end
var int   v = 1;
var int&& p = &&v;
var&? _int r;
do r = &_fff(*p);
finalize (r) with
    nothing;
end
escape r;
]],
    stmts = 'line 16 : invalid `escape` : expected operator `!`',
    --stmts = 'line 17 : invalid `escape` : types mismatch : "int" <= "_int?"',
    --env = 'line 16 : types mismatch (`int` <= `int&?`)',
}

Test { [[
native _f, _int;
var&? _int v = &_f();
escape 0;
]],
    scopes = 'line 2 : invalid binding : expected `finalize`',
}

Test { [[
var int? ret=0;
var& int? p = &ret;
p! = p!;
escape 1;
]],
    run = 1,
}

Test { [[
native _f, _int;
do
    var&? _int a;
    do
        a = &_f();
    finalize (a) with
        do await FOREVER; end;
    end
end
]],
    props_ = 'line 7 : invalid `await` : unexpected enclosing `finalize`',
    --props = "line 7 : not permitted inside `finalize`",
}

Test { [[
native _f, _int;
do
    var&? _int a;
    do a = &_f();
    finalize (a) with
        await async do
        end;
    end
end
]],
    props_ = 'line 6 : invalid `async` : unexpected enclosing `finalize`',
    --props = "line 7 : not permitted inside `finalize`",
}

Test { [[
native _f, _int;
do/_
    var&? _int a;
    do a = &_f();
    finalize (a) with
        do/_ escape 0; end;
    end
end
]],
    props_ = 'line 6 : invalid `escape` : unexpected enclosing `finalize`',
    --props = "line 7 : not permitted inside `finalize`",
}

Test { [[
native _void, _myalloc;
native/pre do
    void* myalloc (void) {
        return NULL;
    }
    void myfree (void* v) {
    }
end
native/nohold _myfree;

var&? _void v;
do
    v = &_myalloc();
finalize(v) with
    if v? then
        _myfree(&&v!);
    end
end

var& _void vv = &v!;

escape 1;
]],
    run = '20] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
native _void, _myalloc, _V;
native/pre do
    int V;
    void* myalloc (void) {
        return &V;
    }
    void myfree (void* v) {
    }
end
native/nohold _myfree;

var&? _void v;
do
    v = &_myalloc();
finalize(v) with
    if v? then
        _myfree(&&v!);
    end
end

var& _void vv = &v!;

escape (&&vv==(&&_V as _void&&) and (&&_V as _void&&)==&&v!) as int;
]],
    run = 1,
}

-->> OPTION / NATIVE / FINALIZE

Test { [[
native _int;

native _fff;
native/pre do
    int V = 10;
    int* fff (int v) {
        V += v;
        return &V;
    }
end
var int   v = 1;
var int&& p = &&v;
var&? _int r;
do
    r = &_fff(*p);
finalize (r) with
    nothing;
end
escape r!;
]],
    run = 11,
}

Test { [[
native _SDL_Renderer, _f;
native/nohold _g;

var&? _SDL_Renderer ren;
    do ren = &_f();
    finalize (ren) with
    end

await 1s;
_g(&&(ren!));

escape 1;
]],
    cc = 'error: unknown type name ‘SDL_Renderer’',
}

Test { [[
native _int;
native _f;
input none E;
var&? _int n;
do n = &_f();
finalize (n) with
end
await E;
escape n!;
]],
    cc = 'error: implicit declaration of function ‘f’',
}

Test { [[
native _int;
native _f;
native/pos do
    int* f (void) {
        return NULL;
    }
end
var int r = 0;
do/_
    var&? _int a;
    do a = &_f();
    finalize (a) with
        var int b = do escape 2; end;
    end
    r = 1;
end
escape r;
]],
    --props = "line 8 : not permitted inside `finalize`",
    --cc = '9:27: error: variable ‘__ceu_a_3’ set but not used [-Werror=unused-but-set-variable]',
    run = 1,
}

Test { [[
native _int;
native _f;
native/pos do
    int* f (void) {
        return NULL;
    }
end
var int r = 0;
do/_
    var&? _int a;
    do a = &_f();
    finalize (a) with
        if a? then end
        var int b = do escape 2; end;
    end
    r = 1;
end
escape r;
]],
    --props = "line 8 : not permitted inside `finalize`",
    run = 1,
}

Test { [[
native _int;
native _getV;
native/pos do
    int V = 10;
    int* getV (void) {
        return &V;
    }
end

var&? _int v;
do
    v = &_getV();
finalize (v)
with
    nothing;
end

escape v!;
]],
    run = 10,
}
Test { [[
native _getV, _int;
native/pos do
    int V = 10;
    int* getV (void) {
        return &V;
    }
end

var&? _int v;
do
    v = &_getV();
finalize (v)
with
    nothing;
end

escape v!;
]],
    run = 10,
}
Test { [[
native _int;
native _V, _getV;
native/pos do
    int V = 10;
    int* getV (void) {
        return &V;
    }
end

var&? _int v1;
do v1 = &_getV();
finalize (v1) with
    nothing;
end
*v1! = 20;

var&? _int v2;
do v2 = &_getV();
finalize (v2) with
    nothing;
end

escape *v1!+*v2!+_V;
]],
    todo = 'opt-ro',
    --env = 'line 14 : invalid attribution : missing `!` (in the left) or `&` (in the right)',
    run = 60,
}
Test { [[
native _int;
native _V, _getV;
native/pos do
    int V = 10;
    int* getV (void) {
        return &V;
    }
end

var&? _int v1;
do
    v1 = &_getV();
finalize (v1)
with
    nothing;
end
*v1! = 20;

var&? _int v2;
do
    v2 = &_getV();
finalize (v2)
with
    nothing;
end

escape v1!+v2!+_V;
]],
    todo = 'opt-ro',
    run = 60,
}

Test { [[
native _int;
native _f;
native/pre do
    int* f (int* ptr) { return ptr; }
end

var int ret = 0;
do
var int v = 2;
var&? _int p = &_f(&&v)
                finalize (p,v) with
                    ret = 5;
                end;
end
escape ret;
]],
    run = 5,
}

Test { [[
native _f;
native/pos do
    int f (int* p) { return *p+1; }
end
var int x = 1;
var int r;
do
    r = _f(&&x);
finalize (x) with
    nothing;
end
escape r;
]],
    run = 2,
}
Test { [[
native _int;
native _f;
var int x = 0;
var&? _int r;
do
    r = &_f(&&x);
finalize (x) with
    nothing;
end
escape 0;
]],
    scopes = 'line 7 : invalid `finalize` : unmatching identifiers : expected "r" (vs. /tmp/tmp.ceu:6)',
}
Test { [[
native _int;
native _f;
var int x = 0;
var&? _int r;
do
    r = &_f(&&x);
finalize (r) with
    nothing;
end
escape 0;
]],
    scopes = 'line 7 : invalid `finalize` : unmatching identifiers : expected "x" (vs. /tmp/tmp.ceu:6)',
}
Test { [[
native _int;
native/pre do
    int* f(int* x) { return x; }
end
native _f;
var int x = 0;
var&? _int r;
do
    r = &_f(&&x);
finalize (r,x) with
    nothing;
end
escape 1;
]],
    run = 1,
}
Test { [[
native _int;
native _f;
var int x = 0;
do
    var&? _int r;
    do
        r = &_f(&&x);
    finalize (r,x) with
        nothing;
    end
end
escape 1;
]],
    scopes = 'line 7 : invalid `finalize` : incompatible scopes',
}
Test { [[
native/nohold _S, _F, _f;
code/await Surface_from_desc (var _S desc) -> FOREVER
do
    var&? _F f = &_f(desc) finalize (f) with end;
    await FOREVER;
end
]],
    wrn = true,
    parser = 'line 2 : after `->` : expected `(` or type or `NEVER`',
    --run = 1,
}

Test { [[
native/nohold _S, _F, _f;
code/await Surface_from_desc (var _S desc) -> NEVER
do
    var&? _F f = &_f(desc) finalize (f) with end;
    await FOREVER;
end
]],
    wrn = true,
    cc = '4:57: error: implicit declaration of function ‘f’',
    --run = 'Aborted (core dumped)',
}

Test { [[
native/nohold _S, _F, _f;
code/await Surface_from_desc (var _S desc) -> NEVER
do
    var&? _F f = &_f(desc) finalize (f) with end;
    await FOREVER;
end
var _S x = _;
await Surface_from_desc(x);
escape 0;
]],
    wrn = true,
    cc = 'error: implicit declaration of function ‘f’',
    --run = 1,
}

Test { [[
native _f;
var int x = 0;
do
    var int y = 0;
    do
        _f(&&x,&&y);
    finalize with
        nothing;
    end
end
escape 1;
]],
    scopes = 'line 6 : invalid `finalize` : incompatible scopes',
}

Test { [[
native _int;
native _alloc;
native/pos do
    int V;
    int* alloc (int ok) {
        return &V;
    }
    void dealloc (int* ptr) {
    }
end
native/nohold _dealloc;

var&? _int tex;
do tex = &_alloc(1);    // v=2
finalize (tex) with
    _dealloc(&&tex);
end

escape 1;
]],
    dcls = 'line 16 : invalid operand to `&&` : unexpected option type',
}

Test { [[
native _int;
native _alloc;
native/pos do
    int V;
    int* alloc (int ok) {
        return &V;
    }
    void dealloc (int* ptr) {
    }
end
native/nohold _dealloc;

var&? _int tex;
do tex = &_alloc(1);    // v=2
finalize (tex) with
    _dealloc(&&tex!);
end

escape 1;
]],
    run = 1,
}

Test { [[
native _int;
native _alloc;
native/pos do
    int* alloc (int ok) {
        return NULL;
    }
    void dealloc (int* ptr) {
    }
end
native/nohold _dealloc;

var&? _int tex;
do
    tex = &_alloc(1);    // v=2
finalize (tex)
with
    _dealloc(&&tex!);
end

escape 1;
]],
    run = '17] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
native _int;
native _alloc, _V;
native/pos do
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
native/nohold _dealloc;

do
    var&? _int tex;
do tex = &_alloc(1);
    finalize (tex) with
        _dealloc(tex);
    end
end

escape _V;
]],
    stmts = 'line 20 : invalid call : unexpected context for operator `?`',
    --env = 'line 19 : wrong argument #1 : cannot pass option values to native calls',
    --run = 1,
}

Test { [[
native _f;
event int e;
_f(e);
escape 0;
]],
    stmts = 'line 3 : invalid expression list : item #1 : unexpected context for event "e"',
}

Test { [[
native _int;
native _alloc, _V;
native/pos do
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
native/nohold _dealloc;

do
    var&? _int tex;
    do tex = &_alloc(1);
    finalize (tex) with
        _dealloc(&tex!);
    end
end

escape _V;
]],
    stmts = 'line 20 : invalid expression list : item #1 : unexpected context for alias "tex"',
    --stmts = 'line 19 : invalid call : unexpected context for operator `&`',
    --env = 'line 19 : wrong argument #1 : cannot pass aliases to native calls',
    --run = '19] -> runtime error: invalid tag',
}

Test { [[
native _int;
native/pos do
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
native _alloc, _V;
native/nohold _dealloc;

do
    var&? _int tex;
    do tex = &_alloc(1);
    finalize (tex) with
        _dealloc(&&tex!);
    end
end

escape _V;
]],
    --env = 'line 19 : wrong argument #1 : cannot pass option type',
    run = '20] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
native/pre do
    struct Tx;
    typedef struct Tx* t;
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
native _alloc, _V, _t;
native/nohold _dealloc;

var int ret = _V;           // v=1, ret=1

do
    var&? _t tex;
do
        tex = &_alloc(1);    // v=2
    finalize (tex)
    with
        _dealloc(&&tex!);
    end
    ret = ret + _V;         // ret=3
    if not tex? then
        ret = 0;
    end
end                         // v=4

ret = ret + _V;             // ret=7

do
    var&? _t tex;
do
        tex = &_alloc(0);    // v=4
    finalize (tex)
    with
        if tex? then
            _dealloc(&&tex!);
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
native _f;
native/pos do
    void* f () {
        return NULL;
    }
end

var&? none ptr;
do ptr = &_f();
finalize (ptr) with
    nothing;
end

escape &&ptr! == &&ptr!;  // ptr.SOME fails
]],
    --run = 1,
    stmts = 'line 9 : invalid binding : expected `native` type',
    --dcls = 'line 8 : invalid declaration : option alias : expected native or `code/await` type',
    --dcls = 'line 14 : invalid expression : unexpected context for operation `&`',
    --env = 'line 14 : invalid use of operator "&" : not a binding assignment',
}

Test { [[
native _f, _void;
native/pos do
    void* f () {
        return NULL;
    }
end

var&? _void ptr;
do
    ptr = &_f();
finalize (ptr)
with
    nothing;
end

escape (&&ptr! == &&ptr!) as int;  // ptr.SOME fails
]],
    run = '16] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
    --stmts = 'line 10 : invalid binding : types mismatch : "none" <= "_"',
}

Test { [[
native _f, _void;
native/pre do
    void* f () {
        return NULL;
    }
end

var&? _void ptr;
do
    ptr = &_f();
finalize (ptr)
with
    nothing;
end

escape (&&ptr! == &&ptr!) as int;  // ptr.SOME fails
]],
    run = '16] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
native _f, _void;
native/pre do
    void* f () {
        return NULL;
    }
end

var&? _void ptr;
do
    ptr = &_f();
finalize (ptr)
with
    nothing;
end

escape (not ptr? )as int;
]],
    run = 1,
}

Test { [[
native _f, _void;
native/pre do
    void* f () {
        return NULL;
    }
    void g (void* g) {
    }
end
native/nohold _g;

var&? _void ptr;
do
    ptr = &_f();
finalize (ptr)
with
    _g(&&ptr!);    // error (ptr is Nil)
end

escape (not ptr? )as int;
]],
    run = '16] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
native _f, _void;
native/pre do
    void* f () {
        return NULL;
    }
    void g (void* g) {
    }
end
native/nohold _g;

var int ret = 0;

do
    var&? _void ptr;
do
        ptr = &_f();
    finalize (ptr)
    with
        if ptr? then
            _g(&&ptr!);
        else
            ret = ret + 1;
        end
    end
    ret = ret + ((not ptr?) as int);
end

escape ret;
]],
    run = 2,
}

Test { [[
native _alloc, _V;
native/pos do
    int V = 1;
    int* alloc () {
        return &V;
    }
end

var& int? tex1;
do tex1 = &_alloc(1);
finalize (tex1) with
    nothing;
end

var& int tex2 = tex1;

escape &tex2==&_V;
]],
    dcls = 'line 17 : invalid expression : unexpected context for operation `&`',
    --env = 'line 15 : types mismatch (`int&` <= `int&?`)',
    --run = 1,
}

Test { [[
native _alloc, _V;
native/pos do
    int V = 1;
    int* alloc () {
        return NULL;
    }
end

var& int? tex1;
do tex1 = &_alloc(1);
finalize (tex1) with
    nothing;
end

var& int tex2 = tex1;

escape &tex2==&_V;
]],
    dcls = 'line 17 : invalid expression : unexpected context for operation `&`',
    --env = 'line 15 : types mismatch (`int&` <= `int&?`)',
    --asr = true,
}

Test { [[
native _V, _t, _alloc;
native/pre do
    struct Tx;
    typedef struct Tx t;
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
native/nohold _dealloc;

var int ret = _V;           // v=1, ret=1

do
    var&? _t tex;
do
        tex = &_alloc(1);    // v=2
    finalize (tex)
    with
        _dealloc(&&tex!);
    end
    ret = ret + _V;         // ret=3
    if not tex? then
        ret = 0;
    end
end                         // v=4

ret = ret + _V;             // ret=7

do
    var&? _t tex;
do
        tex = &_alloc(0);    // v=4
    finalize (tex)
    with
        if tex? then
            _dealloc(&&tex!);
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
native _SDL_Window, _SDL_CreateWindow, _SDL_WINDOW_SHOWN;
//native/nohold _SDL_DestroyWindow;

var& _SDL_Window win =
    &_SDL_CreateWindow("UI - Texture", 500, 1300, 800, 480, _SDL_WINDOW_SHOWN);
escape 0;
]],
    scopes = 'line 5 : invalid binding : expected `finalize`',
    --scopes = 'line 5 : invalid binding : expected option alias `&?` as destination : got "_SDL_Window"',
    --fin = 'line 6 : must assign to a option reference (declared with `&?`)',
}
Test { [[
native _SDL_Window, _SDL_CreateWindow, _SDL_WINDOW_SHOWN;
//native/nohold _SDL_DestroyWindow;

var& _SDL_Window win =
    &_SDL_CreateWindow("UI - Texture", 500, 1300, 800, 480, _SDL_WINDOW_SHOWN)
        finalize (win) with
            //_SDL_DestroyWindow(win);
        end
escape 0;
]],
    cc = '1: error: unknown type name ‘SDL_Window’',
    --parser = 'line 5 : after `)` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `..` or `;`',
    --scopes = 'line 4 : invalid binding : expected option alias `&?` as destination : got "_SDL_Window"',
    --fin = 'line 6 : must assign to a option reference (declared with `&?`)',
}

Test { [[
native _my_alloc, _void;
native/pre do
    void* my_alloc (void) {
        return NULL;
    }
end

input none SDL_REDRAW;

par/or do
    await 1s;
with
    loop do
        await SDL_REDRAW;
        var&? _void srf = &_my_alloc()
            finalize (srf) with end;
    end
end
escape 1;
]],
    wrn = true,
    run = { ['~>SDL_REDRAW;~>SDL_REDRAW;~>SDL_REDRAW;~>SDL_REDRAW;~>1s']=1 },
}

Test { [[
native _my_alloc, _void;
native/pre do
    void* my_alloc (void) {
        return NULL;
    }
end

input none SDL_REDRAW;

par/or do
    await 1s;
with
    every SDL_REDRAW do
        var&? _void srf = &_my_alloc()
            finalize (srf) with end;
    end
end
escape 1;
]],
    props_ = 'line 14 : invalid `finalize` : unexpected enclosing `every`',
    wrn = true,
    run = { ['~>SDL_REDRAW;~>SDL_REDRAW;~>SDL_REDRAW;~>SDL_REDRAW;~>1s']=114 },
}

Test { [[
native _V, _my_alloc, _my_free, _void;
native/pre do
    int V = 0;
    void* my_alloc (void) {
        V += 1;
        return NULL;
    }
    void my_free () {
        V *= 2;
    }
end

input none SDL_REDRAW;

par/or do
    await 1s;
    _V = _V + 100;
with
    loop do
        await SDL_REDRAW;
        var&? _void srf;
        do
            srf = &_my_alloc();
        finalize (srf) with
            if srf? then
            end;
            _my_free();
        end
    end
end
escape _V+1;
]],
    run = { ['~>SDL_REDRAW;~>SDL_REDRAW;~>SDL_REDRAW;~>1s']=115 },
}

Test { [[
native _f;
native/pos do
    int* f () {
        int a = 10;
        escape &a;
    }
end
var& int? p = _f();
escape 0;
]],
    --stmts = 'line 9 : invalid `escape` : types mismatch : "int" <= "int?"',
    --inits = 'line 8 : invalid attribution : missing `!` (in the left) or `&` (in the right)',
    inits = 'line 8 : invalid binding : expected operator `&` in the right side',
}

Test { [[
native _f, _int;
native/pre do
    int* f () {
        int a = 10;
        escape &a;
    }
end
var&? _int p = &_f();
escape p;
]],
    stmts = 'line 9 : invalid `escape` : expected operator `!`',
    --stmts = 'line 10 : invalid `escape` : types mismatch : "int" <= "_int?"',
    --env = 'line 9 : types mismatch (`int` <= `int&?`)',
}

Test { [[
native _f,_int;
native/pre do
    int* f () {
        int a = 10;
        escape &a;
    }
end
var&? _int p = &_f();
escape p!;
]],
    scopes = 'line 8 : invalid binding : expected `finalize`',
    --fin = 'line 8 : attribution requires `finalize`',
}

Test { [[
native _int, _f;
native/pre do
    int a;
    int* f () {
        a = 10;
        return &a;
    }
end
var&? _int p;
do
    p = &_f();
finalize (p)
with
    nothing;
end
escape p!;
]],
    run = 10,
}
Test { [[
native _int, _f;
native/pre do
    int a;
    int* f () {
        a = 10;
        return &a;
    }
end
var&? _int p;
do
    p = &_f();
finalize (p)
with
    nothing;
end
escape p!;
]],
    run = 10,
}
Test { [[
native/pure _f;    // its actually impure
native/pre do
    int a;
    int* f () {
        a = 10;
        return &a;
    }
end
var int&& p;
    p = _f();
escape *p;
]],
    run = 10,
}
Test { [[
native _int, _f;
native/pre do
    int A = 10;
    int* f () {
        return &A;
    }
end
var int a=0;
do
    var&? _int p;
do
        p = &_f();
    finalize (p)
    with
        a = p!;
end
end
escape a;
]],
    run = 10,
}

Test { [[
native _int, _f;
native/pre do
    int A = 10;
    int* f () {
        return &A;
    }
end
var int a = 10;
do
    var&? _int p;
    //do
do
            p = &_f();
        finalize (p)
        with
            a = a + p!;
        end
    //end
    a = 0;
end
escape a;
]],
    run = 10,
}

Test { [[
native _int, _f;
native/pre do
    int A = 10;
    int* f () {
        return &A;
    }
end
var int a = 10;
do
    var&? _int p;
    //do
do
            p = &_f();
        finalize (p)
        with
            a = a + p!;
        end
    //end
    a = 0;
    await 1s;
    a = p!;
end
escape a;
]],
    run = { ['~>1s']=20 },
}

--<< OPTION / NATIVE / FINALIZE

--<< OPTION / NATIVE

-- TODO: SKIP-01

-->> OPTION / NIL

Test { [[
var int x = 10;
x = _;
escape x;
]],
    --stmts = 'line 2 : invalid assignment : expected option destination',
    run = 10,
}

Test { [[
var[] int x = [1,2,3];
x = _;
escape x[1];
]],
    _opts = { ceu_features_dynamic='true' },
    --stmts = 'line 2 : invalid assignment : unexpected context for vector "x"',
    run = 2,
}

Test { [[
var int? x = 10;
x = _;
escape (x? as int) + 1;
]],
    run = 1,
}

--<< OPTION / NIL
--<<< OPTION TYPES

-->>> WATCHING

Test { [[
input int&& E;
var int e =
    watching E do
        await FOREVER;
    end;
escape 0;
]],
    stmts = 'line 2 : invalid assignment : types mismatch : "(int)" <= "(int&&)"',
}

Test { [[
input int&& E;
var int e =
    watching E -> (&a) do
        await FOREVER;
    end;
escape 0;
]],
    parser = 'line 3 : after `E` : expected `,` or `do`',
    --adjs = 'line 3 : unexpected `->`',
}

Test { [[
var int ret = 1;
watching 1s do
    every 100ms do
        ret = ret + 1;
    end
end;
escape ret;
]],
    run = { ['~>1s'] = 10 },
}

Test { [[
var int n =
    watching 1s do
        await FOREVER;
    end;
escape n/10;
]],
    stmts = 'line 1 : invalid `watching` assignment : expected option type `?` : got "int"',
    --run = { ['~>1001ms'] = 100 },
}

Test { [[
var int? n =
    watching 1s do
        await FOREVER;
    end;
escape n!/10;
]],
    run = { ['~>1001ms'] = 100 },
}

Test { [[
var int? n =
    watching 1s do
    end;
escape n!/10;
]],
    run = '4] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
input none OS_START;
watching OS_START do
    await FOREVER;
end
escape 1;
]],
    run = 1,
}

Test { [[
input (int,int) E;
var int n =
    watching E do
        await FOREVER;
    end;
escape n;
]],
    stmts = 'line 2 : invalid assignment : types mismatch : "(int)" <= "(int,int)"',
}

Test { [[
input (int,int) E;
var int a; var int b;
(a,b) =
    watching E do
        await FOREVER;
    end;
escape a+b;
]],
    stmts = 'line 3 : invalid `watching` assignment : expected option type `?` : got "int"',
}

Test { [[
input (int,int) E;
var int? a;
var int  b;
(a,b) =
    watching E do
        await FOREVER;
    end;
escape a!+b;
]],
    stmts = 'line 4 : invalid `watching` assignment : expected option type `?` : got "int"',
}

Test { [[
input (int,int) E;
var int? a; var int? b;
(a,b) =
    watching E do
    end;
escape (a? as int) + (b? as int) + 1;
]],
    run = 1,
}

Test { [[
par/or do
    input (int,int) E;
    var int? a; var int? b;
    (a,b) =
        watching E do
            await FOREVER;
        end;
    escape a!+b!;
with
    await async do
        emit E(10,20);
    end
end
]],
    run = 30,
}

Test { [[
event int e;
par do
    var int? n =
        watching e do
            await FOREVER;
        end;
    escape n!;
with
    await 1s;
    emit e(10);
    await FOREVER;
end
]],
    run = { ['~>1001ms'] = 10 },
}

Test { [[
var int? n =
    watching 1s do
        escape 1;
    end;
escape n!;
]],
    run = { ['~>1001ms'] = 1 },
}

Test { [[
input none E;
event int e;
par do
    var int? n =
        watching e do
            await 300ms;
            escape 1;
        end;
    escape n!;
with
    await E;
    emit e(10);
    await FOREVER;
end
]],
    run = { ['~>1001ms'] = 1 },
}

Test { [[
event int e;
par do
    var int? n =
        watching e do
            await 300ms;
            escape 1;
        end;
    escape n!;
with
    await 1s;
    emit e(10);
    await FOREVER;
end
]],
    _ana = { acc=1 },
    run = { ['~>1001ms'] = 1 },
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
var int? v =
    watching I do
        await 1s;
        ret = 5;
    end;
if v? then
    ret = ret + v!;
end
escape ret;
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
event none e;
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

-- EMIT / SELF-ABORT
Test { [[
native _assert;
native/pre do
    ##include <assert.h>
end
input none I;
event none e; event none  f;
par do
    watching e do       // 5
        await I;        // 1
        emit f;         // 3, aborted on 5
        _assert(0);     // never executes
    end
    await I;
    escape 42;
with
    await f;            // 2
    emit e;             // 4, aborted on 5
    //_assert(0);         // never executes
    escape 99;
with
    await async do
        emit I;
        emit I;
    end
end
]],
    run = 99,
    --run = 42,
}

Test { [[
event none e;
loop do
    watching e do
        emit e;
        await FOREVER;
    end
end
]],
    wrn = true,
    _ana = {
        isForever = true,
        acc = true,
    },
    awaits = 1,
    run = false,
}

--<<< WATCHING

-->>> CODE / TIGHT / FUNCTIONS

Test { [[
code/tight Code (var int)->none
do
end
escape 1;
]],
    --wrn = true,
    --adj = 'line 1 : missing parameter identifier',
    --adjs = 'line 1 : invalid declaration : expected identifier',
    --adjs = 'line 1 : invalid declaration : parameter #1 : expected identifier',
    parser = 'line 1 : after `int` : expected type modifier or internal identifier',
}

Test { [[
code/tight Code (var int)->none;
escape 1;
]],
    --wrn = true,
    --adj = 'line 1 : missing parameter identifier',
    --adjs = 'line 1 : invalid declaration : expected identifier',
    --adjs = 'line 1 : invalid declaration : parameter #1 : expected identifier',
    parser = 'line 1 : after `int` : expected type modifier or internal identifier',
}

Test { [[
code/tight Code (var int x, var  int)->none
do
end
escape 1;
]],
    parser = 'line 1 : after `int` : expected type modifier or internal identifier',
    --adjs = 'line 1 : invalid declaration : expected identifier',
    --adjs = 'line 1 : invalid declaration : parameter #2 : expected identifier',
}

Test { [[
code/tight Code (var none, var  int x) -> none
do
end
escape 1;
]],
    parser = 'line 1 : after `none` : expected type modifier or internal identifier',
    --adjs = 'line 1 : invalid declaration : expected identifier',
    --adjs = 'line 1 : invalid declaration : parameter #1 : expected identifier',
    --parser = 'line 1 : after `int` : expected type modifier or `,` or `)`',
    --adj = 'line 1 : wrong argument #1 : cannot be `none`',
}

Test { [[
code/tight Code (var none, var  int) -> none
do
end
escape 1;
]],
    --wrn = true,
    --adj = 'line 1 : wrong argument #1 : cannot be `none`',
    --parser = 'line 1 : after `none` : expected type modifier or `;`',
    --adjs = 'line 1 : invalid declaration : parameter #1 : expected identifier',
    --adjs = 'line 1 : invalid declaration : expected identifier',
    parser = 'line 1 : after `none` : expected type modifier or internal identifier',
}

Test { [[
code/tight Code (var none a, var  int b) -> none
do
end
escape 1;
]],
    wrn = true,
    --adj = 'line 1 : wrong argument #1 : cannot be `none`',
    dcls = 'line 1 : invalid declaration : variable cannot be of type `none`',
    --dcls = 'line 1 : invalid declaration : unexpected type `none`',
}

Test { [[
code/tight Code (var int a)->none
    __ceu_nothing(&&a);
do
end
escape 1;
]],
    parser = 'line 1 : after `none` : expected type modifier or `do` or `;`',
}

Test { [[
code/tight Code (var int a)->none;
code/tight Code (var int a)->none
do
    //native/nohold ___ceu_nothing;
    //___ceu_nothing(&&a);
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Code (var none a)->none
do
end
escape 1;
]],
    wrn = true,
    dcls = 'line 1 : invalid declaration : variable cannot be of type `none`',
}

Test { [[
code/tight Code (var none a)->none
do
end
escape 1;
]],
    wrn = true,
    dcls = 'line 1 : invalid declaration : variable cannot be of type `none`',
}

Test { [[
code/tight Code (none)->none
do
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Abc(none) -> none do
    escape;
end
call Abc();
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
code/tight Code ()->none
do
end
escape 1;
]],
    parser = 'line 1 : after `(` : expected `var` or `pool` or `event`',
}

Test { [[
code/tight Code (var int xxx) -> int
do
    xxx = xxx + 1;
    escape xxx;
end
var int a = call Code(1);
var int b = call Code(a+10);
escape b;
]],
    run = 13,
}

Test { [[
code/tight Code (var int x) -> int
do
    x = x + 1;
    escape x;
end
var int a = call Code(1);
escape call Code(a+10);
]],
    run = 13,
}

Test { [[
code/tight Code (var int x) -> int
do
    x = x + 1;
    escape x;
end
var int a = call Code(1) + call Code(2);
escape call Code(a+10) + call Code(1);
]],
    run = 18,
}

Test { [[
code/tight Fx (var int v)->int do
    escape v+1;
end
escape call Fx();
]],
    dcls = 'line 4 : invalid call : expected 1 argument(s)',
}

Test { [[
code/tight Fx (var int v)->int do
    escape v+1;
end
var int&& ptr;
escape call Fx(ptr);
]],
    dcls = 'line 5 : invalid call : argument #1 : types mismatch : "int" <= "int&&"',
}

Test { [[
code/tight Fx (var int v)->int do
    escape v+1;
end
escape call Fx(1);
]],
    run = 2,
}

Test { [[
code/tight Fx (none);
escape 1;
]],
    parser = 'line 1 : after `)` : expected `->`',
}

Test { [[
code/tight Fx (none) -> none
escape 1;
]],
    parser = 'line 1 : after `none` : expected type modifier or `do` or `;`'
}

Test { [[
code/tight Fx (none) -> none;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Fx none -> (none);
escape 1;
]],
    wrn = true,
    parser = 'line 1 : after `Fx` : expected `(`',
    --parser = 'line 1 : after `Fx` : expected param list',
    --parser = 'line 1 : after `->` : expected type',
}

Test { [[
code/tight Fx (none) -> none;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Fx (var int) -> none do
    escape 1;
end
escape 1;
]],
    --wrn = true,
    --env = 'line 1 : missing parameter identifier',
    --parser = 'line 1 : after `none` : expected type modifier or `;`',
    --adjs = 'line 1 : invalid declaration : parameter #1 : expected identifier',
    --adjs = 'line 1 : invalid declaration : expected identifier',
    parser = 'line 1 : after `int` : expected type modifier or internal identifier',
}

Test { [[
code/tight Fx (none) -> none do
    event none i;
    emit i;
    await i;
end
escape 1;
]],
    wrn = true,
    props_ = 'line 3 : invalid `emit` : unexpected enclosing `code`',
    --props = 'line 3 : not permitted inside `function`',
}

Test { [[
code/tight Fx (none) -> none do
    event none i;
    await i;
    emit i;
end
escape 1;
]],
    wrn = true,
    props_ = 'line 3 : invalid `await` : unexpected enclosing `code`',
    --props = 'line 3 : not permitted inside `function`',
}

Test { [[
code/tight Fx (none) -> none do
    var int a = 1;
    if a!=0 then end;
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Fx (none) -> none do
    escape;
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Fx (none) -> none do
    escape 1;
end
escape 1;
]],
    wrn = true,
    --gcc = 'error: ‘escape’ with a value, in function returning none',
    --env = 'line 2 : invalid escape value : types mismatch (`none` <= `int`)',
    dcls = 'line 2 : invalid `escape` : unexpected expression',
}

Test { [[
code/tight Fx (none) -> none do
    escape;
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
do/_
    escape 1;
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
    stmts = 'line 2 : invalid assignment : unexpected context for event "a"',
    --env = 'types mismatch',
}

Test { [[
code/tight Fx (none)->int do
    escape 1;
end
escape call Fx();
]],
    run = 1,
}

Test { [[
code/tight Fx (none)->int do
    escape 1;
end
escape call Fx();
]],
    todo = 'call?',
    run = 1,
}

Test { [[
code/tight Fx (none) -> int;
code/tight Fx (var int x)  -> int do end
escape 1;
]],
    dcls = 'line 2 : invalid `code` declaration : unmatching prototypes (vs. /tmp/tmp.ceu:1)',
    --env = 'line 2 : function declaration does not match the one at "/tmp/tmp.ceu:1"',
    wrn = true,
}

Test { [[
code/tight Fx (none) -> int;
code/tight Fx (var int a)  -> int;
escape 1;
]],
    wrn = true,
    --env = 'line 2 : function declaration does not match the one at "/tmp/tmp.ceu:1"',
    --dcls = 'line 2 : identifier "Fx" is already declared',
    dcls = 'line 2 : invalid `code` declaration : unmatching prototypes (vs. /tmp/tmp.ceu:1)',
}

Test { [[
code/tight Fx (none) -> int;
code/tight Fx (none) -> int do escape 111; end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Fx (var none a, var int b) -> int;
escape 1;
]],
    dcls = 'line 1 : invalid declaration : variable cannot be of type `none`',
    --dcls = 'line 1 : invalid declaration : unexpected type `none`',
}

Test { [[
code/tight Fx (var int a) -> none;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Fx (var int a, var int b) -> int;
code/tight Fx (var int a, var  int b) -> int do
    escape a + b;
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Fx (var int a, var int b) -> int;
code/tight Fx (var int a, var  u8 b) -> int do
    escape a + b;
end
escape 1;
]],
    dcls = 'line 2 : invalid `code` declaration : unmatching prototypes (vs. /tmp/tmp.ceu:1)',
}

Test { [[
code/tight Fx (var int a, var int b) -> int;
code/tight Fx (var int a, var  int b) -> int do
    escape a + b;
end
escape call Fx(1,2);
]],
    run = 3,
}

Test { [[
code/tight Fx (var int a, var int b) -> int;
code/tight Fx (var int a, var  int b) -> int do
    escape a + b;
end
code/tight Fx (var int a, var  int b) -> int do
    escape a + b;
end
escape call Fx(1,2);
]],
    dcls = 'line 5 : invalid `code` declaration : body for "Fx" already exists',
}

Test { [[
code/tight Fff (var int x)->int do
    escape x + 1;
end

var int x = call Fff(10);

input none OS_START;
await OS_START;

escape call Fff(x);
]],
    run = 12,
}

Test { [[
escape 1;
code/tight Fx (var int x)->int do
    if x!=0 then end;
var int i;
    loop i in [0 -> 10[ do
    end
    escape 1;
end
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await Tx (none) -> int
do
    code/await Fx (var int a)->int do
        escape a;
    end
    var int y = await Fx(10);
    escape y;
end
var int x = await Tx();
escape x;
]],
    run = {['~>1s']=10},
}

Test { [[
code/await Tx (none) -> int
do
    code/await Fx (var int a)->int;
    code/await Fx (var int a)->int do
        escape a;
    end
    var int y = await Fx(10);
    escape y;
end
var int x = await Tx();
escape x;
]],
    _opts = { ceu_features_trace='true' },
    run = {['~>1s']=10},
}

Test { [[
code/await Tx (none) -> int
do
    code/tight Fx (var int a)->int;
    code/tight Fx (var int a)->int do
        escape a;
    end
    escape call Fx(10);
end
var int x = await Tx();
escape x;
]],
    run = {['~>1s']=10},
}

Test { [[
escape 1;
code/tight Fx (none) -> int do
    escape 1;
end
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Fx (none) -> int do
    escape 1;
end
escape 1;
]],
    wrn = true,
    props = 'line 2 : not permitted across function declaration',
}

Test { [[
code/tight Set (var u8&& v)->none do
    *v = 3;
end
var u8 v = 0;
call Set(&&v);
escape v as int;
]],
    run = 3,
}

Test { [[
code/tight Set (var& u8 v)->none do
    v = 3;
end
var u8 v = _;
call Set(&v);
escape v as int;
]],
    wrn = true,
    run = 3,
}

Test { [[
code/tight Set (var u8 v)->int do
    escape 3;
end
var u8 v = call Set(_);
escape v as int;
]],
    dcls = 'line 1 : variable "v" declared but not used',
}

Test { [[
code/tight Set (var u8 v)->int do
    escape 3;
end
var u8 v = call Set(_);
escape v as int;
]],
    wrn = true,
    run = 3,
}

Test { [[
code/tight Set (var& u8 v)->none do
    v = 3;
end
var u8 v = 0;
call Set(_);
escape v as int;
]],
    dcls = 'line 5 : invalid call : invalid binding : argument #1 : expected location',
    --dcls = 'line 5 : invalid constructor : argument #1 : unexpected `_`',
}

Test { [[
code/tight Ff (var& int a)->none do
    a = 1;
end
var int v = 0;
call Ff(v);
escape v;
]],
    dcls = 'line 5 : invalid call : invalid binding : argument #1 : unexpected context for variable "v"',
}

Test { [[
code/tight Fx (var int x)->int do
    escape x + 1;
end

if true then
    escape call Fx(1);
else
    escape 0;
end
]],
    run = 2,
}

Test { [[
code/tight Fx (var int x)->int;
var int x = 0;
code/tight Fx (var int x)->int do
    this.x = x;
    escape 2;
end
escape call Fx(1) + this.x;
]],
    todo = 'globals',
    run = 3,
}

Test { [[
code/tight Code (var int a)->none;
code/tight Code (var int a)->none
do
    escape 1;
end
escape 1;
]],
    wrn = true,
    dcls = 'line 4 : invalid `escape` : unexpected expression',
    run = 1,
}

Test { [[
code/tight get (none)->int&& do
    var int x;
    escape &&x;
end
escape 10;
]],
    parser = 'line 1 : after `/tight` : expected `/dynamic` or `/recursive` or abstraction identifier',
    --ref = 'line 3 : invalid access to uninitialized variable "x" (declared at /tmp/tmp.ceu:2)',
}

Test { [[
code/tight Fx.Fx (none)->none do
end
]],
    parser = 'line 1 : after `/tight` : expected `/dynamic` or `/recursive`',
}

Test { [[
code/tight Get (none)->int&& do
    var int x;
    //escape &&x;
end
escape 10;
]],
    wrn = true,
    --inits = 'line 2 : uninitialized variable "x" : reached `end of code` (/tmp/tmp.ceu:5)',
    --inits = 'line 2 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:5)',
    run = 10,
}

Test { [[
code/tight Get (none)->int&& do
    var int x;
    escape null;
end
escape 10;
]],
    wrn = true,
    --inits = 'line 2 : uninitialized variable "x" : reached `escape` (/tmp/tmp.ceu:3)',
    run = 10,
}

Test { [[
code/tight Get (none)->int&& do
    var int x=0;
    escape &&x;
end
escape 10;
]],
    wrn = true,
    scopes = 'line 3 : invalid `escape` : incompatible scopes',
    --fins = 'line 3 : invalid escape value : local reference',
    --ref = 'line 3 : invalid access to uninitialized variable "x" (declared at /tmp/tmp.ceu:2)',
}

Test { [[
code/tight Get (none)->int& do
    var int x=1;
    escape &x;
end
escape 10;
]],
    wrn = true,
    parser = 'line 1 : after `int` : expected type modifier or `do` or `;`',
    --env = 'line 3 : invalid escape value : local reference',
    --ref = 'line 3 : attribution to reference with greater scope',
}

Test { [[
var[] byte str = [0,1,2];

code/tight Fx (var&[] byte vec)->int do
    escape vec[1];
end

escape Fx(&str);
]],
    parser = 'line 7 : after `escape` : expected expression or `;`',
}

Test { [[
code/tight Ff (var none&& p1, var none&& p2)->none do
end
var int x = 0;
do
    var int y = 0;
    call Ff(&&x, &&y);
end
escape 0;
]],
    wrn = true,
    tmp = 'TODO: incomp. scopes',
}

Test { [[
code/tight GetVS (var none&& && o1, var  none&& && o2)->int do
    if (*o1!=null) then
        escape 1;
    else/if (*o2!=null) then
        var none&& tmp = *o1;
        *o1 = *o2;
        do
            *o2 = tmp;
        finalize (tmp) with
        end
            // tmp is an alias to "o1"
        escape 1;
    else
        //*o1 = NULL;
        //*o2 = NULL;
        escape 0;
    end
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Fx (var int a, var  none b)->int do
end
escape 1;
]],
    wrn = true,
    dcls = 'line 1 : invalid declaration : variable cannot be of type `none`',
    --dcls = 'line 1 : invalid declaration : unexpected type `none`',
}

Test { [[
code/tight Fx (var none, var int b)->int do
end
escape 1;
]],
    parser = 'line 1 : after `none` : expected type modifier or internal identifier',
    --parser = 'line 1 : after `int` : expected type modifier or `;`',
    --adjs = 'line 1 : invalid declaration : parameter #1 : expected identifier',
}

Test { [[
code/tight Fx (var none a, var  int v)->int do
end
escape 1;
]],
    wrn = true,
    dcls = 'line 1 : invalid declaration : variable cannot be of type `none`',
    --dcls = 'line 1 : invalid declaration : unexpected type `none`',
}

Test { [[
code/tight Fx (var u8 v)->int do
    escape v as int;
end
var s8 i = 0;
escape call Fx(i);
]],
    dcls = 'line 5 : invalid call : argument #1 : types mismatch : "u8" <= "s8"',
}

Test { [[
native/pos do
    int V;
end
native _V;
code/tight Fx (var int v)->none do
    _V = v;
end
var none&& x=null;
call Fx(5);
escape (_V==5) as int;
]],
    run = 1,
}

Test { [[
spawn () do
    code/tight Ff (none) -> none do end
    await FOREVER;
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Ff (var& int x) -> int do
    escape x + 1;
end
escape call Ff(&1);
]],
    run = 1,
    dcls = 'line 4 : invalid binding : unexpected context for value "1"',
    --todo = 'support aliases to constants',
}

Test { [[
code/tight Ff (none) -> int do
    loop do
        if true then
            break;
        end
    end
    escape 10;
end

var int x = call Ff();
escape x;
]],
    wrn = true,
    run = 10,
}

Test { [[
code/tight Test (var int a) -> int do
    var int ret = 0;
    loop do
        if a < 1 then break; end
        a = a - 1;
        ret = ret + 1;
    end
    escape ret;
end
var int ret = call Test(3);
escape ret;
]],
    wrn = true,
    run = 3,
}
-->>> RECURSIVE

Test { [[
code/tight/recursive Fx (none)->none;
code/tight/recursive Fx (none)->none do end
code/tight Gx      (none)->none;
code/tight/recursive Gx (none)->none do end
escape 1;
]],
    wrn = true,
    --env = 'line 4 : function declaration does not match the one at "/tmp/tmp.ceu:3"',
    dcls = 'line 4 : invalid `code` declaration : unmatching prototypes (vs. /tmp/tmp.ceu:3)',
}
Test { [[
code/tight/recursive Fx (none)->none;
code/tight/recursive Fx (none)->none do end
code/tight/recursive Gx (none)->none;
code/tight Gx      (none)->none do end
escape 1;
]],
    wrn = true,
    --env = 'line 4 : function declaration does not match the one at "/tmp/tmp.ceu:3"',
    dcls = 'line 4 : invalid `code` declaration : unmatching prototypes (vs. /tmp/tmp.ceu:3)',
}
Test { [[
//var int x;

code/tight/recursive Fa (none)->none;
code/tight/recursive Fb (none)->none;

code/tight/recursive Fa (none)->none do
    if false then
        call/recursive Fb();
    end
end

code/tight/recursive Fb (none)->none do
    call/recursive Fa();
end

call/recursive Fa();

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/tight Ff (none) -> int;
var int ret = call Ff();
code/tight Ff (none) -> int do
    escape 1;
end
escape ret;
]],
    --run = 1,
    tight_ = 'line 1 : invalid `code` declaration : expected `/recursive` : `call` to unknown body (/tmp/tmp.ceu:2)',
}

Test { [[
//var int x;

code/tight Fa (none)->none;
code/tight Fb (none)->none;

code/tight Fa (none)->none do
    call Fb();
end

code/tight Fb (none)->none do
end

call Fa();

escape 1;
]],
    tight_ = 'line 4 : invalid `code` declaration : expected `/recursive` : `call` to unknown body (/tmp/tmp.ceu:7)',
}

Test { [[
//var int x;

code/tight Fa (none)->none;
code/tight Fb (none)->none;

code/tight Fb (none)->none do
end

code/tight Fa (none)->none do
    call Fb();
end

call Fa();

escape 1;
]],
    run = 1,
}

Test { [[
//var int x;

code/tight Fa (none)->none;
code/tight Fb (none)->none;

code/tight Fa (none)->none do
    call Fb();
end

code/tight Fb (none)->none do
    call Fa();
end

call Fa();

escape 1;
]],
    tight_ = 'line 4 : invalid `code` declaration : expected `/recursive` : `call` to unknown body (/tmp/tmp.ceu:7)',
    --tight = 'line 10 : function must be annotated as `@rec` (recursive)',
}

Test { [[
//var int x;

code/tight Fa (none)->none;
code/tight/recursive Fb (none)->none;

code/tight Fa (none)->none do
    if false then
        call/recursive Fb();
    end
end

code/tight/recursive Fb (none)->none do
    call Fa();
end

call Fa();

escape 1;
]],
    tight_ = 'line 6 : invalid `code` declaration : expected `/recursive` : nested `call/recursive` (/tmp/tmp.ceu:8)',
    --tight = 'line 3 : function must be annotated as `@rec` (recursive)',
}

Test { [[
code/tight/recursive Fx (var int v)->int;
code/tight Fx (var int v)->int do
    if v == 0 then
        escape 1;
    end
    escape v*call Fx(v-1);
end
escape call Fx(5);
]],
    dcls = 'line 2 : invalid `code` declaration : unmatching prototypes (vs. /tmp/tmp.ceu:1)',
    --env = 'line 2 : function declaration does not match the one at "/tmp/tmp.ceu:1"',
    --run = 120,
}
Test { [[
code/tight/recursive Fx (var int v)->int;
code/tight/recursive Fx (var int v)->int do
    if v == 0 then
        escape 1;
    end
    escape v*call Fx(v-1);
end
escape call Fx(5);
]],
    tight_ = 'line 6 : invalid `call` : expected `/recursive` : `call` to unknown body',
    --tight = 'line 6 : `call/recursive` is required for "Fx"',
    --run = 120,
}
Test { [[
1;
]],
    --run = 1,
    stmts = 'line 1 : invalid call',
    --parser = 'line 1 : after `call` : expected external identifier or location',
    --env = 'TODO: not a call',
    --ast = 'line 1 : invalid call',
    --env = 'TODO: 1 not func',
    --parser = 'line 1 : after `1` : expected <h,min,s,ms,us>',
}

Test { [[
call 1;
]],
    --run = 1,
    stmts = 'line 1 : invalid call',
    --parser = 'line 1 : after `call` : expected external identifier or location',
    --env = 'TODO: not a call',
    --ast = 'line 1 : invalid call',
    --env = 'TODO: 1 not func',
    --parser = 'line 1 : after `1` : expected <h,min,s,ms,us>',
}

Test { [[
code/tight/recursive Fx (var int v)->int;
code/tight/recursive Fx (var int v)->int do
    if v == 0 then
        escape 1;
    end
    escape v * (call/recursive Fx(v-1));
end
escape call Fx(5);
]],
    tight_ = 'line 8 : invalid `call` : expected `/recursive`',
    --tight = 'line 8 : `call/recursive` is required for "Fx"',
}
Test { [[
code/tight Fx (var int v)->int do
    escape v + 1;
end
escape call/recursive Fx(5);
]],
    tight_ = 'line 4 : invalid `call` : unexpected `/recursive`',
    --tight = 'line 8 : `call/recursive` is required for "Fx"',
}
Test { [[
code/tight/recursive Fx (var int v)->int;
code/tight/recursive Fx (var int v)->int do
    if v == 0 then
        escape 1;
    end
    escape v * call/recursive Fx(v-1);
end
escape call/recursive Fx(5);
]],
    run = 120,
}

Test { [[
code/tight/recursive Fat (var int v) -> int;
code/tight/recursive Fat (var int v) -> int do  // "Fat" is a recursive code
    if v > 1 then
        escape v * (call/recursive Fat(v-1));
    else
        escape 1;
    end
end
escape (call/recursive Fat(10) == 3628800) as int;
]],
    run = 1,
}

Test { [[
code/tight/recursive Gg (none) -> none do
    call/recursive Gg();
end
code/await Ff (none) -> none do
    call/recursive Gg();
end
escape 1;
]],
    wrn = true,
    run = 1,
}

--<<< RECURSIVE

-->> VECTOR / CODE

Test { [[
var[] byte str = [0,1,2];

code/tight Fx (var[] byte vec)->int do
    escape vec[1];
end

escape call Fx(&str);
]],
    _opts = { ceu_features_dynamic='true' },
    --parser = 'line 3 : after `vector` : expected `&`',
    dcls = 'line 3 : invalid declaration : vector inside `code/tight`',
}
Test { [[
var[] byte str = [0,1,2];

code/tight Fx (var&[] byte vec)->int do
    escape vec[1];
end

escape call Fx(&str);
]],
    _opts = { ceu_features_dynamic='true' },
    wrn = true,
    --stmts = 'line 4 : invalid assignment : types mismatch : "int" <= "byte"',
    run = 1,
}
Test { [[
var[] byte str = [0,1,2];

code/tight Fx (var&[] byte vec)->int do
    escape vec[1] as int;
end

escape call Fx(&str);
]],
    _opts = { ceu_features_dynamic='true' },
    wrn = true,
    run = 1,
}
Test { [[
var[1] byte str = [0,1,2];

code/tight Fx (var&[2] byte&& vec)->int do
    escape vec[1] as int;
end

escape call Fx(&&str);
]],
    dcls = 'line 7 : invalid call : invalid binding : argument #1 : unexpected context for value "str"',
}
Test { [[
var[1] byte str = [0,1,2];

code/tight Fx (var&[2] byte vec)->int do
    escape vec[1] as int;
end

escape call Fx(&str);
]],
    dcls = 'line 7 : invalid call : invalid binding : argument #1 : dimension mismatch',
}
Test { [[
var  byte v1 = 0;
var& int v2;
v2 = &v1;
escape v2;
]],
    stmts = 'line 3 : invalid binding : types mismatch : "int" <= "byte"',
    --run = 1,
}
Test { [[
var[]  byte v1 = [0,1,2];
var&[] int v2;
v2 = &v1;
escape v2[1];
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 3 : invalid binding : types mismatch : "int" <= "byte"',
    --run = 1,
}
Test { [[
var[] byte str = [0,1,2];

code/tight Fx (var&[] int vec)->int do
    escape vec[1];
end

escape call Fx(&str);
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 7 : invalid call : argument #1 : types mismatch : "int" <= "byte"',
    --run = 1,
}
Test { [[
var[] byte str = [0,1,2];

code/tight Fx (var&[] byte vec)->bool do
    escape vec[1];
end

escape call Fx(&str);
]],
    _opts = { ceu_features_dynamic='true' },
    wrn = true,
    stmts = 'line 4 : invalid `escape` : types mismatch : "bool" <= "byte"',
    --env = 'line 7 : wrong argument #1 : types mismatch (`int` <= `byte`)',
}
Test { [[
var[] byte str = [0,1,2];

code/tight Fx (var&[] byte vec)->int do
    escape vec[1];
end

escape call Fx(str);
]],
    _opts = { ceu_features_dynamic='true' },
    wrn = true,
    --ref = 'line 7 : invalid attribution : missing alias operator `&`',
    dcls = 'line 7 : invalid call : invalid binding : argument #1 : unexpected context for vector "str"',
}
Test { [[
var[] byte str = [0,1,2];

code/tight Fx (none) -> byte[] do
    escape &this.str;
end

var&[] byte ref = &call Fx();

escape ref[1];
]],
    parser = 'line 3 : after `byte` : expected type modifier or `do` or `;`',
    --env = 'line 4 : invalid escape value : types mismatch (`byte[]` <= `byte[]&`)',
}

-- vectors as argument (NO)
Test { [[
var[] byte str = [0,1,2];

code/tight Fx (var none&& x, var[] int vec)->int do
    escape vec[1];
end

escape call Fx(str);
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 3 : invalid declaration : vector inside `code/tight`',
    --parser = 'line 3 : after `vector` : expected `&`',
    --env = 'line 3 : wrong argument #2 : vectors are not supported',
    --env = 'line 7 : wrong argument #1 : types mismatch (`int[]` <= `byte[]`)',
}

Test { [[
code/tight FillBuffer (var&[] u8 buf)->none do
    buf = buf .. [3];
end
var[10] u8 buffer;
call FillBuffer(&buffer);
escape buffer[0] as int;
]],
    run = 3,
}

Test { [[
code/tight FillBuffer (var&[20] u8 buf)->none do
    buf = buf .. [3];
end
var[10] u8 buffer;
call FillBuffer(&buffer);
escape buffer[0] as int;
]],
    dcls = 'line 5 : invalid call : invalid binding : argument #1 : dimension mismatch',
    --tmp = 'line 5 : wrong argument #1 : types mismatch (`u8[]&` <= `u8[]&`) : dimension mismatch',
}

Test { [[
code/tight FillBuffer (var&[3] u8 buf)->none do
    buf = buf .. [2,3,4];
end
var[3] u8 buffer = [1];
call FillBuffer(&buffer);
escape buffer[0] as int;
]],
    run = '2] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
}

-- TODO: dropped support for pointers to vectors
Test { [[
code/tight FillBuffer (var[]&& u8 buf)->none do
    *buf = *buf .. [3];
end
var[10] u8 buffer;
call FillBuffer(&&buffer);
escape buffer[0] as int;
]],
    run = 3,
    todo = 'no pointers to vectors',
}

Test { [[
code/tight FillBuffer (var[3]&& u8 buf)->none do
    *buf = *buf .. [2,3,4];
end
var[3] u8 buffer = [1];
call FillBuffer(&&buffer);
escape buffer[0] as int;
]],
    run = '2] -> runtime error: access out of bounds',
    _opts = { ceu_features_trace='true' },
    todo = 'no pointers to vectors',
}

Test { [[
code/tight Build (var[] u8 bytes)->none do
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 1 : invalid declaration : vector inside `code/tight`',
    --wrn = true,
    --parser = 'line 1 : after `vector` : expected `&`',
    --env = 'line 1 : wrong argument #1 : vectors are not supported',
}

Test { [[
var[] byte str = [0,1,2];

code/tight Fx (none) -> byte[]& do
    escape &this.str;
end

var&[] byte ref = &f();

escape ref[1];
]],
    parser = 'line 3 : after `byte` : expected type modifier or `do` or `;`',
    --run = 1,
}

Test { [[
var[] byte str = [0,1,2];

code/tight Fx (none) -> byte[]& do
    escape &this.str;
end

var&[] byte ref = &f();
ref = [3, 4, 5];

escape str[1];
]],
    parser = 'line 3 : after `byte` : expected type modifier or `do` or `;`',
    --run = 4,
}

Test { [[
var[] byte str = [0,1,2];

code/tight Fx (none) -> byte[]& do
    escape &this.str;
end

var&[] byte ref = &f();
ref = [] .. "ola";

escape str[1] == 'l';
]],
    parser = 'line 3 : after `byte` : expected type modifier or `do` or `;`',
    --run = 1,
}

Test { [[
var[] byte str = [0,1,2];

native/pos do
    byte* g () {
        escape "ola";
    }
end

code/tight Fx (none) -> byte[]& do
    escape &this.str;
end

var&[] byte ref = &f();
native _char;
ref = [] .. ({g}() as _char&&) .. "ola";

escape str[3] == 'o';
]],
    --run = 1,
    parser = 'line 9 : after `byte` : expected type modifier or `do` or `;`',
}

Test { [[
var[] byte str;

code/tight Fa (none)->byte[]& do
    escape &this.str;
end

code/tight Fb (none)->none do
    var&[] byte ref = &f1();
    ref = [] .. "ola" .. "mundo";
end

f2();

escape str[4] == 'u';
]],
    parser = 'line 3 : after `byte` : expected type modifier or `do` or `;`',
    --run = 1,
}

Test { [[
native/pure _strlen;
code/tight Strlen (var byte&& str)->int do
    escape _strlen(str as _char&&);
end

var[] byte str = [].."Ola Mundo!";
escape call Strlen(&&str[0]);
]],
    _opts = { ceu_features_dynamic='true' },
    --env = 'line 6 : wrong argument #1 : types mismatch (`byte&&` <= `byte[]&&`)',
    run = 10,
}

Test { [[
native _char, _strlen;
code/tight Strlen (var byte&& str)->int do
    escape _strlen(str[0]);
end

var[] byte str = [].."Ola Mundo!";
escape call Strlen((&&str[0]) as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 3 : invalid vector : unexpected context for variable "str"',
    --run = 10,
}

Test { [[
code/tight Fx (none)->none do
    var int x = 0;

    var[10] byte cs;
end
escape 1;
]],
    dcls = 'line 4 : invalid declaration : vector inside `code/tight`',
    --wrn = true,
    --props = 'line 4 : not permitted inside `function`',
    --props_ = 'line 4 : invalid `await` : unexpected enclosing `code`',
}

Test { [[
code/tight Fx (var&[] byte cs)->none do
    cs[0] = 10;
end
var[] byte cs = [0];
call Fx(&cs);
escape cs[0];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 10,
}

--<< VECTOR / CODE

Test { [[
code/tight Rect (none) -> none
do
end
await Rect();

escape 0;
]],
    --dcls = 'line 4 : invalid declaration : option alias : expected native or `code/await` type',
    --stmts = 'line 4 : invalid `spawn` : expected `code/await` declaration (/tmp/tmp.ceu:1)',
    stmts = 'line 4 : invalid `await` : expected `code/await` declaration (/tmp/tmp.ceu:1)',
}

-->> CODE / ALIAS / FINALIZE

Test { [[
native _void;
code/tight Ff (none) -> none do
end
var&? _void ptr = & call Ff()
        finalize (ptr) with
        end;
escape 0;
]],
    --stmts = 'line 4 : invalid binding : expected native type',
    stmts = 'line 4 : invalid binding : types mismatch : "_void" <= "none"',
}

Test { [[
native _V, _void, _f;
native/pre do
    int V;
    none* f (int x) {
        return NULL;
    }
end

do
    var&? _void ptr = & _f(true)
            finalize (ptr) with
                _V = 2;
            end;
    _V = 1;
end
escape _V;
]],
    run = 2,
}
Test { [[
native _void, _f;
native/pre do
    int V;

    none* f (int x) {
        if (x) {
            return &V;
        } else {
            return NULL;
        }
    }
end

var int ret = 1;

do
    var&? _void ptr = & _f(true)
            finalize (ptr) with
                ret = ret * 2;
            end;
    ret = ret + (ptr? as int);
end

do
    var&? _void ptr = & _f(false)
            finalize (ptr) with
                ret = ret + 3;
            end;
    ret = ret + (ptr? as int);
end

escape ret;
]],
    run = 7,
}

Test { [[
native _V, _void;
native/pre do
    int V;
end

code/tight Ff (var bool x) -> _void&& do
    if x then
        escape &&_V;
    else
        escape null;
    end
end

var int ret = 1;

do
    var&? _void ptr = & call Ff(true)
            finalize (ptr) with
                ret = ret * 2;
            end;
    ret = ret + (ptr? as int);
end

do
    var&? _void ptr = & call Ff(false)
            finalize (ptr) with
                ret = ret + 3;
            end;
    ret = ret + (ptr? as int);
end

escape ret;
]],
    run = 7,
}

--<< CODE / ALIAS / FINALIZE

--<<< CODE / TIGHT / FUNCTIONS

-->>> CODE / AWAIT

Test { [[
code/await F (none)->none
do
    escape 1;
end
escape 1;
]],
    parser = 'line 1 : after `/await` : expected `/dynamic` or `/recursive` or abstraction identifier',
}

Test { [[
code/await Fx (none)->none
do
    escape 1;
end
escape 1;
]],
    wrn = true,
    dcls = 'line 3 : invalid `escape` : unexpected expression',
    --stmts = 'line 3 : invalid assignment : types mismatch : "none" <= "int"',
    --adj = 'line 3 : invalid `escape`',
    run = 1,
}

Test { [[
code/await Tx (var int x)->none
do
end
escape 1;
]],
    wrn = true,
    --cc = '1:9: error: unused variable ‘__ceu_x_1’ [-Werror=unused-variable]',
    run = 1,
}
Test { [[
code/await Tx (var int x)->none
do
    if x!=0 then end;
end
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
code/await Tx (var int x)->none
do
    var int v;
end

native/pos do
    int V = sizeof(CEU_T);
end

native _V;
var Tx t;
escape _V;
]],
    todo = 'recalculate',
    run = 8,    -- 2/2 (trl0) 0 (x) 4 (y)
}

Test { [[
code/await Tx (none)->none do end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await Tx (var int x)->none
do
    var int v;
end

native/pos do
    int V = sizeof(CEU_T);
end
native _V;
escape _V;
]],
    todo = 'recalculate',
    run = 8,
}

Test { [[
code/await Tx (var int a)->none
do
end

native/plain _TCEU_T;
var _TCEU_T t = _TCEU_T();
t.a = 1;
escape t.a;
]],
    wrn = true,
    cc = 'error: unknown type name ‘TCEU_T’',
    --run = 1,
}

Test { [[
call TestX(5);
escape 0;
]],
    dcls = 'line 1 : abstraction "TestX" is not declared',
}

Test { [[
code/await Tx (none)->none do end
call Tx();
escape 1;
]],
    dcls = 'line 2 : invalid call : expected `code/tight` : got `code/await` (/tmp/tmp.ceu:2)',
}

Test { [[
code/await Tx (none)->none do end
await Tx();
escape 1;
]],
    run = 1,
}

Test { [[
native/pre do
    ##include <stdio.h>
end
code/await Tx (none)->int do
    escape 10;
end
var int ret = await Tx();
escape ret;
]],
    run = 10,
}

Test { [[
code/await Tx (none)->none do end
par/or do
    await Tx();
with
    await Tx();
end

input none OS_START;
await OS_START;

escape 1;
]],
    run = 1,
}

Test { [[
native _SDL_MouseButtonEvent;
input _SDL_MouseButtonEvent&& SDL_MOUSEBUTTONUP;
code/await Tx (none)->none do
    var _SDL_MouseButtonEvent&& but = await SDL_MOUSEBUTTONUP;
end
await FOREVER;
]],
    dcls = 'line 3 : code "Tx" declared but not used',
}

Test { [[
native _SDL_MouseButtonEvent;
input _SDL_MouseButtonEvent&& SDL_MOUSEBUTTONUP;
code/await Tx (none)->none do
    var _SDL_MouseButtonEvent&& but = await SDL_MOUSEBUTTONUP;
end
await FOREVER;
]],
    --run = 1,
    wrn = true,
    cc = 'error: unknown type name ‘SDL_MouseButtonEvent’',
    _ana = {
        isForever = true,
    },
}

Test { [[
code/await Tx (none)->none do
    await FOREVER;
end

var Tx t;

await 1s;

escape 1;
]],
    dcls = 'line 5 : invalid declaration : unexpected context for `code` "Tx"',
    wrn = true,
    run = { ['~>1s'] = 1 },
}

Test { [[
native/pos do
    int V = 1;
end
native _V;

code/await Xx (none)->none do
    every 1s do
        _V = _V + 1;
    end
end

event bool pse;
par/or do
    pause/if pse do
        par do
            await Xx();
        with
            await Xx();
        end
    end
with
    emit pse(true);
    await 5s;
end

escape _V;
]],
    _opts = { ceu_features_pause='true' },
    _ana = {acc=true},
    run = {['~>5s']=1},
}

Test { [[
code/await Code (var int x) -> int
do
    await async do end;
    escape x;
end
var int a = await Code(1);
escape a;
]],
    run = 1,
}

Test { [[
code/await Code (var int x) -> int
do
    x = x + 1;
    await 1s;
    x = x + 1;
    escape x;
end
var int a = await Code(1);
escape a;
]],
    run = { ['~>1s']=3 },
}

Test { [[
code/await Fy (none) -> int do
    escape 1;
end

code/await Fx (var int x) -> int do
    var int y = await Fy();
    escape x;
end

var int x = await Fx(10);

escape x;
]],
    wrn = true,
    run = 10,
}

Test { [[
code/await Fy (var int x) -> int do
    escape x + 1;
end

code/await Fx (var int x) -> int do
    var int y = await Fy(x);
    escape y + 1;
end

var int x = await Fx(10);

escape x;
]],
    run = 12,
}

Test { [[
every do
end
]],
    --parser = 'line 1 : after `every` : expected location or external identifier or number',
    parser = 'line 1 : after `every` : expected location or `{` or `(` or external identifier or number',
}
Test { [[
every Code(1) do
end
]],
    parser = 'line 1 : after `every` : expected location or `{` or `(` or number',
    --parser = 'line 1 : after `every` : expected location or number',
}
Test { [[
code/await Code (none)->none;
await Code(1) until true;
]],
    parser = 'line 2 : after `)` : expected `;`',
}
Test { [[
await 1s until true;
]],
    parser = 'line 1 : after `s` : expected number or `/_` or `;`',
}
Test { [[
code/await Code (var int x) -> int
do
    var int xx = x + 1;
    await 1s;
    escape xx+1;
end
var int a = await Code(1);
escape a;
]],
    run = { ['~>1s']=3 },
}
Test { [[
native _X;
native/pos do
    int X = 0;
end
code/await Code (var int x) -> int
do
    var int xx = x + 1;
    await 1s;
    _X = xx + 1;
    escape xx+1;
end
await Code(1);
escape _X;
]],
    run = { ['~>1s']=3 },
}

Test { [[
code/await Code (var int x) -> int
do
    x = x + 222;
    await 1s;
    escape x;
end
par do
    var int a = await Code(111);
    escape a;
with
    escape 99;
end
]],
    _ana = {acc=1},
    run = 99,
}

Test { [[
code/await Code (var int x) -> int
do
    x = x + 1;
    await 1s;
    escape x;
end
par do
    var int a = await Code(10);
    escape a;
with
    await 5s;
    escape 1;
end
]],
    run = {['~>1s']=11 },
}

Test { [[
code/await Tx (none)->none do
end
event Tx a;
escape 0;
]],
    dcls = 'line 3 : invalid declaration : unexpected context for `code` "Tx"',
}

Test { [[
code/await Tx (none)->none do end
var Tx a = 1;
escape 0;
]],
    dcls = 'line 2 : invalid declaration : unexpected context for `code` "Tx"',
}

Test { [[
code/await Tx (none)->none;
code/await Tx (none)->none do
    await Tx();
end
escape 1;
]],
    stmts = 'line 3 : invalid `await` : unexpected recursive invocation',
    --run = 1,
}
Test { [[
code/await Tx (none)->none do
    await Tx();
end
await Tx();
escape 0;
]],
    wrn = true,
    stmts = 'line 2 : invalid `await` : unexpected recursive invocation',
    --stmts = 'line 2 : invalid `spawn` : unexpected recursive invocation',
    --dcls = 'line 2 : abstraction "Tx" is not declared',
}
Test { [[
code/await Tx (none)->none;
code/await Tx (none)->none do
end
await Tx();
await Tx();
escape 1;
]],
    run = 1,
}

Test { [[
code/await Tx (none)->none;
code/await Tx (none)->none do
    spawn Tx();
end
spawn Tx();
escape 0;
]],
    wrn = true,
    stmts = 'line 3 : invalid `spawn` : unexpected recursive invocation',
    --dcls = 'line 2 : abstraction "Tx" is not declared',
}

Test { [[
input none A;

code/await Rect (none) -> none do
    par/or do
        await A;
    with
        await FOREVER;
    end
end

par/or do
    await async do
        emit A;
    end
with
    await Rect();
with
    await Rect();
with
    await A;
end

escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> none do
end
var int i;
loop i in [0 -> 10[ do
    await Ff();
    await 1s;
end
escape 1;
]],
    run = { ['~>100s'] = 1 },
}

Test { [[
code/await Play (none) -> none do
    await async do end;
end

par/or do
    await async do end;
with
    await Play();
end

await Play();

escape 1;
]],
    run = { ['~>2s']=1 },
}

Test { [[
input none A;

code/await Play (none) -> none do
    await A;
end

par/or do
    await A;
with
    await Play();
end

await Play();

escape 1;
]],
    run = { ['~>A;~>A']=1 },
}

Test { [[
code/await Play (none) -> none do
    await 1s;
end

par/or do
    await 1s;
with
    await Play();
end

escape 1;
]],
    run = { ['~>1s']=1 },
}

Test { [[
code/await Play (none) -> none do
    await 1s;
end

par/or do
    await 1s;
with
    await Play();
end

await Play();

escape 1;
]],
    run = { ['~>2s']=1 },
}

Test { [[
code/await Scene (none) -> none
do
    par do
        await async do
            loop do
            end
        end
    with
        await FOREVER;
    end
end

code/await Play (none) -> none
do
    await 1s;
end

watching Scene() do
    watching 1s do
        par/or do
            await Play();
        with
            await 100ms;
        end
    end
    await Play();
end

escape 1;
]],
    run = { ['~>10s']=1 },
}

Test { [[
code/await Ff (none)->none do
    par/and do
    with
    with
    with
    with
    end
end

var int i;
loop i in [0 -> 10[ do
    await 1s;
    var[] byte string = [] .. "Alo mundo!\n";
    await Ff();
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    run = { ['~>20s']=1 },
}

Test { [[
code/await Ff (var int&& ptr) -> none do
end
var int v = 0;
var int&& ptr = &&v;
await Ff(ptr);
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await Ff (var int&& ptr) -> none do
end
var int v = 0;
var int&& ptr = &&v;
spawn Ff(ptr);
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
par/or do
with
end
//await async do end;
code/await Ff (none)->NEVER do
    await FOREVER;
end
spawn Ff();
escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> none do
    var int trails=0;
    var int mem=0;
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await Ff (none) -> none;

code/await Ff (none) -> none do
    {ceu_assert(_ceu_mem->trails_n == 5, "erro");}
    par/or do
    with
    end
end

await Ff();
escape 1;
]],
    run = 1,
}

Test { [[
code/await Xxx (var u32 freq, var u8 byte_order, var u8 mode) -> NEVER do
    par/or do with end
    await FOREVER;
end

spawn do
    await async do
        emit 1min;
    end
end

var int ret = 0;

var byte i;
loop i in [0->10[ do
    watching Xxx(1400000, 10, 10) do
        await 1s;
        ret = ret + 1;
    end
    await 1s;
end

escape ret;
]],
    wrn = true,
    run = 10,
}

Test { [[
var int? x = _;
escape 10;
]],
    wrn = true,
    run = 10,
}

Test { [[
code/await Xxx (var int? csn) -> none do
end

await Xxx(_);

escape 10;
]],
    wrn = true,
    run = 10,
}

Test { [[
code/await Xxx (var u32 freq, var u8 byte_order, var u8 mode, var int? cs, var int? csn) -> NEVER do
    par/or do with end
    await FOREVER;
end

spawn do
    await async do
        emit 1min;
    end
end

var int ret = 0;

var byte i;
loop i in [0->10[ do
    watching Xxx(1400000, 10, 10, _, _) do
        await 1s;
        ret = ret + 1;
    end
    await 1s;
end

escape ret;
]],
    wrn = true,
    run = 10,
}

-->> CODE / ALIAS

Test { [[
code/await Tx (var& none p)->int do
    var none&& p1 = ((&&p) as int&&);
    escape *((p1) as int&&);
end

var int v = 10;
var int ret = await Tx(&v);
escape ret;
]],
    run = 10,
}

Test { [[
input none OS_START;

code/await Tx (var& int a)->none do
    await FOREVER;
end

var int v = 0;
watching Tx(&v) do
    v = 5;
    await OS_START;
end
escape v;
]],
    wrn = true,
    run = 5,
}

Test { [[
code/tight Fx (var& int x) -> none do
    x = 10;
end
var int x;
call Fx(&x);
escape x;
]],
    inits = 'line 4 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:5)',
    --run = 'line 6 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
    --mode = 'line 7 : cannot read field with mode `input`',
}
Test { [[
code/await Fx (var& int x) -> none do
    x = 10;
end
var int x;
await Fx(&x);
escape x;
]],
    --inits = 'line 4 : uninitialized variable "x" : reached `await` (/tmp/tmp.ceu:5)',
    inits = 'line 4 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:5)',
    --inits = 'line 4 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:5)',
    --run = 'line 6 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
    --mode = 'line 7 : cannot read field with mode `input`',
}
Test { [[
code/tight Fx (var& int x) -> none do
end
var int x;
call Fx(&x);
escape x;
]],
    wrn = true,
    inits = 'line 3 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:4)',
    --run = 'line 6 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
    --mode = 'line 7 : cannot read field with mode `input`',
}
Test { [[
code/await Fx (var& int x) -> none do
    await 1s;
    x = 1;
end
var int x;
await Fx(&x);
escape x;
]],
    --inits = 'line 5 : uninitialized variable "x" : reached `await` (/tmp/tmp.ceu:6)',
    --inits = 'line 5 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:6)',
    inits = 'line 5 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:6)',
    --run = 'line 6 : missing initialization for field "i" (declared in /tmp/tmp.ceu:3)',
    --mode = 'line 7 : cannot read field with mode `input`',
}

Test { [[
code/tight Ff (var& int x) -> none do
    var int v = 0;
    x = &v;
end

var& int x;
call Ff(&x);

escape 0;
]],
    --inits = 'line 3 : invalid binding : variable "x" is already bound',
    inits = 'line 6 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:7)',
}

Test { [[
var[] int x;
var& int xx = &x;
escape 0;
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 2 : invalid binding : types mismatch : "Var" <= "Vec"',
}

Test { [[
code/await Ff (var& int x) -> int do
    escape x;
end

var[] int x;
spawn Ff(&x);

escape 0;
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 6 : invalid binding : types mismatch : "Var" <= "Vec"',
}

Test { [[
code/tight Ff (var int x) -> none do
end

var int x = 0;
var int a = &x;
call Ff(&x);
escape 0;
]],
    dcls = 'line 6 : invalid binding : argument #1 : expected declaration with `&`',
    wrn = true,
}

Test { [[
code/await Ff (event& none e) -> none do
    await async do end
    emit e;
end

event none e;
spawn Ff(&e);
await e;
escape 1;
]],
    run = 1,
}

Test { [[
every 1s do
    spawn do end;
    escape 1;
end
escape 0;
]],
    props_ = 'line 2 : invalid `spawn` : unexpected enclosing `every`',
    run = { ['~>1s']=1 },
}

Test { [[
code/await Ff (none) -> none do
end
every 1s do
    spawn Ff();
    escape 1;
end
escape 0;
]],
    --props_ = 'line 4 : invalid `await` : unexpected enclosing `every`',
    props_ = 'line 4 : invalid `spawn` : unexpected enclosing `every`',
    run = { ['~>1s']=1 },
}

--<< CODE / ALIAS

-->> CODE / AWAIT / OPTION

Test { [[
code/tight Fx (var int? xxx) -> int do
    if xxx? then
        escape xxx! + 1;
    else
        escape 1;
    end
end

escape (call Fx(_)) + (call Fx(10));
]],
    run = 12,
}

Test { [[
code/await Fx (var int? x) -> int do
    if x? then
        escape x! + 1;
    else
        escape 1;
    end
end

var int v1 = await Fx(10);
var int v2 = await Fx(_);

escape v1+v2;
]],
    run = 12,
}

Test { [[
data Dd with
    var int x = 10;
end
code/tight Ff (var Dd d) -> int do
    escape d.x;
end
escape call Ff(_);
]],
    run = 10,
}

Test { [[
code/tight Ff (var int? x) -> int do
    escape (x? as int) + 1;
end
escape call Ff(_);
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> none do
end
var& Ff f = spawn Ff();
escape 0;
]],
    dcls = 'line 3 : invalid declaration : `code/await` must execute forever',
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
var& Ff f = spawn Ff();
escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> none do
end
var&? Ff f1 = spawn Ff();
var& Ff f2 = &f1!;
escape 0;
]],
    dcls = 'line 4 : invalid declaration : `code/await` must execute forever',
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
var&? Ff f1 = spawn Ff();
var& Ff f2 = &f1!;
escape 1;
]],
    --dcls = 'line 4 : invalid declaration : `code/await` must not execute forever',
    run = 1,
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
pool[1] Ff fs;
var& Ff f1 = spawn Ff() in fs;
var& Ff f2 = spawn Ff() in fs;
escape 1;
]],
    run = '6] -> runtime error: out of memory',
    _opts = { ceu_features_trace='true', ceu_features_pool='true' },
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
var& Ff f = spawn Ff();
kill f;
escape 0;
]],
    stmts = 'line 5 : invalid `kill` : expected `&?` alias',
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
pool[] Ff fs;
every 1s do
    var& Ff f;
    loop f in fs do
    end
end
escape 0;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = false,
}
--<< CODE / AWAIT / OPTION

-->> CODE / AWAIT / FOREVER

Test { [[
code/tight Ff (none) -> NEVER do
end
]],
    parser = 'line 1 : after `->` : expected type',
}

Test { [[
code/await Ff (none) -> NEVER do
    escape 1;
end
]],
    dcls = 'line 2 : invalid `escape` : no matching enclosing `do`',
}
Test { [[
code/await Ff (none) -> NEVER do
    escape;
end
]],
    dcls = 'line 2 : invalid `escape` : no matching enclosing `do`',
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
var int ret = await Ff();
escape 1;
]],
    stmts = 'line 4 : invalid assignment : `code` executes forever',
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
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
code/await Ff (none) -> NEVER do
    // err must have non-term stmt
end
spawn Ff();
escape 1;
]],
    run = '3] -> runtime error: reached end of `code`',
    _opts = { ceu_features_trace='true' },
}

--<< CODE / AWAIT / FOREVER

Test { [[
code/await Ff (none) -> NEVER do
end
var int? x = watching Ff() do
end;
escape 0;
]],
    --stmts = 'line 3 : invalid `watching` : `code` executes forever',
    stmts = 'line 3 : invalid assignment : `code` executes forever',
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
watching Ff() do
end
escape 1;
]],
    --stmts = 'line 3 : invalid `watching` : `code` executes forever',
    run = 1,
}

-->>> REACTIVE / VAR / OPT / ALIAS

Test { [[
var int ret = 0;
var&? int ppp;
do
    var int x = 10;
    ppp = &x;
    ret = ppp!;
end
ret = ret + (ppp? as int);
escape ret;
]],
    --dcls = 'line 2 : invalid declaration : option alias : expected native or `code/await` type',
    scopes = 'line 5 : invalid binding : incompatible scopes',
    --run = 10,
}

Test { [[
var int ret = 0;
var&? int? p;
do
    var int x = 10;
    p = &x;     // err
    ret = p!;
end
ret = ret + (p? as int);
escape ret;
]],
    --dcls = 'line 2 : invalid declaration : option alias : expected native or `code/await` type',
    dcls = 'line 2 : invalid declaration : option type : not implemented',
    --stmts = 'line 5 : invalid binding : types mismatch : "int?" <= "int"',
}

Test { [[
var int ret = 0;
var&? int? p;
do
    var int? x = 10;
    p = &x;
    ret = p!!;
end
ret = ret + (p? as int);
escape ret;
]],
    --dcls = 'line 2 : invalid declaration : option alias : expected native or `code/await` type',
    dcls = 'line 2 : invalid declaration : option type : not implemented',
    --run = 10,
}

Test { [[
var int ret = 0;
var&? int? p;
do
    var int? x;
    p = &x;
    var int? y = p!;
    ret = p!!;
end
ret = ret + (p? as int);
escape ret;
]],
    --dcls = 'line 2 : invalid declaration : option alias : expected native or `code/await` type',
    dcls = 'line 2 : invalid declaration : option type : not implemented',
    --run = 'err acc to p!!',
}

Test { [[
var int ret = 0;
var&? int p;
par/or do
    var int x = 10;
    p = &x;
    ret = p!;
with
    await p;
end
ret = ret + (p? as int);
escape ret;
]],
    stmts = 'line 8 : invalid `await` : expected `code/await` abstraction',
    --dcls = 'line 2 : invalid declaration : option alias : expected native or `code/await` type',
    --inits = 'line 2 : uninitialized variable "p" : reached `par/or` (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "p" : reached yielding statement (/tmp/tmp.ceu:3)',
}

-->> CODE / AWAIT / INLINE

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
spawn Ff();
escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> none do
end
await Ff();
escape 1;
]],
    run = 1,
}

Test { [[
var int y = do escape 1; end;

code/await Ff (none) -> int do
    escape 1;
end
await Ff();
escape 1;
]],
    run = 1,
}
Test { [[
var int y = do escape 1; end;

code/await Ff (none) -> int do
    escape 1;
end
var int x = _;
x = await Ff();
escape x;
]],
    run = 1,
}

Test { [[
code/tight Ff (none) -> int do
    escape 1;
end
var int x = call Ff();
escape x;
]],
    run = 1,
}

Test { [[
code/tight Ff (none) -> bool do
    escape true;
end
var bool x = call Ff();
if x then
    escape 1;
else
    escape 0;
end
]],
    run = 1,
}

Test { [[
code/await Ff (var int x) -> int do
    escape x + 1;
end
var int x = await Ff(10);
escape x;
]],
    run = 11,
}

Test { [[
code/await Ff (var int x, var bool z) -> int do
    if z then
        escape x + 1;
    else
        escape x + 2;
    end
end
var bool z = false;
var int x = await Ff(10,z);
escape x;
]],
    run = 12,
}

Test { [[
code/tight Ff (var int x) -> int do
    escape x + 1;
end
var int x = call Ff(10);
escape x;
]],
    run = 11,
}

Test { [[
code/tight Ff (var int x) -> int do
    escape x + 1;
end
call Ff(10);
escape 11;
]],
    run = 11,
}

Test { [[
code/await Ff (var int x) -> int do
    escape x + 1;
end
var int y = 10;
var int ret = await Ff(y);
escape ret;
]],
    run = 11,
}

Test { [[
code/await Gg (var int y) -> int do
    escape y + 1;
end

code/await Ff (var int x) -> int do
    x = await Gg(x);
    escape x;
end
var int y = 10;
var int ret = await Ff(y);
escape ret;
]],
    run = 11,
}

Test { [[
code/await Gg (var int y) -> int do
    escape {@y} + 1;
end

code/await Ff (var int x) -> int do
    x = await Gg(x);
    escape x;
end
var int y = 10;
var int ret = await Ff(y);
escape ret;
]],
    run = 11,
}

Test { [[
code/await Ff (var int x) -> int do
    escape x + 1;
end
var int y = 10;
var int ret1 = await Ff(y);
var int ret2 = await Ff(y);
escape ret1+ret2;
]],
    run = 22,
}

Test { [[
code/await Ff (var& int x) -> int do
    escape x + 1;
end
var int y = 10;
var int ret = await Ff(&y);
escape ret;
]],
    run = 11,
}

Test { [[
code/await Ff (var int x) -> int do
    escape x + 1;
end
var int x = 10;
var int ret = await Ff(x);
escape ret;
]],
    run = 11,
}

Test { [[
code/await Ff (var& int x) -> int do
    escape x + 1;
end
var int x = 10;
var int ret = await Ff(&x);
escape ret;
]],
    run = 11,
}

Test { [[
code/await Ff (var& int x) -> none do
    x = x + 1;
end
var int x = 10;
spawn Ff(&x);
escape x;
]],
    run = 11,
}

Test { [[
code/await Ff (var u8? x) -> u8 do
    escape x!;
end
var u8? y = 10;
var u8 v = await Ff(y!);
escape v as int;
]],
    run = 10,
}
Test { [[
code/await Ff (var u8 x) -> u8 do
    escape x;
end
var u8? y = 10;
var u8 v = await Ff(y!);
escape v as int;
]],
    run = 10,
}

Test { [[
code/await Gg (var u8 b) -> u8 do
    escape b;
end

code/await Ff (var u8? v) -> u8 do
    if v? then
        var u8 a = await Gg(v!);
        escape a;
    else
        escape 0;
    end
end
var u8 x = await Ff(10);
escape x as int;
]],
    run = 10,
}

Test { [[
code/await Ff (none) -> none do
end
await Ff();
await Ff();
escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> int do
    loop do
        if true then
            break;
        else
            await 1s;
        end
    end
    escape 10;
end
var int x = await Ff();
escape x;
]],
    run = 10,
}

Test { [[
code/await Gg (var& int x) -> NEVER;
code/await Gg (var& int x) -> NEVER do
    x = x + 1;
    await FOREVER;
end
code/await Ff (var& int x) -> NEVER do
    spawn Gg(&x);
    await FOREVER;
end
var int x = 10;
spawn Ff(&x);
escape x;
]],
    run = 11,
}

Test { [[
input none A;

code/await Ff (none) -> bool do
    escape true;
end

await Ff();
await A;

escape 100;
]],
    run = { ['~>A']=100 },
}

--<< CODE / AWAIT / INLINE

-->> CODE / AWAIT / INITIALIZATION / PUBLIC

Test { [[
code/await UV_TCP_Open (none) -> (var int v) -> none
do
    if false then
        escape;
    end

    v = 10;
end
escape 1;
]],
    wrn = true,
    --inits = 'line 1 : uninitialized variable "v" : reached end of `if` (/tmp/tmp.ceu:3)',
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int v) -> int do
    if true then
        escape 10;
    end
    var int x = 100;
    v = &x;
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await UV_TCP_Open (none) -> (var& int v) -> none
do
end
await UV_TCP_Open();
var int x = 1;
escape x;
]],
    wrn = true,
    inits = 'line 1 : uninitialized variable "v" : reached yielding statement (/tmp/tmp.ceu:4)',
    --inits = 'line 1 : uninitialized variable "v" : reached `escape` (/tmp/tmp.ceu:5)',
    --inits = 'line 1 : uninitialized variable "v" : reached end of `code` (/tmp/tmp.ceu:1)',
}

Test { [[
code/await UV_TCP_Open (none) -> (var& int v) -> none
do
    if false then escape; end
    var int vv = 10;
    v = &vv;
end
escape 1;
]],
    wrn = true,
    run = 1,
    --inits = 'line 1 : uninitialized variable "v" : reached end of `if` (/tmp/tmp.ceu:3)',
}

Test { [[
code/await UV_TCP_Open (none) -> (var& int v) -> none
do
    do/_ escape; end
    var int vv = 10;
    v = &vv;
end
escape 1;
]],
    wrn = true,
    --inits = 'line 1 : uninitialized variable "v" : reached `escape` (/tmp/tmp.ceu:3)',
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 0;
    x = &v;
end

var int x;
spawn Ff() -> (x);

escape 0;
]],
    parser = 'line 7 : after `)` : expected `in` or `;`',
}

Test { [[
data Dd with
    var bool x;
end

var Dd? d = val Dd(true);
var bool x = d!.x;

escape x as int;
]],
    run = 1;
}

Test { [[
code/await Ff (none) -> (var int x) -> none do
    var int v = 0;
    x = v;
end

var&? Ff f = spawn Ff();
var bool x = f!.x;

escape 0;
]],
    stmts = 'line 7 : invalid assignment : types mismatch : "bool" <= "int"',
}

Test { [[
code/await Ff (none) -> (var int x) -> none do
    x = 10;
end

var&? bool f = spawn Ff();
var int x = f!.x;

escape x;
]],
    --dcls = 'line 5 : invalid declaration : option alias : expected native or `code/await` type',
    stmts = 'line 5 : invalid constructor : types mismatch : "bool" <= "Ff"',
}

Test { [[
code/await Ff (none) -> (var int x) -> none do
    x = 10;
end

var Ff f = spawn Ff();
var int x = f!.x;

escape x;
]],
    dcls = 'line 5 : invalid declaration : unexpected context for `code` "Ff"',
}

Test { [[
code/await Ff (none) -> (var int x) -> none do
    x = 10;
end

var&? Ff f = spawn Ff();
var int x = f!.x;

escape x;
]],
    run = '6] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
    --run = 10;
}

Test { [[
code/await Ff (var int xxx) -> (var& int yyy) -> NEVER do
    yyy = &xxx;
    do
        do finalize with end
    end
    await FOREVER;
end

var int aaa = 10;
var&? Ff f = spawn Ff(aaa);

escape f!.yyy;
]],
    run = 10,
    --dcls = 'line 10 : invalid declaration : `code/await` must not execute forever',
}

Test { [[
code/await Ff (var int xxx) -> (var& int yyy) -> NEVER do
    yyy = &xxx;
    do
        do finalize with end
    end
    await FOREVER;
end

var int aaa = 10;
var& Ff f = spawn Ff(aaa);

escape f!.yyy;
]],
    dcls = 'line 12 : invalid operand to `!` : expected option type : got "Ff"',
}

Test { [[
code/await Ff (var int xxx) -> (var& int yyy) -> NEVER do
    yyy = &xxx;
    do
        do finalize with end
    end
    await FOREVER;
end

var int aaa = 10;
var& Ff f = spawn Ff(aaa);

escape f.yyy;
]],
    run = 10,
}

Test { [[
code/tight Ff (none) -> (var& int x) -> none do
end
]],
    parser = 'line 1 : after `->` : expected type',
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end
var&? Ff f = spawn Ff();
escape f!.x;
]],
    --stmts = 'line 6 : invalid binding : argument #1 : terminating `code` : expected alias `&?` declaration',
    run = '6] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end

pool[] Ff fs;
spawn Ff() in fs;

var int ret = 0;
var int i;
loop i in [0->1] do
    var&? Ff f1 = do
        var& Ff f2;
        loop f2 in fs do
            if i == 0 then
                escape &f2;
            end
        end
    end;
    ret = ret + 1 + (f1? as int);
end

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 3,
}
Test { [[
code/await Ff (none) -> none do
end
pool[] Ff ffs;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    dcls = 'line 3 : pool "ffs" declared but not used',
}

Test { [[
native _void_ptr, _malloc;
native/nohold _free;
native/pre do
    typedef void* void_ptr;
end
code/await Ff (none) -> (var&? _void_ptr xxx) -> none do
    do
        xxx = &_malloc(10);
    finalize (xxx) with
        _free(&&xxx!);
    end
    await FOREVER;
end
var&? Ff fff = spawn Ff();
escape (fff!.xxx? as int) + 1;
]],
    run = 2,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 1s;
end
var&? Ff f = spawn Ff();
escape f!.x + 1;
]],
    run = 11,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end
var&? Ff f = spawn Ff();
escape (f? as int) + 1;
]],
    run = 1,
}
Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end
pool[] Ff ffs;
var&? Ff fff = spawn Ff() in ffs;
escape (fff? as int) + 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
code/await Ff (event& int e, var int i) -> none do
    par/or do
        var int ii = await e until i==ii;
    with
        await async do end
        emit e(2);
        await FOREVER;
    end
end

pool[] Ff fs;
event int e;
spawn Ff(&e, 1) in fs;
spawn Ff(&e, 2) in fs;
await async do end
await async do end
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}
Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end
var int n = 0;
pool[n] Ff ffs;
var&? Ff f = spawn Ff() in ffs;
escape (f? as int) + 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    consts = 'line 6 : not implemented : dynamic limit for pools',
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end
var&? Ff x = spawn Ff();
await x;
escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int yyy) -> none do
    var int v = 10;
    yyy = &v;
    await async do end;
end
var&? Ff x = spawn Ff();
await x;
escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    var[] byte c = [1,2,3];
    await async do end;
end
var&? Ff x = spawn Ff();
await x;
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int xxx) -> none do
    var int v = 10;
    xxx = &v;
    await async do end;
end

var&? Ff x_ = spawn Ff();

await x_;

escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int xxx) -> none do
    var int v = 10;
    xxx = &v;
    await async do end;
end
pool[] Ff ffs;
spawn Ff() in ffs;
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

-- test valgrind used to fail
Test { [[
code/await Ff (none) -> (var& int xxx) -> none do
    var int v = 10;
    xxx = &v;
    await async do end;
end

pool[] Ff ffs;
var&? Ff x_ = spawn Ff() in ffs;

await x_;

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
code/await Ff (none) -> int do
    await 1s;
    escape 1;
end

pool[] Ff fs;
var&? Ff f = spawn Ff() in fs;
var int? ret = await f;
escape ret!;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>1s']=1 },
}
Test { [[
code/await Ff (none) -> (var& int x) -> NEVER do
    var int v = 10;
    x = &v;
    await FOREVER;
end
var&? Ff x = spawn Ff();
escape x!.x + 1;
]],
    run = 11,
}

Test { [[
code/await Ff (none) -> (var& int x) -> NEVER do
    var int v = 10;
    x = &v;
    await FOREVER;
end
pool[] Ff ffs;
var&? Ff x = spawn Ff() in ffs;
escape x!.x + 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 11,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 1s;
end
pool[] Ff ffs;
var&? Ff x = spawn Ff() in ffs;
escape x!.x + 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 11,
}

Test { [[
code/await Ff (none) -> none do
    await 1s;
end

do
    pool[] Ff fs;
    var&? Ff f = spawn Ff() in fs;
    par/or do
        await f;
    with
        await FOREVER;
    end
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>1s']=1 },
}

Test { [[
code/await Ff (event& none e) -> none do
    emit e;
end
event none e;
par/or do
    await e;
with
    pool[] Ff fs;
    spawn Ff(&e) in fs;
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
                        // err
    var int v = 10;
    x = &v;
    await 1s;
end

var int ret = 0;

var&? Ff x = spawn Ff();

ret = x!.x;
await x;
ret = ret + (x? as int) + 1;

escape x!.x;
]],
    run = {['~>1s']='16] -> runtime error: value is not set'};
    _opts = { ceu_features_trace='true' },
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
                        // err
    var int v = 10;
    x = &v;
    await 1s;
end

var int ret = 0;

var&? Ff x = spawn Ff();

ret = x!.x;
await x;
ret = ret + (x? as int) + 1;

escape ret;
]],
    --stmts = 'line 11 : invalid binding : argument #1 : unmatching alias `&` declaration',
    run = {['~>1s']=11};
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await FOREVER;
end

var int ret = 0;

var&? Ff x = spawn Ff();

escape x!.x;
]],
    run = 10,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await async do end;
end

var&? Ff x = spawn Ff();

var int ret = x!.x;
await async do end;
ret = ret + (x? as int) + 1;
escape ret;
]],
    run = 11,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 1s;
end

var int ret = 0;

var&? Ff x = spawn Ff();

ret = x!.x;
await x;    // err
ret = ret + (x? as int) + 1;

escape ret;//x!.x;
]],
    run = {['~>1s']=11},
    --stmts = 'line 13 : invalid `await` : expected `var` with `&?` modifier',
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end

var int ret = 0;

var&? Ff x = spawn Ff();

escape (x? as int) + 1;
]],
    run = 1,
}

Test { [[
var int x = 0;
await x;
escape 0;
]],
    stmts = 'line 2 : invalid `await` : expected `var` with `&?` modifier',
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end

var int ret = 0;

var&? Ff x = spawn Ff();
await x;
ret = ret + (x? as int) + 1;

escape ret;
]],
    run = { ['~>1s'] = 1 },
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 1s;
end

var int ret = 0;

pool[] Ff fs;

var&? Ff x = spawn Ff() in fs;

ret = x!.x;
await x;
ret = ret + (x? as int) + 1;

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>1s'] = 11 },
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end
var&? Ff x = spawn Ff();
var int v = await x;
escape v;
]],
    --run = 10,
    stmts = 'line 6 : invalid assignment : types mismatch : "(int)" <= "(none?)"',
}

Test { [[
code/await Ff (none) -> int do
    await async do end
    escape 10;
end
var&? Ff x = spawn Ff();
var int v = await x;
escape v;
]],
    stmts = 'line 6 : invalid assignment : types mismatch : "(int)" <= "(int?)"',
}

Test { [[
code/await Ff (none) -> int do
    await async do end
    escape 10;
end
var&? Ff x = spawn Ff();
var int? v = await x;
escape v!;
]],
    run = 10,
}

--<< CODE / AWAIT / INITIALIZATION / PUBLIC

--<<< REACTIVE / VAR / OPT / ALIAS

-->> CODE / AWAIT / WATCHING

Test { [[
code/await Code (var int x) -> int do
    escape 0;
end
var int&& a =
    watching Code(111) do
        await FOREVER;
    end;

escape 0;
]],
    wrn = true,
    --stmts = 'line 4 : invalid assignment : types mismatch : "(int&&)" <= "(int)"',
    stmts = 'line 4 : invalid assignment : types mismatch : "int&&" <= "int"',
}

Test { [[
code/await Code (var int x) -> int
do
    x = x + 222;
    await 1s;
    escape x;
end
var int? a =
    watching Code(111) do
        escape 99;
    end;

escape a!+1;
]],
    run = 99,
}

Test { [[
code/await Code (var int x) -> int
do
    escape x;
end
var int? a =
    watching Code(111) do
        escape 99;
    end;

escape a!+1;
]],
    run = 112,
}

Test { [[
code/await Code (var int x) -> int
do
    x = x + 1;
    await 1s;
    escape x;
end
var int? a =
    watching Code(10) do
        await 5s;
        escape 1;
    end;

escape a!;
]],
    run = {['~>1s']=11 },
}

Test { [[
code/await Code (var& int x) -> (var& int y) -> int
do
    y = &x;
    x = x + 1;
    await 1s;
    escape x;
end

var int x = 10;
var&? Code c = spawn Code(&x);
var int? a =
    watching c do
        c.y = c.y + 1;
        await 5s;
        escape 1;
    end;

escape a! + x;
]],
    run = {['~>1s']=24 },
}

Test { [[
code/await Code (none) -> (var& int y) -> none do
    var int x = 10;
    y = &x;
end

var&? Code c;
do
    c = spawn Code();
    watching c do
    end
end
do
    var[10] int x = [];
end

escape c!.y;
]],
    run = '16] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
    --props_ = 'line 15 : invalid access to internal identifier "y" : crossed `watching` (/tmp/tmp.ceu:8)',
    --props_ = 'line 15 : invalid access to internal identifier "y" : crossed yielding statement (/tmp/tmp.ceu:8)',
}

Test { [[
code/await Code (var& int x) -> (var& int y, var& int z) -> int
do
    y = &x;
    z = &x;
    x = x + 1;
    await 1s;
    escape x+x;
end
var int x = 10;
var&? Code c = spawn Code(&x);
var int? a =
    watching c do
        c.y = c.y + 1;
        await 5s;
        escape 1;
    end;

escape a! + x;
]],
    run = {['~>1s']=36 },
}

Test { [[
code/await Code (var& int x) -> (var& int y) -> int
do
    y = &x;
    x = x + 1;
    await 10s;
    escape x;
end
var&? Code c;
var int x = 10;
c = spawn Code(&x);
watching c do
    c.y = c.y + 1;
    await 5s;
    escape c.y;
end;

escape x;
]],
    run = {['~>5s']=12 },
}

Test { [[
code/await Ff (none) -> int do
    await 2s;
    escape 100;
end

do
    var int? err = 1;
end

do/_
    var int? err =
        watching Ff() do
            await 1s;
        end;
    escape (err? as int) + 1;
end
]],
    run = { ['~>2s']=1 },
}

Test { [[
native/nohold _SDL_CreateWindow;

native _SDL_Window;
native/nohold _printf;

code/await SDL_Go (none) -> (var& _SDL_Window win) -> none
do
    var&? _SDL_Window win_ = &_SDL_CreateWindow() finalize (win_) with end
    win = &win_!;
end

var&? SDL_Go sdl = spawn SDL_Go();
watching sdl do
    await 1s;
    _printf("%p\n", sdl.win);
end

escape 0;
]],
    cc = '8: error: unknown type name ‘SDL_Window’',
}

Test { [[
native _int, _myalloc;
native/pre do
    none* myalloc (none) {
        return NULL;
    }
    none myfree (none* v) {
    }
end
native/nohold _myfree;

code/await Fx (none) -> (var& _int vv) -> none do
    var&? _int v;
    do
        v = &_myalloc();
    finalize(v) with
        if v? then
            _myfree(&&v!);
        end
    end

    vv = &v!;
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
native _int, _myalloc;
native/pre do
    int V = 10;
    none* myalloc (none) {
        return &V;
    }
end

code/await Fx (none) -> (var& _int vv) -> int do
    var&? _int v;
    do
        v = &_myalloc();
    finalize(v) with
    end

    vv = &v!;
    escape vv;
end

var int x = await Fx();

escape x;
]],
    run = 10,
    --dcls = 'line 17 : invalid access to output variable "vv"',
}

Test { [[
native _int, _myalloc;
native/pre do
    int V = 10;
    none* myalloc (none) {
        return &V;
    }
    none myfree (none* v) {
    }
end
native/nohold _myfree;

code/await Fy (var& _int x) -> int do
    escape x + 1;
end

code/await Fx (none) -> (var& _int vv) -> int do
    var&? _int v;
    do
        v = &_myalloc();
    finalize(v) with
        if v? then
            _myfree(&&v!);
        end
    end

    vv = &v!;
    var int x = await Fy(&v!);
    escape x + 1;
end

var int x = await Fx();

escape x;
]],
    run = 12,
}

Test { [[
native _int, _myalloc;
native/pre do
#include <stdio.h>
    int V = 10;
    none* myalloc (none) {
        return &V;
    }
end

code/await Fx (none) -> (var& _int vv) -> none do
    var&? _int v;
    do
        v = &_myalloc();
    finalize(v) with
    end
    vv = &v!;
end

var&? Fx f = spawn Fx();
escape f!.vv;
]],
    run = '20] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
native _int, _myalloc;
native/pre do
#include <stdio.h>
    int V = 10;
    none* myalloc (none) {
        return &V;
    }
end

code/await Fx (none) -> (var& _int vv) -> none do
    var&? _int v;
    do
        v = &_myalloc();
    finalize(v) with
    end
    vv = &v!;
    await FOREVER;
end

var&? Fx f = spawn Fx();
escape f!.vv;
]],
    run = 10,
}

Test { [[
native _int, _myalloc;
native/pre do
#include <stdio.h>
    int V = 10;
    none* myalloc (none) {
        return &V;
    }
    none myfree (none* v) {
    }
end
native/nohold _myfree;

code/await Fy (var& _int x) -> int do
    await 1s;
    escape x + 1;
end

code/await Fx (none) -> (var& _int vv) -> int do
    var&? _int v;
    do
        v = &_myalloc();
    finalize(v) with
        if v? then
            _myfree(&&v!);
        end
    end

    vv = &v!;
    var int x = await Fy(&v!);
    escape x + 1;
end

var int ret = 0;
var&? Fx f = spawn Fx();
var int? x =
    watching f do
        ret = ret + f.vv;
        await 1s;
    end;

escape ret+x!;
]],
    run = { ['~>1s']=22 },
}

Test { [[
code/await Ff (none) -> (none) -> none do
end

var&? Ff f = spawn Ff();
watching f do
    watching f do
    end
end
escape 1;
]],
    run = 1,
}
Test { [[
code/await Ff (none) -> (var& int x, var& int y) -> none do
    var int xx = 10;
    x = &xx;
    y = &xx;
    await FOREVER;
end

var&? Ff f = spawn Ff();
watching f do
    escape f!.y + 1;
end

escape 0;
]],
    dcls = 'line 10 : invalid operand to `!` : found enclosing matching `watching`',
}
Test { [[
code/await Ff (none) -> (var& int x, var& int y) -> none do
    var int xx = 10;
    x = &xx;
    y = &xx;
    await FOREVER;
end

var&? Ff f = spawn Ff();
watching f do
    escape f.y + 1;
end

escape 0;
]],
    run = 11,
}

Test { [[
code/await Ff (none) -> (var int x) -> none do
    x = 10;
end
var&? Ff f = spawn Ff();
watching f do
    code/await Gg (none) -> int do
        escape outer.f!.x;
    end
end
escape 1;
]],
    dcls = 'line 7 : invalid operand to `!` : found enclosing matching `watching`',
    --wrn = true,
    --run = 1,
}

Test { [[
code/await Ff (none) -> (var int x) -> none do
    x = 10;
end
var&? Ff f = spawn Ff();
watching f do
    code/await Gg (none) -> int do
        escape outer.f.x;
    end
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Dd with
    event none e;
end

code/await Ff (none) -> (var Dd d) -> none do
    d = _;
    await 1s;
end

var&? Ff f = spawn Ff();
watching f do
    watching f.d.e do
        par/and do
            await f.d.e;
        with
            emit f.d.e;
        end
    end
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Dd with
    event none e;
end

code/await Ff (none) -> (var Dd d) -> none do
    d = _;
    await 1s;
end

var&? Ff f = spawn Ff();
watching f do
    par/and do
        await f.d.e;
    with
        emit f.d.e;
    end
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Dd with
    event none e;
end

code/await Ff (none) -> (var Dd d) -> none do
    d = _;
    await 1s;
end

var&? Ff f = spawn Ff();
watching f!.d.e do
    par/and do
        await f!.d.e;
    with
        emit f!.d.e;
    end
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Dd with
    event none e;
end

code/await Ff (none) -> (var Dd d) -> NEVER do
    d = _;
    await FOREVER;
end

var& Ff f = spawn Ff();
watching f.d.e do
    par/and do
        await f.d.e;
    with
        emit f.d.e;
    end
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Int with
    var int x;
end

code/await Texs (none) -> (var&[10] Int nums) -> none
do
    var[10] Int nums_ = [ ];
    nums = &nums_;
    await FOREVER;
end

var&? Texs t = spawn Texs();
watching t do
    var&[10] Int nums_ = &t.nums;   // TODO: deveria poder
end

escape 1;
]],
    --stmts = 'line 14 : invalid binding : unexpected source with `&?`',
    run = 1,
}

Test { [[
data Int with
    var int x;
end

code/await Texs (none) -> (var&[10] Int nums) -> none
do
    var[10] Int nums_ = [ ];
    nums = &nums_;
    await FOREVER;
end

var&? Texs t = spawn Texs();
watching t do
    escape ($t.nums as int)+10;
end

escape 1;
]],
    run = 10,
}

Test { [[
code/await Ff (none) -> none do
end

watching Ff() do
    var int xxx = 0;
end

await 1s;

escape 1;
]],
    run = {['~>1s']=1},
}

Test { [[
code/await Ff (none) -> none do
end

code/await Gg (none) -> none do
    watching Ff() do
        var int xxx = 0;
    end
    await 1s;
end

await Gg();

escape 1;
]],
    run = {['~>1s']=1},
}

Test { [[
code/await Ff (none) -> none do
end

var int ret;
watching Ff() do
    ret = 0;
end

await 1s;
escape ret;
]],
    --inits = 'line 4 : uninitialized variable "ret" : reached `par/or` (/tmp/tmp.ceu:5)',
    --inits = 'line 4 : uninitialized variable "ret" : reached yielding statement (/tmp/tmp.ceu:5)',
    inits = 'line 4 : uninitialized variable "ret" : reached end of `par/or` (/tmp/tmp.ceu:5)',
    --inits = 'line 5 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:9)',
}

Test { [[
code/await Ff (var _char&& path) -> none do
end

code/await Gg (var _char&& path) -> none
do
    watching Ff(path) do
    end
end

await Gg("aaa");

escape 1;
]],
    wrn = true,
    run = 1,
}

-->> CODE / WATCHING / SPAWN

Test { [[
code/await Ff (none) -> (var& int x) -> none
do
    var int x_ = 10;
    x = &x_;
    await FOREVER;
end

var&? Ff f = spawn Ff();
spawn Ff();
escape f!.x;
]],
    run = 10;
    --stmts = 'line 9 : invalid binding : argument #1 : terminating `code` : expected alias `&?` declaration',
}
Test { [[
code/await Ff (none) -> (var& int x) -> NEVER
do
    var int x_ = 10;
    x = &x_;
    await FOREVER;
end

var&? Ff f = spawn Ff();
escape f!.x;
]],
    run = 10,
}

Test { [[
code/await Ff (none) -> (var& int x) -> NEVER
do
    var int x_ = 10;
    x = &x_;
    await FOREVER;
end

var&? Ff f = spawn Ff();
await 1s;
escape f!.x;
]],
    run = { ['~>1s']=10 },
}

Test { [[
native _V;
native/pos do
    int V = 0;
end
code/await Ff (none) -> none do
    every 1s do
        _V = _V + 1;
    end
end
spawn Ff();
await 10s;
escape _V;
]],
    run = { ['~>10s']=10 },
}

Test { [[
code/await Ff (none) -> (var& int x) -> none
do
    var int x_ = 10;
    x = &x_;
end

var&? Ff f = spawn Ff();
await 1s;
escape f!.x;
]],
    run = { ['~>1s']='9] -> runtime error: value is not set' },
    _opts = { ceu_features_trace='true' },
}

Test { [[
code/await Show (none) -> (var& int ret) -> none do
    var int a = 0;
    ret = &a;
end
await Show();
escape 1;
]],
    run = 1,
}
Test { [[
code/await Show (var int obj) -> (var& int ret) -> int do
    var int a = obj;
    ret = &a;
    escape a;
end
var int r = await Show(10);
escape r;
]],
    run = 10,
}
Test { [[
data Object;
code/await Show (var Object obj) -> none do
    var& int ret;
end
escape 1;
]],
    wrn = true,
    --inits = 'line 3 : uninitialized variable "ret" : reached yielding statement (/tmp/tmp.ceu:5)',
    run = 1,
}
Test { [[
data Object with
  var int c;
end
code/await Show (var Object obj) -> int do
    escape obj.c;
end
var int r = await Show(Object(10));
escape r;
]],
    run = 10,
}
Test { [[
data Object with
  var int c;
end
code/await Show (var Object obj) -> (var& int ret) -> int do
    var int a = obj.c;
    ret = &a;
    escape a;
end
var int r = await Show(Object(10));
escape r;
]],
    run = 10,
}
--<< CODE / WATCHING / SPAWN

-->> CODE / WATCHING / SCOPES

Test { [[
code/await Ff (none) -> (var& int v) -> none do
    var int vv = 0;
    v = &vv;
    await FOREVER;
end

var  int vv = 0;
var&? Ff f = spawn Ff();
watching f do
    f.v = &vv;
    escape f.v;
end
escape 0;
]],
    stmts = 'line 10 : invalid binding : unexpected context for operator `.`',
    --inits = 'line 10 : invalid binding : variable "v" is already bound (/tmp/tmp.ceu:9)',
}
Test { [[
code/await Ff (none) -> (var& int v) -> none do
    var int vv = 10;
    v = &vv;
    await FOREVER;
end

var  int vv = 0;
var&? Ff f = spawn Ff();
watching f do
    escape f.v;
end
escape 0;
]],
    run = 10,
    --inits = 'line 9 : invalid binding : variable "v" is already bound (/tmp/tmp.ceu:8)',

}
Test { [[
code/await Ff (none) -> (var& int v) -> none do
    var int vv = 10;
    v = &vv;
    await FOREVER;
end

var&? Ff f = spawn Ff();
watching f do
    escape f.v;
end
escape 0;
]],
    run = 10,

}

Test { [[
code/await Ff (none) -> (var&[1] int vec) -> none do
    var[1] int vec_ = [10];
    vec = &vec_;
    await FOREVER;
end

var&? Ff f = spawn Ff();
watching f do
    escape f.vec[0];
end
escape 0;
]],
    run = 10,
}

Test { [[
code/await Fx (none) -> (var& int a, var&[10] int b) -> none
do
    var int x;
    a = &x;
end

escape 0;
]],
    wrn = true,
    --inits = 'line 1 : uninitialized vector "b" : reached `end of code` (/tmp/tmp.ceu:7)',
    inits = 'line 1 : uninitialized vector "b" : reached yielding statement (/tmp/tmp.ceu:7)',
    --inits = 'line 1 : uninitialized vector "b" : reached end of `code` (/tmp/tmp.ceu:1)',
}

Test { [[
var int ret = 0;
var int x;
watching 1s do
    ret = x;
end
escape ret;
]],
    --inits = 'line 2 : uninitialized variable "x" : reached `par/or` (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "x" : reached `watching` (/tmp/tmp.ceu:3)',
    inits = 'line 2 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:4)',
}

Test { [[
var int ret = 0;
var int x;
watching 1s do
    await 2s;
    x = 10;
end
ret = x;
escape ret;
]],
    inits = 'line 2 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:7)',
    --inits = 'line 2 : uninitialized variable "x" : reached end of `par/or` (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:3)',
    --run = { ['~>2s']=10 },
}

Test { [[
var int ret = 0;
var int x;
watching 1s do
    x = 10;
end
ret = x;
escape ret;
]],
    inits = 'line 2 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:6)',
    --inits = 'line 2 : uninitialized variable "x" : reached end of `par/or` (/tmp/tmp.ceu:3)',
    --inits = 'line 2 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:3)',
    --run = 10,
}

Test { [[
code/await Ff (none) -> (var int x) -> NEVER do
    x = 10;
    await FOREVER;
end

var&? Ff f = spawn Ff();
var& int x = &f!.x;

escape x;
]],
    scopes = 'line 7 : invalid binding : unexpected source with `&?` : destination may outlive source',
    --stmts = 'line 7 : invalid binding : unexpected source with `&?`',
    --run = 11,
    --inits = 'line 8 : invalid binding : active scope reached yielding `await` (/tmp/tmp.ceu:11)',
    --inits = 'line 8 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:11)',
    --scopes = 'line 8 : invalid binding : incompatible scopes',
}

Test { [[
code/await Ff (none) -> none do
end

var int x;
var &? Ff f = spawn Ff();
await 1s;
x = 10;
escape x;
]],
    run = {['~>1s']=10},
}

Test { [[
code/await Ff (none) -> none do
    await FOREVER;
end

var int x;
var &? Ff f = spawn Ff();
watching f do
    x = 10;
    escape x;
end
]],
    run = 10,
}

Test { [[
code/await Ff (none) -> none do
end

var int x;
var &? Ff f = spawn Ff();
watching f do
    await 1s;
    x = 10;
end
escape x;
]],
    inits = 'line 4 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:10)',
    --inits = 'line 4 : uninitialized variable "x" : reached end of `par/or` (/tmp/tmp.ceu:6)',
    --run = 1,
}

Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g = spawn Gg();
    x = &g!.y;
    watching g do
        await FOREVER;
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x = &f.x;
    escape f.x;
end

escape 0;
]],
    scopes = 'line 9 : invalid binding : unexpected source with `&?` : destination may outlive source'
}

Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g = spawn Gg();
    watching g do
        x = &g.y;
        await FOREVER;
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x = &f.x;
    escape f.x;
end

escape 1;
]],
    run = 10,
    --stmts = 'line 9 : invalid binding : unexpected source with `&?`',
    --run = false,
    --inits = 'line 8 : invalid binding : active scope reached yielding `await` (/tmp/tmp.ceu:11)',
    --inits = 'line 8 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:11)',
    --scopes = 'line 8 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> int do
    var&? Gg g = spawn Gg();
    watching g do
        x = &g.y;
        await FOREVER;
    end
    escape x;
end

var&? Ff f = spawn Ff();
watching f do
    var& int x = &f.x;
    escape f.x;
end

escape 0;
]],
    inits = 'line 7 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:13)',
    --inits = 'line 7 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:9)',
    --stmts = 'line 9 : invalid binding : unexpected source with `&?`',
    --run = false,
    --inits = 'line 8 : invalid binding : active scope reached yielding `await` (/tmp/tmp.ceu:11)',
    --inits = 'line 8 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:11)',
    --scopes = 'line 8 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g = spawn Gg();
    watching g do
        x = &g.y;
        await FOREVER;
    end
end

var&? Ff f = spawn Ff();
var& int x = &f!.x;
watching f do
    escape f.x;
end

escape 0;
]],
    scopes = 'line 16 : invalid binding : unexpected source with `&?` : destination may outlive source',
    --stmts = 'line 9 : invalid binding : unexpected source with `&?`',
    --run = false,
    --inits = 'line 8 : invalid binding : active scope reached yielding `await` (/tmp/tmp.ceu:11)',
    --inits = 'line 8 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:11)',
    --scopes = 'line 8 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g = spawn Gg();
    x = &g!.y;                  // no, outside watching g
    watching g do
        await FOREVER;
    end
    await 1s;
end

var&? Ff f = spawn Ff();
var& int x = &f!.x;
watching f do
    escape f.x;
end

escape 0;
]],
    scopes = 'line 9 : invalid binding : unexpected source with `&?` : destination may outlive source',
    --run = false,
    --inits = 'line 8 : invalid binding : active scope reached yielding `await` (/tmp/tmp.ceu:11)',
    --inits = 'line 8 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:11)',
    --scopes = 'line 8 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g = spawn Gg();
    watching g do
        await 1s;
        x = &g.y;              // no, crossing await
        await FOREVER;
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x = &f.x;
    escape f.x;
end

escape 0;
]],
    --stmts = 'line 9 : invalid binding : unexpected source with `&?`',
    --run = false,
    inits = 'line 7 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:10)',
    --inits = 'line 8 : invalid binding : active scope reached yielding `await` (/tmp/tmp.ceu:11)',
    --inits = 'line 8 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:11)',
    --scopes = 'line 8 : invalid binding : incompatible scopes',
}

Test { [[
code/await Ff (none) -> none do
    await 1s;
end

var&? Ff f = spawn Ff();
var&? Ff f1 = &f;

escape 1;
]],
    --stmts = 'line 6 : invalid binding : expected `spawn`',
    run = 1,
    --inits = 'line 8 : invalid binding : active scope reached yielding `await` (/tmp/tmp.ceu:11)',
    --inits = 'line 8 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:11)',
    --scopes = 'line 8 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var&? Gg g) -> none do
    g = spawn Gg();
    watching g do
        await FOREVER;
    end
    await 1s;
end

var&? Ff f = spawn Ff();
watching f do
    escape f.g!.y;
end

escape 0;
]],
    run = false,
    --inits = 'line 8 : invalid binding : active scope reached yielding `await` (/tmp/tmp.ceu:11)',
    --inits = 'line 8 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:11)',
    --scopes = 'line 8 : invalid binding : incompatible scopes',
}

Test { [[
code/await Ff (none) -> (var& int v) -> none do
    var int x = 10;
    v = &x;
end

var&? Ff f = spawn Ff();
var& int v = &f!.v;
watching f do
    await FOREVER;
end

await 1s;
]],
    scopes = 'line 7 : invalid binding : unexpected source with `&?` : destination may outlive source',
    --run = false,
    --inits = 'line 7 : invalid binding : active scope reached yielding `await` (/tmp/tmp.ceu:12)',
    --inits = 'line 7 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:12)',
}

Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
end

code/await Ff (none) -> (var& int kkk) -> none do
    var&? Gg g = spawn Gg();
    kkk = &g!.y;
end

escape 1;
]],
    wrn = true,
    --run = 1,
    scopes = 'line 8 : invalid binding : unexpected source with `&?` : destination may outlive source',
}
Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int kkk) -> none do
    var&? Gg g = spawn Gg();
    watching g do
        kkk = &g.y;
        await FOREVER;
    end
end

var&? Ff f = spawn Ff();
watching f do
    escape f.kkk;
end

escape 0;
]],
    run = 10,
}
Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x, var& int y) -> none do
    var&? Gg g = spawn Gg();
    var& int a;
    watching g do
        a = &g.y;
        x = &a;
        y = &a;
        await FOREVER;
    end
end

var& int x;
var&? Ff f = spawn Ff();
watching f do
    x = &f.x;
    var& int y;
    y = &f.y;
    do/_
        escape x+y;
    end
    escape 0;
end
]],
    run = 20,
    scopes = 'line 11 : invalid binding : incompatible scopes',
}
Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x, var& int y) -> none do
    var&? Gg g = spawn Gg();
    watching g do
        x = &g.y;
        y = &g.y;
        await FOREVER;
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x;
    x = &f.x;
    var& int y;
    y = &f.y;
    do/_
        escape x+y;
    end
    escape 0;
end
]],
    run = 20,
}
Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x, var& int y) -> none do
    var&? Gg g = spawn Gg();
    var& int a;
    watching g do
        a = &g.y;
        x = &a;
        y = &a;
        await FOREVER;
    end
end

var& int x;
var&? Ff f = spawn Ff();
x = &f!.x;
var& int y;
y = &f!.y;
watching f do
    escape x+y;
end

escape 0;
]],
    scopes = 'line 11 : invalid binding : incompatible scopes',
    --scopes = 'line 20 : invalid binding : unexpected source with `&?` : destination may outlive source',
    --stmts = 'line 20 : invalid binding : unexpected source with `&?`',
}
Test { [[
code/await Gg (none) -> (var& int a) -> none do
    var int v = 10;
    a = &v;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g1 = spawn Gg();
    var&? Gg g2;
    watching g1 do
        var& int a1;
        a1 = &g1.a;
        //x = &a1;
        g2 = spawn Gg();
        watching g2 do
            x = &g2.a;
            await FOREVER;
        end
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x;
    x = &f.x;
    escape x;
end
]],
    run = 10,
}

Test { [[
code/await Gg (none) -> (var& int a) -> none do
    var int v = 10;
    a = &v;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g1 = spawn Gg();
    watching g1 do
        //x = &a1;
        var&? Gg g2 = spawn Gg();
        watching g2 do
            x = &g2.a;
            await FOREVER;
        end
    end
end

var&? Ff f = spawn Ff();
var& int x;
watching f do
    x = &f.x;
    escape x;
end
]],
    scopes = 'line 22 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (none) -> (var& int a) -> none do
    var int v = 10;
    a = &v;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g1 = spawn Gg();
    var&? Gg g2;
    watching g1 do
        //x = &a1;
        g2 = spawn Gg();
        watching g2 do
            x = &g2.a;
            await FOREVER;
        end
    end
end

var&? Ff f = spawn Ff();
var& int x;
watching f do
    x = &f.x;
    escape x;
end
]],
    scopes = 'line 23 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (none) -> (var& int a) -> none do
    var int v = 10;
    a = &v;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g1 = spawn Gg();
    var&? Gg g2;
    watching g1 do
        g2 = spawn Gg();
        watching g2 do
            x = &g2.a;
            await FOREVER;
        end
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x;
    x = &f.x;
    escape x;
end
]],
    run = 10,
    --scopes = 'line 17 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (none) -> (var& int y) -> none do
    var int yy = 10;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    nothing;
    var&? Gg g = spawn Gg();
    watching g do
        x = &g.y;
        await FOREVER;
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x;
    x = &f.x;
    escape x;
end
]],
    run = 10,
    --scopes = 'line 10 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (none) -> NEVER do
    await FOREVER;
end

var&? Gg g;
g = spawn Gg();
g = spawn Gg();
escape 1;
]],
    --inits = 'line 7 : invalid binding : variable "g" is already bound',
    run = 1,
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do
    var int yy = 10+x;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var int y1;
    var int y2;
    var int y3;
    var int v;
    var&? Gg g1 = spawn Gg(1);
    var&? Gg g2;
    var&? Gg g3;
    watching g1 do
        y1 = g1.y;
        g2 = spawn Gg(2);
        watching g2 do
            g3 = spawn Gg(3);
            y2 = g2.y;
            watching g3 do
                y3 = g3.y;
                v = y1+y2+y3;
                x = &v;
                await FOREVER;
            end
        end
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x;
    x = &f.x;
    escape x;
end
]],
    run = 36,
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do
    var int yy = 10+x;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var int y1;
    var int y2;
    var int y3;
    var int v;
    var&? Gg g1 = spawn Gg(1);
    var&? Gg g2 = spawn Gg(2);
    var&? Gg g3 = spawn Gg(3);
    watching g1 do
        y1 = g1.y;
        watching g2 do
            y2 = g2.y;
            watching g3 do
                y3 = g3.y;
                v = y1+y2+y3;
                x = &v;
                await FOREVER;
            end
        end
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x;
    x = &f.x;
    escape x;
end
]],
    run = 36,
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do
    var int yy = 10+x;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var int y1;
    var int y2;
    var int y3;
    var int v;
    var&? Gg g1 = spawn Gg(1);
    var&? Gg g2 = spawn Gg(2);
    var&? Gg g3 = spawn Gg(3);
    watching g1,g2,g3 do
        y1 = g1.y;
        y2 = g2.y;
        y3 = g3.y;
        v = y1+y2+y3;
        x = &v;
        await FOREVER;
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x;
    x = &f.x;
    escape x;
end
]],
    run = 36,
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do
    y = &x;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var int y1;
    var&? Gg g = spawn Gg(1);
    watching g do
        y1 = g.y;
        do
            var int v = y1;
            x = &v;
            await FOREVER;
        end
    end
end

escape 1;
]],
    wrn = true,
    --scopes = 'line 13 : invalid binding : incompatible scopes',
    run = 1,
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do
    var int yy = 10+x;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var int y1;
    var int y2;
    var&? Gg g1 = spawn Gg(1);
    var&? Gg g2;
    var int v;
    watching g1 do
        y1 = g1.y;
        nothing;
        g2 = spawn Gg(2);
        watching g2 do
            y2 = g2.y;
            v = y1+y2;
            x = &v;
            await FOREVER;
        end
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x;
    x = &f.x;
    escape x;
end
]],
    run = 23,
    --scopes = 'line 12 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do
    var int yy = 10+x;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> none do
    var int y1;
    var int y2;
    var&? Gg g1 = spawn Gg(1);
    var&? Gg g2 = spawn Gg(2);
    watching g1,g2 do
        y1 = g1.y;
        await 1s;
        y2 = g2.y;
    end
end

escape 1;
]],
    wrn = true,
    --inits = 'line 7 : uninitialized variable "x" : reached `await` (/tmp/tmp.ceu:10)',
    --inits = 'line 7 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:15)',
    run = 1,
    --run = 23,
    --scopes = 'line 12 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do
    var int yy = 10+x;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var int y1;
    var int y2;
    var&? Gg g1 = spawn Gg(1);
    var&? Gg g2 = spawn Gg(2);
    var int v;
    watching g1 do
        y1 = g1.y;
        watching g2 do
            y2 = g2.y;
            v = y1+y2;
            x = &v;
            await FOREVER;
        end
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x;
    x = &f.x;
    escape x;
end
]],
    run = 23,
    --scopes = 'line 11 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do
    var int yy = 10+x;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var& int y1;
    var& int y2;
    var&? Gg g1 = spawn Gg(1);
    var&? Gg g2 = spawn Gg(2);
    var int v;
    watching g1 do
        y1 = &g1.y;
        watching g2 do
            y2 = &g2.y;
            v = y1+y2;
            x = &v;
            await FOREVER;
        end
        nothing;
    end
end

var& int x;
var&? Ff f = spawn Ff();
watching f do
    x = &f.x;
    escape x;
end

escape 0;
]],
    --inits = 'line 7 : uninitialized variable "x" : reached end of `par/or` (/tmp/tmp.ceu:15)',
    inits = 'line 7 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:15)',
    --run = 23,
    --scopes = 'line 11 : invalid binding : incompatible scopes',
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do
    var int yy = 10+x;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var& int y1;
    var& int y2;
    var&? Gg g1 = spawn Gg(1);
    var&? Gg g2 = spawn Gg(2);
    var int v;
    watching g1 do
        y1 = &g1.y;
        watching g2 do
            y2 = &g2.y;
            v = y1+y2;
            x = &v;
            await FOREVER;
        end
        await 1s;
    end
end

escape 0;
]],
    wrn = true,
    --inits = 'line 10 : invalid binding : active scope reached yielding `await` (/tmp/tmp.ceu:15)',
    --inits = 'line 10 : invalid binding : active scope reached yielding statement (/tmp/tmp.ceu:15)',
    --inits = 'line 7 : uninitialized variable "x" : reached end of `par/or` (/tmp/tmp.ceu:15)',
    inits = 'line 7 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:15)',
}

Test { [[
native _void, _g;
data Dd with
    var& _void v;
end
code/await Ff (var _void&& p) -> (var& Dd d) -> NEVER do
    var&? _void v_ =
        &_g()
            finalize (v_) with
            end;

    var Dd d_ = val Dd(&v_!);
    d = &d_;

    await FOREVER;
end
escape 1;
]],
    wrn = true,
    cc = '6:43: error: implicit declaration of function ‘g’',
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do
    var int yy = 10+x;
    y = &yy;
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var int y1;
    var int y2;
    var int y3;
    var int v;
    var&? Gg g1 = spawn Gg(1);
    var&? Gg g2 = spawn Gg(2);
    var&? Gg g3 = spawn Gg(3);
    watching g1, g2, g3 do
        y1 = g1.y;
        y2 = g2.y;
        y3 = g3.y;
        v = y1+y2+y3;
        x = &v;
        await FOREVER;
    end
end

var&? Ff f = spawn Ff();
watching f do
    var& int x;
    x = &f.x;
    escape x;
end
]],
    run = 36,
}

Test { [[
code/await Ff (var int x) -> (event& int e) -> none do
    event int e_;
    e = &e_;
    await e;
end
escape 1;
]],
    wrn = true,
    --dcls = 'line 4 : invalid access to output variable "e"',
    run = 1,
}

Test { [[
code/await Ff (var int x) -> (event& int e) -> int do
    event int e_;
    e = &e_;
    var int v = await e_;
    escape v + x;
end

var&? Ff f = spawn Ff(10);
    watching f do
        event& int e;
        e = &f.e;
        emit e(100);
        escape 0;
    end;

escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (var int x) -> (event& int e) -> int do
    event int e_;
    e = &e_;
    var int v = await e_;
    await 1s;
    escape v + x;
end

var&? Ff f = spawn Ff(10);
    watching f do
        event& int e;
        e = &f.e;
        par/or do
            await e;
        with
            emit e(100);
        end
        escape 10;
    end;

escape 1;
]],
    run = 10,
}

Test { [[
code/await Ff (var int x) -> (var& int y) -> int do
    y = &x;
    await 1s;
    escape y + x;
end

var&? Ff f = spawn Ff(10);
var int? ret =
    watching f do
        var& int y = &f!.y;
        await 2s;
        escape y;
    end;

escape ret!;
]],
    dcls = 'line 10 : invalid operand to `!` : found enclosing matching `watching`',
}

Test { [[
code/await Ff (var int x) -> (var& int y) -> int do
    y = &x;
    await 1s;
    escape y + x;
end

var&? Ff f = spawn Ff(10);
var int? ret =
    watching f do
        var& int y = &f.y;
        await 2s;
        escape y;
    end;

escape ret!;
]],
    run = {['~>5s']=20},
}

Test { [[
code/await Ff (var int x) -> (var& int y) -> int do
    y = &x;
    await 2s;
    escape y + x;
end

var&? Ff f = spawn Ff(10);
var int? ret =
    watching f do
        var& int y = &f.y;
        await 1s;
        escape y;
    end;

escape ret!;
]],
    run = {['~>5s']=10},
}

Test { [[
code/await Ff (var int x) -> (event& int e) -> int do
    event int e_;
    e = &e_;
    var int v = await e_;
    escape v + x;
end

var&? Ff f = spawn Ff(10);
var int? ret =
    watching f do
        event& int e;
        e = &f.e;
        emit e(100);
        escape 0;
    end;

escape ret!;
]],
    run = 110,
}

Test { [[
code/await Ff (var int x) -> (event& int e) -> int do
    event int e_;
    e = &e_;
    var int v = await e_;
    escape v + x;
end

event& int e;
var&? Ff f = spawn Ff(10);
var int? ret =
    watching f do
        e = &f.e;
        emit e(100);
        escape 0;
    end;

escape ret!;
]],
    scopes = 'line 12 : invalid binding : incompatible scopes',
    --inits = 'line 8 : uninitialized event "e" : reached end of `par/or` (/tmp/tmp.ceu:11)',
    --inits = 'line 8 : uninitialized event "e" : reached end of `par/or` (/tmp/tmp.ceu:11)',
    --run = 110,
}

Test { [[
code/await Ff (var int x) -> (event& none e, var& int v) -> int do
    event none e_;
    var int v_ = 10;
    e = &e_;
    v = &v_;
    await e_;
    escape x;
end

var&? Ff f = spawn Ff(10);
var int? ret =
    watching f do
        event& none e = &f.e;
        var& int v = &f.v;
        emit e;
        escape 0;
    end;

escape ret!;
]],
    run = 10,
}

Test { [[
code/await Ff (var int x, event& int fff) -> int do
    var int v = await fff;
    escape v + x;
end

event int eee;

var int? ret =
    watching Ff(10, &eee) do
        emit eee(100);
        escape 0;
    end;

escape ret!;
]],
    run = 110,
}

Test { [[
code/await Ff (var int x, event& (int) e) -> int do
    var int v = await e;
    escape v + x;
end

event int e;

var int? ret =
    watching Ff(10, &e) do
        emit e(100);
        escape 0;
    end;

escape ret!;
]],
    run = 110,
}

Test { [[
code/await Hh (none) -> (var int x) -> NEVER do
    x = 10;
    await FOREVER;
end

code/await Gg (none) -> NEVER do
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g = spawn Gg();
    watching g do
        var&? Hh h = spawn Hh();
        watching h do
            x = &h.x;
            await FOREVER;
        end
        await 1s;
    end
end

escape 1;
]],
    inits = 'line 10 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:14)',
    wrn = true,
}

Test { [[
code/await Hh (none) -> (var int x) -> NEVER do
    x = 10;
    await FOREVER;
end

code/await Gg (none) -> NEVER do
    await FOREVER;
end

code/await Ff (none) -> (var& int x) -> none do
    var&? Gg g = spawn Gg();
    watching g do
        var&? Hh h = spawn Hh();
        watching h do
            x = &h.x;
            await FOREVER;
        end
    end
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await Ff (var int v) -> (var& int x) -> none do
    x = &v;
    await FOREVER;
end

code/await Gg (none) -> none do
    await FOREVER;
end

var&? Ff f1 = spawn Ff(2);
var&? Ff f2 = spawn Ff(1);

watching f1 do
    var& int ctrl1;
    ctrl1 = &f1.x;
    watching Gg() do
        watching f2 do
            var& int ctrl2;
            ctrl2 = &f2.x;
            escape ctrl1+ctrl2;
        end
    end
end

escape 0;
]],
    wrn = true,
    run = 3,
}

Test { [[
code/await Ff (var int v) -> (var& int x) -> none do
    x = &v;
    await FOREVER;
end
var& int ctrl1;
var&? Ff f1 = spawn Ff(1);
ctrl1 = &f1!.x;
escape 0;
]],
    scopes = 'line 7 : invalid binding : unexpected source with `&?` : destination may outlive source',
    --stmts = 'line 7 : invalid binding : unexpected source with `&?`',
    --stmts = 'line 12 : invalid binding : argument #1 : terminating `code` : expected alias `&?` declaration',
}
Test { [[
code/await Ff (var int v) -> (var& int x) -> NEVER do
    x = &v;
    await FOREVER;
end

code/await Gg (none) -> none do
    await FOREVER;
end

var&? Ff f1 = spawn Ff(1);
spawn Gg();
var&? Ff f2 = spawn Ff(2);

escape f1!.x + f2!.x;
]],
    run = 3,
}

Test { [[
code/await Ff (var int x) -> (var& int y) -> none do
    y = &x;
    if x%2 == 1 then
        await FOREVER;
    end
end

var int ret = 0;
var& int nn;
var&? Ff f = spawn Ff(10);
watching f do
    nn = &f.y;
end

escape nn;
]],
    inits = 'line 9 : uninitialized variable "nn" : reached read access (/tmp/tmp.ceu:15)',
    --inits = 'line 9 : uninitialized variable "nn" : reached end of `par/or` (/tmp/tmp.ceu:11)',
    --scopes = 'line 12 : invalid binding : incompatible scopes',
    --run = 10,
    --inits = 'line 9 : uninitialized variable "nn" : reached end of `par/or` (/tmp/tmp.ceu:11)',
    --props_ = 'line 16 : invalid access to internal identifier "nn" : crossed `watching` (/tmp/tmp.ceu:11)',
    --props_ = 'line 16 : invalid access to internal identifier "nn" : crossed yielding statement (/tmp/tmp.ceu:11)',
}

Test { [[
code/await Ff (none) -> (var& int x) -> int
do
    var int xx = 10;
    x = &xx;
    await async do end
    escape 100;
end

var&? Ff fff = spawn Ff();
var int? ret = await fff;
escape ret! + (fff? as int);
]],
    run = 100,
}

Test { [[
code/await Ff (none) -> (var& int x) -> int
do
    var int xx = 10;
    x = &xx;
    escape 10;
end

var&? Ff fff = spawn Ff();
var int? ret = await fff;
escape ret!;
]],
    run = '10] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
code/await Ff (none) -> (var& int x) -> int
do
    var int xx = 10;
    x = &xx;
    escape 10;
end

var&? Ff fff = spawn Ff();
var int? ret =
    watching fff do
    end;
escape ret!;
]],
    run = '12] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
code/await Gg (none) -> (var& int x) -> none do
    do finalize with
        nothing;
    end
    var int y=1;
    x = &y;
end
escape 10;
]],
    wrn = true,
    run = 10,
}

Test { [[
code/await Ff (none) -> NEVER do
end
code/await Gg (var& Ff f) -> (var& int x) -> none do
    var& Ff g = &f;
    var int y=1;
    x = &y;
end
escape 10;
]],
    wrn = true,
    run = 10,
}

Test { [[
code/await Ff (none) -> none do
end
code/await Gg (none) -> (var& int x) -> none do
    pool[] Ff fs;
    var int y=1;
    x = &y;
end
escape 10;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = 10,
}

Test { [[
code/await Ff (none) -> none do
    await async do end;
end

code/await Gg (none) -> int
do
    pool[] Ff fs;
    var&? Ff f = spawn Ff() in fs;
    await f;
    escape 10;
end

var int ret = await Gg();

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
    --inits = 'line 8 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:12)',
}

Test { [[
code/await Ff (none) -> (var& int x) -> int
do
    var int xx = 10;
    x = &xx;
    await async do end;
    escape 10;
end

code/await Gg (none) -> (var& int x) -> int
do
    pool[] Ff fs;
    var&? Ff f = spawn Ff() in fs;
    var int? ret =
        watching f do
            x = &f.x;
            await FOREVER;
        end;
    escape ret!;
end

var int ret = await Gg();

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
    --inits = 'line 8 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:12)',
}

Test { [[
code/await Ff (none) -> (var& int x) -> int
do
    var int xx = 10;
    x = &xx;
    await async do end;
    escape 10;
end

code/await Gg (none) -> (var& int x) -> int
do
    pool[] Ff fs;
    var&? Ff f = spawn Ff() in fs;
    var int? ret =
        watching f do
            x = &f.x;
            await FOREVER;
        end;
    escape x;                   // error: deallocated
end

var int ret = await Gg();

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    inits = 'line 9 : uninitialized variable "x" : reached read access (/tmp/tmp.ceu:18)',
    --run = 10,
}

Test { [[
code/await Ff (none) -> (var& int x) -> NEVER do
    code/await Gg (none) -> (var& int x) -> NEVER do
        var int y = 10;
        x = &y;
        await FOREVER;
    end
    var&? Gg g = spawn Gg();
    watching g do
        x = &g.x;
        await FOREVER;
    end
    code/tight Hh (none) -> none do end
    code/tight Ii (none) -> none do end
end
spawn Ff();
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
code/await Ff (none) -> (var& int x) -> NEVER do
    code/await Gg (none) -> (var& int x) -> NEVER do
        var int y = 10;
        x = &y;
        await FOREVER;
    end
    var&? Gg g = spawn Gg();
    watching g do
        x = &g.x;
        await FOREVER;
    end
    code/tight Hh (none) -> none do end
    nothing;
    code/tight Ii (none) -> none do end
end
spawn Ff();
escape 1;
]],
    inits = 'line 1 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:8)',
    wrn = true,
}

--<< CODE / WATCHING / SCOPES

--<< CODE / AWAIT / WATCHING

-- TODO: SKIP-02

-->>> CODE / AWAIT / SPAWN

Test { [[
code/await Tx (none)->none do
end
do
    pool[1] Tx ts;
    spawn Tx() in ts;
end
escape 5;
]],
    _opts = { ceu_features_pool='true' },
    run = 5,
}
Test { [[
code/await Tx (none)->none do
end
do
    pool[] Tx ts;
    spawn Tx() in ts;
end
escape 5;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 5,
}

Test { [[
code/await Tx (var& int a)->int do
    a = 5;
    escape 1;
end
var int a = 0;

do end
do
    pool[1] Tx ts;
    spawn Tx(&a) in ts;
end

escape a;
]],
    _opts = { ceu_features_pool='true' },
    run = 5,
}

Test { [[
native/pos do
    int V = 10;
end
code/await Tx (none)->none do
    _V = 100;
end
spawn Tx();
escape _V;
]],
    dcls = 'line 5 : native identifier "_V" is not declared',
}

Test { [[
native/pos do
    int V = 10;
end
native _V;
code/await Tx (none)->none do
    _V = 100;
end
pool[1] Tx ts;
spawn Tx() in ts;
escape _V;
]],
    _opts = { ceu_features_pool='true' },
    run = 100,
}

Test { [[
code/await Tx (var& int a)->none do
    a = do
            escape 5;
        end;
end
var int a = 0;
pool[1] Tx ts;
spawn Tx(&a) in ts;
escape a;
]],
    _opts = { ceu_features_pool='true' },
    run = 5,
}

Test { [[
code/await Tx (none)->none do end
pool[1] Tx ts;
escape 1;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 1,
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = 5;
end
var int a = 0;
pool[1] Tx ts;
spawn Tx(&a) in ts;
await 1s;
escape a;
]],
    _opts = { ceu_features_pool='true' },
    run = { ['~>1s']=5 },
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = aaa + 5;
    await FOREVER;
end
var int a = 0;
pool[2] Tx ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
await 2s;
escape a;
]],
    _opts = { ceu_features_pool='true' },
    run = { ['~>2s']=10 },
}
Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = aaa + 5;
    await 1s;
    aaa = aaa + 5;
    await FOREVER;
end
var int a = 0;
pool[2] Tx ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
await 2s;
escape a;
]],
    _opts = { ceu_features_pool='true' },
    run = { ['~>2s']=20 },
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = aaa + 5;
    await 1s;
    aaa = aaa + 5;
end
var int a = 0;
pool[2] Tx ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
await 2s;
escape a;
]],
    _opts = { ceu_features_pool='true' },
    run = { ['~>2s']=20 },
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = aaa + 5;
    await 1s;
    aaa = aaa + 5;
    await FOREVER;
end
var int a = 0;
pool[2] Tx ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
await 2s;
escape a;
]],
    _opts = { ceu_features_pool='true' },
    run = { ['~>2s']=20 },
}

Test { [[
code/await Tx (var& int aaa)->none do
    aaa = aaa + 5;
end
var int a = 0;
pool[1] Tx ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
escape a;
]],
    _opts = { ceu_features_pool='true' },
    run = 20,
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = aaa + 5;
    await 1s;
    aaa = aaa + 5;
end
var int a = 0;
pool[2] Tx ts;
spawn Tx(&a) in ts;
await 1s;
spawn Tx(&a) in ts;
await 2s;
escape a;
]],
    _opts = { ceu_features_pool='true' },
    run = { ['~>3s']=20 },
}

Test { [[
native _V;
native/pos do
    int V = 1;
end

code/await Jj (none)->none do
    _V = _V * 2;
end

code/await Tx (none)->none do
    pool[1] Jj js;
    spawn Jj() in js;
    _V = _V + 1;
end

pool[3] Tx ts;

spawn Tx() in ts;
_V = _V*3;
spawn Tx() in ts;
_V = _V*3;
spawn Tx() in ts;
_V = _V*3;
escape _V;
]],
    _opts = { ceu_features_pool='true' },
    run = 345;
}

Test { [[
native _V;
native/pos do
    int V = 1;
end

code/await Jj (none)->none do
    _V = _V * 2;
end

code/await Tx (none)->none do
    pool[1] Jj js;
    spawn Jj() in js;
    _V = _V + 1;
end

input none OS_START;

pool[3] Tx ts;
spawn Tx() in ts;
_V = _V*3;
spawn Tx() in ts;
_V = _V*3;
spawn Tx() in ts;
_V = _V*3;

await OS_START;
escape _V;
]],
    _opts = { ceu_features_pool='true' },
    run = 345;
}

Test { [[
native _V;
native/pos do
    int V = 1;
end;

code/await Tx (none)->none do
    event none e;
    emit e;
    _V = 10;
end

pool[3] Tx ts;
do
    spawn Tx() in ts;
end
escape _V;
]],
    _opts = { ceu_features_pool='true' },
    run = 10,
}

Test { [[
native _V;
native/pos do
    int V = 1;
end;

code/await Tx (none)->none do
    await 1s;
    _V = 10;
end

do
    pool[3] Tx ts;
    spawn Tx() in ts;
end
escape _V;
]],
    _opts = { ceu_features_pool='true' },
    run = 1,
}

Test { [[
native _V;
native/pos do
    int V = 1;
end

watching 1s do
    await 500ms;

    code/await Fire (none) -> none do end

    watching 1ms do
        pool[0] Fire rocks;
        par do
        with
            await 10ms;
            _V = 99;
        end
    end
    await FOREVER;
end

escape _V;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = { ['~>1s'] = 1 },
}

Test { [[
code/await Tx (var& int a)->int do
    a = 5;
    escape 1;
end
var int a = 0;

do end
do
    pool[] Tx ts;
    spawn Tx(&a) in ts;
end

escape a;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 5,
}

Test { [[
native/pos do
    int V = 10;
end
native _V;
code/await Tx (none)->none do
    _V = 100;
end
pool[] Tx ts;
spawn Tx() in ts;
escape _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 100,
}

Test { [[
code/await Tx (var& int a)->none do
    a = do
            escape 5;
        end;
end
var int a = 0;
pool[] Tx ts;
spawn Tx(&a) in ts;
escape a;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 5,
}

Test { [[
code/await Tx (none)->none do
    await async do end
end
pool[] Tx ts;
spawn Tx() in ts;
await async do end
escape 5;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>1s']=5 },
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = 5;
end
var int a = 0;
pool[] Tx ts;
spawn Tx(&a) in ts;
await 1s;
escape a;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>1s']=5 },
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = aaa + 5;
    await 1s;
    aaa = aaa + 5;
    await FOREVER;
end
var int zzz = 0;
pool[] Tx ts;
spawn Tx(&zzz) in ts;
spawn Tx(&zzz) in ts;
await 2s;
escape zzz;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>2s']=20 },
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = aaa + 5;
    await 1s;
    aaa = aaa + 5;
    await FOREVER;
end
var int a = 0;
pool[] Tx ts1;
pool[] Tx ts2;
spawn Tx(&a) in ts1;
spawn Tx(&a) in ts2;
await 2s;
escape a;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>2s']=20 },
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = aaa + 5;
    await 1s;
    aaa = aaa + 5;
end
var int a = 0;
pool[] Tx ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
await 2s;
escape a;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>2s']=20 },
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = aaa + 5;
    await 1s;
    aaa = aaa + 5;
    await FOREVER;
end
var int a = 0;
pool[] Tx ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
await 2s;
escape a;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    defines = {
        CEU_TESTS_REALLOC = 2,
    },
    run = { ['~>2s']=20 },
}

Test { [[
code/await Tx (var& int aaa)->none do
    aaa = aaa + 5;
end
var int a = 0;
pool[] Tx ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
spawn Tx(&a) in ts;
escape a;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    defines = {
        CEU_TESTS_REALLOC = 1,
    },
    run = 20,
}

Test { [[
code/await Tx (var& int aaa)->none do
    await 1s;
    aaa = aaa + 5;
    await 1s;
    aaa = aaa + 5;
end
var int a = 0;
pool[] Tx ts;
spawn Tx(&a) in ts;
await 1s;
spawn Tx(&a) in ts;
await 2s;
escape a;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    defines = {
        CEU_TESTS_REALLOC = 2,
    },
    run = { ['~>3s']=20 },
}

Test { [[
native _V;
native/pos do
    int V = 1;
end

code/await Jj (none)->none do
    _V = _V * 2;
end

code/await Tx (none)->none do
    pool[1] Jj js;
    spawn Jj() in js;
    _V = _V + 1;
end

pool[] Tx ts;

spawn Tx() in ts;
_V = _V*3;
spawn Tx() in ts;
_V = _V*3;
spawn Tx() in ts;
_V = _V*3;
escape _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    defines = {
        CEU_TESTS_REALLOC = 3,
    },
    run = 345;
}

Test { [[
native _V;
native/pos do
    int V = 1;
end

code/await Jj (none)->none do
    _V = _V * 2;
end

code/await Tx (none)->none do
    pool[1] Jj js;
    spawn Jj() in js;
    _V = _V + 1;
end

input none OS_START;

pool[] Tx ts;
spawn Tx() in ts;
_V = _V*3;
spawn Tx() in ts;
_V = _V*3;
spawn Tx() in ts;
_V = _V*3;

await OS_START;
escape _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    defines = {
        CEU_TESTS_REALLOC = 3,
    },
    run = 345;
}

Test { [[
native _V;
native/pos do
    int V = 1;
end;

code/await Tx (none)->none do
    event none e;
    emit e;
    _V = 10;
end

pool[] Tx ts;
do
    spawn Tx() in ts;
end
escape _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
}

Test { [[
native _VVV;
native/pos do
    int VVV = 1;
end;

code/await Tx (none)->none do
    await 1s;
    _VVV = 10;
end

do
    pool[] Tx ts;
    spawn Tx() in ts;
end
escape _VVV;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
native _V;
native/pos do
    int V = 1;
end

watching 1s do
    await 500ms;

    code/await Fire (none) -> none do end

    watching 1ms do
        pool[] Fire rocks;
        par do
        with
            await 10ms;
            _V = 99;
        end
    end
    await FOREVER;
end

escape _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = { ['~>1s'] = 1 },
}

-- spawn killing itself

Test { [[
event none e;

code/await Ff (event& none e) -> none do
    emit e;
end

watching e do
    spawn Ff(&e);
    native _ceu_assert;
    _ceu_assert(0,"bug found");
end

escape 1;
]],
    run = 1,
}
Test { [[
event none e;

code/await Ff (event& none e) -> none do
    emit e;
end

pool[] Ff ffs;

watching e do
    spawn Ff(&e) in ffs;
    native _ceu_assert;
    _ceu_assert(0,"bug found");
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
event none e;

code/await Ff (none) -> none do
    emit outer.e;
end

watching e do
    spawn Ff();
    native _ceu_assert;
    _ceu_assert(0,"bug found");
end

escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (var int i) -> none do
    await async do end
    if i == 1 then
        await async do end
    end
end
pool[] Ff fs;
spawn Ff(0) in fs;
spawn Ff(1) in fs;
await async do end;
await async do end;
await async do end;
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
event none e;
code/await Ff (none) -> none do
    await async do end
    emit outer.e;
end
par/or do
    await FOREVER;
with
    watching e do
        pool[] Ff fs;
        spawn Ff() in fs;
        spawn Ff() in fs;
        await FOREVER;
    end
    await async do end;
end
await async do end;
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
event none e;
code/await Gg (event& none e) -> none do
    await async do end
    emit e;
end
code/await Ff (none) -> none do
    event none ee;
    spawn Gg(&ee);
    await ee;
    emit outer.e;
end
do
    pool[] Ff fs;
    spawn Ff() in fs;
    spawn Ff() in fs;
    await e;
end
await async do end;
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

-->> CODE / AWAIT / EMIT-INTERNAL

Test { [[
code/await Tx (var& int ret, var int x)->none do
    event int e;
    par do
        var int v = await e;
        ret = ret + v;
        await FOREVER;
    with
        await 1s;
        emit e(x);
        await FOREVER;
    end
end

var int ret = 0;

par/or do
    await Tx(&ret, 1);
with
    await Tx(&ret, 2);
with
    await Tx(&ret, 3);
with
    await 1s;
end

escape ret;
]],
    run = { ['~>1s']=6 },
}

Test { [[
code/await Tx (var& int ret, var int x)->none do
    event int e;
    await 1s;
    par do
        var int v = await e;
        ret = ret + v;
        await FOREVER;
    with
        emit e(x);
        await FOREVER;
    end
end

var int ret = 0;

pool[3] Tx ts;
spawn Tx(&ret, 1) in ts;
spawn Tx(&ret, 2) in ts;
spawn Tx(&ret, 3) in ts;

await 1s;

escape ret;
]],
    _opts = { ceu_features_pool='true' },
    run = { ['~>1s']=6 },
}

--<< CODE / AWAIT / EMIT-INTERNAL

-->> CODE / AWAIT / ALIAS

Test { [[
code/await Ff (none) -> (var& int x) -> none do
                        // error
    var int v = 10;
    x = &v;
end

var&? Ff f1 = spawn Ff();
var&? Ff f2 = &f1;
escape (f2? as int) + 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end

var&? Ff f1 = spawn Ff();
var&? Ff f2 = &f1;
escape (f2? as int) + 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await FOREVER;
end

var&? Ff f1 = spawn Ff();
var&? Ff f2 = &f1;
escape (f2? as int) + 1 + f2!.x;
]],
    run = 12,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 500ms;
end

var&? Ff f1 = spawn Ff();
var&? Ff f2 = &f1;
await 1s;
escape (f2? as int) + 1;
]],
    run = { ['~>1s']=1 },
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 500ms;
end

var&? Ff f1 = spawn Ff();
var&? Ff f2 = &f1;
await 1s;
escape f2!.x;
]],
    run = { ['~>1s']='10] -> runtime error: value is not set' },
    _opts = { ceu_features_trace='true' },
}

--<< CODE / AWAIT / ALIAS

-->> CODE / AWAIT / FINALIZE

Test { [[
native _V;
native/pre do
    int V = 0;
end
code/await Ff (none)->none do
    do finalize with
        _V = _V + 1;
        //{printf(">>> V1 = %d\n", V);}
    end
    await FOREVER;
end
watching 1s do
    do finalize with
        _V = _V * 2;
        //{printf(">>> V2 = %d\n", V);}
    end
    await Ff();
end
await 1s;
escape _V;
]],
    run = { ['~>2s']=2 },
}

Test { [[
native _V;
native/pre do
    int V = 1;
end
code/await Ff (none)->none do
    do finalize with
        _V = _V * 2;
    end
    await FOREVER;
end
do
    spawn Ff();
    do finalize with
        _V = _V + 1;
    end
    await 1s;
end
await 1s;
escape _V;
]],
    run = { ['~>2s']=4 },
}

Test { [[
native _V;
native/pre do
    int V = 1;
end
code/await Gg (none)->none do
    do finalize with
        _V = _V * 2;
    end
    await FOREVER;
end
code/await Ff (none)->none do
    do finalize with
        _V = _V + 2;
    end
    await Gg();
end
watching 1s do
    do finalize with
        _V = _V * 3;
    end
    await Ff();
    do finalize with
        _V = _V + 1;
    end
end
escape _V;
]],
    run = { ['~>1s']=12 },
}

Test { [[
native _V;
native/pre do
    int V = 1;
end
code/await Gg (none)->none do
    do finalize with
        _V = _V * 2;
    end
    await FOREVER;
end
code/await Ff (none)->none do
    do finalize with
        _V = _V + 2;
    end
    await Gg();
end
watching 1s do
    do finalize with
        _V = _V * 3;
    end
    spawn Ff();
    do finalize with
        _V = _V + 1;
    end
    await FOREVER;
end
escape _V;
]],
    run = { ['~>1s']=18 },
}

Test { [[
native _V;
native/pre do
    int V = 1;
end
code/await Ff (none)->none do
    do finalize with
        _V = _V * 2;
    end
    _V = _V + 1;
    await FOREVER;
end
do
    spawn Ff();
end
escape _V;
]],
    run = 4;
}

--<< CODE / AWAIT / FINALIZE

-->> CODE / AWAIT / RECURSIVE

Test { [[
code/await Tx (none) -> none do
    await Tx();
end
escape 0;
]],
    wrn = true,
    stmts = 'line 2 : invalid `await` : unexpected recursive invocation',
}

Test { [[
native _V;
native/pos do
    int V = 0;
end

code/await Tx (pool&[] Tx txs) -> none do
    _V = _V + 1;
    spawn Tx(&txs) in txs;
end

pool[] Tx txs;
await Tx(&txs);

escape _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    defines = {
        CEU_TESTS_REALLOC = 100,
    },
    --wrn = 'line 7 : unbounded recursive spawn',
    run = 101,  -- tests force 100 allocations at most
    --asr = 'runtime error: stack overflow',
}
Test { [[
native _V;
native/pos do
    int V = 0;
end

code/await Tx (pool&[] Tx txs) -> none do
    _V = _V + 1;
    spawn Tx(&txs) in txs;
end

pool[] Tx txs;
await Tx(&txs);

escape _V;
]],
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_pool='true' },
    defines = {
        CEU_STACK_MAX = 40000,
    },
    --wrn = 'line 7 : unbounded recursive spawn',
    run = 'runtime error: stack overflow',
}
Test { [[
native _V;
native/pos do
    int V = 0;
end

code/await Tx (none) -> none do
    pool[] Tx ts;
    _V = _V + 1;
    spawn Tx() in ts;
end

await Tx();

escape _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    defines = {
        CEU_TESTS_REALLOC = 100,
    },
    --wrn = 'line 7 : unbounded recursive spawn',
    run = 101,  -- tests force 100 allocations at most
    --asr = 'runtime error: stack overflow',
}

Test { [[
code/await Tx (var& Tx txs) -> none;
escape 0;
]],
    dcls = 'line 1 : invalid declaration : `code/await` must execute forever',
}

Test { [[
code/await Tx (var&? Tx txs) -> NEVER;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await Tx (var& Tx txs) -> NEVER;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await Ff (pool&[] Ff fs) -> (var int y) -> int do
    y = 10;
    await async do end

    var&? Ff f;
    loop f in fs do
        escape f!.y;
    end

    escape 0;
end

pool[] Ff fs;
var&? Ff f;
f = spawn Ff(&fs) in fs;
var int? y = await f;
escape y!;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
}

Test { [[
code/await Ff (pool&[] Ff fs) -> (var int y) -> int do
    y = 10;
    code/await Gg (none) -> int do
        var&? Ff f;
        loop f in outer.fs do
            escape f!.y;
        end
        escape 0;
    end
    var int x = await Gg();
    await async do end;
    escape x;
end

pool[] Ff fs;
spawn Ff(&fs) in fs;
var int x = await Ff(&fs);
escape x;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
}

--<< CODE / AWAIT / RECURSIVE

-->> C FIELDS / DIRECT ACCESS / TCEU_MEM
Test { [[
native __ceu_mem, _tceu_code_mem_ROOT;
var int xxx = 10;
escape (__ceu_mem as _tceu_code_mem_ROOT&&):xxx;
]],
    run = 10,
}

Test { [[
native __ceu_mem, _tceu_code_mem_ROOT;
do/_
    var int xxx = 10;
    escape (__ceu_mem as _tceu_code_mem_ROOT&&):xxx;
end
]],
    cc = '4:64: error: ‘tceu_code_mem_ROOT {aka struct tceu_code_mem_ROOT}’ has no member named ‘xxx’',
}

Test { [[
par/and do
    var int xxx = 10;
with
    var int xxx = 10;
end
escape 1;
]],
    run = 1,
}

Test { [[
native __ceu_mem, _tceu_code_mem_Ff;
code/await Ff (none) -> int do
    var int yyy = 10;
    escape (__ceu_mem as _tceu_code_mem_Ff&&):yyy;
end
var int v = await Ff();
escape v;
]],
    run = 10,
}

Test { [[
native __ceu_mem, _tceu_code_mem_Ff;
code/tight Ff (none) -> int do
    var int yyy = 10;
    escape (__ceu_mem as _tceu_code_mem_Ff&&):yyy;
end
var int v = call Ff();
escape v;
]],
    run = 10,
}

Test { [[
native __ceu_mem, _tceu_code_mem_Ff;
code/await Ff (none) -> int do
    do/_
        var int yyy = 10;
        escape (__ceu_mem as _tceu_code_mem_Ff&&):yyy;
    end
end
var int v = await Ff();
escape v;
]],
    cc = '5:82: error: ‘tceu_code_mem_Ff {aka struct tceu_code_mem_Ff}’ has no member named ‘yyy’',
}

Test { [[
native __ceu_mem, _tceu_code_mem_Ff;
code/await Ff (none) -> NEVER do
    do/_
        var int yyy = 10;
        var int zzz = (__ceu_mem as _tceu_code_mem_Ff&&):yyy;
    end
    await FOREVER;
end
spawn Ff();
escape 10;
]],
    cc = '5:84: error: ‘tceu_code_mem_Ff {aka struct tceu_code_mem_Ff}’ has no member named ‘yyy’',
}

Test { [[
native __ceu_mem, _tceu_code_mem_Ff;
code/await Ff (var int xxx) -> int do
    escape (__ceu_mem as _tceu_code_mem_Ff&&):xxx;
end
var int yyy = await Ff(10);
escape yyy;
]],
    wrn = true,
    run = 10,
}

Test { [[
code/await Ff (none) -> NEVER do
    par do
        var int e=_;
    with
        var int e=_;
    end
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await Ff (none) -> NEVER do
    par do
        var int yyy = 10;
    with
        var int yyy = 10;
    end
end
spawn Ff();
escape 10;
]],
    run = 10,
}
--<< C FIELDS / DIRECT ACCESS / TCEU_MEM

-- BUG #100
Test { [=[
event none a;
var int ret = 0;

spawn do
    await async do end;
    ret = 10;
    emit a;
    ret = 20;
    emit a;
end

do
    await a;
end
par/or do
    await FOREVER;
with
    await a;
end

escape ret;
]=],
    wrn = true,
    run = 20;
}

-- BUG #100
Test { [[
event none a;
var int ret = 0;

spawn do
    await async do end;
    emit a;
    ret = 10;
    emit a;
    ret = 20;
end

do
    await a;
end
par/or do
    await FOREVER;
with
    await a;
end

escape ret;
]],
    run = 10,
}

Test { [=[
native/pre do
    int V = 0;
end

code/await UV_FS_Write2 (none) -> none do
    await 1s;
    {V++;}
end

do
    await 1s;
end
par/or do
    await FOREVER;
with
    await UV_FS_Write2();
end

escape {V};
]=],
    wrn = true,
    run = {['~>2s']=1},
}

Test { [=[
native/pre do
    int V = 0;
end

code/await UV_FS_Write2 (none) -> none do
    await 1s;
    {V++;}
end

do
    await UV_FS_Write2();
end
par/or do
    await FOREVER;
with
    await UV_FS_Write2();
end

escape {V};
]=],
    wrn = true,
    run = {['~>2s']=2},
}

Test { [[
input none A;
var int ret = 0;
code/await Ff (none) -> none do
    await A;
    outer.ret = 10;
end
await Ff();
escape ret+1;
]],
    run = {['~>A']=11},
}

Test { [[
code/await Ff (none) -> none do
end
await Ff();
escape 1;
]],
    run = 1,
}
Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
var& Ff f = spawn Ff();
escape 1;
]],
    run = 1,
}
--<<< CODE / AWAIT / FUNCTIONS

-- TODO: SKIP-03

-->>> POOL ITERATORS

Test { [[
var int ts = _;
loop t in ts do
end
escape 1;
]],
    dcls = 'line 2 : internal identifier "t" is not declared',
    --parser = 'line 2 : after `in` : expected `[` or `]`',
}

Test { [[
var int ts = _;
loop _ in ts do
end
escape 1;
]],
    wrn = true,
    stmts = 'line 2 : invalid `pool` iterator : unexpected context for variable "ts"',
}

Test { [[
code/await Ff (none) -> none do
    await FOREVER;
end

pool[5] Ff fs;

var int n = 0;
loop _ in fs do
    n = n + 1;
end

escape n+1;
]],
    _opts = { ceu_features_pool='true' },
    run = 1,
}

Test { [[
code/await Ff (none) -> none do
end
var int i;
pool[1] Ff player;
var&? Ff player1;
loop player1 in player do
    break;
end
escape 1;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 1,
}

Test { [[
code/await Ff (none) -> none do
    await FOREVER;
end

pool[5] Ff fs;

var int i;
loop i in [0 -> 10] do
    spawn Ff() in fs;
end

var int n = 0;
loop _ in fs do
    n = n + 1;
end

escape n;
]],
    _opts = { ceu_features_pool='true' },
    run = 5,
}

Test { [[
code/await Ff (var int x) -> none do
    if x == 1 then
        await FOREVER;
    end
end

pool[5] Ff fs;

var int i;
loop i in [0 -> 8] do
    spawn Ff(i%2) in fs;
end

var int n = 0;
loop _ in fs do
    n = n + 1;
end

escape n;
]],
    _opts = { ceu_features_pool='true' },
    run = 4,
}

Test { [[
code/await Ff (none) -> none do
end

pool[1] Ff fs;

var int n = 0;
loop (n) in fs do
end

escape n+1;
]],
    parser = 'line 7 : after `loop` : expected `do` or internal identifier or `_`',
}

Test { [[
code/await Ff (none) -> none do
end

pool[1] Ff fs;

var&? Ff f;
loop f in fs do
end

escape 1;
]],
    _opts = { ceu_features_pool='true' },
    run = 1,
    --dcls = 'line 6 : variable "f" declared but not used',
    --stmts = 'line 7 : invalid `loop` : expected 0 argument(s)',
}

Test { [[
code/await Ff (none) -> none do
end
spawn Ff(_);
escape 0;
]],
    dcls = 'line 3 : invalid call : expected 0 argument(s)',
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int xx = 10;
    x = &xx;
    await FOREVER;
end

pool[1] Ff fs;

var& Ff n;
loop n in fs do
end

escape n+1;
]],
    _opts = { ceu_features_pool='true' },
    dcls = 'line 9 : invalid declaration : `code/await` must execute forever',
    --dcls = 'line 9 : invalid declaration : unexpected context for `code` "Ff"',
    --stmts = 'line 10 : invalid binding : argument #1 : expected alias `&` declaration',
}

Test { [[
code/await Ff (none) -> (var& int x) -> NEVER do
    var int xx = 10;
    x = &xx;
    await FOREVER;
end

pool[1] Ff fs;

var& Ff n;
loop n in fs do
end

escape 1;
]],
    _opts = { ceu_features_pool='true' },
    run = 1,
    --dcls = 'line 9 : invalid declaration : unexpected context for `code` "Ff"',
    --stmts = 'line 10 : invalid binding : argument #1 : expected alias `&` declaration',
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int xx = 10;
    x = &xx;
    await FOREVER;
end

pool[1] Ff fs;

var&? Ff n;
loop n in fs do
end

escape n;
]],
    _opts = { ceu_features_pool='true' },
    stmts = 'line 13 : invalid `escape` : expected operator `!`',
    --props_ = 'line 13 : invalid access to internal identifier "n" : crossed `loop` (/tmp/tmp.ceu:10)',
    --props_ = 'line 13 : invalid access to internal identifier "n" : crossed yielding statement (/tmp/tmp.ceu:10)',
}

Test { [[
code/await Gg (var int x) -> (var& int y) -> none do end
code/await Ff (var int x) -> (var& int y) -> none do
    y = &x;
    if x == 1 then
        await FOREVER;
    end
end

pool[5] Ff fs;

var int i;
loop i in [0 -> 8] do
    spawn Ff(i%2) in fs;
end

var int ret = 0;
var&? Gg n;
loop n in fs do
end

escape 0;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    --stmts = 'line 17 : invalid binding : argument #1 : types mismatch : "int" <= "bool"',
    stmts = 'line 18 : invalid control variable : types mismatch : "Gg" <= "Ff"',
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end

pool[5] Ff fs;
spawn Ff() in fs;
spawn Ff() in fs;

var int ret = 0;
loop _ in fs do
    ret = ret + 1;
end
escape ret;
]],
    _opts = { ceu_features_pool='true' },
    run = 2,
}

Test { [[
code/await Ff (none) -> none do
    await FOREVER;
end

pool[5] Ff fs;
spawn Ff() in fs;
spawn Ff() in fs;

var int ret = 0;
var&? Ff fff;
loop fff in fs do
    ret = ret + 1;
end
escape ret;
]],
    _opts = { ceu_features_pool='true' },
    run = 2,
}

Test { [[
code/await Ff (var int x) -> (var& int y) -> none do
    y = &x;
    if x%2 == 1 then
        await FOREVER;
    end
end

pool[5] Ff fs;

var int i;
loop i in [0 -> 8] do
    spawn Ff(i) in fs;
end

var int ret = 0;
var&? Ff fff;
loop fff in fs do
    ret = ret + fff!.y;
end

escape ret;
]],
    _opts = { ceu_features_pool='true' },
    run = 16,
}

Test { [[
loop in gs do
    ret = ret + 1;
end
]],
    parser = 'line 1 : after `loop` : expected `do` or internal identifier or `_`',
}

Test { [[
code/await Gg (none) -> none do
    await FOREVER;
end

pool[3] Gg gs;
spawn Gg() in gs;

pool&[3] Gg gs_ = &gs;

var int ret = 0;
loop _ in gs_ do
    ret = ret + 1;
end

spawn Gg() in gs_;

loop _ in gs do
    ret = ret + 1;
end

escape ret;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 3,
}

Test { [[
code/await Gg (none) -> none do
end

code/await Ff (none) -> none do
end

pool[4] Gg gs;

await Ff();

loop _ in gs do
end

escape 1;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 1,
}

Test { [[
code/await Gg (none) -> none do
    await FOREVER;
end

code/await Ff (pool&[4] Gg gs, var& int ret) -> none do
    loop _ in gs do
        ret = ret + 1;
    end
    spawn Gg() in gs;
end

pool[4] Gg gs;
spawn Gg() in gs;

pool&[3] Gg gs_ = &gs;

var int ret = 0;
loop _ in gs_ do
    ret = ret + 1;
end

spawn Gg() in gs_;

loop _ in gs do
    ret = ret + 1;
end

await Ff(&gs_, &ret);

loop _ in gs_ do
    ret = ret + 1;
end

escape ret;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 8,
}

Test { [[
native _V;
native/pos do
    int V = 0;
end

code/await Ff (none) -> none do
    every 1s do
        _V = _V + 1;
    end
end

pool[1] Ff fff;
spawn Ff() in fff;
par/and do
with
end
await 10s;
escape _V;
]],
    _opts = { ceu_features_pool='true' },
    run = { ['~>10s'] = 10 },
}

Test { [[
code/await Ff (none) -> (var& int y) -> none do
    var int x = 0;
    y = &x;
end

pool[5] Ff fs;

var& int nn;
var&? Ff fff;
loop fff in fs do
    nn = &fff!.y;
end

escape nn;
]],
    _opts = { ceu_features_pool='true' },
    inits = 'line 11 : invalid binding : crossing `loop` (/tmp/tmp.ceu:10)',
    --inits = 'line 8 : uninitialized variable "nn" : reached `loop`',
    --props_ = 'line 14 : invalid access to internal identifier "nn" : crossed `loop` (/tmp/tmp.ceu:10)',
    --props_ = 'line 14 : invalid access to internal identifier "nn" : crossed yielding statement (/tmp/tmp.ceu:10)',
}

Test { [[
code/await Ff (none) -> none do
end

pool[] Ff ffs;

loop _ in ffs do
    continue;
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await FOREVER;
end

pool[] Ff ffs;

var&? Ff fff;
loop fff in ffs do
    await 1s;
end

escape 1;
]],
    --props_ = 'line 11 : invalid `await` : unexpected enclosing `loop`',
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = {['~>1s']=1},
}

Test { [[
code/await Ff (event& none e) -> none do
    await async do end
    emit e;
end

event none e;
pool[] Ff ffs;
spawn Ff(&e) in ffs;
await e;
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
native _V;
native/pos do
    int V = 0;
end

code/await Gg (none) -> NEVER do
    _V = _V + 1;
    await FOREVER;
end

code/await Ff (pool&[] Gg ggs) -> none do
    spawn Gg() in ggs;
    spawn Gg() in ggs;
end

pool[1] Gg ggs;
await Ff(&ggs);

escape _V;
]],
    _opts = { ceu_features_pool='true' },
    run = 1,
}

-->> POOL / LOOP

Test { [[
code/await Ff (none) -> (var& int x) -> none do
                        // error
    var int v = 10;
    x = &v;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var&? int x = do
    var&? Ff fff;
    loop fff in ffs do
        escape &fff!.x;
    end
end;

escape (x? as int) + 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    --dcls = 'line 10 : invalid declaration : option alias : expected native or `code/await` type',
    --stmts = 'line 13 : invalid binding : unmatching alias `&` declaration',
    scopes = 'line 13 : invalid binding : unexpected source with `&?` : destination may outlive source',
}
Test { [[
code/await Ff (none) -> (var& int x) -> none do
                        // error
    var int v = 10;
    x = &v;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var& int x = do
    var&? Ff fff;
    loop fff in ffs do
        escape &fff!.x;
    end
end;

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    --dcls = 'line 10 : invalid declaration : option alias : expected native or `code/await` type',
    --stmts = 'line 13 : invalid binding : unmatching alias `&` declaration',
    scopes = 'line 13 : invalid binding : unexpected source with `&?` : destination may outlive source',
}
Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var&? Ff f1 = do
    var&? Ff f2;
    loop f2 in ffs do
        escape &f2;
    end
end;

escape (f1? as int) + 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
    --stmts = 'line 12 : invalid binding : argument #1 : unmatching alias `&` declaration',
}
Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 1ms;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var&? Ff f1 = do
    var&? Ff f2;
    loop f2 in ffs do
        escape &f2;
    end
end;

var int ret = (f1? as int);
await 1s;
escape ret + (f1? as int);
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>1s']=1 },
    --stmts = 'line 12 : invalid binding : argument #1 : unmatching alias `&` declaration',
}

Test { [[
code/await Ff (none) -> none do end
pool[] Ff fs;
var&? Ff ff = do
    every 1s do
        var&? Ff f;
        loop f in fs do
            escape &f;
        end
    end
end;
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = false,
}

Test { [[
code/await Ff (var int x) -> (var int y) -> NEVER do
    y = x;
    await FOREVER;
end

pool[] Ff fs;
spawn Ff(10) in fs;
spawn Ff(20) in fs;
spawn Ff(30) in fs;

var&? Ff ff = do
    every 1s do
        var&? Ff f;
        loop f in fs do
            if f!.y == 20 then
                escape &f;
            end
        end
    end
end;

escape ff!.y;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = {['~>1s']=20},
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var&? Ff f;
loop f in ffs do
    break;
end

escape (f? as int) + 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}
Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await FOREVER;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var&? Ff f;
loop f in ffs do
    break;
end

escape f!.x;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
}

Test { [[
code/await Ff (none) -> (var& int yyy) -> none do
    var int v = 10;
    yyy = &v;
    await 1s;
end

pool[] Ff ffs;
spawn Ff() in ffs;

    var&? Ff f;
    loop f in ffs do
        break;
    end

escape f!.yyy;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
}
Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 1s;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var&? Ff f1 = do
    var&? Ff f2;
    loop f2 in ffs do
        escape &f2;
    end
end;

escape f1!.x;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
}
Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 1s;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var&? Ff x_;
loop x_ in ffs do
    break;
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 1s;
end

pool[] Ff ffs;
spawn Ff() in ffs;

    var&? Ff x_;
    loop x_ in ffs do
        break;
    end
var int ret = x_!.x;
watching x_ do
    every 100ms do
        ret = ret + 1;
    end
end

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>1s']=19 },
}

Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await 1s;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var&? Ff x = do
    var&? Ff x_;
    loop x_ in ffs do
        escape &x_;
    end
end;
var int ret = x!.x;
watching x do
    every 100ms do
        ret = ret + 1;
    end
end

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>1s']=19 },
}

Test { [[
code/await Ff (var& int ret) -> (var& int x, event& none e) -> NEVER do
    var int x_ = 0;
    x = &x_;
    event none e_;
    e = &e_;
    await e_;
    ret = ret + x_;
    await FOREVER;
end

var int ret = 5;

pool[] Ff ffs;
spawn Ff(&ret) in ffs;
spawn Ff(&ret) in ffs;

var&? Ff x;
loop x in ffs do
    x!.x = ret;
    emit x!.e;
end

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 20,
}

Test { [[
code/await Ff (none) -> (var& int x, event& none e) -> none do
    var int x_ = 0;
    x = &x_;
    event none e_;
    e = &e_;
    await e_;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var&? Ff x;
loop x in ffs do
    emit x!.e;
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
    --props_ = 'line 14 : invalid declaration : expected `&?` modifier : yielding `loop`',
}

Test { [[
code/await Ff (none) -> (event none eee) -> none do
    await eee;
end

pool[] Ff ffs;
spawn Ff() in ffs;

var&? Ff fff;
loop fff in ffs do
    emit fff!.eee; // kill iterator (why?)
end

loop _ in ffs do
    escape 99;  // yes (no!)
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
    --run = 99,
}

Test { [[
input none A;

code/await Ff (none) -> (event& none eee) -> none do
    event none eee_;
    eee = &eee_;
    await eee_;
end

pool[] Ff ffs;
spawn Ff() in ffs;

    var&? Ff fff;
    loop fff in ffs do
        emit fff!.eee; // kill iterator
    end

loop _ in ffs do
    escape 99;  // yes
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    --run = { ['~>A']=99 },
    run = { ['~>A']=1 },
}

-- valgrind fails
Test { [[
input none A;

native _V, _ceu_assert;
native/pos do
    int V = 0;
end

code/await Ff (none) -> (event& none e) -> none do
    event none e_;
    e = &e_;
    await e_;
    _ceu_assert(_V == 0, "bug found");
    _V = _V + 1;
end

event none g;
pool[] Ff ffs;
spawn Ff() in ffs;

watching g do
    var&? Ff f;
    loop f in ffs do
        emit f!.e; // kill 1st, but don't delete
        emit g; // kill iterator
    end
end

var&? Ff f;
loop f in ffs do
    emit f!.e;     // no awake!
    escape 99;  // nooo
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>A']=1 },
}

Test { [[
code/await Ff (none) -> (var& int x, event& none e) -> none do
    var int v = 10;
    x = &v;
    event none e_;
    e = &e_;
    await e_;
end

pool[] Ff ffs;
spawn Ff() in ffs;
spawn Ff() in ffs;

var int ret = 0;
var&? Ff f1;
loop f1 in ffs do
    emit f1!.e;
    var&? Ff f2;
    loop f2 in ffs do
        ret = ret + f2!.x;
        emit f2!.e;
    end
end

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
}
Test { [[
code/await Ff (none) -> (var& int x, event& none e) -> none do
    var int v = 10;
    x = &v;
    event none e_;
    e = &e_;
    await e_;
end

pool[1] Ff ffs;

var&? Ff fa = spawn Ff() in ffs;

emit fa!.e;

var&? Ff fc = spawn Ff() in ffs;
var bool b3 = fc?;                  // b3=1

//{printf("%d %d %d %d\n", @b1, @b2, @b3, @b4);}
escape (b3 as int);
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
code/await Ff (none) -> (var& int x, event& none e) -> none do
    var int v = 10;
    x = &v;
    event none e_;
    e = &e_;
    await e_;
end

pool[2] Ff ffs;

var&? Ff fa = spawn Ff() in ffs;
var&? Ff fb = spawn Ff() in ffs;
var bool b1 = fa?;                  // b1=1
var bool b2 = fb?;                  // b2=1

event none g;

var int ret = 0;                    // ret=0
watching g do
    var&? Ff f1;
    loop f1 in ffs do
        emit f1!.e;
        var&? Ff f2;
        loop f2 in ffs do
            ret = ret + f2!.x;              // ret=10
            emit f2!.e;
            ret = ret + (f2? as int) + 1;   // ret=11
            emit g;
        end
    end
end

var&? Ff fc = spawn Ff() in ffs;
var&? Ff fd = spawn Ff() in ffs;
var bool b3 = fc?;                  // b3=1
var bool b4 = fd?;                  // b4=1

//{printf("%d %d %d %d\n", @b1, @b2, @b3, @b4);}
escape ret + (b1 as int) + (b2 as int) + (b3 as int) + (b4 as int);
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 15,
}

Test { [[
event& none e2;
if e2? then
    emit e2;
end
escape 1;
]],
    dcls = 'line 2 : invalid operand to `?` : unexpected context for event "e2"',
}

Test { [[
event&? none e2;
if e2? then
    emit e2!;
end
escape 1;
]],
    --inits = 'line 1 : uninitialized event "e2" : reached `emit` (/tmp/tmp.ceu:3)',
    --inits = 'line 1 : uninitialized event "e2" : reached yielding statement (/tmp/tmp.ceu:3)',
    --inits = 'line 1 : uninitialized event "e2" : reached read access (/tmp/tmp.ceu:3)',
    parser = 'line 1 : after `&` : expected `(` or type',
}

Test { [[
input none A;

code/await Ff (none) -> (var& int x, event& none e) -> none do
    var int x_ = 0;
    x = &x_;
    event none e_;
    e = &e_;
    par/or do
        await e_;
    with
        var int y = 0;
        every A do
            y = y + 1;
        end
    end
end

pool[] Ff ffs;
spawn Ff() in ffs;
spawn Ff() in ffs;
spawn Ff() in ffs;

await A;

var&? Ff f1;
loop f1 in ffs do
    var&? Ff f2;
    loop f2 in ffs do
        if f1? then
            emit f1!.e;
        end
        if f2? then
            emit f2!.e;
        end
    end
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>A']=1 },
}

Test { [[
code/await Ff (none) -> (var& int x, event& int e) -> none do
    var int v = 10;
    x = &v;

    event int e_;
    e = &e_;
    var int vv = await e_;

    v = v + vv;
    await async do end
end

pool[] Ff ffs;

var&? Ff f = spawn Ff() in ffs;

var int ret = 0;

par/and do
    await f!.e;
with
    await f;
with
    emit f!.e(20);
    ret = f!.x;
end

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 30,
}


Test { [[
code/await Ff (none) -> (var& int x) -> none do
    var int v = 10;
    x = &v;
    await async do end
end

pool[] Ff ffs;

var&? Ff f = spawn Ff() in ffs;
escape f!.x;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
}

Test { [[
native _printf;
native _V;
native/pos do
    int V = 0;
end

code/await Bird (none) -> (event& none e) -> NEVER
do
    event none e_;
    e = &e_;

    await e_;
    _V = _V + 1;

    await FOREVER;
end

pool[5] Bird birds;

spawn Bird() in birds;
spawn Bird() in birds;

await async do end;

loop _ in birds do
end

var&? Bird f;
loop f in birds do
    _V = _V + 1;
    emit f!.e;
end

escape _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = 4,
}

Test { [[
//native _printf;
native _V;
native/pos do
    int V = 0;
end

code/await Bird (none) -> (event& none e) -> none
do
    event none e_;
    e = &e_;

    await e_;
    _V = _V + 1;
end

pool[1] Bird birds_;
pool[5] Bird birds;

spawn Bird() in birds;
spawn Bird() in birds;
spawn Bird() in birds;
spawn Bird() in birds_;

var&? Bird f1;
var int i = 0;
loop f1 in birds do
    var&? Bird f2;
    var int j = 0;
    loop f2 in birds do
        if (i==1 and j==2) then
            _V = _V + 1;
            emit f2!.e;
        end
        j = j + 1;
    end
    i = i + 1;
end

//_printf(">>> %d\n", _V);
escape _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = 2,
}

Test { [[
native _V;
native/pure _fff;
native/nohold _ceu_assert;
native/pos do
    ##define fff(x) x
    none* V;
end

data Ii;

code/await Cloud (none) -> (var& Ii i) -> NEVER do
    var Ii i_ = val Ii();
    i = &i_;
    await FOREVER;
end

pool[] Cloud clouds;
spawn Cloud() in clouds;
spawn Cloud() in clouds;

code/await Collides (none) -> none do end

code/await Collisions (none) -> none do
    var&? Cloud cloud1;
    loop cloud1 in outer.clouds do
        var&? Cloud cloud2;
        loop cloud2 in outer.clouds do
            _V = _fff(&&cloud1!.i);
            spawn Collides();
            _ceu_assert(_V == &&cloud1!.i, "bug found");
        end
    end
end
await Collisions();
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
    --props_ = 'line 29 : invalid `spawn` : unexpected enclosing `loop`',
}

Test { [[
native _ceu_assert;
input none A; input none  B;

code/await Ph (none) -> none do
    await B;
    _ceu_assert(0, "bug found");
end

code/await Drop (none) -> NEVER do
    spawn Ph();
    await FOREVER;
end

pool[] Drop  drops;

await A;
spawn Drop() in drops;
do end

await FOREVER;
]],
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>A;~>B'] = '6] -> runtime error: bug found' },
}

Test { [[
code/await Gg (none) -> NEVER do
end

pool[] Gg gs;
var&? Gg g;
loop g in gs do
    await 1s;
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = {['~>1s']=1},
}

Test { [[
code/await Gg (var& int x) -> NEVER do
    await FOREVER;
end
pool[] Gg gs;
do
    var int x = 10;
    spawn Gg(&x) in gs;
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    scopes = 'line 7 : invalid binding : incompatible scopes',
}
Test { [[
code/await Gg (var& int x) -> NEVER do
    await FOREVER;
end
do
    pool[] Gg gs;
    var int x = 10;
    spawn Gg(&x) in gs;
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = 1,
}
Test { [[
code/await Ff (none) -> (var int x) -> NEVER do
    x = 10;
    await FOREVER;
end

code/await Gg (var&? Ff f, var& int x) -> NEVER do
    await FOREVER;
end

var&? Ff f = spawn Ff();
watching f do
    pool[] Gg gs;
    spawn Gg(&f, &f.x) in gs;
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = 1,
}
Test { [[
code/await Ff (none) -> (var int x) -> NEVER do
    x = 10;
    await FOREVER;
end

code/await Gg (var&? Ff f, var& int x) -> NEVER do
    await FOREVER;
end

pool[] Gg gs;
var&? Ff f = spawn Ff();
watching f do
    spawn Gg(&f, &f.x) in gs;
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    scopes = 'line 13 : invalid binding : incompatible scopes',
}

Test { [[
code/await Ff (none) -> none do
end

pool[1] Ff fs;
var&? Ff f;
event none e;
watching e do
    loop f in fs do
        emit e;
    end
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_pool='true' },
}

--<< POOL / LOOP
--||| TODO: POOL ITERATORS

Test { [[
code/await Tx (none) -> none do end
var bool ok1 = spawn Tx();
escape 1;
]],
    --run = 1,
    --parser = 'line 2 : after `)` : expected `->` or `in`',
    stmts = 'line 2 : invalid constructor : types mismatch : "bool" <= "Tx"',
}
Test { [[
code/await Tx (none) -> none do end
pool[1] Tx ts;
var Tx&&?  ok1 = spawn Tx() in ts;
escape 0;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    dcls = 'line 3 : invalid declaration : unexpected context for `code` "Tx"',
}
Test { [[
code/await Tx (none) -> none do end
pool[1] Tx ts;
var[] int ok1 = spawn Tx() in ts;
escape 0;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    stmts = 'line 3 : invalid constructor : unexpected context for vector "ok1"',
}
Test { [[
code/await Tx (none) -> none do end
pool[1] Tx ts;
var int ok1 = spawn Tx() in ts;
escape 0;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    --stmts = 'line 3 : invalid constructor : expected `bool` destination',
    stmts = 'line 3 : invalid constructor : types mismatch : "int" <= "Tx"',
}

Test { [[
code/await Tx (none)->none do await FOREVER; end;
pool[10] Tx ts;
spawn Tx() in ts;
var int ret = 0;
loop _ in ts do
    ret = ret + 1;
    spawn Tx() in ts;
end
escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10,
    --props = 'line 6 : pool iterator cannot contain yielding statements (`await`, `emit`, `spawn`, `kill`)',
}

Test { [[
code/await Tx (none) -> none do end
pool[] Tx t;
spawn Tx() in t;
spawn Tx();
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
native _V;
native/pos do
    int V = 0;
end
code/await Tx (var int v1)->(var& int v2)->none do
    _V = _V + v1;
    var int x = v1;
    v2 = &x;
    await async do end;
end
pool[] Tx ts;
spawn Tx(10) in ts;
spawn Tx(20);
var int ret = 0;
var&? Tx v;
loop v in ts do
    ret = ret + v!.v2;
end
escape ret + _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 40,
}

Test { [[
native _V;
native/pos do
    int V = 0;
end
code/await Tx (var int v1)->(var& int v2)->none do
    _V = _V + v1;
    var int x = v1;
    v2 = &x;
    await async do end;
end
pool[] Tx ts;
spawn Tx(10);
spawn Tx(20) in ts;
var int ret = 0;
var&? Tx v;
loop v in ts do
    ret = ret + v!.v2;
end
escape ret + _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 50,
}

Test { [[
code/await Tx (none)->none do
    await FOREVER;
end

pool[2] Tx ts;
spawn Tx() in ts;
spawn Tx() in ts;

input none OS_START;
await OS_START;
escape 60;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 60,
}
Test { [[
code/await Tx (none)->none do await FOREVER; end
pool[] Tx ts;
spawn Tx() in ts;
spawn Tx() in ts;
escape 60;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 60,
}

Test { [[
code/await Tx (none)->none do await FOREVER; end
pool[] Tx ts;
spawn Tx() in ts;
spawn Tx() in ts;
input none OS_START;
await OS_START;
escape 60;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 60,
}

Test { [[
native _V;
native/pos do
    int V = 0;
end
code/await Tx (var int v1)->(var& int v2)->none do
    _V = _V + v1;
    var int x = v1;
    v2 = &x;
    await async do end;
end
pool[] Tx ts;
spawn Tx(10) in ts;
spawn Tx(20) in ts;
var int ret = 0;
var&? Tx v;
loop v in ts do
    ret = ret + v!.v2;
end
escape ret + _V;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 60,
}

Test { [[
data Dd;
data Dd.Aa;

code/await Ff (var& Dd vis) -> NEVER do
    await FOREVER;
end

pool[] Ff fs;

code/await Gg (none) -> NEVER do
    var int x1 = 0;
    var int x2 = 0;
    var int x3 = 0;
    var int x4 = 0;
    await FOREVER;
end

spawn Gg() in fs;
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = 1,
}

Test { [[
native/pre do
    int V = 0;
end

code/await Gg (none) -> NEVER do
    every 100ms do
        {V++;}
    end
end

code/await Ff (none) -> (pool[1] Gg gs) -> NEVER do
    pool[1] Gg gs_;
    spawn Gg() in gs_;
    spawn Gg() in gs;
    await FOREVER;
end

spawn Ff();
await 1s;
escape {V};
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = {['~>1s']=20},
}
Test { [[
native/pre do
    int V = 0;
end

code/await Gg (none) -> NEVER do
    every 100ms do
        {V++;}
    end
end

code/await Ff (none) -> (pool[1] Gg gs1, pool[1] Gg gs2) -> NEVER do
    pool[1] Gg gs_;
    spawn Gg() in gs_;
    spawn Gg() in gs1;
    spawn Gg() in gs2;
    await FOREVER;
end

spawn Ff();
await 1s;
escape {V};
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = {['~>1s']=30},
}

Test { [[
code/await Light (pool&[] Light    lights,
                  var     int?     direction,
                  var     int?     magnitude,
                  var     bool?    is_fork,
                 ) -> none
do
end

pool[] Light lights;

spawn Light(&lights,_,_,_) in lights;

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = 1,
}

-->> POOL/SPAWN/OPTION

Test { [[
code/await Tx (var int v1)->(var& int v2)->none do
    var int x = v1;
    v2 = &x;
end

var&? Tx v;
v = spawn Tx(10);;
escape v!.v2;
]],
    --asr = '7] runtime error: invalid tag',
    run = '8] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
code/await Tx (var int v1)->(var& int v2)->none do
    var int x = v1;
    v2 = &x;
end

var&? Tx v;
v = spawn Tx(10);
await async do end
escape v!.v2;
]],
    --asr = '7] runtime error: invalid tag',
    _opts = { ceu_features_trace='true' },
    run = '9] -> runtime error: value is not set',
}

Test { [[
data Dd with
    var int v = 10;
end

code/await Ff (none) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd(_);
    d = &d_;
    await FOREVER;
end

pool[] Ff fs;
spawn Ff() in fs;

var int ret = 0;

watching 10s do
    every 1s do
        var&? Ff d;
        loop d in fs do
            ret = ret + d.d.v;
        end
    end
end

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    dcls = 'line 20 : invalid operand to `.` : unexpected option alias',
}

Test { [[
data Dd with
    var int v = 10;
end

code/await Ff (none) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd(_);
    d = &d_;
    await FOREVER;
end

pool[] Ff fs;
spawn Ff() in fs;

var int ret = 0;

watching 10s do
    every 1s do
        var&? Ff f;
        loop f in fs do
            ret = ret + f!.d.v;
        end
    end
end

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = {['~>10s']=90},
}

Test { [[
code/await Tx (none) -> none do
    par/or do
        await 10s;
    with
        await 10s;
    with
        await 10s;
    end
end
pool[] Tx ts;
    spawn Tx() in ts;
    spawn Tx() in ts;
    spawn Tx() in ts;
escape 10;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10;
}

Test { [[
code/await Tx (none) -> none do
    par/or do
        await 10s;
    with
        await 10s;
    with
        await 10s;
    end
end
pool[] Tx ts;
do
    spawn Tx() in ts;
    spawn Tx() in ts;
    spawn Tx() in ts;
end
escape 10;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 10;
}

Test { [[
spawn i;
]],
    --parser = 'line 1 : after `spawn` : expected `(` or `do` or `async/isr` or abstraction identifier',
    parser = 'line 1 : after `i` : expected `[` or `:` or `.` or `!` or `as`',
}

Test { [[
_f(spawn Tx);
]],
    --parser = 'line 1 : after `(` : expected `)`',
    parser = 'line 1 : after `(` : expected expression',
}

Test { [[
spawn Uu();
]],
    dcls = 'line 1 : abstraction "Uu" is not declared',
}

Test { [[
code/await Tx (none) -> none do
    spawn Tx();
end
escape 10;
]],
    wrn = true,
    stmts = 'line 2 : invalid `spawn` : unexpected recursive invocation',
}

Test { [[
code/await Tx (none)->(event& none e)->none do
    event none e_;
    e = &e_;
end

var&? Tx t =
spawn Tx();
await t!.e;
escape 1;
]],
    wrn = true,
    run = '8] -> runtime error: value is not set',
    _opts = { ceu_features_trace='true' },
}

Test { [[
code/await Tx (none)->(event& none e)->none do
    event none e_;
    e = &e_;
    await async do end;
    emit e_;
end

var&? Tx t =
spawn Tx();
await t!.e;
escape 1;
]],
    wrn = true,
    run = 1,
}

-- fails w/o setjmp on parent orgs traversal
Test { [[
input none OS_START;

code/await Tx (none) -> none do
    await OS_START;
end

do
    await Tx();
end
do
native _char;
    var[1000] _char v = _;
    native/nohold _memset;
    _memset(&&v, 0, 1000);
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
input none A;

code/await Tx (none)->(var& int x)->none do
    var int x_=_;
    x = &x_;
    await A;
end

var&? Tx t1 =
spawn Tx();
await t1;

var&? Tx t2 =
spawn Tx();
await t2;

escape 1;
]],
    wrn = true,
    run = { ['~>A;~>A']=1 },
}

Test { [[
code/await Tx (none)->(var& int x)->none do
    var int x_=_;
    x = &x_;
    await 1us;
end

var&? Tx t1 =
spawn Tx();
await t1;

var&? Tx t2 =
spawn Tx();
await t2;

escape 1;
]],
    wrn = true,
    run = { ['~>2us']=1 },
}

Test { [[
code/await Tx (none)->(var& int x)->none do
    var int x_=_;
    x = &x_;
    await 1us;
end

var&? Tx x1 =
spawn Tx();
spawn Tx();
await x1;

var&? Tx x2 =
spawn Tx();
await x2;

escape 1;
]],
    wrn = true,
    run = { ['~>2us']=1 },
}

Test { [[
code/await Tx (none)->(var int e)->NEVER do
    e = 1;
    await FOREVER;
end

var&? Tx t = spawn Tx();

var& int e = &t!.e;

escape 0;
]],
    wrn = true,
    scopes = 'line 8 : invalid binding : unexpected source with `&?` : destination may outlive source',
}

Test { [[
code/await Tx (none)->(var int e)->NEVER do
    e = 1;
    await FOREVER;
end

code/await Ux (var& int e) -> none do end

var&? Tx t = spawn Tx();
spawn Ux(&t!.e);

escape 0;
]],
    wrn = true,
    --run = 1,
    scopes = 'line 9 : invalid binding : unexpected source with `&?` : destination may outlive source',
}

Test { [[
code/await Tx (none)->(var int e)->NEVER do
    e = 1;
    await FOREVER;
end

code/await Ux (var& int e) -> none do end

var&? Tx t = spawn Tx();
watching t do
    spawn Ux(&t.e);
end

escape 1;
]],
    wrn = true,
    run = 1,
    --scopes = 'line 9 : invalid binding : unexpected source with `&?` : destination may outlive source',
}

Test { [[
code/await Tx (none)->(event none e)->NEVER do
    await FOREVER;
end

code/await Ux (event& none e) -> none do end

var&? Tx t = spawn Tx();
spawn Ux(&t!.e);

escape 0;
]],
    wrn = true,
    --run = 1,
    scopes = 'line 8 : invalid binding : unexpected source with `&?` : destination may outlive source',
}

Test { [[
code/tight Ff (var& int x) -> int do
    escape x + 1;
end
code/await Gg (none) -> (var int x) -> NEVER do
    x = 10;
    await FOREVER;
end
var&? Gg g = spawn Gg();
var int ret = call Ff(&g!.x);
escape ret;
]],
    run = 11,
}

-- group of tests fails w/o sudden death check while traversing children
Test { [[
native _V;
input none OS_START;
native/pos do
    int V = 0;
end

code/await Tx (none)->(event& none e)->NEVER do
    event none e_;
    e = &e_;
    await FOREVER;
end

code/await Ux (var&? Tx t, var bool only_await) -> none do
    par/or do
        await t!.e;
        _V = _V + 1;
    with
        if only_await then
            await FOREVER;
        end
        await OS_START;
        emit t!.e;
    with
        await OS_START;
    end
end

var&? Tx t =
spawn Tx();

spawn Ux(&t, true);
spawn Ux(&t, false);

await OS_START;

escape _V;
]],
    run = 1,
}

Test { [[
input none OS_START;
native _V;
native/pos do
    int V = 0;
end

code/await Ux (event& none e, var bool only_await) -> none do
    par/or do
        await e;
        _V = _V + 1;
    with
        if only_await then
            await FOREVER;
        end
        await OS_START;
        emit e;
    with
        if only_await then
            await FOREVER;
        end
        await OS_START;
    end
end

event none e;

spawn Ux(&e, true);
spawn Ux(&e, false);

await OS_START;

escape _V;
]],
    run = 2,
}
Test { [[
native _V;
input none OS_START;
native/pos do
    int V = 0;
end

code/await Ux (event& none e, var bool only_await) -> none do
    par/or do
        await e;
        _V = _V + 1;
    with
        if only_await then
            await FOREVER;
        end
        await OS_START;
        emit e;
    with
        await OS_START;
    end
end

event none e;

spawn Ux(&e, true);
spawn Ux(&e, false);

await OS_START;

escape _V;
]],
    run = 1,
}
Test { [[
native _V;
input none OS_START;
native/pos do
    int V = 0;
end

code/await Ux (event& none e, var bool only_await) -> none do
    par/or do
        await e;
        _V = _V + 1;
    with
        if only_await then
            await FOREVER;
        end
        await OS_START;
        emit e;
    with
        await OS_START;
    end
end

event none e;

spawn Ux(&e, false);
spawn Ux(&e, true);

await OS_START;

escape _V;
]],
    run = 2,
}

-- u1 doesn't die, kills u2, which becomes dangling
Test { [[
native _V;
input none OS_START;
native/pos do
    int V = 0;
end

code/await Ux (event& none e, var bool only_await) -> none do
    if only_await then
        await e;
        _V = 1;
    else
        await OS_START;
        emit e;
        await FOREVER;
    end
end

event none e;

spawn Ux(&e, false);
spawn Ux(&e, true);

await OS_START;

escape _V;
]],
    run = 1,
}

Test { [[
native _V;
input none OS_START;
native/pos do
    int V = 0;
end

code/await Ux (event& none e, var bool only_await) -> none do
    if only_await then
        await e;
        _V = 1;
    else
        await OS_START;
        emit e;
        await FOREVER;
    end
end

event none e;
spawn Ux(&e, false);
spawn Ux(&e, true);

await OS_START;

escape _V;
]],
    run = 1,
}

Test { [[
code/await Ux (none)->none do
end
code/await Tx (none)->none do
    await Ux();
end
do
    pool[] Tx ts;
    spawn Tx() in ts;
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

-- fails w/o ceu_sys_stack_clear_org
Test { [[
code/await Ux (none)->none do
    await 1us;
end
code/await Tx (none)->none do
    await Ux();
end
do
    pool[] Tx ts;
    spawn Tx() in ts;
    await 1us;
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = { ['~>1us']=1 },
}

Test { [[
code/await Ff (var int x) -> (var int y) -> NEVER do
    y = x;
    await FOREVER;
end

pool[2] Ff fs;

var int ret = 0;
var int i;
loop i in [1->2] do
    var& Ff f = spawn Ff(i) in fs;
    ret = ret + f.y;
end

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 3,
}
Test { [[
code/await Ff (var int x) -> (var int y) -> NEVER do
    y = x;
    await FOREVER;
end

pool[1] Ff fs;

var int ret = 0;
var int i;
loop i in [1->2] do
    var& Ff f = spawn Ff(i) in fs;
    ret = ret + f.y;
end

escape ret;
]],
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_pool='true' },
    run = '11] -> runtime error: out of memory',
}
Test { [[
code/await Ff (var int x) -> (var int y) -> NEVER do
    y = x;
    await FOREVER;
end

pool[1] Ff fs;

var int ret = 0;
var int i;
loop i in [1->2] do
    var&? Ff f = spawn Ff(i) in fs;
    if f? then
        ret = ret + f!.y;
    end
end

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}
-- TODO: SKIP-04

-->>> STACK TRACE

Test { [[
code/await Ff (none) -> none do
    {ceu_assert(0, "hello");}
end
await Ff();
escape 0;
]],
    run = '[/tmp/tmp.ceu:4] -> \n[/tmp/tmp.ceu:2] -> runtime error: hello',
    _opts = { ceu_features_trace='true' },
}

Test { [[
code/await Ff (none) -> none do
    {ceu_assert(0, "hello");}
end
code/await Gg (none) -> none do
    await Ff();
end
await Gg();
escape 0;
]],
    run = '[/tmp/tmp.ceu:7] -> [/tmp/tmp.ceu:5] -> \n[/tmp/tmp.ceu:2] -> runtime error: hello',
    _opts = { ceu_features_trace='true' },
}

--<<< STACK TRACE

-->>> EXCEPTIONS / THROW / CATCH

Test { [[
var Exception? e;
catch e do
    var Exception e_ = val Exception(_);
    throw e_;
end

escape 1;
]],
    props_ = 'line 4 : `exception` support is disabled',
}

Test { [[
var Exception? e;
catch e do
    var Exception e_ = val Exception(_);
    throw e_;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    run = 1,
}

Test { [[
var Exception? e;
catch e do
end

if e? then
    escape 10;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    run = 1,
}

Test { [[
if true then
    var Exception e = val Exception(_);
    throw e;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    wrn = true,
    run = '3] -> runtime error: unspecified message',
}

Test { [[
if true then
    var Exception e = val Exception("alo-alo");
    throw e;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    wrn = true,
    run = '3] -> runtime error: alo-alo',
}

Test { [[
if true then
    var Exception e_ = val Exception(_);
    throw e_;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    props_ = 'line 3 : uncaught exception',
}
Test { [[
var Exception? e;
catch e do
    if true then
        var Exception e_ = val Exception(_);
        throw e_;
    end
    {ceu_assert(0,"bug found");}
end

if e? then
    escape 10;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    run = 10,
}

Test { [[
data Xx;
data Xx.Yy;
var Xx.Yy? y;
var Xx? xxx = y;
escape 1;
]],
    run = 1,
}

Test { [[
data Exception.Sub;

var Exception.Sub? e;
catch e do
    if true then
        var Exception e_ = val Exception(_);
        throw e_;
    end
    {ceu_assert(0,"bug found");}
end

if e? then
    escape 10;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    props_ = 'line 7 : uncaught exception',
}


Test { [[
if true then
    var Exception e = val Exception("alo-alo");
    throw e;
end

escape 1;
]],
    _opts = { ceu_features_exception='true' },
    wrn = true,
    run = 'Aborted (core dumped)',
}
Test { [[
data Exception.Sub;

var Exception.Sub? e;
catch e do
    if true then
        var Exception e_ = val Exception(_);
        throw e_;
    end
    {ceu_assert(0,"bug found");}
end

if e? then
    escape 10;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    run = '7] -> runtime error: unspecified message',
    wrn = true,
}

Test { [[
data Exception.Sub;

var Exception.Sub? e;
catch e do
    if true then
        var Exception.Sub e_ = val Exception.Sub(_);
        throw e_;
    end
    {ceu_assert(0,"bug found");}
end

if e? then
    escape 10;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    run = 10,
}

Test { [[
data Exception.Sub with
    var int value = 10;
end

var Exception.Sub? eee;
catch eee do
    if true then
        var Exception.Sub e_ = val Exception.Sub(_,20);
        throw e_;
    end
    {ceu_assert(0,"bug found");}
end

escape eee!.value;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    run = 20,
}

Test { [[
data Exception.Sub;

var Exception? e;
catch e do
    if true then
        var Exception.Sub e_ = val Exception.Sub(_);
        throw e_;
    end
    {ceu_assert(0,"bug found");}
end

if e? then
    escape 10;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    run = 10,
}

Test { [[
var int ret = 0;
var Exception? e;
catch e do
    do finalize with
        ret = 10;
    end
    var Exception e_ = val Exception(_);
    throw e_;
end

escape ret;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    run = 10,
}

Test { [[
var Exception? e;
catch e do
    var Exception e_ = val Exception(_);
    throw e_;
end

if e? then
    escape 10;
end

escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    run = 10,
}

Test { [[
var Exception? e;
catch e do
    var Exception e_ = val Exception(_);
    throw e_;
    nothing;
end
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    parser = 'line 4 : after `;` : expected `end`',
}

Test { [[
code/await Ff (none) -> none do
    var Exception e_ = val Exception(_);
    throw e_;
end
await Ff();
escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    props_ = 'line 3 : uncaught exception',
}

Test { [[
code/await Ff (none) -> none
    throws Ex
do
    var Exception e_ = val Exception(_);
    throw e_;
end
await Ff();
escape 1;
]],
    _opts = { ceu_features_exception='true' },
    dcls = 'line 2 : abstraction "Ex" is not declared',
}

Test { [[
code/await Ff (none) -> none
    throws Exception
do
    var Exception e_ = val Exception(_);
    throw e_;
end
await Ff();
escape 1;
]],
    _opts = { ceu_features_exception='true' },
    props_ = 'line 7 : uncaught exception',
}

Test { [[
code/await Ff (none) -> none
    throws Exception
do
    var Exception e_ = val Exception(_);
    throw e_;
end
await Ff();
escape 1;
]],
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
    wrn = true,
    run = '5] -> runtime error: unspecified message',
}

Test { [[
data Dd;
code/await Ff (none) -> none
    throws Dd
do
    var Exception e_ = val Exception(_);
    throw e_;
end
await Ff();
escape 1;
]],
    _opts = { ceu_features_exception='true' },
    props_ = 'line 6 : uncaught exception',
}

Test { [[
data Dd;
code/await Ff (none) -> none
    throws Exception
do
    var Dd e_ = val Dd();
    throw e_;
end
await Ff();
escape 1;
]],
    _opts = { ceu_features_exception='true' },
    props_ = 'line 6 : uncaught exception',
}

Test { [[
data Exception.Sub;
code/await Ff (none) -> none
    throws Exception.Sub
do
    var Exception e_ = val Exception(_);
    throw e_;
end
await Ff();
escape 1;
]],
    _opts = { ceu_features_exception='true' },
    props_ = 'line 6 : uncaught exception',
}

Test { [[
data Exception.Sub;
code/await Ff (none) -> none
    throws Exception
do
    var Exception.Sub e_ = val Exception.Sub(_);
    throw e_;
end
await Ff();
escape 1;
]],
    props_ = 'line 6 : uncaught exception',
    _opts = { ceu_features_exception='true' },
}

Test { [[
var Exception? e;
catch e do
    code/await Ff (none) -> none do
        var Exception e_ = val Exception(_);
        throw e_;
    end
    await Ff();
end
escape 1;
]],
    props_ = 'line 5 : uncaught exception',
    _opts = { ceu_features_exception='true' },
}

Test { [[
code/await Ff (none) -> none
    throws Exception
do
    var Exception e_ = val Exception(_);
    throw e_;
end
var Exception? e;
catch e do
    await Ff();
end
if e? then
    escape 10;
end
escape 1;
]],
    _opts = { ceu_features_exception='true' },
    run = 10,
}

Test { [[
code/tight Ff (none) -> none
    throws Exception
do
    var Exception e_ = val Exception(_);
    throw e_;
end
call Ff();
escape 1;
]],
    parser = 'line 1 : after `none` : expected type modifier or `do` or `;`',
}

Test { [[
code/tight Ff (none) -> none do
    var Exception? e;
    catch e do
        var Exception e_ = val Exception(_);
        throw e_;
    end
end
call Ff();
escape 1;
]],
    _opts = { ceu_features_exception='true' },
    props_ = 'line 5 : invalid `throw` : unexpected enclosing `code`',
}

Test { [[
code/await Ff (none) -> int
    throws Exception
do
    var Exception? e;
    catch e do
        var Exception e_ = val Exception(_);
        throw e_;
    end
    if e? then
        escape 10;
    else
        escape 0;
    end
end
var int ret = 0;
var Exception? e;
catch e do
    ret = await Ff();
end
if e? then
    escape 0;
end
escape ret;
]],
    _opts = { ceu_features_exception='true' },
    run = 10,
}

Test { [[
data Exception.Sub;
code/await Ff (none) -> int
    throws Exception
do
    var Exception.Sub? e;
    catch e do
        var Exception e_ = val Exception(_);
        throw e_;
    end
    if e? then
        escape 10;
    else
        escape 0;
    end
end
var int ret = 0;
var Exception? e;
catch e do
    ret = await Ff();
end
if e? then
    escape 90;
end
escape ret;
]],
    _opts = { ceu_features_exception='true' },
    run = 90,
}

Test { [[
data Exception.Sub;
code/await Ff (none) -> int
    throws Exception
do
    par do
        var Exception.Sub? e;
        catch e do
            var Exception e_ = val Exception(_);
            throw e_;
        end
        if e? then
            escape 10;
        else
            escape 0;
        end
    with
        var Exception.Sub? e;
        catch e do
            var Exception e_ = val Exception(_);
            throw e_;
        end
        if e? then
            escape 10;
        else
            escape 0;
        end
    end
end
var int ret = 0;
var Exception? e;
catch e do
    ret = await Ff();
end
if e? then
    escape 90;
end
escape ret;
]],
    _opts = { ceu_features_exception='true' },
    run = 90,
}

Test { [[
code/await Ff (none) -> int
    throws Exception
do
    par/and do
        var Exception? e;
        catch e do
            var Exception e_ = val Exception(_);
            throw e_;
        end
        if not e? then
            escape 0;
        end
    with
        var Exception? e;
        catch e do
            var Exception e_ = val Exception(_);
            throw e_;
        end
        if not e? then
            escape 0;
        end
    end
    escape 50;
end
var int ret = 0;
var Exception? e;
catch e do
    ret = await Ff();
end
if e? then
    escape 90;
end
escape ret;
]],
    _opts = { ceu_features_exception='true' },
    run = 50,
}

Test { [[
code/await Ff (none) -> none
    throws Exception
do
    var Exception e_ = val Exception(_);
    throw e_;
end

code/await Gg (none) -> none
    throws Exception
do
    await Ff();
end

var Exception? e;
catch e do
    await Gg();
end
if e? then
    escape 10;
end
escape 0;
]],
    _opts = { ceu_features_exception='true' },
    run = 10,
}

Test { [[
data Exception.Sub;
data Exception.Sub.Sub;
var Exception? e1;
var Exception.Sub? e2;
var Exception.Sub.Sub? e3;
catch e1,e2,e3 do
    var Exception.Sub.Sub e_ = val Exception.Sub.Sub(_);
    throw e_;
end
if e1? then
    escape 10;
end
escape 0;
]],
    _opts = { ceu_features_exception='true' },
    run = 10,
    wrn = true,
}

Test { [[
data Exception.Sub;
data Exception.Sub.Sub;
var Exception? e1;
var Exception.Sub? e2;
var Exception.Sub.Sub? e3;
catch e3,e2,e1 do
    var Exception.Sub.Sub e_ = val Exception.Sub.Sub(_);
    throw e_;
end
if e1? then
    escape 0;
else/if e2? then
    escape 0;
else/if e3? then
    escape 10;
end
escape 0;
]],
    _opts = { ceu_features_exception='true' },
    run = 10,
}

Test { [[
code/await Gg (none) -> (var int file) -> int do
    file = 1;
    escape 0;
end

code/await Ff (none) -> (var& int file) -> NEVER
    throws Exception
do
    var&? Gg o = spawn Gg();
    var int? err =
        watching o do
            file = &o.file;
        end;
    var Exception e = val Exception(_);
    throw e;
end

await Ff();
escape 0;
]],
    run = '15] -> runtime error: unspecified message',
    wrn = true,
    _opts = { ceu_features_exception='true', ceu_features_trace='true' },
}

Test { [==[
[[
    aa $ aa
]]
escape 1;
]==],
    --run = '1] -> runtime error: [string "..."]:2: syntax error near \'$\'',
    --run = '2: \'=\' expected near \'$\'',
    _opts = { ceu_features_exception='true', ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
    props_ = 'line 1 : uncaught exception',
}

Test { [==[
[[
    aa $ aa
]]
escape 1;
]==],
    run = '1] -> runtime error: [string "..."]:2: syntax error near \'$\'',
    --run = '2: \'=\' expected near \'$\'',
    _opts = { ceu_features_exception='true', ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
    wrn = true,
}

Test { [==[
var Exception.Lua? e;
catch e do
    [[
        aa $ aa
    ]]
end
if e? then
    throw e!;
end
escape 1;
]==],
    run = '8] -> runtime error: [string "..."]:2: syntax error near \'$\'',
    --run = '2: \'=\' expected near \'$\'',
    _opts = { ceu_features_exception='true', ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
    wrn = true,
}

Test { [=[
var Exception.Lua? e;
catch e do
    [[ error'1' ]]
    {ceu_assert(0, "bug");}
    [[ error'2' ]]
end
escape 1;
]=],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true', ceu_features_trace='true', ceu_features_exception='true' },
    run = 1,
    wrn = true,
}

Test { [[
event none f;
watching f do
    event none e;
    watching e do
        do finalize with
            emit f;
        end
        emit e;
    end
    {ceu_assert(0,"bug found-a");}
end
await 1s;
escape 10;
]],
    run = {['~>1s']=10},
    _opts = { ceu_features_trace='true' },
}

Test { [[
par/or do
    var Exception? e;
    catch e do
        do finalize with
            var Exception e_ = val Exception(_);
            throw e_;
        end
        var Exception e_ = val Exception(_);
        throw e_;
    end
with
end
escape 10;
]],
    run = '6] -> runtime error: double catch',
    _opts = { ceu_features_trace='true', ceu_features_exception='true' },
}

Test { [[
data Exception.Sub;
var Exception? f;
catch f do
    var Exception.Sub? e;
    catch e do
        do finalize with
            var Exception f_ = val Exception(_);
            throw f_;
        end
        var Exception.Sub e_ = val Exception.Sub(_);
        throw e_;
    end
    {ceu_assert(0,"bug found-a");}
    //{printf("out\n");}
end
//{printf("OUT\n");}
await 1s;
escape 10;
]],
    run = {['~>1s']=10},
    _opts = { ceu_features_exception='true' },
}

Test { [[
var int ret = 0;

code/await Gg (none) -> none
    throws Exception
do
    var Exception e_ = val Exception(_);
    throw e_;
end

code/await Ff (var bool go) -> none do
    var Exception? e;
    catch e do
        if go then
            await Gg();
        else
            await FOREVER;
        end
    end
    outer.ret = outer.ret + 1;
end

spawn Ff(false);
spawn Ff(true);

escape ret;

]],
    run = 1,
    _opts = { ceu_features_exception='true' },
}

Test { [[
var Exception e = val Exception(_);
throw e;
]],
    run = 'Aborted',
    _opts = { ceu_features_exception='true', ceu_err_uncaught_exception_main='warning' },
    wrn = true,
}
Test { [[
var Exception e = val Exception(_);
throw e;
]],
    run = 'Aborted',
    _opts = { ceu_features_exception='true', ceu_err_uncaught_exception_main='pass' },
}
Test { [[
var Exception e = val Exception(_);
throw e;
]],
    run = 'Aborted',
    _opts = { ceu_features_exception='true', ceu_err_uncaught_exception_main='error' },
    props_ = 'line 2 : uncaught exception',
    wrn = true,
}

Test { [[
code/await Ff (none) -> none do
    var Exception e = val Exception(_);
    throw e;
end
await Ff();
escape 0;
]],
    run = 1,
    _opts = { ceu_features_exception='true', ceu_err_uncaught_exception_main='pass' },
    props_ = 'line 3 : uncaught exception',
}
Test { [[
code/await Ff (none) -> none do
    var Exception e = val Exception(_);
    throw e;
end
await Ff();
escape 0;
]],
    run = 'Aborted',
    _opts = { ceu_features_exception='true', ceu_err_uncaught_exception='pass' },
}
Test { [[
code/await Ff (none) -> none do
    var Exception e = val Exception(_);
    throw e;
end
await Ff();
escape 0;
]],
    run = '3] -> runtime error: unspecified message',
    _opts = { ceu_features_trace='true', ceu_features_exception='true', ceu_err_uncaught_exception='pass' },
}

Test { [[
code/await Ff (none) -> none do
    var Exception.Lua e = val Exception.Lua(_);
    throw e;
end
await Ff();
escape 0;
]],
    run = 1,
    props_ = 'line 3 : uncaught exception',
    _opts = { ceu_features_trace='true', ceu_features_exception='true', ceu_features_dynamic='true', ceu_features_lua='true' },
}
Test { [[
code/await Ff (none) -> none do
    var Exception.Lua e = val Exception.Lua("lua");
    throw e;
end
await Ff();
escape 0;
]],
    run = '3] -> runtime error: lua',
    _opts = { ceu_features_trace='true', ceu_features_exception='true', ceu_features_dynamic='true', ceu_features_lua='true', ceu_err_uncaught_exception_lua='pass' },
}
Test { [[
var Exception.Lua e = val Exception.Lua("lua");
throw e;
]],
    run = '2] -> runtime error: lua',
    _opts = { ceu_features_trace='true', ceu_features_exception='true', ceu_features_dynamic='true', ceu_features_lua='true', ceu_err_uncaught_exception_lua='pass' },
}

Test { [[
code/tight Ff (none) -> none do
end
call Ff();
escape 1;
]],
    run = 1,
    _opts = { ceu_features_exception='true' },
}

Test { [[
code/tight Ff (none) -> none
    throws Exception
do
end
call Ff();
escape 0;
]],
    parser = 'line 1 : after `none` : expected type modifier or `do` or `;`',
    _opts = { ceu_features_exception='true' },
}

Test { [[
code/tight Ff (none) -> none
do
    var Exception e = _;
    throw e;
end
call Ff();
escape 0;
]],
    props_ = 'line 4 : invalid `throw` : unexpected enclosing `code`',
    _opts = { ceu_features_exception='true' },
}

Test { [=[
 ##include <stdio.h>

 native/plain
   _stderr
 ;

 native/nohold
   _fprintf
 ;

 var Exception? e;
 catch e do
   [[
     //print ('teste')
   ]]
 end
 if e? then
   _fprintf (_stderr, "%s\n", e!.message);
 end
 escape 1;
]=],
    wrn = true,
    _opts = { ceu_features_exception='true', ceu_features_dynamic='true', ceu_features_lua='true', },
    run = "2: unexpected symbol near '//'",
}

Test { [=[
var Exception? e;
escape e!.message as int;
]=],
    wrn = true,
    _opts = { ceu_features_exception='true' },
    cc = 'error: cast from pointer to integer of different size',
}

--<<< EXCEPTIONS / THROW / CATCH

-->>> LUA

Test { [==[
[[
    aaa = 1
]]
var int bbb = [[aaa]];
escape bbb;
]==],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
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
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    parser = 'line 3 : after `1` : expected `[` or `:` or `.` or `!` or `?` or `(` or `is` or `as` or binary operator or `..` or `;`',
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
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var bool v = [["ok" == 'ok']];
escape v as int;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var bool v = [[true]];
escape v as int;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var bool v = [[false]];
escape v as int;
]=],
    run = 0,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [==[
[[
    print '*** END: 10 0'
]]
var int v = [[1]];
escape v;
]==],
    todo = 'END for tests is not used anymore',
    run = 10,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [==[
[[
    aa $ aa
]]
escape 1;
]==],
    run = '1] -> runtime error: [string "..."]:2: syntax error near \'$\'',
    --run = '2: \'=\' expected near \'$\'',
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
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
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
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
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[

[[ error'oi' ]];
escape 1;
]=],
    run = '2] -> runtime error: [string " error\'oi\' "]:1: oi',
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var int ret = [[ true ]];
escape ret;
]=],
    run = '1] -> runtime error: number expected',
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
}
Test { [=[
var bool ret = [[ nil ]];
escape (ret==false) as int;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}
Test { [=[

var int ret = [[ nil ]];
escape ret;
]=],
    run = '2] -> runtime error: number expected',
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
native _char;
native/nohold _strcmp;
var byte&& str = "oioioi";
[[ str = @str ]]
var bool ret = [[ str == 'oioioi' ]];
var[10] byte cpy = [[ str ]];
escape ret and (0 == _strcmp(str,(&&cpy[0]) as _char&&));
]=],
    stmts = 'line 6 : invalid Lua assignment : unexpected context for vector "cpy"',
    --run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
native _char;
native/nohold _strcmp;
var _char&& str = "oioioi";
[[ str = @str ]]
var bool ret = [[ str == 'oioioi' ]];
var[10] byte cpy = [].. [[ str ]];
escape (ret and (0 == _strcmp(str,(&&cpy[0]) as _char&&))) as int;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
native/nohold _strcmp, _strcpy;
var[10] byte str;
_strcpy(&&str[0],"oioioi");
[[ str = @(&&str[0]) ]]
var bool ret = [[ str == 'oioioi' ]];

var[10] byte cpy;
var byte&& ptr = cpy;
ptr = [[ str ]];
escape ret and (0 == _strcmp(&&str[0],&&cpy[0]));
]=],
    stmts = 'line 8 : invalid assignment : unexpected context for vector "cpy"',
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
native/nohold _strcmp;
var[10] byte str = [] .. "oioioi";
[[ str = @str ]]
var bool ret = [[ str == 'oioioi\0' ]];
var[10] byte cpy;
var&[10] byte ptr = &cpy;
ptr = [].. [[ str ]];
native _char;
escape (ret and (0 == _strcmp((&&str[0]) as _char&&,(&&cpy[0]) as _char&&))) as int;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
native/nohold _strcmp;
[[ str = '1234567890' ]]
var[2] byte cpy = [].. [[ str ]];
native _char;
escape (_strcmp((&&cpy[0]) as _char&&,"1") == 0) as int;
]=],
    run = '3] -> runtime error: access out of bounds',
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true', ceu_features_trace='true' },
}

Test { [=[
native/nohold _strcmp;
[[ str = '1234567890' ]]
var[2] byte cpy;
var[20] byte cpy_;
var&[] byte ptr = &cpy;
ptr = [].. [[ str ]];
native _char;
escape (0 == _strcmp((&&cpy[0]) as _char&&,"1234567890")) as int;
]=],
    wrn = true,
    run = '6] -> runtime error: access out of bounds',
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true', ceu_features_trace='true' },
}

Test { [=[
var[3] byte str = [] .. [ {'a'},{'b'},{'c'} ];
var int len1 = [[ @$str ]];
var int len2 = [[ string.len(@str) ]];
escape len1 + len2;
]=],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    run = 6,
}

Test { [=[
[[
    str = 'alo'
]]
var[3] byte str = [] .. [[ str ]];
escape $str as int;
]=],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    run = 3,
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
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
[[ ]] [[ ]] [[ ]]
escape 1;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}
Test { [=[
[[ ]]
[[ ]]
[[ ]]
escape 1;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}
Test { [=[
native/nohold _strcmp;

[[
-- this is lua code
v_from_lua = 100
]]

var int v_from_ceu = [[v_from_lua]];

[[
str_from_lua = 'string from lua'
]]
var[100] byte str_from_ceu = [].. [[str_from_lua]];
native _ceu_assert;
native _char;
_ceu_assert(0==_strcmp((&&str_from_ceu[0]) as _char&&, "string from lua"), "bug found");

[[
--print(@v_from_ceu)
v_from_lua = v_from_lua + @v_from_ceu
]]

//v_from_ceu = [[nil]];

var int ret = [[v_from_lua]];
escape ret;
]=],
    run = 200,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var int a=0;
var none&& ptr1 = &&a;
[[ ptr = @ptr1 ]];
var none&& ptr2 = [[ ptr ]];
escape (ptr2==&&a) as int;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var bool b1 = true;
var bool b2 = false;
var int ret = [[ @b1==true and @b2==false ]];
[[
    b1 = @b1
    b2 = @b2
]];
var bool b1_ = [[b1]];
var bool b2_ = [[b2]];
escape ret + (b1_ as int) + (b2_ as int);
]=],
    run = '3] -> runtime error: number expected',
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var bool b1 = true;
var bool b2 = false;
var bool ret = [[ @b1==true and @b2==false ]];
[[
    b1 = @b1
    b2 = @b2
]];
var bool b1_ = [[b1]];
var bool b2_ = [[b2]];
escape (ret as int) + (b1_ as int) + (b2_ as int);
]=],
    run = 2,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[

[[
    (0)();
]];
escape 1;
]=],
    run = '2: attempt to call a number value',
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[

var int ret = [[
    (0)();
]];
escape ret;
]=],
    --run = 1,
    run = '2: attempt to call a number value',
    _opts = { ceu_features_trace='true', ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
do
    var r32 f = 10;
    [[assert(math.type(@f)=='float')]];
end
do
    var r64 f = 0;
    [[assert(math.type(@f)=='float')]];
end

var int   i = 0;
var real f = 0;
var bool is_int   = [[math.type(@i)=='integer']];
var bool is_real = [[math.type(@f)=='float']];

[[assert(math.type(@(1.1))=='float')]];
[[assert(math.type(@(1.0))=='float')]];
[[assert(math.type(@(1))=='integer')]];

escape (is_int as int)+(is_real as int);
]=],
    run = 2,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
code/tight Fx (none)->int do
    var int v = [[ 1 ]];
    escape v;
end
escape call Fx();
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var real v1 = [[ 0.5 ]];
var real v2 = 0.5;
escape (v1==v2) as int;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var real f = 3.2;
var bool ok = [[ 3.1<(@f) and 3.3>(@f) ]];
escape ok as int;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var int f = 3;
var bool ok = [[ 3.0==@f ]];
escape ok as int;
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var[] byte str = [].."12345";
var[] byte bts = [1,2,3,4,5,0];
var int r1 = [[ string.len(@str) ]];
var int r2 = [[ string.len(@bts) ]];
escape r1+r2;
]=],
    run = 12,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [[
lua do
    escape 1;
end
]],
    parser = 'line 1 : after `lua` : expected `[`',
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [[
lua[] do
    escape 1;
end
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
lua[] do
    var int ret = [[ 1 ]];
    escape ret;
end
]=],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [[
watching 1s do
    lua[] do
        await FOREVER;
    end
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    run = { ['~>1s']=1 },
}

Test { [=[
[[ a = 1 ]];
lua[] do
    var int a = [[a or 10]];
    escape a;
end
]=],
    run = 10,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
[[ a = 1 ]];
lua[] do
    var int a = [[a or 10]];
end
lua[] do
    var int a = [[a or 11]];
    escape a;
end
]=],
    run = 11,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
code/tight Ff (none) -> int do
    var int a = [[a or 3]];
    escape a;
end

[[ a = 1 ]];
lua[] do
    [[ a = 2 ]];
    var int x = call Ff();
    escape x;
end
]=],
    run = 2,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
code/await Ff (none) -> int do
    var int a = [[a or 3]];
    escape a;
end

[[ a = 1 ]];
lua[] do
    [[ a = 2 ]];
    var int x = await Ff();
    escape x;
end
]=],
    run = 2,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var int v_ceu = 10;
{
    int v_c = @v_ceu * 2;       // yields 20
}
v_ceu = { v_c + @v_ceu };       // yields 30
{
    //printf("%d\n", @v_ceu);     // prints "v = 10"
}

[[
    v_lua = @v_ceu * 2
]]
v_ceu = [[ v_lua + @v_ceu ]];
[[
    --print(@v_ceu)
]]
escape v_ceu;
]=],
    _opts = {
        ceu = true,
        ceu_features_dynamic='true', ceu_features_lua = 'true',
    },
    run = 90,
}

Test { [=[
var[] byte vec = [].."123";
[[
    str = @vec
]]
var int len = [[ #str ]];
escape len;
]=],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    run = 4,
}

Test { [=[
var[] byte xxx = [1];
var int ret = [[ @xxx[0] ]];
escape ret;
]=],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    run = 1,
}

Test { [=[
var int len = [[ string.len('@@ceu-lang.org') ]];
escape len;
]=],
    run = 13,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [=[
var[10*] byte xxx = [].."01234";
xxx = [].."567890";
[[ xxx = @xxx ]]
//[[ print(xxx) ]]
var bool v = [[ xxx=='567890\0' ]];
escape v as int;
]=],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    run = 1,
}

--<<< LUA

-- TODO: SKIP-05

-->>> DATA INI
-- HERE:

-- ADTs used in most examples below
DATA = [[
// C-like struct
data Pair with
    var int x;
    var int y;
end

// "Nullable pointer"
data Opt;
data Opt.Nothing;
data Opt.Ptr with
    var none&& v;
end

// List (recursive type)
data List;
data List.Nil;
data List.Cons with
    var int  head;
    var List tail;
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
    parser = 'line 1 : after `data` : expected abstraction identifier'
}
Test { [[
data Tx with
    var int x;
end
escape 1;
]],
    wrn = true,
    run = 1,
}

-- data type identifiers cannot clash with interface/classe identifiers
Test { [[
data Tx with
    var int x;
end
code/await Tx (none) -> none do
end
escape 1;
]],
    wrn = true,
    --tmp = 'line 4 : top-level identifier "Tx" already taken',
    dcls = 'line 4 : invalid `code` declaration',
}
Test { [[
code/await Tx (none) -> none do
end
data Tx with
    var int x;
end
escape 1;
]],
    wrn = true,
    tmp = 'line 3 : top-level identifier "Tx" already taken',
}
Test { [[
data Tx with
    var int x;
end
data Tx with
    var int y;
end
escape 1;
]],
    dcls = 'line 4 : declaration of "Tx" hides previous declaration (/tmp/tmp.ceu : line 1)',
    --dcls = 'line 4 : identifier "Tx" is already declared (/tmp/tmp.ceu : line 1)',
}
Test { [[
code/await Tx (none) -> none
do
end
code/tight Tx (none) -> none
do
end
escape 1;
]],
    --tmp = 'top-level identifier "Tx" already taken',
    dcls = 'line 4 : invalid `code` declaration : body for "Tx" already exists',
}

Test { [[
data Dx with
    var int x;
end
code/await Cc (none) -> (var Dx d) -> NEVER do
    d = val Dx(200);
    await FOREVER;
end
var&? Cc c = spawn Cc();
escape c!.d.x;
]],
    run = 200,
}

Test { [[
data Ax;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Ax.Bx;
escape 1;
]],
    dcls = 'line 1 : invalid declaration : abstraction "Ax" is not declared',
}

Test { [[
data Ax;
data Ax.Bx;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Ax;
data Bx;
data Ax.Bx.Cx;
escape 1;
]],
    wrn = true,
    dcls = 'line 3 : invalid declaration : abstraction "Ax.Bx" is not declared',
}

Test { [[
data Ax;
data Ax.Bx;
data Ax.Bx.Cx;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Opt;
data Opt.OptNIL;
data Opt.OptPTR with
    var none&& v;
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data OptNIL.;
]],
    parser = 'line 1 : after `OptNIL` : expected `as` or `with` or `;`',
    --parser = 'line 1 : after `is` : expected abstraction identifier',
}

Test { [[
data OptNIL. with
end
]],
    parser = 'line 1 : after `OptNIL` : expected `as` or `with` or `;`',
    --parser = 'line 1 : after `is` : expected abstraction identifier',
}

Test { [[
data OptNIL with
end
]],
    parser = 'line 1 : after `with` : expected `var` or `pool` or `event`',
}

Test { [[
data Opt;
data Opt_.OptNIL;
escape 1;
]],
    dcls = 'line 2 : invalid declaration : abstraction "Opt_" is not declared',
    --dcls = 'line 2 : abstraction "Opt_" is not declared',
}

-->>> MISC

Test { [[
data SDL_Rect with
    var int x; var int y; var int w; var int h;
end

var SDL_Rect rect;
var SDL_Rect r = rect;

escape r.x+r.y+r.w+r.h;
]],
    inits = 'line 5 : uninitialized variable "rect" : reached read access (/tmp/tmp.ceu:6)',
    --ref = 'line 6 : invalid access to uninitialized variable "rect" (declared at /tmp/tmp.ceu:5)',
}
Test { [[
data SDL_Rect with
    var int x; var int y; var int w; var int h;
end

var SDL_Rect rect = val SDL_Rect(1,2,3,4);
var SDL_Rect r = rect;

escape r.x+r.y+r.w+r.h;
]],
    run = 10,
}
Test { [[
data Ball with
    var int x; var int  y;
    var int radius;
end

var Ball ball = val Ball(130,130,8);
escape ball.x + ball.y + ball.radius;
]],
    run = 268,
}

Test { [[
data Ball with
    var real x;
    var real y;
    var real radius;
end

var Ball ball = val Ball(130,130,8);

native _add;
native/pos do
    int add (s16 a, s16 b, s16 c) {
        return a + b + c;
    }
end

escape _add(ball.x, ball.y, ball.radius);
]],
    run = 268,
}

Test { [[
do
    data Ball1 with
        var real x;
        var real y;
        var real radius;
    end
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Ball1 with
    var real x;
end
do
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
native/pos do
    int add (int a, int b, int c) {
        return a + b + c;
    }
end
native _add;

var int sum = 0;
do
    data Ball1 with
        var real x;
        var real y;
        var real radius;
    end
    var Ball1 ball = val Ball1(130,130,8);
    sum = sum + _add(ball.x, ball.y, ball.radius);
end

do
    data Ball2 with
        var real x;
        var real y;
        var real radius;
    end
    var Ball2 ball = val Ball2(130,130,8);
    sum = sum + _add(ball.x, ball.y, ball.radius);
end

escape sum;
]],
    run = 536,
}

Test { [[
data Tx with
    var int x;
end

code/tight Fx (none)->Tx do
    var Tx t = val Tx(10);
    escape t;
end

var Tx t = call Fx();
escape t.x;
]],
    wrn = true,
    run = 10,
}

Test { [[
data Tx with
    var int x;
end
data Tx.Ux;

code/tight Fx (none)->Tx.Ux do
    var Tx.Ux t = val Tx.Ux(10);
    escape t;
end

var Tx t = call Fx();
escape t.x;
]],
    wrn = true,
    run = 10,
}

Test { [[
data Ee;
var int x = 0;
var Ee e = val x;
escape 1;
]],
    --parser = 'line 3 : after `val` : expected abstraction identifier',
    parser = 'line 3 : after `x` : expected `[` or `:` or `.` or `!` or `as`',
}

Test { [[
code/tight Fx (none)->none do end;
data Ee;
var int x = 0;
var Ee e = val Fx();

escape 1;
]],
    stmts = 'line 4 : invalid constructor : expected `data` abstraction : got `code` "Fx" (/tmp/tmp.ceu:1)',
}

Test { [[
data Ui with
    event none       ok_clicked;
    var   SDL_Rect   rect;
    var   SDL_Color? bg_clr;
end
escape 1;
]],
    dcls = 'line 3 : abstraction "SDL_Rect" is not declared',
}

Test { [[
data Dd with
    var int x;
end
event Dd e;
escape 1;
]],
    dcls = 'line 4 : invalid declaration : unexpected context for `data` "Dd"',
}

-->>> DATA / HIERARCHY / SUB-DATA / SUB-TYPES

Test { [[
data Ee;
data Ee.Nothing;
data Ee.Xx with
    var int x;
end

var Ee e = val Ee(1);

escape 1;
]],
    wrn = true,
    --env = 'line 7 : union data constructor requires a tag',
    dcls = 'line 7 : invalid constructor : expected 0 argument(s)',
}

Test { [[
data Ee;
data Ee.Nothing;
var Ee e = val Ee.Nothing();
escape (e is Ee.Nothing) as int;
]],
    run = 1,
    --stmts = 'line 3 : invalid constructor : types mismatch : "Ee" <= "Ee.Nothing"',
}

Test { [[
data Dx with
    var int x;
end

data Ee with
    var Dx d;
end

var Dx d = val Dx(10);
var Ee e = val Ee(d);
escape e.d.x;
]],
    run = 10,
}

Test { [[
data Dx with
    var int x;
end

data Ee with
    var Dx d;
end

var Ee e = val Ee(Dx(10));
escape e.d.x;
]],
    run = 10,
}

Test { [[
data Dx with
    var int x;
end
data Ee with
    var& Dx d;
end
var int x = 0;
var Ee ex = val Ee(&x);
escape 1;
]],
    dcls = 'line 8 : invalid constructor : argument #1 : types mismatch : "Dx" <= "int"',
}

Test { [[
data Dx with
    var int x;
end
do
    var Dx dx = val Dx(10);
end
do/_
    var Dx dx = val Dx(_);
    escape dx.x+1;
end
]],
    run = false,
    --run = 1,
}

Test { [[
data Dx with
    var int x;
end
data Ee with
    var& Dx d;
end
var Ee ex = val Ee(_);
escape 1;
]],
    dcls = 'line 7 : invalid constructor : invalid binding : argument #1 : expected location',
    --dcls = 'line 7 : invalid constructor : argument #1 : unexpected `_`',
}

Test { [[
data Dx with
    var int x;
end
data Ee with
    var& Dx d;
end
var Dx d = val Dx(10);
var Ee ex = val Ee(&d);
escape ex.d.x;
]],
    run = 10,
}

Test { [[
data Dx with
    var int x;
end

data Ee;
data Ee.Xx with
    var& Dx d;
end

var Dx d = val Dx(10);
var Ee.Xx ex = val Ee.Xx(&d);
escape ex.d.x;
]],
    wrn = true,
    run = 10,
}

Test { [[
data Dx with
    var int x;
end
data Ex with
    var int x;
end
var Dx d = val Dx(10);
escape (d as Ex).x;
]],
    dcls = 'line 8 : invalid operand to `as` : unmatching `data` abstractions',
    --dcls = 'line 8 : invalid operand to `as` : unexpected plain `data` : got "Dx"',
}

Test { [[
data Ee;
data Ee.Xx with
    var int x;
end
var Ee ex = val Ee();
var Ee&& e = &&ex;
escape (e as Ee.Xx&&):x;
]],
    wrn = true,
    run = '7] -> runtime error: invalid cast `as`',
    _opts = { ceu_features_trace='true' },
}

Test { [[
data Dx with
    var int x;
end

data Ee;
data Ee.Nothing;
data Ee.Xx with
    var& Dx d;
end

var Dx d = val Dx(10);
var Ee.Xx ex = val Ee.Xx(&d);
var Ee&& e = &&ex;

escape (e as Ee.Xx&&):d.x;
]],
    wrn = true,
    run = 10,
}

Test { [[
data Dx with
    var int x;
end

data Ee;
data Ee.Nothing;
data Ee.Xx with
    var& Dx d;
end

var Dx d = val Dx(10);
var Ee.Xx ex = val Ee.Xx(&d);
var& Ee e = &ex;

escape (e as Ee.Xx).d.x;
]],
    wrn = true,
    run = 10,
}

Test { [[
data Dx with
    var int x;
end

data Ee;
data Ee.Nothing;
data Ee.Xx with
    var& Dx d;
end

var& Ee e;    // TODO: should bind here
do
    var Dx d = val Dx(1);
    (e as Ee.Xx).d = &d;
end

escape 1;//e.Xx.d.x;
]],
    wrn = true,
    --stmts = 'line 14 : invalid binding : expected declaration with `&`',
    stmts = 'line 14 : invalid binding : unexpected context for operator `.`',
    --inits = 'line 11 : uninitialized variable "e" : reached read access (/tmp/tmp.ceu:14)',
    --ref = 'line 11 : uninitialized variable "e" crossing compound statement (/tmp/tmp.ceu:14)',
}

Test { [[
data Ee;
data Ee.Xx with
    var int x;
end

var Ee.Xx e1 = val Ee.Xx(10);
var& Ee e = &e1;
if e is Ee.Xx then
    escape (e as Ee.Xx).x;
else
    escape 0;
end
]],
    run = 10,
}

Test { [[
data Ee;
data Ee.Xx with
    var int x;
end

var Ee.Xx e1 = val Ee.Xx(10);
var& Ee e = &e1;
if e is Ee then
    escape (e as Ee.Xx).x;
else
    escape 0;
end
]],
    run = 10,
}

Test { [[
data Dx with
    var int x;
end
data Ee;
data Ee.Nothing;
data Ee.Xx with
    var& Dx d;
end
var Dx d = val Dx(1);
var Ee e1 = val Ee();
var& Ee e = &e1;
(e as Ee.Xx).d.x = 10;
escape (e as Ee.Xx).d.x;
]],
    wrn = true,
    run = '12] -> runtime error: invalid cast `as`',
    _opts = { ceu_features_trace='true' },
}

Test { [[
data Ee;
data Ee.Xx with
    var int x;
end

var Ee e1 = val Ee();
var& Ee e = &e1;
escape (e as Ee.Xx).x;
]],
    run = '8] -> runtime error: invalid cast `as`',
    _opts = { ceu_features_trace='true' },
}

Test { [[
data Ee;
data Ee.Xx with
    var int x;
end

var Ee e1 = val Ee();
var& Ee e = &e1;
if e is Ee.Xx then
    escape 0;
else
    escape 1;
end
]],
    run = 1,
}

Test { [[
data Dx with
    var int x;
end

data Ee;
data Ee.Xx with
    var& Dx d;
end

    var Dx d = val Dx(1);
    var Ee.Xx e1 = val Ee.Xx(&d);
    var& Ee e = &e1;
// TODO: run-time check
    d.x = 10;

escape (e as Ee.Xx).d.x;
]],
    wrn = true,
    run = 10,
}

Test { [[
data Dx with
    var int x;
end

data Ee;
data Ee.Nothing;
data Ee.Xx with
    var& Dx d;
end

    var Dx d = val Dx(1);
var Ee.Xx ex = val Ee.Xx(&d);
var& Ee e = &ex;
    (e as Ee.Xx).d = &d;

escape (e as Ee.Xx).d.x;
]],
    wrn = true,
    --stmts = 'line 13 : invalid binding : expected declaration with `&`',
    stmts = 'line 14 : invalid binding : unexpected context for operator `.`',
    --run = 1,
}
Test { [[
data Dx with
    var int x;
end

data Ee;
data Ee.Nothing;
data Ee.Xx with
    var Dx&& d;
end

var Ee.Xx ex = val Ee.Xx(null);
var& Ee e = &ex;
    var Dx d = val Dx(10);
    (e as Ee.Xx).d = &&d;

escape (e as Ee.Xx).d:x;
]],
    wrn = true,
    run = 10,
}

Test { [[
data Ee;
data Ee.Xx with
    var int x;
end
var Ee ex = val Ee();
var Ee&& e = &&ex;
escape (e as Ee.Xx&&):x;
]],
    wrn = true,
    run = '7] -> runtime error: invalid cast `as`',
    _opts = { ceu_features_trace='true' },
}

Test { [[
data Ee;
data Xx with
    var int x;
end
var Ee ex = val Ee();
var& Ee e = &ex;
escape (e as Xx):x;
]],
    wrn = true,
    dcls = 'line 7 : invalid operand to `as` : unmatching `data` abstractions',
}

Test { [[
data Ee;
data Xx with
    var int x;
end
var Ee ex = val Ee();
var& Ee e = &ex;
escape (e is Xx) as int;
]],
    wrn = true,
    dcls = 'line 7 : invalid operand to `is` : expected `data` type in some hierarchy : got "Ee"',
}

Test { [[
data Aa;
var Aa a = _;
escape a as int;
]],
    dcls = 'line 3 : invalid operand to `as` : expected `data` type in a hierarchy : got "Aa"',
}

Test { [[
data Aa;
escape (1 as Aa) as int;
]],
    dcls = 'line 2 : invalid operand to `as` : expected `data` type in a hierarchy : got "Aa"',
}

Test { [[
escape null as int;
]],
    cc = 'error: cast from pointer to integer of different size [-Werror=pointer-to-int-cast]',
}

Test { [[
data Ee;
data Ee.Xx with
    var int x;
end
var Ee ex = val Ee();
var Ee&& e = &&ex;
escape ((*e is Ee.Xx) as int) + 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
data Ee;
data Ee.Xx;
var Ee ex = val Ee.Xx();
var Ee&& e = &&ex;
escape ((*e is Ee.Xx) as int) + 1;
]],
    wrn = true,
    run = 2,
}
Test { [[
data Ee;
data Ee.Xx;
var Ee.Xx ex = val Ee.Xx();
escape ((ex is Ee) as int) + 1;
]],
    wrn = true,
    dcls = 'line 4 : invalid operand to `is` : unmatching `data` abstractions',
}
Test { [[
data Ee;
data Ee.Xx;
var Ee ex = val Ee.Xx();
escape ((ex is Ee.Xx) as int) + 1;
]],
    wrn = true,
    run = 2,
}
Test { [[
data Ee;
var Ee ex = val Ee();
escape ((ex is Ee) as int) + 1;
]],
    wrn = true,
    dcls = 'line 3 : invalid operand to `is` : expected `data` type in some hierarchy : got "Ee"',
}
Test { [[
data Ee;
data Ee.Xx with
    var int x;
end
var Ee ex = val Ee();
var Ee&& e = &&ex;
escape (e is Ee.Xx&&) as int;
]],
    wrn = true,
    dcls = 'line 7 : invalid operand to `is` : expected plain `data` type : got "Ee&&"',
}

Test { [[
data Ee;
data Xx with
    var int x;
end
var Ee ex = val Ee();
var Ee&& e = &&ex;
escape (e as Xx&&):x;
]],
    wrn = true,
    dcls = 'line 7 : invalid operand to `as` : unmatching `data` abstractions',
}

Test { [[
data Ax with
    var int v;
end

data Bx with
    var Ax a;
end

data Cx with
    var Bx b;
end

var Cx c = val Cx(Bx(Ax(1)));

escape c.b.a;
]],
    stmts = 'line 15 : invalid `escape` : types mismatch : "int" <= "Ax"',
}

Test { [[
data Ax with
    var int v;
end

data Bx with
    var Ax a;
end

data Cx with
    var Bx b;
end

var Cx c = val Cx(Bx(Ax(1)));

escape c.b.a.v;
]],
    run = 1,
}

Test { [[
data Ball with
    var int x;
end

data Leaf;
data Leaf.Nothing;
data Leaf.Tween with
    var& Ball ball;
end

code/tight LeafHandler (var& Leaf leaf) -> int do
    var& Ball ball = &(leaf as Leaf.Tween).ball;
    escape ball.x;
end

var Ball ball = val Ball(10);
var Leaf.Tween leaf = val Leaf.Tween(&ball);

var int x = call LeafHandler(&leaf);

escape x;
]],
    wrn = true,
    run = 10,
}

Test { [[
data Ball with
    var int x;
end

data Leaf;
data Leaf.Nothing;
data Leaf.Tween with
    var& Ball ball;
end

code/tight LeafHandler (var& Leaf leaf) -> int do
    var& Ball ball = &(leaf as Leaf.Tween).ball;
    escape ball.x;
end

var Ball ball = val Ball(10);
var Leaf.Nothing leaf = val Leaf.Nothing();

var int x = call LeafHandler(&leaf);

escape x;
]],
    wrn = true,
    run = '12] -> runtime error: invalid cast `as`',
    _opts = { ceu_features_trace='true' },
}

Test { [[
native _t;
native/nohold _f;
native/pre do
    typedef struct t {
        int x;
    } t;
    int f (t* v) {
        return v->x;
    }
end

data Data with
    var int x;
end

var Data d = val Data(10);

escape _f(&&d as _t&&);
]],
    run = 10,
}

Test { [[
data Data with
    var int x;
end

var Data d = val Data(10);
var& Data dd = &d;

escape (dd is Data) as int;
]],
    dcls = 'line 8 : invalid operand to `is` : expected `data` type in some hierarchy : got "Data"',
}

Test { [[
data Aa with
    var int a;
end

var Aa a = val Aa(10);

escape a.a + a.b;
]],
    dcls = 'line 7 : field "b" is not declared',
    --dcls = 'line 7 : invalid member access : "a" has no member "b" : `data` "Aa" (/tmp/tmp.ceu:1)',
}

Test { [[
data Aa with
    var int a;
end
data Aa.Bb with
    var int b;
end

var Aa    a = val Aa(10);
var Aa.Bb b = val Aa.Bb(10,20);

escape a.a + b.a + b.b;
]],
    run = 40,
}

Test { [[
data Aa with
    var int a;
end
data Aa.Bb with
    var int b;
end

var Aa    a = val Aa(10);
var Aa.Bb b = val Aa.Bb(10,20);

escape a.a + b.a + b.b + b.c;
]],
    dcls = 'line 11 : field "c" is not declared',
    --dcls = 'line 11 : invalid member access : "b" has no member "c" : `data` "Aa.Bb" (/tmp/tmp.ceu:4)',
}

Test { [[
data Aa with
    var int a;
end

code/tight Ff (var& Aa a) -> int do
    escape a.a;
end

data Aa.Bb with
    var int b;
end

var Aa.Bb b = val Aa.Bb(10,20);

escape (call Ff(&b));
]],
    run = 10,
}

Test { [[
data Aa with
    var int a;
end

code/tight Ff (var Aa&& a) -> int do
    escape a:a;
end

data Aa.Bb with
    var int b;
end

var Aa.Bb b = val Aa.Bb(10,20);

escape (call Ff(&&b));
]],
    run = 10,
}

Test { [[
data Dd with
    var int vvv = 10;
end
data Dd.Ee with
    var int vvv = 100;
    var int kkk;
end
var Dd    d = val Dd(_);
var Dd.Ee e = val Dd.Ee(_,50);
escape d.vvv + e.vvv + e.kkk;
]],
    run = 160;
}

Test { [[
data Dd with
    var int vvv = 10;
end
data Dd.Ee;
data Dd.Ee.Ff with
    var int vvv = 100;
    var int kkk;
end
var Dd       d = val Dd(_);
var Dd.Ee.Ff f = val Dd.Ee.Ff(_,50);
escape d.vvv + f.vvv + f.kkk;
]],
    run = 160;
}

-->> OPTION / DATA

Test { [[
data Dd with
    var int x;
end

var Dd d = val Dd(10);

var Dd? d1;
var Dd? d2;

d2 = d;

var int ret = 0;

if d1? then
    ret = ret + d1!.x;
else
    ret = ret + 1;
end

if d2? then
    ret = ret + d2!.x;
else
    ret = ret + 1;
end

escape ret;
]],
    run = 11,
}

Test { [[
data Dd with
    var& int? x;
end

var int? x1;
var int? x2;

var Dd d1 = val Dd(&x1);
var Dd d2 = val Dd(&x2);

x2 = 10;

escape (d1.x? as int) + d2.x! + 1;
]],
    run = 11,
}

-- exemplos de atribuicao a data com valor "?"
Test { [[
data Dd with
    var int? x;
end
var int? y;
var int? z;
z = y;
var Dd d = val Dd(y);
escape (d.x? as int) + 1;
]],
    run = 1,
}
Test { [[
data Ee with
    var int x;
end
data Dd with
    var Ee? e;
end
var Dd d = _;

d.e = val Ee(10);
var int c = 0;

escape d.e!.x;
]],
    --wrn = true,
    run = 10,
}

Test { [[
data Dd with
    var int? x;
end
var int? x = 10;
var Dd d = val Dd(x);
escape d.x!;
]],
    run = 10,
}
Test { [[
data Dd with
    var int x;
end
data Ee with
    var Dd? d;
end
var Dd d = val Dd(10);
var Ee e = val Ee(d);
escape e.d!.x;
]],
    run = 10,
}
Test { [[
data Dd with
    var int x;
end
data Ee with
    var Dd? d;
end
var Ee e = val Ee(Dd(10));
escape e.d!.x;
]],
    run = 10,
}
Test { [[
data Dd with
    var int x;
end
data Ee with
    var Dd? d1;
end
var Dd? d2 = val Dd(10);
var Ee  e = val Ee(d2);
escape e.d1!.x;
]],
    run = 10,
}

Test { [[
data Dd with
    var int v;
end
var Dd? d_ = val Dd(10);
var Dd? d;
d = d_;
escape d!.v;
]],
    run = 10,
}

Test { [[
code/await Ff (var int? v_) -> (var int? v) -> NEVER do
    v = v_;
    await FOREVER;
end
var&? Ff f = spawn Ff(_);
var int ret = f!.v? as int;
f!.v = 10;
escape ret + f!.v!;
]],
    run = 10,
}

Test { [[
data Dd with
    var int v;
end
code/await Ff (var Dd? d_) -> (var Dd? d) -> NEVER do
    d = d_;
    await FOREVER;
end
var&? Ff f = spawn Ff(_);
var int ret = f!.d? as int;
f!.d = val Dd(10);
escape ret + f!.d!.v;
]],
    run = 10,
}

Test { [[
data Dd with
    var int? v;
end
var Dd d = val Dd(_);
var int? x = 10;
d.v = do
    if x? then
        escape x!;
    else
        escape {0};
    end
end;
escape d.v!;
]],
    run = 10,
}

Test { [[
data Dd with
    var int? v;
end
var Dd d = val Dd(_);
d.v = do
    escape {10};
end;
escape d.v!;
]],
    run = 10,
}

--<< OPTION / DATA

-->> DATA / HIER / ENUM

Test { [[
data Xx;
var Xx x = val Xx();
escape 1;
]],
    wrn = true,
    --stmts = 'line 2 : invalid declaration : cannot instantiate abstract `data` "Xx"',
    run = 1,
}

Test { [[
data Xx as 1;
data Yy as 1;
var  Xx x_ = _;
var& Xx x  = &x_;
escape (x as Yy) as int;
]],
    wrn = true,
    dcls = 'line 5 : invalid operand to `as` : unmatching `data` abstractions',
}

Test { [[
data Xx as 1;
var  Xx x_ = val Xx();
var& Xx xxx  = &x_;
escape xxx as int;
]],
    wrn = true,
    dcls = 'line 4 : invalid operand to `as` : expected `data` type in a hierarchy : got "Xx"',
}

Test { [[
data Xx as 1;
var  Xx x_ = val Xx();
var& Xx xxx  = &x_;
escape 1;
]],
    wrn = true,
    props_ = 'line 1 : invalid `as` declaration : expected `data` hierarchy',
}

Test { [[
data Xx as 1;
data Xx.Yy;
var  Xx x_ = val Xx();
var& Xx xxx  = &x_;
escape xxx as int;
]],
    wrn = true,
    props_ = 'line 2 : invalid `data` declaration : missing `as`',
}

Test { [[
data Xx;
data Xx.Yy as 1;
var  Xx x_ = val Xx();
var& Xx xxx  = &x_;
escape xxx as int;
]],
    wrn = true,
    props_ = 'line 1 : invalid `data` declaration : missing `as`',
}

Test { [[
data Xx as 1;
data Xx.Yy as 2;
var  Xx x_ = val Xx();
var& Xx xxx  = &x_;
escape xxx as int;
]],
    wrn = true,
    run = 1;
}

Test { [[
data Xx as 1;
data Xx.Yy as 1;
var  Xx x = val Xx();
escape x as int;
]],
    wrn = true,
    run = 1;
}

Test { [[
var int a = 0;
data Xx as a;
var Xx x = _;
escape 1;
]],
    wrn = true,
    consts = 'line 2 : invalid `data` declaration : after `is` : expected integer constant',
}

Test { [[
native/const _LEFT, _RIGHT;
native/pre do
    enum {
        LEFT  =  10,
        RIGHT = -1,
    };
end

data Xx as 0;
data Xx.Left  as _LEFT;
data Xx.Right as _RIGHT;

var Xx x1 = val Xx.Left();
var Xx x2 = val Xx.Right();

escape (x1 as int) + (x2 as int);
]],
    run = 9;
}

Test { [[
data Xx as 0;
data Xx.Yy as 1;

code/tight Ff (var int x) -> int do
    escape 111;
end

var int rrr = call Ff(999);
escape rrr;
]],
    wrn = true,
    run = 111,
}

Test { [[
data Xx as 0;
data Xx.Yy as 1;

code/tight Ff (var Xx x) -> int do
    escape x as int;
end

var int rrr = call Ff(Xx.Yy());
escape rrr;
]],
    run = 1,
}

Test { [[
data Xx as -1;
data Xx.Yy as 0;
var Xx x = val Xx();
escape ((x as int) == -1) as int;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Direction as 0;
data Direction.Right as 10;
data Direction.Left as 20;
var Direction.Right x = val Direction.Right();
var Direction y1 = val Direction.Left();
var Direction y2 = x;
escape (y1 as int) + (y2 as int);
]],
    wrn = true,
    run = 30,
    --stmts = 'line 5 : invalid assignment : `data` copy : expected same `data`',
}

Test { [[
data Direction as 0;
data Direction.Right as 10;
data Direction.Left as 20;
var Direction.Right x = val Direction.Right();
var Direction y1 = val Direction.Left();
var Direction? y2 = x;
escape (y1 as int) + (y2! as int);
]],
    wrn = true,
    run = 30,
    --stmts = 'line 5 : invalid assignment : `data` copy : expected same `data`',
}

Test { [[
data Direction as 0;
data Direction.Right as  1;
data Direction.Left as -1;
var Direction.Right xxx = val Direction.Right();
var Direction.Right yyy = xxx;
escape (yyy as int);
]],
    wrn = true,
    run = 1,
}

Test { [[
data Direction as 0;
data Direction.Right as  1;
data Direction.Left as -1;
var Direction.Right x = val Direction.Right();
var& Direction y = &x;
escape (y as int);
]],
    wrn = true,
    run = 1,
}

Test { [[
data Dd as 0;
escape 1;
]],
    wrn = true,
    props_ = 'line 1 : invalid `as` declaration : expected `data` hierarchy',
}
Test { [[
data Dd as nothing;
escape 1;
]],
    wrn = true,
    props_ = 'line 1 : invalid `as` declaration : expected `data` hierarchy',
}
Test { [[
data Dd as nothing;
var Dd d;
escape 1;
]],
    wrn = true,
    --run = 1,
    props_ = 'line 1 : invalid `as` declaration : expected `data` hierarchy',
    --dcls = 'line 2 : invalid declaration : cannot instantiate `data` "Dd"',
}

Test { [[
data Direction as 0;
data Direction.Right as 10;

code/tight Ff (var Direction dir) -> int do
    escape dir as int;
end

var Direction.Right x1 = val Direction.Right();

escape (call Ff(x1));
]],
    wrn = true,
    run = 10,
}

Test { [[
data Direction as nothing;
data Direction.Right as 10;
data Direction.Left as 20;
var Direction y = val Direction();
escape 1;
]],
    wrn = true,
    stmts = 'line 4 : invalid constructor : cannot instantiate `data` "Direction"',
}

Test { [[
data Dd;
data Dd.Ee;
var Dd.Ee e;
escape {CEU_DATA_Dd__dot__Ee};
]],
    run = 1,
    wrn = true,
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
}

Test { [[
data Aa;
data Aa.Bb;
var Aa.Bb b = val Aa.Bb();
escape b as int;
]],
    run = 1,
    wrn = true,
}

--<< DATA / HIER / ENUM

--<<< DATA / HIERARCHY / SUB-DATA / SUB-TYPES / INHERITANCE

Test { [[
data Dx with
    var int x;
end
code/await Cc (none) -> (var Dx d) -> NEVER do
    d = val Dx(200);
    await FOREVER;
end
var&? Cc c = spawn Cc();
escape c!.d.x;
]],
    run = 200,
}

Test { [[
code/await Tx (var& real v) -> none do
end

data Dx with
    var real v;
end

var Dx d;
await Tx(&d.v);
d = val Dx(1);

escape 1;
]],
    wrn = true,
    --ref = 'line 11 : uninitialized variable "d" crossing compound statement (/tmp/tmp.ceu:12)',
    --tmp = 'line 13 : invalid access to uninitialized variable "d" (declared at /tmp/tmp.ceu:11)',
    inits = 'line 8 : uninitialized variable "d" : reached read access (/tmp/tmp.ceu:9)',
}

Test { [[
code/await Tx (var& real v) -> none do
end

data Dx with
    var real v;
end

var Dx d;
spawn Tx(&d.v);
d = val Dx(1);

escape 1;
]],
    wrn = true,
    --ref = 'line 11 : uninitialized variable "d" crossing compound statement (/tmp/tmp.ceu:12)',
    --tmp = 'line 13 : invalid access to uninitialized variable "d" (declared at /tmp/tmp.ceu:11)',
    inits = 'line 8 : uninitialized variable "d" : reached read access (/tmp/tmp.ceu:9)',
}

Test { [[
code/await Tx (var& real v) -> none do
end
var real v;
spawn Tx(&v);
v = 1;
escape 1;
]],
    wrn = true,
    --ref = 'line 11 : uninitialized variable "d" crossing compound statement (/tmp/tmp.ceu:12)',
    --tmp = 'line 13 : invalid access to uninitialized variable "d" (declared at /tmp/tmp.ceu:11)',
    inits = 'line 3 : uninitialized variable "v" : reached read access (/tmp/tmp.ceu:4)',
}

Test { [[
data Vector3f with
    var real x;
    var real y;
    var real z;
end

native _t,_u;
var& _t me;
    code/tight Set_pos (var _u&& p)->none do
        outer.me.p = val Vector3f(p:x, p:y, p:z);
    end
escape 1;
]],
    wrn = true,
    --adt = 'line 9 : invalid attribution : destination is not a "data" type',
    stmts = 'line 10 : invalid constructor : types mismatch : "_t" <= "Vector3f"',
}

Test { [[
data Dx with
    var int x;
    var int y;
end

var Dx d1 =val  Dx(10,10);
var Dx d2 = d1;
d2.y = 20;

escape d1.x + d2.x + d1.y + d2.y;
]],
    run = 50,
}

Test { [[
data Dx with
    var int  x;
    var& int y;
end

var int v = 10;
var Dx d1 = val Dx(10,&v);
var Dx d2 = d1;
d2.y = 20;

escape d1.x + d2.x + d1.y + d2.y;
]],
    run = 60,
}

Test { [[
data Vx with
    var int v;
end

var& Vx v1 = val Vx(1);
var& Vx v2;
var& Vx v3;
    v2 = val Vx(2);
    v3 = val Vx(3);
escape v1.v+v2.v+v3.v;
]],
    --inits = 'line 5 : invalid binding : unexpected statement in the right side',
    inits = 'line 5 : invalid binding : expected operator `&` in the right side',
    --ref = 'line 5 : invalid attribution : missing alias operator `&`',
    --run = 6,
}

Test { [[
data Vx with
    var int v;
end

var Vx v1_ = val Vx(1);
var& Vx v1 = &v1_;
var& Vx v2;
var& Vx v3;
do
    var Vx v2_ = val Vx(2);
    v2 = &v2_;
end
do
    var Vx v3_ = val Vx(3);
    v3 = &v3_;
end
escape v1.v+v2.v+v3.v;
]],
    scopes = 'line 11 : invalid binding : incompatible scopes',
    --inits = 'line 7 : uninitialized variable "v2" crossing compound statement (/tmp/tmp.ceu:8)',
    --ref = 'line 10 : attribution to reference with greater scope',
    --ref = 'line 10 : invalid attribution : variable "v2_" has narrower scope than its destination',
    --run = 6,
}

Test { [[
native _u8;
data Test with
  var[10] _u8 v;
end
var Test t = val Test();
escape t.v[0];
]],
    --env = 'line 4 : arity mismatch',
    dcls = 'line 5 : invalid constructor : expected 1 argument(s)',
}

Test { [[
data Dd with
    var[10] byte x;
end
var Dd d = _;
d.x = d.x..[1];
escape d.x[0];
]],
    run = 1,
}

Test { [[
native _u8;
data Test with
  var[10] _u8 v;
end
var Test t = val Test(_);
t.v[9] = 10;
escape t.v[9];
]],
    run = 10,
}

Test { [[
native _u8;
data Test with
    var int a;
    var[10] _u8 v;
    var int b;
end
var Test t = val Test(1, _, 1);
t.v[0] = 10;
escape t.v[0];
]],
    run = 10,
}

Test { [[
native _char;

data Tx with
    var[255] _char str;
    var int x;
end
var Tx t = val Tx(_, 1);
t.str[0] = {'\0'};
escape t.x;
]],
    run = 1,
}

Test { [[
native _char;
native/pure _strlen;
data Tx with
    var[255] _char xxxx;
end
var Tx t = val Tx("oioioi");
escape _strlen(t.xxxx);
]],
    stmts = 'line 7 : invalid expression list : item #1 : unexpected context for vector "t.xxxx"',
}

Test { [[
native _char;
native/pure _strlen;
data Tx with
    var[255] _char xxxx;
end
var Tx t = val Tx("oioioi");
escape _strlen(&&t.xxxx[0]);
]],
    run = 6,
}

Test { [[
data Tx;
event Tx a;
escape 0;
]],
    dcls = 'line 2 : invalid declaration : unexpected context for `data` "Tx"',
    --dcls = 'line 2 : invalid event type : must be primitive',
}

Test { [[
data Dd with
    var int x;
end

code/tight Fx (var Dd? d) -> int do
    if d? then
        escape d!.x + 1;
    else
        escape 1;
    end
end
escape (call Fx(Dd(1))) + (call Fx(_));
]],
    run = 3,
}

-- << ADT : MISC

-->> DATA / ALIAS / POINTER

Test { [[
data Dd with
    var& _char c;
end
var  _char c = 65;
var& _char p = &c;
var Dd d = val Dd(&c);
escape p + d.c;
]],
    run = 130,
}

Test { [[
native _void, _V, _f;
native/pre do
    int V = 10;
    none* f() {
        return &V;
    }
end

data Dd with
    var& _void ptr;
end

var&? _void ptr = &_f()
    finalize (ptr) with
    end

var Dd d = val Dd(&ptr!);

escape (&&d.ptr == (&&_V as none&&)) as int;
]],
    run = 1,
}

Test { [[
data Dd with
    var& int v;
end

var Dd d1;
do
    var int v = 10;
    var Dd d2 = val Dd(&v);
    d1 = d2;
end
do
    var[10] int x = [];
end

escape d1.v;
]],
    scopes = 'line 9 : invalid assignment : incompatible scopes : `data` "Dd" is not plain',
}

Test { [[
data Dd with
    var int&& v;
end

var Dd d1;
do
    var int v = 10;
    var Dd d2 = val Dd(&&v);
    d1 = d2;
end
do
    var[10] int x = [];
end

escape *d1.v;
]],
    scopes = 'line 9 : invalid assignment : incompatible scopes : `data` "Dd" is not plain',
}

Test { [[
data Dd with
    var int&& v;
end

var int v = 10;
var Dd d2 = val Dd(&&v);
do
    var Dd d1;
    d1 = d2;
    *d1.v = 100;
end
do
    var[10] int x = [];
end

escape *d2.v;
]],
    run = 100,
}

Test { [[
data Dd with
    var int&& x;
end

var int x = 10;
var Dd dd = val Dd(&&x);
await 1s;
escape *dd.x;

]],
    --inits = 'line 8 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:7)',
    ptrs = 'line 8 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:7)',
    --run = { ['~>1s']=1 },
}

Test { [[
data Dd with
    var int&& x;
end
data Ee with
    var Dd dd;
end

var int x = 10;
var Ee ee = val Ee(Dd(&&x));
await 1s;
escape *ee.dd.x;

]],
    --inits = 'line 11 : invalid pointer access : crossed `await` (/tmp/tmp.ceu:10)',
    ptrs = 'line 11 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:10)',
    --run = { ['~>1s']=1 },
}

Test { [[
native _void_ptr, _alloc;
native/pre do
    typedef none* none_ptr;
end

data Dd with
    var& _void_ptr h;
end

var&? _void_ptr ptr = &_alloc()
    finalize (ptr) with
    end;

var Dd dd = val Dd(&ptr!);

await 1s;

escape (dd.h != null) as int;
]],
    cc = 'error: implicit declaration of function ‘alloc’',
}

--<< DATA / ALIAS / POINTER

-->>> DATA/EVENTS

Test { [[
var Ddd d = Ddd(1);
]],
    parser = 'line 1 : after `=` : expected expression',
}

Test { [[
data Ddd with
    var int xxx;
    event none e;
end

var Ddd d = val Ddd(1,_);

par/and do
    await d.e;
with
    await 1s;
    emit d.e;
end

d.xxx = d.xxx + 2;
escape d.xxx;
]],
    run = { ['~>1s']=3 },
}

Test { [[
data Aa with
    event none e;
end
data Aa.Bb;

var Aa.Bb b = val Aa.Bb(_);
par/and do
    await b.e;
with
    emit b.e;
end

escape 1;
]],
    run = 1,
}

Test { [[
data Aa with
    event none e;
end
data Aa.Bb;

var Aa.Bb b = val Aa.Bb(_);
var& Aa a = &b;

par/and do
    await a.e;
with
    emit b.e;
end

escape 1;
]],
    run = 1,
}

Test { [[
data IPoints with
    var&   int  cur;
    event& none inc;
end

var int cur = 0;
event none inc;

var IPoints me_ = val IPoints(&cur,&inc);

escape 1;
]],
    run = 1,
}

Test { [[
data IPoints with
    var&   int  cur;
    event& none inc;
end

code/await Points (none) -> (var& IPoints me) -> none do
    var int cur = 0;
    event none inc;

    var IPoints me_ = val IPoints(&cur,&inc);
    me = &me_;
end

var&? Points points = spawn Points();
watching points do
    emit points.me.inc;
end

escape 1;
]],
    run = 1,
}

--<<< DATA / EVENTS

-->> DATA / VECTOR

Test { [[
data Tt with
    var        int x;
    var[10] int v;
    event      int e;
end

var Tt t;

t.x = 1;
var int x = t.x;

t.v = [1,2,3];
x = t.v[0];

emit t.e;
await t.e;

escape 1;
]],
    stmts = 'line 15 : invalid `emit` : types mismatch : "(int)" <= "()"',
}

Test { [[
native _CEU_APP;
data Vv with
    var[] int xxx;
end
var Vv yyy = val Vv(_);
escape _CEU_APP.root.__mem.trails_n;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 3,
}
Test { [[
native _CEU_APP;
data Vv with
    var[] int xxx;
    var[] int yyy;
end
var Vv zzz = val Vv(_,_);
escape _CEU_APP.root.__mem.trails_n;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 5,
}
Test { [[
native _CEU_APP;
data Vv with
    var[] int xxx;
    var[] int yyy;
end
par/and do
with
    var Vv zzz = val Vv(_,_);
end
escape _CEU_APP.root.__mem.trails_n;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 6,
}
Test { [[
data Vv with
    var[] int xxx;
end

var[] int vvv;

var Vv yyy = val Vv(_);

vvv = [1,2,3];
yyy.xxx = [1,2,3];

escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}
Test { [[
data Kk with
    var[] int xxx;
end

data Vv with
    var Kk kkk;
end

var[] int vvv;

var Vv yyy = val Vv(Kk(_));

vvv = [1,2,3];
yyy.kkk.xxx = [1,2,3];

escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}
Test { [[
data Kk with
    var[] int xxx;
end

data Vv with
    var Kk kkk;
end

var Vv yyy = val Vv(Kk(_));
yyy.kkk.xxx = [1,2,3];

escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 1,
}
Test { [[
data Kk with
    var[] int xxx;
end

data Vv with
    var Kk kkk;
end

var Vv yyy = val Vv(Kk(_));

yyy.kkk.xxx = [1,2,3];
yyy.kkk.xxx[1] = yyy.kkk.xxx[0]+yyy.kkk.xxx[1]+yyy.kkk.xxx[2];

escape yyy.kkk.xxx[1];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 6,
}
Test { [[
data Vv with
    var[] int xxx;
end

var Vv yyy;
yyy = val Vv([1,2,true]);

escape yyy.xxx[1];
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 6 : invalid constructor : item #1 : invalid expression list : item #3 : types mismatch : "int" <= "bool"',
}
Test { [[
data Vv with
    var[] int xxx;
end

var Vv yyy;
yyy = val Vv([1,2]);

escape yyy.xxx[1];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 2,
}
Test { [[
data Vv with
    var int v;
    var[] int xxx;
end

var Vv yyy;
yyy = val Vv(10,[1,2]);

escape yyy.xxx[1] + yyy.v;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 12,
}
Test { [[
data Kk with
    var[] int xxx;
end

data Vv with
    var Kk kkk;
end

var Vv yyy;
yyy = val Vv(Kk([1,2,true]));

escape yyy.kkk.xxx[1];
]],
    _opts = { ceu_features_dynamic='true' },
    stmts = 'line 10 : invalid constructor : item #1 : invalid expression list : item #3 : types mismatch : "int" <= "bool"',
}
Test { [[
data Kk with
    var int aaa;
    var[] int xxx;
end

data Vv with
    var int aaa;
    var Kk kkk;
end

var Vv yyy = val Vv(_,Kk(_,[1,2,3]));

escape yyy.kkk.xxx[1];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 2,
}
Test { [[
data Kk with
    var[] int xxx;
end

data Vv with
    var Kk kkk;
    var[] int zzz;
end

var Vv yyy = val Vv(Kk([1,2,3]), [4,5,6]);

escape yyy.kkk.xxx[1] + yyy.zzz[2];
]],
    _opts = { ceu_features_dynamic='true' },
    run = 8,
}
Test { [[
data Kk with
    var[] byte xxx;
end

data Vv with
    var Kk kkk;
end

var Vv yyy = val Vv(Kk([].."oi"));

native/pure _strlen;
escape _strlen(&&yyy.kkk.xxx[0] as _char&&);
]],
    _opts = { ceu_features_dynamic='true' },
    run = 2,
}

Test { [[
data Tt with
    var[10] int v;
end

var Tt t = val Tt(_);
t.v = [1,2,3];
escape 1;
]],
    run = 1,
}

Test { [[
data Tt with
    var        int x;
    var[10] int v;
    event      int e;
end

var Tt t = val Tt(_,_,_);

t.x = 1;
var int x = t.x;

t.v = [1,2,3];
x = t.v[0];

par do
    var int k = await t.e;
    escape k;
with
    emit t.e(1);
end
]],
    run = 1,
}

Test { [[
data Tt with
    var        int x;
    var[10] int v;
    event      int e;
end

var Tt t;

emit t.x;

escape 1;
]],
    stmts = 'line 9 : invalid `emit` : unexpected context for variable "t.x"',
}

Test { [[
data Ta with
    var        int x;
    var[10] int v;
    event      int e;
end

data Tb with
    var Ta a;
end

var Tb b;

emit b.a.x;

escape 1;
]],
    stmts = 'line 13 : invalid `emit` : unexpected context for variable "b.a.x"',
}

Test { [[
data Ta with
    var        int x;
    var[10] int v;
    event      int e;
end

data Tb with
    var Ta a;
end

var Tb b = val Tb(Ta(_,_,_));

b.a.x = 1;
var int x = b.a.x;

b.a.v = [1,2,3];
x = b.a.v[0];

par do
    await b.a.e;
    escape 1;
with
    emit b.a.e(0);
end
]],
    run = 1,
}

Test { [[
data Ta with
    var        int x;
    var[10] int v;
    event      int e;
end

data Tb with
    var Ta a;
end

var Tb b = val Tb(_);

b.a.x = 1;
var int x = b.a.x;

b.a.v = [1,2,3];
x = b.a.v[0];

par do
    await b.a.e;
    escape 1;
with
    emit b.a.e(0);
end
]],
    run = 1,
}

Test { [[
data Ts;
pool[] Ts ts;
escape ts + 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    dcls = 'line 3 : invalid operand to `+` : unexpected context for pool "ts"',
}
Test { [[
data Dd;
pool[] Dd dds;
escape dds?;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    dcls = 'line 3 : invalid operand to `?` : unexpected context for pool "dds"',
}
Test { [[
data Dd;
pool[] Dd dds;
escape dds!;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    dcls = 'line 3 : invalid operand to `!` : unexpected context for pool "dds"',
}

Test { [[
code/await Ff (none)->none do end
pool[5] Ff a;
pool[5] Ff b = a;
escape 1;
]],
    _opts = { ceu_features_pool='true' },
    stmts = 'line 3 : invalid assignment : unexpected context for pool "a"',
}

Test { [[
data Dd with
    var int n;
    var[n] int vs;
end
]],
    wrn = true,
    consts = 'line 3 : invalid declaration : vector dimension must be an integer constant',
}

Test { [[
native/pure _strlen;

data Dd with
    var[] byte xxx;
end

code/tight Ff (var& Dd d) -> int do
    escape _strlen(&&d.xxx[0] as _char&&);
end

var Dd d = val Dd([].."oioi");

escape call Ff(&d);
]],
    _opts = { ceu_features_dynamic='true' },
    wrn = true,
    run = 4,
}

Test { [[
data Aa with
    event none e;
end
var Aa d = _;
escape 1;
]],
    --wrn = true,
    run = 1,
}

Test { [[
data Aa with
    var[] u8 v;
end
var Aa d = _;
escape 1;
]],
    _opts = { ceu_features_dynamic='true' },
    --wrn = true,
    run = 1,
}

Test { [[
data Bb with
    var [] byte v;
end
data Aa with
    var Bb b;
end
var Aa d = _;
d.b = val Bb([1,2,3]);
escape $d.b.v as int;
]],
    _opts = { ceu_features_dynamic='true' },
    --wrn = true,
    run = 3,
}

Test { [[
data Data with
   var [] byte v;
end
var Data d = _;
code/tight Ff (none)->int do
    outer.d = val Data([1,2,3]);
    escape $outer.d.v as int;
end
escape (call Ff ());
]],
    _opts = { ceu_features_dynamic='true' },
    --wrn = true,
    run = 3,
}

Test { [[
data Dd with
    var int x = 10;
end
var[] Dd ds = [];
var Dd d2 = val Dd(_);
var Dd d1 = val Dd(1);
ds = ds .. [d2,d1];
escape ds[0].x + ds[1].x;
]],
    _opts = { ceu_features_dynamic='true' },
    run = 11,
}

--<< DATA / VECTOR

-->> DATA / DEFAULT / CONSTRUCTOR
Test { [[
data Dd with
    var int x = 10;
end
var Dd ddd = _;
escape ddd.x;
]],
    --wrn = true,
    run = 10,
}

Test { [[
data Dd with
    var int x = 10;
    var int y;
end
var Dd ddd = _;
escape ddd.x;
]],
    --inits = 'line 5 : uninitialized variable "ddd"',
    run = 10,
}

Test { [[
data Ee with
    var int e = 10;
end
data Dd with
    var Ee e1 = _;
end
var Dd d = _;
escape d.e1.e;
]],
    --wrn = true,
    run = 10,
}

Test { [[
data Ee with
    var int e = 10;
end
data Dd with
    var Ee e1 = _;
    var Ee e2 = val Ee(_);
    var Ee e3 = val Ee(100);
end
var Dd d = _;
escape d.e1.e + d.e2.e + d.e3.e;
]],
    --wrn = true,
    run = 120,
}

Test { [[
data Obj with
    var int x = 0;
end

var int ret = 0;

code/await DoObj(var Obj o) -> NEVER
do
    outer.ret = outer.ret + o.x;
    await FOREVER;
end

spawn DoObj(Obj(1));

escape ret;
]],
    run = 1,
}

Test { [[
data Obj with
    var bool a = false;
end

var int ret = 0;

code/await DoObjRef(var& Obj o) -> NEVER
do
    outer.ret = outer.ret + (o.a as int);
    await FOREVER;
end

code/await DoObj(var Obj o) -> NEVER
do
    outer.ret = outer.ret + (o.a as int);
    await FOREVER;
end

spawn DoObj(Obj(true));

var Obj o = val Obj(true);
spawn DoObj(o);

spawn DoObjRef(&o);

escape ret;
]],
    run = 3,
}

Test { [[
data Dd with
    var int x = 10;
end

code/tight Ff (var Dd d) -> int do
    escape d.x;
end

var Dd d = val Dd(_);

escape call Ff(Dd(_)) + d.x
     + call Ff(Dd(_));
]],
    run = 30,
}
Test { [[
data Dd with
    var int x = 10;
end

code/await Ff (var Dd d) -> int do
    escape d.x;
end

var int x = await Ff(Dd(_));
escape x;
]],
    run = 10,
}
Test { [[
data Dd with
    var int x = 10;
end

code/tight Ff (var Dd d) -> int do
    escape d.x;
end

escape call Ff(_);
//escape call Ff(Dd(_));
]],
    --wrn = true,
    run = 10,
}
Test { [[
data Dd with
    var int x = 10;
end
var Dd d = _;
escape d.x;
]],
    --wrn = true,
    run = 10,
}
Test { [[
data Dd with
    var int x = 10;
end
var Dd d = val Dd(_);
escape d.x;
]],
    run = 10,
}

Test { [[
data Dd with
    var int v=10;
end
code/tight Ff (var Dd d) -> int do
    escape d.v;
end
escape call Ff(Dd(10));
]],
    run = 10,
}
Test { [[
data Dd with
    var int v=10;
end
code/tight Ff (var Dd d) -> int do
    escape d.v;
end
escape call Ff(Dd(_));
]],
    run = 10,
}

Test { [[
native/const
    _CONSTANT,
;
native/pre do
    ##define CONSTANT 10
end

data Object with
  var int c = _CONSTANT;
end

var Object a = _;

escape a.c;
]],
    --wrn = true,
    run = 10,
}

Test { [[
native/const
    _CONSTANT,
;
native/pre do
    ##define CONSTANT 10
end

data Object with
  var int c = _CONSTANT+10;
end

var Object a = _;

escape a.c;
]],
    --wrn = true,
    run = 20,
}

Test { [[
data Object with
  var int c = 101;
end
code/await Show(var Object obj) -> int do
    escape obj.c;
end
var int r = await Show(_);
escape r;
]],
    --wrn = true,
    run = 101,
}
Test { [[
data Object with
  var int c = 101;
end
code/await Show(var Object obj) -> (var& int ret) -> int do
    var int a = obj.c;
    ret = &a;
    escape a;
end
var int r = await Show(_);
escape r;
]],
    --wrn = true,
    run = 101,
}
Test { [[
data Object with
  var int c = 101;
end
code/await Show(var Object obj) -> (var& int ret) -> NEVER do
    var int a = obj.c;
    ret = &a;
    await FOREVER;
end

var&? Show s;
s = spawn Show(Object(1)); // prints 0
escape s!.ret;
]],
    run = 1,
}
Test { [[
data Object with
  var int c = 101;
end
code/tight Show(var Object obj) -> int do
    escape obj.c;
end
escape call Show(Object(_));
]],
    --wrn = true,
    run = 101,
}
Test { [[
data Object with
  var int c = 101;
end
code/tight Show(var Object obj) -> int do
    escape obj.c;
end
escape call Show(_);
]],
    --wrn = true,
    run = 101,
}
Test { [[
data Object with
  var int ccc = 101;
end
code/await Show(var Object obj) -> (var& int rrr) -> NEVER do
    var int aaa = obj.ccc;
    rrr = &aaa;
    await FOREVER;
end

spawn Show(Object(_));
escape 10;
]],
    --wrn = true,
    run = 10,
}

Test { [[
data Object with
  var int ccc = 101;
end
code/await Show(var Object obj) -> (var& int rrr) -> int do
    var int aaa = obj.ccc;
    rrr = &aaa;
    await 1s;
    escape 1;
end

var&? Show s =
spawn Show(Object(_));
var& int rr = &s!.rrr;                  // TODO: should not allow this
await 2s;
escape rr;
]],
    scopes = 'line 13 : invalid binding : unexpected source with `&?` : destination may outlive source',
    --wrn = true,
    --run = { ['~>2s']=101 },
}

Test { [[
data Object with
  var int ccc = 101;
end
code/await Show(var Object obj) -> (var& int rrr) -> int do
    var int aaa = obj.ccc;
    rrr = &aaa;
    await 1s;
    escape 1;
end

var&? Show s =
spawn Show(Object(_));
escape s!.rrr;
]],
    --wrn = true,
    run = 101,
}
Test { [[
data Object with
  var int c = 101;
end
code/await Show(var Object obj) -> (var& int ret) -> NEVER do
    var int a = obj.c;
    ret = &a;
    await FOREVER;
end

var&? Show s =
spawn Show(_); // prints 0
escape s!.ret;
]],
    --wrn = true,
    run = 101,
}

Test { [[
data Aa with
    var int a;
end
data Aa.Bb with
    var int b = 20;
end
var Aa.Bb b = _;
escape b.b;
]],
    wrn = true,
    run = 20,
}
Test { [[
data Aa with
    var int a;
end
data Aa.Bb with
    var int b = 20;
end
var Aa.Bb b = _;
escape b.b;
]],
    --inits = 'line 7 : uninitialized variable "b"',
    run = 20,
}

Test { [[
data Dd with
    var int x = 111;
end
code/await Ff (var Dd d) -> int do
    escape d.x;
end
var int ret = await Ff(_);
escape ret;
]],
    run = 111,
}

Test { [[
data Dd with
    var int x = 111;
end
code/tight Ff (var Dd d) -> int do
    escape d.x;
end
var int ret = call Ff(_);
escape ret;
]],
    run = 111,
}

Test { [[
data Dd with
    var int x = 111;
end
code/await Ff (none) -> (var Dd d) -> NEVER do
    d = val Dd(_);
    await FOREVER;
end
var&? Ff f = spawn Ff();
escape f!.d.x;
]],
    run = 111,
}

--<< DATA / DEFAULT / CONSTRUCTOR

-->> DATA / CODE / SCOPE

Test { [[
do/_
    data Dd with
        var int x = 0;
    end
end
do/_
    data Dd with
        var int x = 100;
    end
    var Dd d = _;
    escape d.x;
end
]],
    wrn = true,
    run = 100,
}

Test { [[
do/_
    code/tight Ff (none) -> int do
        escape 10;
    end
end
do/_
    code/tight Ff (none) -> int do
        escape 100;
    end
    escape call Ff();
end
]],
    wrn = true,
    run = 100,
}

Test { [[
do/_
    code/await Ff (none) -> int do
        escape 10;
    end
end
do/_
    code/await Ff (none) -> int do
        escape 100;
    end
    var int ret = await Ff();
    escape ret;
end
]],
    wrn = true,
    run = 100,
}

Test { [[
code/tight Ff (none) -> none;
code/tight Ff (none) -> none do
end
call Ff();
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    run = 1,
}

Test { [[
code/await Ff (none) -> none;
code/await Ff (none) -> none do
end
await Ff();
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    run = 1,
}

Test { [[
do/_
    code/await Ff (none) -> none;
    code/await Ff (none) -> none do
    end
    await Ff();
    escape 1;
end
]],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    run = 1,
}

Test { [[
data IData with
   var int d;
end
code/await Data (var int d) -> (var& IData mydata) -> none;
code/await Data (var int d) -> (var& IData mydata) -> none
do
   var IData ref_ = val IData (d);
   mydata = &ref_;
end
await Data (0);
escape 1;
]],
    run = 1,
}

--<< DATA / CODE / SCOPE

-->> CODE / RETURN / DATA

Test { [[
data Dd;

code/await Ff (none) -> Dd do
    var Dd d = _;
    escape d;
end

var Dd d = await Ff();

escape 10;
]],
    run = 10,
}
Test { [[
data Dd with
    var int x = 10;
end

code/await Ff (none) -> Dd do
    var Dd d = val Dd(_);
    escape d;
end

var Dd d = await Ff();

escape d.x;
]],
    run = 10,
}
Test { [[
data Dd with
    var int x = 10;
end

code/tight Ff (none) -> Dd do
    var Dd d = val Dd(_);
    escape d;
end

var Dd d = call Ff();

escape d.x;
]],
    run = 10,
}

Test { [[
data Dd with
    var int x = 10;
end
code/await Ff (none) -> Dd do
    code/tight Gg (none) -> Dd do
        var Dd d = _;
        escape d;
    end
    var Dd d = call Gg();
    escape d;
end
var Dd d = await Ff();
escape d.x;
]],
    run = 10,
}

Test { [[
data Dd with
    var int x = 10;
end
code/await Ff (none) -> Dd do
    code/tight Gg (none) -> Dd do
        var Dd d = _;
        escape d;
    end
    escape call Gg();
end
var Dd d = await Ff();
escape d.x;
]],
    run = 10,
}

Test { [[
code/tight Ff (none) -> int do
    data Dd with
        var int x;
    end
    var Dd d = val Dd(10);
    escape d.x;
end
escape call Ff();
]],
    run = 10,
}

--<< CODE / RETURN / DATA

-->> DATA / RECURSIVE / OPTION ALIAS

Test { [[
data Dd with
    var int x;
    var&? Dd d;
end
var Dd d = val Dd(10,_);
escape d.x;
]],
    run = 10,
}

Test { [[
data Dd with
    var int x;
    var&? Dd d;
end
var Dd d1 = val Dd(10,_);
var Dd d2 = val Dd(20,&d1);
escape d2.x + d2.d!.x;
]],
    run = 30,
}

Test { [[
data Dd with
    var int x = 1;
    var&? Dd d;
end
code/tight/recursive Dd_D(var& Dd d, var& Dd ret) -> none do
    if d.d? then
        call/recursive Dd_D(&d.d!, &ret);
    end
    ret.x = ret.x + d.x;
end
var Dd d1 = val Dd(10,_);
var Dd d2 = val Dd(20,&d1);
var Dd d = _;
call/recursive Dd_D(&d2,&d);
escape d.x;
]],
    run = 31,
}

Test { [[
data Dd with
    var int x = 1;
    var&? Dd d;
end
code/tight/recursive Dd_D_(var& Dd d, var& Dd ret) -> none do
    if d.d? then
        call/recursive Dd_D_(&d.d!, &ret);
    end
    ret.x = ret.x + d.x;
end
code/tight/recursive Dd_D(var& Dd d, var& Dd ret) -> none do
    ret = val Dd(0,_);
    call/recursive Dd_D_(&d, &ret);
end
var Dd d1 = val Dd(10,_);
var Dd d2 = val Dd(20,&d1);
var Dd d = _;
call/recursive Dd_D(&d2,&d);
escape d.x;
]],
    run = 30,
}

--<< DATA / RECURSIVE / OPTION ALIAS

--<<< DATA

-->>> ASYNCS // THREADS

Test { [[
var int  a=10; var int  b=5;
var& int p = &b;
await async/thread do
end
escape a + b + p;
]],
    run = 20,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var bool ret =
    await async/thread do
    end;
escape ret as int;
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
event& none ret =
    await async/thread do
    end;
escape 0;
]],
    stmts = 'line 1 : invalid `async/thread` assignment : unexpected context for event "ret"',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int ret =
    await async/thread do
    end;
escape (ret == 1) as int;
]],
    stmts = 'line 2 : invalid `async/thread` assignment : expected `bool` destination',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int ret=1;
await async/thread (ret) do
    ret = ret + 10;
end
escape ret;
]],
    run = 11,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
await async/thread do
end
await async/thread do
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
await async/thread do
end
await async do end
await async/thread do
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
await async/thread do
end
par/and do
    await async/thread do
    end
with
    await async/thread do
    end
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
par/and do
    await async/thread do
    end
with
    await async/thread do
    end
end
await async/thread do
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
par/and do
    await async/thread do
    end
with
    await async/thread do
    end
end
par/and do
    await async/thread do
    end
with
    await async/thread do
    end
end
par/and do
    await async/thread do
    end
with
    await async/thread do
    end
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
par/or do
    await async/thread do
    end
with
    await async/thread do
    end
end
par/and do
    await async/thread do
    end
with
    await async/thread do
    end
end
par/or do
    await async/thread do
    end
with
    await async/thread do
    end
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
    valgrind = false,
}
Test { [[
native _usleep;
par/or do
    await async/thread do
        _usleep(100);
    end
with
    await async/thread do
    end
end
par/and do
    await async/thread do
        _usleep(100);
    end
with
    await async/thread do
    end
end
par/or do
    await async/thread do
    end
with
    await async/thread do
        _usleep(100);
    end
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
    valgrind = false,
}

Test { [[
code/await Test(none) -> NEVER do
    do finalize with
        await async/thread do
        end
    end
    await FOREVER;
end

par/or do
    await Test();
with
    await 1ms;
end

escape 0;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
    props_ = 'line 3 : invalid `async/thread` : unexpected enclosing `finalize`',
}
Test { [[
var int  a=10; var int  b=5;
var& int p = &b;
await async/thread (a, p) do
    a = a + p;
    atomic do
        p = a;
    end
end
escape a + b + p;
]],
    run = 45,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int  a=10; var int  b=5;
var& int p = &b;
var bool ret =
    await async/thread (a, p) do
        a = a + p;
        atomic do
            p = a;
        end
    end;
escape (ret as int) + a + b + p;
]],
    run = 46,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
atomic do
    escape 1;
end
]],
    props = 'line 2 : not permitted inside `atomic`',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
native/pos do
    ##define ceu_out_isr_on();
    ##define ceu_out_isr_off();
end
await async do
    atomic do
        nothing;
    end
end
escape 1;
]],
    --props = 'line 2 : not permitted outside `thread`',
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int x = 0;
par/and do
    x = 1;
with
    var& int p = &x;
    p = 2;
    await async/thread (p) do
        p = 2;
    end
end
escape x;
]],
    _ana = {
        acc = 4,
    },
    run = 2,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int x = 0;
par/and do
    x = 1;
with
    var& int p = &x;
    p = 2;
    await async/thread (p) do
        atomic do
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
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int  a=10; var int  b=5;
var& int p = &b;
await async/thread (a, p) do
    a = a + p;
    p = a;
end
escape a + b + p;
]],
    run = 45,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int  a=10; var int  b=5;
var int&& p = &&b;
await async/thread (p) do
    *p = 1;
end
escape 1;
]],
    --inits = 'line 3 : invalid pointer access : crossed `async/thread` (/tmp/tmp.ceu:3)',
    ptrs = 'line 3 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:3)',
    --fin = 'line 3 : unsafe access to pointer "p" across `async/thread`',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
native _usleep;
var int  a=10; var int  b=5;
var& int p = &b;
par/and do
    await async/thread (a, p) do
        _usleep(100);
        a = a + p;
        p = a;
    end
with
    p = 2;
end
escape a + b + p;
]],
    _ana = {
        acc = true,
    },
    run = 36,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int  a=10; var int  b=5;
var& int p = &b;
await async/thread (a, p) do
    atomic do
        a = a + p;
        p = a;
    end
end
escape a + b + p;
]],
    run = 45,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

for i=1, 50 do
    Test { [[
native/pos do
    ##include <unistd.h>
end
var int ret = 1;
var& int p = &ret;
par/or do
    await async/thread (p) do
        atomic do
            p = 2;
        end
    end
with
end
native _usleep;
_usleep(]]..i..[[);
escape ret;
]],
        usleep = true,
        run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
    }
end

for i=1, 50 do
    Test { [[
native _usleep;
native/pos do
    ##include <unistd.h>
end
var int rrr = 0;
var& int ppp = &rrr;
par/or do
    await async/thread (ppp) do
        _usleep(]]..i..[[);
        atomic do
            ppp = 2;
        end
    end
with
    rrr = 1;
end
_usleep(]]..i..[[+1);
escape rrr;
]],
        complete = (i>1),   -- run i=1 for sure
        usleep = true,
        run = 1,
        _ana = { acc=1 },
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
    }
end

Test { [[
var int  v1=10; var int  v2=5;
var& int p1 = &v1;
var& int p2 = &v2;

par/and do
    await async/thread (v1, p1) do
        atomic do
            p1 = v1 + v1;
        end
    end
with
    await async/thread (v2, p2) do
        atomic do
            p2 = v2 + v2;
        end
    end
end
escape v1+v2;
]],
    run = 30,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int  v1=0; var int  v2=0;
var& int p1 = &v1;
var& int p2 = &v2;

native _calc, _assert;
native/pos do
    int calc ()
    {
        int ret, i, j;
        ret = 0;
        for (i=0; i<10; i++) {
            for (j=0; j<10; j++) {
                ret = ret + i + j;
            }
        }
        return ret;
    }
end

par/and do
    await async/thread (p1) do
        var int ret = _calc();
        atomic do
            p1 = ret;
        end
    end
with
    await async/thread (p2) do
        var int ret = _calc();
        atomic do
            p2 = ret;
        end
    end
end
native/pos do ##include <assert.h> end
_assert(v1 == v2);
escape v1;
]],
    run = 900,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
native _assert;
var int  v1=0; var int  v2=0;
var& int p1 = &v1;
var& int p2 = &v2;

par/and do
    await async/thread (p1) do
        var int ret = 0;
var int i;
        loop i in [0 -> 10[ do
var int j;
            loop j in [0 -> 10[ do
                ret = ret + i + j;
            end
        end
        atomic do
            p1 = ret;
        end
    end
with
    await async/thread (p2) do
        var int ret = 0;
var int i;
        loop i in [0 -> 10[ do
var int j;
            loop j in [0 -> 10[ do
                ret = ret + i + j;
            end
        end
        atomic do
            p2 = ret;
        end
    end
end
native/pos do ##include <assert.h> end
_assert(v1 == v2);
escape v1;
]],
    run = 900,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int  v1=0; var int  v2=0;
var& int p1 = &v1;
var& int p2 = &v2;

native/pos do
    int calc ()
    {
        int ret, i, j;
        ret = 0;
        for (i=0; i<50000; i++) {
            for (j=0; j<50000; j++) {
                ret = ret + i + j;
            }
        }
        return ret;
    }
end

native _calc, _assert;
par/and do
    await async/thread (p1) do
        var int ret = _calc();
        atomic do
            p1 = ret;
        end
    end
with
    await async/thread (p2) do
        var int ret = _calc();
        atomic do
            p2 = ret;
        end
    end
end
native/pos do ##include <assert.h> end
_assert(v1 == v2);
escape v1;
]],
    --run = false,
    run = 1066784512,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
native _assert;
var int  v1=0; var int  v2=0;
var& int p1 = &v1;
var& int p2 = &v2;

par/and do
    await async/thread (p1) do
        var int ret = 0;
var int i;
        loop i in [0 -> 50000[ do
var int j;
            loop j in [0 -> 50000[ do
                ret = ret + i + j;
            end
        end
        atomic do
            p1 = ret;
        end
    end
with
    await async/thread (p2) do
        var int ret = 0;
var int i;
        loop i in [0 -> 50000[ do
var int j;
            loop j in [0 -> 50000[ do
                ret = ret + i + j;
            end
        end
        atomic do
            p2 = ret;
        end
    end
end
native/pos do ##include <assert.h> end
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
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
native/pre do
    ##include <unistd.h>
    int V = 0;
end
native _usleep;
par/or do
    await async do
var int i;
        loop i in [0 -> 3[ do
            _usleep(500);
        end
    end
with
    await async/thread do
var int i;
        loop i in [0 -> 2[ do
            _V = _V + 1;
            _usleep(500);
        end
    end
end
escape _V;
]],
    dcls = 'line 17 : native identifier "_V" is not declared',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
native/pre do
    ##include <unistd.h>
    int V = 0;
end
native _usleep;
native _V;
par/or do
    await async do
        var int i;
        loop i in [0 -> 3[ do
            _usleep(500);
        end
    end
with
    await async/thread do
        var int i;
        loop i in [0 -> 2[ do
            _V = _V + 1;
            _usleep(500);
        end
    end
end
escape _V;
]],
    _ana = {acc=1},
    usleep = true,
    run = 2,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
    await async/thread do
        var int i;
        loop i in [0->5[ do
        end
    end
    escape 1;
]],
    run = 1,
    _opts = {
        ceu_features_dynamic='true', ceu_features_thread = 'true',
        ceu_features_trace  ='true',
    },
}

-- THREADS / EMITS

Test { [[
input int A;
par/or do
    await A;
with
    await async/thread do
        emit A(10);
    end
end;
escape 10;
]],
    _ana = {
        isForever = false,
    },
    --run = 10,
    stmts = 'line 6 : invalid `emit` : unexpected context for external `input` "A"',
    --props = 'not permitted inside `thread`',
    --props = 'line 6 : invalid `emit`',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
input int A;
par/or do
    await A;
with
    await async do
        emit A(10);
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
var int a=1;
var& int pa = &a;
await async/thread (pa) do
    emit 1min;
    pa = 10;
end;
escape a + 1;
]],
    --run = 11,
    props_ = 'line 4 : invalid `emit` : expected enclosing `async` or `async/isr`',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
var int a=1;
var& int pa = &a;
await async (pa) do
    emit 1min;
    pa = 10;
end;
escape a + 1;
]],
    run = 11,
}

Test { [[
par do
    var int v1=4; var int v2=4;
    par/or do
        await 10ms;
        v1 = 1;
    with
        await 10ms;
        v2 = 2;
    end
    escape v1 + v2;
with
    await async/thread do
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
    props_ = 'line 13 : invalid `emit` : expected enclosing `async` or `async/isr`',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
par do
    var int v1=4; var int v2=4;
    par/or do
        await 10ms;
        v1 = 1;
    with
        await 10ms;
        v2 = 2;
    end
    escape v1 + v2;
with
    await async do
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
    await async/thread do end
with
    await A;
    escape 1;
end
]],
    run = { ['1~>A']=1 },
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
native/pos do ##include <assert.h> end
native _assert;
input none A;
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
        par/or do
            var int t;
            t = await 1s;
        with
            loop do
                await A;
                i = i + 1;
            end
        end
    end
with
    await async/thread do
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
    end
end
escape ret;
]],
    --run = 72000,
    stmts = 'line 27 : invalid `emit` : unexpected context for external `input` "A"',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
native/pos do ##include <assert.h> end
native _assert;
input none A;
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
        par/or do
            var int t;
            t = await 1s;
            if t!=0 then end;
        with
            loop do
                await A;
                i = i + 1;
            end
        end
    end
with
    await async do
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
        emit 12ms;
        emit A;
    end
end
escape ret;
]],
    run = 72000,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
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
    await async/thread do
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
    --run = 0,
    stmts = 'line 17 : invalid `emit` : unexpected context for external `input` "P2"',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
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
    await async do
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

Test { [[
var int ret = 0;
input none A;
par/and do
    await 1s;
    ret = ret + 1;
with
    await async do
        emit 1s;
    end
    ret = ret + 1;
with
    await async/thread do
        atomic do
        end
    end
    ret = ret + 1;
with
    await async do
        emit A;
    end
    ret = ret + 1;
end
escape ret;
]],
    run = { ['~>A;~>1s'] = 4 },
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

-- ASYNC/NONDET

Test { [[
var int x = 0;
await async do
    x = 2;
end
escape x;
]],
    dcls = 'line 3 : internal identifier "x" is not declared',
}

Test { [[
var int x = 0;
await async/thread do
    x = 2;
end
escape x;
]],
    dcls = 'line 3 : internal identifier "x" is not declared',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int x = 0;
par/and do
    x = 1;
with
    await async (x) do
        x = 2;
    end
end
escape x;
]],
    _ana = { acc=1 },
    run = 2,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int x = 0;
par/and do
    x = 1;
with
    await async/thread (x) do
        x = 2;
    end
end
escape x;
]],
    _ana = { acc=1 },
    run = 2,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int x = 0;
par/and do
    x = 1;
with
    await async/thread (x) do
        x = 2;
    end
end
escape x;
]],
    _ana = {
        acc = 1,
    },
    run = 2,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int x = 0;
par/and do
    await 1s;
    x = 1;
with
    var int y = x;
    await async/thread (y) do
        y = 2;
native _usleep;
        _usleep(150);   // forces "await 1s" awake before
    end
    x = x + y;
end
escape x;
]],
    valgrind = false,
    run = { ['~>1s']=3 },
    _ana = {
        acc = true,
    },
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int x = 0;
par/and do
    await 1s;
    x = 1;
with
    var int y = x;
    await async/thread (y) do
        y = 2;
native _usleep;
        _usleep(150);   // forces "await 1s" awake before
    end
    x = x + y;
end
escape x;
]],
    valgrind = false,
    run = { ['~>1s']=3 },
    safety = 2,
    _ana = {
        acc = 3,
    },
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int x  = 0;
par/and do
var int&& p = &&x;
    *p = 1;
with
    var int y = x;
    await async/thread (y) do
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
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
native/plain _int;
var[10] _int x = _;
await async/thread (x) do
    x[0] = 2;
end
escape x[0];
]],
    wrn = true,
    run = 2,
    --gcc = 'error: lvalue required as left operand of assignment',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var[10] int x = [0];
await async/thread (x) do
    x[0] = 2;
end
escape x[0];
]],
    run = 2,
    --gcc = 'error: lvalue required as left operand of assignment',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var[10] int x = [0,1];
par/and do
    await async/thread (x) do
native _usleep;
        _usleep(100);
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
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int v = 1;
await async (v) do
    do finalize with
        v = 2;
    end
end;
escape v;
]],
    props_ = 'line 3 : invalid `finalize` : unexpected enclosing `async`',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
var int v = 1;
await async/thread (v) do
    do finalize with
        v = 2;
    end
end;
escape v;
]],
    props = 'line 3 : not permitted inside `thread`',
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
native _f;
native/pos do
    int f (int v) {
        return v + 1;
    }
end
var int a = 0;
await async/thread (a) do
    a = _f(10);
end
escape a;
]],
    run = 11,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int ret = 0;
await async (ret) do
    ret = do escape 1; end;
end
escape ret;
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}
Test { [[
var int ret = 0;
await async/thread (ret) do
    ret = do escape 1; end;
end
escape ret;
]],
    run = 1,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [=[
await async/thread do
end
await 1s;
escape 1;
]=],
    run = {['~>1s; ~>1s']=1},
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [=[
    await async/thread do
    end
var int i;
    loop i in [0 -> 100[ do
        await 1s;
    end
    escape 1;
]=],
    run = {['~>100s;~>100s']=1},
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

--<<< THREADS / EMITS

Test { [[
native _V;
native/pre do
    int V = 1;
end
code/await Ff (none)->none do
    do finalize with
        _V = _V + 10;
    end
    _V = _V + 1;
    _V = _V * 2;
    await FOREVER;
end
do
    spawn Ff();
    await 1s;
end
escape _V;
]],
    run = { ['~>1s']=14 },
}

Test { [[
native _V;
native/pre do
    int V = 1;
end
code/await Ff (none)->none do
    do finalize with
        _V = _V + 10;
    end
    await async/thread do
        _V = _V + 1;
    end
    _V = _V * 2;
    await FOREVER;
end
do
    spawn Ff();
    await 1s;
end
escape _V;
]],
    run = { ['~>1s']=14 },
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
atomic do
    escape 1;
end
]],
    props_ = 'line 1 : `atomic` support is disabled: enable `--ceu-features-thread` or `--ceu-features-isr`',
}

-- TODO: no escape
Test { [[
atomic do
    escape 1;
end
]],
    _opts = {
        ceu = true,
        ceu_features_dynamic='true', ceu_features_thread = 'true',
    },
    todo = 'no escape',
}

Test { [[
var int ret = 0;
atomic do
    ret = 1;
end
escape ret;
]],
    _opts = {
        ceu = true,
        ceu_features_dynamic='true', ceu_features_thread = 'true',
    },
    run = 1,
}

Test { [[
code/tight Fx (none)->int do
    escape 2;
end
var int v = call Fx();
par/or do
    await async/thread (v) do
        v = v + call Fx();
    end
with
end
escape v;
]],
    --isr = 'line 7 : call breaks the static check for `atomic` sections',
    --dcls = 'line 6 : abstraction inside `async` : not implemented',
    run = 4,
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
}

Test { [[
var int i;
loop i in [1->10] do
    par/and do
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    with
        await async/thread do end;
    end
end
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_thread='true' },
    run = 1,
    valgrind = false,
}

--<<< ASYNCS / THREADS

-->> KILL

Test { [[
event int a;
kill a;
escape 1;
]],
    stmts = 'line 2 : invalid `kill` : unexpected context for event "a"',
}

Test { [[
var int a = 0;
kill a;
escape 1;
]],
    stmts = 'line 2 : invalid `kill` : expected `code/await` abstraction',
}

Test { [[
code/await Ff (none) -> none do
    await 1s;
end
var&? Ff f = spawn Ff();
par/and do
    await f;
with
    kill f;
end

escape 1;
]],
    run = 1,
}
Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
var&? Ff f = spawn Ff();
par/and do
    await f;
with
    kill f;
end

escape 1;
]],
    stmts = 'line 8 : invalid kill : `code/await` executes forever',
    --run = 1,
}
Test { [[
code/await Ff (none) -> none do
    await 1s;
end
var&? Ff f = spawn Ff();
par/or do
    await f;
with
    kill f;
    {ceu_assert(0,"bug found");}
end

escape 1;
]],
    run = 1,
}
Test { [[
code/await Ff (none) -> none do
    await 1s;
end
event none e;
watching e do
    pool[] Ff fs;
    var&? Ff f = spawn Ff() in fs;
    par/or do
        await f;
        emit e;
    with
        kill f;
        {ceu_assert(0,"bug found");}
    end
end

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = 1,
}

Test { [[
code/await Tx (none) -> none do
    await 1s;
end
var&? Tx aaa = spawn Tx();
par/and do
    kill aaa;
with
    await aaa;
end
escape 1;
]],
    _ana = { acc=3 },
    run = 1,
}

Test { [[
code/await Tx (none) -> (var int a) -> none do
    a = 1;
    await 1s;
end
var&? Tx a = spawn Tx();
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
code/await Tx (none) -> (var int a) -> none do
    a = 1;
    await 1s;
end
var&? Tx a = spawn Tx();

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
native/pre do
    int V = 0;
end

code/await Gg (none) -> none do
    every 100ms do
        {V++;}
    end
end

code/await Ff (none) -> (pool[1] Gg gs) -> NEVER do
    var&? Gg g1 = spawn Gg() in gs;
    kill g1;
    var&? Gg g2 = spawn Gg() in gs;
    await FOREVER;
end

spawn Ff();
await 1s;
escape {V};
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = {['~>1s']=10},
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
var& Ff f = spawn Ff();
kill f;
escape 0;
]],
    stmts = 'line 5 : invalid `kill` : expected `&?` alias',
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
pool[] Ff fs;
spawn Ff() in fs;
var&? Ff f;
loop f in fs do
    kill f;
end
escape 0;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    stmts = 'line 8 : invalid kill : `code/await` executes forever',
}

Test { [[
code/await Ff (none) -> (var int a) -> NEVER do
    a = 1;
    await FOREVER;
end
pool[] Ff fs;
spawn Ff() in fs;
var&? Ff f;
loop f in fs do
    kill f;
end
escape 0;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    stmts = 'line 9 : invalid kill : `code/await` executes forever',
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
var& Ff f = spawn Ff();
kill f;     // error
escape 1;
]],
    stmts = 'line 5 : invalid `kill` : expected `&?` alias',
}
Test { [[
input none A;
code/await Ff (none) -> int do
    await A;
    escape 10;
end
var int v = await Ff();
escape v+1;
]],
    run = {['~>A']=11},
}

--<< KILL

-->> CODE / FINALIZE / EMIT / SPAWN / THREADS

Test { [[
event none e;
var int ret = 0;
par/or do
    every e do
        ret = ret + 1;
    end
with
    watching e do
        do finalize with
            emit e;
        end
    end
end

escape ret;
]],
    run = 1,
}

Test { [[
var int ret = 0;

code/tight Ff (none) -> none do
    outer.ret = outer.ret + 1;
end

do
    do finalize with
        call Ff();
    end
end

escape ret;
]],
    run = 1,
}

Test { [[
var int ret = 0;

code/await Ff (none) -> none do
    outer.ret = outer.ret + 1;
end

//pool[] Ff fs;

do
    do finalize with
        spawn Ff();// in fs;
    end
end
await 1s;

escape ret;
]],
    props_ = 'line 11 : invalid `spawn` : unexpected enclosing `finalize`',
}

Test { [[
var int ret = 0;

code/await Ff (none) -> none do
    outer.ret = outer.ret + 1;
end

pool[] Ff fs;

do
    do finalize with
        spawn Ff() in fs;
    end
end
await 1s;

escape ret;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    run = {['~>1s']=1},
}

Test { [[
var int ret = 0;

code/await Ff (var int s) -> none do
    do finalize with
        outer.ret = outer.ret + 1;
    end
    await (s)s;
    outer.ret = outer.ret + 1;
end

do
    pool[] Ff fs;

    do
        do finalize with
            spawn Ff(2) in fs;
        end
        do finalize with
            spawn Ff(1) in fs;
        end
    end
    await 1s500ms;
end

escape ret;
]],
    _opts = { ceu_features_pool='true', ceu_features_dynamic='true', ceu_features_thread='true' },
    run = {['~>5s']=3},
}

Test { [[
native _sleep;
var int ret = 0;

code/await Ff (var int s) -> none do
    do finalize with
        outer.ret = outer.ret + 1;
    end
    await async/thread (s) do
        _sleep(s);
    end
    outer.ret = outer.ret + 1;
end

do
    pool[] Ff fs;
    do
        do finalize with
            spawn Ff(3) in fs;
        end
        do finalize with
            spawn Ff(1) in fs;
        end
    end
    _sleep(2);
    await async do end
    await async do end
    await async do end
end

escape ret;
]],
    _opts = { ceu_features_pool='true', ceu_features_dynamic='true', ceu_features_thread='true' },
    run = {['~>5s']=3},
}

--<< CODE / FINALIZE / EMIT / SPAWN / THREADS

-->> CODE / TIGHT / AWAIT / MULTIMETHODS / DYNAMIC

Test { [[
data Aa with
    var int a;
end

code/tight Ff (var& Aa a, var int xxx) -> int;

data Aa.Bb with
    var int b;
end

code/tight Ff (var& Aa.Bb b, var int yyy) -> int do
    escape 0;
end

escape 0;
]],
    wrn = true,
    dcls = 'line 11 : invalid `code` declaration : unmatching prototypes (vs. /tmp/tmp.ceu:5)',
}

Test { [[
data Aa with
    var int a;
end

code/tight Ff (var& Aa a, var int xxx) -> int do
    escape 0;
end

data Aa.Bb with
    var int b;
end

code/tight Ff (var& Aa.Bb b, var int yyy) -> int do
    escape 0;
end

escape 0;
]],
    wrn = true,
    dcls = 'line 13 : invalid `code` declaration : body for "Ff" already exists',
}

Test { [[
data Ui with
    var int x;
end

code/await/dynamic Ui_go (var& Ui ui) -> none do
end

var Ui ui = val Ui(10);
await Ui_go(&ui);

escape 1;
]],
    dcls = 'line 5 : invalid `dynamic` declaration : expected dynamic parameter',
    wrn = true,
    run = 1,
}

Test { [[
data Ui with
    var int x;
end

code/await/dynamic Ui_go (var&/dynamic Ui ui) -> none do
end

var Ui ui = val Ui(10);
await Ui_go(&ui);

escape 1;
]],
    stmts = 'line 9 : invalid `await` : expected `/dynamic` or `/static` modifier',
    wrn = true,
    run = 1,
}

Test { [[
data Ui with
    var int x;
end

code/await/dynamic Ui_go (var&/dynamic Ui ui) -> none do
end

var Ui ui = val Ui(10);
await/dynamic Ui_go(&ui);

escape 1;
]],
    props_ = 'line 5 : invalid `dynamic` declaration : parameter #1 : expected `data` in hierarchy',
    wrn = true,
    run = 1,
}

Test { [[
code/tight Ff (none) -> none do
end

escape call/dynamic Ff();
]],
    dcls = 'line 4 : invalid call : unexpected `/dynamic` modifier',
}

Test { [[
data Aa with
    var int a;
end

data Aa.Bb with
    var int b;
end

escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
data Aa with
    var int a;
end

code/tight/dynamic Ff (var/dynamic Aa&& a, var int xxx) -> int do
    escape a:a + xxx;
end

data Aa.Bb with
    var int b;
end

code/tight/dynamic Ff (var/dynamic Aa.Bb&& b, var int yyy) -> int do
    escape b:b + yyy;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

escape (call Ff(&&b,22)) + (call Ff(&&a,33));
]],
    dcls = 'line 20 : invalid call : expected `/dynamic` or `/static` modifier',
}
Test { [[
data Aa with
    var int x;
end
data Aa.Bb with
    var int y;
end

code/tight/dynamic Ff (var/dynamic Aa&& a) -> int do
    escape a:x;
end

var Aa i = val Aa(1);

escape (call/dynamic Ff(&&i));
]],
    wrn = true,
    run = 1,
}
Test { [[
data Aa with
    var int a;
end
data Aa.Bb with
    var int b;
end

code/tight/dynamic Ff (var/dynamic Aa&& a, var int xxx) -> int do
    escape a:a + xxx;
end

var Aa a = val Aa(1);

code/tight Gg (var int x) -> int do
    escape x;
end

escape (call Gg(10)) + (call/dynamic Ff(&&a,33));
]],
    wrn = true,
    run = 44,
}
Test { [[
data Aa with
    var int a;
end

code/tight/dynamic Ff (var/dynamic Aa&& a, var int xxx) -> int do
    escape a:a + xxx;
end

data Aa.Bb with
    var int b;
end

code/tight/dynamic Ff (var/dynamic Aa.Bb&& b, var int yyy) -> int do
    escape b:b + yyy;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

escape (call/dynamic Ff(&&b,22)) + (call/dynamic Ff(&&a,33));
]],
    --run = 58,
    run = 59,
}
Test { [[
data Aa with
    var int a;
end

code/tight/dynamic Ff (var int xxx, var/dynamic Aa&& a) -> int do
    escape a:a + xxx;
end

data Aa.Bb with
    var int b;
end

code/tight/dynamic Ff (var int yyy, var/dynamic Aa.Bb&& b) -> int do
    escape b:b + yyy;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

escape (call/dynamic Ff(22,&&b)) + (call/dynamic Ff(33,&&a));
]],
    --run = 58,
    run = 59,
}

Test { [[
data Aa with
    var int a;
end

code/tight/dynamic Ff (var&/dynamic Aa a1, var int xxx, var&/dynamic Aa a2) -> int do
    escape a1.a + xxx + a2.a;
end

data Aa.Bb with
    var int b;
end

code/tight/dynamic Ff (var&/dynamic Aa.Bb b1, var int yyy, var&/dynamic Aa.Bb b2) -> int do
    //escape b.b + (call Ff(&b as Aa, 11)) + yyy;
    escape b1.b + yyy + b2.b;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

escape (call/dynamic Ff(&b,22,&b)) + (call/dynamic Ff(&a,33,&a));
]],
    run = 63,
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var&/dynamic Aa a, var int xxx) -> int do
    escape a.a + xxx;
end

var Aa a = val Aa(1);
var int v2 = await/dynamic Ff(&a,33);
escape v2;
]],
    --run = 58,
    props_ = 'line 5 : invalid `dynamic` declaration : parameter #1 : expected `data` in hierarchy',
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var&/dynamic Aa a, var int xxx) -> int do
    escape a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var&/dynamic Aa.Bb b, var int yyy) -> int do
    //escape b.b + (call Ff(&b as Aa, 11)) + yyy;
    escape b.b + yyy;
end

var Aa a = val Aa(1);

await Ff(&a,22);
escape 0;
]],
    stmts = 'line 20 : invalid `await` : expected `/dynamic` or `/static` modifier',
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var&/dynamic Aa a, var int xxx) -> int do
    escape a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var&/dynamic Aa.Bb b, var int yyy) -> int do
    //escape b.b + (call Ff(&b as Aa, 11)) + yyy;
    escape b.b + yyy;
end

var Aa a = val Aa(1);

spawn Ff(&a,22);
escape 0;
]],
    stmts = 'line 20 : invalid `spawn` : expected `/dynamic` or `/static` modifier',
    --stmts = 'line 20 : invalid `await` : expected `/dynamic` or `/static` modifier',
}

Test { [[
code/await Ff (none) -> none do
end
spawn Ff();
escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (var& int ret) -> none do
    ret = 1;
end
var int ret = 0;
spawn Ff(&ret);
escape ret;
]],
    run = 1,
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var& int ret, var&/dynamic Aa a, var int xxx) -> none do
    ret = ret + a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var& int ret, var&/dynamic Aa.Bb b, var int yyy) -> none do
    ret = ret + b.b + yyy;
end

var  Aa    a = val Aa(1);
var  Aa.Bb b = val Aa.Bb(2,3);
var& Aa    c = &b;

var int zzz = 0;
spawn/dynamic Ff(&zzz,&a,1);     // 1+1
spawn/dynamic Ff(&zzz,&b,2);     // 3+2
spawn/dynamic Ff(&zzz,&c,3);     // 3+3

escape zzz;
]],
    run = 13,
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var& int ret, var&/dynamic Aa a, var int xxx) -> none do
    ret = ret + a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var& int ret, var&/dynamic Aa.Bb b, var int yyy) -> none do
    ret = ret + b.b + yyy;
end

var  Aa    a = val Aa(1);
var  Aa.Bb b = val Aa.Bb(2,3);
var& Aa    c = &b;

var int ret = 0;
spawn/dynamic Ff(&ret,&a,1);     // 1+1
spawn/dynamic Ff(&ret,&b,2);     // 3+2
spawn/dynamic Ff(&ret,&c,3);     // 3+3

escape ret;
]],
    run = 13,
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var&/dynamic Aa a, var int xxx) -> int do
    escape a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var&/dynamic Aa.Bb b, var int yyy) -> int do
    //escape b.b + (call Ff(&b as Aa, 11)) + yyy;
    escape b.b + yyy;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

var int v1 = await/dynamic Ff(&b,22);
var int v2 = await/dynamic Ff(&a,33);
escape v1 + v2;
]],
    --run = 58,
    run = 59,
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var&/dynamic Aa a1, var int xxx, var&/dynamic Aa a2) -> int do
    escape a1.a + xxx + a2.a;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var&/dynamic Aa.Bb b1, var int yyy, var&/dynamic Aa.Bb b2) -> int do
    //escape b.b + (call Ff(&b as Aa, 11)) + yyy;
    escape b1.b + yyy + b2.b;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

var int v1 = await/dynamic Ff(&b,22,&b);
var int v2 = await/dynamic Ff(&a,33,&a);

escape v1 + v2;
]],
    run = 63,
}

Test { [[
data Aa;
data Aa.Bb;

code/tight/dynamic Ff (var&/dynamic Aa v1, var&/dynamic Aa v2) -> int do
    escape 1;
end
code/tight/dynamic Ff (var&/dynamic Aa.Bb v1, var&/dynamic Aa.Bb v2) -> int do
    escape 2;
end

var Aa a = val Aa();
var Aa b = val Aa.Bb();

escape call/dynamic Ff(&b, &a);
]],
    wrn = true,
    run = 1,
}

Test { [[
data Aa;
data Aa.Bb;
data Aa.Bb.Xx;
data Aa.Cc;

code/tight/dynamic Ff (var&/dynamic Aa v1, var&/dynamic Aa v2, var&/dynamic Aa v3) -> int do
    escape 1;
end
code/tight/dynamic Ff (var&/dynamic Aa.Bb v1, var&/dynamic Aa v2, var&/dynamic Aa.Bb v3) -> int do
    escape 2;
end
code/tight/dynamic Ff (var&/dynamic Aa.Bb v1, var&/dynamic Aa.Bb v2, var&/dynamic Aa.Bb v3) -> int do
    escape 4;
end
code/tight/dynamic Ff (var&/dynamic Aa.Bb v1, var&/dynamic Aa.Bb.Xx v2, var&/dynamic Aa.Bb v3) -> int do
    escape 8;
end

var Aa a = val Aa();
var Aa b = val Aa.Bb();
var Aa c = val Aa.Bb.Xx();

escape (call/dynamic Ff(&b,&a,&a)) + (call/dynamic Ff(&b,&a,&b)) +
       (call/dynamic Ff(&b,&b,&b)) + (call/dynamic Ff(&b,&c,&b));
]],
    wrn = true,
    run = 15,
}

Test { [[
data Bb with
    var int x=10;
end

code/tight Ff (var Bb b) -> int;

var int v1 = call Ff(_);
escape v1;
]],
    tight_ = 'line 5 : invalid `code` declaration : expected `/recursive` : `call` to unknown body (/tmp/tmp.ceu:7)',
}

Test { [[
data Bb with
    var int x=10;
end
data Bb.Cc with
    var int y=20;
end

var Bb.Cc c = val Bb.Cc(_,_);
escape c.x;
]],
    run = 10,
}

Test { [[
data Bb with
    var int x=10;
end
data Bb.Cc with
    var int y=20;
end

code/tight/dynamic Ff (var&/dynamic Bb b) -> int do
    escape b.x;
end

code/tight/dynamic Ff (var&/dynamic Bb.Cc c) -> int do
    escape c.x + c.y;
end

var Bb.Cc c = val Bb.Cc(_,_);
var Bb    b = val Bb(_);
var int v1 = call/dynamic Ff(&c);
var int v2 = call/dynamic Ff(&b);
escape v1 + v2;
]],
    run = 40,
}

Test { [[
data Bb with
    var int x=10;
end
data Bb.Cc with
    var int y=20;
end

code/tight/dynamic Ff (var/dynamic Bb b) -> int do
    escape b.x;
end

code/tight/dynamic Ff (var/dynamic Bb.Cc c) -> int do
    escape c.x + c.y;
end

var int v2 = call/dynamic Ff(Bb(_));
var int v1 = call/dynamic Ff(Bb.Cc(_,_));
escape v1 + v2;
]],
    dcls = 'line 17 : invalid call argument #1 : `data` copy : unmatching fields',
}
Test { [[
data Aa;
data Bb with
    var int x;
end
data Bb.Cc;

code/tight/dynamic Ff (var Bb b, var Aa a) -> none do
end

code/tight/dynamic Ff (var Bb.Cc c, var Aa a) -> none do
end
]],
    dcls = 'line 7 : invalid `dynamic` declaration : expected dynamic parameters',
}

Test { [[
data Aa;
data Bb with
    var int x;
end
data Bb.Cc;

code/tight/dynamic Ff (var&/dynamic Bb b, var/dynamic Aa a) -> none do
end

code/tight/dynamic Ff (var&/dynamic Bb.Cc c, var/dynamic Aa a) -> none do
end

escape 1;
]],
    wrn = true,
    props_ = 'line 7 : invalid `dynamic` declaration : parameter #2 : expected `data` in hierarchy',
    --dcls = 'line 7 : invalid `dynamic` declaration : parameter #2 : unexpected plain `data`',
}

Test { [[
data Aa;
data Bb with
    var int x;
end
data Bb.Cc;

code/tight/dynamic Ff (var&/dynamic Bb b, var Aa a) -> none do
end

code/tight/dynamic Ff (var&/dynamic Bb.Cc c, var Aa a) -> none do
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Aa;
data Bb with
    var int x;
end
data Bb.Cc;

code/tight/dynamic Ff (var Aa a, var&/dynamic Bb b) -> none do
end

code/tight/dynamic Ff (var Aa a, var&/dynamic Bb.Cc c) -> none do
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Aa;
data Bb with
    var int x;
end
data Bb.Cc;

code/tight/dynamic Ff (var& Aa a, var&/dynamic Bb b,
                       var Aa a2, var&/dynamic Bb b2, var Aa a3) -> none do
end

code/tight/dynamic Ff (var& Aa a, var&/dynamic Bb.Cc c,
                       var Aa a2, var&/dynamic Bb.Cc c2, var Aa a3) -> none do
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Aa;
data Bb with
    var int x;
end
data Bb.Cc;

code/tight/dynamic Ff (var&/dynamic Bb b,    var& Aa a) -> none do
end

code/tight/dynamic Ff (var&/dynamic Bb.Cc c, var& Aa a) -> none do
end

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Dd;
data Dd.Ee;

code/tight Play_New (var& Dd x) -> none;
code/tight Play_New (var& Dd x) -> none do
end
code/tight Play_New (var& Dd x) -> none;

var Dd d = _;

call Play_New(&d);

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Dd;
data Dd.Ee;

//code/tight/dynamic Play_New (var&/dynamic Dd d) -> none;
code/tight/dynamic Play_New (var&/dynamic Dd d) -> none do
end

var Dd d = _;

call/dynamic Play_New(&d);

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Dd;
data Dd.Ee;

code/tight/dynamic Play_New (var&/dynamic Dd d) -> none;
code/tight/dynamic Play_New (var&/dynamic Dd d) -> none do
end
code/tight/dynamic Play_New (var&/dynamic Dd d) -> none;

var Dd d = _;

call/dynamic Play_New(&d);

escape 1;
]],
    dcls = 'line 7 : not implemented : prototype for non-base dynamic code',
    wrn = true,
    run = 1,
}

Test { [[
data Aa;
data Aa.Bb;

code/await/dynamic Ff (var& int ret, var&/dynamic Aa v1) -> none do
    ret = ret + 15;
end

var Aa aaa = val Aa();

var int ret = 0;

pool[10] Ff ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;

escape ret;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 15,
}

Test { [[
data Aa;
data Aa.Bb;
code/await/dynamic Ff (var&/dynamic Aa v1) -> none;
var Aa a = val Aa();
pool[10] Ff ffs;
spawn/dynamic Ff(&a) in ffs;
escape 1;
]],
    _opts = { ceu_features_pool='true' },
    mems = 'line 3 : missing implementation',
    wrn = true,
    run = 15,
}

Test { [[
data Media;
data Media.Text;
do
    code/tight/dynamic Play (var&/dynamic Media m) -> none do end
    code/tight/dynamic Play (var&/dynamic Media.Text m) -> none do end
end
escape 1;
]],
    wrn = true,
    run = 1,
}
Test { [[
data Media;
data Media.Text;
do/_
    code/tight/dynamic Play (var&/dynamic Media m) -> int do escape 1; end
    code/tight/dynamic Play (var&/dynamic Media.Text m) -> int do escape 2; end
    var Media x = val Media.Text();
    escape call/dynamic Play(&x);
end
]],
    wrn = true,
    run = 2,
}
Test { [[
data Media;
data Media.Text;
code/tight/dynamic Play (var&/dynamic Media m) -> none do end
code/tight/dynamic Play (var&/dynamic Media.Text m) -> none do end
escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    wrn = true,
    run = 1,
}

Test { [[
data Aa;
data Aa.Bb;
code/await/dynamic Ff (var&/dynamic Aa v1) -> none;
var Aa a = val Aa();
pool[10] Ff ffs;
code/await/dynamic Ff (var&/dynamic Aa v1) -> none do end;
spawn/dynamic Ff(&a) in ffs;
escape 1;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 1,
}

Test { [[
data Aa;
data Aa.Bb;
data Aa.Bb.Xx;
data Aa.Cc;

code/await/dynamic Ff (var& int ret, var&/dynamic Aa v1, var&/dynamic Aa v2, var&/dynamic Aa v3) -> none;

pool[10] Ff ffs;

code/await/dynamic Ff (var& int ret, var&/dynamic Aa v1, var&/dynamic Aa v2, var&/dynamic Aa v3) -> none do
    ret = ret + 1;
end
code/await/dynamic Ff (var& int ret, var&/dynamic Aa.Bb v1, var&/dynamic Aa v2, var&/dynamic Aa.Bb v3) -> none do
    ret = ret + 2;
end
code/await/dynamic Ff (var& int ret, var&/dynamic Aa.Bb v1, var&/dynamic Aa.Bb v2, var&/dynamic Aa.Bb v3) -> none do
    ret = ret + 4;
end
code/await/dynamic Ff (var& int ret, var&/dynamic Aa.Bb v1, var&/dynamic Aa.Bb.Xx v2, var&/dynamic Aa.Bb v3) -> none do
    ret = ret + 8;
end

var Aa a = val Aa();
var Aa b = val Aa.Bb();
var Aa c = val Aa.Bb.Xx();

var int ret = 0;

spawn/dynamic Ff(&ret,&b,&a,&a) in ffs;
spawn/dynamic Ff(&ret,&b,&a,&b) in ffs;
spawn/dynamic Ff(&ret,&b,&b,&b) in ffs;
spawn/dynamic Ff(&ret,&b,&c,&b) in ffs;

escape ret;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 15,
}

Test { [[
code/tight Ff (var int x) -> none do
end
code/tight Ff (var int x) -> none do
end
escape 1;
]],
    wrn = true,
    dcls = 'line 3 : invalid `code` declaration : body for "Ff" already exists',
}

Test { [[
data Dd;
code/tight/dynamic Ff (var&/dynamic Dd d) -> none do
end
code/tight Ff (var int x) -> none do
end
escape 1;
]],
    wrn = true,
    dcls = 'line 4 : invalid `code` declaration : body for "Ff" already exists',
}

Test { [[
data Dd;
code/tight/dynamic Ff (var&/dynamic Dd d) -> none do
end
code/tight/dynamic Ff (var&/dynamic Dd d) -> none do
end
escape 1;
]],
    wrn = true,
    dcls = 'line 4 : invalid `code` declaration : body for "Ff" already exists',
}

Test { [[
data Dd;
data Ee;
code/tight/dynamic Ff (var&/dynamic Dd d) -> none do
end
code/tight/dynamic Ff (var&/dynamic Ee d) -> none do
end
escape 1;
]],
    wrn = true,
    props_ = 'line 3 : invalid `dynamic` declaration : parameter #1 : expected `data` in hierarchy',
}

Test { [[
data Dd;
data Dd.Ee;
code/tight/dynamic Ff (var&/dynamic Dd a, var&/dynamic Dd b) -> none do
end
code/tight/dynamic Ff (var&/dynamic Dd a, var&/dynamic Dd.Ee b) -> none do
end
code/tight/dynamic Ff (var&/dynamic Dd.Ee a, var&/dynamic Dd b) -> none do
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Dd;
data Dd.Ee;
code/tight/dynamic Ff (var&/dynamic Dd.Ee b) -> none do
end
code/tight/dynamic Ff (var&/dynamic Dd b) -> none do
end
escape 1;
]],
    wrn = true,
    mems = 'line 3 : invalid `code` declaration : missing base case',
}

Test { [[
data Dd;
data Dd.Ee;
code/tight/dynamic Ff (var&/dynamic Dd a, var&/dynamic Dd.Ee b) -> none do
end
code/tight/dynamic Ff (var&/dynamic Dd.Ee a, var&/dynamic Dd b) -> none do
end
escape 1;
]],
    wrn = true,
    mems = 'line 3 : invalid `code` declaration : missing base case',
}

Test { [[
data Media as nothing;
data Media.Audio as 1;
data Media.Video as 1;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Media as nothing;
data Media.Audio;
data Media.Video;

code/await/dynamic Play (var&/dynamic Media.Audio media) -> none do end
code/await/dynamic Play (var&/dynamic Media.Video media) -> none do end

var Media.Audio m = val Media.Audio();
await/dynamic Play(&m);
]],
    wrn = true,
    mems = 'line 5 : invalid `code` declaration : missing base case',
}

Test { [[
data Media as nothing;
data Media.Audio as 1;
data Media.Video as 1;

code/await/dynamic Play (var&/dynamic Media media) -> none do end
code/await/dynamic Play (var&/dynamic Media.Audio media) -> none do end
code/await/dynamic Play (var&/dynamic Media.Video media) -> none do end

var Media.Audio m = val Media.Audio();
await/dynamic Play(&m);
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
do/_
 data IData;
 data IData.Test1 with
   var int d;
 end
 code/tight/dynamic
 Ff (var&/dynamic IData mydata) -> int
 do
   escape 1;
 end
 code/tight/dynamic
 Ff (var&/dynamic IData.Test1 mydata) -> int
 do
   escape 2;
 end
 var IData.Test1 t1 = val IData.Test1 (0);
 escape call/dynamic Ff (&t1);
end
]],
    wrn = true,
    run = 2,
}
Test { [[
do/_
data IData;

 data IData.Test1 with
   var int d;
 end

 data IData.Test2 with
   var r64 f;
 end

 code/tight/dynamic
 Test (var&/dynamic IData mydata) -> int
 do
   escape 1;
 end

 code/tight/dynamic
 Test (var&/dynamic IData.Test1 mydata) -> int
 do
   escape 2;
 end

 code/tight/dynamic
 Test (var&/dynamic IData.Test2 mydata) -> int
 do
   escape 3;
 end

 var IData.Test1 t1 = val IData.Test1 (0);
 var int v1 = call/dynamic Test (&t1);

 var IData.Test2 t2 = val IData.Test2 (0);
 var int v2 = call/dynamic Test (&t2);

escape v1 + v2;
end
]],
    wrn = true,
    run = 5,
}
Test { [[
do/_
    data Media as nothing;
    data Media.Audio with
        var int a = 1;
    end
    code/tight/dynamic Play (var&/dynamic Media media) -> int do
    end
    code/tight/dynamic Play (var&/dynamic Media.Audio media) -> int do
        escape media.a;
    end
    var Media.Audio audio = val Media.Audio(_);
    var& Media m = &audio;
    var int ret = call/dynamic Play(&m);
    escape ret;
end
]],
    wrn = true,
    run = 1,
}
Test { [[
do/_
    data Media as nothing;
    data Media.Audio with
        var int a = 1;
    end
    code/await/dynamic Play (var&/dynamic Media media) -> int do
    end
    code/await/dynamic Play (var&/dynamic Media.Audio media) -> int do
        escape media.a;
    end
    var Media.Audio audio = val Media.Audio(_);
    var& Media m = &audio;
    var int ret = await/dynamic Play(&m);
    escape ret;
end
]],
    wrn = true,
    run = 1,
}
Test { [[
do/_
    native _ceu_assert, _printf;
    data Media as nothing;

    data Media.Audio with
        var int a = 1;
    end

    data Media.Video with
        var int b = 2;
    end


    code/await/dynamic Play (var&/dynamic Media media) -> int do
        _ceu_assert(0, "bug found");               // never dispatched
    end

    code/await/dynamic Play (var&/dynamic Media.Audio media) -> int do
        escape media.a;
    end

    code/await/dynamic Play (var&/dynamic Media.Video media) -> int do
        escape media.b;
    end

    var Media.Audio audio = val Media.Audio(_);

    var& Media m = &audio; // receives one of "Media.Audio" or "Media.Video"

    var int ret = await/dynamic Play(&m);
    escape ret;
end
]],
    wrn = true,
    run = 1,
}
Test { [[
native _ceu_assert, _printf;
data Media as nothing;

data Media.Audio with
    var int a = 1;
end

data Media.Video with
    var int b = 2;
end


code/await/dynamic Play (var&/dynamic Media media) -> int do
    _ceu_assert(0, "bug found");               // never dispatched
end

code/await/dynamic Play (var&/dynamic Media.Audio media) -> int do
    escape media.a;
end

code/await/dynamic Play (var&/dynamic Media.Video media) -> int do
    escape media.b;
end

var Media.Audio audio = val Media.Audio(_);

var& Media m = &audio; // receives one of "Media.Audio" or "Media.Video"

var int ret = await/dynamic Play(&m);
escape ret;
]],
    wrn = true,
    run = 1,
}
Test { [[
do/_
    data Media as nothing;

    data Media.Audio with
        var int a = 2;
    end

    data Media.Video with
        var int v = 1;
    end

    code/await/dynamic Play (var&/dynamic Media media) -> none do
        escape;             // never dispatched
    end

    code/await/dynamic Play (var&/dynamic Media.Audio media) -> none do
        await 1s;                   // plays an audio
    end

    code/await/dynamic Play (var&/dynamic Media.Video media) -> none do
        await 2s;                  // plays a video
    end
    escape 1;
end
]],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' },
    wrn = true,
    run = 1,
}

Test { [[
data IData;
data IData.Test1 with
  var int d;
end
code/tight/dynamic Ff (var&/dynamic IData mydata) -> int do
  escape 1;
end
code/tight/dynamic Ff (var&/dynamic IData.Test1 mydata) -> int;
code/tight/dynamic Ff (var&/dynamic IData.Test1 mydata) -> int do
  escape 2;
end
var IData.Test1 t1 = val IData.Test1 (0);
escape call/dynamic Ff (&t1);
]],
    dcls = 'line 8 : not implemented : prototype for non-base dynamic code',
    wrn = true,
    run = 2,
}

Test { [[
do/_
 data IData;
 data IData.Test1 with
   var int d;
 end
 code/tight/dynamic Ff (var&/dynamic IData mydata) -> int do
   escape 1;
 end
 //code/tight/dynamic Ff (var&/dynamic IData.Test1 mydata) -> int;
 code/tight/dynamic
 Ff (var&/dynamic IData.Test1 mydata) -> int
 do
   escape 2;
 end
 var IData.Test1 t1 = val IData.Test1 (0);
 escape call/dynamic Ff (&t1);
end
]],
    wrn = true,
    run = 2,
}

Test { [[
data Dd;

code/tight Ff (none) -> Dd do
    var Dd d = val Dd();
    escape d;
end

var Dd d = call Ff();

escape 1;
]],
    run = 1,
}

Test { [[
data Dd;
data Dd.Ee;

code/tight Ff (none) -> Dd do
    var Dd d = val Dd.Ee();
    escape d;
end

var Dd d = call Ff();

escape (d is Dd.Ee) as int;
]],
    run = 1,
}

Test { [[
data Dd;
data Dd.Ee;

code/await Ff (none) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd.Ee();
    d = &d_;
    await FOREVER;
end

var&? Ff f = spawn Ff();

escape (f!.d is Dd.Ee) as int;
]],
    run = 1,
}

Test { [[
data Xx;
code/await/dynamic Ff (var/dynamic Xx x1) -> (var& Xx x2) -> none;
escape 1;
]],
    wrn = true,
    props_ = 'line 2 : invalid `dynamic` declaration : parameter #1 : expected `data` in hierarchy',
}

Test { [[
data Dd with
    var int x;
end
data Dd.Ee;

var Dd d = val Dd.Ee(10);

escape ((d is Dd.Ee) as int) + d.x;
]],
    wrn = true,
    run = 11,
}

Test { [[
data Xx;
data Xx.Yy;
data Dd;

code/await/dynamic Ff (var/dynamic Xx x) -> (var& Dd d) -> NEVER;

code/await/dynamic Ff (var/dynamic Xx x) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd();
    d = &d_;
    await FOREVER;
end

var&? Ff f = spawn/dynamic Ff(Xx.Yy());

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Xx;
data Xx.Yy;
data Dd;

code/await Ff (var Xx x) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd();
    d = &d_;
    await FOREVER;
end

spawn Ff(Xx.Yy());

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Xx;
data Xx.Yy;
data Dd;

//code/await/dynamic Ff (var/dynamic Xx x) -> (var& Dd d) -> NEVER;

code/await/dynamic Ff (var/dynamic Xx x) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd();
    d = &d_;
    await FOREVER;
end

spawn/dynamic Ff(Xx.Yy());

escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
data Xx with
    var int v = 10;
end
data Xx.Yy;

data Dd with
    var Xx x;
end
data Dd.Ee;

native _ceu_assert;
code/await/dynamic Ff (var/dynamic Xx x) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd(x);
    d = &d_;
    _ceu_assert(0, "bug found");
    await FOREVER;
end

code/await/dynamic Ff (var/dynamic Xx.Yy x) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd.Ee(x);
    d = &d_;
    await FOREVER;
end

var&? Ff f = spawn/dynamic Ff(Xx.Yy(20));

escape ((f!.d is Dd.Ee) as int);
]],
    wrn = true,
    run = 1,
}
Test { [[
data Xx with
    var int v = 10;
end
data Xx.Yy;

data Dd with
    var Xx x;
end
data Dd.Ee;

native _ceu_assert;
code/await/dynamic Ff (var/dynamic Xx x) -> (var& Dd d1) -> NEVER do
    var Dd d_ = val Dd(x);
    d1 = &d_;
    _ceu_assert(0, "bug found");
    await FOREVER;
end

code/await/dynamic Ff (var/dynamic Xx.Yy x) -> (var& Dd d2) -> NEVER do
    var Dd d_ = val Dd.Ee(x);
    d2 = &d_;
    await FOREVER;
end

var&? Ff f = spawn/dynamic Ff(Xx.Yy(20));

escape ((f!.d1 is Dd.Ee) as int);
]],
    wrn = true,
    run = 1,
}
Test { [[
data Xx with
    var int v = 10;
end
data Xx.Yy;

data Dd with
    var Xx x;
end
data Dd.Ee;

native _ceu_assert;
code/await/dynamic Ff (var/dynamic Xx x) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd(x);
    d = &d_;
    _ceu_assert(0, "bug found");
    await FOREVER;
end

code/await Gg (var Xx.Yy x) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd.Ee(x);
    d = &d_;
    await FOREVER;
end

var&? Gg g = spawn Gg(Xx.Yy(20));

escape ((g!.d is Dd.Ee) as int);
]],
    wrn = true,
    run = 1,
}

Test { [[
data Xx with
    var int v = 10;
end
data Xx.Yy;

data Dd with
    var Xx x;
end
data Dd.Ee;

native _ceu_assert;
code/await/dynamic Ff (var/dynamic Xx x) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd(x);
    d = &d_;
    _ceu_assert(0, "bug found");
    await FOREVER;
end

code/await/dynamic Ff (var/dynamic Xx.Yy x) -> (var& Dd d) -> NEVER do
    var Dd d_ = val Dd.Ee(x);
    d = &d_;
    await FOREVER;
end

var&? Ff f = spawn/dynamic Ff(Xx.Yy(20));

escape ((f!.d is Dd.Ee) as int) + f!.d.x.v;
]],
    wrn = true,
    run = 21,
}

Test { [[
data Dd with
    var int x = 10;
end

data Aa;
data Aa.Bb;

code/await/dynamic Ff (var& int ret, var&/dynamic Aa v1) -> (var Dd d) -> NEVER do
    d = _;
    await FOREVER;
end

var Aa aaa = val Aa();

var int ret = 0;

pool[10] Ff ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;

var&? Ff f;
loop f in ffs do
    ret = ret + f!.d.x;
end

escape ret;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 20,
}

Test { [[
data Dd with
    var int x = 10;
end

data Aa;
data Aa.Bb;

code/await/dynamic Ff (var& int ret, var&/dynamic Aa v1) -> (var& Dd d) -> NEVER do
    var Dd d_ = _;
    d = &d_;
    await FOREVER;
end

var Aa aaa = val Aa();

var int ret = 0;

pool[10] Ff ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;

var&? Ff f;
loop f in ffs do
    ret = ret + f!.d.x;
end

escape ret;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 20,
}

Test { [[
data Dd with
    var int x = 10;
end

data Aa;
data Aa.Bb;

code/await/dynamic Ff (var& int ret, var&/dynamic Aa v1) -> (var& Dd d) -> none do
    var Dd d_ = _;
    d = &d_;
end

var Aa aaa = val Aa();

var int ret = 0;

pool[10] Ff ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;

var&? Ff f;
loop f in ffs do
    ret = ret + f!.d.x;
end

escape ret+1;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 1,
}

Test { [[
data Dd with
    var int x = 10;
end

data Aa;
data Aa.Bb;

code/await/dynamic Ff (var& int ret, var&/dynamic Aa v1) -> (var&? Dd d) -> NEVER do
    var Dd d_ = _;
    d = &d_;
    await FOREVER;
end

var Aa aaa = val Aa();

var int ret = 0;

pool[10] Ff ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;

event none e;
var&? Ff f;
loop f in ffs do
    ret = ret + f!.d!.x;
    emit e;
end

escape ret+1;
]],
    _opts = { ceu_features_pool='true' },
    wrn = true,
    run = 21,
}

Test { [[
data Dd with
    var int x = 10;
end

data Aa;
data Aa.Bb;

code/await/dynamic Ff (var& int ret, var&/dynamic Aa v1) -> (var&? Dd d, event& none e) -> none do
    var Dd d_ = _;
    d = &d_;
    event none e_;
    e = &e_;
    await e_;
end

var Aa aaa = val Aa();

var int ret = 0;

pool[10] Ff ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;
spawn/dynamic Ff(&ret,&aaa) in ffs;

var&? Ff f;
loop f in ffs do
    ret = ret + f!.d!.x;
    ret = ret + (f!.d? as int);
    emit f!.e;
    ret = ret + (f!.d? as int);
end

escape ret+1;
]],
    wrn = true,
    --run = 23,
    run = '29] -> runtime error: value is not set',
    _opts = { ceu_features_pool='true', ceu_features_trace='true' },
}

Test { [[
data Xx;
data Xx.Yy;
code/await Gg (var/dynamic Xx.Yy x) -> (none) -> NEVER do
    await FOREVER;
end
escape 1;
]],
    dcls = 'line 3 : invalid `dynamic` modifier : expected enclosing `code/dynamic`',
    run = 1,
}

Test { [[
data Direction as nothing;
//data Direction as 0;
data Direction.Right as 10;
data Direction.Left as 20;

code/tight/dynamic Ff (var/dynamic Direction dir) -> int do
    escape 1;
end

code/tight/dynamic Ff (var/dynamic Direction.Right dir) -> int do
    escape 10;
end

code/tight/dynamic Ff (var/dynamic Direction.Left dir) -> int do
    escape 100;
end

var Direction.Right x1 = val Direction.Right();
var Direction y1 = val Direction.Left();
var Direction y2 = val Direction();

escape (call/dynamic Ff(x1)) + (call/dynamic Ff(y1)) + (call/dynamic Ff(y2));
]],
    wrn = true,
    stmts = 'line 20 : invalid constructor : cannot instantiate `data` "Direction"',
}

Test { [[
//data Direction as nothing;
data Direction as 0;
data Direction.Right as 10;
data Direction.Left as 20;

code/tight/dynamic Ff (var/dynamic Direction dir) -> int do
    escape 1;
end

code/tight/dynamic Ff (var/dynamic Direction.Right dir) -> int do
    escape 10;
end

code/tight/dynamic Ff (var/dynamic Direction.Left dir) -> int do
    escape 100;
end

var Direction.Right x1 = val Direction.Right();
var Direction y1 = val Direction.Left();
var Direction y2 = val Direction();

escape (call/dynamic Ff(x1)) + (call/dynamic Ff(y1)) + (call/dynamic Ff(y2));
]],
    wrn = true,
    run = 111,
}

Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var&/dynamic Aa a, var int xxx) -> int do
    escape a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var&/dynamic Aa.Bb b, var int yyy) -> int do
    par/or do with with end
    //escape b.b + (call Ff(&b as Aa, 11)) + yyy;
    escape b.b + yyy;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

var int v1 = await/dynamic Ff(&b,22);
var int v2 = await/dynamic Ff(&a,33);
escape v1 + v2;
]],
    --run = 58,
    run = 59,
}
Test { [[
data Aa with
    var int a;
end

code/await/dynamic Ff (var&/dynamic Aa a, var int xxx) -> int do
    par/or do with with end
    escape a.a + xxx;
end

data Aa.Bb with
    var int b;
end

code/await/dynamic Ff (var&/dynamic Aa.Bb b, var int yyy) -> int do
    //escape b.b + (call Ff(&b as Aa, 11)) + yyy;
    escape b.b + yyy;
end

var Aa    a = val Aa(1);
var Aa.Bb b = val Aa.Bb(2,3);

var int v1 = await/dynamic Ff(&b,22);
var int v2 = await/dynamic Ff(&a,33);
escape v1 + v2;
]],
    --run = 58,
    run = 59,
}

Test { [[
data My_Data;
data My_Data.Aa with
  var int x;
end

code/await/dynamic Code_A (var&/dynamic My_Data ddd) -> none do
  //var int x;
end

code/await/dynamic Code_A (var&/dynamic My_Data.Aa ddd) -> none do
  var int x = ddd.x; //it works if we remove this line
    par/or do with with with end
end

var My_Data.Aa a = val My_Data.Aa(10);

pool[] Code_A p;
spawn/dynamic Code_A (&a) in p;

escape 1;
]],
    _opts = { ceu_features_dynamic='true', ceu_features_pool='true' },
    wrn = true,
    run = 1,
}

--<< CODE / TIGHT / AWAIT / MULTIMETHODS / DYNAMIC

-->>> ASYNCS / ISR / ATOMIC

PRE_ISR = [[
native/pre do
    ##define ceu_out_isr_on()
    ##define ceu_out_isr_off()
    int V;
    none ceu_sys_isr_attach (none* f, int v) {
        V = V + v;
    }
    none ceu_sys_isr_detach (none* f, int v) {
        V = V * v;
    }
    ##define ceu_out_isr_attach ceu_sys_isr_attach
    ##define ceu_out_isr_detach ceu_sys_isr_detach
end






]]

Test { [[
atomic do
    await 1s;
end
escape 1;
]],
    props = 'line 2 : not permitted inside `atomic`',
    _opts = { ceu_features_isr='true' },
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
    props = 'line 2 : not permitted inside `atomic`',
    _opts = { ceu_features_isr='true' },
}

Test { [[
output none O;
atomic do
    emit O;
end
escape 1;
]],
    props = 'line 3 : not permitted inside `atomic`',
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
native/pos do
    none f (none){}
end
atomic do
native _f;
    _f();
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
code/tight Fx (none)->none do end
atomic do
    call Fx();
end
escape 1;
]],
    run = 1,
    --props = 'line 4 : not permitted inside `atomic`',
    _opts = { ceu_features_isr='true' },
}

Test { [[
atomic do
    loop do
    end
end
escape 1;
]],
    props = 'line 3 : not permitted inside `atomic`',
    wrn = true,
    _opts = { ceu_features_isr='true' },
}

Test { [[
loop do
    atomic do
        break;
    end
end
escape 1;
]],
    props = 'line 3 : not permitted inside `atomic`',
    _opts = { ceu_features_isr='true' },
}

Test { [[
par/or do
    async/isr [20] do
    end
with
end
escape 1;
]],
    parser = 'line 1 : after `do` : expected statement',
    --parser = 'line 1 : after `do` : expected `nothing` or `var` or `vector`',
    --adj = 'line 2 : `async/isr` must be followed by `await FOREVER`',
    _opts = { ceu_features_isr='true' },
}

Test { [[
par/or do
    spawn async/isr [20] do
    end
    await FOREVER;
with
end
escape 1;
]],
    run = 1,
    --cc = 'error: implicit declaration of function ‘ceu_out_isr_attach’',
    _opts = { ceu_features_isr='true' },
}

Test { [[
native/pre do
    ##define ceu_callback_env(cmd,evt,params) CB(cmd,evt,params)
    int CB (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled;
        is_handled = 0;
        return is_handled;
    }
end
par/or do
    spawn async/isr [1] do
    end
    await FOREVER;
with
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_isr='true' },
}

Test { [[
native/pre do
    int V = 1;
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled = 1;
        int* args = (int*) p2.ptr;
        switch (cmd) {
            case CEU_CALLBACK_ISR_ATTACH:
                V = V + args[0] + args[1];
                break;
            case CEU_CALLBACK_ISR_DETACH:
                V = V * args[0] - args[1];
                break;
            default:
                is_handled = 0;
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }
par/or do
do
    spawn async/isr [3,4] do
    end
    await FOREVER;
end             // TODO: forcing finalize out_isr(null)
with
end
native _V;
escape _V;
]],
    run = 20,
    _opts = { ceu_features_isr='true' },
}

Test { [[
native/pre do
    int V = 1;
    int CB_F (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled = 1;
        int* args = (int*) p2.ptr;
        switch (cmd) {
            case CEU_CALLBACK_ISR_ATTACH:
                V = V + args[0];
                break;
            case CEU_CALLBACK_ISR_DETACH:
                V = V * args[0];
                break;
            default:
                is_handled = 0;
        }
        return is_handled;
    }
    tceu_callback CB = { &CB_F, NULL };
end
{ ceu_callback_register(&CB); }
par/or do
    do
        spawn async/isr [3] do
        end
        await FOREVER;
    end             // TODO: forcing finalize out_isr(null)
with
end
native _V;
escape _V;
]],
    run = 12,
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
var[10] int v = [1];
v[0] = 2;
par/or do
    spawn async/isr [20] do
        outer.v[0] = 1;
    end
    await FOREVER;
with
end
escape v[0];
]],
    run = 2,
    --isr = 'line 2 : access to "v" must be atomic',
    _opts = { ceu_features_isr='true' },
}

Test { [[
var[10] int v;
atomic do
    v[0] = 2;
end
par/or do
    spawn async/isr [20] do
        outer.v[0] = 1;
    end
    await FOREVER;
with
end
atomic do
    escape v[0];
end
]],
    props = 'line 13 : not permitted inside `atomic`',
    _opts = { ceu_features_isr='true' },
}

Test { [[
native/pre do
    int V = 1;
    ##define ceu_callback_env(cmd,evt,params) CB(cmd,evt,params)
    int CB (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled = 1;
        int* args = (int*) p2.ptr;
        switch (cmd) {
            case CEU_CALLBACK_ISR_ATTACH:
                V = V + args[0];
                break;
            case CEU_CALLBACK_ISR_DETACH:
                V = V * args[0];
                break;
            default:
                is_handled = 0;
        }
        return is_handled;
    }
end
var[10] int v = [];
atomic do
    v = v .. [2];
end
par do
    spawn async/isr [20] do
        outer.v[0] = 1;
    end
    await FOREVER;
with
    var int ret;
    atomic do
        ret = v[0];
    end
    escape ret;
end
]],
    _ana = {acc=1},
    run = 2,
    _opts = { ceu_features_isr='true' },
}

Test { [[
spawn async/isr [20] do
    atomic do
native _f;
        _f();
    end
end
await FOREVER;
]],
    props = 'line 2 : not permitted inside `async/isr`',
    _opts = { ceu_features_isr='true' },
}

Test { [[
var int x = 0;

atomic do
    x = 1;
end
par/or do
    spawn async/isr [20] do
        x = 0;
    end
    await FOREVER;
with
end
escape x;
]],
    dcls = 'line 8 : internal identifier "x" is not declared',
    _opts = { ceu_features_isr='true' },
}

Test { [[
native/pre do
    int V = 1;
    ##define ceu_callback_env(cmd,evt,params) CB(cmd,evt,params)
    int CB (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled = 1;
        int* args = (int*) p2.ptr;
        switch (cmd) {
            case CEU_CALLBACK_ISR_ATTACH:
                V = V + args[0];
                break;
            case CEU_CALLBACK_ISR_DETACH:
                V = V * args[0];
                break;
            default:
                is_handled = 0;
        }
        return is_handled;
    }
end

var int x = 0;

atomic do
    x = 1;
end
par/or do
    spawn async/isr [20] do
        outer.x = 0;
    end
    await FOREVER;
with
end
escape x;
]],
    run = 1,
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
var int v = 2;
par/or do
    spawn async/isr[20] do
        outer.v = 1;
    end
    await FOREVER;
with
end
escape v;
]],
    run = 2,
    --isr = 'line 1 : access to "v" must be atomic',
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
var int&& v = null;
    spawn async/isr[20] do
        *outer.v = 1;
    end
    await FOREVER;
]],
    ptrs = 'line 22 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:21)',
    --isr = 'line 4 : pointer access breaks the static check for `atomic` sections',
    --run = 1,
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
var int&& v = null;
par/or do
    spawn async/isr[20] do
        *outer.v = 1;
    end
    await FOREVER;
with
end
escape 1;
]],
    ptrs = 'line 23 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:22)',
    --inits = 'line 22 : invalid pointer access : crossed yielding statement (/tmp/tmp.ceu:21)',
    --inits = 'line 23 : invalid pointer access : crossed `par/or` (/tmp/tmp.ceu:22)',
    --isr = 'line 4 : pointer access breaks the static check for `atomic` sections',
    --run = 1,
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
code/tight Fx (none)->int do
    escape 2;
end
var int v = call Fx();
par/or do
    spawn async/isr [20] do
        call Fx();
    end
    await FOREVER;
with
end
escape v;
]],
    --dcls = 'line 25 : abstraction inside `async` : not implemented',
    --isr = 'line 7 : call breaks the static check for `atomic` sections',
    run = 2,
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
native/pos do
    int f (none) { return 2; }
end
native _f;
var int v = _f();
par/or do
    spawn async/isr [20] do
        _f();
    end
    await FOREVER;
with
end
escape v;
]],
    run = 2,
    --wrn = true,
    --isr = 'line 1 : access to "_f" must be atomic',
    _opts = { ceu_features_isr='true' },
}

Test { [[
native/pure _f;
native/pre do
    int f (none) {
        return 2;
    }
end

var int v = _f();
par/or do
    spawn async/isr [20] do
        _f();
    end
    await FOREVER;
with
end
escape v;
]],
    run = 2,
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
var int v;
v = 2;
par/or do
    spawn async/isr [20] do
        outer.v = 1;
    end
    await FOREVER;
with
end
escape v;
]],
    --isr = 'line 2 : access to "v" must be atomic',
    run = 2,
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
var int v;
atomic do
    v = 2;
end
par/or do
    spawn async/isr [20] do
        outer.v = 1;
    end
    await FOREVER;
with
end
escape v;
]],
    run = 2,
    _opts = { ceu_features_isr='true' },
}

Test { [[
var int v;
atomic do
    v = 2;
end
par do
    spawn async/isr [20] do
        outer.v = 1;
        outer.v = 1;
    end
    await FOREVER;
with
    var int ret;
    atomic do
        ret = v;
    end
    escape ret;
end
]],
    _ana = {acc=2},
    run = 2,
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
var int v;
atomic do
    v = 2;
end
par/or do
    spawn async/isr [20] do
        outer.v = 1;
    end
    await FOREVER;
with
end
escape v;
]],
    --isr = 'line 12 : access to "v" must be atomic',
    props = 'line 27 : not permitted inside `async/isr`',
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
var int v;
var int&& p;
atomic do
    v = 2;
    p = &&v;
end
par/or do
    spawn async/isr [20] do
        outer.v = 1;
    end
    await FOREVER;
with
end
escape 1;
]],
    --isr = 'line 5 : reference access breaks the static check for `atomic` sections',
    run = 1,
    _opts = { ceu_features_isr='true' },
}

Test { [[
var[10] int v;
var int&& p;
atomic do
    p = &&v[0];
end
par/or do
    spawn async/isr [20] do
        //this.v[1] = 1;
    end
    await FOREVER;
with
end
escape 1;
]],
    run = 1,
    --dcls = 'line 4 : invalid operand to `&&` : unexpected context for vector "v"',
    --env = 'line 4 : types mismatch (`int&&` <= `int[]&&`)',
    --env = 'line 4 : invalid operand to unary "&&"',
    _opts = { ceu_features_isr='true' },
}

Test { [[
par/or do
    spawn async/isr [1] do
        emit A;
    end
    await FOREVER;
with
end
escape 1;
]],
    dcls = 'line 3 : external identifier "A" is not declared',
    _opts = { ceu_features_isr='true' },
}

Test { [[
input int A;
par/or do
    spawn async/isr [] do
        emit A;
    end
    await FOREVER;
with
end
escape 1;
]],
    --adj = 'line 3 : missing ISR identifier',
    parser = 'line 3 : after `[` : expected expression',
    _opts = { ceu_features_isr='true' },
}

Test { [[
input int A;
par/or do
    spawn async/isr [1] do
        emit A;
    end
    await FOREVER;
with
end
escape 1;
]],
    stmts = 'line 4 : invalid `emit` : types mismatch : "(int)" <= "()"',
    --env = ' line 4 : arity mismatch',
    _opts = { ceu_features_isr='true' },
}

Test { [[
input int A;
par/or do
    spawn async/isr [1] do
        var int x = 111;
        emit A(1);
        x = 222;
    end
    await FOREVER;
with
end
escape 1;
]],
    run = 1,
    _opts = { ceu_features_isr='true' },
}

Test { [[
native/pre do
    int V = 0;
    int CB (int cmd, tceu_callback_val p1, tceu_callback_val p2) {
        int is_handled = 1;
        int* args = (int*) p2.ptr;
        switch (cmd) {
            case CEU_CALLBACK_ISR_ATTACH:
                V = V + args[0];
                break;
            case CEU_CALLBACK_ISR_DETACH:
                V = V - args[0];
                break;
            default:
                is_handled = 0;
        }
        return is_handled;
    }
    tceu_callback CB_ = { &CB, NULL };
end
{ ceu_callback_register(&CB_); }
native _ceu_assert;
native _V;
par/or do
    _ceu_assert(_V==0, "bug found");
    spawn async/isr [1] do
    end
    await FOREVER;
with
    _ceu_assert(_V==1, "bug found");
    await 1s;
    _ceu_assert(_V==1, "bug found");
end             // TODO: forcing finalize out_isr(null)
_ceu_assert(_V==0, "bug found");
escape _V+1;
]],
    run = { ['~>1s']=1 },
    _opts = { ceu_features_isr='true' },
}

Test { [[
native _digitalRead, _digitalWrite;
input int PIN02;
par/or do
    spawn async/isr [1] do
        emit PIN02(_digitalRead(2));
    end
    await FOREVER;
with
    _digitalWrite(13, 1);
end
escape 1;
]],
    --_ana = {acc=1},
    todo = 'acc',
    acc = 'line 8 : access to symbol "_digitalWrite" must be atomic (vs symbol `_digitalRead` (/tmp/tmp.ceu:4))',
    run = 1,
    _opts = { ceu_features_isr='true' },
}

Test { [[
input int PIN02;
native _digitalWrite;
par/or do
    var int i = 0;
    spawn async/isr [1] do
        emit PIN02(i);
    end
    await FOREVER;
with
    _digitalWrite(13, 1);
end
escape 1;
]],
    dcls = 'line 6 : internal identifier "i" is not declared',
    _opts = { ceu_features_isr='true' },
}

Test { [[
native _digitalWrite;
input int PIN02;
par/or do
    var int i = 0;
    spawn async/isr [1] do
        emit PIN02(outer.i);
    end
    await FOREVER;
with
    _digitalWrite(13, 1);
end
escape 1;
]],
    cc = '10:1: error: implicit declaration of function ‘digitalWrite’',
    _opts = { ceu_features_isr='true' },
}

Test { [[
var int i = 0;
par/or do
    spawn async/isr [1] do
        outer.i = 2;
    end
    await FOREVER;
with
    i = 1;
end
escape 1;
]],
    todo = 'acc',
    acc = 'line 9 : access to symbol "i" must be atomic (vs variable/event `i` (/tmp/tmp.ceu:5))',
    _opts = { ceu_features_isr='true' },
}

Test { [[
input int PIN02;
var int i = 0;
par/or do
    spawn async/isr [1] do
        outer.i = 2;
    end
    await FOREVER;
with
    atomic do
        i = 1;
    end
end
escape 1;
]],
    wrn = true,
    _ana = {acc=1},
    run = 1,
    --cc = '#error "Missing definition for macro',
    _opts = { ceu_features_isr='true' },
}

Test { PRE_ISR..[[
code/tight Fx (none)->int do
    escape 2;
end
var int v = call Fx();
par/or do
    spawn async/isr[20] do
        call Fx();
    end
    await FOREVER;
with
end
escape v;
]],
    --wrn = true,
    --isr = 'line 4 : access to "Fx" must be atomic',
    run = 2,
    _opts = { ceu_features_isr='true' },
    --dcls = 'line 25 : abstraction inside `async` : not implemented',
}

Test { [[
native _CEU_APP;
spawn async/isr [1] do
end
escape _CEU_APP.root.__mem.trails_n;
]],
    _opts = { ceu_features_isr='true' },
    run = 3,
}
Test { [[
native _CEU_APP;
spawn async/isr [1] do
end
spawn do
end
escape _CEU_APP.root.__mem.trails_n;
]],
    _opts = { ceu_features_isr='true' },
    run = 5,
}

Test { [[
spawn async/isr [0] do
    emit 1s;
end
escape 1;
]],
    _opts = { ceu_features_isr='true' },
    run = 1,
}

Test { [[
native _X, _V, _U, _fff;
native/pre do
    ##define X 1
end
native/pos do
    ##define fff(x) 1
    ##ifdef CEU_ISR__X
        int V = 1;
    ##else
        int V = 0;
    ##endif
    ##ifdef CEU_ISR__fff__lpar__0__rpar__
        int U = 1;
    ##else
        int U = 0;
    ##endif

end

spawn async/isr [_X] do
    emit 1s;
end
spawn async/isr [_fff(0)] do
    emit 1s;
end
escape _V+_U;
]],
    _opts = { ceu_features_isr='true' },
    run = 2,
}

Test { [[
code/await Ff (none) -> none do
    spawn async/isr [0] do
        var int x = 10;
    end
end
escape 1;
]],
    wrn = true,
    _opts = { ceu_features_isr='true' },
    run = 1,
}

Test { [[
code/await Ff (var int x) -> none do
    var int y = 0;
    spawn async/isr [0] do
        var int z = outer.x + outer.y;
    end
end
escape 1;
]],
    _opts = { ceu_features_isr='true' },
    wrn = true,
    run = 1,
}

--<<< ASYNCS / ISR / ATOMIC

-->>> OUTER

Test { [[
var int x;
code/tight Ff (none)->none do
end
x = 1;
escape x;
]],
    wrn = true,
    --inits = 'line 1 : uninitialized variable "x" : reached end of `code` (/tmp/tmp.ceu:2)',
    --inits = 'line 1 : uninitialized variable "x" : reached yielding statement (/tmp/tmp.ceu:2)',
    run = 1,
}

Test { [[
var int x = 0;
code/tight Ff (none)->none do
    outer.y = 1;
end
var int y = 10;
call Ff();
escape x;
]],
    dcls = 'line 3 : internal identifier "y" is not declared',
}

Test { [[
var int ret = 0;
do
    var int x = 0;
    code/tight Ff (none)->none do
        outer.x = 1;
    end
    call Ff();
    ret = x;
end
call Ff();
escape ret;
]],
    dcls = 'line 10 : abstraction "Ff" is not declared',
}

Test { [[
var int x = 0;
code/tight Ff (none)->none do
    code/tight Gg (none)->none do end
    outer.x = 1;
end
call Ff();
escape x;
]],
    wrn = true,
    --dcls = 'line 3 : invalid `code` declaration : nesting is not allowed',
    run = 1,
}
Test { [[
var int x = 0;
data Dd with
    code/tight Ff (none)->none do
        outer.x = 1;
    end
end
call Ff();
escape x;
]],
    parser = 'line 2 : after `with` : expected `var` or `pool` or `event`',
}
Test { [[
var int x = 0;
data Dd with
    data Ee;
end
call Ff();
escape x;
]],
    parser = 'line 2 : after `with` : expected `var` or `pool` or `event`',
}

Test { [[
var int x = 0;
code/tight Ff (none)->none do
    outer.x = 1;
end
call Ff();
escape x;
]],
    run = 1,
}

Test { [[
var int ret = 0;
do
    var int x = 0;
    code/tight Ff (none)->none do
        outer.x = 1;
    end
    call Ff();
    ret = x;
end
escape ret;
]],
    run = 1,
}

Test { [[
native _int, _f;
var& _int ren;
_f(&&outer.ren);
escape 0;
]],
    dcls = 'line 3 : invalid `outer`',
}

Test { [[
code/await Ff (none) -> int do
    var int xxx = 10;
    code/await Gg (none) -> int do
        escape xxx;
    end
    var int yyy = await Gg();
    escape yyy;
end
var int zzz = await Ff();
escape zzz;
]],
    dcls = 'line 4 : internal identifier "xxx" is not declared',
}

Test { [[
code/await Ff (none) -> int do
    var int xxx = 10;
    code/await Gg (none) -> int do
        escape outer.xxx;
    end
    var int yyy = await Gg();
    escape yyy;
end
var int zzz = await Ff();
escape zzz;
]],
    run = 10,
}

Test { [[
code/await Ff (none) -> int do
    var int xxx = 10;
    code/await Gg (none) -> int do
        var int aaa = 10;
        code/tight Hh (none) -> int do
            escape outer.xxx + outer.aaa;
        end
        escape call Hh();
    end
    var int yyy = await Gg();
    escape yyy;
end
var int zzz = await Ff();
escape zzz;
]],
    run = 20,
}

Test { [[
code/tight Ff (var int xxx) -> int do
    var int b = 0;
    var int yyy = xxx;
    code/tight Get (none) -> int do
        escape outer.yyy + outer.xxx;
    end
    escape b + call Get();
end
escape call Ff(10);
]],
    run = 20,
}

Test { [[
code/tight Ff (var int xxx) -> int do
    var int b = 0;
    var int yyy = xxx;
    code/tight Get (none) -> int do
        escape outer.yyy + outer.xxx;
    end
    escape b + call Get();
end
escape call Ff(10);
]],
    run = 20,
}

Test { [[
var int x = 10;
code/tight Gg (none) -> int do
    escape outer.x;
end
escape call Gg();
]],
    run = 10,
}
Test { [[
code/tight Ff (none) -> int do
    var int x = 10;
    code/tight Gg (none) -> int do
        escape outer.x;
    end
    escape call Gg();
end
escape call Ff();
]],
    run = 10,
}
Test { [[
code/tight Ff (none) -> int do
    var int x = 10;
    code/tight Gg (none) -> int do
        escape outer.x;
    end
    code/tight Hh (none) -> int do
        escape call Gg();
    end
    escape call Hh();
end
escape call Ff();
]],
    run = 10,
}
Test { [[
code/tight Ff (none) -> int do
    var int x = 10;
    code/tight Gg (none) -> int do
        escape outer.x;
    end
    code/tight Hh (none) -> int do
        code/tight Ii (none) -> int do
            escape call Gg();
        end
        escape call Ii();
    end
    escape call Hh();
end
escape call Ff();
]],
    run = 10,
}
Test { [[
    var int x = 10;
    code/tight Gg (none) -> int do
        escape outer.x;
    end
    code/tight Hh (none) -> int do
        code/tight Ii (none) -> int do
            escape call Gg();
        end
        escape call Ii();
    end
    escape call Hh();
]],
    run = 10,
}
Test { [[
code/await Ff (none) -> int do
    var int x = 10;
    code/await Gg (none) -> int do
        escape outer.x;
    end
    code/await Hh (none) -> int do
        code/await Ii (none) -> int do
            var int a = await Gg();
            escape a;
        end
        var int b = await Ii();
        escape b;
    end
    var int c = await Hh();
    escape c;
end
var int d = await Ff();
escape d;
]],
    run = 10,
}
Test { [[
    var int x = 10;
    code/await Gg (none) -> int do
        escape outer.x;
    end
    code/await Hh (none) -> int do
        code/await Ii (none) -> int do
            var int c = await Gg();
            escape c;
        end
        var int d = await Ii();
        escape d;
    end
    var int e = await Hh();
    escape e;
]],
    run = 10,
}

Test { [[
code/tight Pingus (none) -> int do
    var int x = 10;
    code/tight GetVelocity (none) -> int do
        escape outer.x;
    end
    escape call GetVelocity();
end
escape call Pingus();
]],
    run = 10,
}
Test { [[
code/tight Pingus (none) -> int do
    var int x = 10;
    code/tight GetVelocity (none) -> int do
        escape outer.x;
    end
    code/tight LinearMover (none) -> int do
        escape call GetVelocity();
    end
    code/tight Faller (none) -> int do
        escape call LinearMover();
    end
    escape call Faller();
end
escape call Pingus();
]],
    run = 10,
}
Test { [[
code/await Pingus (none) -> int do
    var int xxx = 10;
    code/await GetVelocity (none) -> int do
        escape outer.xxx;
    end
    code/await LinearMover (none) -> int do
        var int x = await GetVelocity();
        escape x;
    end
    code/await Faller (none) -> int do
        var int x = await LinearMover();
        escape x;
    end
    var int x = await Faller();
    escape x;
end
var int x = await Pingus();
escape x;
]],
    run = 10,
}

Test { [[
code/await Ff (var int x) -> NEVER do
    code/tight Get_X (none) -> int do
        escape outer.x;
    end
    await FOREVER;
end

pool[] Ff fs;
spawn Ff(1) in fs;
spawn Ff(2) in fs;

var int ret = 0;

var&? Ff f;
loop f in fs do
    ret = ret + (call f!.Get_X());
end

escape ret;
]],
    _opts = { ceu_features_pool='true', ceu_features_dynamic='true' },
    wrn = true,     -- TODO
    run = 3,
}

Test { [[
code/await Ff (var int x) -> NEVER do
    code/await Get_X (none) -> int do
        escape outer.x;
    end
    await FOREVER;
end

pool[] Ff fs;
spawn Ff(1) in fs;
spawn Ff(2) in fs;

var int ret = 0;

var&? Ff f;
loop f in fs do
    var int v = await f!.Get_X();
    ret = ret + v;
end

escape ret;
]],
    _opts = { ceu_features_pool='true', ceu_features_dynamic='true' },
    todo = 'dot for spawn/await',
    wrn = true,     -- TODO
    run = 3,
}

Test { [[
data Dd with
    var int x = 10;
    code/tight Get_X (none) -> int do
        escape outer.x;
    end
end

var Dd d = _;
escape call d.Get_X();
]],
    todo = 'dot for data',
    run = 10,
}

Test { [[
data Dd with
    var int x = 10;
    code/await Get_X (none) -> int do
        escape outer.x;
    end
end

var Dd d = val Dd(20);
var int x = await d.Get_X();
escape x;
]],
    todo = 'dot for spawn/await',
    run = 10,
}

Test { [[
code/await Ff (none) -> none do
    code/tight Gg (none) -> none do end
end
pool[] Ff fs;
var&? Ff f;
loop f in fs do
    call f!.Gg();
end
escape 1;
]],
    _opts = { ceu_features_pool='true', ceu_features_dynamic='true' },
    wrn = true,
    --dcls = 'line 7 : invalid `call`',
    run = 1,
}

Test { [[
code/await Ff (none) -> (var int x) -> NEVER do
    x = 10;
    await FOREVER;
end
var&? Ff f = spawn Ff();
escape f.x;
]],
    dcls = 'line 6 : invalid operand to `.` : unexpected option alias',
}

Test { [[
code/await Ff (var&[] byte buf) -> NEVER do
    code/tight Reset (none) -> none do
        $outer.buf = 0;
    end
    call Reset();
    await FOREVER;
end
var[] byte buf = [1,2,3];
var&? Ff f = spawn Ff(&buf);
call f.Reset();
escape ($buf as int) + 1;
]],
    _opts = { ceu_features_dynamic='true' },
    dcls = 'line 10 : invalid operand to `.` : unexpected option alias',
}

Test { [[
spawn () do
    var bool v = true;
    code/tight Is_At (var int x, var int y) -> bool do
        escape outer.v;
    end
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
var int a = 1;
par/or do
with
    var int a = 1;
    code/await Ff (none) -> NEVER do
        code/tight Gg (none) -> none do
            var int b = outer.a;
        end
        await FOREVER;
    end
    spawn Ff();
end
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await Ff (none) -> int do
    event none ok_escape;

    code/await Gg (none) -> NEVER do
        emit outer.ok_escape;
        await FOREVER;
    end

    par do
        await ok_escape;
        escape 1;
    with
        spawn Gg();
        escape 99;
    end
end
var int ret = await Ff();
escape ret;
]],
    run = 1,
}

--<<< OUTER

-->>> TCO

Test { [[
par/or do
with
end
escape 1;
]],
    run = 1,
}

Test { [[
var int i;
loop i in [0->50000[ do      // 35000 already fails
    par/or do with end
end
escape 1;
]],
    run = 1,
}

Test { [[
code/await Ff (none) -> NEVER do
    await FOREVER;
end
var usize i;
loop i in [0->100000[ do      // never fails [was (5000 already fails)]
    spawn Ff();
end
escape 1;
]],
    run = 1,
}

Test { [[
var usize i;
loop i in [0->10000[ do
    do
        par do
            escape;
        with
        end
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
var usize i;
loop i in [0->100000[ do
    do
        par do
            escape;
        with
        end
    end
end
escape 1;
]],
    run = 1,
}

Test { [[
var int i;
loop i in [0->100000[ do
    par/or do with end
end
escape 1;
]],
    run = 1,
}

--<<< TCO

-->>> CEU_FEATURES_*

Test { [[
lua[] do
end
escape 1;
]],
    _opts = {
        ceu = true,
        ceu_features_lua = 1,
    },
    cmd = 'invalid value for option "ceu_features_lua"',
}

Test { [[
lua[] do
end
escape 1;
]],
    _opts = {
        ceu = true,
        ceu_features_lua = 'false',
    },
    props_ = 'line 1 : `lua` support is disabled',
}
Test { [=[

var int ret = [[1]];
escape ret;
]=],
    _opts = {
        ceu_features_lua = 'false',
    },
    props_ = 'line 2 : `lua` support is disabled',
}
Test { [=[
[[ ]];
escape 1;
]=],
    _opts = {
        ceu_features_lua = 'false',
    },
    props_ = 'line 1 : `lua` support is disabled',
}
Test { [[
await async/thread do end
escape 1;
]],
    _opts = {
        ceu_features_dynamic='true', ceu_features_thread = 'false',
    },
    props_ = 'line 1 : `async/thread` support is disabled',
}

Test { [=[
code/await Ff (none) -> int do
    [[ G = 111 ]];
    await async/thread do end;
    var int ret = [[G]];
    escape ret;
end
var int ret = 0;
par/and do
    lua[] do
        var int v = await Ff();
        ret = ret + v;
    end
with
    lua[] do
        var int v = await Ff();
        ret = ret + v;
    end
end
escape ret;
]=],
    _opts = { ceu_features_dynamic='true', ceu_features_lua='true' , ceu_features_thread='true' },
    run = 222,
}

Test { [[
escape 1;
]],
    _opts = { ceu_features_lua='true' },
    cmd = 'expected option `ceu-features-dynamic`',
}
Test { [[
escape 1;
]],
    _opts = { ceu_features_thread='true' },
    cmd = 'expected option `ceu-features-dynamic`',
}

Test { [[
code/await Ff (none) -> none do
end
pool[] Ff fs;
spawn Ff() in fs;
escape 1;
]],
    _opts = { ceu_features_pool='true', },
    dcls = 'line 3 : dynamic allocation support is disabled',
}

Test { [[
code/await Ff (none) -> none do
end
pool[] Ff fs;
spawn Ff() in fs;
escape 1;
]],
    _opts = { ceu_features_pool='true', ceu_features_dynamic='true' },
    run = 1,
}

Test { [[
var&[] byte vec;
escape 1;
]],
    wrn = true,
    run = 1,
}

Test { [[
code/await Ff (none) -> none do end
pool[1] Ff fs;
spawn Ff() in fs;
escape 1;
]],
    dcls = 'line 2 : pool support is disabled',
}

--<<< CEU_FEATURES_*
