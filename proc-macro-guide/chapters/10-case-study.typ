#import "../lib.typ": *
= 实战：从零实现 #[derive(Builder)]
#labnote[ 第十站 ]

现在做一个完整的东西——一个 `#[derive(Builder)]` 宏，为结构体自动生成 Builder 模式。

这是 Rust 生态中最经典的 derive 宏用例之一（`derive_builder`、`typed-builder` 等 crate 都在做类似的事）。

== 目标

用户写：

```rust
#[derive(Builder)]
struct Command {
    executable: String,
    #[builder(default)]
    args: Vec<String>,
    #[builder(default = "vec![]")]
    env: Vec<String>,
    current_dir: Option<String>,
}
```

然后能用：

```rust
let cmd = Command::builder()
    .executable("cargo".to_string())
    .args(vec!["build".to_string()])
    .build()
    .unwrap();
```

== 项目结构

```bash
cargo new builder-derive --lib
```

`Cargo.toml`：

```toml
[lib]
proc-macro = true

[dependencies]
syn = { version = "2.0", features = ["full"] }
quote = "1.0"
```

== 核心设计

这是写过程宏的关键设计模式：

1. 遍历字段，为每个字段收集信息
2. 为每个字段生成一个"builder 版本"（`Option<T>`）
3. 为每个字段生成一个 setter 方法
4. 在 `build()` 中检查必填字段，用 `unwrap_or_default()` 处理可选字段

== 解析阶段

```rust
use proc_macro::TokenStream;
use syn::{parse_macro_input, DeriveInput, Data, Fields};
use quote::quote;

#[proc_macro_derive(Builder, attributes(builder))]
pub fn derive_builder(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as DeriveInput);

    match derive_builder_impl(&input) {
        Ok(tokens) => tokens.into(),
        Err(err) => err.to_compile_error().into(),
    }
}

fn derive_builder_impl(input: &DeriveInput)
    -> syn::Result<proc_macro2::TokenStream>
{
    let struct_name = &input.ident;
    let builder_name = syn::Ident::new(
        &format!("{}Builder", struct_name),
        struct_name.span(),
    );

    let fields = match &input.data {
        Data::Struct(data) => &data.fields,
        _ => return Err(syn::Error::new_spanned(
            input, "Builder can only be derived for structs")),
    };

    let (impl_generics, ty_generics, where_clause) =
        input.generics.split_for_impl();

    // 遍历字段，收集信息
    let mut builder_fields = Vec::new();
    let mut setter_methods = Vec::new();
    let mut initializers = Vec::new();

    for field in fields.iter() {
        let field_name = field.ident.as_ref()
            .ok_or_else(|| syn::Error::new_spanned(
                field, "tuple structs not supported"))?;
        let field_type = &field.ty;

        let has_default = field.attrs.iter().any(|attr| {
            attr.path().is_ident("builder")
        });

        // Builder 结构体字段：Option<FieldType>
        builder_fields.push(quote! {
            #field_name: Option<#field_type>
        });

        // setter 方法
        setter_methods.push(quote! {
            pub fn #field_name(mut self, value: #field_type) -> Self {
                self.#field_name = Some(value);
                self
            }
        });

        // build() 中的初始化
        if has_default {
            initializers.push(quote! {
                #field_name: self.#field_name
                    .unwrap_or_default()
            });
        } else {
            initializers.push(quote! {
                #field_name: self.#field_name
                    .ok_or_else(|| format!(
                        "field `{}` is required",
                        stringify!(#field_name)
                    ))?
            });
        }
    }

    // 生成代码
    let expanded = generate_builder_code(
        struct_name, builder_name,
        impl_generics, ty_generics, where_clause,
        &builder_fields, &setter_methods, &initializers,
    );

    Ok(expanded)
}
```

== 代码生成阶段

```rust
fn generate_builder_code(
    struct_name: &syn::Ident,
    builder_name: syn::Ident,
    impl_generics: impl quote::ToTokens,
    ty_generics: impl quote::ToTokens,
    where_clause: impl quote::ToTokens,
    builder_fields: &[proc_macro2::TokenStream],
    setter_methods: &[proc_macro2::TokenStream],
    initializers: &[proc_macro2::TokenStream],
) -> proc_macro2::TokenStream {
    quote! {
        // Builder 结构体
        pub struct #builder_name #ty_generics #where_clause {
            #(#builder_fields),*
        }

        // Builder 的 new() 和 setter 方法
        impl #impl_generics #builder_name #ty_generics #where_clause {
            pub fn new() -> Self {
                Self {
                    #( #builder_fields: None ),*
                }
            }

            #(#setter_methods)*

            pub fn build(self) -> Result<#struct_name #ty_generics, String> {
                Ok(#struct_name {
                    #(#initializers),*
                })
            }
        }

        // 为原结构体添加 builder() 方法
        impl #impl_generics #struct_name #ty_generics #where_clause {
            pub fn builder() -> #builder_name #ty_generics {
                #builder_name::new()
            }
        }
    }
}
```

== 完整的展开示例

输入：

```rust
#[derive(Builder)]
struct Command {
    executable: String,
    #[builder(default)]
    args: Vec<String>,
}
```

展开为：

```rust
pub struct CommandBuilder {
    executable: Option<String>,
    args: Option<Vec<String>>,
}

impl CommandBuilder {
    pub fn new() -> Self {
        Self { executable: None, args: None }
    }

    pub fn executable(mut self, value: String) -> Self {
        self.executable = Some(value);
        self
    }

    pub fn args(mut self, value: Vec<String>) -> Self {
        self.args = Some(value);
        self
    }

    pub fn build(self) -> Result<Command, String> {
        Ok(Command {
            executable: self.executable
                .ok_or_else(|| "field `executable` is required".to_string())?,
            args: self.args.unwrap_or_default(),
        })
    }
}

impl Command {
    pub fn builder() -> CommandBuilder { CommandBuilder::new() }
}
```

== 进阶改进

=== 1. 支持 `#[builder(default = "expr")]`

```rust
fn get_default_value(field: &syn::Field) -> Option<proc_macro2::TokenStream> {
    for attr in &field.attrs {
        if attr.path().is_ident("builder") {
            let mut default = None;
            attr.parse_nested_meta(|meta| {
                if meta.path.is_ident("default") {
                    let value = meta.value()?;
                    let expr: syn::Expr = value.parse()?;
                    default = Some(quote! { #expr });
                }
                Ok(())
            }).ok()?;
            return default;
        }
    }
    None
}
```

=== 2. 支持文档注释转发

```rust
let doc_attrs: Vec<_> = field.attrs.iter()
    .filter(|a| a.path().is_ident("doc"))
    .collect();

quote! {
    #(#doc_attrs)*
    pub fn #field_name(mut self, value: #field_type) -> Self { ... }
}
```

=== 3. 一次报告所有缺失字段

```rust
let check_required: Vec<_> = fields.iter().filter_map(|field| {
    let has_default = field_has_default(field);
    if has_default { return None; }
    let field_name = &field.ident;
    Some(quote! {
        if self.#field_name.is_none() {
            missing.push(stringify!(#field_name));
        }
    })
}).collect();

quote! {
    pub fn build(self) -> Result<#struct_name, Vec<String>> {
        let mut missing = Vec::new();
        #(#check_required)*
        if !missing.is_empty() { return Err(missing); }
        Ok(#struct_name { #(#initializers),* })
    }
}
```

== 常见陷阱

#warning[
  *Builder 宏的几个陷阱：*

  1. *生命周期*：如果字段包含引用，builder 需要处理生命周期参数
  2. *默认值和必填字段的区分*：`Option` 本身可以是合法的字段值
  3. *错误收集*：一次报告所有缺失字段，而不是第一个就终止
  4. *Builder 的 consuming vs borrowing*：这里用了 `mut self`（消费），也可以用 `&mut self`（借用）
]

== 小结

- Builder 宏架构：遍历字段 → 生成 builder 结构体 → 生成 setter → 生成 build()
- 用 `#[builder(default)]` 标记可选字段
- 用 `ok_or_else` 在 build() 中检查必填字段
- 用 `format!("...")` 生成友好的缺失字段错误信息
- `parse_nested_meta` 处理属性参数
- 考虑生命周期、错误聚合等进阶需求
#pagebreak()
