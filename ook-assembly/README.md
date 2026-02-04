# Ook Assembly

An **Ook** interpreter implemented entirely in ARM64 assembly.

## What is Ook?

Ook is an esoteric programming language based on the "language" of orangutans. It uses only three distinct tokens:
- `Ook.` - Represents the word "ook"
- `Ook?` - Represents a question
- `Ook!` - Represents an exclamation

These tokens are combined to create a Turing-complete language. Despite its minimal syntax, Ook can express any computable function.

## Files

- `ook.s` - ARM64 assembly implementation of the interpreter
- `ook` - Compiled executable
- `helloworld.ook` - Hello World program
- `countdown.ook` - Countdown example
- `countdown2.ook` - Alternative countdown implementation
- `gen_ook.py` - Python script to generate Ook code
- `Makefile` - Build configuration

## Building

```bash
make
```

## Running

```bash
./ook <program.ook>
```

## Examples

- `helloworld.ook` - Prints "Hello, World!"
- `countdown.ook` - Counts down from a number
- `countdown2.ook` - Alternative countdown approach

## Generating Ook Code

Use `gen_ook.py` to generate Ook programs from higher-level descriptions:

```bash
python gen_ook.py
```
