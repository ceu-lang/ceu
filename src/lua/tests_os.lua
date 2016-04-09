VALGRIND = true

--[===[
--]===]

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
    [[await 50ms; escape(10);]],
    run = 12,
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
        { 1, 1, 2, 242 },
	},
	run = 3,
}

Test {
    [[output int A; emit A=>2; escape 1;]],
	[[input  int A; var int a=await A; escape a;]],
	[[input  int A; var int a=await A; escape a;]],
	lnks = {
        { 1, 1, 2, 242 },
        { 1, 1, 3, 242 },
	},
	run = 5,
}

Test {
    [[output int A; emit A=>2; escape 1;]],
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
        { 1, 1, 2, 242 },
		{ 1, 1, 2, 241 },
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
		{ 1, 1, 2, 242 },
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
        { 1, 1, 2, 242 },
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
        { 1, 1, 2, 242 },
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
        { 1, 1, 2, 242 },
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
await OS_START;
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
        { 1, 1, 2, 242 },
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
        { 1, 1, 2, 242 },
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
        { 2, 1, 1, 242 },
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
await OS_START;
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
escape v;
]],
	lnks = {
        { 1, 1, 2, 242 },
        { 2, 1, 1, 242 },
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
await OS_START;
escape v;
]],
[[
output (void)=>void A;
await OS_START;
call A;
escape 1;
]],
    run = 1,
    lnks = { { 2,1, 1,242 } },
}
Test {
[[
output (void)=>void A;
await OS_START;
call A;
escape 1;
]],
[[
var int v = 0;
input (void)=>void A do
    v = 1;
end
await OS_START;
escape v;
]],
    run = 2,
    lnks = { { 1,1, 2,242 } },
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
    lnks = { { 1,1, 2,242 } },
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
    lnks = { { 1,1, 2,242 } },
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
    lnks = { { 1,1, 2,242 } },
}

Test {
[[
output int O;
var int ret = 0;
await OS_START;
loop i in 10 do
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
    run = 20,
    lnks = { { 1,1, 2,242 } },
}

Test {
[[
output int O;
var int ret = 0;
await OS_START;
loop i in 10 do
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
    lnks = { { 1,1, 2,242 } },
}

Test {
[[
output (u8,u8) O;
output void F;
await OS_START;
var int ret = 0;
loop i in 100 do
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
        { 1,1, 2,242 },
        { 1,2, 2,241 },
    },
}

Test {
[[
output (u8,u8) O;
output int F;
var int ret = 0;
loop i in 10000 do
    var int a=1, b=2;
    emit O => (a,b);
    ret = ret + 1;
end
await 30s;     // queue is full, <emit F> would fail
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
    run = 13640,
    lnks = {
        { 1,1, 2,242 },
        { 1,2, 2,241 },
    },
}

Test {
[[
output (u8,u8) O;
output int F;
var int ret = 0;
loop i in 10000 do
    var int a=1, b=2;
    emit O => (a,b);
    ret = ret + 1;
end
loop i in 10000 do
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
    run = 13640,
    lnks = {
        { 1,1, 2,242 },
        { 1,2, 2,241 },
    },
}

Test {
[[
output (int,int) O;
var int ret = 0;
    loop i in 1000 do
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
    lnks = { { 1,1, 2,242 } },
}

Test {
[[
output (u8,u8) O;
output int F;
var int ret = 0;
    loop i in 10000 do
        var int a=1, b=2;
        emit O => (a,b);
        ret = ret + 1;
    end
    loop i in 10000 do
        async do end
    end
    emit F=>0;
    loop i in 1000 do
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
    run = 19640,
    lnks = {
        { 1,1, 2,242 },
        { 1,2, 2,241 },
    },
}

Test {
[[
output (int,int) O;
var int ret = 0;
par/or do
    every 1s do
        var int a=1, b=2;
        emit O => (a,b);    // last is lost by app2
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
    run = 3597,
    lnks = { { 1,1, 2,242 } },
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
        { 2, 1, 1, 242 },
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
escape 10;
]],
    lnks = {
        { 2, 1, 1, 242 },
	},
    run = 29,
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

-- STRINGS / STDLIB

Test { [[
var char&& a;
a = "o";
escape 1;
]],
    run = 1,
}

Test { [[
native _char=1;
var _char&& a = (_char&&)"Abcd12" ;
escape 1;
]],
    run = 1
}
Test { [[
native @pure _strlen1();
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
input void OS_START;

output (void)=>int&& LUA_NEW;
output (int&& l, int v)=>void LUA_PUSHNUMBER;
output (int&& l, int index)=>int LUA_TONUMBER;

await OS_START;

var int&& l = (call LUA_NEW);

call LUA_PUSHNUMBER => (l, 10);
var int v = (call LUA_TONUMBER => (l, -1));
escape v;
]],
----
[[
input void OS_START;
var int v;
input (void)=>int&& NEW do
    return &&v;
end

input (int&& l, int v)=>void PUSHNUMBER do
    *l = v;
end

input (int&& l, int idx)=>int TONUMBER do
    return *l;
end
await OS_START;
escape v;
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 1, 3, 2, 240 },
	},
    run = 20,
}

Test { [[
native/pre do
    typedef int lua_State;
    void lua_pushnil (lua_State* l) {}
end

input (_lua_State&& l)=>void PUSHNIL do
    _lua_pushnil(l);
end
escape 1;
]],
    run = 1,
}

--[=[
Test { [[
native @pure _strlen();
native do
    ##include <string.h>
end
escape _strlen("123");
]],
    run=3
}
Test { [[
native @pure _strlen();
native do
    ##include <string.h>
end
escape _strlen("123\n");
]],
    run=4
}
Test { [[
native @nohold _strncpy(), _strlen();
native _char = 1;
var _char[10] str;
_strncpy(str, "123", 4);
escape _strlen(str);
]],
    run = 3
}

Test { [[
native @nohold _strncpy(), _strlen(), _strcpy();
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
--]=]

--do return end

-- REQUESTS / RAW

-- normal: request -> return
Test { [[
output (int,int)     REQUEST;
output int           CANCEL;
input  (int,int,int) RETURN;

par/or do
    emit REQUEST => (1, 10);
    await RETURN;
    escape 1;
with
    await 10s;
end
await 100ms;
escape 100;
]],[[
input  (int,int)     REQUEST;
input  int           CANCEL;
output (int,int,int) RETURN;

do
    par/or do
        await REQUEST;
        emit RETURN => (1, 0, 1);
        await 20ms;
        escape 1;
    with
        await 2s;
    end
end
await 100ms;
escape 200;
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 2,
}

Test { [[
output (int,int)     REQUEST;
output int           CANCEL;
input  (int,int,int) RETURN;

var int gid = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit REQUEST => (id, 20);
    finalize with
        emit CANCEL => id;
        gid = gid - 1;
    end
    var int id2, err, ret;
    (id2, err, ret) = await RETURN
                      until id == id2;
    escape ret;
with
    await 1s;
end
escape 100;
]],[[
input  (int,int)     REQUEST;
input  int           CANCEL;
output (int,int,int) RETURN;

class Line with
    var int id;
    var int param;
do
    finalize with
        var int err = 1;
        emit RETURN => (this.id,err,0);
    end
    par/or do
        emit RETURN => (this.id, 0, param+1);
    with
        await 100ms;
    with
        var int v = await CANCEL
                    until v == this.id;
    end
end
var int ret = 0;
do
    par/or do
        every (id,param) in REQUEST do
            ret = param;
            var Line&&? ok = spawn Line with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit RETURN => (id,err,0);
            end
        end
    with
        await 100ms;
    end
end
escape ret;
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 41,
}

-- error: request -> return(err)
Test { [[
output (int,int)     REQUEST;
output int           CANCEL;
input  (int,int,int) RETURN;

var int gid = 5;
var int ret = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit REQUEST => (id, 10);   // id=5
    finalize with
        emit CANCEL => id;
        gid = gid - 1;
    end
    ret = 15;
    await 2s;
with
    var int id,err,v;
    (id,err,v) = await RETURN;
    escape id + err + v;        // 5 + x + x
with
    await 10s;
end
escape ret;     // ret = 6
]],[[
input  (int,int)     REQUEST;
input  int           CANCEL;
output (int,int,int) RETURN;

input int RET;

class Line with
    var int id;
    var int param;
    var int ret = 0;
do
    finalize with
        var int err = 1;
        emit RETURN => (this.id,err,0);     // 5,1,0
    end
    par/or do
        await 2s;
        emit RETURN => (this.id, 0, param+1);
    with
        await 1s;
    end
end
var int ret = 0;
do
    par/or do
        every (id,param) in REQUEST do
            ret = param;    // 10
            var Line&&? ok = spawn Line with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit RETURN => (id,err,0);
            end
        end
    with
        await 2s;
    end
end
escape ret;     // 10
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 16,
}

-- error: request -> return(err) (spawn[0])
Test { [[
output (int,int)     REQUEST;
output int           CANCEL;
input  (int,int,int) RETURN;

var int gid = 5;
var int ret = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit REQUEST => (id, 10);   // id=5
    finalize with
        emit CANCEL => id;
        gid = gid - 1;
    end
    ret = 15;
    await 2s;
with
    var int id,err,v;
    (id,err,v) = await RETURN;
    escape id + err + v;        // 5 + 2 + 0
with
    await 10s;
end
escape ret;     // ret = 7
]],[[
input  (int,int)     REQUEST;
input  int           CANCEL;
output (int,int,int) RETURN;

input int RET;

class Line with
    var int id;
    var int param;
    var int ret = 0;
do
    finalize with
        var int err = 1;
        emit RETURN => (this.id,err,0);     // 2,1,0
    end
    par/or do
        await 2s;
        emit RETURN => (this.id, 0, param+1);
    with
        await 1s;
    end
end
var int ret = 0;
do
    par/or do
        pool Line[0] lines;
        every (id,param) in REQUEST do
            ret = param;    // 10
            var Line&&? ok = spawn Line in lines with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit RETURN => (id,err,0);  // 5,2,0
            end
        end
    with
        await 2s;
    end
end
escape ret;     // 10
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 17,
}

-- cancel: request + cancel
Test { [[
output (int,int)     REQUEST;
output int           CANCEL;
input  (int,int,int) RETURN;

var int gid = 5;
var int ret = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit REQUEST => (id, 10);
    finalize with
        emit CANCEL => id;
        gid = gid - 1;
    end
    ret = 15;
with
    await RETURN;
with
    await 10s;
end
escape ret;
]],[[
input  (int,int)     REQUEST;
input  int           CANCEL;
output (int,int,int) RETURN;

input int RET;

class Line with
    var int id;
    var int param;
    var int ret = 0;
do
    finalize with
        var int err = 1;
        emit RETURN => (this.id,err,0);
    end
    par/or do
        await 1s;
        emit RETURN => (this.id, 0, param+1);
    with
        await 10s;
    with
        var int v = await CANCEL
                    until v == this.id;     // v = 5
        ret = 10+v;                         // ret = 15
    end
    async (ret) do
        emit RET => ret;                    // RET = 15
    end
end
var int ret = 0;
do
    par/or do
        every (id,param) in REQUEST do
            ret = param;
            var Line&&? ok = spawn Line with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit RETURN => (id,err,0);
            end
        end
    with
        ret = await RET;    // ret = 15
        ret = ret + 5;      // ret = 20
    with
        await 2s;
    end
end
escape ret;
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 35,
}

-- REQUESTS / DCLS

Test { [[
input/output (int max)=>char&& [10] LINE;
escape 1;
]],
    run = 1,
}

Test { [[
input/output (int max)=>char&& [10] LINE1, LINE2;
escape 1;
]],
    run = 1,
}

-- normal: request -> return
Test { [[
output/input (int)=>int EVT;

par/or do
    emit EVT_REQUEST => (1, 10);
    await EVT_RETURN;
    escape 1;
with
    await 10s;
end
await 100ms;
escape 100;
]],[[
input/output (int)=>int EVT;

do
    par/or do
        await EVT_REQUEST;
        emit EVT_RETURN => (1, 0, 1);
        await 20ms;
        escape 1;
    with
        await 2s;
    end
end
await 100ms;
escape 200;
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 2,
}

Test { [[
output/input (int)=>int EVT;

var int gid = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit EVT_REQUEST => (id, 20);
    finalize with
        emit EVT_CANCEL => id;
        gid = gid - 1;
    end
    var int id2, err, ret;
    (id2, err, ret) = await EVT_RETURN
                      until id == id2;
    escape ret;
with
    await 1s;
end
escape 100;
]],[[
input/output (int)=>int EVT;

class Line with
    var int id;
    var int param;
do
    finalize with
        var int err = 1;
        emit EVT_RETURN => (this.id,err,0);
    end
    par/or do
        emit EVT_RETURN => (this.id, 0, param+1);
    with
        await 100ms;
    with
        var int v = await EVT_CANCEL
                    until v == this.id;
    end
end
var int ret = 0;
do
    par/or do
        every (id,param) in EVT_REQUEST do
            ret = param;
            var Line&&? ok = spawn Line with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit EVT_RETURN => (id,err,0);
            end
        end
    with
        await 100ms;
    end
end
escape ret;
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 41,
}

-- error: request -> return(err)
Test { [[
output/input (int)=>int EVT;

var int gid = 5;
var int ret = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit EVT_REQUEST => (id, 10);   // id=5
    finalize with
        emit EVT_CANCEL => id;
        gid = gid - 1;
    end
    ret = 15;
    await 2s;
with
    var int id,err,v;
    (id,err,v) = await EVT_RETURN;
    escape id + err + v;        // 5 + x + x
with
    await 10s;
end
escape ret;     // ret = 6
]],[[
input/output (int)=>int EVT;

input int RET;

class Line with
    var int id;
    var int param;
    var int ret = 0;
do
    finalize with
        var int err = 1;
        emit EVT_RETURN => (this.id,err,0);     // 5,1,0
    end
    par/or do
        await 2s;
        emit EVT_RETURN => (this.id, 0, param+1);
    with
        await 1s;
    end
end
var int ret = 0;
do
    par/or do
        every (id,param) in EVT_REQUEST do
            ret = param;    // 10
            var Line&&? ok = spawn Line with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit EVT_RETURN => (id,err,0);
            end
        end
    with
        await 2s;
    end
end
escape ret;     // 10
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 16,
}

-- error: request -> return(err) (spawn[0])
Test { [[
output/input (int)=>int EVT;

var int gid = 5;
var int ret = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit EVT_REQUEST => (id, 10);   // id=5
    finalize with
        emit EVT_CANCEL => id;
        gid = gid - 1;
    end
    ret = 15;
    await 2s;
with
    var int id,err,v;
    (id,err,v) = await EVT_RETURN;
    escape id + err + v;        // 5 + 2 + 0
with
    await 10s;
end
escape ret;     // ret = 7
]],[[
input/output (int)=>int EVT;

input int RET;

class Line with
    var int id;
    var int param;
    var int ret = 0;
do
    finalize with
        var int err = 1;
        emit EVT_RETURN => (this.id,err,0);     // 2,1,0
    end
    par/or do
        await 2s;
        emit EVT_RETURN => (this.id, 0, param+1);
    with
        await 1s;
    end
end
var int ret = 0;
do
    par/or do
        pool Line[0] lines;
        every (id,param) in EVT_REQUEST do
            ret = param;    // 10
            var Line&&? ok = spawn Line in lines with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit EVT_RETURN => (id,err,0);  // 5,2,0
            end
        end
    with
        await 2s;
    end
end
escape ret;     // 10
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 17,
}

-- cancel: request + cancel
Test { [[
output/input (int)=>int EVT;

var int gid = 5;
var int ret = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit EVT_REQUEST => (id, 10);
    finalize with
        emit EVT_CANCEL => id;
        gid = gid - 1;
    end
    ret = 15;
with
    await EVT_RETURN;
with
    await 10s;
end
escape ret;
]],[[
input/output (int)=>int EVT;

input int RET;

class Line with
    var int id;
    var int param;
    var int ret = 0;
do
    finalize with
        var int err = 1;
        emit EVT_RETURN => (this.id,err,0);
    end
    par/or do
        await 1s;
        emit EVT_RETURN => (this.id, 0, param+1);
    with
        await 10s;
    with
        var int v = await EVT_CANCEL
                    until v == this.id;     // v = 5
        ret = 10+v;                         // ret = 15
    end
    async (ret) do
        emit RET => ret;                    // RET = 15
    end
end
var int ret = 0;
do
    par/or do
        every (id,param) in EVT_REQUEST do
            ret = param;
            var Line&&? ok = spawn Line with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit EVT_RETURN => (id,err,0);
            end
        end
    with
        ret = await RET;    // ret = 15
        ret = ret + 5;      // ret = 20
    with
        await 2s;
    end
end
escape ret;
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 35,
}

-- REQUESTS / FULL

-- normal: request -> return
Test { [[
output/input (int)=>int EVT;

par/or do
    emit EVT_REQUEST => (1, 10);
    await EVT_RETURN;
    escape 1;
with
    await 10s;
end
await 100ms;
escape 100;
]],[[
input/output (int)=>int EVT;

do
    par/or do
        await EVT_REQUEST;
        emit EVT_RETURN => (1, 0, 1);
        await 20ms;
        escape 1;
    with
        await 2s;
    end
end
await 100ms;
escape 200;
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 2,
}

Test { [[
output/input (int)=>int EVT;

var int gid = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit EVT_REQUEST => (id, 20);
    finalize with
        emit EVT_CANCEL => id;
        gid = gid - 1;
    end
    var int id2, err, ret;
    (id2, err, ret) = await EVT_RETURN
                      until id == id2;
    escape ret;
with
    await 1s;
end
escape 100;
]],[[
input/output (int)=>int EVT;

class Line with
    var int id;
    var int param;
do
    finalize with
        var int err = 1;
        emit EVT_RETURN => (this.id,err,0);
    end
    par/or do
        emit EVT_RETURN => (this.id, 0, param+1);
    with
        await 100ms;
    with
        var int v = await EVT_CANCEL
                    until v == this.id;
    end
end
var int ret = 0;
do
    par/or do
        every (id,param) in EVT_REQUEST do
            ret = param;
            var Line&&? ok = spawn Line with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit EVT_RETURN => (id,err,0);
            end
        end
    with
        await 100ms;
    end
end
escape ret;
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 41,
}

-- error: request -> return(err)
Test { [[
output/input (int)=>int EVT;

var int gid = 5;
var int ret = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit EVT_REQUEST => (id, 10);   // id=5
    finalize with
        emit EVT_CANCEL => id;
        gid = gid - 1;
    end
    ret = 15;
    await 2s;
with
    var int id,err,v;
    (id,err,v) = await EVT_RETURN;
    escape id + err + v;        // 5 + x + x
with
    await 10s;
end
escape ret;     // ret = 6
]],[[
input/output (int)=>int EVT;

input int RET;

class Line with
    var int id;
    var int param;
    var int ret = 0;
do
    finalize with
        var int err = 1;
        emit EVT_RETURN => (this.id,err,0);     // 5,1,0
    end
    par/or do
        await 2s;
        emit EVT_RETURN => (this.id, 0, param+1);
    with
        await 1s;
    end
end
var int ret = 0;
do
    par/or do
        every (id,param) in EVT_REQUEST do
            ret = param;    // 10
            var Line&&? ok = spawn Line with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit EVT_RETURN => (id,err,0);
            end
        end
    with
        await 2s;
    end
end
escape ret;     // 10
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 16,
}

-- error: request -> return(err) (spawn[0])
Test { [[
output/input (int)=>int EVT;

var int gid = 5;
var int ret = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit EVT_REQUEST => (id, 10);   // id=5
    finalize with
        emit EVT_CANCEL => id;
        gid = gid - 1;
    end
    ret = 15;
    await 2s;
with
    var int id,err,v;
    (id,err,v) = await EVT_RETURN;
    escape id + err + v;        // 5 + 2 + 0
with
    await 10s;
end
escape ret;     // ret = 7
]],[[
input/output (int)=>int EVT;

input int RET;

class Line with
    var int id;
    var int param;
    var int ret = 0;
do
    finalize with
        var int err = 1;
        emit EVT_RETURN => (this.id,err,0);     // 2,1,0
    end
    par/or do
        await 2s;
        emit EVT_RETURN => (this.id, 0, param+1);
    with
        await 1s;
    end
end
var int ret = 0;
do
    par/or do
        pool Line[0] lines;
        every (id,param) in EVT_REQUEST do
            ret = param;    // 10
            var Line&&? ok = spawn Line in lines with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit EVT_RETURN => (id,err,0);  // 5,2,0
            end
        end
    with
        await 2s;
    end
end
escape ret;     // 10
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 17,
}

-- cancel: request + cancel
Test { [[
output/input (int)=>int EVT;

var int gid = 5;
var int ret = 0;

par/or do
    var int id = gid;
    gid = gid + 1;
    emit EVT_REQUEST => (id, 10);
    finalize with
        emit EVT_CANCEL => id;
        gid = gid - 1;
    end
    ret = 15;
with
    await EVT_RETURN;
with
    await 10s;
end
escape ret;
]],[[
input/output (int)=>int EVT;

input int RET;

class Line with
    var int id;
    var int param;
    var int ret = 0;
do
    finalize with
        var int err = 1;
        emit EVT_RETURN => (this.id,err,0);
    end
    par/or do
        await 1s;
        emit EVT_RETURN => (this.id, 0, param+1);
    with
        await 10s;
    with
        var int v = await EVT_CANCEL
                    until v == this.id;     // v = 5
        ret = 10+v;                         // ret = 15
    end
    async (ret) do
        emit RET => ret;                    // RET = 15
    end
end
var int ret = 0;
do
    par/or do
        every (id,param) in EVT_REQUEST do
            ret = param;
            var Line&&? ok = spawn Line with
                this.id = id;
                this.param = param;
            end;
            if not ok? then
                var int err = 2;
                emit EVT_RETURN => (id,err,0);
            end
        end
    with
        ret = await RET;    // ret = 15
        ret = ret + 5;      // ret = 20
    with
        await 2s;
    end
end
escape ret;
]],
    lnks = {
        { 1, 1, 2, 242 },
        { 1, 2, 2, 241 },
        { 2, 1, 1, 242 },
    },
    run = 35,
}

-- REQUESTS

Test { [[
input/output [10] (int max)=>int LINE do
    return max + 1;
end
await 1s;
escape 1;
]],
    run = 1,
}

Test { [[
input/output [10] (int max)=>int LINE do
    return max + 1;
end
await 1s;
escape 1;
]],[[
output/input [10] (int max)=>int LINE;
var int ret = 1;
par/or do
    var int err;
    (err,ret) = request LINE=>10;
with
end
escape ret;
]],
    run = 2,
}

Test { [[
output/input [10] (int max)=>int LINE;
var int ret = 1;
var int err = 1;
par/or do
    (err,ret) = request LINE=>10;
with
    async do
        emit LINE_RETURN => (1,2,10);
    end
end
escape ret+err;
]],
    run = 12,
}

Test { [[
input/output [10] (int max)=>int LINE do
    return max + 1;
end
await 1s;
escape 1;
]],[[
output/input [10] (int max)=>int LINE;
var int ret = 1;
var int err = 1;
(err,ret) = request LINE=>10;
escape ret;
]],
    run = 12,
    lnks = {
        { 2,1 , 1,242},
        { 2,2 , 1,241},
        { 1,1 , 2,242},
    },
}

Test { [[
input/output [10] (int max)=>int LINE do
    return max * 2;
end
await 1s;
escape 111;
]],[[
output/input (int max)=>int LINE;
var int ret = 0;
par/and do
    var int err, v;
    (err,v) = request LINE => 10;
    ret = ret + err + v;
with
    var int err, v;
    (err,v) = request LINE => 20;
    ret = ret + err + v;
with
    var int err, v;
    (err,v) = request LINE => 30;
    ret = ret + err + v;
end
escape ret;
]],
    run = 231,
    lnks = {
        { 2,1 , 1,242},
        { 2,2 , 1,241},
        { 1,1 , 2,242},
    },
}

Test { [[
input/output [2] (int max)=>int LINE do
    await 1s;
    return max + 1;
end
await 1s;
escape 111;
]],[[
output/input (int max)=>int LINE;
var int ret = 0;
par/and do
    var int v, err;
    (err,v) = request LINE => 10;
    ret = ret + v + err;
with
    var int v, err;
    (err,v) = request LINE => 20;
    ret = ret + v + err;
with
    var int v, err;
    (err,v) = request LINE => 30;
    ret = ret + v + err;
end
escape ret;
]],
    run = 116,
    lnks = {
        { 2,1 , 1,242},
        { 2,2 , 1,241},
        { 1,1 , 2,242},
    },
}

Test { [[
input/output [2] (int max)=>int LINE do
    await 1s;
    return max * 2;
end
await 2s;
escape 111;
]],[[
output/input [2] (int max)=>int LINE;
var int ret = 0;
par/and do
    var int v, err;
    (err,v) = request LINE => 10;
    ret = ret + v + err;
with
    var int v, err;
    (err,v) = request LINE => 20;
    ret = ret + v + err;
with
    var int v, err;
    (err,v) = request LINE => 30;
    ret = ret + v + err;
end
escape ret;
]],
    run = 172,
    lnks = {
        { 2,1 , 1,242},
        { 2,2 , 1,241},
        { 1,1 , 2,242},
    },
}

Test { [[
input/output [2] (int max)=>int LINE do
    await 1s;
    return max * 2;
end
await 3s;
escape 0;
]],[[
output/input [2] (int max)=>int LINE;
var int ret = 0;
par/and do
    var int v, err;
    (err,v) = request LINE => 10;
    ret = ret + v + err;
with
    var int v, err;
    (err,v) = request LINE => 20;
    ret = ret + v + err;
with
    var int v, err;
    (err,v) = request LINE => 30;
    ret = ret + v + err;
with
    await 1s500ms;
    var int v, err;
    (err,v) = request LINE => 40;
    ret = ret + v + err;
with
    await 1s500ms;
    var int v, err;
    (err,v) = request LINE => 50;
    ret = ret + v + err;
with
    await 1s500ms;
    var int v, err;
    (err,v) = request LINE => 60;
    ret = ret + v + err;
end
escape ret;
]],
    run = 240+1+1,
    lnks = {
        { 2,1 , 1,242},
        { 2,2 , 1,241},
        { 1,1 , 2,242},
    },
}

Test { [[
input/output [1] (int max)=>int LINE do
    await 1s;
    return max * 2;
end
await 3s;
escape 1000;
]],[[
output/input [1] (int max)=>int LINE;
var int ret = 0;
par/and do
    var int v, err;
    (err,v) = request LINE => 10;
    ret = ret + v + err;
with
    var int v, err;
    (err,v) = request LINE => 20;
    ret = ret + v + err;
with
    var int v, err;
    (err,v) = request LINE => 30;
    ret = ret + v + err;
with
    await 1s500ms;
    var int v, err;
    (err,v) = request LINE => 40;
    ret = ret + v + err;
with
    await 1s500ms;
    var int v, err;
    (err,v) = request LINE => 50;
    ret = ret + v + err;
with
    await 1s500ms;
    var int v, err;
    (err,v) = request LINE => 60;
    ret = ret + v + err;
end
escape ret;
]],
    run = 1104,
    lnks = {
        { 2,1 , 1,242},
        { 2,2 , 1,241},
        { 1,1 , 2,242},
    },
}

Test { [[
input/output [0] (int max)=>int LINE do
    await 1s;
    return max * 2;
end
await 3s;
escape 1000;
]],[[
output/input [0] (int max)=>int LINE;
var int ret = 0;
par/and do
    var int v, err;
    (err,v) = request LINE => 10;
    ret = ret + v + err;
with
    var int v, err;
    (err,v) = request LINE => 20;
    ret = ret + v + err;
with
    var int v, err;
    (err,v) = request LINE => 30;
    ret = ret + v + err;
with
    await 1s500ms;
    var int v, err;
    (err,v) = request LINE => 40;
    ret = ret + v + err;
with
    await 1s500ms;
    var int v, err;
    (err,v) = request LINE => 50;
    ret = ret + v + err;
with
    await 1s500ms;
    var int v, err;
    (err,v) = request LINE => 60;
    ret = ret + v + err;
end
escape ret;
]],
    run = 1006,
    lnks = {
        { 2,1 , 1,242},
        { 2,2 , 1,241},
        { 1,1 , 2,242},
    },
}

Test { [[
input/output [1] (int max)=>int LINE do
    await 1s;
    return max * 2;
end
await 3s;
escape 1000;
]],[[
output/input [1] (int max)=>int LINE;
var int ret = 0;
par/or do
    var int v, err;
    (err,v) = request LINE => 10;
    ret = ret + v + err;
with
end
do
    var int v, err;
    (err,v) = request LINE => 20;
    ret = ret + v + err;
end
escape ret;
]],
    run = 1040,
    lnks = {
        { 2,1 , 1,242},
        { 2,2 , 1,241},
        { 1,1 , 2,242},
    },
}

Test { [[
input/output [2] (int max)=>int LINE do
    await 1s;
    return max * 2;
end
await 3s;
escape 1000;
]],[[
output/input [2] (int max)=>int LINE;
var int ret = 0;
par/and do
    var int v, err;
    (err,v) = request LINE => 10;
    ret = ret + v + err;
with
    par/or do
        var int v, err;
        (err,v) = request LINE => 20;
        ret = ret + v + err;
    with
    end
    par/and do
        var int v, err;
        (err,v) = request LINE => 30;
        ret = ret + v + err;
    with
        var int v, err;
        (err,v) = request LINE => 40;
        ret = ret + v + err;
    end
end
escape ret;
]],
    run = 1081,
    lnks = {
        { 2,1 , 1,242},
        { 2,2 , 1,241},
        { 1,1 , 2,242},
    },
}
