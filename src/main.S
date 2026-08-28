#ifndef CRC32_UPDATE_FN
#define CRC32_UPDATE_FN crc32_update_table
#endif

.section .text

.equ SYS_OPENAT, 56
.equ SYS_CLOSE,  57
.equ SYS_READ,   63
.equ SYS_WRITE,  64
.equ SYS_EXIT,   93

.equ AT_FDCWD,   -100
.equ O_RDONLY,   0

.equ BUFFER_SIZE, 4096


.global _start
.type _start, %function

.extern crc32_init
.extern CRC32_UPDATE_FN
.extern crc32_finalize


_start:
    /*
     * Linux AArch64 process entry stack:
     *
     *   [sp]      = argc
     *   [sp + 8]  = argv[0]
     *   [sp + 16] = argv[1]
     *
     * Require exactly one file argument.
     */
    ldr x9, [sp]
    cmp x9, #2
    b.ne .Lusage_error

    /*
     * openat(AT_FDCWD, argv[1], O_RDONLY, 0)
     */
    ldr x1, [sp, #16]
    mov x0, #AT_FDCWD
    mov x2, #O_RDONLY
    mov x3, #0
    mov x8, #SYS_OPENAT
    svc #0

    cmp x0, #0
    b.lt .Lopen_error

    /*
     * Keep the file descriptor in a callee-saved register.
     */
    mov x19, x0

    /*
     * Initialize CRC state.
     */
    bl crc32_init
    mov w20, w0

    /*
     * Keep the buffer address in x21.
     */
    adrp x21, io_buffer
    add x21, x21, :lo12:io_buffer


.Lread_loop:
    /*
     * read(fd, buffer, BUFFER_SIZE)
     */
    mov x0, x19
    mov x1, x21
    mov x2, #BUFFER_SIZE
    mov x8, #SYS_READ
    svc #0

    /*
     * x0 < 0  -> read error
     * x0 == 0 -> EOF
     * x0 > 0  -> number of bytes read
     */
    cmp x0, #0
    b.lt .Lread_error
    cbz x0, .Lread_done

    /*
     * crc32_update(state, buffer, bytes_read)
     *
     * w0 = state
     * x1 = buffer
     * x2 = bytes_read
     */
    mov x2, x0
    mov w0, w20
    mov x1, x21

    bl CRC32_UPDATE_FN

    mov w20, w0
    b .Lread_loop


.Lread_done:
    /*
     * close(fd)
     */
    mov x0, x19
    mov x8, #SYS_CLOSE
    svc #0

    /*
     * Finalize the accumulated CRC state.
     */
    mov w0, w20
    bl crc32_finalize

    /*
     * Print the result as eight uppercase hexadecimal digits.
     */
    bl print_hex32

    mov x0, #0
    b .Lexit


.Lusage_error:
    mov x0, #2

    adrp x1, usage_msg
    add x1, x1, :lo12:usage_msg

    mov x2, #USAGE_MSG_LEN
    bl write_message

    mov x0, #1
    b .Lexit


.Lopen_error:
    mov x0, #2

    adrp x1, open_error_msg
    add x1, x1, :lo12:open_error_msg

    mov x2, #OPEN_ERROR_MSG_LEN
    bl write_message

    mov x0, #2
    b .Lexit


.Lread_error:
    /*
     * The file was opened successfully, so close it before exiting.
     */
    mov x0, x19
    mov x8, #SYS_CLOSE
    svc #0

    mov x0, #2

    adrp x1, read_error_msg
    add x1, x1, :lo12:read_error_msg

    mov x2, #READ_ERROR_MSG_LEN
    bl write_message

    mov x0, #3


.Lexit:
    mov x8, #SYS_EXIT
    svc #0

.size _start, . - _start


/*
 * void write_message(int fd, const char *message, uint64_t length)
 *
 * Arguments:
 *   x0 = file descriptor
 *   x1 = message address
 *   x2 = message length
 */
.type write_message, %function

write_message:
    mov x8, #SYS_WRITE
    svc #0
    ret

.size write_message, . - write_message


/*
 * void print_hex32(uint32_t value)
 *
 * Arguments:
 *   w0 = 32-bit value
 *
 * Output:
 *   Eight uppercase hexadecimal characters followed by '\n'.
 *
 * Example:
 *   0xCBF43926 -> "CBF43926\n"
 */
.type print_hex32, %function

print_hex32:
    mov w9, w0

    adrp x10, hex_buffer
    add x10, x10, :lo12:hex_buffer

    mov x11, x10
    mov w12, #8

.Lhex_loop:
    /*
     * Extract the upper four bits.
     */
    lsr w13, w9, #28

    cmp w13, #9
    b.ls .Lhex_digit

    /*
     * 10..15 -> 'A'..'F'
     */
    add w13, w13, #55
    b .Lhex_store

.Lhex_digit:
    /*
     * 0..9 -> '0'..'9'
     */
    add w13, w13, #48

.Lhex_store:
    strb w13, [x10], #1

    /*
     * Move the next nibble into bits 31..28.
     */
    lsl w9, w9, #4

    subs w12, w12, #1
    b.ne .Lhex_loop

    mov w13, #10
    strb w13, [x10]

    /*
     * write(STDOUT_FILENO, hex_buffer, 9)
     */
    mov x0, #1
    mov x1, x11
    mov x2, #9
    mov x8, #SYS_WRITE
    svc #0

    ret

.size print_hex32, . - print_hex32


.section .rodata

usage_msg:
    .ascii "Usage: aarch64-crc32 <file>\n"
.equ USAGE_MSG_LEN, . - usage_msg


open_error_msg:
    .ascii "[ERROR] could not open file\n"
.equ OPEN_ERROR_MSG_LEN, . - open_error_msg


read_error_msg:
    .ascii "[ERROR] could not read file\n"
.equ READ_ERROR_MSG_LEN, . - read_error_msg


.section .bss

.balign 16

io_buffer:
    .skip BUFFER_SIZE


.balign 16

hex_buffer:
    .skip 9


.section .note.GNU-stack,"",@progbits