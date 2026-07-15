#import "../lib.typ": *
= 翻译链的普遍性
#labnote[ 终点站 ]

== 三条链，一个骨架

把三本教程放在一起看：

#table(
  columns: (auto, auto, auto, auto),
  fill: (rgb("#e5e7eb"),),
  inset: 6pt,
  stroke: 0.5pt,
  [*层*], [*proc-macro-guide*], [*rust2mlog*], [*compilation-theory*],
  [1], [TokenStream], [MLOG DSL], [C / Rust],
  [2], [syn 解析 → DeriveInput], [手写解析 → AST], [解析 → AST],
  [3], [quote! 生成代码], [三地址码 IR], [三地址码 / LLVM IR],
  [4], [impl Trait 块], [MLOG 文本], [x86 / ARM 汇编],
  [5], [编译器拼接], [字符串字面量], [机器码],
)

#intuition[
  三本教程从三个角度覆盖了同一个问题：*如何让机器写代码*。

  - proc-macro-guide：工具层——过程宏的 API 和模式
  - rust2mlog：实践层——用 proc macro 实现编译器
  - compilation-theory（本书）：理论层——编译器为什么这样工作

  三者构成一个完整的知识闭环。
]

== 核心概念回顾

| 概念 | 首次出现 | 本质 |
|:---|:---|:---|
| TokenStream | proc-macro-guide Ch2 | 编译器的"原材料" |
| AST | rust2mlog Ch4 | 源代码的树形表示 |
| 三地址码 | rust2mlog Ch5 / 本书 Ch6 | 编译器的"通用语言" |
| 寄存器分配 | 本书 Ch5 | 有限资源的优雅分配 |
| 栈帧 / 调用约定 | 本书 Ch4 | 函数调用的底层机制 |
| 控制流图 | 本书 Ch3 | 分析和优化的基础 |
| SSA | 本书 Ch6 | 更严格的三地址码 |
| 优化 pass | 本书 Ch9 | 不改语义，改善性能 |
| proc macro 前端 | 本书 Ch11 | 编译时翻译的框架 |

== 编译器设计的核心原则

1. *分阶段*：解析 → IR → 优化 → 代码生成。每层解决一个问题。
2. *IR 是支点*：前端和后端的唯一接口。IR 设计好，前后端独立演化。
3. *三地址码是黄金表示*：足够表达、足够简单、适合优化。
4. *寄存器分配是最难的优化*：NP 完全，用启发式近似。
5. *优化必须保守*：不能改变可观察行为。
6. *目标架构的约束决定编译器复杂度*：MLOG 无寄存器压力 → 编译器简单；x86 寄存器有限 → 编译器复杂。

== 推荐阅读

- *Engineering a Compiler* (Cooper & Torczon) — 编译器全栈教材
- *LLVM Essentials* — 理解 LLVM IR 和优化 pass
- *Crafting Interpreters* (Nystrom) — 解析器和编译器入门
- *Mindcode 源码* — 另一个 MLOG 编译器
- *proc-macro-guide*（本系列）— 过程宏实践
- *rust2mlog*（本系列）— MLOG 编译器实战

== 最后的话

三个 PDF，一个主题：*代码生成*。

从 Rust 过程宏的 API，到 MLOG 编译器的实现，到编译理论的底层原理——三本教程覆盖了从「怎么用」到「怎么做」到「为什么」的完整链条。

当你理解了 C → x86 的翻译，你就理解了 Rust → LLVM 的翻译。当你理解了 MLOG → 三地址码的映射，你就理解了任何编译目标的选择。

编译器是为人类服务的翻译器。过程宏是这个翻译器在 Rust 生态中的具现。

在 Rust 的世界里，只要你能 parse 它，你就能生成它。

而且你现在知道了*为什么*。
#pagebreak()
