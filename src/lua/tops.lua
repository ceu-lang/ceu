TOPS = {
--[[
    [id] = node + {
        id      = <string>,
        is_num  = true | false,
        is_used = ...,
    },
]]
}

-- Primitive types: id / is_num
do
    local prims = {
        bool  = { is_num=false, is_int=false },
        byte  = { is_num=true,  is_int=true  },
        f32   = { is_num=true,  is_int=false },
        f64   = { is_num=true,  is_int=false },
        float = { is_num=true,  is_int=false },
        int   = { is_num=true,  is_int=true  },
        s16   = { is_num=true,  is_int=true  },
        s32   = { is_num=true,  is_int=true  },
        s64   = { is_num=true,  is_int=true  },
        s8    = { is_num=true,  is_int=true  },
        ssize = { is_num=true,  is_int=true  },
        u16   = { is_num=true,  is_int=true  },
        u32   = { is_num=true,  is_int=true  },
        u64   = { is_num=true,  is_int=true  },
        u8    = { is_num=true,  is_int=true  },
        uint  = { is_num=true,  is_int=true  },
        usize = { is_num=true,  is_int=true  },
        void  = { is_num=false, is_int=false },
        null  = { is_num=false, is_int=false },
        _     = { is_num=true,  is_int=true  },
    }
    for id, t in pairs(prims) do
        TOPS[id] = {
            tag   = 'Prim',
            id    = id,
            prim  = t,
            is_used = true,
        }
    end
end

-- native declarations are allowed until `native/end´
local native_end = false

local function tops_new (me)
    local old = TOPS[me.id]
    if old and (not old.is_predefined) then
        ASR(false, me,
            'identifier "'..me.id..'" is already declared'..
                ' ('..old.ln[1]..' : line '..old.ln[2]..')')
    end
    TOPS[me.id] = me
end

local function tops_use (me, id, tag)
    local top = TOPS[id]
    ASR(top and ((not tag) or top.tag==tag), me,
        (tag and AST.tag2id[tag] or 'abstraction')..' "'..id..'" is not declared')
    top.is_used = true
    return top
end

F = {

-- ID -> DCL

    ID_prim = function (me)
        local id = unpack(me)
        me.top = tops_use(me, id, 'Prim')
    end,
    ID_nat = function (me)
        local id = unpack(me)
        me.top = tops_use(me, id, 'Nat')
    end,
    ID_ext = function (me)
        local id = unpack(me)
        me.top = tops_use(me, id, 'Ext')
    end,
    ID_abs = function (me)
        local id = unpack(me)
        me.top = tops_use(me, id)
    end,

-- NATIVE

    Nat_End = function (me)
        native_end = true
    end,
    Nat__PRE = function (me)
        local _,_,id = unpack(me)
        me.id = id
        tops_new(me)

        ASR(not native_end, me,
            'native declarations are disabled')

        if id=='_@' or id=='_char' then
            me.is_predefined = true
        end
    end,

-- EXT

    Extcall_proto = 'Extcall_impl',
    Extcall_impl = function (me)
        local grp, _, id = unpack(me)
        me.id = id
        tops_new(me)
    end,

    Ext = function (me)
        local _, grp, id = unpack(me)
        me.id = id
        tops_new(me)
    end,

-- CODE / DATA

    Code = function (me)
        local _,_,id,_,_blk = unpack(me)
        me.id = id

        local top = TOPS[me.id]
        if (not top) or top.blk then
        --if not (top and top.blk) then
            tops_new(me)
            top = me
        end

        -- CHECK prototype
        if me ~= top then
            -- ...
        end
        if blk then
            assert(not top.blk)
            top.blk = blk
        end
    end,

    Data = function (me)
        local id = unpack(me)
        me.id = id
        tops_new(me)
    end,
}

AST.visit(F)

for _, top in pairs(TOPS) do
    if top.tag=='Data' and string.sub(top.id,1,1)=='_' then
        -- auto generated
    else
        WRN(top.is_used or top.is_predefined, top,
            AST.tag2id[top.tag]..' "'..top.id..'" declared but not used')
    end
end
