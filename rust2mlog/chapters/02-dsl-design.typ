#import "../lib.typ": *
= 设计 DSL — 从 MLOG 到 Rust 语法
#labnote[ 第二站：语法映射 ]

现在设计 DSL。目标：写起来像 Rust，编译出去像 MLOG。

== 设计原则

#concept[
  三条原则指导 DSL 设计：

  1. *表面像 Rust*：`let`、`if`、`while`、`loop` 等关键词都沿用
  2. *映射可预测*：每个 DSL 构造对应一组确定的 MLOG 指令
  3. *编译时检查*：变量未定义、break 在非循环中等错误在编译时捕获
]

== 语法映射表

=== 变量

| DSL | MLOG |
|:---|:---|
| `let x = 5;` | `set x 5` |
| `let mut x = 0;` | `set x 0` |
| `x = 10;` | `set x 10` |
| `let y = x;` | `set y x` |

变量自动创建，首次出现即声明。`let` / `let mut` 在语义上有区别（不可变 vs 可变），但编译后都是 `set`——不变性检查在编译时做。

=== 算术和比较

| DSL | MLOG |
|:---|:---|
| `let z = x + y;` | `op add z x y` |
| `let z = x * y + 1;` | `op mul __tmp x y` 然后 `op add z __tmp 1` |
| `let b = x > y;` | `op gt b x y` |
| `let b = x == 0;` | `op eq b x 0` |

复杂表达式自动分解——这是编译器的责任。

=== 条件

| DSL | MLOG |
|:---|:---|
| `if x > 0 { ... }` | `op gt __tmp x 0` → `jump __skip not __tmp` |
| `if x > 0 { ... } else { ... }` | 同上 + 额外 jump 到 else 分支 |

=== 循环

| DSL | MLOG |
|:---|:---|
| `while x < 10 { ... }` | 标签循环头 + 条件检查 + 条件跳转出口 |
| `loop { ... break; }` | 无条件循环 + break 转条件跳转 |
| `for i in 0..5 { ... }` | 展开为 while 循环 |

=== 特殊操作

| DSL | MLOG |
|:---|:---|
| `print("hello");` | `print "hello"` |
| `print(x);` | `print x` |
| `print_flush(msg);` | `printflush msg` |
| `let v = sensor(@unit, @x);` | `sensor v @unit @x` |
| `enable(block);` | `control enabled block 1 0 0 0` |
| `disable(block);` | `control enabled block 0 0 0 0` |
| `ubind(@poly);` | `ubind @poly` |

== 一个完整对照示例

DSL：

```rust
let mut i = 0;
let limit = 5;
let mut sum = 0;

while i < limit {
    sum += i;
    i += 1;
}

print("Sum: ");
print(sum);
print_flush(message1);
```

期望 MLOG 输出：

```
set i 0
set limit 5
set sum 0
:__while_0
op lt __tmp_0 i limit
jump __end_while_0 not __tmp_0
op add sum sum i
op add i i 1
jump __while_0
:__end_while_0
print "Sum: "
print sum
printflush message1
```

#intuition[
  不是 1:1 翻译，也不是完全不一样——

  每条 DSL 语句对应 1-3 条 MLOG 指令。表达式的自动分解和处理是编译器的核心工作。

  因为 MLOG 是「三地址码」形式的，它天然适合做编译目标。
]

== DSL 的明确限制

#warning[
  设计上*不支持*的特性：

  1. *函数调用* — MLOG 没有调用栈，所有代码内联展开
  2. *字符串操作* — MLOG 不支持字符串运算，只能 print
  3. *数组和结构体* — 只能用内存单元模拟
  4. *递归* — 不可能，因为没有栈
  5. *闭包/高阶函数* — 超出 MLOG 的能力
  6. *浮点精度控制* — MLOG 的数字是 64 位浮点

  这不是 Rust 的子集——这是一个受限的嵌入式 DSL。它的表达能力受 MLOG 指令集的约束。
]

== 为什么不像 Mindcode 那样做一个独立语言

Mindcode 选择做独立编译器，因为它追求通用性。我们的 DSL 选择嵌入 Rust，是因为：

1. *Rust 工具链*：IDE 高亮、格式化、Git 比较都来自 Rust
2. *编译时执行*：宏在 `cargo build` 时运行——不增加运行时依赖
3. *混合代码*：MLOG 程序可以和 Rust 逻辑混合在一起
4. *文本输出*：展开为 `&str`，可以写文件、网络发送、嵌入常量

这是 proc macro 作为编译器前端的经典应用。

== 小结

- DSL 语法映射到 MLOG 指令必须可预测、直接
- 变量映射到 `set`，运算映射到 `op`，控制流映射到 `jump`
- 特殊操作（sensor、control、print）有专用函数
- 不支持函数、字符串运算、递归——受 MLOG 限制
- 嵌入 Rust 的好处：IDE 支持、编译时执行、零运行时成本
#pagebreak()
