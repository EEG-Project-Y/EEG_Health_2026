#===============================================================================
# @brief    KS1092 local raw sampling sample.
#===============================================================================

if(DEFINED CONFIG_SAMPLE_SUPPORT_KS1092)
set(SOURCES_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}/ks1092_demo.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../../products/sle_uart/sle_link_a.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../../products/sle_uart/sle_uart_server/sle_uart_server.c
    ${CMAKE_CURRENT_SOURCE_DIR}/../../products/sle_uart/sle_uart_server/sle_uart_server_adv.c
)
set(HEADER_LIST
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/../../products/sle_uart
    ${CMAKE_CURRENT_SOURCE_DIR}/../../products/sle_uart/sle_uart_server
)
set(SOURCES "${SOURCES}" ${SOURCES_LIST} PARENT_SCOPE)
set(PUBLIC_HEADER "${PUBLIC_HEADER}" ${HEADER_LIST} PARENT_SCOPE)
endif()
