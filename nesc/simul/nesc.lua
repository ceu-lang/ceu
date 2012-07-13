local simul = require 'simul'

module((...), package.seeall)

setmetatable(_M, {__index=simul})

function app (app)
    app.defines = app.defines or {}
    app.defines.TOS_NODE_ID = app.defines.TOS_NODE_ID or 0
    app.name = app.name or 'node_'..app.defines.TOS_NODE_ID
    app.values = app.values or {}
    local vals = { 'Radio_start',  'Radio_startDone',
                   'Serial_start', 'Serial_startDone',
                   'Photo_read',   'Photo_readDone',
                   'Temp_read',    'Temp_readDone',   }
    for _, k in ipairs(vals) do
        app.values[k] = app.values[k] or {}
    end

    local VALS = 'C do /******/\n'
    for k, t in pairs(app.values) do
        VALS = VALS .. '#define CEU_SEQN_'..k..' '..#t..'\n'
        VALS = VALS .. '#define CEU_SEQV_'..k..' {'..table.concat(t,',')..'}\n'
    end
    VALS = VALS .. '/******/ end\n'

    app.source = [[
/*{-{*/
]] .. VALS .. [[
C do
    #include "IO.h"
    #include "tinyos.c"
end
_srand(_time(_NULL)+_TOS_NODE_ID);
/*}-}*/
]] .. app.source

    local app = simul.app(app)
    return app
end

function topology (T)
    for n1, t in pairs(T) do
        assert(n1.io.OUT_Radio_send, n1.name..' has no Radio_send event')
        for _, n2 in ipairs(t) do
            assert(n2.io.IN_Radio_receive, n2.name..' has no Radio_receive event')
            simul.link(n1,'OUT_Radio_send',  n2,'IN_Radio_receive')
        end
    end
end
