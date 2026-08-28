.section .text

.global _start
.type _start, %function

.extern crc32_init
.extern crc32_finalize
.extern crc32_bitwise
.extern crc32_tablewise
.extern crc32_update_hw
.extern crc32_hardware


_start:
    /*
     * Test 1: Empty input.
     */
    adrp x0, test_empty
    add x0, x0, :lo12:test_empty
    mov x1, #TEST_EMPTY_LEN
    ldr w2, =CRC_EMPTY
    bl run_hw_test
    cbnz w0, .Lfail_empty


    /*
     * Test 2: 1 byte -> CRC32B tail path.
     */
    adrp x0, test_1
    add x0, x0, :lo12:test_1
    mov x1, #TEST_1_LEN
    ldr w2, =CRC_1
    bl run_hw_test
    cbnz w0, .Lfail_1


    /*
     * Test 3: 2 bytes -> CRC32H path.
     */
    adrp x0, test_2
    add x0, x0, :lo12:test_2
    mov x1, #TEST_2_LEN
    ldr w2, =CRC_2
    bl run_hw_test
    cbnz w0, .Lfail_2


    /*
     * Test 4: 4 bytes -> CRC32W path.
     */
    adrp x0, test_4
    add x0, x0, :lo12:test_4
    mov x1, #TEST_4_LEN
    ldr w2, =CRC_4
    bl run_hw_test
    cbnz w0, .Lfail_4


    /*
     * Test 5: 8 bytes -> CRC32X path.
     */
    adrp x0, test_8
    add x0, x0, :lo12:test_8
    mov x1, #TEST_8_LEN
    ldr w2, =CRC_8
    bl run_hw_test
    cbnz w0, .Lfail_8


    /*
     * Test 6: Standard 9-byte CRC vector.
     * Exercises CRC32X + CRC32B.
     */
    adrp x0, test_standard
    add x0, x0, :lo12:test_standard
    mov x1, #TEST_STANDARD_LEN
    ldr w2, =CRC_STANDARD
    bl run_hw_test
    cbnz w0, .Lfail_standard


    /*
     * Test 7: 15-byte input.
     *
     * Exercises all four variants in one call:
     *   8 + 4 + 2 + 1
     */
    adrp x0, test_15
    add x0, x0, :lo12:test_15
    mov x1, #TEST_15_LEN
    ldr w2, =CRC_15
    bl run_hw_test
    cbnz w0, .Lfail_15


    /*
     * Test 8: Three-chunk streaming.
     */
    bl crc32_init

    adrp x1, chunk_123
    add x1, x1, :lo12:chunk_123
    mov x2, #CHUNK_123_LEN
    bl crc32_update_hw

    ldr w9, =STATE_123
    cmp w0, w9
    b.ne .Lfail_stream

    adrp x1, chunk_456
    add x1, x1, :lo12:chunk_456
    mov x2, #CHUNK_456_LEN
    bl crc32_update_hw

    ldr w9, =STATE_123456
    cmp w0, w9
    b.ne .Lfail_stream

    adrp x1, chunk_789
    add x1, x1, :lo12:chunk_789
    mov x2, #CHUNK_789_LEN
    bl crc32_update_hw

    ldr w9, =STATE_123456789
    cmp w0, w9
    b.ne .Lfail_stream

    bl crc32_finalize

    ldr w9, =CRC_STANDARD
    cmp w0, w9
    b.ne .Lfail_stream


    /*
     * Test 9: Zero-length update must preserve state and
     * must not dereference the null pointer.
     */
    bl crc32_init

    adrp x1, chunk_123
    add x1, x1, :lo12:chunk_123
    mov x2, #CHUNK_123_LEN
    bl crc32_update_hw

    mov x1, #0
    mov x2, #0
    bl crc32_update_hw

    ldr w9, =STATE_123
    cmp w0, w9
    b.ne .Lfail_zero


    /*
     * Test 10:
     * Bitwise, table-driven and hardware implementations
     * must produce exactly the same final CRC.
     */
    adrp x0, test_15
    add x0, x0, :lo12:test_15
    mov x1, #TEST_15_LEN

    bl compare_three_implementations
    cbnz w0, .Lfail_compare


    adrp x1, pass_all_msg
    add x1, x1, :lo12:pass_all_msg
    mov x2, #PASS_ALL_LEN
    bl print_message

    mov x0, #0
    b .Lexit


.Lfail_empty:
    adrp x1, fail_empty_msg
    add x1, x1, :lo12:fail_empty_msg
    mov x2, #FAIL_EMPTY_LEN
    b .Lreport_failure

.Lfail_1:
    adrp x1, fail_1_msg
    add x1, x1, :lo12:fail_1_msg
    mov x2, #FAIL_1_LEN
    b .Lreport_failure

.Lfail_2:
    adrp x1, fail_2_msg
    add x1, x1, :lo12:fail_2_msg
    mov x2, #FAIL_2_LEN
    b .Lreport_failure

.Lfail_4:
    adrp x1, fail_4_msg
    add x1, x1, :lo12:fail_4_msg
    mov x2, #FAIL_4_LEN
    b .Lreport_failure

.Lfail_8:
    adrp x1, fail_8_msg
    add x1, x1, :lo12:fail_8_msg
    mov x2, #FAIL_8_LEN
    b .Lreport_failure

.Lfail_standard:
    adrp x1, fail_standard_msg
    add x1, x1, :lo12:fail_standard_msg
    mov x2, #FAIL_STANDARD_LEN
    b .Lreport_failure

.Lfail_15:
    adrp x1, fail_15_msg
    add x1, x1, :lo12:fail_15_msg
    mov x2, #FAIL_15_LEN
    b .Lreport_failure

.Lfail_stream:
    adrp x1, fail_stream_msg
    add x1, x1, :lo12:fail_stream_msg
    mov x2, #FAIL_STREAM_LEN
    b .Lreport_failure

.Lfail_zero:
    adrp x1, fail_zero_msg
    add x1, x1, :lo12:fail_zero_msg
    mov x2, #FAIL_ZERO_LEN
    b .Lreport_failure

.Lfail_compare:
    adrp x1, fail_compare_msg
    add x1, x1, :lo12:fail_compare_msg
    mov x2, #FAIL_COMPARE_LEN


.Lreport_failure:
    bl print_message
    mov x0, #1


.Lexit:
    mov x8, #93
    svc #0

.size _start, . - _start


/*
 * int run_hw_test(const uint8_t *data, uint64_t length, uint32_t expected)
 */
.type run_hw_test, %function

run_hw_test:
    stp x19, x30, [sp, #-16]!
    mov w19, w2

    bl crc32_hardware

    cmp w0, w19
    cset w0, ne

    ldp x19, x30, [sp], #16
    ret

.size run_hw_test, . - run_hw_test


/*
 * int compare_three_implementations(const uint8_t *data, uint64_t length)
 *
 * Returns:
 *   w0 = 0 if bitwise == table == hardware
 *   w0 = 1 otherwise
 */
.type compare_three_implementations, %function

compare_three_implementations:
    stp x19, x20, [sp, #-48]!
    stp x21, x22, [sp, #16]
    str x30, [sp, #32]

    mov x19, x0
    mov x20, x1

    bl crc32_bitwise
    mov w21, w0

    mov x0, x19
    mov x1, x20
    bl crc32_tablewise
    mov w22, w0

    mov x0, x19
    mov x1, x20
    bl crc32_hardware

    cmp w21, w22
    b.ne .Lcompare_fail

    cmp w0, w21
    cset w0, ne
    b .Lcompare_done

.Lcompare_fail:
    mov w0, #1

.Lcompare_done:
    ldr x30, [sp, #32]
    ldp x21, x22, [sp, #16]
    ldp x19, x20, [sp], #48
    ret

.size compare_three_implementations, . - compare_three_implementations


.type print_message, %function

print_message:
    mov x0, #1
    mov x8, #64
    svc #0
    ret

.size print_message, . - print_message


.section .rodata

.equ CRC_EMPTY,        0x00000000
.equ CRC_1,            0xE8B7BE43
.equ CRC_2,            0x4F5344CD
.equ CRC_4,            0x9BE3E0A3
.equ CRC_8,            0x9AE0DAAF
.equ CRC_STANDARD,     0xCBF43926
.equ CRC_15,           0x524C3AE4

.equ STATE_123,        0x77B79C2D
.equ STATE_123456,     0xF68D2C9E
.equ STATE_123456789,  0x340BC6D9


test_empty:
    .byte 0x00
.equ TEST_EMPTY_LEN, 0


test_1:
    .ascii "a"
.equ TEST_1_LEN, . - test_1


test_2:
    .ascii "12"
.equ TEST_2_LEN, . - test_2


test_4:
    .ascii "1234"
.equ TEST_4_LEN, . - test_4


test_8:
    .ascii "12345678"
.equ TEST_8_LEN, . - test_8


test_standard:
    .ascii "123456789"
.equ TEST_STANDARD_LEN, . - test_standard


test_15:
    .ascii "123456789ABCDEF"
.equ TEST_15_LEN, . - test_15


chunk_123:
    .ascii "123"
.equ CHUNK_123_LEN, . - chunk_123


chunk_456:
    .ascii "456"
.equ CHUNK_456_LEN, . - chunk_456


chunk_789:
    .ascii "789"
.equ CHUNK_789_LEN, . - chunk_789


pass_all_msg:
    .ascii "[PASS] All hardware CRC32 tests passed (10/10)\n"
.equ PASS_ALL_LEN, . - pass_all_msg


fail_empty_msg:
    .ascii "[FAIL] hardware empty input\n"
.equ FAIL_EMPTY_LEN, . - fail_empty_msg

fail_1_msg:
    .ascii "[FAIL] hardware CRC32B path\n"
.equ FAIL_1_LEN, . - fail_1_msg

fail_2_msg:
    .ascii "[FAIL] hardware CRC32H path\n"
.equ FAIL_2_LEN, . - fail_2_msg

fail_4_msg:
    .ascii "[FAIL] hardware CRC32W path\n"
.equ FAIL_4_LEN, . - fail_4_msg

fail_8_msg:
    .ascii "[FAIL] hardware CRC32X path\n"
.equ FAIL_8_LEN, . - fail_8_msg

fail_standard_msg:
    .ascii "[FAIL] hardware standard vector\n"
.equ FAIL_STANDARD_LEN, . - fail_standard_msg

fail_15_msg:
    .ascii "[FAIL] hardware mixed-width tail path\n"
.equ FAIL_15_LEN, . - fail_15_msg

fail_stream_msg:
    .ascii "[FAIL] hardware streaming state\n"
.equ FAIL_STREAM_LEN, . - fail_stream_msg

fail_zero_msg:
    .ascii "[FAIL] hardware zero-length update\n"
.equ FAIL_ZERO_LEN, . - fail_zero_msg

fail_compare_msg:
    .ascii "[FAIL] bitwise/table/hardware equivalence\n"
.equ FAIL_COMPARE_LEN, . - fail_compare_msg


.section .note.GNU-stack,"",@progbits