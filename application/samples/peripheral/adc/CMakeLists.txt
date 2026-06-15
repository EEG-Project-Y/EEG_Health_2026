#===============================================================================
# @brief    cmake file
# Copyright (c) CompanyNameMagicTag 2023-2023. All rights reserved.
#===============================================================================

if(DEFINED CONFIG_SAMPLE_ENABLE_ADC_DEMO)
set(SOURCES "${SOURCES}" "${CMAKE_CURRENT_SOURCE_DIR}/adc_demo.c" PARENT_SCOPE)
endif()
