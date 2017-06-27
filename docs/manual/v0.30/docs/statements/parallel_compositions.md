## Parallel Compositions

```ceu
Pars ::= (par | par/and | par/or) do
             Block
         with
             Block
         { with
             Block }
         end

Spawn ::= spawn [`(´ [LIST(ID_int)] `)´] do
              Block
          end

Watching ::= watching LIST(ID_ext|Loc|WCLOCKK|WCLOCKE|Code_Cons_Init) do
                 Block
             end
```

The parallel statements `par/and`, `par/or`, and `par` fork the running trail 
in multiple others.
They differ only on how trails rejoin and terminate the composition.

The `spawn` statement starts to execute a block in parallel with the enclosing
block.

The `watching` statement executes a block and terminates when one of its
specified events occur.

See also [Parallel Compositions and Abortion](../#parallel-compositions-and-abortion).

### par

The `par` statement never rejoins.

Examples:

```ceu
// reacts continuously to "1s" and "KEY_PRESSED" and never terminates
input void KEY_PRESSED;
par do
    every 1s do
        <...>           // does something every "1s"
    end
with
    every KEY_PRESSED do
        <...>           // does something every "KEY_PRESSED"
    end
end
```

### par/and

The `par/and` statement stands for *parallel-and* and rejoins when all nested
trails terminate.

Examples:

```ceu
// reacts once to "1s" and "KEY_PRESSED" and terminates
input void KEY_PRESSED;
par/and do
    await 1s;
    <...>               // does something after "1s"
with
    await KEY_PRESSED;
    <...>               // does something after "KEY_PRESSED"
end
```

### par/or

The `par/or` statement stands for *parallel-or* and rejoins when any of the 
trails terminate, aborting all other trails.

Examples:

```ceu
// reacts once to `1s` or `KEY_PRESSED` and terminates
input void KEY_PRESSED;
par/or do
    await 1s;
    <...>               // does something after "1s"
with
    await KEY_PRESSED;
    <...>               // does something after "KEY_PRESSED"
end
```

### spawn

The `spawn` statement starts to execute a block in parallel with the enclosing
block.
When the enclosing block terminates, the spawned block is aborted.

Like a [`do-end` block](#do-end-and-escape), a `spawn` also supports an
optional list of identifiers in parenthesis which restricts the visible
variables inside the block to those matching the list.

Examples:

```ceu
spawn do
    every 1s do
        <...>       // does something every "1s"...
    end
end

<...>               // ...in parallel with whatever comes next
```

### watching

A `watching` expands to a `par/or` with *n+1* trails:
one to await each of the listed events,
and one to execute its body, i.e.:

```ceu
watching <e1>,<e2>,... do
    <body>
end
```

expands to

```ceu
par/or do
    await <e1>;
with
    await <e2>;
with
    ...
with
    <body>
end
```

The `watching` statement accepts a list of events and terminates when any of
them occur.
It evaluates to what the occurring event value(s), which can be captured with
an optional [assignment](#assignments).

Examples:

```ceu
// reacts continuously to "KEY_PRESSED" during "1s"
input void KEY_PRESSED;
watching 1s do
    every KEY_PRESSED do
        <...>           // does something every "KEY_PRESSED"
    end
end
```
