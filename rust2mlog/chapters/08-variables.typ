#import "../lib.typ": *
= 变量系统
#labnote[ 第八站：作用域与唯一名称 ]

MLOG 变量是全局的。DSL 中我们写了 `let x = 5;`，在 MLOG 中它就是 `set x 5`。

但如果有作用域呢？如果两个嵌套的 block 中有同名变量呢？

== MLOG 的变量模型

#definition[
  在 MLOG 中：

  - 变量由 `set` 指令在运行时创建
  - 一个处理器中所有变量是全局可见的
  - 没有作用域的概念
  - 变量名就是字面名字——`counter` 在整个程序生命周期内指向同一个值

  编译器要解决的问题：将 DSL 中的*语义作用域*映射到 MLOG 的*平面命名空间*。
]

== 问题场景

```rust
let x = 10;
if something {
    let x = 20;  // 新作用域中的 x
    print(x);    // 应该输出 20
}
print(x);        // 应该输出 10（外层 x 没有被改变）
```

如果直接把两个 `x` 都翻译为 MLOG 的 `set x`，那么内层会覆盖外层——语义错误。

== 解决方案一：扁平化

对于简单的 DSL，可以禁止 shadowing——同一个变量只能声明一次：

```rust
let x = 10;
if something {
    let x = 20;  // 编译错误：'x' already defined
}
```

这最简单，但用户体验不好——不能在不同作用域中复用变量名。

== 解决方案二：唯一名称

更优雅的方案——给每个 `let` 声明的变量分配唯一的内部名称：

```rust
// DSL
let x = 10;
if something {
    let x = 20;
    print(x);
}
print(x);
```

内部映射：

```
x_0 = 10
x_1 = 20
print(x_1)
print(x_0)
```

MLOG：

```
set x_0 10
op neq __tmp_0 something 0
jump __skip equal __tmp_0 false
set x_1 20
print x_1
:__skip
print x_0
```

用户只看到 `x`，但编译器背后用 `x_0`、`x_1` 等唯一名称。

== 作用域管理

```rust
// vars.rs — 作用域 + 唯一名称管理
use std::collections::HashMap;

pub struct ScopeManager {
    // 当前作用域层级（0 = 全局）
    depth: usize,
    // 变量名 → 唯一 MLOG 名
    names: HashMap<String, String>,
    // 计数器，确保唯一
    counter: u64,
}

impl ScopeManager {
    pub fn new() -> Self {
        ScopeManager {
            depth: 0,
            names: HashMap::new(),
            counter: 0,
        }
    }

    // 进入新作用域（if body, while body, loop body）
    pub fn enter(&mut self) {
        self.depth += 1;
    }

    // 离开作用域
    pub fn leave(&mut self) {
        self.depth -= 1;
    }

    // 声明新变量
    pub fn declare(&mut self, name: &str) -> String {
        let unique = format!("__{}_{}", name, self.counter);
        self.counter += 1;
        self.names.insert(name.to_string(), unique.clone());
        unique
    }

    // 查找变量的唯一名称
    pub fn lookup(&self, name: &str) -> Option<&str> {
        self.names.get(name).map(|s| s.as_str())
    }
}
```

== 临时变量

临时变量不需要作用域管理——它们在 MLOG 中是全局的，但名称唯一即可。

```rust
// 临时变量生成
fn new_temp(&mut self) -> String {
    let id = self.temp_counter;
    self.temp_counter += 1;
    format!("__t{}", id)
}
```

临时变量在 MLOG 中生成 `__t0`、`__t1`……和用户变量区分开。

#concept[
  变量命名的层次策略：

  | 前缀 | 来源 | 示例 |
  |:---|:---|:---|
  | 无前缀 | 用户声明的变量（唯一化后） | `__counter_0` |
  | `__t` | 编译器自动生成的临时变量 | `__t0` |
  | `__` | 标签 | `__while_0`, `__break_1` |
  | `@` | MLOG 内建变量 | `@unit`, `@time` |

  用户不可能写出以 `__` 开头的变量名（诊断阶段会报错），所以不会有冲突。
]

== 不可变性检查

`let` vs `let mut` 的语义差异在 DSL 解析时检查：

```rust
// 解析 let 语句时记录可变性
struct VarInfo {
    unique_name: String,
    mutable: bool,
}

// 解析赋值语句时检查
fn check_assign(name: &str) -> Result<(), DiagError> {
    if let Some(info) = scope.lookup_info(name) {
        if !info.mutable {
            return Err(DiagError::new(
                span,
                format!("cannot assign to immutable variable '{}'", name),
            ));
        }
    }
    Ok(())
}
```

如果用户写了 `let x = 5;` 后又 `x = 10;`，编译器在编译时拒绝——因为 `let` 变量不可变。

== 完整例子

DSL：

```rust
let x = 10;         // → __x_0
let mut y = 5;      // → __y_1
y = y + 1;          // → set __y_1 (op add __t0 __y_1 1)
if y > 5 {
    let x = 20;     // → __x_2（新变量，不覆盖 __x_0）
    print(x);       // → print __x_2
}
print(x);           // → print __x_0
```

MLOG（带唯一名称）：

```
set __x_0 10
set __y_1 5
op add __t0 __y_1 1
set __y_1 __t0
op gt __t1 __y_1 5
jump __skip_0 equal __t1 false
set __x_2 20
print __x_2
:__skip_0
print __x_0
```

用户看到的 DSL 是干净的，编译器管理的 MLOG 是唯一的——两全其美。

== 小结

- MLOG 没有作用域——编译器必须管理
- 唯一名称化：每个 let 声明分配全局唯一的名字
- 作用域管理器跟踪进入/离开作用域
- 临时变量用独立命名空间 (`__tN`)
- 用户变量以 `__` 开头 + 计数器后缀防止冲突
- 不可变性在编译时检查——不产生 MLOG 指令
- 最终 MLOG 中的变量名是自动生成的，用户无需关心
#pagebreak()
