.section .text

.global crc32_init
.type crc32_init, %function

/*
 * uint32_t crc32_init(void)
 *
 * Returns:
 *   w0 = initial internal CRC state (0xFFFFFFFF)
 */
crc32_init:
    mov w0, #-1
    ret

.size crc32_init, . - crc32_init


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


.section .note.GNU-stack,"",@progbits