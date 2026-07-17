#import "../lib.typ": *
= 优化 — 编译器在帮你做什么
#labnote[ 第九站：不改变语义，只改善性能 ]

编译器不只做翻译——它还做优化。优化的原则是*在不改变可观察行为的前提下，让代码更快或更小*。

== 常量折叠 (Constant Folding)

```c
int x = 2 + 3 * 4;
```

编译器在编译时计算：

```c
int x = 14;   // 编译后
```

不仅是算术——字符串长度、数组大小、简单的条件判断都可能被折叠。

== 常量传播 (Constant Propagation)

```c
int a = 5;
int b = a + 3;    // → 8
int c = b * 2;    // → 16
```

经过传播和折叠：

```c
int a = 5;
int b = 8;
int c = 16;
```

如果后续没人用 `a` 和 `b`，它们会被死代码消除干掉，最后只剩 `int c = 16;`。

== 死代码消除 (Dead Code Elimination)

```c
int x = expensive_calculation();
return 42;
```

`x` 被定义但从未使用 → `expensive_calculation()` 可以被删除。

== 公共子表达式消除 (CSE)

```c
int x = a * b + c;
int y = a * b + d;   // a * b 重复计算
```

优化后：

```c
int tmp = a * b;
int x = tmp + c;
int y = tmp + d;
```

== 循环不变量外提 (Loop Invariant Code Motion)

```c
for (int i = 0; i < n; i++) {
    arr[i] = a * b + c;   // a * b + c 在每次迭代中相同
}
```

优化后：

```c
int tmp = a * b + c;
for (int i = 0; i < n; i++) {
    arr[i] = tmp;
}
```

== 内联 (Inlining)

```c
static int add(int a, int b) { return a + b; }
int x = add(3, 4);
```

内联后：

```c
int x = 3 + 4;   // 然后常量折叠 → 7
```

内联不仅省了 call/ret 的开销，更重要的是*暴露了更多的优化机会*——常量传播、CSE 等都能跨函数执行。

== 强度削减 (Strength Reduction)

```asm
; 乘法 → 移位 + 加法
imul rax, 8    →    lea rax, [rax*8]

; 除法 → 乘法 + 移位（编译器用魔法常量）
idiv rcx       →    mov rax, magic; mul; shr...
```

#intuition[
  优化的哲学：

  程序员写 *语义清晰* 的代码。
  编译器生成 *性能最优* 的代码。

  `a * 8` 和 `a << 3` 语义相同，但后者更快。
  程序员应该写 `a * 8`（它表达了"乘以 8"的意图），编译器负责把它变成移位。

  这是分工：人关注可读性，编译器关注性能。
]

== 优化的局限性

编译器不能优化一切：

- 不能改变 I/O 的顺序
- 不能删除 volatile 访问
- 不能跨编译单元做激进优化（除非 LTO）
- 不能确定指针别名时不能重排内存访问
- 不能展开递归深度不确定的函数

编译优化是*保守的*——它必须在保证正确性的前提下做变换。

== 这些优化和 MLOG 的关系

rust2mlog 中的 MLOG 编译器目前几乎是*零优化*的——直接从 AST → IR → MLOG。

但所有这些优化技术都可以应用到 MLOG 编译器上：
- CSE 可以减少 MLOG 中的冗余 `op` 指令
- 常量折叠可以在编译时计算常量表达式
- 死代码消除可以删除无用的 `set` 指令
- 循环不变量外提可以减少 MLOG 循环体中的指令数

MLOG 优化器和 x86 优化器使用的是同一种理论——只需要适配指令集。

== 练习

#note[
  *题目位置*：`exercises/src/ch10_optimize.rs`

  *任务*：实现 `constant_fold` 函数，遍历 TAC 指令，折叠所有常量运算。

  给你：`t0 = 2 + 3; t1 = t0 * 4; t2 = 10 - 5`

  你要输出：`t0 = 5; t1 = t0 * 4; t2 = 5`（`t0 * 4` 不变——`t0` 是变量，不做传播）

  提示：只匹配 `Tac::BinOp { lhs: Value::Int(_), rhs: Value::Int(_) }` 模式。折叠后用 `Tac::Copy { value: Value::Int(folded) }` 替换。其他指令原样保留。

  *验证*：`cd exercises && cargo test ch10`

  *答案*：`exercises/answers/ch10_optimize.rs`
]

== 小结

- 优化的原则：不改变语义，改善性能
- 常量折叠/传播、死代码消除、CSE、循环不变量外提、内联、强度削减
- 内联是最重要的优化——它暴露其他所有优化机会
- 编译器优化是保守的——安全第一
- MLOG 编译器也可以应用相同的优化 pass
- 编译优化的理论是通用的——跨越目标架构
#pagebreak()
