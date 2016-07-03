-- "-C":  keep comments (because of nesting)
-- "-dD": repeat #define's (because of macros used as C functions)
local f = io.popen(CEU.opts.pre_exe..' -C -dD '..CEU.opts.pre_args..
            ' '..CEU.opts.pre_input..' -o '..CEU.opts.pre_output..' 2>&1')
local err = f:read'*a'
ASR(f:close(), err)
