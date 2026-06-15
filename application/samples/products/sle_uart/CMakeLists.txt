#===============================================================================
# @brief    cmake file
# Copyright (c) CompanyNameMagicTag 2023-2023. All rights reserved.
#===============================================================================
if(DEFINED CONFIG_SAMPLE_SUPPORT_SLE_UART_SERVER)
set(SOURCES_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/sle_uart.c
    ${CMAKE_CURRENT_SOURCE_DIR}/eeg_parser.c
)
set(HEADER_LIST ${CMAKE_CURRENT_SOURCE_DIR})
elseif(DEFINED CONFIG_SAMPLE_SUPPORT_SLE_UART_CLIENT)
set(SOURCES_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/sle_uart.c
    ${CMAKE_CURRENT_SOURCE_DIR}/eeg_parser.c
)
set(HEADER_LIST ${CMAKE_CURRENT_SOURCE_DIR})
endif()

set(SOURCES "${SOURCES}" ${SOURCES_LIST} PARENT_SCOPE)
set(PUBLIC_HEADER "${PUBLIC_HEADER}" ${HEADER_LIST} PARENT_SCOPE)
