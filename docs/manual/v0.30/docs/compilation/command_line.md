## Command Line

The single command `ceu` is used for all compilation phases:

```
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
```

All phases are optional.
To enable a phase, the associated prefix must be enabled.
If two consecutive phases are enabled, the output of the preceding and the
input of the succeeding phases can be omitted.

Examples:

```
# Preprocess "user.ceu", and converts the output to "user.c"
$ ceu --pre --pre-input="user.ceu" --ceu --ceu-output="user.c"
```

```
# Packs "user.c", "types.h", and "main.c", compiling them to "app.out"
$ ceu --env --env-ceu=user.c --env-types=types.h --env-main=main.c \
      --cc --cc-output=app.out
```
