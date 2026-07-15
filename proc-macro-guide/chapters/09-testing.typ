#import "../lib.typ": *
= 测试过程宏
#labnote[ 第九站 ]

过程宏在编译期运行，不能像普通代码那样直接写 `#[test]` 测试。但有几种行之有效的测试策略。

== 策略一：集成测试

在另一个 crate 中测试宏展开后的行为。过程宏 crate 可以有自己的 `tests/` 目录：

```
my-macro/
├── Cargo.toml
├── src/
│   └── lib.rs          # 宏定义
└── tests/
    └── integration.rs   # 集成测试
```

```rust
// tests/integration.rs
use my_macro::MyTrait;
use my_macro_derive::MyTrait;

#[derive(MyTrait)]
struct Point { x: i32, y: i32 }

#[test]
fn test_point_method() {
    let p = Point { x: 1, y: 2 };
    let result = p.my_method();
    assert_eq!(result, "Point(1, 2)");
}
```

#concept[
  集成测试的优点：测试完整的宏展开流程，和用户使用方式一致。
  缺点：需要在测试文件中定义类型，编译速度较慢。
]

== 策略二：用 proc_macro2 做单元测试

把核心逻辑和宏入口分离：

```rust
// src/lib.rs — 逻辑拆出去
pub fn derive_my_trait_impl(
    input: &syn::DeriveInput,
) -> syn::Result<proc_macro2::TokenStream> {
    let name = &input.ident;
    // ... 实际逻辑
    Ok(quote! { /* ... */ })
}

// 宏入口是薄薄的包装层
#[proc_macro_derive(MyTrait)]
pub fn derive_my_trait(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    derive_my_trait_impl(&input)
        .unwrap_or_else(|err| err.to_compile_error())
        .into()
}
```

单元测试：

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use syn::parse_quote;

    #[test]
    fn test_basic_struct() {
        let input: syn::DeriveInput = parse_quote! {
            struct Point { x: i32, y: i32 }
        };
        let output = derive_my_trait_impl(&input).unwrap();
        assert!(output.to_string().contains("impl MyTrait for Point"));
    }

    #[test]
    fn test_generic_struct() {
        let input: syn::DeriveInput = parse_quote! {
            struct Wrapper<T: Display> { value: T }
        };
        let output = derive_my_trait_impl(&input).unwrap();
        let output_str = output.to_string();
        assert!(output_str.contains("impl<T: Display>"));
        assert!(output_str.contains("Wrapper<T>"));
    }

    #[test]
    fn test_enum_rejected() {
        let input: syn::DeriveInput = parse_quote! {
            enum MyEnum { A, B, C }
        };
        let result = derive_my_trait_impl(&input);
        assert!(result.is_err());
    }
}
```

#intuition[
  `parse_quote!` 是 syn 提供的神奇宏——在测试中直接写 Rust 代码，自动解析成语法树节点。

  ```rust
  let field: syn::Field = parse_quote! { name: String };
  let ty: syn::Type = parse_quote! { Vec<u32> };
  ```

  不需要从字符串解析，不需要关心 TokenStream 构造——直接写代码就行。
]

== 策略三：编译失败测试（trybuild）

测试宏在错误使用时是否给出友好的编译错误。

```rust
// tests/compile_fail.rs
#[test]
fn compile_fail_tests() {
    let t = trybuild::TestCases::new();
    t.compile_fail("tests/ui/*.rs");
}
```

在 `tests/ui/` 中放"应该编译失败"的文件：

```rust
// tests/ui/enum_not_supported.rs
use my_macro_derive::MyTrait;

#[derive(MyTrait)]
//~^ error: MyTrait can only be derived for structs
enum MyEnum { A, B }
```

`//~^` 注释告诉 trybuild：这个错误信息应该出现在上一行。

#definition[
  trybuild 把源文件作为独立 crate 编译，检查编译结果是否符合预期。

  第一次运行会生成 `.stderr` 文件，之后每次测试都会比较输出是否一致。
]

== 策略四：快照测试

用 `insta` crate 验证生成的代码：

```rust
use insta;

#[test]
fn test_generated_code_snapshot() {
    let input: syn::DeriveInput = parse_quote! {
        struct Point { x: i32, y: i32 }
    };
    let output = derive_my_trait_impl(&input).unwrap();
    let output_str = prettyplease::unparse(
        &syn::parse_file(&output.to_string()).unwrap()
    );
    insta::assert_snapshot!("point_derive", output_str);
}
```

格式化的代码会被保存到快照文件中。修改宏后，`cargo insta review` 可以逐个审查变化。

== 测试策略总结

| 方法 | 适用场景 | 特点 |
|:---|:---|:---|
| 集成测试 | 验证宏展开后的行为 | 最真实，但编译慢 |
| 单元测试 (parse_quote!) | 验证逻辑正确性 | 快速，可精细控制 |
| trybuild | 验证错误信息质量 | 确保友好报错 |
| cargo expand | 手动检查展开结果 | 交互式调试 |
| 快照测试 | 防止回归 | 自动化对比 |

== 最佳实践

```rust
// tests/integration.rs — 功能验证
#[derive(MyTrait)]
struct Point { x: i32, y: i32 }

#[test]
fn it_works() {
    let p = Point { x: 1, y: 2 };
    assert_eq!(p.greeting(), "Hello from Point");
}

// tests/compile_fail.rs — 错误验证
#[test]
fn compile_fail() {
    let t = trybuild::TestCases::new();
    t.compile_fail("tests/ui/*.rs");
}

// src/lib.rs — 单元测试
#[cfg(test)]
mod tests {
    #[test]
    fn test_generics() { /* ... */ }
    #[test]
    fn test_empty_struct_rejected() { /* ... */ }
}
```

== 小结

- 拆分逻辑：核心逻辑放在独立函数中，宏入口只是包装层
- 使用 `parse_quote!` 在测试中快速构造 syn 节点
- 使用 `trybuild` 测试编译失败场景
- 使用快照测试（`insta`）防止代码生成回归
- `cargo expand` 是方便的交互式调试工具
- 好的测试方案 = 单元测试 + 集成测试 + 编译失败测试
#pagebreak()
