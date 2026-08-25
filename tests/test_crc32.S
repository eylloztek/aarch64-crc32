.section .text

.global _start
.type _start, %function

.extern crc32_init
.extern crc32_update
.extern crc32_finalize
.extern crc32_bitwise


_start:
    /*
     * Test 1: Empty input through one-shot API.
     */
    adrp x0, test_empty
    add x0, x0, :lo12:test_empty
    mov x1, #TEST_EMPTY_LEN
    ldr w2, =CRC_EMPTY

    bl run_one_shot_test
    cbnz w0, .Lfail_empty

    /*
     * Test 2: Single-byte input through one-shot API.
     */
    adrp x0, test_single_a
    add x0, x0, :lo12:test_single_a
    mov x1, #TEST_SINGLE_A_LEN
    ldr w2, =CRC_SINGLE_A

    bl run_one_shot_test
    cbnz w0, .Lfail_single_a

    /*
     * Test 3: Standard test vector through one-shot API.
     */
    adrp x0, test_standard
    add x0, x0, :lo12:test_standard
    mov x1, #TEST_STANDARD_LEN
    ldr w2, =CRC_STANDARD

    bl run_one_shot_test
    cbnz w0, .Lfail_standard

    /*
     * Test 4: Multi-byte text through one-shot API.
     */
    adrp x0, test_hello
    add x0, x0, :lo12:test_hello
    mov x1, #TEST_HELLO_LEN
    ldr w2, =CRC_HELLO

    bl run_one_shot_test
    cbnz w0, .Lfail_hello

    /*
     * Test 5: Binary input through one-shot API.
     */
    adrp x0, test_binary
    add x0, x0, :lo12:test_binary
    mov x1, #TEST_BINARY_LEN
    ldr w2, =CRC_BINARY

    bl run_one_shot_test
    cbnz w0, .Lfail_binary


    /*
     * Test 6:
     * Stream "123" + "456" + "789".
     *
     * Also verify internal states after the first
     * and second chunks.
     */
    bl crc32_init

    adrp x1, chunk_123
    add x1, x1, :lo12:chunk_123
    mov x2, #CHUNK_123_LEN
    bl crc32_update

    ldr w9, =STATE_123
    cmp w0, w9
    b.ne .Lfail_stream_chunks

    adrp x1, chunk_456
    add x1, x1, :lo12:chunk_456
    mov x2, #CHUNK_456_LEN
    bl crc32_update

    ldr w9, =STATE_123456
    cmp w0, w9
    b.ne .Lfail_stream_chunks

    adrp x1, chunk_789
    add x1, x1, :lo12:chunk_789
    mov x2, #CHUNK_789_LEN
    bl crc32_update

    bl crc32_finalize

    ldr w9, =CRC_STANDARD
    cmp w0, w9
    b.ne .Lfail_stream_chunks


    /*
     * Test 7:
     * A zero-length update must preserve the state.
     *
     * Passing x1 = 0 also verifies that update()
     * does not dereference the pointer when length = 0.
     */
    bl crc32_init

    adrp x1, chunk_123
    add x1, x1, :lo12:chunk_123
    mov x2, #CHUNK_123_LEN
    bl crc32_update

    mov x1, #0
    mov x2, #0
    bl crc32_update

    ldr w9, =STATE_123
    cmp w0, w9
    b.ne .Lfail_zero_length

    adrp x1, chunk_456789
    add x1, x1, :lo12:chunk_456789
    mov x2, #CHUNK_456789_LEN
    bl crc32_update

    bl crc32_finalize

    ldr w9, =CRC_STANDARD
    cmp w0, w9
    b.ne .Lfail_zero_length


    /*
     * Test 8:
     * Feed "123456789" one byte at a time.
     */
    bl crc32_init
    mov w21, w0

    adrp x19, test_standard
    add x19, x19, :lo12:test_standard
    mov x20, #TEST_STANDARD_LEN

.Lbytewise_loop:
    mov w0, w21
    mov x1, x19
    mov x2, #1

    bl crc32_update

    mov w21, w0

    add x19, x19, #1
    subs x20, x20, #1
    b.ne .Lbytewise_loop

    mov w0, w21
    bl crc32_finalize

    ldr w9, =CRC_STANDARD
    cmp w0, w9
    b.ne .Lfail_bytewise


    /*
     * Test 9:
     * Split binary data into 2-byte and 3-byte chunks.
     */
    bl crc32_init

    adrp x1, test_binary
    add x1, x1, :lo12:test_binary
    mov x2, #2
    bl crc32_update

    adrp x1, test_binary
    add x1, x1, :lo12:test_binary
    add x1, x1, #2
    mov x2, #3
    bl crc32_update

    bl crc32_finalize

    ldr w9, =CRC_BINARY
    cmp w0, w9
    b.ne .Lfail_binary_split


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

.Lfail_stream_chunks:
    adrp x1, fail_stream_chunks_msg
    add x1, x1, :lo12:fail_stream_chunks_msg
    mov x2, #FAIL_STREAM_CHUNKS_LEN
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

.Lfail_binary_split:
    adrp x1, fail_binary_split_msg
    add x1, x1, :lo12:fail_binary_split_msg
    mov x2, #FAIL_BINARY_SPLIT_LEN


.Lreport_failure:
    bl print_message
    mov x0, #1


.Lexit:
    mov x8, #93
    svc #0

.size _start, . - _start


/*
 * int run_one_shot_test(
 *     const uint8_t *data,
 *     uint64_t length,
 *     uint32_t expected
 * )
 *
 * Arguments:
 *   x0 = input pointer
 *   x1 = input length
 *   w2 = expected CRC
 *
 * Returns:
 *   w0 = 0 on success
 *   w0 = 1 on failure
 */
.type run_one_shot_test, %function

run_one_shot_test:
    stp x19, x30, [sp, #-16]!
    mov w19, w2

    bl crc32_bitwise

    cmp w0, w19
    cset w0, ne

    ldp x19, x30, [sp], #16
    ret

.size run_one_shot_test, . - run_one_shot_test


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


.equ CRC_EMPTY,       0x00000000
.equ CRC_SINGLE_A,    0xE8B7BE43
.equ CRC_STANDARD,    0xCBF43926
.equ CRC_HELLO,       0x3610A686
.equ CRC_BINARY,      0x37B2C8D3

.equ STATE_123,       0x77B79C2D
.equ STATE_123456,    0xF68D2C9E


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
    .ascii "[PASS] All CRC32 tests passed (9/9)\n"
.equ PASS_ALL_LEN, . - pass_all_msg


fail_empty_msg:
    .ascii "[FAIL] one-shot empty input\n"
.equ FAIL_EMPTY_LEN, . - fail_empty_msg


fail_single_a_msg:
    .ascii "[FAIL] one-shot single-byte input\n"
.equ FAIL_SINGLE_A_LEN, . - fail_single_a_msg


fail_standard_msg:
    .ascii "[FAIL] one-shot standard vector\n"
.equ FAIL_STANDARD_LEN, . - fail_standard_msg


fail_hello_msg:
    .ascii "[FAIL] one-shot multi-byte text\n"
.equ FAIL_HELLO_LEN, . - fail_hello_msg


fail_binary_msg:
    .ascii "[FAIL] one-shot binary input\n"
.equ FAIL_BINARY_LEN, . - fail_binary_msg


fail_stream_chunks_msg:
    .ascii "[FAIL] three-chunk streaming test\n"
.equ FAIL_STREAM_CHUNKS_LEN, . - fail_stream_chunks_msg


fail_zero_length_msg:
    .ascii "[FAIL] zero-length streaming update\n"
.equ FAIL_ZERO_LENGTH_LEN, . - fail_zero_length_msg


fail_bytewise_msg:
    .ascii "[FAIL] byte-by-byte streaming test\n"
.equ FAIL_BYTEWISE_LEN, . - fail_bytewise_msg


fail_binary_split_msg:
    .ascii "[FAIL] split binary streaming test\n"
.equ FAIL_BINARY_SPLIT_LEN, . - fail_binary_split_msg


.section .note.GNU-stack,"",@progbits