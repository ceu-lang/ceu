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
    LINK   = -1,
    UNLINK = -2,
    TIME   = -10,
    ASYNC  = -11,
}

local H = [[
C do
    /******/
    #include <stdarg.h>

    int MQ (int id, int v) {
        char buf[10];
        int len = 0;
        memcpy(buf, &id, sizeof(s16));
            len += sizeof(s16);
        memcpy(buf+len, &v, sizeof(int));
            len += sizeof(int);
        return mq_send(ceu_mqueue_mqd, buf, len, 0);
    }

    void DBG (char *fmt, ... )
    {
        char tmp[1024];
        va_list args;
        va_start(args, fmt);
        vsnprintf(tmp, 1024, fmt, args);
        va_end(args);
        printf("[ %s ] %s", CEU_DBG, tmp);
    }
    /******/
end
]]

APPS = {}

function app (app)
    assert(app.name,   'missing `name´')
    assert(app.source, 'missing `source´')

    app._name = string.gsub(app.name, '%s', '_')
    assert(not APPS[app._name], 'duplicate `name´')
    APPS[app._name] = app

    app._exe   = app._name .. '.exe'
    app._ceu   = '_'..app._name..'.ceu'
    app._queue = app._queue or '/'..app._name

    app.start = _start
    app.kill  = _kill

    local M4 = ''
    local DEFS = [[
C do /******/
    #define CEU_DBG "]]..app._name..[["
]]
    for k, v in pairs(app.defines or {}) do
        DEFS = DEFS .. '#define '..k..' '..v..'\n'
        M4 = M4 .. ' -D '..k..'='..v
    end
    DEFS = DEFS .. '/******/ end\n'

    app.source = '/*{-{*/' .. DEFS
                     .. H
              .. '/*}-}*/' .. app.source

    f = assert(io.open(app._ceu, 'w'))
    f:write(app.source)
    f:close()
    DBG('===> Compiling '..app._ceu..' (NO DFA!)...')
    assert(os.execute('./ceu '..app._ceu
                        --.. ' --dfa-viz'
                        .. ' --m4-args "'..M4..'"'
                        .. ' --output _ceu_code.c'
                        .. ' --events-file _ceu_events.h'
                     ) == 0)
    assert(os.execute('gcc -o '..app._exe..' main.c -lrt')==0)

    DBG('', 'queue:', app._queue)

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

    assert(os.execute('./qu.exe create '..app._queue) == 0)

    return app
end

function link (app1,out, app2,inp)
    DBG('===> Linking '..app1._queue..'/'..out..' -> '..app2._queue..'/'..inp)
    os.execute('./qu.exe send '..app1._queue..' '..QU.LINK..' '..app1.io[out]
                          ..' '..app2._queue..' '..app2.io[inp])
end

function unlink (app1,out, app2,inp)
    DBG('===> Unlinking '..app1._queue..'/'..out..' -> '..app2._queue..'/'..inp)
    os.execute('./qu.exe send '..app1._queue..' '..QU.UNLINK..' '..app1.io[out]
                          ..' '..app2._queue..' '..app2.io[inp])
end

function emit (app, inp, v)
    local evt = app.io[inp] or inp
    DBG('===> Emit '..app._queue..'/'..inp..'['..evt..']('..v..')')
    os.execute('./qu.exe send '..app._queue..' '..evt..' '..v)
end

function _start (app)
    DBG('===> Executing '..app.name..'...')
    os.execute('./'..app._exe..' '..app._queue..'&')
end

function _kill (app)
    os.remove('/dev/mqueue/'..app._queue)
    os.remove(app._ceu)
    os.execute('killall '..app._exe)
end

function shell (start)
    start = start~=false
    if start then
        for name, app in pairs(APPS) do
            app:start()
        end
    end

    while true do
        io.write('> ' )
        local str = io.read()
        local cmd, p1, p2, p3, p4 = string.match(str, '(%S*) ?(%S*) ?(%S*) ?(%S*) ?(%S*)')

        if cmd == 'quit' then
            break

        elseif cmd == 'start' then
            APPS[p1]:start()

        elseif cmd == 'kill' then
            APPS[p1]:kill()

        elseif cmd == 'emit' then
            emit(APPS[p1], p2, p3)

        elseif cmd == 'link' then
            link(APPS[p1],p2, APPS[p3],p4)

        elseif cmd == 'unlink' then
            unlink(APPS[p1],p2, APPS[p3],p4)

        else
            print('invalid command: "'..cmd..'" (type "quit" to terminate)')
        end
    end

    for name, app in pairs(APPS) do
        app:kill()
    end
end
