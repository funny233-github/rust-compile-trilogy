#import "../lib.typ": *
= 三地址码 — 编译器的通用语言
#labnote[ 第六站：IR 的深层理论 ]

三地址码已经出现了多次——在第二章（C 表达式分解）、在 rust2mlog 的第五章（IR 设计）、在 MLOG 本身的指令格式中。

这一章把三地址码作为独立的理论对象来审视：它为什么是编译器的"通用语言"？

== 三地址码的形式

#definition[
  三地址码是一种中间表示，每条指令最多有三个操作数：

  ```
  result = operand1 ⟨operator⟩ operand2
  ```

  或者单操作数形式：
  ```
  result = ⟨operator⟩ operand
  ```

  操作数可以是：常量、变量、临时变量。
]

四种基本指令类型：

#table(
  columns: (auto, auto, auto),
  fill: (rgb("#e5e7eb"),),
  inset: 6pt,
  stroke: 0.5pt,
  [*类型*], [*形式*], [*示例*],
  [二元运算], [`x = y op z`], [`t1 = a + b`],
  [一元运算], [`x = op y`], [`t2 = -t1`],
  [复制], [`x = y`], [`t3 = b`],
  [条件跳转], [`if x op y goto L`], [`if t1 < 10 goto loop`],
  [无条件跳转], [`goto L`], [`goto end`],
)

这恰好是 MLOG 的 `op` + `set` + `jump` 指令族——MLOG 天然就是三地址码。

== 为什么三地址码是"最佳"IR

=== 对比：语法树

语法树（AST）保留了源代码的嵌套结构：

```
     (+)
    /   \
  (a)   (*)
       /   \
     (b)   (c)
```

这很漂亮，但不适合做分析和优化——指令顺序不明确，操作数位置不统一。

=== 对比：二地址码

x86 汇编很多指令是二地址的：

```asm
add rax, rbx    ; rax = rax + rbx（破坏了 rbx 还是 rax？是 rax）
```

二地址码的问题是：源操作数被破坏，需要额外指令来保留值。

=== 三地址码的黄金平衡

- 每条指令只做一件事（不像语法树可以有任意深度）
- 不破坏操作数（不像二地址码）
- 指令顺序明确（优化器可以重新排列）
- 操作数位置固定（便于写优化 pass）

#intuition[
  "三"不是随便选的。

  - 一地址码（累加器模型）：太受限，需要大量 load/store
  - 二地址码：破坏性操作，不够灵活
  - 三地址码：刚好表达了"取两个值，算一下，放结果"
  - 四地址码：多余（大多数运算只需要两个输入和一个输出）

  *三*是编译优化的甜点——足够表达所有操作，但不冗余。
]

== SSA 形式：更严格的三地址码

#definition[
  *静态单赋值*（Static Single Assignment, SSA）要求每个变量在程序中只被赋值一次。

  ```
  // 非 SSA
  x = a + b
  x = x + 1
  y = x * 2

  // SSA
  x1 = a + b
  x2 = x1 + 1
  y = x2 * 2
  ```

  如果有多个控制流路径都定义同一个变量，用 *phi 函数* 合并：

  ```
  if cond:
      x1 = 1
  else:
      x2 = 2
  x3 = phi(x1, x2)   // 根据来自哪个分支选择值
  ```
]

SSA 的主要优势：每个变量只有一个定义点——*使用-定义链*变得平凡。很多优化（常量传播、死代码消除）在 SSA 形式上更容易实现。

LLVM IR 就是 SSA 形式的三地址码。

== MLOG 和 x86 在三地址码下的统一

#table(
  columns: (auto, auto, auto),
  fill: (rgb("#e5e7eb"),),
  inset: 6pt,
  stroke: 0.5pt,
  [], [*x86*], [*MLOG*],
  [二元运算], [`add rax, rbx`（二地址）], [`op add result a b`（三地址）],
  [赋值], [`mov rax, 5`], [`set result 5`],
  [条件跳转], [`cmp a, b; je label`（两步）], [`jump label equal a b`（一步）],
)

从三地址码视角看，x86 的二地址指令只是语法差异——每条 x86 指令可以规范化为三地址形式。MLOG 本身就是三地址码。

#concept[
  计算 IR 的终极价值：

  不管你编译到 x86、ARM、MLOG 还是 WebAssembly——
  三地址码 IR 提供了统一的抽象。

  - 前端：语言特定 → IR
  - IR：分析和优化
  - 后端：IR → 目标语言

  这就是为什么 LLVM 能支持几十种前端语言和几十种后端目标——
  因为它们都在 LLVM IR（SSA 形式的三地址码）上汇合。
]

== 小结

- 三地址码是编译器的通用中间语言
- 语法树太深，二地址太受限，三地址刚好
- SSA = 每个变量只赋值一次 + phi 函数合并
- MLOG 的 op/set/jump 是天然的三地址码
- LLVM IR 是 SSA 形式的三地址码
- IR 是编译器架构的支点——前后端解耦
#pagebreak()
