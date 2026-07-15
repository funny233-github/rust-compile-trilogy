#import "../lib.typ": *
= 属性宏 — 函数的注解
#labnote[ 第六站 ]

Derive 宏只能用于类型定义。但如果我们想注解一个 *函数* 呢？比如在所有函数调用前后插入日志？

这就是 *属性宏*（attribute macros）的用途。

== 属性宏的结构

#definition[
  属性宏用 `#[proc_macro_attribute]` 标注，接收 *两个* 参数：

  ```rust
  #[proc_macro_attribute]
  pub fn my_attribute(
      attr: TokenStream,   // 属性本身的参数
      item: TokenStream,   // 被注解的项
  ) -> TokenStream {
      // ...
  }
  ```

  - `attr`：`#[my_attribute(args...)]` 中的 `args...`
  - `item`：被注解的整个函数/结构体/模块定义
]

== 示例：#[log_call]

在每次函数调用前后插入日志：

```rust
// 用户代码
#[log_call]
fn add(a: i32, b: i32) -> i32 {
    a + b
}

fn main() {
    add(3, 4); // 输出: "Calling add(3, 4)"
}
```

实现：

```rust
use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, ItemFn};

#[proc_macro_attribute]
pub fn log_call(attr: TokenStream, item: TokenStream) -> TokenStream {
    let input_fn = parse_macro_input!(item as ItemFn);
    let fn_name = &input_fn.sig.ident;
    let fn_vis = &input_fn.vis;
    let fn_sig = &input_fn.sig;
    let fn_block = &input_fn.block;

    let arg_names: Vec<_> = input_fn.sig.inputs.iter().map(|arg| {
        match arg {
            syn::FnArg::Typed(pat_type) => &pat_type.pat,
            _ => panic!("Unexpected argument type"),
        }
    }).collect();

    let expanded = quote! {
        #fn_vis #fn_sig {
            eprintln!("Calling {} with ({})",
                stringify!(#fn_name),
                stringify!(#(#arg_names),*)
            );
            let result = #fn_block;
            eprintln!("{} returned: {:?}", stringify!(#fn_name), &result);
            result
        }
    };

    expanded.into()
}
```

#intuition[
  属性宏的工作方式：

  1. 编译器看到 `#[log_call] fn add(...) { ... }`
  2. 把整个函数定义传给宏
  3. 宏输出替换原来的函数定义
  4. 宏可以包一层、改签名、甚至完全换成不同的代码
]

== 用 attr 参数做配置

```rust
#[log_call(level = "warn")]
fn dangerous_op() {
    // ...
}
```

```rust
#[proc_macro_attribute]
pub fn log_call(attr: TokenStream, item: TokenStream) -> TokenStream {
    // attr 包含了 level = "warn" 这部分 token
    // 用 syn 解析 attr 参数
    if attr.is_empty() {
        // 默认行为
    } else {
        // 解析配置
    }
    // ...
}
```

== 典型用例

| 宏 | 用途 |
|:---|:---|
| `#[tokio::main]` | 将异步 main 函数包装进 runtime |
| `#[test]` | 标记测试函数 |
| `#[instrument]` (tracing) | 自动注入跟踪 span |
| `#[must_use]` 风格的 lint | 编译期检查 |

== 属性宏 vs Derive 宏

| 特性 | Attribute Macro | Derive Macro |
|:---|:---:|:---:|
| 输入 | 属性参数 + 被注解项 | 整个类型定义 |
| 输出 | 替换被注解项（完全改变） | 追加 impl 块 |
| 应用范围 | 函数、结构体、枚举、模块 | 结构体、枚举、联合体 |
| 灵活性 | 极高 | 中等 |
| 典型用例 | `#[tokio::main]` | `#[derive(Serialize)]` |

== 常见陷阱

#warning[
  属性宏展开时会完全替换被注解的项。

  如果只是想加东西（而不是替换），必须在输出中包含原始代码：

  ```rust
  // ❌ 错误：忘记了原始函数体
  quote! {
      eprintln!("before");
      // 忘了 include 原始函数
      eprintln!("after");
  }

  // ✅ 正确：保留原始函数体
  let original_body = &input_fn.block;
  quote! {
      eprintln!("before");
      #original_body
      eprintln!("after");
  }
  ```
]

== 小结

- 属性宏：`#[proc_macro_attribute]`，接收 `(attr, item)`，返回替换后的代码
- 可以应用于函数、结构体、枚举、模块等
- `attr` 参数让宏可配置
- 属性宏会完全替换被注解的项——不要忘了包含原始代码
- 典型用途：日志、拦截、包装、代码转换
- 和 Python 装饰器类似，但发生在编译时，没有运行时开销
#pagebreak()
