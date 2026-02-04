# Esoteric Assembly Experiments

This repository contains experiments combining **ARM64 assembly language** with **esoteric programming languages**. Each folder demonstrates implementations of classic esoteric languages interpreted as native assembly.

## Overview

### [befunge-assembly](./befunge-assembly/)
Befunge interpreter/compiler written in ARM64 assembly. Befunge is a 2D esoteric language where the instruction pointer moves through a 2D grid of commands.

### [brainfuck-assembly](./brainfuck-assembly/)
Brainfuck interpreter implemented in ARM64 assembly. Brainfuck is a minimalist Turing-complete language with just 8 commands that manipulate a memory tape.

### [ook-assembly](./ook-assembly/)
Ook interpreter in ARM64 assembly. Ook is an esoteric language based on the "language" of orangutans, using only three words: "Ook.", "Ook?", and "Ook!".

## Building and Running

Each folder contains:
- A `Makefile` for compilation
- `.s` assembly source files
- Sample programs in the respective esoteric language (`.bf`, `.ook`, etc.)

Navigate to each folder and run `make` to build the executables.

## Architecture

All implementations are written in ARM64 assembly for macOS, showcasing low-level implementation details of interpreter/compiler design.
