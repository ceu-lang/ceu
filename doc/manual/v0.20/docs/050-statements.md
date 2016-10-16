Statements
==========

A program in Céu is a sequence of statements as follows:

```
Program ::= Stmts
Stmts   ::= {Stmt `;´} {`;´}
Block   ::= Stmts
```

*Note: statements terminated with the `end` keyword do not require a 
terminating semicolon.*

A `Block` creates a new scope for [variables](#TODO), which are only visible
for statements inside the block.

Compound statements (e.g. *if-then-else*, *loops*, etc.) create new blocks and 
can be nested for an arbitrary level.


      // Do ::=
      |  do [`/´(`_´|ID_int)]
             Block
         end
      |  escape [`/´ID_int] [Exp]

      /* pre (top level) execution */
      | pre do
            Block
        end


