#import "../lib.typ": *
= 派生宏 — 自动实现 Trait
#labnote[ 第五站 ]

Rust 中最常见的过程宏就是 `#[derive(...)]`。

Serde 用它生成序列化代码，clap 用它从结构体生成命令行参数解析器，thiserror 用它生成 Error 实现。

== 从一个简单的 trait 开始

首先定义目标 trait：

```rust
// hello_macro_def/src/lib.rs
pub trait HelloMacro {
    fn hello_macro();
}
```

然后写过程宏，让用户能这样用：

```rust
use hello_macro::HelloMacro;
use hello_macro_derive::HelloMacro;

#[derive(HelloMacro)]
struct Pancakes;

fn main() {
    Pancakes::hello_macro(); // 输出: "Hello from Pancakes!"
}
```

== 派生宏的签名

```rust
// hello_macro_derive/src/lib.rs
use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, DeriveInput};

#[proc_macro_derive(HelloMacro)]
pub fn hello_macro_derive(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    let name = &input.ident;

    let expanded = quote! {
        impl hello_macro::HelloMacro for #name {
            fn hello_macro() {
                println!("Hello from {}!", stringify!(#name));
            }
        }
    };

    expanded.into()
}
```

#intuition[
  Derive 宏的核心流程：

  1. 编译器遇到 `#[derive(MyTrait)]` 时，把整个类型定义作为 TokenStream 传给宏
  2. 宏用 `syn` 解析成 `DeriveInput`
  3. 宏用 `quote!` 生成 `impl Trait for Type { ... }` 块
  4. 编译器把生成的代码拼接到类型定义的后面
]

== 处理泛型

如果结构体有泛型参数，不能简单粗暴地生成 impl 块——必须正确包含泛型约束。

```rust
#[derive(HelloMacro)]
struct Container<T: Display> {
    value: T,
}
```

#definition[
  `DeriveInput` 包含 `generics: Generics` 字段。

  `Generics` 提供了 `split_for_impl()` 方法，返回三个部分：

  - `impl_generics`：`<T: Display>` — 用于 `impl` 关键字后面
  - `ty_generics`：`<T>` — 用于类型名称后面
  - `where_clause`：如果有 where 约束，包含它
]

```rust
let (impl_generics, ty_generics, where_clause) = input.generics.split_for_impl();

let expanded = quote! {
    impl #impl_generics hello_macro::HelloMacro for #name #ty_generics #where_clause {
        fn hello_macro() {
            println!("Hello from {}!", stringify!(#name));
        }
    }
};
```

输出：

```rust
impl<T: Display> HelloMacro for Container<T> {
    fn hello_macro() { /* ... */ }
}
```

== 访问字段

```rust
use syn::{Data, Fields};

let fields = match &input.data {
    Data::Struct(data) => &data.fields,
    _ => panic!("HelloMacro only supports structs"),
};

let field_names: Vec<_> = fields.iter().map(|f| &f.ident).collect();
let field_types: Vec<_> = fields.iter().map(|f| &f.ty).collect();

let expanded = quote! {
    impl #impl_generics #name #ty_generics #where_clause {
        pub fn field_names() -> Vec<&'static str> {
            vec![#(stringify!(#field_names)),*]
        }
        pub fn field_types() -> Vec<&'static str> {
            vec![#(stringify!(#field_types)),*]
        }
    }
};
```

#concept[
  字段的 `ident` 是 `Option<Ident>`：

  - 命名结构体：`struct Foo { x: i32 }` → `Some("x")`
  - 元组结构体：`struct Foo(i32, String)` → `None`
  - 单元结构体：`struct Foo;` → 没有字段

  元组结构体用索引访问：`self.0`、`self.1`……
]

== 带属性的派生宏

让用户通过属性自定义行为：

```rust
#[derive(HelloMacro)]
#[hello_macro(greeting = "Hola")]
struct Person {
    name: String,
    #[hello_macro(skip)]
    age: u32,
}
```

关键在于 `#[proc_macro_derive]` 的第二个参数：

```rust
#[proc_macro_derive(HelloMacro, attributes(hello_macro))]
pub fn hello_macro_derive(input: TokenStream) -> TokenStream {
    // attributes(hello_macro) 告诉编译器：
    // 这个 derive 宏会消费 #[hello_macro(...)] 属性
    // 这样编译器不会报"不认识这个属性"
}
```

解析自定义属性：

```rust
fn parse_greeting(attrs: &[syn::Attribute]) -> Option<String> {
    for attr in attrs {
        if attr.path().is_ident("hello_macro") {
            let mut greeting = None;
            attr.parse_nested_meta(|meta| {
                if meta.path.is_ident("greeting") {
                    greeting = Some(meta.value()?.parse::<syn::LitStr>()?.value());
                }
                Ok(())
            }).ok()?;
            return greeting;
        }
    }
    None
}
```

== 完整的模式

```rust
let greeting = parse_greeting(&input.attrs)
    .unwrap_or_else(|| "Hello".to_string());

let expanded = quote! {
    impl #impl_generics #name #ty_generics #where_clause {
        fn hello_macro() {
            println!("{} from {}!", #greeting, stringify!(#name));
        }
    }
};
```

== Derive 宏的设计模式

所有 derive 宏都遵循同样的模式：

1. 用 `parse_macro_input!` 解析 `DeriveInput`
2. 用 `split_for_impl()` 处理泛型
3. 遍历 `data` 中的字段/变体
4. 读取 `attrs` 中的自定义属性
5. 用 `quote!` 生成 `impl Trait for Type` 代码
6. 用 `Result` 模式处理错误（`syn::Error` → `to_compile_error()`）

这就是 serde、clap、thiserror 等所有 derive 宏的工作方式。

== 小结

- Derive 宏签名：`#[proc_macro_derive(Name)]`，接收 `TokenStream`，返回 `TokenStream`
- 用 `syn::DeriveInput` 解析类型定义
- 用 `generics.split_for_impl()` 正确处理泛型
- 用 `input.data` 获取字段信息
- 用 `attributes(...)` 注册宏消费的自定义属性
- `parse_nested_meta` 是解析属性的利器
- 核心模式：解析 → 遍历 → 读取属性 → quote! 生成
#pagebreak()
