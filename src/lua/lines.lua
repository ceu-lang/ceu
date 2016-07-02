m = require 'lpeg'
m.setmaxstack(1000)

local LINE = 1
local FILE = OPTS.input
local patt

LINES = {
    i2l = {},
}

local line = m.Cmt('\n',
    function (s,i)
        for i=#LINES.i2l, i do
            LINES.i2l[i] = { FILE, LINE }
        end
        LINE = LINE + 1
        return true
    end )

local S = (m.S'\t\r ' + m.P'\\'*(1-m.P'\n')^0*'\n')
local SS = S^0

-- #line N "file" :: directive to set line/filename
local dir_lins = m.Cmt( m.P'#' *SS* m.P'line'^-1
                          *SS* m.C(m.R'09'^1)             -- line
                          *SS* ( m.P'"' * m.C((1-m.P'"')^0) * m.P'"'
                              + m.Cc(false) )            -- file
                          * (S + (m.P(1)-'\n'))^0 * '\n' -- \n
                 ,
    function (s,i, line, file)
        LINE = tonumber(line)
        FILE = file
        return true
    end )

patt = (line + dir_lins + 1)^0

-- pre-append extra line to match #
OPTS.source = '\n#line 1 "'..OPTS.input..'"\n'..OPTS.source

if OPTS.cpp or OPTS.cpp_args then
    local args = OPTS.cpp_args or ''
    if OPTS.timemachine then
        args = args .. ' -DCEU_TIMEMACHINE'
    end
    local orig = (OPTS.input=='-' and 'tmp.ceu')
                    or OPTS.input
    local base, name = string.match(orig, '(.*/)(.*)')
    if not base then
        base = ''
        name = orig
    end

    -- fin, fout, ferr
    local fout = OPTS.out_dir..'/_ceu_cpp_'..name
    local ferr = fout..'.err'
    local fin  = fout..'.in'
    local f = assert( io.open(fin,'w') )
    f:write(OPTS.source)
    f:close()

    -- execute cpp
    local ret = os.execute(OPTS.cpp_exe..' -C -dD '..args..' '..fin
                            ..' > '..fout..' 2>'..ferr)
            -- "-C":  keep comments (because of nesting)
            -- "-dD": repeat #define's (because of macros used as C functions)
    os.remove(fin)
    assert(ret == 0 or ret == true, assert(io.open(ferr)):read'*a')
    os.remove(ferr)

    -- pre-append extra line to match #
    -- remove blank lines of #define's (because of "-dD")
    OPTS.source = '\n'..assert(io.open(fout)):read'*a'
    --OPTS.source = string.gsub(OPTS.source, '(#define[^\n]*)(\n)(\n)', '%1%3')
    os.remove(fout)
    --print(OPTS.source)
end

patt:match(OPTS.source..'\n')
