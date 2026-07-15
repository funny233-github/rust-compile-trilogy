#import "../lib.typ": *
= 过程宏架构设计
#labnote[ 第三站：选型与项目骨架 ]

开始编码之前，先确定整体架构。选择哪种过程宏、怎么组织代码、数据流怎么走——这些决定直接影响到后续所有章节。

== 三种宏类型的取舍

在 proc-macro-guide 中我们学过了三种过程宏。现在为 MLOG 编译器选择一个。

| 方案 | 用法 | 适合吗 |
|:---|:---|:---|
| Derive 宏 | `#[derive(Mlog)] struct Foo` | ❌ 语法不匹配，我们需要代码块 |
| Attribute 宏 | `#[mlog] fn foo() { ... }` | 🤔 可行，但函数签名是多余的 |
| 函数式宏 | `mlog! { ... }` | ✅ 最自然，直接嵌入代码块 |

*选择函数式宏*：`mlog! { ... }` 最直观。输入是一段 DSL 代码块，输出是 MLOG 文本的字符串字面量。

```rust
let program: &str = mlog! {
    let mut i = 0;
    while i < 10 {
        print(i);
        i += 1;
    }
};
// program 是展开后的 MLOG 文本
```

== Crate 结构

```
mlog/
├── Cargo.toml              # facade crate（用户直接依赖）
├── src/
│   └── lib.rs              # 重新导出宏 + 工具函数
└── mlog-macro/
    ├── Cargo.toml          # proc-macro = true
    └── src/
        ├── lib.rs          # 宏入口
        ├── parser.rs       # DSL 解析器
        ├── ast.rs          # 语法树定义
        ├── ir.rs           # 三地址码中间表示
        ├── codegen.rs      # IR → MLOG 代码生成
        └── diagnostics.rs  # 错误报告
```

```
// mlog/Cargo.toml
[dependencies]
mlog-macro = { path = "../mlog-macro" }
```

```
// mlog-macro/Cargo.toml
[lib]
proc-macro = true

[dependencies]
proc-macro2 = "1.0"
quote = "1.0"
```

#concept[
  *Facade 模式*：用户只依赖 `mlog` crate。`mlog` 重新导出 `mlog!` 宏。

  `mlog-macro` 是实际的 proc-macro crate，用户不直接依赖它。
  这是 Rust 过程宏生态的标准做法。
]

== 编译器数据流

```
DSL 源代码
    │
    ▼
TokenStream (proc_macro)
    │
    ▼
TokenStream (proc_macro2)  // .into()
    │
    ▼
parser.rs → AST            // 语法树：Program > Stmt > Expr
    │
    ▼
ir.rs → TAC (三地址码)     // 中间表示：指令序列
    │
    ▼
codegen.rs → Vec<MlogInstr> // MLOG 指令序列
    │
    ▼
String                    // 格式化输出
    │
    ▼
TokenStream (proc_macro)   // quote! { "..." }
    │
    ▼
&'static str              // 展开为字面量
```

== AST 节点设计

```rust
// ast.rs
pub struct Program {
    pub stmts: Vec<Stmt>,
}

pub enum Stmt {
    Let {
        name: Ident,
        mutable: bool,
        init: Expr,
    },
    Assign {
        name: Ident,
        value: Expr,
    },
    If {
        condition: Expr,
        then_branch: Vec<Stmt>,
        else_branch: Option<Vec<Stmt>>,
    },
    While {
        condition: Expr,
        body: Vec<Stmt>,
    },
    Loop {
        body: Vec<Stmt>,
    },
    Break,
    Print(Expr),
    PrintFlush(Ident),
    Enable(Ident),
    Disable(Ident),
    Sensor {
        result: Ident,
        object: Ident,
        property: Ident,
    },
    ExprStmt(Expr),
}

pub enum Expr {
    Number(f64),
    String(String),
    Variable(Ident),
    BinaryOp {
        lhs: Box<Expr>,
        op: BinaryOp,
        rhs: Box<Expr>,
    },
    UnaryOp {
        op: UnaryOp,
        expr: Box<Expr>,
    },
}

pub enum BinaryOp {
    Add, Sub, Mul, Div, Mod,
    Eq, Neq, Lt, Gt, Lteq, Gteq,
    And, Or,
}

pub enum UnaryOp {
    Neg, Not,
}
```

#intuition[
  AST 是编译器的第一层抽象。

  它不关心 MLOG 的三地址码限制——`let z = x + y * 3` 在 AST 中是一个嵌套的 `BinaryOp` 树。
  后面 IR 阶段会把嵌套表达式拍平成 MLOG 能消费的三地址码序列。
]

== 宏入口

```rust
// mlog-macro/src/lib.rs
use proc_macro::TokenStream;

mod ast;
mod parser;
mod ir;
mod codegen;
mod diagnostics;

#[proc_macro]
pub fn mlog(input: TokenStream) -> TokenStream {
    // 1. 解析 DSL → AST
    let program = match parser::parse_program(input.into()) {
        Ok(ast) => ast,
        Err(err) => return err.to_compile_error().into(),
    };

    // 2. AST → IR（三地址码）
    let ir = ir::lower_program(&program);

    // 3. IR → MLOG 指令序列
    let mlog_instrs = codegen::generate(&ir);

    // 4. 格式化为字符串
    let output = codegen::format(&mlog_instrs);

    // 5. 返回为字符串字面量
    quote::quote! { #output }.into()
}
```

== 为什么返回 String 而不是用 quote!

注意第 5 步——`quote! { #output }` 生成的是 TokenStream 形式的字符串字面量。

这和之前教程中的做法不同。之前我们用 `quote!` 生成 Rust 代码。这里我们生成的 MLOG *不是* Rust 代码——它只是一个字符串常量，可以嵌入 Rust 程序中使用。

#concept[
  编译器的输出是 *MLOG 文本*，不是 Rust 代码。

  `mlog! { ... }` 展开后是 `"set x 5\nop add ..."` 这样的字符串。
  用户可以用 `include_str!`、`write!` 等方式进一步处理。
]

== 小结

- 选函数式宏 `#`proc_macro``，最自然地嵌入 DSL 代码块
- Facade crate 模式：`mlog` + `mlog-macro`
- 编译器流水线：TokenStream → AST → IR → MLOG 指令 → String
- AST 是嵌套语法树，IR 是三地址码，两个阶段分离关注点
- 输出是 MLOG 文本字符串，不是 Rust 代码
- 模块化：parser / ast / ir / codegen / diagnostics 各司其职
#pagebreak()
