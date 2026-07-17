#import "../lib.typ": *
= 回到 MLOG — 理论如何指导实践
#labnote[ 第十站：用前九章的理论重新审视 rust2mlog ]

前九章建立了从 C 到 Rust 到 x86 的完整编译理论。现在回到 rust2mlog——用这套理论解释 MLOG 编译器的工作。

== MLOG 编译器和 x86 编译器的同构

把两者放在同一张表里对照：

#table(
  columns: (auto, auto, auto),
  fill: (rgb("#e5e7eb"),),
  inset: 6pt,
  stroke: 0.5pt,
  [*阶段*], [*x86 编译器*], [*MLOG 编译器*],
  [解析], [C 语法 → AST], [DSL 语法 → AST],
  [中间表示], [AST → GIMPLE/LLVM IR], [AST → 三地址码 IR],
  [表达式], [树 → 三地址码 + 寄存器分配], [树 → 三地址码（不需寄存器分配）],
  [控制流], [if/while/for → cmp+jmp], [if/while/loop → jump],
  [函数], [调用约定 + 栈帧], [不支持（必须内联展开）],
  [变量], [虚拟寄存器 → 物理寄存器 + 溢出], [全局变量（唯一名称化）],
)

#intuition[
  MLOG 编译器和 x86 编译器是*同一棵树上结的不同果实*。

  三地址码是它们共同的根。差异在于叶子——目标指令集的不同约束。

  x86: 有限寄存器、有调用栈、有内存层次结构
  MLOG: 无限变量、无调用栈、无内存层次结构

  编译器前端可以完全共享，后端各自适配。
]

== MLOG 编译器的简化来源

MLOG 编译器比 x86 编译器简单得多。原因：

1. *不需要寄存器分配* — MLOG 的变量模型不需要映射到物理寄存器
2. *不需要栈帧管理* — 没有 call/ret，没有 rbp/rsp 操作
3. *不需要指令选择* — MLOG 的 op 指令就是三地址码的直接对应
4. *不需要指令调度* — MLOG 没有流水线，指令顺序不重要

#v(0.3em)
这四条中的每一条在 x86 编译器中都是一个几千行的 pass。

== 共享的部分

尽管后端不同，核心前端逻辑完全相同：

```rust
// 这个函数在 x86 编译器和 MLOG 编译器中的逻辑是一样的
fn lower_binary_expr(lhs: &Expr, op: BinaryOp, rhs: &Expr) -> IrValue {
    let lhs_val = lower_expr(lhs);    // 递归处理左子树
    let rhs_val = lower_expr(rhs);    // 递归处理右子树
    let result = new_temp();          // 分配临时变量
    emit(IrInstr::Op {                // 生成三地址码
        opcode: map_op(op),
        result: result.clone(),
        lhs: lhs_val,
        rhs: rhs_val,
    });
    IrValue::Var(result)
}
```

表达式分解、控制流标签生成、变量名管理——这些在 x86 和 MLOG 之间是*可复用的代码*。

== 如果给 MLOG 编译器加一个 x86 后端

核心文件结构：

```
mlog-compiler/
├── parser.rs         # DSL → AST（前后端共享）
├── ir.rs             # AST → 三地址码 IR（前后端共享）
├── codegen_mlog.rs   # IR → MLOG 文本
└── codegen_x86.rs    # IR → x86 汇编（新增）
```

只需要加一个文件——因为 IR 是前端和后端之间的稳定接口。

#concept[
  这就是 LLVM 架构的精髓：

  ```
  前端 (C/Rust/Swift/...) → LLVM IR ← 后端 (x86/ARM/WASM/...)
  ```

  三地址码 IR 是所有这些编译器的共同语言。

  MLOG 编译器也遵循相同的架构——只是目标不是机器码，而是 MLOG 文本。
]

== MLOG 作为教学编译目标的优势

MLOG 作为编译目标有几个独特的教学优势：

#table(
  columns: (auto, auto),
  fill: (rgb("#e5e7eb"),),
  inset: 6pt,
  stroke: 0.5pt,
  [*特性*], [*教学价值*],
  [天然三地址码], [不需要指令选择阶段],
  [无限变量], [不需要寄存器分配],
  [无调用栈], [简化函数编译（内联）],
  [人类可读], [输出可以手动检查和调试],
  [指令集小], [完整的后端不到 200 行],
)

这就是为什么用 MLOG 来学习编译器设计比用 x86 容易得多——它去掉了最复杂的两块（寄存器分配和指令选择），同时保留了编译器的核心骨架。

== 练习

#note[
  *题目位置*：`exercises/src/ch12_mlog.rs`

  *任务*：实现 `tac_to_mlog` 函数，把三地址码 IR 翻译为 MLOG 文本——这就是 rust2mlog 代码生成器后端的核心逻辑。

  给你：`Tac::BinOp { result: "t0", op: Add, lhs: Int(1), rhs: Int(2) }`

  你要输出：`"op add t0 1 2"`

  映射表：
  - `BinOp` → `"op <opcode> <result> <lhs> <rhs>"`
  - `Copy` → `"set <result> <value>"`
  - `Label` → `":<name>"`
  - `Jump` → `"jump <label> always"`
  - `IfGoto` → `"jump <label> equal <cond> false"`

  *验证*：`cd exercises && cargo test ch12`

  *答案*：`exercises/answers/ch12_mlog.rs`
]

== 小结

- MLOG 和 x86 编译器共享相同的 IR 层
- 差异在后端：MLOG 不需要寄存器分配、栈帧、指令选择
- 前端逻辑（解析、三地址码生成）完全可复用
- IR 是编译器架构的支点
- MLOG 是理想的教学编译目标——保留核心、去掉复杂
- 加一个 x86 后端只需要一个额外文件
#pagebreak()
