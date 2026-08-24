.section .text

.global _start
.type _start, %function

.extern crc32_bitwise

_start:
    /*
     * Test 1: Empty input
     * Expected CRC32: 0x00000000
     */
    adrp x0, test_empty
    add x0, x0, :lo12:test_empty
    mov x1, #TEST_EMPTY_LEN
    ldr w2, =CRC_EMPTY

    bl run_test
    cbnz w0, .Lfail_empty

    /*
     * Test 2: Single-byte input "a"
     * Expected CRC32: 0xE8B7BE43
     */
    adrp x0, test_single_a
    add x0, x0, :lo12:test_single_a
    mov x1, #TEST_SINGLE_A_LEN
    ldr w2, =CRC_SINGLE_A

    bl run_test
    cbnz w0, .Lfail_single_a

    /*
     * Test 3: Standard CRC-32 test vector "123456789"
     * Expected CRC32: 0xCBF43926
     */
    adrp x0, test_standard
    add x0, x0, :lo12:test_standard
    mov x1, #TEST_STANDARD_LEN
    ldr w2, =CRC_STANDARD

    bl run_test
    cbnz w0, .Lfail_standard

    /*
     * Test 4: Multi-byte text input "hello"
     * Expected CRC32: 0x3610A686
     */
    adrp x0, test_hello
    add x0, x0, :lo12:test_hello
    mov x1, #TEST_HELLO_LEN
    ldr w2, =CRC_HELLO

    bl run_test
    cbnz w0, .Lfail_hello

    /*
     * Test 5: Binary input including 0x00 and high-bit values
     * Expected CRC32: 0x37B2C8D3
     */
    adrp x0, test_binary
    add x0, x0, :lo12:test_binary
    mov x1, #TEST_BINARY_LEN
    ldr w2, =CRC_BINARY

    bl run_test
    cbnz w0, .Lfail_binary

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

.Lfail_single_a:
    adrp x1, fail_single_a_msg
    add x1, x1, :lo12:fail_single_a_msg
    mov x2, #FAIL_SINGLE_A_LEN
    b .Lreport_failure

.Lfail_standard:
    adrp x1, fail_standard_msg
    add x1, x1, :lo12:fail_standard_msg
    mov x2, #FAIL_STANDARD_LEN
    b .Lreport_failure

.Lfail_hello:
    adrp x1, fail_hello_msg
    add x1, x1, :lo12:fail_hello_msg
    mov x2, #FAIL_HELLO_LEN
    b .Lreport_failure

.Lfail_binary:
    adrp x1, fail_binary_msg
    add x1, x1, :lo12:fail_binary_msg
    mov x2, #FAIL_BINARY_LEN

.Lreport_failure:
    bl print_message
    mov x0, #1

.Lexit:
    mov x8, #93
    svc #0

.size _start, . - _start


/*
 * int run_test(const uint8_t *data, uint64_t length, uint32_t expected)
 *
 * Arguments:
 *   x0 = input pointer
 *   x1 = input length
 *   w2 = expected CRC32
 *
 * Returns:
 *   w0 = 0 if the test passes
 *   w0 = 1 if the test fails
 */
.type run_test, %function

run_test:
    stp x19, x30, [sp, #-16]!
    mov w19, w2

    bl crc32_bitwise

    cmp w0, w19
    cset w0, ne

    ldp x19, x30, [sp], #16
    ret

.size run_test, . - run_test


/*
 * void print_message(const char *message, uint64_t length)
 *
 * Arguments:
 *   x1 = message address
 *   x2 = message length
 */
.type print_message, %function

print_message:
    mov x0, #1
    mov x8, #64
    svc #0
    ret

.size print_message, . - print_message


.section .rodata

.equ CRC_EMPTY,    0x00000000
.equ CRC_SINGLE_A, 0xE8B7BE43
.equ CRC_STANDARD, 0xCBF43926
.equ CRC_HELLO,    0x3610A686
.equ CRC_BINARY,   0x37B2C8D3


test_empty:
    .byte 0x00
.equ TEST_EMPTY_LEN, 0


test_single_a:
    .ascii "a"
.equ TEST_SINGLE_A_LEN, . - test_single_a


test_standard:
    .ascii "123456789"
.equ TEST_STANDARD_LEN, . - test_standard


test_hello:
    .ascii "hello"
.equ TEST_HELLO_LEN, . - test_hello


test_binary:
    .byte 0x00, 0x01, 0x7F, 0x80, 0xFF
.equ TEST_BINARY_LEN, . - test_binary


pass_all_msg:
    .ascii "[PASS] All CRC32 tests passed (5/5)\n"
.equ PASS_ALL_LEN, . - pass_all_msg


fail_empty_msg:
    .ascii "[FAIL] empty input\n"
.equ FAIL_EMPTY_LEN, . - fail_empty_msg


fail_single_a_msg:
    .ascii "[FAIL] single-byte input\n"
.equ FAIL_SINGLE_A_LEN, . - fail_single_a_msg


fail_standard_msg:
    .ascii "[FAIL] standard test vector\n"
.equ FAIL_STANDARD_LEN, . - fail_standard_msg


fail_hello_msg:
    .ascii "[FAIL] multi-byte text input\n"
.equ FAIL_HELLO_LEN, . - fail_hello_msg


fail_binary_msg:
    .ascii "[FAIL] binary input\n"
.equ FAIL_BINARY_LEN, . - fail_binary_msg


.section .note.GNU-stack,"",@progbits