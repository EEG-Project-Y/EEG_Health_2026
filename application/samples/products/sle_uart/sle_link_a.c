#include "sle_link_a.h"

#include <string.h>
#include "common_def.h"
#include "gpio.h"
#include "pinctrl.h"
#include "securec.h"
#include "sle_device_discovery.h"
#include "sle_errcode.h"
#include "sle_uart_server/sle_uart_server.h"
#include "soc_osal.h"

#if SLE_DIAG_LOG_ENABLE
#define SLE_DIAG_LOG(fmt, args...) osal_printk(fmt, ##args)
#else
#define SLE_DIAG_LOG(fmt, args...) do { } while (0)
#endif

#if (CURRENT_SLE_ROLE == SLE_ROLE_A_SERVER)
#define SLE_A_CURRENT_ROLE_TEXT "A_SERVER"
#elif (CURRENT_SLE_ROLE == SLE_ROLE_B_CLIENT)
#define SLE_A_CURRENT_ROLE_TEXT "B_CLIENT"
#else
#define SLE_A_CURRENT_ROLE_TEXT "UNKNOWN"
#endif

#define SLE_A_TASK_STACK_SIZE              0x800
#define SLE_A_TASK_PRIO                    28
#define SLE_A_LED_TASK_STACK_SIZE          0x800
#define SLE_A_LED_TASK_PRIO                17
#define SLE_A_SEND_TASK_STACK_SIZE         0x800
#define SLE_A_SEND_TASK_PRIO               27
#define SLE_A_SEND_TEST_DELAY_MS           1000
#define SLE_A_STATUS_LED_PIN               2
#define SLE_A_ADV_HANDLE_DEFAULT           1
#define SLE_A_MSG_QUEUE_LEN                5
#define SLE_A_MSG_QUEUE_MAX_SIZE           32
#define SLE_A_QUEUE_WAIT_FOREVER           0xFFFFFFFF
#define SLE_A_RETRY_DELAY_MS               1000
#define SLE_A_LED_SLOW_BLINK_MS            1000
#define SLE_A_LED_FAST_BLINK_MS            200
#define SLE_A_DISCONNECT_MSG               "sle_dis_connect"
#define SLE_A_LOG_HEX_MAX_LEN              64
#define SLE_A_LOG_ASCII_MAX_LEN            64
#define SLE_A_EEG_FRAME_SIZE               196
#define SLE_A_EEG_FRAME_HEAD               0xAA55
#define SLE_A_EEG_SAMPLE_RATE              250
#define SLE_A_EEG_SAMPLES_PER_FRAME        42
#define SLE_A_EEG_SOURCE_A_SLE_TX          0xA1
#define SLE_A_TEST_PAYLOAD                 "HELLO_FROM_A"

#pragma pack(push, 1)
typedef struct {
    int16_t ch1;
    int16_t ch2;
} SleAEegSample2CH;

typedef struct {
    uint16_t head;
    uint16_t sequence;
    uint8_t deviceId[16];
    SleAEegSample2CH samples[SLE_A_EEG_SAMPLES_PER_FRAME];
    uint8_t reserved[6];
    uint16_t crc16;
} SleAEegRawFrame2CH;
#pragma pack(pop)

typedef char sle_a_eeg_raw_frame_size_check[(sizeof(SleAEegRawFrame2CH) == SLE_A_EEG_FRAME_SIZE) ? 1 : -1];

#if ENABLE_SLE_RX_FORWARD_TO_UART
void UartInitForOrangePi(void);
int32_t send_bytes_to_orange_pi(const uint8_t *data, uint16_t len);
#endif

typedef enum {
    SLE_A_LED_DISCONNECTED,
    SLE_A_LED_CONNECTED,
    SLE_A_LED_ERROR
} SleALedState;

static volatile bool g_sle_a_connected = false;
static volatile bool g_sle_a_ready = false;
static volatile bool g_sle_a_advertising = false;
static volatile bool g_sle_a_led_started = false;
static volatile bool g_sle_a_send_test_task_started = false;
static volatile bool g_sle_a_test_sent = false;
static uint16_t g_sle_a_eeg_sequence = 0;
static uint32_t g_sle_a_eeg_sample_index = 0;
#if ENABLE_SLE_RX_FORWARD_TO_UART
static volatile bool g_sle_a_uart_forward_ready = false;
#endif
static volatile SleALedState g_sle_a_led_state = SLE_A_LED_DISCONNECTED;
static unsigned long g_sle_a_msgqueue_id;

static const int16_t g_sle_a_alpha_sine_table[25] = {
    0, 25, 48, 68, 84, 95, 100, 98, 90, 77,
    59, 37, 13, -13, -37, -59, -77, -90, -98, -100,
    -95, -84, -68, -48, -25
};

static errcode_t AppLed_Write(bool on)
{
    return uapi_gpio_set_val(SLE_A_STATUS_LED_PIN, on ? GPIO_LEVEL_HIGH : GPIO_LEVEL_LOW);
}

static errcode_t AppLed_Init(void)
{
    errcode_t mode_ret = uapi_pin_set_mode(SLE_A_STATUS_LED_PIN, PIN_MODE_0);
    errcode_t dir_ret = uapi_gpio_set_dir(SLE_A_STATUS_LED_PIN, GPIO_DIRECTION_OUTPUT);
    errcode_t val_ret = AppLed_Write(false);

    SLE_DIAG_LOG("[led] init ret = mode:0x%x dir:0x%x val:0x%x\r\n", mode_ret, dir_ret, val_ret);
    if (mode_ret != ERRCODE_SUCC) {
        return mode_ret;
    }
    if (dir_ret != ERRCODE_SUCC) {
        return dir_ret;
    }
    return val_ret;
}

static void AppLed_SetDisconnected(void)
{
    g_sle_a_led_state = SLE_A_LED_DISCONNECTED;
    SLE_DIAG_LOG("[led] state = disconnected\r\n");
}

static void AppLed_SetConnected(void)
{
    g_sle_a_led_state = SLE_A_LED_CONNECTED;
    (void)AppLed_Write(true);
    SLE_DIAG_LOG("[led] state = connected\r\n");
}

static void AppLed_SetError(void)
{
    g_sle_a_led_state = SLE_A_LED_ERROR;
    SLE_DIAG_LOG("[led] state = error\r\n");
}

#if ENABLE_LED_TASK
static int SleALedTask(void *arg)
{
    unused(arg);

    while (1) {
        if (g_sle_a_led_state == SLE_A_LED_CONNECTED) {
            (void)AppLed_Write(true);
            osal_msleep(SLE_A_LED_SLOW_BLINK_MS);
        } else if (g_sle_a_led_state == SLE_A_LED_ERROR) {
            (void)AppLed_Write(true);
            osal_msleep(SLE_A_LED_FAST_BLINK_MS);
            (void)AppLed_Write(false);
            osal_msleep(SLE_A_LED_FAST_BLINK_MS);
        } else {
            (void)AppLed_Write(true);
            osal_msleep(SLE_A_LED_SLOW_BLINK_MS);
            (void)AppLed_Write(false);
            osal_msleep(SLE_A_LED_SLOW_BLINK_MS);
        }
    }

    return 0;
}
#endif

static void SleAStartLedTask(void)
{
#if ENABLE_LED_TASK
    osal_task *task_handle = NULL;
#endif

    if (g_sle_a_led_started) {
        return;
    }

    (void)AppLed_Init();
    AppLed_SetDisconnected();

#if ENABLE_LED_TASK
    SLE_DIAG_LOG("[led] before task create\r\n");
    osal_kthread_lock();
    task_handle = osal_kthread_create(SleALedTask, NULL, "SleALedTask",
                                      SLE_A_LED_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, SLE_A_LED_TASK_PRIO);
        osal_kfree(task_handle);
        g_sle_a_led_started = true;
        SLE_DIAG_LOG("[led] task create ok\r\n");
    } else {
        SLE_DIAG_LOG("[led] task create failed\r\n");
    }
    osal_kthread_unlock();
#else
    g_sle_a_led_started = true;
    SLE_DIAG_LOG("[led] task disabled by ENABLE_LED_TASK=0\r\n");
#endif
}

static void SleAMsgQueueCreate(void)
{
    int32_t ret;

    if (g_sle_a_msgqueue_id != 0) {
        return;
    }

    ret = osal_msg_queue_create("sle_a_msgqueue", SLE_A_MSG_QUEUE_LEN, &g_sle_a_msgqueue_id, 0,
        SLE_A_MSG_QUEUE_MAX_SIZE);
    SLE_DIAG_LOG("[sle_a] msg queue create ret = %d\r\n", ret);
    if (ret != OSAL_SUCCESS) {
        osal_printk("[sle_a] message queue create failed\r\n");
        AppLed_SetError();
    }
}

static void SleAMsgQueueWrite(uint8_t *buffer_addr, uint16_t buffer_size)
{
    int32_t ret;

    if (g_sle_a_msgqueue_id == 0 || buffer_addr == NULL || buffer_size == 0) {
        return;
    }

    ret = osal_msg_queue_write_copy(g_sle_a_msgqueue_id, (void *)buffer_addr, (uint32_t)buffer_size, 0);
    SLE_DIAG_LOG("[sle_a] msg queue write ret = %d, len=%u\r\n", ret, buffer_size);
}

static int32_t SleAMsgQueueRead(uint8_t *buffer_addr, uint32_t *buffer_size)
{
    return osal_msg_queue_read_copy(g_sle_a_msgqueue_id, (void *)buffer_addr, buffer_size,
                                    SLE_A_QUEUE_WAIT_FOREVER);
}

static void SleAReadRequestCb(uint8_t server_id, uint16_t conn_id, ssaps_req_read_cb_t *read_cb_para,
    errcode_t status)
{
    SLE_DIAG_LOG("[sle_a] read request: server_id=%u conn_id=%u handle=0x%x status=0x%x\r\n",
                 server_id, conn_id, read_cb_para == NULL ? 0 : read_cb_para->handle, status);
}

static uint16_t SleLinkA_Crc16Modbus(const uint8_t *data, uint16_t len)
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

static int16_t SleLinkA_TriangleWave(uint32_t sample_index, uint32_t freq_hz, int16_t amplitude)
{
    uint32_t period = SLE_A_EEG_SAMPLE_RATE / freq_hz;
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

static int16_t SleLinkA_MockEegSample(uint32_t sample_index, uint8_t channel)
{
    int32_t alpha = g_sle_a_alpha_sine_table[sample_index % 25];
    int32_t theta = SleLinkA_TriangleWave(sample_index, 6, 35);
    int32_t delta = SleLinkA_TriangleWave(sample_index, 2, 20);
    int32_t beta = SleLinkA_TriangleWave(sample_index, 18, 18);
    int32_t noise = (int32_t)((sample_index * 17 + channel * 29) % 13) - 6;

    if (channel == 0) {
        return (int16_t)((alpha * 120 / 100) + theta + delta + beta + noise);
    }

    return (int16_t)((alpha * 95 / 100) + (theta * 45 / 35) + (delta * 25 / 20) +
                     (beta * 55 / 18) + noise);
}

static void SleLinkA_BuildEegFrame(SleAEegRawFrame2CH *frame)
{
    static const char device_id[] = "BEARPI_A_SLE_001";

    if (frame == NULL) {
        return;
    }

    (void)memset_s(frame, sizeof(SleAEegRawFrame2CH), 0, sizeof(SleAEegRawFrame2CH));
    frame->head = SLE_A_EEG_FRAME_HEAD;
    frame->sequence = g_sle_a_eeg_sequence++;

    for (uint32_t i = 0; i < sizeof(frame->deviceId) && device_id[i] != '\0'; i++) {
        frame->deviceId[i] = (uint8_t)device_id[i];
    }

    for (uint32_t i = 0; i < SLE_A_EEG_SAMPLES_PER_FRAME; i++) {
        frame->samples[i].ch1 = SleLinkA_MockEegSample(g_sle_a_eeg_sample_index, 0);
        frame->samples[i].ch2 = SleLinkA_MockEegSample(g_sle_a_eeg_sample_index, 1);
        g_sle_a_eeg_sample_index++;
    }

    frame->reserved[0] = SLE_A_EEG_SOURCE_A_SLE_TX;
    frame->crc16 = SleLinkA_Crc16Modbus((const uint8_t *)frame,
                                        (uint16_t)(sizeof(SleAEegRawFrame2CH) - sizeof(frame->crc16)));
}

static void SleLinkA_PrintAscii(const uint8_t *data, uint16_t len)
{
    char ascii[SLE_A_LOG_ASCII_MAX_LEN + 1] = { 0 };
    uint16_t print_len = len > SLE_A_LOG_ASCII_MAX_LEN ? SLE_A_LOG_ASCII_MAX_LEN : len;

    for (uint16_t i = 0; i < print_len; i++) {
        ascii[i] = (data[i] >= 0x20 && data[i] <= 0x7E) ? (char)data[i] : '.';
    }
    ascii[print_len] = '\0';

    osal_printk("[sle_a] data ascii=%s%s\r\n", ascii, print_len < len ? "..." : "");
}

static void SleLinkA_PrintHex(const uint8_t *data, uint16_t len)
{
    uint16_t print_len = len > SLE_A_LOG_HEX_MAX_LEN ? SLE_A_LOG_HEX_MAX_LEN : len;

    osal_printk("[sle_a] data hex=");
    for (uint16_t i = 0; i < print_len; i++) {
        osal_printk("%02X ", data[i]);
    }
    if (print_len < len) {
        osal_printk("...");
    }
    osal_printk("\r\n");
}

static bool SleLinkA_TryPrintEegFrame(const uint8_t *data, uint16_t len)
{
    SleAEegRawFrame2CH frame;

    if (data == NULL || len != sizeof(SleAEegRawFrame2CH)) {
        return false;
    }
    if (memcpy_s(&frame, sizeof(frame), data, len) != EOK) {
        return false;
    }

    osal_printk("[sle_a] eeg frame received from B, len=%u\r\n", len);
    osal_printk("[sle_a] head=0x%04X, seq=%u, source=0x%02X\r\n",
                frame.head, frame.sequence, frame.reserved[0]);

    return true;
}

#if ENABLE_SLE_RX_FORWARD_TO_UART
static void SleLinkA_ForwardToUart(const uint8_t *data, uint16_t len)
{
    static const uint8_t prefix[] = "SLE_RX:";

    if (!g_sle_a_uart_forward_ready) {
        UartInitForOrangePi();
        g_sle_a_uart_forward_ready = true;
    }

    (void)send_bytes_to_orange_pi(prefix, (uint16_t)(sizeof(prefix) - 1));
    (void)send_bytes_to_orange_pi(data, len);
    osal_printk("[uart] forwarded SLE data from B, len=%u\r\n", len);
}
#endif

void SleLinkA_OnReceive(const uint8_t *data, uint16_t len)
{
    if (data == NULL || len == 0) {
        osal_printk("[sle_a] received from B, len=0\r\n");
        return;
    }

    if (SleLinkA_TryPrintEegFrame(data, len)) {
        return;
    }

    osal_printk("[sle_a] received from B, len=%u\r\n", len);
    SleLinkA_PrintAscii(data, len);
    SleLinkA_PrintHex(data, len);

#if ENABLE_SLE_RX_FORWARD_TO_UART
    SleLinkA_ForwardToUart(data, len);
#endif
}

static void SleAWriteRequestCb(uint8_t server_id, uint16_t conn_id, ssaps_req_write_cb_t *write_cb_para,
    errcode_t status)
{
    SLE_DIAG_LOG("[sle_a] write request: server_id=%u conn_id=%u handle=0x%x status=0x%x\r\n",
                 server_id, conn_id, write_cb_para == NULL ? 0 : write_cb_para->handle, status);
    osal_printk("[sle_a] receive callback entered\r\n");
    if (status != ERRCODE_SUCC || write_cb_para == NULL || write_cb_para->value == NULL) {
        osal_printk("[sle_a] receive invalid: status=0x%x len=%u\r\n",
                    status, write_cb_para == NULL ? 0 : write_cb_para->length);
        return;
    }

    SleLinkA_OnReceive(write_cb_para->value, write_cb_para->length);
}

static int SleAControlTask(void *arg)
{
    uint8_t rx_buf[SLE_A_MSG_QUEUE_MAX_SIZE] = {0};
    uint32_t rx_length;

    unused(arg);

    while (1) {
        rx_length = sizeof(rx_buf);
        (void)memset_s(rx_buf, sizeof(rx_buf), 0, sizeof(rx_buf));
        if (SleAMsgQueueRead(rx_buf, &rx_length) != OSAL_SUCCESS) {
            continue;
        }

        if (strncmp((const char *)rx_buf, SLE_A_DISCONNECT_MSG, sizeof(SLE_A_DISCONNECT_MSG)) == 0) {
            SLE_DIAG_LOG("[sle_a] restart advertising after disconnect delay %ums\r\n", SLE_A_RETRY_DELAY_MS);
            osal_msleep(SLE_A_RETRY_DELAY_MS);
            SleLinkA_Start();
        }
    }

    return 0;
}

static void SleAStartControlTask(void)
{
    osal_task *task_handle = NULL;

    SLE_DIAG_LOG("[sle_a] before control task create\r\n");
    osal_kthread_lock();
    task_handle = osal_kthread_create(SleAControlTask, NULL, "SleACtrlTask",
                                      SLE_A_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, SLE_A_TASK_PRIO);
        osal_kfree(task_handle);
        SLE_DIAG_LOG("[sle_a] control task create ok\r\n");
    } else {
        SLE_DIAG_LOG("[sle_a] control task create failed\r\n");
    }
    osal_kthread_unlock();
}

void SleLinkA_Init(void)
{
    errcode_t ret;

#if SLE_A_ENABLE_ONLY_DIAG
    if (g_sle_a_ready) {
        return;
    }

    osal_printk("[sle_a] before enable_sle\r\n");
    ret = enable_sle();
    osal_printk("[sle_a] after enable_sle ret=0x%x\r\n", ret);
    if (ret == ERRCODE_SUCC) {
        g_sle_a_ready = true;
    }
    return;
#endif

    SLE_DIAG_LOG("[sle] current role = %s\r\n", SLE_A_CURRENT_ROLE_TEXT);
    SLE_DIAG_LOG("[sle_a] role = server/advertiser\r\n");
    SLE_DIAG_LOG("[sle_a] device name = %s\r\n", SLE_A_DEVICE_NAME);
    SLE_DIAG_LOG("[sle_a] init start\r\n");

    if (g_sle_a_ready) {
        SLE_DIAG_LOG("[sle_a] init ret = 0x0 (already ready)\r\n");
        return;
    }

    SLE_DIAG_LOG("[sle_a] before led init/task\r\n");
    SleAStartLedTask();
    SLE_DIAG_LOG("[sle_a] after led init/task\r\n");

    SLE_DIAG_LOG("[sle_a] before msg queue create\r\n");
    SleAMsgQueueCreate();
    SLE_DIAG_LOG("[sle_a] after msg queue create\r\n");

    SLE_DIAG_LOG("[sle_a] before server msg register\r\n");
    sle_uart_server_register_msg(SleAMsgQueueWrite);
    SLE_DIAG_LOG("[sle_a] after server msg register\r\n");

    SLE_DIAG_LOG("[sle_a] before server init\r\n");
    ret = sle_uart_server_init(SleAReadRequestCb, SleAWriteRequestCb);
    SLE_DIAG_LOG("[sle_a] after server init ret=0x%x\r\n", ret);
    SLE_DIAG_LOG("[sle_a] server init ret = 0x%x\r\n", ret);
    SLE_DIAG_LOG("[sle_a] init ret = 0x%x\r\n", ret);
    if (ret != ERRCODE_SUCC) {
        osal_printk("[sle_a] init failed, ret=0x%x\r\n", ret);
        AppLed_SetError();
        return;
    }

    g_sle_a_ready = true;
    g_sle_a_advertising = true;
    osal_printk("[sle_a] init ok, name=%s\r\n", SLE_A_DEVICE_NAME);
    SleAStartControlTask();
}

void SleLinkA_Start(void)
{
    errcode_t ret;

#if SLE_A_ENABLE_ONLY_DIAG
    return;
#endif

    if (!g_sle_a_ready) {
        osal_printk("[sle_a] init failed\r\n");
        AppLed_SetError();
        return;
    }

    if (g_sle_a_advertising) {
        osal_printk("[sle_a] advertising started\r\n");
        return;
    }

    ret = sle_start_announce(SLE_A_ADV_HANDLE_DEFAULT);
    SLE_DIAG_LOG("[sle_a] advertising start ret = 0x%x\r\n", ret);
    if (ret != ERRCODE_SLE_SUCCESS) {
        osal_printk("[sle_a] advertising failed, ret=0x%x\r\n", ret);
        AppLed_SetError();
        osal_msleep(SLE_A_RETRY_DELAY_MS);
        ret = sle_start_announce(SLE_A_ADV_HANDLE_DEFAULT);
        SLE_DIAG_LOG("[sle_a] advertising retry ret = 0x%x\r\n", ret);
        if (ret != ERRCODE_SLE_SUCCESS) {
            osal_printk("[sle_a] advertising failed, ret=0x%x\r\n", ret);
            return;
        }
    }

    g_sle_a_advertising = true;
    AppLed_SetDisconnected();
    osal_printk("[sle_a] advertising started\r\n");
}

bool SleLinkA_IsConnected(void)
{
    return g_sle_a_connected;
}

int SleLinkA_Send(const uint8_t *data, uint16_t len)
{
    errcode_t ret;

    if (!g_sle_a_connected || data == NULL || len == 0) {
        return -1;
    }

    ret = sle_uart_server_send_report_by_handle(data, len);
    return (int)ret;
}

#if ENABLE_A_SEND_TEST_TO_B
static int SleLinkA_SendTestDataToB(void)
{
#if (A_SEND_MODE == A_SEND_MODE_TEXT)
    const char *msg = SLE_A_TEST_PAYLOAD;
    int ret;

    if (g_sle_a_test_sent) {
        return 0;
    }

    osal_printk("[sle_a] send test data to B: %s\r\n", msg);
    ret = SleLinkA_Send((const uint8_t *)msg, (uint16_t)strlen(msg));
    osal_printk("[sle_a] send ret=0x%x\r\n", ret);
    if (ret == ERRCODE_SUCC) {
        g_sle_a_test_sent = true;
    }

    return ret;
#else
    SleAEegRawFrame2CH frame;
    int ret;

    if (g_sle_a_test_sent) {
        return 0;
    }

    SleLinkA_BuildEegFrame(&frame);
    osal_printk("[sle_a] send eeg frame to B, len=%u, seq=%u\r\n",
                (unsigned int)sizeof(frame), frame.sequence);
    ret = SleLinkA_Send((const uint8_t *)&frame, (uint16_t)sizeof(frame));
    osal_printk("[sle_a] send ret=0x%x\r\n", ret);
    if (ret == ERRCODE_SUCC) {
        g_sle_a_test_sent = true;
    }

    return ret;
#endif
}

static int SleASendTestTask(void *arg)
{
    unused(arg);

    osal_msleep(SLE_A_SEND_TEST_DELAY_MS);
    if (g_sle_a_connected) {
        (void)SleLinkA_SendTestDataToB();
    }
    g_sle_a_send_test_task_started = false;

    return 0;
}

static void SleAStartSendTestTask(void)
{
    osal_task *task_handle = NULL;

    if (g_sle_a_send_test_task_started) {
        return;
    }
    g_sle_a_send_test_task_started = true;

    osal_kthread_lock();
    task_handle = osal_kthread_create(SleASendTestTask, NULL, "SleASendTask", SLE_A_SEND_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, SLE_A_SEND_TASK_PRIO);
        osal_kfree(task_handle);
    } else {
        g_sle_a_send_test_task_started = false;
        osal_printk("[sle_a] send test task create failed\r\n");
    }
    osal_kthread_unlock();
}
#endif

void SleOnConnected(void)
{
    g_sle_a_connected = true;
    g_sle_a_advertising = false;
    g_sle_a_test_sent = false;
    AppLed_SetConnected();
    osal_printk("[sle_a] connected\r\n");
#if ENABLE_A_SEND_TEST_TO_B
    SleAStartSendTestTask();
#endif
}

void SleOnDisconnected(void)
{
    g_sle_a_connected = false;
    g_sle_a_advertising = false;
    g_sle_a_test_sent = false;
    AppLed_SetDisconnected();
    osal_printk("[sle_a] disconnected, restart advertising\r\n");
}

int SleSendEegData(const uint8_t *data, uint16_t len)
{
    return SleLinkA_Send(data, len);
}
