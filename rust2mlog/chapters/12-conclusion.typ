#import "../lib.typ": *
= 总结与展望
#labnote[ 终点站 ]

== 回顾旅程

我们从一个问题出发——在 Mindustry 中手写 MLOG 太痛苦——到最终拥有一个嵌入在 Rust 中的 MLOG 编译器。

| 阶段 | 关键产出 |
|:---|:---|
| 理解 MLOG | 完整的指令集参考，硬限制清单 |
| DSL 设计 | Rust 语法 → MLOG 指令的映射表 |
| 架构选型 | 函数式宏 + facade crate + 三阶段编译 |
| 解析器 | 递归下降解析，300 行 hand-rolled parser |
| 中间表示 | 三地址码 IR，表达式展平，临时变量分配 |
| 代码生成 | IR → MLOG 文本的直接映射 |
| 控制流 | if/while/loop/break 的 jump 模式全解 |
| 变量系统 | 作用域管理 + 唯一名称 + 不可变性检查 |
| 错误诊断 | Span 精确定位 + 多错误收集 |
| 完整编译器 | 仓库监控 + 单位巡逻两个实战案例 |

== 概念速查表

| 概念 | 在编译器中的位置 |
|:---|:---|
| TokenStream | 宏入口接收的输入 token 流 |
| AST | 解析后的嵌套语法树 |
| 三地址码 IR | MLOG op 指令的中间表示 |
| 临时变量 | 表达式分解产生的 `__tN` |
| 标签 | 控制流目标的 `__while_N` `__break_N` |
| 唯一名称 | 用户变量的作用域安全映射 |
| Span | 错误定位的源头 |
| Diagnostic | 多错误收集器 |
| quote! | 返回 MLOG 字符串字面量 |

== 与其他方案对比

| 方案 | 学习成本 | 集成 Rust | 类型安全 | 编译器控制 |
|:---|:---|:---|:---|:---|
| 手写 MLOG | 低 | N/A | 无 | 完全 |
| Mindcode | 中 | 否 | 独立系统 | 间接 |
| 本教程 (rust2mlog) | 低 (写 Rust) | 是 | 可扩展 | 完全 |

== 进阶扩展

=== 优化器

在 IR 层面做优化：

- *死代码消除*：删除未使用的 `set` 和 `op`
- *公共子表达式消除*：`a + b` 多次出现只算一次
- *常量折叠*：编译时计算的常量直接替换
- *临时变量压缩*：复用过期的临时变量

=== 更多语言特性

- `for i in 0..10 { ... }` — 展开为 while 循环
- 数组访问 `arr[index]` — 映射到 `read arr index`
- 函数模拟 — 用标签 + jump 做内联"子程序"

=== 编译错误的持续改进

- `cargo expand` 集成 — 查看展开后的 MLOG
- trybuild 集成 — 测试错误信息的质量
- LSP 支持 — VS Code 中跳转到错误位置

== 推荐阅读

- *Mindcode 源码* — 另一个 MLOG 编译器的设计
- *The MLOG ISA* — MLOG 指令集的底层编码
- *Crafting Interpreters* (Nystrom) — 解析器和编译器的经典入门
- *Engineering a Compiler* (Cooper & Torczon) — 中间表示的深入讲解
- *proc-macro-guide* (本系列) — Rust 过程宏的全面教程

== 最后的思考

用 Rust 过程宏做编译器前端是一种被低估的模式。

传统编译器要么是独立工具（gcc、clang），要么是解释器（Python eval）。过程宏提供了一种不同的路径——*编译时的程序变换*，可以直接嵌入在宿主语言的构建流程中。

本教程展示了这个模式的最简实例：一个约 1000 行的编译器，把类 Rust 的 DSL 编译成 Mindustry 汇编。

这不仅仅是关于 MLOG。任何需要"生成另一种语言的代码"的场景——SQL、着色器、配置文件、协议描述——都可以用同样的架构。

在 Rust 的世界里，只要你能 parse 它，你就能生成它。
#pagebreak()
