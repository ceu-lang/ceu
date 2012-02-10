define(`BUFFER', `-- $1=name, $2=type, $3=len
(   -- Initialization
$2   $1_ins, $1_rem ;
void $1_inc, $1_dec ;
int  $1_overflow = 0;
int  $1_underflow = 0;
int  $1_n = 0;
do
    $2[$3] buf ;
    int in = 0;
    int out = 0;

    par/and do  -- Insertion
        loop do
            await $1_ins ;
            if $1_n == $3 then
                emit $1_overflow=1;
            else
                buf[in] = $1_ins;
                in = (in+1) % $3;
                $1_n = $1_n + 1;
                emit $1_inc;
            end;
        end;

    with        -- Removal
        loop do
            await $1_rem ;
            if $1_n == 0 then
                emit $1_underflow=1;
            else
                $1_rem = buf[out];
                out = (out+1) % $3;
                $1_n = $1_n - 1;
                emit $1_dec;
            end;
        end;
    end;
end;
')
