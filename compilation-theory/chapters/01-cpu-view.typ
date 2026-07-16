#import "../lib.typ": *
= 最低抽象 — CPU 看到的世界
#labnote[ 第一站：目标机的眼睛 ]

写编译器的人必须理解目标机能做什么。取 x86-64 作为参考架构——不是为了精通汇编，而是为了理解任何 CPU 的底层共性。

== 寄存器：CPU 的零级缓存

寄存器是 CPU 内部最快的存储器。x86-64 有 16 个通用 64 位寄存器。

#table(
  columns: (auto, auto),
  fill: (rgb("#e5e7eb"),),
  inset: 6pt,
  stroke: 0.5pt,
  [*寄存器*], [*常用角色*],
  [`rax`], [返回值、累加器],
  [`rbx`], [被调用者保存],
  [`rcx`], [参数 4、计数器],
  [`rdx`], [参数 3、除法高 64 位],
  [`rsi`], [参数 2、源指针],
  [`rdi`], [参数 1、目标指针],
  [`rsp`], [*栈指针* — 指向栈顶],
  [`rbp`], [*基址指针* — 栈帧底部（可选）],
  [`r8`–`r15`], [参数 5–6、通用],
)

#concept[
  寄存器的本质：CPU 能*直接*操作的最快存储。

  操作寄存器的指令通常 1 个周期完成。
  操作内存的指令需要多周期（缓存命中/未命中差异极大）。
]

== 内存：大但慢

内存和寄存器之间通过 `load`（读入寄存器）和 `store`（写回内存）交互：

```asm
mov rax, [rbx]      ; load:  rax = *rbx（把 rbx 指向的地址的值读入 rax）
mov [rbx], rax      ; store: *rbx = rax
```

内存是字节数组——没有类型。32-bit 有符号整数和 32-bit 浮点数在内存里都是 4 个字节。区别只在*你用什么指令操作它们*。

== 核心指令

=== 数据移动

```asm
mov rax, rbx        ; rax = rbx
mov rax, 42         ; rax = 42（立即数）
mov rax, [rbx]      ; rax = 内存[rbx]
mov [rbx], rax      ; 内存[rbx] = rax
```

=== 算术

```asm
add rax, rbx        ; rax = rax + rbx
sub rax, rbx        ; rax = rax - rbx
imul rax, rbx       ; rax = rax * rbx（有符号乘）
idiv rbx            ; rax = rdx:rax / rbx; rdx = 余数
neg rax             ; rax = -rax
and rax, rbx        ; rax = rax & rbx
or  rax, rbx        ; rax = rax | rbx
xor rax, rbx        ; rax = rax ^ rbx
shl rax, cl         ; rax = rax << cl
shr rax, cl         ; rax = rax >> cl（逻辑）
sar rax, cl         ; rax = rax >> cl（算术）
```

=== 比较和跳转

```asm
cmp rax, rbx        ; 计算 rax - rbx，设置标志位，丢弃结果
je  label           ; 相等则跳
jne label           ; 不等则跳
jl  label           ; 小于（有符号）则跳
jg  label           ; 大于（有符号）则跳
jle label           ; 小于等于
jge label           ; 大于等于
jmp label           ; 无条件跳转
```

#concept[
  x86 的比较-跳转是两步操作：
  1. `cmp a, b` 做减法，只设置标志位（ZF、SF、OF、CF），不存储结果
  2. `jxx` 根据标志位决定是否跳转

  这和 MLOG 的 `jump label condition a b` 很不一样——MLOG 把比较和跳转合并成一条指令。
  但在三地址码层面，它们等价。
]

=== 函数调用

```asm
call func           ; push rip; jmp func
ret                 ; pop rip（返回到调用者）
```

== 没有的东西

在汇编层面不存在的东西——编译器必须自己实现：

#table(
  columns: (auto, auto),
  fill: (rgb("#e5e7eb"),),
  inset: 6pt,
  stroke: 0.5pt,
  [*高层概念*], [*汇编现实*],
  [变量名], [寄存器编号或栈偏移],
  [类型], [不同宽度的指令],
  [作用域], [不存在——只有地址],
  [控制流结构], [cmp + jmp 组合],
  [函数], [call + ret + 传参约定],
  [数组], [基址 + 偏移 × 元素大小],
  [对象/struct], [基址 + 字段偏移],
)

#intuition[
  *CPU 是一个极其简单的机器。*

  它能做的事：从寄存器/内存读取数据，做算术/位操作，把结果写回寄存器/内存，根据比较结果跳转。

  它不知道什么是 int、什么是 struct、什么是 for 循环。它只知道：mov、add、cmp、jmp。

  编译器的工作就是把 int、struct、for 循环全部翻译成 mov、add、cmp、jmp。
]

== 一个简单的 C → 汇编对照

C：

```c
int add(int a, int b) {
    return a + b;
}
```

x86-64：

```asm
add:
    lea eax, [rdi + rsi]   ; eax = rdi + rsi（a + b）
    ret
```

C 看来很简单——两个参数加起来返回。汇编层面：
- `a` 在 `rdi` 中（System V 调用约定，第一个整数参数）
- `b` 在 `rsi` 中（第二个参数）
- 结果放在 `eax` 中（返回值）
- `lea` 是一条指令完成加法并存入目标（不访问内存）

这就是编译的最底层——把语义映射到寄存器操作。理解了这一层，往上走的每一层抽象都有根可循。

== 小结

- CPU 的核心操作：mov / 算术 / cmp+jmp / call+ret
- 寄存器是最快的存储，内存大但慢
- 高层概念（类型、变量、循环）在汇编层*不存在*
- 编译 = 把不存在的东西翻译成存在的东西
- x86 比较-跳转是两步；MLOG 的 jump 是一步——但三地址码层等价
- 这是所有编译器后端的共同祖先
#pagebreak()
