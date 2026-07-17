# AGENTS.md — 代码生成论 项目规则

## 练习目录

`compilation-theory/exercises/` 是给学生做的编程练习，**不是给 agent 做的**。

### agent 操作练习时的铁律

1. **src/ 下所有文件必须是 `todo!()` stub。** 如果发现任何文件包含完整实现而非 `todo!("...")`，立即恢复为 stub。答案只能存在于 `answers/` 目录。

2. **文档和练习文件必须一一对应。** 每次修改练习后，检查 `.typ` 文档中的 `== 练习` 节：
   - `*题目位置*` 指向的路径是否存在
   - `*验证*` 中的 `cargo test chXX` 名称是否和模块名匹配
   - `*答案*` 指向的 `answers/` 路径是否存在
   - 映射表：

   | .typ 文件 | 文档章节 | 练习模块 | 测试命令 |
   |---|---|---|---|
   | `02-c-expr.typ` | 第 3 章 | `ch03_expr` | `cargo test ch03` |
   | `03-c-control.typ` | 第 4 章 | `ch04_control` | `cargo test ch04` |
   | `04-c-func.typ` | 第 5 章 | `ch05_func` | `cargo test ch05` |
   | `05-regalloc.typ` | 第 6 章 | `ch06_regalloc` | `cargo test ch06` |
   | `08-rust-specific.typ` | 第 9 章 | `ch09_enum` | `cargo test ch09` |
   | `09-optimization.typ` | 第 10 章 | `ch10_optimize` | `cargo test ch10` |
   | `10-back-to-mlog.typ` | 第 11 章 | `ch11_mlog` | `cargo test ch11` |

3. **每次操作练习后必须验证：**
   ```bash
   cd compilation-theory/exercises && cargo test 2>&1 | grep 'test result'
   ```
   输出必须是 `0 passed; N failed`（全部 stub，无一泄露答案）。

4. **answers/ 目录只读。** 参考答案可以查看，但绝不能复制到 `src/`。除非用户明确要求参考实现来对照学习。

5. **Typst 语法检查。** 修改完 `.typ` 文件后必须编译验证：
   ```bash
   cd compilation-theory && typst compile main.typ
   ```

### 为什么要这样做

这些练习的目的是让读者亲手实现编译器核心算法。答案泄露会毁掉学习效果。agent 的职责是维护练习框架的正确性，而不是替用户做题。
