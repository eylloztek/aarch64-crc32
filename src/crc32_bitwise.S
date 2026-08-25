.section .text


.global crc32_init
.type crc32_init, %function

/*
 * uint32_t crc32_init(void)
 *
 * Returns:
 *   w0 = initial internal CRC state
 */
crc32_init:
    mov w0, #-1
    ret

.size crc32_init, . - crc32_init


.global crc32_update
.type crc32_update, %function

/*
 * uint32_t crc32_update(uint32_t state, const uint8_t *data, uint64_t length)
 *
 * Arguments:
 *   w0 = current internal CRC state
 *   x1 = pointer to input data
 *   x2 = input length in bytes
 *
 * Returns:
 *   w0 = updated internal CRC state
 *
 * Note:
 *   This function does not apply the final XOR.
 */
crc32_update:
    movz w3, #0x8320
    movk w3, #0xEDB8, lsl #16

    cbz x2, .Lupdate_done

.Lupdate_byte_loop:
    ldrb w4, [x1], #1
    eor w0, w0, w4

    mov w5, #8

.Lupdate_bit_loop:
    tst w0, #1
    lsr w0, w0, #1

    b.eq .Lupdate_skip_xor
    eor w0, w0, w3

.Lupdate_skip_xor:
    subs w5, w5, #1
    b.ne .Lupdate_bit_loop

    subs x2, x2, #1
    b.ne .Lupdate_byte_loop

.Lupdate_done:
    ret

.size crc32_update, . - crc32_update


.global crc32_finalize
.type crc32_finalize, %function

/*
 * uint32_t crc32_finalize(uint32_t state)
 *
 * Arguments:
 *   w0 = internal CRC state
 *
 * Returns:
 *   w0 = finalized CRC-32 checksum
 */
crc32_finalize:
    mvn w0, w0
    ret

.size crc32_finalize, . - crc32_finalize


.global crc32_bitwise
.type crc32_bitwise, %function

/*
 * uint32_t crc32_bitwise(const uint8_t *data, uint64_t length)
 *
 * Compatibility one-shot API.
 *
 * Arguments:
 *   x0 = pointer to input data
 *   x1 = input length in bytes
 *
 * Returns:
 *   w0 = finalized CRC-32 checksum
 */
crc32_bitwise:
    stp x19, x20, [sp, #-32]!
    str x30, [sp, #16]

    mov x19, x0
    mov x20, x1

    bl crc32_init

    mov x1, x19
    mov x2, x20
    bl crc32_update

    bl crc32_finalize

    ldr x30, [sp, #16]
    ldp x19, x20, [sp], #32
    ret

.size crc32_bitwise, . - crc32_bitwise


.section .note.GNU-stack,"",@progbits