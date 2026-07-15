#import "../lib.typ": *
= 错误处理与诊断
#labnote[ 第十站：友好的报错 ]

编译器不是只对"正确输入"负责——对"错误输入"的反馈质量同样重要。

#concept[
  过程宏中的错误处理目标：

  1. 精确指向 DSL 源代码中的错误位置（用 Span）
  2. 给出人类可读的错误信息（不是 token dump）
  3. 尽量一次报告多个错误（而不止第一个）
]

== Span 从哪来

syn 的 `Ident`、`Literal`、`Token` 都自带 Span——它们知道自己在原始输入中的位置。

```rust
// 解析时，每个 syn 节点都带了 span 信息
let ident: syn::Ident = input.parse()?;
// ident.span() 指向这个标识符在源文件中的行列位置
```

当解析失败时，直接用节点的 span 创建错误：

```rust
fn parse_let_stmt(input: ParseStream) -> syn::Result<Stmt> {
    input.parse::<Token![let]>()?;
    let name: Ident = input.parse()
        .map_err(|e| {
            // 保留原始 span，但改善错误信息
            syn::Error::new(e.span(),
                "expected variable name after 'let'")
        })?;
    // ...
}
```

== 语义错误 vs 语法错误

语法错误（token 不匹配）syn 自动处理。语义错误需要手动实现：

| 错误 | 类型 | 示例 |
|:---|:---|:---|
| `let x = y;` y 未定义 | 语义 | `error: variable 'y' is not defined` |
| `break;` 不在循环中 | 语义 | `error: 'break' outside loop` |
| `x = 10;` x 不可变 | 语义 | `error: cannot assign to immutable 'x'` |
| `5 + "str"` | 语义 | `error: type mismatch` |

== 诊断系统

```rust
// diagnostics.rs
use proc_macro2::Span;
use syn::Error;

pub struct Diagnostic {
    errors: Vec<Error>,
}

impl Diagnostic {
    pub fn new() -> Self {
        Diagnostic { errors: Vec::new() }
    }

    pub fn error(&mut self, span: Span, msg: impl Into<String>) {
        self.errors.push(Error::new(span, msg.into()));
    }

    pub fn emit(self) -> Result<(), Error> {
        if self.errors.is_empty() {
            return Ok(());
        }
        let mut combined = self.errors.into_iter()
            .reduce(|mut a, b| { a.combine(b); a })
            .unwrap();
        Err(combined)
    }
}
```

#intuition[
  `Diagnostic` 收集多个错误，然后一次性发出。

  syn::Error 的 `combine` 方法将多个错误合并为一个——编译器会显示所有错误位置。

  用户可以在修复一轮后重新编译，看到下一组错误——就像 Rust 编译器的行为。
]

== 典型语义检查

=== 未定义变量

```rust
fn check_variables(ast: &Program, diag: &mut Diagnostic) {
    let mut scope = ScopeManager::new();

    for stmt in &ast.stmts {
        check_stmt_vars(stmt, &mut scope, diag);
    }
}

fn check_stmt_vars(stmt: &Stmt, scope: &mut ScopeManager, diag: &mut Diagnostic) {
    match stmt {
        Stmt::Let { name, init, .. } => {
            check_expr_vars(init, scope, diag);
            scope.declare(&name.to_string(), name.span());
        }
        Stmt::Assign { name, value } => {
            if !scope.contains(&name.to_string()) {
                diag.error(name.span(),
                    format!("variable '{}' is not defined", name));
            }
            if !scope.is_mutable(&name.to_string()) {
                diag.error(name.span(),
                    format!("cannot assign to immutable variable '{}'", name));
            }
            check_expr_vars(value, scope, diag);
        }
        // ... 其他语句
    }
}

fn check_expr_vars(expr: &Expr, scope: &ScopeManager, diag: &mut Diagnostic) {
    if let Expr::Variable(ident) = expr {
        if !scope.contains(&ident.to_string()) {
            diag.error(ident.span(),
                format!("variable '{}' is not defined", ident));
        }
    }
    // ... 递归检查子表达式
}
```

=== break 不在循环中

```rust
fn check_break(stmts: &[Stmt], in_loop: bool, diag: &mut Diagnostic) {
    for stmt in stmts {
        match stmt {
            Stmt::Break => {
                if !in_loop {
                    diag.error(span_of(stmt),
                        "'break' can only be used inside a loop");
                }
            }
            Stmt::While { body, .. } | Stmt::Loop { body } => {
                check_break(body, true, diag);
            }
            _ => {}
        }
    }
}
```

== 与 syn 的错误处理集成

所有诊断检查在解析完成后、生成 IR 之前运行：

```rust
#[proc_macro]
pub fn mlog(input: TokenStream) -> TokenStream {
    let input_ts: proc_macro2::TokenStream = input.into();

    // Phase 1: Parse
    let program = match parser::parse_program(input_ts) {
        Ok(ast) => ast,
        Err(err) => return err.to_compile_error().into(),
    };

    // Phase 1.5: Semantic checks
    let mut diag = Diagnostic::new();
    check_variables(&program, &mut diag);
    check_break(&program.stmts, false, &mut diag);
    if let Err(err) = diag.emit() {
        return err.to_compile_error().into();
    }

    // Phase 2-4: IR → Codegen → Output
    // ...
}
```

== 调试模式

添加一个 `mlog_debug!` 宏，打印中间表示：

```rust
#[proc_macro]
pub fn mlog_debug(input: TokenStream) -> TokenStream {
    let program = match parser::parse_program(input.into()) {
        Ok(ast) => ast,
        Err(err) => return err.to_compile_error().into(),
    };

    let ir = ir::lower_program(&program);
    let ir_dump = format!("{:#?}", ir.instrs);
    let mlog_text = codegen::generate_mlog(&ir.instrs);

    let output = format!(
        "/* IR dump:\n{}\n*/\n{}",
        ir_dump, mlog_text
    );

    quote! { #output }.into()
}
```

这样开发者在不确定编译器行为时可以用 `mlog_debug!` 看到中间表示的 dump。

== 小结

- 用 Span 精确定位 DSL 中的错误位置
- Diagnostic 系统收集多个错误一次报告
- 语义检查：未定义变量、不可变赋值、break 位置
- 检查在解析后、IR 生成前运行
- `mlog_debug!` 打印中间表示辅助调试
- 错误信息应该让 DS L 用户不需要看 MLOG 就能理解
#pagebreak()
