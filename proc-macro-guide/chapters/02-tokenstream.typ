#import "../lib.typ": *
= TokenStream — 编译器眼中的代码
#labnote[ 第二站 ]

TokenStream 是理解过程宏的*核心概念*——它是编译器表示源代码的内部数据结构。

它不是字符串。它是编译器经过词法分析后的输出——一串带有位置信息的 token。

== TokenStream 的组成

TokenStream 包含一系列 *TokenTree*，每个 TokenTree 是以下四种之一：

| TokenTree 类型 | 对应什么 | 示例 |
|:---|:---|:---|
| `Ident` | 标识符 | `foo`、`struct`、`_x` |
| `Punct` | 标点符号 | `+`、`::`、`->` |
| `Literal` | 字面量 | `42`、`"hello"`、`3.14` |
| `Group` | 括号分组 | `{ ... }`、`(...)`、`[...]` |

#example[
  对于这段代码：

  ```rust
  fn add(x: i32) -> i32 { x + 1 }
  ```

  编译器看到的 TokenStream 大致是：

  ```
  Ident("fn"), Ident("add"), Group(() [
    Ident("x"), Punct(":"), Ident("i32")
  ]), Punct("->"), Ident("i32"), Group({) [
    Ident("x"), Punct("+"), Literal("1")
  ]}
  ```

  `()` 和 `{}` 是 Group——它们包含了内部的 TokenStream。
]

== 打印 TokenStream

写一个宏来观察输入的 TokenStream 结构：

```rust
#[proc_macro]
pub fn print_tokens(input: TokenStream) -> TokenStream {
    for tt in input.clone() {
        match tt {
            TokenTree::Ident(ident) => eprintln!("Ident: {}", ident),
            TokenTree::Punct(punct) => {
                eprintln!("Punct: {}, (spacing={:?})", punct, punct.spacing())
            }
            TokenTree::Group(group) => {
                eprintln!("Group({:?}): [ {:#?} ]", group.delimiter(), group.stream())
            }
            TokenTree::Literal(literal) => eprintln!("Literal: {}", literal),
        }
    }
    input
}
```

```rust
print_tokens! {
    fn hello(x: u32) -> u32 { x * 2 }
}
```

stderr 输出：

```
Group(Brace): [
  Ident: "fn"
  Ident: "hello"
  Group(Paren): [
    Ident: "x"
    Punct: ":"
    Ident: "u32"
  ]
  Punct: "->"
  Ident: "u32"
  ...
]
```

#intuition[
  *TokenStream 是编译器的"母语"。*

  你的 Rust 代码经过词法分析 → TokenStream → AST → HIR → MIR → 机器码。

  过程宏在 TokenStream 阶段介入——把输入 TokenStream 变换成输出 TokenStream。
]

== Group：括号里的世界

#definition[
  *Group* 代表一对配对的括号（`( )`、`[ ]`、`{ }`）及其内部的所有 token。

  每个 Group 有：
  - `delimiter()`：括号类型（`Parenthesis`、`Bracket`、`Brace`、`None`）
  - `stream()`：内部的 TokenStream
]

Group 在过程宏中非常重要——当你解析 Rust 代码时，所有"内部"的东西都被包在 Group 里。`fn foo(args) { body }` 中，参数列表在 `(...)` Group 里，函数体在 `{...}` Group 里。

== Ident、Punct、Literal

| 类型 | 关键方法 | 用途 |
|:---|:---|:---|
| `Ident` | `.to_string()` | 读取标识符名称 |
| `Punct` | `.as_char()`、`.spacing()` | 读取符号，判断是否有空格间隔 |
| `Literal` | `.to_string()` | 读取字面量文本表示 |

Punct 的 `spacing()` 返回 `Spacing::Alone` 或 `Spacing::Joint`：
- `->`：`-` 的 spacing = `Joint`（和 `>` 连在一起）
- `+ 1`：`+` 的 spacing = `Alone`（后面有空格）

== TokenStream 是可解析的

TokenStream 是一个扁平化的 token 序列，Group 展开后形成树形结构。

在过程宏中，你的工作就是：

1. 接收一段输入 TokenStream
2. *解析* 它——转换成有意义的数据结构（用 `syn`）
3. *处理* 它——根据数据生成新的代码
4. *输出* 新的 TokenStream（用 `quote`）

整个过程在编译器内部完成，不产生运行时开销。

== 字符串与 TokenStream 的互相转换

```rust
// 字符串 → TokenStream
let ts: TokenStream = "fn answer() -> u32 { 42 }".parse().unwrap();

// TokenStream → 字符串（用于调试）
let s = ts.to_string();
```

不过日常开发中你不会这样写——你会用 `syn` 解析，用 `quote!` 生成。

#warning[
  直接用字符串拼接生成代码非常不推荐：

  - 没有语法检查
  - 容易产生无效的 Rust 代码
  - 没有卫生性保护

  后面会学 `quote!`——安全的代码生成方式。
]

== 小结

- TokenStream = 词法分析后的 token 序列
- 四种 TokenTree：Ident（标识符）、Punct（标点）、Literal（字面量）、Group（括号分组）
- Group 包含括号和内部 TokenStream——代码的嵌套结构由此体现
- 过程宏的流程：输入 TokenStream → 解析 → 处理 → 生成 → 输出 TokenStream
- 不要直接拼接字符串来生成代码——用 `syn` 和 `quote`
#pagebreak()
