#ifndef EEG_PARSER_H
#define EEG_PARSER_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
#if __cplusplus
extern "C" {
#endif
#endif

/*
 * TODO: 请用户根据 KS1092 数据手册确认以下参数并修改:
 *   - EEG_SAMPLES_PER_FRAME: 每帧包含的采样点数
 *   - EEG_FRAME_HEAD:       帧头魔数
 *   - EEG_FRAME_SIZE:       完整帧字节数 (sizeof(EegRawFrame2CH))
 *   - CRC 多项式:          当前使用 CRC16-Modbus，若 KS1092 使用不同算法请替换
 */
#define EEG_SAMPLES_PER_FRAME   42
#define EEG_FRAME_HEAD          0xAA55
#define EEG_DEVICE_ID_LEN       16

#pragma pack(push, 1)
typedef struct {
    int16_t ch1;
    int16_t ch2;
} EegSample2CH;

typedef struct {
    uint16_t     head;
    uint16_t     sequence;
    uint8_t      deviceId[EEG_DEVICE_ID_LEN];
    EegSample2CH samples[EEG_SAMPLES_PER_FRAME];
    uint8_t      reserved[6];
    uint16_t     crc16;
} EegRawFrame2CH;
#pragma pack(pop)

#define EEG_FRAME_SIZE  sizeof(EegRawFrame2CH)

#define EEG_RING_BUF_SIZE   (EEG_FRAME_SIZE * 4)

typedef struct {
    uint8_t  buffer[EEG_RING_BUF_SIZE];
    uint32_t write;
    uint32_t read;
    uint32_t count;
} EegRingBuf;

void EegRingBuf_Init(EegRingBuf *rb);
void EegRingBuf_Put(EegRingBuf *rb, uint8_t byte);
uint8_t EegRingBuf_Peek(const EegRingBuf *rb, uint32_t offset);
void EegRingBuf_Consume(EegRingBuf *rb, uint32_t n);
uint32_t EegRingBuf_Available(const EegRingBuf *rb);

typedef void (*eeg_frame_callback_t)(const EegRawFrame2CH *frame);

typedef struct {
    EegRingBuf          ring;
    eeg_frame_callback_t frame_cb;
    uint32_t            total_frames;
    uint32_t            good_frames;
    uint32_t            crc_errors;
    uint32_t            sync_lost;
    bool                synced;
} EegParser;

void EegParser_Init(EegParser *parser, eeg_frame_callback_t callback);
void EegParser_FeedBytes(EegParser *parser, const uint8_t *data, uint32_t len);

uint16_t EegCrc16Modbus(const uint8_t *data, uint16_t len);

void EegParser_PrintFrame(const EegRawFrame2CH *frame);

#ifdef __cplusplus
#if __cplusplus
}
#endif
#endif

#endif
