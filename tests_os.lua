_VALGRIND = true

--[===[
--]===]

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
	[[output int A; emit A=>2;         escape 1;]],
	[[input  int A; var int a=await A; escape a;]],
	lnks = {
		{ 1, 1, 2, 245 },
	},
	run = 3,
}

Test {
	[[output int A; emit A=>2;         escape 1;]],
	[[input  int A; var int a=await A; escape a;]],
	[[input  int A; var int a=await A; escape a;]],
	lnks = {
		{ 1, 1, 2, 245 },
		{ 1, 1, 3, 245 },
	},
	run = 5,
}

Test {
	[[output int A; emit A=>2;         escape 1;]],
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
		{ 1, 1, 2, 245 },
		{ 1, 1, 2, 244 },
	},
	run = 6,
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
		{ 1, 1, 2, 245 },
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
	lnks = {
		{ 1, 1, 2, 245 },
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
        { 1, 1, 2, 245 },
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
        { 1, 1, 2, 245 },
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
_printf("A: v=%d this=%d\n", v,this.inc);
    return v + this.inc + inc;
end
escape inc;
]],
    [[
input void OS_START;
output (int)=>int A;
await OS_START;
var int ret = call A=>2;
_printf("1v = %d\n", ret);
escape ret;
]],
	lnks = {
        { 2, 1, 1, 245 },
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
        { 1, 1, 2, 244 },
        { 2, 1, 1, 244 },
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
call A;
escape 1;
]],
    run = 2,
    lnks = { { 2,1, 1,245 } },
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
    lnks = { { 1,1, 2,245 } },
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
    lnks = { { 1,1, 2,245 } },
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
    lnks = { { 1,1, 2,245 } },
}

Test {
[[
output int O;
var int ret = 0;
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
    lnks = { { 1,1, 2,245 } },
}

Test {
[[
output (u8,u8) O;
output void F;
var int ret = 0;
    loop i, 100 do
        var int a=1, b=2;
        emit O => (a,b);
        ret = ret + a + b;
    end
    emit F;
escape ret;
]],
[[
input (u8,u8) I;
input void F;
var int ret = 0;
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
        { 1,1, 2,245 },
        { 1,2, 2,244 },
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
        { 1,1, 2,245 },
        { 1,2, 2,244 },
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
    lnks = { { 1,1, 2,245 } },
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
        { 1,1, 2,245 },
        { 1,2, 2,244 },
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
end
escape ret;
]],
    run = 3600,
    lnks = { { 1,1, 2,245 } },
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
