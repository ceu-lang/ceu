--_VALGRIND = true

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
	[[input void START; await START; escape(1);]],
	[[escape(2);]],
	[[escape(3);]],
	[[input void START; await START; escape(4);]],
	run = 10,
}

Test {
	[[output int A; emit A=>2;         escape 1;]],
	[[input  int A; var int a=await A; escape a;]],
	lnks = {
		{ 1, 1, 2, 246 },
	},
	run = 3,
}

Test {
	[[output int A; emit A=>2;         escape 1;]],
	[[input  int A; var int a=await A; escape a;]],
	[[input  int A; var int a=await A; escape a;]],
	lnks = {
		{ 1, 1, 2, 246 },
		{ 1, 1, 3, 246 },
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
		{ 1, 1, 2, 246 },
		{ 1, 1, 2, 245 },
	},
	run = 6,
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
		{ 1, 1, 2, 246 },
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
var int ret = call A=>2;
escape ret;
]],
    [[
input (int v)=>int A do
    return v+1;
end
escape 1;
]],
	lnks = {
		{ 1, 1, 2, 246 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
	run = 4,
}

Test {
    [[
input void START;
output (int)=>int A;
await START;
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
		{ 1, 1, 2, 246 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
    run = 11,
}

Test {
    [[
output (int)=>int O;
input (int v)=>int I do
    return v + 1;
end
var int ret = call O=>2;
_printf("C = %d\n", ret);
escape ret;
]],
    [[
input void START;
output (int)=>int O;
var int v;
input (int v)=>int I do
    var int x = call O=>v;
_printf("B = %d\n", x);
    this.v = x;
    return x + 1;
end
await START;
_printf("D = %d\n", v);
escape v;
]],
	lnks = {
		{ 1, 1, 2, 245 },
        { 2, 1, 1, 245 },
        -- src app
        -- src evt
        -- dst app
        -- dst evt
	},
	run = 7,
}


