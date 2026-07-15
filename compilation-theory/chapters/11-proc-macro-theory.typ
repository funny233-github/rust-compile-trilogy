#import "../lib.typ": *
= 到过程宏 — 编译时翻译的通用框架
#labnote[ 第十一站：proc macro 作为编译器前端 ]

前两本教程（proc-macro-guide 和 rust2mlog）都在做同一件事：用过程宏做代码生成。这一章从编译理论的视角重新审视——为什么过程宏是编译器前端的理想载体。

== 过程宏本质上是编译器前端

```rust
// proc-macro-guide 做的事
#[proc_macro_derive(Builder)]
pub fn derive_builder(input: TokenStream) -> TokenStream {
    // input: 结构体定义 (源语言)
    // output: Builder 实现 (目标语言)
    // 两者都是 Rust 代码
}

// rust2mlog 做的事
#[proc_macro]
pub fn mlog(input: TokenStream) -> TokenStream {
    // input: MLOG DSL (源语言)
    // output: MLOG 文本 (目标语言)
    // 源是类 Rust DSL，目标是 MLOG
}

// 本质上
// TokenStream → 解析 → IR → 代码生成 → TokenStream
//                     ↑ 编译器前端
```

#concept[
  过程宏提供了一个*受管理的编译阶段*：

  - 输入是 TokenStream（编译器已经做了词法分析）
  - 运行在编译器进程中（可以访问文件系统、环境变量等）
  - 输出自动集成到构建流程中（不需要额外工具）
]

== 和传统编译器的对比

| 方面 | 传统编译器 (gcc/llc) | 过程宏编译器 |
|:---|:---|:---|
| 运行时机 | 构建时（独立进程） | 构建时（编译器进程内） |
| 输入 | 文件路径 | TokenStream |
| 输出 | .o / .s 文件 | TokenStream |
| 集成 | 需要构建系统配置 | 自动（cargo） |
| 错误报告 | stderr + 退出码 | `syn::Error` → 编译错误 |
| 使用方式 | 命令行 | 宏调用 |

过程宏*不是*独立编译器——它是嵌入在 Rust 编译器中的翻译函数。这让它和宿主语言有更紧密的集成，但也限制了它的独立性。

== 适合放过程宏的场景

| 适合 | 不适合 |
|:---|:---|
| 代码生成（Builder、Serialize） | 大型独立编译（>10K 行） |
| 内嵌 DSL（SQL、HTML、MLOG） | 需要独立二进制工具链 |
| 编译时验证（正则、格式串） | 非常复杂的优化 pass |
| 协议/配置编译 | 需要跨语言共享的 |

#intuition[
  判断标准：*生成的代码是否需要和宿主 Rust 代码紧密集成？*

  如果需要（Builder 模式、serde、sqlx）→ proc macro
  如果不需要（独立程序、另一个语言）→ 独立编译器

  MLOG 编译器确实可以做成独立工具——但做成 proc macro 的好处是：
  它和 Rust 项目中的其他代码共享同一个构建流程。

  你用 `cargo build`，MLOG 自动生成。
]

== 任何源语言 → 任何目标语言

过程宏的模式是通用的翻译框架：

```
源 TokenStream → [解析] → [IR] → [代码生成] → 目标 TokenStream
```

源和目标可以是：
- Rust → Rust（serde、thiserror）
- DSL → Rust（html!、sqlx::query!）
- DSL → MLOG（rust2mlog）
- DSL → SQL（ORM 宏）
- DSL → OpenGL Shader（shader! 宏）
- 配置格式 → Rust 结构体

只要你能把源语言解析为 AST，能把目标语言表示为 TokenStream，过程宏就能做这个翻译。

== 过程宏的局限性

#warning[
  过程宏不适合的场景：

  1. *极大的编译任务* — 过程宏在编译期运行，慢的宏拖慢所有 crate 的编译
  2. *需要持久化状态* — 宏不能跨 crate 共享数据
  3. *需要精确的错误恢复* — `syn::Error` 只能报告，不能修复
  4. *需要多 pass 分析* — 过程宏是单 pass 的（输入 → 输出）

  对于 MLOG 编译器来说，这些限制都不是问题——
  1000 行的编译器在宏中运行毫秒级，不持久化，不跨 crate。
]

== 小结

- 过程宏本质上是嵌入在 Rust 编译器中的编译器前端
- TokenStream → 解析 → IR → 代码生成 → TokenStream
- 适合代码生成、嵌入式 DSL、编译时验证
- 不适合大型独立编译、持久化状态、多 pass
- 任何「源语言 → 目标语言」的翻译都可以用 proc macro 实现
- 编译理论的通用性 = 过程宏应用场景的通用性
#pagebreak()
