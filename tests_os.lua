_VALGRIND = true

-- TODO: elminate all "await 20ms"

--[===[
--]===]

Test { [[
var char* a;
a = "o";
escape 1;
]],
    run = 1,
}

Test { [[
native _char=1;
var _char* a = "Abcd12" ;
escape 1;
]],
    run = 1
}
Test { [[
native pure _strlen1();
native do
    int strlen1 (char* str) {
        int n = 0;
        while (1) {
            if (str[n] == '\0')
                return n;
            n++;
        }
    }
end
escape _strlen1("123");
]],
    run=3
}
Test { [[
native pure _strlen();
native do
    ##include <string.h>
end
escape _strlen("123");
]],
    run=3
}
Test { [[
native pure _strlen();
native do
    ##include <string.h>
end
escape _strlen("123\n");
]],
    run=4
}
Test { [[
native nohold _strncpy(), _printf(), _strlen();
native _char = 1;
var _char[10] str;
_strncpy(str, "123", 4);
escape _strlen(str);
]],
    run = 3
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
escape _strlen(d);
]],
    run = 12
}

--do return end

-- OK: well tested

Test { [[escape(1);]],
	run = 1,
}

Test {
	[[escape(2);]],
	[[escape(3);]],
	run = 5,
}

Test {
	[[escape(1);]],
	[[escape(2);]],
	[[escape(3);]],
	[[escape(4);]],
	run = 10,
}

Test {
	[[escape(2);]],
	[[await 50ms; escape(3);]],
	run = 5,
}

Test {
	[[async do end escape(2);]],
	[[await 50ms; escape(3);]],
	run = 5,
}

Test {
	[[await 1ms; async do end escape(2);]],
	[[await 50ms; async do end; escape(3);]],
	run = 5,
}

Test {
	[[await 1ms; async do end escape(2);]],
	[[
input void A;
par/and do
	await A;
with
	async do
		emit A;
	end
end
escape(3);
]],
	run = 5,
}

Test {
	[[await 100ms; async do emit 1s; end escape(2);]],
	[[
input void A;
par/and do
	await A;
with
	async do
		emit A;
	end
end
escape(3);
]],
	run = 5,
}

Test {
    [[input void OS_START; await OS_START; escape(1);]],
	[[escape(2);]],
	[[escape(3);]],
    [[input void OS_START; await OS_START; escape(4);]],
	run = 10,
}

Test {
    [[
output int A;
await OS_START;
emit A=>2;
await 2s;
escape 1;
]],
	[[
input  int A;
var int a=await A;
escape a;
]],
	lnks = {
        { 1, 1, 2, 244 },
	},
	run = 3,
}

Test {
    [[output int A; emit A=>2;         await 20ms; escape 1;]],
	[[input  int A; var int a=await A; escape a;]],
	[[input  int A; var int a=await A; escape a;]],
	lnks = {
        { 1, 1, 2, 244 },
        { 1, 1, 3, 244 },
	},
	run = 5,
}

Test {
    [[output int A; emit A=>2; await 20ms; escape 1;]],
	[[
input int A, B;
var int ret = 0;
par/and do
	var int a = await A;
	ret = ret + a;
with
	var int b = await B;
	ret = ret + b + 1;
end
escape ret;
]],
	lnks = {
        { 1, 1, 2, 244 },
		{ 1, 1, 2, 243 },
	},
	run = 6,
}

Test {
    [[
output (int)=>void A;
await OS_START;
call A=>2;
escape 1;
]],
    [[
input (int v)=>void A do
end
await OS_START;
escape 1;
]],
	lnks = {
		{ 1, 1, 2, 244 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
	run = 2,
}

Test {
    [[
output (int)=>void A;
call A=>2;
escape 1;
]],
    [[
input (int v)=>void A do
end
escape 1;
]],
	lnks = {
		{ 1, 1, 2, 244 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
	run = 2,
    todo = 'load/init/start',
}

Test {
    [[
output (int)=>int A;
await OS_START;
call A=>2;
escape 1;
]],
    [[
input (int v)=>int A do
    return 1;
end
await OS_START;
escape 1;
]],
	lnks = {
		{ 1, 1, 2, 244 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
	run = 2,
}

Test {
    [[
output (int)=>int A;
call A=>2;
escape 1;
]],
    [[
input (int v)=>int A do
    return 1;
end
escape 1;
]],
    todo = 'load/init/start',
	lnks = {
		{ 1, 1, 2, 244 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
	run = 2,
}

Test {
    [[
output (int)=>int A;
await 10ms;
var int ret = call A=>2;
escape ret;
]],
    [[
input (int v)=>int A do
    return v+1;
end
await 10ms;
escape 1;
]],
	lnks = {
        { 1, 1, 2, 244 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
	run = 4,
}

Test {
    [[
input void OS_START;
output (int)=>int A;
await OS_START;
var int ret = call A=>2;
escape ret;
]],
[[
var int inc = 3;
input (int v)=>int A do
    return v + this.inc + inc;
end
escape inc;
]],
	lnks = {
        { 1, 1, 2, 244 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
    todo = 'should fail on call broken link',
    run = 11,
}
Test {
    [[
var int inc = 3;
input (int v)=>int A do
    return v + this.inc + inc;
end
escape inc;
]],
    [[
input void OS_START;
output (int)=>int A;
await OS_START;
var int ret = call A=>2;
escape ret;
]],
	lnks = {
        { 2, 1, 1, 244 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
    todo = 'should fail on call broken link',
    run = 11,
}

Test {
    [[
output (int)=>int O;
input (int v)=>int I do
    return v + 1;
end
await 10ms;
var int ret = call O=>2;
escape ret;
]],
    [[
input void OS_START;
output (int)=>int O;
var int v;
input (int v)=>int I do
    var int x = call O=>v;
    this.v = x;
    return x + 1;
end
await OS_START;
await 10ms;
escape v;
]],
	lnks = {
        { 1, 1, 2, 243 },
        { 2, 1, 1, 243 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
	run = 7,
}

Test {
[[
var int v = 0;
input (void)=>void A do
    v = 1;
end
await 1s;
escape v;
]],
[[
output (void)=>void A;
await OS_START;
call A;
escape 1;
]],
    run = 2,
    lnks = { { 2,1, 1,244 } },
}
Test {
[[
var int v = 0;
output (int,int) O;
par/or do
    every 1s do
        var int a=1, b=2;
        emit O => (a,b);
    end
with
    await 2s;
end
escape 0;
]],
[[
input (int,int) I;
var int ret = 0;
par/or do
    var int a,b;
    (a,b) = await I;
    ret = ret + a + b;
with
    await 2s;
end
escape ret;
]],
    run = 3,
    lnks = { { 1,1, 2,244 } },
}

Test {
[[
var int v = 0;
output (int,int) O;
par/or do
    loop do
        await 1s;
        var int a=1, b=2;
        emit O => (a,b);
        await 1s;
    end
with
    await 2s;
    v = v;
    await 2s;
end
escape 0;
]],
[[
input (int,int) I;
var int ret = 0;
par/or do
    var int a,b;
    (a,b) = await I;
    ret = ret + a + b;
with
    await 2s;
    await 2s;
end
escape ret;
]],
    run = 3,
    lnks = { { 1,1, 2,244 } },
}

Test {
[[
var int v = 0;
output (int,int) O;
par/or do
    loop do
        await 1s;
        var int a=1, b=2;
        emit O => (a,b);
        await 1s;
    end
with
    await 2s;
    v = v;
    await 2s;
end
escape 0;
]],
[[
input (int,int) I;
var int ret = 0;
par/or do
    var int a,b;
    (a,b) = await I
            until a == 1;
    ret = ret + a + b;
with
    await 2s;
    await 2s;
    await 10ms;
end
escape ret;
]],
    run = 3,
    lnks = { { 1,1, 2,244 } },
}

Test {
[[
output int O;
var int ret = 0;
await OS_START;
loop i, 10 do
    var int a=1;
    emit O => a;
    ret = ret + a;
end
escape ret;
]],
[[
input int I;
var int ret = 0;
await OS_START;
par/or do
    loop do
        var int a;
        a = await I
            until a == 1;
        ret = ret + a;
    end
with
    await 10min;
end
escape ret;
]],
    run = 10,
    lnks = { { 1,1, 2,244 } },
}

Test {
[[
output int O;
var int ret = 0;
await OS_START;
loop i, 10 do
    var int a=1;
    emit O => a;
    ret = ret + a;
end
await 10min;
escape ret;
]],
[[
input int I;
var int ret = 0;
await OS_START;
par/or do
    loop do
        var int a;
        a = await I
            until a == 1;
        ret = ret + a;
    end
with
    await 10min;
end
escape ret;
]],
    run = 20,
    lnks = { { 1,1, 2,244 } },
}

Test {
[[
output (u8,u8) O;
output void F;
await OS_START;
var int ret = 0;
loop i, 100 do
    var int a=1, b=2;
    emit O => (a,b);
    ret = ret + a + b;
end
await 50ms;
emit F;
await 50ms;
escape ret;
]],
[[
input (u8,u8) I;
input void F;
var int ret = 0;
await OS_START;
par/or do
    loop do
        var int a,b;
        (a,b) = await I
                until a == 1;
        ret = ret + a + b;
    end
with
    await F;
end
escape ret;
]],
    run = 600,
    lnks = {
        { 1,1, 2,244 },
        { 1,2, 2,243 },
    },
}

Test {
[[
output (u8,u8) O;
output int F;
var int ret = 0;
loop i, 10000 do
    var int a=1, b=2;
    emit O => (a,b);
    ret = ret + 1;
end
await 20ms;
emit F=>0;
await 20ms;
escape ret;
]],
[[
input (u8,u8) I;
input int F;
var int ret = 0;
par/or do
    loop do
        var int a,b;
        (a,b) = await I
                until a == 1;
        ret = ret + 1;
    end
with
    await F;
end
escape ret;
]],
    run = 11927,
    lnks = {
        { 1,1, 2,244 },
        { 1,2, 2,243 },
    },
}

Test {
[[
output (u8,u8) O;
output int F;
var int ret = 0;
loop i, 10000 do
    var int a=1, b=2;
    emit O => (a,b);
    ret = ret + 1;
end
loop i, 10000 do
    async do end
end
emit F=>0;
await 20ms;
escape ret;
]],
[[
input (u8,u8) I;
input int F;
var int ret = 0;
par/or do
    loop do
        var int a,b;
        (a,b) = await I
                until a == 1;
        ret = ret + 1;
    end
with
    await F;
end
escape ret;
]],
    run = 11927,
    lnks = {
        { 1,1, 2,244 },
        { 1,2, 2,243 },
    },
}

Test {
[[
output (int,int) O;
var int ret = 0;
    loop i, 1000 do
        var int a=1, b=2;
        emit O => (a,b);
        ret = ret + a + b;
    end
await 20ms;
escape ret;
]],
[[
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
    await 10min;
end
escape ret;
]],
    run = 6000,
    lnks = { { 1,1, 2,244 } },
}

Test {
[[
output (u8,u8) O;
output int F;
var int ret = 0;
    loop i, 10000 do
        var int a=1, b=2;
        emit O => (a,b);
        ret = ret + 1;
    end
    loop i, 10000 do
        async do end
    end
    emit F=>0;
    loop i, 1000 do
        var int a=1, b=2;
        emit O => (a,b);
        ret = ret + a + b;
    end
    await 20ms;
escape ret;
]],
[[
input (u8,u8) I;
input int F;
var int ret = 0;
par/or do
    loop do
        var int a,b;
        (a,b) = await I
                until a == 1;
        ret = ret + 1;
    end
with
    await F;
end
par/or do
    loop do
        var int a,b;
        (a,b) = await I
                until a == 1;
        ret = ret + a + b;
    end
with
    await 10min;
end
escape ret;
]],
    run = 17927,
    lnks = {
        { 1,1, 2,244 },
        { 1,2, 2,243 },
    },
}

Test {
[[
output (int,int) O;
var int ret = 0;
par/or do
    every 1s do
        var int a=1, b=2;
        emit O => (a,b);
        ret = ret + a + b;
    end
with
    await 10min;
    await 20ms;
end
escape ret;
]],
[[
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
    await 10min;
    await 20ms;
end
escape ret;
]],
    run = 3600,
    lnks = { { 1,1, 2,244 } },
}

Test { [[
output int O;
par/or do
    loop do
        await 250ms;
        await 250ms;
        emit O => 1;
    end
with
    await 10min;
end
escape(1);
]],
	run = 1,
}

Test { [[
var int ret = 0;
input void STOP;
par/or do
    loop do
        await 1s;
        ret = ret + 1;
    end

    par/or do with end
with
    await STOP;
end
escape ret;
]],
[[
output void STOP;
await 5s;
emit STOP;
await 20ms;
escape 1;
]],
    lnks = {
		{ 2, 1, 1, 244 },
	},
    run = 6;
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
with
    await OS_START;
with
    await OS_START;
with
    await OS_START;
end
]],
    run = 1,
}

Test { [[
await OS_START;

input void F;
var int ret = 0;

finalize with
    ret = -10;
end

par/or do
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
with
    await F;
end
escape ret;
]],
[[
await OS_START;
await 20s;
output void F;
emit F;
await 20ms;
escape 10;
]],
    lnks = {
		{ 2, 1, 1, 244 },
	},
    run = 29,
}

do return end

-- need to know the addr of the other APP

Test {
	[[
output int A;
emit A=>2;
emit A=>2;
emit A=>2;
await 1s;
_ceu_sys_stop(&__ceu_app_2);
emit A=>2;
await 1s;
escape 1;
]],
    [[
input int A;
var int a;
var int ret = 0;
par/or do
    every a = A do
        ret = ret + a;
    end
with
    await OS_STOP;
    ret = ret + 10;
end
escape ret;
]],
	lnks = {
		{ 1, 1, 2, 245 },
	},
    run = 17,
}

Test {
	[[
native nohold _ceu_sys_stop();
native do
    extern tceu_app _ceu_app_2;
end
output int A;
emit A=>2;
emit A=>2;
emit A=>2;
await 1s;
_ceu_sys_stop(&__ceu_app_2);
emit A=>2;
await 1s;
escape 1;
]],
    [[
input int A;
var int a;
var int ret = 0;
every a = A do
    ret = ret + a;
end
escape ret;
]],
	lnks = {
		{ 1, 1, 2, 245 },
	},
    run = 2,
}
