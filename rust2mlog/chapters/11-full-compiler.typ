#import "../lib.typ": *
= 实战：从 DSL 到 MLOG 的完整流程
#labnote[ 第十一站：组装编译器 ]

前面分别写了解析器、IR、代码生成、诊断。现在把它们拼在一起，并测试两个完整的 Mindustry 场景。

== 完整的宏入口

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
    let input_ts: proc_macro2::TokenStream = input.into();

    // 1. Parse DSL → AST
    let program = match parser::parse_program(input_ts) {
        Ok(ast) => ast,
        Err(err) => return err.to_compile_error().into(),
    };

    // 2. Semantic checks
    if let Err(err) = diagnostics::check(&program) {
        return err.to_compile_error().into();
    }

    // 3. AST → IR (Three-Address Code)
    let ir = ir::lower_program(&program);

    // 4. IR → MLOG text
    let mlog_text = codegen::generate_mlog(&ir.instrs);

    // 5. Return as &str literal
    quote::quote! { #mlog_text }.into()
}
```

== 场景一：仓库库存监控

在 Mindustry 中监控容器中铜的数量，小于阈值时启动传送带。

DSL：

```rust
let program = mlog! {
    let threshold = 100;

    loop {
        sensor(copper, container1, @copper);

        if copper < threshold {
            enable(conveyor1);
        } else {
            disable(conveyor1);
        }

        print("Copper: ");
        print(copper);
        print_flush(message1);
    }
};
```

生成的 MLOG：

```
set __threshold_0 100
:__loop_1
sensor __copper_2 container1 @copper
op lt __t0 __copper_2 __threshold_0
jump __else_3 equal __t0 false
control enabled conveyor1 1 0 0 0
jump __end_if_4 always
:__else_3
control enabled conveyor1 0 0 0 0
:__end_if_4
print "Copper: "
print __copper_2
printflush message1
jump __loop_1 always
```

验证：复制到 Mindustry，链接 container1、conveyor1 和 message1。运行后显示屏上会出现实时铜数量，传送带在 < 100 时自动启动。

== 场景二：单位巡逻

让一个 Poly 单位在两个坐标间来回巡逻。

DSL：

```rust
let program = mlog! {
    ubind(@poly);

    let target_x = 100;
    let target_y = 100;
    let mut at_first = true;

    loop {
        if at_first {
            target_x = 200;
            target_y = 300;
        } else {
            target_x = 100;
            target_y = 100;
        }

        ucontrol_move(target_x, target_y);

        sensor(x, @unit, @x);
        sensor(y, @unit, @y);

        let dx = x - target_x;
        let dy = y - target_y;
        let dist = dx * dx + dy * dy;

        if dist < 16 {
            at_first = !at_first;
        }
    }
};
```

生成的 MLOG：

```
ubind @poly
set __target_x_0 100
set __target_y_1 100
set __at_first_2 1
:__loop_3
jump __else_4 equal __at_first_2 false
set __target_x_0 200
set __target_y_1 300
jump __end_if_5 always
:__else_4
set __target_x_0 100
set __target_y_1 100
:__end_if_5
ucontrol move __target_x_0 __target_y_1 0 0 0
sensor __x_6 @unit @x
sensor __y_7 @unit @y
op sub __t0 __x_6 __target_x_0
set __dx_8 __t0
op sub __t1 __y_7 __target_y_1
set __dy_9 __t1
op mul __t2 __dx_8 __dx_8
op mul __t3 __dy_9 __dy_9
op add __t4 __t2 __t3
set __dist_10 __t4
op lt __t5 __dist_10 16
jump __skip_11 equal __t5 false
op eq __t6 __at_first_2 0
set __at_first_2 __t6
:__skip_11
jump __loop_3 always
```

#intuition[
  注意 `!at_first` 的翻译：`at_first = !at_first` 在 MLOG 中变成：

  ```
  op eq __t6 __at_first_2 0    // __t6 = (at_first == false)
  set __at_first_2 __t6        // at_first = __t6
  ```

  MLOG 没有逻辑非——用 `== false`（`eq x 0`）模拟。
]

== 测试编译器的输出

使用单元测试验证生成的 MLOG：

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_simple_assignment() {
        let result = compile("let x = 5;");
        assert_eq!(result.trim(), "set __x_0 5");
    }

    #[test]
    fn test_addition() {
        let result = compile("let z = x + y;");
        assert_eq!(result.trim(),
            "op add __t0 __x_0 __y_1\nset __z_2 __t0");
    }

    #[test]
    fn test_while_loop() {
        let result = compile(
            "let mut i = 0; while i < 10 { i = i + 1; }"
        );
        assert!(result.contains(":__while_"));
        assert!(result.contains("jump"));
    }

    #[test]
    fn test_error_undefined_var() {
        let result = try_compile("let z = x;");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not defined"));
    }
}
```

#concept[
  单元测试验证生成 MLOG 的正确性，不需要 Mindustry。

  把 `compile` 函数抽象出来（不含宏包装），在测试中直接调用解析 + IR + 代码生成。
]

== 编译器的文件清单

```
mlog-macro/src/
├── lib.rs           # 宏入口 (20 行)
├── ast.rs           # AST 定义 (50 行)
├── parser.rs        # 解析器 (350 行)
├── ir.rs            # IR 定义 + 降级 (250 行)
├── codegen.rs       # MLOG 代码生成 (150 行)
├── diagnostics.rs   # 语义检查 + 错误报告 (100 行)
└── vars.rs          # 作用域 + 变量管理 (80 行)
```

总共约 1000 行 Rust——一个完整的 MLOG 编译器。

== 小结

- 宏入口是装配线：解析 → 诊断 → IR → 代码生成 → 输出
- 仓库监控：sensor + if/else + printflush 完整闭环
- 单位巡逻：ubind + ucontrol + 距离计算 + 状态切换
- MLOG 的 `!` 用 `eq x 0` 模拟
- 单元测试验证 MLOG 输出正确性
- 完整编译器约 1000 行 Rust
#pagebreak()
