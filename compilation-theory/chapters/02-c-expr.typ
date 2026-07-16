#import "../lib.typ": *
= C 表达式 → 汇编
#labnote[ 第二站：类型消失与三地址码 ]

C 表达式是嵌套的树。汇编指令是扁平的序列。翻译的核心就是把树变成序列——这和 rust2mlog 中的 AST → 三地址码是同一个问题。

== 最简单的对照

C：

```c
int x = a + b;
```

x86-64（假设 a 在 rsi，b 在 rdx）：

```asm
mov eax, esi        ; eax = a
add eax, edx        ; eax = eax + b
mov [x], eax        ; 存回内存
```

三条指令完成一条 C 语句。表达式内部已有隐含的三地址码结构：`temp = a; temp = temp + b; x = temp`。

== 复杂表达式分解

C：

```c
int z = a + b * c - d / e;
```

编译器内部先把它变成三地址码：

```
t0 = b * c
t1 = a + t0
t2 = d / e
t3 = t1 - t2
z  = t3
```

x86-64：

```asm
mov eax, [b]        ; t0 = b * c
imul eax, [c]
add eax, [a]        ; t1 = a + t0
mov ecx, [d]        ; t2 = d / e
cdq
idiv dword [e]
sub eax, ecx        ; t3 = t1 - t2  (wait, this is wrong...)
```

等等——这乱了。寄存器分配是一个独立的复杂问题。让我们用无限虚拟寄存器来简化思考。

== 用虚拟寄存器思考

#concept[
  *无限虚拟寄存器模型*：假设有无限多个寄存器 `r0, r1, r2, ...`。

  每个临时值占一个新寄存器。后面（第五章）再讨论如何把无限虚拟寄存器映射到有限的物理寄存器。

  这个模型和三地址码几乎同构：
  ```
  r3 = r1 op r2   ←→   op <opcode> r3 r1 r2
  ```
]

```
r0 = b * c
r1 = a + r0
r2 = d / e
r3 = r1 - r2
z  = r3
```

这三地址码和 MLOG 的 op 指令完全一致——只是寄存器名不同。

== 类型如何消失

C：

```c
char  c = 'A';       // 1 字节
short s = 1000;      // 2 字节
int   i = 100000;    // 4 字节
long  l = 100000;    // 8 字节
```

x86-64：

```asm
mov al, 65           ; char  → 8-bit 寄存器
mov ax, 1000         ; short → 16-bit
mov eax, 100000      ; int   → 32-bit
mov rax, 100000      ; long  → 64-bit
```

类型信息在编译时驱动了*指令选择*——决定用 `mov al`（8 位）还是 `mov eax`（32 位）。一旦指令生成，类型就消失了。

== 指针和内存寻址

C：

```c
int *p = &x;
int y = *p;          // y = *p
int z = p[3];        // z = *(p + 3)
```

汇编（假设 x 在栈上偏移 -4(rbp)，p 在 -8(rbp)）：

```asm
; int *p = &x;
lea rax, [rbp-4]     ; rax = &x
mov [rbp-8], rax     ; p = rax

; int y = *p;
mov rax, [rbp-8]     ; rax = p
mov eax, [rax]       ; eax = *p
mov [rbp-12], eax    ; y = eax

; int z = p[3];  = *(p + 3 * sizeof(int))
mov rax, [rbp-8]     ; rax = p
mov eax, [rax + 12]  ; eax = *(p + 12) = p[3]
```

`p[3]` 在汇编中消失——变成 `[rax + 12]`（12 = 3 × sizeof(int) = 3 × 4）。

#intuition[
  数组索引在编译时被*算术化*：
  `arr[i] → *(arr + i * sizeof(element))`

  这完全是一个编译时计算——生成的汇编中只有加法和解引用。
]

== 结构体字段访问

C：

```c
struct Point { int x; int y; };
struct Point p;
p.x = 10;
p.y = 20;
```

汇编：

```asm
; p 在栈上，基址 rbp-8
mov dword [rbp-8], 10     ; p.x = 10  (offset +0)
mov dword [rbp-4], 20     ; p.y = 20  (offset +4)
```

`p.x` 和 `p.y` 在编译时被计算为栈偏移量。编译完成后没有"字段名"这个概念。

== 表达式翻译的通用模式

无论目标是 x86 还是 MLOG：

+ 把嵌套表达式树拍平为三地址码序列
+ 每个操作数可以是：立即数、虚拟寄存器、内存位置
+ 为每个子表达式结果分配临时存储（寄存器或临时变量）
+ 按依赖顺序排列指令

在 x86 编译器中，步骤 3-4 还需要寄存器分配（第五章）。在 MLOG 编译器中不需要——MLOG 变量无限制。

== 练习

#note[
  *题目位置*：`exercises/src/ch02_expr.rs`

  *任务*：实现 `lower_expr_impl` 函数，将嵌套表达式树递归转换为三地址码序列。

  *验证*：`cd exercises && cargo test ch02`

  *答案参考*：`exercises/answers/ch02_expr.rs`
]

提示：递归处理是最简单的思路——Int 和 Var 不需要生成指令，直接返回对应的 Value；BinOp 先递归处理左右子树，再为当前运算生成临时变量和 BinOp 指令。

== 小结

- C 表达式是嵌套树，汇编是扁平序列
- 翻译 = 把树分解为三地址码
- 类型在编译时驱动指令选择，编译后消失
- 数组索引 `arr[i]` 变成 `*(base + i * stride)`
- 结构体字段变成编译时的偏移量
- 三地址码是所有编译目标的共同语言
- x86 有寄存器压力，MLOG 没有——这是关键差异
#pagebreak()
