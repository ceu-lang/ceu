local simul = require 'simul'

module((...), package.seeall)

setmetatable(_M, {__index=simul})

local H = [[
C do
    /******/

    #define nx_struct struct

    typedef s8  nx_int8_t;
    typedef u8  nx_uint8_t;
    typedef s16 nx_int16_t;
    typedef u16 nx_uint16_t;
    typedef u16 nxle_uint16_t;
    typedef s32 nx_int32_t;
    typedef u32 nx_uint32_t;

    typedef u8  am_id_t;
    typedef u16 am_addr_t;
    typedef u8  am_group_t;
    typedef u8  nx_am_id_t;
    typedef u16 nx_am_addr_t;
    typedef u8  nx_am_group_t;

    #define SUCCESS 0

    #define TOSH_DATA_LENGTH 28
    #define TOS_BCAST_ADDR 0xFFFF

    typedef nx_struct {
        nx_am_addr_t dest;
        nx_am_addr_t src;
        nx_uint8_t length;
        nx_am_group_t group;
        nx_am_id_t type;
    } radio_header_t;

    typedef nx_struct {
        nxle_uint16_t crc;
    } radio_footer_t;

    typedef nx_struct {
        nx_int8_t strength;
        nx_uint8_t ack;
        nx_uint16_t time;
    } radio_metadata_t;

/*
    typedef nx_struct serial_header {
        nx_am_addr_t dest;
        nx_am_addr_t src;
        nx_uint8_t length;
        nx_am_group_t group;
        nx_am_id_t type;
    } serial_header_t;

    typedef nx_struct serial_packet {
        serial_header_t header;
        nx_uint8_t data[];
    } serial_packet_t;

    typedef nx_struct serial_metadata {
        nx_uint8_t ack;
    } serial_metadata_t;
*/

    typedef union message_header {
        radio_header_t  radio;
        //serial_header_t serial;
    } message_header_t;

    typedef union message_footer {
        radio_footer_t radio;
    } message_footer_t;

    typedef union message_metadata {
        radio_metadata_t radio;
    } message_metadata_t;

    typedef nx_struct message_t {
        message_header_t   header;
        nx_uint8_t         data[TOSH_DATA_LENGTH];
        message_footer_t   footer;
        message_metadata_t metadata;
    } message_t;

    /* RADIO */

    int Radio_start ()
    {
        static int v1[] = CEU_SEQV_Radio_start;
        static int n1 = 0;
        int ret;
        if (n1 < CEU_SEQN_Radio_start)
            ret = v1[n1++];
        else
            ret = SUCCESS;

        static int v2[] = CEU_SEQV_Radio_startDone;
        static int n2 = 0;
        if (ret == SUCCESS) {
            if (n2 < CEU_SEQN_Radio_startDone)
                MQ(IN_Radio_startDone, v2[n2++]);
            else
                MQ(IN_Radio_startDone, SUCCESS);
        }

        return ret;
    }
    am_addr_t Radio_getSource (message_t* msg) {
        return msg->header.radio.src;
    }
    void Radio_setSource (message_t* msg, am_addr_t to) {
        msg->header.radio.src = to;
    }
    am_addr_t Radio_getDestination (message_t* msg) {
        return msg->header.radio.dest;
    }
    void Radio_setDestination (message_t* msg, am_addr_t to) {
        msg->header.radio.dest = to;
    }
    am_id_t Radio_getType (message_t* msg) {
        return msg->header.radio.type;
    }
    void Radio_setType (message_t* msg, am_id_t id) {
        msg->header.radio.type = id;
    }
    void* Radio_getPayload (message_t* msg, u8 len) {
        if (len <= TOSH_DATA_LENGTH) {
            return msg->data;
        }
        else {
            return NULL;
        }
    }

    void Leds_led0Toggle () {
        //printf("Leds_led0Toggle\n");
    }
    void Leds_set (u8 v) {
        //printf("Leds_set: %d\n", v);
    }

#ifdef FUNC_Photo_read
    int Photo_read ()
    {
        static int v1[] = CEU_SEQV_Photo_read;
        static int n1 = 0;
        int ret;
        if (n1 < CEU_SEQN_Photo_read)
            ret = v1[n1++];
        else
            ret = SUCCESS;

#ifdef IN_Photo_readDone
        static int v2[] = CEU_SEQV_Photo_readDone;
        static int n2 = 0;
        if (ret == SUCCESS) {
            if (n2 < CEU_SEQN_Photo_readDone)
                MQ(IN_Photo_readDone, v2[n2++]);
            else
                MQ(IN_Photo_readDone, v2[n2-1]);
        }
#endif

        return ret;
    }
#endif

#ifdef FUNC_Temp_read
    int Temp_read ()
    {
        static int v1[] = CEU_SEQV_Temp_read;
        static int n1 = 0;
        int ret;
        if (n1 < CEU_SEQN_Temp_read)
            ret = v1[n1++];
        else
            ret = SUCCESS;

#ifdef IN_Temp_readDone
        static int v2[] = CEU_SEQV_Temp_readDone;
        static int n2 = 0;
        if (ret == SUCCESS) {
            if (n2 < CEU_SEQN_Temp_readDone)
                MQ(IN_Temp_readDone, v2[n2++]);
            else
                MQ(IN_Temp_readDone, v2[n2-1]);
        }
#endif

        return ret;
    }
#endif
    /******/
end
]]

function app (app)
    app.values = app.values or {}
    local vals = { 'Radio_start', 'Radio_startDone',
                   'Photo_read',  'Photo_readDone',
                   'Temp_read',   'Temp_readDone',   }
    for _, k in ipairs(vals) do
        app.values[k] = app.values[k] or {}
    end

    local VALS = 'C do /******/\n'
    for k, t in pairs(app.values) do
        VALS = VALS .. '#define CEU_SEQN_'..k..' '..#t..'\n'
        VALS = VALS .. '#define CEU_SEQV_'..k..' {'..table.concat(t,',')..'}\n'
    end
    VALS = VALS .. '/******/ end\n'

    assert(not app.files.include)
    app.files.include = VALS .. H

    local app = simul.app(app)
    return app
end
