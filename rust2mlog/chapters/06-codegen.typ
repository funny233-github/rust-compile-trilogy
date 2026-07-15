#import "../lib.typ": *
= 代码生成 — IR → MLOG 文本
#labnote[ 第六站：生成指令 ]

IR 已经是 MLOG 的近亲。现在把每个 IR 指令一对一地映射到 MLOG 文本。

== IrInstr → MLOG 字符串

```rust
// codegen.rs
pub fn generate_milog(instrs: &[IrInstr]) -> String {
    let mut out = String::new();

    for instr in instrs {
        let line = match instr {
            IrInstr::Set { result, value } => {
                format!("set {} {}", result, fmt_value(value))
            }

            IrInstr::Op { opcode, result, lhs, rhs } => {
                format!("op {} {} {} {}",
                    opcode, result,
                    fmt_value(lhs),
                    fmt_value(rhs),
                )
            }

            IrInstr::Jump { label } => {
                format!("jump {} always", label)
            }

            IrInstr::JumpIf { label, condition, lhs, rhs } => {
                let cond_str = match condition.as_str() {
                    "eq"  => "equal",
                    "neq" => "notEqual",
                    "lt"  => "lessThan",
                    "gt"  => "greaterThan",
                    "lteq" => "lessThanEq",
                    "gteq" => "greaterThanEq",
                    "not" => "not",
                    _ => condition,
                };
                format!("jump {} {} {} {}",
                    label, cond_str,
                    fmt_value(lhs),
                    fmt_value(rhs),
                )
            }

            IrInstr::Label(name) => {
                format!(":{}", name)
            }

            IrInstr::Print(val) => {
                format!("print {}", fmt_value(val))
            }

            IrInstr::PrintFlush(block) => {
                format!("printflush {}", block)
            }

            IrInstr::Sensor { result, object, property } => {
                format!("sensor {} {} {}", result, object, property)
            }

            IrInstr::Control { action, block, value } => {
                format!("control {} {} {} 0 0 0",
                    action, block, fmt_value(value))
            }

            IrInstr::Ubind(unit_type) => {
                format!("ubind {}", unit_type)
            }
            // ...
        };

        out.push_str(&line);
        out.push('\n');
    }

    out
}
```

== 值的格式化

```rust
fn fmt_value(val: &IrValue) -> String {
    match val {
        IrValue::Number(n) => {
            // MLOG 中的数字直接用标准格式
            if *n == n.floor() && n.is_finite() {
                format!("{}", *n as i64)
            } else {
                format!("{}", n)
            }
        }
        IrValue::String(s) => {
            // MLOG 字符串用双引号
            format!("\"{}\"", s)
        }
        IrValue::Var(name) => name.clone(),
        IrValue::Temp(id) => format!("__tmp_{}", id),
        IrValue::Special(name) => name.clone(),
    }
}
```

#concept[
  `fmt_value` 是代码生成中最关键的小函数。

  它把 IR 中的抽象值类型转换为 MLOG 文本中的具体表示。注意：
  - 整数去掉 `.0` 后缀（MLOG 中 `5` 比 `5.0` 更自然）
  - 字符串加双引号
  - 临时变量名按 `__tmp_N` 格式
]

== 完整的代码生成示例

输入 IR：

```
set i 0
set limit 5
set sum 0
:__while_0
op lt __tmp_0 i limit
jump __end_while_0 equal __tmp_0 false
op add sum sum i
op add i i 1
jump __while_0 always
:__end_while_0
print "Sum: "
print sum
printflush message1
```

输出 MLOG（和 IR 一模一样——因为 IR 已经设计为 1:1 映射）：

```
set i 0
set limit 5
set sum 0
:__while_0
op lt __tmp_0 i limit
jump __end_while_0 equal __tmp_0 false
op add sum sum i
op add i i 1
jump __while_0 always
:__end_while_0
print "Sum: "
print sum
printflush message1
```

== MLOG 变量名的考虑

MLOG 变量名有一些隐含规则：

1. 区分大小写：`counter` 和 `Counter` 是不同的
2. 不能以数字开头
3. 不能包含空格或特殊字符
4. `@` 开头的是内建变量
5. 不能用 MLOG 关键字：`set` `op` `jump` `read` `write` 等

我们的编译器做几件事来保证安全：
- 临时变量以 `__tmp_` 开头——用户不太可能重名
- 标签以 `__` 前缀确保不会冲突
- 检查用户变量名不冲突（诊断阶段）

== 一个值得注意的设计选择

为什么不把 IR 省掉、直接从 AST 生成 MLOG？

```
AST → MLOG（略过 IR）
```

#intuition[
  没有 IR 阶段也能工作——AST 语句的代码生成可以内联处理表达式。

  但有 IR 的好处：

  1. *清晰的分界*：AST 阶段关心"语法"，IR 阶段关心"指令序列"，codegen 阶段关心"文本格式"
  2. *可测试*：每个阶段的输出都可以独立验证
  3. *可优化*：未来可以在 IR 层面做优化（消除冗余临时变量、合并相邻指令）
  4. *可调试*：出问题时，打印 IR 中间状态非常有用

  对于教学目的，三层架构清晰、易理解。对于生产环境，两层（AST → MLOG）也可以工作。
]

== 在宏入口中串联

回到 `lib.rs`，串联所有阶段：

```rust
#[proc_macro]
pub fn mlog(input: TokenStream) -> TokenStream {
    let input: proc_macro2::TokenStream = input.into();

    // Phase 1: Parse
    let program = match parser::parse_program(input) {
        Ok(ast) => ast,
        Err(err) => return err.to_compile_error().into(),
    };

    // Phase 2: Lower to IR
    let ir = ir::lower_program(&program);

    // Phase 3: Generate MLOG text
    let mlog_text = codegen::generate_mlog(&ir.instrs);

    // Phase 4: Return as string literal
    quote::quote! { #mlog_text }.into()
}
```

== 小结

- 代码生成是 IR → MLOG 文本的直接转换
- `fmt_value` 处理值的 MLOG 表示（数字去 `.0`、字符串加引号）
- IR 已经设计为 1:1 映射，代码生成几乎是逐条翻译
- 编译器管好变量名——`__tmp_N` 避免冲突
- 三层架构（AST → IR → MLOG）清晰、可测试
- 四个阶段在宏入口中串联，编译时完成全部工作
#pagebreak()
