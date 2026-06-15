#include <stdint.h>
#include <string.h>

#include "app_init.h"
#include "errcode.h"
#include "gpio.h"
#include "pinctrl.h"
#include "soc_osal.h"
#include "spi.h"
#include "tcxo.h"

#include "eeg_parser.h"

#define KS1092_SPI_BUS_ID              0
#define KS1092_SPI_MISO_PIN            11
#define KS1092_SPI_MOSI_PIN            9
#define KS1092_SPI_CLK_PIN             7
#define KS1092_SPI_CS_PIN              10
#define KS1092_SPI_PIN_MODE            PIN_MODE_3
#define KS1092_SPI_CS_PIN_MODE         PIN_MODE_0

#define KS1092_SPI_SLAVE_NUM           1
#define KS1092_SPI_BUS_CLK             32000000
#define KS1092_SPI_FREQUENCY_MHZ       1
#define KS1092_SPI_FRAME_FORMAT        SPI_CFG_FRAME_FORMAT_MOTOROLA_SPI
#define KS1092_SPI_WAIT_CYCLES         0x10
#define KS1092_SPI_TRANSFER_TIMEOUT    0xFFFFFFFF

#define KS1092_TASK_STACK_SIZE         0x1200
#define KS1092_TASK_PRIO               17
#define KS1092_INTERVAL_MS             1000
#define KS1092_CS_DELAY_US             5

/*
 * TODO: 请用户根据 KS1092 数据手册调整以下 EEG 接收参数:
 *   - KS1092_EEG_READ_CHUNK:    每次 SPI 读取的字节数 (建议 128~512)
 *   - KS1092_EEG_READ_INTERVAL_MS: 两次读取之间的间隔 (ms)
 *   - 若 KS1092 支持 DMA 或中断模式，可替换轮询读取为 DMA/中断模式
 */
#define KS1092_EEG_READ_CHUNK          256
#define KS1092_EEG_READ_INTERVAL_MS    10
#define KS1092_EEG_STARTUP_DELAY_MS    200
#define KS1092_EEG_STATS_INTERVAL      100
#define KS1092_SPI_DUMMY_BYTE          0xDD

#define KS1092_REG_CH1SET              0x00
#define KS1092_REG_CH2SET              0x01
#define KS1092_READ_CMD_BASE           0x10
#define KS1092_READ_ONE_REG_COUNT      0x00
#define KS1092_READ_DUMMY              0xDD

typedef struct {
    uint8_t mode;
    uint32_t cpol;
    uint32_t cpha;
} ks1092_spi_mode_t;

static const ks1092_spi_mode_t g_ks1092_spi_modes[] = {
    {0, SPI_CFG_CLK_CPOL_0, SPI_CFG_CLK_CPHA_0},
    {1, SPI_CFG_CLK_CPOL_0, SPI_CFG_CLK_CPHA_1},
    {2, SPI_CFG_CLK_CPOL_1, SPI_CFG_CLK_CPHA_0},
    {3, SPI_CFG_CLK_CPOL_1, SPI_CFG_CLK_CPHA_1},
};

static EegParser g_eeg_parser = {0};
static uint32_t  g_eeg_stats_count = 0;

static void Ks1092EegFrameCallback(const EegRawFrame2CH *frame)
{
    g_eeg_stats_count++;

    if (g_eeg_stats_count == 1 || (g_eeg_stats_count % KS1092_EEG_STATS_INTERVAL) == 0) {
        osal_printk("[ks1092_test] frame #%u seq=%u len=%uB\r\n",
                    g_eeg_stats_count, frame->sequence, (unsigned int)sizeof(*frame));
    }

    if (g_eeg_stats_count <= 3) {
        EegParser_PrintFrame(frame);
    }
}

static void Ks1092FillSpiConfig(const ks1092_spi_mode_t *mode, spi_attr_t *config)
{
    config->is_slave = false;
    config->slave_num = KS1092_SPI_SLAVE_NUM;
    config->bus_clk = KS1092_SPI_BUS_CLK;
    config->freq_mhz = KS1092_SPI_FREQUENCY_MHZ;
    config->clk_polarity = mode->cpol;
    config->clk_phase = mode->cpha;
    config->frame_format = KS1092_SPI_FRAME_FORMAT;
    config->spi_frame_format = HAL_SPI_FRAME_FORMAT_STANDARD;
    config->frame_size = HAL_SPI_FRAME_SIZE_8;
    config->tmod = HAL_SPI_TRANS_MODE_TXRX;
    config->sste = SPI_CFG_SSTE_DISABLE;
}

static void Ks1092InitPin(void)
{
    (void)uapi_pin_set_mode(KS1092_SPI_MISO_PIN, KS1092_SPI_PIN_MODE);
    (void)uapi_pin_set_mode(KS1092_SPI_MOSI_PIN, KS1092_SPI_PIN_MODE);
    (void)uapi_pin_set_mode(KS1092_SPI_CLK_PIN, KS1092_SPI_PIN_MODE);
    (void)uapi_pin_set_mode(KS1092_SPI_CS_PIN, KS1092_SPI_CS_PIN_MODE);
    (void)uapi_gpio_set_dir(KS1092_SPI_CS_PIN, GPIO_DIRECTION_OUTPUT);
    (void)uapi_gpio_set_val(KS1092_SPI_CS_PIN, GPIO_LEVEL_HIGH);
}

static errcode_t Ks1092SetSpiMode(const ks1092_spi_mode_t *mode)
{
    spi_attr_t config = {0};

    Ks1092FillSpiConfig(mode, &config);
    return uapi_spi_set_attr(KS1092_SPI_BUS_ID, &config);
}

static errcode_t Ks1092SpiInit(void)
{
    spi_attr_t config = {0};
    spi_extra_attr_t ext_config = {0};
    errcode_t ret;

    osal_printk("[ks1092_test] spi init begin\r\n");
    Ks1092InitPin();

    Ks1092FillSpiConfig(&g_ks1092_spi_modes[0], &config);
    ext_config.sspi_param.wait_cycles = KS1092_SPI_WAIT_CYCLES;
    ret = uapi_spi_init(KS1092_SPI_BUS_ID, &config, &ext_config);
    if (ret == ERRCODE_SUCC) {
        osal_printk("[ks1092_test] spi init ok\r\n");
        osal_printk("[ks1092_test] spi mode=%u CPOL=%u CPHA=%u\r\n",
            g_ks1092_spi_modes[0].mode, g_ks1092_spi_modes[0].cpol, g_ks1092_spi_modes[0].cpha);
        osal_printk("[ks1092_test] spi freq=%u MHz\r\n", KS1092_SPI_FREQUENCY_MHZ);
        osal_printk("[ks1092_test] cs mode=manual gpio\r\n");
    } else {
        osal_printk("[ks1092_test] spi init failed ret=0x%x\r\n", ret);
    }

    return ret;
}

static void Ks1092DumpTransfer(const uint8_t *tx, const uint8_t *rx)
{
    osal_printk("[ks1092_test] tx: %02X %02X %02X\r\n", tx[0], tx[1], tx[2]);
    osal_printk("[ks1092_test] rx: %02X %02X %02X\r\n", rx[0], rx[1], rx[2]);
}

static errcode_t Ks1092ReadRegister(uint8_t reg, uint8_t *value)
{
    uint8_t tx[3] = {
        (uint8_t)(KS1092_READ_CMD_BASE | (reg & 0x0F)),
        KS1092_READ_ONE_REG_COUNT,
        KS1092_READ_DUMMY,
    };
    uint8_t rx[3] = {0};
    spi_xfer_data_t data = {0};
    errcode_t ret;

    data.tx_buff = tx;
    data.tx_bytes = sizeof(tx);
    data.rx_buff = rx;
    data.rx_bytes = sizeof(rx);

    osal_printk("[ks1092_test] cs low\r\n");
    (void)uapi_gpio_set_val(KS1092_SPI_CS_PIN, GPIO_LEVEL_LOW);
    (void)uapi_tcxo_delay_us(KS1092_CS_DELAY_US);
    ret = uapi_spi_master_writeread(KS1092_SPI_BUS_ID, &data, KS1092_SPI_TRANSFER_TIMEOUT);
    (void)uapi_tcxo_delay_us(KS1092_CS_DELAY_US);
    (void)uapi_gpio_set_val(KS1092_SPI_CS_PIN, GPIO_LEVEL_HIGH);
    osal_printk("[ks1092_test] cs high\r\n");

    Ks1092DumpTransfer(tx, rx);
    *value = rx[2];
    return ret;
}

static void Ks1092TryMode(const ks1092_spi_mode_t *mode)
{
    uint8_t ch1 = 0;
    uint8_t ch2 = 0;
    errcode_t ret;

    osal_printk("[ks1092_test] try spi mode %u\r\n", mode->mode);
    ret = Ks1092SetSpiMode(mode);
    if (ret != ERRCODE_SUCC) {
        osal_printk("[ks1092_test] set mode %u failed ret=0x%x\r\n", mode->mode, ret);
        return;
    }

    ret = Ks1092ReadRegister(KS1092_REG_CH1SET, &ch1);
    if (ret == ERRCODE_SUCC) {
        osal_printk("[ks1092_test] reg read rx=0x%02X reg=CH1SET(0x00)\r\n", ch1);
    } else {
        osal_printk("[ks1092_test] reg read rx=0x%02X reg=CH1SET(0x00) ret=0x%x\r\n", ch1, ret);
    }

    ret = Ks1092ReadRegister(KS1092_REG_CH2SET, &ch2);
    if (ret == ERRCODE_SUCC) {
        osal_printk("[ks1092_test] reg read rx=0x%02X reg=CH2SET(0x01)\r\n", ch2);
    } else {
        osal_printk("[ks1092_test] reg read rx=0x%02X reg=CH2SET(0x01) ret=0x%x\r\n", ch2, ret);
    }
}

/*
 * TODO: 若 KS1092 支持 DMA 传输，建议将以下轮询读取替换为 uapi_spi_set_dma_mode + uapi_spi_master_read，
 *       可大幅降低 CPU 占用。
 *      若 KS1092 支持中断模式 (数据就绪引脚)，可改用 uapi_spi_set_irq_mode 以事件驱动方式接收。
 */
static errcode_t Ks1092ReadEegBurst(uint8_t *rx_buf, uint32_t rx_len)
{
    uint8_t *tx_buf = NULL;
    spi_xfer_data_t data = {0};
    errcode_t ret;

    /*
     * 申请发送缓冲区，填充 dummy 字节用于生成 SPI 时钟。
     * KS1092 作为从机通过 MISO 在时钟沿输出数据，MOSI 数据无关紧要。
     */
    tx_buf = (uint8_t *)osal_kmalloc(rx_len, 0);
    if (tx_buf == NULL) {
        osal_printk("[ks1092_test] eeg burst malloc tx_buf failed len=%u\r\n", rx_len);
        return ERRCODE_FAIL;
    }
    (void)memset(tx_buf, KS1092_SPI_DUMMY_BYTE, rx_len);

    data.tx_buff  = tx_buf;
    data.tx_bytes = rx_len;
    data.rx_buff  = rx_buf;
    data.rx_bytes = rx_len;

    (void)uapi_gpio_set_val(KS1092_SPI_CS_PIN, GPIO_LEVEL_LOW);
    (void)uapi_tcxo_delay_us(KS1092_CS_DELAY_US);
    ret = uapi_spi_master_writeread(KS1092_SPI_BUS_ID, &data, KS1092_SPI_TRANSFER_TIMEOUT);
    (void)uapi_tcxo_delay_us(KS1092_CS_DELAY_US);
    (void)uapi_gpio_set_val(KS1092_SPI_CS_PIN, GPIO_LEVEL_HIGH);

    osal_kfree(tx_buf);
    return ret;
}

static int Ks1092TestTask(void *arg)
{
    (void)arg;
    osal_printk("[ks1092_test] boot\r\n");
    if (Ks1092SpiInit() != ERRCODE_SUCC) {
        return 0;
    }

    uint8_t *eeg_buf = (uint8_t *)osal_kmalloc(KS1092_EEG_READ_CHUNK, 0);

    while (1) {
        for (uint32_t i = 0; i < (sizeof(g_ks1092_spi_modes) / sizeof(g_ks1092_spi_modes[0])); i++) {
            Ks1092TryMode(&g_ks1092_spi_modes[i]);
            osal_msleep(KS1092_INTERVAL_MS);
        }

        /*
         * 模式轮询结束后进入 EEG 数据接收模式。
         * 使用最后一个成功配置的 SPI 模式（通常为 mode 0）。
         * TODO: 若需固定 SPI 模式，可提前 break 出 for 循环并使用特定 mode 索引。
         */
        osal_printk("[ks1092_test] enter eeg receive mode\r\n");
        EegParser_Init(&g_eeg_parser, Ks1092EegFrameCallback);
        g_eeg_stats_count = 0;

        if (eeg_buf == NULL) {
            eeg_buf = (uint8_t *)osal_kmalloc(KS1092_EEG_READ_CHUNK, 0);
            if (eeg_buf == NULL) {
                osal_printk("[ks1092_test] eeg buf malloc failed\r\n");
                osal_msleep(KS1092_EEG_STARTUP_DELAY_MS);
                continue;
            }
        }

        osal_msleep(KS1092_EEG_STARTUP_DELAY_MS);

        while (1) {
            (void)memset(eeg_buf, 0, KS1092_EEG_READ_CHUNK);

            errcode_t ret = Ks1092ReadEegBurst(eeg_buf, KS1092_EEG_READ_CHUNK);
            if (ret == ERRCODE_SUCC) {
                EegParser_FeedBytes(&g_eeg_parser, eeg_buf, KS1092_EEG_READ_CHUNK);
            } else {
                osal_printk("[ks1092_test] eeg burst read failed ret=0x%x\r\n", ret);
            }

            osal_msleep(KS1092_EEG_READ_INTERVAL_MS);
        }
    }

    return 0;
}

static void sle_uart_entry(void)
{
    osal_task *task_handle = NULL;

    osal_kthread_lock();
    task_handle = osal_kthread_create(Ks1092TestTask, NULL, "Ks1092TestTask", KS1092_TASK_STACK_SIZE);
    if (task_handle != NULL) {
        osal_kthread_set_priority(task_handle, KS1092_TASK_PRIO);
        osal_kfree(task_handle);
    } else {
        osal_printk("[ks1092_test] task create failed\r\n");
    }
    osal_kthread_unlock();
}

app_run(sle_uart_entry);
