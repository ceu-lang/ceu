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
