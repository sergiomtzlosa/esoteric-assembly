// Ook! Interpreter in ARM64 Assembly
// Usage: ./ook <filename>

.global _main
.align 2

// -----------------------------------------------------------------------------
// Constants
// -----------------------------------------------------------------------------
.equ SYSCALL_EXIT, 1
.equ SYSCALL_READ, 3
.equ SYSCALL_WRITE, 4
.equ SYSCALL_OPEN, 5
.equ SYSCALL_CLOSE, 6
.equ SYSCALL_MMAP, 197

.equ O_RDONLY, 0

.equ PROT_READ_WRITE, 0x3
.equ MAP_ANON_PRIVATE, 0x1002

.equ BUFFER_SIZE, 1024 * 1024
.equ OPS_SIZE, 1024 * 512
.equ TAPE_SIZE, 30000

// -----------------------------------------------------------------------------
// Data Section
// -----------------------------------------------------------------------------
.data
    // Error messages
    msg_usage:      .asciz "Usage: ./ook <filename>\n"
    msg_open_err:   .asciz "Error: Could not open file\n"
    msg_read_err:   .asciz "Error: Could not read file\n"
    msg_parse_err:  .asciz "Error: Invalid Ook! sequence\n"
    msg_unbalanced: .asciz "Error: Unbalanced loops\n"

// -----------------------------------------------------------------------------
// BSS Section (Uninitialized Data)
// -----------------------------------------------------------------------------
.bss
    .align 4
    file_fd:        .space 4
    read_len:       .space 8
    
    // Using static buffers
    .align 16
    read_buffer:    .space BUFFER_SIZE
    ops_buffer:     .space OPS_SIZE
    jump_map:       .space OPS_SIZE * 4
    tape:           .space TAPE_SIZE
    loop_stack:     .space 4096

// -----------------------------------------------------------------------------
// Code Section
// -----------------------------------------------------------------------------
.text

_main:
    // Standard C entry point:
    // x0 = argc
    // x1 = argv (pointer to array of strings)
    
    cmp x0, #2
    b.lt usage_error        // If argc < 2

    // argv is in x1. argv[0] at [x1], argv[1] at [x1, #8]
    ldr x19, [x1, #8]       // Load argv[1] (filename) into x19

    // Open file
    mov x0, x19             // Path
    mov x1, #O_RDONLY       // Flags
    mov x2, #0              // Mode
    mov x16, #SYSCALL_OPEN
    svc #0
    
    // Check for error (negative result)
    cmp x0, #0
    b.lt open_error
    
    adrp x1, file_fd@PAGE
    add x1, x1, file_fd@PAGEOFF
    str w0, [x1]            // Store FD

    // Read File
    // x0 is already fd
    adrp x1, read_buffer@PAGE
    add x1, x1, read_buffer@PAGEOFF
    mov x2, #BUFFER_SIZE
    mov x16, #SYSCALL_READ
    svc #0

    cmp x0, #0
    b.lt read_error
    
    // Store read length
    adrp x1, read_len@PAGE
    add x1, x1, read_len@PAGEOFF
    str x0, [x1]

    // Close File
    adrp x0, file_fd@PAGE
    add x0, x0, file_fd@PAGEOFF
    ldr w0, [x0]
    mov x16, #SYSCALL_CLOSE
    svc #0

    // -------------------------------------------------------------------------
    // Parsing Phase
    // -------------------------------------------------------------------------
    // We will scan the read_buffer for '.', '?', '!'.
    // We treat them as 0, 1, 2.
    // We read them in pairs to determine the instruction.
    
    adrp x19, read_buffer@PAGE
    add x19, x19, read_buffer@PAGEOFF  // x19 = current read ptr
    
    adrp x1, read_len@PAGE
    add x1, x1, read_len@PAGEOFF
    ldr x20, [x1]
    add x20, x19, x20                  // x20 = read buffer end
    
    adrp x21, ops_buffer@PAGE
    add x21, x21, ops_buffer@PAGEOFF   // x21 = ops write ptr
    
    mov x22, #-1                       // x22 = first half of pair (-1 if expecting first, 0-2 if expecting second)

parse_loop:
    cmp x19, x20
    b.ge parse_done                    // If current >= end, we are done

    ldrb w0, [x19], #1                 // Load byte and increment
    
    // Check for Ook punctuation
    cmp w0, #'.'
    b.eq is_dot
    cmp w0, #'?'
    b.eq is_question
    cmp w0, #'!'
    b.eq is_exclaim
    b parse_loop                       // Skip other characters

is_dot:
    mov w0, #0
    b process_token
is_question:
    mov w0, #1
    b process_token
is_exclaim:
    mov w0, #2
    b process_token

process_token:
    cmp x22, #-1
    b.ne have_first
    
    // This is the first token of a pair
    mov w22, w0
    b parse_loop

have_first:
    // We have a pair: (x22, w0)
    // Map pairs to opcodes:
    // 0,1 (.?) -> > (Right) -> Op 1
    // 1,0 (?.) -> < (Left)  -> Op 2
    // 0,0 (..) -> + (Inc)   -> Op 3
    // 2,2 (!!) -> - (Dec)   -> Op 4
    // 2,0 (!.) -> . (Print) -> Op 5
    // 0,2 (.!) -> , (Read)  -> Op 6
    // 2,1 (!?) -> [ (Start) -> Op 7
    // 1,2 (?!) -> ] (End)   -> Op 8
    
    // Encode pair as (first << 2) | second
    // 0=., 1=?, 2=!
    lsl w23, w22, #2
    orr w23, w23, w0
    
    // Switch on encoded pair
    cmp w23, #(0<<2 | 1) // 1 (.?)
    b.eq emit_right
    cmp w23, #(1<<2 | 0) // 4 (?.)
    b.eq emit_left
    cmp w23, #(0<<2 | 0) // 0 (..)
    b.eq emit_inc
    cmp w23, #(2<<2 | 2) // 10 (!!)
    b.eq emit_dec
    cmp w23, #(2<<2 | 0) // 8 (!.)
    b.eq emit_print
    cmp w23, #(0<<2 | 2) // 2 (.!)
    b.eq emit_read
    cmp w23, #(2<<2 | 1) // 9 (!?)
    b.eq emit_loop_start
    cmp w23, #(1<<2 | 2) // 6 (?!)
    b.eq emit_loop_end
    
    // Invalid pair? Just ignore? Or error?
    // User requested spec says valid Ook is these pairs. 
    // We'll ignore invalid pairings for now or treat as no-op.
    mov x22, #-1
    b parse_loop

emit_right:
    mov w0, #1
    b emit
emit_left:
    mov w0, #2
    b emit
emit_inc:
    mov w0, #3
    b emit
emit_dec:
    mov w0, #4
    b emit
emit_print:
    mov w0, #5
    b emit
emit_read:
    mov w0, #6
    b emit
emit_loop_start:
    mov w0, #7
    b emit
emit_loop_end:
    mov w0, #8
    b emit

emit:
    strb w0, [x21], #1
    mov x22, #-1
    b parse_loop

parse_done:
    // Verify we are not half-way through a pair
    cmp x22, #-1
    b.ne unclosed_pair_error
    
    // Calculate op count
    adrp x0, ops_buffer@PAGE
    add x0, x0, ops_buffer@PAGEOFF
    sub x19, x21, x0            // x19 = total ops count

    // -------------------------------------------------------------------------
    // Jump Table Computation (Pre-compute brackets)
    // -------------------------------------------------------------------------
    // x19 = ops count
    // x0 = ops_buffer start
    // x20 = current op index
    // x21 = stack pointer for loops (using loop_stack buffer)
    
    adrp x21, loop_stack@PAGE
    add x21, x21, loop_stack@PAGEOFF
    
    adrp x22, jump_map@PAGE
    add x22, x22, jump_map@PAGEOFF  // x22 = jump_map base
    
    mov x20, #0                 // Current index
    
compute_jumps_loop:
    cmp x20, x19
    b.ge compute_jumps_done
    
    ldrb w1, [x0, x20]          // Load op
    
    cmp w1, #7                  // [ Loop Start
    b.eq push_stack
    cmp w1, #8                  // ] Loop End
    b.eq pop_stack
    b next_jump_op

push_stack:
    // Store current index on stack
    str w20, [x21], #4          // Push index, increment stack ptr
    b next_jump_op

pop_stack:
    // Check underflow
    adrp x2, loop_stack@PAGE
    add x2, x2, loop_stack@PAGEOFF
    cmp x21, x2
    b.eq unbalanced_error
    
    sub x21, x21, #4
    ldr w23, [x21]              // w23 = start index
    
    // We have a pair: Start=w23. End=w20.
    // Store in jump_map
    // jump_map[start] = end
    // jump_map[end] = start
    
    // Start -> End
    str w20, [x22, x23, lsl #2] // x22 + x23*4 = end
    
    // End -> Start
    str w23, [x22, x20, lsl #2] // x22 + x20*4 = start
    
    b next_jump_op

next_jump_op:
    add x20, x20, #1
    b compute_jumps_loop

compute_jumps_done:
    // Check if stack is empty (balanced)
    adrp x2, loop_stack@PAGE
    add x2, x2, loop_stack@PAGEOFF
    cmp x21, x2
    b.ne unbalanced_error
    
execution_phase:
    // -------------------------------------------------------------------------
    // Execution Phase
    // -------------------------------------------------------------------------
    // Setup registers
    // x19 = ops count
    // x20 = PC (Instruction Pointer)
    adrp x21, tape@PAGE
    add x21, x21, tape@PAGEOFF  // x21 = tape base
    mov x22, #0                 // x22 = tape pointer offset
    
    adrp x23, ops_buffer@PAGE
    add x23, x23, ops_buffer@PAGEOFF // x23 = ops base
    
    adrp x24, jump_map@PAGE
    add x24, x24, jump_map@PAGEOFF   // x24 = jump map base
    
    mov x20, #0                 // PC = 0

exec_loop:
    cmp x20, x19
    b.ge end_program            // PC >= Ops Count -> Done
    
    ldrb w0, [x23, x20]         // Load instruction
    
    // Jump table for execution (1-8)
    cmp w0, #1
    b.eq do_right
    cmp w0, #2
    b.eq do_left
    cmp w0, #3
    b.eq do_inc
    cmp w0, #4
    b.eq do_dec
    cmp w0, #5
    b.eq do_print
    cmp w0, #6
    b.eq do_read
    cmp w0, #7
    b.eq do_loop_start
    cmp w0, #8
    b.eq do_loop_end
    
    // Unknown op?
    add x20, x20, #1
    b exec_loop

do_right:
    add x22, x22, #1
    add x20, x20, #1
    b exec_loop

do_left:
    sub x22, x22, #1
    add x20, x20, #1
    b exec_loop

do_inc:
    ldrb w0, [x21, x22]
    add w0, w0, #1
    strb w0, [x21, x22]
    add x20, x20, #1
    b exec_loop

do_dec:
    ldrb w0, [x21, x22]
    sub w0, w0, #1
    strb w0, [x21, x22]
    add x20, x20, #1
    b exec_loop

do_print:
    // Write 1 byte from tape to stdout
    // We need address: x21 + x22
    add x1, x21, x22
    mov x0, #1                  // stdout
    mov x2, #1                  // len = 1
    mov x16, #SYSCALL_WRITE
    svc #0
    
    add x20, x20, #1
    b exec_loop

do_read:
    // Read 1 byte from stdin to tape
    add x1, x21, x22
    mov x0, #0                  // stdin
    mov x2, #1                  // len = 1
    mov x16, #SYSCALL_READ
    svc #0
    
    // If read returns 0 (EOF), current cell unchanged or set to 0?
    // Brainfuck spec varies. Some say 0, some say -1, some say unchanged.
    // We'll leave it as is or maybe we should zero it if EOF?
    // Let's assume standard behavior is unchanged.
    
    add x20, x20, #1
    b exec_loop

do_loop_start:
    // if *ptr == 0, jump to matching ]
    ldrb w0, [x21, x22]
    cbz w0, take_jump
    
    // Else, continue
    add x20, x20, #1
    b exec_loop

do_loop_end:
    // if *ptr != 0, jump to matching [
    ldrb w0, [x21, x22]
    cbnz w0, take_jump
    
    // Else, continue
    add x20, x20, #1
    b exec_loop

take_jump:
    // Load target from jump_map[PC]
    ldr w20, [x24, x20, lsl #2]
    // Note: If we jump to matching bracket, do we execute it?
    // If we are at [, and jump to ], we land on ]. Next iter we increment PC?
    // No, standard BF logic:
    // [ -> If 0, jump AFTER ]. 
    // ] -> If !0, jump AFTER [. 
    // BUT usually easier to jump TO the bracket and then next iter process it?
    // Wait. 
    // If at [ and 0: Jump to matching ]. Next instruction should be ]+1.
    // If at ] and !0: Jump to matching [. Next instruction should be [+1.
    // So my logic is:
    // do_loop_start: Check 0. If 0, new_pc = matching_end.
    // new_pc points to `]`. Next iter, we load `]`, see it's 8.
    // `do_loop_end`: Check !0. Since we just came here because it WAS 0, it is likely still 0 (unless tape changed magically).
    // So `]` sees 0, and continues to PC+1. Correct.
    
    // Reverse:
    // `]`: Check !0. If !0, new_pc = matching_start.
    // new_pc points to `[`. Next iter, we load `[`.
    // `do_loop_start`: Check 0. It's !0. Continue PC+1. Correct.
    
    // So jumping TO the matching bracket works fine with this loop structure.
    b exec_loop
unclosed_pair_error:
    adrp x0, msg_parse_err@PAGE
    add x0, x0, msg_parse_err@PAGEOFF
    bl print_str
    mov x0, #1
    b exit

unbalanced_error:
    adrp x0, msg_unbalanced@PAGE
    add x0, x0, msg_unbalanced@PAGEOFF
    bl print_str
    mov x0, #1
    b exit

usage_error:
    adrp x0, msg_usage@PAGE
    add x0, x0, msg_usage@PAGEOFF
    bl print_str
    mov x0, #1
    b exit

open_error:
    adrp x0, msg_open_err@PAGE
    add x0, x0, msg_open_err@PAGEOFF
    bl print_str
    mov x0, #1
    b exit

read_error:
    adrp x0, msg_read_err@PAGE
    add x0, x0, msg_read_err@PAGEOFF
    bl print_str
    mov x0, #1
    b exit

// Helper to print null-terminated string in x0
print_str:
    mov x1, x0              // buffer
    // Calculate length
    mov x2, #0
1:
    ldrb w3, [x1, x2]
    cbz w3, 2f
    add x2, x2, #1
    b 1b
2:
    mov x0, #1              // stdout
    mov x16, #SYSCALL_WRITE
    svc #0
    ret

end_program:
    mov x0, #0
exit:
    mov x16, #SYSCALL_EXIT
    svc #0
