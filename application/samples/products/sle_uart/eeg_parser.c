#include "eeg_parser.h"
#include "soc_osal.h"
#include <string.h>

#define EEG_LOG_TAG "[eeg_parser]"

/*
 * TODO: 请用户根据 KS1092 数据手册调整:
 *   - EEG_SAMPLES_PER_FRAME  (eeg_parser.h)
 *   - EEG_FRAME_HEAD          (eeg_parser.h)
 *   - CRC 多项式: 当前使用 CRC16-Modbus (0xA001, init=0xFFFF)
 *     若 KS1092 使用 CRC16-CCITT 或其他算法，请替换 EegCrc16Modbus 实现。
 */

/* ---------- Ring Buffer ---------- */

void EegRingBuf_Init(EegRingBuf *rb)
{
    if (rb == NULL) {
        return;
    }
    (void)memset(rb->buffer, 0, sizeof(rb->buffer));
    rb->write = 0;
    rb->read  = 0;
    rb->count = 0;
}

void EegRingBuf_Put(EegRingBuf *rb, uint8_t byte)
{
    if (rb == NULL) {
        return;
    }
    if (rb->count >= EEG_RING_BUF_SIZE) {
        /* buffer full: advance read pointer (drop oldest byte) */
        rb->read = (rb->read + 1) % EEG_RING_BUF_SIZE;
        rb->count--;
    }
    rb->buffer[rb->write] = byte;
    rb->write = (rb->write + 1) % EEG_RING_BUF_SIZE;
    rb->count++;
}

uint8_t EegRingBuf_Peek(const EegRingBuf *rb, uint32_t offset)
{
    if (rb == NULL || offset >= rb->count) {
        return 0;
    }
    return rb->buffer[(rb->read + offset) % EEG_RING_BUF_SIZE];
}

void EegRingBuf_Consume(EegRingBuf *rb, uint32_t n)
{
    if (rb == NULL || n > rb->count) {
        return;
    }
    rb->read  = (rb->read + n) % EEG_RING_BUF_SIZE;
    rb->count -= n;
}

uint32_t EegRingBuf_Available(const EegRingBuf *rb)
{
    if (rb == NULL) {
        return 0;
    }
    return rb->count;
}

/* ---------- CRC16 ---------- */
/*
 * TODO: 若 KS1092 不使用 CRC16-Modbus，请替换为对应算法。
 *       常见备选: CRC16-CCITT (poly=0x1021, init=0x0000 或 0xFFFF)
 */

uint16_t EegCrc16Modbus(const uint8_t *data, uint16_t len)
{
    uint16_t crc = 0xFFFF;

    for (uint16_t i = 0; i < len; i++) {
        crc ^= data[i];
        for (uint8_t bit = 0; bit < 8; bit++) {
            if ((crc & 0x0001) != 0) {
                crc = (uint16_t)((crc >> 1) ^ 0xA001);
            } else {
                crc = (uint16_t)(crc >> 1);
            }
        }
    }

    return crc;
}

/* ---------- Frame parsing ---------- */

static uint32_t EegParser_FindHeader(const EegRingBuf *rb)
{
    uint32_t avail = EegRingBuf_Available(rb);

    if (avail < 2) {
        return UINT32_MAX;
    }

    for (uint32_t i = 0; i <= avail - 2; i++) {
        uint16_t word = (uint16_t)((EegRingBuf_Peek(rb, i + 1) << 8) | EegRingBuf_Peek(rb, i));

        if (word == EEG_FRAME_HEAD) {
            return i;
        }

        word = (uint16_t)((EegRingBuf_Peek(rb, i) << 8) | EegRingBuf_Peek(rb, i + 1));

        if (word == EEG_FRAME_HEAD) {
            return i;
        }
    }

    return UINT32_MAX;
}

/*
 * TODO: 校验帧完整性
 * (1) 帧头匹配 (read 指针已在 header 位置)
 * (2) 帧长度 = EEG_FRAME_SIZE
 * (3) CRC 校验通过
 */
static bool EegParser_TryParseFrame(const EegRingBuf *rb, EegRawFrame2CH *out_frame)
{
    uint8_t temp[EEG_FRAME_SIZE];
    uint16_t computed_crc;
    uint16_t received_crc;

    if (EegRingBuf_Available(rb) < EEG_FRAME_SIZE) {
        return false;
    }

    for (uint32_t i = 0; i < EEG_FRAME_SIZE; i++) {
        temp[i] = EegRingBuf_Peek(rb, i);
    }

    (void)memcpy(out_frame, temp, EEG_FRAME_SIZE);

    if (out_frame->head != EEG_FRAME_HEAD) {
        return false;
    }

    computed_crc = EegCrc16Modbus(temp, (uint16_t)(EEG_FRAME_SIZE - sizeof(out_frame->crc16)));
    received_crc = out_frame->crc16;

    return (computed_crc == received_crc);
}

/* ---------- Parser ---------- */

void EegParser_Init(EegParser *parser, eeg_frame_callback_t callback)
{
    if (parser == NULL) {
        return;
    }
    EegRingBuf_Init(&parser->ring);
    parser->frame_cb    = callback;
    parser->total_frames = 0;
    parser->good_frames  = 0;
    parser->crc_errors   = 0;
    parser->sync_lost    = 0;
    parser->synced       = false;
}

void EegParser_FeedBytes(EegParser *parser, const uint8_t *data, uint32_t len)
{
    uint32_t head_index;
    EegRawFrame2CH frame;

    if (parser == NULL || data == NULL || len == 0) {
        return;
    }

    /* Step 1: push all bytes into ring buffer */
    for (uint32_t i = 0; i < len; i++) {
        EegRingBuf_Put(&parser->ring, data[i]);
    }

    /* Step 2: try to extract frames while enough data */
    while (EegRingBuf_Available(&parser->ring) >= 2) {
        head_index = EegParser_FindHeader(&parser->ring);

        if (head_index == UINT32_MAX) {
            /* no header found: discard all but last byte (partial header) */
            uint32_t avail = EegRingBuf_Available(&parser->ring);
            if (avail > 1) {
                EegRingBuf_Consume(&parser->ring, avail - 1);
            }
            if (!parser->synced) {
                parser->sync_lost++;
            } else {
                parser->synced = false;
            }
            break;
        }

        if (head_index > 0) {
            /* discard garbage before header */
            EegRingBuf_Consume(&parser->ring, head_index);
            if (parser->synced) {
                parser->sync_lost++;
                parser->synced = false;
            }
        }

        if (EegRingBuf_Available(&parser->ring) < EEG_FRAME_SIZE) {
            break;
        }

        if (EegParser_TryParseFrame(&parser->ring, &frame)) {
            parser->total_frames++;
            parser->good_frames++;
            parser->synced = true;

            if (parser->frame_cb != NULL) {
                parser->frame_cb(&frame);
            }
        } else {
            parser->crc_errors++;
            /* CRC mismatch: skip 2 bytes and search again */
            EegRingBuf_Consume(&parser->ring, 2);
            if (parser->synced) {
                parser->synced = false;
            }
            continue;
        }

        /* consume the parsed frame */
        EegRingBuf_Consume(&parser->ring, EEG_FRAME_SIZE);
    }
}

void EegParser_PrintFrame(const EegRawFrame2CH *frame)
{
    uint16_t i;

    if (frame == NULL) {
        return;
    }

    osal_printk(EEG_LOG_TAG " head=0x%04X seq=%u\r\n", frame->head, frame->sequence);

    osal_printk(EEG_LOG_TAG " deviceId=");
    for (i = 0; i < EEG_DEVICE_ID_LEN; i++) {
        osal_printk("%c", (frame->deviceId[i] >= 0x20 && frame->deviceId[i] <= 0x7E) ?
                    (char)frame->deviceId[i] : '.');
    }
    osal_printk("\r\n");

    osal_printk(EEG_LOG_TAG " samples(ch1,ch2):\r\n");
    for (i = 0; i < EEG_SAMPLES_PER_FRAME; i++) {
        osal_printk("  [%02u] %6d %6d\r\n", i, frame->samples[i].ch1, frame->samples[i].ch2);
    }

    osal_printk(EEG_LOG_TAG " crc16=0x%04X\r\n", frame->crc16);
}
