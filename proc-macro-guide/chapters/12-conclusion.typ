#import "../lib.typ": *
= 回顾与展望
#labnote[ 终点站 ]

== 回顾旅程

从重复代码的困扰，到一个完整的 `#[derive(Builder)]` 宏——我们走过了很长的路。

| 概念 | 关键内容 |
|:---|:---|
| TokenStream | 编译器表示代码的内部结构，四种 TokenTree |
| 三种过程宏 | 函数式宏、派生宏、属性宏 |
| syn 解析 | 把 TokenStream 解析成 DeriveInput 等数据结构 |
| quote 生成 | 安全地生成 TokenStream |
| Derive Macro | 为类型自动实现 trait |
| Attribute Macro | 注解函数/结构体，包裹或转换代码 |
| Function-like Macro | 创造自定义 DSL |
| syn::Error | 给用户友好的编译错误 |
| trybuild | 测试编译失败场景 |
| Builder 实战 | 完整的 derive 宏实现 |
| 卫生性与 Span | 控制标识符的作用域规则 |

== 概念速查表

| 类型 | 标注 | 用途 |
|:---|:---|:---|
| `#[proc_macro]` | 函数式宏 | 自定义 DSL 语法 `my_macro!(...)` |
| `#[proc_macro_derive]` | 派生宏 | 为类型自动实现 trait `#[derive(Trait)]` |
| `#[proc_macro_attribute]` | 属性宏 | 注解函数/结构体 `#[attr]` |
| `proc_macro::TokenStream` | 内置类型 | 编译器传入传出的 token 序列 |
| `proc_macro2::TokenStream` | 跨平台封装 | 可在普通代码和测试中使用 |
| `syn::DeriveInput` | 解析结构 | derive 宏的输入数据结构 |
| `syn::ItemFn` | 解析结构 | 函数定义的语法树 |
| `quote!` | 代码生成 | 安全地生成 TokenStream |
| `syn::Error` | 错误处理 | 生成友好的编译错误 |
| `parse_quote!` | 测试辅助 | 在测试中快速构造 syn 节点 |
| `trybuild` | 测试框架 | 测试编译失败场景 |

== 推荐阅读

进阶资料：

- *The Little Book of Rust Macros* — macro_rules! 的全面教程
- *syn 文档* — 所有解析类型的详细说明
- *quote 文档* — 插值模式的高级用法
- *serde 源码* — 最经典的 derive 宏实现
- *tokio 的 `#[tokio::main]`* — 属性宏的优雅应用
- *sqlx 的 query!* — 函数式宏 + 编译时 SQL 解析
- *Rust Reference: Procedural Macros* — 官方规范的权威描述

== 最后的话

过程宏让 Rust 具备了这个语言最强大的元编程能力。但强大意味着责任——好的宏不是"能工作就行"，而是"让使用它的人感觉不到宏的存在"。

给宏作者的几条建议：

1. *用户友好的错误信息* — 不要 panic，不要 unwrap
2. *正确处理泛型* — 你的宏必须工作在泛型代码中
3. *测试* — 单元测试 + 集成测试 + 编译失败测试
4. *文档* — 写清楚宏做什么、怎么用、错误意味着什么
5. *模块化* — 复杂宏要拆分文件，逻辑清晰

过程宏的本质是 *编译时计算*——你把一部分逻辑从运行时提前到编译时执行。这不仅减少了重复代码，还让生成的代码拥有手工编写级别的性能。

在 Rust 的世界里，只要你能 parse 它，你就能生成它。
#pagebreak()
