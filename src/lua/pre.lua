-- "-C":  keep comments (because of nesting)
-- "-dD": repeat #define's (because of macros used as C functions)
local f = io.popen(CEU.opts.pre_exe..' -C -dD '..CEU.opts.pre_args..
            ' '..CEU.opts.pre_input..' -o '..CEU.opts.pre_output..' 2>&1')
local out = f:read'*a'
ASR(f:close(), out)

-- remove "# <n> "<filename>"
if CEU.opts.ceu_line_directives == false then
    local f = assert(io.open(CEU.opts.pre_output))
    local str = f:read'*a'
    f:close()

    str = string.gsub(str, '\n# %d+[^\n]*\n', '\n')

    f = assert(io.open(CEU.opts.pre_output, 'w'))
    f:write(str)
    f:close()
end

if CEU.opts.pre_output == '-' then
    print(out)
end
