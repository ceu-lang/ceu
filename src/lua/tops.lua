TOPS = {
--[[
    [id] = node + {
        id    = <string>,
        group = 'primitive' | 'native' | 'data' | 'code'
              | 'input' | 'output' | ...,
        is_num = true | false,
        is_used = ...,
    },
]]
    _ = {
        id = '_',
        group = 'native',
        is_predefined = true,
    },
    _char = {
        id = '_char',
        group = 'native',
        is_predefined = true,
    },
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
    }
    for id, t in pairs(prims) do
        TOPS[id] = {
            id    = id,
            group = 'primitive',
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

local function tops_use (me, id, group)
    local top = ASR(TOPS[id], me,
                    group..' "'..id..'" is not declared')
    top.is_used = true
    return top
end

F = {

-- ID -> DCL

    ID_prim = function (me)
        local id = unpack(me)
        me.top = tops_use(me, id, 'primitive')
    end,
    ID_nat = function (me)
        local id = unpack(me)
        me.top = tops_use(me, id, 'native')
    end,
    ID_ext = function (me)
        local id = unpack(me)
        me.top = tops_use(me, id, 'external')
    end,
    ID_abs = function (me)
        local id = unpack(me)
        me.top = tops_use(me, id, 'abstraction')
    end,

-- NATIVE

    Nat_End = function (me)
        native_end = true
    end,
    Nat = function (me)
        local _,id = unpack(me)
        me.id    = id
        me.group = 'native'
        tops_new(me)

        ASR(not native_end, me,
            'native declarations are disabled')
    end,

-- EXT

    Extcall_proto = 'Extcall_impl',
    Extcall_impl = function (me)
        local grp, _, id = unpack(me)
        me.id    = id
        me.group = grp
        tops_new(me)
    end,

    Ext = function (me)
        local tp, grp, id = unpack(me)
        me.tp    = tp
        me.group = grp
        me.id    = id
        tops_new(me)
    end,

-- CODE / DATA

    Code_proto = function (me)
        local mod, is_rec, id, ins, out = unpack(me)
        me.id    = id
        me.group = 'code'
        tops_new(me)
    end,
    Code_impl = function (me)
        local mod, is_rec, id, ins, out, blk = unpack(me)
        me.id    = id
        me.group = 'code'

        local top = TOPS[id]
        if (not top) or top.blk then
            tops_new(me)
            top = me
        end

        -- CHECK prototype
        if me ~= top then
            -- ...
        end
        top.blk = blk
    end,

    Data = function (me)
        local id, super = unpack(me)
        me.id    = id
        me.group = 'data'
        tops_new(me)
    end,
}

AST.visit(F)

for _, top in pairs(TOPS) do
    if top.group=='data' and string.sub(top.id,1,1)=='_' then
        -- auto generated
    else
        WRN(top.is_used or top.is_predefined, top,
            top.group..' "'..top.id..' declared but not used')
    end
end
