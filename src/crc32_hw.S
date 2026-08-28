.section .text

.extern crc32_init
.extern crc32_finalize


.global crc32_update_hw
.type crc32_update_hw, %function

/*
 * uint32_t crc32_update_hw(uint32_t state, const uint8_t *data, uint64_t length)
 *
 * Arguments:
 *   w0 = current internal CRC state
 *   x1 = pointer to input data
 *   x2 = input length in bytes
 *
 * Returns:
 *   w0 = updated internal CRC state
 *
 * Requires:
 *   Arm CRC32 extension (FEAT_CRC32)
 *
 * Processing strategy:
 *   8-byte blocks -> CRC32X
 *   4-byte tail   -> CRC32W
 *   2-byte tail   -> CRC32H
 *   1-byte tail   -> CRC32B
 */
crc32_update_hw:
    cbz x2, .Lhw_done

.Lhw_x_loop:
    cmp x2, #8
    b.lo .Lhw_word

    ldr x3, [x1], #8
    crc32x w0, w0, x3

    sub x2, x2, #8
    b .Lhw_x_loop


.Lhw_word:
    cmp x2, #4
    b.lo .Lhw_half

    ldr w3, [x1], #4
    crc32w w0, w0, w3

    sub x2, x2, #4


.Lhw_half:
    cmp x2, #2
    b.lo .Lhw_byte

    ldrh w3, [x1], #2
    crc32h w0, w0, w3

    sub x2, x2, #2


.Lhw_byte:
    cbz x2, .Lhw_done

    ldrb w3, [x1]
    crc32b w0, w0, w3


.Lhw_done:
    ret

.size crc32_update_hw, . - crc32_update_hw


.global crc32_hardware
.type crc32_hardware, %function

/*
 * uint32_t crc32_hardware(const uint8_t *data, uint64_t length)
 *
 * One-shot hardware-assisted CRC-32 API.
 */
crc32_hardware:
    stp x19, x20, [sp, #-32]!
    str x30, [sp, #16]

    mov x19, x0
    mov x20, x1

    bl crc32_init

    mov x1, x19
    mov x2, x20
    bl crc32_update_hw

    bl crc32_finalize

    ldr x30, [sp, #16]
    ldp x19, x20, [sp], #32
    ret

.size crc32_hardware, . - crc32_hardware


.section .note.GNU-stack,"",@progbits