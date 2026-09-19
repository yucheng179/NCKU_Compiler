# 成大編譯系統作業｜NCKU Compiler Construction Homework

## 中文說明

本 repository 收錄國立成功大學 114-2「編譯系統（Compiler Construction）」課程的兩次實作作業。專案以[文言文程式語言（Wenyan）](https://github.com/wenyan-lang/wenyan)的部分語法為目標，依序完成詞法分析器，以及可產生 LLVM IR 的編譯器。

### 專案內容

#### HW1 — 詞法分析器（Lexical Analyzer）

使用 C 與 Flex 實作詞法分析器，主要完成內容包括：

- 支援 UTF-8 的行號與欄位位置追蹤
- 中文數字常值解析
- 識別字與字串常值辨識
- 資料型態、流程控制、函式、算術及邏輯運算相關 token
- 自動化輸出比對測試

主要實作：[`HW1/src/compiler.l`](HW1/src/compiler.l)

#### HW2 — 文言文至 LLVM IR 編譯器

在課程骨架上使用 C、Flex、Bison/Yacc 與 LLVM IR 完成編譯器，涵蓋：

- 詞法分析與語法分析
- 變數、常值、型別、陣列與運算式
- Symbol table 與巢狀 scope 管理
- `if`／`else`、`for`、`while` 與 `break`
- 函式定義、呼叫、參數與回傳
- LLVM IR 產生與 runtime 執行測試

保留的測試紀錄顯示：verbose output 測試為 53.89/54，runtime output 測試為 41/41，合計 94.89/95。此數字是測試腳本結果，不是課程總成績。

主要實作：[`HW2/src`](HW2/src)

測試紀錄：[`HW2/test_result.log`](HW2/test_result.log)

### 建置與測試

兩份作業保留原有的建置說明與測試腳本：

- [`HW1/README.md`](HW1/README.md)
- [`HW2/README.md`](HW2/README.md)

專案使用 CMake，並需要各 README 中列出的編譯工具。HW2 另外需要 Bison 與 LLVM。

### 來源、個人實作範圍與授權

本專案是建立在課程教師提供的骨架程式上。本 repository 保留建置與測試所需的課程骨架，並收錄我在作業中完成的 lexer、parser、scope／symbol 管理、控制流程及 LLVM IR code generation 等實作。

第三方元件沿用其原有的授權及來源說明，例如 `utf8.c`。中文數字轉換程式亦已在原始碼中標示參考來源。本 repository 不提供統一的全域授權；各第三方檔案仍適用其個別授權條款。

---

## English

This repository contains two assignments from NCKU Compiler Construction (114-2). The projects target a subset of the [Wenyan language](https://github.com/wenyan-lang/wenyan), progressing from a lexical analyzer to a compiler that generates LLVM IR.

### Projects

#### HW1 — Lexical Analyzer

Implemented a Flex-based lexer in C with support for:

- UTF-8-aware line and column tracking
- Chinese number literals
- identifiers and string literals
- type, control-flow, function, arithmetic, and logical tokens
- automated output-comparison tests

Main implementation: [`HW1/src/compiler.l`](HW1/src/compiler.l)

#### HW2 — Wenyan-to-LLVM Compiler

Extended the course skeleton into a compiler using C, Flex, Bison/Yacc, and LLVM IR. The implementation covers:

- lexical and syntax analysis
- variables, values, types, arrays, and expressions
- symbol tables and nested scopes
- `if`/`else`, `for`, `while`, and `break`
- function definitions, calls, parameters, and returns
- LLVM IR generation and runtime execution tests

The saved test report records 53.89/54 for verbose-output checks and 41/41 for runtime-output checks (94.89/95 total). This is a test-suite result, not the final course grade.

Main implementation: [`HW2/src`](HW2/src)

Test report: [`HW2/test_result.log`](HW2/test_result.log)

### Build and test

Each homework directory retains its original build instructions and test scripts:

- [`HW1/README.md`](HW1/README.md)
- [`HW2/README.md`](HW2/README.md)

The projects use CMake and require the tools documented in those files. HW2 additionally requires Bison and LLVM.

### Attribution, implementation scope, and licensing

These assignments were built on skeleton code provided by the course staff. This repository retains the supporting skeleton and tests required to build and evaluate the projects, together with my implementations of the lexer, parser, scope and symbol management, control flow, and LLVM IR code generation.

Third-party components retain their original notices where supplied, including `utf8.c`. The Wenyan number-conversion implementation cites its upstream reference in the source. No repository-wide license is granted; individual third-party files remain under their respective licenses.
