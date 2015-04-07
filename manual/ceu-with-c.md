Interfacing Céu with C
======================

## Basics

## Annotations

## Pointers

## Resources

Some native calls manipulate external resources such as files and sockets.
Typically, these calls allocate system memory that has to be properly 
deallocated after use:
    - A constructor call returns a handler or opaque pointer to the resource.
    - During use, this handler is passed to auxiliary functions to manipulate 
      the resource.
    - After use, a destructor call releases the handler.

The manipulation of external resources in Céu rely on *option reference types* 
and *finalization blocks*.
The reference represents the resource and is seen as an opaque block of memory 
handled automatically by Céu.
The reference must be an option because the resource constructor may fail.
The finalization calls the destructor automatically when the reference goes out 
of scope.

As an example, the function `SDL_CreateWindow` creates a system window that has 
to be destroyed with `SDL_DestroyWindow` after use:

```
do
    var _SDL_Window&? win;                  // "win" is a local resource
    finalize
        win = _SDL_CreateWindow(...);       // acquires the resource
    with
        if win? then                        // tests if acquired
            _SDL_DestroyWindow(&win);       // destroys when "win" goes out of scope
        end
    end
    <...>
    <uses-of-win?-and-&win>
    <...>
end
```

Option types are type safe and all accesses to `win` are checked at runtime.

Note that external calls to manipulate the resource use the `&` to convert the 
reference back to a pointer as expected by C.

<!--
When an external pointer value in C is assigned to Céu,
strong reference
When a variable in Céu is assigned External values from C must
    var _SDL_Texture[] tex = _TEX_DOWN;

Pointer from C => Céu:

    - invalid across reactions
        var <_t> v* = <_C-VALUE-CALL>;
        every <E> do
            <use-v>;    // accesses across reactions to <E>
        end

    - a C pointer value can be managed by Céu through "option references":

        var _SDL_Window&? win;
        finalize
            win = _SDL_CreateWindow("Birds - 01 (class)", 200,200, 640,480, 0);
        with
            _SDL_DestroyWindow(&win);
        end

    - the accesss must be finalized to release the memory held by the pointer
    - it is the responsibility of the programmer to guarantee that the pointer 
      is valid during the whole scope of the respective variable in Céu


    - if "_SDL_CreateWindow" returns NULL, the option type is "NONE" and any 
      access to the respective variable in Céu will fail:
        - test with "?":
            if win? then
                <safe-access>
            else

    - "win" is an opaque reference, the original C pointer can be reacquired 
      with &win

    - the reference can be passed forward safely w/o the "?" respecting the 
      scope rules:
        class T with
            var _SDL_Window& win;
        do
            <uses-&win>;
        end
        <acquire-win>
        var T t with
            this.win = win;
        end;
-->
