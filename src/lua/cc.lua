--DBG(CEU.opts.cc_exe..' -xc '..CEU.opts.cc_input..' '..  '-o '..CEU.opts.cc_output..' '..  CEU.opts.cc_args..' 2>&1')
local cc = CEU.opts.cc_exe..' -xc '..CEU.opts.cc_input..' '..
            '-o '..CEU.opts.cc_output..' '..
            CEU.opts.cc_args..' 2>&1'
local f = io.popen(cc)
local err = f:read'*a'
local ok = f:close()
ASR(ok, err)
