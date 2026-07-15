#import "../lib.typ": *
= 生成代码：quote! 魔法
#labnote[ 第四站 ]

解析搞定了——`syn` 把 TokenStream 变成我们可以操作的数据结构。现在反过来：从数据结构如何 *生成* 新的 TokenStream？

最直接的方式是字符串拼接，但不推荐：

```rust
format!("impl Hello for {} {{ ... }}", name)
```

问题：
1. 没有语法检查——拼错了编译器才知道
2. 标识符冲突风险——如果用户有个类型叫 `impl` 呢？
3. 没有卫生性——生成的临时变量可能和用户代码冲突
4. 代码丑陋、难以维护

`quote` 库提供了更好的方式。

#concept[
  `quote!` 宏让你在 Rust 代码中书写"模板"代码，模板中的 `#var` 会被替换为实际值。

  它生成的 TokenStream 是 *语法安全的*、*卫生的*，而且写起来像在写普通的 Rust 代码。
]

== 第一个 quote! 示例

```rust
use quote::quote;

let name = syn::Ident::new("Player", proc_macro2::Span::call_site());
let tokens = quote! {
    impl #name {
        pub fn new() -> Self {
            Self {}
        }
    }
};
// tokens 类型是 proc_macro2::TokenStream
// 可以转为 proc_macro::TokenStream: tokens.into()
```

展开后相当于：

```rust
impl Player {
    pub fn new() -> Self {
        Self {}
    }
}
```

#intuition[
  `quote!` 的魔法：你在 `quote! { ... }` 里写的是 Rust 代码，但它不会编译——它被编译成了 *生成这段 Rust 代码的代码*。

  `#var` 插值把 Rust 值嵌入到生成的代码中。
]

== 插值方式

| 语法 | 类型 | 效果 |
|:---|:---|:---|
| `#var` | `Ident` / `TokenStream` / `ToTokens` | 插入一个值 |
| `#( #var )*` | 迭代器 | 重复插值 |
| `#(#var),*` | 迭代器 | 重复插值，逗号分隔 |
| `#(#var),* ,` | 迭代器 | 重复插值，逗号分隔 + 尾部逗号 |

== 为结构体生成 getter 方法

#example[
  ```rust
  use syn::{Data, Fields, DeriveInput};
  use quote::quote;

  fn generate_getters(input: &DeriveInput) -> proc_macro2::TokenStream {
      let name = &input.ident;

      let fields = match &input.data {
          Data::Struct(data) => &data.fields,
          _ => panic!("Expected a struct"),
      };

      let getters = fields.iter().map(|field| {
          let field_name = &field.ident;
          let field_type = &field.ty;

          quote! {
              pub fn #field_name(&self) -> &#field_type {
                  &self.#field_name
              }
          }
      });

      quote! {
          impl #name {
              #(#getters)*
          }
      }
  }
  ```

  输入 `struct Point { x: i32, y: i32 }`，输出：

  ```rust
  impl Point {
      pub fn x(&self) -> &i32 { &self.x }
      pub fn y(&self) -> &i32 { &self.y }
  }
  ```
]

== 条件生成

`quote!` 支持条件插入。常用 `Option<TokenStream>` 模式：

```rust
let extra_impl = if has_debug {
    Some(quote! { impl std::fmt::Debug for #name { ... } })
} else {
    None  // None 表示不插入任何代码
};
```

== proc_macro2 与 proc_macro

`quote!` 返回的是 `proc_macro2::TokenStream`，不是 `proc_macro::TokenStream`。

#definition[
  `proc_macro2` 是 `proc_macro` 的跨平台封装。

  | `proc_macro` | `proc_macro2` |
  |---|---|
  | 只能在过程宏 crate 中使用 | 普通 crate 也能用 |
  | 不是 `Send` + `Sync` | 是 `Send` + `Sync` |
  | 只能操作来自编译器的 TokenStream | 可以创建任意 TokenStream |
  | 不能用于测试 | 可在单元测试中使用 |
]

典型写法——入口用 proc_macro，内部全部用 proc_macro2：

```rust
#[proc_macro_derive(Hello)]
pub fn derive_hello(input: proc_macro::TokenStream) -> proc_macro::TokenStream {
    let input: proc_macro2::TokenStream = input.into();                // 转
    let derive_input = syn::parse2::<syn::DeriveInput>(input).unwrap(); // 解析
    let output = quote! { /* ... */ };                                 // 生成
    output.into()                                                       // 转回
}
```

== ToTokens trait

任何实现了 `ToTokens` trait 的类型都可以用 `#var` 插入到 `quote!` 中。

- `Ident`、`Literal`、`Type`、`Expr` 等 syn 类型都实现了
- `String`、`i32` 等基础类型也实现了（生成字面量）
- 可以为自定义类型实现 `ToTokens`

```rust
use quote::{ToTokens, TokenStreamExt};

struct Wrapper(syn::Type);

impl ToTokens for Wrapper {
    fn to_tokens(&self, tokens: &mut proc_macro2::TokenStream) {
        // 在类型外面包一层 Wrapper<>
        // self.0.to_tokens(tokens);
        tokens.append(Ident::new("Wrapper", span));
    }
}
```

== 常见陷阱

#warning[
  *引用与借用：*

  - `#(#fields),*` 中的 `fields` 如果是迭代器，`quote!` 会消费它
  - 如果需要多次使用，用 `.collect::<Vec<_>>()` 先收集

  *Span 控制：*

  - `quote!` 默认使用当前调用位置的 span
  - 可以用 `quote_spanned! { span => ... }` 指定 span 以改善错误定位
]

== 小结

- `quote!` 宏让在代码中写"模板"，`#var` 做插值
- `#(#iter)*` 用于循环插入代码
- `proc_macro2` 是跨平台封装，syn 和 quote 都基于它
- `ToTokens` trait 定义值如何转换为 TokenStream
- `quote_spanned!` 控制生成代码的 span（错误定位）
- 永远用 quote! 而不是字符串拼接来生成代码
#pagebreak()
