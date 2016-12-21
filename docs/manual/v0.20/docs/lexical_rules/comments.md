## Comments

Céu provides C-style comments.

Single-line comments begin with `//` and run to end of the line.

Multi-line comments use `/*` and `*/` as delimiters.
Multi-line comments can be nested by using a different number of `*` as
delimiters.

Examples:

```ceu
var int a;    // this is a single-line comment

/** comments a block that contains comments

var int a;
/* this is a nested multi-line comment
a = 1;
*/

**/
```
