PAK = PAK or {
    ceu_ver = '?',
    ceu_git = '?',
}

if not TESTS then
    CEU = {}

    local help = [[
ceu ]]..PAK.ceu_ver..' ('..PAK.ceu_git..[[)

Usage: ceu [<options>] <file>...

Options:

    --help                          display this help, then exit
    --version                       display version information, then exit

    --pre                           Preprocessor phase: preprocess Céu into Céu
    --pre-exe=FILE                      preprocessor executable
    --pre-args=ARGS                     preprocessor arguments
    --pre-input=FILE                    input file to compile (Céu source)
    --pre-output=FILE                   output file to generate (Céu source)

    --ceu                           Céu phase: compiles Céu into C
    --ceu-input=FILE                    input file to compile (Céu source)
    --ceu-output=FILE                   output source file to generate (C source)
    --ceu-line-directives=BOOL          insert `#line` directives in the C output (default `true`)

    --ceu-features-trace=BOOL           enable trace support (default `false`)
    --ceu-features-exception=BOOL       enable exceptions support (default `false`)
    --ceu-features-dynamic=BOOL         enable dynamic allocation support (default `false`)
    --ceu-features-pool=BOOL            enable pool support (default `false`)
    --ceu-features-lua=BOOL             enable `lua` support (default `false`)
    --ceu-features-thread=BOOL          enable `async/thread` support (default `false`)
    --ceu-features-isr=BOOL             enable `async/isr` support (default `false`)
    --ceu-features-pause=BOOL           enable `pause/if` support (default `false`)

    --ceu-err-unused=OPT                effect for unused identifier: error|warning|pass
    --ceu-err-unused-native=OPT                    unused native identifier
    --ceu-err-unused-code=OPT                      unused code identifier
    --ceu-err-uninitialized=OPT         effect for uninitialized variable: error|warning|pass
    --ceu-err-uncaught-exception=OPT    effect for uncaught exception: error|warning|pass
    --ceu-err-uncaught-exception-main=OPT   ... at the main block (outside `code` abstractions)
    --ceu-err-uncaught-exception-lua=OPT    ... from Lua code

    --env                           Environment phase: packs all C files together
    --env-types=FILE                    header file with type declarations (C source)
    --env-threads=FILE                  header file with thread declarations (C source)
    --env-ceu=FILE                      output file from Céu phase (C source)
    --env-main=FILE                     source file with main function (C source)
    --env-output=FILE                   output file to generate (C source)

    --cc                            C phase: compiles C into binary
    --cc-exe=FILE                       C compiler executable
    --cc-args=ARGS                      compiler arguments
    --cc-input=FILE                     input file to compile (C source)
    --cc-output=FILE                    output file to generate (binary)

http://www.ceu-lang.org/

Please report bugs at <http://github.com/fsantanna/ceu/issues>.
]]

--[[
  -b                       a short option with no long option
      --long               a long option with no short option
      --another-long       a long option with internal hypen
      --true               a Lua keyword as an option name
  -v, --verbose            a combined short and long option
  -n, --dryrun, --dry-run  several spellings of the same option
  -u, --name=USER          require an argument
  -o, --output=[FILE]      accept an optional argument
  --                       end of options
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
        local kk = string.gsub(k,'_','-')
        ASR(not string.find(k, '^'..pre..'_'),
            'invalid option "'..kk..'" : '..
            'expected option "'..pre..'"')
    end
end

if not (CEU.opts.pre or CEU.opts.ceu or CEU.opts.env or CEU.opts.cc) then
    DBG(CEU.help)
    ASR(false, 'expected some option')
end

if CEU.opts.pre then
    CEU.opts.pre_exe  = CEU.opts.pre_exe  or 'cpp'
    CEU.opts.pre_args = CEU.opts.pre_args or ''
    ASR(CEU.opts.pre_input, 'expected option `pre-input`')
    CEU.opts.pre_output = CEU.opts.pre_output or '-'
else
    check_no('pre')
end

do
    local function toboolean (v)
        if v == 'true' then
            return true
        elseif v == 'false' then
            return false
        end
        return nil
    end

    local T = {
        ceu_output             = { tostring,  '-'     },
        ceu_line_directives    = { toboolean, 'true'  },
        ceu_features_trace     = { toboolean, 'false' },
        ceu_features_exception = { toboolean, 'false' },
        ceu_features_dynamic   = { toboolean, 'false' },
        ceu_features_pool      = { toboolean, 'false' },
        ceu_features_lua       = { toboolean, 'false' },
        ceu_features_thread    = { toboolean, 'false' },
        ceu_features_isr       = { toboolean, 'false' },
        ceu_features_pause     = { toboolean, 'false' },

        env_output             = { tostring,  '-'     },
    }

    for k, t in pairs(T) do
        local tp, v = unpack(t)
        local pre = string.match(k, '^(.-)_')
        if CEU.opts[pre] then
            v = tp(CEU.opts[k] or v)
            ASR(v ~= nil, 'invalid value for option "'..k..'"')
            CEU.opts[k] = v
        end
    end
end

if CEU.opts.ceu then
    if CEU.opts.pre then
        if CEU.opts.ceu_input then
            ASR(CEU.opts.ceu_input == CEU.opts.pre_output,
                "`pre-output` and `ceu-input` don't match")
        else
            if CEU.opts.pre_output == '-' then
                CEU.opts.pre_output = os.tmpname()
            end
            CEU.opts.ceu_input = CEU.opts.pre_output
        end
    end
    ASR(CEU.opts.ceu_input, 'expected option `ceu-input`')

    if CEU.opts.ceu_features_exception then
        --ASR(CEU.opts.ceu_features_trace, 'expected option `ceu-features-trace`')
    end
    if CEU.opts.ceu_features_lua or CEU.opts.ceu_features_thread then
        ASR(CEU.opts.ceu_features_dynamic, 'expected option `ceu-features-dynamic`')
    end
else
    check_no('ceu')
end

if CEU.opts.env then
    if not CEU.opts.ceu then
        ASR(not CEU.opts.pre, 'expected option `ceu`')
    end

    ASR(CEU.opts.env_types,   'expected option `env-types`')
    --ASR(CEU.opts.env_threads, 'expected option `env-threads`')
    --ASR(CEU.opts.env_main,    'expected option `env-main`')

    if CEU.opts.ceu then
        if CEU.opts.env_ceu then
            ASR(CEU.opts.env_ceu == CEU.opts.ceu_output,
                "`ceu-output` and `env-ceu` don't match")
        else
            if CEU.opts.ceu_output == '-' then
                CEU.opts.ceu_output = os.tmpname()
            end
            CEU.opts.env_ceu = CEU.opts.ceu_output
        end
    end
    ASR(CEU.opts.env_ceu, 'expected option `env-ceu`')
else
    check_no('env')
end

if CEU.opts.cc then
    if not CEU.opts.env then
        ASR(not CEU.opts.pre, 'expected option `env`')
        ASR(not CEU.opts.ceu, 'expected option `env`')
    end

    CEU.opts.cc_exe  = CEU.opts.cc_exe  or 'gcc'
    CEU.opts.cc_args = CEU.opts.cc_args or ''

    if CEU.opts.env then
        if CEU.opts.cc_input then
            ASR(CEU.opts.cc_input == CEU.opts.env_output,
                "`env-output` and `cc-input` don't match")
        else
            if CEU.opts.env_output == '-' then
                CEU.opts.env_output = os.tmpname()
            end
            CEU.opts.cc_input = CEU.opts.env_output
        end
    end
    ASR(CEU.opts.cc_input, 'expected option `cc-input`')

    ASR(CEU.opts.cc_output, 'expected option `cc-output`')
else
    check_no('cc')
end
