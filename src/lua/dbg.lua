-- Lua 5.3
unpack     = unpack     or table.unpack
loadstring = loadstring or load

-------------------------------------------------------------------------------

function DBG1 (...)
    local t = {}
    for i=1, select('#',...) do
        t[#t+1] = tostring( select(i,...) )
    end
    if #t == 0 then
        t = { [1]=debug.traceback() }
    end
    io.stderr:write(table.concat(t,'\t')..'\n')
end

function ASR1 (cond, msg)
    if cond then
        return cond
    end
    if TESTS then
        return assert(false, msg)
                -- TODO: error(msg) ???
    else
        DBG('>>> ERROR : '..msg)
        os.exit(1)
    end
end

-------------------------------------------------------------------------------

function DBG2 (...)
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

    if TESTS_file and tonumber(code)>1100 then
        TESTS_file:write([[
==============
]]..msg..[[

--------------
]]..T[1]..[[
--------------
]]..debug.traceback()..[[

==============
]])
    end

    DBG2('WRN ['..code..'] : '..ln[1]..' : line '..ln[2]..' : '..msg)
    return cond
end
function ASR2 (cond, ln, code, msg, extra)
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

    if TESTS_file and tonumber(code)>1100 then
        TESTS_file:write([[
==============
]]..msg..[[

--------------
]]..T[1]..[[
--------------
]]..debug.traceback()..[[
==============
]])
    end

    if TESTS then
        return assert(false, msg)
                -- TODO: error(msg) ???
    else
        DBG2(msg)
        os.exit(1)
    end
end

local pass = function () end
function ASR_WRN_PASS (v)
    if v == 'error' then
        return ASR
    elseif v == 'warning' then
        return WRN
    else
        assert(v == 'pass')
        return pass
    end
end

function ASR_WRN_PASS_MIN (f1, f2)
    if f1==pass or f2==pass then
        return pass
    elseif f1==WRN or f2==WRN then
        return WRN
    else
        return ASR
    end
end
