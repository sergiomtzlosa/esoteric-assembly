# Befunge Assembly

An interpreter/compiler for **Befunge**, a 2D esoteric programming language, implemented entirely in ARM64 assembly.

## What is Befunge?

Befunge is a 2D stack-based esoteric language where:
- The instruction pointer starts at the top-left and moves right
- Commands operate on a stack and modify the 2D playfield
- Direction can be changed (`^`, `v`, `<`, `>`)
- It's Turing-complete

## Files

- `befunge.s` - ARM64 assembly implementation
- `befunge` - Compiled executable
- `hello.bf` - Hello World example
- `countdown.bf` - Countdown example
- `math.bf` - Math operations example
- `Makefile` - Build configuration

## Building

```bash
make
```

## Running

```bash
./befunge <program.bf>
```

## Examples

- `hello.bf` - Prints "Hello, World!"
- `countdown.bf` - Counts down from a number
- `math.bf` - Basic arithmetic demonstrations
