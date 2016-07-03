CEU_VER = CEU_VER or '?'
CEU_GIT = CEU_GIT or '?'

if not RUNTESTS then
    local optparse = dofile 'optparse.lua'

    CEU = {}

    local help = [[
ceu ]]..CEU_VER..' ('..CEU_GIT..[[)

Usage: ceu [<options>] <file>...

Options:

    --help              display this help, then exit
    --version           display version information, then exit

    --pre               Preprocessor phase: preprocess Céu into Céu
    --pre-exe=FILE          preprocessor executable
    --pre-args=ARGS         preprocessor arguments
    --pre-input=FILE        input file to compile (Céu source)
    --pre-output=FILE       output file to generate (Céu source)

    --ceu               Céu phase: compiles Céu into C
    --ceu-input=FILE        input file to compile (Céu source)
    --ceu-output=FILE       output file to generate (C source)

    --env               Environment phase: packs all C files together
    --env-header=FILE       header file with declarations (C source)
    --env-ceu=FILE          output from Céu phase (C source)
    --env-main=FILE         source file with main function (C source)
    --env-output=FILE       output file to generate (C source)

    --c                 C phase: compiles C into binary
    --c-exe=FILE            C compiler executable
    --c-args=ARGS           compiler arguments
    --c-input=FILE          input file to compile (C source)
    --c-output=FILE         output file to generate (binary)

  -b                       a short option with no long option
      --long               a long option with no short option
      --another-long       a long option with internal hypen
      --true               a Lua keyword as an option name
  -v, --verbose            a combined short and long option
  -n, --dryrun, --dry-run  several spellings of the same option
  -u, --name=USER          require an argument
  -o, --output=[FILE]      accept an optional argument
  --                       end of options

http://www.ceu-lang.org/

Please report bugs at <http://github.com/fsantanna/ceu/issues>.
]]

    local parser = optparse(help)
    local arg, opts = parser:parse(_G.arg)
--[[
    print'------'
    for k,v in pairs(arg) do
        print(k,v)
    end
    print'------'
    for k,v in pairs(opts) do
        print(k,v)
    end
    print'------'
]]

    CEU.help = help
    CEU.arg  = arg
    CEU.opts = opts
end

for i,v in pairs(CEU.arg) do
    DBG(CEU.help)
    ASR(false, 'invalid option "'..v..'"')
end

local function check_no (pre)
    for k,v in pairs(CEU.opts) do
        ASR(not string.find(k, '^'..pre..'_'),
            'invalid option "'..k..'" : '..
            'expected option "'..pre..'"')
    end
end

if CEU.opts.pre then
    CEU.opts.pre_exe  = CEU.opts.pre_exe  or 'cpp'
    CEU.opts.pre_args = CEU.opts.pre_args or ''
    ASR(CEU.opts.pre_input,  'pre_input')
    ASR(CEU.opts.pre_output, 'pre_output')
else
    check_no('pre')
end

if CEU.opts.ceu then
    ASR(CEU.opts.ceu_input,  'ceu_input')
    ASR(CEU.opts.ceu_output, 'ceu_output')
else
    check_no('ceu')
end

if CEU.opts.env then
    ASR(CEU.opts.env_header, 'env_header')
    ASR(CEU.opts.env_ceu,    'env_ceu')
    ASR(CEU.opts.env_main,   'env_main')
    ASR(CEU.opts.env_output, 'env_output')
else
    check_no('env')
end

if CEU.opts.c then
    CEU.opts.c_exe  = CEU.opts.c_exe  or 'gcc'
    CEU.opts.c_args = CEU.opts.c_args or ''
else
    check_no('c')
end
