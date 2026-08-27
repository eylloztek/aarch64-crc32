.section .text

.extern crc32_init
.extern crc32_finalize


.global crc32_update
.global crc32_update_bitwise
.type crc32_update, %function
.type crc32_update_bitwise, %function

/*
 * uint32_t crc32_update_bitwise(uint32_t state, const uint8_t *data, uint64_t length)
 *
 * Arguments:
 *   w0 = current internal CRC state
 *   x1 = pointer to input data
 *   x2 = input length in bytes
 *
 * Returns:
 *   w0 = updated internal CRC state
 *
 * crc32_update is kept as a compatibility alias for the bitwise engine.
 */
crc32_update:
crc32_update_bitwise:
    movz w3, #0x8320
    movk w3, #0xEDB8, lsl #16

    cbz x2, .Lbitwise_update_done

.Lbitwise_byte_loop:
    ldrb w4, [x1], #1
    eor w0, w0, w4

    mov w5, #8

.Lbitwise_bit_loop:
    tst w0, #1
    lsr w0, w0, #1

    b.eq .Lbitwise_skip_xor
    eor w0, w0, w3

.Lbitwise_skip_xor:
    subs w5, w5, #1
    b.ne .Lbitwise_bit_loop

    subs x2, x2, #1
    b.ne .Lbitwise_byte_loop

.Lbitwise_update_done:
    ret

.size crc32_update_bitwise, . - crc32_update_bitwise
.size crc32_update, . - crc32_update


.global crc32_bitwise
.type crc32_bitwise, %function

/*
 * uint32_t crc32_bitwise(const uint8_t *data, uint64_t length)
 *
 * One-shot bitwise CRC-32 API.
 */
crc32_bitwise:
    stp x19, x20, [sp, #-32]!
    str x30, [sp, #16]

    mov x19, x0
    mov x20, x1

    bl crc32_init

    mov x1, x19
    mov x2, x20
    bl crc32_update_bitwise

    bl crc32_finalize

    ldr x30, [sp, #16]
    ldp x19, x20, [sp], #32
    ret

.size crc32_bitwise, . - crc32_bitwise


.section .note.GNU-stack,"",@progbits