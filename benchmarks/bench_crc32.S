#ifndef CRC32_UPDATE_FN
#error "CRC32_UPDATE_FN must be defined"
#endif

.section .text

.equ SYS_WRITE,          64
.equ SYS_EXIT,           93
.equ SYS_CLOCK_GETTIME, 113

.equ CLOCK_MONOTONIC_RAW, 4

.equ MAX_BUFFER_SIZE, 1048576

.equ SIZE_4K,   4096
.equ SIZE_64K,  65536
.equ SIZE_1M,   1048576

.equ ITER_4K,   2048
.equ ITER_64K,  128
.equ ITER_1M,   8

.equ CRC_4K,    0xA2912082
.equ CRC_64K,   0xB11DE6A1
.equ CRC_1M,    0x04D0E435

.equ RESULT_LINE_LEN, 44

.global _start
.type _start, %function

.extern crc32_init
.extern crc32_finalize
.extern CRC32_UPDATE_FN


_start:
    /*
     * Fill the 1 MiB benchmark buffer with the repeating pattern:
     *
     *   00 01 02 ... FE FF 00 01 ...
     *
     * Buffer initialization is outside the timed region.
     */
    adrp x19, bench_buffer
    add x19, x19, :lo12:bench_buffer

    mov x20, #MAX_BUFFER_SIZE
    mov w21, #0

.Lfill_loop:
    strb w21, [x19], #1
    add w21, w21, #1

    subs x20, x20, #1
    b.ne .Lfill_loop

    /*
     * Case 1:
     *   4 KiB × 2048 = 8 MiB
     */
    mov x0, #SIZE_4K
    mov x1, #ITER_4K
    ldr w2, =CRC_4K
    bl run_case

    cbnz w0, .Lbenchmark_error

    /*
     * Case 2:
     *   64 KiB × 128 = 8 MiB
     */
    mov x0, #SIZE_64K
    mov x1, #ITER_64K
    ldr w2, =CRC_64K
    bl run_case

    cbnz w0, .Lbenchmark_error

    /*
     * Case 3:
     *   1 MiB × 8 = 8 MiB
     */
    mov x0, #SIZE_1M
    mov x1, #ITER_1M
    ldr w2, =CRC_1M
    bl run_case

    cbnz w0, .Lbenchmark_error

    mov x0, #0
    b .Lexit


.Lbenchmark_error:
    cmp w0, #2
    b.eq .Lclock_error

    mov x0, #2
    adrp x1, checksum_error_msg
    add x1, x1, :lo12:checksum_error_msg
    mov x2, #CHECKSUM_ERROR_LEN
    bl write_message

    mov x0, #1
    b .Lexit


.Lclock_error:
    mov x0, #2
    adrp x1, clock_error_msg
    add x1, x1, :lo12:clock_error_msg
    mov x2, #CLOCK_ERROR_LEN
    bl write_message

    mov x0, #2


.Lexit:
    mov x8, #SYS_EXIT
    svc #0

.size _start, . - _start


/*
 * int run_case(
 *     uint64_t length,
 *     uint64_t iterations,
 *     uint32_t expected_crc
 * )
 *
 * Arguments:
 *   x0 = buffer length
 *   x1 = iteration count
 *   w2 = expected final CRC
 *
 * Returns:
 *   w0 = 0 success
 *   w0 = 1 checksum mismatch
 *   w0 = 2 clock_gettime failure
 */
.type run_case, %function

run_case:
    stp x19, x20, [sp, #-64]!
    stp x21, x22, [sp, #16]
    stp x23, x24, [sp, #32]
    stp x25, x30, [sp, #48]

    mov x19, x0
    mov x20, x1
    mov w21, w2

    adrp x22, bench_buffer
    add x22, x22, :lo12:bench_buffer

    /*
     * Warm-up.
     *
     * This result is checked, but the execution is not timed.
     */
    bl crc32_init

    mov x1, x22
    mov x2, x19
    bl CRC32_UPDATE_FN

    bl crc32_finalize

    cmp w0, w21
    b.ne .Lcase_checksum_error

    /*
     * start_ts = clock_gettime(CLOCK_MONOTONIC_RAW)
     */
    mov x0, #CLOCK_MONOTONIC_RAW

    adrp x1, start_ts
    add x1, x1, :lo12:start_ts

    mov x8, #SYS_CLOCK_GETTIME
    svc #0

    cbnz x0, .Lcase_clock_error

    mov x23, x20


.Lbenchmark_loop:
    bl crc32_init

    mov x1, x22
    mov x2, x19
    bl CRC32_UPDATE_FN

    bl crc32_finalize
    mov w24, w0

    subs x23, x23, #1
    b.ne .Lbenchmark_loop

    /*
     * end_ts = clock_gettime(CLOCK_MONOTONIC_RAW)
     */
    mov x0, #CLOCK_MONOTONIC_RAW

    adrp x1, end_ts
    add x1, x1, :lo12:end_ts

    mov x8, #SYS_CLOCK_GETTIME
    svc #0

    cbnz x0, .Lcase_clock_error

    /*
     * Verify the measured loop still produced
     * the expected CRC.
     */
    cmp w24, w21
    b.ne .Lcase_checksum_error

    /*
     * Load start time.
     *
     * x10 = start seconds
     * x11 = start nanoseconds
     */
    adrp x9, start_ts
    add x9, x9, :lo12:start_ts
    ldp x10, x11, [x9]

    /*
     * Load end time.
     *
     * x12 = end seconds
     * x13 = end nanoseconds
     */
    adrp x9, end_ts
    add x9, x9, :lo12:end_ts
    ldp x12, x13, [x9]

    /*
     * Convert:
     *
     * elapsed =
     *     (end_sec - start_sec) * 1_000_000_000
     *     + (end_nsec - start_nsec)
     */
    sub x12, x12, x10

    movz x14, #0xCA00
    movk x14, #0x3B9A, lsl #16

    /*
     * Normalize nanoseconds if the end nanosecond
     * field wrapped across a second boundary.
     */
    cmp x13, x11
    b.hs .Lnsec_ready

    sub x12, x12, #1
    add x13, x13, x14

.Lnsec_ready:
    sub x13, x13, x11

    mul x12, x12, x14
    add x25, x12, x13

    /*
     * Print:
     *
     * <size> <iterations> <elapsed_ns> <crc>
     *
     * All fields are hexadecimal and fixed width.
     */
    mov x0, x19
    mov x1, x20
    mov x2, x25
    mov w3, w24

    bl print_result

    mov w0, #0
    b .Lcase_done


.Lcase_checksum_error:
    mov w0, #1
    b .Lcase_done


.Lcase_clock_error:
    mov w0, #2


.Lcase_done:
    ldp x25, x30, [sp, #48]
    ldp x23, x24, [sp, #32]
    ldp x21, x22, [sp, #16]
    ldp x19, x20, [sp], #64
    ret

.size run_case, . - run_case


/*
 * void print_result(
 *     uint64_t length,
 *     uint64_t iterations,
 *     uint64_t elapsed_ns,
 *     uint32_t crc
 * )
 *
 * Output:
 *
 * 00001000 00000800 0000000012345678 A2912082
 */
.type print_result, %function

print_result:
    stp x19, x20, [sp, #-48]!
    stp x21, x22, [sp, #16]
    str x30, [sp, #32]

    mov x19, x0
    mov x20, x1
    mov x21, x2
    mov w22, w3

    adrp x4, result_buffer
    add x4, x4, :lo12:result_buffer

    /*
     * Buffer length.
     */
    mov w0, w19
    mov x1, x4
    bl format_hex32

    mov w4, #32
    strb w4, [x0], #1

    /*
     * Iterations.
     */
    mov x1, x0
    mov w0, w20
    bl format_hex32

    mov w4, #32
    strb w4, [x0], #1

    /*
     * Elapsed nanoseconds.
     */
    mov x1, x0
    mov x0, x21
    bl format_hex64

    mov w4, #32
    strb w4, [x0], #1

    /*
     * CRC32.
     */
    mov x1, x0
    mov w0, w22
    bl format_hex32

    mov w4, #10
    strb w4, [x0]

    /*
     * Write the complete line to stdout.
     */
    mov x0, #1

    adrp x1, result_buffer
    add x1, x1, :lo12:result_buffer

    mov x2, #RESULT_LINE_LEN
    mov x8, #SYS_WRITE
    svc #0

    ldr x30, [sp, #32]
    ldp x21, x22, [sp, #16]
    ldp x19, x20, [sp], #48
    ret

.size print_result, . - print_result


/*
 * char *format_hex32(uint32_t value, char *output)
 *
 * Returns:
 *   x0 = pointer immediately after the 8 generated characters
 */
.type format_hex32, %function

format_hex32:
    mov w2, w0
    mov x0, x1
    mov w3, #8

.Lhex32_loop:
    lsr w4, w2, #28

    cmp w4, #9
    b.ls .Lhex32_digit

    add w4, w4, #55
    b .Lhex32_store

.Lhex32_digit:
    add w4, w4, #48

.Lhex32_store:
    strb w4, [x0], #1
    lsl w2, w2, #4

    subs w3, w3, #1
    b.ne .Lhex32_loop

    ret

.size format_hex32, . - format_hex32


/*
 * char *format_hex64(uint64_t value, char *output)
 *
 * Returns:
 *   x0 = pointer immediately after the 16 generated characters
 */
.type format_hex64, %function

format_hex64:
    mov x2, x0
    mov x0, x1
    mov w3, #16

.Lhex64_loop:
    lsr x4, x2, #60

    cmp x4, #9
    b.ls .Lhex64_digit

    add x4, x4, #55
    b .Lhex64_store

.Lhex64_digit:
    add x4, x4, #48

.Lhex64_store:
    strb w4, [x0], #1
    lsl x2, x2, #4

    subs w3, w3, #1
    b.ne .Lhex64_loop

    ret

.size format_hex64, . - format_hex64


.type write_message, %function

write_message:
    mov x8, #SYS_WRITE
    svc #0
    ret

.size write_message, . - write_message


.section .rodata

checksum_error_msg:
    .ascii "[ERROR] benchmark checksum mismatch\n"
.equ CHECKSUM_ERROR_LEN, . - checksum_error_msg

clock_error_msg:
    .ascii "[ERROR] clock_gettime failed\n"
.equ CLOCK_ERROR_LEN, . - clock_error_msg


.section .bss

.balign 16

start_ts:
    .skip 16

end_ts:
    .skip 16


.balign 16

result_buffer:
    .skip RESULT_LINE_LEN


.balign 64

bench_buffer:
    .skip MAX_BUFFER_SIZE


.section .note.GNU-stack,"",@progbits