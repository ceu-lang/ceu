function DBG (...)
    local t = {}
    for i=1, select('#',...) do
        t[#t+1] = tostring( select(i,...) )
    end
    if #t == 0 then
        t = { [1]=debug.traceback() }
    end
    io.stderr:write(table.concat(t,'\t')..'\n')
end

module((...), package.seeall)

QU = {
    LINK  = -1,
    TIME  = -10,
    ASYNC = -11,
}

local _n = 0
function N ()
    _n = _n + 1
    return _n
end

function file2string (str)
    local f = io.open(str)
    if f then
        return f:read'*a'
    end
    return str
end

local H = [[
C do
    /******/
    #include <stdarg.h>

    void MQ (int id, int v) {
        char buf[10];
        int len = 0;
        memcpy(buf, &id, sizeof(s16));
            len += sizeof(s16);
        memcpy(buf+len, &v, sizeof(int));
            len += sizeof(int);
        mq_send(ceu_mqueue_mqd, buf, len, 0);
    }

    void DBG (char *fmt, ... )
    {
        char tmp[128];
        va_list args;
        va_start(args, fmt);
        vsnprintf(tmp, 128, fmt, args);
        va_end(args);
        printf("[ %s ] %s", CEU_DBG, tmp);
    }
    /******/
end
]]

function app (app)
    app.start = _start
    app.kill  = _kill
    app.queue = app.queue or '/'..app.name..'_'..os.time()..'_'..N()

    app.files.include = file2string(app.files.include or '')
    app.files.source  = file2string(app.files.source)
    app.files.tmp     = '/tmp/ceu_'..N()..os.time()..'.ceu'

    local DEFS = [[
C do /******/
    #define CEU_DBG "]]..app.name..[["
]]
    for k, v in pairs(app.defines or {}) do
        DEFS = DEFS .. '#define '..k..' '..v..'\n'
    end
    DEFS = DEFS .. '/******/ end\n'
    app.files.include = DEFS .. H .. app.files.include

    f = assert(io.open(app.files.tmp, 'w'))
    f:write(app.files.include .. app.files.source)
    f:close()
    DBG('===> Compiling '..app.name..'...')
    assert(os.execute('./ceu '..app.files.tmp        ..
                        ' --output      _ceu_code.c'   ..
                        ' --events-file _ceu_events.h'
                     ) == 0)
    assert(os.execute('gcc -o '..app.files.exec..' main.c -lrt'))
    DBG('', 'tmp:',   app.files.tmp)
    DBG('', 'queue:', app.queue)

    app.io = {}
    local str = assert(io.open('_ceu_events.h')):read'*a'
    DBG('', 'inputs:')
    for evt, v in string.gmatch(str,'(IN_%u[^%s]*)%s+(%d+)\n') do
        app.io[evt] = v
        DBG('','',evt, v)
    end
    DBG('', 'outputs:')
    for evt, v in string.gmatch(str,'(OUT_%u[^%s]*)%s+(%d+)\n') do
        app.io[evt] = v
        DBG('','',evt, v)
    end

    assert(os.execute('./qu.exe create '..app.queue) == 0)

    return app
end

function link (app1,out, app2,inp)
    DBG('===> Linking '..app1.queue..'/'..out..' -> '..app2.queue..'/'..inp)
    os.execute('./qu.exe send '..app1.queue..' '..QU.LINK..' '..app1.io[out]
                          ..' '..app2.queue..' '..app2.io[inp])
end

function emit (app, inp, v)
    DBG('===> Emit '..app.queue..'/'..inp..'('..v..')')
    if inp > 0 then
        os.execute('./qu.exe send '..app.queue..' '..app.io[inp]..' '..v)
    else
        os.execute('./qu.exe send '..app.queue..' '..inp..' '..v)
    end
end

function _start (app)
    local exec = app.files.exec
    DBG('===> Executing '..app.name..'...')
    os.execute('./'..exec..' '..app.queue..'&')
end

function _kill (app)
    os.execute('killall '..app.files.exec)
end
