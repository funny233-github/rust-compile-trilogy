#import "../lib.typ": *
= 从 macro_rules! 到过程宏
#labnote[ 第一站 ]

== 两种宏的对比

Rust 有两种宏系统：*声明式宏*（`macro_rules!`）和 *过程宏*（procedural macros）。

它们的本质区别：

| 特性 | macro_rules! | 过程宏 |
|------|:---:|:---:|
| 本质 | 模式匹配 + 替换 | `TokenStream → TokenStream` 的函数 |
| 处理能力 | 匹配替换 | 任意 Rust 逻辑 |
| 类型信息 | 不可访问 | 可解析类型签名 |
| 属性访问 | 不可访问 | 可读取 `#[...]` 属性 |
| 编译开销 | 极轻量 | 有额外开销 |
| 宿主 crate | 不需要额外依赖 | 必须是 proc-macro crate |

过程宏是 *编译期运行的函数*。它输入一段代码的 TokenStream，输出另一段 TokenStream。编译器在类型检查之前执行宏展开。

== 项目结构

创建一个过程宏 crate：

```bash
cargo new hello_proc_macro --lib
cd hello_proc_macro
```

编辑 `Cargo.toml`：

```toml
[lib]
proc-macro = true

[dependencies]
quote = "1.0"
syn = { version = "2.0", features = ["full"] }
```

#definition[
  过程宏 crate 必须在 `Cargo.toml` 中设置 `proc-macro = true`。

  这个标志告诉编译器：这个 crate 不是普通库，而是在编译期运行的代码生成器。

  它只能导出过程宏函数，不能导出普通函数供运行时使用。
]

== 第一个过程宏

最简单的过程宏——什么都不做，直接返回输入：

```rust
// src/lib.rs
use proc_macro::TokenStream;

#[proc_macro]
pub fn identity(input: TokenStream) -> TokenStream {
    input
}
```

创建一个测试工程来验证：

```rust
// tests/test.rs — 或者另一个 crate
use hello_proc_macro::identity;

identity! {
    fn hello() {
        println!("Hello from proc macro!");
    }
}

fn main() {
    hello(); // 输出: Hello from proc macro!
}
```

#concept[
  过程宏的工作流程：

  1. 编译器解析源代码，产生 TokenStream
  2. 把 TokenStream 传给过程宏函数
  3. 过程宏运行（编译期），返回新的 TokenStream
  4. 编译器用返回的 TokenStream 替换宏调用
  5. 继续编译（类型检查、代码生成）
]

== 三种过程宏

Rust 有三种过程宏，用不同的属性标注：

#definition[
  *函数式宏（Function-like macros）* \
  `#[proc_macro]` — 像函数调用一样使用：`my_macro!(...)`

  *派生宏（Derive macros）* \
  `#[proc_macro_derive]` — 用于 `#[derive(MyTrait)]`

  *属性宏（Attribute macros）* \
  `#[proc_macro_attribute]` — 用于给函数/结构体加注解：`#[my_attr]`
]

== 函数式宏示例

```rust
use proc_macro::TokenStream;

#[proc_macro]
pub fn make_answer(_input: TokenStream) -> TokenStream {
    "fn answer() -> u32 { 42 }".parse().unwrap()
}
```

使用：

```rust
use my_macros::make_answer;

make_answer!();

fn main() {
    println!("{}", answer()); // 42
}
```

字符串 `.parse::<TokenStream>()` 是最简单的代码生产方式——但不推荐用于复杂场景（后面会讲 `quote!`）。

== macro_rules! 做不到的事

```rust
// 用过程宏做类型感知的代码生成
#[proc_macro_derive(MySerialize)]
pub fn derive_my_serialize(input: TokenStream) -> TokenStream {
    // 用 syn 解析出 DeriveInput
    // 遍历字段、读取类型、生成序列化代码
    // 如果字段是 Option<T>，生成不同的处理方式
    // 如果字段有 #[serde(skip)] 属性，跳过它
    // ...
}
```

这就是 serde 的 `#[derive(Serialize)]` 的工作原理——`macro_rules!` 完全做不到。

== 过程宏的代价

#warning[
  使用过程宏之前要知道的代价：

  - *编译时间增加*：过程宏在编译期运行，而且是独立编译的
  - *调试困难*：错误信息可能不直观，需要特殊工具（`cargo expand`）
  - *只能返回代码*：不能和运行时交互
  - *需要额外依赖*：`syn`、`quote` 几乎是必备的
  - *卫生性处理*：需要注意标识符冲突问题（后面会讲）
]

== 小结

- `macro_rules!` 基于模式匹配——适合简单的模板化代码
- 过程宏是 `TokenStream → TokenStream` 的函数——可以做任意复杂逻辑
- 三种过程宏：函数式宏、派生宏、属性宏
- 过程宏 crate 必须设置 `proc-macro = true`
- 核心库：`proc_macro`（内置）、`syn`（解析）、`quote`（生成）
- 下一步：理解 TokenStream 到底是什么
#pagebreak()
