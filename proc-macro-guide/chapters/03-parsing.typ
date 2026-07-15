#import "../lib.typ": *
= 解析：用 syn 把 TokenStream 变成数据结构
#labnote[ 第三站 ]

TokenStream 是一串 token。但我们需要像 Rust 编译器一样"看懂"代码——知道这是一个结构体定义，它有 3 个字段，第一个字段类型是 `String`，等等。

`syn` 就是做这个的。

#concept[
  `syn` 是一个 Rust 库，它能把 TokenStream *解析*（parse）成 Rust 语法对应的数据结构。

  就像 `serde_json` 把 JSON 字符串解析成 Rust 结构体，`syn` 把 Rust 源代码 TokenStream 解析成语法树（AST）。
]

== 第一条解析代码

```rust
use proc_macro::TokenStream;
use syn::{parse_macro_input, DeriveInput};

#[proc_macro_derive(Hello)]
pub fn derive_hello(input: TokenStream) -> TokenStream {
    // parse_macro_input! 是 syn 提供的便捷宏
    // 它把 TokenStream 解析成 DeriveInput 结构体
    // 如果解析失败，会自动生成友好的编译错误
    let input = parse_macro_input!(input as DeriveInput);

    // 打印结构体名称到 stderr（编译时可见）
    eprintln!("Struct name: {}", input.ident);

    // 暂时返回空 TokenStream
    TokenStream::new()
}
```

== DeriveInput

#definition[
  `DeriveInput` 是 derive 宏中最常用的解析类型。它代表用 `#[derive(...)]` 标记的数据类型定义。

  包含：
  - `ident`: `Ident` — 结构体/枚举的名称
  - `attrs`: `Vec<Attribute>` — 外部属性（如 `#[serde(...)]`）
  - `data`: `Data` — 具体的数据定义（结构体/枚举/联合体）
  - `generics`: `Generics` — 泛型参数
]

#example[
  给定这个输入：

  ```rust
  #[derive(Hello)]
  #[serde(rename_all = "camelCase")]
  pub struct Player {
      pub name: String,
      #[hello(greeting = "Hi")]
      pub level: u32,
  }
  ```

  syn 解析出的 `DeriveInput` 结构：

  ```
  DeriveInput {
      ident: Ident("Player"),
      attrs: [Attribute { path: "serde", ... }],
      data: Data::Struct(DataStruct {
          struct_token: Struct,
          fields: Fields::Named(FieldsNamed {
              named: [
                  Field { ident: Some("name"), ty: Type::Path("String"), attrs: [] },
                  Field { ident: Some("level"), ty: Type::Path("u32"),
                          attrs: [Attribute { path: "hello", ... }] },
              ],
          }),
      }),
      generics: Generics { params: [], ... },
  }
  ```

  syn 把扁平的 token 整理成了有意义的层级结构！
]

== 解析不同的数据类型

`Data` 枚举代表了 Rust 的数据类型定义：

```rust
pub enum Data {
    Struct(DataStruct),  // struct { ... }
    Enum(DataEnum),      // enum { ... }
    Union(DataUnion),    // union { ... }
}
```

每个变体都包含对应的字段信息：

```rust
pub enum Fields {
    Named(FieldsNamed),     // struct { x: i32, y: String }
    Unnamed(FieldsUnnamed), // struct(i32, String)
    Unit,                   // struct Nothing;
}
```

derive 宏可以通过匹配这些枚举来判断输入的结构类型，分别处理。

== 不只是 DeriveInput

syn 几乎能解析所有 Rust 语法结构：

| syn 类型 | 对应 Rust 语法 |
|:---|:---|
| `ItemFn` | `fn foo() { ... }` |
| `ItemImpl` | `impl Foo for Bar { ... }` |
| `ItemTrait` | `trait Foo { ... }` |
| `Type` | 任何类型表达式（`Vec<u32>`、`&str`） |
| `Expr` | 任何表达式（`a + b`、`foo()`） |
| `Lit` | 字面量（`42`、`"str"`、`true`） |
| `Pat` | 模式（`Some(x)`、`_`） |
| `Attribute` | `#[foo(...)]` |

这意味着我们可以解析函数体、trait 定义、甚至任意表达式。

== 属性解析：读取 `#[...]`

#concept[
  属性（attributes）是过程宏和外部世界通信的主要方式。

  `#[serde(skip)]` 告诉 serde"跳过这个字段"。
  `#[builder(default)]` 告诉 builder 宏"这个字段用默认值"。
]

```rust
use syn::{Attribute, Meta};

fn parse_attributes(attrs: &[Attribute]) {
    for attr in attrs {
        match &attr.meta {
            Meta::Path(path) => {
                // 简单属性：#[skip]
            }
            Meta::List(meta_list) => {
                // 带参数的属性：#[serde(rename = "foo")]
                // meta_list.tokens 包含括号内的 token
            }
            Meta::NameValue(meta_name_value) => {
                // 键值对：#[doc = "documentation"]
            }
        }
    }
}
```

== Parse trait：自定义解析

对于自定义 DSL（比如 `sql!` 宏），可以为自定义类型实现 `Parse` trait：

```rust
use syn::parse::{Parse, ParseStream};

struct SqlQuery {
    table: syn::Ident,
    columns: Vec<syn::Ident>,
}

impl Parse for SqlQuery {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        // 解析 "SELECT col1, col2 FROM table"
        input.parse::<syn::Token![SELECT]>()?;
        let mut columns = Vec::new();
        while !input.peek(syn::Token![FROM]) {
            columns.push(input.parse()?);
            if input.peek(syn::Token![,]) {
                input.parse::<syn::Token![,]>()?;
            }
        }
        input.parse::<syn::Token![FROM]>()?;
        let table = input.parse()?;
        Ok(SqlQuery { table, columns })
    }
}
```

过程宏不局限于标准 Rust 语法——可以用 `Parse` 定义自己的语法规则。

== syn 的 features

```toml
[dependencies]
syn = { version = "2.0", features = [
    "full",       # 完整语法解析（ItemFn、Expr 等）
    "extra-traits", # 为语法树实现 Debug、Clone、Eq 等
    "visit",      # 语法树遍历
    "fold",       # 语法树变换
] }
```

- 只写 derive 宏？`features = ["derive"]` 就够了
- 写属性宏或函数式宏？需要 `features = ["full"]`
- `features = ["default"]` 包含 `derive`、`parsing`、`printing` 等基础功能

== 动手验证

```rust
use syn::{DeriveInput, Data, Fields};

fn describe_struct(input: &DeriveInput) {
    match &input.data {
        Data::Struct(data) => {
            let fields = &data.fields;
            println!("Struct `{}` has {} field(s):", input.ident, fields.len());
            for (i, field) in fields.iter().enumerate() {
                let name = field.ident.as_ref()
                    .map(|id| id.to_string())
                    .unwrap_or_else(|| format!("field_{}", i));
                let ty = quote::quote! { #field.ty }.to_string();
                println!("  - {}: {}", name, ty);
            }
        }
        Data::Enum(data) => {
            println!("Enum `{}` has {} variant(s):", input.ident, data.variants.len());
            for variant in &data.variants {
                println!("  - {}", variant.ident);
            }
        }
        _ => {}
    }
}
```

== 小结

- `syn` 把 TokenStream 解析成 Rust 语法树
- `DeriveInput` 是 derive 宏的入口数据结构
- `Data` 枚举区分为结构体/枚举/联合体
- `Fields` 枚举区分为命名/未命名/单元字段
- `Attribute` 让宏能读取 `#[...]` 参数
- 通过实现 `Parse` trait 可以解析自定义语法
- syn 的 feature flags 控制编译内容
#pagebreak()
