Errors
======

Pointer attributions (11xx)
---------------------------

### 1101 : *wrong operator*

Use of the unsafe operator ":=" for non-pointer attributions.

Instead, use `=`.

Example:

<pre><code><b>var int</b> v := 1;

>>> ERR [1101] : file.ceu : line 1 : wrong operator
</code></pre>

### 1102 : *attribution does not require "finalize"*

Use of `finalize` for non-pointer attributions.

Instead, do not use `finalize`.

Example:

<pre><code><b>var int</b> v;
<b>finalize</b>
    v = 1;
<b>with</b>
    <...>
<b>end</b>

>>> ERR [1102] : file.lua : line 3 : attribution does not require "finalize"
</code></pre>

### 1103 : *wrong operator*

Use of the unsafe operator `:=` for constant pointer attributions.

Instead, use `=`.

Example:

<pre><code><b>var int</b> ptr := null;

>>> ERR [1103] : file.ceu : line 1 : wrong operator
</code></pre>

### 1104 : *attribution does not require "finalize"*

Use of `finalize` for constant pointer attributions.

Instead, do not use `finalize`.

Example:

<pre><code><b>var int</b> ptr;
<b>finalize</b>
    ptr = null;
<b>with</b>
    <...>
<b>end</b>

>>> ERR [1104] : file.lua : line 3 : attribution does not require `finalize´
</code></pre>

### 1105 : *destination pointer must be declared with the "[]" buffer modifier*

Use of normal pointer `*` to hold pointer to acquired resource.

Instead, use `[]`.

Example:

<pre><code><b>var int</b>* ptr = _malloc();

>>> ERR [1105] : file.ceu : line 1 : destination pointer must be declared with the `[]´ buffer modifier
</code></pre>

### 1106 : *parameter must be "hold"*

Omit `@hold` annotation for function parameter held in the class or global.

Instead, annotate the parameter declaration with `@hold`.

Examples:

<pre><code><b>class</b> T <b>with</b>
    <b>var none</b>* ptr;
    <b>function</b> (<b>none</b>* v)=><b>none</b> f;
<b>do</b>
    <b>function</b> (<b>none</b>* v)=><b>none</b> f <b>do</b>
        ptr := v;
    <b>end</b>
<b>end</b>

>>> ERR [1106] : file.ceu : line 6 : parameter must be `hold´

/*****************************************************************************/

<b>native do</b>
    <b>none</b>* V;
<b>end</b>
<b>function</b> (<b>none</b>* v)=><b>none</b> f <b>do</b>
    _V := v;
<b>end</b>

>>> ERR [1106] : file.ceu : line 5 : parameter must be `hold´
</code></pre>

### 1107 : *pointer access across "await"*

Access to pointer across an `await` statement.
The pointed data may go out of scope between reactions to events.

Instead, don't do it. :)

(Or check if the pointer is better represented as a buffer pointer (`[]`).)

Examples:

<pre><code><b>event int</b>* e;
<b>var int</b>* ptr = <b>await</b> e;
<b>await</b> e;     // while here, what "ptr" points may go out of scope
<b>escape</b> *ptr;

>>> ERR [1107] : file.ceu : line 4 : pointer access across `await´

/*****************************************************************************/

<b>var int</b>* ptr = <...>;
<b>par/and do</b>
    <b>await</b> 1s;   // while here, what "ptr" points may go out of scope
<b>with</b>
    <b>event int</b>* e;
    ptr = <b>await</b> e;
<b>end</b>
<b>escape</b> *ptr;

>>> ERR [1107] : file.ceu : line 8 : pointer access across `await´
</code></pre>

### 1108 : *"finalize" inside constructor*

Use of `finalize` inside constructor.

Instead, move it to before the constructor or to inside the class.

Examples:

<pre><code><b>class</b> T <b>with</b>
    <b>var none</b>* ptr;
<b>do</b>
    <...>
<b>end</b>

<b>var</b> T t <b>with</b>
    <b>finalize</b>
        this.ptr = _malloc(10);
    <b>with</b>
        _free(this.ptr);
    <b>end</b>
<b>end</b>;

>>> ERR [1008] : file.ceu : line 7 : `finalize´ inside constructor

/*****************************************************************************/

<b>class</b> T <b>with</b>
    <b>var none</b>* ptr;
<b>do</b>
    <...>
<b>end</b>

<b>spawn</b> T <b>with</b>
    <b>finalize</b>
        this.ptr = _malloc(10);
    <b>with</b>
        _free(this.ptr);
    <b>end</b>
<b>end</b>;

>>> ERR [1008] : file.ceu : line 7 : `finalize´ inside constructor
</code></pre>

### 1109 : *call requires "finalize"*

Call missing `finalize` clause.

Call passes a pointer.
Function may hold the pointer indefinitely.
Pointed data goes out of scope and yields a dangling pointer.

Instead, `finalize` the call.

Example:

<pre><code><b>var char</b>[255] buf;
_enqueue(buf);

>>> ERR [1009] : file.ceu : line 2 : call requires `finalize´'
</code></pre>

### 1110 : *invalid "finalize"*

Call a function that does not require a `finalize`.

Instead, don't use it.

Example:

<pre><code>_f() <b>finalize with</b>
        <...>
     <b>end</b>;

>>> ERR [1010] : file.ceu : line 1 : invalid `finalize´
</code></pre>
