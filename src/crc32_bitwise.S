.section .text

.global crc32_bitwise
.type crc32_bitwise, %function

/*
 * uint32_t crc32_bitwise(const uint8_t *data, uint64_t length)
 *
 * Arguments:
 *   x0 = pointer to input data
 *   x1 = input length in bytes
 *
 * Returns:
 *   w0 = CRC-32/ISO-HDLC checksum
 *
 * CRC parameters:
 *   polynomial = 0xEDB88320 (reflected)
 *   init       = 0xFFFFFFFF
 *   xorout     = 0xFFFFFFFF
 */
crc32_bitwise:
    mov w2, #-1

    movz w3, #0x8320
    movk w3, #0xEDB8, lsl #16

    cbz x1, .Lcrc_done

.Lbyte_loop:
    ldrb w4, [x0], #1
    eor w2, w2, w4

    mov w5, #8

.Lbit_loop:
    tst w2, #1
    lsr w2, w2, #1

    b.eq .Lskip_xor
    eor w2, w2, w3

.Lskip_xor:
    subs w5, w5, #1
    b.ne .Lbit_loop

    subs x1, x1, #1
    b.ne .Lbyte_loop

.Lcrc_done:
    mvn w0, w2
    ret

.size crc32_bitwise, . - crc32_bitwise

.section .note.GNU-stack,"",@progbits