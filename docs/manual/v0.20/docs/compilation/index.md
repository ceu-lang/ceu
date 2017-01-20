# Compilation

The compiler converts an input program in Céu to an output in C, which is
further embedded in an [environment](#TODO) satisfying a [C API](#TODO), which
is finally compiled to an executable:

![](compilation.png)

{!compilation/command_line.md!}
{!compilation/c_api.md!}
