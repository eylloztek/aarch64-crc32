.section .text

.global _start
.type _start, %function

_start:
    adrp x0, test_data
    add x0, x0, :lo12:test_data
    mov x1, #TEST_LEN

    bl crc32_bitwise

    movz w1, #0x3926
    movk w1, #0xCBF4, lsl #16

    cmp w0, w1
    b.eq .Lpass

.Lfail:
    mov x0, #1

    adrp x1, fail_msg
    add x1, x1, :lo12:fail_msg

    mov x2, #FAIL_LEN
    mov x8, #64
    svc #0

    mov x0, #1
    mov x8, #93
    svc #0

.Lpass:
    mov x0, #1

    adrp x1, pass_msg
    add x1, x1, :lo12:pass_msg

    mov x2, #PASS_LEN
    mov x8, #64
    svc #0

    mov x0, #0
    mov x8, #93
    svc #0

.size _start, . - _start


.global crc32_bitwise
.type crc32_bitwise, %function

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


.section .rodata

.align 4

test_data:
    .ascii "123456789"

.equ TEST_LEN, . - test_data


pass_msg:
    .ascii "[PASS] CRC32 test vector matched\n"

.equ PASS_LEN, . - pass_msg


fail_msg:
    .ascii "[FAIL] CRC32 test vector mismatch\n"

.equ FAIL_LEN, . - fail_msg


.section .note.GNU-stack,"",@progbits