--DBG(CEU.opts.cc_exe..' -xc '..CEU.opts.cc_input..' '..  '-o '..CEU.opts.cc_output..' '..  CEU.opts.cc_args..' 2>&1')

-- TODO-TCO (see tests.lua:TODO-TCO)
-- Céu requires tail call elimination because of par/or inside loops
-- In gcc:
-- -foptimize-sibling-calls
-- What about other compilers? How to warn the user if not enabled?

local cc = CEU.opts.cc_exe..' -xc '..CEU.opts.cc_input..' '..
            '-o '..CEU.opts.cc_output..' '..
            CEU.opts.cc_args..' 2>&1'
local f = io.popen(cc)
local err = f:read'*a'
local ok = f:close()
ASR(ok, err)
DBG(err)
