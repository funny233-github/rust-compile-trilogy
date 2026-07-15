#import "../lib.typ": *
= 错误处理与调试
#labnote[ 第八站 ]

过程宏出错时，编译器只会给出很有限的信息：

```text
error: proc macro panicked
  --> src/main.rs:10:1
   |
10 | #[derive(MyMacro)]
   | ^^^^^^^^^^^^^^^^^^
   |
   = help: message: called `Result::unwrap()` on an `Err` value: ...
```

没有行号、没有上下文——错误指向宏调用的位置，而不是宏内部的具体问题。

这意味着错误处理对过程宏来说比普通代码更重要。

== 错误处理的两条原则

#concept[
  过程宏中的错误处理：

  1. *永远不要 unwrap。* 使用 `syn::Result` 和 `?` 操作符传播错误
  2. *尽量让错误指向用户的代码位置。* 使用 `Span` 提供精确的行列信息
]

== syn::Error — 正确的错误处理

```rust
use syn::Error;

// ❌ 错误做法
fn parse_field(input: ParseStream) -> syn::Result<Field> {
    let name = input.parse::<Ident>().unwrap();
    // ...
}

// ✅ 正确做法
fn parse_field(input: ParseStream) -> syn::Result<Field> {
    let name: Ident = input.parse()?;  // 传播错误
    // ...
}
```

#definition[
  `syn::Error` 是过程宏的标准错误类型，有两个关键能力：

  1. 关联一个 `Span`——指向用户代码中的具体位置
  2. 可以组合多个错误一起报告

  ```rust
  use syn::Error;
  use proc_macro2::Span;

  let error = Error::new(span, "expected a string literal");

  let mut errors = Error::new(span1, "error 1");
  errors.combine(Error::new(span2, "error 2"));
  ```
]

== 在 derive 宏中使用 Error

```rust
use proc_macro::TokenStream;
use syn::{parse_macro_input, DeriveInput, Error};

#[proc_macro_derive(MyTrait)]
pub fn derive_mytrait(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);

    match derive_mytrait_impl(&input) {
        Ok(tokens) => tokens.into(),
        Err(err) => err.to_compile_error().into(),
    }
}

fn derive_mytrait_impl(input: &DeriveInput)
    -> syn::Result<proc_macro2::TokenStream>
{
    let name = &input.ident;

    let data = match &input.data {
        syn::Data::Struct(data) => data,
        _ => {
            return Err(Error::new_spanned(
                input,
                "MyTrait can only be derived for structs",
            ));
        }
    };

    if data.fields.is_empty() {
        return Err(Error::new_spanned(
            name,
            "MyTrait requires at least one field",
        ));
    }

    Ok(quote! { /* ... */ })
}
```

#intuition[
  `err.to_compile_error()` 是把 `syn::Error` 转化为 `compile_error!()` 宏调用的关键方法。

  它生成类似这样的代码：

  ```rust
  compile_error!("MyTrait can only be derived for structs");
  ```

  并带有正确的 span 信息，让编译器精准报错。
]

== Span：错误定位的生命线

#concept[
  `Span` 代表源代码中的一段位置。

  当你在 syn 中解析代码时，每个 token 都携带了它在源文件中的 span 信息。

  - `Error::new(span, msg)` — 创建一个指向 span 位置的错误
  - `Error::new_spanned(value, msg)` — 自动使用 value 的 span
]

```rust
fn check_field(field: &syn::Field) -> syn::Result<()> {
    let field_name = field.ident.as_ref()
        .ok_or_else(|| Error::new_spanned(
            field,
            "tuple struct fields are not supported",
        ))?;

    if !is_valid_type(&field.ty) {
        return Err(Error::new_spanned(
            &field.ty,
            format!("unsupported type `{}`", quote!(#field.ty)),
        ));
    }

    Ok(())
}
```

当错误发生时，编译器的错误信息会指向具体的字段或类型，而不是宏调用的位置。

== 属性解析中的错误

```rust
fn parse_my_attr(attrs: &[syn::Attribute]) -> syn::Result<MyAttr> {
    for attr in attrs {
        if attr.path().is_ident("my_attr") {
            return attr.parse_args::<MyAttr>();
            //     ^^^^^^^^^^^^^^^^^^^^^^ 自动使用 attr 的 span
        }
    }
    Ok(MyAttr::default())
}

struct MyAttr { name: Option<String> }

impl syn::parse::Parse for MyAttr {
    fn parse(input: syn::parse::ParseStream) -> syn::Result<Self> {
        let mut name = None;
        if !input.is_empty() {
            let ident: syn::Ident = input.parse()?;
            if ident != "name" {
                return Err(syn::Error::new(ident.span(),
                    "expected `name`"));
            }
            input.parse::<syn::Token![=]>()?;
            let lit: syn::LitStr = input.parse()?;
            name = Some(lit.value());
        }
        Ok(MyAttr { name })
    }
}
```

== 调试技巧

=== 1. cargo expand — 查看宏展开结果

```bash
cargo install cargo-expand
cargo expand  # 展开所有宏，查看生成的代码
```

#example[
  ```bash
  $ cargo expand
  struct Point { x: i32, y: i32 }

  #[automatically_derived]
  impl MyTrait for Point {
      fn method(&self) -> String {
          format!("Point({}, {})", self.x, self.y)
      }
  }
  ```
]

=== 2. eprintln! — 打印调试信息

过程宏在编译期运行，打印到 stderr 会在编译输出中显示：

```rust
#[proc_macro_derive(MyTrait)]
pub fn my_derive(input: TokenStream) -> TokenStream {
    eprintln!("=== Debug ===");
    eprintln!("Input: {}", input);
    // ...
}
```

=== 3. 使用 syn::visit 遍历语法树

```rust
use syn::visit::{self, Visit};

struct FieldVisitor {
    fields: Vec<String>,
}

impl<'ast> Visit<'ast> for FieldVisitor {
    fn visit_field(&mut self, field: &'ast syn::Field) {
        if let Some(ref ident) = field.ident {
            self.fields.push(ident.to_string());
        }
        visit::visit_field(self, field);
    }
}

let mut visitor = FieldVisitor { fields: vec![] };
visitor.visit_derive_input(&input);
println!("Found fields: {:?}", visitor.fields);
```

=== 4. 单元测试

用 `proc_macro2` 而非 `proc_macro`：

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use syn::parse_quote;

    #[test]
    fn test_derive() {
        let input: syn::DeriveInput = parse_quote! {
            struct Point { x: i32, y: i32 }
        };
        let result = derive_my_trait_impl(&input).unwrap();
        let output = result.to_string();
        assert!(output.contains("impl MyTrait for Point"));
    }
}
```

== 避免 panic

#warning[
  永远不要在过程宏中 panic！

  ```rust
  // ❌ 不要这样做
  #[proc_macro_derive(Bad)]
  pub fn bad_derive(input: TokenStream) -> TokenStream {
      let input = parse_macro_input!(input as DeriveInput);
      let first_field = match &input.data {
          syn::Data::Struct(d) => d.fields.iter().next().unwrap(),
          _ => panic!("only structs supported"),
      };
      // ...
  }

  // ✅ 应该这样做
  #[proc_macro_derive(Good)]
  pub fn good_derive(input: TokenStream) -> TokenStream {
      let input = parse_macro_input!(input as DeriveInput);
      match good_derive_impl(&input) {
          Ok(tokens) => tokens.into(),
          Err(err) => err.to_compile_error().into(),
      }
  }
  ```

  panic 会导致：
  - 没有准确的错误位置
  - 无法看到其他错误（编译直接终止）
  - 用户不知道如何修复
]

== 小结

- 永远用 `syn::Error` 和 `?` 操作符——不要用 `unwrap()` 或 `panic!`
- `err.to_compile_error()` 把错误转化为 `compile_error!()` 宏
- `Span` 提供错误定位——`Error::new_spanned(value, msg)` 自动使用 value 的 span
- `cargo expand` 是调试的利器
- 单元测试用 `proc_macro2` 而非 `proc_macro`，用 `parse_quote!` 快速构造输入
- 永远在顶层函数中使用 `Result` 模式，而不是让 panic 泄漏出去
#pagebreak()
