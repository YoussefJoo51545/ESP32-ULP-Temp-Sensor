; https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/system/ulp_instruction_set.html
; Registers:
; General Purpose, 16-bit: R0, R1, R2, R3
; Stage Count, 8-bit
; Instruction Counter

#include "soc/soc_ulp.h"
#include "soc/sens_reg.h"
#include "soc/rtc_cntl_reg.h"
#include "sdkconfig.h"

    .data

    .global entry
    .global temp_array
    .global min_temp_thresh
    .global max_temp_thresh
    buffer: .long 3
    min_temp_thresh: .long -135
    max_temp_thresh: .long 450
    .set measure_cycles, 1000
    .set sleep_cycles, 5000

    .bss

    temp_array:
       db  0
       db  0
       db  0

    sum: db

    .text

    entry:
        jump cpu_ready ;don't move a fucking muscle unless the CPU wants to be our friend
    init_buffer:
        move r0, buffer ;init array of 3 bytes (3 elements)
        move r1, 0 ;we'll use this shit later
        move r2, temp_array ;pointer to index of array
    get_temperature:
        tsens, temp_array[r1], measure_cycles
    check_buffer:
        add r2, r2, 1
        sub r0, r0, 1
        wait sleep_cycles
        jumpr get_temperature, buffer, eq ;keep getting temp data
    add_elements:
        add r4, temp_array[r1]
    loop_buffer:
        sub r1, r1, 1 ;decrement index
        and r1, r1, 0
        jumpr add_elements, r1 ;keep adding
        move r0, r4
        jumpr temperature_failure, min_temp_thresh, le
        jumpr temperature_failure, max_temp_thresh, ge
        jump entry
    temperature_failure:
        halt
    cpu_ready:
      READ_RTC_REG(RTC_CNTL_LOW_POWER_ST_REG, 27, 1)
      move r1, r0
      move r0, 0
      READ_RTC_FIELD(RTC_CNTL_LOW_POWER_ST_REG, RTC_CNTL_RDY_FOR_WAKEUP)
      and r0, r0, r1 ;we only want to use this if the CPU is awake and can receive a tx from ULP
      wait sleep_cycles
      jumpr init_buffer, 0, eq
      jump cpu_ready ;loop