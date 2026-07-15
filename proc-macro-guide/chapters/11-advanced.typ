#import "../lib.typ": *
= 进阶主题
#labnote[ 第十一站 ]

至此我们已经掌握了过程宏的基础流程。现在来看一些更深层的机制。

== 卫生性（Hygiene）

#concept[
  *词法卫生性*（lexical hygiene）是宏系统最重要的保证之一——防止宏内部生成的标识符意外地和用户代码冲突。

  在 `macro_rules!` 中这是自动的。在过程宏中……需要手动控制。
]

```rust
// 宏生成的代码
let temp = 42;

// 如果用户代码也有 temp：
let temp = "hello";
my_macro!(); // 这里会冲突吗？
```

过程宏中生成的 `temp` 默认使用调用位置的 span——它会和外部在同一个作用域。

解决方案：使用 *唯一标识符*：

```rust
use quote::format_ident;

// 为每个宏调用生成唯一的标识符
let uid: u64 = /* 生成唯一 ID */;
let temp_var = format_ident!("__temp_{}", uid, span = span);

quote! {
    let #temp_var = 42;
    // 使用 #temp_var
}
```

== Span 的深层语义

#concept[
  `Span` 不只是"错误定位"——它还参与 Rust 的隐私检查和卫生性。

  - `Span::call_site()` — 使用宏调用位置的 span。此标识符可以和外部代码交互。
  - `Span::def_site()` — 使用宏定义位置的 span。此标识符是"完全卫生"的，外部无法访问。
  - 自定义 `Span` — 如果你知道自己在做什么，可以直接控制 span。
]

```rust
#[proc_macro]
pub fn make_answer(input: TokenStream) -> TokenStream {
    // ❌ def_site 生成的标识符无法访问用户 crate 中的类型
    let helper = Ident::new("Helper", Span::def_site());

    // ✅ call_site 生成的标识符可以访问宏调用位置
    let helper = Ident::new("Helper", Span::call_site());

    quote! {
        struct #helper;
        impl MyTrait for #helper { ... }
    }
}
```

不正确的 span 选择会导致"找不到类型"或"trait 未实现"等奇怪错误。

== 模块化

当宏变得复杂时，需要拆分文件：

```rust
// lib.rs
mod parsing;
mod codegen;
mod attrs;

#[proc_macro_derive(Builder, attributes(builder))]
pub fn derive_builder(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);
    builder_impl::expand(input)
        .unwrap_or_else(|err| err.to_compile_error())
        .into()
}
```

```rust
// parsing.rs — TokenStream → 配置数据结构
pub(super) fn parse_builder_attrs(field: &syn::Field) -> BuilderFieldConfig { ... }

// codegen.rs — 配置 → TokenStream
pub(super) fn generate_builder_struct(config: &BuilderConfig) -> proc_macro2::TokenStream { ... }

// attrs.rs — #[builder(...)] 属性解析
pub(super) struct BuilderFieldConfig {
    pub has_default: bool,
    pub default_expr: Option<proc_macro2::TokenStream>,
}
```

#concept[
  模块化原则：
  - 解析逻辑：把 TokenStream 变成配置
  - 代码生成：把配置变成 TokenStream
  - 入口：薄薄的包装层
]

== 编译时资源嵌入

过程宏可以在编译时读取文件、解析内容，生成对应的 Rust 代码：

```rust
#[proc_macro]
pub fn include_sql(input: TokenStream) -> TokenStream {
    let file_path: syn::LitStr = parse_macro_input!(input as syn::LitStr);
    let path = file_path.value();

    // 编译时读取 SQL 文件
    let sql = std::fs::read_to_string(&path)
        .expect("failed to read SQL file");

    // 编译时解析 SQL
    let parsed = parse_sql(&sql);

    // 生成类型安全的 Rust 代码
    let expanded = generate_typesafe_query(parsed);
    expanded.into()
}
```

这就是 `sqlx::query!` 的原理——编译时读取 SQL 文件，解析它，生成对应类型的行结构体。

== 发布过程宏 crate

通常过程宏 crate 分两个包：

```
my_macro/           # 用户依赖的包，导出 trait 和重新导出宏
my_macro_derive/    # 实际的 proc-macro crate（用户不直接依赖）
```

```toml
# my_macro/Cargo.toml
[dependencies]
my_macro_derive = { version = "0.1", path = "../my_macro_derive" }
```

```rust
// my_macro/src/lib.rs
pub use my_macro_derive::MyMacro;
pub trait MyMacro { ... }
```

依赖注意事项：

```toml
[dependencies]
syn = { version = "2.0", features = ["derive"] }  # 够用就行
quote = "1.0"
proc-macro2 = "1.0"
```

- syn 用 `features = ["derive"]` 即可（不需要 `full` 就尽量不加）
- 用最新稳定版，不依赖 nightly
- 不要引入运行时依赖

== 过程宏的限制

#warning[
  1. *只能生成代码* — 不能检查类型信息（类型检查在宏展开之后）
  2. *不能有副作用* — 除了读取文件，不能访问网络等
  3. *不能跨越模块边界* — 一个宏不能直接修改另一个模块的代码
  4. *编译时间* — 复杂宏会显著增加编译时间
  5. *递归限制* — 宏展开有深度限制
  6. *不支持跨 crate 的宏状态* — 每个 crate 独立编译宏
]

== 未来方向

| 特性 | 状态 | 说明 |
|:---|:---:|:---|
| `proc_macro_diagnostic` | nightly | 更丰富的诊断信息 |
| `proc_macro_span` | nightly | 更精确的 span 操作 |
| `proc_macro_tracked_env` | nightly | 跟踪环境变量变化 |
| 类型化宏参数 | RFC | 更安全地传递类型信息 |

即使没有 nightly 特性，稳定版的过程宏已经足够强大——serde、tokio、sqlx、axum 等核心生态都构建在它们之上。

== 本质

过程宏表面上是代码生成，但本质是 *编译时计算*。你把一部分决策工作从运行时挪到编译时——生成代码的逻辑本身在编译期运行，生成的代码在运行时执行。这是一个双层的计算模型。

理解了这一点，过程宏就不只是"省力工具"——它是一种强大的程序变换方式。

== 小结

- 卫生性：用 `Span` 控制标识符的可见范围，用 `format_ident!` 创建唯一变量名
- 模块化：解析逻辑、代码生成、属性处理分离
- 编译时资源嵌入：读取文件、解析 SQL、生成类型安全代码
- 发布策略：分离为 proc-macro crate 和 facade crate
- 限制：不能检查类型信息、有编译开销
- 本质：编译时计算——把决策从运行时提前到编译时
#pagebreak()
