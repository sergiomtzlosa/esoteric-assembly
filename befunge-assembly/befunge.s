.global _main
.align 2

// Constants
.equ SC_EXIT, 1
.equ SC_READ, 3
.equ SC_WRITE, 4
.equ SC_OPEN, 5
.equ SC_CLOSE, 6

.equ O_RDONLY, 0

.equ GRID_WIDTH, 80
.equ GRID_HEIGHT, 25
.equ GRID_SIZE, 2000
.equ STACK_SIZE, 8192

.data
    .align 4
    grid: .space GRID_SIZE
    stack: .space STACK_SIZE
    
    default_file: .asciz "hello.bf"
    newline: .ascii "\n"

.text

// Register Aliases
// x19: PC x
// x20: PC y
// x21: dx
// x22: dy
// x23: Stack Pointer (points to next free slot)
// x24: Grid Base Address
// x25: Stack Base Address
// x26: String Mode Flag (0 = off, 1 = on)

_main:
    // 1. Setup
    stp x29, x30, [sp, -16]!
    mov x29, sp

    // Save argc, argv
    mov x27, x0             // x27 = argc
    mov x28, x1             // x28 = argv

    mov x19, #0             // x = 0
    mov x20, #0             // y = 0
    mov x21, #1             // dx = 1
    mov x22, #0             // dy = 0
    
    adrp x24, grid@PAGE     
    add x24, x24, grid@PAGEOFF
    
    // Clear Grid
    mov x0, x24
    mov x1, #0x20
    mov x2, #GRID_SIZE
    bl _memset_custom

    adrp x25, stack@PAGE    
    add x25, x25, stack@PAGEOFF
    mov x23, x25            
    
    mov x26, #0             

    // 2. Load File
    // Check argc
    cmp x27, #2
    b.ge _load_arg_file
    
    // Load default
    mov x0, #-100           
    adrp x0, default_file@PAGE
    add x0, x0, default_file@PAGEOFF
    b _do_open

_load_arg_file:
    ldr x0, [x28, #8]       // argv[1]

_do_open:
    mov x1, #O_RDONLY
    mov x2, #0
    mov x16, #SC_OPEN
    svc #0
    
    cmp x0, #0
    b.lt _exit_error
    mov x10, x0             

    // Read loop
    mov x11, #0
    mov x12, #0

load_loop:
    sub sp, sp, #16
    mov x0, x10
    mov x1, sp
    mov x2, #1
    mov x16, #SC_READ
    svc #0
    
    cmp x0, #1
    b.ne load_done

    ldrb w13, [sp]
    add sp, sp, #16

    cmp w13, #10
    b.eq handle_newline

    // Store in grid
    mov x14, #GRID_WIDTH
    mul x14, x12, x14
    add x14, x14, x11
    cmp x14, #GRID_SIZE
    b.ge load_continue

    strb w13, [x24, x14]
    
    add x11, x11, #1
    cmp x11, #GRID_WIDTH
    b.lt load_loop
    mov x11, #0
    add x12, x12, #1
    b load_loop

handle_newline:
    mov x11, #0
    add x12, x12, #1
    b load_loop

load_continue:
    b load_loop

load_done:
    mov x0, x10
    mov x16, #SC_CLOSE
    svc #0

    // 3. Main Loop
interpret_loop:
    mov x0, #GRID_WIDTH
    mul x0, x20, x0
    add x0, x0, x19
    ldrb w0, [x24, x0]

    // Check String Mode
    cbnz x26, _handle_string_mode

    // Decode Normal Mode
    cmp w0, #'@'
    b.eq _exit_ok
    
    cmp w0, #'"'
    b.eq _toggle_string_mode

    cmp w0, #'>'
    b.eq _dir_right
    cmp w0, #'<'
    b.eq _dir_left
    cmp w0, #'^'
    b.eq _dir_up
    cmp w0, #'v'
    b.eq _dir_down
    cmp w0, #'?'
    b.eq _dir_right // Simplified

    cmp w0, #'#'
    b.eq _bridge
    
    // Conditionals
    cmp w0, #'_'
    b.eq _cond_horiz
    cmp w0, #'|'
    b.eq _cond_vert

    cmp w0, #'+'
    b.eq _op_add
    cmp w0, #'-'
    b.eq _op_sub
    cmp w0, #'*'
    b.eq _op_mul
    cmp w0, #'/'
    b.eq _op_div
    cmp w0, #'%'
    b.eq _op_mod
    
    cmp w0, #'!'
    b.eq _op_not
    cmp w0, #'`'
    b.eq _op_gt
    
    cmp w0, #'.'
    b.eq _op_print_int
    cmp w0, #','
    b.eq _op_print_char
    
    cmp w0, #':'
    b.eq _op_dup
    cmp w0, #'\\'   
    b.eq _op_swap
    cmp w0, #'$'
    b.eq _op_pop

    // Digits
    cmp w0, #'0'
    b.lt _check_space
    cmp w0, #'9'
    b.gt _check_space
    // Is digit
    sub w0, w0, #'0'
    str x0, [x23], #8
    b next_step

_check_space:
    // Ignore space (NOP)
    b next_step

_handle_string_mode:
    cmp w0, #'"'
    b.eq _toggle_string_mode
    // Push char code
    str x0, [x23], #8
    b next_step


// --- Instructions ---
_toggle_string_mode:
    eor x26, x26, #1
    b next_step

_bridge:
    // Move one extra step
    add x19, x19, x21
    // Wrap X
    cmp x19, #80
    b.ge 1f
    cmp x19, #0
    b.lt 2f
    b 3f
1:  sub x19, x19, #80
    b 3f
2:  add x19, x19, #80
3:
    // Y
    add x20, x20, x22
    cmp x20, #25
    b.ge 1f
    cmp x20, #0
    b.lt 2f
    b 3f
1:  sub x20, x20, #25
    b 3f
2:  add x20, x20, #25
3:
    b next_step

_dir_right:
    mov x21, #1
    mov x22, #0
    b next_step
_dir_left:
    mov x21, #-1
    mov x22, #0
    b next_step
_dir_up:
    mov x21, #0
    mov x22, #-1
    b next_step
_dir_down:
    mov x21, #0
    mov x22, #1
    b next_step

_cond_horiz:
    // Pop x, if x=0 right, else left
    cmp x23, x25
    b.eq _ch_zero 
    sub x23, x23, #8
    ldr x0, [x23]
    cbz x0, _ch_zero
    // Non-zero: left
    b _dir_left
_ch_zero:
    // Zero: right
    b _dir_right

_cond_vert:
    // Pop x, if x=0 down, else up
    cmp x23, x25
    b.eq _cv_zero
    sub x23, x23, #8
    ldr x0, [x23]
    cbz x0, _cv_zero
    // Non-zero: up
    b _dir_up
_cv_zero:
    // Zero: down
    b _dir_down

// Stack Ops
_op_dup:
    cmp x23, x25            
    b.eq _stack_empty_dup
    ldr x0, [x23, #-8]      
    str x0, [x23], #8       
    b next_step
_stack_empty_dup:
    mov x0, #0
    str x0, [x23], #8
    b next_step

_op_pop:
    cmp x23, x25
    b.eq next_step
    sub x23, x23, #8
    b next_step

_op_swap:
    sub x0, x23, x25
    cmp x0, #16
    b.lt next_step          
    
    ldr x0, [x23, #-8]      // Top
    ldr x1, [x23, #-16]     // Second
    str x1, [x23, #-8]
    str x0, [x23, #-16]
    b next_step

// Arithmetic
_pop_two:
    mov x0, #0
    mov x1, #0
    cmp x23, x25
    b.eq 1f                 
    sub x23, x23, #8
    ldr x0, [x23]           
    
    cmp x23, x25
    b.eq 1f                 
    sub x23, x23, #8
    ldr x1, [x23]           
1:  ret

_op_add:
    bl _pop_two
    add x0, x1, x0
    str x0, [x23], #8
    b next_step

_op_sub:
    bl _pop_two
    sub x0, x1, x0
    str x0, [x23], #8
    b next_step

_op_mul:
    bl _pop_two
    mul x0, x1, x0
    str x0, [x23], #8
    b next_step

_op_div:
    bl _pop_two
    cbz x0, _div_zero
    sdiv x0, x1, x0
    str x0, [x23], #8
    b next_step
_div_zero:
    mov x0, #0
    str x0, [x23], #8
    b next_step

_op_mod:
    bl _pop_two
    cbz x0, _mod_zero
    sdiv x2, x1, x0
    mul x2, x2, x0
    sub x0, x1, x2
    str x0, [x23], #8
    b next_step
_mod_zero:
    mov x0, #0
    str x0, [x23], #8
    b next_step

_op_not:
    // Pop x, push 1 if x==0 else 0
    cmp x23, x25
    b.eq _not_empty
    sub x23, x23, #8
    ldr x0, [x23]
    cmp x0, #0
    b.eq 1f
    mov x0, #0
    b 2f
1:  mov x0, #1
2:  str x0, [x23], #8
    b next_step
_not_empty:
    mov x0, #1
    str x0, [x23], #8
    b next_step

_op_gt:
    bl _pop_two
    cmp x1, x0
    b.gt 1f
    mov x0, #0
    b 2f
1:  mov x0, #1
2:  str x0, [x23], #8
    b next_step


_op_print_char:
    cmp x23, x25
    b.eq next_step
    sub x23, x23, #8
    ldr x0, [x23]
    
    sub sp, sp, #16
    strb w0, [sp]
    mov x0, #1              
    mov x1, sp
    mov x2, #1
    mov x16, #SC_WRITE
    svc #0
    add sp, sp, #16
    b next_step

_op_print_int:
    cmp x23, x25
    b.eq next_step
    sub x23, x23, #8
    ldr x0, [x23]
    bl _print_integer
    
    // Space
    mov x0, #32             
    sub sp, sp, #16
    strb w0, [sp]
    mov x0, #1
    mov x1, sp
    mov x2, #1
    mov x16, #SC_WRITE
    svc #0
    add sp, sp, #16
    
    b next_step

// Print integer in x0
_print_integer:
    stp x29, x30, [sp, -16]!
    mov x29, sp
    
    cbnz x0, 1f
    sub sp, sp, #16
    mov w1, #'0'
    strb w1, [sp]
    mov x0, #1
    mov x1, sp
    mov x2, #1
    mov x16, #SC_WRITE
    svc #0
    add sp, sp, #16
    ldp x29, x30, [sp], 16
    ret
1:
    cmp x0, #0
    b.ge 2f
    // Negative
    neg x0, x0
    mov x9, x0 
    
    sub sp, sp, #16
    mov w1, #'-'
    strb w1, [sp]
    mov x0, #1
    mov x1, sp
    mov x2, #1
    mov x16, #SC_WRITE
    svc #0
    add sp, sp, #16
    
    mov x0, x9 
2:
    sub sp, sp, #32
    mov x1, sp
    add x1, x1, #31 
    
    mov x3, #10
convert_loop:
    udiv x4, x0, x3     
    msub x5, x4, x3, x0 
    add w5, w5, #'0'
    strb w5, [x1, #-1]!
    mov x0, x4
    cbnz x0, convert_loop

    mov x2, sp
    add x2, x2, #31
    sub x2, x2, x1
    
    mov x0, #1
    mov x16, #SC_WRITE
    svc #0
    
    add sp, sp, #32
    ldp x29, x30, [sp], 16
    ret


next_step:
    add x19, x19, x21
    cmp x19, #80
    b.ge 1f
    cmp x19, #0
    b.lt 2f
    b 3f
1:  sub x19, x19, #80
    b 3f
2:  add x19, x19, #80
3:
    add x20, x20, x22
    cmp x20, #25
    b.ge 1f
    cmp x20, #0
    b.lt 2f
    b 3f
1:  sub x20, x20, #25
    b 3f
2:  add x20, x20, #25
3:
    b interpret_loop


_memset_custom:
    cbz x2, _memset_end
_memset_loop:
    strb w1, [x0], #1
    sub x2, x2, #1
    cbnz x2, _memset_loop
_memset_end:
    ret

_exit_ok:
    mov x0, #0
    b _exit_syscall

_exit_error:
    mov x0, #1
    b _exit_syscall

_exit_syscall:
    ldp x29, x30, [sp], 16
    mov x16, #SC_EXIT
    svc #0
