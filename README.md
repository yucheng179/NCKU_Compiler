# NCKU Compiler Construction Homework

Coursework for NCKU Compiler Construction (114-2). The projects implement a lexer and a compiler for a subset of the [Wenyan language](https://github.com/wenyan-lang/wenyan).

## Projects

### HW1 — Lexical Analyzer

Implemented a Flex-based lexer in C with support for:

- UTF-8-aware line and column tracking
- Chinese number literals
- identifiers and string literals
- type, control-flow, function, arithmetic, and logical tokens
- automated comparison tests

Source: [`HW1/src/compiler.l`](HW1/src/compiler.l)

### HW2 — Wenyan-to-LLVM Compiler

Extended the course skeleton into a compiler using C, Flex, Bison/Yacc, and LLVM IR. The implementation covers:

- lexical and syntax analysis
- variables, values, types, arrays, and expressions
- symbol tables and nested scopes
- `if`/`else`, `for`, `while`, and `break`
- function definition, calls, and returns
- LLVM IR generation and runtime execution tests

The saved test report records 53.89/54 for verbose-output checks and 41/41 for runtime-output checks (94.89/95 total). This is a test-suite result, not the final course grade.

Source: [`HW2/src`](HW2/src)  
Test report: [`HW2/test_result.log`](HW2/test_result.log)

## Build and test

Each homework directory retains its original build instructions and test scripts:

- [`HW1/README.md`](HW1/README.md)
- [`HW2/README.md`](HW2/README.md)

The projects use CMake and require the tools documented in those files. HW2 additionally requires Bison and LLVM.

## Attribution and scope

These are course assignments built on skeleton code provided by the course staff. The repository includes my completed implementation together with the supporting skeleton and tests needed to build and evaluate it.

Third-party components retain their original notices where supplied, including `utf8.c`. The Wenyan number-conversion implementation cites its upstream reference in the source. No repository-wide license is granted; individual third-party files remain under their respective licenses.

