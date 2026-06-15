/**
 * Copyright (c) HiSilicon (Shanghai) Technologies Co., Ltd. 2023-2023. All rights reserved.
 *
 * Description: UART Sample Source. \n
 *
 * History: \n
 * 2023-06-29, Create file. \n
 */
#include <stddef.h>
#include <stdint.h>
#include "pinctrl.h"
#include "soc_osal.h"
#include "uart.h"
#include "watchdog.h"
#include "osal_debug.h"
#include "securec.h"
#include "cmsis_os2.h"
#include "app_init.h"

#define UART_BAUDRATE                      115200
#define UART_DATA_BITS                     3
#define UART_STOP_BITS                     1
#define UART_PARITY_BIT                    0
#define UART_TRANSFER_SIZE                 512
#define CONFIG_UART_INT_WAIT_MS            5

#define UART_TASK_STACK_SIZE               0x1000
#define EEG_SAMPLE_RATE                    250
#define EEG_SAMPLES_PER_FRAME              42
#define EEG_FRAME_INTERVAL_MS              168
#define EEG_FRAME_HEAD                     0xAA55
#define EEG_FRAME_SIZE                     196
#define EEG_LOG_INTERVAL_FRAMES            36
#define UART_TASK_PRIO                     (osPriority_t)(17)
#ifndef ENABLE_LOCAL_EEG_MOCK_SENDER
#define ENABLE_LOCAL_EEG_MOCK_SENDER       0
#endif

static uint8_t g_app_uart_rx_buff[UART_TRANSFER_SIZE] = { 0 };
static uint16_t g_eeg_sequence = 0;
static uint32_t g_eeg_sample_index = 0;
#if defined(CONFIG_UART_INT_TRANSFER_MODE)
static uint8_t g_app_uart_int_rx_flag = 0;
#endif
static uart_buffer_config_t g_app_uart_buffer_config = {
    .rx_buffer = g_app_uart_rx_buff,
    .rx_buffer_size = UART_TRANSFER_SIZE
};

#pragma pack(push, 1)
typedef struct {
    int16_t ch1;
    int16_t ch2;
} EEGSample2CH;

typedef struct {
    uint16_t head;
    uint16_t sequence;
    uint8_t deviceId[16];
    EEGSample2CH samples[EEG_SAMPLES_PER_FRAME];
    uint8_t reserved[6];
    uint16_t crc16;
} EEGRawFrame2CH;
#pragma pack(pop)

typedef char eeg_raw_frame_size_check[(sizeof(EEGRawFrame2CH) == EEG_FRAME_SIZE) ? 1 : -1];

static const int16_t g_alpha_sine_table[25] = {
    0, 25, 48, 68, 84, 95, 100, 98, 90, 77,
    59, 37, 13, -13, -37, -59, -77, -90, -98, -100,
    -95, -84, -68, -48, -25
};

static void app_uart_init_pin(void)
{
    uapi_pin_set_mode(CONFIG_UART_TXD_PIN, PIN_MODE_1);
    uapi_pin_set_mode(CONFIG_UART_RXD_PIN, PIN_MODE_1);
}

static void app_uart_init_config(void)
{
    uart_attr_t attr = {
        .baud_rate = UART_BAUDRATE,
        .data_bits = UART_DATA_BITS,
        .stop_bits = UART_STOP_BITS,
        .parity = UART_PARITY_BIT
    };

    uart_pin_config_t pin_config = {
        .tx_pin = CONFIG_UART_TXD_PIN,
        .rx_pin = CONFIG_UART_RXD_PIN,
        .cts_pin = PIN_NONE,
        .rts_pin = PIN_NONE
    };
    uapi_uart_deinit(CONFIG_UART_BUS_ID); 
    uapi_uart_init(CONFIG_UART_BUS_ID, &pin_config, &attr, NULL, &g_app_uart_buffer_config);

}

void UartInitForOrangePi(void)
{
    app_uart_init_pin();
    app_uart_init_config();
}

int32_t send_bytes_to_orange_pi(const uint8_t *data, uint16_t len)
{
    if (data == NULL || len == 0) {
        return -1;
    }

    return uapi_uart_write(CONFIG_UART_BUS_ID, data, len, 0);
}

static uint16_t crc16_modbus(const uint8_t *data, uint16_t len)
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

static int16_t triangle_wave(uint32_t sample_index, uint32_t freq_hz, int16_t amplitude)
{
    uint32_t period = EEG_SAMPLE_RATE / freq_hz;
    uint32_t phase;
    int32_t value;

    if (period == 0) {
        return 0;
    }

    phase = sample_index % period;
    if (phase < (period / 2)) {
        value = ((int32_t)phase * 4 * amplitude / (int32_t)period) - amplitude;
    } else {
        value = amplitude - ((int32_t)(phase - period / 2) * 4 * amplitude / (int32_t)period);
    }

    return (int16_t)value;
}

static int16_t mock_eeg_sample(uint32_t sample_index, uint8_t channel)
{
    int32_t alpha = g_alpha_sine_table[sample_index % 25];
    int32_t theta = triangle_wave(sample_index, 6, 35);
    int32_t delta = triangle_wave(sample_index, 2, 20);
    int32_t beta = triangle_wave(sample_index, 18, 18);
    int32_t noise = (int32_t)((sample_index * 17 + channel * 29) % 13) - 6;

    if (channel == 0) {
        return (int16_t)((alpha * 120 / 100) + theta + delta + beta + noise);
    }

    return (int16_t)((alpha * 95 / 100) + (theta * 45 / 35) + (delta * 25 / 20) +
                     (beta * 55 / 18) + noise);
}

static void build_eeg_frame(EEGRawFrame2CH *frame)
{
    static const char device_id[] = "BEARPI_H3863_001";
    uint8_t *device = frame->deviceId;

    (void)memset_s(frame, sizeof(EEGRawFrame2CH), 0, sizeof(EEGRawFrame2CH));
    frame->head = EEG_FRAME_HEAD;
    /* head = 0xAA55; little-endian UART byte order is 55 AA. */
    frame->sequence = g_eeg_sequence++;

    for (uint32_t i = 0; i < sizeof(frame->deviceId) && device_id[i] != '\0'; i++) {
        device[i] = (uint8_t)device_id[i];
    }

    for (uint32_t i = 0; i < EEG_SAMPLES_PER_FRAME; i++) {
        frame->samples[i].ch1 = mock_eeg_sample(g_eeg_sample_index, 0);
        frame->samples[i].ch2 = mock_eeg_sample(g_eeg_sample_index, 1);
        g_eeg_sample_index++;
    }

    frame->crc16 = crc16_modbus((const uint8_t *)frame,
                                (uint16_t)(sizeof(EEGRawFrame2CH) - sizeof(frame->crc16)));
}

int32_t send_eeg_frame_to_orange_pi(const EEGRawFrame2CH *frame)
{
    if (frame == NULL) {
        return -1;
    }

    return send_bytes_to_orange_pi((const uint8_t *)frame, sizeof(EEGRawFrame2CH));
}

#if defined(CONFIG_UART_INT_TRANSFER_MODE)
static void app_uart_read_int_handler(const void *buffer, uint16_t length, bool error)
{
    unused(error);
    if (buffer == NULL || length == 0) {
        osal_printk("uart%d int mode transfer illegal data!\r\n", CONFIG_UART_BUS_ID);
        return;
    }

    uint8_t *buff = (uint8_t *)buffer;
    if (memcpy_s(g_app_uart_rx_buff, length, buff, length) != EOK) {
        osal_printk("uart%d int mode data copy fail!\r\n", CONFIG_UART_BUS_ID);
        return;
    }
    g_app_uart_int_rx_flag = 1;
}

static void app_uart_write_int_handler(const void *buffer, uint32_t length, const void *params)
{
    unused(params);
    uint8_t *buff = (void *)buffer;
    for (uint32_t i = 0; i < length; i++) {
        osal_printk("uart%d write data[%d] = %d\r\n", CONFIG_UART_BUS_ID, i, buff[i]);
    }
    
}
#endif

static void *uart_task(const char *arg)
{
    unused(arg);
    EEGRawFrame2CH frame;
    uint32_t sent_count = 0;
    int32_t written;

    osal_printk("[app] EEG UART sender starting...\r\n");

    UartInitForOrangePi();

#if defined(CONFIG_UART_INT_TRANSFER_MODE)
    osal_printk("uart%d int mode register receive callback start!\r\n", CONFIG_UART_BUS_ID);
    if (uapi_uart_register_rx_callback(CONFIG_UART_BUS_ID, UART_RX_CONDITION_FULL_OR_IDLE,
                                       1, app_uart_read_int_handler) == ERRCODE_SUCC) {
        osal_printk("uart%d int mode register receive callback succ!\r\n", CONFIG_UART_BUS_ID);
    }
#endif

    while (1) {
        build_eeg_frame(&frame);
        (void)uapi_watchdog_kick();
        written = send_eeg_frame_to_orange_pi(&frame);
        if (written != (int32_t)sizeof(frame)) {
            osal_printk("[uart] warning: eeg frame write %d/%u bytes\r\n",
                        written, (unsigned int)sizeof(frame));
        } else if ((sent_count % EEG_LOG_INTERVAL_FRAMES) == 0) {
            osal_printk("[uart] eeg data sent, seq=%u\r\n", (unsigned int)frame.sequence);
        }
        sent_count++;
        osal_msleep(EEG_FRAME_INTERVAL_MS);
#if defined(CONFIG_UART_INT_TRANSFER_MODE)
        while (g_app_uart_int_rx_flag != 1) {
            osal_msleep(CONFIG_UART_INT_WAIT_MS);
        }
        g_app_uart_int_rx_flag = 0;
        osal_printk("uart%d int mode send back!\r\n", CONFIG_UART_BUS_ID);
        if (uapi_uart_write_int(CONFIG_UART_BUS_ID, g_app_uart_rx_buff, UART_TRANSFER_SIZE, 0,
                                app_uart_write_int_handler) == ERRCODE_SUCC) {
            osal_printk("uart%d int mode send back succ!\r\n", CONFIG_UART_BUS_ID);
        }
#endif
    }

    return NULL;
}

static void uart_entry(void)
{
#if ENABLE_LOCAL_EEG_MOCK_SENDER
    osal_task *task_handle = NULL;

    osal_kthread_lock();
    task_handle = osal_kthread_create((osal_kthread_handler)uart_task, 0, "UartTask", UART_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, UART_TASK_PRIO);
        osal_kfree(task_handle);
    }
    osal_kthread_unlock();
#else
    osal_printk("[uart] local EEG mock sender disabled\r\n");
#endif
}

/* Run the uart_entry. */
app_run(uart_entry);
