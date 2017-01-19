## Command Line

<!--
Céu provides a command line compiler that generates C code for a given input program.
The compiler is independent of the target platform.

The generated C output should be included in the main application, and is supposed to be integrated with the specific platform through the presented [[#sec.env.api|API]].
-->

`TODO`

The command line options for the compiler are as follows:

```
Usage: ceu [<options>] <file>...

Options:

    --help                      display this help, then exit
    --version                   display version information, then exit

    --pre                       Preprocessor phase: preprocess Céu into Céu
    --pre-exe=FILE                  preprocessor executable
    --pre-args=ARGS                 preprocessor arguments
    --pre-input=FILE                input file to compile (Céu source)
    --pre-output=FILE               output file to generate (Céu source)

    --ceu                       Céu phase: compiles Céu into C
    --ceu-input=FILE                input file to compile (Céu source)
    --ceu-output=FILE               output source file to generate (C source)
    --ceu-line-directives=BOOL      insert `#line´ directives in the C output

    --ceu-features-lua=BOOL         enable `lua´ support
    --ceu-features-thread=BOOL      enable `async/thread´ support
    --ceu-features-isr=BOOL         enable `async/isr´ support

    --ceu-err-unused=OPT            effect for unused identifier: error|warning|pass
    --ceu-err-unused-native=OPT                unused native identifier
    --ceu-err-unused-code=OPT                  unused code identifier
    --ceu-err-uninitialized=OPT     effect for uninitialized variable: error|warning|pass

    --env                       Environment phase: packs all C files together
    --env-types=FILE                header file with type declarations (C source)
    --env-threads=FILE              header file with thread declarations (C source)
    --env-ceu=FILE                  output file from Céu phase (C source)
    --env-main=FILE                 source file with main function (C source)
    --env-output=FILE               output file to generate (C source)

    --cc                        C phase: compiles C into binary
    --cc-exe=FILE                   C compiler executable
    --cc-args=ARGS                  compiler arguments
    --cc-input=FILE                 input file to compile (C source)
    --cc-output=FILE                output file to generate (binary)
```
