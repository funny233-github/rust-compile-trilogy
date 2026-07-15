#import "../lib.typ": *
= 序章：重复代码的问题

想象一下这个场景。

某团队正在用 Rust 开发一个游戏引擎。他们需要为多种类型实现类似的功能——

- 为每个组件类型实现一个 `update` 方法
- 为每种错误类型实现 `Display` 和 `Error` trait
- 为每个配置结构体写 `Default` 和 builder 模式

他们写了很多重复的代码。

== 方案一：复制粘贴

最直接的办法——手动为每个类型写一遍。

```rust
#[derive(Debug)]
pub struct Player {
    pub name: String,
    pub health: i32,
}

impl Player {
    pub fn new(name: String, health: i32) -> Self {
        Self { name, health }
    }
}

impl fmt::Display for Player {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Player({}, {})", self.name, self.health)
    }
}
```

再到 `Monster`、`Item`、`NPC`……每个都手动写一遍。团队有 50 个组件类型。

#table(
  columns: (auto, auto),
  fill: (rgb("#e5e7eb"),),
  inset: 6pt,
  stroke: 0.5pt,
  [*方案*], [*代价*],
  [复制粘贴 50 次], [约 3000 行模板代码，改一个字段名要改 5 个地方],
)

对于一次性原型，复制粘贴最快。但维护成本随着重复次数线性增长。

== 方案二：macro_rules!

Rust 自带的声明式宏可以处理简单的模板化场景：

```rust
macro_rules! impl_display {
    ($ty:ty, $($field:ident),+) => {
        impl fmt::Display for $ty {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                write!(f, stringify!($ty) "("
                    $( write!(f, "{}: {}", stringify!($field), self.$field) ),+
                    $( write!(f, ", ") ),+
                write!(f, ")")
            }
        }
    };
}
```

但 `macro_rules!` 有本质上的限制：

- 不能访问类型信息（不知道字段是 `String` 还是 `i32`）
- 不能根据类型做分支（不同类型用不同的格式化方式）
- 不能读取外部属性（`#[serde(rename = "...")]`）
- 语法表达能力有限，复杂逻辑很难写

`macro_rules!` 能处理简单的模板替换，但涉及类型信息的代码生成——它无能为力。

== 方案三：过程宏

Rust 的 *过程宏*（procedural macros）从根本上解决了这个问题。

它不是模板替换——它是把代码当作数据来操作：

- 接收一段 Rust 代码（以 TokenStream 的形式）
- 可以用任意 Rust 逻辑解析和处理它
- 输出一段新的 Rust 代码

```rust
// 过程宏是 TokenStream → TokenStream 的函数
#[proc_macro_derive(MyTrait)]
pub fn derive_my_trait(input: TokenStream) -> TokenStream {
    // 想做什么都行——遍历字段、读属性、访问文件、查数据库……
}
```

过程宏打破了 `macro_rules!` 的所有限制：

| 能力 | macro_rules! | 过程宏 |
|------|:---:|:---:|
| 访问类型信息 | ❌ | ✅ |
| 读取属性 | ❌ | ✅ |
| 条件分支 | 有限 | ✅ 任意逻辑 |
| 自定义语法 | ❌ | ✅ |
| 文件 I/O | ❌ | ✅ |

这就是 serde 的 `#[derive(Serialize)]`、tokio 的 `#[tokio::main]`、sqlx 的 `query!` 背后使用的技术。

== 本教程的目标

这本笔记不是 API 手册——它是一份探索记录。

我们从最基础的概念（"TokenStream 到底是什么？"）开始，一步步深入，直到能写出一个完整的 `#[derive(Builder)]` 宏。

每章围绕一个核心问题展开：

> 第一章：过程宏和 macro_rules! 有什么区别？
> 第二章：TokenStream 到底是什么？
> 第三章：怎么把 TokenStream 解析成有意义的结构？
> 第四章：怎么安全地生成代码？
> ……

准备好了吗？从第一章开始。
#pagebreak()
