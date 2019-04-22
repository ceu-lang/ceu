## Primary

`TODO`

### Outer

`TODO`

Example:

```ceu
var int x=0;

code/call Test(none)->none do
    outer.x = 1;
    var int x = 0;

    _printf("%d\n", outer.x); //prints 1
    _printf("%d\n", x);       //prints 0
end

call Test();
_printf("%d\n", x); //prints 1
```

<!--
outer, ID_var, ID_nat, null, NUM, String, true, false, 
call/call/rec/finalize, C, parens`
-->
