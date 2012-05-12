/*{-{*/

C do
    void bm_clear (u8* map, int len) {
        memset(map, 0, len/8);
    }

    int bm_idx (int pos) {
        return pos/8;
    }
    int bm_bit (int pos) {
        return pos%8;
    }

    int bm_get (u8* map, int pos) {
        return map[bm_idx(pos)]>>bm_bit(pos) &1;
    }

    void bm_on (u8* map, int pos) {
        map[bm_idx(pos)] = map[bm_idx(pos)] | 1<<bm_bit(pos);
    }

    void bm_off (u8* map, int pos) {
        map[bm_idx(pos)] = map[bm_idx(pos)] & ~(1<<bm_bit(pos));
    }

    void bm_or (u8* dst, u8* src, int len) {
        int i;
        for (i=0; i<len/8; i++)
            dst[i] |= src[i];
    }

    int bm_isZero (u8* map, int len) {
        int i;
        for (i=0; i<len/8; i++)
            if (map[i])
                return 0;
        return 1;
    }

    void bm_tostr (u8* map, int len, char* str) {
        int i;
        for (i=0; i<len; i++)
            str[i] = '0' + bm_get(map,i);
        str[len] = '\0';
    }
end

pure _bm_idx, _bm_bit, _bm_isZero, _bm_tostr;

/*}-}*/dnl
