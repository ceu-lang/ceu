local simul = require 'simul'

module((...), package.seeall)

setmetatable(_M, {__index=simul})

function app (app)
    assert(app.defines and app.defines.TOS_NODE_ID,
            'missing `TOS_NODE_ID´')
    app.name = app.name or 'node_'..app.defines.TOS_NODE_ID
    app.values = app.values or {}
    local vals = { 'Radio_start', 'Radio_startDone',
                   'Photo_read',  'Photo_readDone',
                   'Temp_read',   'Temp_readDone',   }
    for _, k in ipairs(vals) do
        app.values[k] = app.values[k] or {}
    end

    local VALS = 'C do /******/\n'
    for k, t in pairs(app.values) do
        VALS = VALS .. '#define CEU_SEQN_'..k..' '..#t..'\n'
        VALS = VALS .. '#define CEU_SEQV_'..k..' {'..table.concat(t,',')..'}\n'
    end
    VALS = VALS .. '/******/ end\n'

    app.source = '/*{-{*/' .. VALS
                     ..'C do #include "tinyos.c" end\n'
              .. '/*}-}*/' .. app.source

    local app = simul.app(app)
    return app
end

function topology (T)
    for n1, t in pairs(T) do
        for _, n2 in ipairs(t) do
            simul.link(n1,'OUT_Radio_send',  n2,'IN_Radio_receive')
        end
    end
end
