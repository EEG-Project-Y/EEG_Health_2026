#ifndef SLE_LINK_A_H
#define SLE_LINK_A_H

#include <stdbool.h>
#include <stdint.h>

#ifndef SLE_ROLE_A_SERVER
#define SLE_ROLE_A_SERVER 1
#endif
#ifndef SLE_ROLE_B_CLIENT
#define SLE_ROLE_B_CLIENT 2
#endif
#ifndef CURRENT_SLE_ROLE
#define CURRENT_SLE_ROLE SLE_ROLE_A_SERVER
#endif
#ifndef SLE_DIAG_LOG_ENABLE
#define SLE_DIAG_LOG_ENABLE 1
#endif
#ifndef ENABLE_LED_TASK
#define ENABLE_LED_TASK 0
#endif
#ifndef SLE_A_ENABLE_ONLY_DIAG
#define SLE_A_ENABLE_ONLY_DIAG 0
#endif
#ifndef ENABLE_SLE_RX_FORWARD_TO_UART
#define ENABLE_SLE_RX_FORWARD_TO_UART 0
#endif
#ifndef ENABLE_A_SEND_TEST_TO_B
#define ENABLE_A_SEND_TEST_TO_B 0
#endif
#ifndef A_SEND_MODE_TEXT
#define A_SEND_MODE_TEXT 0
#endif
#ifndef A_SEND_MODE_EEG_FRAME
#define A_SEND_MODE_EEG_FRAME 1
#endif
#ifndef A_SEND_MODE
#define A_SEND_MODE A_SEND_MODE_EEG_FRAME
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define SLE_A_DEVICE_NAME "EEG_SLE_A"

void SleLinkA_Init(void);
void SleLinkA_Start(void);
bool SleLinkA_IsConnected(void);
int SleLinkA_Send(const uint8_t *data, uint16_t len);
void SleLinkA_OnReceive(const uint8_t *data, uint16_t len);

#ifdef __cplusplus
}
#endif

#endif
