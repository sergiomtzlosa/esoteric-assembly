// Brainfuck Interpreter in ARM64 Assembly for macOS

.global _main
.align 2

// Apple syscall numbers
.equ SYSCALL_EXIT, 1
.equ SYSCALL_READ, 3
.equ SYSCALL_WRITE, 4
.equ SYSCALL_OPEN, 5
.equ SYSCALL_CLOSE, 6

// Constants
.equ O_RDONLY, 0x0000
.equ TAPE_SIZE, 30000
.equ CODE_BUFFER_SIZE, 65536

.bss
    .align 4
    tape: .space TAPE_SIZE
    code_buffer: .space CODE_BUFFER_SIZE

.data
    usage_msg: .ascii "Usage: ./brainfuck <file>\n"
    usage_len = . - usage_msg
    
    error_open_msg: .ascii "Error: Could not open file\n"
    error_open_len = . - error_open_msg

    error_read_msg: .ascii "Error: Could not read file\n"
    error_read_len = . - error_read_msg

.text

_main:
    // x0 contains argc
    // x1 contains argv (pointer to array of pointers)
    
    // Check if argc == 2
    cmp x0, #2
    b.ne usage_error
    
    // Save argv[1] (filename) to x19 so we don't lose it
    ldr x19, [x1, #8]  // argv[0] is at offset 0, argv[1] at offset 8

    // Open file
    // syscall open(path, flags, mode)
    mov x0, x19        // path = argv[1]
    mov x1, #O_RDONLY  // flags = O_RDONLY
    mov x2, #0         // mode = 0 (ignored for reading)
    mov x16, #SYSCALL_OPEN
    svc #0x80
    
    // Check for error (result < 0 means error? actually on macOS check carry flag usually, but small neg integers are errors)
    // For now, let's assume a valid FD is positive. A generic error check is checking for -1.
    // However, syscalls return errors in a specific way on macOS (carry flag set).
    b.cs open_error    // Branch if Carry Set (error occurred)
    
    mov x20, x0        // Save File Descriptor (fd) to x20
    
    // Read file into code_buffer
    // syscall read(fd, buffer, size)
    mov x0, x20             // fd
    adrp x1, code_buffer@PAGE
    add x1, x1, code_buffer@PAGEOFF // buffer
    mov x2, #CODE_BUFFER_SIZE // size
    mov x16, #SYSCALL_READ
    svc #0x80
    
    b.cs read_error    // Branch if Carry Set
    
    mov x21, x0        // Save number of bytes read to x21
    
    // Close file
    // syscall CLOSE = 6
    mov x0, x20       // fd
    mov x16, #6       // SYSCALL_CLOSE
    svc #0x80

    // Initialize Pointers
    // x19: Instruction Pointer (IP) - currently points to start of code_buffer
    adrp x19, code_buffer@PAGE
    add x19, x19, code_buffer@PAGEOFF
    
    // x28: End of Code Pointer
    add x28, x19, x21 

    // x20: Data Pointer (DP) - points to start of tape
    adrp x20, tape@PAGE
    add x20, x20, tape@PAGEOFF
    
    // Zero out the tape (optional if .bss is zeroed, but good practice)
    // For now assuming .bss is zero initialized by OS.

interpretation_loop:
    cmp x19, x28
    b.ge program_exit  // If IP >= End of Code, exit

    ldrb w22, [x19]    // Load instruction byte

    // Switch case for instructions
    cmp w22, #62       // '>'
    b.eq instr_inc_ptr
    cmp w22, #60       // '<'
    b.eq instr_dec_ptr
    cmp w22, #43       // '+'
    b.eq instr_inc_val
    cmp w22, #45       // '-'
    b.eq instr_dec_val
    cmp w22, #46       // '.'
    b.eq instr_output
    cmp w22, #44       // ','
    b.eq instr_input
    cmp w22, #91       // '['
    b.eq instr_loop_start
    cmp w22, #93       // ']'
    b.eq instr_loop_end
    
    // Ignore other characters (comments)
    b next_instr

instr_inc_ptr:
    add x20, x20, #1
    b next_instr

instr_dec_ptr:
    sub x20, x20, #1
    b next_instr

instr_inc_val:
    ldrb w23, [x20]
    add w23, w23, #1
    strb w23, [x20]
    b next_instr

instr_dec_val:
    ldrb w23, [x20]
    sub w23, w23, #1
    strb w23, [x20]
    b next_instr

instr_output:
    // write(1, x20, 1)
    mov x0, #1          // stdout
    mov x1, x20         // buffer = current data pointer
    mov x2, #1          // length = 1
    mov x16, #4         // SYSCALL_WRITE
    svc #0x80
    b next_instr

instr_input:
    // read(0, x20, 1)
    mov x0, #0          // stdin
    mov x1, x20         // buffer = current data pointer
    mov x2, #1          // length = 1
    mov x16, #3         // SYSCALL_READ
    svc #0x80
    b next_instr

instr_loop_start:
    ldrb w23, [x20]    // Check data at current cell
    cbz w23, find_matching_close
    b next_instr

find_matching_close:
    mov x24, #1        // depth = 1
    mov x25, x19       // scan pointer = current IP
    
scan_forward:
    add x25, x25, #1
    cmp x25, x28       // Check bounds
    b.ge program_exit  // Error: unmatched [

    ldrb w26, [x25]
    cmp w26, #91       // '['
    b.eq inc_depth
    cmp w26, #93       // ']'
    b.eq dec_depth
    b scan_forward

inc_depth:
    add x24, x24, #1
    b scan_forward

dec_depth:
    sub x24, x24, #1
    cbnz x24, scan_forward
    
    // Found matching ] at x25
    mov x19, x25
    b next_instr

instr_loop_end:
    ldrb w23, [x20]
    cbnz w23, find_matching_open
    b next_instr

find_matching_open:
    mov x24, #1        // depth = 1
    mov x25, x19       // scan pointer = current IP

scan_backward:
    sub x25, x25, #1
    // Need to check bounds? If we go below code_buffer start... 
    // Assuming valid brainfuck code, will find match. Safe check:
    // cmp x25, code_buffer_start
    
    ldrb w26, [x25]
    cmp w26, #93       // ']'
    b.eq inc_depth_back
    cmp w26, #91       // '['
    b.eq dec_depth_back
    b scan_backward

inc_depth_back:
    add x24, x24, #1
    b scan_backward

dec_depth_back:
    sub x24, x24, #1
    cbnz x24, scan_backward
    
    // Found matching [ at x25
    mov x19, x25
    b next_instr


next_instr:
    add x19, x19, #1
    b interpretation_loop

program_exit:
    mov x0, #0
    mov x16, #1         // SYSCALL_EXIT
    svc #0x80


usage_error:
    mov x0, #1         // stdout
    adrp x1, usage_msg@PAGE
    add x1, x1, usage_msg@PAGEOFF
    mov x2, usage_len
    mov x16, #SYSCALL_WRITE
    svc #0x80
    
    mov x0, #1
    mov x16, #SYSCALL_EXIT
    svc #0x80

open_error:
    mov x0, #1         // stdout (or stderr 2)
    adrp x1, error_open_msg@PAGE
    add x1, x1, error_open_msg@PAGEOFF
    mov x2, error_open_len
    mov x16, #SYSCALL_WRITE
    svc #0x80
    
    mov x0, #1
    mov x16, #SYSCALL_EXIT
    svc #0x80

read_error:
    mov x0, #1
    adrp x1, error_read_msg@PAGE
    add x1, x1, error_read_msg@PAGEOFF
    mov x2, error_read_len
    mov x16, #SYSCALL_WRITE
    svc #0x80
    
    mov x0, #1
    mov x16, #SYSCALL_EXIT
    svc #0x80
