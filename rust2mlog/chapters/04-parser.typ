#import "../lib.typ": *
= 解析器 — 把 TokenStream 变成 AST
#labnote[ 第四站：手写解析 ]

现在写解析器。我要把 `mlog! { ... }` 中的 DSL 代码解析成第三章定义的那些 AST 节点。

== 为什么不用 syn 的 DeriveInput

之前写 derive 宏时，`syn` 提供了 `DeriveInput`、`ItemFn` 等现成的解析结构。但这里不一样——

我们的输入不是标准 Rust 语法结构。`let mut x = 0;` 是有效的 Rust，但 `print_flush(message1);` 和 `sensor(v, @unit, @x)` 不是——它们是自定义的 DSL。

所以需要*手写解析器*。

== 准备工作：Peek 和 Parse 模式

syn 仍然有用——它的 `ParseStream` 提供了 peek/parse 能力：

```rust
use syn::parse::{Parse, ParseStream};
use proc_macro2::{TokenStream, Ident, Literal, TokenTree};

// 逐 token 读取
fn parse_program(input: ParseStream) -> syn::Result<Program> {
    let mut stmts = Vec::new();
    while !input.is_empty() {
        stmts.push(parse_stmt(input)?);
    }
    Ok(Program { stmts })
}
```

核心方法：
- `input.peek(Token![let])` — 看下一个 token，不消费
- `input.parse::<Ident>()` — 消费并解析一个标识符
- `input.parse::<Token![;]>()` — 消费分号
- `input.is_empty()` — 是否到达末尾

== 解析语句

```rust
fn parse_stmt(input: ParseStream) -> syn::Result<Stmt> {
    if input.peek(Token![let]) {
        parse_let_stmt(input)
    } else if input.peek(Token![if]) {
        parse_if_stmt(input)
    } else if input.peek(Token![while]) {
        parse_while_stmt(input)
    } else if input.peek(Token![loop]) {
        parse_loop_stmt(input)
    } else if input.peek(Token![break]) {
        parse_break_stmt(input)
    } else if is_identifier(input) && input.peek2(Token![=]) {
        // x = ...;  赋值语句
        parse_assign_stmt(input)
    } else {
        // 以表达式开头的语句
        parse_expr_stmt(input)
    }
}
```

=== let 语句

```rust
fn parse_let_stmt(input: ParseStream) -> syn::Result<Stmt> {
    input.parse::<Token![let]>()?;

    let mutable = input.peek(Token![mut]);
    if mutable {
        input.parse::<Token![mut]>()?;
    }

    let name: Ident = input.parse()?;
    input.parse::<Token![=]>()?;
    let init: Expr = parse_expr(input)?;
    input.parse::<Token![;]>()?;

    Ok(Stmt::Let { name, mutable, init: Box::new(init) })
}
```

=== if 语句

```rust
fn parse_if_stmt(input: ParseStream) -> syn::Result<Stmt> {
    input.parse::<Token![if]>()?;
    let condition = parse_expr(input)?;
    let then_branch = parse_block(input)?;

    let else_branch = if input.peek(Token![else]) {
        input.parse::<Token![else]>()?;
        if input.peek(Token![if]) {
            // else if → 递归当作 if 语句处理
            Some(vec![parse_if_stmt(input)?])
        } else {
            Some(parse_block(input)?)
        }
    } else {
        None
    };

    Ok(Stmt::If { condition, then_branch, else_branch })
}
```

=== 解析代码块

```rust
fn parse_block(input: ParseStream) -> syn::Result<Vec<Stmt>> {
    let content;
    syn::braced!(content in input);  // 匹配 { ... }
    let mut stmts = Vec::new();
    while !content.is_empty() {
        stmts.push(parse_stmt(&content)?);
    }
    Ok(stmts)
}
```

== 表达式解析

表达式解析是编译器中最经典的部分——需要处理优先级和结合性。

#definition[
  *操作符优先级*（从高到低）：

  | 优先级 | 操作符 |
  |:---|:---|
  | 最高 | `()` 括号、字面量、变量 |
  | 一元 | `-`、`!` |
  | 乘法 | `*` `/` `%` |
  | 加法 | `+` `-` |
  | 比较 | `==` `!=` `<` `>` `<=` `>=` |
  | 逻辑 | `&&` `\|\|` |
  | 最低 | 赋值（不在表达式中处理，由 `parse_stmt` 处理） |
]

== 经典的递归下降解析

```rust
// 入口：解析整个表达式
fn parse_expr(input: ParseStream) -> syn::Result<Expr> {
    parse_logical_or(input)
}

// expr || expr ...
fn parse_logical_or(input: ParseStream) -> syn::Result<Expr> {
    let mut left = parse_logical_and(input)?;
    while input.peek(Token![||]) {
        input.parse::<Token![||]>()?;
        let right = parse_logical_and(input)?;
        left = Expr::BinaryOp {
            lhs: Box::new(left),
            op: BinaryOp::Or,
            rhs: Box::new(right),
        };
    }
    Ok(left)
}

// expr && expr ...
fn parse_logical_and(input: ParseStream) -> syn::Result<Expr> {
    let mut left = parse_comparison(input)?;
    while input.peek(Token![&&]) {
        input.parse::<Token![&&]>()?;
        let right = parse_comparison(input)?;
        left = Expr::BinaryOp {
            lhs: Box::new(left),
            op: BinaryOp::And,
            rhs: Box::new(right),
        };
    }
    Ok(left)
}

// expr == expr 等等
fn parse_comparison(input: ParseStream) -> syn::Result<Expr> {
    let mut left = parse_add_sub(input)?;
    if input.peek(Token![==]) {
        input.parse::<Token![==]>()?;
        let right = parse_add_sub(input)?;
        return Ok(Expr::BinaryOp {
            lhs: Box::new(left), op: BinaryOp::Eq, rhs: Box::new(right),
        });
    }
    if input.peek(Token![!=]) {
        input.parse::<Token![!=]>()?;
        let right = parse_add_sub(input)?;
        return Ok(Expr::BinaryOp {
            lhs: Box::new(left), op: BinaryOp::Neq, rhs: Box::new(right),
        });
    }
    if input.peek(Token![<]) {
        input.parse::<Token![<]>()?;
        let right = parse_add_sub(input)?;
        return Ok(Expr::BinaryOp {
            lhs: Box::new(left), op: BinaryOp::Lt, rhs: Box::new(right),
        });
    }
    if input.peek(Token![>]) {
        input.parse::<Token![>]>()?;
        let right = parse_add_sub(input)?;
        return Ok(Expr::BinaryOp {
            lhs: Box::new(left), op: BinaryOp::Gt, rhs: Box::new(right),
        });
    }
    if input.peek(Token![<=]) {
        input.parse::<Token![<=]>()?;
        let right = parse_add_sub(input)?;
        return Ok(Expr::BinaryOp {
            lhs: Box::new(left), op: BinaryOp::Lteq, rhs: Box::new(right),
        });
    }
    if input.peek(Token![>=]) {
        input.parse::<Token![>=]>()?;
        let right = parse_add_sub(input)?;
        return Ok(Expr::BinaryOp {
            lhs: Box::new(left), op: BinaryOp::Gteq, rhs: Box::new(right),
        });
    }
    Ok(left)
}

// expr + expr, expr - expr
fn parse_add_sub(input: ParseStream) -> syn::Result<Expr> {
    let mut left = parse_mul_div(input)?;
    loop {
        if input.peek(Token![+]) {
            input.parse::<Token![+]>()?;
            let right = parse_mul_div(input)?;
            left = Expr::BinaryOp {
                lhs: Box::new(left), op: BinaryOp::Add, rhs: Box::new(right),
            };
        } else if input.peek(Token![-]) {
            input.parse::<Token![-]>()?;
            let right = parse_mul_div(input)?;
            left = Expr::BinaryOp {
                lhs: Box::new(left), op: BinaryOp::Sub, rhs: Box::new(right),
            };
        } else {
            break;
        }
    }
    Ok(left)
}

// expr * expr, expr / expr, expr % expr
fn parse_mul_div(input: ParseStream) -> syn::Result<Expr> {
    let mut left = parse_unary(input)?;
    loop {
        if input.peek(Token![*]) {
            input.parse::<Token![*]>()?;
            let right = parse_unary(input)?;
            left = Expr::BinaryOp {
                lhs: Box::new(left), op: BinaryOp::Mul, rhs: Box::new(right),
            };
        } else if input.peek(Token![/]) {
            input.parse::<Token![/]>()?;
            let right = parse_unary(input)?;
            left = Expr::BinaryOp {
                lhs: Box::new(left), op: BinaryOp::Div, rhs: Box::new(right),
            };
        } else if input.peek(Token![%]) {
            input.parse::<Token![%]>()?;
            let right = parse_unary(input)?;
            left = Expr::BinaryOp {
                lhs: Box::new(left), op: BinaryOp::Mod, rhs: Box::new(right),
            };
        } else {
            break;
        }
    }
    Ok(left)
}

// 一元运算：-expr, !expr
fn parse_unary(input: ParseStream) -> syn::Result<Expr> {
    if input.peek(Token![-]) {
        input.parse::<Token![-]>()?;
        let expr = parse_atom(input)?;
        Ok(Expr::UnaryOp { op: UnaryOp::Neg, expr: Box::new(expr) })
    } else if input.peek(Token![!]) {
        input.parse::<Token![!]>()?;
        let expr = parse_atom(input)?;
        Ok(Expr::UnaryOp { op: UnaryOp::Not, expr: Box::new(expr) })
    } else {
        parse_atom(input)
    }
}

// 原子：字面量、变量、括号
fn parse_atom(input: ParseStream) -> syn::Result<Expr> {
    if input.peek(syn::LitInt) || input.peek(syn::LitFloat) {
        let lit: syn::Lit = input.parse()?;
        let num: f64 = lit.to_string().parse()
            .map_err(|_| input.error("invalid number"))?;
        Ok(Expr::Number(num))
    } else if input.peek(syn::LitStr) {
        let lit: syn::LitStr = input.parse()?;
        Ok(Expr::String(lit.value()))
    } else if input.peek(Token![true]) {
        input.parse::<Token![true]>()?;
        Ok(Expr::Number(1.0))
    } else if input.peek(Token![false]) {
        input.parse::<Token![false]>()?;
        Ok(Expr::Number(0.0))
    } else if input.peek(syn::Ident) {
        let ident: syn::Ident = input.parse()?;
        Ok(Expr::Variable(ident))
    } else if input.peek(syn::token::Paren) {
        let content;
        syn::parenthesized!(content in input);
        parse_expr(&content)
    } else {
        Err(input.error("expected expression"))
    }
}
```

== 特殊语句解析

除了标准控制流，还需要解析 DSL 特有的"函数调用"：

=== print / print_flush

```rust
fn parse_special_call(input: ParseStream) -> syn::Result<Option<Stmt>> {
    let ident: Ident = input.parse()?;
    match ident.to_string().as_str() {
        "print" => {
            let content;
            syn::parenthesized!(content in input);
            let expr = parse_expr(&content)?;
            input.parse::<Token![;]>()?;
            Ok(Some(Stmt::Print(expr)))
        }
        "print_flush" => {
            let content;
            syn::parenthesized!(content in input);
            let block: Ident = content.parse()?;
            input.parse::<Token![;]>()?;
            Ok(Some(Stmt::PrintFlush(block)))
        }
        "sensor" => {
            let content;
            syn::parenthesized!(content in input);
            let object: Ident = content.parse()?;
            content.parse::<Token![,]>()?;
            let property: Ident = content.parse()?;
            input.parse::<Token![;]>()?;
            Ok(Some(Stmt::Sensor { result: ident, object, property }))
        }
        "enable" | "disable" => {
            // ...
        }
        _ => Ok(None),
    }
}
```

== 解析器的位置

解析器完整代码约 300-400 行。关键技巧：

#concept[
  1. *递归下降*：每层函数处理一个优先级级别
  2. *peek 先行*：看下个 token 但不消费，决定走哪个分支
  3. *错误传播*：用 `syn::Result` 和 `?`，失败时自动带 span 信息
  4. *syn 辅助*：`braced!`、`parenthesized!` 等宏简化括号处理
]

== 小结

- 手写解析器因为 DSL 不是标准 Rust 语法
- 递归下降法：每个优先级一层函数调用
- peek/parse 模式：`input.peek(...)` 先行，`input.parse()` 消费
- AST 保持嵌套结构——表达式树尚未展开
- syn 的 ParseStream 是通用 token 流解析器，不限于 Rust 语法
- 整个解析器约 300-400 行就能处理我们的 DSL 全集
#pagebreak()
