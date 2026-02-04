# Brainfuck Assembly

A **Brainfuck** interpreter implemented entirely in ARM64 assembly.

## What is Brainfuck?

Brainfuck is a minimalist Turing-complete esoteric language with only 8 commands:
- `>` - Increment the data pointer
- `<` - Decrement the data pointer
- `+` - Increment the byte at the data pointer
- `-` - Decrement the byte at the data pointer
- `.` - Output the byte at the data pointer
- `,` - Input a byte to the data pointer
- `[` - Jump forward to the matching `]` if the byte is 0
- `]` - Jump backward to the matching `[` if the byte is non-zero

## Files

- `interpreter.s` - ARM64 assembly implementation of the interpreter
- `brainfuck` - Compiled executable
- `hello.bf` - Hello World program
- `countdown.bf` - Countdown example
- `fibonacci.bf` - Fibonacci sequence generator
- `test.bf` - Simple test program
- `Makefile` - Build configuration

## Building

```bash
make
```

## Running

```bash
./brainfuck <program.bf>
```

## Examples

- `hello.bf` - Classic Hello World
- `countdown.bf` - Counts down from 10
- `fibonacci.bf` - Generates Fibonacci numbers
- `test.bf` - Basic functionality test
