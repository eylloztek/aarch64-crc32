.section .text

.global _start
.type _start, %function

.extern crc32_init
.extern crc32_finalize
.extern crc32_bitwise
.extern crc32_update_table
.extern crc32_tablewise


_start:
    /* Tests 1-5: known one-shot vectors. */
    adrp x0, test_empty
    add x0, x0, :lo12:test_empty
    mov x1, #TEST_EMPTY_LEN
    ldr w2, =CRC_EMPTY
    bl run_table_test
    cbnz w0, .Lfail_empty

    adrp x0, test_single_a
    add x0, x0, :lo12:test_single_a
    mov x1, #TEST_SINGLE_A_LEN
    ldr w2, =CRC_SINGLE_A
    bl run_table_test
    cbnz w0, .Lfail_single_a

    adrp x0, test_standard
    add x0, x0, :lo12:test_standard
    mov x1, #TEST_STANDARD_LEN
    ldr w2, =CRC_STANDARD
    bl run_table_test
    cbnz w0, .Lfail_standard

    adrp x0, test_hello
    add x0, x0, :lo12:test_hello
    mov x1, #TEST_HELLO_LEN
    ldr w2, =CRC_HELLO
    bl run_table_test
    cbnz w0, .Lfail_hello

    adrp x0, test_binary
    add x0, x0, :lo12:test_binary
    mov x1, #TEST_BINARY_LEN
    ldr w2, =CRC_BINARY
    bl run_table_test
    cbnz w0, .Lfail_binary


    /* Test 6: three-chunk streaming and internal states. */
    bl crc32_init

    adrp x1, chunk_123
    add x1, x1, :lo12:chunk_123
    mov x2, #CHUNK_123_LEN
    bl crc32_update_table

    ldr w9, =STATE_123
    cmp w0, w9
    b.ne .Lfail_chunks

    adrp x1, chunk_456
    add x1, x1, :lo12:chunk_456
    mov x2, #CHUNK_456_LEN
    bl crc32_update_table

    ldr w9, =STATE_123456
    cmp w0, w9
    b.ne .Lfail_chunks

    adrp x1, chunk_789
    add x1, x1, :lo12:chunk_789
    mov x2, #CHUNK_789_LEN
    bl crc32_update_table

    ldr w9, =STATE_123456789
    cmp w0, w9
    b.ne .Lfail_chunks

    bl crc32_finalize

    ldr w9, =CRC_STANDARD
    cmp w0, w9
    b.ne .Lfail_chunks


    /* Test 7: zero-length update with a null pointer. */
    bl crc32_init

    adrp x1, chunk_123
    add x1, x1, :lo12:chunk_123
    mov x2, #CHUNK_123_LEN
    bl crc32_update_table

    mov x1, #0
    mov x2, #0
    bl crc32_update_table

    ldr w9, =STATE_123
    cmp w0, w9
    b.ne .Lfail_zero_length

    adrp x1, chunk_456789
    add x1, x1, :lo12:chunk_456789
    mov x2, #CHUNK_456789_LEN
    bl crc32_update_table

    bl crc32_finalize

    ldr w9, =CRC_STANDARD
    cmp w0, w9
    b.ne .Lfail_zero_length


    /* Test 8: one-byte-at-a-time streaming. */
    bl crc32_init
    mov w21, w0

    adrp x19, test_standard
    add x19, x19, :lo12:test_standard
    mov x20, #TEST_STANDARD_LEN

.Lbytewise_loop:
    mov w0, w21
    mov x1, x19
    mov x2, #1

    bl crc32_update_table

    mov w21, w0

    add x19, x19, #1
    subs x20, x20, #1
    b.ne .Lbytewise_loop

    mov w0, w21
    bl crc32_finalize

    ldr w9, =CRC_STANDARD
    cmp w0, w9
    b.ne .Lfail_bytewise


    /* Test 9: all byte values from 0x00 through 0xFF. */
    adrp x0, test_all_bytes
    add x0, x0, :lo12:test_all_bytes
    mov x1, #TEST_ALL_BYTES_LEN
    ldr w2, =CRC_ALL_BYTES

    bl run_table_test
    cbnz w0, .Lfail_all_bytes


    /*
     * Test 10:
     * Bitwise and table-driven implementations must agree.
     */
    adrp x0, test_all_bytes
    add x0, x0, :lo12:test_all_bytes
    mov x1, #TEST_ALL_BYTES_LEN

    bl compare_implementations
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
    b .Lreport_failure

.Lfail_chunks:
    adrp x1, fail_chunks_msg
    add x1, x1, :lo12:fail_chunks_msg
    mov x2, #FAIL_CHUNKS_LEN
    b .Lreport_failure

.Lfail_zero_length:
    adrp x1, fail_zero_length_msg
    add x1, x1, :lo12:fail_zero_length_msg
    mov x2, #FAIL_ZERO_LENGTH_LEN
    b .Lreport_failure

.Lfail_bytewise:
    adrp x1, fail_bytewise_msg
    add x1, x1, :lo12:fail_bytewise_msg
    mov x2, #FAIL_BYTEWISE_LEN
    b .Lreport_failure

.Lfail_all_bytes:
    adrp x1, fail_all_bytes_msg
    add x1, x1, :lo12:fail_all_bytes_msg
    mov x2, #FAIL_ALL_BYTES_LEN
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
 * int run_table_test(const uint8_t *data, uint64_t length, uint32_t expected)
 */
.type run_table_test, %function

run_table_test:
    stp x19, x30, [sp, #-16]!
    mov w19, w2

    bl crc32_tablewise

    cmp w0, w19
    cset w0, ne

    ldp x19, x30, [sp], #16
    ret

.size run_table_test, . - run_table_test


/*
 * int compare_implementations(const uint8_t *data, uint64_t length)
 *
 * Returns:
 *   w0 = 0 if both implementations return the same CRC
 *   w0 = 1 otherwise
 */
.type compare_implementations, %function

compare_implementations:
    stp x19, x20, [sp, #-32]!
    stp x21, x30, [sp, #16]

    mov x19, x0
    mov x20, x1

    bl crc32_bitwise
    mov w21, w0

    mov x0, x19
    mov x1, x20
    bl crc32_tablewise

    cmp w0, w21
    cset w0, ne

    ldp x21, x30, [sp, #16]
    ldp x19, x20, [sp], #32
    ret

.size compare_implementations, . - compare_implementations


.type print_message, %function

print_message:
    mov x0, #1
    mov x8, #64
    svc #0
    ret

.size print_message, . - print_message


.section .rodata

.equ CRC_EMPTY,        0x00000000
.equ CRC_SINGLE_A,     0xE8B7BE43
.equ CRC_STANDARD,     0xCBF43926
.equ CRC_HELLO,        0x3610A686
.equ CRC_BINARY,       0x37B2C8D3
.equ CRC_ALL_BYTES,    0x29058C73

.equ STATE_123,        0x77B79C2D
.equ STATE_123456,     0xF68D2C9E
.equ STATE_123456789,  0x340BC6D9


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


test_all_bytes:
    .byte 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
    .byte 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F
    .byte 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F
    .byte 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F
    .byte 0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F
    .byte 0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F
    .byte 0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F
    .byte 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F
    .byte 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F
    .byte 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9E, 0x9F
    .byte 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAE, 0xAF
    .byte 0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF
    .byte 0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD, 0xCE, 0xCF
    .byte 0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF
    .byte 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF
    .byte 0xF0, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF
.equ TEST_ALL_BYTES_LEN, . - test_all_bytes


chunk_123:
    .ascii "123"
.equ CHUNK_123_LEN, . - chunk_123


chunk_456:
    .ascii "456"
.equ CHUNK_456_LEN, . - chunk_456


chunk_789:
    .ascii "789"
.equ CHUNK_789_LEN, . - chunk_789


chunk_456789:
    .ascii "456789"
.equ CHUNK_456789_LEN, . - chunk_456789


pass_all_msg:
    .ascii "[PASS] All table-driven CRC32 tests passed (10/10)\n"
.equ PASS_ALL_LEN, . - pass_all_msg


fail_empty_msg:
    .ascii "[FAIL] table empty input\n"
.equ FAIL_EMPTY_LEN, . - fail_empty_msg

fail_single_a_msg:
    .ascii "[FAIL] table single-byte input\n"
.equ FAIL_SINGLE_A_LEN, . - fail_single_a_msg

fail_standard_msg:
    .ascii "[FAIL] table standard vector\n"
.equ FAIL_STANDARD_LEN, . - fail_standard_msg

fail_hello_msg:
    .ascii "[FAIL] table multi-byte text\n"
.equ FAIL_HELLO_LEN, . - fail_hello_msg

fail_binary_msg:
    .ascii "[FAIL] table binary input\n"
.equ FAIL_BINARY_LEN, . - fail_binary_msg

fail_chunks_msg:
    .ascii "[FAIL] table three-chunk streaming\n"
.equ FAIL_CHUNKS_LEN, . - fail_chunks_msg

fail_zero_length_msg:
    .ascii "[FAIL] table zero-length update\n"
.equ FAIL_ZERO_LENGTH_LEN, . - fail_zero_length_msg

fail_bytewise_msg:
    .ascii "[FAIL] table byte-by-byte streaming\n"
.equ FAIL_BYTEWISE_LEN, . - fail_bytewise_msg

fail_all_bytes_msg:
    .ascii "[FAIL] table all-byte-values input\n"
.equ FAIL_ALL_BYTES_LEN, . - fail_all_bytes_msg

fail_compare_msg:
    .ascii "[FAIL] bitwise/table equivalence\n"
.equ FAIL_COMPARE_LEN, . - fail_compare_msg


.section .note.GNU-stack,"",@progbits