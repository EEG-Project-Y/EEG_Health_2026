/*
 * KS1092 VO1/VO2 ADC observer.
 * Scope: ADC3(GPIO10 Pin34) and ADC5(GPIO12 Pin36) only.
 */
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "adc.h"
#include "adc_porting.h"
#include "app_init.h"
#include "cmsis_os2.h"
#include "gpio.h"
#include "pinctrl.h"
#include "../../products/sle_uart/sle_link_a.h"
#include "soc_osal.h"
#include "tcxo.h"

#define EEG_ADC_TASK_STACK_SIZE    0x1000
#define EEG_ADC_TASK_PRIO          ((osPriority_t)17)
#define EEG_ADC_SAMPLE_PERIOD_MS   4
#define EEG_ADC_WINDOW_SAMPLES     250

/*
 * KS1092 ADC diagnostic mode.
 *
 * Set EEG_ADC_DIAG_MODE to 1 to run ADC-only diagnostics:
 *   - no SLE send
 *   - no SPI read
 *   - no EEG frame packing
 *   - only ADC/GPIO init and ADC diagnostic logs
 *
 * EEG_ADC_DIAG_TEST:
 *   1 = single ADC3/GPIO10 only
 *   2 = single ADC5/GPIO12 only
 *   3 = dual stable ADC3/GPIO10 + ADC5/GPIO12
 *
 * Diagnosis notes:
 * If VO1 -> ADC3 is normal and VO1 -> ADC5 is normal, but
 * VO2 -> ADC3 is low and VO2 -> ADC5 is also low, H3863 ADC3/ADC5
 * are basically usable and the abnormal point is concentrated on
 * the KS1092 VO2/CH2 side.
 *
 * If single ADC5 is normal but dual polling makes ADC5 abnormal, the
 * original multi-channel sampling/channel switching settle time/buffer
 * logic is suspect.
 *
 * If single ADC5 is also abnormal, but VO1 connected to ADC5 is normal,
 * ADC5 is not completely damaged; continue checking VO2 output,
 * input impedance, pull-down, or analog pin configuration.
 */
#define EEG_ADC_DIAG_MODE          0
#define EEG_ADC_DIAG_TEST          1
#define EEG_TRANSMIT_MODE          1
#define EEG_ENABLE_CH2_DEFAULT     0
#define EEG_FRAME_TEXT_DEBUG       1

#define EEG_ADC3_GPIO              10
#define EEG_ADC5_GPIO              12
#define EEG_ADC3_PIN_MODE          PIN_MODE_5
#define EEG_ADC5_PIN_MODE          PIN_MODE_6

#if EEG_ADC_DIAG_MODE
#define EEG_ADC_DIAG_PERIOD_MS     500
#define EEG_ADC_SINGLE_TOTAL       16
#define EEG_ADC_SINGLE_DROP        4
#define EEG_ADC_DUAL_TOTAL         8
#define EEG_ADC_DUAL_DROP          2
#define EEG_ADC_SETTLE_MS          2

typedef struct {
    uint32_t min_mv;
    uint32_t max_mv;
    uint64_t sum_mv;
    uint32_t count;
} eeg_adc_diag_stats_t;

static volatile uint32_t g_eeg_adc_diag_mv[ADC_CHANNEL_MAX_NUM];
static volatile bool g_eeg_adc_diag_seen[ADC_CHANNEL_MAX_NUM];
static volatile uint8_t g_eeg_adc_diag_cb_adc[ADC_CHANNEL_MAX_NUM];
static volatile uint32_t g_eeg_adc_diag_raw[ADC_CHANNEL_MAX_NUM];

static void eeg_adc_diag_callback(uint8_t ch, uint32_t *buffer, uint32_t length, bool *next)
{
    if (next != NULL) {
        *next = false;
    }

    if (buffer == NULL || length == 0 || ch >= ADC_CHANNEL_MAX_NUM) {
        return;
    }

    g_eeg_adc_diag_mv[ch] = buffer[length - 1];
    g_eeg_adc_diag_raw[ch] = buffer[length - 1];
    g_eeg_adc_diag_cb_adc[ch] = ch;
    g_eeg_adc_diag_seen[ch] = true;
}

static void eeg_adc_diag_stats_reset(eeg_adc_diag_stats_t *stats)
{
    stats->min_mv = 0;
    stats->max_mv = 0;
    stats->sum_mv = 0;
    stats->count = 0;
}

static void eeg_adc_diag_stats_add(eeg_adc_diag_stats_t *stats, uint32_t mv)
{
    if (stats->count == 0) {
        stats->min_mv = mv;
        stats->max_mv = mv;
        stats->sum_mv = mv;
        stats->count = 1;
        return;
    }

    if (mv < stats->min_mv) {
        stats->min_mv = mv;
    }
    if (mv > stats->max_mv) {
        stats->max_mv = mv;
    }
    stats->sum_mv += mv;
    stats->count++;
}

static uint32_t eeg_adc_diag_stats_avg(const eeg_adc_diag_stats_t *stats)
{
    if (stats->count == 0) {
        return 0;
    }
    return (uint32_t)(stats->sum_mv / stats->count);
}

static uint32_t eeg_adc_diag_stats_pp(const eeg_adc_diag_stats_t *stats)
{
    if (stats->count == 0 || stats->max_mv < stats->min_mv) {
        return 0;
    }
    return stats->max_mv - stats->min_mv;
}

static void eeg_adc_diag_config_pin(uint8_t gpio, pin_mode_t mode)
{
    errcode_t pull_ret = uapi_pin_set_pull((pin_t)gpio, PIN_PULL_TYPE_DISABLE);
    errcode_t mode_ret = uapi_pin_set_mode((pin_t)gpio, mode);

    printf("[eeg_adc_diag] gpio=%u mode=%u pull=disable ret_pull=0x%x ret_mode=0x%x\r\n",
           gpio, (uint8_t)mode, pull_ret, mode_ret);
}

static void eeg_adc_diag_config_adc_gpio(uint8_t adc)
{
    if (adc == ADC_CHANNEL_3) {
        eeg_adc_diag_config_pin(EEG_ADC3_GPIO, EEG_ADC3_PIN_MODE);
    } else if (adc == ADC_CHANNEL_5) {
        eeg_adc_diag_config_pin(EEG_ADC5_GPIO, EEG_ADC5_PIN_MODE);
    }
}

static uint8_t eeg_adc_diag_gpio_of(uint8_t adc)
{
    if (adc == ADC_CHANNEL_3) {
        return EEG_ADC3_GPIO;
    }
    if (adc == ADC_CHANNEL_5) {
        return EEG_ADC5_GPIO;
    }
    return 0xFF;
}

static uint32_t eeg_adc_diag_read_adc(uint8_t adc, uint32_t settle_ms)
{
    adc_scan_config_t config = {
        .type = 0,
        .freq = 1,
    };

    if (adc >= ADC_CHANNEL_MAX_NUM) {
        return 0;
    }

    g_eeg_adc_diag_mv[adc] = 0;
    g_eeg_adc_diag_raw[adc] = 0;
    g_eeg_adc_diag_seen[adc] = false;
    g_eeg_adc_diag_cb_adc[adc] = 0xFF;

    (void)uapi_adc_auto_scan_ch_enable(adc, config, eeg_adc_diag_callback);
    osal_msleep(settle_ms);
    (void)uapi_adc_auto_scan_ch_disable(adc);

    if (!g_eeg_adc_diag_seen[adc]) {
        printf("[eeg_adc_diag] adc=%u gpio=%u no_sample cb_adc=0x%x\r\n",
               adc, eeg_adc_diag_gpio_of(adc), g_eeg_adc_diag_cb_adc[adc]);
        return 0;
    }

    return g_eeg_adc_diag_mv[adc];
}

static void eeg_adc_diag_print_help(void)
{
    printf("[diag_help] Test 1: connect VO1 to GPIO10/ADC3, run single_adc3\r\n");
    printf("[diag_help] Test 2: connect VO1 to GPIO12/ADC5, run single_adc5\r\n");
    printf("[diag_help] Test 3: connect VO2 to GPIO10/ADC3, run single_adc3\r\n");
    printf("[diag_help] Test 4: connect VO2 to GPIO12/ADC5, run single_adc5\r\n");
    printf("[diag_help] Test 5: connect VO1->GPIO10 and VO2->GPIO12, run dual_stable\r\n");
    printf("[eeg_adc_diag] EEG_ADC_DIAG_TEST=%u, 1=single_adc3 2=single_adc5 3=dual_stable\r\n",
           EEG_ADC_DIAG_TEST);
}

static void eeg_adc_diag_init_common(void)
{
    uapi_adc_init(ADC_CLOCK_500KHZ);
    uapi_adc_power_en(AFE_SCAN_MODE_MAX_NUM, true);
}

static void eeg_adc_diag_sample_single(uint8_t adc, uint8_t gpio)
{
    eeg_adc_diag_stats_t stats;

    eeg_adc_diag_stats_reset(&stats);
    for (uint32_t i = 0; i < EEG_ADC_SINGLE_TOTAL; i++) {
        uint32_t mv = eeg_adc_diag_read_adc(adc, 1);

        if (i >= EEG_ADC_SINGLE_DROP) {
            eeg_adc_diag_stats_add(&stats, mv);
        }
    }

    printf("[eeg_adc_single] adc=%u gpio=%u min_mv=%u max_mv=%u avg_mv=%u pp_mv=%u\r\n",
           adc,
           gpio,
           stats.min_mv,
           stats.max_mv,
           eeg_adc_diag_stats_avg(&stats),
           eeg_adc_diag_stats_pp(&stats));
}

void eeg_adc_diag_single_adc3(void)
{
    eeg_adc_diag_init_common();
    eeg_adc_diag_config_adc_gpio(ADC_CHANNEL_3);

    while (1) {
        eeg_adc_diag_sample_single(ADC_CHANNEL_3, EEG_ADC3_GPIO);
        osal_msleep(EEG_ADC_DIAG_PERIOD_MS);
    }
}

void eeg_adc_diag_single_adc5(void)
{
    eeg_adc_diag_init_common();
    eeg_adc_diag_config_adc_gpio(ADC_CHANNEL_5);

    while (1) {
        eeg_adc_diag_sample_single(ADC_CHANNEL_5, EEG_ADC5_GPIO);
        osal_msleep(EEG_ADC_DIAG_PERIOD_MS);
    }
}

static uint32_t eeg_adc_diag_dual_channel_once(uint8_t adc, char slot)
{
    eeg_adc_diag_stats_t stats;

    eeg_adc_diag_stats_reset(&stats);

    for (uint32_t i = 0; i < EEG_ADC_DUAL_TOTAL; i++) {
        /*
         * Select the physical ADC slot, wait for the analog mux/sample path
         * to settle, then discard early samples to avoid previous-channel residue.
         */
        uint32_t mv = eeg_adc_diag_read_adc(adc, EEG_ADC_SETTLE_MS);

        if (i >= EEG_ADC_DUAL_DROP) {
            eeg_adc_diag_stats_add(&stats, mv);
        }
    }

    printf("[eeg_adc_diag] slot=%c adc=%u gpio=%u mv=%u raw=%u cb_adc=%u\r\n",
           slot,
           adc,
           eeg_adc_diag_gpio_of(adc),
           eeg_adc_diag_stats_avg(&stats),
           g_eeg_adc_diag_raw[adc],
           g_eeg_adc_diag_cb_adc[adc]);

    return eeg_adc_diag_stats_avg(&stats);
}

void eeg_adc_diag_dual_stable(void)
{
    eeg_adc_diag_stats_t adc3_stats;
    eeg_adc_diag_stats_t adc5_stats;

    eeg_adc_diag_init_common();
    eeg_adc_diag_config_adc_gpio(ADC_CHANNEL_3);
    eeg_adc_diag_config_adc_gpio(ADC_CHANNEL_5);

    while (1) {
        eeg_adc_diag_stats_reset(&adc3_stats);
        eeg_adc_diag_stats_reset(&adc5_stats);

        for (uint32_t i = 0; i < EEG_ADC_SINGLE_TOTAL; i++) {
            uint32_t adc3_mv = eeg_adc_diag_dual_channel_once(ADC_CHANNEL_3, 'A');
            uint32_t adc5_mv = eeg_adc_diag_dual_channel_once(ADC_CHANNEL_5, 'B');

            if (i >= EEG_ADC_SINGLE_DROP) {
                eeg_adc_diag_stats_add(&adc3_stats, adc3_mv);
                eeg_adc_diag_stats_add(&adc5_stats, adc5_mv);
            }
        }

        printf("[eeg_adc_dual] adc3_gpio10 avg_mv=%u pp_mv=%u | adc5_gpio12 avg_mv=%u pp_mv=%u\r\n",
               eeg_adc_diag_stats_avg(&adc3_stats),
               eeg_adc_diag_stats_pp(&adc3_stats),
               eeg_adc_diag_stats_avg(&adc5_stats),
               eeg_adc_diag_stats_pp(&adc5_stats));

        osal_msleep(EEG_ADC_DIAG_PERIOD_MS);
    }
}

static void *eeg_adc_diag_task(const char *arg)
{
    (void)arg;

    osal_msleep(1000);
    eeg_adc_diag_print_help();

#if EEG_ADC_DIAG_TEST == 1
    eeg_adc_diag_single_adc3();
#elif EEG_ADC_DIAG_TEST == 2
    eeg_adc_diag_single_adc5();
#elif EEG_ADC_DIAG_TEST == 3
    eeg_adc_diag_dual_stable();
#else
    printf("[eeg_adc_diag] invalid EEG_ADC_DIAG_TEST=%u, use 1/2/3\r\n", EEG_ADC_DIAG_TEST);
    while (1) {
        osal_msleep(EEG_ADC_DIAG_PERIOD_MS);
    }
#endif

    return NULL;
}

static void eeg_adc_entry(void)
{
    osThreadAttr_t attr;

    attr.name = "EEGADCDiag";
    attr.attr_bits = 0U;
    attr.cb_mem = NULL;
    attr.cb_size = 0U;
    attr.stack_mem = NULL;
    attr.stack_size = EEG_ADC_TASK_STACK_SIZE;
    attr.priority = EEG_ADC_TASK_PRIO;

    (void)osThreadNew((osThreadFunc_t)eeg_adc_diag_task, NULL, &attr);
}

#else

typedef struct {
    uint32_t seq;
    uint32_t timestamp_ms;
    uint16_t ch1_mv;
    uint16_t ch2_mv;
    uint16_t ch1_pp_mv;
    uint16_t ch2_pp_mv;
    bool ch1_valid;
    bool ch2_valid;
    uint8_t flags;
} eeg_sample_t;

typedef struct {
    uint16_t min_mv;
    uint16_t max_mv;
    uint32_t sum_mv;
    uint8_t count;
} eeg_adc_window_t;

#ifndef CONFIG_KS1092_RESET_PIN
#define CONFIG_KS1092_RESET_PIN    6
#endif

#define EEG_ADC_CH1                ADC_CHANNEL_3
#define EEG_ADC_CH2                ADC_CHANNEL_5
#define EEG_ADC_CH1_GPIO           10
#define EEG_ADC_CH2_GPIO           12
#define EEG_ADC_CH1_PIN_MODE       PIN_MODE_5
#define EEG_ADC_CH2_PIN_MODE       PIN_MODE_6
#define EEG_ADC_TOTAL_SAMPLES      16
#define EEG_ADC_DROP_SAMPLES       4
#define EEG_ADC_SETTLE_MS          2
#define EEG_FRAME_HEADER0          0xAA
#define EEG_FRAME_HEADER1          0x55
#define EEG_FRAME_VERSION          0x01
#define EEG_FRAME_LEN              21
#define EEG_TRANSMIT_INTERVAL_MS   20
#define EEG_CH2_MIN_VALID_MV       100
#define EEG_CH2_MAX_VALID_MV       3200
#define EEG_FLAG_CH1_VALID         0x01
#define EEG_FLAG_CH2_VALID         0x02

static volatile uint32_t g_eeg_adc_mv[ADC_CHANNEL_MAX_NUM];
static volatile bool g_eeg_adc_seen[ADC_CHANNEL_MAX_NUM];
static volatile uint8_t g_eeg_adc_cb_adc[ADC_CHANNEL_MAX_NUM];
static bool g_eeg_ch2_enabled = (EEG_ENABLE_CH2_DEFAULT != 0);
static uint32_t g_eeg_seq = 0;

static void eeg_adc_callback(uint8_t ch, uint32_t *buffer, uint32_t length, bool *next)
{
    if (next != NULL) {
        *next = false;
    }

    if (buffer == NULL || length == 0 || ch >= ADC_CHANNEL_MAX_NUM) {
        return;
    }

    if (ch != EEG_ADC_CH1 && ch != EEG_ADC_CH2) {
        return;
    }

    g_eeg_adc_mv[ch] = buffer[length - 1];
    g_eeg_adc_cb_adc[ch] = ch;
    g_eeg_adc_seen[ch] = true;
}

static void eeg_put_u16_le(uint8_t *buf, uint16_t value)
{
    buf[0] = (uint8_t)(value & 0xFF);
    buf[1] = (uint8_t)((value >> 8) & 0xFF);
}

static void eeg_put_u32_le(uint8_t *buf, uint32_t value)
{
    buf[0] = (uint8_t)(value & 0xFF);
    buf[1] = (uint8_t)((value >> 8) & 0xFF);
    buf[2] = (uint8_t)((value >> 16) & 0xFF);
    buf[3] = (uint8_t)((value >> 24) & 0xFF);
}

static uint8_t eeg_crc8_xor(const uint8_t *buf, size_t len)
{
    uint8_t crc = 0;

    if (buf == NULL) {
        return 0;
    }

    for (size_t i = 0; i < len; i++) {
        crc ^= buf[i];
    }
    return crc;
}

void ks1092_gpio_power_init(void)
{
    (void)uapi_pin_set_mode((pin_t)CONFIG_KS1092_RESET_PIN, PIN_MODE_0);
    (void)uapi_gpio_set_dir((pin_t)CONFIG_KS1092_RESET_PIN, GPIO_DIRECTION_OUTPUT);
    (void)uapi_gpio_set_val((pin_t)CONFIG_KS1092_RESET_PIN, GPIO_LEVEL_HIGH);
    osal_printk("[eeg_a] ks1092 rst gpio=%u level=high\r\n", CONFIG_KS1092_RESET_PIN);
}

static void eeg_adc_config_pin(uint8_t gpio, pin_mode_t mode)
{
    (void)uapi_pin_set_pull((pin_t)gpio, PIN_PULL_TYPE_DISABLE);
    (void)uapi_pin_set_mode((pin_t)gpio, mode);
}

void eeg_adc_init(void)
{
    eeg_adc_config_pin(EEG_ADC_CH1_GPIO, EEG_ADC_CH1_PIN_MODE);
    eeg_adc_config_pin(EEG_ADC_CH2_GPIO, EEG_ADC_CH2_PIN_MODE);
    uapi_adc_init(ADC_CLOCK_500KHZ);
    uapi_adc_power_en(AFE_SCAN_MODE_MAX_NUM, true);
    osal_printk("[eeg_a] adc init ch1_adc=%u gpio=%u ch2_adc=%u gpio=%u ch2_enabled=%u\r\n",
                EEG_ADC_CH1, EEG_ADC_CH1_GPIO, EEG_ADC_CH2, EEG_ADC_CH2_GPIO,
                g_eeg_ch2_enabled ? 1 : 0);
}

static uint16_t eeg_adc_read_mv(uint8_t adc_channel)
{
    adc_scan_config_t config = {
        .type = 0,
        .freq = 1,
    };

    if (adc_channel >= ADC_CHANNEL_MAX_NUM) {
        return 0;
    }

    g_eeg_adc_mv[adc_channel] = 0;
    g_eeg_adc_seen[adc_channel] = false;
    g_eeg_adc_cb_adc[adc_channel] = 0xFF;

    (void)uapi_adc_auto_scan_ch_enable(adc_channel, config, eeg_adc_callback);
    osal_msleep(EEG_ADC_SETTLE_MS);
    (void)uapi_adc_auto_scan_ch_disable(adc_channel);

    if (!g_eeg_adc_seen[adc_channel] || g_eeg_adc_cb_adc[adc_channel] != adc_channel) {
        return 0;
    }

    return (uint16_t)g_eeg_adc_mv[adc_channel];
}

static void eeg_adc_window_reset(eeg_adc_window_t *window)
{
    window->min_mv = 0;
    window->max_mv = 0;
    window->sum_mv = 0;
    window->count = 0;
}

static void eeg_adc_window_add(eeg_adc_window_t *window, uint16_t value)
{
    if (window->count == 0) {
        window->min_mv = value;
        window->max_mv = value;
        window->sum_mv = value;
        window->count = 1;
        return;
    }

    if (value < window->min_mv) {
        window->min_mv = value;
    }
    if (value > window->max_mv) {
        window->max_mv = value;
    }
    window->sum_mv += value;
    window->count++;
}

static bool eeg_ch2_is_plausible(uint16_t avg_mv, uint16_t pp_mv)
{
    (void)pp_mv;

    if (avg_mv < EEG_CH2_MIN_VALID_MV) {
        return false;
    }
    if (avg_mv > EEG_CH2_MAX_VALID_MV) {
        return false;
    }
    return true;
}

bool eeg_is_ch2_enabled(void)
{
    return g_eeg_ch2_enabled;
}

void eeg_set_ch2_enabled(bool enabled)
{
    g_eeg_ch2_enabled = enabled;
    osal_printk("[eeg_a] ch2_enabled=%u\r\n", g_eeg_ch2_enabled ? 1 : 0);
}

static void eeg_adc_sample_channel(uint8_t adc, uint16_t *avg_mv, uint16_t *pp_mv)
{
    eeg_adc_window_t window;

    if (avg_mv == NULL || pp_mv == NULL) {
        return;
    }

    *avg_mv = 0;
    *pp_mv = 0;
    eeg_adc_window_reset(&window);

    for (uint8_t i = 0; i < EEG_ADC_TOTAL_SAMPLES; i++) {
        uint16_t mv = eeg_adc_read_mv(adc);

        if (i >= EEG_ADC_DROP_SAMPLES) {
            eeg_adc_window_add(&window, mv);
        }
    }

    if (window.count != 0) {
        *avg_mv = (uint16_t)(window.sum_mv / window.count);
        *pp_mv = (uint16_t)(window.max_mv - window.min_mv);
    }
}

void eeg_sample_window(eeg_sample_t *out)
{
    uint16_t ch2_avg = 0;
    uint16_t ch2_pp = 0;

    if (out == NULL) {
        return;
    }

    (void)memset(out, 0, sizeof(*out));
    out->seq = g_eeg_seq++;
    out->timestamp_ms = (uint32_t)uapi_tcxo_get_ms();

    eeg_adc_sample_channel(EEG_ADC_CH1, &out->ch1_mv, &out->ch1_pp_mv);
    out->ch1_valid = true;

    if (eeg_is_ch2_enabled()) {
        eeg_adc_sample_channel(EEG_ADC_CH2, &ch2_avg, &ch2_pp);
        out->ch2_mv = ch2_avg;
        out->ch2_pp_mv = ch2_pp;
        out->ch2_valid = eeg_ch2_is_plausible(ch2_avg, ch2_pp);
    } else {
        out->ch2_mv = 0;
        out->ch2_pp_mv = 0;
        out->ch2_valid = false;
    }

    out->flags = 0;
    if (out->ch1_valid) {
        out->flags |= EEG_FLAG_CH1_VALID;
    }
    if (out->ch2_valid) {
        out->flags |= EEG_FLAG_CH2_VALID;
    }
}

size_t eeg_frame_pack(uint8_t *buf, size_t buf_len, const eeg_sample_t *sample)
{
    size_t pos = 0;

    if (buf == NULL || sample == NULL || buf_len < EEG_FRAME_LEN) {
        return 0;
    }

    buf[pos++] = EEG_FRAME_HEADER0;
    buf[pos++] = EEG_FRAME_HEADER1;
    buf[pos++] = EEG_FRAME_VERSION;
    eeg_put_u32_le(&buf[pos], sample->seq);
    pos += sizeof(uint32_t);
    eeg_put_u32_le(&buf[pos], sample->timestamp_ms);
    pos += sizeof(uint32_t);
    eeg_put_u16_le(&buf[pos], sample->ch1_mv);
    pos += sizeof(uint16_t);
    eeg_put_u16_le(&buf[pos], sample->ch2_mv);
    pos += sizeof(uint16_t);
    eeg_put_u16_le(&buf[pos], sample->ch1_pp_mv);
    pos += sizeof(uint16_t);
    eeg_put_u16_le(&buf[pos], sample->ch2_pp_mv);
    pos += sizeof(uint16_t);
    buf[pos++] = sample->flags;
    buf[pos] = eeg_crc8_xor(buf, pos);
    pos++;

    return pos;
}

bool eeg_frame_check_crc(const uint8_t *buf, size_t len)
{
    if (buf == NULL || len != EEG_FRAME_LEN) {
        return false;
    }
    return eeg_crc8_xor(buf, len - 1) == buf[len - 1];
}

static void *eeg_transmit_task(const char *arg)
{
    uint8_t frame[EEG_FRAME_LEN];
    eeg_sample_t sample;
    size_t send_len;
    int send_ret;

    (void)arg;

    osal_msleep(1000);
    osal_printk("[eeg_a] formal transmit mode start diag=%u transmit=%u\r\n",
                EEG_ADC_DIAG_MODE, EEG_TRANSMIT_MODE);
    ks1092_gpio_power_init();
    eeg_adc_init();
    SleLinkA_Init();

    while (1) {
        eeg_sample_window(&sample);
        send_len = eeg_frame_pack(frame, sizeof(frame), &sample);
        send_ret = -1;
        if (send_len != 0 && SleLinkA_IsConnected()) {
            send_ret = SleLinkA_Send(frame, (uint16_t)send_len);
        }

#if EEG_FRAME_TEXT_DEBUG
        osal_printk("[eeg_a] seq=%u ch1=%u pp1=%u valid1=%u ch2=%u pp2=%u valid2=%u flags=0x%02X send_len=%u ret=0x%x\r\n",
                    sample.seq, sample.ch1_mv, sample.ch1_pp_mv, sample.ch1_valid ? 1 : 0,
                    sample.ch2_mv, sample.ch2_pp_mv, sample.ch2_valid ? 1 : 0,
                    sample.flags, (unsigned int)send_len, send_ret);
#endif
        osal_msleep(EEG_TRANSMIT_INTERVAL_MS);
    }

    return NULL;
}

static void eeg_adc_entry(void)
{
    osThreadAttr_t attr;

    attr.name = "EEGTxTask";
    attr.attr_bits = 0U;
    attr.cb_mem = NULL;
    attr.cb_size = 0U;
    attr.stack_mem = NULL;
    attr.stack_size = EEG_ADC_TASK_STACK_SIZE;
    attr.priority = EEG_ADC_TASK_PRIO;

#if EEG_TRANSMIT_MODE
    (void)osThreadNew((osThreadFunc_t)eeg_transmit_task, NULL, &attr);
#else
    osal_printk("[eeg_a] EEG_TRANSMIT_MODE=0, no transmit task\r\n");
#endif
}

#endif

app_run(eeg_adc_entry);
