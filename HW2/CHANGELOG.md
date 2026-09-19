# 更新紀錄

---

## 2026-06-24 — `test/test.sh` 的 Part 1 比對方式改成 column 容忍 + 比例計分

`test/test.sh` 裡 Part 1（verbose）的比對邏輯改動：
- 比對前先用 `strip_column()` 把每行的 column 數字正規化掉，column 不一致不算錯，只比 line 跟內容
- 計分從「整份測資逐字一致才給分、不一致就 0 分」改成「依比對正確的行數比例給分」（`verbose_match_ratio()`），分數可能出現小數
- `PART1_SCORE` / `TOTAL` 因此從整數改成用 `awk` 累加的浮點數，顯示到小數第二位


---

## 2026-06-24 — 修正 verbose log 的位置（column/line）顯示 bug

對應 commit（更新前的最後一版）：`a6103a2`

### 這次在修什麼

`-v` 詳述模式印出來的 `檔名:行:列` 位置，有兩類 bug：

1. **欄位起算點跟 Bison 慣例不一致**：程式一開始（`SCOPE_MAIN`）會顯示 `1:2` 而不是 `1:1`。
2. **部分位置會「跳到下一句」**：像 `return`、`break`、運算式（`乘`/`加`/`減`...）這類規則，因為 LALR(1) parser 需要多看一個 token 才能確定句子結束，verbose log 印出來的位置會變成「下一句」的起點，不是這個語句自己的位置。

`test/*/*.verbose` 答案檔是逐行逐字比對, column 數字變了就會整批不一致, 所以這次更新已經把 repo 裡所有 `test/*/*.verbose` 答案檔重新產生過, 跟新版輸出對齊, 已經包含在這次更新裡, 不用自己重灌。
`.expected`（實際執行結果)沒有受影響, IR 生成邏輯沒變。

### 你需不需要改自己的程式碼？

**大部分人完全不用動。** 只有 `code_return`/`code_returnValue`/`code_break` 這兩組函式的簽名多了一個參數，**只有你已經寫了呼叫它們的程式碼**才需要補一個參數；運算式那組（`code_expression*`）簽名沒變，只是要檢查 `aLoc` 傳的對不對（見下表)。

| 檔案 | 函式 | 改了什麼 | 你要做什麼 |
|---|---|---|---|
| `compiler.l` | （`%{...%}` 段裡的 `yycolumnUtf8`、`updateNewline()`) | column 計數起點從 `0` 改成 `1`，跟 Bison 預設的 `yylloc` 初值（`{1,1,1,1}`）對齊 | **不用動**，純內部修正 |
| `compiler_util.h` / `compiler.h` / `lib/code_gen.h` | `yyerrorf`/`yyerrorlf`/`yyerrortf`/`yyerror`/`compilerLog` 系列巨集 | 印 column 時拿掉 `+1`（因為起點已經改 1-based，不用再額外加一); `compilerLog` 內部改成轉呼叫新巨集 `compilerLogAt(loc, ...)` | **不用動**，純內部修正 |
| `compiler.y` | （無新規則，只改 TODO 註解文字) | `OperationStmt`、`Expressions` 兩段 TODO 註解補上「呼叫 `code_return`/`code_returnValue`/`code_break` 要多傳位置參數」「`aLoc` 該傳哪個 `@N`」的說明；**規則本身還是空的，沒有幫你寫**，因為這幾條規則的內容是你要填的 TODO | 等你動手寫 `compiler.y` 時對照表格下面那幾列補位置參數即可 |
| `control/function.c`、`main.c`、`object.c` | `func_call`、`code_arrayPush`、`object_getIndex` | 內部 log 改用正確位置 | **不用動**，這些函式本來就是給好的，沒有 TODO |
| `control/function.h` / `function.c` | `code_return`、`code_returnValue` | 多一個 `const YYLTYPE* tokenLoc` 參數 | 如果你的 `compiler.y` 已經寫了 `ReturnStmt`，呼叫處補上 `&@1`（`RETURN ExpressionChainStmt` 那條)或 `&@2`（`ExpressionChainStmt RETURN` 那條) |
| `control/while.h` / `while.c` | `code_break` | 多一個 `const YYLTYPE* tokenLoc` 參數 | 如果你已經寫了 `code_break` 的函式定義/呼叫，兩邊都要補 `tokenLoc` 參數；`compiler.y` 呼叫處補 `&@1` |
| `expression.h` / `expression.c` | `code_expression`、`code_expressionMod`、`code_expressionChain`、`code_expressionChainMod` | 簽名沒變，只是內部改用 `compilerLogAt(aLoc, ...)` | 如果你已經寫了運算式相關規則，**不用加參數**；但要檢查 `aLoc` 有沒有傳對——`aLoc` 代表「整個運算式的起點」不是「左運算元的位置」，多數規則第一個符號就是起點可以直接傳 `&@1`，但「運算子在前」的規則（例如 乘/加/減 開頭、`THOSE` 開頭）記得傳開頭那個 token 的 `&@1`，不要傳成運算元的位置 |

`code_getLength` 的 TODO 註解多了一句提示（提醒你 log 要用 `compilerLogAt(loc, ...)` 而不是 `compilerLog(...)`)，這只是文字提示，沒有簽名變動，不會讓你舊的程式碼編譯失敗。

### 怎麼更新（git pull / merge）

如果你是從這個 repo fork 出去寫作業的，在你自己的 repo 裡：

```bash
# 如果還沒加過上游 remote
git remote add upstream git@github.com:WavJaby/NCKU_Compiler_HW2.git

git fetch upstream
git merge upstream/master
```

大部分人會是**乾淨合併**，因為這次改動的檔案你大多沒碰過（`compiler.l` 的 prologue、`compiler_util.h`、`code_gen.h` 這些都是 infra）。

如果你已經寫了 `ReturnStmt`/`code_break`/運算式相關規則，`merge` 可能在 `compiler.y`、`function.h`、`while.h`、`expression.h` 出現衝突（因為你在同一行附近加了自己的程式碼）。解法：

1. 衝突的地方保留你自己寫的邏輯
2. 對照上面表格，把簽名／呼叫處補上對應的位置參數（`&@1`/`&@2`)
3. 重新 build 跑一次 `test/test.sh` 確認沒有壞掉

如果不想用 git merge，也可以手動對照上表，自己在程式碼裡補參數即可，改動量很小（每個呼叫處只多一個參數）。

> **附註**：如果 `git fetch && git merge` 直接報 `unrelated histories`——因為剛發布那幾天還在改文件，有 force push 過，改用 cherry-pick 即可：
> ```bash
> git remote add upstream git@github.com:WavJaby/NCKU_Compiler_HW2.git   # 已加過就跳過
> git fetch upstream
> git cherry-pick a6103a2..upstream/master
> # 有衝突就解完後: git add -A && git cherry-pick --continue
> ```
