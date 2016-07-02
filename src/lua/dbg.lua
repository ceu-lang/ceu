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

function WRN (cond, ln, code, msg)
    if cond then
        return cond
    end

    if not tonumber(code) then
        code, msg, extra = '0000', code, msg
    end
    ln = (AST.is_node(ln) and ln.ln) or ln
    msg = 'WRN ['..code..'] : '..ln[1]..' : line '..ln[2]..' : '..msg

    if RUNTESTS_file and tonumber(code)>1100 then
        RUNTESTS_file:write([[
==============
]]..msg..[[

--------------
]]..T[1]..[[
--------------
]]..debug.traceback()..[[

==============
]])
    end

    DBG('WRN ['..code..'] : '..ln[1]..' : line '..ln[2]..' : '..msg)
    return cond
end
function ASR (cond, ln, code, msg, extra)
    if cond then
        return cond
    end

    if not tonumber(code) then
        code, msg, extra = '0000', code, msg
    end
    ln = (AST.is_node(ln) and ln.ln) or ln
    msg = 'ERR ['..code..'] : '..ln[1]..' : line '..ln[2]..' : '..msg
    if extra and OPTS.verbose then
        msg = msg..'\n'..extra
    end

    if RUNTESTS_file and tonumber(code)>1100 then
        RUNTESTS_file:write([[
==============
]]..msg..[[

--------------
]]..T[1]..[[
--------------
]]..debug.traceback()..[[
==============
]])
    end

    if RUNTESTS then
        return assert(false, msg)
                -- TODO: error(msg) ???
    else
        DBG(msg)
        os.exit(1)
    end
end
