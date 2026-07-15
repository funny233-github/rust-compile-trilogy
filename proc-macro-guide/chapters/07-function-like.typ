#import "../lib.typ": *
= 函数式宏 — 自定义 DSL
#labnote[ 第七站 ]

Derive 宏扩展类型，属性宏注解函数——但还有第三种：函数式宏，它可以创造全新的语法。

`sqlx::query!("SELECT * FROM users")` 就是一个典型——嵌入在 Rust 中的 SQL，在编译时被解析和验证。

== 函数式宏的签名

#definition[
  函数式宏用 `#[proc_macro]` 标注，只接收一个参数：

  ```rust
  #[proc_macro]
  pub fn my_macro(input: TokenStream) -> TokenStream {
      // input 是 my_macro!(...) 中 ... 的 TokenStream
  }
  ```

  使用方式：
  ```rust
  my_macro!(任何 Rust token 或自定义语法);
  ```
]

== 案例：简化的 json! 宏

实现一个简化版 `json!` 宏，把 JSON 字面量转换为 Rust 表达式：

```rust
let data = json!({
    "name": "Rust",
    "year": 2015,
    "tags": ["systems", "performance"]
});
```

因为输入是合法的 Rust token（字面量、方括号、花括号），所以可以用 syn 的通用解析器。

```rust
use syn::parse::{Parse, ParseStream};
use syn::{LitStr, LitInt, Token};

enum JsonValue {
    Str(LitStr),
    Num(LitInt),
    Array(Vec<JsonValue>),
    Object(Vec<(String, JsonValue)>),
}

impl Parse for JsonValue {
    fn parse(input: ParseStream) -> syn::Result<Self> {
        if input.peek(LitStr) {
            input.parse().map(JsonValue::Str)
        } else if input.peek(LitInt) {
            input.parse().map(JsonValue::Num)
        } else if input.peek(Token![{]) {
            let content;
            syn::braced!(content in input);
            let mut pairs = Vec::new();
            while !content.is_empty() {
                let key: LitStr = content.parse()?;
                content.parse::<Token![:]>()?;
                let value: JsonValue = content.parse()?;
                pairs.push((key.value(), value));
                if content.peek(Token![,]) {
                    content.parse::<Token![,]>()?;
                }
            }
            Ok(JsonValue::Object(pairs))
        } else if input.peek(Token![[]]) {
            let content;
            syn::bracketed!(content in input);
            let mut values = Vec::new();
            while !content.is_empty() {
                values.push(content.parse()?);
                if content.peek(Token![,]) {
                    content.parse::<Token![,]>()?;
                }
            }
            Ok(JsonValue::Array(values))
        } else {
            Err(syn::Error::new(input.span(), "expected JSON value"))
        }
    }
}
```

#concept[
  syn 提供的括号解析辅助宏：

  - `syn::braced!(content in input)` — 匹配 `{...}`，返回内容的 ParseStream
  - `syn::bracketed!(content in input)` — 匹配 `[...]`
  - `syn::parenthesized!(content in input)` — 匹配 `(...)`
]

== 生成代码

```rust
fn generate_json(value: &JsonValue) -> proc_macro2::TokenStream {
    match value {
        JsonValue::Str(lit) => {
            quote! { #lit.into() }
        }
        JsonValue::Num(lit) => {
            quote! { #lit.into() }
        }
        JsonValue::Array(items) => {
            let items_ts: Vec<_> = items.iter().map(generate_json).collect();
            quote! { vec![ #(#items_ts),* ] }
        }
        JsonValue::Object(pairs) => {
            let keys: Vec<_> = pairs.iter().map(|(k, _)| {
                syn::LitStr::new(k, proc_macro2::Span::call_site())
            }).collect();
            let values_ts: Vec<_> = pairs.iter()
                .map(|(_, v)| generate_json(v))
                .collect();
            quote! {
                maplit::btreemap! {
                    #( #keys.into() => #values_ts ),*
                }
            }
        }
    }
}
```

== 解析自定义 DSL

函数式宏不限于 Rust 语法——你可以定义自己的 DSL。

#example[
  一个简单的 HTML 模板宏：

  ```rust
  let name = "World";
  let greeting = html! {
      <div class="container">
          <h1>"Hello, " (name) "!"</h1>
      </div>
  };
  ```

  这里 `<` 和 `>` 在 TokenStream 中是 Punct，`div` 是 Ident。
  解析器需要手动识别 `<` `ident` `attr`... `>` 的模式。
]

```rust
enum HtmlNode {
    Element { tag: String, attrs: Vec<(String, String)>, children: Vec<HtmlNode> },
    Text(String),
    Expr(proc_macro2::TokenStream),
}

fn parse_html(input: proc_macro2::TokenStream) -> Vec<HtmlNode> {
    let tokens: Vec<_> = input.into_iter().collect();
    // 遍历 token，识别 < > 结构
    // 遇到 ( ... ) 时，内部当作 Rust 表达式
    vec![]
}
```

== 函数式宏的典型用例

| 宏 | 用途 |
|:---|:---|
| `lazy_static!` | 声明懒静态变量 |
| `sqlx::query!` | 编译时 SQL 解析和验证 |
| `html!` | JSX 风格 HTML 模板 |
| `json!` (serde) | JSON 字面量转 Rust 值 |
| `regex!` | 编译期正则编译 |

== 函数式宏的挑战

#warning[
  函数式宏虽然灵活，但也有代价：

  1. *解析是手动的*——不同于 derive 宏有 `DeriveInput` 这种现成结构
  2. *错误信息可能不友好*——需要手动处理 span
  3. *语法不一定是合法 Rust*——`<div>` 在普通 Rust 中是运算符，在 html! 中是标签
  4. *维护成本高*——自定义语法需要自己写解析器
]

函数式宏展示了过程宏的终极形态：在 Rust 中嵌入任意 DSL。但大多数场景下，derive 和 attribute 宏已经足够——它们约束在 Rust 语法内，更安全、更容易维护。

== 小结

- 函数式宏：`#[proc_macro]`，接收一个 TokenStream，返回一个 TokenStream
- 输入可以是任何 token 序列——不受 Rust 语法约束
- 可以用 `syn::parse::Parse` trait + 辅助宏（braced、bracketed）解析
- 适合嵌入式 DSL：html、sql、json、regex
- 灵活性最高，但解析工作和错误处理也更复杂
- 如果 derive 或 attribute 宏能满足需求，优先用它们
#pagebreak()
